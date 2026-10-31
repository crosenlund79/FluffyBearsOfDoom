#!/usr/bin/env python3
"""Generates the template_*.png placeholder art for Fluffy Bears of Doom.

Only files prefixed with ``template_`` are ever written, so your own
replacement art (same name without the prefix) is never touched.

Usage:  python3 tools/generate_placeholders.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
SS = 4  # supersampling factor

random.seed(7)


def rgba(hex_str, a=255):
    hex_str = hex_str.lstrip("#")
    return (int(hex_str[0:2], 16), int(hex_str[2:4], 16), int(hex_str[4:6], 16), a)


class Canvas:
    """A supersampled RGBA canvas; coordinates are given in final pixels."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _b(self, box):
        return [v * SS for v in box]

    def ellipse(self, cx, cy, rx, ry, fill=None, outline=None, width=1):
        self.d.ellipse(self._b((cx - rx, cy - ry, cx + rx, cy + ry)), fill=fill, outline=outline,
                       width=int(width * SS) if outline else 0)

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width=1, radius=0):
        self.d.rounded_rectangle(self._b((x0, y0, x1, y1)), radius=radius * SS, fill=fill, outline=outline,
                                 width=int(width * SS) if outline else 0)

    def line(self, pts, fill, width=1):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=int(width * SS), joint="curve")

    def polygon(self, pts, fill=None, outline=None):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill, outline=outline)

    def arc(self, cx, cy, rx, ry, a0, a1, fill, width=1):
        self.d.arc(self._b((cx - rx, cy - ry, cx + rx, cy + ry)), a0, a1, fill=fill, width=int(width * SS))

    def dashed_ellipse(self, cx, cy, rx, ry, fill, width=1.2, dashes=24, duty=0.55, a0=0, a1=360):
        span = (a1 - a0) / dashes
        for i in range(dashes):
            s = a0 + i * span
            self.arc(cx, cy, rx, ry, s, s + span * duty, fill, width)

    def dashed_line(self, x0, y0, x1, y1, fill, width=1.2, dash=4, gap=3):
        length = math.hypot(x1 - x0, y1 - y0)
        if length == 0:
            return
        ux, uy = (x1 - x0) / length, (y1 - y0) / length
        t = 0
        while t < length:
            e = min(t + dash, length)
            self.line([(x0 + ux * t, y0 + uy * t), (x0 + ux * e, y0 + uy * e)], fill, width)
            t += dash + gap

    def result(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def paste(sheet, img, x, y):
    sheet.alpha_composite(img, (x, y))


def plush_blob(c, cx, cy, rx, ry, base, fuzz=True, shade=True):
    """A soft fabric shape with fuzzy edge and radial shading."""
    if fuzz:
        n = int((rx + ry) * 0.9)
        for i in range(n):
            a = 2 * math.pi * i / n
            px = cx + math.cos(a) * rx * 0.97
            py = cy + math.sin(a) * ry * 0.97
            r = 2.2 + random.random() * 1.6
            c.ellipse(px, py, r, r, fill=base)
    c.ellipse(cx, cy, rx, ry, fill=base)
    if shade:
        # darker lower rim, lighter top highlight => plush volume
        steps = 10
        for i in range(steps):
            k = i / steps
            col = (int(base[0] * (0.82 + 0.18 * k)), int(base[1] * (0.82 + 0.18 * k)),
                   int(base[2] * (0.82 + 0.18 * k)), 255)
            c.ellipse(cx - rx * 0.05 * k, cy - ry * 0.12 * k, rx * (1 - 0.55 * k), ry * (1 - 0.55 * k), fill=col)
        c.ellipse(cx - rx * 0.3, cy - ry * 0.45, rx * 0.22, ry * 0.12, fill=(255, 255, 255, 45))


# ---------------------------------------------------------------- bear sheet
# 10 cells in one row, each 128x128:
# 0 body, 1 belly, 2 head, 3 ear, 4 arm, 5 leg, 6 face normal, 7 face smug,
# 8 face indignant, 9 face stunned.
BEAR_CELL = 128
FUR = rgba("f3ede6")
FUR_DARK = rgba("c9bfb4")
STITCH = rgba("8d7f72")


def bear_body():
    c = Canvas(128, 128)
    plush_blob(c, 64, 66, 46, 50, FUR)
    c.dashed_line(64, 22, 64, 110, STITCH, 1.4, 4, 3)  # centre seam
    # little patch on the side
    c.rect(82, 34, 100, 50, fill=rgba("e4dbd0"), radius=3)
    c.rect(82, 34, 100, 50, outline=STITCH, width=1.0, radius=3)
    c.dashed_line(84, 36, 98, 48, STITCH, 1.0, 2, 2)
    c.dashed_line(98, 36, 84, 48, STITCH, 1.0, 2, 2)
    return c.result()


def bear_belly():
    c = Canvas(128, 128)
    plush_blob(c, 64, 64, 40, 44, rgba("fffaf2"), fuzz=False)
    c.dashed_ellipse(64, 64, 36, 40, rgba("b9aa98"), 1.6, 30)
    # tiny heart patch
    c.ellipse(58, 76, 5, 5, fill=rgba("f2c4c8"))
    c.ellipse(68, 76, 5, 5, fill=rgba("f2c4c8"))
    c.polygon([(53, 78), (73, 78), (63, 89)], fill=rgba("f2c4c8"))
    return c.result()


def bear_head():
    c = Canvas(128, 128)
    plush_blob(c, 64, 66, 52, 48, FUR)
    c.dashed_line(64, 20, 64, 40, STITCH, 1.3, 3, 3)
    return c.result()


def bear_ear():
    c = Canvas(128, 128)
    plush_blob(c, 64, 64, 22, 22, FUR)
    c.ellipse(64, 66, 12, 12, fill=rgba("fbe9e6"))
    c.dashed_ellipse(64, 66, 12, 12, STITCH, 1.0, 14)
    return c.result()


def bear_arm():
    c = Canvas(128, 128)
    c.rect(48, 34, 80, 96, fill=FUR, radius=16)
    c.rect(48, 34, 60, 96, fill=(225, 216, 206, 255), radius=10)
    c.rect(52, 34, 80, 92, fill=FUR, radius=14)
    c.ellipse(64, 86, 12, 10, fill=rgba("fbf1e6"))
    c.dashed_ellipse(64, 86, 12, 10, STITCH, 0.9, 12)
    return c.result()


def bear_leg():
    c = Canvas(128, 128)
    c.rect(46, 40, 82, 92, fill=FUR, radius=17)
    c.ellipse(64, 84, 15, 9, fill=rgba("fbf1e6"))
    for dx in (-8, 0, 8):
        c.ellipse(64 + dx, 77, 3, 2.4, fill=rgba("f3dcd6"))
    return c.result()


EYE = rgba("2b2220")
MUZZLE = rgba("f7ead8")
NOSE = rgba("4a3127")
MOUTH = rgba("5a3a2e")
BLUSH = rgba("f0a9ad", 150)


def face_base(c):
    c.ellipse(64, 84, 22, 16, fill=MUZZLE)
    c.dashed_ellipse(64, 84, 22, 16, rgba("c8b49c"), 1.0, 26)
    c.ellipse(64, 76, 7, 5, fill=NOSE)
    c.ellipse(62, 74.5, 2.4, 1.4, fill=(255, 255, 255, 120))
    c.ellipse(32, 82, 8, 5, fill=BLUSH)
    c.ellipse(96, 82, 8, 5, fill=BLUSH)


def button_eye(c, x, y, r=8.5):
    c.ellipse(x, y, r, r, fill=EYE)
    c.ellipse(x, y, r * 0.72, r * 0.72, outline=rgba("4f403a"), width=1.0)
    for dx, dy in ((-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)):
        c.ellipse(x + dx, y + dy, 1.2, 1.2, fill=rgba("6d5a52"))
    c.ellipse(x - 3, y - 3.5, 2.2, 1.6, fill=(255, 255, 255, 170))


def face_normal():
    c = Canvas(128, 128)
    face_base(c)
    button_eye(c, 42, 58)
    button_eye(c, 86, 58)
    c.line([(64, 81), (64, 87)], MOUTH, 1.6)
    c.arc(57, 85, 7, 5, 10, 170, MOUTH, 1.6)
    c.arc(71, 85, 7, 5, 10, 170, MOUTH, 1.6)
    return c.result()


def face_smug():
    c = Canvas(128, 128)
    face_base(c)
    # half-closed, very pleased button eyes
    for x in (42, 86):
        c.d.pieslice(c._b((x - 8.5, 51.5, x + 8.5, 68.5)), 0, 180, fill=EYE)
        c.line([(x - 10, 59), (x + 10, 59)], MOUTH, 2.0)
        c.ellipse(x - 2, 62, 1.2, 1.2, fill=rgba("6d5a52"))
        c.ellipse(x + 2, 62, 1.2, 1.2, fill=rgba("6d5a52"))
    # smirk
    c.line([(64, 81), (64, 86)], MOUTH, 1.6)
    c.arc(64, 82, 13, 8, 15, 120, MOUTH, 1.8)
    c.line([(52, 88), (60, 89)], MOUTH, 1.6)
    return c.result()


def face_indignant():
    c = Canvas(128, 128)
    face_base(c)
    button_eye(c, 42, 60)
    button_eye(c, 86, 60)
    c.line([(30, 44), (54, 51)], MOUTH, 2.6)
    c.line([(98, 44), (74, 51)], MOUTH, 2.6)
    c.ellipse(64, 90, 5, 6, fill=MOUTH)
    c.ellipse(64, 92, 3, 2.5, fill=rgba("d27c80"))
    return c.result()


def face_stunned():
    c = Canvas(128, 128)
    face_base(c)
    for x in (42, 86):
        c.line([(x - 7, 51), (x + 7, 65)], EYE, 3.2)
        c.line([(x + 7, 51), (x - 7, 65)], EYE, 3.2)
    pts = [(50 + i * 2, 89 + math.sin(i * 1.4) * 2.2) for i in range(15)]
    c.line(pts, MOUTH, 1.8)
    return c.result()


def make_bear():
    parts = [bear_body, bear_belly, bear_head, bear_ear, bear_arm, bear_leg,
             face_normal, face_smug, face_indignant, face_stunned]
    sheet = Image.new("RGBA", (BEAR_CELL * len(parts), BEAR_CELL), (0, 0, 0, 0))
    for i, fn in enumerate(parts):
        paste(sheet, fn(), i * BEAR_CELL, 0)
    return sheet


# ---------------------------------------------------------------- tiles
# 9 cells of 64x64: 0 rug, 1 rug alt, 2 ice, 3 honey, 4 bouncy, 5 conveyor (pointing right),
# 6 pillar wall, 7 destructible cushion block, 8 border wall
T = 64


def weave(c, base, line_col, step=8):
    c.rect(0, 0, T, T, fill=base)
    for i in range(0, T, step):
        c.line([(i, 0), (i, T)], line_col, 0.7)
        c.line([(0, i), (T, i)], line_col, 0.7)


def tile_rug(base, accent):
    c = Canvas(T, T)
    weave(c, rgba(base), rgba(accent, 40))
    c.dashed_line(3, 3, T - 3, 3, rgba(accent, 90), 1.0, 4, 3)
    c.dashed_line(3, T - 3, T - 3, T - 3, rgba(accent, 60), 1.0, 4, 3)
    for _ in range(5):
        x, y = random.uniform(8, 56), random.uniform(8, 56)
        c.ellipse(x, y, 1.2, 1.2, fill=rgba(accent, 45))
    return c.result()


def tile_ice():
    c = Canvas(T, T)
    c.rect(0, 0, T, T, fill=rgba("d6ecf4"))
    c.rect(2, 2, T - 2, T - 2, fill=rgba("e2f3f8"), radius=4)
    for i in range(3):
        x = 10 + i * 18
        c.line([(x, 52), (x + 14, 12)], (255, 255, 255, 190), 2.2)
    c.line([(40, 40), (48, 46), (46, 56)], rgba("b4d4e2"), 1.0)
    c.line([(18, 18), (26, 22), (30, 16)], rgba("b4d4e2"), 1.0)
    return c.result()


def tile_honey():
    c = Canvas(T, T)
    c.rect(0, 0, T, T, fill=rgba("e9b84c"))
    for _ in range(6):
        x, y = random.uniform(6, 58), random.uniform(6, 58)
        r = random.uniform(4, 9)
        c.ellipse(x, y, r, r * 0.8, fill=rgba("f2c867"))
        c.ellipse(x - r * 0.3, y - r * 0.3, r * 0.3, r * 0.2, fill=(255, 250, 220, 160))
    return c.result()


def tile_bouncy():
    c = Canvas(T, T)
    c.rect(0, 0, T, T, fill=rgba("f1bcc6"))
    for i in range(-T, T * 2, 16):
        c.dashed_line(i, 0, i + T, T, rgba("d48a99"), 1.0, 3, 3)
        c.dashed_line(i, T, i + T, 0, rgba("d48a99"), 1.0, 3, 3)
    for (x, y) in ((16, 16), (48, 16), (16, 48), (48, 48), (32, 32)):
        c.ellipse(x, y, 3, 3, fill=rgba("c77486"))
    return c.result()


def tile_conveyor():
    c = Canvas(T, T)
    c.rect(0, 0, T, T, fill=rgba("aab4bf"))
    c.rect(0, 8, T, T - 8, fill=rgba("c3ccd5"))
    for x in (8, 30, 52):
        c.line([(x - 6, 20), (x + 6, 32), (x - 6, 44)], rgba("7e8b99"), 3.0)
    c.dashed_line(0, 9, T, 9, rgba("8a96a3"), 1.0, 4, 3)
    c.dashed_line(0, T - 9, T, T - 9, rgba("8a96a3"), 1.0, 4, 3)
    return c.result()


def tile_pillar():
    c = Canvas(T, T)
    # wooden toy block seen slightly from above: top face + front face
    c.rect(2, 4, 62, 62, fill=rgba("9b7556"), radius=7)
    c.rect(2, 2, 62, 46, fill=rgba("c79f78"), radius=7)
    for y in (12, 22, 34):
        c.arc(32, y, 26, 4, 200, 340, rgba("b48b65"), 1.0)
    # carved heart
    c.ellipse(27, 22, 6, 6, fill=rgba("d98e98"))
    c.ellipse(37, 22, 6, 6, fill=rgba("d98e98"))
    c.polygon([(21.5, 24), (42.5, 24), (32, 35)], fill=rgba("d98e98"))
    c.rect(2, 2, 62, 46, outline=rgba("8a6649"), width=1.2, radius=7)
    return c.result()


def tile_block():
    c = Canvas(T, T)
    # a puffy patchwork cushion
    c.rect(4, 8, 60, 62, fill=rgba("b38289", 120), radius=12)
    c.rect(3, 4, 61, 58, fill=rgba("e9c2c4"), radius=14)
    c.rect(6, 6, 32, 30, fill=rgba("f2d6cf"), radius=10)
    c.rect(32, 30, 58, 55, fill=rgba("d9e2cc"), radius=10)
    c.rect(3, 4, 61, 58, outline=rgba("b9858c"), width=1.4, radius=14)
    c.dashed_line(32, 8, 32, 54, rgba("a8747c"), 1.1, 3, 3)
    c.dashed_line(7, 31, 57, 31, rgba("a8747c"), 1.1, 3, 3)
    c.ellipse(32, 31, 3.2, 3.2, fill=rgba("8f6067"))
    c.ellipse(18, 12, 7, 3, fill=(255, 255, 255, 90))
    return c.result()


def tile_border():
    c = Canvas(T, T)
    c.rect(0, 0, T, T, fill=rgba("8c6a52"))
    c.rect(3, 3, T - 3, T - 3, fill=rgba("a27e62"), radius=5)
    for y in (16, 32, 48):
        c.line([(4, y), (T - 4, y)], rgba("8f6d55"), 1.0)
    c.dashed_line(6, 6, T - 6, 6, rgba("e8d6bd", 140), 1.0, 4, 3)
    return c.result()


def make_tiles():
    tiles = [tile_rug("efe6d2", "b9a685"), tile_rug("e4e7d0", "9aa883"), tile_ice(), tile_honey(),
             tile_bouncy(), tile_conveyor(), tile_pillar(), tile_block(), tile_border()]
    sheet = Image.new("RGBA", (T * len(tiles), T), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        paste(sheet, t, i * T, 0)
    return sheet


# ---------------------------------------------------------------- objects
def make_bomb():
    c = Canvas(64, 64)
    # knitted yarn-ball bomb
    c.ellipse(30, 36, 23, 23, fill=rgba("6b5672"))
    for i in range(6):
        a = i * 30
        c.arc(30, 36, 21, 8 + i * 2, a, a + 180, rgba("856f8c"), 1.6)
    c.arc(30, 36, 23, 23, 200, 330, rgba("9a86a0"), 2.0)
    c.ellipse(22, 27, 6, 4, fill=(255, 255, 255, 70))
    # cork + fuse
    c.rect(36, 10, 46, 18, fill=rgba("b08d6a"), radius=2)
    c.line([(41, 12), (46, 6), (52, 5)], rgba("7c6a58"), 2.0)
    return c.result()


def make_fluff():
    c = Canvas(32, 32)
    for (x, y, r) in ((12, 18, 7), (20, 17, 7), (16, 11, 7), (10, 12, 5), (22, 11, 5), (16, 20, 6)):
        c.ellipse(x, y, r, r, fill=rgba("d9d2ca"))
    for (x, y, r) in ((12, 17, 6), (20, 16, 6), (16, 10, 6), (10, 11, 4), (22, 10, 4), (16, 19, 5)):
        c.ellipse(x, y, r, r, fill=rgba("fffdf8"))
    return c.result()


# ---------------------------------------------------------------- powerups
# 4 cells of 64x64: 0 extra bomb, 1 bigger blast, 2 springy stitching (speed), 3 biome shuffle
def badge(c, ring):
    c.ellipse(32, 33, 27, 27, fill=rgba("bfae98", 160))
    c.ellipse(32, 31, 27, 27, fill=rgba("fbf3e3"))
    c.ellipse(32, 31, 27, 27, outline=rgba(ring), width=3)
    c.dashed_ellipse(32, 31, 22, 22, rgba(ring), 1.1, 22)


def pu_bomb():
    c = Canvas(64, 64)
    badge(c, "8f7aa0")
    c.ellipse(30, 35, 12, 12, fill=rgba("6b5672"))
    c.line([(36, 24), (40, 19)], rgba("7c6a58"), 2)
    c.line([(46, 18), (46, 30)], rgba("6c9a63"), 3)
    c.line([(40, 24), (52, 24)], rgba("6c9a63"), 3)
    return c.result()


def pu_fire():
    c = Canvas(64, 64)
    badge(c, "d8908a")
    for i in range(8):
        a = i * math.pi / 4
        c.line([(32 + math.cos(a) * 7, 31 + math.sin(a) * 7), (32 + math.cos(a) * 17, 31 + math.sin(a) * 17)],
               rgba("e39b7f"), 3.5)
    c.ellipse(32, 31, 8, 8, fill=rgba("f3c56f"))
    return c.result()


def pu_speed():
    c = Canvas(64, 64)
    badge(c, "7fa8c2")
    pts = []
    for i in range(60):
        k = i / 59
        pts.append((24 + k * 16 + math.sin(k * math.pi * 8) * 0, 44 - k * 26 + math.sin(k * math.pi * 8) * 0))
    for i in range(5):
        y = 44 - i * 6
        c.arc(32, y, 10, 3.5, 0, 360, rgba("6d8fa6"), 2.4)
    c.ellipse(32, 18, 6, 3, fill=rgba("e6b6bc"))
    return c.result()


def pu_shuffle():
    c = Canvas(64, 64)
    badge(c, "9db87f")
    c.rect(18, 17, 32, 31, fill=rgba("cfe8f1"), radius=3)
    c.rect(32, 17, 46, 31, fill=rgba("efc25b"), radius=3)
    c.rect(18, 31, 32, 45, fill=rgba("f1bcc6"), radius=3)
    c.rect(32, 31, 46, 45, fill=rgba("e8dfc9"), radius=3)
    c.arc(32, 31, 19, 19, 200, 330, rgba("5b4636"), 2.2)
    c.polygon([(47, 19), (52, 25), (44, 25)], fill=rgba("5b4636"))
    c.arc(32, 31, 19, 19, 20, 150, rgba("5b4636"), 2.2)
    c.polygon([(17, 43), (12, 37), (20, 37)], fill=rgba("5b4636"))
    return c.result()


def make_powerups():
    cells = [pu_bomb(), pu_fire(), pu_speed(), pu_shuffle()]
    sheet = Image.new("RGBA", (64 * len(cells), 64), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * 64, 0)
    return sheet


# ---------------------------------------------------------------- effects
# 6 cells of 64x64: 0 blast centre puff, 1 blast arm (horizontal), 2 blast end (pointing right),
# 3 star, 4 dust puff, 5 sparkle
PUFF = rgba("fff6e8")
PUFF_SHADE = rgba("f2d3cf")


def cloud(c, blobs, shade_off=2.5):
    for (x, y, r) in blobs:
        c.ellipse(x, y + shade_off, r, r, fill=PUFF_SHADE)
    for (x, y, r) in blobs:
        c.ellipse(x, y, r, r, fill=PUFF)


def fx_center():
    c = Canvas(64, 64)
    blobs = [(32, 32, 17)] + [(32 + math.cos(a) * 15, 32 + math.sin(a) * 15, 10)
                              for a in [i * math.pi / 4 for i in range(8)]]
    cloud(c, blobs)
    c.ellipse(32, 32, 7, 7, fill=rgba("fbe3a6"))
    return c.result()


def fx_arm():
    c = Canvas(64, 64)
    cloud(c, [(x, 32 + (4 if i % 2 else -4), 13) for i, x in enumerate(range(0, 72, 12))])
    return c.result()


def fx_end():
    c = Canvas(64, 64)
    cloud(c, [(0, 30, 13), (12, 34, 13), (24, 30, 12), (34, 33, 10), (42, 31, 7)])
    return c.result()


def fx_star():
    c = Canvas(64, 64)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 26 if i % 2 == 0 else 11
        pts.append((32 + math.cos(a) * r, 33 + math.sin(a) * r))
    c.polygon(pts, fill=rgba("f6d77a"))
    inner = [(32 + (x - 32) * 0.7, 33 + (y - 33) * 0.7) for x, y in pts]
    c.polygon(inner, fill=rgba("fbe7a8"))
    c.ellipse(27, 30, 2.4, 2.4, fill=rgba("6b4a3a"))
    c.ellipse(37, 30, 2.4, 2.4, fill=rgba("6b4a3a"))
    c.arc(32, 36, 4, 3, 20, 160, rgba("6b4a3a"), 1.4)
    return c.result()


def fx_dust():
    c = Canvas(64, 64)
    for (x, y, r) in ((24, 36, 13), (40, 36, 12), (32, 26, 13), (20, 26, 8), (44, 26, 8)):
        c.ellipse(x, y, r, r, fill=rgba("e7dccb"))
    for (x, y, r) in ((24, 34, 10), (40, 34, 9), (32, 24, 10)):
        c.ellipse(x, y, r, r, fill=rgba("f3ebde"))
    return c.result()


def fx_sparkle():
    c = Canvas(64, 64)
    c.polygon([(32, 6), (37, 27), (58, 32), (37, 37), (32, 58), (27, 37), (6, 32), (27, 27)], fill=rgba("ffffff"))
    c.ellipse(32, 32, 5, 5, fill=rgba("fff2c4"))
    return c.result()


def make_effects():
    cells = [fx_center(), fx_arm(), fx_end(), fx_star(), fx_dust(), fx_sparkle()]
    sheet = Image.new("RGBA", (64 * len(cells), 64), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * 64, 0)
    return sheet


def make_icon():
    # a tinted bear head for the project icon
    bear = make_bear()
    cell = lambda i: bear.crop((i * BEAR_CELL, 0, (i + 1) * BEAR_CELL, BEAR_CELL))

    def tint(im, col):
        r, g, b, a = im.split()
        r = r.point(lambda v: v * col[0] // 255)
        g = g.point(lambda v: v * col[1] // 255)
        b = b.point(lambda v: v * col[2] // 255)
        return Image.merge("RGBA", (r, g, b, a))

    col = rgba("d9a66b")
    icon = Image.new("RGBA", (128, 128), rgba("f4ecdc"))
    ear = tint(cell(3), col).resize((70, 70), Image.LANCZOS)
    icon.alpha_composite(ear, (2, 6))
    icon.alpha_composite(ear, (56, 6))
    icon.alpha_composite(tint(cell(2), col), (0, 4))
    icon.alpha_composite(cell(6), (0, 4))
    return icon


def save(img, *path):
    full = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    assert os.path.basename(full).startswith("template_")
    img.save(full)
    print("wrote", os.path.relpath(full))


if __name__ == "__main__":
    save(make_bear(), "bears", "template_bear.png")
    save(make_tiles(), "tiles", "template_tiles.png")
    save(make_bomb(), "objects", "template_bomb.png")
    save(make_fluff(), "objects", "template_fluff.png")
    save(make_powerups(), "powerups", "template_powerups.png")
    save(make_effects(), "effects", "template_effects.png")
    make_icon().save(os.path.join(ROOT, "..", "..", "icon.png"))
