#!/usr/bin/env python3
"""See a car's render settings at work (CP-2): the quick loop while tuning tools/blender/car_looks.py.

    python3 tools/car_review.py hauler,halo [--tilt=6] [--frames=level_3,level_6]
    python3 tools/car_review.py hauler,halo --race       # after tools/render_car.sh, in real races

The first renders the frames from each car's model (seconds, not the 21 of render_car.sh) beside
its concept-sheet frames in build/car_renders/review.png, and prints how the paint measures
against the concept's. --race races the concept strips and build/car_renders/<car>/strips/ on a
few stages, same frames side by side, in build/car_renders/race_<car>.png. Those strips go in a
copy of the game, build/car_trial, so assets/sprites/cars/ stays as it is; the command to play
that copy is printed at the end.

Models are in --models (default assets/models, then build/car_models).
"""
import argparse
import colorsys
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

import make_car_renders as mcr
from make_car_sprites import GARAGE, PLAYER_SHEETS, make_player
from spritelib import rgba

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BUILD = os.path.join(ROOT, "build")
# (name, stage, segment, frame): just after GO on flat road, then partway up a hill
RACE_SHOTS = [("palm", 1, 400, 300), ("neon", 3, 400, 300), ("forest", 5, 400, 300), ("uphill", 1, 1411, 300)]
PAINT_SATURATION = 0.35  # a pixel under this isn't measured as paint
PAINT_VALUE = 0.3


def paint_measure(img):
    """(commonest hue in degrees, mean saturation, median value) of the paint in `img`. The
    commonest hue, not the mean: red wraps round. (0, 0, 0) for no paint."""
    a = rgba(img)
    a = a[a[..., 3] > 200][:, :3] / 255.0
    top, low = a.max(axis=1), a.min(axis=1)
    sat = (top - low) / np.maximum(top, 1e-3)
    paint = (sat > PAINT_SATURATION) & (top > PAINT_VALUE)
    if not paint.any():
        return (0.0, 0.0, 0.0)
    hues = np.array([colorsys.rgb_to_hsv(*p)[0] for p in a[paint][::5]]) * 360.0
    counts, edges = np.histogram(hues, bins=36, range=(0.0, 360.0))
    return (float(edges[counts.argmax()] + 5.0), float(sat[paint].mean()), float(np.median(top[paint])))


def concept_frames(car):
    """`car`'s concept-sheet strip, cut fresh (the one in the game may be the render by now), as
    its seven frames. None if it has no sheet."""
    sheets = dict(GARAGE)
    sheets["vega"] = PLAYER_SHEETS[0][0]
    if car not in sheets:
        return None
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "strip.png")
        make_player(os.path.join(ROOT, "assets", "concept", "cars", sheets[car]), out)
        strip = mcr.load(out)
    cell = strip.width // mcr.FRAMES
    return [strip.crop((cell * i, 0, cell * (i + 1), strip.height)) for i in range(mcr.FRAMES)]


def model_path(car, models):
    for d in filter(None, (models, os.path.join(ROOT, "assets", "models"), os.path.join(ROOT, "build", "car_models"),
                           os.path.join(ROOT, "..", "..", "..", "build", "car_models"))):
        path = os.path.join(d, car + ".glb")
        if os.path.exists(path):
            return path
    sys.exit("no model for " + car)


def rendered(car, frames, a):
    """The strip pass's frames for `car`, rendered now."""
    out = tempfile.mkdtemp()
    cmd = ["blender", "-b", "--factory-startup", "-P", os.path.join(ROOT, "tools", "blender", "render_car.py"), "--",
           "--model", model_path(car, a.models), "--out", out, "--car=" + car, "--only=" + ",".join(frames),
           "--size=" + str(a.size)]
    if a.tilt is not None:
        cmd.append("--tilt=%g" % a.tilt)
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    raw = [mcr.load(os.path.join(out, f + ".png")) for f in frames]
    shutil.rmtree(out)
    scale = mcr.render_scale(raw[0])
    band = mcr.look(car)["hue_band"]
    done = []
    for f in raw:
        small = mcr.pixelate_down(mcr.trim(f), scale)
        if band:
            small = mcr.shift_hue_band(small, band)
        done.append(mcr.contact_shadow(mcr.outline(mcr.fill_glass(small))))
    return done


def review(cars, a):
    frames = a.frames.split(",")
    cells = len(frames) * 2
    tile = (190, 150)
    sheet = Image.new("RGB", (tile[0] * cells, (tile[1] + 16) * len(cars)), (88, 90, 96))
    draw = ImageDraw.Draw(sheet)
    for y, car in enumerate(cars):
        concept = concept_frames(car)
        renders = rendered(car, frames, a)
        pairs = []
        for name, r in zip(frames, renders):
            c = concept[int(name.split("_")[1])] if concept else r
            pairs += [c, r]
        want, got = paint_measure(pairs[0]), paint_measure(pairs[1])
        print("%-8s concept hue %3.0f sat %.2f val %.2f | render hue %3.0f sat %.2f val %.2f"
              % ((car,) + want + got))
        draw.text((4, y * (tile[1] + 16) + 2), car, fill=(255, 230, 120))
        for x, img in enumerate(pairs):
            img = img.crop(img.getbbox())
            img.thumbnail((tile[0] - 8, tile[1] - 4))
            sheet.paste(img, (x * tile[0] + 4, y * (tile[1] + 16) + 16), img)
    os.makedirs(BUILD, exist_ok=True)
    path = os.path.join(a.out_dir, "review.png")
    sheet.save(path)
    print("review:", path)


def trial_copy(cars):
    """build/car_trial: the game with these cars' render strips in, imported."""
    open(os.path.join(BUILD, ".gdignore"), "a").close()  # or Godot imports everything in build/
    copy = os.path.join(BUILD, "car_trial")
    subprocess.run(["rsync", "-a", "--exclude", ".git", "--exclude", "build", "--exclude", ".godot",
                    "--exclude", "assets/concept", "--exclude", "assets/models", "--exclude", "tests/shots",
                    ROOT + "/", copy + "/"], check=True)
    for car in cars:
        strips = os.path.join(BUILD, "car_renders", car, "strips")
        for name in os.listdir(strips):
            shutil.copy(os.path.join(strips, name), os.path.join(copy, "assets", "sprites", "cars", name))
    subprocess.run([godot(), "--headless", "--path", copy, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return copy


def godot():
    return os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"


def race_shot(project, car, shot, out):
    name, stage, segment, frame = shot
    subprocess.run([godot(), "--path", project, "--fixed-fps", "60", "--audio-driver", "Dummy", "--quit-after", str(frame + 60),
                    "--", "--autodrive", "--stage=%d" % stage, "--at-segment=%d" % segment, "--car=car_" + car,
                    "--settings-file=" + os.path.join(out, "opts.cfg"), "--screenshots=%d" % frame, "--shot-dir=" + out],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=200)
    return Image.open(os.path.join(out, "frame_%05d.png" % frame)).convert("RGB")


def race(cars):
    copy = trial_copy(cars)
    for car in cars:
        rows = []
        with tempfile.TemporaryDirectory() as d:
            for shot in RACE_SHOTS:
                rows.append([race_shot(p, car, shot, os.path.join(d, k)) for p, k in ((ROOT, "concept"), (copy, "render"))])
        w, h = rows[0][0].size
        box = (w // 4, h // 2 - h // 36, w * 3 // 4, h - h // 36)
        size = (box[2] - box[0], box[3] - box[1])
        sheet = Image.new("RGB", (size[0] * 2 + 8, (size[1] + 8) * len(rows)), (20, 20, 24))
        for y, row in enumerate(rows):
            for x, img in enumerate(row):
                sheet.paste(img.crop(box), (x * (size[0] + 8), y * (size[1] + 8)))
        path = os.path.join(BUILD, "car_renders", "race_%s.png" % car)
        sheet.save(path)
        print("race:", path)
    print("play it: %s --path %s -- --stage=1 --car=car_%s --save-file=%s" % (godot(), copy, cars[0], os.path.join(BUILD, "trial_save.cfg")))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("cars")
    ap.add_argument("--race", action="store_true")
    ap.add_argument("--models")
    ap.add_argument("--tilt", type=float)
    ap.add_argument("--frames", default="level_3,level_6")
    ap.add_argument("--size", type=int, default=480)
    ap.add_argument("--out-dir", default=os.path.join(BUILD, "car_renders"))
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    cars = a.cars.split(",")
    if a.race:
        race(cars)
    else:
        review(cars, a)


if __name__ == "__main__":
    main()
