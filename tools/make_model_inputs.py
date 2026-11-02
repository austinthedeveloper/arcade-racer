#!/usr/bin/env python3
"""The pictures to give an image-to-3D tool (Tripo's multi-view mode) for a car (CP-1, CP-2).

    python3 tools/make_model_inputs.py vega [--sheet car_vega_views_A_v2.png] [--out build/model_inputs]

Cuts the car's views sheet (assets/concept/cars/car_<car>_views_*.png, the newest by default:
back, front and side, left to right, on magenta) into back.png, front.png, left.png and
right.png on transparent backgrounds, each padded to a square. The sheet's side view has the
nose to the left, so it shows the car's left flank; the right is that one mirrored. The hero
picture, if there is one, is copied as hero.png for a tool that takes one image.
"""
import argparse
import glob
import os
import shutil

from PIL import Image

from spritelib import key_sheet, slice_row

PROJECT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CONCEPT = os.path.join(PROJECT, "assets", "concept", "cars")
VIEWS = ["back", "front", "left"]
PAD = 0.1  # of the square's side, around the car


def newest(car, kind):
    found = sorted(glob.glob(os.path.join(CONCEPT, "car_%s_%s_*.png" % (car, kind))))
    return found[-1] if found else None


def square(img, pad=PAD):
    """`img` centred on a transparent square with `pad` of margin."""
    side = round(max(img.size) * (1 + 2 * pad))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return out


def views(sheet_path):
    """{name: image} for the views sheet: back, front, left (as drawn) and right (mirrored)."""
    sheet = Image.open(sheet_path).convert("RGB")
    crops = slice_row(key_sheet(sheet), key_sheet(sheet, hue_fringe=0, spill=0))
    if len(crops) != len(VIEWS):
        raise SystemExit("%s: found %d views, expected %d (back, front, side)" % (sheet_path, len(crops), len(VIEWS)))
    out = {name: square(c) for name, c in zip(VIEWS, crops)}
    out["right"] = out["left"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("car")
    ap.add_argument("--sheet", help="views sheet in assets/concept/cars (default: the newest)")
    ap.add_argument("--out", default=os.path.join(PROJECT, "build", "model_inputs"))
    a = ap.parse_args()
    sheet = os.path.join(CONCEPT, a.sheet) if a.sheet else newest(a.car, "views")
    if not sheet:
        raise SystemExit("no views sheet for " + a.car)
    out_dir = os.path.join(a.out, a.car)
    os.makedirs(out_dir, exist_ok=True)
    for name, img in views(sheet).items():
        img.save(os.path.join(out_dir, name + ".png"))
    hero = newest(a.car, "hero")
    if hero:
        shutil.copy(hero, os.path.join(out_dir, "hero.png"))
    print("from", os.path.basename(sheet), "->", os.path.relpath(out_dir, PROJECT), sorted(os.listdir(out_dir)))


if __name__ == "__main__":
    main()
