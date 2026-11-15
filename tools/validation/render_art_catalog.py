"""Draw offline composition contact sheets from the presentation catalogue.

These diagrams are authoring guides, NOT runtime screenshots, terrain-mask
renders or navigation tests. They show profile coordinates, existing room
connections, coast shaping guides and the reserved landmark foot rectangle.
No engine, game instance, audio device or test suite is started.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PAPER = "#efe6d0"
DIM = "#b5c5c3"
NAVY = "#172d3c"
BRASS = "#dfc58b"
ROUTE = "#f4e6b2"
LANDMARK = "#f8b576"
FIGHT = (-236, -60, 566, 124)
SERVICE_SHORT = {"market": "MKT", "tavern": "INN", "workshop": "WRK",
                 "quest_board": "JOB", "house": "HSE", "navigation": "NAV"}


def font(size: int, mono: bool = False):
    paths = (["C:/Windows/Fonts/consola.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]
             if mono else ["C:/Windows/Fonts/segoeui.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"])
    for path in paths:
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


FONTS = {n: font(n) for n in (10, 11, 12, 13, 14, 17, 21, 25)}


def rgb(value):
    return ImageColor.getrgb(value)


def mix(a, b, t):
    a, b = rgb(a) if isinstance(a, str) else a, rgb(b) if isinstance(b, str) else b
    return tuple(round(x * (1 - t) + y * t) for x, y in zip(a, b))


def fit_text(draw, text, width, size=12):
    f = FONTS[size]
    if draw.textlength(text, font=f) <= width:
        return text
    while text and draw.textlength(text + "…", font=f) > width:
        text = text[:-1]
    return text + "…"


def text(draw, xy, value, size=12, fill=PAPER, width=None):
    if width is not None:
        value = fit_text(draw, value, width, size)
    draw.text(xy, value, font=FONTS[size], fill=fill)


class Plot:
    def __init__(self, draw, rect, points, pad=10):
        self.draw, self.rect = draw, rect
        xs, ys = [p[0] for p in points], [p[1] for p in points]
        lo, hi = (min(xs), min(ys)), (max(xs), max(ys))
        self.scale = min((rect[2] - rect[0] - pad * 2) / max(1, hi[0] - lo[0]),
                         (rect[3] - rect[1] - pad * 2) / max(1, hi[1] - lo[1]))
        self.centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)

    def p(self, value):
        x, y = value
        return ((self.rect[0] + self.rect[2]) / 2 + (x - self.centre[0]) * self.scale,
                (self.rect[1] + self.rect[3]) / 2 + (y - self.centre[1]) * self.scale)

    def line(self, a, b, fill=ROUTE, width=2):
        self.draw.line([self.p(a), self.p(b)], fill=fill, width=width)

    def box(self, centre, dimensions, fill=None, outline=LANDMARK):
        w, h = dimensions
        x, y = centre
        self.draw.rectangle([self.p((x - w / 2, y - h / 2)), self.p((x + w / 2, y + h / 2))],
                            fill=fill, outline=outline, width=2)

    def dot(self, p, color, label=""):
        x, y = self.p(p)
        self.draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill=color, outline=NAVY)
        if label:
            text(self.draw, (x + 5, y - 6), label, 10)


def shape_bounds(shapes):
    points = []
    for x, y, radius in shapes:
        # An isometric cell-space disk projects to this ellipse. This is a
        # shaping guide only; Coast's noisy final land mask is not simulated.
        rx, ry = math.sqrt(2) * 16 * radius, math.sqrt(2) * 8 * radius
        points += [(x - rx, y - ry), (x + rx, y + ry)]
    return points


def shape_guides(plot, profile, palette):
    for key in ("lobes", "cuts"):
        for x, y, radius in profile.get("coast", {}).get(key, []):
            rx, ry = math.sqrt(2) * 16 * radius, math.sqrt(2) * 8 * radius
            fill = mix(palette["deep"], palette["grass"], 0.5) if key == "lobes" else rgb(palette["deep"])
            outline = mix(palette["grass"], PAPER, 0.4) if key == "lobes" else mix(palette["sea"], PAPER, 0.3)
            plot.draw.ellipse([plot.p((x - rx, y - ry)), plot.p((x + rx, y + ry))],
                              fill=fill, outline=outline, width=1)


def draw_port(draw, rect, rec, palette):
    # Reference terrain span of 32 cells = 16 current ship cells. Live ports
    # derive this span from the actual hull and retain the same service order.
    def iso(x, y):
        return ((x - y) * 16, (x + y) * 8)
    port = rec["port"]
    order, setbacks = port["order"], port["setbacks"]
    frontage = [iso(1 + i * 5, setbacks[i]) for i in range(len(order))]
    ship = [iso(0, 0), iso(32, 0), iso(32, 12), iso(0, 12)]
    quay = [iso(-3, -5), iso(35, -5), iso(35, -3), iso(-3, -3)]
    lm_offset = port.get("landmarkOffset", [0, -140])
    mid = iso(16, -13)
    landmark = [mid[0] + lm_offset[0], mid[1] + lm_offset[1]]
    plot = Plot(draw, rect, ship + quay + frontage + [landmark, (landmark[0], landmark[1] - 70)])
    draw.polygon([plot.p(p) for p in quay], fill=mix(palette["land"], NAVY, 0.25), outline=BRASS)
    draw.polygon([plot.p(p) for p in ship], fill=mix("#ba8650", NAVY, 0.18), outline=BRASS)
    p = plot.p(iso(16, 6))
    text(draw, (p[0] - 30, p[1] - 6), "reference hull", 10)
    plot.box(landmark, rec.get("landmarkFootprint", [100, 36]))
    for i, at in enumerate(frontage):
        plot.box(at, [68, 42], fill=mix(palette["land"], PAPER, 0.2), outline=NAVY)
        px = plot.p(at)
        text(draw, (px[0] - 10, px[1] - 5), SERVICE_SHORT[order[i]], 10, NAVY)
    text(draw, (rect[0] + 4, rect[3] - 13), "Reference berth; live width follows selected hull", 10, DIM)


def location_card(loc_id, rec, loc, world, palette):
    image = Image.new("RGB", (340, 280), NAVY)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 339, 279), outline="#536b75", width=1)
    text(draw, (10, 7), loc_id, 14, PAPER, 320)
    text(draw, (10, 29), loc["type"] + " / " + rec["compositionId"].split(":", 1)[-1], 11, BRASS, 320)
    rect = (10, 51, 330, 224)
    draw.rectangle(rect, fill=mix(palette["deep"], NAVY, 0.25))
    if loc["type"] == "port":
        draw_port(draw, rect, rec, palette)
    else:
        nodes = rec["nodes"]
        lm = rec["landmarkPosition"]
        foot = rec.get("landmarkFootprint", [100, 36])
        shapes = rec.get("coast", {})
        points = list(nodes.values()) + shape_bounds(shapes.get("lobes", []) + shapes.get("cuts", []))
        points += [(lm[0] - foot[0] / 2, lm[1] - foot[1] / 2),
                   (lm[0] + foot[0] / 2, lm[1] + foot[1] / 2)]
        plot = Plot(draw, rect, points, pad=14)
        shape_guides(plot, rec, palette)
        rooms = world["ROOM_TEMPLATES"].get(loc["type"], [])
        if rooms:
            plot.line(nodes["_landing"], nodes[rooms[0]["id"]], mix(ROUTE, palette["sea"], 0.3))
        for room in rooms:
            for target in room.get("next", []):
                plot.line(nodes[room["id"]], nodes[target])
        plot.box(lm, foot)
        for key, at in nodes.items():
            label = "boat" if key == "_landing" else key
            plot.dot(at, "#a9ddaa" if key == "_landing" else PAPER, label)
        for name, x, y, _ in rec.get("setPieces", []):
            px, py = plot.p((x, y))
            draw.rectangle((px - 1, py - 1, px + 1, py + 1), fill=BRASS)
    text(draw, (10, 232), "Landmark: " + rec["landmark"].replace("_", " "), 12, LANDMARK, 320)
    text(draw, (10, 252), "Guides only · connections from world.json", 11, DIM, 320)
    return image


def battle_card(key, rec, palette):
    image = Image.new("RGB", (340, 218), NAVY)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 339, 217), outline="#536b75", width=1)
    text(draw, (10, 7), key, 13, PAPER, 320)
    text(draw, (10, 28), rec["tier"] + " / " + rec.get("motif", ""), 11, BRASS, 320)
    rect = (10, 50, 330, 172)
    draw.rectangle(rect, fill=mix(palette["deep"], NAVY, 0.35))
    lm = rec["landmarkOffset"]
    plot = Plot(draw, rect, [(-350, -205), (420, 95), lm], pad=10)
    # Safe fight band is the current ArenaScene FIGHT rectangle, not a claim
    # that an offline diagram exercises the combat camera or spawn paths.
    x, y, w, h = FIGHT
    plot.box((x + w / 2, y + h / 2), (w, h), fill=mix(palette["grass"], NAVY, 0.55), outline="#a7d694")
    plot.line((-236, 14), (330, 14), fill="#b8d9b2")
    plot.box(lm, rec.get("landmarkFootprint", [100, 36]))
    plot.dot((-180, 0), "#8cc5df", "crew")
    plot.dot((230, 0), "#ef967c", "foes")
    for name, px, py, _ in rec.get("setPieces", []):
        plot.dot((px, py), BRASS)
    text(draw, (14, 153), "green: clear fight band / orange: landmark feet", 10, DIM)
    text(draw, (10, 180), rec["landmark"].replace("_", " "), 12, LANDMARK, 320)
    text(draw, (10, 199), "Static profile diagram; not a rendered arena", 10, DIM, 320)
    return image


def contact_sheet(world, profiles, battle=False):
    regions = world["REGIONS"]
    columns, gap, margin, region_header = 5, 9, 18, 44
    card_w, card_h = (340, 218 if battle else 280)
    counts = []
    for region in regions:
        rid = region["id"]
        records = profiles["battleRooms"] if battle else profiles["locations"]
        counts.append(sum(rec["regionId"] == rid for rec in records.values()))
    height = 112 + sum(region_header + math.ceil(n / columns) * (card_h + gap) + 16 for n in counts) + 24
    width = margin * 2 + columns * card_w + (columns - 1) * gap
    image = Image.new("RGB", (width, height), "#10222f")
    draw = ImageDraw.Draw(image)
    title = "Layout catalogue — not runtime screenshots"
    text(draw, (margin, 16), title, 25)
    count = len(profiles["battleRooms"] if battle else profiles["locations"])
    text(draw, (margin, 52), f"{count} {'battle contexts' if battle else 'location compositions'} · ten seas · profile coordinates and authoring guides", 17, BRASS)
    text(draw, (margin, 80), "No engine or game instance used. Pale lines: room links. Coast ellipses: shape guides. Orange: reserved landmark footprint.", 14, DIM)
    y = 112
    for region, count in zip(regions, counts):
        rid, palette = region["id"], region["palette"]
        draw.rectangle((margin, y, width - margin, y + 32), fill=mix(palette["deep"], NAVY, 0.35))
        text(draw, (margin + 9, y + 4), rid.upper().replace("_", " ") + f"   /   {count} {'battles' if battle else 'places'}", 17, PAPER)
        text(draw, (margin + 600, y + 8), profiles["regions"][rid]["architecture"].replace("_", " "), 13, BRASS)
        y += region_header
        records = profiles["battleRooms"] if battle else profiles["locations"]
        records = [(key, rec) for key, rec in records.items() if rec["regionId"] == rid]
        for i, (key, rec) in enumerate(records):
            card = battle_card(key, rec, palette) if battle else location_card(key, rec, world["LOCATIONS"][key], world, palette)
            image.paste(card, (margin + (i % columns) * (card_w + gap), y + (i // columns) * (card_h + gap)))
        y += math.ceil(count / columns) * (card_h + gap) + 16
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "art/previews")
    args = parser.parse_args()
    world = json.loads((ROOT / "game/data/world.json").read_text(encoding="utf-8"))
    profiles = json.loads((ROOT / "game/data/scene_profiles.json").read_text(encoding="utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    for battle, name in ((False, "world-art-location-layouts.png"), (True, "world-art-battle-layouts.png")):
        path = args.out / name
        result = contact_sheet(world, profiles, battle)
        result.save(path, optimize=True)
        print(f"Offline layout catalogue: {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path} ({result.width}x{result.height})")


if __name__ == "__main__":
    main()
