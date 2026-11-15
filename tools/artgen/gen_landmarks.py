"""Build coherent native-pixel landmarks from reviewed visual concepts.

Generation is deliberately separate: rebuilding never calls a model or replaces
the selected masters in art/source/landmarks. The game only ships the atlas.
"""
from __future__ import annotations

import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from lib.common import GAME, OUT, PREVIEW, ROOT, Packer, record, save_json
from lib import kit
from lib.kit import P
from lib.vox import EMIT, GLOSS, SEAM_SIDE, Vol, hexrgb, mix, mul
from gen_env import ARCHITECTURE, architectural_roof, vol_sprite

SOURCE = ROOT / "art" / "source" / "landmarks"
REGIONS = ["dawnwater", "emberreach", "verdant_maw", "glass_current",
           "crown_shoals", "stormbelt", "moonwake", "ashen_trench",
           "leviathan_ring", "grand_horizon"]


def concept_preview(path):
    """The previous raster treatment, retained for before/after review only."""
    master = Image.open(path).convert("RGBA")
    # The generated alpha includes soft light spill. Keep the solid object,
    # rather than carrying a large translucent rectangle into the pixel world.
    solid = master.getchannel("A").point(lambda a: 255 if a >= 160 else 0)
    box = solid.getbbox()
    if box is None:
        raise ValueError(f"No solid landmark pixels in {path}")
    master = master.crop(box)
    factor = min(144 / master.width, 150 / master.height)
    size = (max(1, round(master.width * factor)), max(1, round(master.height * factor)))
    sprite = master.resize(size, Image.Resampling.BOX)
    alpha = sprite.getchannel("A").point(lambda a: 255 if a >= 144 else 0)
    # Cluster fine source texture before a fixed, non-dithered palette pass.
    rgb = sprite.convert("RGB").filter(ImageFilter.MedianFilter(3))
    rgb = rgb.quantize(colors=64, method=Image.Quantize.MEDIANCUT,
                       dither=Image.Dither.NONE).convert("RGBA")
    rgb.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox:
        rgb = rgb.crop(bbox)
    return rgb


def _tube(v, start, end, radius, colour):
    """A solid square-section pipe/root/bone on the native voxel lattice."""
    n = max(abs(end[k] - start[k]) for k in range(3)) * 2 + 1
    for step in range(n):
        p = [round(start[k] + (end[k] - start[k]) * step / max(1, n - 1)) for k in range(3)]
        v.box(p[0] - radius, p[1] - radius, p[2] - radius,
              p[0] + radius + 1, p[1] + radius + 1, p[2] + radius + 1, colour)


def _arch(v, cx, y, bottom, half_width, height, colour, thickness=2):
    for x in range(cx - half_width - 1, cx + half_width + 2):
        for z in range(bottom, bottom + height + 1):
            upper = max(0, z - bottom - height * .44) / (height * .56)
            outer = ((x - cx) / half_width) ** 2 + upper ** 2
            inner = ((x - cx) / max(1, half_width - thickness)) ** 2 + upper ** 2
            if outer <= 1.08 and (inner >= 1 or abs(x - cx) >= half_width - thickness):
                if upper > .02:
                    block = int((math.atan2(upper, (x - cx) / half_width) + math.pi) * 3)
                else:
                    block = (z - bottom) // 5
                c = mul(colour, (.96, 1.02, .98, 1.05)[block % 4])
                v.box(x, y, z, x + 1, y + 3, z + 1, c)


def _foliage(v, cx, cy, cz, rx, ry, rz, colour):
    for x in range(cx - rx, cx + rx + 1):
        for y in range(cy - ry, cy + ry + 1):
            for z in range(cz - rz, cz + rz + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1:
                    # Three clean leaf masses, not per-voxel noise.
                    tint = .88 if z < cz - 1 else (1.07 if x + y < cx + cy else 1)
                    v.put(x, y, z, mul(colour, tint))


def _facet(v, cx, cy, bottom, height, radius, colour):
    """A cut octagonal crystal with continuous planar faces and sharp tip."""
    for z in range(bottom, bottom + height):
        t = (z - bottom) / max(1, height - 1)
        r = radius * (.56 + t * 1.46 if t < .30 else (1 - (t - .30) / .70))
        r = max(.45, r)
        for x in range(cx - radius - 1, cx + radius + 2):
            for y in range(cy - radius - 1, cy + radius + 2):
                dx, dy = x + .5 - cx, y + .5 - cy
                if max(abs(dx), abs(dy)) + min(abs(dx), abs(dy)) * .42 <= r:
                    c = mix(colour, (231, 248, 236), .28) if dx + dy < -1 else colour
                    if dx > 0 and dy > 0:
                        c = mul(colour, .85)
                    v.put(x, y, z, c)


def _stairs(v, x, y, width, height, colour):
    for k in range(height):
        v.box(x, y + k, 1, x + width, y + k + 1, height + 1 - k, mul(colour, 1 - .025 * k))


def _balustrade(v, x, y, width, z, colour):
    for px in range(x, x + width, 3):
        v.box(px, y, z, px + 1, y + 1, z + 4, colour)
    v.box(x, y, z + 4, x + width, y + 1, z + 5, colour)


def enrich_native_master(v, rid, wall, roof, trim, accent):
    """Architectural detail is geometry: deep recesses, courses, ribs,
    scaffolds, working hardware and stairs; never soft raster texture."""
    stone = mix(wall, (132, 122, 106), .4)
    # Shared foundations have cut blocks and a short approach stair.
    for x in range(5, 29, 6):
        v.box(x, 25, 2, x + 5, 26, 4, mul(stone, .91))
    _stairs(v, 13, 26, 9, 4, stone)
    if rid == "dawnwater":
        # A visible exterior stair spirals around the masonry. Its open
        # gaps and projecting landings do more work than texture specks.
        for i in range(15):
            a = .4 + i * .39
            x, y = round(17 + 8.2 * math.cos(a)), round(14 + 8.2 * math.sin(a))
            z = 5 + i * 2
            v.box(x - 2, y - 2, z, x + 3, y + 3, z + 1, P["wood"])
            if i % 3 == 0:
                v.box(x + 2, y + 2, z + 1, x + 3, y + 3, z + 5, trim)
        for x, y in ((12, 19), (20, 19), (23, 12)):
            v.box(x, y, 12, x + 2, y + 1, 16, mul(wall, .72))
        for z in (8, 19, 27):
            v.box(14, 20, z, 19, 21, z + 1, mul(wall, .8))
        _balustrade(v, 10, 21, 15, 33, trim)
        kit.crate(v, 26, 22, 4, 5)
    elif rid == "emberreach":
        # Recessed firebox with iron grate, bolted copper bands and three
        # large side ducts establish an industrial silhouette.
        v.clear(11, 20, 5, 24, 28, 16)
        v.box(12, 18, 6, 23, 21, 15, P["fire"], EMIT)
        _arch(v, 17, 24, 4, 9, 18, wall, 3)
        for x in range(12, 24, 3):
            v.box(x, 24, 5, x + 1, 25, 14, P["iron_d"])
        v.box(10, 24, 4, 25, 26, 6, P["iron"])
        for z in (9, 19, 30, 37):
            v.box(10, 10, z, 20, 19, z + 1, trim)
            for x in (10, 18):
                v.box(x, 19, z, x + 1, 20, z + 1, P["steel"])
        v.clear(12, 11, 40, 18, 17, 44)
        for y, h in ((8, 28), (15, 23), (21, 18)):
            _tube(v, (26, y, 5), (30, y, h), 1, roof)
            _tube(v, (30, y, h), (23, y, h), 1, roof)
            v.box(29, y - 2, h - 4, 32, y + 3, h - 3, trim)
        v.box(4, 8, 23, 10, 24, 24, P["iron"])
        _balustrade(v, 4, 24, 7, 24, P["iron_d"])
        for x in (7, 27):
            v.box(x, 25, 4, x + 3, 28, 6, P["iron"])
            v.box(x + 1, 25, 6, x + 2, 27, 8, accent)
    elif rid == "verdant_maw":
        # A raised side gallery, plaited root buttresses and layered leaf
        # canopy give this a shrine's mass rather than a small gate.
        v.box(24, 9, 12, 35, 23, 13, P["wood"])
        for y in (10, 21):
            v.box(32, y, 3, 34, y + 2, 24, trim)
        architectural_roof(v, 23, 8, 12, 16, 24, "stilt", roof, trim)
        _balustrade(v, 25, 23, 10, 13, trim)
        for a, b, c in (((4, 24, 4), (7, 19, 19), (11, 13, 31)),
                        ((30, 24, 4), (25, 20, 18), (22, 15, 31))):
            _tube(v, a, b, 1, P["wood_d"])
            _tube(v, b, c, 1, P["wood_d"])
        _foliage(v, 5, 16, 29, 4, 5, 3, P["green_d"])
        _foliage(v, 23, 7, 35, 7, 5, 3, P["leaf"])
        for x, y in ((8, 23), (29, 25)):
            kit.plant(v, x, y, pot=accent, h=6)
        v.box(27, 22, 17, 29, 24, 20, P["lamp"], EMIT)
    elif rid == "glass_current":
        # Replace the stepped cube spire and curved cap with true cut
        # crystal geometry, an octagonal canopy and brass radial ribs.
        v.clear(0, 0, 23, 36, 32, 62)
        brass = mix(P["brass"], trim, .4)
        for z in range(23, 30):
            radius = 12 - (z - 23) * .7
            for x in range(4, 31):
                for y in range(3, 29):
                    dx, dy = x + .5 - 17, y + .5 - 15
                    if max(abs(dx), abs(dy)) + .42 * min(abs(dx), abs(dy)) <= radius:
                        colour = mix(roof, P["glass"], .25) if dx + dy < 0 else roof
                        v.put(x, y, z, colour)
        for a in range(8):
            angle = a * math.pi / 4
            end = (round(17 + 11 * math.cos(angle)), round(15 + 11 * math.sin(angle)), 24)
            _tube(v, (17, 15, 31), end, 0, brass)
        _facet(v, 17, 15, 28, 20, 5, roof)
        _facet(v, 6, 23, 4, 12, 3, roof)
        _facet(v, 28, 23, 4, 17, 3, roof)
        for x in (9, 24):
            v.box(x, 22, 7, x + 2, 24, 20, wall)
            v.box(x - 1, 21, 19, x + 3, 25, 22, brass)
        _arch(v, 17, 23, 7, 7, 15, wall, 1)
        v.box(16, 24, 16, 18, 25, 19, P["lamp"], EMIT)
        for z in (5, 7):
            v.cyl(17, 15, z, z + 1, 12 + (7 - z), brass)
    elif rid == "crown_shoals":
        # Twin lower wings and a deep three-bay ceremonial arcade make
        # the archive a civic monument. Gold heraldry fronts its tower.
        for x in (1, 27):
            v.box(x, 8, 4, x + 8, 26, 17, wall)
            architectural_roof(v, x, 7, 8, 20, 17, "gable", roof, trim)
            v.box(x + 2, 26, 9, x + 5, 27, 13, P["lamp"], EMIT)
        v.box(6, 22, 15, 29, 28, 16, trim)
        for x in (9, 17, 25):
            _arch(v, x, 26, 4, 4, 12, wall, 1)
        _balustrade(v, 6, 28, 23, 16, trim)
        for x in (9, 17, 25):
            v.box(x - 2, 22, 18, x + 2, 23, 23, trim)
            v.box(x - 1, 23, 19, x + 1, 24, 22, P["lamp"], EMIT)
        # A shaped shield, rather than a text plaque, remains readable.
        v.box(15, 19, 31, 21, 21, 37, roof)
        v.box(16, 19, 29, 20, 21, 31, roof)
        v.box(17, 21, 31, 19, 22, 36, P["brass"])
        v.box(15, 21, 33, 21, 22, 34, P["brass"])
        for x in (3, 30):
            v.box(x, 7, 22, x + 1, 8, 32, trim)
            v.box(x + 1, 7, 27, x + 4, 8, 31, accent)
    elif rid == "stormbelt":
        for z in range(7, 30, 5):
            cx = 15 + (z - 4) // 8
            v.box(cx - 4, 19, z, cx + 3, 21, z + 1, mul(wall, .8))
            v.box(cx + 5, 11, z + 1, cx + 7, 17, z + 2, mul(wall, .91))
        for x in (14, 18, 22):
            v.box(x, 19, 34, x + 1, 21, 41, trim)
        v.box(12, 19, 37, 25, 21, 38, trim)
        v.box(7, 20, 26, 28, 25, 27, P["wood"])
        _balustrade(v, 7, 25, 21, 27, trim)
        for x in (5, 29):
            _tube(v, (x, 25, 4), (18, 14, 31), 0, P["rope"])
        kit.barrel(v, 28, 24, h=5, r=2)
    elif rid == "moonwake":
        # Broad observing balcony with individual rails, a large angled
        # telescope barrel, tripod and a visible glass objective.
        v.box(6, 22, 14, 32, 32, 16, trim)
        _balustrade(v, 6, 31, 26, 16, trim)
        for y in range(23, 32, 3):
            v.box(6, y, 16, 7, y + 1, 20, trim)
            v.box(31, y, 16, 32, y + 1, 20, trim)
        _tube(v, (22, 26, 23), (18, 24, 16), 0, P["iron"])
        _tube(v, (22, 26, 23), (28, 28, 16), 0, P["iron"])
        _tube(v, (22, 26, 23), (21, 31, 16), 0, P["iron"])
        _tube(v, (19, 23, 21), (28, 28, 28), 1, P["brass"])
        v.box(27, 27, 27, 30, 30, 30, P["glass"])
        for x in (10, 22):
            v.box(x, 23, 7, x + 4, 24, 12, trim)
            v.box(x + 1, 24, 8, x + 3, 25, 11, P["lamp"], EMIT)
        for y in (8, 15):
            v.box(27, y, 8, 28, y + 4, 13, trim)
            v.box(28, y + 1, 9, 29, y + 3, 12, P["lamp"], EMIT)
    elif rid == "ashen_trench":
        # The scaffold belongs beside the seal, not across its face.
        # Removing the three blank rails exposes a carved, segmented ring.
        v.clear(2, 19, 6, 33, 24, 29)
        copper = mix(P["brass"], accent, .55)
        # A sealed bronze door fills the ring. Three broad engraved bands
        # and angular radial glyphs express an ancient mechanism without
        # introducing a per-pixel texture or a modern icon/logo.
        for x in range(8, 27):
            for z in range(10, 33):
                rr = ((x - 17) / 8.5) ** 2 + ((z - 21) / 10.5) ** 2
                if rr <= 1:
                    face = mul(copper, .77 if x + z < 36 else .9)
                    if .80 <= rr <= .91 or .35 <= rr <= .44:
                        face = mul(copper, .58)
                    v.box(x, 15, z, x + 1, 18, z + 1, face)
        for a in range(8):
            angle = a * math.tau / 8
            x, z = round(17 + 5.8 * math.cos(angle)), round(21 + 7 * math.sin(angle))
            v.box(x, 18, z - 1, x + 1, 19, z + 2, copper)
            v.box(x - 1, 18, z, x + 2, 19, z + 1, copper)
        v.box(16, 18, 18, 19, 19, 25, trim)
        v.box(14, 18, 20, 21, 19, 23, trim)
        v.box(16, 19, 20, 19, 20, 23, copper)
        for a in range(12):
            angle = a * math.tau / 12
            x, z = round(17 + 10.5 * math.cos(angle)), round(21 + 13 * math.sin(angle))
            if x > 23 and z > 31:
                continue
            v.box(x - 1, 17, z - 1, x + 2, 19, z + 2, trim)
            v.box(x, 19, z - 1, x + 1, 20, z + 2, copper)
            v.box(x - 1, 19, z, x + 2, 20, z + 1, copper)
        for x, y in ((2, 7), (6, 7), (2, 21), (6, 21)):
            v.box(x, y, 4, x + 1, y + 1, 31, P["wood_d"])
        for z in (12, 22, 30):
            v.box(1, 6, z, 8, 23, z + 1, P["wood"])
        for x in (9, 26):
            v.box(x, 23, 4, x + 4, 26, 12, wall)
            v.box(x + 1, 26, 6, x + 2, 27, 10, copper)
            v.box(x, 26, 8, x + 3, 27, 9, copper)
        v.box(17, 17, 7, 20, 20, 12, roof)
    elif rid == "leviathan_ring":
        # Heavy vertebrae, rib feet and coral branches frame the hollow
        # interior. The largest front rib becomes a monumental jaw arch.
        _arch(v, 17, 24, 4, 13, 31, wall, 3)
        for y in (5, 9, 13, 17, 21, 25):
            v.box(15, y, 30, 20, y + 2, 34, trim)
            v.box(16, y, 34, 19, y + 2, 36, wall)
        for x, y in ((5, 24), (28, 24), (6, 13), (28, 13)):
            v.box(x - 1, y, 3, x + 3, y + 3, 8, wall)
        for a, b in (((16, 17, 11), (10, 23, 19)), ((18, 17, 15), (24, 21, 24)),
                     ((17, 18, 12), (23, 26, 16))):
            _tube(v, a, b, 0, accent)
            v.box(b[0] - 1, b[1] - 1, b[2], b[0] + 2, b[1] + 2, b[2] + 2, roof)
        v.box(15, 19, 19, 20, 22, 23, P["glass"])
    else:
        # The armillary has substantial gilded rings, a shaded globe and
        # a sun finial; the ivory colonnade has layered capitals.
        for a in range(120):
            angle = a * math.tau / 120
            x, z = 18 + round(11 * math.cos(angle)), 28 + round(12 * math.sin(angle))
            v.box(x, 14, z, x + 2, 16, z + 2, roof)
            y, z2 = 15 + round(9 * math.cos(angle)), 28 + round(11 * math.sin(angle))
            v.box(17, y, z2, 19, y + 2, z2 + 2, trim)
        for x in range(13, 23):
            for y in range(10, 20):
                for z in range(23, 33):
                    if (x - 18) ** 2 + (y - 15) ** 2 + (z - 28) ** 2 <= 23:
                        colour = accent if x + y < 32 else mul(accent, .8)
                        if (x < 17 and z > 28) or (y < 13 and 25 < z < 28):
                            colour = wall
                        v.put(x, y, z, colour)
        for x, y in ((8, 9), (26, 9), (8, 23), (26, 23)):
            v.box(x - 1, y - 1, 9, x + 3, y + 3, 11, trim)
            v.box(x - 1, y - 1, 21, x + 3, y + 3, 23, roof)
        _balustrade(v, 7, 27, 23, 10, wall)
        for x in (4, 31):
            v.box(x, 10, 4, x + 1, 11, 26, trim)
            v.box(x + 1, 10, 20, x + 4, 11, 25, accent)


def native_master(rid):
    """Ten bespoke monuments rendered with the house/ship pixel renderer.

    AI originals remain preserved concept references. None of their painted
    pixels enter this runtime render: outlines, material faces, occlusion
    and contact shadows are produced by the established native asset kit.
    """
    style, wall_h, roof_h, trim_h, accent_h = ARCHITECTURE[rid]
    wall, roof, trim, accent = map(hexrgb, (wall_h, roof_h, trim_h, accent_h))
    v = Vol(36, 32, 62)
    base = mix(wall, (132, 122, 106), .4)
    v.box(3, 3, 1, 31, 27, 3, mul(base, .85))
    v.box(5, 5, 3, 29, 25, 4, base)

    if rid == "dawnwater":
        # Broken lookout: round masonry, external landings, open lantern
        # cage and blue roof remains. It is not another gabled house.
        v.cyl(17, 14, 4, 32, 6.6, wall)
        for z in (5, 15, 25, 31):
            v.cyl(17, 14, z, z + 1, 7.2, trim)
        for z, x, y in ((9, 10, 18), (16, 22, 16), (23, 16, 6)):
            v.box(x - 3, y - 3, z, x + 4, y + 4, z + 1, P["wood"])
            v.box(x + 3, y - 3, z + 1, x + 4, y + 4, z + 4, trim)
        v.box(16, 20, 6, 19, 22, 13, trim)
        v.box(14, 20, 21, 17, 22, 25, P["lamp"], EMIT)
        v.cyl(17, 14, 32, 34, 8, trim)
        for x, y in ((12, 10), (21, 10), (12, 18), (21, 18)):
            v.box(x, y, 34, x + 1, y + 1, 43, trim)
        v.cyl(17, 14, 35, 39, 3, P["lamp"], EMIT)
        for z in range(43, 47):
            v.cyl(17, 14, z, z + 1, max(1, 7 - 2 * (z - 43)), roof)
        v.clear(17, 6, 43, 27, 13, 49)
        v.box(26, 15, 4, 27, 16, 32, trim)
        v.box(27, 15, 26, 33, 16, 31, accent)
    elif rid == "emberreach":
        # Basalt furnace with open glowing throat, chimney and bent copper
        # ducts. Large material planes stay readable beside the workshop.
        v.box(7, 8, 4, 27, 23, 22, wall)
        v.box(10, 19, 5, 24, 24, 16, trim)
        v.box(12, 20, 6, 22, 25, 14, P["fire"], EMIT)
        _arch(v, 17, 24, 4, 9, 17, wall, 3)
        v.box(8, 9, 22, 26, 22, 25, roof)
        v.box(11, 10, 25, 19, 18, 41, wall)
        v.box(10, 9, 40, 20, 19, 43, trim)
        _tube(v, (23, 12, 27), (28, 12, 27), 1, roof)
        _tube(v, (28, 12, 27), (28, 12, 14), 1, roof)
        _tube(v, (7, 13, 7), (7, 13, 29), 1, roof)
        _tube(v, (7, 13, 29), (12, 13, 29), 1, roof)
        kit.crate(v, 26, 23, 4, 4)
    elif rid == "verdant_maw":
        # A true root-embraced arch, with a small woven shrine shelter
        # behind it. Root limbs describe an asymmetrical branching mass.
        _arch(v, 17, 16, 4, 10, 24, base, 3)
        v.box(7, 7, 4, 26, 15, 16, wall)
        architectural_roof(v, 5, 5, 24, 14, 17, style, roof, trim)
        for path in (((4, 23, 4), (9, 19, 18), (12, 16, 31)),
                     ((30, 23, 4), (25, 18, 20), (20, 16, 32)),
                     ((12, 16, 31), (18, 11, 34), (26, 8, 32))):
            for a, b in zip(path, path[1:]):
                _tube(v, a, b, 1, trim)
        for x, y, z in ((8, 12, 30), (16, 9, 35), (25, 10, 32)):
            _foliage(v, x, y, z, 6, 4, 3, P["green"])
        v.box(16, 20, 17, 18, 22, 21, P["lamp"], EMIT)
    elif rid == "glass_current":
        # An open faceted prism pavilion: ivory columns, blue glass
        # canopy, brass framing and a deliberately planar quartz spire.
        v.cyl(17, 15, 4, 7, 12, wall)
        for x, y in ((8, 11), (17, 6), (26, 11), (8, 21), (26, 21)):
            v.box(x, y, 7, x + 2, y + 2, 23, wall)
            v.box(x - 1, y - 1, 21, x + 3, y + 3, 24, trim)
        for z in range(24, 34):
            r = max(2, 12 - (z - 24))
            v.cyl(17, 15, z, z + 1, r, roof)
            if z in (24, 29):
                v.cyl(17, 15, z, z + 1, r + .8, trim)
        for z in range(31, 46):
            r = max(1, 4 - abs(z - 37) // 3)
            v.box(17 - r, 15 - r, z, 18 + r, 16 + r, z + 1, roof, GLOSS)
        v.box(16, 13, 35, 17, 17, 42, P["glass"], GLOSS)
        v.box(16, 24, 7, 19, 26, 11, trim)
        v.box(14, 25, 4, 21, 28, 6, wall)
    elif rid == "crown_shoals":
        # Archive arcade: broad two-storey facade with deep open arches,
        # a navy roof and a pediment carrying the charter seal.
        v.box(5, 6, 4, 29, 22, 25, wall)
        for x in (9, 17, 25):
            v.clear(x - 2, 18, 4, x + 3, 24, 15)
            _arch(v, x, 21, 4, 4, 12, trim, 1)
            v.box(x - 1, 22, 18, x + 2, 23, 22, P["lamp"], EMIT)
        architectural_roof(v, 3, 4, 28, 20, 25, style, roof, trim)
        v.box(13, 12, 30, 22, 19, 39, wall)
        architectural_roof(v, 12, 11, 11, 9, 39, "gable", roof, trim)
        v.cyl(18, 16, 40, 42, 2, trim)
        for x in (7, 27):
            kit.plant(v, x, 25, pot=accent, h=5)
    elif rid == "stormbelt":
        # Wind-braced lighthouse leans across its terraced buttress. The
        # bright lantern remains a small focal point, never a fuzzy glow.
        for z in range(4, 32):
            cx = 15 + (z - 4) // 8
            v.cyl(cx, 14, z, z + 1, 6.7, wall)
            if z in (10, 21, 30):
                v.cyl(cx, 14, z, z + 1, 7.3, trim)
        for k in range(6):
            v.box(4 + k, 12, 4, 8 + k, 20, 6 + 3 * k, trim)
        v.box(10, 5, 32, 27, 22, 34, trim)
        v.box(13, 8, 34, 24, 19, 41, P["lamp"], EMIT)
        for x, y in ((12, 7), (24, 7), (12, 19), (24, 19)):
            v.box(x, y, 34, x + 1, y + 1, 42, trim)
        architectural_roof(v, 10, 5, 17, 17, 42, "storm", roof, trim)
        _tube(v, (27, 23, 4), (24, 19, 32), 0, P["rope"])
        v.box(28, 12, 13, 29, 13, 32, trim)
        v.box(29, 12, 27, 34, 13, 31, accent)
    elif rid == "moonwake":
        # Observatory: broad indigo hemisphere with an actual open slit,
        # star finial and telescope on a projecting viewing terrace.
        v.cyl(17, 14, 4, 19, 10, wall)
        for z in (5, 16, 18):
            v.cyl(17, 14, z, z + 1, 10.7, trim)
        for z in range(19, 31):
            r = 11 * math.sqrt(max(.01, 1 - ((z - 19) / 12) ** 2))
            v.cyl(17, 14, z, z + 1, r, roof)
        v.clear(17, 13, 19, 20, 27, 33)
        v.box(17, 13, 19, 18, 26, 20, trim)
        v.box(14, 23, 13, 27, 29, 15, trim)
        kit.telescope(v, 19, 23, 15)
        for x in (12, 22):
            v.box(x, 23, 9, x + 2, 24, 12, P["lamp"], EMIT)
        v.box(11, 7, 29, 12, 8, 36, trim)
        v.box(9, 7, 32, 14, 8, 33, accent)
    elif rid == "ashen_trench":
        # A vertical broken sea seal framed by archaeological supports.
        for x in range(4, 31):
            for z in range(4, 38):
                r = ((x - 17) / 12) ** 2 + ((z - 21) / 15) ** 2
                if .58 <= r <= 1.05:
                    v.box(x, 12, z, x + 1, 17, z + 1, wall)
                if .68 <= r <= .78 and (x + z) % 6 < 2:
                    v.box(x, 17, z, x + 1, 18, z + 1, accent, EMIT)
        v.clear(22, 10, 31, 31, 20, 42)
        for x in (4, 29):
            v.box(x, 20, 4, x + 1, 21, 28, trim)
        for z in (10, 18, 26):
            v.box(3, 19, z, 31, 23, z + 1, P["wood"])
        v.box(16, 15, 4, 20, 19, 15, P["iron_d"])
        v.box(17, 18, 11, 19, 20, 13, P["lamp"], EMIT)
    elif rid == "leviathan_ring":
        # Whale-rib vault, coral heart and a clear hollow centre. The
        # seven bone arches have different spans along the spine.
        for y, width, height in ((7, 9, 25), (13, 12, 31), (21, 11, 28)):
            _arch(v, 17, y, 4, width, height, wall, 2)
        _tube(v, (17, 7, 29), (17, 23, 32), 1, trim)
        v.box(15, 14, 4, 19, 18, 22, roof)
        for x, y, z in ((11, 14, 14), (21, 14, 18), (13, 19, 12), (20, 21, 10)):
            _tube(v, (17, 16, 9), (x, y, z), 0, accent)
            v.box(x - 1, y - 1, z, x + 2, y + 2, z + 2, roof)
        v.box(16, 19, 16, 18, 21, 19, P["lamp"], EMIT)
    else:
        # Grand Horizon armillary: nested brass rings on an ivory dais,
        # with four columns. Large negative spaces remain transparent.
        for k in range(3):
            v.box(5 + k * 2, 5 + k * 2, 4 + k * 2, 30 - k * 2, 26 - k * 2, 6 + k * 2, wall)
        for x, y in ((8, 9), (26, 9), (8, 23), (26, 23)):
            v.box(x, y, 9, x + 2, y + 2, 24, wall)
            v.box(x - 1, y - 1, 23, x + 3, y + 3, 25, trim)
        v.cyl(18, 15, 9, 17, 3, trim)
        for a in range(96):
            angle = a * math.tau / 96
            x, z = 18 + round(10 * math.cos(angle)), 28 + round(11 * math.sin(angle))
            v.box(x, 14, z, x + 1, 16, z + 1, roof, GLOSS)
            y = 15 + round(8 * math.cos(angle))
            z2 = 28 + round(10 * math.sin(angle))
            v.box(17, y, z2, 19, y + 1, z2 + 1, trim, GLOSS)
        v.cyl(18, 15, 26, 29, 4, accent)
        v.box(17, 14, 39, 19, 16, 44, roof)
        v.box(15, 14, 41, 21, 16, 42, roof)
    enrich_native_master(v, rid, wall, roof, trim, accent)
    pixels, _ = vol_sprite(v, (18, 16, 1))
    return Image.fromarray(pixels)


class Vignette:
    """Compose depth-ordered native pieces around a single contact origin.

    No source images are destructively edited. Components retain their
    original anchors, are resized only by nearest-neighbour sampling, and
    are composed behind playable paths as one small background vignette.
    """

    def __init__(self, rid, env, props, buildings, palette):
        self.rid, self.env = rid, env
        self.props, self.buildings = props, buildings
        self.palette = palette
        self.image = Image.new("RGBA", (144, 150))
        self.draw = ImageDraw.Draw(self.image)
        self.layers = []
        self.sources = []

    def pad(self, form="stone"):
        land = hexrgb(self.palette["land"])
        grass = hexrgb(self.palette["grass"])
        sea = hexrgb(self.palette["sea"])
        top = mix(land, grass, 0.18) if form == "garden" else mix(land, (169, 156, 135), 0.35)
        if form == "wood":
            top = (151, 110, 76)
        edge = mul(top, 0.65)
        self.draw.polygon([(6, 123), (70, 99), (138, 123), (72, 148)], fill=edge)
        self.draw.polygon([(6, 119), (70, 95), (138, 119), (72, 144)], fill=top)
        if form == "wood":
            for k in range(1, 8):
                x = 6 + 8 * k
                self.draw.line((x, 119 - 3 * k, x + 66, 144 - 3 * k), fill=mul(top, 0.86))
        elif form in ("pool", "spring"):
            self.draw.ellipse((34, 112, 108, 137), fill=mul(top, 0.73))
            self.draw.ellipse((38, 113, 104, 133), fill=mix(sea, (147, 219, 203), 0.45))
            self.draw.arc((42, 116, 98, 130), 20, 165, fill=(191, 229, 214), width=1)
        elif form == "dais":
            for inset, lift in ((0, 0), (10, -3), (20, -6)):
                self.draw.polygon([(18 + inset, 119 + lift), (70, 101 + lift + inset // 3),
                                   (126 - inset, 119 + lift), (72, 138 + lift - inset // 3)],
                                  fill=mix(top, (231, 216, 178), inset / 65), outline=edge)

    def piece(self, name, x=72, y=129, scale=1.0, flip=False):
        building = name.startswith("building:")
        name = name.removeprefix("building:")
        table = self.env["buildings" if building else "props"]
        key = f"{self.rid}:{name}" if f"{self.rid}:{name}" in table else name
        if key not in table:
            raise KeyError(f"Missing vignette component {self.rid}:{name}")
        meta = table[key]
        px, py, w, h = meta["rect"]
        sprite = (self.buildings if building else self.props).crop((px, py, px + w, py + h))
        anchor = meta["anchor"]
        if scale != 1:
            sprite = sprite.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.NEAREST)
        ax, ay = round(anchor[0] * scale), round(anchor[1] * scale)
        if flip:
            sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            ax = sprite.width - ax
        self.layers.append((y, sprite, (round(x - ax), round(y - ay))))
        self.sources.append(("buildings:" if building else "props:") + key)

    def master(self, sprite, scale=1.0, x=72, y=140):
        factor = min(1, 132 / sprite.width, 136 / sprite.height) * scale
        sprite = sprite.resize((max(1, round(sprite.width * factor)), max(1, round(sprite.height * factor))),
                               Image.Resampling.NEAREST)
        self.layers.append((y - 16, sprite, (round(x - sprite.width / 2), round(y - sprite.height))))
        self.sources.append(f"native-voxel-landmark:{self.rid}")

    def finish(self):
        for _, sprite, pos in sorted(self.layers, key=lambda layer: layer[0]):
            self.image.alpha_composite(sprite, pos)
        # The opaque native kit and thresholded master share hard alpha.
        alpha = self.image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        self.image.putalpha(alpha)
        return self.image


# Eight native compositions per sea, explicitly arranged for the named
# locations in world.locationIds order. Slots 0 and 5 use the bespoke native
# regional monument, while these local recipes match the actual site purpose.
# Each tuple is (component, contactX, contactY, scale[, mirror]).
RECIPES = {
    "dawnwater": {
        1: ("wood", [("building:market", 66, 132, .83), ("rack", 112, 136, 1), ("sacks", 24, 134, 1)]),
        2: ("stone", [("sea_stack", 43, 128, 1.9), ("sea_stack", 92, 119, 1.3), ("flag", 105, 139, .7)]),
        3: ("garden", [("building:house", 77, 130, .78), ("lamp", 28, 135, 1.2), ("herb", 113, 133, 1.2)]),
        4: ("pool", [("coral", 37, 132, 2), ("rock_big", 87, 117, 1.7), ("coral", 108, 141, 1.2)]),
        6: ("stone", [("ruin_arch", 72, 119, 1.3), ("barrels", 43, 137, 1.3), ("sacks", 107, 140, 1.1), ("chest", 77, 139, 1)]),
        7: ("wood", [("wreck_hull", 71, 133, 1.4), ("mast_fallen", 102, 139, 1), ("crate", 29, 141, 1)]),
        8: ("dais", [("standard", 29, 129, 1), ("standard", 111, 129, 1), ("statue", 71, 118, 1.1), ("lamp", 80, 141, .7)]),
        9: ("spring", [("rock_big", 52, 117, 1.7), ("reeds", 108, 136, 1.6), ("nest", 38, 139, 1.2)]),
    },
    "emberreach": {
        1: ("wood", [("building:workshop", 73, 133, .87), ("sacks", 32, 141, 1.2), ("brazier", 113, 141, .9)]),
        2: ("stone", [("rock_big", 47, 126, 2.1), ("stalagmite", 89, 126, 1.8), ("ore", 108, 143, 1.2)]),
        3: ("stone", [("obelisk", 55, 125, 1.2), ("brazier", 97, 133, 1.6), ("ore", 35, 141, 1.4)]),
        4: ("pool", [("crystal", 43, 123, 1.7), ("sea_rock", 104, 136, 1.8), ("ore", 75, 142, 1.2)]),
        6: ("stone", [("building:workshop", 75, 129, .83), ("brazier", 38, 139, 1.2), ("barrels", 111, 141, 1)]),
        7: ("wood", [("ribs", 72, 132, 1.8), ("mast_fallen", 44, 138, 1.1), ("campfire", 109, 143, 1)]),
        8: ("dais", [("brazier", 31, 135, 1.3), ("gate", 75, 120, 1.3), ("brazier", 114, 135, 1.3)]),
        9: ("spring", [("rock_big", 49, 119, 1.8), ("nest", 75, 129, 1.8), ("ore", 112, 140, 1.2)]),
    },
    "verdant_maw": {
        1: ("wood", [("building:market", 79, 133, .81), ("tree_b", 28, 126, 1.2), ("reeds", 111, 140, 1.3)]),
        2: ("garden", [("ruin_arch", 72, 125, 1.5), ("tree_b", 29, 137, .95), ("herb", 113, 139, 1.3)]),
        3: ("spring", [("mushroom", 35, 129, 1.8), ("herb", 97, 119, 1.8), ("bush", 112, 140, 1.5)]),
        4: ("garden", [("dead_tree", 53, 124, 1.5), ("ruin_arch", 86, 132, 1), ("bones", 39, 142, 1.2)]),
        6: ("pool", [("stalagmite", 37, 125, 1.8), ("tree_b", 95, 129, 1.5), ("mushroom", 68, 141, 1.3)]),
        7: ("garden", [("wreck_hull", 73, 131, 1.35), ("tree_b", 34, 128, 1.1), ("bush", 110, 142, 1.5)]),
        8: ("dais", [("gate", 72, 121, 1.5), ("herb", 31, 138, 1.7), ("mushroom", 109, 140, 1.3)]),
        9: ("garden", [("tree_b", 64, 125, 2), ("lair_nest", 73, 138, 1.7), ("mushroom", 112, 141, 1.1)]),
    },
    "glass_current": {
        1: ("wood", [("building:market", 69, 133, .85), ("crystal", 114, 135, .9), ("lamp", 23, 135, 1)]),
        2: ("pool", [("crystal", 38, 129, 1.4), ("crystal", 82, 119, 2), ("ore", 112, 142, 1.4)]),
        3: ("dais", [("gate", 70, 126, 1.6), ("crystal", 32, 140, .9), ("lamp", 110, 139, .9)]),
        4: ("stone", [("crystal", 55, 133, 2.6), ("pillar_broken", 112, 138, 1.4), ("ore", 30, 142, 1)]),
        6: ("stone", [("gate", 48, 123, 1.15), ("ruin_arch", 96, 135, 1.15), ("crystal", 28, 143, .8)]),
        7: ("pool", [("ribs", 67, 133, 1.6), ("crystal", 107, 139, 1.7), ("mast_fallen", 36, 141, .9)]),
        8: ("dais", [("pillar", 32, 125, 1.5), ("obelisk", 77, 123, 1.15), ("pillar", 114, 133, 1)]),
        9: ("spring", [("reeds", 32, 133, 1.6), ("crystal", 87, 119, 1.8), ("nest", 97, 140, 1.4)]),
    },
    "crown_shoals": {
        1: ("wood", [("building:market", 71, 131, .9), ("barrels", 29, 141, 1), ("flag", 113, 140, .75)]),
        2: ("dais", [("statue", 72, 123, 1.7), ("pillar_broken", 30, 139, 1), ("herb", 112, 139, 1.4)]),
        3: ("garden", [("building:house", 79, 124, .76), ("reeds", 28, 136, 1.6), ("lamp", 111, 140, .8)]),
        4: ("stone", [("pillar", 33, 131, 1.7), ("ruin_arch", 89, 128, 1.4), ("statue", 112, 142, .9)]),
        6: ("stone", [("ruin_arch", 73, 120, 1.5), ("statue", 39, 139, 1.2), ("chest", 103, 141, 1.2)]),
        7: ("wood", [("wreck_hull", 73, 130, 1.35), ("chest", 31, 141, 1.5), ("gold", 101, 143, 1.7)]),
        8: ("dais", [("standard", 33, 126, 1.15), ("statue", 72, 119, 1.3), ("standard", 111, 136, 1)]),
        9: ("spring", [("statue", 70, 116, 1.5), ("herb", 30, 137, 1.2), ("crystal", 109, 139, .9)]),
    },
    "stormbelt": {
        1: ("stone", [("building:tavern", 71, 131, .8), ("lamp", 29, 138, 1.2), ("barrels", 111, 142, 1)]),
        2: ("stone", [("stalagmite", 52, 129, 2.1), ("sea_stack", 102, 139, 1.5), ("rock", 29, 143, 1.3)]),
        3: ("wood", [("mast_fallen", 68, 135, 1.6), ("flag", 45, 121, 1.2), ("rack", 108, 140, 1)]),
        4: ("stone", [("obelisk", 72, 123, 1.4), ("pillar_broken", 29, 139, 1.2), ("lamp", 111, 139, 1.2)]),
        6: ("pool", [("ruin_arch", 68, 121, 1.6), ("stalagmite", 112, 141, 1.1), ("barrels", 35, 140, 1)]),
        7: ("wood", [("wreck_hull", 74, 130, 1.3), ("mast_fallen", 35, 138, 1.2), ("flag", 106, 139, .7)]),
        8: ("dais", [("standard", 33, 132, 1.1), ("barrier", 74, 130, 1.6), ("brazier", 113, 139, 1.1)]),
        9: ("garden", [("ruin_arch", 72, 123, 1.45), ("lair_nest", 75, 140, 1.7), ("reeds", 26, 140, 1.4)]),
    },
    "moonwake": {
        1: ("wood", [("building:tavern", 73, 130, .84), ("lamp", 26, 139, 1.3), ("herb", 113, 142, 1.1)]),
        2: ("garden", [("tree_b", 65, 124, 1.7), ("lamp", 29, 139, 1.1), ("herb", 111, 139, 1.5)]),
        3: ("pool", [("gate", 72, 123, 1.5), ("lamp", 32, 137, 1), ("rock_big", 109, 140, 1.3)]),
        4: ("pool", [("crystal", 73, 119, 1.9), ("rock_big", 32, 140, 1.4), ("ore", 109, 143, 1.5)]),
        6: ("stone", [("gate", 47, 126, 1.3), ("pillar", 106, 130, 1.5), ("lamp", 77, 141, 1)]),
        7: ("wood", [("wreck_hull", 72, 132, 1.4), ("lamp", 32, 137, 1.1), ("mast_fallen", 110, 141, .8)]),
        8: ("dais", [("standard", 32, 129, 1.1), ("gate", 75, 122, 1.2), ("standard", 112, 139, 1)]),
        9: ("garden", [("tree_b", 44, 128, 1.7), ("mushroom", 101, 127, 1.6), ("lamp", 86, 141, 1.2), ("nest", 34, 143, 1)]),
    },
    "ashen_trench": {
        1: ("wood", [("building:workshop", 71, 131, .83), ("rack", 113, 139, 1), ("lamp", 29, 139, 1.2)]),
        2: ("stone", [("rock_big", 50, 127, 1.9), ("pillar_broken", 98, 124, 1.7), ("bones", 98, 142, 1.2)]),
        3: ("stone", [("ruin_arch", 72, 122, 1.5), ("stalagmite", 111, 142, 1.1), ("rock_big", 32, 143, 1.1)]),
        4: ("wood", [("barrier", 70, 122, 1.9), ("pillar", 32, 136, 1.6), ("lamp", 111, 139, 1.1)]),
        6: ("dais", [("obelisk", 72, 120, 1.45), ("rack", 29, 138, 1.3), ("lamp", 112, 139, 1.3)]),
        7: ("wood", [("wreck_hull", 69, 134, 1.3), ("rack", 105, 123, 1.5), ("crate", 29, 143, 1.3)]),
        8: ("dais", [("gate", 73, 121, 1.45), ("brazier", 30, 139, 1.2), ("obelisk", 110, 137, .9)]),
        9: ("spring", [("stalagmite", 42, 126, 1.9), ("lair_nest", 83, 140, 1.8), ("brazier", 112, 141, 1)]),
    },
    "leviathan_ring": {
        1: ("wood", [("building:house", 70, 126, .85), ("bones", 29, 139, 1.4), ("flag", 112, 139, .8)]),
        2: ("stone", [("bones", 45, 128, 2), ("sea_stack", 91, 122, 1.8), ("coral", 112, 141, 1.3)]),
        3: ("stone", [("ribs", 71, 130, 1.8), ("bones", 30, 142, 1.3), ("coral", 113, 142, 1.4)]),
        4: ("pool", [("bone_pile", 48, 126, 1.8), ("ribs", 98, 137, 1.25), ("coral", 30, 141, 1.4)]),
        6: ("pool", [("ruin_arch", 73, 123, 1.45), ("coral", 30, 139, 1.8), ("crystal", 111, 139, 1.2)]),
        7: ("wood", [("wreck_hull", 73, 131, 1.4), ("bones", 31, 142, 1.4), ("coral", 111, 142, 1.4)]),
        8: ("dais", [("ribs", 74, 125, 1.8), ("lamp", 30, 138, 1.1), ("lamp", 112, 138, 1.1)]),
        9: ("spring", [("coral", 40, 125, 2.2), ("lair_nest", 80, 139, 1.8), ("coral", 112, 139, 1.3)]),
    },
    "grand_horizon": {
        1: ("stone", [("building:navigation", 73, 130, .8), ("standard", 29, 140, .85), ("statue", 112, 141, 1)]),
        2: ("dais", [("statue", 72, 123, 1.7), ("pillar_broken", 30, 137, 1.3), ("herb", 112, 139, 1.4)]),
        3: ("stone", [("ruin_arch", 72, 123, 1.6), ("obelisk", 30, 138, .9), ("crystal", 112, 140, 1)]),
        4: ("pool", [("crystal", 70, 120, 1.8), ("statue", 30, 137, 1.2), ("sea_rock", 110, 141, 1.5)]),
        6: ("dais", [("obelisk", 72, 119, 1.5), ("pillar", 29, 137, 1.3), ("crystal", 112, 139, 1.4)]),
        7: ("wood", [("wreck_hull", 72, 132, 1.4), ("standard", 31, 138, .85), ("chest", 109, 141, 1.4)]),
        8: ("dais", [("statue", 73, 117, 1.5), ("standard", 29, 136, 1.1), ("standard", 113, 136, 1.1), ("gold", 74, 141, 1.8)]),
        9: ("spring", [("crystal", 40, 123, 1.8), ("lair_nest", 82, 137, 1.7), ("lamp", 112, 139, 1.1)]),
    },
}


def build():
    manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    world = json.loads((GAME / "data" / "world.json").read_text(encoding="utf-8"))
    profiles = json.loads((GAME / "data" / "scene_profiles.json").read_text(encoding="utf-8"))
    env = json.loads((OUT / "env" / "env.json").read_text(encoding="utf-8"))
    props = Image.open(OUT / "env" / "props.png").convert("RGBA")
    buildings = Image.open(OUT / "env" / "buildings.png").convert("RGBA")
    regions = {r["id"]: r for r in world["REGIONS"]}
    pack = Packer(1024, pad=3)
    preview = Image.new("RGBA", (1600, 1800), "#17384a")
    draw = ImageDraw.Draw(preview)
    rows = {}
    variants = {}
    style_comparison = Image.new("RGBA", (1440, 340), "#17384a")
    for i, rid in enumerate(REGIONS):
        path = SOURCE / f"{rid}.png"
        sprite = native_master(rid)
        rows[rid] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                     "sourceRole": "AI concept reference only; no source pixels shipped",
                     "runtimeMethod": "bespoke native voxel render",
                     "nativeSize": list(sprite.size), "anchor": [sprite.width // 2, sprite.height - 3]}
        # Native-grid before/after pairs (4x nearest-neighbour), so a review
        # can assess actual pixel structure rather than a smoothed thumbnail.
        pair = Image.new("RGBA", (288, 170), "#17384a")
        before = concept_preview(path)
        pair.alpha_composite(before, ((144 - before.width) // 2, 150 - before.height))
        scaled = sprite
        if sprite.width > 132 or sprite.height > 136:
            factor = min(132 / sprite.width, 136 / sprite.height)
            scaled = sprite.resize((round(sprite.width * factor), round(sprite.height * factor)), Image.Resampling.NEAREST)
        pair.alpha_composite(scaled, (144 + (144 - scaled.width) // 2, 150 - scaled.height))
        pd = ImageDraw.Draw(pair)
        pd.text((4, 154), "before: raster", fill="#efe3c2")
        pd.text((148, 154), "after: native voxel", fill="#efe3c2")
        PREVIEW.mkdir(parents=True, exist_ok=True)
        pair.resize((1152, 680), Image.Resampling.NEAREST).save(PREVIEW / f"landmark_style_{rid}_4x.png")
        style_comparison.alpha_composite(pair, ((i % 5) * 288, (i // 5) * 170))
        for slot, loc_id in enumerate(regions[rid]["locationIds"]):
            vignette = Vignette(rid, env, props, buildings, regions[rid]["palette"])
            if slot in (0, 5):
                vignette.pad("wood" if slot == 0 else "stone")
                vignette.master(sprite, .87 if slot == 0 else 1)
                if slot == 0:
                    vignette.piece("barrels", 29, 139, 1.1)
                    vignette.piece("flag", 115, 139, .7)
                else:
                    vignette.piece("rock_big", 25, 140, 1.1)
                    vignette.piece("brazier", 116, 141, .8)
            else:
                form, recipe = RECIPES[rid][slot]
                vignette.pad(form)
                for component in recipe:
                    vignette.piece(*component)
            final = vignette.finish()
            key = f"{rid}:{slot}"
            profile = profiles["locations"][loc_id]
            pack.add(key, np.asarray(final), anchor=[72, 142], footprint=[144, 64],
                     locationId=loc_id, motif=profile["landmark"],
                     source="native-voxel-landmark+native-kit" if slot in (0, 5) else "native-authored-kit",
                     depthMode="background")
            variants[key] = {"locationId": loc_id, "motif": profile["landmark"],
                             "sources": vignette.sources,
                             "sha256": hashlib.sha256(final.tobytes()).hexdigest()}
            x, y = slot * 160, i * 180
            preview.alpha_composite(final, (x + 8, y + 2))
            draw.text((x + 5, y + 155), loc_id, fill="#f0e5cc")
    target = OUT / "env" / "landmarks.png"
    rects, size = pack.pack(target)
    # Region-only access remains compatible with older views; new views
    # request location variants. Aliases do not duplicate atlas pixels.
    for rid in REGIONS:
        rects[rid] = dict(rects[f"{rid}:0"])
    save_json({"version": 2, "landmarks": rects}, target.with_suffix(".json"))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW / "world_landmarks.png")
    for i, rid in enumerate(REGIONS):
        preview.crop((0, i * 180, 1600, (i + 1) * 180)).save(PREVIEW / f"landmarks_{rid}.png")
    style_comparison.resize((5760, 1360), Image.Resampling.NEAREST).save(PREVIEW / "landmarks_style_comparison_4x.png")
    manifest["packed"] = rows
    manifest["compiledVariants"] = variants
    manifest["production"] = (
        "All ten generated originals are preserved as concept references only. "
        "Runtime landmarks are bespoke native voxel/pixel models in tools/artgen/gen_landmarks.py, "
        "rendered with the same hard-edged material/outline/occlusion pipeline as houses and ships. "
        "One hundred location vignettes combine these native models with original native prop/building kit pieces. "
        "No AI raster pixels are packed into the runtime atlas. Rebuilds never call image generation.")
    manifest["runtimeRasterOrigin"] = "original code-authored native voxel and pixel art"
    for asset in manifest.get("assets", {}).values():
        asset["usage"] = "preserved concept reference, excluded from runtime atlas"
    (SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    record("game/assets/gen/env/landmarks.png", f"{size[0]}x{size[1]}", "100 location vignettes + 10 metadata aliases",
           "10 bespoke native voxel monuments + native kit; AI concepts retained as references (gen_landmarks.py)",
           "Location-specific harbor, island, dungeon, wreck, trial and secret landmarks",
           "Solid backdrop scenery; paths and battle band reserved outside footprint")
    print("[landmarks] 10 bespoke native voxel monuments + native kit -> 100 location-specific vignettes; AI concepts preserved")


if __name__ == "__main__":
    build()
