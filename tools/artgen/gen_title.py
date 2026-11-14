"""Title-screen emblem: a gold ship's wheel over a small pennant.

Drawn on the shared pixel canvas (lib/pix.py), so it is shaded and outlined
like the characters and icons. Output:
    game/assets/gen/ui/title.png + title.json  {name: {rect: [x, y, w, h]}}

Usage (from the repository root):
    tools/artgen/.venv/bin/python tools/artgen/gen_title.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from lib.common import OUT, PREVIEW, record, save_json, save_png, upscale_preview  # noqa: E402
from lib.pix import Canvas, DEEP, LIGHT, SHADE, SHINE  # noqa: E402

GOLD = "#f2c24a"
GOLD_D = "#b9812e"
WOOD = "#8e5531"
WOOD_D = "#5e3620"
RED = "#c8463c"
NAVY = "#2b4a78"
NAVY_L = "#4a78b4"
CREAM = "#f6ecd0"


def wheel():
    """Ship's wheel, 47x47: wooden rim with gold bands, eight spokes whose
    handles reach past the rim, and a gold hub with a red boss."""
    n = 47
    c = Canvas(n, n)
    cx = cy = n // 2
    # spokes and handles first (the rim is drawn over them)
    for k in range(8):
        a = math.tau * k / 8.0
        dx, dy = math.cos(a), math.sin(a)
        for r10 in range(40, 225, 5):
            r = r10 / 10.0
            x, y = cx + dx * r, cy + dy * r
            col = WOOD if r < 17.5 else WOOD_D
            c.px(x, y, col)
            c.px(x + (1 if abs(dy) > 0.5 else 0), y + (1 if abs(dx) > 0.5 else 0), col)
        # handle knob
        hx, hy = cx + dx * 21.5, cy + dy * 21.5
        c.ellipse(hx, hy, 1.6, 1.6, GOLD)
    # rim
    for y in range(n):
        for x in range(n):
            r = math.hypot(x - cx, y - cy)
            if 12.0 <= r <= 16.2:
                band = 13.0 <= r <= 15.2
                c.px(x, y, WOOD if band else GOLD_D, LIGHT if (band and y < cy - 6) else (SHADE if y > cy + 8 else 0))
    # gold bands across the rim between the spokes
    for k in range(8):
        a = math.tau * (k + 0.5) / 8.0
        for r10 in range(120, 163, 4):
            r = r10 / 10.0
            c.px(cx + math.cos(a) * r, cy + math.sin(a) * r, GOLD, SHINE if r10 < 135 else 0)
    # hub
    c.ellipse(cx, cy, 5.2, 5.2, GOLD_D)
    c.ellipse(cx, cy, 4.0, 4.0, GOLD)
    c.ellipse(cx, cy, 1.8, 1.8, RED)
    c.px(cx - 2, cy - 2, GOLD, SHINE)
    return c.render()


def pennant():
    """A swallow-tailed navy pennant with a cream stripe, 61x13."""
    w, h = 61, 13
    c = Canvas(w, h)
    for x in range(w):
        # gentle wave along the cloth
        off = int(round(math.sin(x / 9.0) * 1.2))
        tail = max(0, abs(x - w // 2) - (w // 2 - 6))
        for y in range(2, 11):
            yy = y + off
            if tail and abs(y - 6) < tail * 0.75:
                continue
            col = CREAM if y in (5, 6, 7) else (NAVY_L if y < 5 else NAVY)
            c.px(x, yy, col, DEEP if x in (w // 2 - 22, w // 2 + 22) else 0)
    return c.render()


def build():
    parts = [("wheel", wheel()), ("pennant", pennant())]
    W = max(a.shape[1] for _, a in parts) + 2
    H = sum(a.shape[0] + 1 for _, a in parts) + 1
    atlas = np.zeros((H, W, 4), np.uint8)
    meta = {}
    y = 1
    for name, a in parts:
        atlas[y: y + a.shape[0], 1: 1 + a.shape[1]] = a
        meta[name] = {"rect": [1, y, a.shape[1], a.shape[0]]}
        y += a.shape[0] + 1
    save_png(atlas, OUT / "ui" / "title.png")
    save_json(meta, OUT / "ui" / "title.json")
    PREVIEW.mkdir(parents=True, exist_ok=True)
    upscale_preview(atlas, 4).save(PREVIEW / "ui_title.png")
    record("game/assets/gen/ui/title.png", f"{W}x{H}", "ship's wheel emblem 47x47, pennant 61x13",
           "pixel canvas (gen_title.py)", "title screen emblem")
    return meta


def main():
    build()
    print("[artgen] title emblem")


if __name__ == "__main__":
    main()
