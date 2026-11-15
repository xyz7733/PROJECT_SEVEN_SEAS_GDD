"""Facility generator: 27 furnished rooms and deck installations.

Every facility is a voxel diorama built from lib/kit.py, rendered in an idle
and a working state for both rotations, and sliced into per-cell pieces.

Outputs (game/assets/gen/facilities/):
  facilities.png / facilities.json   pieces, work spots, FX anchors, lights
  cards.png / cards.json             whole-facility thumbnails for menus
"""
from __future__ import annotations

import json

import numpy as np

from lib import kit
from lib.common import GAME, OUT, PREVIEW, Packer, record, save_json, save_png, trim, upscale_preview
from lib.kit import F, P
from lib.kvol import K, KVol, fzf
from lib.vox import EMIT, GLOSS, NOSHADOW, SEAM, SEAM_L, SEAM_R, SEAM_SIDE, Vol, hexrgb, mix, mul, render, slice_groups

C = json.loads((GAME / "data" / "content.json").read_text())
FAC = C["FACILITIES"]

STYLE = {
    "command": dict(wall=hexrgb("#3c5a96"), wains=P["wood_dd"], trim=P["gold"]),
    "living": dict(wall=hexrgb("#efd6aa"), wains=P["wood_d"], trim=P["wood_l"]),
    "training": dict(wall=hexrgb("#d8b27a"), wains=P["wood_d"], trim=P["wood_l"]),
    "medical": dict(wall=hexrgb("#dff3ea"), wains=hexrgb("#7fc8b0"), trim=P["white"]),
    "production": dict(wall=hexrgb("#c46a4e"), wains=P["stone_d"], trim=P["stone"]),
    "navigation": dict(wall=hexrgb("#3f86a0"), wains=P["wood_dd"], trim=P["brass"]),
    "storage": dict(wall=hexrgb("#b9844e"), wains=P["wood_d"], trim=P["wood_l"]),
    "pet": dict(wall=hexrgb("#8cc276"), wains=P["wood_d"], trim=P["straw"]),
    "social": dict(wall=hexrgb("#7a4f96"), wains=P["wood_dd"], trim=P["gold"]),
    "defense": dict(wall=hexrgb("#7d838e"), wains=P["iron_d"], trim=P["steel"]),
}


class Ctx:
    def __init__(self, W, H, work, cat):
        self.W, self.H, self.work, self.cat = W, H, work, cat
        self.fx, self.spots, self.lights = [], [], []

    def room(self, v, floor, sides="xy", **kw):
        floor(v)
        st = dict(STYLE[self.cat])
        st.update(kw)
        kit.back_walls(v, self.W, self.H, st["wall"], st["wains"], st["trim"], sides=sides)
        # A room has a low, open threshold and a small colour-coded wall
        # plaque. Its purpose reads at ship scale without a floating label.
        for x in range(1, self.W - 1):
            if abs(x - self.W // 2) > 1:
                v.put(x, self.H - 1, F, st["trim"], NOSHADOW)
        for y in range(1, self.H - 1):
            v.put(self.W - 1, y, F, st["trim"], NOSHADOW)
        if "y" in sides and self.W >= 8:
            v.box(self.W - 5, 0, F + 7, self.W - 1, 1, F + 10, st["wains"])
            v.box(self.W - 4, 1, F + 8, self.W - 2, 2, F + 9, st["trim"], GLOSS)

    def light(self, x, y, z, kind="lamp"):
        self.lights.append([x, y, z, kind])


# -- builders --------------------------------------------------------------

def b_captains_cabin(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_carpet(v, W, H, P["red_d"], P["gold"], inset=1, motif=4))
    kit.window(v, "y", 9, curtain=P["red"])
    kit.bookshelf(v, "x", 2, 6)
    kit.painting(v, "x", 10, F + 6, 4, 4, [P["blue"], P["teal"], P["green"]])
    kit.table(v, 5, 6, 7, 4, h=5, top=P["wood_dd"])
    v.box(6, 7, F + 5, 9, 9, F + 6, P["parch"])
    v.put(10, 7, F + 5, P["brass"])
    kit.candle(v, 11, 9, F + 5, lit=c.work)
    kit.chair(v, 8, 3, P["red"], back="y")
    kit.globe(v, 13.5, 3.5)
    kit.plant(v, 12, 12)
    kit.chest(v, 2, 12, 4, 3)
    kit.wall_lamp(v, "y", 4, F + 9)
    kit.wall_lamp(v, "x", 9, F + 9)
    c.light(4, 1, F + 9)
    c.light(11, 9, F + 6, "candle")
    c.fx.append([8, 8, F + 9, "sparkle"])


def b_chart_table(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["wood"], P["wood_d"])
    kit.rug(v, 0, 0, W, H, P["navy"], P["gold"])
    kit.table(v, 1, 1, 5, 4, h=5, top=P["wood_dd"])
    v.box(1, 1, F + 5, 6, 5, F + 6, P["parch"])
    for i in range(4):
        v.put(2 + i, 2 + (i % 2), F + 5, P["ink"])
    v.put(4, 3, F + 6, P["brass"], GLOSS)
    kit.lamp_post(v, 0, 6, h=10, lit=True)
    c.light(0.5, 6.5, F + 11)
    c.spots.append([5.5, 6.5, 0, "y"])
    c.fx.append([3, 3, F + 8, "sparkle"])


def b_muster_deck(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["plank"], P["plank_d"])

    def ring(x, y, d):
        return P["gold"] if 5.2 <= d <= 6.2 else (P["red"] if d <= 1.6 else None)
    kit.disc(v, 8, 8, 6.2, 0, ring)
    kit.flag_pole(v, 1, 1, 20, P["red"], length=6, height=5)
    kit.drum(v, 13, 3, P["red"])
    kit.drum(v, 13.5, 6.5, P["navy"])
    kit.crate(v, 2, 7, s=4, h=3, c=P["wood_l"])
    v.box(3, 11, F, 5, 13, F + 2, P["wood_d"])
    kit.rope_fence(v, 0, 0, W, H)
    v.box(10, 1, F, 11, 2, F + 12, P["wood_d"])
    v.box(9, 1, F + 9, 12, 3, F + 12, P["gold"], GLOSS)
    c.fx.append([8, 8, F + 10, "notes"])


def b_crew_quarters(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H))
    kit.rug(v, 7, 7, 14, 13, P["red"], P["gold"])
    for z0, blanket in ((F, P["blue"]), (F + 7, P["red"])):
        kit.bed(v, 1, 1, along="x", length=8, width=4, blanket=blanket, z0=z0)
        kit.bed(v, 1, 7, along="y", length=8, width=4, blanket=P["green"] if z0 == F else P["yellow"], z0=z0)
    v.box(8, 1, F, 9, 5, F + 14, P["wood_d"])
    v.box(1, 14, F, 5, 15, F + 14, P["wood_d"])
    kit.chest(v, 11, 1, 4, 3, c=P["wood"])
    kit.chest(v, 10, 13, 4, 3, c=P["wood_d"])
    kit.wall_lamp(v, "y", 12, F + 9, lit=c.work)
    c.light(12, 1, F + 9)
    kit.window(v, "x", 10, lit=True, curtain=P["blue"])
    c.fx.append([5, 4, F + 12, "zzz"])


def b_mess_hall(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_checker(v, W, H, P["cream"], hexrgb("#d9a06a"), n=2))
    kit.table(v, 3, 6, 11, 4, h=5, top=P["wood"], cloth=P["white"])
    for i in range(4, 13, 3):
        v.put(i, 7, F + 5, P["white"])
        v.put(i, 8, F + 5, P["orange"] if c.work else P["white"])
    v.put(8, 7, F + 6, P["red"])
    kit.bench(v, 3, 3, 11, "x")
    kit.bench(v, 3, 11, 11, "x")
    kit.barrel(v, 2.5, 2.5)
    kit.shelf(v, "y", 6, 8, F + 8, [P["white"], P["cream"], None])
    kit.window(v, "x", 9)
    kit.wall_lamp(v, "y", 14, F + 9)
    c.light(14, 1, F + 9)
    c.spots.append([14.5, 13.5, 0, "x"])
    c.fx.append([8, 8, F + 9, "steam"])


def b_practice_deck(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, hexrgb("#e8c48a"), hexrgb("#cfa468"))
    kit.rug(v, 1, 1, W - 1, H - 1, hexrgb("#d2b07a"), P["red"])
    kit.dummy(v, 3, 3)
    kit.dummy(v, 10, 3)
    kit.target(v, 21, 4)
    v.box(15, 0, F, 20, 1, F + 1, P["wood_d"])
    kit.weapon_rack(v, "y", 14, F, 6)
    v.box(14, 0, F, 15, 2, F + 10, P["wood_d"])
    v.box(20, 0, F, 21, 2, F + 10, P["wood_d"])
    kit.sandbags(v, 1, 12, 5, 15, h=3)
    c.spots.append([5.5, 8.5, 0, "y"])
    c.spots.append([12.5, 8.5, 0, "y"])
    c.fx.append([4, 4, F + 10, "hit"])
    c.fx.append([11, 4, F + 10, "hit"])


def b_class_hall(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H, P["wood_l"], P["wood"]))
    kit.blackboard(v, "y", 2, 10)
    kit.banner(v, "x", 3, F + 5, P["red"])
    kit.banner(v, "x", 9, F + 5, P["blue"])
    v.box(12, 3, F, 15, 5, F + 7, P["wood_d"])
    v.box(12, 3, F + 7, 15, 5, F + 8, P["wood_l"], GLOSS)
    for (tx, ty) in ((3, 7), (8, 7), (3, 11), (8, 11)):
        kit.table(v, tx, ty, 4, 2, h=4, top=P["wood"])
        kit.stool(v, tx + 1, ty + 2)
        v.put(tx + 1, ty, F + 4, P["paper"])
    kit.wall_lamp(v, "y", 13, F + 10)
    c.light(13, 1, F + 10)
    c.spots.append([13.5, 6.5, 0, "y"])
    c.fx.append([7, 2, F + 12, "sparkle"])


def b_infirmary(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_tiles(v, W, H, P["white"], hexrgb("#b8e0d4"), n=4))
    kit.bed(v, 1, 1, along="y", length=7, width=4, blanket=P["mint"])
    kit.bed(v, 1, 9, along="y", length=7, width=4, blanket=P["mint"])

    def cross(i, j):
        if (i == 2 and 0 < j < 4) or (j == 2 and 0 < i < 4):
            return P["red"]
        return P["white"]
    kit.on_wall(v, "y", 6, F + 7, 5, 5, cross, depth=1)
    kit.shelf(v, "y", 11, 4, F + 6, [P["red"], P["green"], P["blue"]])
    kit.shelf(v, "y", 11, 4, F + 9, [P["purple"], P["yellow"], P["red"]])
    v.box(9, 3, F, 10, 10, F + 9, P["mint"])
    v.box(9, 3, F + 9, 10, 10, F + 10, P["white"])
    kit.table(v, 12, 11, 3, 3, h=5, top=P["white"])
    kit.flask(v, 13, 12, F + 5, P["red"], lit=c.work)
    kit.wall_lamp(v, "x", 8, F + 10)
    c.light(1, 8, F + 10)
    c.spots.append([7.5, 6.5, 0, "x"])
    c.fx.append([3, 5, F + 8, "heal"])


def b_recovery_room(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_tiles(v, W, H, hexrgb("#d8eef0"), hexrgb("#9ccad0"), n=3),
           wall=hexrgb("#bfe4e8"), wains=hexrgb("#6fb0bc"), trim=P["white"])
    v.box(2, 1, F, 12, 7, F + 3, P["stone"])
    v.box(3, 2, F + 1, 11, 6, F + 3, P["water"], EMIT | NOSHADOW)
    v.box(3, 2, F + 2, 11, 6, F + 3, hexrgb("#7fd0f0"), EMIT | NOSHADOW)
    v.put(5, 3, F + 2, hexrgb("#e0f8ff"), EMIT)
    v.put(8, 4, F + 2, hexrgb("#e0f8ff"), EMIT)
    kit.plant(v, 13, 1, pot=P["white"])
    v.box(14, 5, F, 15, 6, F + 6, P["wood_d"])
    v.box(13, 5, F + 5, 15, 7, F + 6, P["wood"])
    v.box(13, 6, F + 2, 15, 7, F + 5, P["pink"])
    c.spots.append([13.5, 6.0, 0, "x"])
    c.fx.append([6, 3, F + 6, "steam"])
    c.fx.append([9, 4, F + 6, "steam"])
    c.light(7, 4, F + 3, "water")


def b_galley(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_tiles(v, W, H, P["stone"], P["stone_d"], n=3))
    kit.stove(v, 1, 1, w=6, d=4, lit=c.work)
    kit.counter(v, 8, 1, 7, "x")
    for i, col in enumerate((P["leaf"], P["red"], P["orange"], P["cream"])):
        v.put(9 + i * 2, 2, F + 6, col)
    v.box(12, 2, F + 6, 14, 3, F + 7, P["wood_l"])
    for i in range(3):
        v.put(9 + i * 2, 1, F + 11, P["iron"])
        v.put(9 + i * 2, 1, F + 10, P["brass"] if i % 2 else P["iron"])
    kit.barrel(v, 14, 6, h=5, r=1.6)
    if c.work:
        c.light(3.5, 5, F + 2, "fire")
    c.spots.append([4.5, 6.0, 0, "y"])
    c.fx.append([2, 2, F + 19, "smoke"])
    c.fx.append([3, 3, F + 11, "steam"])


def b_workshop(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H, P["wood"], P["wood_d"]),
           wall=hexrgb("#8a6448"), wains=P["stone_d"], trim=P["wood_l"])
    kit.table(v, 3, 1, 8, 4, h=5, top=P["wood_l"])
    v.box(4, 2, F + 5, 6, 3, F + 6, P["iron"])
    v.box(7, 2, F + 5, 10, 3, F + 6, P["steel"], GLOSS)
    for i in range(0, 10, 2):
        v.put(3 + i, 1, F + 9, P["iron"])
        v.put(3 + i, 1, F + 8, P["steel"] if i % 4 else P["wood"])
    kit.anvil(v, 9, 9)
    v.box(1, 9, F, 5, 14, F + 5, P["stone"], SEAM_SIDE)
    v.box(2, 10, F + 5, 4, 13, F + 6, P["fire"] if c.work else P["black"], EMIT if c.work else 0)
    v.box(1, 9, F + 5, 3, 11, F + 14, P["stone_d"], SEAM_SIDE)
    for i in range(3):
        v.box(12, 2 + i, F + i, 15, 3 + i, F + 1 + i, P["wood_l"])
    v.box(12, 5, F, 15, 7, F + 2, P["wood"], SEAM)
    if c.work:
        c.light(3, 11, F + 6, "fire")
    c.spots.append([8.5, 12.5, 0, "y"])
    c.fx.append([11, 10, F + 8, "sparks"])


def b_material_bench(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H), sides="y")
    kit.table(v, 1, 1, 8, 3, h=5, top=P["wood_l"])
    v.box(2, 2, F + 5, 6, 3, F + 6, P["plank"], SEAM)
    for i in range(4):
        v.put(7, 1 + i % 3, F + 5 + i % 2, P["steel"])
    kit.crate(v, 11, 1, s=4, h=4)
    kit.crate(v, 11, 1, s=3, h=3, c=P["wood_l"], z0=F + 4)
    kit.sack(v, 10, 5)
    v.cyl(14, 6, F, F + 1, 1.5, P["rope"])
    c.spots.append([4.5, 5.5, 0, "y"])
    c.fx.append([5, 2, F + 8, "dust"])


def b_lookout(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H)
    top = F + 26
    for (px, py) in ((1, 1), (6, 1), (1, 6), (6, 6)):
        v.box(px, py, F, px + 1, py + 1, top, P["wood_d"], SEAM_SIDE)
    for z in range(F + 6, top, 8):
        for i in range(1, 7):
            v.put(i, 6, z, P["wood"])
            v.put(6, i, z, P["wood"])
    for z in range(F + 1, top, 2):
        v.put(3, 7, z, P["wood_l"])
        v.put(5, 7, z, P["wood_l"])
        v.put(4, 7, z, P["wood"] if z % 4 == 1 else P["wood_l"])
    v.box(0, 0, top, 8, 8, top + 1, P["wood"], SEAM)
    for i in range(8):
        for (x, y) in ((i, 0), (0, i), (i, 7), (7, i)):
            if i % 2 == 0 or (x, y) in ((0, 0), (7, 7)):
                v.box(x, y, top + 1, x + 1, y + 1, top + 4, P["wood_d"])
            v.put(x, y, top + 4, P["wood_l"], GLOSS)
    kit.telescope(v, 4, 2, top + 1)
    v.box(1, 1, top + 1, 2, 2, top + 12, P["wood_d"])
    for i in range(4):
        for j in range(3):
            v.put(1, 2 + i, top + 11 - j, P["red"] if (i + j) % 2 else P["white"], NOSHADOW)
    kit.lamp_post(v, 7, 0, h=4, lit=True) if False else None
    v.box(6, 0, top + 4, 7, 1, top + 6, P["lamp"], EMIT | NOSHADOW)
    c.light(6.5, 0.5, top + 5)
    c.spots.append([4.0, 4.0, top - 1, "x"])
    c.fx.append([5, 3, top + 8, "sparkle"])


def b_compass_room(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H, P["wood_d"], P["wood_dd"]))

    def rose(x, y, d):
        dx, dy = x + 0.5 - 8, y + 0.5 - 4.5
        if 3.0 <= d <= 3.6:
            return P["brass"]
        if (abs(dx) < 0.6 or abs(dy) < 0.6) and d < 3.4:
            return P["gold"]
        if abs(abs(dx) - abs(dy)) < 0.7 and d < 2.4:
            return P["cream"]
        return None
    kit.disc(v, 8, 4.5, 3.6, 0, rose)
    v.box(12, 2, F, 14, 4, F + 5, P["wood_dd"])
    v.box(11, 1, F + 5, 15, 5, F + 6, P["brass"], GLOSS)
    v.box(12, 2, F + 6, 14, 4, F + 7, P["glass"], EMIT if c.work else 0)

    def stars(i, j):
        if i in (0, 7) or j in (0, 5):
            return P["brass"]
        return P["yellow"] if (i * 7 + j * 3) % 5 == 0 else P["navy_d"]
    kit.on_wall(v, "y", 3, F + 6, 8, 6, stars)
    kit.globe(v, 2.5, 5.5)
    kit.wall_lamp(v, "x", 2, F + 9)
    c.light(1, 2, F + 9)
    c.spots.append([6.0, 6.0, 0, "y"])
    c.fx.append([13, 3, F + 10, "sparkle"])


def b_tide_archive(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H, P["wood"], P["wood_d"]))
    kit.bookshelf(v, "y", 1, 14)
    kit.bookshelf(v, "x", 3, 12)
    kit.table(v, 7, 7, 6, 4, h=5, top=P["wood_dd"])
    v.box(8, 8, F + 5, 11, 9, F + 6, P["paper"])
    v.box(9, 9, F + 5, 12, 10, F + 6, P["parch"])
    kit.candle(v, 12, 8, F + 5, lit=c.work)
    kit.chair(v, 9, 11, P["navy"], back="y") if False else kit.stool(v, 9, 11)
    for i in range(6):
        v.box(4 + i, 3 + i // 2, F + i * 2, 5 + i, 4 + i // 2, F + i * 2 + 1, P["wood_l"])
    v.box(13, 12, F, 16, 15, F + 3, P["wood"])
    for i in range(3):
        v.box(13 + i, 12, F + 3, 14 + i, 15, F + 4, P["parch"])
    kit.globe(v, 4.5, 13.5)
    c.light(12, 8, F + 6, "candle")
    c.spots.append([10.5, 12.5, 0, "y"])
    c.fx.append([10, 8, F + 9, "sparkle"])


def b_pantry(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_planks(v, W, H))
    for z in (F + 4, F + 8):
        kit.shelf(v, "y", 1, 10, z, [P["red"], P["yellow"], P["green"], P["orange"], P["cream"]])
    for i in range(1, 10, 3):
        v.put(i, 1, F + 12, P["cream"])
        v.put(i, 1, F + 11, P["cream"])
        v.put(i + 1, 1, F + 12, P["red_d"])
    kit.barrel(v, 13, 2.5)
    kit.barrel(v, 13, 6, h=5)
    kit.sack(v, 2, 4)
    kit.sack(v, 5, 4, P["straw"])
    kit.crate(v, 8, 4, s=3, h=3, c=P["wood_l"])
    v.put(9, 5, F + 3, P["red"])
    v.put(8, 4, F + 3, P["leaf"])


def b_cargo_hold(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["wood"], P["wood_d"])
    kit.back_walls(v, W, H, hexrgb("#a87444"), P["wood_d"], P["wood_l"], height=7)
    kit.crate(v, 1, 1, s=5, h=5)
    kit.crate(v, 1, 1, s=4, h=4, c=P["wood_l"], z0=F + 5)
    kit.crate(v, 7, 1, s=4, h=4, c=hexrgb("#b07040"))
    kit.crate(v, 1, 7, s=4, h=4, c=P["wood_l"])
    kit.barrel(v, 13, 3)
    kit.barrel(v, 13, 3, h=5, z0=F + 6)
    kit.barrel(v, 3, 13)
    kit.sack(v, 7, 7)
    kit.sack(v, 9, 6, P["straw"])
    v.box(9, 10, 0, 14, 15, 1, P["wood_dd"])
    for x in range(9, 14):
        for y in range(10, 15):
            if (x + y) % 2 == 0:
                v.put(x, y, 0, P["black"])
    v.cyl(6, 13, F, F + 1, 2.0, P["rope"])


def b_secure_locker(v, c):
    W, H = c.W, c.H
    kit.floor_tiles(v, W, H, P["stone"], P["stone_d"], n=4)
    v.box(1, 1, F, 6, 5, F + 9, P["iron"], SEAM_SIDE)
    v.box(1, 4, F + 1, 6, 5, F + 8, P["iron_d"])
    v.box(2, 5, F + 3, 5, 6, F + 6, P["steel"], GLOSS)
    v.put(3, 6, F + 4, P["gold"])
    v.box(1, 1, F + 9, 6, 5, F + 10, P["steel"], GLOSS)
    kit.chest(v, 1, 5, w=3, d=2, c=P["wood_d"], open_=c.work, loot=P["gold"])
    v.box(6, 5, F, 7, 7, F + 2, P["gold"], GLOSS)
    if c.work:
        c.fx.append([2, 6, F + 6, "sparkle"])


def b_hatchery(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_straw(v, W, H))
    kit.nest(v, 4, 4, [P["blue"], P["pink"], P["cream"]])
    kit.nest(v, 11, 4, [P["green"], P["yellow"], P["purple"]])
    for x in (4, 11):
        v.box(x, 1, F + 13, x + 1, 2, F + 14, P["iron"])
        v.box(x, 2, F + 10, x + 1, 3, F + 13, P["iron"])
        v.box(x - 1, 2, F + 9, x + 2, 5, F + 10, P["orange"] if c.work else P["iron_d"], EMIT if c.work else 0)
        c.light(x, 3, F + 9, "heat")
    v.box(13, 6, F, 16, 8, F + 4, P["wood_d"])
    v.box(13, 6, F + 4, 16, 8, F + 6, P["glass"], EMIT if c.work else 0)
    c.spots.append([7.5, 6.5, 0, "y"])
    c.fx.append([4, 4, F + 6, "hearts"])
    c.fx.append([11, 4, F + 6, "hearts"])


def b_pet_lab(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_tiles(v, W, H, hexrgb("#e6f0e0"), hexrgb("#b6d0a8"), n=4),
           wall=hexrgb("#a4cf8e"))
    kit.table(v, 4, 1, 9, 4, h=5, top=P["white"])
    for i, col in enumerate((P["green"], P["purple"], P["pink"], P["blue"])):
        kit.flask(v, 5 + i * 2, 2, F + 5, col, lit=c.work)
    kit.tank(v, 1, 8, 4, 7, 7, lit=True)
    v.put(2, 10, F + 5, P["orange"], EMIT)
    v.put(3, 12, F + 6, P["yellow"], EMIT)
    kit.shelf(v, "y", 1, 3, F + 9, [P["green"], P["pink"]])
    kit.disc(v, 12, 12, 2.6, F, P["pink"])
    kit.disc(v, 12, 12, 1.6, F + 1, P["cream"])
    c.light(3, 11, F + 6, "water")
    c.spots.append([8.5, 7.5, 0, "y"])
    c.fx.append([8, 3, F + 9, "bubbles"])


def b_creature_pens(v, c):
    W, H = c.W, c.H
    kit.floor_straw(v, W, H)
    kit.fence(v, 0, 0, W, H, P["wood"], h=4, sides="xyb")
    v.box(7, 0, F, 8, H, F + 4, P["wood_d"])
    v.box(1, 1, F, 5, 4, F + 5, P["wood_l"], SEAM_SIDE)
    v.box(1, 1, F + 5, 5, 4, F + 6, P["red"])
    v.box(2, 3, F, 4, 4, F + 3, P["black"])
    v.box(9, 1, F, 14, 3, F + 2, P["wood_d"])
    v.box(10, 1, F + 1, 13, 3, F + 2, P["leaf"])
    v.box(10, 4, F, 13, 6, F + 2, P["straw"])
    v.put(11, 5, F + 2, P["straw_d"])


def b_tavern_corner(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_checker(v, W, H, P["wood_d"], P["wood_dd"], n=2),
           wall=hexrgb("#b0703c"), trim=P["gold"])
    kit.counter(v, 1, 3, 9, "x")
    for i in range(3):
        kit.stool(v, 2 + i * 3, 6, P["red"])
    for i in range(0, 8, 2):
        kit.bottle(v, 1 + i, 1, F + 7, [P["green"], P["red_d"], P["yellow"], P["purple"]][i // 2])
    v.box(1, 1, F + 6, 10, 2, F + 7, P["wood"])
    kit.barrel(v, 12, 2.5, h=5)
    kit.barrel(v, 14.5, 2.5, h=5)
    kit.barrel(v, 13.2, 2.5, h=4, z0=F + 5)
    v.put(4, 4, F + 6, P["yellow"])
    v.put(7, 4, F + 6, P["cream"])
    kit.wall_lamp(v, "y", 11, F + 10)
    c.light(11, 1, F + 10)
    c.spots.append([4.5, 1.8, 0, "y"])
    c.fx.append([8, 4, F + 9, "notes"])


def b_story_deck(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["plank"], P["plank_d"])
    kit.rug(v, 2, 2, 14, 14, hexrgb("#b65a3a"), P["gold"])
    v.cyl(8, 8, F + 1, F + 3, 2.0, P["iron_d"])
    if c.work:
        v.cyl(8, 8, F + 3, F + 5, 1.2, P["fire"], EMIT | NOSHADOW)
        v.put(8, 8, F + 5, P["fire_l"], EMIT | NOSHADOW)
        c.light(8, 8, F + 5, "fire")
    kit.bench(v, 4, 3, 8, "x", P["wood_l"])
    kit.bench(v, 3, 5, 7, "y", P["wood_l"])
    kit.bench(v, 12, 5, 7, "y", P["wood_l"])
    kit.chair(v, 7, 13, P["red"], back="y") if False else kit.stool(v, 7, 12, P["red"])
    for (px, py) in ((0, 0), (15, 0), (0, 15)):
        v.box(px, py, F, px + 1, py + 1, F + 14, P["wood_d"])
    for i in range(15):
        z = F + 13 - (2 if 4 < i < 11 else 1 if 2 < i < 13 else 0)
        v.put(i, 0, z, P["rope"], NOSHADOW)
        v.put(0, i, z, P["rope"], NOSHADOW)
        if i % 3 == 1:
            col = [P["red"], P["yellow"], P["blue"], P["green"]][(i // 3) % 4]
            v.put(i, 0, z - 1, col, NOSHADOW)
            v.put(0, i, z - 1, col, NOSHADOW)
    c.fx.append([8, 8, F + 9, "sparkle"])


def b_music_room(v, c):
    W, H = c.W, c.H
    c.room(v, lambda v: kit.floor_checker(v, W, H, P["cream"], P["lilac"], n=2))
    kit.piano(v, 1, 1)
    kit.stool(v, 4, 5, P["red"])
    kit.drum(v, 12, 3)
    kit.drum(v, 14, 5.5, P["navy"])
    for j in range(5):
        v.put(13 + (j % 2), 1, F + 8 + j, P["wood_l"] if j < 4 else P["gold"])
    v.box(10, 1, F + 5, 11, 2, F + 11, P["gold"])
    v.box(10, 6, F, 11, 7, F + 6, P["iron"])
    v.box(9, 6, F + 6, 12, 7, F + 8, P["paper"])
    kit.wall_lamp(v, "x", 6, F + 10)
    c.light(1, 6, F + 10)
    c.fx.append([5, 3, F + 12, "notes"])


def b_boarding_gate(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["wood"], P["wood_d"])
    v.box(1, 1, F, 2, 2, F + 16, P["wood_d"], SEAM_SIDE)
    v.box(1, 6, F, 2, 7, F + 16, P["wood_d"], SEAM_SIDE)
    v.box(1, 1, F + 16, 2, 7, F + 18, P["wood"], GLOSS)
    for i in range(2, 6, 3):
        v.box(1, i, F + 12, 2, i + 1, F + 16, P["iron"])
        v.put(2, i, F + 12, P["iron"])
    v.cyl(5, 5, F, F + 1, 1.8, P["rope"])
    for z in range(F, F + 14, 3):
        v.box(1, 3, z, 2, 5, z + 1, P["rope"], NOSHADOW)
    kit.wall_lamp(v, "x", 2, F + 14)
    c.light(1, 2, F + 14)
    c.spots.append([5.0, 3.5, 0, "x"])


def b_barricade_room(v, c):
    W, H = c.W, c.H
    kit.floor_planks(v, W, H, P["wood"], P["wood_d"])
    kit.sandbags(v, 1, 5, 15, 8, h=4)
    kit.crate(v, 1, 1, s=4, h=4)
    kit.cannon(v, 7, 1)
    for x in (5, 12):
        v.box(x, 4, F + 4, x + 1, 5, F + 8, P["steel"])
        v.box(x, 4, F + 8, x + 1, 5, F + 9, P["iron"])
    kit.barrel(v, 14, 2.5, c=P["iron_d"], h=4)


def b_guard_post(v, c):
    W, H = c.W, c.H
    kit.floor_tiles(v, W, H, P["stone"], P["stone_d"], n=4)
    v.box(0, 0, F, 1, 5, F + 14, P["wood_d"], SEAM_R)
    v.box(0, 0, F, 5, 1, F + 14, P["wood_d"], SEAM_L)
    v.box(4, 0, F, 5, 1, F + 14, P["wood_dd"])
    v.box(0, 4, F, 1, 5, F + 14, P["wood_dd"])
    v.box(0, 0, F + 14, 6, 6, F + 15, P["red_d"])
    v.box(0, 0, F + 15, 5, 5, F + 16, P["red"])
    v.box(1, 1, F + 16, 4, 4, F + 17, P["red_d"])
    kit.weapon_rack(v, "y", 1, F, 3)
    v.box(6, 1, F, 7, 2, F + 10, P["wood_d"])
    v.box(5, 1, F + 10, 8, 2, F + 11, P["wood_d"])
    v.box(6, 2, F + 7, 7, 3, F + 10, P["brass"], GLOSS)
    v.box(1, 5, F + 8, 2, 6, F + 11, P["lamp"], EMIT | NOSHADOW)
    c.light(1.5, 5.5, F + 9)
    c.spots.append([4.0, 5.0, 0, "y"])


BUILDERS = {k[2:]: fn for k, fn in globals().items() if k.startswith("b_")}


CELL = 16            # fine voxels per cell (lib.kvol doubles the kit's 8)
INTERIOR_CLIP = 22   # interior levels are cut 22 voxels above the floor surface


def local_screen(x, y, z):
    """Screen offset of a kit-unit point relative to cell (0,0)'s anchor at ship scale."""
    X, Y, Z = x * K, y * K, fzf(z)
    h = CELL / 2
    return [round(2 * (X - Y), 1), round((X - h) + (Y - h) - 2 * (Z - F), 1)]


def build_one(fid, rot, work):
    """Ship-scale render sliced per cell (16 voxels per cell, 1.5x heights)."""
    f = FAC[fid]
    w, h = int(f["w"]), int(f["h"])
    W, H = 8 * w, 8 * h
    clip = INTERIOR_CLIP if f.get("zone", "interior") == "interior" else None
    kv = KVol(W, H, 48, clip_z=clip)
    ctx = Ctx(W, H, work, f["category"])
    BUILDERS[fid](kv, ctx)
    v = kv.v
    if rot == 1:
        v = v.mirror_xy()
        ctx.spots = [[s[1], s[0], s[2], "x" if s[3] == "y" else "y"] for s in ctx.spots]
        ctx.fx = [[p[1], p[0], p[2], p[3]] for p in ctx.fx]
        ctx.lights = [[p[1], p[0], p[2], p[3]] for p in ctx.lights]
    X, Y, Z = v.shape
    gx = np.arange(X) // CELL
    gy = np.arange(Y) // CELL
    G = gy[None, :] * 16 + gx[:, None]
    v.group[...] = np.where(v.solid, G[:, :, None], -1)
    r = render(v, shadow_len=60)
    pieces = slice_groups(r)
    out = []
    c = CELL // 2
    for g, (crop, (x0, y0)) in pieces.items():
        cx, cy = g % 16, g // 16
        # anchor of cell (cx, cy): voxel (16cx+8, 16cy+8, F)
        ax = r.origin[0] + 2 * ((CELL * cx + c) - (CELL * cy + c))
        ay = r.origin[1] + (CELL * cx + c) + (CELL * cy + c) - 2 * F
        out.append((cx, cy, crop, [int(x0 - ax), int(y0 - ay)]))
    meta = {
        "spots": [[round(s[0] / 8 - 0.5, 3), round(s[1] / 8 - 0.5, 3), s[2], s[3]] for s in ctx.spots],
        "fx": [local_screen(p[0], p[1], p[2]) + [p[3]] for p in ctx.fx],
        "lights": [local_screen(p[0], p[1], p[2]) + [p[3]] for p in ctx.lights],
    }
    full, _ = trim(r.rgba)
    return out, meta, full


def build_card(fid):
    """Compact unscaled render for menus and info cards."""
    f = FAC[fid]
    W, H = 8 * int(f["w"]), 8 * int(f["h"])
    v = Vol(W, H, 48)
    BUILDERS[fid](v, Ctx(W, H, False, f["category"]))
    full, _ = trim(render(v).rgba)
    return full


def main():
    pk = Packer(width=4096)
    cards = Packer(width=1024)
    table = {}
    previews = []
    for fid in FAC:
        f = FAC[fid]
        entry = {"w": int(f["w"]), "h": int(f["h"]), "category": f["category"], "rot": {}}
        for rot in (0, 1):
            re = {}
            for work in (False, True):
                state = "work" if work else "idle"
                pieces, meta, full = build_one(fid, rot, work)
                plist = []
                for cx, cy, crop, off in pieces:
                    name = f"{fid}:{rot}:{state}:{cx}:{cy}"
                    pk.add(name, crop, off=off)
                    plist.append(name)
                re[state] = plist
                if not work:
                    re.update(meta)
                if rot == 0 and not work:
                    cards.add(fid, build_card(fid))
                    previews.append((fid, full))
            entry["rot"][str(rot)] = re
        table[fid] = entry
    rects, size = pk.pack(OUT / "facilities" / "facilities.png")
    for fid, e in table.items():
        for rot, re in e["rot"].items():
            for state in ("idle", "work"):
                re[state] = [dict(name=n, cell=[int(n.split(":")[3]), int(n.split(":")[4])], **rects[n])
                             for n in re[state]]
    save_json(table, OUT / "facilities" / "facilities.json")
    crects, csize = cards.pack(OUT / "facilities" / "cards.png")
    save_json(crects, OUT / "facilities" / "cards.json")
    record((OUT / "facilities" / "facilities.png").relative_to(GAME.parent), f"{size[0]}x{size[1]} atlas",
           "2 states (idle, working) x 2 rotations", "voxel dioramas (lib/kit.py) rendered by lib/vox.py",
           "All 27 facilities at ship scale (16 voxels per cell), sliced per cell for depth sorting; spots/FX/lights in facilities.json")
    record((OUT / "facilities" / "cards.png").relative_to(GAME.parent), f"{csize[0]}x{csize[1]} atlas", "static",
           "same renders, uncut", "Build menu and info cards")
    # contact sheet preview
    from PIL import Image
    cols = 6
    cell_w = max(a.shape[1] for _, a in previews) + 8
    cell_h = max(a.shape[0] for _, a in previews) + 8
    rows = (len(previews) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (219, 162, 92, 255))
    for i, (fid, a) in enumerate(previews):
        sheet.alpha_composite(Image.fromarray(a), ((i % cols) * cell_w + 4, (i // cols) * cell_h + 4))
    save_png(sheet, PREVIEW / "facilities.png")
    print("facilities", len(table), size)


if __name__ == "__main__":
    main()
