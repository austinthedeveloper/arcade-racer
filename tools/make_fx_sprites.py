#!/usr/bin/env python3
"""Build the FX layer's sprites from the round 2/3 concept sheets (assets/prompts/fx).

- fx01: tire smoke, eight frames (also the landing puff).
- fx02: nitro exhaust flame, six frames (one flame of each twin pair), and the shock burst.
- fx03: spark spray, six frames, and the impact starburst.
- fx04: surface kick-up, five frames each of dust, sand, snow and water.
- fx06: fireworks in four colors, six frames each; confetti pieces and streamers.
- fx07: speed lines in three intensities, stretched to the screen.

The frames sit in rows with uneven gaps, and some touch, so each animation is cut at
hand-picked x positions (refined to the emptiest column nearby) instead of by finding
objects. Every frame of one animation shares one scale, so the animation doesn't pump.
FX have no world size, so nothing here goes in the manifest.

Usage:
    python3 tools/make_fx_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

from spritelib import hard_alpha, key_out, pixelate_down, rgba

SCREEN = (640, 360)
SNAP = 40  # how far (sheet pixels) a cut may move to find an emptier column

# name: (sheet, (y0, y1) band on the sheet, x cuts (n + 1 for n frames), frames to keep (1-based,
# None for all), texture height of the tallest kept frame)
ANIMS = {
    "smoke": ("fx01_tire_smoke_A_v1.png", (235, 470), [30, 200, 440, 700, 965, 1280, 1596, 1876, 2145], None, 40),
    # Twin flames: the left flame of each pair (the right one is a mirror of it, near enough)
    "nitro": ("fx02_nitro_A_v1.png", (240, 570), [90, 160, 315, 415, 560, 702, 865, 1032, 1205, 1343, 1535, 1630],
              [1, 3, 5, 7, 9, 11], 40),
    "nitro_burst": ("fx02_nitro_A_v1.png", (240, 570), [1800, 2120], None, 36),
    "sparks": ("fx03_sparks_A_v1.png", (330, 580), [8, 183, 354, 527, 700, 865, 1040], None, 40),
    "impact": ("fx03_sparks_A_v1.png", (330, 580), [1490, 1665], None, 32),
    "dust": ("fx04_surface_kickup_A_v1.png", (4, 238), [16, 246, 538, 853, 1210, 1660], None, 48),
    "sand": ("fx04_surface_kickup_A_v1.png", (238, 480), [16, 246, 538, 853, 1210, 1660], None, 48),
    "snow": ("fx04_surface_kickup_A_v1.png", (482, 710), [16, 246, 538, 853, 1210, 1660], None, 48),
    "water": ("fx04_surface_kickup_A_v1.png", (710, 930), [16, 246, 538, 853, 1210, 1660], None, 48),
    "firework_orange": ("fx06_celebration_A_v1.png", (4, 200), [100, 265, 535, 815, 1090, 1370, 1620], None, 72),
    "firework_blue": ("fx06_celebration_A_v1.png", (200, 398), [100, 265, 535, 815, 1090, 1370, 1620], None, 72),
    "firework_red": ("fx06_celebration_A_v1.png", (398, 590), [100, 265, 535, 815, 1090, 1370, 1620], None, 72),
    "firework_green": ("fx06_celebration_A_v1.png", (590, 788), [100, 265, 535, 815, 1090, 1370, 1620], None, 72),
    "streamer": ("fx06_celebration_A_v1.png", (790, 935), [1352, 1424, 1487, 1560, 1640], None, 18),
}
CONFETTI = ("fx06_celebration_A_v1.png", (790, 935), (30, 830), 7)  # sheet, y band, x range, height
SPEED = ("fx07_speed_A_v1.png", (230, 710), [20, 415, 835, 1255])
# The smoke's fading frames are see-through paint over the magenta, so they come out pink:
# these animations are made gray, keeping each pixel's brightness
GRAY = {"smoke"}


def desaturate(img):
    a = rgba(img)
    lum = a[..., :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    a[..., :3] = np.clip(lum, 0, 255).astype(np.uint8)[..., None]
    return Image.fromarray(a)


def emptiest_column(alpha, x):
    """The column within SNAP of `x` with the fewest opaque pixels (nearest on a tie)."""
    lo, hi = max(0, x - SNAP), min(alpha.shape[1], x + SNAP + 1)
    counts = alpha[:, lo:hi].sum(axis=0)
    best = np.flatnonzero(counts == counts.min())
    return lo + int(best[np.argmin(np.abs(best + lo - x))])


def cut_frames(keyed, band, cuts):
    """The band cut into frames at the (snapped) x cuts, each trimmed to its pixels."""
    strip = keyed.crop((0, band[0], keyed.width, band[1]))
    alpha = rgba(strip)[..., 3] > 0
    xs = [emptiest_column(alpha, x) for x in cuts]
    frames = []
    for x0, x1 in zip(xs, xs[1:]):
        f = strip.crop((x0, 0, x1, strip.height))
        frames.append(f.crop(f.getbbox()))
    return frames


def make_anims(concept_dir, out_dir):
    sheets = {}
    for name, (sheet, band, cuts, keep, height) in ANIMS.items():
        if sheet not in sheets:
            sheets[sheet] = key_out(Image.open(os.path.join(concept_dir, "fx", sheet)))
        frames = cut_frames(sheets[sheet], band, cuts)
        if keep:
            frames = [frames[k - 1] for k in keep]
        scale = height / max(f.height for f in frames)
        for i, f in enumerate(frames, start=1):
            sprite = pixelate_down(f, scale)
            if name in GRAY:
                sprite = desaturate(sprite)
            out = name if len(frames) == 1 else "%s_%d" % (name, i)
            sprite.save(os.path.join(out_dir, out + ".png"))
            print(out, sprite.size)


def make_confetti(concept_dir, out_dir):
    """Each confetti piece on its own (they never touch), left to right."""
    sheet, band, xr, height = CONFETTI
    keyed = key_out(Image.open(os.path.join(concept_dir, "fx", sheet)))
    part = keyed.crop((xr[0], band[0], xr[1], band[1]))
    labels, count = ndimage.label(rgba(part)[..., 3] > 0)
    pieces = []
    for sl in ndimage.find_objects(labels):
        ys, xs = sl
        if (ys.stop - ys.start) * (xs.stop - xs.start) >= 300:
            pieces.append((xs.start, part.crop((xs.start, ys.start, xs.stop, ys.stop))))
    pieces.sort(key=lambda p: p[0])
    scale = height / max(p.height for _, p in pieces)
    for i, (_, p) in enumerate(pieces, start=1):
        sprite = pixelate_down(p, scale)
        sprite.save(os.path.join(out_dir, "confetti_%d.png" % i))
        print("confetti_%d" % i, sprite.size)


def make_speed_lines(concept_dir, out_dir):
    """The three speed-line panels, each stretched to fill the screen."""
    sheet, band, cuts = SPEED
    keyed = key_out(Image.open(os.path.join(concept_dir, "fx", sheet)))
    for i, f in enumerate(cut_frames(keyed, band, cuts), start=1):
        sprite = hard_alpha(f.convert("RGBA").resize(SCREEN, Image.BOX), 140)
        sprite.save(os.path.join(out_dir, "speed_%d.png" % i))
        print("speed_%d" % i, sprite.size)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    out_dir = os.path.join(project_dir, "assets", "sprites", "fx")
    os.makedirs(out_dir, exist_ok=True)
    make_anims(concept_dir, out_dir)
    make_confetti(concept_dir, out_dir)
    make_speed_lines(concept_dir, out_dir)


if __name__ == "__main__":
    main()
