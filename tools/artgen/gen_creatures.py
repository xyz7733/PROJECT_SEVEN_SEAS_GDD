"""Creature, boss and pet sprite sheets built from parameterised body plans.

Monsters: 32x32 frames, bosses: 48x48, pets: 24x24. Each sheet row holds the
frames listed in FRAMES; every sprite faces right (flip for left).
"""
from __future__ import annotations

import json
import math

import numpy as np
from PIL import Image

from lib.common import GAME, OUT, PREVIEW, record, save_json, save_png
from lib.pix import AUTO, DEEP, FLAT, LIGHT, SHADE, SHINE, Canvas
from lib.vox import hexrgb, mix, mul

FRAMES = ["idle0", "idle1", "move0", "move1", "move2", "move3", "atk0", "atk1", "atk2", "hit", "down"]
ANIMS = {
    "idle": {"frames": [0, 1], "fps": 2}, "walk": {"frames": [2, 3, 4, 5], "fps": 7},
    "attack": {"frames": [6, 7, 8], "fps": 9, "loop": False}, "hit": {"frames": [9], "fps": 4, "loop": False},
    "down": {"frames": [10], "fps": 1, "loop": False}, "work": {"frames": [0, 2], "fps": 3},
    "cheer": {"frames": [7, 1], "fps": 4},
}


def pose_of(f):
    p = dict(bob=0, sq=0, step=None, lunge=0, wind=0, hit=False, down=False, open=False, wave=0)
    if f == "idle1":
        p.update(bob=1, sq=1, wave=1)
    elif f.startswith("move"):
        k = int(f[-1])
        p.update(step=k, bob=-1 if k % 2 else 0, wave=k % 2)
    elif f == "atk0":
        p.update(wind=2, bob=-1, open=True)
    elif f == "atk1":
        p.update(lunge=3, open=True, wave=1)
    elif f == "atk2":
        p.update(lunge=1)
    elif f == "hit":
        p.update(lunge=-2, hit=True)
    elif f == "down":
        p.update(down=True)
    return p


class SC:
    """Scaled canvas proxy: draw in a 32x32 design space onto any frame size."""

    def __init__(self, cv, s, ox=0.0, oy=0.0):
        self.cv, self.s, self.ox, self.oy = cv, s, ox, oy

    def X(self, x):
        return self.ox + x * self.s

    def Y(self, y):
        return self.oy + y * self.s

    def ell(self, cx, cy, rx, ry, c, t=AUTO):
        self.cv.ellipse(self.X(cx), self.Y(cy), rx * self.s, ry * self.s, c, t)

    def rect(self, x0, y0, x1, y1, c, t=AUTO):
        self.cv.rect(round(self.X(x0)), round(self.Y(y0)), round(self.X(x1 + 1) - 1), round(self.Y(y1 + 1) - 1), c, t)

    def line(self, x0, y0, x1, y1, c, t=AUTO, th=1):
        th2 = max(1, int(round(th * self.s)))
        self.cv.line(self.X(x0), self.Y(y0), self.X(x1), self.Y(y1), c, t, th2)

    def poly(self, pts, c, t=AUTO):
        self.cv.poly([(self.X(x), self.Y(y)) for x, y in pts], c, t)

    def px(self, x, y, c, t=AUTO):
        """A 'pixel' in design space; grows with scale."""
        n = max(1, int(round(self.s)))
        x0, y0 = int(round(self.X(x))), int(round(self.Y(y)))
        self.cv.rect(x0, y0, x0 + n - 1, y0 + n - 1, c, t)

    def dot(self, x, y, c, t=AUTO):
        self.cv.px(self.X(x), self.Y(y), c, t)


EYE = (36, 28, 48)


def eyes(sc, x, y, p, gap=4, col=EYE, glow=None, big=False):
    if p["down"]:
        for ex in (x, x + gap):
            sc.line(ex - 1, y - 1, ex + 1, y + 1, col, FLAT)
            sc.line(ex - 1, y + 1, ex + 1, y - 1, col, FLAT)
        return
    if p["hit"]:
        for ex, d in ((x, 1), (x + gap, -1)):
            sc.line(ex - d, y - 1, ex, y, col, FLAT)
            sc.line(ex, y, ex - d, y + 1, col, FLAT)
        return
    for ex in (x, x + gap):
        if glow:
            sc.px(ex, y, glow, SHINE)
            if big:
                sc.px(ex, y + 1, glow, LIGHT)
        else:
            sc.px(ex, y, col, FLAT)
            sc.px(ex, y + 1, col, FLAT)
            sc.dot(sc.X(0) * 0 + ex + 0.0, y, (255, 255, 255), SHINE) if big else None


# ----------------------------------------------------------- body plans ----

def plan_crab(sc, p, pal, crown=False):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    bx = 16 + p["lunge"] - p["wind"]
    by = 21 + p["bob"]
    if p["down"]:
        sc.ell(16, 25, 10, 4, b)
        sc.ell(16, 24, 7, 2, b, LIGHT)
        sc.ell(5, 27, 3, 2, b)
        sc.ell(27, 27, 3, 2, b)
        eyes(sc, 13, 22, p)
        return
    for side in (-1, 1):
        for i in range(3):
            ph = 0 if p["step"] is None else ((p["step"] + i) % 2)
            lx = bx + side * (4 + i * 2)
            sc.line(lx, by + 2, lx + side * 3, by + 6 - ph, mul(hexrgb(b), 0.8))
    sc.ell(bx, by, 10, 6.5 - p["sq"] * 0.5, b)
    sc.ell(bx, by - 2, 7, 3, b, LIGHT)
    sc.ell(bx, by + 3, 7, 2.2, l)
    for k in (-4, 0, 4):
        sc.px(bx + k, by - 3, a, SHINE)
    open_ = p["open"]
    for side in (-1, 1):
        cx = bx + side * 11 + (side * 2 if open_ else 0) + (p["lunge"] if side > 0 else 0)
        cy = by - 3 - (3 if open_ else 0)
        sc.line(bx + side * 7, by - 1, cx, cy + 2, b, th=2)
        sc.ell(cx, cy, 3.6, 3.2, b)
        sc.ell(cx - side * 0.5, cy - 1, 2, 1.2, b, LIGHT)
        if open_:
            sc.poly([(cx + side * 1, cy - 1), (cx + side * 4, cy - 2), (cx + side * 4, cy + 1)], None)
        else:
            sc.line(cx + side * 1, cy, cx + side * 3, cy, mul(hexrgb(b), 0.5), FLAT)
    for ex in (bx - 3, bx + 3):
        sc.line(ex, by - 5, ex, by - 8, b)
        sc.ell(ex, by - 9, 1.5, 1.5, (250, 250, 240))
        if p["hit"]:
            sc.px(ex, by - 9, EYE, FLAT)
        else:
            sc.dot(ex + 0.6, by - 9, EYE, FLAT)
    if crown:
        sc.rect(bx - 4, by - 9, bx + 4, by - 8, "#f0c048")
        for k in (-4, 0, 4):
            sc.px(bx + k, by - 10, "#f0c048", LIGHT)
        sc.px(bx, by - 8, "#d84a6a", SHINE)


def plan_golem(sc, p, pal, kind="rock"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 4 + p["bob"]
    if p["down"]:
        sc.ell(16, 26, 11, 3.5, b)
        sc.ell(9, 24, 4, 3, b)
        sc.ell(22, 25, 5, 3, b, LIGHT)
        sc.px(9, 23, a, SHINE)
        return
    # legs
    for i, side in enumerate((-1, 1)):
        lift = 1 if p["step"] is not None and (p["step"] + i) % 4 == 1 else 0
        sc.rect(x + side * 4 - 2, y + 20, x + side * 4 + 2, y + 24 - lift + (-p["bob"]), b)
        sc.rect(x + side * 4 - 3, y + 24 - lift - p["bob"], x + side * 4 + 3, y + 25 - lift - p["bob"],
                mul(hexrgb(b), 0.82))
    # back arm
    arm_y = y + 11 - (4 if p["open"] else 0)
    sc.ell(x - 9 - (1 if p["open"] else 0), arm_y + 4, 3.2, 5, b, SHADE)
    # torso
    sq = p["sq"]
    sc.poly([(x - 9, y + 6 + sq), (x + 9, y + 6 + sq), (x + 7, y + 21), (x - 7, y + 21)], b)
    sc.rect(x - 8, y + 6 + sq, x + 8, y + 7 + sq, b, LIGHT)
    sc.ell(x + 1, y + 14, 4, 3.5, l)
    # head
    hy = y + 1 + sq
    sc.rect(x - 5, hy + 6, x + 6, hy + 6, b, DEEP)
    sc.rect(x - 4, hy, x + 5, hy + 5, l)
    sc.rect(x - 4, hy, x + 5, hy, l, LIGHT)
    sc.rect(x - 4, hy + 5, x + 5, hy + 5, l, SHADE)
    sc.rect(x - 3, hy + 2, x + 4, hy + 2, b, DEEP)
    eyes(sc, x - 1, hy + 3, p, gap=4, glow=a, big=True)
    # front arm
    fx = x + 9 + (p["lunge"] * 2 if p["open"] or p["lunge"] > 1 else 0)
    fy = arm_y + (0 if not p["open"] else -2)
    sc.ell(fx, fy + 1, 3.5, 3, b)
    sc.ell(fx + 1, fy + 6, 3.8, 4.2, b)
    sc.ell(fx + 1, fy + 5, 2, 1.5, b, LIGHT)
    # material details
    if kind == "lava":
        for (dx, dy) in ((-5, 9), (-2, 12), (4, 9), (5, 17), (-4, 17)):
            sc.line(x + dx, y + dy, x + dx + 2, y + dy + 2, a, SHINE)
        sc.px(fx + 1, fy + 8, a, SHINE)
    elif kind == "bark":
        for dx in (-5, -1, 3):
            sc.line(x + dx, y + 8, x + dx + 1, y + 20, mul(hexrgb(b), 0.7), FLAT)
        sc.ell(x - 4, y + 6, 4, 1.6, a)
        sc.ell(x + 5, hy - 1, 2.5, 1.5, a)
        sc.px(x + 3, y + 6, "#f07aa0", SHINE)
    elif kind == "crystal":
        for (dx, dy, h) in ((-6, 5, 5), (-1, 3, 6), (5, 5, 4)):
            sc.poly([(x + dx - 1.5, y + dy + 2), (x + dx + 1.5, y + dy + 2), (x + dx, y + dy - h + 2)], a)
            sc.line(x + dx, y + dy - h + 3, x + dx, y + dy + 1, a, SHINE)
    elif kind == "storm":
        sc.line(x - 3, y + 9, x, y + 13, a, SHINE)
        sc.line(x, y + 13, x - 2, y + 15, a, SHINE)
        sc.line(x - 2, y + 15, x + 2, y + 19, a, SHINE)
        sc.ell(x, hy - 2, 4, 1.5, "#d8e0f0")
    elif kind == "abyss":
        for dx in (-5, 0, 5):
            sc.px(x + dx, y + 18, a, SHINE)
        sc.line(x - 4, hy - 1, x - 6, hy - 4, mul(hexrgb(b), 0.7))
        sc.line(x + 5, hy - 1, x + 7, hy - 4, mul(hexrgb(b), 0.7))
    elif kind == "ogre":
        sc.rect(x - 7, y + 17, x + 7, y + 20, a)
        sc.rect(x - 7, y + 17, x + 7, y + 17, a, LIGHT)
        sc.px(x + 1, hy + 5, (250, 250, 240), FLAT)
        sc.px(x + 3, hy + 5, (250, 250, 240), FLAT)
        if not p["hit"]:
            sc.px(x - 1, hy + 3, b, DEEP)
            sc.px(x + 3, hy + 3, b, DEEP)
    elif kind == "knight":
        sc.rect(x - 1, y + 7, x + 2, y + 20, a)
        sc.rect(x - 4, hy + 3, x + 5, hy + 3, (30, 26, 40), FLAT)
        sc.ell(x - 1, hy - 2, 4, 1.5, a)
        sc.px(x + 1, y + 10, "#f0c048", SHINE)
    elif kind == "shell":
        sc.ell(x, y + 10, 9, 6, a)
        for dx in (-5, 0, 5):
            sc.line(x + dx, y + 5, x + dx, y + 15, mul(hexrgb(a), 0.7), FLAT)
        sc.ell(x - 2, y + 7, 3, 1.5, a, LIGHT)
    elif kind == "core":
        sc.ell(x + 1, y + 13, 3, 3, a, SHINE)
        sc.ell(x + 1, y + 13, 1.5, 1.5, (255, 255, 255), SHINE)
    elif kind == "brass":
        sc.ell(x + 1, y + 13, 3.5, 3.5, "#f0c048")
        sc.line(x + 1, y + 13, x + 3, y + 11, "#d84a4a", FLAT)
        sc.line(x + 1, y + 13, x - 1, y + 15, (250, 250, 240), FLAT)


def plan_imp(sc, p, pal, kind="imp"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 15 + p["bob"] + (0 if p["step"] is None else (-1 if p["step"] in (1, 2) else 0))
    if p["down"]:
        sc.ell(16, 26, 7, 3, b)
        eyes(sc, 14, 25, p)
        return
    flap = p["wave"]
    if kind != "wisp":
        for side in (-1, 1):
            wx = x - 4 if side < 0 else x + 3
            tip = (wx + side * 8, y - 6 + flap * 4)
            sc.poly([(wx, y - 2), tip, (wx + side * 6, y + 3), (wx + side * 3, y + 1)], a, SHADE)
        sc.line(x - 3, y + 6, x - 9, y + 9 - flap, b)
        sc.poly([(x - 10, y + 8 - flap), (x - 12, y + 10 - flap), (x - 9, y + 11 - flap)], a)
    else:
        sc.poly([(x - 6, y + 2), (x + 6, y + 2), (x + 2 - flap * 2, y + 13), (x - 4 - flap, y + 10)], b)
    sc.ell(x, y, 7, 6.5 - p["sq"] * 0.5, b)
    sc.ell(x - 2, y - 3, 3, 1.6, b, LIGHT)
    sc.ell(x + 1, y + 3, 3.5, 2, l)
    if kind == "imp":
        sc.poly([(x - 5, y - 4), (x - 3, y - 5), (x - 6, y - 10)], l)
        sc.poly([(x + 3, y - 5), (x + 5, y - 4), (x + 6, y - 10)], l)
        sc.ell(x, y - 8, 1.5, 1.5 + flap * 0.5, a, SHINE)
    else:
        sc.px(x - 4, y - 7 - flap, a, SHINE)
        sc.px(x + 5, y - 8 + flap, a, SHINE)
        sc.px(x + 7, y - 3, a, SHINE)
    eyes(sc, x - 1, y - 1, p, gap=4, glow=None if kind == "wisp" else None)
    if p["open"]:
        sc.ell(x + 2, y + 3, 1.5, 1, (90, 30, 40), FLAT)


def plan_beast(sc, p, pal, kind="cat"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 15 + p["lunge"] - p["wind"]
    y = 20 + p["bob"]
    if p["down"]:
        sc.ell(16, 26, 11, 3.5, b)
        sc.ell(25, 24, 4, 3, b)
        eyes(sc, 24, 24, p, gap=3)
        return
    for i, lx in enumerate((x - 7, x - 4, x + 4, x + 7)):
        ph = 0 if p["step"] is None else (1 if (p["step"] + i) % 2 else -1)
        sc.line(lx, y + 2, lx + ph, y + 8, mul(hexrgb(b), 0.85 if i % 2 == 0 else 1.0), th=2)
    sc.line(x - 9, y - 1, x - 13, y - 6 - p["wave"], b, th=2)
    sc.ell(x - 13, y - 7 - p["wave"], 1.6, 1.6, a)
    sc.ell(x, y, 10, 4.5 - p["sq"] * 0.5, b)
    sc.ell(x, y - 2, 7, 1.6, b, LIGHT)
    sc.ell(x + 1, y + 2, 6, 1.6, l)
    hx = x + 10 + (2 if p["open"] else 0)
    hy = y - 5
    sc.ell(hx, hy, 5, 4.5, b)
    sc.poly([(hx - 4, hy - 2), (hx - 1, hy - 3), (hx - 3, hy - 8)], b)
    sc.poly([(hx + 1, hy - 3), (hx + 4, hy - 2), (hx + 3, hy - 8)], b)
    sc.px(hx - 3, hy - 5, a, FLAT)
    sc.px(hx + 2, hy - 5, a, FLAT)
    eyes(sc, hx - 2, hy - 1, p, gap=3, glow=a)
    if p["open"]:
        sc.poly([(hx + 1, hy + 2), (hx + 5, hy + 1), (hx + 4, hy + 4)], (90, 30, 50), FLAT)
    for (dx, dy) in ((-5, -1), (1, 1), (5, -2)):
        sc.px(x + dx, y + dy, a, SHINE)


def plan_plant(sc, p, pal, kind="trap"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    if p["down"]:
        sc.ell(16, 27, 9, 2.5, b)
        sc.ell(22, 25, 4, 3, a)
        return
    for i, side in enumerate((-1, 1)):
        ph = 0 if p["step"] is None else (p["step"] + i) % 2
        sc.line(x, 24, x + side * 7, 29 - ph, b, th=2)
        sc.line(x + side * 7, 29 - ph, x + side * 10, 28, b)
    sc.ell(x - 5, 22, 4, 1.8, l)
    sc.ell(x + 5, 21, 4, 1.8, l, SHADE)
    top = 9 + p["bob"]
    sway = p["wave"] if p["step"] is None else (1 if p["step"] % 2 else -1)
    sc.line(x, 25, x + sway, top + 7, b, th=2)
    hx = x + sway + 1 + (p["lunge"] if p["open"] else 0)
    open_ = 3 if p["open"] else 1
    sc.ell(hx, top - open_ * 0.5, 7, 4, a)
    sc.ell(hx, top + 3 + open_ * 0.5, 7, 3.5, a, SHADE)
    sc.ell(hx + 1, top + 1, 5, open_ * 0.8, (110, 30, 50), FLAT)
    for k in range(-4, 5, 2):
        sc.px(hx + k, top + 1 - open_ * 0.4, (250, 245, 230), FLAT)
    sc.ell(hx - 2, top - 3 - open_ * 0.5, 2.5, 1, a, LIGHT)
    for k in (-5, 0, 5):
        sc.px(hx + k, top - 4 - open_ * 0.6, l, LIGHT)
    if kind == "trap":
        sc.ell(hx - 1, top - 2, 1, 1, EYE, FLAT) if not p["hit"] else None


def plan_serpent(sc, p, pal, kind="eel"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 14 + p["lunge"] - p["wind"]
    sc.ell(16, 28, 11, 2.5, pal.get("pool", "#3a6a9a"))
    sc.ell(14, 27.5, 6, 1, pal.get("pool", "#3a6a9a"), LIGHT)
    if p["down"]:
        sc.ell(16, 26, 8, 3, b)
        eyes(sc, 18, 25, p, gap=3)
        return
    sway = p["wave"] if p["step"] is None else (1 if p["step"] % 2 else -1)
    pts = [(x - 2, 27), (x - 5 + sway, 22), (x - 2 - sway, 16), (x + 4, 11 + p["bob"])]
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        for t in np.linspace(0, 1, 6):
            r = 3.6 - (i + t) * 0.5
            sc.ell(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r, r, b)
    for (cx, cy) in pts[1:3]:
        sc.ell(cx + 1, cy + 1, 1.5, 1.2, l)
        sc.px(cx - 2, cy - 2, a, LIGHT)
    hx, hy = pts[-1][0] + 2, pts[-1][1] - 1
    sc.ell(hx, hy, 5.5, 4, b)
    sc.ell(hx - 1, hy - 2, 3, 1.2, b, LIGHT)
    sc.poly([(hx - 4, hy - 3), (hx - 1, hy - 4), (hx - 6, hy - 8)], a)
    if p["open"]:
        sc.poly([(hx + 1, hy + 1), (hx + 7, hy - 1), (hx + 6, hy + 4)], (110, 30, 50), FLAT)
        sc.px(hx + 5, hy, (250, 245, 230), FLAT)
    eyes(sc, hx, hy - 1, p, gap=3, glow=a if kind == "abyss" else None)


def plan_ghost(sc, p, pal, kind="ghost"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 13 + p["bob"] + (p["step"] % 2 if p["step"] is not None else 0)
    if p["down"]:
        sc.ell(16, 26, 9, 3, b)
        eyes(sc, 14, 25, p)
        return
    w = p["wave"]
    sc.ell(x, y, 8, 8, b)
    sc.poly([(x - 8, y), (x + 8, y), (x + 7, y + 13), (x + 3, y + 11 + w), (x, y + 14 - w), (x - 4, y + 11 + w),
             (x - 8, y + 13)], b)
    sc.ell(x - 3, y - 4, 3, 2, b, LIGHT)
    for side in (-1, 1):
        ax = x + side * 9 + (p["lunge"] if side > 0 and p["open"] else 0)
        sc.ell(ax, y + 4 - (3 if p["open"] else 0) + w * side, 2.2, 2.6, b)
    eyes(sc, x - 2, y - 1, p, gap=5, glow=a, big=True)
    if kind == "crown":
        sc.rect(x - 4, y - 9, x + 4, y - 8, "#f0c048")
        for k in (-4, 0, 4):
            sc.px(x + k, y - 10, "#f0c048", LIGHT)
    elif kind == "stars":
        for (dx, dy) in ((-5, 4), (4, 6), (0, 9), (6, -3)):
            sc.px(x + dx, y + dy, a, SHINE)
    elif kind == "lantern":
        sc.line(x + 9, y + 4, x + 9, y + 7, (90, 80, 70))
        sc.rect(x + 8, y + 7, x + 10, y + 10, "#f0c048")
        sc.px(x + 9, y + 8, "#fff2a0", SHINE)
    elif kind == "eye":
        sc.ell(x, y - 10, 3, 2, a)
        sc.px(x, y - 10, EYE, FLAT)


def plan_jelly(sc, p, pal, kind="jelly"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 14 + p["bob"] + (1 if p["step"] is not None and p["step"] % 2 else 0)
    if p["down"]:
        sc.ell(16, 26, 9, 3, b)
        sc.ell(16, 25, 6, 1.5, b, LIGHT)
        return
    w = p["wave"]
    # trailing tentacles
    for i in range(5):
        tx = x - 8 + i * 4
        sway = (w * 2 - 1) * (1 if i % 2 else -1)
        sc.line(tx, y + 3, tx + sway, y + 10 + (i % 2) * 2, mul(hexrgb(b), 0.78), th=1)
        if i % 2 == 0:
            sc.px(tx + sway, y + 11, a, LIGHT)
    # dome
    dome_h = 4 if p["open"] else 5
    sc.ell(x, y, 9, dome_h, b)
    sc.ell(x + 1, y - 2, 6, 2.2, b, LIGHT)
    sc.ell(x - 2, y + 2, 7, 2, l)
    for k in (-5, 0, 5):
        sc.px(x + k, y - 2, a, SHINE)
    if kind == "swarm":
        for k in (-7, -3, 3, 7):
            sc.px(x + k, y - 4 + (k % 3), a, SHINE)
    eyes(sc, x - 2, y - 1, p, gap=4, glow=a)
    if p["open"]:
        sc.ell(x + 1, y + 2, 2.2, 1.4, (90, 30, 50), FLAT)


def plan_ray(sc, p, pal, kind="ray"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 15 + p["bob"]
    if p["down"]:
        sc.ell(16, 26, 10, 3, b)
        sc.ell(16, 25, 6, 1.2, l)
        eyes(sc, 14, 24, p)
        return
    w = p["wave"]
    spread = 2 if p["open"] else 0
    sc.poly([(x - 13, y - 1 - w), (x - 2, y - 5), (x + 2, y - 1), (x - 8, y + 4 + w)], mul(hexrgb(b), 0.84), SHADE)
    sc.poly([(x + 13, y - 1 - w), (x + 2, y - 5), (x - 2, y - 1), (x + 8, y + 4 + w)], b)
    sc.line(x - 9, y - w, x - 3, y + 1, mul(hexrgb(b), 0.7), FLAT)
    sc.line(x + 4, y, x + 10, y - w, mul(hexrgb(b), 0.7), FLAT)
    sc.ell(x, y + 1, 5, 3.5 + spread * 0.3, b)
    sc.ell(x, y - 1, 3.5, 1.2, b, LIGHT)
    sc.ell(x, y + 2, 3.5, 1.3, l)
    sc.line(x - 3, y + 3, x - 7, y + 8 + w * 2, mul(hexrgb(b), 0.8), th=1)
    sc.px(x - 7, y + 9 + w * 2, a, SHINE)
    eyes(sc, x - 2, y - 1, p, gap=3, glow=a)


def plan_worm(sc, p, pal, kind="worm"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    if p["down"]:
        for i in range(4):
            sc.ell(10 + i * 4, 26, 3.5, 2.5, b if i % 2 == 0 else mul(hexrgb(b), 0.88))
        return
    sway = p["wave"] if p["step"] is None else (1 if p["step"] % 2 else -1)
    segs = 5
    for i in range(segs):
        t = i / (segs - 1)
        sx = x - 4 + t * sway * 3
        sy = 28 - t * (16 + p["bob"])
        r = 4.2 - t * 1.7
        sc.ell(sx, sy, r, r, b if i % 2 == 0 else mul(hexrgb(b), 0.88))
        sc.ell(sx - 1, sy - r * 0.45, r * 0.5, r * 0.28, b, LIGHT)
        sc.px(sx + r * 0.5, sy - 1, a, SHINE)
    hx = x - 4 + sway * 3 + (p["lunge"] if p["open"] else 0)
    hy = 12 - p["bob"]
    sc.ell(hx, hy, 5.2, 4.6, b)
    sc.ell(hx - 1, hy - 2, 3, 1.2, b, LIGHT)
    open_ = 2.4 if p["open"] else 1.2
    sc.ell(hx + 1, hy + 1, 3.2, open_, (90, 30, 50), FLAT)
    for k in (-2, 0, 2):
        sc.px(hx + 1 + k, hy + 1 - open_, (250, 245, 230), FLAT)
        sc.px(hx + 1 + k, hy + 1 + open_, (250, 245, 230), FLAT)
    sc.px(hx - 3, hy - 3, a, SHINE)


def plan_bird(sc, p, pal, kind="bird"):
    b, l, a = pal["body"], pal["belly"], pal["accent"]
    x = 16 + p["lunge"] - p["wind"]
    y = 15 + p["bob"]
    if p["down"]:
        sc.ell(16, 27, 9, 2.5, b)
        sc.ell(23, 25, 3, 2, b)
        return
    w = p["wave"]
    flap = -3 + w * 5
    sc.poly([(x - 2, y - 1), (x - 12, y - 6 + flap), (x - 5, y + 3), (x + 1, y + 2)], mul(hexrgb(b), 0.8), SHADE)
    sc.poly([(x - 5, y + 2), (x - 11, y + 5), (x - 9, y + 6), (x - 4, y + 4)], a, SHADE)
    sc.ell(x, y, 6, 5, b)
    sc.ell(x, y + 2, 4.5, 2, l)
    sc.poly([(x, y - 1), (x + 10, y - 9 + flap), (x + 7, y + 1), (x + 2, y + 3)], b)
    sc.line(x + 3, y - 1, x + 8, y - 7 + flap, mul(hexrgb(b), 0.7), FLAT)
    hx = x + 7 + (2 if p["open"] else 0)
    hy = y - 6
    sc.ell(hx, hy, 3.8, 3.4, b)
    sc.poly([(hx + 2, hy - 1), (hx + 7, hy + 1), (hx + 2, hy + 2)], "#e8b040")
    for k in (-4, 0, 4):
        sc.px(hx + k, hy - 4, a, SHINE)
    eyes(sc, hx - 1, hy - 2, p, gap=3, glow=a)


PLANS = {"crab": plan_crab, "golem": plan_golem, "imp": plan_imp, "beast": plan_beast, "plant": plan_plant,
         "serpent": plan_serpent, "ghost": plan_ghost, "jelly": plan_jelly, "ray": plan_ray, "worm": plan_worm,
         "bird": plan_bird}


def pal(body, belly, accent, **kw):
    d = dict(body=body, belly=belly, accent=accent)
    d.update(kw)
    return d


MONSTERS = {
    "reef_crab": ("crab", pal("#e0603a", "#f6d0a0", "#ffe0b0"), {}),
    "cinder_imp": ("imp", pal("#d8442a", "#ffb347", "#ffd060"), {"kind": "imp"}),
    "magma_golem": ("golem", pal("#4a3a36", "#6a4a40", "#ffb030"), {"kind": "lava"}),
    "vine_stalker": ("plant", pal("#3f8a3a", "#7ac04a", "#c6e86b"), {"kind": "trap"}),
    "bark_brute": ("golem", pal("#7a5a3a", "#9a7a4a", "#5fae4a"), {"kind": "bark"}),
    "quartz_knight": ("golem", pal("#a8c8d8", "#d8eef8", "#e7f7ff"), {"kind": "crystal"}),
    "thunder_brute": ("golem", pal("#5a6a80", "#7c8796", "#ffe066"), {"kind": "storm"}),
    "night_stalker": ("beast", pal("#3a3570", "#5a5590", "#d9c8ff"), {"kind": "cat"}),
    "dream_ogre": ("golem", pal("#8a7fd0", "#b0a8e8", "#5a4a8a"), {"kind": "ogre"}),
    "lull_spirit": ("imp", pal("#c8c0f0", "#eae6ff", "#fff3c4"), {"kind": "wisp"}),
    "abyss_brute": ("golem", pal("#3a2a40", "#5a4050", "#ff5a4a"), {"kind": "abyss"}),
    "shell_titan": ("golem", pal("#5fa89a", "#c9b28a", "#c9b28a"), {"kind": "shell"}),
    "bone_spitter": ("serpent", pal("#e8dcc0", "#c8b8a0", "#5fb39a", pool="#1f7a8c"), {"kind": "eel"}),
}

BOSSES = {
    "lookout_warden": ("golem", pal("#5a6a8a", "#8a9ab0", "#f0c048"), {"kind": "knight"}),
    "cellar_king": ("crab", pal("#c84a3a", "#f6d0a0", "#ffe0b0"), {"crown": True}),
    "vent_tyrant": ("imp", pal("#8a2a2a", "#ff7a3a", "#ffd060"), {"kind": "imp"}),
    "forge_colossus": ("golem", pal("#3a3036", "#5a4a48", "#ff8a30"), {"kind": "lava"}),
    "shrine_tyrant": ("plant", pal("#2f6a3a", "#9ad06a", "#d84a7a"), {"kind": "trap"}),
    "root_mother": ("golem", pal("#6a4a2a", "#8a6a3a", "#79c46a"), {"kind": "bark"}),
    "vault_sentinel": ("golem", pal("#7ab0c8", "#cfe6ef", "#e7f7ff"), {"kind": "crystal"}),
    "refraction_queen": ("ghost", pal("#9fd3e6", "#e7f7ff", "#ffffff"), {"kind": "crown"}),
    "archive_keeper": ("golem", pal("#5a3a8a", "#8a6ab0", "#ffd76a"), {"kind": "knight"}),
    "family_patriarch": ("golem", pal("#c8a040", "#f2dfa7", "#3f6fb8"), {"kind": "knight"}),
    "drowned_keeper": ("ghost", pal("#5a9a9a", "#a8d8d0", "#ffe066"), {"kind": "lantern"}),
    "tempest_wyrm": ("serpent", pal("#4a5f7a", "#8fa6bf", "#ffe066", pool="#2f3e55"), {"kind": "eel"}),
    "observatory_ghost": ("ghost", pal("#8a7fd0", "#d9c8ff", "#fff3c4"), {"kind": "stars"}),
    "labyrinth_dreamer": ("beast", pal("#5a4a9a", "#8a7fd0", "#f0e8ff"), {"kind": "cat"}),
    "seal_guardian": ("golem", pal("#4a3f4a", "#6a5a60", "#ff7a5a"), {"kind": "abyss"}),
    "trench_horror": ("serpent", pal("#3a2a40", "#5a4050", "#ff5a4a", pool="#221d28"), {"kind": "abyss"}),
    "gut_leviathan": ("serpent", pal("#1f7a8c", "#9ef0d0", "#9ef0d0", pool="#145566"), {"kind": "eel"}),
    "colossus_core": ("golem", pal("#5f9a8a", "#9ac8b8", "#9ef0d0"), {"kind": "core"}),
    "gate_warden": ("golem", pal("#e8e0d0", "#fff3c4", "#e08a4a"), {"kind": "knight"}),
    "compass_guardian": ("golem", pal("#a87a3a", "#f2b84a", "#fff3c4"), {"kind": "brass"}),
}

# Expansion bestiary (game/data/bestiary.json). Palettes are keyed by region so
# the same body plan reads as a different creature in every sea.
EXPANSION_MONSTERS = {
    "tide_jelly": ("jelly", pal("#6fb8d8", "#d8f4ff", "#ffd76a"), {}),
    "shoal_ray": ("ray", pal("#5aa8d8", "#d8f0ff", "#2a7a9a"), {}),
    "brine_worm": ("worm", pal("#7aa898", "#d8e8d8", "#ffd76a"), {}),
    "cinder_jelly": ("jelly", pal("#d8683a", "#ffc890", "#ffe066"), {}),
    "magma_ray": ("ray", pal("#c8543a", "#ffb080", "#ffd060"), {}),
    "ash_worm": ("worm", pal("#8a6a5a", "#c8b0a0", "#ff7a3a"), {}),
    "spore_jelly": ("jelly", pal("#7ab84a", "#d8f0a0", "#f07aa0"), {}),
    "canopy_ray": ("ray", pal("#4a9a4a", "#c8e898", "#f0d060"), {}),
    "mire_worm": ("worm", pal("#5a7a3a", "#b0c890", "#c6e86b"), {}),
    "prism_jelly": ("jelly", pal("#a8d8f0", "#ffffff", "#7af0f0"), {}),
    "shard_ray": ("ray", pal("#9fd3e6", "#ffffff", "#7af0f0"), {}),
    "glass_worm": ("worm", pal("#b8d8d8", "#e8f8f8", "#ffffff"), {}),
    "coin_jelly": ("jelly", pal("#e8c060", "#fff3c4", "#ffffff"), {}),
    "gilded_ray": ("ray", pal("#e8b040", "#fff3c4", "#c88a30"), {}),
    "vault_worm": ("worm", pal("#a8904a", "#e8d8a0", "#f0c048"), {}),
    "storm_jelly": ("jelly", pal("#5a6ab0", "#aab8ff", "#ffe066"), {}),
    "squall_ray": ("ray", pal("#6a7aa8", "#c8d0f0", "#ffe066"), {}),
    "thunder_worm": ("worm", pal("#6a6a8a", "#b0b0d0", "#ffe066"), {}),
    "dream_jelly": ("jelly", pal("#9a8ad8", "#e0d8ff", "#fff3c4"), {}),
    "moon_ray": ("ray", pal("#b0a8e0", "#f0e8ff", "#ffffff"), {}),
    "nightmare_worm": ("worm", pal("#6a5a8a", "#b0a0d0", "#ff8aa0"), {}),
    "abyss_jelly": ("jelly", pal("#8a98a8", "#d8e0e8", "#ff8a7a"), {}),
    "pale_ray": ("ray", pal("#c8d0d8", "#f0f4f8", "#ff9a8a"), {}),
    "trench_worm": ("worm", pal("#5a6068", "#a0a8b0", "#ff7a5a"), {}),
    "leviathan_jelly": ("jelly", pal("#4a9a8a", "#a8e0d0", "#ffe066"), {}),
    "reef_ray": ("ray", pal("#5ab0a0", "#c8f0e0", "#e8c060"), {}),
    "shell_worm": ("worm", pal("#7a9a7a", "#c8e0b8", "#e8c060"), {}),
    "star_jelly": ("jelly", pal("#e890a8", "#ffd8e0", "#fff3c4"), {}),
    "horizon_ray": ("ray", pal("#f0a8b8", "#fff0f4", "#ffd76a"), {}),
    "dawn_worm": ("worm", pal("#c8a080", "#f0dcc0", "#fff3c4"), {}),
    "swarmling": ("jelly", pal("#b8a84a", "#e8dca0", "#d84a3a"), {"kind": "swarm"}),
}

EXPANSION_BOSSES = {
    "harbor_leviathan": ("serpent", pal("#3a6a9a", "#9ad8e8", "#ffe066", pool="#1f4a6a"), {"kind": "eel"}),
    "magma_hydra": ("serpent", pal("#8a3a2a", "#ff8a4a", "#ffd060", pool="#5a2a1a"), {"kind": "eel"}),
    "spore_matriarch": ("plant", pal("#3a7a3a", "#8ad06a", "#f07aa0"), {"kind": "trap"}),
    "prism_serpent": ("serpent", pal("#8ac8e8", "#e8f8ff", "#7af0f0", pool="#5a9ab8"), {"kind": "eel"}),
    "gilded_kraken": ("crab", pal("#c8a040", "#f2dfa7", "#fff3c4"), {"crown": True}),
    "thunder_roc": ("bird", pal("#4a5f8a", "#a8b8e8", "#ffe066"), {"kind": "bird"}),
    "dream_eater": ("ghost", pal("#5a4a8a", "#a89ae0", "#ff8aa0"), {"kind": "eye"}),
    "void_angler": ("serpent", pal("#3a2a40", "#5a4050", "#ff5a4a", pool="#221d28"), {"kind": "abyss"}),
    "world_serpent": ("serpent", pal("#2f7a6a", "#8ae0c8", "#e8c060", pool="#1a4a40"), {"kind": "eel"}),
    "dawn_titan": ("golem", pal("#d8b878", "#fff3c4", "#ffb060"), {"kind": "brass"}),
}

EXPANSION_RARES = {
    "golden_crab": ("crab", pal("#e0b040", "#fff0b0", "#ffffff"), {"crown": True}),
    "cinder_moth": ("imp", pal("#d85a3a", "#ffb060", "#ffe066"), {"kind": "wisp"}),
    "elder_mossback": ("beast", pal("#4a7a3a", "#9ac87a", "#d8e8a0"), {"kind": "cat"}),
    "mirror_ray": ("ray", pal("#c8e8f0", "#ffffff", "#7af0f0"), {}),
    "coin_drake": ("serpent", pal("#c8a040", "#f2dfa7", "#fff3c4", pool="#8a6a2a"), {"kind": "eel"}),
    "storm_roc": ("bird", pal("#5a6aa8", "#c8d0f0", "#ffe066"), {"kind": "bird"}),
    "lunar_moth": ("imp", pal("#8a7ac8", "#d8c8ff", "#fff3c4"), {"kind": "wisp"}),
    "pale_angler": ("serpent", pal("#b8c0c8", "#e8eef2", "#ff8a7a", pool="#5a6068"), {"kind": "abyss"}),
    "island_whale": ("serpent", pal("#5a7a8a", "#b8d8e0", "#e8c060", pool="#2f4a5a"), {"kind": "eel"}),
    "aurora_wyrm": ("serpent", pal("#4a8a8a", "#a8f0d8", "#ffd76a", pool="#2a6a6a"), {"kind": "eel"}),
}


def render_rows(table, size, scale, origin):
    strips = {}
    for key, (plan, P, kw) in table.items():
        strip = np.zeros((size, size * len(FRAMES), 4), np.uint8)
        for i, f in enumerate(FRAMES):
            cv = Canvas(size, size)
            sc = SC(cv, scale, (size - 32 * scale) / 2, size - 32 * scale - (1 if size > 32 else 0))
            PLANS[plan](sc, pose_of(f), P, **kw)
            strip[:, i * size:(i + 1) * size] = cv.render()
        strips[key] = strip
    return strips


def pack(strips, size, name, per_line=2):
    keys = list(strips)
    lines = (len(keys) + per_line - 1) // per_line
    W = size * len(FRAMES) * per_line
    atlas = np.zeros((lines * size, W, 4), np.uint8)
    rows = {}
    for i, k in enumerate(keys):
        x = (i % per_line) * size * len(FRAMES)
        y = (i // per_line) * size
        atlas[y:y + size, x:x + size * len(FRAMES)] = strips[k]
        rows[k] = [x, y]
    path = OUT / "creatures" / f"{name}.png"
    save_png(atlas, path)
    record(path.relative_to(GAME.parent), f"{W}x{lines * size}", f"{len(keys)} rows x {len(FRAMES)} frames ({size}x{size})",
           "procedural body-plan pixel art (gen_creatures.py)", f"{name} sprites")
    return rows, atlas


# ---------------------------------------------------------------- pets ----
PET_FAMILIES = {
    "tidefin": dict(body="#5ab0e0", belly="#e8f6ff", accent="#2a7ab0", plan="seal"),
    "cinderback": dict(body="#e0603a", belly="#ffd8a0", accent="#ffc030", plan="lizard"),
    "mossling": dict(body="#6ab04a", belly="#d8f0a0", accent="#f07aa0", plan="sprout"),
    "glasswing": dict(body="#9fd3e6", belly="#ffffff", accent="#7af0f0", plan="flyer"),
    "pearlcub": dict(body="#f0d8c8", belly="#fff6ee", accent="#f0a0c0", plan="cub"),
    "cloudray": dict(body="#e8f0ff", belly="#ffffff", accent="#7ab0f0", plan="ray"),
    "dreammoth": dict(body="#b8a8e8", belly="#f0e8ff", accent="#ffe0a0", plan="moth"),
    "gloomjaw": dict(body="#4a3a6a", belly="#7a6a9a", accent="#ff5a6a", plan="pup"),
    "shellwarden": dict(body="#7ac0a0", belly="#e8dcb0", accent="#3a8a7a", plan="turtle"),
    "starwake": dict(body="#f2c860", belly="#fff3c4", accent="#ffffff", plan="fox"),
}
ROLE_DECOR = {"companion": "#e84a5a", "helper": "#9a6a3e", "explorer": "#3f9a6a"}


def draw_pet(sc, p, fam, role, evo):
    b, l, a = fam["body"], fam["belly"], fam["accent"]
    plan = fam["plan"]
    big = 1.18 if evo else 1.0
    x = 16 + p["lunge"] - p["wind"]
    flying = plan in ("flyer", "ray", "moth")
    y = (18 if flying else 22) + p["bob"] + (0 if p["step"] is None else (-1 if p["step"] % 2 else 0))
    if p["down"]:
        sc.ell(16, 27, 8 * big, 3, b)
        sc.ell(16, 26, 5, 1.2, b, LIGHT)
        eyes(sc, 14, 26, p, gap=4)
        return
    r = 6.5 * big
    w = p["wave"]
    # appendages behind
    if plan in ("flyer", "moth"):
        wing = a if plan == "flyer" else l
        for side in (-1, 1):
            sc.poly([(x, y - 2), (x + side * (9 + 2 * big), y - 8 + w * 4), (x + side * (8 + big), y + 2)], wing,
                    SHADE if side < 0 else AUTO)
            if evo:
                sc.poly([(x, y), (x + side * 7, y + 5 - w), (x + side * 3, y + 4)], wing)
    if plan == "ray":
        sc.poly([(x - 12 * big, y + 1 - w * 2), (x, y - 5), (x + 12 * big, y + 1 - w * 2), (x, y + 4)], b)
        sc.line(x - 2, y + 3, x - 9, y + 7 + w, a)
    if plan in ("seal", "lizard", "fox", "pup"):
        tail_col = a if plan in ("seal", "fox") else b
        sc.line(x - 5, y + 1, x - 10, y - 2 - w, tail_col, th=2)
        if plan == "fox":
            sc.ell(x - 10, y - 3 - w, 2.5 * big, 2.5 * big, a, SHINE)
        if plan == "seal":
            sc.poly([(x - 10, y - 4 - w), (x - 13, y - 1 - w), (x - 9, y)], a)
    # legs
    if plan in ("lizard", "cub", "pup", "fox", "turtle"):
        for i, lx in enumerate((x - 4, x - 1, x + 2, x + 5)):
            ph = 0 if p["step"] is None else ((p["step"] + i) % 2)
            sc.line(lx, y + 3, lx, y + 6 - ph, mul(hexrgb(b), 0.85 if i % 2 == 0 else 1.0), th=2)
    elif plan in ("seal", "sprout"):
        sc.ell(x - 4, y + 5, 2, 1.3, b, SHADE)
        sc.ell(x + 4, y + 5, 2, 1.3, b)
    # body
    if plan == "turtle":
        sc.ell(x, y, r + 1, r * 0.75, a)
        sc.ell(x - 1, y - 2, r * 0.6, r * 0.35, a, LIGHT)
        for dx in (-3, 1, 4):
            sc.px(x + dx, y - 1, mul(hexrgb(a), 0.7), FLAT)
        hx, hy = x + r + 1, y - 1
        sc.ell(hx, hy, 3.5 * big, 3 * big, b)
    else:
        sc.ell(x, y, r, r * (0.9 if plan != "ray" else 0.6) - p["sq"] * 0.5, b)
        sc.ell(x - 2, y - r * 0.55, r * 0.45, 1.2, b, LIGHT)
        sc.ell(x + 1, y + r * 0.45, r * 0.55, r * 0.3, l)
        hx, hy = x + 2, y - 1
    # features on top
    if plan == "seal":
        sc.poly([(x - 2, y - r + 1), (x + 1, y - r - 3 - big), (x + 3, y - r + 1)], a)
    elif plan == "lizard":
        for k in (-3, 0, 3):
            sc.ell(x + k, y - r - 0.5 - (k == 0) * 1.5 - w * 0.5, 1.2, 1.8 * big, a, SHINE)
    elif plan == "sprout":
        sc.line(x, y - r, x, y - r - 3, "#4a8a3a")
        sc.ell(x - 2, y - r - 3, 2, 1, "#8ad06a")
        sc.ell(x + 2, y - r - 4 + w, 2, 1, "#8ad06a")
        if evo:
            sc.ell(x, y - r - 5, 1.5, 1.5, a, SHINE)
    elif plan == "cub":
        for side in (-1, 1):
            sc.ell(x + side * 4, y - r + 1, 1.8, 1.8, b)
        sc.ell(x + 2, y - r + 2, 1.2, 1.2, (250, 250, 255), SHINE)
    elif plan == "moth":
        sc.line(x + 1, y - r, x - 2, y - r - 4, mul(hexrgb(b), 0.6))
        sc.line(x + 3, y - r, x + 5, y - r - 4, mul(hexrgb(b), 0.6))
        sc.px(x - 2, y - r - 4, a, SHINE)
        sc.px(x + 5, y - r - 4, a, SHINE)
        sc.ell(x, y - r + 1, r * 0.7, 1.5, (250, 250, 255))
    elif plan == "pup":
        sc.poly([(x - 3, y - r + 2), (x - 1, y - r + 1), (x - 4, y - r - 3)], b)
        sc.poly([(x + 3, y - r + 1), (x + 5, y - r + 2), (x + 5, y - r - 3)], b)
        if p["open"]:
            sc.ell(x + 3, y + 3, 3, 1.5, (90, 20, 40), FLAT)
        for k in (1, 4):
            sc.px(x + k, y + 2, (250, 245, 230), FLAT)
    elif plan == "fox":
        sc.poly([(x - 4, y - r + 2), (x - 1, y - r + 1), (x - 3, y - r - 4)], b)
        sc.poly([(x + 2, y - r + 1), (x + 5, y - r + 2), (x + 4, y - r - 4)], b)
        sc.px(x + 1, y - r - 2, a, SHINE)
    elif plan == "flyer":
        sc.poly([(x - 1, y - r + 1), (x + 1, y - r - 2 - big), (x + 2, y - r + 1)], a)
    elif plan == "ray":
        sc.px(x - 1, y - 2, a, SHINE)
    # face
    eyes(sc, hx - 1 if plan != "turtle" else hx - 1, hy - 1, p, gap=3 if plan == "turtle" else 4)
    blush = mix(hexrgb(b), (240, 110, 130), 0.5)
    if not p["hit"] and plan != "turtle":
        sc.px(hx - 2, hy + 1, blush, FLAT)
        sc.px(hx + 4, hy + 1, blush, FLAT)
    # role decoration
    dc = ROLE_DECOR[role]
    if role == "companion":
        sc.line(x - 2, y + 2, x + 4, y + 2, dc, FLAT)
        sc.px(x + 1, y + 3, "#f0c048", SHINE)
    elif role == "helper":
        sc.rect(x - 5, y, x - 3, y + 2, dc)
        sc.line(x - 4, y - 1, x + 2, y + 2, mul(hexrgb(dc), 0.7), FLAT)
    else:
        sc.line(x - 1, y + 1, x + 5, y + 1, dc)
        sc.line(x - 1, y + 1, x - 3, y + 4 - w, dc, SHADE)
    if evo:
        sc.px(x - r + 1, y - r + 2, (255, 255, 230), SHINE)
        sc.px(x + r, y - 2, (255, 255, 230), SHINE)


def build():
    content = json.loads((GAME / "data" / "content.json").read_text())
    all_monsters = {**MONSTERS, **EXPANSION_MONSTERS, **EXPANSION_RARES}
    all_bosses = {**BOSSES, **EXPANSION_BOSSES}
    mon, mon_atlas = pack(render_rows(all_monsters, 32, 1.0, (16, 29)), 32, "monsters")
    boss, boss_atlas = pack(render_rows(all_bosses, 48, 1.5, (24, 45)), 48, "bosses")
    pet_strips = {}
    for sid, sp in content["PET_SPECIES"].items():
        fam = PET_FAMILIES[sp["familyId"]]
        strip = np.zeros((24, 24 * len(FRAMES), 4), np.uint8)
        for i, f in enumerate(FRAMES):
            cv = Canvas(24, 24)
            sc = SC(cv, 0.75, 0, 0)
            draw_pet(sc, pose_of(f), fam, sp["role"], sp["evolved"])
            strip[:, i * 24:(i + 1) * 24] = cv.render()
        pet_strips[sid] = strip
    pets, pet_atlas = pack(pet_strips, 24, "pets", per_line=3)
    meta = {
        "frames": FRAMES, "anims": ANIMS,
        "monsters": {"sheet": "res://assets/gen/creatures/monsters.png", "size": 32, "origin": [16, 30], "rows": mon},
        "bosses": {"sheet": "res://assets/gen/creatures/bosses.png", "size": 48, "origin": [24, 46], "rows": boss},
        "pets": {"sheet": "res://assets/gen/creatures/pets.png", "size": 24, "origin": [12, 21], "rows": pets},
    }
    save_json(meta, OUT / "creatures" / "creatures.json")
    k = 3
    for name, atlas, bg in (("monsters", mon_atlas, (70, 110, 90, 255)), ("bosses", boss_atlas, (70, 90, 120, 255)),
                            ("pets", pet_atlas, (196, 160, 112, 255))):
        img = Image.fromarray(atlas).resize((atlas.shape[1] * k, atlas.shape[0] * k), Image.NEAREST)
        out = Image.new("RGBA", img.size, bg)
        out.alpha_composite(img)
        out.save(PREVIEW / f"creatures_{name}.png")
    return meta


if __name__ == "__main__":
    m = build()
    print({k: len(v["rows"]) for k, v in m.items() if isinstance(v, dict) and "rows" in v})
