#!/usr/bin/env python3
"""Draw the road hazards (RC-19): a debris pile and a traffic cone, which stand on the road,
and an ice patch and a puddle, seen from above and laid flat on it. Placeholder pixel art
drawn in code (there is no hazard concept art yet), in assets/sprites/hazards/; the game
reads their sizes from RoadHazards (scripts/race/road_hazards.gd), not the manifest.

Usage:
    python3 tools/make_hazard_sprites.py <project_dir>
"""
import math
import os
import random

from PIL import Image, ImageDraw

import manifest
from spritelib import cli_args, sprite_dir


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def make_debris(path):
    """A pile across a lane: a lost tire, broken planks, a burst crate, scrap between."""
    img, d = canvas(64, 24)
    d.ellipse((2, 19, 62, 24), fill=(0, 0, 0, 90))  # its shadow on the road
    # Planks, splintered at the ends
    d.polygon([(4, 17), (30, 11), (32, 14), (6, 20)], fill=(150, 104, 58))
    d.line((5, 18, 31, 12), fill=(186, 138, 84))
    d.polygon([(30, 20), (58, 15), (59, 18), (31, 23)], fill=(128, 86, 46))
    d.line((31, 21, 58, 16), fill=(170, 120, 70))
    for x, y in ((30, 11), (58, 15)):
        d.polygon([(x, y), (x + 3, y + 1), (x + 1, y + 3)], fill=(196, 150, 96))
    # A burst crate
    d.polygon([(36, 6), (50, 4), (54, 9), (54, 18), (38, 20), (36, 14)], fill=(178, 130, 70))
    d.polygon([(36, 6), (50, 4), (54, 9), (40, 11)], fill=(208, 162, 98))
    d.line((40, 11, 38, 20), fill=(120, 80, 40))
    d.line((44, 10, 52, 17), fill=(120, 80, 40))
    # The tire, lying on its side
    d.ellipse((10, 6, 32, 20), fill=(30, 30, 34))
    d.ellipse((13, 8, 29, 18), fill=(52, 52, 58))
    d.ellipse((17, 10, 25, 16), fill=(120, 124, 132))
    d.ellipse((19, 11, 23, 15), fill=(70, 72, 78))
    for a in range(0, 360, 45):
        x = 21 + 9.5 * math.cos(math.radians(a))
        y = 13 + 6 * math.sin(math.radians(a))
        d.point((round(x), round(y)), fill=(78, 78, 84))
    # Scrap metal glinting between
    for x, y, c in ((8, 21, (170, 176, 186)), (34, 17, (200, 206, 214)), (56, 20, (150, 156, 166)),
                    (48, 21, (210, 80, 50)), (3, 15, (210, 80, 50))):
        d.rectangle((x, y, x + 2, y + 1), fill=c)
    img.save(path)


def make_cone(path):
    """A traffic cone, one of a row closing a lane."""
    img, d = canvas(16, 24)
    d.ellipse((0, 20, 15, 24), fill=(0, 0, 0, 90))
    d.rectangle((0, 20, 15, 22), fill=(40, 40, 44))  # its square base
    d.polygon([(6, 0), (9, 0), (14, 20), (1, 20)], fill=(250, 110, 30))
    d.polygon([(6, 0), (7, 0), (4, 20), (1, 20)], fill=(255, 150, 70))  # lit edge
    d.polygon([(4, 7), (11, 7), (12, 10), (3, 10)], fill=(245, 245, 245))
    d.polygon([(3, 13), (12, 13), (13, 16), (2, 16)], fill=(245, 245, 245))
    d.line((9, 1, 13, 19), fill=(200, 70, 20))
    img.save(path)


def blob(d, w, h, rng, color, rings, rough):
    """A ragged oval filling a w x h canvas: `rings` (scale, color) drawn inward over it."""
    for k, (scale, c) in enumerate([(1.0, color)] + rings):
        pts = []
        for i in range(40):
            a = 2 * math.pi * i / 40
            r = scale * (1.0 - rough * rng.random()) * (1.0 if k == 0 else 0.97)
            pts.append((w / 2 + (w / 2 - 1) * r * math.cos(a), h / 2 + (h / 2 - 1) * r * math.sin(a)))
        d.polygon(pts, fill=c)


def make_ice(path):
    """An ice patch seen from above, the length of the road up the picture: pale blue, glassy
    streaks along it, frost at the ragged edge."""
    rng = random.Random(1919)
    img, d = canvas(64, 128)
    blob(d, 64, 128, rng, (226, 240, 252, 235),
         [(0.9, (188, 222, 246, 235)), (0.75, (162, 206, 240, 230))], 0.12)
    for _ in range(14):  # tire-polished streaks along the road
        x = rng.randint(14, 50)
        y = rng.randint(14, 100)
        d.line((x, y, x + rng.randint(-2, 2), y + rng.randint(10, 24)), fill=(240, 250, 255, 240), width=1)
    for _ in range(6):  # cracks
        x, y = rng.randint(16, 48), rng.randint(20, 108)
        for _ in range(3):
            nx, ny = x + rng.randint(-6, 6), y + rng.randint(-6, 6)
            d.line((x, y, nx, ny), fill=(120, 170, 214, 255))
            x, y = nx, ny
    for _ in range(60):  # frost specks
        a = rng.random() * 2 * math.pi
        r = 0.82 + 0.14 * rng.random()
        x = round(32 + 31 * r * math.cos(a))
        y = round(64 + 63 * r * math.sin(a))
        d.point((x, y), fill=(255, 255, 255, 255))
    img.save(path)


def make_puddle(path):
    """A deep puddle seen from above: dark water, the sky's light in it, rings, a muddy rim."""
    rng = random.Random(1974)
    img, d = canvas(64, 96)
    blob(d, 64, 96, rng, (58, 54, 50, 220),
         [(0.9, (34, 40, 54, 235)), (0.62, (52, 64, 88, 235))], 0.14)
    for k, (rx, ry) in enumerate(((20, 30), (13, 20), (7, 11))):  # ripple rings
        d.ellipse((32 - rx, 50 - ry, 32 + rx, 50 + ry), outline=(110, 128, 160, 200 - 40 * k))
    d.polygon([(18, 22), (30, 16), (34, 20), (22, 28)], fill=(170, 186, 214, 200))  # the sky's glint
    d.line((40, 30, 46, 38), fill=(150, 168, 200, 180))
    img.save(path)


# name: drawing function, in hazards/
DRAWN = {
    "debris": make_debris,
    "cone": make_cone,
    "ice": make_ice,
    "puddle": make_puddle,
}


def main():
    (project_dir,) = cli_args(__doc__, 1)
    out = sprite_dir(project_dir, "hazards")
    for name, draw in DRAWN.items():
        draw(os.path.join(out, name + ".png"))
        print(name)
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
