"""Ship generator: stacked multi-level hulls shown as cutaway views.

Each hull tier from content.json is built as one voxel model at ship scale
(16 voxels per cell, 24 voxels per level): an exposed weather deck with
raised open castles, and two or three covered interior levels inside the
hull. The model is rendered once per *view level*:

  view 0   the open decks: hull exterior, rails, fittings, castles
  view k   interior level k (highest first): everything above its ceiling
           is cut away, the near hull wall is cut down to a sill, and the far
           walls show panelling, ribs, portholes and lanterns

Every render is sliced into per-cell pieces so the game can depth-sort them
with crew and facilities. The rig (furled or set) is rendered separately
for view 0. Dynamic structures (terrace stairs and railings, hatch ladders,
hatches, bulkhead walls and doors) are generic overlay parts.

Outputs (game/assets/gen/ship/):
  hull_<id>.png / hull_<id>.json   view pieces, rig pieces, lights, ropes, foam
  parts.png / parts.json           stairs, ladders, hatches, rails, bulkheads
"""
from __future__ import annotations

import json
import math

import numpy as np

from lib.common import (CELL_VOX, GAME, LEVEL_PX, LEVEL_VOX, OUT, PREVIEW, Packer, record, save_json, save_png,
                        upscale_preview)
from lib.vox import (EMIT, GLOSS, NOOUTLINE, NOSHADOW, SEAM, SEAM_L, SEAM_R, SEAM_SIDE, Vol, hexrgb, mix, mul,
                     render, slice_groups)

C = json.loads((GAME / "data" / "content.json").read_text())
HULLS = C["HULLS"] if isinstance(C["HULLS"], list) else list(C["HULLS"].values())

CV = CELL_VOX                    # voxels per cell
LV = LEVEL_VOX                   # voxels per level
MXS, MXB, MY = 1, 5, 1           # margin cells: stern, bow (bowsprit), each side
HT = 3                           # hull wall thickness
RAIL = 9                         # bulwark height above an open deck
SILL = 3                         # near-wall height left by the cutaway
CEIL = LV - 2                    # clear height of an interior level (floor slab is 2)
BOW_LEN = 46

WOOD = {
    "deck": hexrgb("#d8aa70"), "deck_dark": hexrgb("#b58a56"),
    "hull": hexrgb("#8f5531"), "hull_dark": hexrgb("#6b3b22"), "bottom": hexrgb("#7c3f30"),
    "bottom_dark": hexrgb("#5e2e25"), "boot": hexrgb("#e8dcc0"), "wale": hexrgb("#4f2f1d"),
    "rail": hexrgb("#c3864a"), "cap": hexrgb("#e9b46a"), "post": hexrgb("#a96a38"),
    "cabin": hexrgb("#c07b42"), "cabin_dark": hexrgb("#8f5531"), "door": hexrgb("#6a3a22"),
    "mast": hexrgb("#b9844d"), "iron": hexrgb("#4f5560"), "gold": hexrgb("#f0c04e"),
    "glass": hexrgb("#ffd98a"), "sky": hexrgb("#a9dcf2"), "sail": hexrgb("#f3ead4"), "sail_shade": hexrgb("#d9cdb0"),
    "rope": hexrgb("#7a5634"), "lamp": hexrgb("#ffe39a"),
    "floor": hexrgb("#c39b68"), "floor_dark": hexrgb("#a17b50"), "panel": hexrgb("#c69864"),
    "panel_dark": hexrgb("#7f5232"), "rib": hexrgb("#5d3920"), "section": hexrgb("#3d2618"),
    "trim": hexrgb("#d9a560"),
}
BAND = {"starter": hexrgb("#2f6f8a"), "voyager": hexrgb("#2d7f86"), "adventurer": hexrgb("#2a4c8c"),
        "legend": hexrgb("#8c2b3c")}
PENNANT = {"starter": hexrgb("#d84a3a"), "voyager": hexrgb("#2fae9a"), "adventurer": hexrgb("#3a6fd8"),
           "legend": hexrgb("#f0c04e")}


def cell_gid(gx, gy):
    return (gx + 64) * 256 + (gy + 64)


def gid_cell(g):
    return g // 256 - 64, g % 256 - 64


def h32(*vals):
    h = 2166136261
    for v in vals:
        h ^= int(v) & 0xFFFFFFFF
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def hash_arr(a, b, seed=0):
    """Vectorised integer hash in [0, 1)."""
    a = np.asarray(a, np.int64)
    b = np.asarray(b, np.int64)
    h = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0


def shifted(a, d, axis):
    """out[i] = a[i + d] along axis, False beyond the edge."""
    out = np.zeros_like(a)
    n = a.shape[axis]
    if abs(d) >= n:
        return out
    src = [slice(None)] * a.ndim
    dst = [slice(None)] * a.ndim
    if d >= 0:
        src[axis] = slice(d, n)
        dst[axis] = slice(0, n - d)
    else:
        src[axis] = slice(0, n + d)
        dst[axis] = slice(-d, n)
    out[tuple(dst)] = a[tuple(src)]
    return out


def clone(v: Vol) -> Vol:
    o = Vol(1, 1, 1)
    o.shape = v.shape
    o.solid = v.solid.copy()
    o.col = v.col.copy()
    o.flag = v.flag.copy()
    o.group = v.group.copy()
    return o


class ShipModel:
    def __init__(self, hull):
        self.hull = hull
        self.id = hull["id"]
        self.tier = int(hull["tier"])
        self.decks = hull["decks"]
        self.beam = int(hull["beam"])
        self.open = [d for d in self.decks if d.get("kind", "open") == "open"]
        self.interior = sorted([d for d in self.decks if d.get("kind") == "interior"], key=lambda d: -int(d["elev"]))
        self.total = max(int(d["x0"]) + int(d["w"]) for d in self.decks)
        self.n_int = max([-int(d["elev"]) for d in self.interior] + [0])
        self.max_elev = max(int(d["elev"]) for d in self.open)
        self.ZB = 8 + LV * self.n_int          # weather deck surface
        self.WL = self.ZB - LV - 10             # waterline
        self.floor_bottom = self.ZB - LV * self.n_int - 2
        self.X = CV * (self.total + MXS + MXB)
        self.Y = CV * (self.beam + 2 * MY)
        self.Z = self.ZB + LV * self.max_elev + 30
        self.yc = CV * MY + self.beam * CV / 2
        self.by0, self.by1 = self.vy0(0), self.vy0(self.beam)
        self.stern_x = self.vx0(0) - HT
        self.bow0 = self.vx0(self.total)
        self.lights = []
        self.ropes = []
        self.mast_tops = []
        self.bowsprit = None
        self._surf = [self._surf_g(vx // CV - MXS) for vx in range(self.X + CV)]

    # coordinates ---------------------------------------------------------
    def vx0(self, gx):
        return CV * (gx + MXS)

    def vy0(self, gy):
        return CV * (gy + MY)

    def zs(self, d):
        """Floor surface (top of the planks) of a deck."""
        return self.ZB + LV * int(d["elev"])

    def open_at(self, gx):
        best = None
        for d in self.open:
            if int(d["x0"]) <= gx < int(d["x0"]) + int(d["w"]):
                if best is None or int(d["elev"]) > int(best["elev"]):
                    best = d
        return best

    def _surf_g(self, gx):
        gx = max(0, min(self.total - 1, gx))
        d = self.open_at(gx)
        if d is None:
            # under a gap between open decks: use the nearest one
            best = min(self.open, key=lambda o: min(abs(gx - int(o["x0"])), abs(gx - int(o["x0"]) - int(o["w"]) + 1)))
            d = best
        return self.ZB + LV * int(d["elev"])

    def surf(self, vx):
        return self._surf[max(0, min(len(self._surf) - 1, vx))]

    def world(self, vx, vy, vz):
        """Godot world position of a voxel point: cell (0,0) centre on the weather deck is (0,0)."""
        ox = CV * MXS + CV / 2
        oy = CV * MY + CV / 2
        return [round(2 * ((vx - ox) - (vy - oy)), 1), round((vx - ox) + (vy - oy) - 2 * (vz - self.ZB), 1)]

    def half_w(self, vx, vz):
        """Half-width of the hull at column vx and height vz (None outside)."""
        full = self.beam * CV / 2 + HT
        if vx < self.stern_x:
            return None
        k = 1.0
        zf = self.floor_bottom
        if vz < zf:
            t = (zf - vz) / max(1, zf)
            k = 1 - 0.5 * t ** 1.6
            # the stern bottom rises in a short rocker
            if vx < self.stern_x + 22 and vz < (self.stern_x + 22 - vx) * 0.45:
                return None
        if vx >= self.bow0:
            top = self.surf(vx)
            frac = max(0.0, min(1.0, (vz - self.WL + 14) / max(1, top - self.WL + 14)))
            L = BOW_LEN * (0.42 + 0.58 * frac)
            t = (vx - self.bow0 + 0.5) / L
            if t >= 1:
                return None
            k *= 1 - t * t
        h = full * k
        return h if h >= 1.5 else None


# ---------------------------------------------------------------- hull body
def plank_cols(xs, ys, base, dark, seed=0, width=4, seg=29):
    """Board-sized colour clusters; the deck stays quiet behind small crew."""
    pj = ys // width
    sg = (xs + 7 * pj) // seg
    k = hash_arr(pj, sg, seed)
    b = np.array(base, np.float32)
    d = np.array(dark, np.float32)
    c = b + (d - b) * (0.12 + 0.16 * k)[..., None]
    joint = ((xs + 7 * pj) % seg) == 0
    c = np.where(joint[..., None], c * 0.94, c)
    return c


def build_body(m: ShipModel):
    X, Y, Z = m.X, m.Y, m.Z
    v = Vol(X, Y, Z)
    E = np.zeros((X, Y, Z), bool)
    for vx in range(X):
        top = m.surf(vx)
        for vz in range(top):
            h = m.half_w(vx, vz)
            if h is None:
                continue
            y0 = int(round(m.yc - h))
            y1 = int(round(m.yc + h))
            E[vx, y0:y1, vz] = True
    core = E.copy()
    for d in (HT, -HT):
        core &= shifted(E, d, 1)
        core &= shifted(E, d, 0)
    shell = E & ~core
    # outer hull colours by height
    zz = np.arange(Z)
    xx = np.arange(X)
    strake = zz // 4
    k = hash_arr(xx[:, None] // 23, strake[None, :], 3)
    hb = np.array(WOOD["hull"], np.float32)
    hd = np.array(WOOD["hull_dark"], np.float32)
    col_xz = hb + (hd - hb) * (0.14 + 0.19 * k)[..., None]
    bot = np.array(WOOD["bottom"], np.float32) + (np.array(WOOD["bottom_dark"], np.float32) - np.array(WOOD["bottom"], np.float32)) * (0.2 + 0.5 * k)[..., None]
    col_xz = np.where((zz < m.WL)[None, :, None], bot, col_xz)
    col_xz[:, m.WL] = WOOD["boot"]
    band = BAND.get(m.id)
    for zb in range(m.ZB - 7, m.ZB - 3):
        col_xz[:, zb] = WOOD["wale"]
    if band is not None:
        col_xz[:, m.ZB - 3] = WOOD["gold"]
        col_xz[:, m.ZB - 6:m.ZB - 3] = band
    # a darker wale marks each interior deck line on the outside
    for d in m.interior:
        z = m.zs(d) - 2
        if z > m.WL + 1:
            col_xz[:, z - 1:z + 1] = WOOD["wale"]
    v.solid[...] = E
    v.col[...] = np.clip(col_xz, 0, 255).astype(np.uint8)[:, None, :, :]
    fl = np.where((zz % 4 == 0), SEAM_SIDE, 0).astype(np.uint16)
    v.flag[...] = fl[None, None, :]
    sec = np.array(WOOD["section"], np.uint8)
    v.col[core] = sec
    v.flag[core] = 0
    return v, E, shell


def carve_levels(m: ShipModel, v: Vol):
    """Interior level boxes, floors, panelled far walls, ribs, portholes, lamps."""
    by0, by1 = m.by0, m.by1
    for vi, d in enumerate(m.interior, start=1):
        x0, w = int(d["x0"]), int(d["w"])
        bx0, bx1 = m.vx0(x0), m.vx0(x0 + w)
        zs = m.zs(d)
        v.solid[bx0:bx1, by0:by1, zs:zs + CEIL] = False
        # recess between ribs on the far wall and on the stern end wall
        v.solid[bx0:bx1, by0 - 1, zs:zs + CEIL] = False
        stern_wall = bx0 - 1 >= m.stern_x + 2
        if stern_wall:
            v.solid[bx0 - 1, by0:by1, zs:zs + CEIL] = False
        # floor planks (run along the ship)
        xs, ys = np.meshgrid(np.arange(bx0, bx1), np.arange(by0, by1), indexing="ij")
        c = plank_cols(xs, ys - by0, WOOD["floor"], WOOD["floor_dark"], seed=vi * 11)
        v.col[bx0:bx1, by0:by1, zs - 1] = np.clip(c, 0, 255).astype(np.uint8)
        v.flag[bx0:bx1, by0:by1, zs - 1] = np.where((ys - by0) % 4 == 3, SEAM, 0).astype(np.uint16)
        v.col[bx0:bx1, by0:by1, zs - 2] = WOOD["floor_dark"]
        v.solid[bx0:bx1, by0:by1, zs - 2:zs] = True

        # The floor has a visible edge and a quiet central gangway. These
        # flush inlays change no geometry and remain readable after refits.
        # Room-specific mats in ShipDress sit over this continuous base.
        edge = mix(WOOD["floor_dark"], BAND[m.id], 0.24)
        for yy in (by0 + 2, by1 - 3):
            v.col[bx0:bx1, yy:yy + 1, zs - 1] = edge
            v.flag[bx0:bx1, yy:yy + 1, zs - 1] = 0

        wet = zs + 7 <= m.WL + 1          # below the waterline: no portholes, rough planking

        def panel(z):
            rz = z - zs
            if wet:
                if rz >= CEIL - 2:
                    return WOOD["rib"], 0
                return (WOOD["panel_dark"] if (rz // 3) % 2 else mul(WOOD["panel_dark"], 1.12)), (SEAM_SIDE if rz % 3 == 2 else 0)
            if rz < 7:
                return WOOD["panel_dark"], SEAM_SIDE if rz == 0 else 0
            if rz == 7:
                return WOOD["trim"], 0
            if rz >= CEIL - 2:
                return WOOD["rib"], 0
            return WOOD["panel"], 0
        for z in range(zs, zs + CEIL):
            pc, pf = panel(z)
            v.col[bx0:bx1, by0 - 2, z] = pc
            v.flag[bx0:bx1, by0 - 2, z] = pf
            if stern_wall:
                v.col[bx0 - 2, by0:by1, z] = pc
                v.flag[bx0 - 2, by0:by1, z] = pf
        # vertical board joints in the wainscot
        if not wet:
            for x in range(bx0, bx1, 6):
                v.flag[x, by0 - 2, zs:zs + 7] |= SEAM_L
        # ribs at cell boundaries
        for g in range(x0, x0 + w + 1):
            x = min(bx1 - 1, m.vx0(g))
            v.box(x, by0 - 1, zs, x + 1, by0, zs + CEIL, WOOD["rib"], SEAM_SIDE)
            if wet:
                # hanging knee under the deck beam
                for k in range(4):
                    v.box(x, by0, zs + CEIL - 3 - k, x + 1, by0 + 4 - k, zs + CEIL - 2 - k, WOOD["rib"])
            else:
                v.put(x, by0 - 1, zs + 7, WOOD["trim"])
        if stern_wall:
            for gy in range(0, m.beam + 1):
                y = min(by1 - 1, m.vy0(gy))
                v.box(bx0 - 1, y, zs, bx0, y + 1, zs + CEIL, WOOD["rib"], SEAM_SIDE)
        # carlin beam along the top of the far wall
        v.box(bx0, by0 - 1, zs + CEIL - 2, bx1, by0, zs + CEIL, WOOD["rib"])
        # portholes on odd cells, lanterns on even cells (relative to the level start)
        for g in range(x0, x0 + w):
            cx = m.vx0(g) + 8
            if (g - x0) % 2 == 1 and not wet:
                zc = zs + 11
                for dx in range(-3, 4):
                    for dz in range(-3, 4):
                        r = math.hypot(dx, dz)
                        if r <= 3.3:
                            col = WOOD["gold"] if r > 2.2 else WOOD["sky"]
                            v.put(cx + dx, by0 - 2, zc + dz, col, EMIT if r <= 2.2 else GLOSS)
            elif (g - x0) % 2 == 0 and (g > x0 or not stern_wall):
                v.box(cx - 1, by0 - 1, zs + 17, cx + 1, by0, zs + 18, WOOD["iron"])
                v.box(cx - 1, by0 - 1, zs + 13, cx + 1, by0, zs + 17, WOOD["lamp"], EMIT | NOSHADOW)
                v.box(cx - 1, by0 - 1, zs + 12, cx + 1, by0, zs + 13, WOOD["iron"])
                m.lights.append({"pos": m.world(cx, by0 + 1, zs + 15), "kind": "lamp", "view": vi})
        if stern_wall:
            yc = int(m.yc)
            v.box(bx0 - 1, yc - 1, zs + 13, bx0, yc + 1, zs + 17, WOOD["lamp"], EMIT | NOSHADOW)
            v.box(bx0 - 1, yc - 1, zs + 17, bx0, yc + 1, zs + 18, WOOD["iron"])
            m.lights.append({"pos": m.world(bx0 + 1, yc, zs + 15), "kind": "lamp", "view": vi})
        # mast trunks and their fittings
        for f in d["fixed"]:
            gx = x0 + int(f[0])
            cx, cy = m.vx0(gx) + 8, m.vy0(int(f[1])) + 8
            v.cyl(cx, cy, zs, zs + CEIL, 3.6, WOOD["mast"], jitter=0.03, seed=gx * 3 + vi)
            for rz in (zs + 3, zs + 15):
                v.cyl(cx, cy, rz, rz + 1, 3.9, WOOD["iron"])
            # bitts: a low timber frame with belaying pins
            for (px, py) in ((-6, -6), (5, -6), (-6, 5), (5, 5)):
                v.box(cx + px, cy + py, zs, cx + px + 1, cy + py + 1, zs + 6, WOOD["post"])
            v.box(cx - 6, cy - 6, zs + 6, cx + 6, cy - 5, zs + 7, WOOD["cap"], GLOSS)
            v.box(cx - 6, cy + 5, zs + 6, cx + 6, cy + 6, zs + 7, WOOD["cap"], GLOSS)
            for a in (-3, 0, 3):
                v.put(cx + a, cy + 5, zs + 7, WOOD["iron"])
            v.cyl(cx - 4, cy + 3, zs, zs + 2, 2.3, WOOD["rope"])
            v.cyl(cx - 4, cy + 3, zs + 2, zs + 3, 1.2, WOOD["rope"])
            v.box(cx + 1, cy + 6, zs + 10, cx + 3, cy + 7, zs + 14, WOOD["lamp"], EMIT | NOSHADOW)
            v.box(cx + 1, cy + 6, zs + 14, cx + 3, cy + 7, zs + 15, WOOD["iron"])
            m.lights.append({"pos": m.world(cx + 2, cy + 7, zs + 12), "kind": "lamp", "view": vi})


def deck_tops(m: ShipModel, v: Vol, E):
    """Planks on the open decks and the gunwale waterway around them."""
    X = m.X
    for vx in range(X):
        top = m.surf(vx)
        col = E[vx, :, top - 1]
        if not col.any():
            continue
        ys = np.nonzero(col)[0]
        inner = ys[(ys >= m.by0) & (ys < m.by1)]
        if inner.size:
            c = plank_cols(np.full(inner.size, vx), inner - m.by0, WOOD["deck"], WOOD["deck_dark"], seed=h32(m.tier) % 97)
            v.col[vx, inner, top - 1] = np.clip(c, 0, 255).astype(np.uint8)
            v.flag[vx, inner, top - 1] = np.where((inner - m.by0) % 4 == 3, SEAM, 0).astype(np.uint16)
            v.col[vx, inner, top - 2] = WOOD["deck_dark"]
        outer = ys[(ys < m.by0) | (ys >= m.by1)]
        v.col[vx, outer, top - 1] = WOOD["cap"]
        v.flag[vx, outer, top - 1] = 0
        if vx >= m.bow0:
            # small bow deck between the converging bulwarks
            mid = ys[(ys >= ys.min() + 2) & (ys <= ys.max() - 2)]
            if mid.size:
                c = plank_cols(np.full(mid.size, vx), mid - m.by0 + 64, WOOD["deck"], WOOD["deck_dark"], seed=5)
                v.col[vx, mid, top - 1] = np.clip(c, 0, 255).astype(np.uint8)
    # risers where an open deck steps down toward the bow (+x face visible)
    for vx in range(m.stern_x, X - 1):
        S, Sn = m.surf(vx), m.surf(vx + 1)
        if Sn >= S or not E[vx, int(m.yc), Sn]:
            continue
        for vz in range(Sn, S):
            for vy in range(m.by0 - HT, m.by1 + HT):
                if not E[vx, vy, vz]:
                    continue
                c = WOOD["cabin"] if vz < S - 1 else WOOD["cap"]
                fl = SEAM_R if (vy - m.by0) % 4 == 0 and vz < S - 1 else 0
                if vz == Sn:
                    c = WOOD["cabin_dark"]
                v.put(vx, vy, vz, c, fl)


def add_rails(m: ShipModel, v: Vol):
    by0, by1 = m.by0, m.by1
    main = next(d for d in m.open if d["id"] == "main")
    gate = None
    if main.get("entry"):
        ex = int(main["x0"]) + int(main["entry"][0])
        gate = (m.vx0(ex) + 3, m.vx0(ex) + 13)
    for vx in range(m.stern_x, m.X):
        S = m.surf(vx)
        h = m.half_w(vx, S - 1)
        if h is None:
            continue
        y0 = int(round(m.yc - h))
        y1 = int(round(m.yc + h))
        bow = vx >= m.bow0
        in_gate = gate is not None and gate[0] <= vx < gate[1]
        if bow:
            hn = m.half_w(vx + 1, S - 1)
            if hn is None:
                v.box(vx, y0, S, vx + 1, y1, S + RAIL + 1, WOOD["rail"])
                continue
            n0, n1 = int(round(m.yc - hn)), int(round(m.yc + hn))
            for vy in range(y0, max(y0 + 2, n0 + 2)):
                v.box(vx, vy, S, vx + 1, vy + 1, S + RAIL, WOOD["rail"], SEAM_L if vx % 5 == 0 else 0)
                v.put(vx, vy, S + RAIL, WOOD["cap"], GLOSS)
            for vy in range(min(y1 - 2, n1 - 2), y1):
                if vx % 3 == 0:
                    v.box(vx, vy, S, vx + 1, vy + 1, S + RAIL, WOOD["post"])
                v.put(vx, vy, S + RAIL, WOOD["cap"], GLOSS)
            continue
        # far bulwark: solid boards with stanchions on the inner face
        if not in_gate:
            v.box(vx, y0, S, vx + 1, y0 + 2, S + RAIL, WOOD["rail"], SEAM_L if vx % 6 == 0 else 0)
            v.box(vx, y0, S + RAIL, vx + 1, y0 + 3, S + RAIL + 1, WOOD["cap"], GLOSS)
            if vx % 8 == 0:
                v.box(vx, y0 + 2, S, vx + 1, y0 + 3, S + RAIL, WOOD["post"])
            v.box(vx, y0 + 2, S, vx + 1, y0 + 3, S + 1, WOOD["cabin_dark"])
        # near balustrade: open posts so crew stay visible
        v.box(vx, y1 - 2, S + RAIL, vx + 1, y1, S + RAIL + 1, WOOD["cap"], GLOSS)
        v.box(vx, y1 - 2, S, vx + 1, y1, S + 1, WOOD["rail"])
        v.box(vx, y1 - 1, S + 4, vx + 1, y1, S + 5, WOOD["rail"])
        if vx % 3 == 0:
            v.box(vx, y1 - 1, S + 1, vx + 1, y1, S + RAIL, WOOD["post"])
        if vx % 16 == 0:
            v.box(vx, y1 - 2, S, vx + 2, y1, S + RAIL + 3, WOOD["post"])
            v.box(vx, y1 - 2, S + RAIL + 3, vx + 2, y1, S + RAIL + 4, WOOD["cap"])
        # lanterns on brackets over the far bulwark
        if vx % 48 == 30 and not in_gate and m.surf(vx + 4) == S and m.surf(vx - 4) == S:
            v.box(vx, y0, S + RAIL + 1, vx + 1, y0 + 1, S + RAIL + 8, WOOD["iron"])
            v.box(vx, y0 + 1, S + RAIL + 7, vx + 1, y0 + 3, S + RAIL + 8, WOOD["iron"])
            v.box(vx - 1, y0 + 2, S + RAIL + 2, vx + 2, y0 + 4, S + RAIL + 6, WOOD["lamp"], EMIT | NOSHADOW)
            v.box(vx - 1, y0 + 2, S + RAIL + 6, vx + 2, y0 + 4, S + RAIL + 7, WOOD["iron"])
            m.lights.append({"pos": m.world(vx, y0 + 3, S + RAIL + 4), "kind": "lantern", "view": 0})
        # step posts where the deck level changes
        Sn = m.surf(vx + 1)
        if Sn != S and vx + 1 < m.bow0:
            hi = max(S, Sn)
            v.box(vx, y0, min(S, Sn), vx + 2, y0 + 3, hi + RAIL + 3, WOOD["post"])
            v.box(vx, y1 - 3, min(S, Sn), vx + 2, y1, hi + RAIL + 3, WOOD["post"])
            v.box(vx, y0, hi + RAIL + 3, vx + 2, y0 + 3, hi + RAIL + 4, WOOD["gold"])
            v.box(vx, y1 - 3, hi + RAIL + 3, vx + 2, y1, hi + RAIL + 4, WOOD["gold"])
    # stern transom bulwark and lanterns
    sx = m.stern_x
    S = m.surf(sx)
    v.box(sx, m.by0 - HT, S, sx + 2, m.by1 + HT, S + RAIL, WOOD["rail"])
    v.box(sx, m.by0 - HT, S + RAIL, sx + 3, m.by1 + HT, S + RAIL + 1, WOOD["cap"], GLOSS)
    for vy in (m.by0 + 1, m.by1 - 3):
        v.box(sx, vy, S + RAIL, sx + 2, vy + 2, S + RAIL + 9, WOOD["iron"])
        v.box(sx - 1, vy - 1, S + RAIL + 9, sx + 3, vy + 3, S + RAIL + 14, WOOD["lamp"], EMIT | NOSHADOW)
        v.box(sx - 1, vy - 1, S + RAIL + 14, sx + 3, vy + 3, S + RAIL + 15, WOOD["iron"])
        v.put(sx + 1, vy + 1, S + RAIL + 16, WOOD["gold"])
        m.lights.append({"pos": m.world(sx + 1, vy + 1, S + RAIL + 11), "kind": "lantern", "view": 0})
    # entry gate posts with a lamp
    if gate:
        S = m.surf(gate[0])
        for vx in (gate[0] - 2, gate[1]):
            v.box(vx, m.by0 - HT, S, vx + 2, m.by0, S + RAIL + 6, WOOD["post"])
            v.box(vx, m.by0 - HT, S + RAIL + 6, vx + 2, m.by0, S + RAIL + 7, WOOD["gold"], GLOSS)
        v.box(gate[0], m.by0 - HT, S, gate[1], m.by0, S + 1, WOOD["gold"])
        m.lights.append({"pos": m.world(gate[0] - 1, m.by0 - 1, S + RAIL + 7), "kind": "gate", "view": 0})


def add_hull_details(m: ShipModel, v: Vol):
    """Gunports, deck windows, castle doors, anchor, lifebuoys, bowsprit."""
    by0, by1 = m.by0, m.by1
    yo = by1 + HT - 1                    # near outer face
    main = next(d for d in m.open if d["id"] == "main")
    # An enamel crest on the near stern gives every hull a recognisable
    # identity even with its sails furled. It sits on the outer shell and
    # cannot intrude into walkable deck or interior space.
    cx = m.vx0(0) + 8
    zc = m.surf(cx) - 12
    for dx in range(-6, 7):
        for dz in range(-7, 7):
            shield = abs(dx) <= 5 and -5 <= dz <= 5 and abs(dx) <= 6 + min(dz, 0)
            if shield:
                rim = abs(dx) >= 4 or dz == 5 or abs(dx) == 6 + min(dz, 0)
                v.put(cx + dx, yo + 1, zc + dz, WOOD["gold"] if rim else BAND[m.id], GLOSS if rim else 0)
    if m.id == "starter":
        for i in range(-3, 4):
            v.put(cx + i, yo + 2, zc - 1 + (1 if i % 3 == 0 else 0), WOOD["boot"])
        v.box(cx, yo + 2, zc, cx + 1, yo + 3, zc + 4, WOOD["gold"])
    elif m.id == "voyager":
        for i in range(-3, 4):
            v.put(cx + i, yo + 2, zc + i, WOOD["boot"])
            v.put(cx + i, yo + 2, zc - i, WOOD["boot"])
    elif m.id == "adventurer":
        for i in range(-3, 4):
            v.put(cx + i, yo + 2, zc + 1 - abs(i), WOOD["boot"])
            v.put(cx + i, yo + 2, zc + 2 - abs(i), WOOD["boot"])
    else:
        v.box(cx - 3, yo + 2, zc - 1, cx + 4, yo + 3, zc + 2, WOOD["gold"])
        for i in (-3, 0, 3):
            v.box(cx + i, yo + 2, zc + 1, cx + i + 1, yo + 3, zc + 4, WOOD["gold"])
    # gunports or portholes on the near side, one row per interior level above water
    for li, d in enumerate(m.interior):
        zs = m.zs(d)
        x0, w = int(d["x0"]), int(d["w"])
        for g in range(x0, x0 + w):
            if (g - x0) % 2 != 1:
                continue
            cx = m.vx0(g) + 8
            if li == 0 and m.tier >= 2:
                zc = zs + 8
                if zc - 4 <= m.WL + 1:
                    continue
                v.box(cx - 4, yo, zc - 3, cx + 4, yo + 1, zc + 3, hexrgb("#2a1a18"))
                v.box(cx - 5, yo, zc + 3, cx + 5, yo + 1, zc + 4, WOOD["cap"])
                v.box(cx - 5, yo, zc - 4, cx + 5, yo + 1, zc - 3, WOOD["cap"])
                v.box(cx - 5, yo + 1, zc + 4, cx + 5, yo + 2, zc + 9, WOOD["hull_dark"])
                v.box(cx - 1, yo + 1, zc - 1, cx + 1, yo + 3, zc + 1, WOOD["iron"], GLOSS)
            else:
                zc = zs + 11
                if zc - 3 <= m.WL + 1:
                    continue
                for dx in range(-3, 4):
                    for dz in range(-3, 4):
                        r = math.hypot(dx, dz)
                        if r <= 3.3:
                            lit = r <= 2.0
                            v.put(cx + dx, yo, zc + dz, WOOD["glass"] if lit else WOOD["gold"],
                                  EMIT if lit else GLOSS)
                m.lights.append({"pos": m.world(cx, yo + 1, zc), "kind": "window", "view": 0})
    # castle windows on the near side and doors in the risers
    for d in m.open:
        if int(d["elev"]) <= 0:
            continue
        S = m.zs(d)
        for g in range(int(d["x0"]), int(d["x0"]) + int(d["w"])):
            cx = m.vx0(g) + 8
            zc = S - 12
            v.box(cx - 4, yo, zc - 4, cx + 4, yo + 1, zc + 5, WOOD["cap"])
            v.box(cx - 3, yo, zc - 3, cx + 3, yo + 1, zc + 4, WOOD["glass"], EMIT)
            v.box(cx - 3, yo, zc, cx + 3, yo + 1, zc + 1, WOOD["cap"])
            v.box(cx, yo, zc - 3, cx + 1, yo + 1, zc + 4, WOOD["cap"])
            v.box(cx - 5, yo + 1, zc - 5, cx + 5, yo + 2, zc - 4, WOOD["cap"], GLOSS)
            # A short gallery bracket and the hull's enamel band frame
            # these windows as a cabin, rather than holes in a plank wall.
            v.box(cx - 5, yo + 1, zc + 5, cx + 5, yo + 2, zc + 6, BAND[m.id])
            for dx in (-4, 3):
                v.box(cx + dx, yo + 1, zc - 8, cx + dx + 1, yo + 2, zc - 4, WOOD["hull_dark"])
            m.lights.append({"pos": m.world(cx, yo + 1, zc), "kind": "window", "view": 0})
    for vx in range(m.stern_x, m.X - 1):
        S, Sn = m.surf(vx), m.surf(vx + 1)
        if Sn >= S or vx + 1 >= m.bow0:
            continue
        yc = int(m.yc)
        # double door with a lamp either side
        v.box(vx, yc - 6, Sn, vx + 1, yc + 6, Sn + 17, WOOD["door"])
        v.box(vx + 1, yc - 7, Sn, vx + 2, yc - 6, Sn + 18, WOOD["cap"])
        v.box(vx + 1, yc + 6, Sn, vx + 2, yc + 7, Sn + 18, WOOD["cap"])
        v.box(vx + 1, yc - 7, Sn + 17, vx + 2, yc + 7, Sn + 18, WOOD["cap"])
        v.box(vx + 1, yc - 1, Sn, vx + 2, yc + 1, Sn + 17, WOOD["cabin_dark"])
        v.put(vx + 1, yc - 3, Sn + 8, WOOD["gold"])
        v.put(vx + 1, yc + 2, Sn + 8, WOOD["gold"])
        for wy in range(m.by0 + 4, m.by1 - 6, 16):
            if abs(wy + 3 - yc) < 12:
                continue
            v.box(vx + 1, wy, Sn + 8, vx + 2, wy + 7, Sn + 16, WOOD["cap"])
            v.box(vx + 1, wy + 1, Sn + 9, vx + 2, wy + 6, Sn + 15, WOOD["glass"], EMIT)
            v.box(vx + 1, wy + 3, Sn + 9, vx + 2, wy + 4, Sn + 15, WOOD["cap"])
        for ly in (yc - 10, yc + 9):
            v.box(vx + 1, ly, Sn + 13, vx + 2, ly + 2, Sn + 18, WOOD["lamp"], EMIT | NOSHADOW)
            v.box(vx + 1, ly, Sn + 18, vx + 2, ly + 2, Sn + 19, WOOD["iron"])
            m.lights.append({"pos": m.world(vx + 2, ly + 1, Sn + 15), "kind": "lantern", "view": 0})
    # anchor on the near bow
    bx = m.bow0 - 12
    S = m.surf(bx)
    for (x0, z0, x1, z1) in ((bx + 4, S - 22, bx + 6, S - 6), (bx, S - 22, bx + 10, S - 20),
                             (bx + 2, S - 9, bx + 8, S - 7)):
        v.box(x0, yo + 1, z0, x1, yo + 2, z1, WOOD["iron"], GLOSS)
    v.box(bx, yo + 1, S - 20, bx + 2, yo + 2, S - 17, WOOD["iron"])
    v.box(bx + 8, yo + 1, S - 20, bx + 10, yo + 2, S - 17, WOOD["iron"])
    v.box(bx + 4, yo + 1, S - 6, bx + 6, yo + 2, S - 3, WOOD["rope"])
    # lifebuoys on the near bulwark
    for gx in (int(main["x0"]) + 2, int(main["x0"]) + int(main["w"]) - 3):
        vx = m.vx0(gx) + 8
        S = m.surf(vx)
        for dx in range(-4, 5):
            for dz in range(-4, 5):
                r2 = dx * dx + dz * dz
                if 6 <= r2 <= 18:
                    c = hexrgb("#f4f0e6") if (math.atan2(dz, dx) * 4 / math.pi) % 2 < 1 else hexrgb("#e0473a")
                    v.put(vx + dx, yo + 1, S + 4 + dz, c)
    # bowsprit and figurehead
    yc = int(m.yc)
    S = m.surf(m.bow0)
    tip = m.bow0 + BOW_LEN - 2
    for i in range(0, 52):
        x = tip - 18 + i
        z = S + 4 + i * 0.42
        v.box(x, yc - 2, int(z), x + 1, yc + 2, int(z) + 3, WOOD["mast"])
    m.bowsprit = (tip + 34, yc, S + 26)
    for dz in range(0, 14):
        w = 1 if dz < 3 or dz > 11 else 3
        v.box(tip - 3 + dz // 3, yc - w, S - 18 + dz, tip + 1 + dz // 3, yc + w, S - 17 + dz, WOOD["gold"], GLOSS)
    # Swept wings make the little figurehead read as a gilded sea bird.
    for k in range(6):
        for side in (-1, 1):
            yy = yc + side * (3 + k)
            v.box(tip + 1 - k, yy, S - 10 + k, tip + 4 - k, yy + 1, S - 8 + k, WOOD["gold"], GLOSS)
    # bow deck props: capstan, bell, a crate stack and a rope coil
    b0 = m.bow0
    v.cyl(b0 + 9, yc, S, S + 7, 4.4, WOOD["post"])
    v.cyl(b0 + 9, yc, S + 7, S + 9, 5.2, WOOD["cap"])
    for a in range(-8, 9):
        v.put(b0 + 9 + a, yc, S + 8, WOOD["rail"])
        v.put(b0 + 9, yc + a, S + 8, WOOD["rail"])
    v.box(b0 + 22, yc - 12, S, b0 + 24, yc - 10, S + 17, WOOD["post"])
    v.box(b0 + 22, yc - 16, S + 17, b0 + 24, yc - 6, S + 19, WOOD["post"])
    v.cyl(b0 + 23, yc - 11, S + 10, S + 16, 2.6, WOOD["gold"], GLOSS)
    v.box(b0 + 2, yc + 8, S, b0 + 10, yc + 15, S + 7, hexrgb("#a0703c"), SEAM_SIDE)
    v.box(b0 + 2, yc + 8, S + 7, b0 + 10, yc + 15, S + 8, hexrgb("#c08850"), GLOSS)
    v.box(b0 + 4, yc + 10, S + 8, b0 + 10, yc + 15, S + 13, hexrgb("#a0703c"), SEAM_SIDE)
    v.cyl(b0 + 15, yc + 9, S, S + 2, 3.4, WOOD["rope"])
    v.cyl(b0 + 15, yc + 9, S + 2, S + 3, 1.8, WOOD["rope"])


def add_fixed(m: ShipModel, v: Vol):
    """Open-deck fittings: mast steps with fife rails, the helm and binnacle."""
    for d in m.open:
        for f in d["fixed"]:
            fx, fy, kind = int(f[0]), int(f[1]), f[2]
            gx = int(d["x0"]) + fx
            cx = m.vx0(gx) + 8
            cy = m.vy0(fy) + 8
            S = m.zs(d)
            if kind in ("mast", "foremast", "mizzen"):
                r = 4.6 if kind == "mast" else 4.0
                v.cyl(cx, cy, S, S + 34, r, WOOD["mast"], jitter=0.03, seed=gx)
                for rz in (S + 8, S + 24):
                    v.cyl(cx, cy, rz, rz + 2, r + 0.4, WOOD["iron"])
                # fife rail with belaying pins
                for a in range(-7, 7):
                    for (px, py) in ((cx + a, cy - 7), (cx + a, cy + 6), (cx - 7, cy + a), (cx + 6, cy + a)):
                        v.put(px, py, S + 7, WOOD["cap"], GLOSS)
                for (px, py) in ((-7, -7), (6, -7), (-7, 6), (6, 6), (0, 6), (6, 0)):
                    v.box(cx + px, cy + py, S, cx + px + 1, cy + py + 1, S + 7, WOOD["post"])
                for a in (-4, -1, 2, 5):
                    v.box(cx + a, cy + 6, S + 8, cx + a + 1, cy + 7, S + 10, WOOD["iron"])
                    v.box(cx + 6, cy + a, S + 8, cx + 7, cy + a + 1, S + 10, WOOD["iron"])
                m.mast_tops.append({"kind": kind, "gx": gx, "gy": fy, "cx": cx, "cy": cy, "S": S})
            elif kind == "helm":
                v.box(cx - 2, cy - 2, S, cx + 2, cy + 2, S + 10, WOOD["post"])
                v.box(cx - 3, cy - 3, S, cx + 3, cy + 3, S + 2, WOOD["cabin_dark"])
                wz = S + 13
                for dy in range(-8, 9):
                    for dz in range(-8, 9):
                        r2 = dy * dy + dz * dz
                        ring = 30 <= r2 <= 42
                        spoke = r2 <= 42 and (dy == 0 or dz == 0 or abs(dy) == abs(dz))
                        if ring or spoke:
                            v.put(cx - 3, cy + dy, wz + dz, WOOD["cap"] if ring else WOOD["post"])
                        if 50 <= r2 <= 64 and (dy == 0 or dz == 0 or (abs(dy) == abs(dz))):
                            v.put(cx - 3, cy + dy, wz + dz, WOOD["gold"])
                v.box(cx - 3, cy - 1, wz - 1, cx - 1, cy + 1, wz + 1, WOOD["gold"], GLOSS)
                v.box(cx + 4, cy + 3, S, cx + 8, cy + 7, S + 8, WOOD["cabin_dark"])
                v.box(cx + 4, cy + 3, S + 8, cx + 8, cy + 7, S + 10, WOOD["gold"], GLOSS)
                v.box(cx + 5, cy + 4, S + 10, cx + 7, cy + 6, S + 11, WOOD["sky"], EMIT)


def add_rig(m: ShipModel, v: Vol, mode: str):
    """Upper masts, yards, crow's nest and sails ('furled' or 'set')."""
    heights = {"mast": 150, "foremast": 126, "mizzen": 108}
    yc = m.yc
    beam_v = m.by1 - m.by0
    stripe = BAND.get(m.id) or hexrgb("#c9584a")
    tops = []
    for mt in m.mast_tops:
        cx, cy, S, kind = mt["cx"], mt["cy"], mt["S"], mt["kind"]
        H = heights[kind]
        top = S + H
        v.cyl(cx, cy, S + 34, S + int(H * 0.6), 3.6, WOOD["mast"], jitter=0.03, seed=cx)
        v.cyl(cx, cy, S + int(H * 0.6), top, 2.6, WOOD["mast"], jitter=0.03, seed=cx + 1)
        v.cyl(cx, cy, top, top + 4, 1.6, WOOD["mast"])
        v.cyl(cx, cy, top + 4, top + 6, 2.4, WOOD["gold"])
        yards = [(S + 64, 0.94), (S + int(H * 0.78), 0.66)]
        if kind == "mast":
            nz = S + int(H * 0.6)
            v.cyl(cx, cy, nz, nz + 3, 9.0, WOOD["post"])
            for dy in range(-10, 11):
                for dx in range(-10, 11):
                    r2 = dx * dx + dy * dy
                    if 72 <= r2 <= 100:
                        v.box(cx + dx, cy + dy, nz + 3, cx + dx + 1, cy + dy + 1, nz + 9,
                              WOOD["rail"] if (dx + dy) % 3 else WOOD["post"])
            m.lights.append({"pos": m.world(cx, cy, nz + 10), "kind": "nest", "view": 0})
        for (yz, frac) in yards:
            half = beam_v * frac / 2
            for vy in range(int(yc - half), int(yc + half)):
                v.box(cx - 2, vy, yz, cx + 1, vy + 1, yz + 2, WOOD["post"])
            v.box(cx - 2, int(yc - half) - 1, yz - 1, cx + 1, int(yc - half), yz + 3, WOOD["iron"])
            v.box(cx - 2, int(yc + half), yz - 1, cx + 1, int(yc + half) + 1, yz + 3, WOOD["iron"])
            if mode == "furled":
                for vy in range(int(yc - half) + 2, int(yc + half) - 2):
                    sh = WOOD["sail"] if (vy // 3) % 3 else WOOD["sail_shade"]
                    v.box(cx - 2, vy, yz - 4, cx + 3, vy + 1, yz, sh)
                    if vy % 9 == 0:
                        v.box(cx - 2, vy, yz - 4, cx + 3, vy + 1, yz - 3, WOOD["rope"])
            else:
                sail_h = 34 if frac > 0.8 else 30
                hw = half - 2
                for vy in range(int(yc - hw), int(yc + hw)):
                    u = (vy + 0.5 - (yc - hw)) / (2 * hw)
                    for dz in range(sail_h):
                        w = dz / sail_h
                        bel = 10.0 * math.sin(math.pi * u) * (0.5 + 0.5 * math.sin(math.pi * min(1.0, w * 1.08)))
                        x = int(round(cx + 1 + bel))
                        shade = 0.9 + 0.1 * math.sin(math.pi * u)
                        c = mul(WOOD["sail"], shade)
                        if frac > 0.8 and 11 <= dz <= 14:
                            c = stripe
                        if (vy - int(yc - hw)) % 14 == 0:
                            c = mul(c, 0.93)
                        fl = NOSHADOW | (SEAM_SIDE if dz % 8 == 7 else 0)
                        v.box(x, vy, yz - 2 - dz, x + 2, vy + 1, yz - 1 - dz, c, fl)
        for i in range(20):
            pz = top + 3 - (i // 6)
            v.box(cx - 2 - i, int(cy), pz - 2, cx - 1 - i, int(cy) + 1, pz + 2 if i < 12 else pz, PENNANT[m.id], NOSHADOW)
        tops.append((cx, cy, top))
        sz = S + int(H * 0.6)
        for side in (-1, 1):
            rail_y = m.by0 - 2 if side < 0 else m.by1 + 2
            for k, dx in enumerate((-12, -4, 4)):
                m.ropes.append({"a": m.world(cx, cy, sz), "b": m.world(cx + dx, rail_y, m.surf(cx + dx) + RAIL),
                                "kind": "shroud", "ladder": k == 1})
    tops.sort()
    for a, b in zip(tops, tops[1:]):
        m.ropes.append({"a": m.world(a[0], a[1], a[2] - 8), "b": m.world(b[0], b[1], b[2] - 32), "kind": "stay"})
    if tops and m.bowsprit:
        f = tops[-1]
        bx, by, bz = m.bowsprit
        m.ropes.append({"a": m.world(f[0], f[1], f[2] - 4), "b": m.world(bx - 8, by, bz - 4), "kind": "stay"})
    if tops:
        a = tops[0]
        m.ropes.append({"a": m.world(a[0], a[1], a[2] - 10), "b": m.world(m.stern_x + 2, m.yc, m.surf(m.stern_x) + RAIL + 2),
                        "kind": "stay"})


# ---------------------------------------------------------------- views
def view_volume(m: ShipModel, base: Vol, shell, vi):
    vv = clone(base)
    if vi == 0:
        vv.solid[:, :, :max(0, m.WL - 2)] = False
        return vv
    d = m.interior[vi - 1]
    zs = m.zs(d)
    top = zs + CEIL
    x0, w = int(d["x0"]), int(d["w"])
    bx1 = m.vx0(x0 + w)
    vv.solid[:, :, top:] = False
    near = np.zeros((m.X, m.Y), bool)
    near[:, m.by1:] = True
    near[bx1:, :] = True
    zc = zs + SILL
    vv.solid[:, :, zc:top] &= ~near[:, :, None]
    # cut faces: hull shell reads as a capped rim, the core as a dark section
    for z, mask in ((zc - 1, near), (top - 1, ~near)):
        sel = vv.solid[:, :, z] & mask & ~vv.solid[:, :, z + 1] if z + 1 < m.Z else vv.solid[:, :, z] & mask
        sh = sel & shell[:, :, z]
        core = sel & ~shell[:, :, z]
        vv.col[:, :, z][sh] = WOOD["cap"]
        vv.flag[:, :, z][sh] = GLOSS
        xs, ys = np.nonzero(core)
        if xs.size:
            c = plank_cols(xs, ys, WOOD["section"], mul(WOOD["section"], 0.78), seed=31, width=4, seg=23)
            vv.col[xs, ys, z] = np.clip(c, 0, 255).astype(np.uint8)
            vv.flag[xs, ys, z] = np.where(ys % 4 == 3, SEAM, 0).astype(np.uint16) | NOOUTLINE
    return vv


def assign_groups(v: Vol):
    X, Y, Z = v.shape
    gx = np.arange(X) // CV - MXS
    gy = np.arange(Y) // CV - MY
    G = (gx[:, None] + 64) * 256 + (gy[None, :] + 64)
    v.group[...] = np.where(v.solid, G[:, :, None], -1)


def piece_meta(m: ShipModel, r, pieces, layer, view):
    out = []
    ox = CV * MXS + CV / 2
    oy = CV * MY + CV / 2
    for g, (crop, (x0, y0)) in pieces.items():
        gx, gy = gid_cell(g)
        # world coordinates of the crop's top-left (render origin is voxel point (0,0,0))
        wx = (x0 - r.origin[0]) - 2 * (ox - oy)
        wy = (y0 - r.origin[1]) - (ox + oy) + 2 * m.ZB
        ax, ay = (gx - gy) * CV * 2, (gx + gy) * CV
        out.append((f"v{view}:{layer}:{gx}:{gy}", crop,
                    {"layer": layer, "view": view, "cell": [gx, gy], "off": [int(wx - ax), int(wy - ay)]}))
    return out


def build_ship(hull):
    m = ShipModel(hull)
    base, E, shell = build_body(m)
    carve_levels(m, base)
    deck_tops(m, base, E)
    add_rails(m, base)
    add_hull_details(m, base)
    add_fixed(m, base)
    items = []
    renders = []
    nviews = 1 + len(m.interior)
    for vi in range(nviews):
        vv = view_volume(m, base, shell, vi)
        assign_groups(vv)
        r = render(vv, shadow=(vi == 0), shadow_len=60)
        items += piece_meta(m, r, slice_groups(r), "hull", vi)
        renders.append(r)
    base_lights = list(m.lights)
    keep = None
    for mode in ("furled", "set"):
        m.lights = list(base_lights)
        m.ropes = []
        rv = Vol(m.X, m.Y, m.Z + 170)
        add_rig(m, rv, mode)
        if keep is None:
            keep = (m.lights, m.ropes)
        assign_groups(rv)
        rr = render(rv, shadow=False)
        items += piece_meta(m, rr, slice_groups(rr), "rig_" + mode, 0)
    m.lights, m.ropes = keep
    width = 2048 if m.total < 20 else 4096
    pk = Packer(width=width)
    for name, crop, meta in items:
        pk.add(name, crop, **meta)
    png = OUT / "ship" / f"hull_{m.id}.png"
    rects, size = pk.pack(png)
    foam = []
    for vx in range(m.stern_x, m.X, 3):
        h = m.half_w(vx, m.WL)
        if h is not None:
            foam.append([m.world(vx, m.yc + h, m.WL), m.world(vx, m.yc - h, m.WL)])
    views = [{"kind": "open"}] + [{"kind": "interior", "deck": d["id"]} for d in m.interior]
    meta = {
        "hull": m.id, "levelPx": LEVEL_PX, "cell": [CV * 4, CV * 2], "views": views,
        "pieces": [dict(name=k, **val) for k, val in rects.items()],
        "lights": m.lights, "ropes": m.ropes, "foam": foam,
        "bounds": {"minGx": -MXS, "maxGx": m.total + MXB, "minGy": -MY, "maxGy": m.beam + MY,
                   "top": m.world(0, 0, m.Z + 150)[1], "bottom": m.world(m.X, m.Y, 0)[1]},
        "waterline": round(2 * (m.ZB - m.WL), 1),
    }
    save_json(meta, OUT / "ship" / f"hull_{m.id}.json")
    record(png.relative_to(GAME.parent), f"{size[0]}x{size[1]} atlas, {len(items)} pieces", "static",
           "voxel model rendered by tools/artgen/lib/vox.py once per view level, sliced per cell",
           f"Ship hull '{m.id}': open decks + {len(m.interior)} interior cutaway levels, furled and set rig")
    for vi in range(nviews):
        comp = composite_preview(m, rects, png, vi)
        save_png(upscale_preview(comp, 1), PREVIEW / f"ship_{m.id}_view{vi}.png")
    return m, size


def composite_preview(m, rects, png, view):
    from PIL import Image
    atlas = np.array(Image.open(png))
    items = []
    for name, val in rects.items():
        if val["view"] != view or val["layer"] == "rig_set":
            continue
        gx, gy = val["cell"]
        x, y, w, h = val["rect"]
        key = (gx + gy) * 16 - 4 + (1 if val["layer"].startswith("rig") else 0)
        items.append((key, gx, gy, val["off"], atlas[y:y + h, x:x + w]))
    items.sort(key=lambda t: t[0])
    S = CV * 2
    xs = [(gx - gy) * S + off[0] for _, gx, gy, off, _ in items]
    ys = [(gx + gy) * CV + off[1] for _, gx, gy, off, _ in items]
    x0, y0 = min(xs), min(ys)
    W = max((gx - gy) * S + off[0] + a.shape[1] for _, gx, gy, off, a in items) - x0
    H = max((gx + gy) * CV + off[1] + a.shape[0] for _, gx, gy, off, a in items) - y0
    canvas = Image.new("RGBA", (W + 40, H + 40), (46, 128, 178, 255))
    for key, gx, gy, off, a in items:
        canvas.alpha_composite(Image.fromarray(a), ((gx - gy) * S + off[0] - x0 + 20, (gx + gy) * CV + off[1] - y0 + 20))
    return np.array(canvas)


# -- generic overlay parts ---------------------------------------------------
def build_parts():
    """Per-cell overlays at ship scale. Offsets are relative to the cell anchor
    on the floor the part stands on (the lower deck for stairs and ladders)."""
    pk = Packer(width=1024)
    c = CV // 2

    def emit(name, v, anchor, shadow=True):
        v.group[...] = np.where(v.solid, 0, -1)
        r = render(v, shadow=shadow, shadow_len=24)
        pieces = slice_groups(r)
        crop, (x0, y0) = pieces[0]
        ax = r.origin[0] + 2 * (anchor[0] - anchor[1])
        ay = r.origin[1] + (anchor[0] + anchor[1]) - 2 * anchor[2]
        pk.add(name, crop, off=[int(x0 - ax), int(y0 - ay)])

    base = 4
    # terrace railings on a raised cell's edge facing a lower deck
    for edge in ("px", "mx"):
        v = Vol(CV, CV, base + RAIL + 6)
        x = CV - 1 if edge == "px" else 0
        for y in range(CV):
            if y % 3 == 0:
                v.box(x, y, base, x + 1, y + 1, base + RAIL, WOOD["post"])
            v.box(x, y, base + RAIL, x + 1, y + 1, base + RAIL + 1, WOOD["cap"], GLOSS)
            v.put(x, y, base + 4, WOOD["rail"])
        v.box(x, 0, base, x + 1, 2, base + RAIL + 3, WOOD["post"])
        emit("rail_" + edge, v, (c, c, base))
    # terrace stairs on an open deck: foot on this cell, rising one level
    for d in ("mx", "px"):
        v = Vol(CV, CV, base + LV + 10)
        for i in range(CV):
            x = CV - 1 - i if d == "mx" else i
            z_top = base + int(round((i + 1) * LV / CV))
            step = (i % 2) == 1
            for y in range(2, CV - 2):
                v.box(x, y, base, x + 1, y + 1, z_top, WOOD["cabin"] if y in (2, CV - 3) else WOOD["deck"],
                      SEAM if (step and y not in (2, CV - 3)) else 0)
            v.box(x, 1, base, x + 1, 2, z_top + 1, WOOD["post"])
            v.box(x, CV - 2, base, x + 1, CV - 1, z_top + 1, WOOD["post"])
            v.box(x, 0, z_top + 1, x + 1, 1, z_top + 8, WOOD["post"] if i % 4 == 0 else WOOD["rail"])
            v.box(x, CV - 1, z_top + 1, x + 1, CV, z_top + 8, WOOD["post"] if i % 4 == 0 else WOOD["rail"])
            v.put(x, 0, z_top + 8, WOOD["cap"], GLOSS)
            v.put(x, CV - 1, z_top + 8, WOOD["cap"], GLOSS)
        emit("stair_" + d, v, (c, c, base))
    # hatch ladder: a steep companionway from an interior floor up through
    # the (cut-away) ceiling, rising toward -x
    v = Vol(CV, CV, base + CEIL + 2)
    for z in range(0, CEIL):
        x = int(round(12 - z * 9 / CEIL))
        for y in (4, 11):
            v.box(x, y, base + z, x + 2, y + 1, base + z + 1, WOOD["post"])
        if z % 3 == 1:
            v.box(x, 5, base + z, x + 2, 11, base + z + 1, WOOD["cap"], GLOSS)
    v.box(10, 3, base, 15, 13, base + 1, WOOD["cabin_dark"])
    v.box(2, 3, base + CEIL - 1, 5, 13, base + CEIL, WOOD["iron"])
    emit("ladder", v, (c, c, base), shadow=False)
    # hatch: an opening in the floor with a coaming and the ladder head
    v = Vol(CV, CV, base + 16)
    v.box(2, 2, base - 1, 14, 14, base, hexrgb("#1c120c"), NOOUTLINE)
    for (x0, y0, x1, y1) in ((2, 2, 14, 3), (2, 13, 14, 14), (2, 2, 3, 14), (13, 2, 14, 14)):
        v.box(x0, y0, base - 1, x1, y1, base + 2, WOOD["cap"], GLOSS)
    for y in (5, 10):
        v.box(4, y, base - 1, 5, y + 1, base + 3, WOOD["post"])
    v.box(4, 5, base + 2, 5, 11, base + 3, WOOD["cap"])
    # grating cover propped open on the far side
    for i in range(10):
        for j in range(10):
            if (i % 2 == 0) or (j % 3 == 0):
                v.put(3 + i, 1, base + 2 + j, WOOD["post"] if (i + j) % 2 else WOOD["rail"])
    emit("hatch", v, (c, c, base))
    # bulkhead wall and door across an interior level
    H = 16
    for kind in ("wall", "door"):
        v = Vol(CV, CV, base + H + 2)
        v.box(6, 0, base, 10, CV, base + H, WOOD["panel"])
        for y in range(0, CV, 4):
            v.flag[9, y, base:base + H] |= SEAM_R
        v.box(6, 0, base + H, 10, CV, base + H + 1, WOOD["trim"], GLOSS)
        v.box(6, 0, base, 10, CV, base + 5, WOOD["panel_dark"])
        if kind == "door":
            v.clear(6, 4, base, 10, 12, base + 13)
            v.box(9, 3, base, 10, 4, base + 14, WOOD["trim"])
            v.box(9, 12, base, 10, 13, base + 14, WOOD["trim"])
            v.box(9, 3, base + 13, 10, 13, base + 14, WOOD["trim"])
            v.box(6, 4, base, 7, 6, base + 13, WOOD["door"])
            v.box(10, 13, base + 9, 11, 14, base + 12, WOOD["lamp"], EMIT | NOSHADOW)
        else:
            v.box(9, 5, base + 8, 10, 11, base + 13, WOOD["trim"])
            v.box(9, 6, base + 9, 10, 10, base + 12, WOOD["glass"], EMIT)
        emit("bulkhead_" + kind, v, (c, c, base))
    rects, size = pk.pack(OUT / "ship" / "parts.png")
    save_json(rects, OUT / "ship" / "parts.json")
    record((OUT / "ship" / "parts.png").relative_to(GAME.parent), f"{size[0]}x{size[1]} atlas, {len(rects)} pieces",
           "static", "voxel models rendered by lib/vox.py",
           "Terrace railings and stairs, hatch ladder and hatch, bulkhead wall and door overlays")


def main():
    for hull in HULLS:
        m, size = build_ship(hull)
        print("ship", hull["id"], size)
    build_parts()


if __name__ == "__main__":
    main()
