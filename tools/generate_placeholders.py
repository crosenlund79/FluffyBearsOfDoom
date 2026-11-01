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
    """A stitched fabric toy bomb. Drawn pale so the game can tint it pastel."""
    c = Canvas(64, 64)
    outline = rgba("6e5f57")
    c.ellipse(31, 37, 23.5, 23.5, fill=outline)
    c.ellipse(31, 37, 22, 22, fill=rgba("ece6e0"))
    c.ellipse(29, 34, 19, 19, fill=rgba("fbf9f6"))
    c.ellipse(23, 27, 6, 4, fill=(255, 255, 255, 200))
    # ball-panel seams
    c.dashed_ellipse(31, 37, 10, 21, rgba("a89383"), 1.3, 18, 0.55, 0, 360)
    c.dashed_line(10, 37, 52, 37, rgba("a89383"), 1.3, 3, 3)
    # a little heart patch
    c.ellipse(41, 47, 3.4, 3.4, fill=rgba("e9b9c0"))
    c.ellipse(46, 47, 3.4, 3.4, fill=rgba("e9b9c0"))
    c.polygon([(37.8, 48), (49.2, 48), (43.5, 54)], fill=rgba("e9b9c0"))
    # fabric knot + braided yarn fuse
    c.rect(34, 11, 46, 19, fill=rgba("c9a98a"), radius=3)
    c.rect(34, 11, 46, 19, outline=outline, width=1.0, radius=3)
    c.dashed_line(36, 15, 45, 15, rgba("8a6e57"), 1.0, 2, 2)
    pts = [(40 + i * 0.9, 11 - math.sin(i * 0.5) * 3 - i * 0.6) for i in range(14)]
    c.line(pts, rgba("b48f6e"), 2.4)
    for x, y in pts[::3]:
        c.ellipse(x, y, 1.0, 1.0, fill=rgba("f3e3cc"))
    return c.result()


def make_fluff():
    c = Canvas(32, 32)
    for (x, y, r) in ((12, 18, 7), (20, 17, 7), (16, 11, 7), (10, 12, 5), (22, 11, 5), (16, 20, 6)):
        c.ellipse(x, y, r, r, fill=rgba("d9d2ca"))
    for (x, y, r) in ((12, 17, 6), (20, 16, 6), (16, 10, 6), (10, 11, 4), (22, 10, 4), (16, 19, 5)):
        c.ellipse(x, y, r, r, fill=rgba("fffdf8"))
    return c.result()


# ---------------------------------------------------------------- powerups
# 10 cells of 64x64: 0 extra bomb, 1 bigger blast, 2 springy stitching (speed), 3 biome shuffle,
# 4 bomb kick, 5 line bomb, 6 rubber bomb, 7 immortality, 8 reverse controls (curse), 9 bomb diarrhea (curse)
CONFETTI = ["f2a7b5", "a7c8e8", "f5dc8a", "a8dcc0", "c9b2e3", "f6c1a0"]


def badge(c, ring, bad=False):
    # strong silhouette: soft drop shadow, dark outer rim, coloured ring, glossy highlight
    c.ellipse(32, 34, 29, 29, fill=rgba("5b4636", 110))
    c.ellipse(32, 31, 29.5, 29.5, fill=rgba("4a3a30"))
    c.ellipse(32, 31, 27, 27, fill=rgba("e9e0ef") if bad else rgba("fbf3e3"))
    c.ellipse(32, 31, 27, 27, outline=rgba(ring), width=4)
    c.dashed_ellipse(32, 31, 21.5, 21.5, rgba(ring), 1.2, 22)
    c.arc(32, 31, 23, 23, 200, 290, (255, 255, 255, 190), 2.4)
    if bad:  # stitched "x" corners mark a curse
        for dx, dy in ((-19, -19), (19, -19)):
            c.line([(32 + dx - 3, 31 + dy - 3), (32 + dx + 3, 31 + dy + 3)], rgba("6f5a7c"), 1.6)
            c.line([(32 + dx + 3, 31 + dy - 3), (32 + dx - 3, 31 + dy + 3)], rgba("6f5a7c"), 1.6)


def mini_bomb(c, x, y, r, col="f2a7b5"):
    c.ellipse(x, y, r + 1.2, r + 1.2, fill=rgba("6e5f57"))
    c.ellipse(x, y, r, r, fill=rgba(col))
    c.dashed_ellipse(x, y, r * 0.45, r * 0.95, rgba("8a6e57"), 0.9, 10)
    c.ellipse(x - r * 0.35, y - r * 0.4, r * 0.25, r * 0.18, fill=(255, 255, 255, 140))
    c.line([(x + r * 0.4, y - r * 0.9), (x + r * 0.7, y - r * 1.4)], rgba("b48f6e"), 1.8)


def pu_bomb():
    c = Canvas(64, 64)
    badge(c, "8f7aa0")
    mini_bomb(c, 29, 35, 12)
    c.line([(46, 18), (46, 30)], rgba("6c9a63"), 3)
    c.line([(40, 24), (52, 24)], rgba("6c9a63"), 3)
    return c.result()


def pu_fire():
    c = Canvas(64, 64)
    badge(c, "d8908a")
    for i in range(10):
        a = i * math.pi / 5
        col = rgba(CONFETTI[i % len(CONFETTI)])
        x, y = 32 + math.cos(a) * 15, 31 + math.sin(a) * 15
        c.polygon([(x - 3, y - 2), (x + 3, y - 3), (x + 3, y + 2), (x - 3, y + 3)], fill=col)
    c.ellipse(32, 31, 7, 7, fill=rgba("f5dc8a"))
    return c.result()


def pu_speed():
    c = Canvas(64, 64)
    badge(c, "7fa8c2")
    for i in range(5):
        c.arc(32, 44 - i * 6, 10, 3.5, 0, 360, rgba("6d8fa6"), 2.4)
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


def pu_kick():
    c = Canvas(64, 64)
    badge(c, "c79a6b")
    # a stubby plush foot booting a little bomb
    c.rect(12, 30, 32, 44, fill=rgba("d9a66b"), radius=7)
    c.ellipse(28, 40, 8, 5, fill=rgba("f7ead8"))
    mini_bomb(c, 44, 30, 8, "a7c8e8")
    for i in range(3):
        c.line([(34 - i, 22 + i * 4), (38 - i, 22 + i * 4)], rgba("8a7563"), 1.4)
    return c.result()


def pu_line():
    c = Canvas(64, 64)
    badge(c, "a08bc0")
    for i, col in enumerate(("f2a7b5", "f5dc8a", "a8dcc0")):
        mini_bomb(c, 18 + i * 14, 33, 6, col)
    c.line([(14, 46), (50, 46)], rgba("6f5a7c"), 2.0)
    c.polygon([(50, 42), (56, 46), (50, 50)], fill=rgba("6f5a7c"))
    return c.result()


def pu_rubber():
    c = Canvas(64, 64)
    badge(c, "e0889a")
    c.ellipse(34, 34, 12, 12, fill=rgba("6e5f57"))
    c.ellipse(34, 34, 11, 11, fill=rgba("f6b0c0"))
    for dy in (-5, 0, 5):
        c.line([(24, 34 + dy), (44, 34 + dy)], rgba("fff4f6"), 2.2)
    c.arc(18, 30, 9, 12, 100, 260, rgba("c4778a"), 1.6)
    c.arc(14, 30, 12, 15, 110, 250, rgba("c4778a", 150), 1.4)
    return c.result()


def pu_immortal():
    c = Canvas(64, 64)
    badge(c, "d6b45e")
    c.ellipse(32, 18, 13, 4, outline=rgba("e6c25a"), width=2.5)
    c.ellipse(27, 32, 7, 7, fill=rgba("f2c4c8"))
    c.ellipse(37, 32, 7, 7, fill=rgba("f2c4c8"))
    c.polygon([(20.5, 34), (43.5, 34), (32, 47)], fill=rgba("f2c4c8"))
    c.ellipse(26, 30, 2.5, 1.6, fill=(255, 255, 255, 170))
    return c.result()


def pu_reverse():
    c = Canvas(64, 64)
    badge(c, "6f5a7c", bad=True)
    c.arc(32, 31, 13, 13, 200, 340, rgba("7b9a6a"), 3.0)
    c.polygon([(43, 22), (49, 30), (40, 30)], fill=rgba("7b9a6a"))
    c.arc(32, 31, 13, 13, 20, 160, rgba("b86f8a"), 3.0)
    c.polygon([(21, 40), (15, 32), (24, 32)], fill=rgba("b86f8a"))
    c.ellipse(32, 31, 3, 3, fill=rgba("6f5a7c"))
    return c.result()


def pu_diarrhea():
    c = Canvas(64, 64)
    badge(c, "6f5a7c", bad=True)
    mini_bomb(c, 26, 38, 7, "c9d9a0")
    mini_bomb(c, 40, 38, 7, "c9d9a0")
    mini_bomb(c, 33, 26, 7, "c9d9a0")
    for x in (20, 46):
        c.line([(x, 20), (x + 2, 16), (x, 12)], rgba("8aa06a"), 1.6)
    return c.result()


def make_powerups():
    cells = [pu_bomb(), pu_fire(), pu_speed(), pu_shuffle(), pu_kick(), pu_line(), pu_rubber(),
             pu_immortal(), pu_reverse(), pu_diarrhea()]
    sheet = Image.new("RGBA", (64 * len(cells), 64), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * 64, 0)
    return sheet


# ---------------------------------------------------------------- effects
# 8 cells of 64x64 (cell 7 = floor decal left where a bear got stunned): 0 confetti burst (blast centre), 1 confetti band (blast arm, horizontal),
# 2 confetti tip (blast end, pointing right), 3 star, 4 dust puff, 5 sparkle, 6 cartoon bird
def confetti_pieces(c, n, box, size=(3.5, 2.2), seed=0):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = box
    for i in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        col = rgba(CONFETTI[i % len(CONFETTI)])
        a = rnd.uniform(0, math.pi)
        w, h = size[0] * rnd.uniform(0.8, 1.3), size[1] * rnd.uniform(0.8, 1.3)
        if i % 4 == 3:
            c.ellipse(x, y, h * 1.1, h * 1.1, fill=col)
        else:
            ca, sa = math.cos(a), math.sin(a)
            pts = [(x + ca * dx - sa * dy, y + sa * dx + ca * dy) for dx, dy in ((-w, -h), (w, -h), (w, h), (-w, h))]
            c.polygon(pts, fill=col)


def fx_center():
    c = Canvas(64, 64)
    c.ellipse(32, 32, 26, 26, fill=rgba("fff4e4", 150))
    for i in range(12):
        a = i * math.pi / 6
        c.line([(32 + math.cos(a) * 8, 32 + math.sin(a) * 8), (32 + math.cos(a) * 24, 32 + math.sin(a) * 24)],
               rgba(CONFETTI[i % len(CONFETTI)], 200), 2.2)
    confetti_pieces(c, 26, (8, 8, 56, 56), seed=1)
    c.ellipse(32, 32, 6, 6, fill=rgba("fff6d8"))
    return c.result()


def fx_arm():
    c = Canvas(64, 64)
    c.rect(-4, 18, 68, 46, fill=rgba("fff4e4", 140), radius=12)
    confetti_pieces(c, 22, (0, 20, 64, 44), seed=2)
    return c.result()


def fx_end():
    c = Canvas(64, 64)
    c.rect(-4, 18, 40, 46, fill=rgba("fff4e4", 140), radius=12)
    c.ellipse(36, 32, 12, 14, fill=rgba("fff4e4", 140))
    confetti_pieces(c, 16, (0, 20, 46, 44), seed=3)
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


def fx_bird():
    """Old-cartoon tweety bird, facing right."""
    c = Canvas(64, 64)
    ink = rgba("5b4636")
    c.polygon([(14, 34), (4, 28), (6, 38)], fill=rgba("e8c35e"))      # tail
    c.ellipse(28, 36, 15, 12, fill=ink)
    c.ellipse(28, 36, 13.5, 10.5, fill=rgba("f6d77a"))                 # body
    c.ellipse(41, 26, 10, 10, fill=ink)
    c.ellipse(41, 26, 8.6, 8.6, fill=rgba("f6d77a"))                   # head
    c.polygon([(48, 25), (57, 28), (48, 31)], fill=rgba("e59a5f"))     # beak
    c.ellipse(43, 24, 2.2, 2.6, fill=ink)
    c.ellipse(43.6, 23.2, 0.8, 0.8, fill=(255, 255, 255, 230))
    c.polygon([(20, 32), (32, 30), (24, 20)], fill=rgba("e8c35e"))     # wing
    c.line([(26, 47), (25, 53)], rgba("e59a5f"), 1.6)
    c.line([(31, 47), (32, 53)], rgba("e59a5f"), 1.6)
    return c.result()


def make_effects():
    cells = [fx_center(), fx_arm(), fx_end(), fx_star(), fx_dust(), fx_sparkle(), fx_bird(), fx_stuffing_splat()]
    sheet = Image.new("RGBA", (64 * len(cells), 64), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * 64, 0)
    return sheet


# ---------------------------------------------------------------- duck
# 2 cells of 64x64: 0 wind-up pull-along duck (facing right, wheels included), 1 wind-up key.
# Mother and ducklings share cell 0 at different scales.
def duck_body():
    c = Canvas(64, 64)
    ink = rgba("6e5a45")
    # wooden base + wheels
    c.rect(12, 46, 52, 52, fill=rgba("b48f6e"), radius=2)
    for x in (18, 46):
        c.ellipse(x, 53, 6, 6, fill=ink)
        c.ellipse(x, 53, 4.6, 4.6, fill=rgba("e9b9c0"))
        c.ellipse(x, 53, 1.6, 1.6, fill=ink)
    # tail, body, stitched wing
    c.polygon([(9, 34), (2, 26), (5, 38)], fill=ink)
    c.polygon([(10, 34), (4, 28), (7, 37)], fill=rgba("f3dc93"))
    c.ellipse(28, 36, 19, 12, fill=ink)
    c.ellipse(28, 36, 17.6, 10.6, fill=rgba("f6e2a0"))
    c.ellipse(24, 33, 7, 3, fill=(255, 255, 255, 110))
    c.polygon([(16, 33), (34, 31), (26, 42)], fill=rgba("ead08a"))
    c.dashed_line(18, 34, 32, 32, rgba("a8895a"), 1.0, 2, 2)
    c.dashed_line(18, 34, 26, 41, rgba("a8895a"), 1.0, 2, 2)
    # neck + head
    c.ellipse(44, 22, 11, 11, fill=ink)
    c.ellipse(44, 22, 9.6, 9.6, fill=rgba("f6e2a0"))
    c.rect(36, 24, 48, 34, fill=rgba("f6e2a0"))
    c.dashed_line(36, 30, 47, 30, rgba("e9b9c0"), 1.6, 3, 2)  # ribbon collar
    # beak + button eye + blush
    c.polygon([(51, 21), (61, 24), (51, 27)], fill=rgba("e59a5f"))
    c.line([(51, 24), (59, 24)], rgba("b86f45"), 0.8)
    c.ellipse(46, 19, 2.6, 2.6, fill=rgba("2b2220"))
    c.ellipse(45.2, 18.2, 0.9, 0.9, fill=(255, 255, 255, 220))
    c.ellipse(45, 25, 3, 1.8, fill=rgba("f0a9ad", 150))
    return c.result()


def duck_key():
    c = Canvas(64, 64)
    ink = rgba("6e5a45")
    c.rect(29, 30, 35, 50, fill=rgba("c9a98a"))
    c.ellipse(22, 22, 9, 9, fill=ink)
    c.ellipse(42, 22, 9, 9, fill=ink)
    c.ellipse(22, 22, 7.5, 7.5, fill=rgba("d9c08a"))
    c.ellipse(42, 22, 7.5, 7.5, fill=rgba("d9c08a"))
    c.ellipse(22, 22, 2.5, 2.5, fill=ink)
    c.ellipse(42, 22, 2.5, 2.5, fill=ink)
    c.rect(28, 18, 36, 28, fill=rgba("d9c08a"))
    return c.result()


def make_duck():
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    paste(sheet, duck_body(), 0, 0)
    paste(sheet, duck_key(), 64, 0)
    return sheet


def fx_stuffing_splat():
    """Normal mode floor decal: a scatter of stuffing tufts."""
    c = Canvas(64, 64)
    rnd = random.Random(11)
    for i in range(9):
        x, y = 32 + rnd.uniform(-20, 20), 32 + rnd.uniform(-14, 14)
        r = rnd.uniform(3, 7)
        c.ellipse(x, y + 1, r, r * 0.85, fill=rgba("d9d2ca"))
        c.ellipse(x, y, r * 0.9, r * 0.75, fill=rgba("fffdf8"))
    return c.result()


# ---------------------------------------------------------------- horror mode
# Same layouts as the normal sheets, saved in <folder>/horror/template_*.png.
BLOOD = "8a0f18"
BLOOD_DARK = "4f070c"


def grim(img, bright=0.62, sat=0.45):
    """Dim and desaturate an existing image (keeps alpha)."""
    from PIL import ImageEnhance
    a = img.getchannel("A")
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(sat)
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def scar(c, pts, col=BLOOD_DARK):
    c.line(pts, rgba(col), 1.6)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        dx, dy = (y1 - y0) * 0.25, (x0 - x1) * 0.25
        c.line([(mx - dx, my - dy), (mx + dx, my + dy)], rgba("2a1a18"), 1.4)


def horror_part(index):
    base = make_bear().crop((index * BEAR_CELL, 0, (index + 1) * BEAR_CELL, BEAR_CELL))
    base = grim(base, 0.86, 0.5)
    c = Canvas(128, 128)
    if index == 0:  # body: torn seam with stuffing bulging out
        scar(c, [(40, 40), (52, 50), (46, 64), (58, 76)])
        c.ellipse(76, 86, 11, 8, fill=rgba("3a2422"))
        for (x, y, r) in ((72, 84, 5), (80, 86, 5), (76, 81, 4)):
            c.ellipse(x, y, r, r, fill=rgba("d9cfc4"))
        c.ellipse(70, 96, 7, 4, fill=rgba(BLOOD, 170))
    elif index == 1:  # belly: stain
        c.ellipse(70, 74, 14, 10, fill=rgba(BLOOD, 120))
        c.ellipse(58, 60, 6, 4, fill=rgba(BLOOD, 90))
    elif index == 2:  # head: stitched scar across the scalp
        scar(c, [(30, 40), (50, 30), (74, 34), (92, 26)])
    over = c.result()
    base.alpha_composite(over)
    return base


def horror_eye_button(c, x, y, r=8.5, glow=False):
    c.ellipse(x, y, r, r, fill=rgba("120c0c"))
    for dx, dy in ((-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)):
        c.ellipse(x + dx, y + dy, 1.2, 1.2, fill=rgba("3a2a2a"))
    if glow:
        c.ellipse(x, y, r * 0.38, r * 0.38, fill=rgba("e0262f"))
        c.ellipse(x, y, r * 0.16, r * 0.16, fill=rgba("ffd0c0"))


def horror_face_base(c):
    c.ellipse(64, 84, 22, 16, fill=rgba("b9a796"))
    c.dashed_ellipse(64, 84, 22, 16, rgba("5a463c"), 1.0, 26)
    c.ellipse(64, 76, 7, 5, fill=rgba("1c1212"))


def jagged_grin(c, y, w, open_mouth=False):
    pts = [(64 - w + i * (2 * w / 8), y + (3 if i % 2 else -2)) for i in range(9)]
    if open_mouth:
        c.polygon(pts + [(64 + w * 0.7, y + 9), (64 - w * 0.7, y + 9)], fill=rgba("1a0b0c"))
    c.line(pts, rgba("1a0b0c"), 1.8)
    for x, yy in pts[1:-1:2]:
        c.line([(x, yy - 3), (x, yy + 3)], rgba(BLOOD), 1.2)


def horror_face(kind):
    c = Canvas(128, 128)
    horror_face_base(c)
    if kind == "normal":  # mismatched: one button, one cross-stitch
        horror_eye_button(c, 42, 58)
        c.line([(79, 51), (93, 65)], rgba("1a0b0c"), 3)
        c.line([(93, 51), (79, 65)], rgba("1a0b0c"), 3)
        jagged_grin(c, 88, 12)
    elif kind == "smug":  # glowing eyes, wide stitched grin
        horror_eye_button(c, 42, 58, glow=True)
        horror_eye_button(c, 86, 58, glow=True)
        jagged_grin(c, 90, 20, open_mouth=True)
    elif kind == "indignant":  # hollow eyes, gaping mouth
        horror_eye_button(c, 42, 60, 10, glow=True)
        horror_eye_button(c, 86, 60, 7, glow=True)
        c.line([(30, 44), (54, 54)], rgba("1a0b0c"), 2.6)
        c.line([(98, 44), (74, 54)], rgba("1a0b0c"), 2.6)
        c.ellipse(64, 92, 7, 8, fill=rgba("1a0b0c"))
    else:  # stunned: X-eyes weeping red
        for x in (42, 86):
            c.line([(x - 7, 51), (x + 7, 65)], rgba("1a0b0c"), 3.2)
            c.line([(x + 7, 51), (x - 7, 65)], rgba("1a0b0c"), 3.2)
            c.line([(x, 66), (x + 1, 80)], rgba(BLOOD), 2.0)
            c.ellipse(x + 1, 81, 2, 2.5, fill=rgba(BLOOD))
        jagged_grin(c, 90, 10)
    return c.result()


def make_horror_bear():
    sheet = Image.new("RGBA", (BEAR_CELL * 10, BEAR_CELL), (0, 0, 0, 0))
    for i in range(6):
        paste(sheet, horror_part(i), i * BEAR_CELL, 0)
    for i, kind in enumerate(("normal", "smug", "indignant", "stunned")):
        paste(sheet, horror_face(kind), (6 + i) * BEAR_CELL, 0)
    return sheet


def make_horror_tiles():
    sheet = grim(make_tiles(), 0.55, 0.4)
    c = Canvas(sheet.width, sheet.height)
    rnd = random.Random(5)
    for cell in (0, 1, 2, 3, 4, 5):  # stains on the floors
        for _ in range(2):
            x, y = cell * 64 + rnd.uniform(10, 54), rnd.uniform(10, 54)
            c.ellipse(x, y, rnd.uniform(4, 9), rnd.uniform(3, 6), fill=rgba(BLOOD_DARK, 110))
    for x0 in (6 * 64, 8 * 64):  # claw scratches on wood
        for k in range(3):
            c.line([(x0 + 18 + k * 7, 10), (x0 + 30 + k * 7, 40)], rgba("1a0f0c", 150), 1.4)
    sheet.alpha_composite(c.result())
    return sheet


def blood_blobs(c, blobs, drops=8, seed=0):
    rnd = random.Random(seed)
    for (x, y, r) in blobs:
        c.ellipse(x, y + 1.5, r, r, fill=rgba(BLOOD_DARK))
        c.ellipse(x, y, r * 0.92, r * 0.92, fill=rgba(BLOOD))
        c.ellipse(x - r * 0.3, y - r * 0.35, r * 0.25, r * 0.15, fill=(255, 200, 200, 90))
    for _ in range(drops):
        x, y = rnd.uniform(4, 60), rnd.uniform(6, 58)
        c.ellipse(x, y, rnd.uniform(1.2, 2.6), rnd.uniform(1.2, 2.6), fill=rgba(BLOOD))


def hfx_center():
    c = Canvas(64, 64)
    blood_blobs(c, [(32, 32, 14)] + [(32 + math.cos(a) * 15, 32 + math.sin(a) * 15, 7)
                                       for a in [i * math.pi / 4 for i in range(8)]], 12, 1)
    return c.result()


def hfx_arm():
    c = Canvas(64, 64)
    blood_blobs(c, [(x, 32 + (3 if i % 2 else -3), 9) for i, x in enumerate(range(0, 72, 11))], 8, 2)
    return c.result()


def hfx_end():
    c = Canvas(64, 64)
    blood_blobs(c, [(0, 32, 9), (11, 30, 9), (22, 33, 8), (31, 31, 6), (38, 33, 4)], 6, 3)
    return c.result()


def hfx_skull():
    c = Canvas(64, 64)
    c.ellipse(32, 28, 18, 16, fill=rgba("e6dccb"))
    c.rect(22, 34, 42, 48, fill=rgba("e6dccb"), radius=4)
    c.ellipse(25, 28, 5, 6, fill=rgba("1a0f0f"))
    c.ellipse(39, 28, 5, 6, fill=rgba("1a0f0f"))
    c.polygon([(32, 33), (29, 39), (35, 39)], fill=rgba("1a0f0f"))
    for x in (26, 30, 34, 38):
        c.line([(x, 43), (x, 48)], rgba("1a0f0f"), 1.2)
    return c.result()


def hfx_crow():
    c = Canvas(64, 64)
    ink = rgba("15100f")
    c.polygon([(14, 34), (2, 26), (5, 40)], fill=ink)
    c.ellipse(28, 36, 15, 11, fill=ink)
    c.ellipse(41, 26, 9, 9, fill=ink)
    c.polygon([(48, 24), (60, 28), (48, 31)], fill=rgba("3a3330"))
    c.ellipse(43, 24, 2.2, 2.2, fill=rgba("e0262f"))
    c.polygon([(18, 30), (34, 28), (22, 16)], fill=rgba("2a2220"))
    c.line([(26, 46), (25, 53)], rgba("3a3330"), 1.6)
    c.line([(31, 46), (32, 53)], rgba("3a3330"), 1.6)
    return c.result()


def hfx_splat():
    c = Canvas(64, 64)
    rnd = random.Random(9)
    blobs = [(32, 32, 12)] + [(32 + rnd.uniform(-20, 20), 32 + rnd.uniform(-16, 16), rnd.uniform(3, 7)) for _ in range(9)]
    for (x, y, r) in blobs:
        c.ellipse(x, y, r, r * 0.8, fill=rgba(BLOOD))
    for _ in range(14):
        c.ellipse(rnd.uniform(4, 60), rnd.uniform(6, 58), rnd.uniform(0.8, 2), rnd.uniform(0.8, 2), fill=rgba(BLOOD))
    return c.result()


def make_horror_effects():
    normal = make_effects()
    cell = lambda i: normal.crop((i * 64, 0, (i + 1) * 64, 64))
    cells = [hfx_center(), hfx_arm(), hfx_end(), hfx_skull(), grim(cell(4), 0.45, 0.3), grim(cell(5), 0.9, 0.2),
             hfx_crow(), hfx_splat()]
    sheet = Image.new("RGBA", (64 * len(cells), 64), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * 64, 0)
    return sheet


# ---------------------------------------------------------------- roster
# Teddy bunny, small dino and teddy bear princess share the bear sheet layout
# (cells 0-9) plus two accessory cells: 10 = tail / skirt, 11 = head topper.
PINK = "f3b6c8"
GOLD = "e8c35e"


def species_sheet(cells):
    sheet = Image.new("RGBA", (BEAR_CELL * len(cells), BEAR_CELL), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        paste(sheet, im, i * BEAR_CELL, 0)
    return sheet


def bear_cells():
    b = make_bear()
    return [b.crop((i * BEAR_CELL, 0, (i + 1) * BEAR_CELL, BEAR_CELL)) for i in range(10)]


def eyes_for(c, kind):
    if kind == "normal":
        button_eye(c, 42, 58)
        button_eye(c, 86, 58)
    elif kind == "smug":
        for x in (42, 86):
            c.d.pieslice(c._b((x - 8.5, 51.5, x + 8.5, 68.5)), 0, 180, fill=EYE)
            c.line([(x - 10, 59), (x + 10, 59)], MOUTH, 2.0)
    elif kind == "indignant":
        button_eye(c, 42, 60)
        button_eye(c, 86, 60)
        c.line([(30, 44), (54, 51)], MOUTH, 2.6)
        c.line([(98, 44), (74, 51)], MOUTH, 2.6)
    else:
        for x in (42, 86):
            c.line([(x - 7, 51), (x + 7, 65)], EYE, 3.2)
            c.line([(x + 7, 51), (x - 7, 65)], EYE, 3.2)


# ---- teddy bunny ----
def bunny_belly():
    c = Canvas(128, 128)
    plush_blob(c, 64, 64, 40, 44, rgba("fffaf2"), fuzz=False)
    c.dashed_ellipse(64, 64, 36, 40, rgba("b9aa98"), 1.6, 30)
    c.polygon([(57, 70), (71, 70), (64, 92)], fill=rgba("efa35f"))      # carrot patch
    c.dashed_line(59, 76, 69, 76, rgba("c47a3c"), 1.0, 2, 2)
    for dx in (-4, 0, 4):
        c.line([(64, 70), (64 + dx * 1.5, 62)], rgba("8fbf7a"), 2.4)
    return c.result()


def bunny_head():
    c = Canvas(128, 128)
    plush_blob(c, 64, 68, 47, 45, FUR)
    return c.result()


def bunny_ear():
    """Tall floppy ear, base near y=100 (the rig hangs it from its base)."""
    c = Canvas(128, 128)
    c.rect(46, 6, 82, 104, fill=FUR_DARK, radius=17)
    c.rect(47, 6, 81, 102, fill=FUR, radius=17)
    c.rect(55, 16, 73, 94, fill=rgba("fbe0e4"), radius=9)
    c.dashed_line(64, 20, 64, 90, STITCH, 1.0, 3, 3)
    c.ellipse(56, 18, 6, 4, fill=(255, 255, 255, 60))
    return c.result()


def bunny_face(kind):
    c = Canvas(128, 128)
    c.ellipse(55, 85, 12, 10, fill=MUZZLE)
    c.ellipse(73, 85, 12, 10, fill=MUZZLE)
    c.dashed_ellipse(64, 85, 22, 12, rgba("c8b49c"), 1.0, 24)
    c.polygon([(58, 74), (70, 74), (64, 81)], fill=rgba("e08a9a"))      # pink nose
    if kind != "stunned":
        c.rect(59, 88, 64, 97, fill=rgba("fffdf8"), radius=1)            # buck teeth
        c.rect(64, 88, 69, 97, fill=rgba("fffdf8"), radius=1)
        c.rect(59, 88, 69, 97, outline=MOUTH, width=0.9, radius=1)
    for sgn in (-1, 1):                                                  # whisker stitches
        for k in (-1, 0, 1):
            c.dashed_line(64 + sgn * 22, 84 + k * 4, 64 + sgn * 38, 82 + k * 6, MOUTH, 1.0, 3, 2)
    c.ellipse(30, 78, 8, 5, fill=BLUSH)
    c.ellipse(98, 78, 8, 5, fill=BLUSH)
    eyes_for(c, kind)
    if kind == "smug":
        c.arc(72, 80, 9, 6, 20, 120, MOUTH, 1.8)
    elif kind == "indignant":
        c.ellipse(64, 101, 4, 4, fill=MOUTH)
    elif kind == "stunned":
        c.line([(52 + i * 2, 92 + math.sin(i * 1.4) * 2.2) for i in range(13)], MOUTH, 1.8)
    return c.result()


def bunny_tail():
    c = Canvas(128, 128)
    for (x, y, r) in ((64, 64, 16), (54, 58, 10), (74, 58, 10), (56, 72, 10), (72, 72, 10)):
        c.ellipse(x, y + 1.5, r, r, fill=rgba("d9d2ca"))
    for (x, y, r) in ((64, 63, 14), (55, 57, 8), (73, 57, 8), (57, 71, 8), (71, 71, 8)):
        c.ellipse(x, y, r, r, fill=rgba("fffdf8"))
    return c.result()


def bunny_bow():
    c = Canvas(128, 128)
    c.polygon([(64, 64), (36, 46), (36, 82)], fill=rgba("c76e86"))
    c.polygon([(64, 64), (92, 46), (92, 82)], fill=rgba("c76e86"))
    c.polygon([(64, 64), (39, 50), (39, 78)], fill=rgba(PINK))
    c.polygon([(64, 64), (89, 50), (89, 78)], fill=rgba(PINK))
    c.ellipse(64, 64, 8, 8, fill=rgba("c76e86"))
    c.ellipse(64, 64, 6, 6, fill=rgba("f6c9d6"))
    for x in (46, 82):
        c.ellipse(x, 64, 2, 2, fill=(255, 255, 255, 200))
    return c.result()


def make_bunny():
    b = bear_cells()
    return species_sheet([b[0], bunny_belly(), bunny_head(), bunny_ear(), b[4], b[5]]
                         + [bunny_face(k) for k in ("normal", "smug", "indignant", "stunned")]
                         + [bunny_tail(), bunny_bow()])


# ---- small dino ----
def dino_body():
    c = Canvas(128, 128)
    plush_blob(c, 64, 66, 46, 50, FUR)
    rnd = random.Random(21)
    for _ in range(9):
        x, y = rnd.uniform(26, 102), rnd.uniform(28, 106)
        if (x - 64) ** 2 / 46 ** 2 + (y - 66) ** 2 / 50 ** 2 < 0.75:
            r = rnd.uniform(4, 8)
            c.ellipse(x, y, r, r * 0.8, fill=rgba("c9bfb4", 170))
    c.dashed_line(64, 22, 64, 110, STITCH, 1.4, 4, 3)
    return c.result()


def dino_belly():
    c = Canvas(128, 128)
    plush_blob(c, 64, 64, 38, 44, rgba("fffaf2"), fuzz=False)
    for k in range(5):
        y = 34 + k * 13
        c.dashed_line(36, y, 92, y, rgba("b9aa98"), 1.4, 3, 2)
    c.dashed_ellipse(64, 64, 34, 40, rgba("b9aa98"), 1.6, 30)
    return c.result()


def dino_head():
    c = Canvas(128, 128)
    plush_blob(c, 64, 70, 53, 44, FUR)
    for (x, y) in ((44, 44), (80, 40), (90, 60)):
        c.ellipse(x, y, 5, 4, fill=rgba("c9bfb4", 160))
    return c.result()


def dino_ear():
    """A soft horn nub where a bear has ears."""
    c = Canvas(128, 128)
    c.polygon([(48, 82), (64, 34), (80, 82)], fill=FUR_DARK)
    c.polygon([(51, 80), (64, 40), (77, 80)], fill=FUR)
    c.ellipse(64, 42, 6, 6, fill=FUR)
    c.dashed_line(56, 76, 64, 46, STITCH, 1.0, 3, 2)
    return c.result()


def dino_face(kind):
    c = Canvas(128, 128)
    c.ellipse(64, 88, 32, 17, fill=MUZZLE)
    c.dashed_ellipse(64, 88, 32, 17, rgba("c8b49c"), 1.0, 30)
    for x in (54, 74):
        c.ellipse(x, 80, 2.6, 2, fill=NOSE)
    eyes_for(c, kind)
    if kind == "normal":
        c.arc(64, 88, 20, 8, 15, 165, MOUTH, 1.8)
    elif kind == "smug":
        c.arc(64, 88, 22, 9, 10, 170, MOUTH, 1.8)
        for x in (50, 78):
            c.polygon([(x - 3, 94), (x + 3, 94), (x, 99)], fill=rgba("fffdf8"))
    elif kind == "indignant":
        c.ellipse(64, 96, 8, 5, fill=MOUTH)
    else:
        c.line([(46 + i * 3, 94 + math.sin(i * 1.4) * 2.2) for i in range(13)], MOUTH, 1.8)
    c.ellipse(30, 80, 7, 4, fill=BLUSH)
    c.ellipse(98, 80, 7, 4, fill=BLUSH)
    return c.result()


def dino_tail():
    """Tapered tail pointing right; its base sits at x=14 (the rig pivots there)."""
    c = Canvas(128, 128)
    pts_top = [(14, 50), (50, 52), (86, 58), (112, 66), (122, 70)]
    pts_bot = [(122, 72), (110, 78), (84, 80), (50, 84), (14, 86)]
    c.polygon(pts_top + pts_bot, fill=FUR_DARK)
    c.polygon([(x, y + 2) for x, y in pts_top] + [(x, y - 2) for x, y in pts_bot], fill=FUR)
    for k, x in enumerate((30, 52, 74, 96)):                              # soft back spikes
        h = 12 - k * 2
        c.polygon([(x - 7, 52 + k * 3), (x, 52 + k * 3 - h), (x + 7, 54 + k * 3)], fill=FUR_DARK)
    c.dashed_line(20, 70, 110, 73, STITCH, 1.0, 3, 3)
    return c.result()


def dino_crest():
    c = Canvas(128, 128)
    for x, h in ((44, 22), (64, 30), (84, 22)):
        c.polygon([(x - 11, 80), (x, 80 - h - 20), (x + 11, 80)], fill=FUR_DARK)
        c.polygon([(x - 8, 80), (x, 80 - h - 15), (x + 8, 80)], fill=FUR)
    return c.result()


def make_dino():
    b = bear_cells()
    return species_sheet([dino_body(), dino_belly(), dino_head(), dino_ear(), b[4], b[5]]
                         + [dino_face(k) for k in ("normal", "smug", "indignant", "stunned")]
                         + [dino_tail(), dino_crest()])


# ---- teddy bear princess ----
def princess_face(kind):
    c = Canvas(128, 128)
    face_base(c)
    c.ellipse(32, 82, 10, 6, fill=rgba("f0a9ad", 190))
    c.ellipse(96, 82, 10, 6, fill=rgba("f0a9ad", 190))
    eyes_for(c, kind)
    if kind != "stunned":
        for x, sgn in ((42, -1), (86, 1)):                                # eyelashes
            for k in range(3):
                c.line([(x + sgn * 6, 51 + k * 2), (x + sgn * 12, 46 + k * 3)], EYE, 1.5)
    if kind == "normal":
        c.ellipse(64, 89, 4.5, 3, fill=rgba("d86a82"))                    # little pink smile
        c.arc(64, 87, 7, 4, 20, 160, MOUTH, 1.4)
    elif kind == "smug":
        c.arc(68, 86, 10, 6, 15, 120, MOUTH, 1.8)
        c.ellipse(71, 89, 3, 2, fill=rgba("d86a82"))
    elif kind == "indignant":
        c.ellipse(64, 91, 5, 5, fill=MOUTH)
    else:
        c.line([(52 + i * 2, 89 + math.sin(i * 1.4) * 2.2) for i in range(13)], MOUTH, 1.8)
    return c.result()


def princess_skirt():
    """A frilly tutu worn round the waist, drawn in front of the body."""
    c = Canvas(128, 128)
    c.ellipse(64, 66, 58, 22, fill=rgba("d98aa2"))
    for k in range(13):                                                   # scalloped hem
        a = math.pi * k / 12
        x = 64 + math.cos(a) * 52
        c.ellipse(x, 74 + math.sin(a) * 10, 9, 7, fill=rgba(PINK))
    c.ellipse(64, 62, 54, 17, fill=rgba(PINK))
    c.ellipse(64, 56, 46, 9, fill=rgba("f9d3de"))
    rnd = random.Random(4)
    for _ in range(10):
        c.ellipse(rnd.uniform(20, 108), rnd.uniform(58, 76), 1.6, 1.6, fill=(255, 255, 255, 230))
    c.dashed_ellipse(64, 58, 47, 10, rgba("c76e86"), 1.1, 30)
    return c.result()


def princess_crown():
    c = Canvas(128, 128)
    outline = rgba("9c7a2c")
    pts = [(36, 84), (36, 50), (50, 66), (64, 40), (78, 66), (92, 50), (92, 84)]
    c.polygon([(x, y + 2) for x, y in pts], fill=outline)
    c.polygon(pts, fill=rgba(GOLD))
    c.rect(36, 76, 92, 86, fill=rgba("d9ab3f"))
    for x, col in ((50, "e86f8e"), (64, "7fb3d9"), (78, "e86f8e")):
        c.ellipse(x, 80, 3.6, 3.6, fill=rgba(col))
    for x, y in ((36, 50), (64, 40), (92, 50)):
        c.ellipse(x, y, 3.6, 3.6, fill=rgba("fff2c4"))
    c.line([(42, 74), (86, 74)], (255, 255, 255, 120), 1.4)
    return c.result()


def make_princess():
    b = bear_cells()
    return species_sheet(b[0:6] + [princess_face(k) for k in ("normal", "smug", "indignant", "stunned")]
                         + [princess_skirt(), princess_crown()])


# ---- horror versions of the roster ----
def horror_scars(img, index, seed):
    img = grim(img, 0.86, 0.5)
    c = Canvas(128, 128)
    rnd = random.Random(seed)
    if index in (0, 2):
        x0, y0 = rnd.uniform(34, 50), rnd.uniform(30, 44)
        scar(c, [(x0, y0), (x0 + 14, y0 + 10), (x0 + 8, y0 + 24), (x0 + 20, y0 + 34)])
        c.ellipse(rnd.uniform(60, 84), rnd.uniform(70, 96), 7, 4, fill=rgba(BLOOD, 160))
    elif index == 1:
        c.ellipse(70, 74, 14, 10, fill=rgba(BLOOD, 120))
    img.alpha_composite(c.result())
    return img


def horror_species_face(species, kind):
    face = horror_face(kind)
    c = Canvas(128, 128)
    if species == "bunny":
        c.rect(58, 96, 63, 104, fill=rgba("d9cfc4"))                     # one buck tooth left
        c.line([(64, 96), (69, 103)], rgba("1a0b0c"), 1.2)
        for sgn in (-1, 1):
            c.line([(64 + sgn * 22, 84), (64 + sgn * 38, 80)], rgba("1a0b0c"), 1.0)
    elif species == "dino":
        for x in (54, 74):
            c.ellipse(x, 79, 2.6, 2, fill=rgba("1a0b0c"))
        for x in (44, 52, 76, 84):
            c.polygon([(x - 3, 92), (x + 3, 92), (x, 99)], fill=rgba("d9cfc4"))
    elif species == "princess":
        for x in (42, 86):                                               # running mascara
            c.line([(x - 4, 66), (x - 5, 84)], rgba("1a0b0c", 200), 1.6)
            c.line([(x + 3, 66), (x + 4, 78)], rgba("1a0b0c", 160), 1.2)
    face.alpha_composite(c.result())
    return face


def horror_accessory(img, kind):
    img = grim(img, 0.8, 0.5)
    c = Canvas(128, 128)
    if kind == "crown":
        c.line([(56, 44), (60, 60), (55, 74)], rgba("3a2a12"), 1.6)        # crack
        c.line([(78, 66), (80, 84), (79, 96)], rgba(BLOOD), 2.2)           # drip
        c.ellipse(79, 97, 2, 2.6, fill=rgba(BLOOD))
    elif kind == "skirt":
        for (x, y, r) in ((40, 66, 9), (82, 72, 7), (64, 60, 5)):
            c.ellipse(x, y, r, r * 0.7, fill=rgba(BLOOD, 170))
    elif kind == "bow":
        c.ellipse(52, 70, 6, 4, fill=rgba(BLOOD, 170))
    elif kind == "tail":
        c.ellipse(70, 68, 6, 4, fill=rgba(BLOOD, 160))
        scar(c, [(30, 64), (48, 70), (66, 66)])
    else:
        c.ellipse(64, 70, 6, 4, fill=rgba(BLOOD, 150))
    img.alpha_composite(c.result())
    return img


def tear_ear(img):
    """Bite a notch out of a bunny ear."""
    big = img.resize((512, 512), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    d.polygon([(200, 70), (260, 110), (196, 150)], fill=(0, 0, 0, 0))
    return big.resize((128, 128), Image.LANCZOS)


def make_horror_species(species):
    sheet = {"bunny": make_bunny, "dino": make_dino, "princess": make_princess}[species]()
    cells = [sheet.crop((i * BEAR_CELL, 0, (i + 1) * BEAR_CELL, BEAR_CELL)) for i in range(12)]
    out = [horror_scars(cells[i], i, i * 7 + len(species)) for i in range(6)]
    if species == "bunny":
        out[3] = tear_ear(out[3])
    out += [horror_species_face(species, k) for k in ("normal", "smug", "indignant", "stunned")]
    acc = {"bunny": ("tail_puff", "bow"), "dino": ("tail", "crest"), "princess": ("skirt", "crown")}[species]
    out += [horror_accessory(cells[10], acc[0]), horror_accessory(cells[11], acc[1])]
    return species_sheet(out)


# ---------------------------------------------------------------- crane chair
def make_chair():
    """An overstuffed armchair, bursting with fluff (96x96)."""
    c = Canvas(96, 96)
    wood, fab, fab_d, st = rgba("8c6a50"), rgba("d99aa6"), rgba("b9787f"), rgba("8e5a60")
    for x in (20, 76):
        c.rect(x - 4, 74, x + 4, 92, fill=wood, radius=2)
    c.rect(18, 8, 78, 60, fill=fab_d, radius=16)                         # back
    c.rect(20, 10, 76, 58, fill=fab, radius=15)
    for x in (34, 48, 62):                                                # tufted buttons
        c.ellipse(x, 30, 2.4, 2.4, fill=st)
    c.dashed_line(26, 44, 70, 44, st, 1.1, 3, 3)
    c.rect(10, 40, 30, 80, fill=fab_d, radius=10)                        # arms
    c.rect(66, 40, 86, 80, fill=fab_d, radius=10)
    c.rect(11, 38, 29, 76, fill=fab, radius=9)
    c.rect(67, 38, 85, 76, fill=fab, radius=9)
    c.rect(24, 56, 72, 80, fill=fab_d, radius=10)                        # seat cushion
    c.rect(25, 54, 71, 76, fill=rgba("e7b3bc"), radius=9)
    c.dashed_line(28, 66, 68, 66, st, 1.1, 3, 3)
    # stuffing bursting out of the seams
    for (x, y, r) in ((28, 12, 7), (36, 8, 6), (70, 52, 7), (78, 46, 5), (20, 58, 6), (52, 54, 5)):
        c.ellipse(x, y + 1, r, r, fill=rgba("d9d2ca"))
        c.ellipse(x, y, r * 0.86, r * 0.86, fill=rgba("fffdf8"))
    c.rect(40, 16, 54, 26, fill=rgba("e9d7a6"), radius=2)                 # patch
    c.rect(40, 16, 54, 26, outline=st, width=1.0, radius=2)
    return c.result()


def make_horror_chair():
    img = grim(make_chair(), 0.7, 0.45)
    c = Canvas(96, 96)
    scar(c, [(24, 20), (36, 30), (30, 44)])
    for (x, y, r) in ((60, 64, 8), (30, 70, 5), (70, 30, 4)):
        c.ellipse(x, y, r, r * 0.7, fill=rgba(BLOOD, 190))
    for (x, y, r) in ((70, 52, 6), (28, 12, 5)):                        # stained stuffing
        c.ellipse(x, y, r, r, fill=rgba("c48a8a"))
    c.line([(62, 72), (63, 86)], rgba(BLOOD), 2.0)
    img.alpha_composite(c.result())
    return img


# ---------------------------------------------------------------- horror power-ups
HB = "2a1f21"


def hbadge(c, bad=False):
    c.ellipse(32, 34, 29, 29, fill=(0, 0, 0, 140))
    c.ellipse(32, 31, 29.5, 29.5, fill=rgba("120b0c"))
    c.ellipse(32, 31, 27, 27, fill=rgba("3b2a2d") if bad else rgba(HB))
    c.ellipse(32, 31, 27, 27, outline=rgba("5c4a3a" if bad else "8a0f18"), width=4)
    c.dashed_ellipse(32, 31, 21.5, 21.5, rgba("d9cfc4", 200), 1.3, 18)   # bone-white stitches
    c.ellipse(46, 54, 3, 4, fill=rgba(BLOOD))                           # a drip off the rim
    c.line([(46, 50), (46, 56)], rgba(BLOOD), 2.0)
    if bad:
        for dx, dy in ((-19, -19), (19, -19)):
            c.line([(32 + dx - 3, 31 + dy - 3), (32 + dx + 3, 31 + dy + 3)], rgba("9fae78"), 1.8)
            c.line([(32 + dx + 3, 31 + dy - 3), (32 + dx - 3, 31 + dy + 3)], rgba("9fae78"), 1.8)


def hmini_bomb(c, x, y, r, eye=True):
    c.ellipse(x, y, r + 1.2, r + 1.2, fill=rgba("0d0909"))
    c.ellipse(x, y, r, r, fill=rgba("5a4a48"))
    c.dashed_ellipse(x, y, r * 0.45, r * 0.95, rgba("2a1c1c"), 0.9, 10)
    if eye:
        c.ellipse(x, y, r * 0.38, r * 0.38, fill=rgba("e6dccb"))
        c.ellipse(x, y, r * 0.18, r * 0.18, fill=rgba("c41e2a"))
    c.line([(x + r * 0.4, y - r * 0.9), (x + r * 0.7, y - r * 1.4)], rgba("6e5f57"), 1.8)


def hpu_bomb():
    c = Canvas(64, 64); hbadge(c); hmini_bomb(c, 29, 35, 12)
    c.line([(46, 18), (46, 30)], rgba("d9cfc4"), 3); c.line([(40, 24), (52, 24)], rgba("d9cfc4"), 3)
    return c.result()


def hpu_fire():
    c = Canvas(64, 64); hbadge(c)
    blood_blobs(c, [(32, 31, 7)] + [(32 + math.cos(a) * 13, 31 + math.sin(a) * 13, 4) for a in [i * math.pi / 4 for i in range(8)]], 6, 31)
    return c.result()


def hpu_speed():
    c = Canvas(64, 64); hbadge(c)
    for i in range(5):                                                   # a coiled spine
        y = 44 - i * 6
        c.ellipse(32 + (2 if i % 2 else -2), y, 8, 3.2, fill=rgba("e6dccb"))
        c.ellipse(32 + (2 if i % 2 else -2), y, 3, 1.4, fill=rgba("6e5f57"))
    c.ellipse(32, 15, 5, 3, fill=rgba(BLOOD))
    return c.result()


def hpu_shuffle():
    c = Canvas(64, 64); hbadge(c)
    for (x0, y0, col) in ((18, 17, "5d6f78"), (32, 17, BLOOD), (18, 31, "6e5f57"), (32, 31, "3e3033")):
        c.rect(x0, y0, x0 + 14, y0 + 14, fill=rgba(col), radius=3)
    c.ellipse(32, 31, 7, 5, fill=rgba("e6dccb"))                         # an eye where they meet
    c.ellipse(32, 31, 3, 3, fill=rgba("c41e2a"))
    return c.result()


def hpu_kick():
    c = Canvas(64, 64); hbadge(c)
    c.rect(12, 30, 32, 44, fill=rgba("7a6a5a"), radius=7)               # severed plush foot
    c.ellipse(28, 40, 8, 5, fill=rgba("b9a796"))
    c.line([(12, 30), (12, 44)], rgba(BLOOD), 3)
    scar(c, [(14, 32), (20, 37), (14, 42)])
    hmini_bomb(c, 45, 30, 8, eye=False)
    return c.result()


def hpu_line():
    c = Canvas(64, 64); hbadge(c)
    for i in range(3):
        hmini_bomb(c, 18 + i * 14, 32, 6, eye=(i == 1))
        c.line([(18 + i * 14, 38), (18 + i * 14, 44 + i % 2 * 3)], rgba(BLOOD), 1.6)
    return c.result()


def hpu_rubber():
    c = Canvas(64, 64); hbadge(c)
    c.ellipse(33, 33, 12, 12, fill=rgba("0d0909"))
    c.ellipse(33, 33, 11, 11, fill=rgba("efe6d6"))                      # a bouncing eyeball
    for a in (0.3, 1.4, 2.6, 3.9, 5.1):
        c.line([(33 + math.cos(a) * 11, 33 + math.sin(a) * 11), (33 + math.cos(a + 0.2) * 6, 33 + math.sin(a + 0.2) * 6)], rgba("c41e2a", 200), 1.0)
    c.ellipse(37, 31, 5, 5, fill=rgba("6c8f5e")); c.ellipse(37, 31, 2.3, 2.3, fill=rgba("0d0909"))
    c.arc(17, 30, 9, 12, 100, 260, rgba("8a0f18"), 1.6)
    return c.result()


def hpu_immortal():
    c = Canvas(64, 64); hbadge(c)
    c.ellipse(32, 17, 13, 4, outline=rgba("6e5f57"), width=2.5)          # a tarnished, broken halo
    c.line([(40, 14), (44, 20)], rgba(HB), 3)
    c.ellipse(27, 32, 7, 7, fill=rgba("6e0f18")); c.ellipse(37, 32, 7, 7, fill=rgba("6e0f18"))
    c.polygon([(20.5, 34), (43.5, 34), (32, 47)], fill=rgba("6e0f18"))
    for (x0, y0, x1, y1) in ((24, 28, 40, 40), (40, 28, 24, 40)):         # stitched shut
        c.line([(x0, y0), (x1, y1)], rgba("d9cfc4"), 1.4)
    return c.result()


def hpu_reverse():
    c = Canvas(64, 64); hbadge(c, bad=True)
    c.arc(32, 31, 15, 15, 200, 340, rgba("9fae78"), 3.0)
    c.polygon([(45, 22), (51, 30), (42, 30)], fill=rgba("9fae78"))
    c.arc(32, 31, 15, 15, 20, 160, rgba("c41e2a"), 3.0)
    c.polygon([(19, 40), (13, 32), (22, 32)], fill=rgba("c41e2a"))
    c.ellipse(32, 29, 8, 7, fill=rgba("e6dccb"))                          # tiny skull
    c.rect(28, 33, 36, 38, fill=rgba("e6dccb"))
    c.ellipse(29, 29, 2, 2.4, fill=rgba("0d0909")); c.ellipse(35, 29, 2, 2.4, fill=rgba("0d0909"))
    return c.result()


def hpu_diarrhea():
    c = Canvas(64, 64); hbadge(c, bad=True)
    for (x, y) in ((25, 38), (39, 38), (32, 26)):
        hmini_bomb(c, x, y, 7, eye=False)
        c.ellipse(x - 2, y + 7, 3, 2, fill=rgba("5a6b2a"))
    for (x, y) in ((18, 18), (46, 16), (48, 26)):                         # flies
        c.ellipse(x, y, 1.6, 1.2, fill=rgba("0d0909"))
        c.ellipse(x - 1.5, y - 1.5, 1.4, 0.8, fill=rgba("d9cfc4", 160))
    return c.result()


def make_horror_powerups():
    cells = [hpu_bomb(), hpu_fire(), hpu_speed(), hpu_shuffle(), hpu_kick(), hpu_line(), hpu_rubber(),
             hpu_immortal(), hpu_reverse(), hpu_diarrhea()]
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
    save(make_duck(), "objects", "template_duck.png")
    save(make_powerups(), "powerups", "template_powerups.png")
    save(make_effects(), "effects", "template_effects.png")
    save(make_horror_bear(), "bears", "horror", "template_bear.png")
    save(make_horror_tiles(), "tiles", "horror", "template_tiles.png")
    save(make_horror_effects(), "effects", "horror", "template_effects.png")
    save(make_bunny(), "bears", "template_bunny.png")
    save(make_dino(), "bears", "template_dino.png")
    save(make_princess(), "bears", "template_princess.png")
    for sp in ("bunny", "dino", "princess"):
        save(make_horror_species(sp), "bears", "horror", "template_%s.png" % sp)
    save(make_chair(), "objects", "template_chair.png")
    save(make_horror_chair(), "objects", "horror", "template_chair.png")
    save(make_horror_powerups(), "powerups", "horror", "template_powerups.png")
    make_icon().save(os.path.join(ROOT, "..", "..", "icon.png"))
