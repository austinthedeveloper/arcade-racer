#!/usr/bin/env python3
"""Player car strips from Blender renders (CP-1), in place of the concept-sheet ones.

    python3 tools/make_car_renders.py build/car_renders/vega vega [--install]

Reads the 21 frames tools/blender/render_car.py writes (<pitch>_<frame>.png, pitch level, up
and down) and makes the three strips the game reads (CarSprites.strips): <car>_steer.png,
<car>_steer_up.png and <car>_steer_down.png, laid out as tools/make_car_sprites.py lays out
the sheet ones. Every frame shares one scale, set by the level straight frame's width, so the
car doesn't change size when the game swaps strips on a hill. Then a pixel pass: box-filtered
down with hard alpha edges (spritelib.pixelate_down), the colors cut to a palette if COLORS asks
for one, a dark outline, like the concept art, glass in the windows and a shadow under the car.

The strips go to <render dir>/strips/ and a review page, <render dir>/compare.html, sets them
beside the concept-sheet strips in assets/sprites/cars/. --install writes them over those.
"""
import argparse
import base64
import html
import os
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage

from make_car_sprites import PLAYER_BODY_WIDTH, save_strip
from spritelib import pixelate_down, rgba

PITCHES = {"level": "_steer", "up": "_steer_up", "down": "_steer_down"}
FRAMES = 7
# Palette for the three strips, after the downscale; 0 for none. The concept-sheet strips have
# tens of thousands of colors. At 64 smooth paint breaks into blotches, at 256 it still pales.
COLORS = 0
OUTLINE_DARKEN = 0.35  # edge pixels keep this much of their color
ALPHA_CUT = 8  # render alpha below this is background
# An AI-made model has no glass: its windows are holes, and the road would show through the
# cabin. A hole in the outline gets this, top to bottom, dark with some sky on it.
GLASS_TOP = (78, 102, 138)
GLASS_BOTTOM = (20, 28, 46)
# A shadow under the car down to the sprite's bottom edge, so it meets the road: the game stands
# a strip's lowest pixel on the road, and tail pipes hang lower than the tires' contact.
CONTACT_SHADE = (8, 8, 12, 210)
CONTACT_BAND = 0.1  # the columns with car in this bottom share of the frame get it


def load(path):
    with Image.open(path) as img:
        return img.convert("RGBA")


def trim(img):
    """The frame cut to its opaque pixels."""
    box = Image.fromarray((rgba(img)[..., 3] >= ALPHA_CUT).astype(np.uint8) * 255).getbbox()
    return img.crop(box) if box else img


def outline(img, darken=OUTLINE_DARKEN):
    """Opaque pixels next to a clear one (4-neighbour) darkened: a one-pixel outline inside
    the sprite, so it stays the same size."""
    a = rgba(img)
    solid = a[..., 3] > 0
    pad = np.pad(solid, 1)
    inner = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    edge = solid & ~inner
    a[edge, :3] = (a[edge, :3] * darken).astype(np.uint8)
    return Image.fromarray(a)


def fill_glass(img):
    """Clear pixels the car's outline closes in (windows, seen through the cabin) filled with
    glass, GLASS_TOP at the top of the frame's holes to GLASS_BOTTOM at the bottom."""
    a = rgba(img)
    solid = a[..., 3] > 0
    holes = ndimage.binary_fill_holes(solid) & ~solid
    if holes.any():
        rows = np.where(holes.any(axis=1))[0]
        share = (np.arange(a.shape[0]) - rows[0]) / max(rows[-1] - rows[0], 1)
        ramp = np.outer(np.clip(share, 0.0, 1.0), np.subtract(GLASS_BOTTOM, GLASS_TOP)) + GLASS_TOP
        a[holes, :3] = np.broadcast_to(ramp[:, None, :], a.shape[:2] + (3,))[holes].astype(np.uint8)
        a[holes, 3] = 255
    return Image.fromarray(a)


def contact_shadow(img):
    """CONTACT_SHADE under the car, in every column from its left to its right in the frame's
    bottom CONTACT_BAND, from the car's lowest pixel there down to the frame's bottom."""
    a = rgba(img)
    h = a.shape[0]
    solid = a[..., 3] > 0
    band = solid[h - max(1, int(h * CONTACT_BAND)):]
    cols = np.where(band.any(axis=0))[0]
    if len(cols) == 0:
        return img
    for x in range(cols[0], cols[-1] + 1):
        rows = np.where(solid[:, x])[0]
        a[rows[-1] + 1 if len(rows) else 0:, x] = CONTACT_SHADE
    return Image.fromarray(a)


def quantize(frames, colors=COLORS):
    """The frames cut to one shared palette of `colors`, alpha kept, no dithering."""
    sheet = Image.new("RGB", (sum(f.width for f in frames), max(f.height for f in frames)))
    x = 0
    for f in frames:
        sheet.paste(f.convert("RGB"), (x, 0))
        x += f.width
    pal = sheet.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = []
    for f in frames:
        q = f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        a = rgba(q)
        a[..., 3] = rgba(f)[..., 3]
        out.append(Image.fromarray(a))
    return out


def render_scale(level_straight, body_width=PLAYER_BODY_WIDTH):
    """Scale from render pixels to texture pixels: the level straight frame's body fills
    body_width, as on the concept-sheet strips."""
    return body_width / trim(level_straight).width


def make_strips(render_dir, car, out_dir):
    frames = {p: [load(os.path.join(render_dir, "%s_%d.png" % (p, i))) for i in range(FRAMES)] for p in PITCHES}
    scale = render_scale(frames["level"][FRAMES // 2])
    small = {p: [pixelate_down(trim(f), scale) for f in fs] for p, fs in frames.items()}
    flat = [f for fs in small.values() for f in fs]
    if COLORS:
        flat = quantize(flat, COLORS)
    paths = []
    for k, p in enumerate(PITCHES):
        strip = [contact_shadow(outline(fill_glass(f))) for f in flat[k * FRAMES:(k + 1) * FRAMES]]
        path = os.path.join(out_dir, car + PITCHES[p] + ".png")
        save_strip(strip, path)
        paths.append(path)
    return paths


def compare_page(render_dir, car, project_dir, strips):
    """compare.html: each pitch's sheet strip over its rendered strip, at 1x and 3x, the
    images inside the page so it opens anywhere."""
    rows = []
    for path in strips:
        name = os.path.basename(path)
        old = os.path.join(project_dir, "assets", "sprites", "cars", name)
        cells = []
        for label, src in (("concept sheet", old), ("render", path)):
            if not os.path.exists(src):
                cells.append("<p>%s: none</p>" % label)
                continue
            w, h = load(src).size
            with open(src, "rb") as f:
                data = "data:image/png;base64," + base64.b64encode(f.read()).decode()
            cells.append('<p>%s, %dx%d</p><img src="%s" width="%d"><img src="%s" width="%d" class="big">'
                         % (html.escape(label), w, h, data, w, data, w * 3))
        rows.append("<h2>%s</h2>%s" % (name, "".join(cells)))
    page = """<!doctype html><meta charset="utf-8"><title>%s renders</title>
<style>body{background:#4a4d55;color:#eee;font:14px system-ui;margin:16px}
img{image-rendering:pixelated;display:block;margin:4px 0 12px;background:#6b6e74}
.big{max-width:none}</style><h1>%s: concept-sheet strips vs renders</h1>%s""" % (car, car, "".join(rows))
    out = os.path.join(render_dir, "compare.html")
    with open(out, "w") as f:
        f.write(page)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("render_dir")
    ap.add_argument("car")
    ap.add_argument("--project", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    ap.add_argument("--install", action="store_true", help="write the strips into assets/sprites/cars/")
    a = ap.parse_args()
    strips = make_strips(a.render_dir, a.car, os.path.join(a.render_dir, "strips"))
    print("review:", compare_page(a.render_dir, a.car, a.project, strips))
    if a.install:
        dest = os.path.join(a.project, "assets", "sprites", "cars")
        for path in strips:
            shutil.copy(path, os.path.join(dest, os.path.basename(path)))
            print("installed", os.path.basename(path))


if __name__ == "__main__":
    main()
