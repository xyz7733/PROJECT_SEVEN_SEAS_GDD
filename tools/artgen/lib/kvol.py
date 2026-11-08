"""Scaled voxel volume for furniture built in the kit's original units.

The facility builders and lib/kit.py were written for 8-voxel cells. Ships
now use 16-voxel cells and 24-voxel levels so crew, furniture and hull share
one human scale. KVol accepts the original coordinates and writes into a finer
Vol: x and y are doubled and heights above the floor are stretched by 1.5.
Outlines, ambient occlusion, plank seams and circles are resolved at the fine
resolution, so the result reads as larger furniture, not a blurred upscale.
"""
from __future__ import annotations

import math

import numpy as np

from .vox import SEAM, SEAM_L, SEAM_R, SEAM_SIDE, Vol

K = 2          # horizontal scale
KZ = 1.5       # vertical scale above the floor surface
FLOOR = 1      # kit.F: the floor top surface


def fz(z):
    """Map an integer kit height to the fine volume."""
    if z <= FLOOR:
        return int(z)
    return FLOOR + int(math.floor(KZ * (z - FLOOR) + 0.5))


def fzf(z):
    """Map a fractional kit height (lights, FX anchors)."""
    if z <= FLOOR:
        return float(z)
    return FLOOR + KZ * (z - FLOOR)


SEAMS = SEAM | SEAM_SIDE | SEAM_L | SEAM_R


class KVol:
    def __init__(self, W, H, Z, clip_z=None):
        self.shape = (W, H, Z)
        self.v = Vol(W * K, H * K, fz(Z) + 1)
        self.clip_z = clip_z
        X, Y, ZZ = self.v.shape
        # per-axis masks used to place seam lines on one sub-voxel row
        self._xo_last = (np.arange(X) % K) == K - 1
        self._yo_first = (np.arange(Y) % K) == 0
        self._yo_last = (np.arange(Y) % K) == K - 1
        starts = {fz(z) for z in range(0, Z + 1)}
        self._z_start = np.array([z in starts for z in range(ZZ)], bool)
        inv = np.zeros(ZZ, np.int32)
        for z in range(Z, -1, -1):
            a, b = fz(z), fz(z + 1)
            inv[a:max(a + 1, b)] = z
        self._zinv = inv

    # -- mapping -------------------------------------------------------------
    def _range(self, x0, y0, z0, x1, y1, z1):
        return K * x0, K * y0, fz(z0), K * x1, K * y1, max(fz(z1), fz(z0) + (1 if z1 > z0 else 0))

    def _apply_flags(self, sl, flags):
        """Write flags into slice sl, keeping seam bits only on their sub-row."""
        f = np.uint16(flags)
        base = np.uint16(flags & ~SEAMS)
        sx, sy, sz = sl
        X = np.arange(sx.start, sx.stop)
        Y = np.arange(sy.start, sy.stop)
        Z = np.arange(sz.start, sz.stop)
        out = np.full((X.size, Y.size, Z.size), base, np.uint16)
        if f & SEAM:
            m = self._yo_last[Y][None, :, None]
            out |= np.where(m, np.uint16(SEAM), np.uint16(0))
        if f & SEAM_SIDE:
            m = self._z_start[Z][None, None, :]
            out |= np.where(m, np.uint16(SEAM_SIDE), np.uint16(0))
        if f & SEAM_L:
            m = self._xo_last[X][:, None, None]
            out |= np.where(m, np.uint16(SEAM_L), np.uint16(0))
        if f & SEAM_R:
            m = self._yo_first[Y][None, :, None]
            out |= np.where(m, np.uint16(SEAM_R), np.uint16(0))
        self.v.flag[sl] = out

    def _clipz(self, z1):
        return z1 if self.clip_z is None else min(z1, self.clip_z)

    # -- Vol interface ---------------------------------------------------------
    def box(self, x0, y0, z0, x1, y1, z1, color, flags=0, group=None, jitter=0.0, seed=0):
        a = self._range(x0, y0, z0, x1, y1, z1)
        X, Y, Z = self.v.shape
        nx0, ny0, nz0 = max(0, a[0]), max(0, a[1]), max(0, a[2])
        nx1, ny1, nz1 = min(X, a[3]), min(Y, a[4]), min(Z, self._clipz(a[5]))
        if nx0 >= nx1 or ny0 >= ny1 or nz0 >= nz1:
            return
        if callable(color):
            fn = color
            zinv = self._zinv

            def color(xs, ys, zs):
                return fn(xs // K, ys // K, zinv[zs])
        self.v.box(nx0, ny0, nz0, nx1, ny1, nz1, color, 0, group, jitter, seed)
        self._apply_flags((slice(nx0, nx1), slice(ny0, ny1), slice(nz0, nz1)), flags)

    def put(self, x, y, z, color, flags=0, group=None):
        self.box(x, y, z, x + 1, y + 1, z + 1, color, flags, group)

    def clear(self, x0, y0, z0, x1, y1, z1):
        a = self._range(x0, y0, z0, x1, y1, z1)
        self.v.clear(*a)

    def cyl(self, cx, cy, z0, z1, r, color, flags=0, group=None, jitter=0.0, seed=0):
        a, b = fz(z0), self._clipz(max(fz(z1), fz(z0) + 1))
        if a >= b:
            return
        if callable(color):
            fn = color
            zinv = self._zinv

            def color(xs, ys, zs):
                return fn(xs // K, ys // K, zinv[zs])
        X, Y, _ = self.v.shape
        R = r * K
        ccx, ccy = cx * K, cy * K
        for x in range(int(math.floor(ccx - R)) - 1, int(math.ceil(ccx + R)) + 1):
            for y in range(int(math.floor(ccy - R)) - 1, int(math.ceil(ccy + R)) + 1):
                if (x + 0.5 - ccx) ** 2 + (y + 0.5 - ccy) ** 2 <= R * R and 0 <= x < X and 0 <= y < Y:
                    self.v.box(x, y, a, x + 1, y + 1, b, color, 0, group, jitter, seed + x * 7 + y)
                    self._apply_flags((slice(x, x + 1), slice(y, y + 1), slice(a, b)), flags)

    def mirror_xy(self):
        return self.v.mirror_xy()
