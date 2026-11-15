"""Environment art: animated water + iso terrain tiles per region (TileMapLayer
atlases), voxel props, port buildings, foam/wake sprites and the location
type icons. The sea chart itself is built by gen_chart.py."""
from __future__ import annotations

import json
import math

import numpy as np
from PIL import Image, ImageDraw

from lib import kit
from lib.common import GAME, OUT, PREVIEW, Packer, record, save_json, save_png, trim
from lib.kit import F, P
from lib.vox import EMIT, GLOSS, NOSHADOW, SEAM, SEAM_SIDE, Vol, hexrgb, mix, mul, project, render

TW, TH = 32, 16
RNG = np.random.default_rng(11)


def diamond_mask():
    m = np.zeros((TH, TW), bool)
    for y in range(TH):
        k = y if y < 8 else 15 - y
        m[y, 14 - 2 * k:18 + 2 * k] = True
    return m


DIAMOND = diamond_mask()


def sides_mask(start=0, rows=9):
    """Cliff faces under a diamond, in a tile shifted down by 8px. `start`
    skips that many rows below the diamond edge (a low ledge only shows the
    lower part of a face) and `rows` is the face height."""
    left = np.zeros((TH, TW), bool)
    right = np.zeros((TH, TW), bool)
    for x in range(TW):
        if x < 16:
            top = (x + 1) // 2 + start
            left[top:min(TH, top + rows), x] = True
        else:
            top = (31 - x + 1) // 2 + start
            right[top:min(TH, top + rows), x] = True
    return left, right


SIDE_L, SIDE_R = sides_mask()


def tile_from(fn, mask=DIAMOND, seed=0):
    rng = np.random.default_rng(seed)
    a = np.zeros((TH, TW, 4), np.uint8)
    for y in range(TH):
        for x in range(TW):
            if mask[y, x]:
                c = fn(x, y, rng)
                if c is not None:
                    a[y, x, :3] = c
                    a[y, x, 3] = 255
    return a


def noisy(base, amt=0.07):
    def f(x, y, rng):
        k = 1 + (rng.random() - 0.5) * 2 * amt
        return mul(base, k)
    return f


def grass_tile(base, seed, flowers=None):
    rng = np.random.default_rng(seed)
    dark = mix(mul(base, 0.86), (40, 60, 90), 0.06)
    light = mix(base, (255, 250, 200), 0.12)
    # Quiet turf carries the large colour shape. Three clustered blades,
    # rather than independent pixel noise, read as vegetation at x1 zoom.
    a = tile_from(lambda x, y, r: base, seed=seed)
    for _ in range(3):
        x, y = rng.integers(2, 30), rng.integers(2, 14)
        if DIAMOND[y, x] and DIAMOND[y - 1, x]:
            a[y, x, :3] = dark
            a[y - 1, x, :3] = light
            if x < 30 and DIAMOND[y, x + 1]:
                a[y, x + 1, :3] = light
    if flowers:
        for _ in range(2):
            x, y = rng.integers(6, 26), rng.integers(4, 12)
            if DIAMOND[y, x]:
                a[y, x, :3] = flowers[rng.integers(0, len(flowers))]
    return a


def speck_tile(base, seed, specks=8, dark=0.84, light=1.1):
    rng = np.random.default_rng(seed)
    a = tile_from(lambda x, y, r: base, seed=seed)
    for _ in range(max(1, specks // 4)):
        x, y = rng.integers(1, 31), rng.integers(1, 15)
        if DIAMOND[y, x]:
            c = mul(base, (1 + dark) / 2 if rng.random() < 0.6 else (1 + light) / 2)
            a[y, x, :3] = c
            if x < 30 and DIAMOND[y, x + 1]:
                a[y, x + 1, :3] = c
    return a


def paver_tile(base, grout, seed):
    def f(x, y, rng):
        u = (x + 2 * y) // 8
        v = (2 * y - x + 32) // 8
        edge = (x + 2 * y) % 8 in (0,) or (2 * y - x + 32) % 8 in (0,)
        if edge:
            return grout
        k = 1 + ((u * 7 + v * 13) % 5 - 2) * 0.03
        return mul(base, k)
    return tile_from(f, seed=seed)


def plank_tile(base, seed):
    def f(x, y, rng):
        v = (2 * y - x + 32)
        if v % 6 == 0:
            return mul(base, 0.7)
        k = 1 + (((v // 6) * 5) % 3 - 1) * 0.05
        if (x * 3 + y * 7) % 23 == 0:
            return mul(base, 0.8)
        return mul(base, k)
    return tile_from(f, seed=seed)


def side_tile(top, kind, seed, start=0, rows=9, wet_from=7):
    """Cliff faces in the style `kind`. The defaults give the full 9px face
    of raised ground; start=4, rows=5 gives the face of a low beach ledge."""
    rng = np.random.default_rng(seed)
    a = np.zeros((TH, TW, 4), np.uint8)
    mask_l, mask_r = (SIDE_L, SIDE_R) if (start, rows) == (0, 9) else sides_mask(start, rows)
    for y in range(TH):
        for x in range(TW):
            L, R = mask_l[y, x], mask_r[y, x]
            if not (L or R):
                continue
            base = mul(top, 0.78 if L else 0.6)
            depth = y - ((x + 1) // 2 if x < 16 else (32 - x) // 2) - start
            if kind == "rock":
                # Broad strata and a few joined cracks; no gravel noise.
                c = mul(base, 0.96 if depth < 4 else 0.88)
                if depth == 4 + (x // 11) % 2:
                    c = mul(c, 0.85)
            elif kind == "sand":
                c = mul(base, 1.02 if depth < 3 else 0.94)
            elif kind == "wood":
                post = (x % 8) in (3, 4)
                c = mul(P["wood_d"], 0.95 if L else 0.75) if post else (0, 0, 0)
                if not post:
                    if depth <= 1:
                        c = mul(top, 0.7 if L else 0.55)
                    else:
                        continue
            elif kind == "stone":
                row = depth // 3
                brick = ((x + (row % 2) * 4) % 8 == 0) or depth % 3 == 0
                c = mul(base, 0.82 if brick else 1.0)
            else:
                c = base
            if depth >= wet_from:
                c = mix(c, (30, 50, 80), 0.25)
            if depth == 0:
                c = mul(c, 1.15)
            a[y, x, :3] = c
            a[y, x, 3] = 255
    return a


def water_frames(sea, deep, shallow=False, seed=0, n=4):
    base = mix(hexrgb(sea), (222, 248, 238), 0.16) if shallow else hexrgb(sea)
    dk = hexrgb(deep)
    # Open sea is a calm colour plane. Glints, foam and whitecaps are
    # world-space particles, so the tile never stamps white chevrons over
    # the entire screen. Shallows retain soft animated caustic clusters.
    open_sea = sea == deep
    frames = []
    for f in range(n):
        a = np.zeros((TH, TW, 4), np.uint8)
        for y in range(TH):
            for x in range(TW):
                if not DIAMOND[y, x]:
                    continue
                u, v = tile_uv(x, y)
                wave = math.sin(u * math.tau + f * math.pi / 2) * math.sin(v * math.tau - f * math.pi / 2)
                c = base if open_sea else mix(base, dk, 0.055 if wave < -0.35 else 0.015)
                if shallow and wave > 0.72:
                    c = mix(c, (222, 248, 238), 0.075)
                a[y, x, :3] = c
                a[y, x, 3] = 255
        frames.append(a)
    return frames


# ------------------------------------------------- coast tile additions ----
# Natural coastlines (coast.gd) use two ground heights: raised land 8px above
# the water and low beach ledges 4px above it. Faces are drawn per side, so
# each side style also comes as a left-only and right-only tile, a 5px low
# variant and the top 4px "band" that is redrawn above low ground.

def tile_uv(x, y):
    """Ground coordinates (u along +gx, v along +gy, 0..1) of a tile pixel."""
    a = (x + 0.5 - 16) / 16
    b = (y + 0.5 - 8) / 8
    return (a + b) / 2 + 0.5, (b - a) / 2 + 0.5


def side_variant(tile, faces="LR", rows=None):
    """Keep only the left or right face of a side tile and/or the top `rows`
    pixels of each face."""
    a = tile.copy()
    for x in range(TW):
        left = x < 16
        if (faces == "L" and not left) or (faces == "R" and left):
            a[:, x] = 0
            continue
        if rows is not None:
            top = (x + 1) // 2 if left else (32 - x) // 2
            a[top + rows:, x] = 0
    return a


def water_frames2(base, dk, seed, n=4, blobs=0, blob_col=None, specks=None, crest_k=0.5):
    """Animated water like water_frames(), from RGB colours, with optional
    still shapes under the surface (reef heads, sand ripples)."""
    rng = np.random.default_rng(seed)
    crest = mix(base, (230, 250, 242), crest_k * 0.18)
    under = np.zeros((TH, TW), np.int8)
    for _ in range(blobs):
        bx, by, r = rng.uniform(5, 27), rng.uniform(3, 13), rng.uniform(1.6, 3.0)
        for y in range(TH):
            for x in range(TW):
                if ((x - bx) / (r * 1.6)) ** 2 + ((y - by) / r) ** 2 <= 1.0 and DIAMOND[y, x]:
                    under[y, x] = 1
    if specks:
        for _ in range(specks[0]):
            x, y = int(rng.integers(2, 30)), int(rng.integers(2, 14))
            if DIAMOND[y, x] and not under[y, x]:
                under[y, x] = 2
    frames = []
    for f in range(n):
        a = np.zeros((TH, TW, 4), np.uint8)
        for y in range(TH):
            for x in range(TW):
                if not DIAMOND[y, x]:
                    continue
                u, v = tile_uv(x, y)
                band = math.sin(u * math.tau + f * math.pi / 2) * math.sin(v * math.tau - f * math.pi / 2)
                c = mix(base, dk, 0.065) if band < -0.5 else base
                if under[y, x] == 1:
                    c = mix(c, blob_col, 0.42)
                    if y > 0 and not under[y - 1, x]:
                        c = mix(c, (255, 255, 255), 0.12)
                elif under[y, x] == 2:
                    c = mix(c, specks[1], 0.2)
                if band > 0.76:
                    c = mix(c, crest, 0.65)
                a[y, x, :3] = c
                a[y, x, 3] = 255
        frames.append(a)
    return frames


def _periodic_points(n, seed, variant, jit=0.3):
    """Jittered n x n grid in the unit square, periodic. Points on the outer
    ring are shared by every variant so variants tile seamlessly."""
    shared = np.random.default_rng(seed)
    own = np.random.default_rng(seed + 101 + variant)
    js, jo = shared.uniform(-jit, jit, (n, n, 2)), own.uniform(-jit, jit, (n, n, 2))
    ss, so = shared.uniform(0.84, 1.1, (n, n)), own.uniform(0.84, 1.1, (n, n))
    pts, shades = [], []
    for i in range(n):
        for j in range(n):
            ring = i in (0, n - 1) or j in (0, n - 1)
            jj = js[i, j] if ring or variant < 0 else jo[i, j]
            pts.append(((i + 0.5 + jj[0]) / n, (j + 0.5 + jj[1]) / n))
            shades.append(ss[i, j] if ring or variant < 0 else so[i, j])
    return pts, shades


def cobble_tile(base, mortar, variant, n=5, seed=40):
    """Irregular rounded cobbles (periodic Voronoi in ground space): tiles
    join without seams and variants differ only inside the tile."""
    pts, shades = _periodic_points(n, seed, variant)
    a = np.zeros((TH, TW, 4), np.uint8)
    for y in range(TH):
        for x in range(TW):
            if not DIAMOND[y, x]:
                continue
            u, v = tile_uv(x, y)
            best = [(9.0, -1, 0.0, 0.0), (9.0, -1, 0.0, 0.0)]
            for k, (px, py) in enumerate(pts):
                for ox in (-1, 0, 1):
                    for oy in (-1, 0, 1):
                        du, dv = u - (px + ox), v - (py + oy)
                        d = math.hypot(du, dv)
                        if d < best[0][0]:
                            best = [(d, k, du, dv), best[0]]
                        elif d < best[1][0]:
                            best[1] = (d, k, du, dv)
            (d1, k1, du, dv), (d2, _, _, _) = best
            edge = d2 - d1
            if edge < 0.05:
                c = mortar
            else:
                c = mul(base, shades[k1])
                if edge < 0.1:
                    c = mul(c, 1.12 if du + dv < 0 else 0.86)
            a[y, x, :3] = c
            a[y, x, 3] = 255
    return a


def slab_tile(base, joint, variant, seed=60, moss=None):
    """Quay slabs laid in a running bond: two courses per cell along +gy,
    one slab per cell along +gx with the odd course offset by half."""
    rng = np.random.default_rng(seed + variant)
    shared = np.random.default_rng(seed)
    odd_shade = shared.uniform(0.9, 1.08)
    even_shade = rng.uniform(0.88, 1.1)
    cracks = [(rng.uniform(0.15, 0.85), rng.uniform(0.05, 0.45)) for _ in range(variant)]
    a = np.zeros((TH, TW, 4), np.uint8)
    for y in range(TH):
        for x in range(TW):
            if not DIAMOND[y, x]:
                continue
            u, v = tile_uv(x, y)
            course = int(v * 2) % 2
            fu = (u + (0.5 if course else 0.0)) % 1.0
            fv = (v * 2) % 1.0
            if fv < 0.09 or fu < 0.035:
                c = joint
                if moss is not None and (x * 7 + y * 3 + variant) % 5 == 0:
                    c = mix(joint, moss, 0.5)
            else:
                c = mul(base, odd_shade if course else even_shade)
                c = mul(c, 1 + (rng.random() - 0.5) * 0.05)
                if fv < 0.17:
                    c = mul(c, 1.08)
                elif fv > 0.9:
                    c = mul(c, 0.93)
                for (cu, cv) in cracks:
                    if course == 0 and abs(u - cu - (v - cv) * 0.6) < 0.02 and abs(v - cv - 0.12) < 0.12:
                        c = mul(base, 0.72)
            a[y, x, :3] = c
            a[y, x, 3] = 255
    return a


def wet_sand_tile(sand, sea, seed):
    rng = np.random.default_rng(seed)
    base = mix(mul(sand, 0.84), sea, 0.12)
    a = np.zeros((TH, TW, 4), np.uint8)
    for y in range(TH):
        for x in range(TW):
            if not DIAMOND[y, x]:
                continue
            u, v = tile_uv(x, y)
            c = mul(base, 1 + (rng.random() - 0.5) * 0.05)
            if (u * 3 + v * 3 + math.sin(u * 9) * 0.15) % 1.0 < 0.1:
                c = mul(c, 0.94)
            if rng.random() < 0.03:
                c = mix(c, (255, 255, 255), 0.35)
            a[y, x, :3] = c
            a[y, x, 3] = 255
    return a


def pebble_tile(base, seed, n=26, light=1.18, dark=0.74):
    rng = np.random.default_rng(seed)
    a = tile_from(lambda x, y, r: mul(base, 1 + (r.random() - 0.5) * 0.1), seed=seed)
    for _ in range(n):
        x, y = int(rng.integers(1, 30)), int(rng.integers(1, 14))
        k = rng.uniform(0.85, 1.15)
        if DIAMOND[y, x] and DIAMOND[y, x + 1]:
            a[y, x, :3] = mul(base, light * k)
            a[y, x + 1, :3] = mul(base, k)
            if y + 1 < TH and DIAMOND[y + 1, x]:
                a[y + 1, x, :3] = mul(base, dark * k)
                if DIAMOND[y + 1, x + 1]:
                    a[y + 1, x + 1, :3] = mul(base, dark * k)
    return a


def patch_tile(base, patch, seed, n=5, r=(1.2, 2.6), cracks=0):
    """Ground with a few irregular patches of a second colour (rock showing
    through turf on cliff tops, litter under trees)."""
    rng = np.random.default_rng(seed)
    a = grass_tile(base, seed)
    for _ in range(n):
        bx, by, rr = rng.uniform(4, 28), rng.uniform(3, 13), rng.uniform(*r)
        for y in range(TH):
            for x in range(TW):
                if DIAMOND[y, x] and ((x - bx) / (rr * 1.7)) ** 2 + ((y - by) / rr) ** 2 <= 1.0 + rng.random() * 0.3:
                    c = mul(patch, 1 + (rng.random() - 0.5) * 0.12)
                    if y > 0 and ((x - bx) / (rr * 1.7)) ** 2 + ((y - 1 - by) / rr) ** 2 > 1.0:
                        c = mul(c, 1.15)
                    a[y, x, :3] = c
    for _ in range(cracks):
        x, y = int(rng.integers(6, 26)), int(rng.integers(4, 12))
        for i in range(int(rng.integers(2, 5))):
            if DIAMOND[y, x]:
                a[y, x, :3] = mul(patch, 0.62)
            x += 1
            y += int(rng.integers(0, 2))
            if y >= TH:
                break
    return a


def tuft_tile(sand, grass, seed, n=5):
    rng = np.random.default_rng(seed)
    a = speck_tile(sand, seed, specks=6)
    blade = mix(grass, (200, 190, 120), 0.3)
    for _ in range(n):
        x, y = int(rng.integers(5, 27)), int(rng.integers(4, 13))
        for dx in (-1, 0, 1):
            if DIAMOND[y, x + dx] and DIAMOND[y - 1, x + dx]:
                a[y, x + dx, :3] = mul(blade, 0.8)
                if dx == 0 or rng.random() < 0.5:
                    a[y - 1, x + dx, :3] = blade
    return a


GROUND2 = ["wetsand", "shingle", "cliff", "path", "cobble0", "cobble1", "cobble2", "slab0", "slab1", "slab2",
           "dune", "grass3", "meadow", "forest", "rubble"]
SIDE_SETS = {"high:LR": (0, 3), "high:L": (0, 4), "high:R": (5, 4), "low:LR": (0, 5), "low:L": (5, 5),
             "low:R": (10, 5), "band:LR": (0, 6), "band:L": (5, 6), "band:R": (10, 6)}
WATER_TILES = {"sea": (0, 0), "deep": (4, 0), "shallow": (0, 1), "reef": (4, 1), "lagoon": (8, 1)}


TERRAIN_COLS = 16
GROUND = ["grass0", "grass1", "grass2", "sand0", "sand1", "dirt", "stone0", "stone1", "plank", "quay", "moss",
          "floor0", "floor1", "lava", "crystal", "flowers"]
SIDES = ["rock", "sandside", "wood", "stone", "dark"]


def region_terrain(rid, pal):
    sea, deep, land, grass, acc = (hexrgb(pal[k]) for k in ("sea", "deep", "land", "grass", "accent"))
    atlas = np.zeros((TH * 8, TW * TERRAIN_COLS, 4), np.uint8)
    for i, fr in enumerate(water_frames(pal["sea"], pal["deep"], False, seed=sum(map(ord, rid)) * 31)):
        atlas[0:TH, i * TW:(i + 1) * TW] = fr
    for i, fr in enumerate(water_frames(pal["sea"], pal["deep"], True, seed=sum(map(ord, rid)) * 31 + 5)):
        atlas[TH:2 * TH, i * TW:(i + 1) * TW] = fr
    # deep-water variant for open ocean far from land
    for i, fr in enumerate(water_frames(pal["deep"], pal["deep"], False, seed=sum(map(ord, rid)) * 31 + 9)):
        atlas[0:TH, (4 + i) * TW:(5 + i) * TW] = fr
    sand = mix(land, (240, 220, 160), 0.35) if sum(land) < 450 else land
    stone = mix(land, (150, 150, 160), 0.55)
    tiles = {
        "grass0": grass_tile(grass, 1), "grass1": grass_tile(grass, 2), "grass2": grass_tile(mul(grass, 0.94), 3),
        "sand0": speck_tile(sand, 4), "sand1": speck_tile(mul(sand, 0.97), 5, specks=12),
        "dirt": speck_tile(mix(land, (130, 90, 60), 0.5), 6), "stone0": paver_tile(stone, mul(stone, 0.7), 7),
        "stone1": speck_tile(mul(stone, 0.92), 8, specks=10), "plank": plank_tile(P["plank"], 9),
        "quay": paver_tile(mix(stone, (200, 190, 170), 0.4), mul(stone, 0.65), 10),
        "moss": grass_tile(mix(grass, stone, 0.5), 11), "floor0": paver_tile(mul(stone, 0.75), mul(stone, 0.5), 12),
        "floor1": speck_tile(mul(stone, 0.7), 13, specks=12), "lava": speck_tile(mix(acc, (255, 120, 40), 0.5), 14, 14, 0.8, 1.2),
        "crystal": speck_tile(mix(grass, (220, 240, 255), 0.5), 15, 10, 0.85, 1.25),
        "flowers": grass_tile(grass, 16, flowers=[(240, 120, 160), (250, 240, 160), (255, 255, 255), acc]),
    }
    for i, k in enumerate(GROUND):
        atlas[2 * TH:3 * TH, i * TW:(i + 1) * TW] = tiles[k]
    sides = {"rock": side_tile(mix(land, stone, 0.5), "rock", 20), "sandside": side_tile(sand, "sand", 21),
             "wood": side_tile(P["plank"], "wood", 22), "stone": side_tile(stone, "stone", 23),
             "dark": side_tile(mul(stone, 0.6), "stone", 24)}
    for i, k in enumerate(SIDES):
        atlas[3 * TH:4 * TH, i * TW:(i + 1) * TW] = sides[k]
    coast_rows(atlas, rid, pal, sides, sand, stone, land, grass, acc, sea, deep)
    path = OUT / "env" / f"terrain_{rid}.png"
    save_png(atlas, path)
    return atlas


def coast_rows(atlas, rid, pal, sides, sand, stone, land, grass, acc, sea, deep):
    """Rows 1 (cols 4-11) and 4-7: reef and lagoon water, per-face, low and
    band side tiles, and the second ground row. Every generator here has its
    own seeded RNG, so rows 0-3 keep their pixels."""
    seed = sum(map(ord, rid)) * 31
    shallow = mix(sea, (255, 255, 255), 0.18)
    for i, fr in enumerate(water_frames2(shallow, deep, seed + 13, blobs=4, blob_col=mix(deep, acc, 0.25),
                                         specks=(5, mix(acc, (240, 120, 120), 0.5)), crest_k=0.55)):
        atlas[TH:2 * TH, (4 + i) * TW:(5 + i) * TW] = fr
    lagoon = mix(mix(sea, sand, 0.3), (255, 255, 255), 0.22)
    for i, fr in enumerate(water_frames2(lagoon, sea, seed + 17, specks=(9, mix(sand, (255, 255, 255), 0.3)),
                                         crest_k=0.45)):
        atlas[TH:2 * TH, (8 + i) * TW:(9 + i) * TW] = fr
    tops = {"rock": (mix(land, stone, 0.5), "rock"), "sandside": (sand, "sand"), "wood": (P["plank"], "wood"),
            "stone": (stone, "stone"), "dark": (mul(stone, 0.6), "stone")}
    for i, k in enumerate(SIDES):
        lo = side_tile(tops[k][0], tops[k][1], 30 + i, start=4, rows=5, wet_from=3)
        for name, tile in (("high:L", side_variant(sides[k], "L")), ("high:R", side_variant(sides[k], "R")),
                           ("low:LR", lo), ("low:L", side_variant(lo, "L")), ("low:R", side_variant(lo, "R")),
                           ("band:LR", side_variant(sides[k], "LR", 4)), ("band:L", side_variant(sides[k], "L", 4)),
                           ("band:R", side_variant(sides[k], "R", 4))):
            c0, row = SIDE_SETS[name]
            atlas[row * TH:(row + 1) * TH, (c0 + i) * TW:(c0 + i + 1) * TW] = tile
    rockc = mix(land, stone, 0.5)
    cob = mix(stone, (190, 175, 150), 0.35)
    slab = mix(stone, (205, 195, 175), 0.45)
    t2 = {
        "wetsand": wet_sand_tile(sand, sea, 50), "shingle": pebble_tile(mix(stone, sand, 0.45), 51),
        "cliff": patch_tile(mul(grass, 0.96), rockc, 52, n=4, cracks=2), "path": speck_tile(mix(land, (150, 112, 74), 0.55), 53, specks=14, dark=0.8),
        "cobble0": cobble_tile(cob, mul(cob, 0.6), 0), "cobble1": cobble_tile(cob, mul(cob, 0.6), 1),
        "cobble2": cobble_tile(cob, mul(cob, 0.6), 2),
        "slab0": slab_tile(slab, mul(slab, 0.66), 0), "slab1": slab_tile(slab, mul(slab, 0.66), 1, moss=grass),
        "slab2": slab_tile(slab, mul(slab, 0.66), 2),
        "dune": tuft_tile(sand, grass, 54), "grass3": grass_tile(mix(mul(grass, 0.86), (30, 70, 40), 0.1), 55),
        "meadow": grass_tile(mix(grass, (255, 250, 200), 0.08), 56, flowers=[(250, 245, 225), (250, 226, 130)]),
        "forest": patch_tile(mul(mix(grass, land, 0.25), 0.8), mix(land, (110, 80, 50), 0.5), 57, n=6, r=(0.8, 1.6)),
        "rubble": pebble_tile(mul(rockc, 0.92), 58, n=18, light=1.2, dark=0.68),
    }
    for i, k in enumerate(GROUND2):
        atlas[7 * TH:8 * TH, i * TW:(i + 1) * TW] = t2[k]


# ----------------------------------------------------------------- props ----

def vol_sprite(v, anchor):
    r = render(v)
    crop, (l, t) = trim(r.rgba)
    ax, ay = project(r.origin, *anchor)
    return crop, (int(round(ax - l)), int(round(ay - t)))


def rock(v, cx, cy, r, col, h=None, seed=0):
    rng = np.random.default_rng(seed)
    h = h or r
    for x in range(int(cx - r - 1), int(cx + r + 2)):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for z in range(F, F + int(h) + 2):
                d = ((x - cx) / r) ** 2 + ((y - cy) / r) ** 2 + ((z - F) / h) ** 2
                if d <= 1.0 + rng.random() * 0.15:
                    v.put(x, y, z, mul(col, 0.92 + 0.12 * rng.random()))


def tree(v, cx, cy, leaf, trunk=None, h=8, r=5, seed=0):
    trunk = trunk or P["wood_d"]
    v.box(cx - 1, cy - 1, F, cx + 1, cy + 1, F + h, trunk, SEAM_SIDE)
    rng = np.random.default_rng(seed)
    for (ox, oy, oz, rr) in ((0, 0, h + 3, r), (-2, 1, h + 1, r - 1.5), (2, -1, h + 2, r - 1.5), (0, 0, h + 6, r - 2)):
        for x in range(int(cx + ox - rr - 1), int(cx + ox + rr + 2)):
            for y in range(int(cy + oy - rr - 1), int(cy + oy + rr + 2)):
                for z in range(int(F + oz - rr), int(F + oz + rr + 1)):
                    d = ((x - cx - ox) ** 2 + (y - cy - oy) ** 2) / rr ** 2 + ((z - F - oz) / (rr * 0.8)) ** 2
                    if d <= 1.0:
                        v.put(x, y, z, mul(leaf, 0.9 + 0.2 * rng.random()))


def crystal(v, cx, cy, col, h=10, seed=0):
    rng = np.random.default_rng(seed)
    for (ox, oy, hh, rr) in ((0, 0, h, 1.6), (2, 1, h * 0.6, 1.2), (-1, 2, h * 0.5, 1.1)):
        for z in range(F, F + int(hh)):
            k = rr * (1 - (z - F) / hh) + 0.4
            for x in range(int(cx + ox - 2), int(cx + ox + 3)):
                for y in range(int(cy + oy - 2), int(cy + oy + 3)):
                    if (x - cx - ox) ** 2 + (y - cy - oy) ** 2 <= k * k:
                        v.put(x, y, z, mul(col, 0.9 + 0.25 * ((z - F) / hh)), GLOSS)


def mushroom(v, cx, cy, cap, h=6, r=3.5):
    v.cyl(cx, cy, F, F + h, 1.1, P["cream"])
    for z in range(F + h, F + h + 3):
        rr = r - (z - F - h) * 0.9
        v.cyl(cx, cy, z, z + 1, rr, cap)
    for (dx, dy) in ((1, -1), (-1, 1), (2, 1)):
        v.put(int(cx + dx), int(cy + dy), F + h + 3, P["white"])


def coral(v, cx, cy, col):
    for (dx, dy, hh) in ((0, 0, 7), (2, 1, 5), (-2, 1, 4), (1, -2, 5)):
        v.box(cx + dx, cy + dy, F, cx + dx + 1, cy + dy + 1, F + hh, col)
        v.put(cx + dx, cy + dy, F + hh, mul(col, 1.2))
        v.put(cx + dx + 1, cy + dy, F + hh - 2, col)


def pillar(v, cx, cy, col, h=14, broken=False):
    v.box(cx - 2, cy - 2, F, cx + 2, cy + 2, F + 2, mul(col, 0.9))
    v.box(cx - 1, cy - 1, F + 2, cx + 1, cy + 1, F + h - (4 if broken else 0), col, SEAM_SIDE)
    if not broken:
        v.box(cx - 2, cy - 2, F + h, cx + 2, cy + 2, F + h + 2, mul(col, 1.08))


def campfire(v, cx, cy):
    for a in range(6):
        x = int(round(cx + 2.5 * math.cos(a)))
        y = int(round(cy + 2.5 * math.sin(a)))
        v.box(x, y, F, x + 1, y + 1, F + 1, P["stone"])
    v.box(cx - 1, cy, F, cx + 2, cy + 1, F + 1, P["wood_d"])
    v.box(cx, cy - 1, F, cx + 1, cy + 2, F + 1, P["wood"])
    v.box(cx, cy, F + 1, cx + 1, cy + 1, F + 3, P["fire"], EMIT | NOSHADOW)
    v.put(cx, cy, F + 3, P["fire_l"], EMIT | NOSHADOW)


def signpost(v, cx, cy):
    v.box(cx, cy, F, cx + 1, cy + 1, F + 8, P["wood_d"])
    v.box(cx - 2, cy, F + 5, cx + 4, cy + 1, F + 8, P["wood"])
    v.box(cx - 1, cy + 1, F + 6, cx + 3, cy + 2, F + 7, P["cream"])


def ore(v, cx, cy, col, rock_col):
    rock(v, cx, cy, 3.2, rock_col, 3, seed=5)
    for (dx, dy, dz) in ((-1, 2, 2), (2, 0, 3), (0, 1, 4), (1, -2, 2)):
        v.put(cx + dx, cy + dy, F + dz, col, EMIT)


def herb(v, cx, cy, leaf, berry):
    for (dx, dy, hh) in ((0, 0, 4), (1, 1, 3), (-1, 1, 3), (1, -1, 3), (-1, -1, 2)):
        v.box(cx + dx, cy + dy, F, cx + dx + 1, cy + dy + 1, F + hh, leaf)
    for (dx, dy, dz) in ((1, 1, 3), (-1, 0, 4), (0, -1, 3)):
        v.put(cx + dx, cy + dy, F + dz, berry, EMIT)


def gate(v, cx, cy, col, glow):
    for dy in (-4, 4):
        v.box(cx - 1, cy + dy - 1, F, cx + 1, cy + dy + 1, F + 16, col, SEAM_SIDE)
    v.box(cx - 1, cy - 5, F + 16, cx + 1, cy + 6, F + 18, mul(col, 1.1))
    v.box(cx, cy - 3, F, cx + 1, cy + 4, F + 15, glow, EMIT | NOSHADOW)


def bones(v, cx, cy):
    bone = P["cream"]
    for i in range(5):
        v.box(cx - 5 + i * 2, cy, F, cx - 4 + i * 2, cy + 1, F + 6 - abs(i - 2), bone)
        v.box(cx - 5 + i * 2, cy, F + 6 - abs(i - 2), cx - 3 + i * 2, cy + 1, F + 7 - abs(i - 2), bone)
    v.box(cx - 6, cy - 1, F, cx + 6, cy + 2, F + 1, bone)


def dead_tree(v, cx, cy, col):
    v.box(cx, cy, F, cx + 2, cy + 2, F + 12, col, SEAM_SIDE)
    for (dx, dy, z, ln) in ((1, 0, 8, 4), (-1, 0, 10, 3), (0, 1, 6, 3)):
        for i in range(ln):
            v.put(cx + dx * (i + 1) + (1 if dx > 0 else 0), cy + dy * (i + 1), F + z + i, col)


def nest_prop(v, cx, cy, egg):
    v.cyl(cx, cy, F, F + 2, 3, P["straw_d"])
    v.cyl(cx, cy, F + 1, F + 2, 2, P["straw"])
    v.box(cx - 1, cy - 1, F + 2, cx + 1, cy + 1, F + 5, egg, GLOSS)


def gold_pile(v, cx, cy):
    for (dx, dy, h) in ((0, 0, 3), (1, 1, 2), (-1, 1, 2), (1, -1, 1), (-1, -1, 2), (2, 0, 1)):
        v.box(cx + dx, cy + dy, F, cx + dx + 1, cy + dy + 1, F + h, P["gold"], GLOSS)


def statue(v, cx, cy, col):
    v.box(cx - 3, cy - 3, F, cx + 3, cy + 3, F + 3, mul(col, 0.85))
    v.box(cx - 1, cy - 1, F + 3, cx + 2, cy + 2, F + 11, col)
    v.box(cx - 2, cy - 1, F + 8, cx + 3, cy + 2, F + 10, col)
    v.cyl(cx + 0.5, cy + 0.5, F + 11, F + 14, 1.8, col)


def lighthouse(v, cx, cy):
    for z in range(F, F + 34):
        r = 4.2 - (z - F) * 0.05
        col = P["white"] if ((z - F) // 5) % 2 == 0 else P["red"]
        v.cyl(cx, cy, z, z + 1, r, col)
    v.cyl(cx, cy, F + 34, F + 35, 4.2, P["iron_d"])
    v.cyl(cx, cy, F + 35, F + 39, 2.6, P["lamp"], EMIT | NOSHADOW)
    v.cyl(cx, cy, F + 39, F + 41, 3.2, P["red_d"])


def sea_rock(v, cx, cy, r, col, h, seed=0, crust=None):
    """A rock standing in the water: wet dark foot, pale salt/guano crust on
    the crown."""
    rock(v, cx, cy, r, col, h, seed=seed)
    X, Y, Z = v.shape
    rng = np.random.default_rng(seed + 7)
    for x in range(X):
        for y in range(Y):
            col_z = np.nonzero(v.solid[x, y])[0]
            if col_z.size == 0:
                continue
            for z in col_z:
                if z <= F + 1:
                    v.col[x, y, z] = mix(tuple(int(c) for c in v.col[x, y, z]), (25, 45, 60), 0.45)
            top = col_z.max()
            if crust is not None and top >= F + h * 0.7 and rng.random() < 0.55:
                v.col[x, y, top] = crust


def sea_stack(v, cx, cy, col, h=16, seed=0):
    rng = np.random.default_rng(seed)
    for z in range(F, F + h):
        f = (z - F) / h
        r = 3.6 - 1.4 * f + 0.5 * math.sin(z * 1.3)
        ox = 0.6 * math.sin(z * 0.45 + seed)
        for x in range(int(cx - 5), int(cx + 6)):
            for y in range(int(cy - 5), int(cy + 6)):
                if (x + 0.5 - cx - ox) ** 2 + (y + 0.5 - cy) ** 2 <= r * r + rng.random() * 1.2:
                    c = mul(col, 0.86 + 0.18 * f + (rng.random() - 0.5) * 0.08)
                    if z <= F + 1:
                        c = mix(c, (25, 45, 60), 0.45)
                    if (z - F) % 4 == 0:
                        c = mul(c, 0.9)
                    v.put(x, y, z, c)
    for (dx, dy) in ((0, 0), (1, 0), (0, 1), (-1, 0)):
        v.put(int(cx + dx), int(cy + dy), F + h, P["white"])


def driftwood(v, cx, cy, col):
    for i in range(-5, 6):
        x, y = cx + i, cy + i // 3
        v.box(x, y, F, x + 1, y + 2, F + 2, mul(col, 0.94 + 0.04 * (i % 2)), SEAM_SIDE)
    v.box(cx + 3, cy - 2, F + 1, cx + 4, cy, F + 2, mul(col, 0.9))
    v.box(cx - 4, cy - 1, F, cx - 3, cy, F + 1, mul(col, 0.82))


def grass_tuft(v, cx, cy, col, n=7, seed=0, hmax=6):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        dx, dy = int(rng.integers(-2, 3)), int(rng.integers(-2, 3))
        h = int(rng.integers(3, hmax + 1))
        lean = int(rng.integers(-1, 2))
        for z in range(h):
            x = cx + dx + (lean if z > h // 2 else 0)
            v.put(x, cy + dy, F + z, mul(col, 0.8 + 0.3 * z / h))


# ------------------------------------------------------ arena set pieces ----
# Larger props that give a land battle its setting: an enemy camp, a beast's
# lair, a wrecked ship on the beach, ruins and the fittings of a fighting
# pit. Battle arenas (arena_scene.gd) place them behind and beside the
# fight; the fight band itself stays clear.

def swapped(fn):
    """Run fn on a volume with X and Y exchanged: the same model turned a
    quarter so it runs along the other iso axis."""
    def run(v):
        X, Y, Z = v.shape
        t = Vol(Y, X, Z)
        fn(t)
        m = t.mirror_xy()
        v.solid[...] = m.solid
        v.col[...] = m.col
        v.flag[...] = m.flag
        v.group[...] = m.group
    return run


def tent(v, cloth, trim, L=12, W=11, H=9):
    """A-frame tent, ridge along x, its open flap on the +x gable."""
    X, Y, Z = v.shape
    b0 = Y / 2.0
    slope = H / (W / 2.0 + 0.5)
    a0, a1 = 2, 2 + L
    for a in range(a0, a1):
        for b in range(int(b0 - W / 2), int(b0 + W / 2) + 1):
            d = abs(b + 0.5 - b0)
            zt = int(round(F + H - d * slope))
            if zt < F:
                continue
            c = trim if (a - a0) % 4 == 1 else cloth
            for z in range(F, zt + 1):
                shade = 0.9 + 0.1 * (z - F) / max(1, H)
                v.put(a, b, z, mul(c, shade), SEAM_SIDE if (a - a0) % 4 == 0 else 0)
    # dark doorway on the front gable, flaps folded back beside it
    dark = (34, 28, 30)
    for b in range(int(b0 - W / 2), int(b0 + W / 2) + 1):
        d = abs(b + 0.5 - b0)
        top = int(round(F + H * 0.62 - d * slope))
        for z in range(F, top + 1):
            if d < 2.6:
                v.put(a1 - 1, b, z, dark)
    for s in (-1, 1):
        bb = int(b0 + s * 3.2)
        for z in range(F, F + 4):
            v.put(a1, bb, z, mul(cloth, 0.8))
    # ridge pole ends, guy pegs
    v.put(a0 - 1, int(b0), F + H, P["wood_d"])
    v.put(a1, int(b0), F + H, P["wood_d"])
    v.put(a1, int(b0), F + H - 1, P["wood_d"])
    for (pa, pb) in ((a0 - 1, 0), (a1, 0), (a0 - 1, Y - 1), (a1, Y - 1)):
        v.put(pa, pb, F, P["wood_dd"])


def stand_rack(v):
    """Freestanding weapon rack: two posts, rails, spears and a shield."""
    for x in (1, 10):
        v.box(x, 2, F, x + 1, 3, F + 11, P["wood_d"], SEAM_SIDE)
    v.box(1, 2, F + 3, 11, 3, F + 4, P["wood"])
    v.box(1, 2, F + 9, 11, 3, F + 10, P["wood"])
    for i, x in enumerate(range(2, 10, 2)):
        h = 13 + (i % 2)
        v.box(x, 3, F, x + 1, 4, F + h - 3, P["wood_l"])
        v.box(x, 3, F + h - 3, x + 1, 4, F + h, P["steel"], GLOSS)
    v.box(4, 4, F + 1, 7, 5, F + 5, P["red_d"])
    v.box(5, 5, F + 2, 6, 6, F + 4, P["brass"], GLOSS)


def stakes(v, n=7, seed=0):
    """Palisade of sharpened logs along x, lashed with two ropes."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        cx = 1.5 + i * 2
        h = 10 + int(rng.integers(0, 4))
        c = mul(P["wood"], 0.86 + 0.14 * rng.random())
        v.cyl(cx, 2.5, F, F + h, 1.05, c, SEAM_SIDE)
        v.put(int(cx), 2, F + h, P["wood_l"])
        v.put(int(cx), 2, F + h + 1, P["wood_l"])
    for z in (F + 3, F + 8):
        v.box(0, 3, z, 2 * n + 1, 4, z + 1, P["rope"])


def wreck_hull(v, seed=0):
    """Half-buried hull of a wrecked ship: planked bow, a breach in the near
    side, bare ribs at the broken stern, a snapped mast stump."""
    rng = np.random.default_rng(seed)
    X, Y, Z = v.shape
    yc = Y / 2.0
    D = 10
    plank = mix(P["wood"], (205, 200, 185), 0.3)
    for x in range(2, X - 2):
        t = (x - 2) / (X - 5)
        b = 7.2 * min(1.0, (t / 0.42)) ** 0.62
        if t > 0.86:
            b *= 1.0 - (t - 0.86) * 1.6
        if b < 0.8:
            continue
        ribs_only = t > 0.7
        top_cut = F + D if not ribs_only else F + D - int((t - 0.7) * 22) - int(rng.integers(0, 3))
        for z in range(F, F + D + 1):
            w = b * (0.86 + 0.14 * (z - F) / D)
            for y in range(int(yc - w - 1), int(yc + w + 2)):
                r = abs(y + 0.5 - yc) / w
                deck = z == F + D
                shell = 0.74 < r <= 1.0
                if not (shell or (deck and r <= 1.0)):
                    continue
                if ribs_only and (x % 3 != 0 or z > top_cut):
                    continue
                if deck and not shell and (x % 7 in (2, 3) or rng.random() < 0.18 or t > 0.62):
                    continue
                c = mul(plank, 0.72 + 0.26 * (z - F) / D)
                if z == F + D and shell:
                    c = P["wood_d"]
                if z <= F + 1 and rng.random() < 0.35:
                    c = mix(c, (60, 110, 80) if rng.random() < 0.6 else (225, 225, 215), 0.55)
                v.put(x, y, z, c, SEAM_SIDE)
    # breach in the near (+y) side amidships
    for x in range(12, 18):
        for z in range(F + 2, F + 7):
            if abs(x - 14.5) / 3.2 + abs(z - F - 4.2) / 2.6 < 1.0 + rng.random() * 0.3:
                for y in range(int(yc), Y):
                    if v.solid[x, y, z]:
                        v.solid[x, y, z] = False
    # wet sand inside the hull
    for x in range(4, X - 4):
        for y in range(Y):
            if not v.solid[x, y, F] and abs(y + 0.5 - yc) < 5.5:
                v.put(x, y, F, mix(P["sand"], (90, 80, 60), 0.35))
    # snapped mast with a jagged top
    mx = int(X * 0.38)
    v.cyl(mx + 0.5, yc, F + 1, F + D + 7, 1.2, P["wood_d"], SEAM_SIDE)
    v.put(mx, int(yc), F + D + 7, P["wood_l"])
    v.put(mx + 1, int(yc), F + D + 8, P["wood_l"])


def ribs(v, seed=0):
    """Bleached ribs of a small boat sticking out of the sand."""
    rng = np.random.default_rng(seed)
    bone = mix(P["wood_l"], (230, 225, 210), 0.6)
    v.box(1, 5, F, v.shape[0] - 1, 7, F + 1, mul(bone, 0.85))
    for i, x in enumerate(range(3, v.shape[0] - 2, 3)):
        h = max(3, 10 - abs(i - 2) * 2 - int(rng.integers(0, 2)))
        for z in range(F, F + h):
            f = (z - F) / 9.0
            off = 1.2 + 4.0 * f ** 0.55
            for s in (-1, 1):
                if s > 0 or z < F + h - 1:
                    v.put(x, int(round(6 + s * off - (0.5 if s < 0 else 0))), z, mul(bone, 0.8 + 0.2 * f))


def mast_fallen(v, seed=0):
    """A broken mast lying across the sand, its yard and a torn sail."""
    rng = np.random.default_rng(seed)
    X, Y, Z = v.shape
    for x in range(1, X - 1):
        v.box(x, 4, F, x + 1, 6, F + 2, mul(P["wood_d"], 0.95 + 0.05 * (x % 2)), SEAM_SIDE)
    v.box(X - 3, 3, F, X - 1, 7, F + 2, P["wood_l"])
    yx = int(X * 0.62)
    v.box(yx, 0, F + 2, yx + 1, Y, F + 3, P["wood"])
    sail = P["canvas"]
    for x in range(yx + 1, min(X, yx + 9)):
        for y in range(1, Y - 1):
            if rng.random() < 0.2 + 0.06 * (x - yx):
                continue
            v.put(x, y, F, mul(sail, 0.9 + 0.1 * rng.random()), NOSHADOW)
    for k in range(3):
        v.put(yx - 2 - k, 8 + k % 2, F, P["rope"])


def brazier(v):
    """Iron fire bowl on three legs."""
    for (lx, ly) in ((1, 1), (6, 2), (2, 6)):
        v.box(lx, ly, F, lx + 1, ly + 1, F + 5, P["iron_d"])
    v.cyl(4, 4, F + 5, F + 7, 3.0, P["iron"], GLOSS)
    v.cyl(4, 4, F + 7, F + 8, 3.0, P["iron_d"])
    v.cyl(4, 4, F + 7, F + 8, 2.0, mix(P["fire"], (90, 30, 20), 0.5), EMIT | NOSHADOW)
    v.cyl(4, 4, F + 8, F + 10, 1.6, P["fire"], EMIT | NOSHADOW)
    v.put(4, 3, F + 10, P["fire_l"], EMIT | NOSHADOW)
    v.put(3, 4, F + 11, P["fire_l"], EMIT | NOSHADOW)


def bone_pile(v, seed=0):
    """A beast's leavings: scattered long bones round a horned skull."""
    rng = np.random.default_rng(seed)
    bone = P["cream"]
    for _ in range(9):
        x, y = int(rng.integers(1, 12)), int(rng.integers(1, 10))
        ln = int(rng.integers(3, 6))
        along = rng.random() < 0.5
        z = F + int(rng.integers(0, 2))
        for i in range(ln):
            v.put(x + (i if along else 0), y + (0 if along else i), z, mul(bone, 0.85 + 0.1 * rng.random()))
        v.put(x, y, z + 1, bone)
    # skull facing the viewer, two dark sockets and curling horns
    v.box(6, 5, F, 10, 9, F + 4, bone)
    v.box(10, 6, F, 11, 8, F + 2, mul(bone, 0.9))
    v.put(9, 8, F + 2, (40, 32, 36))
    v.put(10, 6, F + 2, (40, 32, 36))
    for i in range(4):
        v.put(6 - i // 2, 5 - (i + 1) // 2, F + 4 + i, mul(bone, 0.75))
        v.put(9 + (i + 1) // 2, 4 - i // 2, F + 4 + i, mul(bone, 0.75))


def lair_nest(v, egg, seed=0):
    """A big nest of torn branches with eggs and a few bones."""
    rng = np.random.default_rng(seed)
    X, Y, Z = v.shape
    cx, cy = X / 2.0, Y / 2.0
    for x in range(X):
        for y in range(Y):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= 6.8:
                h = 1 if d < 4.0 else int(1 + 2.6 * (d - 4.0) / 2.8)
                for z in range(F, F + h + (1 if rng.random() < 0.3 else 0)):
                    c = P["straw_d"] if (x + y + z) % 3 else P["wood_d"]
                    v.put(x, y, z, mul(c, 0.85 + 0.2 * rng.random()))
    for (dx, dy) in ((-1, 0), (1, 1), (0, -2)):
        x, y = int(cx + dx), int(cy + dy)
        v.box(x, y, F + 1, x + 2, y + 2, F + 4, egg, GLOSS)
        v.put(x, y, F + 4, mul(egg, 1.05), GLOSS)
    for i in range(4):
        v.put(int(cx) + 3 + i, int(cy) + 4, F + 3, P["cream"])


def obelisk(v, col, glow):
    """Tapering stone needle on a stepped base, runes glowing on two faces."""
    X, Y, Z = v.shape
    v.box(1, 1, F, X - 1, Y - 1, F + 2, mul(col, 0.82))
    v.box(2, 2, F + 2, X - 2, Y - 2, F + 3, mul(col, 0.9))
    c0 = X / 2.0
    top = Z - 4
    for z in range(F + 3, top):
        r = 2.4 - 1.0 * (z - F - 3) / (top - F - 3)
        v.box(int(round(c0 - r)), int(round(c0 - r)), z, int(round(c0 + r)), int(round(c0 + r)), z + 1,
              mul(col, 0.95 + 0.1 * ((z // 3) % 2)), SEAM_SIDE if z % 5 == 0 else 0)
    v.box(int(c0) - 1, int(c0) - 1, top, int(c0) + 1, int(c0) + 1, top + 2, mul(col, 1.15))
    v.put(int(c0) - 1, int(c0) - 1, top + 2, glow, EMIT | NOSHADOW)
    for z in range(F + 6, top - 2, 4):
        r = 2.4 - 1.0 * (z - F - 3) / (top - F - 3)
        e = int(round(c0 + r)) - 1
        v.put(e, int(c0) - 1 + (z // 4) % 2, z, glow, EMIT)
        v.put(int(c0) - 1 + (z // 4 + 1) % 2, e, z + 1, glow, EMIT)


def ruin_arch(v, col, moss, seed=0):
    """A broken stone arch spanning along y, rubble at its feet."""
    rng = np.random.default_rng(seed)
    X, Y, Z = v.shape
    for (y0, h) in ((2, 20), (Y - 6, 15)):
        v.box(2, y0, F, 6, y0 + 4, F + h, col, SEAM_SIDE)
        v.box(1, y0 - 1, F, 7, y0 + 5, F + 2, mul(col, 0.85))
    for y in range(2, Y - 9):
        f = (y - 4) / max(1.0, Y - 12)
        zb = F + 13 + int(round(3.0 * math.sin(math.pi * min(1.0, max(0.0, f)))))
        for z in range(zb, F + 21):
            if y > Y * 0.55 and z > F + 18 - (y - Y * 0.55):
                continue
            v.put(2, y, z, mul(col, 1.04), SEAM_SIDE)
            for x in range(3, 6):
                v.put(x, y, z, col)
    for x in range(2, 6):
        for y in range(2, 6):
            if rng.random() < 0.6:
                v.put(x, y, F + 21 if v.solid[x, y, F + 20] else F + 20, moss)
    for _ in range(6):
        x, y = int(rng.integers(0, X - 1)), int(rng.integers(Y // 2, Y - 1))
        if not v.solid[x, y, F]:
            v.box(x, y, F, x + 2, y + 1 + int(rng.integers(0, 2)), F + 1 + int(rng.integers(0, 2)), mul(col, 0.8 + 0.1 * rng.random()))


def stalagmite(v, col, seed=0):
    """Two dripstone cones with wet, glossy tips."""
    rng = np.random.default_rng(seed)
    for (cx, cy, r, h) in ((5, 5, 3.3, 17), (8, 2.5, 1.9, 9), (2.5, 8, 1.6, 7)):
        for z in range(F, F + h):
            rr = r * (1 - (z - F) / h) ** 0.8 + 0.35
            c = mul(col, 0.85 + 0.25 * (z - F) / h + (rng.random() - 0.5) * 0.06)
            v.cyl(cx, cy, z, z + 1, rr, c, GLOSS if z > F + h * 0.7 else 0)


def standard(v, cloth, metal):
    """Tall war banner on a crossbar, swallowtailed, with a pale emblem."""
    X, Y, Z = v.shape
    v.box(1, 3, F, 3, 5, F + 1, P["stone_d"])
    v.box(2, 3, F, 3, 4, F + 27, P["wood_d"])
    v.box(2, 0, F + 25, 3, Y, F + 26, P["wood"])
    v.put(2, 3, F + 27, metal, GLOSS)
    v.put(2, 3, F + 28, metal, GLOSS)
    for y in range(1, Y - 1):
        tail = F + 10 if y in (1, Y - 2) else (F + 12 if y in (2, Y - 3) else F + 13)
        if y in (3, 4):
            tail = F + 13
        for z in range(tail, F + 25):
            c = cloth
            if abs(y - 3.5) + abs(z - F - 19.5) * 0.7 < 2.0:
                c = mix(cloth, (250, 245, 230), 0.75)
            elif z == F + 24 or y in (1, Y - 2):
                c = mul(cloth, 0.8)
            v.put(3, y, z, c, NOSHADOW)


def barrier(v, col, cap, seed=0):
    """Low stone wall segment along x with a lighter coping and a crack."""
    rng = np.random.default_rng(seed)
    X, Y, Z = v.shape
    for x in range(1, X - 1):
        for z in range(F, F + 5):
            blk = ((x + (2 if (z // 2) % 2 else 0)) // 4) % 2
            c = mul(col, 0.88 + 0.08 * blk + (rng.random() - 0.5) * 0.05)
            v.box(x, 1, z, x + 1, 4, z + 1, c, SEAM_SIDE if z % 2 == 0 else 0)
        if not (X // 2 - 1 <= x <= X // 2):
            v.box(x, 0, F + 5, x + 1, 5, F + 6, cap)
    v.clear(X // 2 - 1, 0, F + 3, X // 2 + 1, Y, F + 6)


def prop_table(pal):
    land, grass, acc = (hexrgb(pal[k]) for k in ("land", "grass", "accent"))
    rockc = mix(land, (140, 140, 150), 0.5)
    leaf = mix(grass, (40, 120, 50), 0.25)
    return {
        "tree": (lambda v: tree(v, 8, 8, leaf, seed=1), (16, 16, 26), (8, 8, F)),
        "tree_b": (lambda v: tree(v, 8, 8, mul(leaf, 0.85), h=10, r=6, seed=2), (16, 16, 30), (8, 8, F)),
        "palm": (lambda v: kit.palm(v, 8, 9, h=22), (24, 22, 32), (9, 10, F)),
        "bush": (lambda v: rock(v, 5, 5, 3.2, leaf, 2.6, seed=3), (10, 10, 8), (5, 5, F)),
        "rock": (lambda v: rock(v, 5, 5, 3.4, rockc, 2.8, seed=4), (10, 10, 8), (5, 5, F)),
        "rock_big": (lambda v: rock(v, 8, 8, 6, rockc, 6, seed=5), (16, 16, 14), (8, 8, F)),
        "crystal": (lambda v: crystal(v, 6, 6, mix(acc, (200, 240, 255), 0.4), 12, 6), (12, 12, 16), (6, 6, F)),
        "mushroom": (lambda v: mushroom(v, 5, 5, mix(acc, (220, 60, 70), 0.5)), (10, 10, 14), (5, 5, F)),
        "coral": (lambda v: coral(v, 5, 5, mix(acc, (240, 110, 120), 0.5)), (10, 10, 10), (5, 5, F)),
        "pillar": (lambda v: pillar(v, 5, 5, mix(land, (220, 210, 190), 0.6)), (10, 10, 20), (5, 5, F)),
        "pillar_broken": (lambda v: pillar(v, 5, 5, mix(land, (200, 190, 170), 0.6), broken=True), (10, 10, 16), (5, 5, F)),
        "dead_tree": (lambda v: dead_tree(v, 6, 6, mix(land, (90, 70, 60), 0.6)), (14, 14, 18), (6, 6, F)),
        "bones": (lambda v: bones(v, 8, 6), (16, 12, 10), (8, 6, F)),
        "statue": (lambda v: statue(v, 6, 6, mix(land, (200, 200, 190), 0.5)), (12, 12, 18), (6, 6, F)),
        "ore": (lambda v: ore(v, 5, 5, acc, rockc), (10, 10, 9), (5, 5, F)),
        "herb": (lambda v: herb(v, 4, 4, leaf, (240, 90, 120)), (9, 9, 7), (4, 4, F)),
        "gate": (lambda v: gate(v, 4, 8, mix(land, (120, 120, 130), 0.5), acc), (8, 16, 20), (4, 8, F)),
        # coast dressing (coast.gd): rocks standing in the surf, a stack for
        # exposed headlands, beach driftwood, dune grass and reeds
        "sea_rock": (lambda v: sea_rock(v, 6, 6, 4.4, mul(rockc, 0.9), 3.4, seed=8, crust=mix(rockc, (240, 240, 230), 0.6)),
                     (12, 12, 8), (6, 6, F)),
        "sea_rock_s": (lambda v: sea_rock(v, 4, 4, 2.6, mul(rockc, 0.9), 2.2, seed=9), (8, 8, 6), (4, 4, F)),
        "sea_stack": (lambda v: sea_stack(v, 6, 6, rockc, h=17, seed=3), (12, 12, 22), (6, 6, F)),
        "driftwood": (lambda v: driftwood(v, 7, 3, mix(P["wood_l"], (220, 215, 200), 0.55)), (15, 7, 4), (7, 3, F)),
        "tuft": (lambda v: grass_tuft(v, 3, 3, mix(grass, (200, 190, 120), 0.35), seed=4), (7, 7, 8), (3, 3, F)),
        "reeds": (lambda v: grass_tuft(v, 4, 4, mix(leaf, (120, 140, 60), 0.3), n=12, seed=5, hmax=9), (9, 9, 11), (4, 4, F)),
        # arena set pieces in the region's stone and colours
        "obelisk": (lambda v: obelisk(v, mix(land, (55, 55, 70), 0.55), mix(acc, (220, 240, 255), 0.35)),
                    (10, 10, 30), (5, 5, F)),
        "ruin_arch": (lambda v: ruin_arch(v, mix(land, (205, 198, 180), 0.55), mix(leaf, (60, 110, 50), 0.3), seed=3),
                      (8, 26, 26), (4, 13, F)),
        "stalagmite": (lambda v: stalagmite(v, mix(land, (120, 110, 105), 0.6), seed=2), (11, 11, 20), (5, 5, F)),
        "standard": (lambda v: standard(v, acc, P["brass"]), (6, 8, 31), (2.5, 3.5, F)),
        "barrier": (lambda v: barrier(v, mix(land, (165, 160, 150), 0.55), mix(land, (215, 210, 195), 0.55), seed=1),
                    (18, 5, 8), (9, 2.5, F)),
        "barrier_y": (swapped(lambda v: barrier(v, mix(land, (165, 160, 150), 0.55), mix(land, (215, 210, 195), 0.55),
                                                seed=2)), (5, 18, 8), (2.5, 9, F)),
    }


COMMON_PROPS = {
    "crate": (lambda v: (kit.crate(v, 1, 1, 5, 5), kit.crate(v, 2, 2, 3, 3, z0=F + 5)), (8, 8, 12), (3, 3, F)),
    "barrel": (lambda v: kit.barrel(v, 3, 3, h=7, r=2.2), (6, 6, 10), (3, 3, F)),
    "barrels": (lambda v: (kit.barrel(v, 3, 3, h=7, r=2.2), kit.barrel(v, 7, 4, h=6, r=2.0)), (10, 8, 10), (5, 4, F)),
    "chest": (lambda v: kit.chest(v, 1, 1, 5, 4), (7, 6, 8), (3, 3, F)),
    "chest_open": (lambda v: kit.chest(v, 1, 1, 5, 4, open_=True, loot=P["gold"]), (7, 6, 10), (3, 3, F)),
    "campfire": (lambda v: campfire(v, 4, 4), (9, 9, 6), (4, 4, F)),
    "signpost": (lambda v: signpost(v, 4, 4), (8, 8, 10), (4, 4, F)),
    "lamp": (lambda v: kit.lamp_post(v, 3, 3, h=14), (6, 6, 20), (3, 3, F)),
    "nest": (lambda v: nest_prop(v, 4, 4, (250, 240, 220)), (9, 9, 7), (4, 4, F)),
    "gold": (lambda v: gold_pile(v, 3, 3), (7, 7, 5), (3, 3, F)),
    "flag": (lambda v: kit.flag_pole(v, 3, 3, 16, P["red"], 6, 4), (12, 8, 20), (3, 3, F)),
    "sacks": (lambda v: (kit.sack(v, 1, 1), kit.sack(v, 4, 2), kit.sack(v, 2, 4)), (8, 8, 6), (3, 3, F)),
    "lighthouse": (lambda v: lighthouse(v, 6, 6), (12, 12, 44), (6, 6, F)),
    "cannon": (lambda v: kit.cannon(v, 1, 2), (10, 8, 8), (4, 3, F)),
    # arena set pieces (battle arenas, arena_scene.gd)
    "tent": (lambda v: tent(v, P["canvas"], P["red_d"]), (16, 13, 12), (8, 6.5, F)),
    "tent_b": (swapped(lambda v: tent(v, mix(P["canvas"], P["straw_d"], 0.35), P["navy"], L=10, W=9, H=8)),
               (11, 14, 11), (5.5, 7, F)),
    "rack": (stand_rack, (12, 7, 16), (6, 3, F)),
    "stakes_x": (lambda v: stakes(v, 7, seed=1), (15, 5, 16), (7.5, 2.5, F)),
    "stakes_y": (swapped(lambda v: stakes(v, 7, seed=2)), (5, 15, 16), (2.5, 7.5, F)),
    "wreck_hull": (lambda v: wreck_hull(v, seed=4), (34, 18, 20), (17, 9, F)),
    "ribs": (lambda v: ribs(v, seed=2), (20, 12, 12), (10, 6, F)),
    "mast_fallen": (lambda v: mast_fallen(v, seed=3), (28, 12, 6), (14, 6, F)),
    "brazier": (brazier, (9, 9, 13), (4.5, 4.5, F)),
    "bone_pile": (lambda v: bone_pile(v, seed=5), (15, 12, 9), (7.5, 6, F)),
    "lair_nest": (lambda v: lair_nest(v, (235, 225, 200), seed=6), (16, 16, 7), (8, 8, F)),
}

COAST_PROPS = ["sea_rock", "sea_rock_s", "sea_stack", "driftwood", "tuft", "reeds"]

# Packed for every region: the arena set pieces, plus the ruin, rock and
# grotto props that dungeon, arena and secret layouts (sites and battle
# arenas) ask for in any region.
SET_PROPS = ["obelisk", "ruin_arch", "stalagmite", "standard", "barrier", "barrier_y",
             "pillar", "pillar_broken", "rock_big", "statue", "bones", "crystal", "mushroom", "dead_tree"]

REGION_PROPS = {
    "dawnwater": ["palm", "bush", "rock", "coral", "tree"],
    "emberreach": ["rock", "rock_big", "dead_tree", "crystal", "pillar_broken"],
    "verdant_maw": ["tree", "tree_b", "mushroom", "bush", "herb"],
    "glass_current": ["crystal", "rock", "pillar", "bush", "rock_big"],
    "crown_shoals": ["pillar", "statue", "tree", "bush", "palm"],
    "stormbelt": ["dead_tree", "rock", "rock_big", "pillar_broken", "bush"],
    "moonwake": ["crystal", "mushroom", "tree_b", "pillar", "rock"],
    "ashen_trench": ["bones", "rock_big", "dead_tree", "pillar_broken", "crystal"],
    "leviathan_ring": ["coral", "bones", "rock", "palm", "bush"],
    "grand_horizon": ["pillar", "statue", "palm", "tree", "crystal"],
}


# -------------------------------------------------------------- buildings ----

def house(v, W, D, H, wall, roof, trim, door=True, sign=None, awning=None, extra=None):
    v.box(0, 0, F, W, D, F + 2, P["stone_d"])
    v.box(0, 0, F + 2, W, D, F + H, wall, SEAM_SIDE)
    for z in range(F + 2, F + H, 6):
        v.box(0, 0, z, W, D, z + 1, mul(wall, 0.9))
    v.box(0, 0, F + H, W, D, F + H + 1, trim)
    # pitched roof along x
    for k in range(D // 2 + 2):
        y0, y1 = -1 + k, D + 1 - k
        if y0 >= y1:
            break
        v.box(-1, max(0, y0), F + H + 1 + k, W + 1, min(D, y1), F + H + 2 + k, mul(roof, 1.0 - 0.04 * (k % 2)))
    v.box(-1, D // 2 - 1, F + H + D // 2 + 1, W + 1, D // 2 + 1, F + H + D // 2 + 2, mul(roof, 1.15))
    # windows on +x and +y faces
    for wy in range(3, D - 2, 6):
        v.box(W, wy, F + H - 7, W + 1, wy + 3, F + H - 3, P["lamp"], EMIT)
    for wx in range(3, W - 2, 7):
        if door and abs(wx + 1 - W // 2) < 3:
            continue
        v.box(wx, D, F + H - 7, wx + 3, D + 1, F + H - 3, P["lamp"], EMIT)
        v.box(wx - 1, D, F + H - 3, wx + 4, D + 2, F + H - 2, mul(trim, 0.9))
    if door:
        dx = W // 2 - 2
        v.box(dx, D, F + 2, dx + 4, D + 1, F + 10, P["wood_d"])
        v.box(dx + 1, D, F + 2, dx + 3, D + 1, F + 9, P["wood"])
        v.put(dx + 3, D, F + 6, P["gold"])
    if awning:
        for i in range(W + 2):
            v.box(i - 1, D, F + 11, i, D + 4, F + 12, awning if (i // 2) % 2 == 0 else P["white"])
    if sign:
        v.box(W // 2 - 4, D, F + H - 1, W // 2 + 4, D + 1, F + H + 4, P["wood_d"])
        v.box(W // 2 - 3, D + 1, F + H, W // 2 + 3, D + 2, F + H + 3, sign)
    if extra:
        extra(v)


# Regional building kits change structural profiles as well as pigments.
# Every service has its own floor plan (open market, terrace inn, gantry
# workshop, public notice shelter, observatory tower and compact dwelling).
ARCHITECTURE = {
    "dawnwater": ("gable", "#eee0b6", "#497e94", "#75503c", "#cf6650"),
    "emberreach": ("basalt", "#655451", "#bd7950", "#342e39", "#e7a259"),
    "verdant_maw": ("stilt", "#c6b07b", "#698857", "#5a6447", "#d8ae64"),
    "glass_current": ("crystal", "#e1e5db", "#91cbd1", "#6f91aa", "#cfb6df"),
    "crown_shoals": ("arcade", "#dbbc83", "#3f5c83", "#917146", "#b45764"),
    "stormbelt": ("storm", "#a0a9a1", "#546d77", "#4c5359", "#d9b95b"),
    "moonwake": ("moon", "#a5aec5", "#515178", "#55526b", "#d8b477"),
    "ashen_trench": ("terrace", "#6c676c", "#a5775b", "#3c3c47", "#bd8667"),
    "leviathan_ring": ("shell", "#d8d3b3", "#79a99a", "#887e69", "#d99885"),
    "grand_horizon": ("dome", "#eee5c8", "#c6ab6b", "#b49351", "#629caa"),
}


def architectural_roof(v, x, y, w, d, z, style, roof, trim):
    """A reproducible regional roof silhouette, contained in its volume."""
    if style in ("dome", "arcade", "shell"):
        # Ellipsoidal masonry dome / ribbed shell, not a gable recolour.
        cx, cy = x + w / 2, y + d / 2
        height = 7 if style == "dome" else (5 if style == "arcade" else 6)
        for k in range(height):
            r = math.sqrt(max(0.05, 1 - (k / height) ** 2))
            rw, rd = max(1, round(w * r / 2)), max(1, round(d * r / 2))
            for ix in range(int(cx - rw), int(cx + rw + 1)):
                for iy in range(int(cy - rd), int(cy + rd + 1)):
                    if ((ix + 0.5 - cx) / (rw + 0.4)) ** 2 + ((iy + 0.5 - cy) / (rd + 0.4)) ** 2 <= 1:
                        rib = style == "shell" and (ix - x) % 4 == 0
                        v.put(ix, iy, z + k, mix(roof, trim, 0.45) if rib else roof)
        if style == "dome":
            v.cyl(cx, cy, z + height, z + height + 3, 1, trim)
    elif style in ("basalt", "terrace"):
        v.box(x, y, z, x + w, y + d, z + 2, roof)
        # A flat raised parapet with readable corner caps.
        for bx, by, bw, bd in ((x, y, w, 1), (x, y + d - 1, w, 1), (x, y, 1, d), (x + w - 1, y, 1, d)):
            v.box(bx, by, z + 2, bx + bw, by + bd, z + 4, trim)
        if style == "basalt":
            for i in range(2, w - 1, 5):
                v.box(x + i, y, z + 4, x + i + 2, y + 2, z + 5, roof)
    elif style == "crystal":
        for k in range(max(3, d // 2 + 1)):
            inset = min(k, d // 2 - 1)
            v.box(x + inset // 3, y + inset, z + k, x + w - inset // 3, y + d - inset, z + k + 1,
                  mix(roof, P["glass"], 0.2 if k % 3 else 0.5), GLOSS)
        v.box(x + w // 2 - 1, y + d // 2 - 1, z + d // 2, x + w // 2 + 1, y + d // 2 + 1, z + d // 2 + 4, P["glass"], GLOSS)
    else:
        height = d // 2 + 1 if style == "gable" else max(4, d // 3)
        for k in range(height):
            inset = min(d // 2 - 1, round(k * d / (2 * height)))
            end = 1 if style in ("moon", "stilt") and k < 2 else 0
            col = mix(roof, P["straw"], 0.12) if style == "stilt" and k % 3 == 0 else roof
            v.box(x - end, y + inset, z + k, x + w + end, y + d - inset, z + k + 1, col)
        v.box(x, y + d // 2 - 1, z + height, x + w, y + d // 2 + 1, z + height + 1, trim)
        if style == "moon":
            for bx in (x, x + w - 1):
                v.box(bx, y, z + 1, bx + 1, y + 2, z + 4, trim)
        if style == "storm":
            # Heavy roof battens and a projecting storm hood.
            for bx in range(x + 2, x + w - 1, 5):
                v.box(bx, y, z + 1, bx + 1, y + d, z + 2, trim)


def regional_building(v, rid, kind):
    style, wall_h, roof_h, trim_h, cloth_h = ARCHITECTURE[rid]
    wall, roof, trim, cloth = map(hexrgb, (wall_h, roof_h, trim_h, cloth_h))
    ground = mix(wall, (114, 102, 94), 0.45)
    timber = mix(trim, P["wood"], 0.28)
    # Voxel coordinates fit the existing service sprite scale. Padding is
    # deliberately shared so anchors remain consistent across services.
    W, D = 22, 17
    x, y = 3, 3
    raised = 4 if style == "stilt" else 2
    z0 = F + raised
    v.box(2, 2, F, 29, 28, F + 1, ground)
    if style == "stilt":
        for px in (4, 12, 24):
            for py in (4, 18):
                v.box(px, py, F, px + 2, py + 2, z0, trim)
    v.box(x, y, z0 - 1, x + W, y + D, z0, timber)

    def shell(sx, sy, w, d, h, open_front=False, roof_style=style):
        v.box(sx, sy, z0, sx + w, sy + d, z0 + h, wall)
        # The front is open for workshops; a dark interior and a bench are
        # visible under the eaves instead of another solid house facade.
        if open_front:
            v.clear(sx + 2, sy + 2, z0 + 1, sx + w - 2, sy + d + 1, z0 + h - 2)
            v.box(sx + 2, sy + 2, z0 + 1, sx + w - 2, sy + 3, z0 + h - 2, mul(wall, 0.58))
        else:
            for wx in range(sx + 3, sx + w - 2, 6):
                v.box(wx - 1, sy + d, z0 + 5, wx + 4, sy + d + 1, z0 + 11, trim)
                v.box(wx, sy + d + 1, z0 + 6, wx + 3, sy + d + 2, z0 + 10, P["lamp"], EMIT)
                v.box(wx + 1, sy + d + 1, z0 + 6, wx + 2, sy + d + 2, z0 + 10, trim)
            for wy in range(sy + 3, sy + d - 2, 6):
                v.box(sx + w, wy, z0 + 6, sx + w + 1, wy + 3, z0 + 10, P["lamp"], EMIT)
        for px in (sx, sx + w - 1):
            v.box(px, sy + d, z0, px + 1, sy + d + 1, z0 + h + 1, trim)
        v.box(sx, sy + d, z0 + h - 1, sx + w, sy + d + 1, z0 + h, trim)
        architectural_roof(v, sx - 1, sy - 1, w + 2, d + 2, z0 + h, roof_style, roof, trim)

    def lantern(px, py, pz):
        v.box(px, py, pz, px + 2, py + 2, pz + 4, trim)
        v.box(px, py + 1, pz + 1, px + 2, py + 2, pz + 3, P["lamp"], EMIT)

    if kind == "market":
        # Two open striped produce stalls with a compact storeroom behind.
        shell(4, 3, 20, 8, 10)
        for sx in (3, 16):
            for px in (sx, sx + 10):
                v.box(px, 17, z0, px + 1, 18, z0 + 12, trim)
                v.box(px, 25, z0, px + 1, 26, z0 + 12, trim)
            for i in range(12):
                v.box(sx + i, 16, z0 + 12, sx + i + 1, 26, z0 + 13,
                      cloth if (i // 3) % 2 == 0 else P["cream"])
            v.box(sx, 21, z0 + 2, sx + 11, 26, z0 + 5, timber)
            for k, color in enumerate((P["red"], P["yellow"], P["green"])):
                v.box(sx + k * 3 + 1, 22, z0 + 5, sx + k * 3 + 3, 25, z0 + 6, color)
        kit.crate(v, 28, 15, 3, 5)
    elif kind == "tavern":
        # An inn with a lower terrace, a long lit upstairs gallery and a
        # projecting balcony. The beer barrels are part of its silhouette.
        shell(3, 3, 23, 13, 19)
        v.box(3, 17, z0, 27, 25, z0 + 1, timber)
        for px in range(4, 27, 4):
            v.box(px, 24, z0, px + 1, 25, z0 + 5, trim)
        v.box(3, 24, z0 + 5, 27, 25, z0 + 6, trim)
        kit.table(v, 6, 19, 6, 4, h=5, top=timber)
        kit.barrel(v, 22, 21, h=6, r=2, c=timber)
        kit.barrel(v, 28, 22, h=7, r=2, c=timber)
        v.box(4, 16, z0 + 13, 25, 20, z0 + 14, trim)
        for px in range(5, 25, 3):
            v.box(px, 19, z0 + 14, px + 1, 20, z0 + 18, trim)
        v.box(4, 19, z0 + 18, 25, 20, z0 + 19, trim)
        lantern(27, 15, z0 + 9)
    elif kind == "workshop":
        shell(3, 3, 21, 17, 14, open_front=True)
        # Tall freestanding gantry and its hanging chain; readable even
        # when the forge roof belongs to a very different regional kit.
        for px in (26, 31):
            v.box(px, 6, z0, px + 1, 8, z0 + 24, trim)
        v.box(24, 6, z0 + 23, 33, 8, z0 + 25, trim)
        v.box(29, 8, z0 + 11, 30, 9, z0 + 23, P["iron"])
        v.box(28, 8, z0 + 10, 31, 10, z0 + 12, P["iron"])
        chimney = mix(ground, P["brick_d"], 0.35)
        v.box(5, 4, z0 + 12, 10, 9, z0 + 27, chimney)
        v.box(4, 3, z0 + 26, 11, 10, z0 + 28, trim)
        kit.anvil(v, 16, 23)
        kit.table(v, 5, 18, 9, 4, h=5, top=timber)
        v.box(6, 7, z0 + 2, 9, 9, z0 + 5, P["fire"], EMIT)
        kit.crate(v, 26, 20, 4, 4)
    elif kind == "quest_board":
        # Public loggia: a small rear office and a broad notice cabinet,
        # surrounded by benches rather than a house with a tiny sign.
        shell(4, 3, 17, 9, 12)
        for px in (5, 23):
            v.box(px, 22, z0, px + 2, 24, z0 + 13, trim)
        v.box(4, 22, z0 + 5, 26, 24, z0 + 14, trim)
        v.box(6, 24, z0 + 6, 24, 25, z0 + 13, timber)
        for px, pz, color in ((7, 8, P["paper"]), (12, 7, P["parch"]), (17, 9, P["cream"]), (21, 7, P["paper"])):
            v.box(px, 25, z0 + pz, px + 3, 26, z0 + pz + 3, color)
        architectural_roof(v, 3, 20, 24, 7, z0 + 14, style, roof, trim)
        kit.bench(v, 6, 16, 12, c=timber)
        lantern(28, 21, z0 + 7)
    elif kind == "navigation":
        # An observatory tower: octagonal-ish plan, projecting top deck,
        # telescope and flag. Its height communicates the service at x1.
        cx, cy = 15, 13
        v.cyl(cx, cy, z0, z0 + 25, 7.5, wall)
        for pz in (z0 + 2, z0 + 13, z0 + 24):
            v.cyl(cx, cy, pz, pz + 1, 8, trim)
        v.box(10, 19, z0 + 17, 13, 21, z0 + 22, P["lamp"], EMIT)
        v.box(21, 11, z0 + 17, 23, 14, z0 + 22, P["lamp"], EMIT)
        v.box(7, 5, z0 + 25, 24, 22, z0 + 26, trim)
        # A half-covered observation platform leaves the telescope visible.
        architectural_roof(v, 6, 4, 18, 10, z0 + 29, style, roof, trim)
        kit.telescope(v, 16, 16, z0 + 26)
        v.box(26, 7, z0, 27, 8, z0 + 38, trim)
        v.box(27, 7, z0 + 33, 32, 8, z0 + 37, cloth)
        for k in range(4):
            v.box(11 + k, 21 + k, F, 19 - k, 22 + k, z0 - k, ground)
    else:
        shell(5, 4, 17, 14, 12)
        v.box(11, 18, z0, 16, 20, z0 + 8, trim)
        v.box(12, 19, z0, 15, 20, z0 + 7, timber)
        kit.plant(v, 23, 20, pot=cloth, h=5)
        v.box(6, 20, F, 11, 22, F + 3, ground)

    # Region-specific structural details remain visible on all six types.
    if style == "stilt":
        for px in (3, 25):
            v.box(px, 2, z0, px + 1, 3, z0 + 15, trim)
            v.box(px - 1, 2, z0 + 13, px + 3, 3, z0 + 14, P["green_d"])
    elif style == "crystal":
        crystal(v, 29, 13, P["glass"], h=12, seed=4)
    elif style in ("arcade", "dome"):
        for px in (3, 25):
            v.cyl(px + 1, 26, z0, z0 + 10, 1.3, wall)
            v.box(px - 1, 24, z0 + 10, px + 3, 28, z0 + 12, trim)
    elif style == "storm":
        for k in range(10):
            v.box(3 + k, 2, z0 + k, 5 + k, 3, z0 + k + 2, trim)
        lantern(29, 24, z0 + 8)
    elif style == "moon":
        for px in (3, 25):
            lantern(px, 25, z0 + 8)
    elif style == "terrace":
        for py in (3, 13):
            v.box(28, py, z0, 29, py + 1, z0 + 20, timber)
        for pz in (z0 + 6, z0 + 13, z0 + 20):
            v.box(27, 2, pz, 31, 16, pz + 1, timber)
    elif style == "shell":
        for k in range(7):
            v.box(27, 12 + k, z0 + k, 29, 14 + k, z0 + k + 2, P["cream"])
        coral(v, 29, 23, cloth)


def building_table(pal, rid="dawnwater"):
    # pal remains an argument for the public generator contract. Materials
    # are authored by region to keep architectural identity reproducible.
    return {kind: (lambda v, k=kind: regional_building(v, rid, k), (36, 32, 52))
            for kind in ("market", "tavern", "workshop", "quest_board", "navigation", "house")}


# ------------------------------------------------------------ foam/fx ----

def foam_frames():
    out = []
    for f in range(4):
        a = np.zeros((6, 12, 4), np.uint8)
        rng = np.random.default_rng(f)
        for i in range(12):
            h = 1 + int(1.5 + math.sin(i * 0.9 + f * 1.6) * 1.2)
            for y in range(6 - h - 1, 5):
                if rng.random() < 0.85:
                    a[y, i] = (240, 250, 255, 230 if y > 2 else 200)
        out.append(a)
    return np.concatenate(out, 1)


# ------------------------------------------------------------ chart icons ----

def chart_icons():
    """16x16 location icons by type plus ship marker and fog marker."""
    icons = {}

    def new():
        return Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def out(im):
        a = np.array(im)
        m = a[..., 3] > 0
        o = np.zeros_like(m)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
        o &= ~m
        a[o] = (42, 30, 40, 255)
        return a

    im = new(); d = ImageDraw.Draw(im)
    d.rectangle([4, 7, 11, 12], fill="#f1e3c0"); d.polygon([(3, 7), (8, 2), (13, 7)], fill="#c8463c")
    d.rectangle([7, 9, 8, 12], fill="#8e5531"); icons["port"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.ellipse([2, 7, 13, 13], fill="#e8cf8f"); d.ellipse([4, 4, 11, 10], fill="#4fa04a"); d.line([8, 4, 8, 1], fill="#8e5531")
    icons["island"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.polygon([(2, 13), (8, 2), (14, 13)], fill="#6f6a64"); d.rectangle([6, 8, 9, 13], fill="#2a2228"); icons["dungeon"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.polygon([(2, 10), (14, 10), (12, 13), (4, 13)], fill="#8e5531"); d.line([8, 10, 9, 3], fill="#5e3620", width=1)
    d.polygon([(9, 3), (13, 6), (9, 7)], fill="#e9dfc4"); icons["wreck"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.ellipse([2, 4, 13, 13], fill="#b4553e"); d.ellipse([5, 6, 10, 11], fill="#e8cf8f")
    d.line([4, 2, 11, 9], fill="#c4ccd8"); d.line([11, 2, 4, 9], fill="#c4ccd8"); icons["arena"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (10, 6), (15, 7), (11, 10), (12, 15), (8, 12), (4, 15), (5, 10), (1, 7), (6, 6)], fill="#b49ae0")
    icons["secret"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 12, 12], fill="#9a8a70"); d.text((5, 2), "?", fill="#f1e3c0"); icons["unknown"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.polygon([(2, 9), (14, 9), (12, 13), (4, 13)], fill="#8e5531"); d.line([8, 9, 8, 1], fill="#5e3620")
    d.polygon([(8, 2), (13, 7), (8, 8)], fill="#f6f4ee"); d.polygon([(8, 3), (4, 7), (8, 8)], fill="#e9dfc4")
    d.point([8, 1], fill="#c8463c"); icons["ship"] = out(im)
    im = new(); d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 11, 11], outline="#f0c04e", width=2); icons["target"] = out(im)
    return icons


def build():
    world = json.loads((GAME / "data" / "world.json").read_text())
    regions = {r["id"]: r for r in world["REGIONS"]}
    (OUT / "env").mkdir(parents=True, exist_ok=True)
    meta = {"tile": [TW, TH], "terrain": {}, "ground": GROUND, "sides": SIDES, "ground2": GROUND2,
            "sideSets": {k: list(v) for k, v in SIDE_SETS.items()}, "water": {k: list(v) for k, v in WATER_TILES.items()},
            "waterRows": {"deep": 0, "shallow": 1}, "waterFrames": 4, "props": {}, "buildings": {}}
    prev_tiles = []
    for rid, R in regions.items():
        atlas = region_terrain(rid, R["palette"])
        meta["terrain"][rid] = f"res://assets/gen/env/terrain_{rid}.png"
        prev_tiles.append(atlas)
    record("game/assets/gen/env/terrain_<region>.png", f"{TW * TERRAIN_COLS}x{TH * 8}",
           "row0 water x4 (+open sea x4), row1 shallow/reef/lagoon x4, row2 16 ground tiles, row3 5 cliff sides, "
           "rows 4-6 single-face, low-ledge and top-band sides, row7 15 coast and town ground tiles",
           "procedural pixel tiles (gen_env.py)", "TileMapLayer atlases for sea, islands, ports, arenas")

    # props
    pk = Packer(1024)
    for name, (fn, size, anchor) in COMMON_PROPS.items():
        v = Vol(*size)
        fn(v)
        spr, off = vol_sprite(v, anchor)
        pk.add(name, spr, anchor=list(off))
    for rid, R in regions.items():
        table = prop_table(R["palette"])
        for name in sorted(set(REGION_PROPS[rid]) | {"ore", "herb", "gate", "rock", "bush"} | set(COAST_PROPS) | set(SET_PROPS)):
            fn, size, anchor = table[name]
            v = Vol(*size)
            fn(v)
            spr, off = vol_sprite(v, anchor)
            pk.add(f"{rid}:{name}", spr, anchor=list(off))
    rects, (W, H) = pk.pack(OUT / "env" / "props.png")
    meta["props"] = rects
    meta["regionProps"] = REGION_PROPS
    record("game/assets/gen/env/props.png", f"{W}x{H}", f"{len(rects)} sprites", "voxel render (gen_env.py)",
           "island/port/arena props and interactables")

    # port buildings
    pk = Packer(1024)
    for rid, R in regions.items():
        for name, (fn, size) in building_table(R["palette"], rid).items():
            v = Vol(*size)
            fn(v)
            # anchor at the front-centre ground point
            spr, off = vol_sprite(v, (size[0] / 2, size[1] / 2, F))
            pk.add(f"{rid}:{name}", spr, anchor=list(off))
    brects, (BW, BH) = pk.pack(OUT / "env" / "buildings.png")
    meta["buildings"] = brects
    record("game/assets/gen/env/buildings.png", f"{BW}x{BH}", f"{len(brects)} sprites", "voxel render (gen_env.py)",
           "port buildings per region (market, tavern, workshop, quest board, navigation, house)")

    # Lit-window overlay: the emissive window pixels of every building, in
    # the same atlas layout, drawn over the building after dark.
    b_arr = np.array(Image.open(OUT / "env" / "buildings.png").convert("RGBA"))
    lamp = hexrgb(P["lamp"]) if isinstance(P["lamp"], str) else tuple(P["lamp"][:3])
    win = (b_arr[..., 0] == lamp[0]) & (b_arr[..., 1] == lamp[1]) & (b_arr[..., 2] == lamp[2]) & (b_arr[..., 3] > 0)
    lit = np.zeros_like(b_arr)
    lit[win] = (255, 232, 160, 255)
    save_png(lit, OUT / "env" / "buildings_lit.png")
    record("game/assets/gen/env/buildings_lit.png", f"{BW}x{BH}", f"{len(brects)} window masks",
           "derived from the emissive window voxels (gen_env.py)", "lit windows on port buildings at night")

    save_png(foam_frames(), OUT / "env" / "foam.png")
    record("game/assets/gen/env/foam.png", "48x6", "4 frames 12x6", "procedural", "hull waterline foam")

    icons = chart_icons()
    strip = np.concatenate([icons[k] for k in icons], 1)
    save_png(strip, OUT / "env" / "chart_icons.png")
    meta["chartIcons"] = list(icons)
    record("game/assets/gen/env/chart_icons.png", f"{16 * len(icons)}x16", f"{len(icons)} icons", "procedural",
           "location type icons in lists (the chart itself uses chart_marks.png from gen_chart.py)")
    save_json(meta, OUT / "env" / "env.json")

    # previews
    a = np.concatenate(prev_tiles[:5], 0)
    Image.fromarray(a).resize((a.shape[1] * 3, a.shape[0] * 3), Image.NEAREST).save(PREVIEW / "env_terrain.png")
    props_img = Image.open(OUT / "env" / "props.png")
    bg = Image.new("RGBA", props_img.size, (120, 150, 110, 255))
    bg.alpha_composite(props_img)
    bg.resize((bg.width * 2, bg.height * 2), Image.NEAREST).save(PREVIEW / "env_props.png")
    b_img = Image.open(OUT / "env" / "buildings.png")
    bg = Image.new("RGBA", b_img.size, (120, 150, 110, 255))
    bg.alpha_composite(b_img)
    bg.save(PREVIEW / "env_buildings.png")
    return meta


if __name__ == "__main__":
    m = build()
    print(len(m["props"]), len(m["buildings"]))
