"""Isometric voxel renderer for Project Seven Seas pixel art.

Projection (pixels): a world point (X, Y, Z) in voxel units maps to
    sx = 2 * (X - Y),  sy = (X + Y) - 2 * Z
so one voxel is a 4x4 px hexagon (2x2 top face, 2x2-ish side faces), eight
voxels make one 32x16 game tile, and twelve voxels make one deck level
(24 px). +X runs toward the screen's lower right, +Y toward the lower left,
+Z up. The viewer looks along -(1,1,1), so visible faces are top (+Z), left
(+Y) and right (+X).

The renderer stamps every visible voxel face in back-to-front order
(X+Y+Z), keeping per-pixel owner/face buffers. Shading, cast shadows,
ambient occlusion, rim light, seams and contour outlines are computed from
those buffers so separately sliced pieces still line up seamlessly.
"""
from __future__ import annotations

import numpy as np

# Face pixel patterns relative to the anchor (2(x-y), x+y-2z-2) of voxel (x,y,z).
TOP = [(-1, 0), (0, 0), (-1, 1), (0, 1)]
LEFT = [(-2, 1), (-2, 2), (-1, 2), (-1, 3)]
RIGHT = [(1, 1), (1, 2), (0, 2), (0, 3)]
FACES = (TOP, LEFT, RIGHT)
F_TOP, F_LEFT, F_RIGHT = 0, 1, 2

# Voxel flags.
SEAM = 1          # darken the lower row of the top face (plank seam line)
EMIT = 2          # emissive: no shading, no shadow received
NOSHADOW = 4      # does not cast a shadow
NOOUTLINE = 8     # never receives a contour line
SEAM_SIDE = 16    # darken the lower row of side faces (horizontal strake line)
GLOSS = 32        # extra specular highlight on the top face
SEAM_L = 64       # darken the right column of the left face (vertical board line)
SEAM_R = 128      # darken the left column of the right face


def hexrgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def mul(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c)


class Vol:
    """Dense voxel volume with colour, flag and group channels."""

    def __init__(self, X: int, Y: int, Z: int):
        self.shape = (X, Y, Z)
        self.solid = np.zeros((X, Y, Z), bool)
        self.col = np.zeros((X, Y, Z, 3), np.uint8)
        self.flag = np.zeros((X, Y, Z), np.uint16)
        self.group = np.full((X, Y, Z), -1, np.int32)

    # -- editing ---------------------------------------------------------
    def _clip(self, x0, y0, z0, x1, y1, z1):
        X, Y, Z = self.shape
        return (max(0, x0), max(0, y0), max(0, z0), min(X, x1), min(Y, y1), min(Z, z1))

    def box(self, x0, y0, z0, x1, y1, z1, color, flags=0, group=None, jitter=0.0, seed=0):
        """Fill [x0,x1) x [y0,y1) x [z0,z1). color may be an RGB tuple or a
        callable(xs, ys, zs) -> (N,3) array evaluated on absolute coords."""
        x0, y0, z0, x1, y1, z1 = self._clip(x0, y0, z0, x1, y1, z1)
        if x0 >= x1 or y0 >= y1 or z0 >= z1:
            return
        sl = (slice(x0, x1), slice(y0, y1), slice(z0, z1))
        self.solid[sl] = True
        if callable(color):
            xs, ys, zs = np.meshgrid(np.arange(x0, x1), np.arange(y0, y1), np.arange(z0, z1), indexing="ij")
            c = np.asarray(color(xs, ys, zs), dtype=np.float32)
        else:
            c = np.empty((x1 - x0, y1 - y0, z1 - z0, 3), np.float32)
            c[...] = color
        if jitter:
            rng = np.random.default_rng(seed)
            n = rng.uniform(1 - jitter, 1 + jitter, c.shape[:3])[..., None]
            c = c * n
        self.col[sl] = np.clip(c, 0, 255).astype(np.uint8)
        self.flag[sl] = flags
        if group is not None:
            self.group[sl] = group

    def clear(self, x0, y0, z0, x1, y1, z1):
        x0, y0, z0, x1, y1, z1 = self._clip(x0, y0, z0, x1, y1, z1)
        if x0 >= x1 or y0 >= y1 or z0 >= z1:
            return
        sl = (slice(x0, x1), slice(y0, y1), slice(z0, z1))
        self.solid[sl] = False
        self.flag[sl] = 0

    def put(self, x, y, z, color, flags=0, group=None):
        X, Y, Z = self.shape
        if 0 <= x < X and 0 <= y < Y and 0 <= z < Z:
            self.solid[x, y, z] = True
            self.col[x, y, z] = color
            self.flag[x, y, z] = flags
            if group is not None:
                self.group[x, y, z] = group

    def cyl(self, cx, cy, z0, z1, r, color, flags=0, group=None, jitter=0.0, seed=0):
        """Vertical cylinder centred at (cx, cy) (may be fractional)."""
        X, Y, Z = self.shape
        xs = np.arange(int(np.floor(cx - r)) - 1, int(np.ceil(cx + r)) + 1)
        ys = np.arange(int(np.floor(cy - r)) - 1, int(np.ceil(cy + r)) + 1)
        for x in xs:
            for y in ys:
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.box(x, y, z0, x + 1, y + 1, z1, color, flags, group, jitter, seed + x * 7 + y)

    def mirror_xy(self) -> "Vol":
        """Transpose X and Y (used for a facility's rotated variant)."""
        v = Vol(self.shape[1], self.shape[0], self.shape[2])
        v.solid = self.solid.transpose(1, 0, 2).copy()
        v.col = self.col.transpose(1, 0, 2, 3).copy()
        f = self.flag.transpose(1, 0, 2).copy()
        # swap side-specific flags
        l = (f & SEAM_L) != 0
        r = (f & SEAM_R) != 0
        f &= ~np.uint16(SEAM_L | SEAM_R)
        f |= np.where(l, SEAM_R, 0).astype(np.uint16) | np.where(r, SEAM_L, 0).astype(np.uint16)
        v.flag = f
        v.group = self.group.transpose(1, 0, 2).copy()
        return v


# -- rendering -------------------------------------------------------------
SHADOW_TINT = np.array([0.80, 0.82, 1.00], np.float32)
FACE_MUL = np.array([[1.00, 1.00, 1.00], [0.84, 0.82, 0.86], [0.68, 0.64, 0.72]], np.float32)


class Render:
    """Result of rendering a volume: RGBA image plus per-pixel buffers."""

    def __init__(self, rgba, owner_group, origin, face, vx, vy, vz):
        self.rgba = rgba            # (H, W, 4) uint8
        self.group = owner_group    # (H, W) int32, -2 for background
        self.origin = origin        # pixel coordinate of world projection point (0,0,0)
        self.face = face
        self.vx, self.vy, self.vz = vx, vy, vz


def render(vol: Vol, shadow=True, shadow_step=(-1.0, -0.5, 2.0), shadow_len=40, ao=True,
           outline=True, outline_color=(38, 22, 30), inner_line=0.62, pad=2, sun=1.0) -> Render:
    s = vol.solid
    X, Y, Z = vol.shape
    # Visible voxels: at least one of +x, +y, +z neighbours empty.
    pad_s = np.zeros((X + 1, Y + 1, Z + 1), bool)
    pad_s[:X, :Y, :Z] = s
    exp_top = s & ~pad_s[:X, :Y, 1:Z + 1]
    exp_left = s & ~pad_s[:X, 1:Y + 1, :Z]
    exp_right = s & ~pad_s[1:X + 1, :Y, :Z]
    vis = exp_top | exp_left | exp_right
    xs, ys, zs = np.nonzero(vis)
    if xs.size == 0:
        return Render(np.zeros((1, 1, 4), np.uint8), np.full((1, 1), -2, np.int32), (0, 0),
                      np.zeros((1, 1), np.int8), None, None, None)
    ax = 2 * (xs - ys)
    ay = xs + ys - 2 * zs - 2
    minx = int(ax.min()) - 2 - pad
    maxx = int(ax.max()) + 1 + pad
    miny = int(ay.min()) - pad
    maxy = int(ay.max()) + 3 + pad
    W = maxx - minx + 1
    H = maxy - miny + 1
    depth = xs + ys + zs
    vid = np.arange(xs.size)

    P_idx, P_dep, P_vid, P_face, P_sub = [], [], [], [], []
    for fi, pat in enumerate(FACES):
        for si, (dx, dy) in enumerate(pat):
            px = ax + dx - minx
            py = ay + dy - miny
            P_idx.append(py * W + px)
            P_dep.append(depth)
            P_vid.append(vid)
            P_face.append(np.full(xs.size, fi, np.int8))
            P_sub.append(np.full(xs.size, si, np.int8))
    P_idx = np.concatenate(P_idx)
    P_dep = np.concatenate(P_dep)
    P_vid = np.concatenate(P_vid)
    P_face = np.concatenate(P_face)
    P_sub = np.concatenate(P_sub)
    # Front-most wins. Within one voxel all its faces have distinct pixels.
    order = np.lexsort((P_dep, P_idx))
    P_idx = P_idx[order]
    last = np.ones(P_idx.size, bool)
    last[:-1] = P_idx[1:] != P_idx[:-1]
    sel = order[last]
    pix = P_idx[last]

    owner = np.full(H * W, -1, np.int64)
    owner[pix] = P_vid[sel]
    face = np.full(H * W, -1, np.int8)
    face[pix] = P_face[sel]
    sub = np.full(H * W, -1, np.int8)
    sub[pix] = P_sub[sel]
    owner = owner.reshape(H, W)
    face = face.reshape(H, W)
    sub = sub.reshape(H, W)
    mask = owner >= 0
    o = np.where(mask, owner, 0)
    vx, vy, vz = xs[o], ys[o], zs[o]
    flags = vol.flag[vx, vy, vz]
    base = vol.col[vx, vy, vz].astype(np.float32)
    f = np.where(mask, face, 0)
    emit = (flags & EMIT) != 0

    shade = FACE_MUL[f]
    col = base * shade

    # Seams.
    seam = ((flags & SEAM) != 0) & (f == F_TOP) & (sub >= 2)
    seam_side = ((flags & SEAM_SIDE) != 0) & (f != F_TOP) & (sub == 3)
    seam_side |= ((flags & SEAM_SIDE) != 0) & (f == F_LEFT) & (sub == 1)
    seam_side |= ((flags & SEAM_SIDE) != 0) & (f == F_RIGHT) & (sub == 1)
    seam_l = ((flags & SEAM_L) != 0) & (f == F_LEFT) & ((sub == 2) | (sub == 3))
    seam_r = ((flags & SEAM_R) != 0) & (f == F_RIGHT) & ((sub == 0) | (sub == 1))
    col = np.where((seam | seam_side | seam_l | seam_r)[..., None], col * np.array([0.70, 0.64, 0.66]), col)

    # Rim light on convex top edges facing the viewer.
    def solid_at(ax_, ay_, az_):
        inb = (ax_ >= 0) & (ax_ < X) & (ay_ >= 0) & (ay_ < Y) & (az_ >= 0) & (az_ < Z)
        out = np.zeros(ax_.shape, bool)
        out[inb] = s[ax_[inb], ay_[inb], az_[inb]]
        return out

    top = mask & (f == F_TOP)
    open_py = ~solid_at(vx, vy + 1, vz)
    open_px = ~solid_at(vx + 1, vy, vz)
    rim = top & (((sub == 2) & open_py) | ((sub == 3) & open_px))
    col = np.where((rim & ~seam)[..., None], np.minimum(col * 1.10 + 10, 255), col)
    gloss = top & ((flags & GLOSS) != 0) & (sub == 0)
    col = np.where(gloss[..., None], np.minimum(col * 1.18 + 18, 255), col)

    # Ambient occlusion on top faces next to walls.
    if ao:
        occ = (solid_at(vx - 1, vy, vz + 1).astype(np.float32) + solid_at(vx, vy - 1, vz + 1)
               + solid_at(vx + 1, vy, vz + 1) + solid_at(vx, vy + 1, vz + 1))
        col = np.where(top[..., None], col * (1 - 0.06 * occ)[..., None], col)
        # side faces darken towards a floor
        side = mask & (f != F_TOP)
        below = solid_at(vx + (f == F_RIGHT), vy + (f == F_LEFT), vz - 1)
        col = np.where((side & below & (vz > 0))[..., None], col * 0.93, col)

    # Directional cast shadows on top faces.
    if shadow:
        lit = np.ones(top.shape, bool)
        sx_, sy_, sz_ = shadow_step
        ty, tx = np.nonzero(top & ~emit)
        px0 = vx[ty, tx].astype(np.float32) + 0.5
        py0 = vy[ty, tx].astype(np.float32) + 0.5
        pz0 = vz[ty, tx].astype(np.float32) + 1.0
        # sub-pixel offset so shadow edges are crisp on the 2x2 top face
        sb = sub[ty, tx]
        px0 += np.where(sb % 2 == 1, 0.25, -0.25)
        py0 += np.where(sb >= 2, 0.25, -0.25)
        hit = np.zeros(ty.size, bool)
        casts = s & ((vol.flag & NOSHADOW) == 0)
        for k in range(1, shadow_len + 1):
            qx = np.floor(px0 + sx_ * k * 0.5).astype(np.int64)
            qy = np.floor(py0 + sy_ * k * 0.5).astype(np.int64)
            qz = np.floor(pz0 + sz_ * k * 0.5).astype(np.int64)
            inb = (qx >= 0) & (qx < X) & (qy >= 0) & (qy < Y) & (qz >= 0) & (qz < Z)
            h = np.zeros(ty.size, bool)
            h[inb] = casts[qx[inb], qy[inb], qz[inb]]
            hit |= h
            if (qz >= Z).all():
                break
        lit[ty[hit], tx[hit]] = False
        shadowed = top & ~lit
        col = np.where(shadowed[..., None], col * 0.72 * SHADOW_TINT, col)

    col = col * sun
    col = np.where(emit[..., None], base, col)

    # Contour lines.
    if outline:
        dep = np.where(mask, (vx + vy + vz), -10 ** 6)
        no_ol = (flags & NOOUTLINE) != 0
        sil = np.zeros(mask.shape, bool)
        crease = np.zeros(mask.shape, bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb_mask = np.zeros_like(mask)
            nb_dep = np.full(dep.shape, -10 ** 6)
            ys0 = slice(max(0, dy), H + min(0, dy))
            yd0 = slice(max(0, -dy), H + min(0, -dy))
            xs0 = slice(max(0, dx), W + min(0, dx))
            xd0 = slice(max(0, -dx), W + min(0, -dx))
            nb_mask[yd0, xd0] = mask[ys0, xs0]
            nb_dep[yd0, xd0] = dep[ys0, xs0]
            sil |= mask & ~nb_mask
            crease |= mask & nb_mask & (dep - nb_dep >= 4)
        oc = np.array(outline_color, np.float32)
        col = np.where((sil & ~no_ol)[..., None], oc + (col - oc) * 0.18, col)
        col = np.where((crease & ~sil & ~no_ol)[..., None], col * inner_line, col)

    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    rgba[..., 3] = np.where(mask, 255, 0)
    grp = np.where(mask, vol.group[vx, vy, vz], -2).astype(np.int32)
    origin = (-minx, -miny)  # pixel position of world point (0,0,0)
    return Render(rgba, grp, origin, np.where(mask, face, -1), vx, vy, vz)


def project(origin, X, Y, Z):
    """Pixel position (possibly fractional) of a world point in a render."""
    return (origin[0] + 2 * (X - Y), origin[1] + (X + Y) - 2 * Z)


def slice_groups(r: Render, keep_empty=False):
    """Split a render into {group: (rgba_crop, (left, top))} by owner group."""
    out = {}
    groups = np.unique(r.group)
    for g in groups:
        if g < -1 or (g == -1 and not keep_empty):
            continue
        m = r.group == g
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        sub = r.rgba[y0:y1, x0:x1]
        mm = m[y0:y1, x0:x1]
        crop[mm] = sub[mm]
        out[int(g)] = (crop, (int(x0), int(y0)))
    return out
