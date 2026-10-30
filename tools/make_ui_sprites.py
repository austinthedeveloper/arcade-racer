#!/usr/bin/env python3
"""Build the menu art from the concept sheets.

- The SUNDOWN RUN logo (UI-01), its black backdrop keyed out.
- A 640x360 title backdrop from the Palm Coast background composite.
- One postcard per stage (16:9) from each stage's background composite.
- The Vega GT showroom picture, cropped from its v2 hero art (the round 2 review approved
  that design; the screen mockups' cars are layout reference only).

Usage:
    python3 tools/make_ui_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

from PIL import Image

# Stage order matches Stages.NAMES; Skyline is held back.
STAGES = ["palm-coast", "redrock", "neon", "timberline", "bayou", "harvest", "thunder"]
POSTCARD = (224, 126)
LOGO_WIDTH = 360
VEGA_CROP = (180, 470, 1320, 1000)  # the car and a little road, in the hero art
VEGA_SIZE = (304, 141)


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
        src = Image.open(os.path.join(concept, "backgrounds", stage + "_composite_A_v1.png"))
        card = quantize(crop_16_9(src).resize(POSTCARD, Image.LANCZOS))
        name = "postcard_" + stage.replace("-", "_") + ".png"
        card.save(os.path.join(out, name))
        print(name, card.size)

    hero = Image.open(os.path.join(concept, "cars", "car_vega_hero_A_v2.png")).crop(VEGA_CROP)
    vega = quantize(hero.resize(VEGA_SIZE, Image.LANCZOS))
    vega.save(os.path.join(out, "car_vega.png"))
    print("car_vega", vega.size)


if __name__ == "__main__":
    main()
