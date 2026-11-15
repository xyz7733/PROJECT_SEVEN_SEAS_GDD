"""World sea chart.

One merged chart of all ten seas, plus what the game needs to draw on it:

- **Chart** (`env/chart_world.png`). The ten seas are laid out in their
  order of progression on two rows of five. Seas 1-5 run west to east
  along the north row and seas 6-10 run back east to west along the south
  row. A mainland coast separates the two rows, and the only passage
  between them is a strait at the east end, between seas 5 and 6. Distance
  on the chart therefore follows the game's travel cost, which grows with
  the difference in sea order. The seas share one continuous set of depth
  bands and contour lines, and the water colour changes from sea to sea
  through a dithered band under a dashed boundary line. Each sea has a
  compass rose with rhumb lines and a small vignette. A graduated neat line
  frames the whole chart.
- **Islands** (`env/chart_isles.png`). One coastline silhouette per
  location, authored from its type and a per-location seed: bays, coves,
  headlands, islets and rocks, a varied beach, relief bands and type
  features (harbour, trees, cave, atoll lagoon, reef wreck). The chart
  itself shows no islands; the game draws each one only once its location
  is known, so the chart reveals nothing.
- **Markers** (`env/chart_marks.png`). Map markers in three tiers: port
  badges, smaller location discs, and hollow ink versions for places that
  are charted but not yet visited. Also the ship, the last safe port
  anchor, the objective pin and the cleared badge.
- **Fog** (`env/chart_fog.png`, `env/chart_fogkey.png`, half resolution).
  Cloud-bank art, and a key image with the sea of each fog pixel (taken
  from the cloud puff that covers it, so the edge of a locked sea is a
  scalloped cloud bank), a land flag and an edge-noise value. The game
  builds the fog from these and the save: dense cloud over locked seas,
  light haze over unexplored water in open seas, and clearings around
  known places and charted routes.

Everything is built from smooth functions, ordered dithering and
morphological clean-up, so the edges are clean pixel lines with no
per-pixel noise.
"""
from __future__ import annotations

import json
import math

import numpy as np
from PIL import Image

from lib.common import GAME, OUT, PREVIEW, Packer, record, save_json, save_png
from lib.vox import hexrgb, mix, mul

SW, SH = 400, 225            # one sea
COLS = 5
BAND = 60                    # mainland between the two rows
M = 8                        # neat-line frame
W = COLS * SW + 2 * M        # 2016
H = 2 * SH + BAND + 2 * M    # 526
YB0 = M + SH                 # top of the mainland band
YB1 = YB0 + BAND             # bottom of the mainland band
YMID = (YB0 + YB1) / 2.0
XS = M + 4 * SW + SW // 2    # strait centre (between seas 5 and 6)
FOG = 2                      # fog cell size in chart pixels
FW, FH = W // FOG, H // FOG

PAPER = (236, 224, 192)
INK = (58, 44, 42)
LAND = mix(PAPER, (196, 170, 120), 0.14)
SAND = mix(PAPER, (214, 184, 120), 0.45)
VIGNETTE = {
    "dawnwater": "lookout", "emberreach": "forge", "verdant_maw": "root_shrine", "glass_current": "crystal",
    "crown_shoals": "archive", "stormbelt": "storm_beacon", "moonwake": "observatory", "ashen_trench": "seal",
    "leviathan_ring": "bone_arch", "grand_horizon": "armillary",
}
CHART_ARCHITECTURE = {
    "dawnwater": ((83, 130, 149), (236, 221, 178)),
    "emberreach": ((188, 116, 76), (105, 87, 82)),
    "verdant_maw": ((105, 138, 86), (195, 174, 122)),
    "glass_current": ((147, 198, 203), (225, 229, 216)),
    "crown_shoals": ((68, 91, 128), (216, 186, 133)),
    "stormbelt": ((80, 105, 116), (159, 168, 158)),
    "moonwake": ((82, 79, 118), (164, 172, 194)),
    "ashen_trench": ((163, 117, 90), (107, 102, 108)),
    "leviathan_ring": ((120, 166, 149), (215, 211, 180)),
    "grand_horizon": ((193, 165, 104), (238, 229, 200)),
}
TYPE_R = {"port": 1.0, "island": 1.0, "dungeon": 0.9, "wreck": 0.78, "arena": 0.86, "secret": 0.62}
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32)

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (-1, -1), (1, -1), (-1, 1))


# ------------------------------------------------------------ mask kit ----
def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, dx), min(w, w + dx)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    if xs1 > xs0 and ys1 > ys0:
        out[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def dilate(m, n=N4):
    o = m.copy()
    for dx, dy in n:
        o |= shift(m, dx, dy)
    return o


def erode(m, n=N4):
    o = m.copy()
    for dx, dy in n:
        o &= shift(m, dx, dy)
    return o


def clean(m):
    """Closing then opening: fills one-pixel notches, removes spurs."""
    m = erode(dilate(m))
    return dilate(erode(m))


def dist_in(m, maxd=24):
    """1 on the edge pixels of the mask, rising inward (octagonal metric)."""
    d = np.zeros(m.shape, np.int32)
    cur = m.copy()
    for i in range(1, maxd + 1):
        if not cur.any():
            break
        d[cur] = i
        cur = erode(cur, N4 if i % 2 else N8)
    return d


def dist_out(m, maxd=8):
    """Distance outside the mask (0 inside and beyond maxd)."""
    d = np.zeros(m.shape, np.int32)
    cur = m.copy()
    for i in range(1, maxd + 1):
        nxt = dilate(cur, N4 if i % 2 else N8)
        d[nxt & ~cur] = i
        cur = nxt
    return d


def paint(img, mask, col):
    img[mask, :3] = col
    img[mask, 3] = 255


def blend(img, mask, col, t):
    c = np.array(col, np.float32)
    img[mask, :3] = (img[mask, :3].astype(np.float32) * (1 - t) + c * t).round().astype(np.uint8)


def window(cx, cy, r, w=W, h=H):
    """A square window of the chart around (cx, cy): slices plus local offsets."""
    x0, x1 = max(0, int(cx - r)), min(w, int(cx + r) + 1)
    y0, y1 = max(0, int(cy - r)), min(h, int(cy + r) + 1)
    x1, y1 = max(x0, x1), max(y0, y1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    return (slice(y0, y1), slice(x0, x1)), (xx - cx).astype(np.float32), (yy - cy).astype(np.float32)


def smooth_noise(rng, w, h, cells=4, octaves=3):
    f = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        cx = cells * 2 ** o
        cy = max(2, int(round(cx * h / w)))
        g = (rng.random((cy + 1, cx + 1)) * 255).astype(np.uint8)
        f += amp * np.asarray(Image.fromarray(g).resize((w, h), Image.BICUBIC), np.float32) / 255.0
        amp *= 0.45
    f -= f.min()
    return f / max(1e-6, f.max())


def water_tones(pal):
    sea, deep = hexrgb(pal["sea"]), hexrgb(pal["deep"])
    return [
        mix(mix(sea, PAPER, 0.60), (255, 255, 255), 0.06),  # shallows (coasts, island rings)
        mix(sea, PAPER, 0.47),
        mix(sea, PAPER, 0.37),
        mix(deep, PAPER, 0.30),
        mul(mix(deep, PAPER, 0.21), 0.94),
    ]


# ------------------------------------------------------------- layout ----
def tile_of(order):
    """(column, row) of the sea with this progression order (1..10)."""
    row = 0 if order <= 5 else 1
    col = order - 1 if row == 0 else 10 - order
    return col, row


def tile_origin(order):
    col, row = tile_of(order)
    return M + col * SW, M + row * (SH + BAND)


def loc_points(world):
    """[(location id, region index, chart x, chart y, type)] for every location."""
    out = []
    for i, R in enumerate(world["REGIONS"]):
        ox, oy = tile_origin(R["order"])
        for lid in R["locs"]:
            L = world["LOCATIONS"][lid]
            out.append((lid, i, ox + L["x"] * SW, oy + L["y"] * SH, L["type"]))
    return out


def isle_radius(pts, lid, ri, x, y, typ):
    nn = min(math.hypot(x - q[2], y - q[3]) for q in pts if q[1] == ri and q[0] != lid)
    return max(5.0, min(17.0, max(8.0, 0.33 * nn)) * TYPE_R.get(typ, 1.0)), nn


# ------------------------------------------------------------ ASCII art ----
ART = {
    "lookout": [
        "......XX.......", ".....XooX......", "....XXXXXX.....",
        ".....XooX......", ".....XooX......", ".....XooX......",
        "....XXooXX.....", "...XXooooXX....", "..XXXXXXXXXX...",
        "....X....X.....", "..XX..XX..XX...",
    ],
    "forge": [
        "....XX.........", "....XX..X......", "....XX.XX......",
        "..XXXXXXXXXX...", "..XooooooooX...", "..XoXXXXXXoX...",
        "..XoXooooXoX...", "..XoXoXXoXoX...", "..XXXXXXXXXX...",
        "....XX..XX.....", "...XXXXXXXX....",
    ],
    "root_shrine": [
        "..X.........X..", "...X..X....X...", "....X.X...X....",
        "....XXXXXXX....", "...XoooooooX...", "...XoXXXXXoX...",
        "..XXoX...XoXX..", ".X.XoX...XoX.X.", "X..XXXX.XXXX..X",
        "..XX.......XX..", ".X...........X.",
    ],
    "archive": [
        ".......X.......", "......XXX......", ".....XoooX.....",
        "...XXXXXXXXX...", "..XoooooooooX..", "..XXXXXXXXXXX..",
        "...X.X.X.X.X...", "...X.X.X.X.X...", "...X.X.X.X.X...",
        "..XXXXXXXXXXX..", ".XXXXXXXXXXXXX.",
    ],
    "storm_beacon": [
        "...XXX.........", "..XoooX...X....", ".XoooooX.XX....",
        "..XXXXX...XX...", "....X....XX....", "...XXX....X....",
        "...XoX.........", "...XoX.........", "..XXoXX........",
        ".XXXXXXX.......", "X..X..X..X..X..",
    ],
    "observatory": [
        ".......X.......", "......XXX......", "....XXoooXX....",
        "...XoooooooX...", "..XooooooXXX...", "..XXXXXXXXXXX..",
        "..XoXoooooXoX..", "..XoXoooooXoX..", "..XoXoooooXoX..",
        "..XXXXXXXXXXX..", ".XXXXXXXXXXXXX.",
    ],
    "seal": [
        ".....XXXXX.....", "...XX.....XX...", "..X...XXX...X..",
        ".X..XX...XX..X.", "X..X...X...X..X", "X.X...XXX...X.X",
        "X..X...X...X..X", ".X..XX...XX..X.", "..X...XXX...X..",
        "...XX.....XX...", ".....XXXXX.....",
    ],
    "bone_arch": [
        ".....XXXXX.....", "...XX..X..XX...", "..X....X....X..",
        ".X..X..X..X..X.", ".X..X..X..X..X.", "X...X..X..X...X",
        "X...X..X..X...X", "X...X..X..X...X", "XX.XX.XXX.XX.XX",
        "..X..X...X..X..", ".X..X.....X..X.",
    ],
    "armillary": [
        "......XXX......", "....XX.X.XX....", "...X..XXX..X...",
        "..X..X.X.X..X..", ".XXXXXXXXXXXXX.", "..X..X.X.X..X..",
        "...X..XXX..X...", "....XX.X.XX....", "......XXX......",
        "......XXX......", "....XXXXXXX....",
    ],
    "ship": [
        "........X.........",
        "........XX........",
        "........XoX.......",
        "........XooX......",
        "........XoooX.....",
        "........XooooX....",
        "........XoooooX...",
        "........X.........",
        "XXXXXXXXXXXXXXXXXX",
        ".XooooooooooooooX.",
        "..XXXXXXXXXXXXXX..",
    ],
    "whale": [
        "..............X..X..",
        "...............XX...",
        "....XXXXXXXX....X...",
        "..XXooooooooXX..X...",
        ".XoooooooooooooXX...",
        "XoXoooooooooooooX.XX",
        ".XXXXXXXXXXXXXXXXXX.",
    ],
    "serpent": [
        "..XX........XX........XX..",
        ".XooX......XooX......XooX.",
        "Xo..oX....Xo..oX....Xo..oX",
        "......X..X......X..X....XX",
        ".......XX........XX.....X.",
    ],
    "storm": [
        "....XXXX.......",
        "..XXooooXXX....",
        ".XoooooooooXX..",
        "XoooooooooooooX",
        ".XXXXXXXXXXXXX.",
        "......XX.......",
        ".....XX........",
        "......XX.......",
        ".......X.......",
    ],
    "gulls": [
        "X...X........",
        ".X.X.....X..X",
        "..X.......XX.",
        ".............",
        "....X..X.....",
        ".....XX......",
    ],
    "kelp": [
        ".X...X...X.",
        "X...X...X..",
        ".X...X...X.",
        "..X...X...X",
        ".X...X...X.",
        "X...X...X..",
        ".X...X...X.",
        "XXXXXXXXXXX",
    ],
    "crystal": [
        "...X......X.",
        "..XoX....XoX",
        ".XoooX..XooX",
        "XoooooX.XooX",
        ".XoooX...XX.",
        "..XoX.......",
        "...X........",
    ],
}


def stamp_art(img, name, cx, cy):
    """Draws a vignette in chart ink, centred on (cx, cy)."""
    if name in ART:
        rows = ART[name]
        h, w = len(rows), len(rows[0])
        x0, y0 = int(cx - w / 2), int(cy - h / 2)
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                x, y = x0 + i, y0 + j
                if 0 <= x < W and 0 <= y < H:
                    c = tuple(int(v) for v in img[y, x, :3])
                    img[y, x, :3] = mix(c, INK, 0.55) if ch == "X" else mix(c, PAPER, 0.35)
        return
    sl, dx, dy = window(cx, cy, 12)
    sub = img[sl]
    r = np.hypot(dx, dy)
    ring = np.zeros(r.shape, bool)
    fill = np.zeros(r.shape, bool)
    if name == "moon":
        fill = (r <= 6.5) & ~(np.hypot(dx - 3, dy - 2) <= 5.5)
        ring = dilate(fill) & ~fill
    elif name == "sun":
        fill = r <= 4.5
        ring = dilate(fill) & ~fill
        ang = np.arctan2(dy, dx)
        ring |= (r >= 7) & (r <= 9.5) & (np.abs(((ang * 8 / np.pi) + 0.5) % 2 - 1) < 0.22)
    elif name == "whirl":
        ang = np.arctan2(dy, dx)
        ring = (np.abs(((r - 1.6 * (ang + np.pi)) % 6.0) - 3.0) < 0.6) & (r <= 10)
    blend(sub, fill, PAPER, 0.35)
    blend(sub, ring, INK, 0.55)


def draw_rose(img, cx, cy):
    sl, dx, dy = window(cx, cy, 26)
    sub = img[sl]
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    ring = (r >= 13.0) & (r < 14.2)
    ticks = (r >= 14.2) & (r < 16.0) & (np.abs(((ang * 16 / np.pi) + 0.5) % 1 - 0.5) < 0.12)
    blend(sub, r < 13.0, PAPER, 0.45)
    blend(sub, ring | ticks, INK, 0.70)
    # eight-point star: long cardinal points, short intercardinal points
    star = np.zeros(r.shape, bool)
    dark = np.zeros(r.shape, bool)
    for k in range(8):
        a = k * math.pi / 4 - math.pi / 2
        ln = 12.0 if k % 2 == 0 else 7.0
        wd = 3.2 if k % 2 == 0 else 2.2
        ux, uy = math.cos(a), math.sin(a)
        along = dx * ux + dy * uy
        across = -dx * uy + dy * ux
        m = (along >= 0) & (along <= ln) & (np.abs(across) <= wd * (1 - along / ln))
        star |= m
        dark |= m & (across > 0)
    along, across = -dy, dx
    north = (along >= 0) & (along <= 12.0) & (np.abs(across) <= 3.2 * (1 - along / 12.0))
    paint(sub, star & ~dark, PAPER)
    paint(sub, star & dark, mix(INK, PAPER, 0.25))
    paint(sub, north & ~dark, (214, 84, 64))
    paint(sub, north & dark, (150, 44, 40))
    paint(sub, r <= 1.5, (216, 168, 56))
    # "N" above the rose (5 x 5 pixel letter)
    for (i, j) in ((0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (1, 1), (2, 2), (3, 3), (4, 0), (4, 1), (4, 2), (4, 3), (4, 4)):
        x, y = int(cx - 2 + i), int(cy - 23 + j)
        if 0 <= x < W and 0 <= y < H:
            img[y, x, :3] = INK


def draw_border(img):
    """Graduated neat line: ink outer line, alternating scale, ink inner line."""
    light, dark = PAPER, mix(INK, PAPER, 0.45)
    img[:1, :, :3] = INK
    img[-1:, :, :3] = INK
    img[:, :1, :3] = INK
    img[:, -1:, :3] = INK
    for y in range(1, M):
        for x in range(W):
            c = light if y == 1 else INK if y == M - 1 else (dark if (x // 10) % 2 == 0 else light)
            img[y, x, :3] = c
            img[H - 1 - y, x, :3] = c
    for x in range(1, M):
        for y in range(M - 1, H - M + 1):
            c = light if x == 1 else INK if x == M - 1 else (dark if (y // 10) % 2 == 0 else light)
            img[y, x, :3] = c
            img[y, W - 1 - x, :3] = c


# ---------------------------------------------------------- the chart ----
def region_map(world):
    """Sea index per chart pixel; neighbouring seas meet in a dithered band."""
    regions = world["REGIONS"]
    by_order = {R["order"]: i for i, R in enumerate(regions)}
    grid = np.array([[by_order[c + 1] for c in range(COLS)], [by_order[10 - c] for c in range(COLS)]])
    yy, xx = np.mgrid[0:H, 0:W]
    d = (BAYER4[yy % 4, xx % 4] + 0.5) / 16.0 - 0.5
    col = np.zeros((H, W), np.int32)
    for c in range(1, COLS):
        col += ((xx - (M + c * SW)) + d * 16.0 > 0).astype(np.int32)
    row = ((yy - YMID) + d * 16.0 > 0).astype(np.int32)
    return grid[row, col]


def mainland(world, rng, pts):
    yy, xx = np.mgrid[0:H, 0:W]
    xs = np.arange(W, dtype=np.float32)
    ph = rng.uniform(0, 2 * np.pi, 8)

    def wob(a, b, c):
        return 0.50 * np.sin(xs * 0.006 + ph[a]) + 0.32 * np.sin(xs * 0.021 + ph[b]) + 0.18 * np.sin(xs * 0.071 + ph[c])

    top = YB0 + 3 + 13 * wob(0, 1, 2)
    bot = YB1 - 3 - 13 * wob(3, 4, 5)
    land = (yy >= top[None, :]) & (yy <= bot[None, :])
    # tapered capes reaching into the seas, some bent like hooks
    xs_c = np.sort(rng.uniform(M + 30, W - M - 30, 16))
    for cx in xs_c:
        cx = float(cx)
        if abs(cx - XS) < 110:
            continue
        side = -1 if rng.random() < 0.5 else 1
        ln = float(rng.uniform(12, 24))
        hw = float(rng.uniform(9, 15))
        bend = float(rng.uniform(-0.5, 0.5))
        base = (top[int(cx)] if side < 0 else bot[int(cx)]) - side * 3
        sl, dx, dy = window(cx, base, ln + hw + 4)
        along = dy * side
        t = np.clip(along / ln, 0, 1)
        off = dx - bend * ln * t * t
        land[sl] |= (along >= 0) & (along <= ln) & (np.abs(off) <= hw * np.maximum(0, 1 - t ** 1.6) ** 0.6 + 0.6)
    # bays bitten into the coast
    for _ in range(10):
        cx = float(rng.uniform(M + 30, W - M - 30))
        if abs(cx - XS) < 120:
            continue
        side = -1 if rng.random() < 0.5 else 1
        base = top[int(cx)] if side < 0 else bot[int(cx)]
        rw, rd = float(rng.uniform(8, 16)), float(rng.uniform(7, 14))
        sl, dx, dy = window(cx, base, rw + 2)
        land[sl] &= ~((dx / rw) ** 2 + (dy / rd) ** 2 <= 1)
    # offshore islets along the coast
    for _ in range(26):
        cx = float(rng.uniform(M + 20, W - M - 20))
        side = -1 if rng.random() < 0.5 else 1
        base = top[int(cx)] if side < 0 else bot[int(cx)]
        cy = base + side * float(rng.uniform(7, 15))
        r = float(rng.uniform(1.6, 3.6))
        sl, dx, dy = window(cx, cy, r + 1)
        land[sl] |= dx * dx + dy * dy * 1.4 <= r * r
    # the strait between seas 5 and 6
    rel = np.clip((yy - YMID) / (BAND / 2.0), -1.6, 1.6)
    sx = XS + 6 * np.sin(yy * 0.08 + ph[6])
    land &= ~(np.abs(xx - sx) < 24 + 16 * rel ** 2)
    # keep every island's surroundings clear: coves where the coast comes close
    for (lid, ri, x, y, typ) in pts:
        rad, _nn = isle_radius(pts, lid, ri, x, y, typ)
        need = rad * 1.75 + 9
        sl, dx, dy = window(x, y, need + 1)
        land[sl] &= ~(np.hypot(dx, dy) < need)
    land[:M, :] = False
    land[H - M:, :] = False
    return clean(land)


def world_sheet(world, seed=7):
    rng = np.random.default_rng(seed)
    regions = world["REGIONS"]
    pts = loc_points(world)
    reg = region_map(world)
    land = mainland(world, rng, pts)
    water = ~land
    tones = np.array([water_tones(R["palette"]) for R in regions], np.uint8)  # (10, 5, 3)
    yy, xx = np.mgrid[0:H, 0:W]
    img = np.zeros((H, W, 4), np.uint8)
    img[..., 3] = 255
    # depth bands: one smooth field across all seas, shallower towards the mainland
    f = smooth_noise(rng, W, H, 12, 3)
    dl = dist_out(land, 40)
    near = np.where(land, 0, np.where(dl == 0, 40, dl)).astype(np.float32) / 40.0
    f = 0.72 * f + 0.28 * near
    th = np.quantile(f[water], [0.22, 0.50, 0.78])
    band = np.digitize(f, th)  # 0 shallow .. 3 deep
    img[..., :3] = tones[reg, band + 1]
    for b in range(3):
        m = band == b
        edge = m & ((shift(band, 1, 0) > b) | (shift(band, 0, 1) > b) | (shift(band, -1, 0) > b) | (shift(band, 0, -1) > b))
        if b >= 1:
            edge &= ((xx + yy) % 3) != 0
        blend(img, edge & water, INK, 0.16 + 0.04 * b)
    # a compass rose per sea, in the corner farthest from its locations
    near_land = dilate(dilate(land, N8), N8)
    roses = {}
    rh = np.zeros((H, W), bool)
    for i, R in enumerate(regions):
        ox, oy = tile_origin(R["order"])
        mine = [p for p in pts if p[1] == i]
        cands = [(ox + 46, oy + 42), (ox + SW - 46, oy + 42), (ox + 46, oy + SH - 42), (ox + SW - 46, oy + SH - 42)]
        clear = [c for c in cands if not land[max(0, c[1] - 26):c[1] + 27, max(0, c[0] - 26):c[0] + 27].any()] or cands
        rose = max(clear, key=lambda c: min(math.hypot(c[0] - p[2], c[1] - p[3]) for p in mine))
        roses[R["id"]] = rose
        tile = np.zeros((H, W), bool)
        tile[oy:oy + SH, ox:ox + SW] = True
        for k in range(16):
            a = k * math.pi / 8
            s = np.arange(20, math.hypot(SW, SH), 0.5)
            px = np.round(rose[0] + np.cos(a) * s).astype(int)
            py = np.round(rose[1] + np.sin(a) * s).astype(int)
            ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
            line = np.zeros((H, W), bool)
            line[py[ok], px[ok]] = True
            rh |= line & tile
    blend(img, rh & ~near_land, INK, 0.10)
    # wave marks on a jittered grid (light, four-pixel arcs)
    waves = np.zeros((H, W), bool)
    for gy in range(M + 10, H - M - 8, 18):
        for gx in range(M + 8 + (gy // 18 % 2) * 13, W - M - 10, 26):
            x = int(gx + rng.integers(-5, 6))
            y = int(gy + rng.integers(-4, 5))
            if any(math.hypot(x - r[0], y - r[1]) < 30 for r in roses.values()):
                continue
            if near_land[max(0, y - 2):y + 3, max(0, x - 2):x + 6].any():
                continue
            for (ox, oy) in ((0, 0), (1, 1), (2, 1), (3, 0)):
                waves[y + oy, x + ox] = True
    blend(img, waves, (255, 255, 255), 0.22)
    # sea boundaries: dashed ink lines along the seams, in open water only
    bound = np.zeros((H, W), bool)
    for c in range(1, COLS):
        x = M + c * SW
        bound[:, x] = ((yy[:, x] // 3) % 2 == 0)
    sy = int(round(YMID))
    bound[sy, :] = ((xx[sy, :] // 3) % 2 == 0)
    bound[:M + 2, :] = False
    bound[H - M - 2:, :] = False
    blend(img, bound & ~near_land, INK, 0.30)
    # mainland: shallows, contour, beach, hatched paper, ranges, forests, rivers
    do = dist_out(land, 5)
    paint(img, (do >= 1) & (do <= 3), tones[reg, 0][(do >= 1) & (do <= 3)])
    blend(img, do == 4, INK, 0.22)
    di = dist_in(land, 10)
    paint(img, land, LAND)
    blend(img, land & (((xx - yy) % 4) == 0) & (di >= 4), INK, 0.12)
    paint(img, (di == 2) | (di == 3), SAND)
    paint(img, di == 1, mix(INK, SAND, 0.25))
    relief = smooth_noise(rng, W, 1, 40, 2)[0]
    x = M + 14
    while x < W - M - 14:
        y = int(round(YMID + 4 * math.sin(x * 0.045)))
        if abs(x - XS) > 64 and di[y, x] >= 9:
            if relief[x] > 0.52:
                # a range: three to five peaks, the middle ones tallest
                n = int(rng.integers(3, 6))
                for k in range(n):
                    hk = 4 + int(round(3 * math.sin(math.pi * (k + 0.5) / n))) + int(rng.integers(0, 2))
                    px, py = x + k * 5, y + int(rng.integers(-1, 2)) + (2 if k % 2 else 0)
                    if px < W - M - 10 and di[py, px] >= 8:
                        draw_peak(img, px, py, hk)
                x += 5 * n + int(rng.integers(10, 22))
                continue
            if relief[x] < 0.32:
                for _ in range(int(rng.integers(4, 8))):
                    draw_tree(img, x + int(rng.integers(-6, 7)), y + int(rng.integers(-7, 8)), di)
                x += int(rng.integers(14, 22))
                continue
        x += 6
    for _ in range(5):
        draw_river(img, land, di, rng, tones, reg)
    # one regional vignette per sea in its clearest open water
    for i, R in enumerate(regions):
        ox, oy = tile_origin(R["order"])
        mine = [p for p in pts if p[1] == i]
        rose = roses[R["id"]]
        best, best_d = None, -1.0
        for gy in range(oy + 30, oy + SH - 26, 6):
            for gx in range(ox + 34, ox + SW - 34, 6):
                if near_land[max(0, gy - 14):gy + 15, max(0, gx - 14):gx + 15].any():
                    continue
                d = min(math.hypot(gx - p[2], gy - p[3]) for p in mine)
                d = min(d, math.hypot(gx - rose[0], gy - rose[1]) - 10)
                if d > best_d:
                    best, best_d = (gx, gy), d
        if best is not None and best_d > 22:
            stamp_art(img, VIGNETTE.get(R["id"], "ship"), best[0], best[1])
    for rose in roses.values():
        draw_rose(img, rose[0], rose[1])
    draw_border(img)
    return img, reg, land, roses


def draw_peak(img, x, y, h):
    """A mountain in chart style: ink outline, lit west face, shaded east
    face and a pale cap on the tall ones."""
    for j in range(h):
        for i in range(-j, j + 1):
            px, py = x + i, y - h + 1 + j
            if abs(i) == j:
                img[py, px, :3] = mix(INK, LAND, 0.30)
            elif h >= 6 and j <= 2:
                img[py, px, :3] = (250, 248, 240)
            elif i < 0:
                img[py, px, :3] = mix(LAND, (255, 252, 236), 0.45)
            else:
                img[py, px, :3] = mix(LAND, INK, 0.18)


def draw_tree(img, x, y, di):
    if di[y, x] < 4:
        return
    dark, light = (86, 118, 70), (128, 160, 96)
    for (i, j) in ((0, -1), (-1, 0), (0, 0), (1, 0)):
        img[y + j, x + i, :3] = dark
    img[y - 1, x, :3] = light
    img[y + 1, x, :3] = mix(INK, LAND, 0.4)


def draw_river(img, land, di, rng, tones, reg):
    """A one-pixel river from the inland spine to the north or south coast."""
    for _ in range(30):
        x = float(rng.uniform(M + 40, W - M - 40))
        if abs(x - XS) > 90 and di[int(YMID), int(x)] >= 8:
            break
    else:
        return
    step = -1 if rng.random() < 0.5 else 1
    y = int(YMID)
    ph = float(rng.uniform(0, 6.28))
    t = 0
    while land[y, int(round(x))] and 0 < y < H - 1:
        xi = int(round(x))
        img[y, xi, :3] = tones[reg[y, xi], 1]
        if di[y, xi] <= 3:  # widen towards the mouth
            img[y, xi + 1, :3] = tones[reg[y, xi + 1], 1]
        y += step
        t += 1
        x += 0.8 * math.sin(t * 0.45 + ph)


# --------------------------------------------------------------- islands ----
def isle_sprite(L, ox, oy, pal, tones, R, nn, seed):
    rng = np.random.default_rng(seed)
    typ = L["type"]
    rid = L["regionId"]
    S = int(math.ceil(min(R * 1.7, nn * 0.46))) + 7
    size = 2 * S + 1
    yy, xx = np.mgrid[0:size, 0:size]
    dx, dy = (xx - S).astype(np.float32), (yy - S).astype(np.float32)
    ang = np.arctan2(dy, dx)
    rad = np.hypot(dx, dy)
    # harbour / feature side faces open water (towards the sea's middle)
    to_mid = math.atan2(SH / 2 - L["y"] * SH, SW / 2 - L["x"] * SW)
    ks = np.arange(2, 7)
    jag = 1.5 if typ in ("dungeon", "secret") else 1.0
    amp = rng.uniform(0.05, 0.15, len(ks)) / np.sqrt(ks - 1) * jag
    ph = rng.uniform(0, 2 * np.pi, len(ks))
    wav = sum(a * np.cos(k * ang + p) for a, k, p in zip(amp, ks, ph))
    elong = rng.uniform(0.70, 0.95)
    rot = rng.uniform(0, np.pi)
    ell = elong / np.sqrt((elong * np.cos(ang - rot)) ** 2 + np.sin(ang - rot) ** 2)
    shape_r = R * (1 + wav) * ell
    # Each sea's geology has a visible contour language. The chart retains
    # discovery rules and marker positions, while its silhouettes now echo
    # the basalt shelves, reef rings and wind-cut crags in the world art.
    if rid == "glass_current":
        face = np.cos(np.pi / 6) / np.cos((ang - rot + np.pi / 6) % (np.pi / 3) - np.pi / 6)
        shape_r = R * face * ell * (1 + wav * 0.35)
    elif rid == "stormbelt":
        shape_r *= 0.83 + 0.24 * np.cos(ang - rot) ** 2
    elif rid == "emberreach":
        shape_r *= 0.94 + 0.06 * np.cos(6 * ang)
    elif rid == "verdant_maw":
        shape_r *= 1 + 0.09 * np.sin(3 * ang + rot)
    elif rid == "leviathan_ring":
        shape_r *= 1 + 0.10 * np.cos(5 * ang + rot)
    land = rad <= shape_r
    lagoon = np.zeros_like(land)
    if typ == "arena":
        inner = rad <= shape_r * 0.58
        lagoon = inner.copy()
        land &= ~inner
        ca = rng.uniform(0, 2 * np.pi)
        chan = (np.abs(np.angle(np.exp(1j * (ang - ca)))) < 0.16) & (rad > R * 0.4)
        land &= ~chan
    elif typ == "wreck":
        arc0 = to_mid + math.pi + rng.uniform(-0.6, 0.6)
        da = np.abs(np.angle(np.exp(1j * (ang - arc0))))
        land = (rad >= shape_r * 0.62) & (rad <= shape_r * 0.86) & (da < 1.75)
    else:
        # one or two coves bitten out of the coast
        for c in range(1 + int(rng.random() < 0.6)):
            ca = to_mid if (typ == "port" and c == 0) else rng.uniform(0, 2 * np.pi)
            cr = R * (0.44 if typ == "port" and c == 0 else rng.uniform(0.26, 0.38))
            cd = R * (0.98 if typ == "port" and c == 0 else rng.uniform(1.0, 1.15))
            land &= np.hypot(dx - math.cos(ca) * cd, dy - math.sin(ca) * cd) > cr
        # a headland or peninsula
        if R >= 9 and typ != "secret":
            pa = to_mid + math.pi * rng.choice([-0.55, 0.55]) + rng.uniform(-0.3, 0.3)
            ux, uy = math.cos(pa), math.sin(pa)
            along = dx * ux + dy * uy
            across = np.abs(-dx * uy + dy * ux)
            reach = R * rng.uniform(1.25, 1.45)
            land |= (along >= 0) & (along <= reach) & (across <= 1.6 + 1.6 * (1 - along / reach))
    land = clean(land)
    if rid == "moonwake" and typ in ("island", "secret"):
        cut_a = to_mid + 0.45
        land &= np.hypot(dx - math.cos(cut_a) * R * 0.70, dy - math.sin(cut_a) * R * 0.70) > R * 0.50
        land = clean(land)
    # islets (not for wrecks), kept clear of neighbouring islands
    islets = np.zeros_like(land)
    if typ != "wreck":
        n_isl = int(rng.integers(1, 4)) if typ in ("island", "dungeon", "secret") else int(rng.integers(0, 3))
        lim = min(R * 1.6, nn * 0.44 - 3)
        for _ in range(n_isl):
            a = rng.uniform(0, 2 * np.pi)
            d = rng.uniform(R * 1.25, max(R * 1.3, lim))
            ir = rng.uniform(1.4, 2.8)
            islets |= np.hypot(dx - math.cos(a) * d, dy - math.sin(a) * d) <= ir
        islets &= ~dilate(dilate(land, N8), N8)
    allland = land | islets
    # rocks: single dark pixels in the shallows
    rocks = np.zeros_like(land)
    n_rock = int(rng.integers(2, 5)) + (3 if typ in ("dungeon", "wreck") else 0)
    for _ in range(n_rock):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(R * 1.05, R * 1.45)
        x, y = int(round(S + math.cos(a) * d)), int(round(S + math.sin(a) * d))
        if 0 <= x < size and 0 <= y < size and not dilate(allland, N8)[y, x]:
            rocks[y, x] = True
    # ------------------------------------------------------- colouring
    img = np.zeros((size, size, 4), np.uint8)
    sw = 3 + (1 if R >= 12 else 0)
    do = dist_out(allland | rocks, sw + 1)
    shallow = ((do >= 1) & (do <= sw)) | lagoon
    contour = (do == sw + 1) & ~lagoon
    paint(img, shallow, tones[0])
    paint(img, contour, mix(tones[1], INK, 0.30))
    sand = mix(hexrgb(pal["land"]), PAPER, 0.22)
    grass = hexrgb(pal["grass"])
    rock_c, rock_d = (128, 120, 112), (82, 74, 72)
    if typ in ("dungeon", "secret"):
        grass = mix(grass, rock_c, 0.55 if typ == "dungeon" else 0.4)
    if typ == "secret":
        grass = mix(grass, (150, 120, 190), 0.25)
    g_light = mix(grass, (255, 250, 214), 0.24)
    g_dark = mul(grass, 0.78)
    hill = mix(grass, (126, 104, 82), 0.38)
    hill_l = mix(hill, (255, 250, 214), 0.22)
    hill_d = mul(hill, 0.78)
    hgt = dist_in(allland, 20)
    hmax = int(hgt.max()) if hgt.any() else 1
    hf = hgt.astype(np.float32)
    gx = shift(hf, -1, 0) - shift(hf, 1, 0)
    gy = shift(hf, 0, -1) - shift(hf, 0, 1)
    lit = (gx + gy) > 0.6
    shade = (gx + gy) < -0.6
    bw = 1 + ((np.sin(3 * ang + ph[0]) + 0.6 * np.sin(5 * ang + ph[1])) > 0.25).astype(np.int32)
    if typ in ("dungeon", "secret"):
        bw = np.ones_like(bw) * (ang > 10)  # rocky shores: almost no beach
    beach = allland & (hgt >= 2) & (hgt <= 1 + bw)
    inland = allland & (hgt > 1 + bw)
    hill_h = max(4, int(hmax * 0.6))
    low = inland & (hgt < hill_h)
    high = inland & (hgt >= hill_h)
    paint(img, beach, sand)
    paint(img, low, grass)
    paint(img, low & lit, g_light)
    paint(img, low & shade, g_dark)
    if R >= 9 and typ not in ("wreck", "arena"):
        paint(img, high, hill)
        paint(img, high & lit, hill_l)
        paint(img, high & shade, hill_d)
    paint(img, allland & (hgt == 1), mix(INK, sand, 0.28))
    paint(img, rocks, rock_d)

    # --------------------------------------------------- type features
    def put(x, y, c):
        if 0 <= x < size and 0 <= y < size:
            img[y, x, :3] = c
            img[y, x, 3] = 255

    roof_c, wall_c = CHART_ARCHITECTURE[rid]

    inl = list(zip(*np.nonzero(inland)))
    if typ == "port":
        hx, hy = math.cos(to_mid), math.sin(to_mid)
        # pier: from the bay's inner shore out into the bay
        base_d = R * 0.98 - R * 0.44
        for s in range(0, 5):
            put(int(round(S + hx * (base_d + s))), int(round(S + hy * (base_d + s))), (112, 72, 44))
        # houses around the bay (2 x 2, red roof row)
        houses = [(y, x) for (y, x) in inl if R * 0.3 <= math.hypot(x - S - hx * base_d, y - S - hy * base_d) <= R * 0.62]
        rng.shuffle(houses)
        placed = []
        for (y, x) in houses:
            if len(placed) >= 5:
                break
            if any(abs(x - px) < 3 and abs(y - py) < 3 for (py, px) in placed):
                continue
            if not (inland[min(size - 1, y + 1), x] and inland[y, min(size - 1, x + 1)] and inland[min(size - 1, y + 1), min(size - 1, x + 1)]):
                continue
            placed.append((y, x))
            put(x, y, roof_c); put(x + 1, y, mul(roof_c, 0.83))
            put(x, y + 1, wall_c); put(x + 1, y + 1, mul(wall_c, 0.83))
            if rid in ("grand_horizon", "crown_shoals", "leviathan_ring"):
                put(x, y - 1, mix(roof_c, PAPER, 0.3))
            elif rid in ("emberreach", "ashen_trench"):
                put(x + 1, y - 2, wall_c); put(x + 1, y - 1, wall_c)
            elif rid == "verdant_maw":
                put(x, y + 2, mul(wall_c, 0.55)); put(x + 1, y + 2, mul(wall_c, 0.55))
        # lighthouse on the outermost coast pixel towards the open water
        coast = list(zip(*np.nonzero(allland & (hgt == 1))))
        if coast:
            y, x = max(coast, key=lambda q: (q[1] - S) * hx + (q[0] - S) * hy - 0.6 * abs(-(q[1] - S) * hy + (q[0] - S) * hx))
            put(x, y - 1, wall_c); put(x, y, roof_c); put(x, y - 2, (248, 210, 90))
    elif typ in ("island", "secret"):
        n_tree = int(rng.integers(3, 8)) if typ == "island" else 2
        rng.shuffle(inl)
        placed = []
        for (y, x) in inl:
            if len(placed) >= n_tree:
                break
            if hgt[y, x] < 3 or any(abs(x - px) < 3 and abs(y - py) < 3 for (py, px) in placed):
                continue
            placed.append((y, x))
            dk = mul(hexrgb(pal["grass"]), 0.55)
            if rid in ("glass_current", "emberreach", "ashen_trench"):
                # Spires, vents and broken stone instead of ubiquitous
                # little green woods in every sea.
                put(x, y - 1, mix(roof_c, PAPER, 0.25))
                put(x, y, roof_c); put(x, y + 1, mul(roof_c, 0.65)); put(x + 1, y + 1, mul(roof_c, 0.7))
            elif rid == "leviathan_ring":
                put(x - 1, y, roof_c); put(x, y + 1, wall_c); put(x + 1, y, roof_c); put(x, y - 1, wall_c)
            else:
                put(x, y, dk); put(x + 1, y, dk); put(x, y + 1, dk); put(x + 1, y + 1, mul(dk, 0.8))
                put(x, y, mix(hexrgb(pal["grass"]), (255, 255, 220), 0.1))
        if typ == "secret":
            # grotto arch and two sparkles
            cy, cx = max(inl, key=lambda q: hgt[q]) if inl else (S, S)
            for (ox_, oy_) in ((-1, 0), (0, -1), (1, 0), (-1, 1), (1, 1)):
                put(cx + ox_, cy + oy_, (40, 30, 48))
            put(cx, cy + 1, (24, 18, 30))
            for (ox_, oy_) in ((R + 2, -2), (-R - 1, 3)):
                put(int(S + ox_), int(S + oy_), (226, 206, 255))
    elif typ == "dungeon":
        cy, cx = max(inl, key=lambda q: hgt[q]) if inl else (S, S)
        for oy_ in range(-1, 2):
            for ox_ in range(-1, 2):
                put(cx + ox_, cy + oy_, (54, 44, 50))
        put(cx, cy - 2, (54, 44, 50)); put(cx - 1, cy - 1, (96, 88, 90)); put(cx, cy + 1, (24, 18, 22))
        # A small region-specific landmark on the discovered island. It
        # keeps the room icon legible while linking map and playable scene.
        if rid in ("dawnwater", "stormbelt"):
            for k in range(4):
                put(cx, cy - 2 - k, wall_c)
            put(cx - 1, cy - 5, roof_c); put(cx + 1, cy - 5, roof_c)
            put(cx, cy - 4, (248, 210, 90))
        elif rid in ("grand_horizon", "crown_shoals", "moonwake"):
            for ix in range(-2, 3):
                put(cx + ix, cy - 2, roof_c)
            put(cx - 1, cy - 3, roof_c); put(cx + 1, cy - 3, roof_c)
            put(cx, cy - 4, mix(roof_c, PAPER, 0.3))
        elif rid == "verdant_maw":
            for ix in (-2, 2):
                put(cx + ix, cy - 1, mul(grass, 0.65)); put(cx + ix, cy - 2, grass)
            put(cx, cy - 3, grass)
        elif rid == "glass_current":
            for k in range(4):
                put(cx + 1, cy - 2 - k, mix(roof_c, PAPER, 0.2))
            put(cx + 2, cy - 3, roof_c)
        elif rid == "leviathan_ring":
            for ix in (-2, 2):
                for k in range(3):
                    put(cx + ix, cy - k, wall_c)
            for ix in range(-1, 2):
                put(cx + ix, cy - 3, wall_c)
        else:
            put(cx - 1, cy - 3, wall_c); put(cx + 1, cy - 4, roof_c)
    elif typ == "wreck":
        # broken hull lying on the reef, mast and a torn sail
        a = to_mid + math.pi * 0.5
        ux, uy = math.cos(a), math.sin(a)
        for s in range(-4, 5):
            for t in (0, 1):
                put(int(round(S + ux * s - uy * t)), int(round(S + uy * s + ux * t)), (120, 76, 46) if t == 0 else (84, 52, 34))
        for m in range(1, 5):
            put(S + 1, S - m, (84, 52, 34))
        put(S + 2, S - 3, (232, 222, 196)); put(S + 2, S - 2, (232, 222, 196)); put(S + 3, S - 2, (210, 198, 170))
    elif typ == "arena":
        for oy_ in range(-1, 2):
            for ox_ in range(-1, 2):
                put(S + ox_, S + oy_, (196, 190, 178) if abs(ox_) + abs(oy_) < 2 else (150, 144, 136))
        put(S, S - 2, (84, 52, 34)); put(S, S - 3, (84, 52, 34)); put(S + 1, S - 3, (214, 84, 64)); put(S + 2, S - 3, (214, 84, 64))
    crop_y, crop_x = np.nonzero(img[..., 3] > 0)
    y0, y1, x0, x1 = crop_y.min(), crop_y.max() + 1, crop_x.min(), crop_x.max() + 1
    return img[y0:y1, x0:x1].copy(), (S - int(x0), S - int(y0))


# ------------------------------------------------------------------ fog ----
FOG_LIGHT = (238, 233, 219)
FOG_MID = (220, 213, 197)
FOG_SHADOW = (196, 188, 173)
FOG_INK = (170, 160, 150)
FOG_HIGH = (246, 243, 234)
FOG_LINE = (184, 174, 162)


def fog_art(rng, reg, land):
    """Cloud-bank art and the fog key, at half resolution.

    Billows of two sizes are laid top to bottom, each lower one overlapping
    those above it: big billows where a slow noise says the bank is thick,
    medium ones everywhere, on jittered rows so no grid shows. Each
    billow is lit from the upper left (highlight, body, shadow crescent) and
    only the arc where it overlaps an earlier billow gets a soft line, which
    gives the scalloped edge of clouds on old charts without a regular grid
    of scales. Each fog pixel belongs to the sea under the centre of its
    billow, so where an open sea meets a locked one the bank ends in whole
    billows."""
    mass = smooth_noise(rng, FW, FH, 5, 2)
    tone = smooth_noise(rng, FW, FH, 9, 2)
    puffs = []
    layers = ((42, 24, 18.0, 26.0, 9.0, 0.40), (27, 15, 11.0, 16.0, 7.0, 0.0))
    for li, (sx, sy, rmin, rmax, jit, need) in enumerate(layers):
        for gy in range(-12, FH + 24, sy):
            for gx in range(-14 + (gy // sy % 2) * (sx // 2), FW + 24, sx):
                cx = gx + float(rng.uniform(-jit, jit))
                cy = gy + float(rng.uniform(-jit * 0.6, jit * 0.6))
                mv = float(mass[min(FH - 1, max(0, int(cy))), min(FW - 1, max(0, int(cx)))])
                if li == 0 and mv < need:
                    continue
                r = float(rng.uniform(rmin, rmax))
                puffs.append((cy + 0.25 * r, cx, cy, r))
    puffs.sort(key=lambda p: p[0])
    ids = np.full((FH, FW), -1, np.int32)
    shade = np.zeros((FH, FW), np.uint8)
    owner = []
    for k, (_, cx, cy, r) in enumerate(puffs):
        sl, dx, dy = window(cx, cy, r + 1, FW, FH)
        if dx.size == 0:
            owner.append(0)
            continue
        m = dx * dx + dy * dy * 1.35 <= r * r
        s = (dx * 0.55 + dy * 0.85) / r
        sh = np.where(s < -0.5, 4, np.where(s > 0.72, 1, np.where(s > 0.42, 2, 3))).astype(np.uint8)
        ids[sl][m] = k
        shade[sl][m] = sh[m]
        px = int(min(W - 1, max(0, round(cx * FOG))))
        py = int(min(H - 1, max(0, round(cy * FOG))))
        owner.append(int(reg[py, px]))
    cover = ids >= 0
    shade[~cover] = 2
    outline = np.zeros((FH, FW), bool)
    for dx, dy in N4:
        nb = shift(ids + 1, dx, dy) - 1  # -1 off the edge and in any gap
        outline |= (nb >= 0) & (nb < ids)
    pal = np.array([FOG_INK, FOG_SHADOW, FOG_MID, FOG_LIGHT, FOG_HIGH], np.float32)
    rgb = pal[shade]
    rgb[outline] = FOG_LINE
    rgb *= (0.965 + 0.05 * tone)[..., None]
    art = np.zeros((FH, FW, 4), np.uint8)
    art[..., 3] = 255
    art[..., :3] = np.clip(rgb.round(), 0, 255).astype(np.uint8)
    key = np.zeros((FH, FW, 4), np.uint8)
    key[..., 3] = 255
    key[..., 0] = (smooth_noise(rng, FW, FH, 30, 2) * 255).round().astype(np.uint8)
    land_h = land[::FOG, ::FOG][:FH, :FW]
    puff_reg = np.where(cover, np.array(owner, np.int32)[np.maximum(ids, 0)], reg[::FOG, ::FOG][:FH, :FW])
    key[..., 1] = (puff_reg * 16 + land_h.astype(np.int32) * 8).astype(np.uint8)
    return art, key


# --------------------------------------------------------------- markers ----
GLYPHS = {
    "port": ["..y..", ".rrr.", ".#y#.", ".###.", ".#r#.", ".###.", "#####"],
    "island": [".##.##.", "#..#..#", "...#...", "...#...", "..###.."],
    "dungeon": [".###.", "#####", "#.#.#", "#####", ".#.#."],
    "wreck": ["....#..", "...#...", "..#....", "#.#...#", ".#####.", "..###.."],
    "arena": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "secret": ["...#...", "...#...", "..###..", "#######", "..###..", "...#...", "...#..."],
    "home": ["..#..", ".#.#.", "..#..", "#####", "..#..", "#.#.#", ".###."],
}
TYPE_FILL = {
    "port": (44, 64, 104), "island": (70, 138, 74), "dungeon": (92, 84, 104), "wreck": (138, 86, 52),
    "arena": (176, 78, 60), "secret": (128, 100, 190),
}
MARK_INK = (42, 30, 40)
CREAM = (246, 236, 208)
GOLD = (232, 190, 84)


def _disc(d, r):
    yy, xx = np.mgrid[0:16, 0:16]
    return (xx - 7.5) ** 2 + (yy - 7.5) ** 2 <= r * r + 0.3


def _glyph(img, rows, col, extra=None, oy=0):
    h, w = len(rows), len(rows[0])
    x0, y0 = 8 - (w + 1) // 2 + (1 if w % 2 == 0 else 0), 8 - (h + 1) // 2 + oy
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            c = col if ch == "#" else (extra or {}).get(ch, col)
            img[y0 + j, x0 + i, :3] = c
            img[y0 + j, x0 + i, 3] = 255


def _outline(img):
    a = img[..., 3] > 0
    o = np.zeros_like(a)
    for dx, dy in N4:
        o |= shift(a, dx, dy)
    o &= ~a
    img[o] = (*MARK_INK, 255)
    return img


def marks():
    """Map markers, 16 x 16 each: a ring of tiers by type and state."""
    out = {}
    for typ, fill in TYPE_FILL.items():
        big = typ == "port"
        r = 6.4 if big else 5.3
        # visited: filled disc, cream glyph (ports: gold rim)
        img = np.zeros((16, 16, 4), np.uint8)
        disc = _disc(16, r)
        img[disc] = (*fill, 255)
        if big:
            rim = disc & ~_disc(16, r - 1.2)
            img[rim] = (*GOLD, 255)
        _glyph(img, GLYPHS[typ], CREAM, {"y": (250, 214, 96), "r": (214, 84, 64)})
        out[typ] = _outline(img)
        # charted but not visited: lighter tier, a paper disc with a thin
        # outline and the glyph in the type colour
        img = np.zeros((16, 16, 4), np.uint8)
        img[disc] = (*mix(PAPER, (255, 255, 255), 0.35), 255)
        gc = mix(fill, MARK_INK, 0.15)
        _glyph(img, GLYPHS[typ], gc, {"y": gc, "r": gc})
        a = img[..., 3] > 0
        o = np.zeros_like(a)
        for dx, dy in N4:
            o |= shift(a, dx, dy)
        img[o & ~a] = (*mix(fill, MARK_INK, 0.45), 255)
        out[typ + "_r"] = img
    # ship: hull, mast, two sails, pennant
    img = np.zeros((16, 16, 4), np.uint8)
    for x in range(2, 14):
        img[10, x] = (*(142, 85, 49), 255)
    for x in range(3, 13):
        img[11, x] = (*(142, 85, 49), 255)
    for x in range(4, 12):
        img[12, x] = (*(110, 62, 34), 255)
    for y in range(2, 10):
        img[y, 8] = (*(94, 54, 32), 255)
    for j, w_ in enumerate((1, 2, 3, 4, 5, 5)):
        for i in range(w_):
            img[3 + j, 9 + i] = (*(250, 248, 240), 255)
    for j, w_ in enumerate((1, 2, 3, 3)):
        for i in range(w_):
            img[5 + j, 7 - i] = (*(226, 218, 196), 255)
    img[1, 8] = (*(214, 84, 64), 255)
    img[1, 9] = (*(214, 84, 64), 255)
    out["ship"] = _outline(img)
    # last safe port: small anchor badge (drawn at the port's corner)
    img = np.zeros((16, 16, 4), np.uint8)
    img[_disc(16, 5.0)] = (*GOLD, 255)
    _glyph(img, GLYPHS["home"], MARK_INK)
    out["home"] = _outline(img)
    # objective pin: gold diamond with a highlight and a short stem
    img = np.zeros((16, 16, 4), np.uint8)
    yy, xx = np.mgrid[0:16, 0:16]
    dia = np.abs(xx - 7.5) + np.abs(yy - 6.0) <= 5.0
    img[dia] = (*GOLD, 255)
    img[dia & (xx < 8) & (yy < 6)] = (*(252, 232, 150), 255)
    img[dia & (xx >= 8) & (yy >= 6)] = (*(196, 140, 50), 255)
    img[12:14, 7:9] = (*(196, 140, 50), 255)
    out["target"] = _outline(img)
    # cleared badge: green disc with a cream tick (drawn small at a corner)
    img = np.zeros((16, 16, 4), np.uint8)
    img[_disc(16, 4.2)] = (*(64, 150, 84), 255)
    for (x, y) in ((5, 8), (6, 9), (7, 10), (8, 9), (9, 8), (10, 7)):
        img[y, x] = (*CREAM, 255)
    out["cleared"] = _outline(img)
    # locked sea: padlock
    img = np.zeros((16, 16, 4), np.uint8)
    img[3:8, 5:11] = (*(120, 110, 104), 255)
    img[4:8, 6:10] = 0
    img[7:13, 4:12] = (*(196, 160, 72), 255)
    img[9:11, 7:9] = (*MARK_INK, 255)
    out["lock"] = _outline(img)
    return out


# ----------------------------------------------------------------- build ----
def build():
    world = json.loads((GAME / "data" / "world.json").read_text())
    regions = world["REGIONS"]
    (OUT / "env").mkdir(parents=True, exist_ok=True)
    pts = loc_points(world)
    sheet, reg, land, roses = world_sheet(world)
    save_png(sheet, OUT / "env" / "chart_world.png")
    rng = np.random.default_rng(11)
    fog, key = fog_art(rng, reg, land)
    save_png(fog, OUT / "env" / "chart_fog.png")
    save_png(key, OUT / "env" / "chart_fogkey.png")
    pk = Packer(512)
    where = {}
    for (lid, ri, x, y, typ) in pts:
        R = regions[ri]
        rad, nn = isle_radius(pts, lid, ri, x, y, typ)
        ox, oy = tile_origin(R["order"])
        spr, anchor = isle_sprite(world["LOCATIONS"][lid], ox, oy, R["palette"], water_tones(R["palette"]), rad, nn,
                                  1000 + hash_id(lid))
        pk.add(lid, spr, anchor=list(anchor), r=round(rad, 1))
        where[lid] = (x, y)
    rects, (AW, AH) = pk.pack(OUT / "env" / "chart_isles.png")
    mk = marks()
    names = list(mk)
    save_png(np.concatenate([mk[n] for n in names], 1), OUT / "env" / "chart_marks.png")
    info = {
        "size": [W, H], "sea": [SW, SH], "margin": M, "band": [YB0, YB1], "strait": [XS, YB0, YB1],
        "fogScale": FOG, "fogSize": [FW, FH],
        "tex": "res://assets/gen/env/chart_world.png",
        "fog": "res://assets/gen/env/chart_fog.png",
        "fogKey": "res://assets/gen/env/chart_fogkey.png",
        "isles": "res://assets/gen/env/chart_isles.png",
        "marks": "res://assets/gen/env/chart_marks.png",
        "markNames": names,
        "regions": {},
        "locs": {},
    }
    for i, R in enumerate(regions):
        info["regions"][R["id"]] = {"index": i, "origin": list(tile_origin(R["order"])), "rose": list(roses[R["id"]])}
    for lid, (x, y) in where.items():
        info["locs"][lid] = dict(rects[lid], pos=[round(x, 1), round(y, 1)])
    save_json(info, OUT / "env" / "chart.json")
    record("game/assets/gen/env/chart_world.png", f"{W}x{H}", "1",
           "procedural chart (gen_chart.py)",
           "world sea chart: ten seas in progression order around a mainland with one strait; depth bands, "
           "contours, dashed sea boundaries, a compass rose and rhumb lines per sea, vignettes, neat line")
    record("game/assets/gen/env/chart_isles.png", f"{AW}x{AH}", f"{len(rects)} islands",
           "procedural coastline silhouettes (gen_chart.py)",
           "one island per location (harbour, trees, cave, atoll, reef wreck); drawn only once known")
    record("game/assets/gen/env/chart_marks.png", f"{16 * len(names)}x16", f"{len(names)} markers",
           "procedural pixel icons (gen_chart.py)",
           "chart markers: port badges, location discs, hollow charted-unvisited markers, ship, last safe port, "
           "objective, cleared badge, lock")
    record("game/assets/gen/env/chart_fog.png", f"{FW}x{FH}", "1", "procedural cloud billows (gen_chart.py)",
           "exploration cloud bank: two billow layers lit from the upper left; alpha, haze and bank edges are set at runtime from the save (sea_chart.gd)")
    record("game/assets/gen/env/chart_fogkey.png", f"{FW}x{FH}", "1", "procedural data image (gen_chart.py)",
           "fog key: edge noise (R), sea index and land flag (G); read at runtime, never drawn")
    # previews: the whole chart with every island, a 2x crop of the first sea, the fog art
    atlas = np.asarray(Image.open(OUT / "env" / "chart_isles.png"))
    im = Image.fromarray(sheet)
    for (lid, ri, x, y, typ) in pts:
        rx, ry, rw, rh = rects[lid]["rect"]
        ax, ay = rects[lid]["anchor"]
        spr = Image.fromarray(atlas[ry:ry + rh, rx:rx + rw])
        im.alpha_composite(spr, (int(round(x - ax)), int(round(y - ay))))
    im.save(PREVIEW / "chart_world.png")
    im.crop((0, 0, SW + 2 * M, SH + BAND // 2 + M)).resize(((SW + 2 * M) * 2, (SH + BAND // 2 + M) * 2), Image.NEAREST) \
        .save(PREVIEW / "chart_dawnwater_2x.png")
    Image.fromarray(fog).save(PREVIEW / "chart_fog.png")
    Image.fromarray(np.concatenate([mk[n] for n in names], 1)).resize((16 * len(names) * 6, 96), Image.NEAREST) \
        .save(PREVIEW / "chart_marks.png")
    return info


def hash_id(s):
    h = 2166136261
    for ch in s.encode():
        h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return h % 100000


if __name__ == "__main__":
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    t = build()
    print(t["size"], len(t["locs"]), "islands")
