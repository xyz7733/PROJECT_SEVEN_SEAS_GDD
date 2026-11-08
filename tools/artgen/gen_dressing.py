"""Interior dressing: stores, guns, cargo and work corners for the hull levels.

The interior levels of every hull are furnished by the player's facilities.
Between them the floor used to stay bare. These single-cell pieces fill the
walls and bays around the routes: guns under the gun-deck ports, powder and
shot, sea chests, hammocks, a carpenter's bench, cable tiers, sail bundles,
lockers and shelving on the orlop, cargo, casks, a hen coop and a bilge pump
in the hold. Structure pieces compose the levels into rooms: plank partitions
(a plain section and an end with a door post, the door hooked open and a
lantern), deck stanchions, and mess tables under hanging lanterns. The game
places them deterministically around the corridors
(scripts/view/ship_dress.gd), so they never cut a route.

Each item is a voxel model on one 16-voxel ship cell, rendered alone for a
crisp outline, plus a translucent cast-shadow overlay that is sliced per floor
cell so it sorts under neighbouring actors. Both rotations are rendered: rot 0
has its back to the far wall (y = 0), rot 1 to the stern wall (x = 0).
Flat floor pieces (canvas runners and duckboards in 16 connection masks, and
floor patches: straw, stains, scuffs, sand, replacement boards, a scuttle
grating) and low slat battens for cargo bays complete the set.

Outputs (game/assets/gen/ship/):
  dressing.png / dressing.json
"""
from __future__ import annotations

import math

import numpy as np

from lib.common import GAME, OUT, PREVIEW, Packer, record, save_json, save_png, trim
from lib.kit import F, P
from lib.kvol import K, KVol, fzf
from lib.vox import EMIT, GLOSS, NOSHADOW, SEAM, SEAM_L, SEAM_SIDE, Vol, hexrgb, mix, mul, render

CELL = 16            # fine voxels per ship cell
INTERIOR_CLIP = 22   # interior levels are cut 22 voxels above the floor surface
KZ = 15              # kit height of the item volume

W = {
    "d": hexrgb("#8e5531"), "dd": hexrgb("#5e3620"), "m": hexrgb("#b07440"), "l": hexrgb("#d39a5c"),
    "floor": hexrgb("#a8703f"), "iron": hexrgb("#4a4f5a"), "iron_l": hexrgb("#6c7380"),
    "rope": hexrgb("#a07c4a"), "rope_d": hexrgb("#7a5a34"), "canvas": hexrgb("#e3d6b4"),
    "canvas_d": hexrgb("#c4b48c"), "tar": hexrgb("#2e2622"), "powder": hexrgb("#7a2a26"),
}
SHADOW_RGB = (22, 18, 40)


# -- fine-voxel helpers (16 per cell, z from the floor top F = 1) ---------------

def fbox(kv, x0, y0, z0, x1, y1, z1, col, flags=0):
    """Box in fine voxels on the KVol's underlying volume (z clipped)."""
    v = kv.v
    X, Y, Z = v.shape
    z1 = min(z1, F + INTERIOR_CLIP)
    x0, y0, z0 = max(0, int(x0)), max(0, int(y0)), max(0, int(z0))
    x1, y1, z1 = min(X, int(x1)), min(Y, int(y1)), min(Z, int(z1))
    if x0 >= x1 or y0 >= y1 or z0 >= z1:
        return
    v.box(x0, y0, z0, x1, y1, z1, col, flags)


def fball(kv, cx, cy, cz, r, col, flags=GLOSS):
    for x in range(int(cx - r - 1), int(cx + r + 2)):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for z in range(int(cz - r - 1), int(cz + r + 2)):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 + (z + 0.5 - cz) ** 2 <= r * r:
                    fbox(kv, x, y, z, x + 1, y + 1, z + 1, col, flags)


def fhcyl(kv, axis, a0, a1, c1, cz, r, col_fn, flags=0):
    """Horizontal cylinder along x ('x') or y ('y'); col_fn(a, d) picks a colour
    from the position along the axis and the radial distance."""
    for u in range(int(c1 - r - 1), int(c1 + r + 2)):
        for z in range(int(cz - r - 1), int(cz + r + 2)):
            d = math.hypot(u + 0.5 - c1, z + 0.5 - cz)
            if d > r:
                continue
            for a in range(int(a0), int(a1)):
                c = col_fn(a, d)
                if c is None:
                    continue
                if axis == "x":
                    fbox(kv, a, u, z, a + 1, u + 1, z + 1, c, flags)
                else:
                    fbox(kv, u, a, z, u + 1, a + 1, z + 1, c, flags)


def fcyl(kv, cx, cy, z0, z1, r, col, flags=0):
    for x in range(int(cx - r - 1), int(cx + r + 2)):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                fbox(kv, x, y, z0, x + 1, y + 1, z1, col, flags)


def fring(kv, cx, cy, z0, z1, r0, r1, col, flags=0):
    for x in range(int(cx - r1 - 1), int(cx + r1 + 2)):
        for y in range(int(cy - r1 - 1), int(cy + r1 + 2)):
            d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
            if r0 * r0 <= d2 <= r1 * r1:
                fbox(kv, x, y, z0, x + 1, y + 1, z1, col, flags)


def barrel(kv, cx, cy, h, r, wood=None, hoop=None, z0=F, lid=None):
    wood = wood or W["m"]
    hoop = hoop or W["iron"]
    for z in range(z0, z0 + h):
        t = (z - z0) / max(1, h - 1)
        rr = r * (0.9 + 0.1 * math.sin(math.pi * t))
        c = hoop if (z - z0) in (1, h - 3) else (mul(wood, 1.0 + 0.06 * ((z - z0) % 2)))
        fcyl(kv, cx, cy, z, z + 1, rr + (0.3 if c == hoop else 0), c, SEAM_L if c != hoop else 0)
    fcyl(kv, cx, cy, z0 + h - 1, z0 + h, r * 0.82, lid or mul(wood, 1.15))
    return z0 + h


def crate(kv, x0, y0, z0, sx, sy, h, wood=None, mark=None):
    wood = wood or W["m"]
    fbox(kv, x0, y0, z0, x0 + sx, y0 + sy, z0 + h, wood, SEAM_SIDE)
    fbox(kv, x0, y0, z0 + h - 1, x0 + sx, y0 + sy, z0 + h, mul(wood, 1.08), SEAM)
    # corner battens on the visible edges
    dk = W["d"]
    fbox(kv, x0 + sx - 1, y0 + sy - 1, z0, x0 + sx, y0 + sy, z0 + h, dk)
    fbox(kv, x0, y0 + sy - 1, z0, x0 + 1, y0 + sy, z0 + h, dk)
    fbox(kv, x0 + sx - 1, y0, z0, x0 + sx, y0 + 1, z0 + h, dk)
    fbox(kv, x0, y0 + sy - 1, z0 + h - 1, x0 + sx, y0 + sy, z0 + h, dk)
    fbox(kv, x0 + sx - 1, y0, z0 + h - 1, x0 + sx, y0 + sy, z0 + h, dk)
    if mark is not None:
        # stencilled mark on the left-front face
        mx = x0 + sx // 2 - 1
        fbox(kv, mx, y0 + sy - 1, z0 + h // 2 - 1, mx + 2, y0 + sy, z0 + h // 2 + 1, mark)
    return z0 + h


def sack(kv, x0, y0, z0, sx, sy, h, col):
    fbox(kv, x0 + 1, y0, z0, x0 + sx - 1, y0 + sy, z0 + h, col)
    fbox(kv, x0, y0 + 1, z0, x0 + sx, y0 + sy - 1, z0 + h - 1, col)
    fbox(kv, x0 + 1, y0 + 1, z0 + h, x0 + sx - 1, y0 + sy - 1, z0 + h + 1, mul(col, 1.06))
    tx, ty = x0 + sx // 2, y0 + sy // 2
    fbox(kv, tx - 1, ty - 1, z0 + h + 1, tx + 1, ty + 1, z0 + h + 3, W["rope"])


def chest(kv, x0, y0, z0, sx, sy, h, wood, band):
    fbox(kv, x0, y0, z0, x0 + sx, y0 + sy, z0 + h - 2, wood, SEAM_SIDE)
    fbox(kv, x0, y0, z0 + h - 2, x0 + sx, y0 + sy, z0 + h, mul(wood, 1.12), GLOSS)
    for bx in (x0 + 1, x0 + sx - 3):
        fbox(kv, bx, y0, z0, bx + 2, y0 + sy, z0 + h, band)
    fbox(kv, x0 + sx // 2 - 1, y0 + sy, z0 + h - 4, x0 + sx // 2 + 1, y0 + sy + 1, z0 + h - 2, P["gold"], GLOSS)
    return z0 + h


def lantern(kv, cx, cy, z0, lit=True):
    """Hanging lantern centred on (cx, cy); z0 is its bottom. Returns the light point."""
    fbox(kv, cx - 2, cy - 2, z0, cx + 2, cy + 2, z0 + 1, W["iron"])
    fbox(kv, cx - 2, cy - 2, z0 + 1, cx + 2, cy + 2, z0 + 5, P["lamp"] if lit else P["cream"],
         (EMIT | NOSHADOW) if lit else 0)
    for (ax, ay) in ((cx - 2, cy - 2), (cx + 1, cy - 2), (cx - 2, cy + 1), (cx + 1, cy + 1)):
        fbox(kv, ax, ay, z0 + 1, ax + 1, ay + 1, z0 + 5, W["iron"], NOSHADOW)
    fbox(kv, cx - 2, cy - 2, z0 + 5, cx + 2, cy + 2, z0 + 6, W["iron"])
    fbox(kv, cx - 1, cy - 1, z0 + 6, cx + 1, cy + 1, z0 + 7, W["iron"])
    return (cx, cy, z0 + 3)


class Ctx:
    def __init__(self):
        self.lights = []   # fine (x, y, z, kind)

    def light(self, p, kind="lamp"):
        self.lights.append((p[0], p[1], p[2], kind))


# -- items (fine coordinates; back to y = 0; +x and +y face the viewer) ---------

def i_gun(kv, c):
    """Gun on a truck carriage, run out to the port in the far wall."""
    wd, wdd = W["d"], W["dd"]
    for x0 in (3, 11):                                   # carriage cheeks, stepped at the rear
        fbox(kv, x0, 2, F, x0 + 2, 14, F + 5, wd, SEAM_SIDE)
        fbox(kv, x0, 2, F + 5, x0 + 2, 9, F + 7, wd)
    fbox(kv, 5, 4, F, 11, 13, F + 2, wdd)                # bed
    fbox(kv, 5, 3, F + 2, 11, 5, F + 4, wdd)             # front transom
    for (yy) in (3, 11):                                  # trucks
        for x0 in (1, 13):
            fhcyl(kv, "x", x0, x0 + 2, yy + 1, F + 2, 2.2, lambda a, d: wdd if d < 1.2 else W["d"])
    # barrel (muzzle at the port)
    fhcyl(kv, "y", 0, 14, 8, F + 8, 2.2,
          lambda a, d: (W["iron_l"] if a < 2 and d > 1.2 else (P["black"] if a == 0 and d < 1.2 else W["iron"])))
    fhcyl(kv, "y", 15, 16, 8, F + 8, 1.3, lambda a, d: W["iron"])
    fbox(kv, 7, 10, F + 7, 9, 13, F + 7 + 4, W["iron"])  # breech reinforce / vent
    # breeching ropes to the wall ring bolts
    fbox(kv, 2, 0, F + 5, 3, 8, F + 6, W["rope"])
    fbox(kv, 13, 0, F + 5, 14, 8, F + 6, W["rope"])
    # three round shot at the front corner
    for (bx, by) in ((13.5, 14.2), (15.0, 12.6), (14.6, 15.0)):
        fball(kv, bx, by, F + 1.1, 1.2, P["black"])


def i_powder(kv, c):
    """Powder kegs and a shot garland tray."""
    barrel(kv, 4, 4, 9, 3.2, wood=W["d"], hoop=W["powder"])
    barrel(kv, 11, 3.5, 8, 2.8, wood=W["d"], hoop=W["powder"])
    fbox(kv, 1, 10, F, 15, 15, F + 2, W["dd"], SEAM_SIDE)      # tray
    fbox(kv, 1, 10, F + 2, 15, 11, F + 3, W["d"])
    for i in range(5):
        fball(kv, 3 + i * 2.6, 12.8, F + 3.4, 1.25, P["black"])
    for i in range(4):
        fball(kv, 4.3 + i * 2.6, 12.8, F + 5.6, 1.25, P["black"])
    fbox(kv, 6, 6, F, 9, 9, F + 1, W["tar"])                    # spilled powder dust


def i_shot_rack(kv, c):
    """Low shot rack along the wall with a rammer and sponge leaning on it."""
    fbox(kv, 0, 1, F, 16, 6, F + 5, W["d"], SEAM_SIDE)
    fbox(kv, 0, 1, F + 5, 16, 6, F + 6, W["l"], GLOSS)
    for i in range(6):
        fball(kv, 1.5 + i * 2.6, 3.5, F + 7.0, 1.25, P["black"])
    # rammer and sponge staves leaning against the wall
    for k in range(14):
        fbox(kv, 3 + k // 3, 0, F + 6 + k, 4 + k // 3, 1, F + 7 + k, W["l"])
        fbox(kv, 10 + k // 3, 0, F + 6 + k, 11 + k // 3, 1, F + 7 + k, W["l"])
    fbox(kv, 7, 0, F + 18, 9, 2, F + 21, W["canvas_d"])
    fbox(kv, 14, 0, F + 18, 16, 2, F + 21, W["iron"])
    # bucket
    fring(kv, 6, 11, F, F + 5, 1.3, 2.6, W["m"], SEAM_SIDE)
    fcyl(kv, 6, 11, F, F + 1, 2.0, W["dd"])
    fcyl(kv, 6, 11, F + 3, F + 4, 1.3, P["water_d"])


def i_chests(kv, c):
    """Sailors' sea chests, one on another, and a ditty bag."""
    chest(kv, 1, 1, F, 10, 6, 7, W["d"], W["iron"])
    chest(kv, 2, 1, F + 7, 8, 5, 6, P["navy_d"], W["l"])
    chest(kv, 10, 8, F, 5, 6, 6, W["m"], W["iron"])
    sack(kv, 2, 9, F, 6, 5, 6, P["canvas"])


def i_water_butt(kv, c):
    """Scuttlebutt with a ladle and a tin cup on a stool."""
    barrel(kv, 7, 6, 15, 5.0, wood=W["m"])
    fcyl(kv, 7, 6, F + 15, F + 16, 3.6, P["water_d"])
    fbox(kv, 6, 2, F + 15, 7, 6, F + 16, W["iron_l"])    # ladle handle
    fbox(kv, 11, 3, F + 9, 14, 7, F + 10, W["d"])        # cup shelf
    fbox(kv, 12, 4, F + 10, 13, 5, F + 12, W["iron_l"])
    fbox(kv, 11, 3, F, 12, 4, F + 9, W["dd"])
    fbox(kv, 13, 12, F, 16, 15, F + 1, P["water"], GLOSS)  # wet patch


def i_hammock(kv, c):
    """Slung hammock with a sleeper's bedroll, a sea bag below."""
    for x0 in (0, 14):                                    # hooks on the beam
        fbox(kv, x0, 1, F + 18, x0 + 2, 3, F + 19, W["iron"])
    for k in range(6):                                    # clews
        fbox(kv, 1 + k // 2, 2, F + 17 - k, 2 + k // 2, 3, F + 18 - k, W["rope"], NOSHADOW)
        fbox(kv, 14 - k // 2, 2, F + 17 - k, 15 - k // 2, 3, F + 18 - k, W["rope"], NOSHADOW)
    for x in range(3, 13):
        sag = int(round(2.2 * math.sin(math.pi * (x - 2.5) / 10.0)))
        z = F + 11 - sag
        fbox(kv, x, 1, z, x + 1, 6, z + 1, W["canvas"])
        fbox(kv, x, 1, z + 1, x + 1, 2, z + 2, W["canvas_d"])
        fbox(kv, x, 5, z + 1, x + 1, 6, z + 2, W["canvas_d"])
        if 5 <= x <= 10:
            fbox(kv, x, 2, z + 1, x + 1, 5, z + 3, P["navy"] if x < 9 else P["white"])
    sack(kv, 5, 9, F, 6, 5, 7, W["canvas_d"])
    fbox(kv, 11, 10, F, 15, 14, F + 2, P["red_d"])         # folded blanket


def i_rope_coil(kv, c):
    """Coiled line, a tar bucket and a swab against the wall."""
    fring(kv, 6, 8, F, F + 2, 1.5, 5.0, W["rope"])
    fring(kv, 6, 8, F + 2, F + 3, 1.5, 4.0, W["rope_d"])
    fring(kv, 6, 8, F + 3, F + 4, 1.5, 3.0, W["rope"])
    for a in range(12):
        t = a / 12 * 2 * math.pi
        x, y = 6 + 4.5 * math.cos(t), 8 + 4.5 * math.sin(t)
        fbox(kv, x, y, F + 1, x + 1, y + 1, F + 2, W["rope_d"])
    fring(kv, 13, 4, F, F + 5, 1.3, 2.4, W["dd"])
    fcyl(kv, 13, 4, F + 3, F + 4, 1.3, W["tar"])
    for k in range(18):                                   # swab handle leaning on the wall
        fbox(kv, 2, 0 + k // 9, F + 2 + k, 3, 1 + k // 9, F + 3 + k, W["l"])
    fbox(kv, 1, 1, F, 4, 4, F + 3, W["canvas_d"])


def i_workbench(kv, c):
    """Carpenter's bench with a vice, a tool board and offcuts."""
    fbox(kv, 0, 0, F, 16, 1, F + 20, W["d"], SEAM_L)      # tool board
    for (tx, h, col) in ((2, 6, W["iron_l"]), (5, 4, W["l"]), (8, 7, W["iron_l"]), (12, 5, W["iron"])):
        fbox(kv, tx, 1, F + 12, tx + 2, 2, F + 12 + h, col)
    fbox(kv, 9, 1, F + 17, 13, 2, F + 18, W["l"])
    fbox(kv, 1, 2, F + 8, 15, 8, F + 10, W["l"], GLOSS)   # top
    for (lx, ly) in ((1, 2), (13, 2), (1, 6), (13, 6)):
        fbox(kv, lx, ly, F, lx + 2, ly + 2, F + 8, W["d"])
    fbox(kv, 1, 4, F + 2, 15, 5, F + 3, W["d"])           # stretcher
    fbox(kv, 12, 7, F + 6, 15, 9, F + 11, W["iron"])      # vice
    fbox(kv, 3, 3, F + 10, 10, 6, F + 11, P["wood_l"])    # plank being planed
    fbox(kv, 5, 4, F + 11, 7, 5, F + 12, W["iron_l"])
    for (sx, sy) in ((4, 11), (7, 12), (10, 10)):         # shavings and offcuts
        fbox(kv, sx, sy, F, sx + 2, sy + 1, F + 1, P["straw"])
    fbox(kv, 11, 12, F, 15, 14, F + 2, W["l"])


def i_lantern(kv, c):
    """Stanchion with a hanging lantern and a sand bucket."""
    fbox(kv, 7, 7, F, 9, 9, F + 21, W["d"], SEAM_SIDE)
    fbox(kv, 6, 6, F, 10, 10, F + 1, W["dd"])
    fbox(kv, 9, 7, F + 17, 12, 8, F + 18, W["iron"])     # bracket
    fbox(kv, 11, 7, F + 14, 12, 8, F + 17, W["iron"])
    c.light(lantern(kv, 11.5, 8, F + 7))
    fring(kv, 4, 12, F, F + 4, 1.2, 2.4, W["powder"])
    fcyl(kv, 4, 12, F + 2, F + 3, 1.2, P["sand"])


def i_cable(kv, c):
    """Cable tier: the anchor cable flaked down in a big coil."""
    fbox(kv, 0, 0, F, 16, 16, F + 1, W["dd"])              # tier gratings
    for x in range(1, 16, 3):
        fbox(kv, x, 0, F + 1, x + 1, 16, F + 2, W["d"])
    for layer, (r0, r1) in enumerate(((2.0, 7.4), (2.0, 6.6), (2.0, 5.6))):
        z = F + 2 + layer * 2
        fring(kv, 8, 8, z, z + 2, r0, r1, W["rope"] if layer % 2 == 0 else mul(W["rope"], 0.92))
    for a in range(20):
        t = a / 20 * 2 * math.pi
        for r in (3.4, 5.0):
            x, y = 8 + r * math.cos(t), 8 + r * math.sin(t)
            fbox(kv, x, y, F + 7, x + 1, y + 1, F + 8, W["rope_d"])
    fbox(kv, 7, 0, F + 6, 9, 3, F + 8, W["rope"])          # cable end to the hawse


def i_sails(kv, c):
    """Spare sails rolled and lashed, stacked on dunnage."""
    for y0 in (2, 9):
        fbox(kv, 0, y0, F, 16, y0 + 2, F + 1, W["dd"])
    def roll(cy, cz, r, col):
        fhcyl(kv, "x", 1, 15, cy, cz, r,
              lambda a, d: (W["rope_d"] if a in (4, 11) else (mul(col, 0.9) if d > r - 1.0 else col)))
    roll(4.0, F + 4.2, 3.2, W["canvas"])
    roll(11.0, F + 4.2, 3.2, mix(W["canvas"], P["straw"], 0.25))
    roll(7.5, F + 9.5, 3.0, W["canvas_d"])


def i_lockers(kv, c):
    """Tall lockers with two doors and a bin on top."""
    fbox(kv, 1, 0, F, 15, 6, F + 19, W["d"], SEAM_L)
    fbox(kv, 1, 6, F, 15, 7, F + 1, W["dd"])
    for dx0 in (2, 8):
        fbox(kv, dx0, 6, F + 2, dx0 + 6, 7, F + 18, W["m"], SEAM_SIDE)
        for vy in range(F + 13, F + 17, 2):
            fbox(kv, dx0 + 1, 7, vy, dx0 + 5, 8, vy + 1, W["dd"])
    fbox(kv, 7, 7, F + 9, 8, 8, F + 11, P["brass"], GLOSS)
    fbox(kv, 8, 7, F + 9, 9, 8, F + 11, P["brass"], GLOSS)
    fbox(kv, 15, 1, F + 2, 16, 6, F + 18, W["dd"])
    fbox(kv, 3, 1, F + 19, 9, 5, F + 21, W["canvas_d"])
    fbox(kv, 2, 9, F, 7, 14, F + 4, W["m"], SEAM_SIDE)        # boot box
    fbox(kv, 3, 10, F + 4, 5, 12, F + 6, P["black"])


def i_shelves(kv, c):
    """Open shelving: jars, bottles, boxes and bolts of cloth."""
    for x0 in (0, 14):
        fbox(kv, x0, 0, F, x0 + 2, 6, F + 21, W["d"], SEAM_SIDE)
    for z in (F, F + 7, F + 14, F + 20):
        fbox(kv, 0, 0, z, 16, 6, z + 1, W["l"] if z > F else W["dd"])
    fbox(kv, 2, 0, F + 1, 14, 1, F + 20, W["dd"])
    items = [
        [(2, 3, P["red_d"]), (5, 3, P["cream"]), (8, 3, P["green_d"]), (11, 3, P["brass"])],
        [(2, 4, P["navy"]), (6, 5, P["canvas"]), (10, 4, P["teal"])],
        [(3, 3, P["glass"]), (6, 3, P["glass"]), (9, 3, P["purple"]), (12, 2, P["cream"])],
    ]
    for li, row in enumerate(items):
        z = F + 1 + li * 7
        for (x, wdt, col) in row:
            h = 4 + (x * 7 + li) % 3
            fbox(kv, x, 1, z, x + wdt, 5, z + h, col, GLOSS if col == P["glass"] else 0)
    fbox(kv, 2, 8, F, 7, 13, F + 5, W["m"], SEAM_SIDE)
    fbox(kv, 9, 9, F, 13, 13, F + 3, W["canvas_d"])


def i_crates(kv, c):
    """Lashed crates."""
    crate(kv, 0, 0, F, 9, 9, 9, W["m"], mark=P["navy"])
    crate(kv, 9, 1, F, 7, 7, 7, W["l"])
    crate(kv, 1, 1, F + 9, 7, 7, 6, W["l"], mark=P["red_d"])
    crate(kv, 2, 10, F, 6, 5, 5, W["d"])
    fbox(kv, 0, 4, F + 15, 8, 5, F + 16, W["rope"])


def i_crates_tall(kv, c):
    """Crates stacked to the deck beams."""
    crate(kv, 0, 0, F, 10, 10, 8, W["m"])
    crate(kv, 0, 0, F + 8, 10, 10, 7, W["l"], mark=P["green_d"])
    crate(kv, 1, 1, F + 15, 8, 8, 6, W["m"])
    crate(kv, 10, 0, F, 6, 9, 9, W["d"], mark=P["red_d"])
    fbox(kv, 10, 3, F + 9, 16, 4, F + 10, W["rope"])


def i_barrels(kv, c):
    """Barrels of salt meat and biscuit."""
    barrel(kv, 4, 4, 13, 3.6)
    barrel(kv, 12, 4, 12, 3.4, wood=W["l"])
    barrel(kv, 8, 11.5, 11, 3.4, wood=W["d"])
    fbox(kv, 12, 12, F, 15, 15, F + 1, P["white"])          # spilt salt


def i_sacks(kv, c):
    """Sacks of grain and peas on a pallet."""
    fbox(kv, 0, 0, F, 16, 15, F + 1, W["dd"])
    for x in range(0, 16, 3):
        fbox(kv, x, 0, F + 1, x + 2, 15, F + 2, W["d"])
    cols = [P["canvas"], mix(P["canvas"], P["straw_d"], 0.4), W["canvas_d"], P["canvas"]]
    for i, (x0, y0) in enumerate(((0, 0), (8, 0), (0, 7), (8, 7))):
        sack(kv, x0, y0, F + 2, 8, 7, 5, cols[i])
    sack(kv, 3, 2, F + 8, 8, 7, 5, cols[1])
    fbox(kv, 11, 13, F, 15, 16, F + 1, P["straw"])         # spilt grain


def i_cask(kv, c):
    """A great cask on chocks with a tap and a drip tray."""
    for x0 in (2, 11):
        fbox(kv, x0, 2, F, x0 + 3, 14, F + 3, W["dd"])
    def col(a, d):
        if a in (2, 3, 12, 13):
            return W["iron"]
        return W["m"] if (a % 2) else mul(W["m"], 1.07)
    fhcyl(kv, "x", 1, 15, 8, F + 7.5, 6.0, col)
    fbox(kv, 15, 7, F + 3, 16, 9, F + 5, W["iron_l"])          # tap
    fbox(kv, 13, 6, F, 16, 10, F + 1, W["iron"])
    fbox(kv, 14, 7, F + 1, 16, 9, F + 2, P["red_d"])


def i_net_cargo(kv, c):
    """Cargo lashed under a net."""
    crate(kv, 0, 0, F, 10, 12, 8, W["m"])
    crate(kv, 10, 1, F, 6, 10, 10, W["l"])
    crate(kv, 1, 1, F + 8, 8, 9, 6, W["d"])
    v = kv.v
    s = v.solid
    X, Y, Z = s.shape
    for x in range(X):
        for y in range(Y):
            for z in range(1, Z):
                if not s[x, y, z]:
                    continue
                exposed = (z + 1 >= Z or not s[x, y, z + 1]) or (x + 1 >= X or not s[x + 1, y, z]) or \
                          (y + 1 >= Y or not s[x, y + 1, z])
                if exposed and ((x + y + z) % 4 == 0 or (x - y + z) % 4 == 0):
                    v.col[x, y, z] = W["rope_d"]
                    v.flag[x, y, z] = 0


def i_ballast(kv, c):
    """Pig-iron ballast and shingle."""
    rng = np.random.default_rng(7)
    for layer in range(3):
        for i in range(4 - layer):
            if layer % 2 == 0:
                fbox(kv, 1 + layer, 1 + i * 3 + layer, F + layer * 2, 15 - layer, 3 + i * 3 + layer, F + layer * 2 + 2,
                     W["iron"] if (i + layer) % 2 else W["iron_l"], GLOSS)
            else:
                fbox(kv, 2 + i * 3 + layer, 2, F + layer * 2, 4 + i * 3 + layer, 12, F + layer * 2 + 2,
                     W["iron"], GLOSS)
    for _ in range(14):
        x, y = rng.integers(0, 14), rng.integers(12, 15)
        fbox(kv, x, y, F, x + 2, y + 2, F + 1 + int(rng.integers(0, 2)), mix(P["stone"], P["stone_d"], float(rng.random())))


def i_lumber(kv, c):
    """Spare spars and planks on dunnage."""
    for x0 in (2, 12):
        fbox(kv, x0, 0, F, x0 + 2, 15, F + 1, W["dd"])
    for i in range(4):
        fhcyl(kv, "x", 0, 16, 2 + i * 3.4, F + 2.6, 1.6, lambda a, d: W["l"] if d < 1.0 else W["m"])
    for i in range(3):
        fbox(kv, 0, 2 + i * 4, F + 4, 16, 5 + i * 4, F + 5, W["l"], SEAM_SIDE)
    fbox(kv, 1, 3, F + 5, 15, 6, F + 6, mul(W["l"], 1.06))


def i_coop(kv, c):
    """Hen coop with slatted fronts and a feed trough."""
    fbox(kv, 0, 0, F, 15, 11, F + 1, W["dd"])
    fbox(kv, 0, 0, F + 10, 15, 11, F + 11, W["m"], SEAM)
    fbox(kv, 0, 0, F + 1, 15, 1, F + 10, W["d"])
    fbox(kv, 0, 0, F + 1, 1, 11, F + 10, W["d"])
    for x in range(1, 15, 3):
        fbox(kv, x, 10, F + 1, x + 1, 11, F + 10, W["l"])
    for y in range(1, 11, 3):
        fbox(kv, 14, y, F + 1, 15, y + 1, F + 10, W["l"])
    fbox(kv, 0, 10, F + 5, 15, 11, F + 6, W["m"])
    fbox(kv, 1, 1, F + 1, 14, 10, F + 2, P["straw"])
    for (hx, hy, col) in ((4, 4, P["white"]), (9, 6, hexrgb("#b8743a"))):
        fbox(kv, hx, hy, F + 2, hx + 4, hy + 3, F + 5, col)
        fbox(kv, hx + 3, hy + 1, F + 5, hx + 5, hy + 2, F + 7, col)
        fbox(kv, hx + 5, hy + 1, F + 6, hx + 6, hy + 2, F + 7, P["orange"])
        fbox(kv, hx + 3, hy + 1, F + 7, hx + 4, hy + 2, F + 8, P["red"])
    fbox(kv, 3, 12, F, 13, 15, F + 3, W["d"], SEAM_SIDE)   # trough
    fbox(kv, 4, 13, F + 2, 12, 14, F + 3, P["straw_d"])


def i_pump(kv, c):
    """Chain pump: barrel, brake handle and a wet floor."""
    fbox(kv, 2, 1, F, 10, 9, F + 4, W["d"], SEAM_SIDE)       # cistern box
    fcyl(kv, 6, 5, F + 4, F + 18, 2.2, W["m"], SEAM_SIDE)    # pump barrel
    for z in (F + 6, F + 12, F + 17):
        fcyl(kv, 6, 5, z, z + 1, 2.5, W["iron"])
    fbox(kv, 5, 4, F + 18, 7, 6, F + 21, W["iron"])          # pivot post
    fbox(kv, 3, 4, F + 20, 16, 6, F + 21, W["l"])            # brake (handle)
    fbox(kv, 14, 3, F + 15, 15, 7, F + 21, W["d"])
    fbox(kv, 8, 5, F + 9, 13, 7, F + 10, W["iron_l"])        # spout
    fbox(kv, 12, 5, F + 8, 13, 7, F + 9, W["iron_l"])
    fring(kv, 12.5, 12, F, F + 5, 1.3, 2.8, W["m"], SEAM_SIDE)
    fcyl(kv, 12.5, 12, F + 3, F + 4, 1.4, P["water_d"])
    fbox(kv, 3, 10, F, 9, 15, F + 1, P["water"], GLOSS | NOSHADOW)


# -- structure: partial walls, stanchions and the mess --------------------------

def _plank_run(kv, x0, x1, y0, y1, top):
    """Plank bulkhead running along y (thin in x), cut at the interior clip."""
    for y in range(y0, y1, 4):
        col = mul(W["m"], 0.93 + 0.09 * ((y // 4) % 2))
        fbox(kv, x0, y, F, x1, min(y1, y + 4), top, col, SEAM_SIDE)
    fbox(kv, x0 - 1, y0, F, x1 + 1, y1, F + 2, W["dd"])               # sole plate
    fbox(kv, x1, y0, F + 9, x1 + 1, y1, F + 10, W["d"])                # chair rail


def i_partition(kv, c):
    """Plank partition section (a frame stud at its far end), with a peg
    holding an oilskin and a ditty bag."""
    _plank_run(kv, 7, 9, 0, 16, F + 22)
    fbox(kv, 6, 0, F, 10, 2, F + 22, W["dd"], SEAM_SIDE)              # stud
    fbox(kv, 9, 9, F + 15, 11, 10, F + 16, W["iron"])                   # peg
    fbox(kv, 9, 7, F + 8, 11, 12, F + 15, P["yellow"], SEAM_SIDE)       # oilskin
    fbox(kv, 9, 7, F + 13, 11, 12, F + 15, mul(P["yellow"], 0.85))
    sack(kv, 10, 2, F, 4, 4, 5, W["canvas_d"])


def i_partition_end(kv, c):
    """End of a partition: heavy door post, the door hooked open against the
    planking, and a lantern on a bracket lighting the doorway."""
    _plank_run(kv, 7, 9, 0, 12, F + 22)
    fbox(kv, 6, 0, F, 10, 2, F + 22, W["dd"], SEAM_SIDE)              # stud
    fbox(kv, 6, 12, F, 10, 16, F + 22, W["dd"], SEAM_SIDE)            # door post
    fbox(kv, 5, 11, F + 19, 11, 16, F + 21, W["d"])                     # head block
    # door leaf, hooked open flat along the planking (+x face)
    for y in range(3, 12, 3):                                           # leaf boards
        fbox(kv, 9, y, F, 11, min(12, y + 3), F + 17, mul(W["l"], 0.9 + 0.06 * (y % 2)), SEAM_SIDE)
    fbox(kv, 10, 3, F + 16, 11, 12, F + 17, W["d"])                     # top rail
    for z in (F + 3, F + 13):                                           # strap hinges
        fbox(kv, 10, 5, z, 11, 12, z + 1, W["iron"])
    fbox(kv, 10, 4, F + 8, 12, 5, F + 9, W["iron_l"])                   # latch
    fbox(kv, 11, 3, F + 10, 12, 4, F + 11, W["iron"])                   # hook
    # lantern on a bracket off the post
    fbox(kv, 10, 13, F + 17, 13, 14, F + 18, W["iron"])
    fbox(kv, 12, 13, F + 14, 13, 14, F + 17, W["iron"])
    c.light(lantern(kv, 12.5, 13.5, F + 7))


def i_pillar(kv, c):
    """Deck stanchion with belaying pins, a coil of line and a fire bucket."""
    fbox(kv, 6, 6, F, 10, 10, F + 22, W["d"], SEAM_SIDE)
    fbox(kv, 5, 5, F, 11, 11, F + 2, W["dd"])                           # step
    fbox(kv, 5, 5, F + 20, 11, 11, F + 22, W["dd"])                     # head
    fbox(kv, 10, 5, F + 12, 12, 11, F + 13, W["dd"])                    # pin rail
    for py in (6, 9):
        fbox(kv, 11, py, F + 11, 12, py + 1, F + 15, W["l"])
    fring(kv, 11.5, 8, F + 6, F + 12, 0.8, 2.0, W["rope"])              # coil on a pin
    fbox(kv, 8, 10, F + 16, 9, 12, F + 17, W["iron"])                   # bucket hook
    fring(kv, 8.5, 12.5, F + 10, F + 15, 1.0, 2.2, P["red_d"], SEAM_SIDE)
    fcyl(kv, 8.5, 12.5, F + 10, F + 11, 1.6, mul(P["red_d"], 0.8))
    fbox(kv, 2, 11, F, 5, 14, F + 1, mix(W["floor"], W["tar"], 0.3), NOSHADOW)


def i_mess_table(kv, c):
    """Mess table with benches, a mess kid, plates and tankards, under a
    lantern hung from the beams."""
    for (bx0, bx1) in ((2, 4), (12, 14)):                               # trestles
        fbox(kv, bx0, 6, F, bx1, 10, F + 7, W["d"], SEAM_SIDE)
    fbox(kv, 1, 5, F + 7, 15, 11, F + 8, W["l"], GLOSS)                 # top
    for (y0, y1) in ((1, 3), (13, 15)):                                 # benches
        fbox(kv, 2, y0, F + 4, 14, y1, F + 5, W["m"], GLOSS)
        for lx in (3, 12):
            fbox(kv, lx, y0, F, lx + 1, y1, F + 4, W["d"])
    fring(kv, 8, 8, F + 8, F + 11, 1.2, 2.4, W["m"], SEAM_SIDE)         # mess kid
    fcyl(kv, 8, 8, F + 10, F + 11, 1.3, P["orange"])
    for (px, py) in ((3.5, 6.8), (12.5, 9.2)):                          # plates
        fcyl(kv, px, py, F + 8, F + 9, 1.4, P["cream"])
    for (tx, ty) in ((5, 9.5), (11, 6.5)):                              # tankards
        fcyl(kv, tx, ty, F + 8, F + 11, 0.9, W["iron_l"], GLOSS)
    fbox(kv, 9, 9, F + 8, 11, 10, F + 9, P["wood_l"])                   # bread
    fbox(kv, 7, 7, F + 19, 9, 9, F + 22, W["iron"])                     # hook on the beam
    c.light(lantern(kv, 8, 8, F + 13))


ITEMS = {
    # name: (builder, themes, placement class, chore)
    # placement: "gun" (gun deck ports only), "wall" (against a wall),
    #            "low" (anywhere, never hides the walkway), "bay" (cargo bays)
    "gun": (i_gun, ("lower",), "gun", True),
    "powder": (i_powder, ("lower",), "low", True),
    "shot_rack": (i_shot_rack, ("lower",), "wall", False),
    "chests": (i_chests, ("lower", "orlop"), "low", False),
    "water_butt": (i_water_butt, ("lower", "orlop"), "wall", True),
    "hammock": (i_hammock, ("lower", "orlop"), "wall", False),
    "rope_coil": (i_rope_coil, ("lower", "orlop", "hold"), "low", True),
    "workbench": (i_workbench, ("lower", "orlop"), "wall", True),
    "lantern": (i_lantern, ("lower", "orlop", "hold"), "post", False),
    "cable": (i_cable, ("orlop",), "low", True),
    "sails": (i_sails, ("orlop", "hold"), "low", True),
    "lockers": (i_lockers, ("orlop",), "wall", True),
    "shelves": (i_shelves, ("orlop", "hold"), "wall", True),
    "crates": (i_crates, ("hold", "orlop"), "bay", True),
    "crates_tall": (i_crates_tall, ("hold",), "wall", False),
    "barrels": (i_barrels, ("hold", "orlop"), "bay", True),
    "sacks": (i_sacks, ("hold",), "bay", True),
    "cask": (i_cask, ("hold",), "bay", True),
    "net_cargo": (i_net_cargo, ("hold",), "bay", False),
    "ballast": (i_ballast, ("hold",), "low", False),
    "lumber": (i_lumber, ("hold", "orlop"), "low", True),
    "coop": (i_coop, ("hold",), "bay", True),
    "pump": (i_pump, ("hold",), "wall", True),
    "partition": (i_partition, ("orlop", "hold"), "frame", False),
    "partition_end": (i_partition_end, ("orlop", "hold"), "frame", False),
    "pillar": (i_pillar, ("lower", "orlop", "hold"), "post", False),
    "mess_table": (i_mess_table, ("lower",), "mid", True),
}


# -- rendering ----------------------------------------------------------------

def _anchor(origin, cx=0, cy=0):
    c = CELL // 2
    X, Y = CELL * cx + c, CELL * cy + c
    return origin[0] + 2 * (X - Y), origin[1] + X + Y - 2 * F


def _floor_slab(n=2):
    v = Vol(CELL * n, CELL * n, F + INTERIOR_CLIP + 2)
    v.box(0, 0, 0, CELL * n, CELL * n, 1, W["floor"])
    gx = np.arange(CELL * n) // CELL
    gy = np.arange(CELL * n) // CELL
    v.group[:, :, 0] = gy[None, :] * n + gx[:, None]
    return v


def shadow_slices(item: Vol):
    """Translucent cast shadow of an item on the floor, one slice per floor cell
    (own cell and the +x / +y / diagonal neighbours)."""
    n = 2
    base = _floor_slab(n)
    a = _floor_slab(n)
    X, Y, Z = item.shape
    a.solid[:X, :Y, 1:Z] |= item.solid[:, :, 1:Z]
    a.col[:X, :Y, 1:Z] = np.where(item.solid[:, :, 1:Z, None], item.col[:, :, 1:Z], a.col[:X, :Y, 1:Z])
    a.flag[:X, :Y, 1:Z] = np.where(item.solid[:, :, 1:Z], item.flag[:, :, 1:Z], a.flag[:X, :Y, 1:Z])
    a.group[:X, :Y, 1:Z] = np.where(item.solid[:, :, 1:Z], -1, a.group[:X, :Y, 1:Z])
    ra = render(a, shadow_len=60, outline=False)
    rb = render(base, shadow_len=60, outline=False)
    dx, dy = rb.origin[0] - ra.origin[0], rb.origin[1] - ra.origin[1]
    H, Wd = ra.group.shape
    alpha = np.zeros((H, Wd), np.float32)
    ys, xs = np.nonzero(ra.group >= 0)
    by, bx = ys + dy, xs + dx
    ok = (by >= 0) & (by < rb.rgba.shape[0]) & (bx >= 0) & (bx < rb.rgba.shape[1])
    ys, xs, by, bx = ys[ok], xs[ok], by[ok], bx[ok]
    la = ra.rgba[ys, xs, :3].astype(np.float32).mean(axis=1)
    lb = np.maximum(1.0, rb.rgba[by, bx, :3].astype(np.float32).mean(axis=1))
    alpha[ys, xs] = np.clip(1.0 - la / lb, 0.0, 0.62)
    alpha[alpha < 0.03] = 0.0
    out = []
    for g in range(n * n):
        m = (ra.group == g) & (alpha > 0)
        if not m.any():
            continue
        yy, xx = np.nonzero(m)
        y0, y1, x0, x1 = yy.min(), yy.max() + 1, xx.min(), xx.max() + 1
        crop = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        crop[..., 0], crop[..., 1], crop[..., 2] = SHADOW_RGB
        sub = np.where(m[y0:y1, x0:x1], alpha[y0:y1, x0:x1], 0.0)
        crop[..., 3] = np.round(sub * 255).astype(np.uint8)
        cx, cy = g % n, g // n
        ax, ay = _anchor(ra.origin, cx, cy)
        out.append(([cx, cy], crop, [int(x0 - ax), int(y0 - ay)]))
    return out


def build_item(name, rot):
    fn = ITEMS[name][0]
    kv = KVol(8, 8, KZ, clip_z=F + INTERIOR_CLIP)
    ctx = Ctx()
    fn(kv, ctx)
    v = kv.v
    lights = ctx.lights
    if rot == 1:
        v = v.mirror_xy()
        lights = [(p[1], p[0], p[2], p[3]) for p in lights]
    r = render(v, shadow_len=60)
    crop, (x0, y0) = trim(r.rgba)
    ax, ay = _anchor(r.origin)
    c = CELL // 2
    lt = [[round(2 * (p[0] - p[1]), 1), round((p[0] - c) + (p[1] - c) - 2 * (p[2] - F), 1), p[3]] for p in lights]
    return crop, [int(x0 - ax), int(y0 - ay)], shadow_slices(v), lt


def build_fence(edge):
    """Low cargo battens along the cell's +x ('px') or +y ('py') edge."""
    kv = KVol(8, 8, KZ)
    for i in range(0, 17, 5):
        p = min(i, 14)
        if edge == "px":
            fbox(kv, 14, p, F, 16, p + 2, F + 8, W["d"])
        else:
            fbox(kv, p, 14, F, p + 2, 16, F + 8, W["d"])
    for z in (F + 2, F + 6):
        if edge == "px":
            fbox(kv, 14, 0, z, 15, 16, z + 2, W["l"], SEAM_SIDE)
        else:
            fbox(kv, 0, 14, z, 16, 15, z + 2, W["l"], SEAM_SIDE)
    r = render(kv.v, shadow_len=60)
    crop, (x0, y0) = trim(r.rgba)
    ax, ay = _anchor(r.origin)
    return crop, [int(x0 - ax), int(y0 - ay)]


def _flat(paint):
    v = Vol(CELL, CELL, F + 2)
    paint(v)
    r = render(v, shadow=False, ao=False)
    crop, (x0, y0) = trim(r.rgba)
    ax, ay = _anchor(r.origin)
    return crop, [int(x0 - ax), int(y0 - ay)]


def runner(mask, kind):
    """Floor runner (canvas) or duckboard joining the cell centre to the
    connected sides. mask bits: 1 = +x, 2 = -x, 4 = +y, 8 = -y."""
    lo, hi = 4, 12
    U = np.zeros((CELL, CELL), bool)
    along_x = np.zeros((CELL, CELL), bool)
    U[lo:hi, lo:hi] = True
    if mask & 1:
        U[hi:, lo:hi] = True
        along_x[hi:, lo:hi] = True
    if mask & 2:
        U[:lo, lo:hi] = True
        along_x[:lo, lo:hi] = True
    if mask & 4:
        U[lo:hi, hi:] = True
    if mask & 8:
        U[lo:hi, :lo] = True
    if not (mask & 12) and (mask & 3):
        along_x[lo:hi, lo:hi] = True
    edge = np.zeros_like(U)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.zeros_like(U)
        xs = slice(max(0, dx), CELL + min(0, dx))
        xd = slice(max(0, -dx), CELL + min(0, -dx))
        ys = slice(max(0, dy), CELL + min(0, dy))
        yd = slice(max(0, -dy), CELL + min(0, -dy))
        inside = np.zeros_like(U)
        inside[xd, yd] = True
        nb[xd, yd] = U[xs, ys]
        edge |= U & inside & ~nb
    if kind == "runner":
        body, trim_c = hexrgb("#a6463a"), hexrgb("#d9b46a")
    else:
        body, trim_c = hexrgb("#8a6038"), hexrgb("#5e3c22")

    def paint(v):
        for x in range(CELL):
            for y in range(CELL):
                if not U[x, y]:
                    continue
                if kind == "runner":
                    c = trim_c if edge[x, y] else mul(body, 1.0 + 0.05 * ((x + y) % 2))
                    v.put(x, y, F, c)
                else:
                    slat = (x if along_x[x, y] else y) % 3 != 2
                    if slat:
                        v.put(x, y, F, body, SEAM_SIDE)
                    elif edge[x, y] or (y in (lo + 1, hi - 2) if along_x[x, y] else x in (lo + 1, hi - 2)):
                        v.put(x, y, F, trim_c)
    return _flat(paint)


def patch(kind):
    rng = np.random.default_rng({"straw": 3, "stain": 5, "scuff": 9, "sand": 11, "boards": 13, "grate": 17}[kind])

    def paint(v):
        if kind == "boards":
            # two replacement boards, paler than the old deck
            for (y0, n) in ((3 + int(rng.integers(0, 3)), 0), (9 + int(rng.integers(0, 3)), 1)):
                x0 = int(rng.integers(0, 4))
                col = mix(W["floor"], P["wood_l"], 0.55 + 0.1 * n)
                v.box(x0, y0, F, min(CELL, x0 + 11), y0 + 2, F + 1, col, SEAM_SIDE)
                v.box(x0 + 1, y0, F, x0 + 2, y0 + 1, F + 1, W["iron"])
                v.box(x0 + 9, y0 + 1, F, x0 + 10, y0 + 2, F + 1, W["iron"])
            return
        if kind == "stain":
            # soft irregular tar or bilge stain with a darker core
            cx, cy = 8 + rng.uniform(-1.5, 1.5), 8 + rng.uniform(-1.5, 1.5)
            rx, ry = rng.uniform(4.0, 6.0), rng.uniform(3.0, 4.5)
            ph = rng.uniform(0, 6.28)
            for x in range(CELL):
                for y in range(CELL):
                    a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                    d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                    d *= 1.0 + 0.22 * math.sin(3 * a + ph) + 0.12 * math.sin(5 * a + 2 * ph)
                    if d < 1.0:
                        v.put(x, y, F, mix(W["tar"], W["floor"], 0.58 if d < 0.35 else 0.72), NOSHADOW)
            return
        if kind == "grate":
            # small scuttle grating, set flush in the deck
            for x in range(4, 12):
                for y in range(4, 12):
                    edge = x in (4, 11) or y in (4, 11)
                    hole = not edge and (x % 2 == 1) and (y % 2 == 1)
                    v.put(x, y, F, mix(W["tar"], W["floor"], 0.2) if hole else (W["dd"] if edge else W["d"]))
            return
        for _ in range(22 if kind != "scuff" else 12):
            x, y = int(rng.integers(2, 14)), int(rng.integers(2, 14))
            if (x - 8) ** 2 + (y - 8) ** 2 > 38:
                continue
            if kind == "straw":
                ln = int(rng.integers(2, 5))
                c = mix(P["straw"] if rng.random() < 0.6 else P["straw_d"], W["floor"], 0.45)
                if rng.random() < 0.5:
                    v.box(x, y, F, min(CELL, x + ln), y + 1, F + 1, c)
                else:
                    v.box(x, y, F, x + 1, min(CELL, y + ln), F + 1, c)
            elif kind == "stain":
                v.box(x, y, F, min(CELL, x + 3), min(CELL, y + 2), F + 1, mix(W["tar"], W["floor"], 0.62), NOSHADOW)
            elif kind == "sand":
                v.box(x, y, F, min(CELL, x + 2), min(CELL, y + 2), F + 1, mix(P["sand"], W["floor"], 0.45))
            else:
                v.box(x, y, F, min(CELL, x + 4), y + 1, F + 1, mix(W["floor"], P["cream"], 0.18))
    return _flat(paint)


def main():
    pk = Packer(width=2048)
    table = {"items": {}, "fence": {}, "runner": {}, "duck": {}, "patch": {}}
    previews = []
    for name, (fn, themes, place, chore) in ITEMS.items():
        e = {"themes": list(themes), "place": place, "chore": chore, "rot": {}}
        for rot in (0, 1):
            crop, off, shadows, lights = build_item(name, rot)
            key = f"item:{name}:{rot}"
            pk.add(key, crop, off=off)
            sh = []
            for i, (cell, scrop, soff) in enumerate(shadows):
                skey = f"shadow:{name}:{rot}:{i}"
                pk.add(skey, scrop, off=soff)
                sh.append({"key": skey, "cell": cell})
            e["rot"][str(rot)] = {"key": key, "shadow": sh, "lights": lights}
            if rot == 0:
                previews.append((name, crop, off, shadows))
        table["items"][name] = e
    for edge in ("px", "py"):
        crop, off = build_fence(edge)
        pk.add(f"fence:{edge}", crop, off=off)
        table["fence"][edge] = {"key": f"fence:{edge}"}
    for kind in ("runner", "duck"):
        for mask in range(16):
            crop, off = runner(mask, kind)
            pk.add(f"{kind}:{mask}", crop, off=off)
            table[kind][str(mask)] = {"key": f"{kind}:{mask}"}
    for kind in ("straw", "stain", "scuff", "sand", "boards", "grate"):
        crop, off = patch(kind)
        pk.add(f"patch:{kind}", crop, off=off)
        table["patch"][kind] = {"key": f"patch:{kind}"}
    rects, size = pk.pack(OUT / "ship" / "dressing.png")

    def fill(d):
        if isinstance(d, dict):
            if "key" in d and isinstance(d["key"], str) and d["key"] in rects:
                r = rects[d["key"]]
                d["rect"] = r["rect"]
                d["off"] = r["off"]
            for v in d.values():
                fill(v)
        elif isinstance(d, list):
            for v in d:
                fill(v)
    fill(table)
    save_json(table, OUT / "ship" / "dressing.json")
    record((OUT / "ship" / "dressing.png").relative_to(GAME.parent), f"{size[0]}x{size[1]} atlas",
           f"{len(ITEMS)} items x 2 rotations + shadows, 2 fences, 32 runner/duckboard masks, 6 floor patches",
           "voxel models (lib/vox.py) at ship scale; shadows derived from a floor-slab render",
           "Interior dressing placed around the routes by scripts/view/ship_dress.gd")
    # preview sheet: each item on a floor diamond with its shadow
    from PIL import Image
    cols = 6
    cw, ch = 96, 112
    rows = (len(previews) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (40, 30, 26, 255))
    floor = np.zeros((33, 64, 4), np.uint8)
    for yy in range(33):
        half = 32 - abs(16 - yy) * 2
        floor[yy, 32 - half:32 + half] = (*W["floor"], 255)
    fimg = Image.fromarray(floor)
    for i, (name, crop, off, shadows) in enumerate(previews):
        ox, oy = (i % cols) * cw + 48, (i // cols) * ch + 84
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            px, py = ox + 32 * (dx - dy), oy + 16 * (dx + dy)
            sheet.alpha_composite(fimg, (px - 32, py - 16))
        for cell, scrop, soff in shadows:
            px, py = ox + 32 * (cell[0] - cell[1]), oy + 16 * (cell[0] + cell[1])
            sheet.alpha_composite(Image.fromarray(scrop), (px + soff[0], py + soff[1]))
        sheet.alpha_composite(Image.fromarray(crop), (ox + off[0], oy + off[1]))
    save_png(sheet, PREVIEW / "dressing.png")
    print("dressing", len(ITEMS), size)


if __name__ == "__main__":
    main()
