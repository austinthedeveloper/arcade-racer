#!/usr/bin/env python3
"""Build the menu art from the concept sheets.

- The SUNDOWN RUN logo (UI-01), its black backdrop keyed out.
- A 640x360 title backdrop from the Palm Coast background composite.
- One postcard per stage (16:9) from each stage's background composite.
- A showroom picture per car, cropped from its approved hero art (the screen mockups' cars
  are layout reference only).

Usage:
    python3 tools/make_ui_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

from PIL import Image

# Stage order matches Stages.NAMES
STAGES = ["palm-coast", "redrock", "neon", "timberline", "bayou", "harvest", "thunder", "skyline"]
# Composite version per stage where the first one was rerolled
COMPOSITE = {"skyline": "A_v2"}
POSTCARD = (224, 126)
LOGO_WIDTH = 360
CAR_SIZE = (304, 141)
# Showroom pictures: (car, hero art, crop). Most heroes share the Vega's framing; the Hauler
# and Zenith fill more of theirs, so they are cropped wider.
CAR_CROP = (100, 400, 1348, 979)  # the car and a little road
CARS = [
    ("vega", "car_vega_hero_A_v2.png", CAR_CROP),
    ("bruiser", "car_bruiser_hero_A_v3.png", CAR_CROP),
    ("kestrel", "car_kestrel_hero_A_v2.png", CAR_CROP),
    ("sol", "car_sol_hero_A_v2.png", CAR_CROP),
    ("mesa", "car_mesa_hero_A_v2.png", CAR_CROP),
    ("phantom", "car_phantom_hero_A_v2.png", CAR_CROP),
    ("hauler", "car_hauler_hero_A_v1.png", (0, 250, 1448, 922)),
    ("zenith", "car_zenith_hero_A_v1.png", (0, 270, 1448, 942)),
    ("tempest", "car_tempest_hero_A_v1.png", CAR_CROP),
    ("skipper", "car_skipper_hero_A_v1.png", CAR_CROP),
    ("halo", "car_halo_hero_A_v1.png", CAR_CROP),
    ("cyclone", "car_cyclone_hero_A_v2.png", CAR_CROP),
]


def quantize(img, colors=128):
    return img.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")


def crop_16_9(img):
    h = img.height
    w = round(h * 16 / 9)
    x0 = (img.width - w) // 2
    return img.crop((x0, 0, x0 + w, h))


def make_logo(src, out_path):
    img = src.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, _ = px[x, y]
            if max(r, g, b) < 28:
                px[x, y] = (0, 0, 0, 0)
    img = img.crop(img.getbbox())
    h = round(img.height * LOGO_WIDTH / img.width)
    img = img.resize((LOGO_WIDTH, h), Image.LANCZOS)
    px = img.load()
    for y in range(h):
        for x in range(LOGO_WIDTH):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    img.save(out_path)
    print("logo", img.size)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    concept, project = sys.argv[1], sys.argv[2]
    out = os.path.join(project, "assets", "sprites", "ui")
    os.makedirs(out, exist_ok=True)

    make_logo(Image.open(os.path.join(concept, "ui", "ui01_logo_A_v1.png")), os.path.join(out, "logo.png"))

    palm = Image.open(os.path.join(concept, "backgrounds", "palm-coast_composite_A_v1.png"))
    title = quantize(crop_16_9(palm).resize((640, 360), Image.LANCZOS))
    title.save(os.path.join(out, "title_bg.png"))
    print("title_bg", title.size)

    for stage in STAGES:
        src = Image.open(os.path.join(concept, "backgrounds", "%s_composite_%s.png" % (stage, COMPOSITE.get(stage, "A_v1"))))
        card = quantize(crop_16_9(src).resize(POSTCARD, Image.LANCZOS))
        name = "postcard_" + stage.replace("-", "_") + ".png"
        card.save(os.path.join(out, name))
        print(name, card.size)

    for car, hero_file, crop in CARS:
        hero = Image.open(os.path.join(concept, "cars", hero_file)).crop(crop)
        pic = quantize(hero.resize(CAR_SIZE, Image.LANCZOS))
        pic.save(os.path.join(out, "car_%s.png" % car))
        print("car_" + car, pic.size)


if __name__ == "__main__":
    main()
