#!/usr/bin/env python3
"""Draw Palm Coast's simple pixel-art props: billboard, lifeguard tower, umbrella, lamp post,
hotel and bush. They were the road prototype's stand-ins and are still placed; the stage's
palms and background come from make_stage_sprites.py.

Usage:
    python3 tools/make_drawn_props.py <project_dir>
"""
import os
import sys

from PIL import Image, ImageDraw


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def make_billboard(path):
    img, d = canvas(96, 76)
    for x in (18, 74):
        d.rectangle((x, 44, x + 4, 75), fill=(70, 52, 40))
        d.rectangle((x + 1, 44, x + 1, 75), fill=(110, 84, 62))
    d.rectangle((0, 0, 95, 50), fill=(40, 34, 52))
    top, bottom = (255, 120, 60), (255, 214, 110)
    for y in range(3, 48):
        t = (y - 3) / 44
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line((3, y, 92, y), fill=c)
    d.ellipse((34, 16, 62, 44), fill=(255, 244, 190))
    for y in range(30, 48, 4):
        d.line((3, y, 92, y), fill=(240, 96, 70))
    d.rectangle((3, 40, 92, 47), fill=(30, 110, 150))
    d.line((14, 47, 18, 18), fill=(40, 30, 40), width=2)
    for dx, dy in ((-8, -2), (8, -2), (-6, 3), (7, 4), (0, -5)):
        d.line((18, 18, 18 + dx, 18 + dy), fill=(40, 30, 40), width=2)
    d.rectangle((0, 0, 95, 50), outline=(20, 16, 28))
    img.save(path)


def make_lifeguard(path):
    img, d = canvas(60, 76)
    leg = (220, 220, 230)
    for x in (10, 46):
        d.line((x, 40, x + (4 if x < 30 else -4), 75), fill=leg, width=3)
    d.line((12, 58, 46, 58), fill=leg, width=2)
    d.rectangle((6, 38, 54, 42), fill=(200, 200, 210))
    d.rectangle((10, 18, 50, 38), fill=(120, 200, 220))
    d.rectangle((16, 22, 44, 32), fill=(40, 70, 100))
    d.polygon([(4, 18), (56, 18), (46, 6), (14, 6)], fill=(220, 50, 50))
    d.line((4, 18, 56, 18), fill=(150, 30, 30))
    d.line((52, 40, 60, 75), fill=(200, 180, 140), width=3)
    d.line((28, 6, 28, 0), fill=(90, 70, 50))
    d.polygon([(28, 0), (36, 2), (28, 4)], fill=(255, 190, 40))
    img.save(path)


def make_umbrella(path):
    img, d = canvas(44, 40)
    d.line((22, 8, 22, 39), fill=(240, 240, 240), width=2)
    d.pieslice((2, 0, 42, 22), 180, 360, fill=(230, 60, 60))
    for i, x in enumerate(range(2, 42, 8)):
        if i % 2:
            d.pieslice((2, 0, 42, 22), 180 + i * 36, 180 + (i + 1) * 36, fill=(250, 250, 245))
    d.rectangle((6, 34, 38, 39), fill=(60, 150, 220))
    d.line((6, 36, 38, 36), fill=(250, 220, 90))
    img.save(path)


def make_lamp(path):
    img, d = canvas(24, 100)
    d.rectangle((10, 12, 13, 99), fill=(60, 66, 80))
    d.rectangle((8, 92, 15, 99), fill=(45, 50, 62))
    d.line((12, 12, 4, 6), fill=(60, 66, 80), width=3)
    d.rectangle((0, 4, 8, 8), fill=(250, 240, 200))
    d.line((12, 12, 20, 6), fill=(60, 66, 80), width=3)
    d.rectangle((16, 4, 23, 8), fill=(250, 240, 200))
    img.save(path)


def make_hotel(path):
    img, d = canvas(128, 100)
    d.rectangle((4, 10, 123, 99), fill=(250, 196, 196))
    d.rectangle((4, 10, 123, 16), fill=(240, 150, 160))
    d.rectangle((50, 0, 78, 12), fill=(250, 196, 196))
    d.rectangle((54, 3, 74, 9), fill=(70, 200, 210))
    for row in range(4):
        for col in range(7):
            x = 12 + col * 16
            y = 22 + row * 16
            d.rectangle((x, y, x + 8, y + 9), fill=(80, 160, 200))
            d.line((x, y + 10, x + 8, y + 10), fill=(255, 255, 255))
    d.rectangle((4, 86, 123, 90), fill=(60, 180, 170))
    for x in range(4, 124, 8):
        d.polygon([(x, 90), (x + 8, 90), (x + 4, 94)], fill=(60, 180, 170))
    d.rectangle((54, 90, 74, 99), fill=(60, 40, 50))
    img.save(path)


def make_bush(path):
    img, d = canvas(40, 24)
    d.ellipse((0, 6, 22, 24), fill=(46, 120, 50))
    d.ellipse((14, 2, 40, 24), fill=(56, 140, 58))
    d.ellipse((8, 0, 28, 18), fill=(70, 160, 66))
    for x, y in ((10, 6), (20, 4), (28, 10), (6, 14), (32, 16), (16, 12)):
        d.rectangle((x, y, x + 2, y + 2), fill=(240, 80, 120))
    img.save(path)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    roadside = os.path.join(sys.argv[1], "assets", "sprites", "roadside", "palm_coast")
    os.makedirs(roadside, exist_ok=True)
    make_billboard(os.path.join(roadside, "billboard.png"))
    make_lifeguard(os.path.join(roadside, "lifeguard_tower.png"))
    make_umbrella(os.path.join(roadside, "umbrella.png"))
    make_lamp(os.path.join(roadside, "lamp_post.png"))
    make_hotel(os.path.join(roadside, "hotel.png"))
    make_bush(os.path.join(roadside, "bush.png"))


if __name__ == "__main__":
    main()
