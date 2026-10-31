#!/usr/bin/env python3
"""Build the road-spanning sprites (tunnels, bridges, arches, race gates) from their
concept images (assets/prompts/roadside/drive-through.md and shared.md).

Each concept image holds one piece, straight-on, with the opening the road runs through
keyed out. The game finds the opening itself (SpriteLibrary.find_opening), so this only
keys, crops and scales.

A span with a "facade" gets building faces drawn either side of it (draw_facade), so a
tunnel mouth reads as a hole in a street of buildings rather than a free-standing gate.
Only the original piece collides: the manifest's "solid" is where it sits in the wider
sprite.

Usage:
    python3 tools/make_span_sprites.py <concept_dir> <project_dir>
"""
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import manifest
from spritelib import key_out, pixelate_down

WIDTH = 640  # texture width; a span fills the screen when the car is under it

# Building faces either side of the Neon Strip tunnel mouth: each side's width and how far
# the buildings rise above the mouth, in texture pixels (the mouth itself is WIDTH wide)
NEON_FACADE = {"side": 560, "rise": 178, "seed": 31}

# output id: (concept file in roadside/, how the game draws it). The game reads the second
# part from the manifest (tools/manifest.py): "fill" is the color beside the span (and above
# it, for a "ceiling" like a tunnel ring); "banner" is where gate text goes, as fractions of
# the sprite (x, y, w, h); "facade" adds building faces (see solid_part).
SPANS = {
    "neon_tunnel": ("dt_neon_tunnel_entrance_A_v1.png", {"fill": "#140b26", "facade": NEON_FACADE}),
    "neon_tunnel_exit": ("dt_neon_tunnel_entrance_A_v1.png", {"fill": "#140b26"}),
    "neon_tunnel_ring": ("dt_neon_tunnel_ring_A_v1.png", {"fill": "#140b26", "ceiling": True}),
    "neon_gantry": ("dt_neon_gantry_A_v1.png", {}),
    "covered_bridge": ("dt_timber_bridge_entrance_A_v1.png", {}),
    "covered_bridge_truss": ("dt_timber_bridge_truss_A_v1.png", {"fill": "#2a1a10", "ceiling": True}),
    "redrock_arch": ("dt_redrock_arch_A_v1.png", {}),
    "bayou_truss": ("dt_bayou_truss_A_v1.png", {}),
    "harvest_trestle": ("dt_harvest_trestle_A_v1.png", {}),
    "thunder_overpass": ("dt_thunder_overpass_A_v1.png", {}),
    "skyline_pylon": ("dt_skyline_pylon_A_v2.png", {}),
    "palm_arch": ("dt_palm_arch_A_v1.png", {}),
    "checkpoint_gate": ("shared_checkpoint_gate_A_v1.png", {"banner": [0.2, 0.09, 0.6, 0.2]}),
    "start_gantry": ("shared_start_gantry_A_v1.png", {"banner": [0.27, 0.33, 0.46, 0.13]}),
    "finish_gantry": ("skyline_finish_A_v1.png", {}),
}


def solid_part(look):
    """The (left, right) fractions of a faced span's sprite that collide: the original piece,
    WIDTH wide, between its two building faces. None for a span without a facade (all of
    it collides)."""
    facade = look.get("facade")
    if facade is None:
        return None
    total = WIDTH + 2 * facade["side"]
    return [facade["side"] / total, (facade["side"] + WIDTH) / total]


def make_span(path):
    keyed = key_out(Image.open(path))
    keyed = keyed.crop(keyed.getbbox())
    sprite = pixelate_down(keyed, WIDTH / keyed.width)
    return sprite.crop(sprite.getbbox())


def opening(sprite):
    """The road opening's (left, right) pixel columns, read the way the game reads it
    (SpriteLibrary.find_opening): the transparent run through the middle of the row 90% down."""
    a = np.array(sprite)[..., 3]
    y = int(a.shape[0] * 0.9)
    left = right = a.shape[1] // 2
    while left > 0 and a[y, left - 1] < 128:
        left -= 1
    while right < a.shape[1] - 1 and a[y, right + 1] < 128:
        right += 1
    return left, right + 1


def fill_holes(sprite, color):
    """Transparent pixels the piece encloses (keying ate pink paint) painted `color`, so the
    buildings behind don't show through; the opening and the outside stay clear."""
    a = np.array(sprite)
    clear = a[..., 3] < 128
    labels, _ = ndimage.label(clear)
    edge = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    holes = clear & ~np.isin(labels, list(edge))
    a[holes] = color + (255,)
    return Image.fromarray(a)


# Facade palette, picked from the tunnel mouth and the stage theme
OUTLINE = (12, 6, 24)
BODY = (36, 24, 69)
BODY_DARK = (26, 16, 51)
PANEL = (48, 33, 88)
PINK = (255, 63, 180)
PINK_CORE = (255, 190, 235)
CYAN = (47, 224, 255)
CYAN_CORE = (200, 250, 255)
BULB = (255, 200, 80)
BULB_CORE = (255, 245, 200)
WINDOWS = [((255, 186, 84), 34), ((255, 226, 150), 10), ((214, 92, 200), 8), ((72, 46, 112), 30),
           ((44, 28, 74), 18)]


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _tube(d, x0, y0, x1, y1, color, core):
    """A neon tube: a dim glow, the colored tube and a bright core, along a horizontal or
    vertical run (x0..x1, y0..y1 inclusive)."""
    d.rectangle((x0 - 2, y0 - 2, x1 + 2, y1 + 2), fill=_mix(BODY, color, 0.35))
    d.rectangle((x0, y0, x1, y1), fill=color)
    if x1 - x0 > y1 - y0:
        cy = (y0 + y1) // 2
        d.line((x0 + 1, cy, x1 - 1, cy), fill=core)
    else:
        cx = (x0 + x1) // 2
        d.line((cx, y0 + 1, cx, y1 - 1), fill=core)


def _windows(d, rng, x0, y0, x1, y1, w=10, h=12, gap_x=6, gap_y=8):
    for y in range(y0, y1 - h, h + gap_y):
        for x in range(x0, x1 - w, w + gap_x):
            color = rng.choices([c for c, _ in WINDOWS], [n for _, n in WINDOWS])[0]
            d.rectangle((x, y, x + w - 1, y + h - 1), fill=color)
            d.line((x, y + h, x + w - 1, y + h), fill=BODY_DARK)
            if color[0] > 200:
                d.line((x, y, x + w - 1, y), fill=_mix(color, (255, 255, 255), 0.4))


def _marquee(d, x0, x1, y):
    """A row of bulbs on a dark band, like the tunnel mouth's, with a cyan tube under it."""
    d.rectangle((x0, y, x1, y + 13), fill=(58, 30, 82), outline=OUTLINE)
    for x in range(x0 + 5, x1 - 4, 10):
        d.rectangle((x - 2, y + 4, x + 2, y + 8), fill=BULB)
        d.point((x, y + 6), fill=BULB_CORE)
    _tube(d, x0 + 2, y + 17, x1 - 2, y + 19, CYAN, CYAN_CORE)


def _block(d, rng, x0, y0, x1, y1):
    """One building: a paneled face, a grid of windows, a storefront at street level."""
    d.rectangle((x0, y0, x1, y1), fill=BODY, outline=OUTLINE)
    for x in range(x0 + 16, x1, 32):
        d.line((x, y0 + 1, x, y1 - 1), fill=PANEL)
    _windows(d, rng, x0 + 14, y0 + 30, x1 - 10, y1 - 70)
    # Storefront: lit glass behind mullions, under a cyan awning
    top = y1 - 58
    for y in range(top, y1 - 6):
        d.line((x0 + 4, y, x1 - 4, y), fill=_mix((255, 150, 60), (255, 214, 120), (y - top) / 52))
    for x in range(x0 + 4, x1 - 3, 14):
        d.line((x, top, x, y1 - 6), fill=(90, 44, 40))
    _tube(d, x0 + 2, top - 4, x1 - 2, top - 2, CYAN, CYAN_CORE)
    d.rectangle((x0 + 1, y1 - 6, x1 - 1, y1), fill=BODY_DARK)


def draw_facade(side, height, seed):
    """The left building faces, `side` wide and `height` tall, bottom on the road; the right
    ones are its mirror. The inner edge runs under the tunnel mouth's leg."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (side, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bottom = height - 1
    # Outer tower, full height, with a setback crown and neon down both edges
    tower = round(side * 0.55)
    d.rectangle((24, 0, tower - 24, 40), fill=BODY_DARK, outline=OUTLINE)
    _tube(d, 30, 8, tower - 30, 10, PINK, PINK_CORE)
    _block(d, rng, 0, 34, tower, bottom)
    _tube(d, 6, 46, 9, bottom - 70, PINK, PINK_CORE)
    _tube(d, tower - 9, 46, tower - 6, bottom - 70, CYAN, CYAN_CORE)
    # Lower block against the tunnel mouth, its roofline under the mouth's crown
    low = round(height * 0.4)
    _block(d, rng, tower - 4, low, side - 1, bottom)
    _marquee(d, tower - 4, side - 1, low - 14)
    # A blade sign on the lower block: bulbs around stacked diamonds
    bx = tower + 30
    d.rectangle((bx, low + 20, bx + 27, low + 150), fill=(40, 18, 60), outline=PINK)
    for y in range(low + 34, low + 140, 26):
        d.polygon([(bx + 13, y - 9), (bx + 22, y), (bx + 13, y + 9), (bx + 4, y)], fill=PINK, outline=PINK_CORE)
    for y in range(low + 24, low + 148, 8):
        d.point((bx + 2, y), fill=BULB)
        d.point((bx + 25, y), fill=BULB)
    return img


def add_facade(sprite, facade):
    """The sprite between two building faces, bottom-aligned, on a wider canvas. The faces
    stop at the road opening so it stays clear for the game to find."""
    assert sprite.width == WIDTH, sprite.size
    side, rise = facade["side"], facade["rise"]
    left, right = opening(sprite)
    height = sprite.height + rise
    out = Image.new("RGBA", (WIDTH + 2 * side, height), (0, 0, 0, 0))
    face = draw_facade(side + left, height, facade["seed"])
    out.paste(face, (0, 0))
    out.paste(face.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (side + right, 0))
    out.alpha_composite(fill_holes(sprite, (20, 11, 38)), (side, rise))
    assert opening(out) == (side + left, side + right), "the facade moved the opening"
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    out_dir = os.path.join(project_dir, "assets", "sprites", "spans")
    os.makedirs(out_dir, exist_ok=True)
    for name, (src, look) in SPANS.items():
        sprite = make_span(os.path.join(concept_dir, "roadside", src))
        if "facade" in look:
            sprite = add_facade(sprite, look["facade"])
        sprite.save(os.path.join(out_dir, name + ".png"))
        print("span", name, sprite.size)
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
