#!/usr/bin/env python3
"""Put a rendered car (tools/blender/render_car_hero.py) in front of the title screen's coast and
cut it to a car select picture.

    python3 tools/make_car_heroes.py build/car_heroes . [car ...]

Reads <render_dir>/<car>.png and its .horizon (the horizon's row, 0 top .. 1 bottom), writes
assets/sprites/ui/car_<car>.png at the size tools/make_ui_sprites.py gives the concept
pictures. With no cars named, every car with a render.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_ui_sprites import CAR_SIZE, quantize  # noqa: E402
from make_car_renders import shift_hue_band  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender"))
from car_looks import look  # noqa: E402

BACKDROP = "assets/sprites/ui/title_bg.png"
# The backdrop's own horizon, where the sea meets the sky, as a share of its height
BACKDROP_HORIZON = 252 / 360


def compose(render_path, horizon, project, band=None):
    car = Image.open(render_path).convert("RGBA")
    if band:  # the paint fix the race strips get (car_looks.py hue_band); the road and sand are out of every band
        car = shift_hue_band(car, band)
    bg = Image.open(os.path.join(project, BACKDROP)).convert("RGBA")
    scale = car.width / bg.width
    bg = bg.resize((car.width, round(bg.height * scale)), Image.LANCZOS)
    top = round(horizon * car.height - BACKDROP_HORIZON * bg.height)
    out = Image.new("RGBA", car.size, bg.getpixel((0, 0)))
    out.alpha_composite(bg, (0, top)) if top >= 0 else out.alpha_composite(bg.crop((0, -top, bg.width, bg.height)), (0, 0))
    out.alpha_composite(car)
    return quantize(out.convert("RGB").resize(CAR_SIZE, Image.LANCZOS))


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    render_dir, project = sys.argv[1], sys.argv[2]
    cars = sys.argv[3:] or sorted(f[:-4] for f in os.listdir(render_dir) if f.endswith(".png"))
    for car in cars:
        with open(os.path.join(render_dir, car + ".horizon")) as f:
            horizon = float(f.read())
        pic = compose(os.path.join(render_dir, car + ".png"), horizon, project, look(car)["hue_band"])
        path = os.path.join(project, "assets", "sprites", "ui", "car_%s.png" % car)
        pic.save(path)
        print("car_" + car, pic.size)


if __name__ == "__main__":
    main()
