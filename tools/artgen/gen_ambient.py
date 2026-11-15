"""Ambient life sprites: gulls, sea glints, whitecaps, leaping fish, spray,
ripples, butterflies, cloud shadows and the lit-window swatch.

Every strip is drawn pixel by pixel here (no source images). Output:
    game/assets/gen/env/ambient.png + ambient.json
        {name: {rect: [x, y, w, h], frames: n, w: frame_w, h: frame_h}}

Usage (from the repository root):
    tools/artgen/.venv/bin/python tools/artgen/gen_ambient.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from lib.common import OUT, PREVIEW, record, save_json, save_png, upscale_preview  # noqa: E402

WHITE = (250, 252, 255, 255)
FOAM = (226, 240, 250, 255)
FOAM_DIM = (176, 212, 236, 255)
INK = (40, 44, 62, 255)


def blank(w, h):
    return np.zeros((h, w, 4), np.uint8)


def put(a, x, y, c):
    h, w = a.shape[:2]
    x, y = int(round(x)), int(round(y))
    if 0 <= x < w and 0 <= y < h:
        a[y, x] = c


def hline(a, x0, x1, y, c):
    for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1):
        put(a, x, y, c)


def strip(frames):
    h = max(f.shape[0] for f in frames)
    w = max(f.shape[1] for f in frames)
    out = blank(w * len(frames), h)
    for i, f in enumerate(frames):
        out[: f.shape[0], i * w: i * w + f.shape[1]] = f
    return out, w, h


# ------------------------------------------------------------------ gull
GULL = [
    ["t.............t",
     "tw...........wt",
     ".ww.........ww.",
     "..www.....www..",
     "....wwbbbww....",
     "......bbbo.....",
     "..............."],
    ["...............",
     ".t...........t.",
     ".tww.......wwt.",
     "...www...www...",
     ".....wbbbw.....",
     "......bbbo.....",
     "..............."],
    ["...............",
     "...............",
     "...............",
     "ttwwww...wwwwtt",
     ".....wbbbw.....",
     "......bbbo.....",
     "..............."],
    ["...............",
     "...............",
     "...............",
     "....wwbbbww....",
     "..www.bbbo.www.",
     ".tw.........wt.",
     ".t...........t."],
]


def gull_frames():
    """A gull as the familiar spread-wing silhouette, 15x7, four wing poses
    from raised to lowered (the view ping-pongs them). White wings with grey
    tips; the beak marks the heading (flipped for the other direction)."""
    pal = {"w": (236, 240, 244, 255), "b": (250, 250, 246, 255), "t": (104, 112, 130, 255),
           "o": (240, 176, 64, 255)}
    out = []
    for rows in GULL:
        a = blank(15, 7)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in pal:
                    put(a, x, y, pal[ch])
        out.append(a)
    return out


def gull_shadow():
    a = blank(10, 5)
    for x in range(1, 9):
        put(a, x, 2, (10, 24, 44, 255))
    for x in range(3, 7):
        put(a, x, 1, (10, 24, 44, 255))
        put(a, x, 3, (10, 24, 44, 255))
    return [a]


# ----------------------------------------------------------------- glint
def glint_frames():
    out = []
    for r in (0, 1, 2, 1, 0):
        a = blank(5, 5)
        put(a, 2, 2, WHITE)
        for i in range(1, r + 1):
            c = WHITE if i < r else FOAM
            for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
                put(a, 2 + dx, 2 + dy, c)
        out.append(a)
    return out


# -------------------------------------------------------------- whitecap
def whitecap_frames():
    """A short foam crest along the iso wave line (2:1 slope), 16x7: it
    gathers, breaks and thins out."""
    out = []
    spans = [(6, 9), (4, 11), (2, 13), (3, 12), (5, 10), (7, 8)]
    for fi, (x0, x1) in enumerate(spans):
        a = blank(16, 7)
        for x in range(x0, x1 + 1):
            y = 4 - (x - 2) // 4
            thin = fi >= 4
            c = FOAM_DIM if thin or x in (x0, x1) else WHITE
            if thin and (x + fi) % 2:
                continue
            put(a, x, y, c)
            if fi in (2, 3) and x0 + 2 <= x <= x1 - 2 and x % 3 != 0:
                put(a, x, y + 1, FOAM_DIM)
        out.append(a)
    return out


# ------------------------------------------------------------------ fish
def fish_frames():
    """A small fish leaping in an arc with entry and exit splashes, 16x14."""
    back = (86, 132, 176, 255)
    belly = (214, 228, 236, 255)
    out = []
    n = 8
    for fi in range(n):
        a = blank(16, 14)
        u = fi / (n - 1)
        base = 11
        if 0.1 < u < 0.9:
            v = (u - 0.1) / 0.8
            x = 3 + v * 9
            y = base - math.sin(v * math.pi) * 8
            ang = math.atan2(-math.cos(v * math.pi) * 8, 9)
            dx, dy = math.cos(ang), math.sin(ang)
            for k in range(-2, 3):
                put(a, x + dx * k, y + dy * k, back)
                put(a, x + dx * k - dy, y + dy * k + dx, belly if abs(k) < 2 else back)
            put(a, x - dx * 3 - dy, y - dy * 3 + dx, back)
            put(a, x - dx * 3 + dy, y - dy * 3 - dx, back)
        # splashes at the exit (early) and the entry (late)
        for at, t0 in ((3, 0.0), (12, 0.75)):
            k = (u - t0) / 0.3
            if 0.0 <= k <= 1.0:
                r = 1 + int(k * 3)
                for sx in (-r, r):
                    put(a, at + sx, base - (2 - int(k * 2)), WHITE)
                put(a, at, base - (3 - int(k * 3)), FOAM)
                hline(a, at - r, at + r, base + 1, FOAM_DIM)
        out.append(a)
    return out


# ---------------------------------------------------------------- ripple
def ripple_frames():
    out = []
    for fi, (rx, ry) in enumerate(((2, 1), (4, 2), (6, 3), (7, 3))):
        a = blank(16, 8)
        cx, cy = 8, 4
        for i in range(48):
            q = math.tau * i / 48.0
            if fi == 3 and i % 3 == 0:
                continue
            put(a, cx + math.cos(q) * rx, cy + math.sin(q) * ry, FOAM if fi < 2 else FOAM_DIM)
        out.append(a)
    return out


# ----------------------------------------------------------------- spray
def spray_frames():
    """Bow spray puff thrown up and back, 14x12."""
    rng = np.random.default_rng(11)
    pts = [(rng.uniform(-1, 1), rng.uniform(0.4, 1.0), rng.uniform(0, 1)) for _ in range(16)]
    out = []
    for fi in range(5):
        a = blank(14, 12)
        u = fi / 4.0
        for vx, vy, ph in pts:
            x = 7 + vx * (1.5 + 5.0 * u)
            y = 10 - vy * 9.0 * math.sin(min(1.0, u * 1.15 + 0.1) * math.pi * 0.85) + 2.0 * u * u
            if ph < u * 0.6:
                continue
            put(a, x, y, WHITE if ph > 0.5 else FOAM)
        if fi < 2:
            hline(a, 5 - fi, 9 + fi, 10, FOAM)
        out.append(a)
    return out


# ------------------------------------------------------------- butterfly
def butterfly_frames():
    """White so it can be tinted at runtime; 5x4, wings open and closed."""
    a = blank(5, 4)
    for x, y in ((0, 0), (1, 0), (3, 0), (4, 0), (0, 1), (1, 1), (3, 1), (4, 1), (1, 2), (3, 2)):
        put(a, x, y, WHITE)
    put(a, 2, 1, INK)
    put(a, 2, 2, INK)
    b = blank(5, 4)
    for x, y in ((1, 0), (3, 0), (1, 1), (3, 1), (1, 2), (3, 2)):
        put(b, x, y, WHITE)
    put(b, 2, 1, INK)
    put(b, 2, 2, INK)
    return [a, b]


def sea_bird_frames(kind):
    """Small but different readable wing plans: tern, swift, albatross."""
    widths = {"tern": 17, "swift": 15, "albatross": 25}
    w = widths[kind]
    mid = w // 2
    out = []
    for pose in range(4):
        a = blank(w, 9)
        body = (236, 234, 215, 255) if kind != "swift" else (63, 67, 87, 255)
        edge = (96, 112, 131, 255) if kind != "swift" else (39, 44, 65, 255)
        for x in range(1, mid):
            distance = mid - x
            bend = (distance * (2 - pose)) // max(2, mid // 2)
            y = max(0, min(8, 4 - bend))
            for sx in (mid - distance, mid + distance):
                put(a, sx, y, edge if distance >= mid - 2 else body)
                if distance < mid - 2:
                    put(a, sx, min(8, y + 1), body)
        hline(a, mid - 2, mid + 2, 4, body)
        hline(a, mid - 1, mid + 3, 5, body)
        put(a, mid + 4, 5, (220, 162, 77, 255))
        if kind == "tern":
            put(a, mid + 1, 3, edge)
            put(a, mid - 3, 5, body)
            put(a, mid - 4, 6, body)
        if kind == "swift":
            put(a, mid - 3, 4, edge)
            put(a, mid - 4, 3, edge)
            put(a, mid - 4, 5, edge)
        out.append(a)
    return out


def coloured_fish_frames(back, belly):
    out = []
    for frame in fish_frames():
        a = frame.copy()
        a[np.all(a == (86, 132, 176, 255), axis=2)] = back
        a[np.all(a == (214, 228, 236, 255), axis=2)] = belly
        out.append(a)
    return out


def moth_frames(glass=False):
    """Broad triangular moth and narrow clear-wing butterfly, two poses."""
    out = []
    for pose in range(2):
        a = blank(7, 6)
        wing = (208, 226, 247, 180) if glass else (225, 211, 178, 255)
        tip = (130, 171, 200, 230) if glass else (122, 104, 143, 255)
        for side in (-1, 1):
            for y in range(4):
                span = (3 - y // 2) if not pose else 1
                for dx in range(1, span + 1):
                    put(a, 3 + side * dx, y, wing)
                put(a, 3 + side * span, y, tip)
            put(a, 3 + side * (2 if not pose else 1), 1, WHITE)
        for y in range(1, 5):
            put(a, 3, y, (70, 68, 91, 255))
        put(a, 2, 0, tip)
        put(a, 4, 0, tip)
        out.append(a)
    return out


def mote_frames(kind):
    out = []
    for frame in range(4):
        a = blank(5, 5)
        if kind == "moon":
            points = [(2, 0), (1, 1), (1, 2), (2, 3), (3, 3)]
            col = (193, 211, 244, 255)
        elif kind == "prism":
            points = [(2, 0), (1, 1), (2, 2), (3, 1)]
            col = (192, 239, 236, 255)
        else:
            points = [(2, 1), (1, 2), (2, 2), (3, 2), (2, 3)]
            col = (250, 218, 143, 255)
        for i, p in enumerate(points):
            if frame in (1, 2) or i % 2 == frame % 2:
                put(a, p[0], p[1], col)
        out.append(a)
    return out


# ---------------------------------------------------------- cloud shadow
def cloud_shadow(seed, w, h):
    """A cloud's shadow at world scale: a union of ellipses with a crisp,
    slightly ragged pixel edge. Drawn 1:1 at low opacity, so the edge stays
    one world pixel wide at every zoom."""
    rng = np.random.default_rng(seed)
    blobs = [(w * 0.5, h * 0.5, w * 0.30, h * 0.30)]
    for _ in range(6):
        blobs.append((rng.uniform(w * 0.22, w * 0.78), rng.uniform(h * 0.32, h * 0.68),
                      rng.uniform(w * 0.12, w * 0.24), rng.uniform(h * 0.14, h * 0.28)))
    ph = rng.uniform(0, math.tau, 3)
    a = blank(w, h)
    for y in range(h):
        for x in range(w):
            d = 9.0
            for cx, cy, rx, ry in blobs:
                d = min(d, math.hypot((x - cx) / rx, (y - cy) / ry))
            edge = 1.0 + 0.035 * math.sin(x * 0.21 + ph[0]) + 0.03 * math.sin(y * 0.37 + ph[1]) + 0.02 * math.sin((x + y) * 0.11 + ph[2])
            if d <= edge:
                a[y, x] = (12, 26, 52, 255)
    return [a]


# -------------------------------------------------------------- lantern
def window_glow():
    """A warm lit-window patch (4x5) for town buildings at night."""
    a = blank(4, 5)
    for y in range(5):
        for x in range(4):
            a[y, x] = (255, 214, 120, 255) if (x in (0, 3) or y in (0, 4)) else (255, 236, 170, 255)
    return [a]


SPRITES = [
    ("gull", gull_frames),
    ("gull_shadow", gull_shadow),
    ("glint", glint_frames),
    ("whitecap", whitecap_frames),
    ("fish", fish_frames),
    ("ripple", ripple_frames),
    ("spray", spray_frames),
    ("butterfly", butterfly_frames),
    ("tern", lambda: sea_bird_frames("tern")),
    ("swift", lambda: sea_bird_frames("swift")),
    ("albatross", lambda: sea_bird_frames("albatross")),
    ("fish_amber", lambda: coloured_fish_frames((193, 133, 77, 255), (246, 218, 151, 255))),
    ("fish_teal", lambda: coloured_fish_frames((58, 137, 137, 255), (191, 231, 202, 255))),
    ("fish_silver", lambda: coloured_fish_frames((131, 159, 186, 255), (237, 240, 232, 255))),
    ("moth", moth_frames),
    ("glasswing", lambda: moth_frames(True)),
    ("mote_prism", lambda: mote_frames("prism")),
    ("mote_moon", lambda: mote_frames("moon")),
    ("mote_gold", lambda: mote_frames("gold")),
    ("cloud_a", lambda: cloud_shadow(3, 320, 160)),
    ("cloud_b", lambda: cloud_shadow(8, 248, 118)),
    ("cloud_c", lambda: cloud_shadow(21, 184, 92)),
    ("window", window_glow),
]


def build():
    strips = []
    for name, fn in SPRITES:
        frames = fn()
        s, fw, fh = strip(frames)
        strips.append((name, s, len(frames), fw, fh))
    W = max(s.shape[1] for _, s, _, _, _ in strips) + 2
    H = sum(s.shape[0] + 1 for _, s, _, _, _ in strips) + 1
    atlas = np.zeros((H, W, 4), np.uint8)
    meta = {}
    y = 1
    for name, s, n, fw, fh in strips:
        atlas[y: y + s.shape[0], 1: 1 + s.shape[1]] = s
        meta[name] = {"rect": [1, y, s.shape[1], s.shape[0]], "frames": n, "w": fw, "h": fh}
        y += s.shape[0] + 1
    png = OUT / "env" / "ambient.png"
    save_png(atlas, png)
    save_json(meta, OUT / "env" / "ambient.json")
    PREVIEW.mkdir(parents=True, exist_ok=True)
    upscale_preview(atlas, 2).save(PREVIEW / "env_ambient.png")
    record("game/assets/gen/env/ambient.png", f"{W}x{H}",
           "gull x4 + shadow, glint x5, whitecap x6, fish x8, ripple x4, spray x5, butterfly x2, "
           "3 regional birds x4, 3 regional fish x8, moth/glasswing x2, 3 motes x4, "
           "3 cloud shadows, window light",
           "pixel canvas (gen_ambient.py)",
           "ambient life in every stage: gulls, sea glints and whitecaps, leaping fish, bow spray, "
           "regional seabirds, fish and insects, sparse local motes, drifting cloud shadows, lit windows at night")
    return meta


def main():
    meta = build()
    print(f"[artgen] ambient: {len(meta)} strips")


if __name__ == "__main__":
    main()
