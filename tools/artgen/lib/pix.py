"""Tiny pixel-art canvas: material labels + tone overrides -> shaded, outlined RGBA."""
from __future__ import annotations

import math

import numpy as np

from .vox import hexrgb, mix, mul

AUTO, LIGHT, SHADE, DEEP, FLAT, SHINE = 0, 1, 2, 3, 4, 5


def rgb(c):
    return hexrgb(c) if isinstance(c, str) else tuple(int(v) for v in c[:3])


class Canvas:
    """A label canvas. Each pixel stores a material id and a tone override."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.m = np.zeros((h, w), np.int16)
        self.t = np.zeros((h, w), np.int8)
        self.colors = [(0, 0, 0)]
        self._ids = {}
        self.no_outline = np.zeros((h, w), bool)

    def mat(self, c):
        c = rgb(c)
        if c not in self._ids:
            self._ids[c] = len(self.colors)
            self.colors.append(c)
        return self._ids[c]

    # --- primitives -------------------------------------------------------
    def px(self, x, y, c, tone=AUTO):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            if c is None:
                self.m[y, x] = 0
                self.t[y, x] = 0
            else:
                self.m[y, x] = self.mat(c)
                self.t[y, x] = tone

    def rect(self, x0, y0, x1, y1, c, tone=AUTO):
        """Inclusive rectangle."""
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.px(x, y, c, tone)

    def hline(self, x0, x1, y, c, tone=AUTO):
        self.rect(min(x0, x1), y, max(x0, x1), y, c, tone)

    def vline(self, x, y0, y1, c, tone=AUTO):
        self.rect(x, min(y0, y1), x, max(y0, y1), c, tone)

    def line(self, x0, y0, x1, y1, c, tone=AUTO, th=1):
        x0, y0, x1, y1 = (int(round(v)) for v in (x0, y0, x1, y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            for ox in range(th):
                for oy in range(th):
                    self.px(x0 + ox, y0 + oy, c, tone)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ray(self, x, y, ang, length, c, tone=AUTO, th=1, start=0):
        """Line from (x, y) along angle (degrees, screen space, 0 = right)."""
        a = math.radians(ang)
        ex, ey = math.cos(a), math.sin(a)
        self.line(x + ex * start, y + ey * start, x + ex * length, y + ey * length, c, tone, th)
        return (x + ex * length, y + ey * length)

    def ellipse(self, cx, cy, rx, ry, c, tone=AUTO):
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                if ((x - cx) / max(rx, 0.01)) ** 2 + ((y - cy) / max(ry, 0.01)) ** 2 <= 1.0:
                    self.px(x, y, c, tone)

    def poly(self, pts, c, tone=AUTO):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                if _inside(x + 0.5, y + 0.5, pts):
                    self.px(x, y, c, tone)

    def blit(self, other, ox=0, oy=0):
        for y in range(other.h):
            for x in range(other.w):
                k = other.m[y, x]
                if k:
                    self.px(x + ox, y + oy, other.colors[k], other.t[y, x])

    def mask(self):
        return self.m > 0

    # --- rendering --------------------------------------------------------
    def render(self, outline=True, ol_tint=(34, 22, 40), ol_mix=0.45, ol_mul=0.42,
               light=(255, 248, 230), light_amt=0.26, shade_mul=0.78, deep_mul=0.58, auto=True):
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), np.uint8)
        m = self.m
        filled = m > 0
        up = np.zeros_like(filled)
        up[1:] = filled[:-1]
        dn = np.zeros_like(filled)
        dn[:-1] = filled[1:]
        rt = np.zeros_like(filled)
        rt[:, :-1] = filled[:, 1:]
        lf = np.zeros_like(filled)
        lf[:, 1:] = filled[:, :-1]
        for y in range(h):
            for x in range(w):
                k = m[y, x]
                if not k:
                    continue
                c = self.colors[k]
                t = self.t[y, x]
                if t == AUTO and auto:
                    if not up[y, x]:
                        t = LIGHT
                    elif not rt[y, x] or not dn[y, x]:
                        t = SHADE
                    else:
                        t = FLAT
                if t == LIGHT:
                    c = mix(c, light, light_amt)
                elif t == SHINE:
                    c = mix(c, (255, 255, 255), 0.55)
                elif t == SHADE:
                    c = mix(mul(c, shade_mul), (60, 50, 110), 0.08)
                elif t == DEEP:
                    c = mix(mul(c, deep_mul), (50, 30, 80), 0.12)
                out[y, x, :3] = c
                out[y, x, 3] = 255
        if outline:
            for y in range(h):
                for x in range(w):
                    if filled[y, x]:
                        continue
                    best = None
                    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < w and 0 <= yy < h and filled[yy, xx] and not self.no_outline[yy, xx]:
                            c = self.colors[m[yy, xx]]
                            lum = c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11
                            if best is None or lum < best[0]:
                                best = (lum, c)
                    if best is not None:
                        c = mul(best[1], ol_mul)
                        if ol_tint is not None:
                            c = mix(c, ol_tint, ol_mix)
                        out[y, x, :3] = c
                        out[y, x, 3] = 255
        return out


def _inside(x, y, pts):
    n = len(pts)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def over(dst, src):
    """Alpha-composite src over dst (both uint8 RGBA, same shape); binary alpha."""
    a = src[..., 3:4] > 0
    return np.where(a, src, dst)


def flip(arr):
    return arr[:, ::-1].copy()
