"""
Generates all the pixel-art PNG assets used by the Love2D examples.

Everything is drawn at small "native" pixel resolutions; Love2D scales them up
with nearest-neighbour filtering so they stay crisp. Run with:

    .venv/bin/python tools/gen_assets.py

Outputs into ../assets/ relative to this file.
"""
import os
import math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)


def save(img, name):
    path = os.path.join(ASSETS, name)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT), img.size)


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
SKIN = (235, 188, 150, 255)
SHIRT = (70, 130, 220, 255)
SHIRT_D = (45, 95, 175, 255)
PANTS = (60, 60, 90, 255)
PANTS_D = (40, 40, 65, 255)
HAIR = (90, 55, 40, 255)
EYE = (30, 30, 40, 255)
SHOE = (35, 35, 40, 255)
OUTLINE = (25, 22, 35, 255)


# ---------------------------------------------------------------------------
# Player spritesheet
# 16x24 frames: [idle0, idle1, run0, run1, run2, run3, jump, fall]  -> 8 frames
# ---------------------------------------------------------------------------
FW, FH = 16, 24
FRAMES = 8


def draw_player_frame(d, ox, leg_phase, arm_phase, squash=0, eyes_closed=False):
    """Draw a single 16x24 character into draw `d` at x-offset ox.
    leg_phase / arm_phase shift limbs for the run cycle. squash bobs the body."""
    cx = ox + 8
    top = 2 + squash

    # head (5 wide)
    d.rectangle([cx - 3, top, cx + 2, top + 5], fill=SKIN, outline=OUTLINE)
    # hair
    d.rectangle([cx - 3, top, cx + 2, top + 1], fill=HAIR)
    d.rectangle([cx - 3, top, cx - 3, top + 2], fill=HAIR)
    # eyes
    if eyes_closed:
        d.line([cx, top + 3, cx + 1, top + 3], fill=EYE)
    else:
        d.point((cx + 1, top + 3), fill=EYE)

    # body / shirt
    by0 = top + 6
    by1 = by0 + 7
    d.rectangle([cx - 3, by0, cx + 2, by1], fill=SHIRT, outline=OUTLINE)
    d.rectangle([cx - 3, by1 - 2, cx + 2, by1], fill=SHIRT_D)

    # arms swing opposite to legs
    ay = by0 + 1
    # back arm
    d.rectangle([cx - 4, ay - arm_phase, cx - 4, ay + 3 - arm_phase],
                fill=SHIRT_D, outline=OUTLINE)
    # front arm
    d.rectangle([cx + 3, ay + arm_phase, cx + 3, ay + 3 + arm_phase],
                fill=SHIRT, outline=OUTLINE)

    # legs / pants
    ly = by1 + 1
    # left leg
    d.rectangle([cx - 3, ly, cx - 1, ly + 4 - abs(leg_phase)],
                fill=PANTS, outline=OUTLINE)
    # right leg
    d.rectangle([cx, ly, cx + 2, ly + 4 - abs(leg_phase)],
                fill=PANTS_D, outline=OUTLINE)
    # shoes
    lfoot = ly + 4 - abs(leg_phase)
    d.rectangle([cx - 4 + max(0, leg_phase), lfoot, cx - 1 + max(0, leg_phase), lfoot + 1], fill=SHOE)
    d.rectangle([cx + max(0, -leg_phase), lfoot, cx + 3 + max(0, -leg_phase), lfoot + 1], fill=SHOE)


def build_player():
    sheet = Image.new("RGBA", (FW * FRAMES, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    # idle 0/1 (subtle breathing)
    draw_player_frame(d, 0 * FW, 0, 0, squash=0)
    draw_player_frame(d, 1 * FW, 0, 0, squash=1)
    # run cycle 0..3
    draw_player_frame(d, 2 * FW, 2, 2, squash=0)
    draw_player_frame(d, 3 * FW, 0, 0, squash=1)
    draw_player_frame(d, 4 * FW, -2, -2, squash=0)
    draw_player_frame(d, 5 * FW, 0, 0, squash=1)
    # jump (legs tucked) / fall (legs spread)
    draw_player_frame(d, 6 * FW, 1, -3, squash=0)
    draw_player_frame(d, 7 * FW, -1, 3, squash=0)
    save(sheet, "player.png")


# ---------------------------------------------------------------------------
# Tileset: 16x16 tiles laid out in one row
# [0]=grass top, [1]=dirt fill, [2]=stone, [3]=platform, [4]=grass-left, [5]=grass-right
# ---------------------------------------------------------------------------
TS = 16


def build_tiles():
    cols = 6
    img = Image.new("RGBA", (TS * cols, TS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    grass = (96, 170, 70, 255)
    grass_d = (70, 135, 55, 255)
    dirt = (120, 85, 55, 255)
    dirt_d = (95, 65, 42, 255)
    stone = (110, 110, 125, 255)
    stone_d = (85, 85, 100, 255)
    plat = (150, 110, 70, 255)
    plat_d = (120, 85, 52, 255)

    def fill(col, c1, c2, speckle):
        x0 = col * TS
        d.rectangle([x0, 0, x0 + TS - 1, TS - 1], fill=c1)
        for sx in range(0, TS, 3):
            for sy in range(0, TS, 4):
                d.point((x0 + (sx + sy) % TS, (sy + sx) % TS), fill=c2)
        for (px, py) in speckle:
            d.point((x0 + px, py), fill=c2)

    # grass top: green cap + dirt body
    x0 = 0
    d.rectangle([x0, 0, x0 + TS - 1, TS - 1], fill=dirt)
    d.rectangle([x0, 0, x0 + TS - 1, 4], fill=grass)
    d.rectangle([x0, 4, x0 + TS - 1, 5], fill=grass_d)
    for sx in range(0, TS, 2):
        d.point((x0 + sx, 0), fill=grass_d)
    for sy in range(6, TS, 5):
        d.point((x0 + (sy * 3) % TS, sy), fill=dirt_d)

    # dirt fill
    fill(1, dirt, dirt_d, [(3, 3), (10, 6), (6, 11), (13, 13)])
    # stone
    fill(2, stone, stone_d, [(2, 2), (9, 5), (5, 10), (12, 12)])
    d.rectangle([2 * TS, 0, 2 * TS, TS - 1], fill=stone_d)
    d.rectangle([2 * TS, 7, 2 * TS + TS - 1, 8], fill=stone_d)

    # platform (one-way) - wooden plank, only top section opaque
    x0 = 3 * TS
    d.rectangle([x0, 0, x0 + TS - 1, 5], fill=plat)
    d.rectangle([x0, 5, x0 + TS - 1, 6], fill=plat_d)
    for sx in range(2, TS, 5):
        d.line([x0 + sx, 0, x0 + sx, 4], fill=plat_d)

    # grass-left edge and grass-right edge (rounded)
    for idx, leftedge in ((4, True), (5, False)):
        x0 = idx * TS
        d.rectangle([x0, 0, x0 + TS - 1, TS - 1], fill=dirt)
        d.rectangle([x0, 0, x0 + TS - 1, 4], fill=grass)
        d.rectangle([x0, 4, x0 + TS - 1, 5], fill=grass_d)
        # darken the outer vertical edge
        ex = x0 if leftedge else x0 + TS - 1
        d.line([ex, 0, ex, TS - 1], fill=dirt_d)

    save(img, "tiles.png")


# ---------------------------------------------------------------------------
# Parallax layers. Internal resolution 480x270. Each layer tiles horizontally.
# ---------------------------------------------------------------------------
PW, PH = 480, 270


def vgrad(img, top_col, bot_col, y0, y1):
    d = ImageDraw.Draw(img)
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0 - 1))
        c = tuple(int(top_col[i] + (bot_col[i] - top_col[i]) * t) for i in range(4))
        d.line([0, y, img.width - 1, y], fill=c)


def build_sky():
    img = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    vgrad(img, (120, 175, 230, 255), (215, 225, 215, 255), 0, PH)
    d = ImageDraw.Draw(img)
    # sun
    d.ellipse([PW - 110, 36, PW - 60, 86], fill=(255, 244, 210, 255))
    d.ellipse([PW - 116, 30, PW - 54, 92], outline=(255, 250, 225, 90))
    save(img, "bg_sky.png")


def silhouette_row(img, base_y, amp, period, col, phase=0.0):
    """Draw a seamless rolling-hill silhouette down to the bottom."""
    d = ImageDraw.Draw(img)
    w = img.width
    for x in range(w):
        # sum of two sines whose periods divide w -> seamless wrap
        y = base_y - int(
            amp * (0.6 * math.sin(2 * math.pi * (x / w) * period + phase)
                   + 0.4 * math.sin(2 * math.pi * (x / w) * period * 2 + phase * 1.7))
        )
        d.line([x, y, x, img.height - 1], fill=col)


def build_mountains():
    # Distant ridge - sits high so its peaks read against the sky.
    img = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    silhouette_row(img, 165, 60, 3, (108, 122, 162, 255), phase=0.4)
    save(img, "bg_mountains.png")


def build_hills():
    # Mid-distance green hills, a touch lower and bigger than the mountains.
    img = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    silhouette_row(img, 198, 34, 5, (84, 150, 100, 255), phase=1.2)
    save(img, "bg_hills.png")


def build_trees():
    # Near tree-line. Foliage pokes above the gameplay horizon; the grassy
    # base sits low and is mostly hidden behind the foreground tilemap.
    img = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ground_y = 214
    d.rectangle([0, ground_y, PW - 1, PH - 1], fill=(56, 108, 70, 255))
    # simple repeating trees, spacing divides width for seamless tiling
    spacing = 80
    for tx in range(0, PW, spacing):
        x = tx + 24
        # trunk
        d.rectangle([x - 3, ground_y - 30, x + 3, ground_y], fill=(70, 50, 38, 255))
        # foliage
        d.ellipse([x - 22, ground_y - 64, x + 22, ground_y - 18], fill=(44, 90, 58, 255))
        d.ellipse([x - 15, ground_y - 76, x + 15, ground_y - 36], fill=(60, 116, 76, 255))
    save(img, "bg_trees.png")


# ---------------------------------------------------------------------------
# Door / checkpoint marker for the map-transition example
# ---------------------------------------------------------------------------
def build_door():
    w, h = 24, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    frame = (60, 45, 70, 255)
    inner = (90, 70, 110, 255)
    glow = (150, 210, 255, 255)
    d.rectangle([0, 2, w - 1, h - 1], fill=frame)
    d.rectangle([3, 5, w - 4, h - 1], fill=inner)
    # glowing portal lines
    for i in range(5, h - 2, 4):
        d.line([4, i, w - 5, i], fill=glow)
    d.rectangle([3, 5, w - 4, h - 1], outline=(200, 235, 255, 255))
    save(img, "door.png")


if __name__ == "__main__":
    build_player()
    build_tiles()
    build_sky()
    build_mountains()
    build_hills()
    build_trees()
    build_door()
    print("done")
