"""UI art: 9-slice theme pieces, 16px icon set, selection/placement diamonds,
emote bubbles, FX sprite strips, mouse cursor and the application icon."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from lib.common import GAME, OUT, PREVIEW, Packer, record, save_json, save_png
from lib.pix import AUTO, DEEP, FLAT, LIGHT, SHADE, SHINE, Canvas
from lib.vox import mix, mul

GOLD, GOLD_D, YELLOW = (240, 192, 78), (184, 124, 44), (252, 226, 104)
WOOD, WOOD_L, WOOD_D = (156, 100, 58), (204, 150, 96), (104, 64, 38)
IRON, STEEL, DARK = (128, 136, 152), (200, 210, 224), (64, 54, 76)
RED, RED_D, PINK = (220, 72, 64), (150, 40, 48), (242, 126, 160)
GREEN, GREEN_D, LEAF = (92, 188, 96), (52, 124, 70), (120, 206, 90)
BLUE, NAVY, CYAN = (78, 142, 222), (46, 70, 130), (104, 220, 236)
PURPLE, LILAC = (158, 104, 216), (204, 170, 250)
WHITE, CREAM, PAPER = (246, 242, 232), (240, 226, 190), (232, 214, 170)
ORANGE, BROWN, SKIN = (242, 142, 58), (136, 88, 52), (240, 196, 160)
TEAL = (64, 176, 170)

ICONS: dict = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


# ------------------------------------------------------------ shape kit ----

def star(cv, cx, cy, r1, r2, c, tone=AUTO, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    cv.poly(pts, c, tone)


def heart(cv, cx, cy, s, c):
    cv.ellipse(cx - s * 0.5, cy - s * 0.25, s * 0.55, s * 0.5, c)
    cv.ellipse(cx + s * 0.5, cy - s * 0.25, s * 0.55, s * 0.5, c)
    cv.poly([(cx - s * 1.05, cy - s * 0.1), (cx + s * 1.05 + 1, cy - s * 0.1), (cx + 0.5, cy + s * 1.0 + 0.5)], c)


def plus(cv, cx, cy, r, w, c, tone=AUTO):
    cv.rect(cx - w, cy - r, cx + w - 1, cy + r - 1, c, tone)
    cv.rect(cx - r, cy - w, cx + r - 1, cy + w - 1, c, tone)


def sword(cv, x0, y0, x1, y1, blade=STEEL, hilt=GOLD, grip=BROWN):
    """Diagonal sword from pommel (x0, y0) to tip (x1, y1)."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    gx, gy = x0 + ux * 3, y0 + uy * 3
    cv.line(gx, gy, x1, y1, blade)
    cv.line(gx + (1 if abs(ux) > abs(uy) else 0), gy + (0 if abs(ux) > abs(uy) else 1),
            x1 - (0 if abs(ux) > abs(uy) else 0), y1, blade, SHADE)
    cv.line(x0, y0, gx, gy, grip, FLAT)
    px, py = -uy, ux
    cv.line(gx - px * 2.5, gy - py * 2.5, gx + px * 2.5, gy + py * 2.5, hilt, FLAT)
    cv.px(x0, y0, hilt, LIGHT)


def shield(cv, body, emb, rim=None):
    pts = [(2, 2), (14, 2), (14, 8), (8, 14.5), (2, 8)]
    cv.poly(pts, rim or mul(body, 0.7))
    cv.poly([(3, 3), (13, 3), (13, 8), (8, 13), (3, 8)], body)
    cv.rect(7, 3, 8, 12, emb, FLAT)
    cv.rect(3, 6, 12, 7, emb, FLAT)


def swirl(cv, c, cx=8, cy=8, turns=2.2, r=6.5):
    pts = []
    n = 60
    for i in range(n):
        t = i / (n - 1)
        a = t * turns * 2 * math.pi
        rr = r * (1 - t) + 0.6
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    for (a, b) in zip(pts, pts[1:]):
        cv.line(a[0], a[1], b[0], b[1], c)


def ring(cv, cx, cy, ro, ri, c, tone=AUTO):
    cv.ellipse(cx, cy, ro, ro, c, tone)
    cv.ellipse(cx, cy, ri, ri, None)


def gear(cv, c, cx=8, cy=8):
    for k in range(8):
        a = math.radians(k * 45)
        x, y = cx + 5.6 * math.cos(a), cy + 5.6 * math.sin(a)
        cv.rect(round(x) - 1, round(y) - 1, round(x), round(y), c)
    ring(cv, cx, cy, 5, 1.8, c)


def arrow(cv, direction, c, cx=8, cy=8, s=5):
    if direction == "up":
        cv.poly([(cx, cy - s - 0.5), (cx + s + 1, cy + 0.5), (cx - s, cy + 0.5)], c)
        cv.rect(cx - 1, cy, cx + 1, cy + s, c)
    elif direction == "down":
        cv.poly([(cx, cy + s + 1.5), (cx + s + 1, cy + 0.5), (cx - s, cy + 0.5)], c)
        cv.rect(cx - 1, cy - s, cx + 1, cy, c)
    elif direction == "left":
        cv.poly([(cx - s - 0.5, cy + 0.5), (cx + 0.5, cy - s), (cx + 0.5, cy + s + 1)], c)
        cv.rect(cx, cy - 1, cx + s, cy + 1, c)
    else:
        cv.poly([(cx + s + 1.5, cy + 0.5), (cx + 0.5, cy - s), (cx + 0.5, cy + s + 1)], c)
        cv.rect(cx - s, cy - 1, cx, cy + 1, c)


def chevron(cv, direction, c):
    for i in range(4):
        if direction == "up":
            cv.rect(8 - 4 + i, 6 + i - 1, 8 - 4 + i + 1, 6 + i, c)
            cv.rect(8 + 3 - i, 6 + i - 1, 8 + 3 - i + 1, 6 + i, c)
        elif direction == "down":
            cv.rect(8 - 4 + i, 10 - i, 8 - 4 + i + 1, 10 - i + 1, c)
            cv.rect(8 + 3 - i, 10 - i, 8 + 3 - i + 1, 10 - i + 1, c)
        elif direction == "left":
            cv.rect(6 + i - 1, 8 - 4 + i, 6 + i, 8 - 4 + i + 1, c)
            cv.rect(6 + i - 1, 8 + 3 - i, 6 + i, 8 + 3 - i + 1, c)
        else:
            cv.rect(10 - i, 8 - 4 + i, 10 - i + 1, 8 - 4 + i + 1, c)
            cv.rect(10 - i, 8 + 3 - i, 10 - i + 1, 8 + 3 - i + 1, c)


def flame(cv, cx, cy, s, outer=ORANGE, inner=YELLOW):
    cv.ellipse(cx, cy + s * 0.35, s * 0.75, s * 0.6, outer)
    cv.poly([(cx - s * 0.7, cy + s * 0.2), (cx + 0.5, cy - s * 1.1), (cx + s * 0.75 + 1, cy + s * 0.2)], outer)
    cv.ellipse(cx, cy + s * 0.5, s * 0.38, s * 0.35, inner, FLAT)
    cv.poly([(cx - s * 0.35, cy + s * 0.45), (cx + 0.5, cy - s * 0.3), (cx + s * 0.4 + 1, cy + s * 0.45)], inner, FLAT)


def drop(cv, cx, cy, s, c):
    cv.ellipse(cx, cy + s * 0.3, s * 0.7, s * 0.7, c)
    cv.poly([(cx - s * 0.65, cy + s * 0.15), (cx + 0.5, cy - s * 1.0), (cx + s * 0.65 + 1, cy + s * 0.15)], c)


def head(cv, cx, cy, hair, shirt):
    cv.ellipse(cx, cy + 5, 3.4, 2.6, shirt)
    cv.rect(cx - 3, cy + 5, cx + 3, cy + 6, shirt)
    cv.ellipse(cx, cy, 2.6, 2.6, SKIN)
    cv.rect(cx - 2, cy - 3, cx + 2, cy - 2, hair)
    cv.px(cx - 3, cy - 1, hair)


def scroll(cv, c=PAPER):
    cv.rect(3, 3, 12, 13, c)
    cv.rect(2, 2, 13, 3, mul(c, 0.85))
    cv.rect(2, 13, 13, 14, mul(c, 0.85))
    for y in (6, 8, 10):
        cv.hline(5, 10, y, mul(c, 0.6), FLAT)


def book(cv, cover, page=CREAM):
    cv.rect(3, 2, 13, 13, cover)
    cv.rect(4, 12, 13, 14, page)
    cv.vline(3, 2, 14, mul(cover, 0.7), FLAT)
    cv.rect(6, 5, 11, 6, GOLD, FLAT)


def gem(cv, cx, cy, r, c):
    cv.poly([(cx - r, cy - r * 0.2), (cx - r * 0.5, cy - r), (cx + r * 0.5 + 1, cy - r), (cx + r + 1, cy - r * 0.2),
             (cx + 0.5, cy + r + 1)], c)
    cv.px(cx - r * 0.4, cy - r * 0.5, WHITE, SHINE)


def wave(cv, c, y0=9):
    for x in range(1, 15):
        y = y0 + round(1.6 * math.sin(x * 0.75))
        cv.rect(x, y, x, 14, c)
    for x in range(2, 14, 4):
        cv.px(x, y0 - 1 + round(1.6 * math.sin(x * 0.75)), WHITE, SHINE)


def cloud(cv, c, cx=8, cy=7):
    cv.ellipse(cx - 3, cy + 1, 3, 2.4, c)
    cv.ellipse(cx + 1, cy - 1, 3.4, 3, c)
    cv.ellipse(cx + 4, cy + 1.2, 2.6, 2.2, c)
    cv.rect(cx - 5, cy + 1, cx + 6, cy + 3, c)


def anchor_shape(cv, c):
    ring(cv, 8, 3, 1.8, 0.7, c)
    cv.rect(7, 5, 8, 13, c)
    cv.rect(4, 6, 11, 7, c)
    for x in range(2, 14):
        y = 13 - round(3.4 * math.cos((x - 7.5) / 6 * math.pi / 2) ** 2)
        cv.px(x, y + 0, c)
        cv.px(x, y - 1 if x in (2, 13) else y, c)
    cv.poly([(1, 9), (4, 11), (1, 12)], c)
    cv.poly([(15, 9), (12, 11), (15, 12)], c)


# ------------------------------------------------------------- icons -------
# Resources
@icon("gold")
def _(cv):
    cv.ellipse(8, 11, 5.5, 2.5, GOLD_D)
    cv.rect(2, 8, 13, 11, GOLD_D)
    cv.ellipse(8, 8, 5.5, 2.5, GOLD)
    cv.ellipse(9, 5, 4.5, 4.5, YELLOW)
    cv.ellipse(9, 5, 2.5, 2.5, GOLD, FLAT)
    cv.vline(9, 3, 7, YELLOW, SHINE)


@icon("food")
def _(cv):
    cv.line(4, 11, 2, 13, CREAM, th=2)
    cv.ellipse(2, 13.5, 1.3, 1.3, CREAM)
    cv.ellipse(1.5, 12, 1.1, 1.1, CREAM)
    cv.ellipse(9, 7, 5, 4.5, (200, 110, 62))
    cv.ellipse(10, 6, 2.5, 2, (232, 150, 92), FLAT)


@icon("supplies")
def _(cv):
    cv.rect(2, 5, 13, 13, WOOD)
    cv.rect(2, 4, 13, 5, WOOD_L, LIGHT)
    cv.line(3, 6, 12, 12, WOOD_D, FLAT)
    cv.line(12, 6, 3, 12, WOOD_D, FLAT)
    cv.rect(2, 5, 2, 13, WOOD_D, FLAT)
    cv.rect(13, 5, 13, 13, WOOD_D, FLAT)


@icon("materials")
def _(cv):
    cv.rect(1, 10, 13, 12, (190, 132, 80))
    cv.rect(3, 7, 14, 9, (172, 116, 68))
    cv.rect(2, 4, 12, 6, (212, 158, 100))
    for (x, y) in ((4, 5), (9, 8), (6, 11), (11, 11)):
        cv.px(x, y, WOOD_D, FLAT)


@icon("stamina")
def _(cv):
    cv.poly([(9, 1), (3, 9), (7.5, 9), (5, 15), (13.5, 6), (9, 6), (11.5, 1)], YELLOW)


@icon("xp")
def _(cv):
    star(cv, 8, 8.5, 7, 3, YELLOW)


@icon("day")
def _(cv):
    for k in range(8):
        cv.ray(8, 8, k * 45, 7, ORANGE, FLAT, start=5)
    cv.ellipse(8, 8, 4, 4, YELLOW)


@icon("night")
def _(cv):
    cv.ellipse(8, 8, 6, 6, (230, 226, 160))
    cv.ellipse(11, 6, 5, 5, None)
    cv.px(12, 11, WHITE, SHINE)
    cv.px(13, 3, WHITE, SHINE)


@icon("hull")
def _(cv):
    cv.vline(8, 1, 9, WOOD_D)
    cv.poly([(8.5, 1), (14, 8), (8.5, 8)], WHITE)
    cv.poly([(1, 9), (15, 9), (12, 14), (4, 14)], WOOD)
    cv.hline(3, 13, 11, WOOD_D, FLAT)


@icon("fame")
def _(cv):
    cv.vline(4, 2, 14, WOOD_D)
    cv.poly([(5, 2), (14, 4.5), (5, 8)], RED)
    cv.px(4, 1, GOLD)


@icon("mastery")
def _(cv):
    cv.poly([(4, 1), (7, 1), (9, 6), (6, 6)], BLUE)
    cv.poly([(12, 1), (9, 1), (7, 6), (10, 6)], RED)
    cv.ellipse(8, 10, 4.5, 4.5, GOLD)
    star(cv, 8, 10.5, 3, 1.3, YELLOW, FLAT)


@icon("time")
def _(cv):
    cv.rect(3, 1, 12, 2, WOOD)
    cv.rect(3, 13, 12, 14, WOOD)
    cv.poly([(4, 3), (12, 3), (8.5, 8), (8, 8)], (200, 230, 240))
    cv.poly([(8, 8), (8.5, 8), (12, 13), (4, 13)], (200, 230, 240))
    cv.poly([(6, 10), (10, 10), (11, 12.5), (5, 12.5)], (240, 210, 120), FLAT)


# Facility categories
@icon("cat_command")
def _(cv):
    for k in range(8):
        cv.ray(8, 8, k * 45 + 22.5, 7.4, WOOD_D, FLAT)
    ring(cv, 8, 8, 5, 3.2, WOOD)
    cv.ellipse(8, 8, 1.6, 1.6, GOLD)


@icon("cat_living")
def _(cv):
    cv.rect(1, 4, 2, 13, WOOD_D)
    cv.rect(1, 9, 14, 11, WOOD)
    cv.rect(3, 7, 14, 9, (214, 86, 86))
    cv.rect(3, 6, 6, 8, WHITE)
    cv.vline(14, 11, 13, WOOD_D)


@icon("cat_training")
def _(cv):
    sword(cv, 2, 13, 13, 2)
    sword(cv, 13, 13, 2, 2)


@icon("cat_medical")
def _(cv):
    cv.rect(2, 2, 13, 13, WHITE)
    plus(cv, 8, 8, 5, 1.5, RED, FLAT)


@icon("cat_production")
def _(cv):
    cv.line(4, 13, 10, 6, WOOD, th=2)
    cv.poly([(7, 3), (11, 0.5), (15, 5), (12, 7.5)], IRON)
    cv.px(13, 2, STEEL, SHINE)


@icon("cat_navigation")
def _(cv):
    cv.ellipse(8, 8, 6.5, 6.5, GOLD_D)
    cv.ellipse(8, 8, 5, 5, CREAM, FLAT)
    cv.poly([(8, 3), (10, 8), (6, 8)], RED, FLAT)
    cv.poly([(6, 8), (10, 8), (8, 13)], DARK, FLAT)
    cv.px(8, 8, GOLD, FLAT)


@icon("cat_storage")
def _(cv):
    cv.rect(4, 3, 11, 13, WOOD)
    cv.rect(3, 5, 12, 11, WOOD)
    cv.ellipse(7.5, 2.5, 3.5, 1.2, WOOD_L, LIGHT)
    cv.hline(3, 12, 5, IRON, FLAT)
    cv.hline(3, 12, 11, IRON, FLAT)


@icon("cat_pet")
def _(cv):
    cv.ellipse(8, 10.5, 3.6, 3, (196, 128, 86))
    for (x, y) in ((3.5, 6.5), (6.5, 4), (10, 4), (12.8, 6.5)):
        cv.ellipse(x, y, 1.5, 1.6, (196, 128, 86))


@icon("cat_social")
def _(cv):
    cv.rect(3, 5, 10, 13, WOOD_L)
    cv.rect(11, 7, 13, 11, WOOD_L)
    cv.rect(12, 8, 12, 10, None)
    cv.ellipse(6.5, 4.5, 4, 1.8, WHITE)
    cv.hline(3, 10, 8, WOOD_D, FLAT)
    cv.hline(3, 10, 11, WOOD_D, FLAT)


@icon("cat_defense")
def _(cv):
    cv.ellipse(3, 11, 2.4, 2.4, WOOD_D)
    cv.ellipse(8, 11, 2.4, 2.4, WOOD_D)
    cv.poly([(1, 6), (12, 3), (14, 7), (2, 10)], DARK)
    cv.px(13, 5, (30, 24, 30), FLAT)


# Roles
@icon("role_vanguard")
def _(cv):
    shield(cv, (90, 120, 200), GOLD)


@icon("role_striker")
def _(cv):
    sword(cv, 3, 13, 13, 3, STEEL, RED)


@icon("role_controller")
def _(cv):
    swirl(cv, PURPLE)


@icon("role_support")
def _(cv):
    heart(cv, 8, 7, 3.6, (240, 100, 120))
    plus(cv, 8, 7.5, 2.5, 1, WHITE, FLAT)


@icon("role_scout")
def _(cv):
    cv.poly([(1, 8), (5, 4), (11, 4), (15, 8), (11, 12), (5, 12)], WHITE)
    cv.ellipse(8, 8, 3, 3, (60, 150, 190))
    cv.ellipse(8, 8, 1.4, 1.4, DARK, FLAT)
    cv.px(7, 7, WHITE, SHINE)


# Stances
@icon("stance_aggressive")
def _(cv):
    flame(cv, 8, 8, 6, RED, ORANGE)


@icon("stance_balanced")
def _(cv):
    cv.vline(8, 2, 13, GOLD_D)
    cv.hline(2, 13, 3, GOLD_D)
    cv.rect(5, 13, 10, 14, GOLD_D)
    for x in (3, 12):
        cv.line(x, 4, x - 2, 9, IRON, FLAT)
        cv.line(x, 4, x + 2, 9, IRON, FLAT)
        cv.ellipse(x, 9.5, 2.6, 1.2, GOLD)


@icon("stance_defensive")
def _(cv):
    shield(cv, (70, 160, 120), WHITE)


@icon("stance_escape")
def _(cv):
    cv.vline(3, 2, 14, WOOD_D)
    cv.poly([(4, 2), (14, 3), (12, 5.5), (14, 8), (4, 8)], WHITE)


# Priorities / skill categories
@icon("prio_auto")
def _(cv):
    gear(cv, IRON)
    cv.ellipse(8, 8, 1.5, 1.5, CYAN, FLAT)


@icon("prio_survival")
def _(cv):
    heart(cv, 8, 7, 4, (230, 70, 90))


@icon("prio_control")
def _(cv):
    swirl(cv, PURPLE)


@icon("prio_damage")
def _(cv):
    star(cv, 8, 8, 7.2, 3, ORANGE, n=8, rot=-90)
    star(cv, 8, 8, 3.5, 1.6, YELLOW, FLAT, n=8, rot=-67)


@icon("prio_support")
def _(cv):
    plus(cv, 8, 8, 6, 2, GREEN)


# Weapon slots / item types
@icon("w_blade")
def _(cv):
    sword(cv, 2, 14, 13, 3)


@icon("w_shield")
def _(cv):
    cv.ellipse(8, 8, 6.5, 6.5, WOOD_D)
    cv.ellipse(8, 8, 5.2, 5.2, (70, 104, 176))
    cv.ellipse(8, 8, 1.8, 1.8, GOLD)


@icon("w_spear")
def _(cv):
    cv.line(2, 14, 11, 5, WOOD)
    cv.poly([(10, 4), (14.5, 1.5), (12, 6)], STEEL)
    cv.px(10, 6, RED)


@icon("w_gun")
def _(cv):
    cv.rect(2, 5, 13, 7, IRON)
    cv.rect(13, 4, 14, 5, IRON)
    cv.poly([(3, 7), (7, 7), (6, 13), (2, 13)], WOOD)
    cv.px(8, 8, IRON)
    cv.px(9, 9, IRON)


@icon("w_fist")
def _(cv):
    cv.rect(3, 5, 12, 12, (200, 150, 110))
    for x in (3, 6, 9):
        cv.rect(x, 3, x + 2, 6, (214, 166, 124))
    cv.rect(12, 7, 14, 10, (214, 166, 124))
    cv.rect(3, 12, 12, 14, RED_D)


@icon("w_kit")
def _(cv):
    cv.rect(5, 2, 10, 4, WOOD_D)
    cv.rect(2, 4, 13, 13, (210, 80, 70))
    plus(cv, 8, 8.5, 3, 1, WHITE, FLAT)


@icon("w_ladle")
def _(cv):
    cv.line(4, 3, 10, 10, IRON, th=1)
    cv.line(3, 2, 4, 3, WOOD_D)
    cv.ellipse(11, 11, 3.2, 2.6, STEEL)
    cv.ellipse(11, 10.5, 2, 1.2, (230, 180, 100), FLAT)


@icon("w_staff")
def _(cv):
    cv.line(3, 14, 10, 6, WOOD)
    cv.ellipse(11.5, 4, 2.8, 2.8, CYAN)
    cv.px(11, 3, WHITE, SHINE)


@icon("w_tool")
def _(cv):
    cv.line(3, 13, 9, 7, IRON, th=2)
    ring(cv, 11, 5, 3.4, 1.3, IRON)
    cv.rect(12, 1, 14, 3, None)


@icon("w_whip")
def _(cv):
    cv.rect(2, 11, 4, 14, BROWN)
    pts = [(4, 11), (6, 7), (10, 5), (13, 6), (14, 9), (12, 11)]
    for a, b in zip(pts, pts[1:]):
        cv.line(*a, *b, (176, 120, 70))


@icon("w_banner")
def _(cv):
    cv.vline(3, 1, 14, WOOD_D)
    cv.rect(4, 2, 12, 9, RED)
    cv.poly([(4, 9), (12, 9), (8, 12)], RED)
    star(cv, 8, 5.5, 2.5, 1.1, GOLD, FLAT)


@icon("w_outfit")
def _(cv):
    cv.poly([(5, 2), (11, 2), (15, 5), (13, 8), (12, 7), (12, 14), (4, 14), (4, 7), (3, 8), (1, 5)], (80, 120, 190))
    cv.vline(8, 3, 13, GOLD, FLAT)
    cv.poly([(6, 2), (10, 2), (8, 4)], CREAM, FLAT)


@icon("w_accessory")
def _(cv):
    ring(cv, 8, 9.5, 5, 3, GOLD)
    gem(cv, 8, 4, 2.5, (230, 70, 110))


# Hazards
@icon("hz_heat")
def _(cv):
    flame(cv, 8, 8, 6.5)


@icon("hz_poison")
def _(cv):
    drop(cv, 8, 9, 5.5, (124, 204, 90))
    cv.ellipse(4, 3, 1.4, 1.4, (150, 220, 110))
    cv.ellipse(12, 3, 1, 1, (150, 220, 110))


@icon("hz_glare")
def _(cv):
    for k in range(4):
        cv.ray(8, 8, k * 90, 7.5, WHITE, FLAT, start=3)
    for k in range(4):
        cv.ray(8, 8, k * 90 + 45, 5.5, YELLOW, FLAT, start=3)
    cv.ellipse(8, 8, 3, 3, (255, 250, 210))


@icon("hz_storm")
def _(cv):
    cloud(cv, (150, 156, 178), 8, 5)
    cv.poly([(8, 8), (5, 12), (7.5, 12), (6, 15.5), (11, 10.5), (8.5, 10.5), (10, 8)], YELLOW)


@icon("hz_dream")
def _(cv):
    cv.ellipse(7, 8, 5.5, 5.5, LILAC)
    cv.ellipse(10, 6, 4.5, 4.5, None)
    for (x, y) in ((11, 11), (13, 3), (9, 2)):
        cv.px(x, y, WHITE, SHINE)


@icon("hz_pressure")
def _(cv):
    for x in (4, 8, 12):
        arrow(cv, "down", (90, 120, 200), x, 7, 2)
    cv.rect(1, 13, 14, 14, NAVY)


@icon("hz_tide")
def _(cv):
    wave(cv, (70, 150, 220), 7)


# Specialties
@icon("sp_saltleaf_grain")
def _(cv):
    cv.line(8, 14, 8, 6, (190, 160, 70))
    for i in range(4):
        cv.ellipse(6.5, 3 + i * 2.2, 1.4, 1.2, (240, 210, 110))
        cv.ellipse(9.5, 3 + i * 2.2, 1.4, 1.2, (240, 210, 110))
    cv.line(8, 11, 12, 9, LEAF)


@icon("sp_ember_ore")
def _(cv):
    cv.poly([(2, 10), (5, 4), (11, 3), (14, 9), (11, 14), (4, 14)], (90, 76, 80))
    for (x, y) in ((6, 7), (10, 6), (8, 11), (11, 10)):
        cv.rect(x, y, x + 1, y, (255, 120, 50), SHINE)


@icon("sp_verdant_resin")
def _(cv):
    drop(cv, 8, 9, 5.2, (230, 150, 40))
    cv.px(6, 9, (255, 230, 150), SHINE)
    cv.px(9, 11, (120, 70, 20), FLAT)


@icon("sp_prism_quartz")
def _(cv):
    cv.poly([(5, 14), (4, 6), (6.5, 2), (9, 6), (8, 14)], (200, 236, 250))
    cv.poly([(8, 14), (9, 8), (11.5, 5), (13, 9), (11, 14)], (170, 200, 250))
    cv.vline(5, 6, 12, WHITE, SHINE)


@icon("sp_crown_silk")
def _(cv):
    cv.rect(4, 3, 11, 13, (230, 140, 200))
    cv.rect(3, 2, 12, 3, WOOD)
    cv.rect(3, 13, 12, 14, WOOD)
    for y in (5, 7, 9, 11):
        cv.hline(4, 11, y, (250, 190, 230), FLAT)


@icon("sp_stormwood")
def _(cv):
    cv.rect(2, 6, 12, 11, (110, 100, 120))
    cv.ellipse(12.5, 8.5, 2, 2.6, (180, 170, 150))
    cv.ellipse(12.5, 8.5, 0.9, 1.2, (110, 100, 120), FLAT)
    cv.line(3, 4, 6, 7, CYAN, FLAT)


@icon("sp_moon_ink")
def _(cv):
    cv.rect(6, 2, 9, 4, WOOD_D)
    cv.ellipse(7.5, 10, 5, 4.5, (80, 70, 140))
    cv.rect(5, 4, 10, 7, (80, 70, 140))
    cv.ellipse(7.5, 10.5, 3, 2, (190, 180, 250), FLAT)


@icon("sp_abyss_alloy")
def _(cv):
    cv.poly([(1, 10), (4, 6), (15, 6), (12, 10)], (110, 120, 150))
    cv.rect(1, 10, 12, 13, (80, 88, 120))
    cv.poly([(12, 10), (15, 6), (15, 9), (12, 13)], (60, 66, 96))
    cv.hline(5, 13, 7, (170, 190, 230), SHINE)


@icon("sp_leviathan_scale")
def _(cv):
    cv.poly([(8, 1), (14, 6), (12, 13), (8, 15), (4, 13), (2, 6)], (70, 180, 170))
    cv.poly([(8, 4), (11, 7), (8, 12), (5, 7)], (120, 220, 200), FLAT)


@icon("sp_horizon_glass")
def _(cv):
    cv.ellipse(8, 8, 6, 6, (180, 220, 250))
    cv.ellipse(8, 8, 4, 4, (240, 210, 140), FLAT)
    cv.ellipse(6, 6, 1.4, 1.4, WHITE, SHINE)


# Ingredients
@icon("ing_fire_pepper")
def _(cv):
    cv.poly([(4, 5), (10, 4), (13, 8), (11, 13), (6, 9)], RED)
    cv.rect(3, 3, 5, 5, GREEN)


@icon("ing_sea_pearl")
def _(cv):
    cv.ellipse(8, 10, 6, 3.5, (210, 200, 190))
    cv.ellipse(8, 8, 3.2, 3.2, (236, 236, 250))
    cv.px(7, 7, WHITE, SHINE)


@icon("ing_kelp_sprig")
def _(cv):
    for (x0, h) in ((5, 11), (8, 13), (11, 9)):
        for y in range(15 - h, 15):
            cv.px(x0 + round(math.sin(y * 0.8)), y, GREEN_D if x0 != 8 else GREEN)


@icon("ing_sun_honey")
def _(cv):
    cv.rect(4, 5, 11, 13, (240, 170, 50))
    cv.rect(3, 3, 12, 5, WOOD)
    cv.rect(5, 8, 10, 10, CREAM, FLAT)


@icon("ing_dusk_ink")
def _(cv):
    drop(cv, 8, 9, 5, (120, 70, 170))


@icon("ing_salt_crystal")
def _(cv):
    cv.rect(3, 8, 8, 13, WHITE)
    cv.rect(8, 5, 12, 9, (230, 236, 246))
    cv.rect(9, 10, 13, 13, (236, 240, 248))


# Pets / factions
@icon("pet_companion")
def _(cv):
    heart(cv, 8, 7, 3.8, PINK)


@icon("pet_helper")
def _(cv):
    cv.rect(2, 5, 13, 13, (170, 120, 70))
    cv.rect(2, 5, 13, 8, (196, 144, 90))
    cv.rect(7, 7, 8, 9, GOLD, FLAT)
    cv.line(4, 5, 7, 2, WOOD_D)
    cv.line(11, 5, 8, 2, WOOD_D)


@icon("pet_explorer")
def _(cv):
    cv.line(2, 12, 11, 5, GOLD_D, th=2)
    cv.ellipse(12, 4.5, 2.5, 2.5, GOLD)
    cv.ellipse(12, 4.5, 1.2, 1.2, (150, 210, 240), FLAT)


@icon("fac_conclave")
def _(cv):
    book(cv, (110, 70, 160))


@icon("fac_league")
def _(cv):
    cv.ellipse(8, 8, 6.5, 6.5, GOLD)
    cv.ellipse(8, 8, 4.5, 4.5, GOLD_D, FLAT)
    cv.vline(8, 4, 12, YELLOW, SHINE)


@icon("fac_tidebound")
def _(cv):
    cv.vline(8, 3, 14, TEAL)
    for x in (4, 8, 12):
        cv.vline(x, 1, 5, TEAL)
    cv.hline(4, 12, 5, TEAL)


@icon("fac_pennants")
def _(cv):
    cv.vline(3, 1, 14, WOOD_D)
    cv.poly([(4, 2), (15, 5), (4, 9)], (40, 34, 48))
    star(cv, 8, 5.5, 2.2, 1, WHITE, FLAT)


# Location types (also on the chart)
@icon("loc_port")
def _(cv):
    anchor_shape(cv, (200, 210, 230))


@icon("loc_island")
def _(cv):
    cv.ellipse(8, 12, 6.5, 2.6, (232, 210, 140))
    cv.line(8, 11, 9, 4, WOOD)
    for a in (200, 240, 290, 330):
        cv.ray(9, 4, a, 5, GREEN, FLAT)


@icon("loc_dungeon")
def _(cv):
    cv.poly([(1, 14), (5, 4), (8, 2), (11, 4), (15, 14)], (120, 114, 108))
    cv.ellipse(8, 11, 2.6, 3.4, (34, 26, 36), FLAT)
    cv.rect(6, 11, 10, 14, (34, 26, 36), FLAT)


@icon("loc_wreck")
def _(cv):
    cv.poly([(1, 10), (13, 6), (15, 9), (4, 14)], WOOD)
    cv.line(9, 8, 6, 1, WOOD_D)
    cv.poly([(6, 2), (11, 3), (8, 6)], (210, 200, 180))


@icon("loc_arena")
def _(cv):
    ring(cv, 8, 9, 6.5, 4, (190, 90, 70))
    sword(cv, 4, 12, 12, 4, STEEL, GOLD)


@icon("loc_secret")
def _(cv):
    star(cv, 8, 8, 7, 2.6, LILAC, n=4, rot=-90)
    cv.px(8, 8, WHITE, SHINE)


# UI actions
@icon("ui_build")
def _(cv):
    cv.line(3, 13, 9, 7, WOOD, th=2)
    cv.poly([(6, 4), (10, 1), (14, 5), (11, 8)], IRON)


@icon("ui_crew")
def _(cv):
    head(cv, 5, 5, BROWN, (80, 120, 190))
    head(cv, 11, 6, GOLD_D, (200, 80, 80))


@icon("ui_pets")
def _(cv):
    ICONS["cat_pet"](cv)


@icon("ui_codex")
def _(cv):
    book(cv, (60, 110, 170))


@icon("ui_system")
def _(cv):
    gear(cv, (180, 186, 200))


@icon("ui_sail")
def _(cv):
    cv.vline(8, 1, 11, WOOD_D)
    cv.poly([(9, 2), (14, 9), (9, 9)], WHITE)
    cv.poly([(7, 3), (7, 9), (3, 9)], CREAM)
    cv.poly([(1, 11), (15, 11), (12, 14), (4, 14)], WOOD)


@icon("ui_map")
def _(cv):
    cv.poly([(1, 3), (5, 2), (10, 4), (15, 3), (15, 13), (10, 14), (5, 12), (1, 13)], PAPER)
    cv.vline(5, 3, 12, mul(PAPER, 0.8), FLAT)
    cv.vline(10, 4, 13, mul(PAPER, 0.8), FLAT)
    cv.line(3, 10, 7, 7, RED_D, FLAT)
    cv.line(7, 7, 12, 8, RED_D, FLAT)
    cv.px(12, 8, RED, FLAT)


@icon("ui_port")
def _(cv):
    anchor_shape(cv, (200, 210, 230))


@icon("ui_save")
def _(cv):
    cv.rect(2, 6, 13, 13, WOOD)
    cv.rect(2, 4, 13, 6, WOOD_L)
    cv.rect(7, 7, 8, 9, GOLD, FLAT)
    arrow(cv, "down", GREEN, 8, 3, 2)


@icon("ui_load")
def _(cv):
    cv.rect(2, 6, 13, 13, WOOD)
    cv.rect(2, 4, 13, 6, WOOD_L)
    cv.rect(7, 7, 8, 9, GOLD, FLAT)
    arrow(cv, "up", CYAN, 8, 3, 2)


@icon("ui_close")
def _(cv):
    cv.line(3, 3, 12, 12, (230, 90, 80), th=2)
    cv.line(12, 3, 3, 12, (230, 90, 80), th=2)


@icon("ui_check")
def _(cv):
    cv.line(2, 8, 6, 12, GREEN, th=2)
    cv.line(6, 12, 13, 3, GREEN, th=2)


@icon("ui_lock")
def _(cv):
    ring(cv, 8, 6, 4, 2.2, IRON)
    cv.rect(3, 7, 12, 14, GOLD)
    cv.rect(7, 9, 8, 12, DARK, FLAT)


@icon("ui_star")
def _(cv):
    star(cv, 8, 8.5, 7, 3, YELLOW)


@icon("ui_warn")
def _(cv):
    cv.poly([(8, 1), (15.5, 14.5), (0.5, 14.5)], (246, 200, 60))
    cv.rect(7, 5, 8, 10, DARK, FLAT)
    cv.rect(7, 12, 8, 13, DARK, FLAT)


@icon("ui_info")
def _(cv):
    cv.ellipse(8, 8, 6.5, 6.5, BLUE)
    cv.rect(7, 7, 8, 12, WHITE, FLAT)
    cv.rect(7, 4, 8, 5, WHITE, FLAT)


@icon("ui_plus")
def _(cv):
    plus(cv, 8, 8, 6, 1.5, GREEN)


@icon("ui_minus")
def _(cv):
    cv.rect(2, 7, 13, 9, RED)


for _d in ("up", "down", "left", "right"):
    ICONS["ui_" + _d] = (lambda d: (lambda cv: chevron(cv, d, CREAM)))(_d)
    ICONS["ui_arrow_" + _d] = (lambda d: (lambda cv: arrow(cv, d, CREAM)))(_d)


@icon("ui_pause")
def _(cv):
    cv.rect(3, 2, 6, 13, CREAM)
    cv.rect(9, 2, 12, 13, CREAM)


@icon("ui_play")
def _(cv):
    cv.poly([(3, 1.5), (14, 8), (3, 14.5)], CREAM)


@icon("ui_ff")
def _(cv):
    cv.poly([(1, 2.5), (8, 8), (1, 13.5)], CREAM)
    cv.poly([(8, 2.5), (15, 8), (8, 13.5)], CREAM)


@icon("ui_skip")
def _(cv):
    cv.poly([(1, 2.5), (7, 8), (1, 13.5)], CREAM)
    cv.poly([(6, 2.5), (12, 8), (6, 13.5)], CREAM)
    cv.rect(12, 2, 14, 13, CREAM)


@icon("ui_rotate")
def _(cv):
    for i in range(40):
        a = math.radians(-60 + i * 7.5)
        cv.px(8 + 5.5 * math.cos(a), 8 + 5.5 * math.sin(a), CYAN)
        cv.px(8 + 4.6 * math.cos(a), 8 + 4.6 * math.sin(a), CYAN)
    cv.poly([(9, 0.5), (14, 3.5), (9, 6.5)], CYAN)


@icon("ui_move")
def _(cv):
    for d in ("up", "down", "left", "right"):
        pass
    cv.rect(7, 3, 8, 12, CREAM)
    cv.rect(3, 7, 12, 8, CREAM)
    cv.poly([(7.5, 0.5), (11, 4), (4, 4)], CREAM)
    cv.poly([(7.5, 15.5), (11, 12), (4, 12)], CREAM)
    cv.poly([(0.5, 7.5), (4, 4), (4, 11)], CREAM)
    cv.poly([(15.5, 7.5), (12, 4), (12, 11)], CREAM)


@icon("ui_demolish")
def _(cv):
    cv.line(3, 14, 9, 6, WOOD, th=2)
    for i in range(9):
        x = 4 + i
        y = 5 - round(2.5 * math.sin(i / 8 * math.pi))
        cv.rect(x, y, x, y + 1, IRON)


@icon("ui_repair")
def _(cv):
    ICONS["w_tool"](cv)


@icon("ui_deck_up")
def _(cv):
    for i in range(4):
        cv.rect(1 + i * 3, 13 - i * 3, 4 + i * 3, 14 - i * 3, WOOD_L)
    arrow(cv, "up", GREEN, 4, 5, 3)


@icon("ui_deck_down")
def _(cv):
    for i in range(4):
        cv.rect(1 + i * 3, 13 - i * 3, 4 + i * 3, 14 - i * 3, WOOD_L)
    arrow(cv, "down", (240, 150, 70), 4, 4, 3)


@icon("ui_rig")
def _(cv):
    cv.vline(8, 1, 14, WOOD_D)
    cv.rect(2, 3, 13, 4, WOOD)
    cv.poly([(2, 5), (13, 5), (12, 11), (3, 11)], WHITE)
    cv.rect(7, 7, 8, 9, RED, FLAT)


@icon("ui_quest")
def _(cv):
    scroll(cv)
    cv.rect(11, 1, 13, 6, RED)
    cv.rect(11, 8, 13, 9, RED)


@icon("ui_trade")
def _(cv):
    ICONS["stance_balanced"](cv)


@icon("ui_recruit")
def _(cv):
    head(cv, 6, 5, BROWN, (80, 160, 120))
    plus(cv, 12, 11, 3, 1, GREEN)


@icon("ui_invest")
def _(cv):
    cv.ellipse(6, 10, 4.5, 4.5, GOLD)
    cv.ellipse(6, 10, 2.5, 2.5, GOLD_D, FLAT)
    arrow(cv, "up", GREEN, 12, 6, 3)


@icon("ui_eye")
def _(cv):
    ICONS["role_scout"](cv)


@icon("ui_egg")
def _(cv):
    cv.ellipse(8, 9, 5, 6, (246, 236, 214))
    for (x, y) in ((6, 7), (10, 10), (7, 12)):
        cv.px(x, y, (120, 190, 220), FLAT)


@icon("ui_battle")
def _(cv):
    ICONS["cat_training"](cv)


@icon("ui_retreat")
def _(cv):
    cv.vline(4, 1, 14, WOOD_D)
    cv.poly([(5, 2), (14, 3), (12, 5.5), (14, 8), (5, 8)], WHITE)
    arrow(cv, "left", CYAN, 9, 12, 2)


@icon("ui_zoom_in")
def _(cv):
    ring(cv, 6.5, 6.5, 5, 3.5, STEEL)
    cv.line(10, 10, 14, 14, WOOD, th=2)
    plus(cv, 6.5, 6.5, 2, 0.5, GREEN, FLAT)


@icon("ui_zoom_out")
def _(cv):
    ring(cv, 6.5, 6.5, 5, 3.5, STEEL)
    cv.line(10, 10, 14, 14, WOOD, th=2)
    cv.rect(5, 6, 8, 7, RED, FLAT)


@icon("ui_fit")
def _(cv):
    # corner brackets around a small target: "fit the view to this"
    for (x0, y0, dx, dy) in ((1, 1, 1, 1), (14, 1, -1, 1), (1, 14, 1, -1), (14, 14, -1, -1)):
        cv.rect(min(x0, x0 + 3 * dx), y0, max(x0, x0 + 3 * dx), y0, STEEL)
        cv.rect(x0, min(y0, y0 + 3 * dy), x0, max(y0, y0 + 3 * dy), STEEL)
    cv.poly([(8, 4.5), (11.5, 8), (8, 11.5), (4.5, 8)], CYAN)
    cv.rect(7, 7, 8, 8, WHITE, FLAT)


@icon("ui_home")
def _(cv):
    cv.poly([(1, 8), (8, 1.5), (15, 8)], RED)
    cv.rect(3, 8, 12, 14, CREAM)
    cv.rect(7, 10, 9, 14, WOOD, FLAT)


@icon("ui_bell")
def _(cv):
    cv.poly([(4, 11), (5, 4), (8, 2), (11, 4), (12, 11)], GOLD)
    cv.rect(2, 11, 13, 12, GOLD_D)
    cv.ellipse(7.5, 13.5, 1.4, 1.2, GOLD_D)


@icon("ui_cook")
def _(cv):
    cv.rect(2, 7, 13, 13, IRON)
    cv.rect(1, 6, 14, 7, STEEL)
    for x in (4, 8, 11):
        cv.vline(x, 1 + (x % 3), 4, WHITE, FLAT)


@icon("ui_heal")
def _(cv):
    heart(cv, 8, 7, 4, (230, 80, 100))
    plus(cv, 8, 7.5, 2.5, 1, WHITE, FLAT)


@icon("ui_sleep")
def _(cv):
    for (x, y, s) in ((2, 9, 4), (8, 4, 3), (12, 1, 2)):
        cv.hline(x, x + s, y, LILAC)
        cv.line(x + s, y, x, y + s, LILAC)
        cv.hline(x, x + s, y + s, LILAC)


@icon("ui_level")
def _(cv):
    arrow(cv, "up", GOLD, 8, 8, 6)


@icon("ui_trash")
def _(cv):
    cv.rect(3, 4, 12, 5, IRON)
    cv.rect(6, 2, 9, 3, IRON)
    cv.rect(4, 6, 11, 14, STEEL)
    for x in (6, 9):
        cv.vline(x, 7, 13, IRON, FLAT)


@icon("ui_globe")
def _(cv):
    cv.ellipse(8, 8, 6.5, 6.5, BLUE)
    cv.ellipse(6, 6, 2.5, 2, GREEN)
    cv.ellipse(10.5, 10.5, 2, 2.2, GREEN)
    cv.px(5, 4, WHITE, SHINE)


@icon("ui_sound")
def _(cv):
    cv.rect(2, 6, 4, 10, CREAM)
    cv.poly([(4, 6), (9, 2), (9, 14), (4, 10)], CREAM)
    for i in range(7):
        cv.px(11 + round(1.2 * math.sin(i / 6 * math.pi)), 5 + i, CREAM)
    for i in range(11):
        cv.px(13 + round(1.6 * math.sin(i / 10 * math.pi)), 3 + i, CREAM)


@icon("ui_fullscreen")
def _(cv):
    for (x, y, sx, sy) in ((1, 1, 1, 1), (14, 1, -1, 1), (1, 14, 1, -1), (14, 14, -1, -1)):
        cv.hline(x, x + sx * 4, y, CREAM)
        cv.vline(x, y, y + sy * 4, CREAM)


@icon("ui_chest")
def _(cv):
    cv.rect(2, 7, 13, 13, WOOD)
    cv.poly([(2, 7), (3, 3), (12, 3), (13, 7)], WOOD_L)
    cv.hline(2, 13, 7, GOLD_D, FLAT)
    cv.rect(7, 6, 8, 9, GOLD, FLAT)


@icon("ui_relic")
def _(cv):
    # a chalice on a plinth: collectible relic
    cv.poly([(4, 3), (12, 3), (11, 7), (8, 9), (5, 7)], GOLD)
    cv.hline(4, 12, 3, YELLOW, LIGHT)
    cv.vline(8, 9, 12, GOLD_D)
    cv.rect(5, 13, 11, 14, GOLD_D)
    cv.px(7, 5, WHITE, SHINE)
    cv.px(9, 4, WHITE, SHINE)


@icon("ui_trophy")
def _(cv):
    cv.poly([(4, 2), (12, 2), (11, 7), (8, 9), (5, 7)], GOLD)
    cv.hline(4, 12, 2, YELLOW, LIGHT)
    cv.line(4, 3, 2, 4, GOLD_D)
    cv.line(2, 4, 3, 7, GOLD_D)
    cv.line(12, 3, 14, 4, GOLD_D)
    cv.line(14, 4, 13, 7, GOLD_D)
    cv.vline(8, 9, 12, GOLD_D)
    cv.rect(5, 13, 11, 14, GOLD_D)
    cv.px(7, 4, WHITE, SHINE)


@icon("ui_chart")
def _(cv):
    cv.rect(2, 4, 13, 12, CREAM)
    cv.hline(2, 13, 4, PAPER, FLAT)
    cv.hline(2, 13, 12, PAPER, FLAT)
    cv.vline(2, 4, 12, WOOD_D)
    cv.vline(13, 4, 12, WOOD_D)
    for y in (7, 10):
        cv.hline(4, 7, y, (120, 180, 190), FLAT)
    cv.line(9, 7, 11, 9, RED, FLAT)
    cv.line(11, 7, 9, 9, RED, FLAT)


@icon("ui_lore")
def _(cv):
    cv.rect(3, 2, 12, 13, CREAM)
    cv.rect(3, 2, 4, 13, (200, 60, 60))
    for y in (5, 7, 9, 11):
        cv.hline(6, 11, y, (150, 130, 110), FLAT)
    cv.px(10, 12, (150, 130, 110), FLAT)


@icon("ui_curio")
def _(cv):
    cv.ellipse(8, 9, 6, 5.5, (232, 170, 110))
    cv.ellipse(9, 7, 4, 3.5, (246, 205, 160))
    cv.ellipse(10, 6, 2.2, 2, (255, 235, 205))
    cv.px(10, 6, (200, 120, 80), FLAT)
    cv.poly([(3, 10), (1, 13), (4, 12)], (232, 170, 110))


@icon("ui_shard")
def _(cv):
    cv.poly([(8, 1), (12, 7), (10, 14), (6, 14), (4, 7)], CYAN)
    cv.poly([(8, 2), (9, 7), (8, 12), (7, 7)], WHITE, LIGHT)
    cv.line(4, 7, 6, 14, (40, 120, 140), FLAT)
    cv.px(10, 4, WHITE, SHINE)


@icon("ui_hp")
def _(cv):
    heart(cv, 8, 7, 4, (230, 70, 90))


@icon("ui_atk")
def _(cv):
    sword(cv, 3, 13, 13, 3)


@icon("ui_def")
def _(cv):
    shield(cv, IRON, STEEL)


@icon("ui_spd")
def _(cv):
    cv.poly([(4, 3), (9, 3), (11, 12), (14, 12), (14, 14), (4, 14)], (190, 120, 70))
    for y in (5, 8, 11):
        cv.hline(0, 2, y, WHITE, FLAT)


# --------------------------------------------------------------- theme ----

def frame_panel(w, h, fill, edge_hi, edge_lo, outer=(16, 14, 24), corner=None, alpha=255, inner_line=None):
    a = np.zeros((h, w, 4), np.uint8)
    a[..., :3] = fill
    a[..., 3] = alpha
    a[0, :, :3] = outer; a[-1, :, :3] = outer; a[:, 0, :3] = outer; a[:, -1, :3] = outer
    a[0, :, 3] = a[-1, :, 3] = a[:, 0, 3] = a[:, -1, 3] = 255
    for (sl, c) in (((1, slice(1, w - 1)), edge_hi), ((slice(1, h - 1), 1), edge_hi),
                    ((h - 2, slice(1, w - 1)), edge_lo), ((slice(1, h - 1), w - 2), edge_lo)):
        a[sl[0], sl[1], :3] = c
        a[sl[0], sl[1], 3] = 255
    if inner_line is not None:
        a[2, 2:w - 2, :3] = inner_line
        a[2, 2:w - 2, 3] = 255
    for (y, x) in ((0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)):
        a[y, x, 3] = 0
    if corner is not None:
        for (y, x) in ((2, 2), (2, w - 3), (h - 3, 2), (h - 3, w - 3)):
            a[y, x, :3] = corner
            a[y, x, 3] = 255
    return a


def theme_pieces():
    out = {}
    out["panel"] = (frame_panel(24, 24, (22, 28, 44), (150, 108, 62), (88, 58, 36), corner=(236, 190, 90),
                                alpha=236, inner_line=(40, 48, 70)), 6)
    out["panel_light"] = (frame_panel(24, 24, (232, 214, 172), (255, 244, 214), (176, 140, 92), outer=(70, 46, 30),
                                      corner=(170, 120, 60)), 6)
    out["panel_flat"] = (frame_panel(12, 12, (16, 20, 32), (40, 50, 74), (30, 36, 54), outer=(10, 10, 16), alpha=210), 3)
    out["tooltip"] = (frame_panel(12, 12, (30, 26, 40), (90, 80, 110), (54, 46, 68), outer=(8, 8, 12), alpha=244), 3)
    out["hudbar"] = (frame_panel(16, 16, (18, 22, 36), (120, 86, 52), (70, 48, 32), alpha=220), 4)
    for state, fill, hi, lo in (("normal", (126, 82, 48), (196, 144, 88), (78, 48, 30)),
                                ("hover", (150, 100, 58), (226, 176, 112), (92, 58, 34)),
                                ("pressed", (96, 60, 36), (78, 48, 30), (150, 100, 58)),
                                ("disabled", (70, 66, 72), (100, 96, 104), (50, 46, 54))):
        out["btn_" + state] = (frame_panel(16, 16, fill, hi, lo, outer=(30, 18, 16)), 4)
    for state, fill, hi, lo in (("normal", (176, 128, 40), (250, 214, 110), (120, 80, 26)),
                                ("hover", (200, 150, 54), (255, 232, 140), (136, 92, 30)),
                                ("pressed", (140, 98, 30), (120, 80, 26), (200, 150, 54))):
        out["btnp_" + state] = (frame_panel(16, 16, fill, hi, lo, outer=(46, 26, 14)), 4)
    out["tab_on"] = (frame_panel(16, 16, (40, 48, 72), (150, 108, 62), (40, 48, 72), outer=(16, 14, 24)), 4)
    out["tab_off"] = (frame_panel(16, 16, (24, 28, 42), (70, 56, 50), (24, 28, 42), outer=(16, 14, 24), alpha=230), 4)
    out["slot"] = (frame_panel(20, 20, (34, 30, 44), (20, 18, 28), (88, 74, 90), outer=(12, 10, 16)), 4)
    out["slot_sel"] = (frame_panel(20, 20, (60, 52, 40), (250, 214, 110), (200, 150, 54), outer=(46, 26, 14)), 4)
    out["chip"] = (frame_panel(10, 10, (44, 40, 60), (80, 74, 100), (32, 28, 44), outer=(10, 10, 16)), 3)
    out["bar_bg"] = (frame_panel(8, 6, (14, 12, 20), (10, 8, 14), (40, 36, 50), outer=(6, 6, 10)), 2)
    for name, c in (("hp", (220, 70, 70)), ("hp_ally", (96, 200, 96)), ("xp", (90, 160, 240)),
                    ("sta", (240, 196, 70)), ("food", (230, 140, 70)), ("hull", (176, 140, 96)), ("mp", (160, 110, 230))):
        a = np.zeros((4, 4, 4), np.uint8)
        a[..., :3] = c
        a[..., 3] = 255
        a[0, :, :3] = mix(c, (255, 255, 255), 0.4)
        a[-1, :, :3] = mul(c, 0.7)
        out["fill_" + name] = (a, 1)
    out["line_h"] = (np.array([[[150, 108, 62, 255]] * 4, [[60, 40, 26, 255]] * 4], np.uint8), 1)
    for name, on in (("check_off", False), ("check_on", True)):
        cv = Canvas(12, 12)
        cv.rect(1, 1, 10, 10, (40, 36, 52), FLAT)
        cv.rect(2, 2, 9, 9, (24, 22, 32), FLAT)
        if on:
            cv.line(3, 6, 5, 8, GREEN, FLAT, th=2)
            cv.line(5, 8, 8, 3, GREEN, FLAT, th=2)
        out[name] = (cv.render(), 0)
    # scrollbar
    out["scroll_bg"] = (frame_panel(6, 12, (16, 14, 24), (10, 8, 14), (30, 28, 40), outer=(6, 6, 10)), 2)
    out["scroll_grab"] = (frame_panel(6, 12, (150, 108, 62), (210, 160, 100), (96, 64, 38), outer=(30, 18, 16)), 2)
    # portrait frame
    pf = frame_panel(28, 28, (40, 52, 76), (220, 176, 90), (130, 90, 40), outer=(30, 18, 16))
    out["portrait"] = (pf, 4)
    # banner ribbon for titles
    rib = np.zeros((14, 32, 4), np.uint8)
    for y in range(14):
        for x in range(32):
            if 2 <= y <= 11 and 3 <= x <= 28:
                rib[y, x] = (*((176, 52, 52) if 3 < y < 10 else (130, 34, 40)), 255)
    rib[2, 3:29] = (230, 110, 100, 255)
    for x in range(0, 4):
        for y in range(4 + x // 2, 14 - x // 2):
            rib[y, x] = (110, 30, 36, 255)
            rib[y, 31 - x] = (110, 30, 36, 255)
    out["ribbon"] = (rib, 6)
    return out


# ------------------------------------------------------ iso markers ------

def diamond(w=32, h=16):
    m = np.zeros((h, w), bool)
    for y in range(h):
        k = y if y < h // 2 else h - 1 - y
        m[y, w // 2 - 2 - 2 * k:w // 2 + 2 + 2 * k] = True
    return m


def iso_markers():
    m = diamond()
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    edge[0, :] = m[0, :]
    edge[-1, :] = m[-1, :]
    out = {}
    for name, c, fill in (("sel", (255, 255, 255), 0), ("hover", (252, 226, 104), 40), ("ok", (110, 230, 120), 70),
                          ("bad", (240, 80, 70), 80), ("target", (240, 80, 70), 0), ("ally", (110, 200, 250), 0),
                          ("move", (252, 226, 104), 0)):
        a = np.zeros((16, 32, 4), np.uint8)
        if fill:
            a[m] = (*c, fill)
        a[edge] = (*c, 255)
        if name in ("target", "ally", "move"):
            # corner brackets only
            keep = np.zeros_like(edge)
            keep[:, :9] = True
            keep[:, 23:] = True
            keep[:3, 12:20] = True
            keep[13:, 12:20] = True
            a[edge & ~keep] = 0
        out["iso_" + name] = a
    dot = np.zeros((5, 9, 4), np.uint8)
    dm = diamond(9, 5)
    dot[dm] = (252, 226, 104, 200)
    out["iso_dot"] = dot
    sh = np.zeros((7, 18, 4), np.uint8)
    yy, xx = np.mgrid[0:7, 0:18]
    e = ((xx - 8.5) / 8.6) ** 2 + ((yy - 3) / 3.4) ** 2
    sh[e <= 1.0] = (10, 14, 30, 90)
    sh[e <= 0.55] = (10, 14, 30, 120)
    out["shadow"] = sh
    big = np.zeros((11, 28, 4), np.uint8)
    yy, xx = np.mgrid[0:11, 0:28]
    e = ((xx - 13.5) / 13.6) ** 2 + ((yy - 5) / 5.4) ** 2
    big[e <= 1.0] = (10, 14, 30, 90)
    big[e <= 0.55] = (10, 14, 30, 120)
    out["shadow_big"] = big
    return out


# ------------------------------------------------------- emote bubbles ----

def bubble(sym):
    cv = Canvas(14, 14)
    cv.ellipse(6.5, 5.5, 5.5, 4.6, WHITE, FLAT)
    cv.poly([(4, 9), (8, 9), (3, 13)], WHITE, FLAT)
    if sym == "!":
        cv.rect(6, 2, 7, 6, RED, FLAT); cv.rect(6, 8, 7, 8, RED, FLAT)
    elif sym == "?":
        cv.rect(5, 2, 8, 2, BLUE, FLAT); cv.rect(8, 3, 8, 4, BLUE, FLAT); cv.rect(6, 5, 7, 5, BLUE, FLAT)
        cv.rect(6, 6, 6, 6, BLUE, FLAT); cv.rect(6, 8, 6, 8, BLUE, FLAT)
    elif sym == "...":
        for x in (3, 6, 9):
            cv.px(x, 6, DARK, FLAT)
    elif sym == "heart":
        heart(cv, 6.5, 4.5, 2.2, (230, 70, 100))
    elif sym == "note":
        cv.vline(8, 2, 7, DARK, FLAT); cv.ellipse(6.5, 7.5, 1.6, 1.2, DARK, FLAT); cv.rect(8, 2, 10, 3, DARK, FLAT)
    elif sym == "anger":
        for (x, y) in ((4, 3), (8, 3), (4, 7), (8, 7)):
            cv.px(x, y, RED, FLAT); cv.px(x + 1, y + (1 if y < 5 else -1), RED, FLAT)
    elif sym == "sweat":
        drop(cv, 6.5, 5.5, 2.6, (100, 180, 240))
    elif sym == "zzz":
        cv.hline(3, 6, 3, BLUE, FLAT); cv.line(6, 3, 3, 6, BLUE, FLAT); cv.hline(3, 6, 6, BLUE, FLAT)
        cv.hline(7, 9, 5, BLUE, FLAT); cv.line(9, 5, 7, 7, BLUE, FLAT); cv.hline(7, 9, 7, BLUE, FLAT)
    elif sym == "food":
        cv.ellipse(7, 5, 3, 2.5, (200, 110, 62), FLAT); cv.line(4, 7, 3, 8, CREAM, FLAT)
    elif sym == "coin":
        cv.ellipse(6.5, 5.5, 2.8, 2.8, GOLD, FLAT); cv.vline(6, 4, 7, YELLOW, FLAT)
    return cv.render(ol_tint=(30, 30, 50), ol_mix=0.6)


# ------------------------------------------------------------- FX --------

def fx_strip(n, w, h, draw, outline=True):
    frames = []
    for f in range(n):
        cv = Canvas(w, h)
        draw(cv, f, n)
        frames.append(cv.render(outline=outline, ol_tint=(40, 40, 60), ol_mix=0.5, ol_mul=0.55))
    return np.concatenate(frames, 1)


def fx_steam(cv, f, n, base=(236, 240, 246)):
    for k in range(3):
        t = ((f + k * n / 3) % n) / n
        y = 14 - t * 12
        r = 1.6 + t * 2.4
        x = 8 + math.sin((t + k) * 4) * 2
        if t < 0.92:
            cv.ellipse(x, y, r, r * 0.85, base)


def fx_smoke(cv, f, n):
    fx_steam(cv, f, n, (120, 116, 130))


def fx_sparks(cv, f, n):
    for k in range(7):
        a = math.radians(k * 51 + 20)
        d = 2 + f * 2
        x, y = 8 + d * math.cos(a), 9 + d * math.sin(a) * 0.8 + f * 0.6
        c = YELLOW if (k + f) % 2 else ORANGE
        if f < n - 1 or k % 2:
            cv.px(x, y, c, FLAT)
            if f < 2:
                cv.px(x - math.cos(a), y - math.sin(a) * 0.8, c, FLAT)


def fx_notes(cv, f, n):
    for k in range(2):
        t = ((f + k * n / 2) % n) / n
        x, y = 4 + k * 6 + math.sin(t * 6) * 1.5, 13 - t * 10
        cv.vline(x + 2, y - 4, y, (250, 240, 200), FLAT)
        cv.ellipse(x + 0.5, y, 1.6, 1.2, (250, 240, 200), FLAT)
        cv.px(x + 3, y - 4, (250, 240, 200), FLAT)


def fx_bubbles(cv, f, n):
    for k in range(3):
        t = ((f + k * n / 3) % n) / n
        x, y = 4 + k * 4 + math.sin(t * 6 + k) * 1.5, 14 - t * 12
        r = 1 + k * 0.4
        cv.ellipse(x, y, r, r, (180, 230, 250))
        cv.px(x - 0.5, y - 0.5, WHITE, SHINE)


def fx_heart(cv, f, n):
    s = [1.6, 2.4, 2.8, 2.6][f % 4]
    heart(cv, 8, 9 - f, s, (240, 90, 120))


def fx_zzz(cv, f, n):
    for k in range(3):
        t = ((f + k * n / 3) % n) / n
        x, y, s = 3 + t * 7, 12 - t * 10, 2 + round(t * 2)
        cv.hline(x, x + s, y, LILAC, FLAT)
        cv.line(x + s, y, x, y + s, LILAC, FLAT)
        cv.hline(x, x + s, y + s, LILAC, FLAT)


def fx_heal(cv, f, n):
    for k in range(3):
        t = ((f + k * n / 3) % n) / n
        x, y = 3 + k * 5, 14 - t * 12
        plus(cv, x + 1, y, 2, 0.5, (120, 240, 130), FLAT)
    if f % 2 == 0:
        cv.px(8, 4 + f, WHITE, SHINE)


def fx_hit(cv, f, n):
    r1 = [4, 7, 8, 6][f]
    r2 = [2, 3, 3.5, 2][f]
    c = [WHITE, (255, 250, 210), YELLOW, (250, 200, 120)][f]
    star(cv, 10, 10, r1, r2, c, FLAT, n=6, rot=-90 + f * 12)
    if f < 2:
        cv.ellipse(10, 10, r2 - 0.5, r2 - 0.5, WHITE, SHINE)


def fx_slash(cv, f, n):
    a0 = -150 + f * 40
    for i in range(10):
        a = math.radians(a0 + i * 9)
        w = 1 + (i > 2 and i < 8)
        for rr in range(9 - w, 10):
            cv.px(12 + rr * math.cos(a), 12 + rr * math.sin(a), WHITE if rr >= 9 else (200, 240, 255), FLAT)
    if f == n - 1:
        cv.m[:] = np.where(np.random.default_rng(1).random(cv.m.shape) < 0.5, cv.m, 0)


def fx_splash(cv, f, n):
    h = [3, 6, 7, 5, 2][f]
    for k, dx in enumerate((-4, -2, 0, 2, 4)):
        hh = h - abs(dx) // 2
        if hh > 0:
            cv.vline(8 + dx, 14 - hh, 14, (210, 240, 255), FLAT)
    if f >= 2:
        for dx in (-5, 5):
            cv.px(8 + dx, 14 - h, WHITE, SHINE)
    cv.ellipse(8, 14, 3 + f, 1, (160, 210, 240), FLAT)


def fx_fire(cv, f, n):
    flame(cv, 6, 9 - (f % 2), 4.5 + (f % 2) * 0.6, (236, 90, 40), YELLOW)
    if f % 2:
        cv.px(4, 2, ORANGE, FLAT)
    else:
        cv.px(8, 1, ORANGE, FLAT)


def fx_dust(cv, f, n):
    for k, dx in enumerate((-4, 0, 4)):
        r = 1.2 + f * 0.6
        cv.ellipse(8 + dx * (1 + f * 0.3), 5 - f * 0.4, r, r * 0.7, (220, 206, 176) if f < 3 else (190, 176, 150))


def fx_sparkle(cv, f, n):
    for k in range(4):
        t = ((f + k * n / 4) % n) / n
        a = math.radians(k * 90 + 45)
        x, y = 6 + 4 * math.cos(a) * t, 6 + 4 * math.sin(a) * t - t * 2
        s = 2 if t < 0.5 else 1
        cv.hline(x - s, x + s, y, (255, 250, 200), FLAT)
        cv.vline(x, y - s, y + s, (255, 250, 200), FLAT)


def fx_coin(cv, f, n):
    w = [3.2, 2.4, 1.0, 0.5, 1.0, 2.4][f]
    cv.ellipse(4, 4, w, 3.2, GOLD)
    if w > 1:
        cv.vline(4, 3, 5, YELLOW, SHINE)


def fx_orb(cv, f, n):
    r = 3 + (f % 2) * 0.6
    cv.ellipse(5, 5, r, r, (230, 240, 255))
    cv.ellipse(5, 5, r - 1.4, r - 1.4, WHITE, SHINE)


def fx_bullet(cv, f, n):
    cv.rect(2, 3, 5, 4, (60, 60, 70))
    cv.rect(0, 3 + f % 2, 1, 3 + f % 2, (250, 220, 120), FLAT)


def fx_arrow(cv, f, n):
    cv.hline(1, 10, 2, WOOD_L)
    cv.poly([(10, 0.5), (13, 2.5), (10, 4.5)], STEEL)
    cv.rect(0, 1, 2, 1, WHITE, FLAT)
    cv.rect(0, 3, 2, 3, WHITE, FLAT)


def fx_wake(cv, f, n):
    for k in range(4):
        t = ((f + k * n / 4) % n) / n
        x = 2 + t * 24
        r = 1 + t * 2
        cv.ellipse(x, 4 + math.sin(t * 6) * 0.5, r, r * 0.5, (236, 246, 255))


FX = {
    "steam": (6, 16, 16, fx_steam, False), "smoke": (6, 16, 16, fx_smoke, False),
    "sparks": (4, 16, 16, fx_sparks, False), "notes": (6, 16, 16, fx_notes, True),
    "bubbles": (6, 16, 16, fx_bubbles, True), "heart": (4, 16, 16, fx_heart, True),
    "zzz": (6, 16, 16, fx_zzz, True), "heal": (6, 16, 16, fx_heal, True),
    "hit": (4, 20, 20, fx_hit, True), "slash": (4, 24, 24, fx_slash, False),
    "splash": (5, 16, 16, fx_splash, False), "fire": (4, 12, 16, fx_fire, True),
    "dust": (4, 16, 8, fx_dust, False), "sparkle": (6, 12, 12, fx_sparkle, False),
    "coin": (6, 8, 8, fx_coin, True), "orb": (4, 10, 10, fx_orb, True),
    "bullet": (2, 6, 7, fx_bullet, False), "arrow": (1, 14, 5, fx_arrow, True),
    "wake": (6, 28, 8, fx_wake, False),
}


# ------------------------------------------------------- cursor + icon ----

def cursor():
    cv = Canvas(16, 16)
    pts = [(1, 1), (1, 13), (4.5, 10), (7, 15), (9, 14), (6.8, 9.2), (11.5, 9.2)]
    cv.poly(pts, CREAM)
    cv.poly([(2, 3), (2, 10), (5, 8)], WHITE, SHINE)
    return cv.render(ol_tint=(30, 18, 16), ol_mix=0.7, ol_mul=0.2)


def app_icon():
    cv = Canvas(32, 32)
    cv.ellipse(15.5, 15.5, 15, 15, (40, 70, 120), FLAT)
    cv.ellipse(15.5, 15.5, 13.5, 13.5, (70, 140, 210), FLAT)
    cv.rect(2, 21, 29, 30, (44, 96, 170), FLAT)
    for x in range(3, 29, 5):
        cv.hline(x, x + 2, 22 + (x % 3), (170, 220, 250), FLAT)
    cv.ellipse(24, 8, 3, 3, (252, 226, 104), FLAT)
    cv.vline(15, 4, 21, WOOD_D)
    cv.poly([(16, 5), (25, 18), (16, 18)], WHITE)
    cv.poly([(14, 7), (14, 18), (7, 18)], CREAM)
    cv.poly([(15, 3.5), (21, 5), (15, 6.5)], RED)
    cv.poly([(5, 19), (27, 19), (24, 25), (8, 25)], WOOD)
    cv.hline(7, 25, 21, WOOD_D, FLAT)
    for x in (10, 15, 20):
        cv.px(x, 22, GOLD, FLAT)
    a = cv.render(ol_tint=(20, 16, 30), ol_mix=0.6)
    # clip to a circle so the outline does not square the badge
    yy, xx = np.mgrid[0:32, 0:32]
    a[((xx - 15.5) ** 2 + (yy - 15.5) ** 2) > 16.4 ** 2] = 0
    return a


# -------------------------------------------------------------- build ----

def build():
    out_dir = OUT / "ui"
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"icons": {}, "theme": {}, "markers": {}, "fx": {}, "bubbles": {}}

    names = list(ICONS)
    cols = 16
    rows = (len(names) + cols - 1) // cols
    sheet = np.zeros((rows * 16, cols * 16, 4), np.uint8)
    for i, n in enumerate(names):
        cv = Canvas(16, 16)
        ICONS[n](cv)
        img = cv.render()
        x, y = (i % cols) * 16, (i // cols) * 16
        sheet[y:y + 16, x:x + 16] = img
        meta["icons"][n] = [x, y]
    save_png(sheet, out_dir / "icons.png")
    record("game/assets/gen/ui/icons.png", f"{cols * 16}x{rows * 16}", f"{len(names)} icons 16x16",
           "pixel canvas drawing (gen_ui.py)", "HUD/menus: resources, categories, roles, stances, items, hazards, actions")

    pk = Packer(256)
    for name, (arr, margin) in theme_pieces().items():
        pk.add(name, arr, margin=margin)
    for name, arr in iso_markers().items():
        pk.add(name, arr, margin=0)
    for sym, key in (("!", "alert"), ("?", "question"), ("...", "dots"), ("heart", "love"), ("note", "music"),
                     ("anger", "anger"), ("sweat", "sweat"), ("zzz", "sleep"), ("food", "hungry"), ("coin", "coin")):
        pk.add("bubble_" + key, bubble(sym), margin=0)
    pk.add("cursor", cursor(), margin=0)
    rects, (W, H) = pk.pack(out_dir / "ui.png")
    for k, v in rects.items():
        bucket = "markers" if k.startswith(("iso_", "shadow")) else "bubbles" if k.startswith("bubble_") else "theme"
        meta[bucket][k] = v
    record("game/assets/gen/ui/ui.png", f"{W}x{H}", f"{len(rects)} pieces",
           "pixel drawing (gen_ui.py)", "9-slice theme panels/buttons/bars, iso selection & placement diamonds, "
           "shadows, emote bubbles, cursor")

    fy = 0
    strips = []
    for name, (n, w, h, fn, ol) in FX.items():
        strip = fx_strip(n, w, h, fn, ol)
        strips.append((name, strip, n, w, h))
    FW = max(s[1].shape[1] for s in strips)
    FH = sum(s[1].shape[0] + 1 for s in strips)
    fx_sheet = np.zeros((FH, FW, 4), np.uint8)
    for name, strip, n, w, h in strips:
        fx_sheet[fy:fy + h, :strip.shape[1]] = strip
        meta["fx"][name] = {"y": fy, "w": w, "h": h, "frames": n}
        fy += h + 1
    save_png(fx_sheet, out_dir / "fx.png")
    record("game/assets/gen/ui/fx.png", f"{FW}x{FH}", ", ".join(f"{k} x{v[0]}" for k, v in FX.items()),
           "pixel canvas animation (gen_ui.py)", "facility steam/smoke/sparks/notes, crew emotes, combat hit/slash/"
           "projectiles/heal, splashes, wake, coins")

    ic = app_icon()
    big = Image.fromarray(ic).resize((256, 256), Image.NEAREST)
    big.save(GAME / "icon.png")
    sizes = [16, 32, 48, 64, 128, 256]
    imgs = [Image.fromarray(ic).resize((s, s), Image.NEAREST if s % 32 == 0 else Image.LANCZOS) for s in sizes]
    imgs[-1].save(GAME / "icon.ico", format="ICO", sizes=[(s, s) for s in sizes], append_images=imgs[:-1])
    record("game/icon.png, game/icon.ico", "256x256 (+ico 16-256)", "1", "pixel drawing 32x32 upscaled (gen_ui.py)",
           "application / window icon")
    save_json(meta, out_dir / "ui.json")

    # previews
    prev = Image.fromarray(sheet)
    bg = Image.new("RGBA", prev.size, (40, 46, 64, 255))
    bg.alpha_composite(prev)
    bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST).save(PREVIEW / "ui_icons.png")
    for nm, arr in (("ui_theme", np.array(Image.open(out_dir / "ui.png"))), ("ui_fx", fx_sheet)):
        im = Image.fromarray(arr)
        bg = Image.new("RGBA", im.size, (60, 90, 120, 255))
        bg.alpha_composite(im)
        bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST).save(PREVIEW / f"{nm}.png")
    return meta


if __name__ == "__main__":
    m = build()
    print(len(m["icons"]), len(m["theme"]), len(m["markers"]), len(m["fx"]))
