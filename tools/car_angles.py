#!/usr/bin/env python3
"""Build the car-angle review page from tools/car_angles.gd's shots.

Crops each 640x360 frame to the bottom middle, where the player's car sits, and inlines the
crops (WebP) and index.json into tools/car_angles.html, so the page is one file to open or share.

Usage:
    godot --path . -s res://tools/car_angles.gd -- --out=/tmp/angles
    python3 tools/car_angles.py /tmp/angles /tmp/angles/car_angles.html
"""
import base64
import datetime
import io
import json
import os
import sys

from PIL import Image

# (left, top, right, bottom) of the 640x360 frame: the car and a car's width of road each side
CROP = (180, 150, 460, 350)
QUALITY = 92  # WebP; lossless would make the page about three times bigger
# CarSprites.PITCH_SWITCH: |pitch| at which a pitched strip takes over from the level one
PITCH_SWITCH = 0.4
TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "car_angles.html")


def shot_uri(path):
    img = Image.open(path).convert("RGB").crop(CROP)
    buf = io.BytesIO()
    img.save(buf, "WEBP", quality=QUALITY, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()


def build(shot_dir):
    """index.json plus every shot, keyed "car_id|slope|frame"."""
    with open(os.path.join(shot_dir, "index.json")) as f:
        index = json.load(f)
    shots = {}
    for car in index["cars"]:
        for slope in index["slopes"]:
            for frame in range(len(index["steer"])):
                name = "%s_%s_%d.png" % (car["strip"], slope["id"], frame)
                shots["%s|%s|%d" % (car["id"], slope["id"], frame)] = shot_uri(os.path.join(shot_dir, name))
    index.update(shots=shots, crop=CROP, pitch_switch=PITCH_SWITCH,
                 made=datetime.date.today().isoformat())
    return index


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    shot_dir, out = sys.argv[1], sys.argv[2]
    with open(TEMPLATE) as f:
        page = f.read().replace("/*DATA*/null", json.dumps(build(shot_dir)))
    with open(out, "w") as f:
        f.write(page)
    print("wrote %s (%.1f MB)" % (out, os.path.getsize(out) / 1e6))


if __name__ == "__main__":
    main()
