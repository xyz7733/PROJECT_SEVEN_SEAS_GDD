"""Layered chibi puppet sprites for crew and humanoid NPCs.

Each layer variant is one row of 21 frames (24x32). Godot stacks the layers
(hair_back, outfit, skin, hair_front, hat, weapon) as Sprite2D children that
share a frame index. Hair is drawn in greyscale and tinted with modulate.
"""
from __future__ import annotations

import json

import numpy as np
from PIL import Image

from lib.common import GAME, OUT, PREVIEW, record, save_json, save_png
from lib.pix import AUTO, DEEP, FLAT, LIGHT, SHADE, SHINE, Canvas, over
from lib.vox import hexrgb, mix, mul

FW, FH = 24, 32
ORIGIN = (12, 29)
FRAMES = ["idle0", "idle1", "walk0", "walk1", "walk2", "walk3", "work0", "work1",
          "atk0", "atk1", "atk2", "hit", "down", "cheer0", "cheer1",
          "bidle0", "bidle1", "bwalk0", "bwalk1", "bwalk2", "bwalk3"]
ATLAS_COLS = 2  # rows of 21 frames placed side by side per atlas line

# ---------------------------------------------------------------- poses ----


def _pose(**kw):
    p = dict(bob=0, lean=0, hdx=0, hdy=0, legs=((0, 0), (0, 0)), far=(-1, 6), near=(1, 6),
             eyes="open", mouth=None, back=False, kneel=False, act="rest", wave=0)
    p.update(kw)
    return p


POSES = {
    "idle0": _pose(),
    "idle1": _pose(bob=1, wave=1),
    "walk0": _pose(legs=((2, 0), (-2, 0)), far=(-3, 5), near=(3, 5), act="walk"),
    "walk1": _pose(bob=-1, legs=((0, 0), (0, 2)), act="walk", wave=1),
    "walk2": _pose(legs=((-2, 0), (2, 0)), far=(2, 5), near=(-2, 5), act="walk"),
    "walk3": _pose(bob=-1, legs=((0, 2), (0, 0)), act="walk", wave=1),
    "work0": _pose(near=(2, -3), far=(1, 5), act="work0", mouth="smile"),
    "work1": _pose(bob=1, lean=1, near=(4, 4), far=(2, 5), act="work1", wave=1),
    "atk0": _pose(lean=-2, bob=1, near=(-3, -5), far=(1, 4), act="wind", legs=((1, 0), (-1, 0))),
    "atk1": _pose(lean=2, near=(6, 0), far=(-2, 5), legs=((3, 0), (-2, 1)), act="strike", mouth="open", wave=1),
    "atk2": _pose(lean=1, near=(4, 5), far=(-1, 5), legs=((2, 0), (-2, 0)), act="follow"),
    "hit": _pose(lean=-2, hdx=-1, near=(-3, 2), far=(-3, 3), legs=((-1, 0), (1, 0)), eyes="hurt",
                 mouth="open", act="hit"),
    "down": _pose(bob=4, lean=1, hdy=1, near=(3, 8), far=(3, 8), kneel=True, eyes="closed", act="down"),
    "cheer0": _pose(bob=-1, near=(1, -8), far=(-1, -8), eyes="happy", mouth="open", act="cheer",
                    legs=((0, 1), (0, 0))),
    "cheer1": _pose(near=(2, -6), far=(-2, -6), eyes="happy", mouth="smile", act="cheer", wave=1),
    "bidle0": _pose(back=True),
    "bidle1": _pose(back=True, bob=1, wave=1),
    "bwalk0": _pose(back=True, legs=((-2, 0), (2, 0)), far=(2, 5), near=(-2, 5), act="walk"),
    "bwalk1": _pose(back=True, bob=-1, legs=((0, 0), (0, 2)), act="walk", wave=1),
    "bwalk2": _pose(back=True, legs=((2, 0), (-2, 0)), far=(-2, 5), near=(2, 5), act="walk"),
    "bwalk3": _pose(back=True, bob=-1, legs=((0, 2), (0, 0)), act="walk", wave=1),
}


class Geo:
    def __init__(self, p):
        ox, oy = p["lean"], p["bob"]
        self.p = p
        self.hx, self.hy = 6 + ox + p["hdx"], 3 + oy + p["hdy"]
        self.tx, self.ty = 8 + ox, 14 + oy
        self.sh_far = (self.tx, self.ty + 1)
        self.sh_near = (self.tx + 7, self.ty + 1)
        self.hand_far = (self.sh_far[0] + p["far"][0], self.sh_far[1] + p["far"][1])
        self.hand_near = (self.sh_near[0] + p["near"][0], self.sh_near[1] + p["near"][1])
        self.hip_y = self.ty + 8
        self.face = -1 if p["back"] else 1


GEOS = {f: Geo(POSES[f]) for f in FRAMES}

# ------------------------------------------------------------- palette ----
LEATHER = "#7a5236"
LEATHER_D = "#4e3424"
GOLD = "#f0c048"
STEEL = "#c4ccd8"
STEEL_D = "#7d8696"
WOOD = "#9a6a3e"
WHITE = "#f4efe2"
BLACK = "#3a3040"


def C(x):
    return hexrgb(x) if isinstance(x, str) else x


# ------------------------------------------------------------- outfits ----

def arm(cv, sh, hand, sleeve, glove, tone=AUTO, cuff=None):
    sx, sy = sh
    hx, hy = hand
    cv.line(sx, sy, hx, hy, sleeve, tone, th=2)
    if cuff:
        cv.rect(hx, hy - 1 if hy > sy else hy + 1, hx + 1, hy - 1 if hy > sy else hy + 1, cuff, tone)
    cv.rect(hx, hy, hx + 1, hy + 1, glove, tone)


def legs(cv, g, s):
    p = g.p
    P, B = s["P"], s["B"]
    if p["kneel"]:
        tx = g.tx
        cv.rect(tx + 1, 26, tx + 7, 28, P)
        cv.rect(tx + 6, 27, tx + 8, 28, P, LIGHT)
        cv.rect(tx - 1, 28, tx + 2, 29, B)
        return
    for i, (hipx, (dx, lift)) in enumerate(((g.tx + 2, p["legs"][0]), (g.tx + 5, p["legs"][1]))):
        tone = SHADE if i == 0 else AUTO
        fy = 29 - lift
        hy = g.hip_y
        for y in range(hy, fy + 1):
            t = (y - hy) / max(1, fy - hy)
            cx = int(round(hipx + dx * t))
            col = B if y >= fy - 1 else P
            cv.hline(cx - 1, cx + 1, y, col, tone)
        cx = int(round(hipx + dx))
        cv.px(cx + 2 * g.face, fy, B, tone)
    cv.hline(g.tx + 1, g.tx + 6, g.hip_y, P)


def skirt(cv, g, x0, x1, y0, y1, col, gap=None, hem=None, flare=0):
    for y in range(y0, y1 + 1):
        k = (y - y0) * flare // max(1, (y1 - y0))
        for x in range(x0 - k, x1 + k + 1):
            if gap and gap[0] <= x <= gap[1] and y >= gap[2]:
                continue
            tone = SHADE if x >= x1 - 1 + k else AUTO
            cv.px(x, y, hem if (hem and y == y1) else col, tone)


def draw_outfit(cv, g, s):
    p = g.p
    back = p["back"]
    tx, ty = g.tx, g.ty
    c_main, D, A = s["C"], s.get("D", s["C"]), s.get("A", GOLD)
    S = s.get("S", c_main)
    G = s.get("G", LEATHER)
    M = s.get("M", GOLD)
    ex = s.get("extra", ())
    shape = s["shape"]

    if "cape" in ex and not back:
        cape = s.get("K", A)
        cv.poly([(tx - 1, ty), (tx + 9, ty), (tx + 10, 27), (tx - 3, 27)], cape, SHADE)
    if "pack" in ex and not back:
        cv.rect(tx - 2, ty + 1, tx, ty + 7, s.get("K", LEATHER), SHADE)
    if "tailhair" in ex:
        pass

    if not back:
        arm(cv, g.sh_far, g.hand_far, S, G, SHADE)

    legs(cv, g, s)

    # torso
    cv.rect(tx, ty, tx + 7, ty + 7, c_main)
    for y in range(ty + 1, ty + 7):
        cv.px(tx + 7, y, c_main, SHADE)

    if shape == "tunic":
        if not back:
            cv.rect(tx + 3, ty, tx + 5, ty, D, FLAT)
            cv.px(tx + 4, ty + 1, D, FLAT)
        cv.hline(tx, tx + 7, ty + 6, LEATHER)
        if not back:
            cv.px(tx + 5, ty + 6, M, LIGHT)
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, c_main)
    elif shape in ("coat", "labcoat"):
        length = 11 if shape == "labcoat" else 10
        if not back:
            cv.rect(tx + 4, ty, tx + 5, ty + 2, D, FLAT)
            cv.px(tx + 3, ty, D, LIGHT)
            cv.px(tx + 3, ty + 1, D, FLAT)
            cv.px(tx + 6, ty, D, LIGHT)
            cv.px(tx + 6, ty + 1, D, FLAT)
            if shape == "coat":
                cv.px(tx + 5, ty + 3, M, LIGHT)
                cv.px(tx + 5, ty + 5, M, LIGHT)
        if "belt" in ex:
            cv.hline(tx, tx + 7, ty + 6, s.get("L", LEATHER))
            if not back:
                cv.px(tx + 5, ty + 6, M, LIGHT)
        if p["kneel"]:
            cv.rect(tx - 1, ty + 7, tx + 8, ty + 9, c_main)
        else:
            gap = None if back else (tx + 5, tx + 6, ty + 8)
            skirt(cv, g, tx, tx + 7, ty + 7, ty + length, c_main, gap=gap, hem=D if "hem" in ex else None,
                  flare=1)
            if back:
                cv.vline(tx + 3, ty + 8, ty + length, c_main, DEEP)
        if shape == "labcoat" and "cross" in ex:
            if back:
                cx, cy = tx + 3, ty + 3
                cv.rect(cx - 1, cy, cx + 2, cy + 1, A, FLAT)
                cv.rect(cx, cy - 1, cx + 1, cy + 2, A, FLAT)
            else:
                cx, cy = tx + 2, ty + 3
                cv.hline(cx - 1, cx + 1, cy, A, FLAT)
                cv.vline(cx, cy - 1, cy + 1, A, FLAT)
    elif shape == "armor":
        cv.rect(tx, ty, tx + 7, ty + 7, M)
        cv.rect(tx + 1, ty + 1, tx + 2, ty + 2, M, LIGHT)
        for y in range(ty + 1, ty + 7):
            cv.px(tx + 7, y, M, SHADE)
        if not p["kneel"]:
            cv.rect(tx + 3, ty + 2, tx + 5, ty + 9, c_main)
            cv.vline(tx + 5, ty + 3, ty + 9, c_main, SHADE)
            if not back:
                cv.px(tx + 4, ty + 3, A, LIGHT)
        cv.hline(tx, tx + 7, ty + 6, s.get("L", LEATHER))
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, M)
            cv.rect(tx + 3, ty + 7, tx + 5, ty + 9, c_main)
    elif shape == "robe":
        if p["kneel"]:
            cv.rect(tx - 1, ty + 7, tx + 8, ty + 10, c_main)
            cv.hline(tx - 1, tx + 8, ty + 10, D)
        else:
            y1 = 28
            skirt(cv, g, tx, tx + 7, ty + 6, y1, c_main, hem=D, flare=2)
            if not back:
                cv.vline(tx + 5, ty, y1 - 1, D, FLAT)
        if not back:
            cv.rect(tx + 3, ty, tx + 5, ty, D, FLAT)
        cv.hline(tx, tx + 7, ty + 6, A)
        if not back and not p["kneel"]:
            cv.vline(tx + 6, ty + 7, ty + 9, A, SHADE)
    elif shape == "apron":
        W = s.get("W", WHITE)
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, c_main)
        if back:
            cv.hline(tx, tx + 7, ty + 5, W)
            cv.rect(tx + 3, ty + 4, tx + 4, ty + 6, W, LIGHT)
            cv.line(tx + 1, ty, tx + 3, ty + 4, W)
            cv.line(tx + 6, ty, tx + 4, ty + 4, W)
        else:
            cv.rect(tx + 4, ty, tx + 5, ty + 1, W)
            bottom = ty + 11 if not p["kneel"] else ty + 9
            cv.rect(tx + 2, ty + 2, tx + 7, bottom, W)
            cv.vline(tx + 7, ty + 3, bottom, W, SHADE)
            cv.hline(tx + 3, tx + 6, ty + 7, W, SHADE)
            cv.hline(tx + 1, tx + 2, ty + 5, W)
    elif shape == "vest":
        cv.rect(tx, ty, tx + 7, ty + 7, D)
        for y in range(ty + 1, ty + 7):
            cv.px(tx + 7, y, D, SHADE)
        if back:
            cv.rect(tx, ty, tx + 7, ty + 6, c_main)
        else:
            cv.rect(tx, ty, tx + 3, ty + 6, c_main)
            cv.rect(tx + 6, ty, tx + 7, ty + 6, c_main, SHADE)
            cv.px(tx + 3, ty + 1, c_main, LIGHT)
        cv.hline(tx, tx + 7, ty + 6, s.get("L", LEATHER))
        if not back:
            cv.px(tx + 5, ty + 6, M, LIGHT)
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, s["P"])
    elif shape == "jacket":
        cv.rect(tx, ty + 6, tx + 7, ty + 7, D)
        if not back:
            cv.vline(tx + 5, ty, ty + 5, D, FLAT)
            cv.rect(tx + 3, ty, tx + 4, ty, D, LIGHT)
            cv.px(tx + 6, ty, D, LIGHT)
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, s["P"])
    elif shape == "overall":
        cv.rect(tx, ty, tx + 7, ty + 7, D)
        for y in range(ty + 1, ty + 7):
            cv.px(tx + 7, y, D, SHADE)
        if back:
            cv.line(tx + 1, ty, tx + 3, ty + 4, c_main)
            cv.line(tx + 6, ty, tx + 4, ty + 4, c_main)
            cv.rect(tx, ty + 5, tx + 7, ty + 7, c_main)
        else:
            cv.vline(tx + 2, ty, ty + 2, c_main)
            cv.vline(tx + 6, ty, ty + 2, c_main)
            cv.rect(tx + 2, ty + 3, tx + 7, ty + 7, c_main)
            cv.px(tx + 2, ty + 3, M, LIGHT)
            cv.px(tx + 6, ty + 3, M, LIGHT)
            cv.hline(tx + 3, tx + 5, ty + 5, c_main, SHADE)
        if not p["kneel"]:
            skirt(cv, g, tx, tx + 7, ty + 7, ty + 8, c_main)

    # extras on the torso
    if "sash" in ex:
        cv.line(tx, ty + 1, tx + 7, ty + 6, s.get("A", A))
    if "bandolier" in ex:
        if back:
            cv.line(tx + 7, ty, tx, ty + 6, LEATHER_D)
        else:
            cv.line(tx, ty, tx + 7, ty + 6, LEATHER_D)
            for i in range(0, 8, 2):
                cv.px(tx + i, ty + (i * 6) // 7, M, LIGHT)
    if "pouch" in ex and not back:
        cv.rect(tx + 6, ty + 7, tx + 8, ty + 8, s.get("L", LEATHER))
        cv.px(tx + 7, ty + 7, M, LIGHT)
    if "tools" in ex:
        cv.rect(tx, ty + 7, tx + 1, ty + 8, LEATHER)
        cv.px(tx + 1, ty + 6, STEEL, LIGHT)
    if "emblem" in ex and not back:
        cv.rect(tx + 5, ty + 2, tx + 6, ty + 3, A, LIGHT)
    if "fur" in ex:
        F = s.get("F", "#d8bf94")
        cv.rect(tx - 1, ty - 1, tx + 8, ty + 1, F)
        for x in range(tx - 1, tx + 9, 2):
            cv.px(x, ty + 2, F, SHADE)
    if "scarf" in ex:
        sc = s.get("A", A)
        cv.hline(tx + 1, tx + 6, ty, sc)
        cv.hline(tx + 1, tx + 6, ty + 1, sc, SHADE)
        if back:
            cv.vline(tx + 3, ty + 2, ty + 5, sc)
            cv.vline(tx + 4, ty + 2, ty + 4, sc, SHADE)
        else:
            off = 1 if p["wave"] else 0
            cv.vline(tx + 1, ty + 2, ty + 4, sc)
            cv.vline(tx, ty + 3, ty + 5 + off, sc, SHADE)
    if "cape" in ex and back:
        cape = s.get("K", A)
        cv.poly([(tx - 1, ty), (tx + 9, ty), (tx + 10, 27), (tx - 2, 27)], cape)
        cv.vline(tx + 4, ty + 3, 26, cape, SHADE)
        cv.hline(tx - 1, tx + 9, ty, s.get("D", D), LIGHT)
    if "pack" in ex and back:
        k = s.get("K", LEATHER)
        cv.rect(tx + 1, ty + 1, tx + 6, ty + 7, k)
        cv.hline(tx + 1, tx + 6, ty + 3, k, SHADE)
        cv.px(tx + 3, ty + 4, M, LIGHT)

    draw_profession(cv, g, s)

    # front arm and pauldrons
    if back:
        arm(cv, g.sh_far, g.hand_far, S, G)
    arm(cv, g.sh_near, g.hand_near, S, G)
    if shape == "armor" or "pauldrons" in ex:
        pm = s.get("Q", M if shape == "armor" else c_main)
        for (sx, sy) in (g.sh_far, g.sh_near):
            cv.rect(sx - 1, sy - 1, sx + 1, sy, pm)
            cv.px(sx - 1, sy - 1, pm, LIGHT)


# Accessories occupy a few deliberate clusters, rather than scattering a
# different noise pattern over every shirt. They move with the existing rig.
PROFESSION_KITS = {
    "guard": ("shield", 0), "guardian": ("shield", 1), "bulwark": ("shield", 2),
    "duelist": ("duel", 0), "blade_dancer": ("duel", 1), "challenger": ("duel", 2),
    "spearfighter": ("spear", 0), "harpooner": ("spear", 1), "dragoon": ("spear", 2),
    "gunner": ("powder", 0), "sharpshooter": ("powder", 1), "skirmisher": ("powder", 2),
    "brawler": ("fist", 0), "breaker": ("fist", 1), "grappler": ("fist", 2),
    "medic": ("medical", 0), "surgeon": ("medical", 1), "lifekeeper": ("medical", 2),
    "cook": ("galley", 0), "provisioner": ("galley", 1), "feastmaster": ("galley", 2),
    "navigator": ("chart", 0), "pathfinder": ("chart", 1), "tide_reader": ("chart", 2),
    "tinkerer": ("craft", 0), "engineer": ("craft", 1), "trapper": ("craft", 2),
    "beastkeeper": ("beast", 0), "beastwarden": ("beast", 1), "wildspeaker": ("beast", 2),
    "mystic": ("arcane", 0), "stormcaller": ("arcane", 1), "hexbreaker": ("arcane", 2),
    "quartermaster": ("officer", 0), "purser": ("officer", 1), "standard_bearer": ("officer", 2),
}


def draw_profession(cv, g, s):
    identity = s.get("identity", "")
    tx, ty = g.tx, g.ty
    a, metal = s.get("A", GOLD), s.get("M", STEEL)
    if identity not in PROFESSION_KITS:
        # Named captains have individual badges, also visible from the back.
        signature = s.get("signature")
        if signature:
            cx, cy = tx + (3 if g.p["back"] else 2), ty + 3
            if signature in ("sun", "prism", "pearl"):
                cv.poly([(cx, cy - 2), (cx + 2, cy), (cx, cy + 2), (cx - 2, cy)], a, LIGHT)
            elif signature in ("leaf", "wing"):
                cv.line(cx - 1, cy + 2, cx + 2, cy - 2, a, FLAT)
                cv.hline(cx - 1, cx + 1, cy, a, LIGHT)
            elif signature in ("moon", "lantern"):
                cv.rect(cx - 1, cy - 1, cx + 1, cy + 1, a)
                cv.px(cx, cy, WHITE, SHINE)
            else:
                cv.hline(cx - 1, cx + 1, cy, a, LIGHT)
                cv.vline(cx, cy - 1, cy + 2, a, FLAT)
        return
    family, rank = PROFESSION_KITS[identity]
    back = g.p["back"]
    if family == "shield":
        # Riveted shoulder plates distinguish guard, winged guardian and
        # the closed, slab-sided bulwark even without a held shield.
        cv.rect(tx - 2, ty, tx, ty + 2, metal)
        cv.hline(tx - 2, tx, ty, metal, LIGHT)
        if rank == 1:
            cv.poly([(tx - 2, ty + 1), (tx - 4, ty - 2), (tx - 1, ty - 1)], WHITE)
        if rank == 2:
            cv.rect(tx - 2, ty, tx + 1, ty + 3, metal)
            cv.vline(tx - 1, ty + 1, ty + 3, a, FLAT)
    elif family == "duel":
        cv.line(tx + 1, ty, tx + 3, ty + 3, WHITE, LIGHT)
        cv.px(tx + 2, ty + 2, a, LIGHT)
        if rank:
            cv.line(tx - 1, ty + 6, tx - 3, ty + 9 + g.p["wave"], a, SHADE)
        if rank == 2:
            cv.rect(tx - 1, ty - 1, tx + 1, ty, GOLD, LIGHT)
    elif family == "spear":
        cv.rect(tx - 1, ty + 5, tx + 1, ty + 8, LEATHER)
        cv.px(tx, ty + 5, metal, LIGHT)
        if rank == 1:
            cv.line(tx + 1, ty + 1, tx + 6, ty + 6, "#dfc68b", FLAT)
        if rank == 2:
            cv.rect(tx - 2, ty - 1, tx + 1, ty, metal)
            cv.px(tx - 3, ty - 2, WHITE, LIGHT)
    elif family == "powder":
        cv.line(tx, ty + 1, tx + 7, ty + 6, LEATHER_D, th=2)
        for dx in (1, 3, 5):
            cv.vline(tx + dx, ty + 1 + dx // 2, ty + 2 + dx // 2, GOLD if rank == 1 else STEEL, LIGHT)
        cv.rect(tx - 2, ty + 6, tx, ty + 8, LEATHER)
        if rank == 2:
            cv.hline(tx - 2, tx, ty + 6, a, LIGHT)
    elif family == "fist":
        cv.hline(tx - 1, tx + 1, ty + 1, WHITE, LIGHT)
        cv.hline(tx + 6, tx + 8, ty + 1, WHITE, LIGHT)
        if rank == 1:
            cv.rect(tx - 2, ty + 2, tx, ty + 4, "#aa7044")
        elif rank == 2:
            cv.rect(tx + 2, ty + 5, tx + 5, ty + 6, GOLD)
            cv.px(tx + 3, ty + 5, WHITE, SHINE)
    elif family == "medical":
        cv.rect(tx - 2, ty + 5, tx + 1, ty + 8, "#f2e8d0")
        cv.hline(tx - 1, tx, ty + 6, "#bd4e57", FLAT)
        cv.vline(tx, ty + 5, ty + 7, "#bd4e57", FLAT)
        if rank == 1:
            cv.line(tx + 1, ty + 1, tx + 6, ty + 5, STEEL_D, FLAT)
        if rank == 2:
            cv.poly([(tx, ty), (tx + 4, ty + 3), (tx + 8, ty), (tx + 4, ty + 1)], GOLD)
    elif family == "galley":
        cv.rect(tx - 2, ty + 5, tx, ty + 9, "#f2e8d0")
        cv.hline(tx - 2, tx, ty + 7, a, FLAT)
        if rank == 1:
            cv.rect(tx - 3, ty + 1, tx - 1, ty + 5, "#c49a65")
            cv.px(tx - 2, ty + 1, "#efe0ad", LIGHT)
        if rank == 2:
            cv.px(tx + 2, ty + 2, GOLD, SHINE)
            cv.px(tx + 5, ty + 2, GOLD, SHINE)
    elif family == "chart":
        cv.rect(tx - 2, ty + 3, tx, ty + 8, "#e8d9ae")
        cv.hline(tx - 2, tx, ty + 3, "#faf0d0", LIGHT)
        cv.hline(tx - 2, tx, ty + 7, LEATHER, FLAT)
        if rank == 1:
            cv.line(tx + 1, ty, tx + 7, ty + 5, LEATHER, FLAT)
        if rank == 2:
            cv.ellipse(tx + 4, ty + 3, 1.5, 1.5, a)
            cv.px(tx + 4, ty + 2, WHITE, SHINE)
    elif family == "craft":
        cv.rect(tx - 2, ty + 6, tx + 1, ty + 8, LEATHER)
        cv.vline(tx - 1, ty + 3, ty + 6, STEEL)
        cv.hline(tx - 2, tx, ty + 3, STEEL, LIGHT)
        if rank == 1:
            cv.rect(tx + 4, ty + 2, tx + 6, ty + 4, "#c4a574")
        if rank == 2:
            cv.ellipse(tx - 1, ty + 2, 2, 2, LEATHER_D)
            cv.px(tx - 1, ty + 2, GOLD, LIGHT)
    elif family == "beast":
        cv.rect(tx - 2, ty + 4, tx + 1, ty + 7, "#a7794b")
        cv.hline(tx - 2, tx + 1, ty + 4, "#d7bd83", LIGHT)
        if rank == 1:
            cv.poly([(tx - 2, ty), (tx - 3, ty - 2), (tx + 1, ty - 1)], "#e2d3af")
        if rank == 2:
            cv.px(tx - 1, ty, "#e4adba", LIGHT)
            cv.px(tx + 1, ty + 1, "#94c15f", LIGHT)
    elif family == "arcane":
        cv.poly([(tx - 1, ty), (tx + 4, ty + 3), (tx + 8, ty), (tx + 4, ty + 1)], a)
        cv.px(tx + 4, ty + 3, WHITE, SHINE)
        if rank == 1:
            cv.line(tx - 1, ty + 4, tx + 1, ty + 5, GOLD, LIGHT)
        if rank == 2:
            cv.rect(tx - 2, ty + 5, tx + 1, ty + 8, "#795584")
            cv.hline(tx - 1, tx, ty + 6, "#eee4cb", LIGHT)
    elif family == "officer":
        cv.rect(tx - 1, ty - 1, tx + 1, ty, GOLD)
        cv.rect(tx + 6, ty - 1, tx + 8, ty, GOLD)
        cv.px(tx + 2, ty + 3, a, LIGHT)
        if rank == 1:
            cv.line(tx + 5, ty + 5, tx + 7, ty + 7, GOLD, FLAT)
        if rank == 2 and back:
            cv.poly([(tx + 2, ty + 3), (tx + 4, ty + 1), (tx + 6, ty + 3), (tx + 4, ty + 5)], WHITE)


# ----------------------------------------------------------------- skin ----
SKINS = {
    "s1": "#f7d2b4", "s2": "#efbf98", "s3": "#d8a074", "s4": "#a8714a", "s5": "#7a4e34",
    "ash": "#b8b0b8", "mint": "#a8d8c0", "moon": "#c4c4f0",
}
EYE = (40, 30, 52)
IRIS = (70, 66, 120)


def draw_head(cv, g, skin):
    p = g.p
    hx, hy = g.hx, g.hy
    rows = {0: (3, 8), 1: (1, 10), 9: (1, 10), 10: (3, 9)}
    for r in range(11):
        a, b = rows.get(r, (0, 11))
        if g.p["back"] and r == 10:
            a, b = 2, 9
        cv.hline(hx + a, hx + b, hy + r, skin)
    cv.vline(hx + 11, hy + 3, hy + 8, skin, SHADE)
    cv.rect(hx + 5, hy + 11, hx + 6, hy + 11, skin, SHADE)  # neck
    if p["back"]:
        cv.rect(hx + 1, hy + 6, hx + 1, hy + 7, skin, SHADE)
        cv.rect(hx + 10, hy + 6, hx + 10, hy + 7, skin, SHADE)
        return
    cv.rect(hx + 2, hy + 6, hx + 2, hy + 7, skin, SHADE)  # ear
    e1, e2, ey = hx + 5, hx + 9, hy + 6
    blush = mix(C(skin), (222, 123, 116), 0.28)
    eyes = p["eyes"]
    if eyes == "open":
        for ex in (e1, e2):
            cv.rect(ex, ey, ex + 1, ey + 1, EYE, FLAT)
            cv.px(ex, ey, "#fff2da", FLAT)
            cv.px(ex + 1, ey + 1, IRIS, FLAT)
        cv.px(hx + 8, hy + 8, mix(C(skin), (255, 240, 207), 0.3), FLAT)
    elif eyes == "closed":
        for ex in (e1, e2):
            cv.px(ex, ey + 1, EYE, FLAT)
            cv.px(ex - 1, ey + 1, mul(C(skin), 0.7), FLAT)
    elif eyes == "happy":
        for ex in (e1, e2):
            cv.px(ex, ey, EYE, FLAT)
            cv.px(ex - 1, ey + 1, EYE, FLAT)
            cv.px(ex + 1, ey + 1, EYE, FLAT)
    elif eyes == "hurt":
        cv.px(e1 - 1, ey, EYE, FLAT)
        cv.px(e1, ey + 1, EYE, FLAT)
        cv.px(e1 - 1, ey + 2, EYE, FLAT)
        cv.px(e2 + 1, ey, EYE, FLAT)
        cv.px(e2, ey + 1, EYE, FLAT)
        cv.px(e2 + 1, ey + 2, EYE, FLAT)
    cv.px(e1 - 1, ey + 2, blush, FLAT) if eyes != "hurt" else None
    cv.px(e2 + 1, ey + 2, blush, FLAT) if eyes != "hurt" else None
    mouth = p["mouth"]
    if mouth == "open":
        cv.px(hx + 7, hy + 8, (150, 60, 70), FLAT)
        cv.px(hx + 7, hy + 9, (110, 40, 56), FLAT)
    elif mouth == "smile":
        cv.px(hx + 7, hy + 9, (150, 70, 70), FLAT)
    else:
        cv.px(hx + 7, hy + 9, mul(C(skin), 0.72), FLAT)


# ----------------------------------------------------------------- hair ----
HAIR = (222, 222, 222)
HAIR_STYLES = ["short", "spiky", "bob", "long", "ponytail", "buns", "curly"]
HAIR_COLORS = ["#3a2c2a", "#5a3a26", "#8a5a34", "#c88a4a", "#e8c878", "#e86a4a", "#9a3a3a",
               "#4a5a8a", "#4a8a7a", "#d8d8e0", "#c890c8", "#2a2a3a"]


def hair_cap(cv, hx, hy, back):
    cv.hline(hx + 2, hx + 9, hy - 1, HAIR)
    cv.hline(hx, hx + 11, hy, HAIR)
    for r in range(1, 4):
        cv.hline(hx - 1, hx + 12, hy + r, HAIR)
    if back:
        for r in range(4, 9):
            cv.hline(hx - 1, hx + 12, hy + r, HAIR)
        cv.hline(hx, hx + 11, hy + 9, HAIR)
        cv.hline(hx + 1, hx + 10, hy + 10, HAIR)
        for x in (hx + 2, hx + 5, hx + 8):
            cv.vline(x, hy + 4, hy + 8, HAIR, SHADE)
        cv.hline(hx + 3, hx + 8, hy, HAIR, SHINE)
        cv.px(hx + 1, hy + 1, HAIR, SHINE)
        return
    cv.rect(hx - 1, hy + 4, hx + 2, hy + 8, HAIR)
    cv.rect(hx - 1, hy + 9, hx + 1, hy + 9, HAIR)
    cv.hline(hx + 3, hx + 12, hy + 4, HAIR)
    cv.vline(hx + 1, hy + 5, hy + 8, HAIR, SHADE)
    cv.hline(hx + 3, hx + 6, hy, HAIR, SHINE)
    cv.px(hx + 2, hy + 1, HAIR, SHINE)


def draw_hair(front, backl, g, style):
    hx, hy = g.hx, g.hy
    b = g.p["back"]
    hair_cap(front, hx, hy, b)
    w = g.p["wave"]
    if not b:
        # bangs
        if style in ("short", "spiky", "curly", "ponytail"):
            for x in (hx + 4, hx + 7, hx + 10):
                front.px(x, hy + 5, HAIR)
            front.px(hx + 11, hy + 5, HAIR)
            front.px(hx + 12, hy + 5, HAIR, SHADE)
        else:
            front.hline(hx + 3, hx + 12, hy + 5, HAIR)
            front.px(hx + 6, hy + 5, None)
            front.px(hx + 12, hy + 6, HAIR, SHADE)
            front.px(hx + 12, hy + 7, HAIR, SHADE)
    if style == "spiky":
        for i, x in enumerate((hx + 1, hx + 4, hx + 7, hx + 10)):
            front.line(x, hy - 1, x - 2, hy - 3 - (i % 2), HAIR)
        if not b:
            front.px(hx + 13, hy + 2, HAIR, SHADE)
    elif style == "bob":
        if not b:
            front.rect(hx - 1, hy + 9, hx + 2, hy + 10, HAIR)
            front.rect(hx + 11, hy + 6, hx + 12, hy + 9, HAIR, SHADE)
        else:
            front.rect(hx - 1, hy + 10, hx + 12, hy + 11, HAIR)
    elif style == "long":
        if not b:
            for r in range(4, 15):
                taper = 1 if r > 12 else 0
                backl.hline(hx - 1 + taper, hx + 2, hy + r, HAIR, SHADE if r > 10 else AUTO)
            for r in range(6, 12):
                backl.hline(hx + 10, hx + 12 - (1 if r > 10 else 0), hy + r, HAIR, SHADE)
            front.rect(hx - 1, hy + 9, hx + 2, hy + 12, HAIR)
            front.px(hx - 1 + (1 if w else 0), hy + 13, HAIR)
            front.rect(hx + 11, hy + 6, hx + 12, hy + 10, HAIR, SHADE)
        else:
            for r in range(9, 16):
                inset = max(0, r - 12)
                front.hline(hx + inset, hx + 11 - inset, hy + r, HAIR)
            for x in (hx + 3, hx + 6, hx + 9):
                front.vline(x, hy + 9, hy + 13, HAIR, SHADE)
            front.px(hx + 5 + (1 if w else 0), hy + 16, HAIR, SHADE)
    elif style == "ponytail":
        tgt = front if b else backl
        ox = hx + 5 if b else hx - 2
        tgt.rect(ox, hy + 3, ox + 2, hy + 9, HAIR)
        tgt.rect(ox + (0 if w else 1), hy + 10, ox + (1 if w else 2), hy + 13, HAIR)
        (front if b else backl).rect(ox, hy + 3, ox + 2, hy + 3, "#d84a5a", FLAT)
        if not b:
            backl.rect(ox - 1, hy + 4, ox, hy + 6, HAIR, SHADE)
    elif style == "buns":
        front.ellipse(hx + 1.5, hy - 1, 2.2, 2, HAIR)
        front.ellipse(hx + 10, hy - 1.5, 2.2, 2, HAIR)
        front.px(hx + 1, hy - 2, HAIR, SHINE)
        front.px(hx + 9, hy - 2, HAIR, SHINE)
        if not b:
            front.rect(hx - 1, hy + 9, hx + 1, hy + 10, HAIR)
    elif style == "curly":
        for (dx, dy) in ((0, -1), (3, -2), (6, -2), (9, -1), (-1, 2), (12, 2), (-1, 6)):
            front.ellipse(hx + dx + 0.5, hy + dy + 0.5, 1.6, 1.6, HAIR)
        if not b:
            front.ellipse(hx + 0.5, hy + 9.5, 1.6, 1.6, HAIR)
        else:
            front.ellipse(hx + 12.5, hy + 6.5, 1.6, 1.6, HAIR)
            front.rect(hx - 1, hy + 10, hx + 12, hy + 11, HAIR)


# ----------------------------------------------------------------- hats ----

def draw_hat(cv, g, kind, H, T=GOLD, A="#d84a4a"):
    hx, hy = g.hx, g.hy
    b = g.p["back"]
    w = g.p["wave"]
    f = g.face

    def helmet_base(neck=False):
        cv.hline(hx + 3, hx + 8, hy - 1, H)
        cv.hline(hx + 1, hx + 10, hy, H)
        cv.rect(hx, hy + 1, hx + 11, hy + 3, H)
        cv.hline(hx - 1, hx + 12, hy + 4, T)
        cv.px(hx + 3, hy, H, SHINE)
        cv.px(hx + 2, hy + 1, H, SHINE)
        if b or neck:
            cv.rect(hx, hy + 5, hx + 11, hy + 7, H, SHADE if not b else AUTO)
        else:
            cv.rect(hx - 1, hy + 5, hx + 1, hy + 8, H)
            cv.vline(hx + 7, hy + 5, hy + 6, H)

    if kind == "helmet":
        helmet_base()
    elif kind == "plumed":
        helmet_base()
        cv.ellipse(hx + 4, hy - 2.5, 4, 1.6, A)
        cv.hline(hx + 1, hx + 6, hy - 3, A, LIGHT)
        cv.px(hx - 1 + (1 if w else 0), hy - 1, A, SHADE)
    elif kind == "great_helm":
        cv.hline(hx + 2, hx + 9, hy - 1, H)
        cv.rect(hx, hy, hx + 11, hy + 10, H)
        cv.rect(hx - 1, hy + 2, hx + 12, hy + 9, H)
        cv.hline(hx - 1, hx + 12, hy + 3, T)
        if not b:
            cv.hline(hx + 4, hx + 12, hy + 6, (30, 26, 40), FLAT)
            cv.vline(hx + 8, hy + 7, hy + 9, H, SHADE)
        cv.px(hx + 3, hy, H, SHINE)
        cv.ellipse(hx + 4, hy - 2, 3, 1.4, A)
    elif kind == "winged":
        helmet_base()
        for sx, d in ((hx - 1, -1), (hx + 12, 1)):
            cv.line(sx, hy + 2, sx + 2 * d, hy - 2, WHITE)
            cv.line(sx, hy + 3, sx + 3 * d, hy - 1, WHITE, SHADE)
    elif kind == "horned":
        helmet_base()
        horn = "#efe2c4"
        cv.line(hx - 1, hy + 2, hx - 3, hy - 2, horn)
        cv.px(hx - 2, hy - 3, horn, LIGHT)
        cv.line(hx + 12, hy + 2, hx + 14, hy - 2, horn)
        cv.px(hx + 13, hy - 3, horn, LIGHT)
    elif kind in ("tricorn", "captain"):
        cv.rect(hx + 1, hy - 2, hx + 10, hy + 1, H)
        cv.hline(hx + 2, hx + 9, hy - 3, H)
        cv.hline(hx - 2, hx + 13, hy + 2, H)
        cv.rect(hx - 2, hy, hx - 1, hy + 1, H)
        cv.rect(hx + 12, hy, hx + 13, hy + 1, H)
        cv.hline(hx - 2, hx + 13, hy + 2, T, LIGHT)
        cv.px(hx + 4, hy - 2, H, SHINE)
        if not b:
            cv.px(hx + 9, hy + 3, H, SHADE)
            cv.px(hx + 8, hy + 3, T)
        if kind == "captain":
            cv.line(hx + 1, hy - 1, hx - 3, hy - 5 - w, A)
            cv.line(hx + 2, hy - 1, hx - 2, hy - 5 - w, A, LIGHT)
            cv.rect(hx + 6, hy - 1, hx + 7, hy, T, LIGHT) if not b else None
    elif kind == "feather":
        cv.rect(hx + 2, hy - 3, hx + 9, hy + 1, H)
        cv.hline(hx + 2, hx + 9, hy + 1, T)
        cv.hline(hx - 2, hx + 13, hy + 2, H)
        if not b:
            cv.px(hx + 13, hy + 3, H, SHADE)
            cv.px(hx + 12, hy + 3, H, SHADE)
        cv.px(hx + 4, hy - 3, H, SHINE)
        cv.line(hx + 3, hy, hx - 2, hy - 5 - w, A, th=1)
        cv.line(hx + 4, hy, hx - 1, hy - 5 - w, A, LIGHT)
        cv.px(hx - 3, hy - 5 - w, A, SHADE)
    elif kind == "headband":
        cv.hline(hx - 1, hx + 12, hy + 3, H)
        if b:
            cv.vline(hx + 5, hy + 4, hy + 7 + w, H, SHADE)
            cv.vline(hx + 6, hy + 4, hy + 6, H)
        else:
            cv.line(hx - 1, hy + 3, hx - 4, hy + 5 + w, H, SHADE)
            cv.line(hx - 1, hy + 4, hx - 3, hy + 7, H)
            cv.px(hx + 8, hy + 3, T, LIGHT)
    elif kind == "bandana":
        cv.hline(hx + 2, hx + 9, hy - 2, H)
        cv.hline(hx, hx + 11, hy - 1, H)
        cv.rect(hx - 1, hy, hx + 12, hy + 3, H)
        for (dx, dy) in ((3, -1), (7, 0), (10, 2), (1, 2), (5, 2)):
            cv.px(hx + dx, hy + dy, T, FLAT)
        if b:
            cv.rect(hx + 4, hy + 4, hx + 7, hy + 5, H)
            cv.line(hx + 5, hy + 5, hx + 4, hy + 8, H, SHADE)
        else:
            cv.rect(hx - 3, hy + 2, hx - 1, hy + 4, H)
            cv.line(hx - 2, hy + 4, hx - 4, hy + 7 + w, H, SHADE)
    elif kind in ("chef", "chef_gold"):
        cv.rect(hx + 1, hy + 1, hx + 10, hy + 3, WHITE)
        cv.ellipse(hx + 5.5, hy - 3, 6, 3.6, WHITE)
        cv.ellipse(hx + 5.5, hy - 5.5, 4, 2.4, WHITE)
        cv.vline(hx + 3, hy - 4, hy, WHITE, SHADE)
        cv.vline(hx + 8, hy - 4, hy, WHITE, SHADE)
        if kind == "chef_gold":
            cv.hline(hx + 1, hx + 10, hy + 2, GOLD)
    elif kind == "cap":
        cv.hline(hx + 2, hx + 9, hy - 2, H)
        cv.rect(hx, hy - 1, hx + 11, hy + 2, H)
        cv.hline(hx - 1, hx + 12, hy + 3, H, SHADE)
        if not b:
            cv.hline(hx + 7, hx + 14, hy + 3, T)
            cv.px(hx + 7, hy + 1, A, LIGHT)
        else:
            cv.hline(hx - 3, hx + 3, hy + 3, T)
        cv.px(hx + 3, hy - 1, H, SHINE)
    elif kind in ("hood", "hood_white"):
        # Rounded cowl with a soft peak that falls back, an oval face opening
        # recessed by an inner shadow, and a mantle draped over the shoulders.
        rows = {-3: (3, 6), -2: (1, 9), -1: (0, 11), 0: (-1, 12)}
        for r in range(-3, 12):
            a0, a1 = rows.get(r, (-2, 13))
            cv.hline(hx + a0, hx + a1, hy + r, H)
        cv.line(hx + 3, hy - 3, hx, hy - 5, H)
        cv.px(hx - 1, hy - 5, H, SHADE)
        cv.hline(hx - 3, hx + 14, hy + 12, H, SHADE)
        cv.hline(hx - 2, hx + 13, hy + 13, H, DEEP)
        cv.px(hx - 3, hy + 12, H, DEEP)
        cv.px(hx + 14, hy + 12, H, DEEP)
        if b:
            cv.vline(hx + 5, hy - 1, hy + 11, H, SHADE)
            cv.vline(hx + 1, hy + 2, hy + 10, H, SHADE)
            cv.vline(hx + 10, hy + 2, hy + 10, H, SHADE)
            cv.hline(hx + 2, hx + 8, hy - 2, H, LIGHT)
        else:
            for r, (a0, a1) in {3: (5, 9), 4: (3, 11), 5: (3, 11), 6: (3, 11), 7: (3, 11), 8: (3, 11), 9: (3, 11), 10: (4, 10)}.items():
                cv.hline(hx + a0, hx + a1, hy + r, None)
            # inner shadow over the forehead and the far cheek
            cv.hline(hx + 4, hx + 10, hy + 4, H, DEEP)
            cv.px(hx + 3, hy + 5, H, DEEP)
            cv.vline(hx + 3, hy + 6, hy + 8, H, SHADE)
            # rim light around the opening and folds down the side
            cv.hline(hx + 5, hx + 9, hy + 2, H, LIGHT)
            cv.px(hx + 4, hy + 3, H, LIGHT)
            cv.px(hx + 10, hy + 3, H, LIGHT)
            cv.vline(hx + 0, hy + 3, hy + 10, H, SHADE)
            cv.vline(hx + 12, hy + 4, hy + 11, H, SHADE)
            cv.vline(hx + 13, hy + 5, hy + 11, H, DEEP)
        cv.px(hx + 2, hy - 2, H, LIGHT)
        cv.px(hx + 1, hy - 1, H, LIGHT)
    elif kind in ("witch", "wizard"):
        tall = 10 if kind == "wizard" else 8
        cv.hline(hx - 3, hx + 14, hy + 2, H)
        cv.hline(hx - 1, hx + 12, hy + 3, H, SHADE)
        for i in range(tall):
            y = hy + 1 - i
            half = max(0, 5 - (i * 5) // tall)
            cx = hx + 5 - (i * 3) // tall
            cv.hline(cx - half, cx + half, y, H)
        cv.line(hx + 2, hy + 1 - tall, hx - 1, hy + 2 - tall + (1 if w else 0), H)
        cv.hline(hx + 1, hx + 10, hy + 1, T)
        if kind == "wizard":
            cv.px(hx + 6, hy - 3, A, SHINE)
            cv.px(hx + 4, hy - 6, A, SHINE)
    elif kind == "nurse":
        cv.hline(hx + 3, hx + 10, hy - 1, WHITE)
        cv.rect(hx + 2, hy, hx + 10, hy + 1, WHITE)
        if not b:
            cv.px(hx + 7, hy - 1, A, FLAT)
            cv.hline(hx + 6, hx + 8, hy, A, FLAT)
            cv.px(hx + 7, hy + 1, A, FLAT)
    elif kind == "surgical":
        cv.hline(hx + 2, hx + 9, hy - 1, H)
        cv.rect(hx, hy, hx + 11, hy + 3, H)
        cv.hline(hx, hx + 11, hy + 3, H, SHADE)
    elif kind == "goggles":
        cv.hline(hx - 1, hx + 12, hy + 3, LEATHER_D)
        if not b:
            for gx in (hx + 4, hx + 8):
                cv.rect(gx, hy + 2, gx + 2, hy + 4, T)
                cv.px(gx + 1, hy + 3, "#9ad8f0", SHINE)
        else:
            cv.rect(hx + 5, hy + 2, hx + 6, hy + 4, LEATHER)
    elif kind == "goggle_cap":
        draw_hat(cv, g, "cap", H, T, A)
        draw_hat(cv, g, "goggles", H, T, A)
    elif kind == "beast":
        cv.hline(hx + 2, hx + 9, hy - 1, H)
        cv.rect(hx, hy, hx + 11, hy + 3, H)
        cv.hline(hx - 1, hx + 12, hy + 3, T)
        for ex in (hx + 1, hx + 8):
            cv.poly([(ex, hy), (ex + 3, hy), (ex + 1, hy - 4)], H)
            if not b:
                cv.px(ex + 1, hy - 1, "#f0a0a8", FLAT)
    elif kind == "bicorne":
        cv.poly([(hx - 3, hy + 3), (hx + 14, hy + 3), (hx + 11, hy - 1), (hx + 5.5, hy - 4), (hx, hy - 1)], H)
        cv.hline(hx - 2, hx + 13, hy + 2, T, LIGHT)
        if not b:
            cv.rect(hx + 7, hy - 1, hx + 8, hy, A, LIGHT)
    elif kind == "souwester":
        cv.hline(hx + 2, hx + 9, hy - 2, H)
        cv.rect(hx + 1, hy - 1, hx + 10, hy + 2, H)
        cv.hline(hx - 2, hx + 13, hy + 3, H, SHADE)
        if b:
            cv.rect(hx - 1, hy + 4, hx + 12, hy + 5, H)
        else:
            cv.rect(hx - 2, hy + 4, hx + 1, hy + 6, H)
        cv.px(hx + 3, hy - 1, H, SHINE)
    elif kind == "turban":
        cv.ellipse(hx + 5.5, hy + 0.5, 6.5, 3.6, H)
        for i in range(-1, 4):
            cv.line(hx + 1 + i * 3, hy + 3, hx + 3 + i * 3, hy - 2, H, SHADE)
        if not b:
            cv.rect(hx + 8, hy + 1, hx + 9, hy + 2, A, SHINE)
    elif kind in ("circlet", "flowers"):
        cv.hline(hx, hx + 11, hy + 3, T)
        if not b:
            cv.px(hx + 8, hy + 3, A, SHINE)
        if kind == "flowers":
            for (dx, col) in ((1, "#f07aa0"), (5, "#f8f0a0"), (9, "#f07aa0"), (11, "#9ad87a")):
                cv.px(hx + dx, hy + 2, col, LIGHT)
                cv.px(hx + dx + 1, hy + 3, col, FLAT)
    elif kind == "explorer":
        cv.rect(hx + 2, hy - 2, hx + 9, hy + 1, H)
        cv.hline(hx + 2, hx + 9, hy + 1, T)
        cv.hline(hx - 3, hx + 14, hy + 2, H)
        cv.hline(hx - 2, hx + 13, hy + 3, H, SHADE)
    elif kind == "tophat":
        cv.rect(hx + 3, hy - 5, hx + 9, hy + 1, H)
        cv.hline(hx + 3, hx + 9, hy, T)
        cv.hline(hx + 1, hx + 11, hy + 2, H)
        cv.px(hx + 4, hy - 4, H, SHINE)
    elif kind == "crown":
        cv.rect(hx + 2, hy - 1, hx + 9, hy + 1, T)
        for dx in (2, 5, 9):
            cv.px(hx + dx, hy - 2, T, LIGHT)
        cv.px(hx + 5, hy - 3, T, SHINE)
        if not b:
            cv.px(hx + 6, hy, A, SHINE)
    elif kind == "mushroom":
        cv.ellipse(hx + 5.5, hy - 0.5, 8, 4, H)
        cv.hline(hx - 1, hx + 12, hy + 3, "#efe2c4")
        for (dx, dy) in ((1, -2), (6, -3), (9, 0), (3, 1)):
            cv.rect(hx + dx, hy + dy, hx + dx + 1, hy + dy, WHITE, FLAT)
    elif kind == "mitre":
        cv.poly([(hx + 1, hy + 3), (hx + 11, hy + 3), (hx + 10, hy - 4), (hx + 6, hy - 8), (hx + 2, hy - 4)], H)
        cv.vline(hx + 6, hy - 6, hy + 2, T, LIGHT)
        cv.hline(hx + 1, hx + 11, hy + 2, T)
    elif kind == "fur":
        cv.hline(hx + 2, hx + 9, hy - 2, H)
        cv.rect(hx, hy - 1, hx + 11, hy + 3, H)
        cv.hline(hx - 1, hx + 12, hy + 3, T)
        for dx in range(0, 12, 3):
            cv.px(hx + dx, hy - 1, H, LIGHT)
        tail = hx - 2 if not b else hx + 5
        cv.rect(tail, hy + 2, tail + 1, hy + 8, T)
        cv.px(tail, hy + 8, (60, 40, 30), FLAT)
    elif kind == "beret":
        cv.ellipse(hx + 4.5, hy, 6.5, 2.4, H)
        cv.px(hx + 4, hy - 3, H)
        cv.hline(hx, hx + 11, hy + 2, H, SHADE)
    elif kind == "none":
        pass
    else:
        raise ValueError(kind)


# -------------------------------------------------------------- weapons ----
ANG = {
    "short": dict(rest=-62, walk=-55, work0=-120, work1=30, wind=-140, strike=-10, follow=55, hit=-165, cheer=-92),
    "long": dict(rest=-96, walk=-96, work0=-70, work1=-30, wind=-170, strike=-4, follow=12, hit=-125, cheer=-96),
    "gun": dict(rest=72, walk=64, work0=-40, work1=20, wind=-45, strike=-2, follow=-22, hit=130, cheer=-90),
    "hold": dict(rest=90, walk=90, work0=-30, work1=40, wind=-90, strike=0, follow=30, hit=150, cheer=-90),
}


def _grip(g):
    hx, hy = g.hand_near
    return hx + 0.5, hy + 0.5


def draw_weapon(cv, g, kind, accent="#5ad8e8"):
    p = g.p
    act = p["act"]
    w = p["wave"]
    if act == "down":
        y = 29
        x = g.tx + 9
        if kind in ("blade", "cutlass", "shield"):
            cv.hline(x - 1, x + 6, y, STEEL)
            cv.vline(x, y - 1, y, GOLD)
        elif kind in ("spear", "trident", "staff", "banner"):
            cv.hline(x - 6, x + 6, y, WOOD)
            cv.px(x + 7, y, STEEL if kind != "staff" else accent, LIGHT)
        elif kind in ("gun", "musket"):
            cv.hline(x, x + (8 if kind == "musket" else 5), y, (70, 66, 80))
            cv.rect(x - 1, y - 1, x, y, WOOD)
        elif kind == "shield":
            pass
        else:
            cv.rect(x, y - 1, x + 2, y, LEATHER)
        if kind == "shield":
            cv.ellipse(g.tx - 1, 27, 3, 2, accent)
        return
    gx, gy = _grip(g)

    def fam_angle(fam):
        return ANG[fam].get(act, ANG[fam]["rest"])

    if kind in ("blade", "short_sword", "cutlass", "shield", "claws", "wand", "ladle", "tool"):
        a = fam_angle("short")
    elif kind in ("spear", "trident", "staff", "banner"):
        a = fam_angle("long")
    elif kind in ("gun", "musket"):
        a = fam_angle("gun")
    else:
        a = fam_angle("hold")
    if p["back"]:
        a = {"rest": -100, "walk": -100}.get(act, a)

    if kind == "shield":
        fx, fy = g.hand_far
        if act in ("strike", "follow"):
            fx, fy = g.hand_near[0] + 1, g.hand_near[1] - 1
        sx = fx - (2 if not p["back"] else 0)
        if p["back"]:
            sx, fy = g.tx + 3, g.ty + 3
        cv.ellipse(sx + 0.5, fy + 0.5, 3.2, 4.2, STEEL_D)
        cv.ellipse(sx + 0.5, fy + 0.5, 2.3, 3.2, accent)
        if not p["back"]:
            cv.vline(sx + 0, fy - 2, fy + 3, GOLD, LIGHT)
            cv.px(sx, fy, GOLD, SHINE)
        if act not in ("strike", "follow"):
            draw_weapon(cv, g, "short_sword")
        return
    if kind in ("blade", "short_sword", "cutlass"):
        length = 6 if kind == "short_sword" else 9
        cv.ray(gx, gy, a + 180, 2, LEATHER_D)
        ang = math_rad(a + 90)
        cx, cy = gx + ang[0] * 0, gy
        p1 = (gx + ang[0] * 1.5, gy + ang[1] * 1.5)
        p2 = (gx - ang[0] * 1.5, gy - ang[1] * 1.5)
        cv.line(p1[0], p1[1], p2[0], p2[1], GOLD, LIGHT)
        if kind == "cutlass":
            mid = cv.ray(gx, gy, a, 6, STEEL, LIGHT, start=1)
            cv.ray(mid[0], mid[1], a + 22, 3, STEEL, LIGHT)
        else:
            cv.ray(gx, gy, a, length, STEEL, LIGHT, start=1)
        return
    if kind == "claws":
        for d in (-1, 0, 1):
            cv.ray(gx + d, gy, a + 15, 4, STEEL, LIGHT, start=1)
        return
    if kind == "spear" or kind == "trident":
        cv.ray(gx, gy, a + 180, 6, WOOD)
        tip = cv.ray(gx, gy, a, 11, WOOD)
        if kind == "spear":
            cv.ray(tip[0], tip[1], a, 3, STEEL, LIGHT)
            n = math_rad(a + 90)
            cv.px(tip[0] + n[0], tip[1] + n[1], STEEL, SHADE)
        else:
            n = math_rad(a + 90)
            for k in (-2, 0, 2):
                cv.ray(tip[0] + n[0] * k, tip[1] + n[1] * k, a, 3, STEEL, LIGHT)
            cv.line(tip[0] - n[0] * 2, tip[1] - n[1] * 2, tip[0] + n[0] * 2, tip[1] + n[1] * 2, STEEL)
        return
    if kind == "staff":
        cv.ray(gx, gy, a + 180, 6, WOOD)
        tip = cv.ray(gx, gy, a, 9, WOOD)
        tx, ty = tip
        cv.ellipse(tx + 0.5, ty - 0.5, 1.8, 1.8, accent)
        cv.px(tx, ty - 1, accent, SHINE)
        cv.px(tx + 1, ty + 1, GOLD, FLAT)
        return
    if kind == "wand":
        tip = cv.ray(gx, gy, a, 5, "#5a3a5a")
        cv.px(tip[0], tip[1], accent, SHINE)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.px(tip[0] + d[0], tip[1] + d[1], accent, LIGHT)
        return
    if kind == "banner":
        cv.ray(gx, gy, a + 180, 7, WOOD)
        tip = cv.ray(gx, gy, a, 12, WOOD)
        cv.px(tip[0], tip[1] - 1, GOLD, SHINE)
        tx, ty = int(round(tip[0])), int(round(tip[1]))
        d = -1 if p["back"] else 1
        for i in range(6):
            sag = 1 if (i + w) % 3 == 0 else 0
            cv.vline(tx + d * (i + 1), ty + 1 + sag, ty + 5 + sag, accent, SHADE if i > 3 else AUTO)
        cv.px(tx + d * 3, ty + 3, GOLD, LIGHT)
        return
    if kind in ("gun", "musket"):
        L = 10 if kind == "musket" else 5
        cv.ray(gx, gy, a, L, (70, 66, 82), th=1, start=0)
        n = math_rad(a + 90)
        cv.line(gx, gy, gx - math_rad(a)[0] * 3 + n[0] * 2, gy - math_rad(a)[1] * 3 + n[1] * 2, WOOD, th=1)
        cv.px(gx, gy, GOLD, LIGHT)
        if kind == "musket":
            cv.ray(gx, gy, a + 180, 4, WOOD)
        return
    if kind == "ladle":
        tip = cv.ray(gx, gy, a, 6, STEEL)
        cv.ellipse(tip[0] + 0.5, tip[1] + 0.5, 1.6, 1.3, STEEL)
        cv.px(tip[0], tip[1], STEEL, SHINE)
        return
    if kind == "tool":
        tip = cv.ray(gx, gy, a, 5, WOOD)
        n = math_rad(a + 90)
        cv.line(tip[0] - n[0] * 2, tip[1] - n[1] * 2, tip[0] + n[0] * 2, tip[1] + n[1] * 2, STEEL_D, th=2)
        cv.px(tip[0] - n[0] * 2, tip[1] - n[1] * 2, STEEL, LIGHT)
        return
    if kind == "fist":
        hx, hy = g.hand_near
        cv.rect(hx - 1, hy, hx + 2, hy + 1, STEEL_D)
        cv.hline(hx - 1, hx + 2, hy, STEEL, LIGHT)
        if not p["back"] and act in ("strike", "cheer"):
            fx, fy = g.hand_far
            cv.rect(fx - 1, fy, fx + 2, fy + 1, STEEL_D)
        return
    if kind == "kit":
        hx, hy = g.hand_near
        if act in ("strike", "follow", "cheer"):
            cv.rect(hx + 1, hy - 3, hx + 2, hy, "#bfe8f0")
            cv.px(hx + 1, hy - 3, "#e86a7a", SHINE)
            cv.px(hx + 2, hy - 2, (255, 255, 255), SHINE)
        else:
            cv.rect(hx - 1, hy + 2, hx + 3, hy + 5, WHITE)
            cv.hline(hx - 1, hx + 3, hy + 2, "#c8b89a", SHADE)
            cv.hline(hx, hx + 2, hy + 4, "#d8404a", FLAT)
            cv.vline(hx + 1, hy + 3, hy + 5, "#d8404a", FLAT)
        return
    if kind == "whip":
        hx, hy = g.hand_near
        cv.ray(gx, gy, a if act != "rest" else -60, 3, LEATHER_D)
        if act in ("strike", "follow"):
            for i in range(12):
                y = gy + (1 if (i // 2 + w) % 2 else 0) + (i // 6 if act == "follow" else 0)
                cv.px(gx + 2 + i, y, LEATHER)
        elif act in ("wind", "cheer"):
            cv.line(gx, gy, gx - 4, gy - 6, LEATHER)
            cv.line(gx - 4, gy - 6, gx - 1, gy - 9, LEATHER)
        else:
            cv.ellipse(hx + 1, hy + 4, 2.2, 1.8, LEATHER)
            cv.ellipse(hx + 1, hy + 4, 1, 0.6, None)
        return
    if kind == "bow":
        hx, hy = g.hand_near
        if act in ("strike", "follow", "wind"):
            bx = hx + 2
            for dy in range(-5, 6):
                cv.px(bx + (1 if abs(dy) < 3 else 0) - (1 if abs(dy) > 4 else 0), hy + dy, WOOD)
            draw = 3 if act == "wind" else 1
            cv.line(bx - draw, hy, bx - 1, hy - 5, (230, 230, 220))
            cv.line(bx - draw, hy, bx - 1, hy + 5, (230, 230, 220))
            if act != "follow":
                cv.hline(bx - draw - 2, bx + 4, hy, "#c8a878")
                cv.px(bx + 4, hy, STEEL, LIGHT)
        else:
            for dy in range(-5, 6):
                cv.px(hx + 2 + (1 if abs(dy) < 3 else 0) - (1 if abs(dy) > 4 else 0), hy + dy, WOOD)
            cv.vline(hx + 1, hy - 5, hy + 5, (230, 230, 220))
        return
    if kind == "book":
        hx, hy = g.hand_near
        cv.rect(hx - 1, hy - 2, hx + 3, hy + 1, accent)
        cv.hline(hx - 1, hx + 3, hy - 2, WHITE, LIGHT)
        cv.vline(hx + 1, hy - 2, hy + 1, GOLD, FLAT)
        if act in ("strike", "cheer"):
            cv.px(hx + 4, hy - 4, accent, SHINE)
            cv.px(hx + 6, hy - 3, accent, SHINE)
        return
    if kind == "lantern":
        hx, hy = g.hand_near
        if act in ("strike", "cheer", "wind", "work0"):
            hy -= 2
        cv.vline(hx + 1, hy + 1, hy + 2, STEEL_D)
        cv.rect(hx, hy + 3, hx + 2, hy + 6, GOLD)
        cv.rect(hx + 1, hy + 4, hx + 1, hy + 5, "#fff2a0", SHINE)
        return
    if kind == "none":
        return
    raise ValueError(kind)


def math_rad(deg):
    import math
    r = math.radians(deg)
    return (math.cos(r), math.sin(r))


# ----------------------------------------------------------- specs ----
# Outfit spec: shape, C main, D secondary, A accent, P pants, B boots, G gloves, M metal.

CLASS_LOOKS = {
    "guard": dict(o=dict(shape="armor", C="#3b5b9a", M="#b6c0ce", A=GOLD, P="#4a4e68", B="#5a3a2a", G="#8a94a6"),
                  hat=("helmet", "#b6c0ce", "#8a94a6"), w="shield", acc="#3b5b9a"),
    "duelist": dict(o=dict(shape="coat", C="#a63a4a", D="#f0e2c0", P="#3a3550", B="#3a2a2a", G=WHITE, extra=("belt",)),
                    hat=("feather", "#7a2a3a", GOLD, WHITE), w="blade"),
    "spearfighter": dict(o=dict(shape="tunic", C="#3f9a8a", D="#f0e2c0", A="#e8a040", P="#8a6a4a", B="#5a4030",
                                extra=("sash",)), hat=("headband", "#d94a4a", GOLD), w="spear"),
    "gunner": dict(o=dict(shape="coat", C="#34507a", D="#e0b050", P="#d9cfb0", B="#2e2a34", G=LEATHER,
                          extra=("belt", "hem")), hat=("tricorn", "#3a3040", GOLD), w="gun"),
    "brawler": dict(o=dict(shape="vest", C="#b0503a", D="#efe4cc", S="#e8d8b8", G="#e8d8b8", P="#4a5a7a",
                           B="#4a3424"), hat=("bandana", "#d0403a", WHITE), w="fist"),
    "medic": dict(o=dict(shape="labcoat", C="#f2f0ea", D="#c8d8e8", A="#d8404a", P="#6a7a9a", B="#6a4a3a", G=WHITE,
                         extra=("cross",)), hat=("nurse", WHITE, WHITE, "#d8404a"), w="kit"),
    "cook": dict(o=dict(shape="apron", C="#8ab4d8", W=WHITE, A="#d84a4a", P="#5a5a6a", B="#5a3a2a", G=WHITE,
                        extra=("scarf",)), hat=("chef", WHITE), w="ladle"),
    "navigator": dict(o=dict(shape="jacket", C="#3f7a5a", D="#f0e2c0", A="#e8c050", P="#c8b890", B="#6a4a30",
                             extra=("scarf",)), hat=("cap", "#2f5a44", GOLD, GOLD), w="gun"),
    "tinkerer": dict(o=dict(shape="overall", C="#c8903a", D="#8a9aaa", P="#c8903a", B="#4a3a30", M=STEEL,
                            extra=("tools",)), hat=("goggles", LEATHER, GOLD), w="tool"),
    "beastkeeper": dict(o=dict(shape="vest", C="#6a8a3a", D="#e8dcc0", P="#7a5a3a", B="#5a3a2a", extra=("fur",)),
                        hat=("beast", "#b08a5a", "#8a6a44"), w="whip"),
    "mystic": dict(o=dict(shape="robe", C="#6a4aa8", D=GOLD, A="#58c8d8", P="#3a2a4a", B="#3a2a4a", G="#6a4aa8"),
                   hat=("hood", "#5a3a98"), w="staff", acc="#7af0f0", hair=False),
    "quartermaster": dict(o=dict(shape="coat", C="#8a5a3a", D="#f0e2c0", P="#3a3a4a", B="#2e2a34",
                                 extra=("bandolier", "belt")), hat=("bicorne", "#2e2a34", GOLD, "#d84a4a"), w="banner",
                          acc="#d84a4a"),
    # branches
    "guardian": dict(o=dict(shape="armor", C="#eceaf2", M="#d4dae4", A=GOLD, P="#4a5a8a", B="#5a3a2a", G="#d4dae4",
                            extra=("cape",), K="#3b5b9a"), hat=("plumed", "#d4dae4", GOLD, "#d84a4a"), w="shield",
                     acc="#eceaf2"),
    "bulwark": dict(o=dict(shape="armor", C="#8a3a3a", M="#7a8496", A=GOLD, P="#3a3a4a", B="#3a2a2a", G="#7a8496"),
                    hat=("great_helm", "#7a8496", "#5a6476", "#d84a4a"), w="shield", acc="#8a3a3a", hair=False),
    "blade_dancer": dict(o=dict(shape="coat", C="#2fa0a0", D="#f6f0dc", A="#f07aa0", P="#2e3a4a", B="#2e2a34",
                                G=WHITE, extra=("sash",)), hat=("feather", "#1f7070", GOLD, "#f07aa0"), w="blade"),
    "challenger": dict(o=dict(shape="coat", C="#c83a3a", D=GOLD, P="#2e2a34", B="#2e2a34", G=WHITE,
                              extra=("belt", "hem", "cape"), K="#5a2030"), hat=("feather", "#2e2a34", GOLD, "#d84a4a"),
                       w="blade"),
    "harpooner": dict(o=dict(shape="tunic", C="#2f4f7a", D="#f0e2c0", A="#e8c050", P="#6a5a4a", B="#3a3040",
                             extra=("bandolier",)), hat=("souwester", "#f0c040"), w="spear"),
    "dragoon": dict(o=dict(shape="armor", C="#3a7ab0", M="#a8c8e0", A=GOLD, P="#3a4a6a", B="#3a2a2a", G="#a8c8e0",
                           extra=("cape",), K="#2a4a7a"), hat=("winged", "#a8c8e0", GOLD), w="spear"),
    "sharpshooter": dict(o=dict(shape="coat", C="#3a6a4a", D="#d8c890", P="#d9cfb0", B="#2e2a34",
                                extra=("belt", "hem")), hat=("captain", "#2e3a2e", GOLD, "#f0e8d0"), w="gun"),
    "skirmisher": dict(o=dict(shape="jacket", C="#8a5a3a", D="#e8dcc0", A="#d84a4a", P="#4a4a5a", B="#3a2a2a",
                              extra=("bandolier",)), hat=("bandana", "#3a6a9a", WHITE), w="gun"),
    "breaker": dict(o=dict(shape="vest", C="#e07a2a", D="#3a3a4a", S="#e8d8b8", G="#e8d8b8", P="#3a3a4a",
                           B="#3a2a2a"), hat=("headband", "#2e2a34", GOLD), w="fist"),
    "grappler": dict(o=dict(shape="vest", C="#3a5ab0", D="#f0e8d8", S="#e8d8b8", G="#e8d8b8", P="#2e3a6a",
                            B="#e8d8b8", extra=("belt",)), hat=("headband", "#3a5ab0", GOLD), w="fist"),
    "surgeon": dict(o=dict(shape="labcoat", C="#7ac0a0", D="#e8f4ee", A="#f2f0ea", P="#4a6a6a", B="#3a3a4a",
                           G=WHITE), hat=("surgical", "#5aa888"), w="kit"),
    "lifekeeper": dict(o=dict(shape="robe", C="#f4efe2", D=GOLD, A="#7ad0a0", P="#c8b890", B="#8a6a4a", G=WHITE),
                       hat=("circlet", GOLD, GOLD, "#7ad0a0"), w="staff", acc="#a8f0b8"),
    "provisioner": dict(o=dict(shape="apron", C="#a87a4a", W="#efe0c0", A="#e8c050", P="#5a4a3a", B="#4a3424",
                               extra=("pack",), K="#8a5a3a"), hat=("bandana", "#e8c050", "#d84a4a"), w="ladle"),
    "feastmaster": dict(o=dict(shape="apron", C="#c83a3a", W=WHITE, A=GOLD, P="#2e2a34", B="#2e2a34", G=WHITE,
                               extra=("scarf",)), hat=("chef_gold", WHITE), w="ladle"),
    "pathfinder": dict(o=dict(shape="jacket", C="#7a5a3a", D="#e8dcc0", A="#3f7a5a", P="#6a6a4a", B="#4a3424",
                              extra=("cape", "pouch"), K="#3f6a4a"), hat=("explorer", "#a88a5a", "#5a3a26"), w="blade"),
    "tide_reader": dict(o=dict(shape="robe", C="#2f7aa8", D="#e8f0f0", A="#5ad8c8", P="#2a3a5a", B="#2a3a5a",
                               G="#2f7aa8"), hat=("turban", "#e8f0f0", GOLD, "#5ad8e8"), w="staff", acc="#a8f0ff"),
    "engineer": dict(o=dict(shape="overall", C="#3a6ab0", D="#d8d0c0", P="#3a6ab0", B="#3a3040", M=STEEL,
                            extra=("tools",)), hat=("goggle_cap", "#e8a040", GOLD, GOLD), w="tool"),
    "trapper": dict(o=dict(shape="jacket", C="#5a6a3a", D="#c8a878", A="#8a5a3a", P="#4a3a2a", B="#3a2a20",
                           extra=("pouch", "fur")), hat=("fur", "#8a6a4a", "#c8a070"), w="whip"),
    "beastwarden": dict(o=dict(shape="armor", C="#6a8a3a", M="#8a6a4a", A=GOLD, P="#4a3a2a", B="#3a2a20",
                               G=LEATHER, extra=("cape", "fur"), K="#6a5040"), hat=("horned", "#8a6a4a", GOLD),
                        w="spear"),
    "wildspeaker": dict(o=dict(shape="robe", C="#4a8a4a", D="#c8e070", A="#f07aa0", P="#3a4a2a", B="#4a3424",
                               G="#4a8a4a"), hat=("flowers", "#4a8a4a", "#5a8a3a"), w="whip"),
    "stormcaller": dict(o=dict(shape="robe", C="#2e3a6a", D="#f0d050", A="#9ad8f0", P="#2a2a3a", B="#2a2a3a",
                               G="#2e3a6a"), hat=("wizard", "#2e3a6a", "#f0d050", "#f0e070"), w="staff", acc="#f0e070"),
    "hexbreaker": dict(o=dict(shape="robe", C="#ece6f4", D="#8a5ac8", A="#8a5ac8", P="#4a3a6a", B="#4a3a6a",
                              G="#ece6f4"), hat=("hood_white", "#ece6f4"), w="staff", acc="#c8a0ff", hair=False),
    "purser": dict(o=dict(shape="coat", C="#3a6a5a", D="#f0e2c0", P="#3a3a4a", B="#2e2a34", G=WHITE,
                          extra=("belt", "emblem")), hat=("tophat", "#2e2a34", "#3a6a5a"), w="blade"),
    "standard_bearer": dict(o=dict(shape="armor", C="#b83a3a", M="#d8b860", A="#f0e8d0", P="#3a3a4a", B="#3a2a2a",
                                   G=LEATHER, extra=("cape",), K="#8a2a2a"), hat=("bicorne", "#b83a3a", GOLD, WHITE),
                            w="banner", acc="#d84a4a"),
}


def _npc(shape, C, D, A, P, B, hat, hc, w, acc=None, skin=None, hair=None, hcol=None, G=LEATHER, extra=(), **kw):
    o = dict(shape=shape, C=C, D=D, A=A, P=P, B=B, G=G, extra=extra)
    o.update(kw)
    return dict(o=o, hat=(hat,) + tuple(hc), w=w, acc=acc, skin=skin, hair=hair, hcol=hcol)


NPC_LOOKS = {
    # dawnwater
    "gull_raider": _npc("vest", "#e8e4dc", "#3a8fd0", GOLD, "#3a4a6a", "#3a2a2a", "bandana", ("#3a8fd0", WHITE), "cutlass",
                        hair="spiky", hcol="#5a3a26"),
    "spray_gunner": _npc("jacket", "#2a6fae", "#e9d58f", GOLD, "#d9cfb0", "#3a2a2a", "cap", ("#1f4f7e", GOLD), "gun",
                         hair="short", hcol="#3a2c2a"),
    "brine_witch": _npc("robe", "#2a8a8a", "#e9d58f", "#79c46a", "#2a3a3a", "#2a3a3a", "witch", ("#1f5a6a", "#79c46a"),
                        "staff", acc="#7af0d0", hair="long", hcol="#d8d8e0", G="#2a8a8a"),
    "kelp_tender": _npc("robe", "#4a9a5a", "#e9d58f", "#79c46a", "#2a4a2a", "#3a2a20", "hood", ("#3a7a4a",), "kit",
                        hair=None, G="#4a9a5a"),
    # emberreach
    "ash_slinger": _npc("tunic", "#4a3a36", "#e0703a", "#ffb347", "#3a2e2a", "#2a2020", "headband", ("#e0703a", GOLD),
                        "gun", hair="short", hcol="#2a2a3a"),
    "flame_seer": _npc("robe", "#c8502a", "#ffb347", "#ffd060", "#3a2a2a", "#3a2a2a", "hood", ("#a8401f",), "staff",
                       acc="#ffb030", hair=None, G="#c8502a"),
    "ember_monk": _npc("robe", "#e0703a", "#ffd060", "#7a3626", "#4a2a2a", "#3a2a20", "none", (), "fist",
                       hair="short", hcol="#2a2a3a", S="#d8a074", G="#d8a074"),
    # verdant maw
    "thorn_archer": _npc("tunic", "#3f7a3a", "#c6e86b", "#8a5a3a", "#4a3a2a", "#3a2a20", "hood", ("#2f6a2f",), "bow",
                         hair=None),
    "spore_shaman": _npc("robe", "#6a5a3a", "#c6e86b", "#d84a4a", "#3a3020", "#3a3020", "mushroom", ("#d84a4a",),
                         "staff", acc="#c6e86b", hair="curly", hcol="#4a8a7a", G="#6a5a3a"),
    "bloom_nurse": _npc("apron", "#f0a0b8", WHITE, "#79c46a", "#5a4a5a", "#5a3a3a", "flowers", ("#4a8a4a", GOLD), "kit",
                        hair="bob", hcol="#e86a4a", W="#fff4f0"),
    # glass current
    "shard_fencer": _npc("coat", "#9fd3e6", WHITE, "#2c7f9c", "#2c4f6c", "#2a3a4a", "feather", ("#2c7f9c", WHITE, "#e7f7ff"),
                         "blade", hair="short", hcol="#d8d8e0", G=WHITE, extra=("belt",)),
    "prism_sniper": _npc("jacket", "#e7f7ff", "#4fb3c8", "#2c7f9c", "#4a6a8a", "#2a3a4a", "cap", ("#4fb3c8", WHITE),
                         "musket", hair="ponytail", hcol="#4a5a8a"),
    "mirror_mage": _npc("robe", "#cfe6ef", "#2c7f9c", "#4fb3c8", "#4a6a8a", "#4a6a8a", "wizard", ("#9fd3e6", WHITE, WHITE),
                        "wand", acc="#e7f7ff", hair="long", hcol="#9ad8f0", G="#cfe6ef"),
    "lens_cleric": _npc("robe", "#f4f4f8", "#4fb3c8", "#9fd3e6", "#8a9aaa", "#5a6a7a", "circlet", (GOLD, GOLD, "#4fb3c8"),
                        "book", acc="#4fb3c8", hair="bob", hcol="#e8c878", G="#f4f4f8"),
    # crown shoals
    "cutpurse": _npc("jacket", "#4a3a6a", "#e8dcc0", "#d9b44a", "#2e2a3a", "#2e2a34", "bandana", ("#2e2a3a", "#d9b44a"),
                     "claws", hair="short", hcol="#3a2c2a"),
    "crown_enforcer": _npc("armor", "#3f6fb8", "#ffd76a", GOLD, "#2b4f8c", "#3a2a2a", "plumed", ("#e0c060", GOLD, "#3f6fb8"),
                           "shield", acc="#3f6fb8", M="#e0c060", G="#e0c060"),
    "musket_noble": _npc("coat", "#2b4f8c", "#ffd76a", GOLD, WHITE, "#2e2a34", "tricorn", ("#2e2a34", GOLD), "musket",
                         hair="curly", hcol="#e8c878", G=WHITE, extra=("belt", "hem")),
    "court_hexer": _npc("robe", "#5a3a8a", "#ffd76a", "#d9b44a", "#2e2a3a", "#2e2a3a", "tophat", ("#2e2a3a", "#ffd76a"),
                        "book", acc="#8a5ac8", hair="long", hcol="#2a2a3a", G="#5a3a8a"),
    "gilded_medic": _npc("labcoat", "#f6f0dc", "#ffd76a", "#d9b44a", "#5a5a6a", "#5a3a2a", "nurse", (WHITE, WHITE, GOLD),
                         "kit", hair="buns", hcol="#c88a4a", G=WHITE, extra=("cross",)),
    # stormbelt
    "squall_runner": _npc("jacket", "#7c8796", "#ffe066", "#4a5f7a", "#2f3e55", "#2a2a3a", "bandana", ("#2f3e55", "#ffe066"),
                          "blade", hair="spiky", hcol="#d8d8e0"),
    "gale_harpooner": _npc("tunic", "#4a5f7a", "#e8e0d0", "#ffe066", "#2f3e55", "#2a2a3a", "souwester", ("#ffe066",),
                           "trident", hair="short", hcol="#5a3a26", extra=("bandolier",)),
    "storm_witch": _npc("robe", "#2f3e55", "#ffe066", "#8fa6bf", "#2a2a3a", "#2a2a3a", "witch", ("#1f2a3e", "#ffe066"),
                        "staff", acc="#ffe066", hair="long", hcol="#4a5a8a", G="#2f3e55"),
    "beacon_keeper": _npc("coat", "#f0c040", "#4a5f7a", "#ffe066", "#2f3e55", "#2a2a3a", "souwester", ("#f0c040",),
                          "lantern", hair="curly", hcol="#9a3a3a", extra=("belt",)),
    # moonwake
    "star_archer": _npc("tunic", "#2b2f6b", "#d9c8ff", "#8a7fd0", "#1a1d47", "#1a1d47", "hood", ("#3a3f8a",), "bow"),
    "moon_oracle": _npc("robe", "#8a7fd0", "#d9c8ff", "#f0e8ff", "#2b2f6b", "#2b2f6b", "circlet", ("#d9c8ff", "#d9c8ff", "#f0e8ff"),
                        "staff", acc="#e8e0ff", skin="moon", hair="long", hcol="#d8d8e0", G="#8a7fd0"),
    # ashen trench
    "relic_thief": _npc("jacket", "#3a3340", "#9a5a4a", "#ff7a5a", "#221d28", "#221d28", "hood", ("#2a2430",), "claws"),
    "trench_gunner": _npc("armor", "#5a4f4a", "#ff7a5a", "#ff7a5a", "#3a3340", "#221d28", "helmet", ("#6a6470", "#4a4450"),
                          "musket", M="#6a6470", G="#6a6470", hair=None),
    "ash_hexer": _npc("robe", "#5a4f4a", "#ff7a5a", "#9a5a4a", "#3a3340", "#3a3340", "hood", ("#4a4040",), "book",
                      acc="#ff7a5a", skin="ash", G="#5a4f4a"),
    "deep_priest": _npc("robe", "#6a2a3a", "#ff7a5a", GOLD, "#3a2a30", "#3a2a30", "mitre", ("#6a2a3a", GOLD), "staff",
                        acc="#ff7a5a", hair="short", hcol="#d8d8e0", G="#6a2a3a"),
    # leviathan ring
    "ring_raider": _npc("vest", "#1f7a8c", "#e8dcc0", "#9ef0d0", "#145566", "#2a2a2a", "bandana", ("#145566", "#9ef0d0"),
                        "cutlass", hair="ponytail", hcol="#c88a4a"),
    "tide_shaman": _npc("robe", "#1f7a8c", "#c9b28a", "#9ef0d0", "#145566", "#145566", "turban", ("#c9b28a", GOLD, "#9ef0d0"),
                        "staff", acc="#9ef0d0", hair="long", hcol="#2a2a3a", skin="s4", G="#1f7a8c"),
    "reef_mender": _npc("apron", "#f07a6a", "#f6f0dc", "#9ef0d0", "#145566", "#3a2a2a", "circlet", (GOLD, GOLD, "#f07a6a"),
                        "kit", hair="buns", hcol="#e8c878", W="#f6f0dc"),
    # grand horizon
    "gate_duelist": _npc("coat", "#f7e3b0", "#e08a4a", GOLD, "#a85a3a", "#5a3a2a", "feather", ("#a85a3a", GOLD, "#fff3c4"),
                         "blade", hair="ponytail", hcol="#9a3a3a", G=WHITE, extra=("belt", "cape"), K="#e08a4a"),
    "horizon_knight": _npc("armor", "#f2b84a", "#fff3c4", "#e08a4a", "#a85a3a", "#5a3a2a", "plumed", ("#f0e0b0", GOLD, "#e08a4a"),
                           "shield", acc="#e08a4a", M="#f0e0b0", G="#f0e0b0", extra=("cape",), K="#e08a4a"),
    "sky_gunner": _npc("jacket", "#e08a4a", "#fff3c4", "#a85a3a", "#7a5a3a", "#4a3424", "goggle_cap", ("#a85a3a", GOLD, GOLD),
                       "gun", hair="short", hcol="#e8c878", extra=("scarf",), A2="#fff3c4"),
    "dawn_mage": _npc("robe", "#f2b84a", "#fff3c4", "#e08a4a", "#a85a3a", "#a85a3a", "wizard", ("#e08a4a", "#fff3c4", WHITE),
                      "staff", acc="#fff3c4", hair="bob", hcol="#c890c8", G="#f2b84a"),
    "conclave_medic": _npc("labcoat", "#fff3c4", "#e08a4a", "#e08a4a", "#7a5a3a", "#5a3a2a", "circlet", (GOLD, GOLD, "#e08a4a"),
                           "kit", hair="long", hcol="#5a3a26", G=WHITE, extra=("cross",)),
    # pennant pirates
    "pennant_deckhand": _npc("vest", "#2e2a34", "#e8dcc0", "#d84a4a", "#3a3a4a", "#2a2020", "bandana", ("#c83a3a", "#2e2a34"),
                             "cutlass", hair="short", hcol="#3a2c2a"),
    "pennant_bosun": _npc("vest", "#5a3a2a", "#e8dcc0", "#d84a4a", "#2e2a34", "#2a2020", "bandana", ("#2e2a34", "#d84a4a"),
                          "tool", hair=None, S="#d8a074", G=LEATHER_D, extra=("bandolier",)),
    "pennant_gunner": _npc("coat", "#2e2a34", "#d84a4a", GOLD, "#5a4a4a", "#2a2020", "tricorn", ("#2e2a34", "#d84a4a"),
                           "musket", hair="ponytail", hcol="#2a2a3a", extra=("belt",)),
    "pennant_hexer": _npc("robe", "#3a2a4a", "#d84a4a", "#8a5ac8", "#2a2030", "#2a2030", "hood", ("#2e2a34",), "book",
                          acc="#8a5ac8", G="#3a2a4a"),
    "pennant_surgeon": _npc("labcoat", "#c8c0b0", "#8a8070", "#d84a4a", "#3a3a4a", "#2a2020", "bandana", ("#2e2a34", "#d84a4a"),
                            "kit", hair="bob", hcol="#5a3a26", G="#8a8070", extra=("cross",)),
    # faction leaders
    "leader_conclave": _npc("robe", "#f4efe2", GOLD, "#e08a4a", "#a85a3a", "#a85a3a", "crown", (GOLD, GOLD, "#e08a4a"),
                            "staff", acc="#fff3c4", hair="long", hcol="#d8d8e0", G="#f4efe2", extra=("cape",), K="#e08a4a"),
    "leader_league": _npc("coat", "#5a3a8a", GOLD, GOLD, "#2e2a3a", "#2e2a34", "tophat", ("#2e2a34", GOLD), "blade",
                          hair="short", hcol="#8a5a34", G=WHITE, extra=("belt", "hem", "emblem")),
    "leader_tidebound": _npc("robe", "#1f7a8c", "#9ef0d0", "#f4efe2", "#145566", "#145566", "turban", ("#9ef0d0", GOLD, WHITE),
                             "trident", hair="long", hcol="#2a2a3a", skin="s4", G="#1f7a8c", extra=("cape",), K="#145566"),
    "leader_pennants": _npc("coat", "#2e2a34", "#c83a3a", GOLD, "#3a2a2a", "#2a2020", "captain", ("#2e2a34", GOLD, "#c83a3a"),
                            "cutlass", hair="long", hcol="#9a3a3a", extra=("belt", "hem", "cape"), K="#8a1a2a"),
}

RIVAL_SET = [("dawnwater", "#3a8fd0", "#f7d154", "blade", "ponytail", "#e86a4a"),
             ("emberreach", "#b35a3c", "#ffb347", "gun", "spiky", "#2a2a3a"),
             ("verdant_maw", "#2f8f6a", "#c6e86b", "spear", "short", "#5a3a26"),
             ("glass_current", "#4fb3c8", "#e7f7ff", "staff", "long", "#d8d8e0"),
             ("crown_shoals", "#3f6fb8", "#ffd76a", "blade", "curly", "#e8c878"),
             ("stormbelt", "#4a5f7a", "#ffe066", "gun", "short", "#4a5a8a"),
             ("moonwake", "#2b2f6b", "#d9c8ff", "staff", "bob", "#c890c8"),
             ("ashen_trench", "#3a3340", "#ff7a5a", "cutlass", "spiky", "#9a3a3a"),
             ("leviathan_ring", "#1f7a8c", "#9ef0d0", "trident", "buns", "#3a2c2a"),
             ("grand_horizon", "#e08a4a", "#fff3c4", "blade", "long", "#c88a4a")]


def _rivals(world):
    by_region = {}
    for rid, r in world["RIVALS"].items():
        by_region[r["regionId"]] = rid
    # Each rival has a costume silhouette as well as a regional colour.
    # Tuple: coat shape, hat, equipment, badge. The existing layered rig and
    # generated identity stay unchanged, including equipment replacement.
    styles = [
        ("coat", "feather", ("belt", "scarf"), "wing"),
        ("overall", "goggle_cap", ("tools", "scarf"), "anvil"),
        ("jacket", "explorer", ("pack", "pouch"), "leaf"),
        ("robe", "circlet", ("cape", "emblem"), "prism"),
        ("coat", "tricorn", ("cape", "belt", "hem"), "crown"),
        ("coat", "souwester", ("fur", "belt"), "anchor"),
        ("robe", "turban", ("scarf", "emblem"), "moon"),
        ("armor", "horned", ("cape", "belt"), "lantern"),
        ("vest", "beast", ("fur", "sash"), "pearl"),
        ("coat", "captain", ("cape", "emblem", "hem"), "sun"),
    ]
    for i, (reg, col, acc, w, hair, hcol) in enumerate(RIVAL_SET):
        rid = by_region.get(reg, "rival_" + reg)
        shape, hat, equipment, signature = styles[i]
        NPC_LOOKS[rid] = _npc(shape, col, acc, acc, "#343442", "#443127", hat,
                              (mul(hexrgb(col), 0.64), acc, acc), w,
                              acc=acc, hair=hair, hcol=hcol, G=WHITE, extra=equipment,
                              signature=signature, M="#c8ad78", W="#efe1bd",
                              K=mul(hexrgb(col), 0.74), skin=["s1", "s3", "s2", "s1", "s4", "s2", "s5", "s3", "s4", "s2"][i])


# ----------------------------------------------------------- rendering ----

def render_layer(draw, **render_kw):
    """draw(cv, g, frame_index) -> Canvas. Returns a (32, 504, 4) strip."""
    strip = np.zeros((FH, FW * len(FRAMES), 4), np.uint8)
    for i, f in enumerate(FRAMES):
        cv = Canvas(FW, FH)
        draw(cv, GEOS[f])
        defaults = dict(light=(255, 242, 215), light_amt=0.2,
                        shade_mul=0.82, ol_mul=0.5, ol_mix=0.25)
        defaults.update(render_kw)
        strip[:, i * FW:(i + 1) * FW] = cv.render(**defaults)
    return strip


class Sheet:
    def __init__(self, name):
        self.name = name
        self.rows = {}
        self.strips = []

    def add(self, key, strip):
        self.rows[key] = len(self.strips)
        self.strips.append(strip)

    def save(self):
        n = len(self.strips)
        lines = (n + ATLAS_COLS - 1) // ATLAS_COLS
        W = FW * len(FRAMES) * ATLAS_COLS
        atlas = np.zeros((lines * FH, W, 4), np.uint8)
        table = {}
        for key, i in self.rows.items():
            x = (i % ATLAS_COLS) * FW * len(FRAMES)
            y = (i // ATLAS_COLS) * FH
            atlas[y:y + FH, x:x + FW * len(FRAMES)] = self.strips[i]
            table[key] = [x, y]
        path = OUT / "chars" / f"{self.name}.png"
        save_png(atlas, path)
        record(path.relative_to(GAME.parent), f"{W}x{lines * FH}", f"{n} rows x 21 frames (24x32)",
               "procedural pixel puppet (gen_chars.py)", f"character layer: {self.name}")
        return table


def build():
    world = json.loads((GAME / "data" / "world.json").read_text())
    _rivals(world)

    outfits, hats, weapons, bodies = Sheet("outfits"), Sheet("hats"), Sheet("weapons"), Sheet("bodies")
    hat_keys = {}
    looks = {}

    def add_look(key, L):
        o = dict(L["o"])
        o["identity"] = key
        outfits.add(key, render_layer(lambda cv, g: draw_outfit(cv, g, o)))
        hat = L["hat"]
        if hat[0] != "none":
            hk = "|".join(str(x) for x in hat)
            if hk not in hat_keys:
                hat_keys[hk] = key
                hats.add(key, render_layer(lambda cv, g: draw_hat(cv, g, *hat)))
            hat_row = hat_keys[hk]
        else:
            hat_row = None
        looks[key] = {"outfit": key, "hat": hat_row, "weapon": L["w"], "acc": L.get("acc"),
                      "hair": L.get("hair", True)}
        return looks[key]

    for cid, L in CLASS_LOOKS.items():
        add_look(cid, L)
    npcs = {}
    for nid, L in NPC_LOOKS.items():
        entry = add_look(nid, L)
        npcs[nid] = dict(entry, skin=L.get("skin") or "s2", hairStyle=L.get("hair"), hairColor=L.get("hcol"))

    # weapon rows: type + accent
    wkeys = set()
    for k, L in list(CLASS_LOOKS.items()) + list(NPC_LOOKS.items()):
        wkeys.add((L["w"], L.get("acc") or "#5ad8e8"))
    for wt in ["blade", "shield", "spear", "gun", "fist", "kit", "ladle", "staff", "tool", "whip", "banner"]:
        wkeys.add((wt, {"shield": "#3b5b9a", "banner": "#d84a4a", "staff": "#7af0f0"}.get(wt, "#5ad8e8")))
    weapon_rows = {}
    for (wt, acc) in sorted(wkeys):
        key = f"{wt}:{acc}"
        weapons.add(key, render_layer(lambda cv, g: draw_weapon(cv, g, wt, acc)))
        weapon_rows[key] = key
    for k, v in looks.items():
        v["weapon"] = f"{v['weapon']}:{v['acc'] or '#5ad8e8'}"
        v.pop("acc", None)
    for k, v in npcs.items():
        v["weapon"] = looks[k]["weapon"]
        v.pop("acc", None)
    default_weapon = {}
    for wt in ["blade", "shield", "spear", "gun", "fist", "kit", "ladle", "staff", "tool", "whip", "banner"]:
        default_weapon[wt] = f"{wt}:" + {"shield": "#3b5b9a", "banner": "#d84a4a", "staff": "#7af0f0"}.get(wt, "#5ad8e8")

    for sk, col in SKINS.items():
        bodies.add("skin:" + sk, render_layer(lambda cv, g: draw_head(cv, g, col)))
    hair_ol = dict(ol_tint=(70, 70, 70), ol_mix=0.3, ol_mul=0.38, light=(255, 255, 255), light_amt=0.15,
                   shade_mul=0.74, deep_mul=0.55)
    for st in HAIR_STYLES:
        def fr(cv, g, st=st):
            dummy = Canvas(FW, FH)
            draw_hair(cv, dummy, g, st)

        def bk(cv, g, st=st):
            dummy = Canvas(FW, FH)
            draw_hair(dummy, cv, g, st)
        bodies.add("hair:" + st, _grey(render_layer(fr, **hair_ol)))
        bodies.add("hairb:" + st, _grey(render_layer(bk, **hair_ol)))

    tables = {s.name: s.save() for s in (outfits, hats, weapons, bodies)}
    meta = {
        "frame": [FW, FH], "origin": list(ORIGIN), "frames": FRAMES,
        "layers": ["hair_back", "outfit", "skin", "hair_front", "hat", "weapon"],
        "sheets": {k: f"res://assets/gen/chars/{k}.png" for k in tables},
        "rows": tables,
        "skins": list(SKINS.keys())[:5], "specialSkins": list(SKINS.keys())[5:],
        "hairStyles": HAIR_STYLES, "hairColors": HAIR_COLORS,
        "classes": looks_for(looks, CLASS_LOOKS), "npcs": npcs, "weapons": default_weapon,
        "anims": {
            "idle": {"frames": [0, 1], "fps": 2}, "walk": {"frames": [2, 3, 4, 5], "fps": 8},
            "work": {"frames": [6, 7], "fps": 4}, "attack": {"frames": [8, 9, 10], "fps": 10, "loop": False},
            "hit": {"frames": [11], "fps": 4, "loop": False}, "down": {"frames": [12], "fps": 1, "loop": False},
            "cheer": {"frames": [13, 14], "fps": 4},
            "idle_back": {"frames": [15, 16], "fps": 2}, "walk_back": {"frames": [17, 18, 19, 20], "fps": 8},
        },
    }
    save_json(meta, OUT / "chars" / "chars.json")
    preview(meta, tables)
    return meta


def looks_for(looks, src):
    return {k: looks[k] for k in src}


def _grey(strip):
    """Hair strips: keep greyscale (already grey); ensures neutral channel balance."""
    a = strip.copy()
    lum = (a[..., 0].astype(int) * 30 + a[..., 1].astype(int) * 59 + a[..., 2].astype(int) * 11) // 100
    for i in range(3):
        a[..., i] = lum
    return a


# ------------------------------------------------------------- preview ----

def load_sheet(name):
    return np.array(Image.open(OUT / "chars" / f"{name}.png").convert("RGBA"))


def compose(sheets, tables, frame, outfit, hat, weapon, skin, hair, hcol):
    out = np.zeros((FH, FW, 4), np.uint8)

    def take(sheet, key):
        x, y = tables[sheet][key]
        return sheets[sheet][y:y + FH, x + frame * FW:x + (frame + 1) * FW]

    def tint(a, col):
        c = hexrgb(col)
        b = a.copy().astype(np.float32)
        for i in range(3):
            b[..., i] = b[..., i] * c[i] / 255.0
        return b.clip(0, 255).astype(np.uint8)

    if hair:
        out = over(out, tint(take("bodies", "hairb:" + hair), hcol))
    out = over(out, take("outfits", outfit))
    out = over(out, take("bodies", "skin:" + skin))
    if hair:
        out = over(out, tint(take("bodies", "hair:" + hair), hcol))
    if hat:
        out = over(out, take("hats", hat))
    out = over(out, take("weapons", weapon))
    return out


def preview(meta, tables):
    sheets = {k: load_sheet(k) for k in tables}
    rng = np.random.default_rng(7)
    rows = []
    for i, (cid, L) in enumerate(meta["classes"].items()):
        hair = HAIR_STYLES[i % len(HAIR_STYLES)] if L["hair"] else None
        hcol = HAIR_COLORS[(i * 5) % len(HAIR_COLORS)]
        skin = meta["skins"][i % 5]
        strip = np.zeros((FH, FW * len(FRAMES), 4), np.uint8)
        for f in range(len(FRAMES)):
            strip[:, f * FW:(f + 1) * FW] = compose(sheets, tables, f, L["outfit"], L["hat"], L["weapon"], skin, hair,
                                                    hcol)
        rows.append(strip)
    npc_rows = []
    for nid, L in meta["npcs"].items():
        frame_set = [0, 2, 9, 11, 15]
        strip = np.zeros((FH, FW * len(frame_set), 4), np.uint8)
        for j, f in enumerate(frame_set):
            strip[:, j * FW:(j + 1) * FW] = compose(sheets, tables, f, L["outfit"], L["hat"], L["weapon"], L["skin"],
                                                    L["hairStyle"], L["hairColor"] or "#3a2c2a")
        npc_rows.append(strip)
    a = np.concatenate(rows, 0)
    k = 3
    img = Image.fromarray(a).resize((a.shape[1] * k, a.shape[0] * k), Image.NEAREST)
    bg = Image.new("RGBA", img.size, (196, 160, 112, 255))
    bg.alpha_composite(img)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    bg.save(PREVIEW / "chars_classes.png")
    # npc grid: 4 per line
    per = 4
    lines = []
    for i in range(0, len(npc_rows), per):
        chunk = npc_rows[i:i + per]
        while len(chunk) < per:
            chunk.append(np.zeros_like(npc_rows[0]))
        lines.append(np.concatenate([np.pad(c, ((0, 0), (0, 8), (0, 0))) for c in chunk], 1))
    b = np.concatenate(lines, 0)
    img = Image.fromarray(b).resize((b.shape[1] * k, b.shape[0] * k), Image.NEAREST)
    bg = Image.new("RGBA", img.size, (90, 120, 140, 255))
    bg.alpha_composite(img)
    bg.save(PREVIEW / "chars_npcs.png")


if __name__ == "__main__":
    m = build()
    print("classes", len(m["classes"]), "npcs", len(m["npcs"]))
