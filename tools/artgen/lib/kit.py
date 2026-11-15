"""Voxel furniture and room kit shared by facility, port and site generators.

Conventions: the floor occupies z = 0 and its top surface is z = 1 (the deck
surface). Back walls stand on the x = 0 and y = 0 edges; +x and +y face the
viewer. All sizes are in voxels (8 per cell).
"""
from __future__ import annotations

import math

from .vox import EMIT, GLOSS, NOOUTLINE, NOSHADOW, SEAM, SEAM_L, SEAM_R, SEAM_SIDE, Vol, hexrgb, mix, mul

F = 1

P = {k: hexrgb(v) for k, v in {
    "wood": "#c78a4c", "wood_l": "#e2ac68", "wood_d": "#8e5531", "wood_dd": "#5e3620",
    "plank": "#d6a060", "plank_d": "#b88042", "cream": "#f1e3c0", "paper": "#f4ecd2",
    "white": "#f6f4ee", "sheet": "#eef0f2", "red": "#c8463c", "red_d": "#8e2a2e", "red_l": "#e86a52",
    "navy": "#2f3f78", "navy_d": "#1f2a52", "blue": "#3f7fd0", "teal": "#2f9a96", "mint": "#9fdcc4",
    "green": "#4fa04a", "green_d": "#2f6a34", "leaf": "#5cbf4a", "yellow": "#f3c84a", "gold": "#f0c04e",
    "gold_d": "#b88a2e", "iron": "#59606c", "iron_d": "#3b404a", "steel": "#9aa6b4", "stone": "#9a958c",
    "stone_d": "#6f6a64", "brick": "#b4553e", "brick_d": "#8a3a2e", "purple": "#7b4fb0", "purple_d": "#4f3078",
    "pink": "#e88aa8", "orange": "#e8823a", "straw": "#e6c869", "straw_d": "#c8a54a", "glass": "#bfe8ff",
    "water": "#4fb6e8", "water_d": "#2f86c0", "fire": "#ffb03a", "fire_l": "#fff07a", "lamp": "#ffe39a",
    "black": "#2a2228", "skin": "#f2c29a", "sand": "#e8cf8f", "rope": "#8a6a42", "canvas": "#e9dfc4",
    "brass": "#d8a838", "parch": "#efd9a0", "ink": "#3a3048", "lilac": "#b49ae0",
}.items()}


# -- floors -----------------------------------------------------------------

def floor_planks(v, W, H, c1=None, c2=None, along="x"):
    """Quiet board-sized colour clusters, with joints rather than pixel grain.

    Furniture and inhabitants carry the small details. A floor should read as
    one warm material at normal play zoom, not compete with their silhouettes.
    """
    c1 = c1 or P["plank"]
    c2 = c2 or P["plank_d"]
    for x in range(W):
        for y in range(H):
            a, b = (y, x) if along == "x" else (x, y)
            board = a // 4
            seg = (b + 7 * board) // 17
            c = mix(c1, c2, 0.12 + ((board * 7 + seg * 3) % 4) * 0.055)
            joint = (b + 7 * board) % 17 == 0
            if joint:
                c = mul(c, 0.91)
            v.put(x, y, 0, c, SEAM if a % 4 == 3 else 0)


def floor_checker(v, W, H, c1, c2, n=4, border=None):
    for x in range(W):
        for y in range(H):
            c = c1 if ((x // n) + (y // n)) % 2 == 0 else c2
            if border is not None and (x == W - 1 or y == H - 1 or x == 0 or y == 0):
                c = border
            v.put(x, y, 0, c)


def floor_tiles(v, W, H, c, grout, n=4):
    for x in range(W):
        for y in range(H):
            g = (x % n == n - 1) or (y % n == n - 1)
            v.put(x, y, 0, mul(grout if g else c, 1.0 if (x // n + y // n) % 3 else 0.95))


def floor_carpet(v, W, H, c, border, inset=1, motif=None):
    for x in range(W):
        for y in range(H):
            edge = x < inset or y < inset or x >= W - inset or y >= H - inset
            col = border if edge else c
            if motif and not edge and (x + y) % motif == 0 and (x - y) % motif == 0:
                col = border
            v.put(x, y, 0, col)


def floor_straw(v, W, H):
    for x in range(W):
        for y in range(H):
            k = (x * 7 + y * 13 + (x * y) % 5) % 6
            v.put(x, y, 0, mix(P["straw"], P["straw_d"], k / 7))


def rug(v, x0, y0, x1, y1, c, border, z=F):
    for x in range(x0, x1):
        for y in range(y0, y1):
            e = x in (x0, x1 - 1) or y in (y0, y1 - 1)
            v.put(x, y, z, border if e else c, NOSHADOW)


def edge_trim(v, W, H, c):
    """Low front-edge sill so the room reads as a unit on the deck."""
    for x in range(W):
        v.put(x, H - 1, F, c, NOSHADOW)
    for y in range(H):
        v.put(W - 1, y, F, c, NOSHADOW)


# -- walls ------------------------------------------------------------------

def back_walls(v, W, H, wall, wains=None, trim=None, height=13, sides="xy", stripes=None):
    wains = wains or P["wood_d"]
    trim = trim or P["wood_l"]
    for side in sides:
        rng = range(W) if side == "y" else range(H)
        for i in rng:
            for z in range(F, F + height):
                if z < F + 4:
                    panel = i % 6
                    c = mul(wains, 0.88) if panel == 0 else wains
                    fl = SEAM_L if side == "y" and panel == 0 else (SEAM_R if side == "x" and panel == 0 else 0)
                elif z == F + 4:
                    c, fl = trim, 0
                else:
                    c = wall
                    if stripes and (i // 2) % 2 == 0:
                        c = stripes
                    # A quiet plaster field above the framed wooden dado.
                    if z == F + height - 1:
                        c = mix(wall, trim, 0.25)
                    fl = 0
                if side == "y":
                    v.put(i, 0, z, c, fl)
                else:
                    v.put(0, i, z, c, fl)
            if side == "y":
                v.put(i, 0, F + height, trim, GLOSS)
            else:
                v.put(0, i, F + height, trim, GLOSS)
    if "x" in sides and "y" in sides:
        v.box(0, 0, F, 1, 1, F + height + 1, trim)
    # front posts close the wall ends
    if "y" in sides:
        v.box(W - 1, 0, F, W, 1, F + height + 1, trim)
        v.box(0, 0, F + height - 1, W, 1, F + height, mul(trim, 0.86))
    if "x" in sides:
        v.box(0, H - 1, F, 1, H, F + height + 1, trim)
        v.box(0, 0, F + height - 1, 1, H, F + height, mul(trim, 0.86))


def on_wall(v, side, pos, z, w, h, col_fn, depth=1, flags=0):
    """Paint/attach a rectangle on a back wall. side 'x' is the x=0 wall
    (runs along y), 'y' is the y=0 wall (runs along x). depth > 0 protrudes."""
    for i in range(w):
        for j in range(h):
            c = col_fn(i, j) if callable(col_fn) else col_fn
            if c is None:
                continue
            for d in range(depth):
                if side == "x":
                    v.put(d, pos + i, z + j, c, flags)
                else:
                    v.put(pos + i, d, z + j, c, flags)


def window(v, side, pos, z=F + 6, w=4, h=5, frame=None, lit=True, curtain=None):
    frame = frame or P["wood_l"]

    def fn(i, j):
        if i in (0, w - 1) or j in (0, h - 1):
            return frame
        if curtain and i == 1:
            return curtain
        return P["lamp"] if lit else P["glass"]
    on_wall(v, side, pos, z, w, h, fn, depth=1, flags=0)
    # glass emits; re-flag inner cells
    for i in range(1, w - 1):
        for j in range(1, h - 1):
            if curtain and i == 1:
                continue
            x, y = (0, pos + i) if side == "x" else (pos + i, 0)
            v.put(x, y, z + j, P["lamp"] if lit else P["glass"], EMIT if lit else 0)


def painting(v, side, pos, z, w, h, colors):
    def fn(i, j):
        if i in (0, w - 1) or j in (0, h - 1):
            return P["gold"]
        return colors[(i + j * 2) % len(colors)]
    on_wall(v, side, pos, z, w, h, fn, depth=1)
    # protrude 1 voxel
    for i in range(w):
        for j in range(h):
            x, y = (1, pos + i) if side == "x" else (pos + i, 1)
            v.put(x, y, z + j, fn(i, j))


def wall_lamp(v, side, pos, z, lit=True):
    x, y = (1, pos) if side == "x" else (pos, 1)
    v.put(x, y, z - 1, P["iron"])
    v.put(x, y, z, P["lamp"] if lit else P["cream"], (EMIT | NOSHADOW) if lit else NOSHADOW)
    v.put(x, y, z + 1, P["iron"])


def shelf(v, side, pos, length, z, items=None, depth=2):
    items = items or [P["red"], P["blue"], P["green"], P["yellow"], P["purple"], P["cream"]]
    for i in range(length):
        for d in range(1, depth + 1):
            x, y = (d, pos + i) if side == "x" else (pos + i, d)
            v.put(x, y, z, P["wood"], 0)
        x, y = (1, pos + i) if side == "x" else (pos + i, 1)
        it = items[(i * 3 + z) % len(items)]
        if it is not None and i % 2 == 0:
            v.put(x, y, z + 1, it)
            if (i * 5 + z) % 3 == 0:
                v.put(x, y, z + 2, it)


def bookshelf(v, side, pos, length, height=11, depth=2):
    books = [P["red"], P["navy"], P["green"], P["gold_d"], P["purple"], P["red_d"], P["teal"], P["cream"]]
    for i in range(length):
        for z in range(F, F + height):
            for d in range(1, depth + 1):
                x, y = (d, pos + i) if side == "x" else (pos + i, d)
                shelf_row = (z - F) % 4 == 0 or z == F + height - 1
                edge = i in (0, length - 1)
                if shelf_row or edge or d == 1 and False:
                    v.put(x, y, z, P["wood_d"])
                elif d == depth:
                    v.put(x, y, z, books[(i * 3 + (z - F) // 4 * 5) % len(books)])


# -- furniture --------------------------------------------------------------

def table(v, x, y, w, d, h=5, top=None, leg=None, cloth=None):
    top = top or P["wood"]
    leg = leg or P["wood_d"]
    for (lx, ly) in ((x, y), (x + w - 1, y), (x, y + d - 1), (x + w - 1, y + d - 1)):
        v.box(lx, ly, F, lx + 1, ly + 1, F + h - 1, leg)
    v.box(x, y, F + h - 1, x + w, y + d, F + h, cloth or top, GLOSS if cloth is None else 0)
    if cloth:
        v.box(x, y + d - 1, F + h - 3, x + w, y + d, F + h - 1, cloth)
        v.box(x + w - 1, y, F + h - 3, x + w, y + d, F + h - 1, cloth)
    return F + h


def stool(v, x, y, c=None):
    c = c or P["wood"]
    v.box(x, y, F, x + 2, y + 2, F + 2, P["wood_d"])
    v.box(x, y, F + 2, x + 2, y + 2, F + 3, c, GLOSS)


def chair(v, x, y, c=None, back="x"):
    c = c or P["wood"]
    v.box(x, y, F, x + 2, y + 2, F + 3, P["wood_d"])
    v.box(x, y, F + 3, x + 2, y + 2, F + 4, c)
    if back == "x":
        v.box(x, y, F + 4, x + 1, y + 2, F + 8, c)
    else:
        v.box(x, y, F + 4, x + 2, y + 1, F + 8, c)


def bench(v, x, y, length, along="x", c=None):
    c = c or P["wood"]
    if along == "x":
        v.box(x, y, F, x + length, y + 2, F + 2, P["wood_d"])
        v.box(x, y, F + 2, x + length, y + 2, F + 3, c, GLOSS)
    else:
        v.box(x, y, F, x + 2, y + length, F + 2, P["wood_d"])
        v.box(x, y, F + 2, x + 2, y + length, F + 3, c, GLOSS)


def bed(v, x, y, along="x", length=8, width=4, sheet=None, blanket=None, frame=None, z0=F, pillow=True):
    sheet = sheet or P["sheet"]
    blanket = blanket or P["red"]
    frame = frame or P["wood_d"]
    L, Wd = (length, width) if along == "x" else (width, length)
    v.box(x, y, z0, x + L, y + Wd, z0 + 2, frame)
    v.box(x, y, z0 + 2, x + L, y + Wd, z0 + 3, sheet)
    if along == "x":
        v.box(x + 3, y, z0 + 3, x + L, y + Wd, z0 + 4, blanket)
        if pillow:
            v.box(x, y + 1, z0 + 3, x + 2, y + Wd - 1, z0 + 4, P["white"])
        v.box(x, y, z0, x + 1, y + Wd, z0 + 6, frame)
    else:
        v.box(x, y + 3, z0 + 3, x + Wd, y + L, z0 + 4, blanket)
        if pillow:
            v.box(x + 1, y, z0 + 3, x + Wd - 1, y + 2, z0 + 4, P["white"])
        v.box(x, y, z0, x + Wd, y + 1, z0 + 6, frame)


def barrel(v, cx, cy, h=6, r=1.9, c=None, z0=F, lid=None):
    c = c or P["wood"]
    v.cyl(cx, cy, z0, z0 + h, r, c, jitter=0.04, seed=int(cx * 7 + cy))
    v.cyl(cx, cy, z0 + 1, z0 + 2, r + 0.15, P["iron_d"])
    v.cyl(cx, cy, z0 + h - 2, z0 + h - 1, r + 0.15, P["iron_d"])
    v.cyl(cx, cy, z0 + h - 1, z0 + h, r - 0.4, lid or mul(c, 1.12))


def crate(v, x, y, s=4, h=4, c=None, z0=F):
    c = c or P["wood"]
    v.box(x, y, z0, x + s, y + s, z0 + h, c, SEAM_SIDE)
    v.box(x, y, z0 + h - 1, x + s, y + s, z0 + h, mul(c, 1.1), SEAM)
    for (a, b) in ((x, y + s - 1), (x + s - 1, y)):
        pass
    v.box(x, y + s - 1, z0, x + 1, y + s, z0 + h, P["wood_d"])
    v.box(x + s - 1, y, z0, x + s, y + 1, z0 + h, P["wood_d"])
    v.box(x + s - 1, y + s - 1, z0, x + s, y + s, z0 + h, P["wood_d"])
    return z0 + h


def sack(v, x, y, c=None):
    c = c or P["canvas"]
    v.box(x, y, F, x + 3, y + 3, F + 3, c)
    v.box(x + 1, y + 1, F + 3, x + 2, y + 2, F + 4, P["rope"])


def chest(v, x, y, w=4, d=3, c=None, band=None, open_=False, loot=None):
    c = c or P["wood_d"]
    band = band or P["gold"]
    v.box(x, y, F, x + w, y + d, F + 3, c)
    v.box(x, y, F + 3, x + w, y + d, F + 4, mul(c, 1.15), GLOSS)
    v.box(x, y + d - 1, F, x + w, y + d, F + 4, band)
    v.box(x + w // 2, y + d, F + 2, x + w // 2 + 1, y + d + 1, F + 3, P["gold"])
    if open_ and loot:
        v.box(x, y, F + 4, x + w, y + 1, F + 7, c)
        v.box(x + 1, y + 1, F + 3, x + w - 1, y + d - 1, F + 4, loot, EMIT)


def lamp_post(v, x, y, h=12, lit=True):
    v.box(x, y, F, x + 1, y + 1, F + h, P["iron"])
    v.box(x - 1, y - 1, F, x + 2, y + 2, F + 1, P["iron_d"])
    v.box(x - 1, y - 1, F + h, x + 2, y + 2, F + h + 3, P["lamp"] if lit else P["cream"],
          (EMIT | NOSHADOW) if lit else 0)
    v.box(x - 1, y - 1, F + h + 3, x + 2, y + 2, F + h + 4, P["iron_d"])
    return (x + 0.5, y + 0.5, F + h + 1.5)


def candle(v, x, y, z, lit=True):
    v.put(x, y, z, P["cream"])
    if lit:
        v.put(x, y, z + 1, P["fire_l"], EMIT | NOSHADOW)


def plant(v, x, y, pot=None, leaf=None, h=6):
    pot = pot or P["brick"]
    leaf = leaf or P["leaf"]
    v.box(x, y, F, x + 3, y + 3, F + 3, pot)
    v.box(x, y, F + 3, x + 3, y + 3, F + 4, mul(pot, 1.15))
    for dz in range(h):
        for (dx, dy) in ((1, 1), (0, 1), (2, 1), (1, 0), (1, 2)):
            if dz < 2 and (dx, dy) != (1, 1):
                continue
            if (dx + dy + dz) % 2 == 0 or (dx, dy) == (1, 1):
                v.put(x + dx, y + dy, F + 4 + dz, mul(leaf, 0.85 + 0.05 * (dz % 3)))
    v.put(x + 1, y + 1, F + 4 + h, mul(leaf, 1.15))


def palm(v, x, y, h=10, lean=(1, 0)):
    """Coconut palm: a curved, ring-banded trunk leaning to one side, a crown
    of eight arched fronds with drooping leaflets, and a coconut cluster."""
    lx, ly = lean
    px, py = x, y
    for z in range(h):
        f = z / max(1, h - 1)
        off = 4.0 * f ** 1.8
        ix, iy = int(round(x + lx * off)), int(round(y + ly * off))
        band = z % 3 == 2
        v.box(ix, iy, F + z, ix + 2, iy + 2, F + z + 1, P["wood"] if band else P["wood_d"], SEAM_SIDE)
        if z == 0:  # slight root flare
            v.put(ix - 1, iy, F, P["wood_dd"])
            v.put(ix, iy + 2, F, P["wood_dd"])
        px, py = ix, iy
    tz = F + h
    v.box(px, py, tz, px + 2, py + 2, tz + 2, P["green_d"])
    for (cx, cy) in ((px - 1, py + 1), (px + 1, py - 1), (px + 2, py + 1)):
        v.put(cx, cy, tz - 1, P["wood_dd"])
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
    for i, (dx, dy) in enumerate(dirs):
        diag = dx != 0 and dy != 0
        length = 5 if diag else 7
        for d in range(1, length + 1):
            z = tz + 1 + int(round(1.25 * d - 0.3 * d * d))
            fx = px + (1 if dx > 0 else 0) + dx * d
            fy = py + (1 if dy > 0 else 0) + dy * d
            tip = d >= length - 1
            rib = P["green_d"] if tip else (P["leaf"] if (d + i) % 2 else P["green"])
            v.put(fx, fy, z, rib)
            if 2 <= d <= length - 1:
                for (sx, sy) in ((-dy, dx), (dy, -dx)):
                    v.put(fx + sx, fy + sy, z - 1, P["green"] if d % 2 else P["leaf"])
                    if d >= 3 and not diag:
                        v.put(fx + sx, fy + sy, z - 2, P["green_d"], NOSHADOW)


def rope_fence(v, x0, y0, x1, y1, post=None):
    post = post or P["wood_d"]
    for (px, py) in ((x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1)):
        v.box(px, py, F, px + 1, py + 1, F + 5, post)
        v.put(px, py, F + 5, P["gold"])
    for x in range(x0, x1):
        v.put(x, y1 - 1, F + 3, P["rope"], NOSHADOW)
    for y in range(y0, y1):
        v.put(x1 - 1, y, F + 3, P["rope"], NOSHADOW)


def fence(v, x0, y0, x1, y1, c=None, h=4, sides="xy"):
    """Picket fence on the front edges (+x, +y) and optionally back edges."""
    c = c or P["wood"]
    for x in range(x0, x1):
        for y in (y1 - 1,) + ((y0,) if "b" in sides else ()):
            if x % 2 == 0:
                v.box(x, y, F, x + 1, y + 1, F + h, c)
            v.put(x, y, F + h - 1, mul(c, 1.1))
    for y in range(y0, y1):
        for x in (x1 - 1,) + ((x0,) if "b" in sides else ()):
            if y % 2 == 0:
                v.box(x, y, F, x + 1, y + 1, F + h, c)
            v.put(x, y, F + h - 1, mul(c, 1.1))


def disc(v, cx, cy, r, z, c_fn, flags=0):
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                c = c_fn(x, y, d) if callable(c_fn) else c_fn
                if c is not None:
                    v.put(x, y, z, c, flags)


def flag_pole(v, x, y, h, cloth, length=6, height=4):
    v.box(x, y, F, x + 1, y + 1, F + h, P["wood_d"])
    v.put(x, y, F + h, P["gold"])
    for i in range(length):
        for j in range(height):
            zz = F + h - 1 - j - (1 if i > 3 and (i % 2) else 0)
            v.put(x, y + 1 + i, zz, cloth if (i + j) % 5 else mul(cloth, 0.85), NOSHADOW)


def dummy(v, x, y, c=None):
    c = c or P["canvas"]
    v.box(x + 1, y + 1, F, x + 2, y + 2, F + 6, P["wood_d"])
    v.box(x, y, F, x + 3, y + 3, F + 1, P["wood_d"])
    v.box(x, y, F + 6, x + 3, y + 3, F + 11, c)
    v.box(x - 1, y + 1, F + 9, x + 4, y + 2, F + 10, P["wood_d"])
    v.box(x, y, F + 11, x + 3, y + 3, F + 14, mix(c, P["straw"], 0.4))
    v.put(x + 2, y + 2, F + 8, P["red"])
    v.put(x + 2, y + 1, F + 8, P["red"])


def weapon_rack(v, side, pos, z=F, length=6):
    for i in range(length):
        x, y = (1, pos + i) if side == "x" else (pos + i, 1)
        v.put(x, y, z + 1, P["wood_d"])
        v.put(x, y, z + 7, P["wood_d"])
        if i % 2 == 1:
            for dz in range(2, 11):
                c = P["steel"] if dz > 6 else P["wood"]
                v.put(x + (1 if side == "x" else 0), y + (1 if side == "y" else 0), z + dz, c)


def target(v, x, y, facing="x"):
    v.box(x, y, F, x + 1, y + 1, F + 4, P["wood_d"])
    for a in range(-3, 4):
        for b in range(-3, 4):
            r = math.hypot(a, b)
            if r <= 3.5:
                c = [P["red"], P["white"], P["red"], P["white"]][min(3, int(r))]
                if facing == "x":
                    v.put(x, y + a, F + 7 + b, c)
                else:
                    v.put(x + a, y, F + 7 + b, c)


def stove(v, x, y, w=6, d=4, lit=True):
    v.box(x, y, F, x + w, y + d, F + 6, P["brick"], SEAM_SIDE)
    v.box(x, y, F + 6, x + w, y + d, F + 7, P["iron_d"])
    # fire mouth on the +y face
    v.box(x + 1, y + d - 1, F + 1, x + w - 1, y + d, F + 4, P["fire"] if lit else P["black"],
          (EMIT | NOSHADOW) if lit else 0)
    if lit:
        v.box(x + 2, y + d - 1, F + 2, x + w - 2, y + d, F + 3, P["fire_l"], EMIT | NOSHADOW)
    # pots
    v.cyl(x + 1.5, y + 1.5, F + 7, F + 10, 1.4, P["iron"])
    v.cyl(x + 4.5, y + 1.5, F + 7, F + 9, 1.4, P["brass"])
    # chimney
    v.box(x, y, F + 7, x + 2, y + 2, F + 18, P["brick_d"], SEAM_SIDE)


def counter(v, x, y, length, along="x", top=None, front=None, h=6):
    top = top or P["wood_l"]
    front = front or P["wood_d"]
    if along == "x":
        v.box(x, y, F, x + length, y + 3, F + h - 1, front, SEAM_L)
        v.box(x, y, F + h - 1, x + length, y + 3, F + h, top, GLOSS)
    else:
        v.box(x, y, F, x + 3, y + length, F + h - 1, front, SEAM_R)
        v.box(x, y, F + h - 1, x + 3, y + length, F + h, top, GLOSS)


def bottle(v, x, y, z, c):
    v.put(x, y, z, c)
    v.put(x, y, z + 1, c)
    v.put(x, y, z + 2, P["cream"])


def flask(v, x, y, z, c, lit=True):
    v.put(x, y, z, P["glass"])
    v.put(x, y, z + 1, c, EMIT if lit else 0)
    v.put(x, y, z + 2, P["glass"])


def tank(v, x, y, w, d, h, lit=True):
    v.box(x, y, F, x + w, y + d, F + 2, P["wood_d"])
    for xx in range(x, x + w):
        for yy in range(y, y + d):
            for zz in range(F + 2, F + 2 + h):
                edge = xx in (x, x + w - 1) and yy in (y, y + d - 1)
                if edge:
                    v.put(xx, yy, zz, P["iron"])
                else:
                    c = P["water"] if zz < F + 1 + h else P["glass"]
                    v.put(xx, yy, zz, mix(c, P["water_d"], (zz - F) / (h + 4)), (EMIT if lit else 0) | NOSHADOW)
    v.box(x, y, F + 2 + h, x + w, y + d, F + 3 + h, P["iron"])


def cauldron(v, cx, cy, lit=True, liquid=None):
    v.cyl(cx, cy, F, F + 4, 2.6, P["iron_d"])
    v.cyl(cx, cy, F + 3, F + 4, 1.8, liquid or P["green"], EMIT if lit else 0)


def anvil(v, x, y):
    v.box(x + 1, y, F, x + 3, y + 3, F + 3, P["wood_d"])
    v.box(x, y, F + 3, x + 5, y + 3, F + 5, P["iron"], GLOSS)
    v.box(x + 5, y + 1, F + 4, x + 6, y + 2, F + 5, P["iron"])


def piano(v, x, y):
    v.box(x, y, F, x + 8, y + 3, F + 9, P["black"])
    v.box(x, y + 3, F + 4, x + 8, y + 5, F + 5, P["white"], 0)
    for i in range(0, 8, 2):
        v.put(x + i, y + 3, F + 5, P["black"])
    v.box(x, y, F + 9, x + 8, y + 3, F + 10, P["wood_dd"], GLOSS)
    v.put(x + 2, y + 2, F + 10, P["gold"])
    v.put(x + 6, y + 2, F + 10, P["gold"])


def drum(v, cx, cy, c=None):
    v.cyl(cx, cy, F, F + 4, 1.8, c or P["red"])
    v.cyl(cx, cy, F + 4, F + 5, 1.8, P["cream"])
    v.cyl(cx, cy, F + 1, F + 2, 1.95, P["gold"])


def nest(v, cx, cy, eggs):
    v.cyl(cx, cy, F, F + 2, 3.0, P["straw_d"])
    v.cyl(cx, cy, F + 1, F + 2, 2.0, P["straw"])
    offs = [(-1, -1), (1, 0), (0, 1)]
    for (dx, dy), c in zip(offs, eggs):
        v.box(int(cx + dx - 0.5), int(cy + dy - 0.5), F + 2, int(cx + dx + 0.5), int(cy + dy + 0.5), F + 4, c, GLOSS)


def globe(v, cx, cy):
    x, y = int(cx), int(cy)
    v.box(x - 1, y - 1, F, x + 2, y + 2, F + 1, P["wood_d"])
    v.box(x, y, F + 1, x + 1, y + 1, F + 4, P["brass"])
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            for dz in range(-2, 3):
                if dx * dx + dy * dy + dz * dz <= 5:
                    land = (dx + 2 * dy + 3 * dz) % 4 == 0
                    v.put(x + dx, y + dy, F + 7 + dz, P["sand"] if land else P["blue"])
    for dz in range(-3, 4):
        v.put(x + 3, y, F + 7 + dz, P["brass"], GLOSS)


def telescope(v, x, y, z):
    v.box(x, y, z, x + 1, y + 1, z + 4, P["wood_d"])
    for i in range(6):
        v.put(x + 1 + i // 2, y + 1 + i // 2, z + 4 + i // 2, P["brass"], GLOSS)


def blackboard(v, side, pos, length, z=F + 5, h=6):
    def fn(i, j):
        if i in (0, length - 1) or j in (0, h - 1):
            return P["wood"]
        if (i * 3 + j * 5) % 11 == 0:
            return P["white"]
        return hexrgb("#2f5a48")
    on_wall(v, side, pos, z, length, h, fn, depth=1)


def banner(v, side, pos, z, c, w=3, h=6):
    def fn(i, j):
        if j == h - 1:
            return P["gold"]
        if j == 0 and i == 1:
            return None
        return c if not (i == 1 and j == h // 2) else P["gold"]
    for i in range(w):
        for j in range(h):
            col = fn(i, j)
            if col is None:
                continue
            x, y = (1, pos + i) if side == "x" else (pos + i, 1)
            v.put(x, y, z + j, col)


def sandbags(v, x0, y0, x1, y1, h=4):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(F, F + h):
                k = (x // 3 + y // 3 + z) % 2
                v.put(x, y, z, P["canvas"] if k else mix(P["canvas"], P["straw_d"], 0.4), SEAM_SIDE if z % 2 else 0)


def cannon(v, x, y, facing="x"):
    v.box(x, y, F, x + 5, y + 4, F + 2, P["wood_d"])
    v.cyl(x + 1, y + 0.2, F, F + 2, 1.0, P["wood_dd"])
    v.cyl(x + 1, y + 3.8, F, F + 2, 1.0, P["wood_dd"])
    for i in range(8):
        v.box(x + i, y + 1, F + 2, x + i + 1, y + 3, F + 4, P["iron_d"] if i < 7 else P["black"], GLOSS)
