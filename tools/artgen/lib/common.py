"""Shared helpers for the art generators: paths, packing, metadata."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT / "game"
OUT = GAME / "assets" / "gen"
PREVIEW = ROOT / "art" / "previews"

TILE_W, TILE_H = 32, 16  # terrain tile (8 voxels per side)
# Ship scale: one ship cell is 16 voxels (2 x 2 terrain tiles, 64 x 32 px)
# and one ship level is 24 voxels (48 px). Characters are ~14 voxels tall,
# so a cell is about 2 m and a level about 3 m.
LEVEL_PX = 48          # screen pixels per ship elevation level
LEVEL_VOX = 24         # voxels per ship elevation level
CELL_VOX = 16          # voxels per ship cell side

INVENTORY: list = []   # rows appended by generators for docs/ASSET_INVENTORY.md


def record(path, size, frames, method, usage, notes=""):
    INVENTORY.append({"path": str(path), "size": size, "frames": frames, "method": method,
                      "usage": usage, "notes": notes})


def save_png(arr_or_img, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img = arr_or_img if isinstance(arr_or_img, Image.Image) else Image.fromarray(arr_or_img)
    img.save(path, optimize=True)
    return img


def save_json(obj, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")


def trim(arr):
    """Crop transparent borders. Returns (crop, (left, top))."""
    a = arr[..., 3] > 0
    if not a.any():
        return arr[:1, :1].copy(), (0, 0)
    ys, xs = np.nonzero(a)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return arr[y0:y1, x0:x1].copy(), (int(x0), int(y0))


class Packer:
    """Shelf packer producing one atlas PNG plus a rect table."""

    def __init__(self, width=1024, pad=1):
        self.width = width
        self.pad = pad
        self.items = []  # (name, arr, meta)

    def add(self, name, arr, **meta):
        self.items.append((name, arr, meta))

    def pack(self, png_path: Path):
        items = sorted(self.items, key=lambda t: (-t[1].shape[0], -t[1].shape[1]))
        x = y = shelf_h = 0
        rects = {}
        placed = []
        W = self.width
        for name, arr, meta in items:
            h, w = arr.shape[:2]
            if w + self.pad > W:
                W = w + self.pad
            if x + w + self.pad > W:
                x = 0
                y += shelf_h + self.pad
                shelf_h = 0
            placed.append((name, arr, x, y))
            rects[name] = dict(meta, rect=[x, y, w, h])
            x += w + self.pad
            shelf_h = max(shelf_h, h)
        H = y + shelf_h + self.pad
        H = max(1, H)
        atlas = np.zeros((H, W, 4), np.uint8)
        for name, arr, px, py in placed:
            h, w = arr.shape[:2]
            atlas[py:py + h, px:px + w] = arr
        save_png(atlas, png_path)
        return rects, (W, H)


def upscale_preview(arr, k=3, bg=(32, 70, 110, 255)):
    img = Image.fromarray(arr)
    img = img.resize((img.width * k, img.height * k), Image.NEAREST)
    out = Image.new("RGBA", img.size, bg)
    out.alpha_composite(img)
    return out
