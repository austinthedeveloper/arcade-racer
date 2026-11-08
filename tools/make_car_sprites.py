#!/usr/bin/env python3
"""Build in-game car sprites from the concept sheets.

- Player cars: the seven steering frames, all at one scale, on equal cells in one strip.
  The nose-down (downhill) and nose-up (uphill) sheets, when they exist, become strips laid
  out the same way. Those sheets may hold 7, 3 (left, straight, right) or 1 (straight) frames;
  fewer frames are repeated across the seven steering cells. Only the Vega has pitched
  sheets so far; the rest of the garage (GARAGE) gets a level strip each. A car in RENDERED
  has strips from its 3D model instead (tools/make_car_renders.py), which this leaves alone.
- Traffic: rear views from the traffic sheets, one keyed sprite each; front views (oncoming,
  RC-11) for the vehicles that have them, at the rear view's width; and light states (CP-6):
  the TRF-10 sheet's brake and signal frames for the beige sedan, and signal frames for the
  other everyday cars made by lighting their own taillights amber on one side.

These stand in until the cars get a proper sprite pipeline.

Usage:
    python3 tools/make_car_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageOps

import manifest
from spritelib import cli_args, hue, key_sheet, pixelate_down, recolor_hue, rgba, slice_row, sprite_dir

PLAYER_BODY_WIDTH = 180  # straight-ahead frame, in texture pixels (about its on-screen width)
TRAFFIC_CAR_WIDTH = 150  # widest vehicle on each sheet
TRAFFIC_BIG_WIDTH = 170
# World units per texture pixel, per sheet: each concept sheet was drawn at its own scale.
CAR_SCALE = 7.0
BIG_SCALE = 8.2
# Pixels of magenta-ish fringe keyed off around the background (spritelib.key_sheet). Traffic
# sheets have wide ones: a shadowed magenta line along the ground, glow around beacons. The
# player cars keep one pixel, since the Zenith's purple paint would go too.
PLAYER_FRINGE = 1
TRAFFIC_FRINGE = 16
# Pixels of the vehicle next to the background that get despilled (spritelib.despill). The
# beacon glow on the traffic sheets reaches further in than the player cars' outline spill.
PLAYER_DESPILL = 3
TRAFFIC_DESPILL = 8

TRAFFIC = [
    ("trf01_cars_A_v1.png", TRAFFIC_CAR_WIDTH, CAR_SCALE, ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow"]),
    ("trf03_big_A_v1.png", TRAFFIC_BIG_WIDTH, BIG_SCALE, ["semi", "bus", "box_truck", "rv", "carrier"]),
    ("trf04_stage_specials_A_v1.png", TRAFFIC_CAR_WIDTH, CAR_SCALE, [
        "surf_van", "trolley", "log_truck", "tractor", "airboat_trailer", "taxi"]),
    ("trf06_cars_more_A_v1.png", TRAFFIC_CAR_WIDTH, CAR_SCALE, [
        "pickup_red", "suv_green", "muscle_white", "van_navy", "tuk_tuk", "hatch_purple"]),
    ("trf08_service_A_v1.png", TRAFFIC_BIG_WIDTH, BIG_SCALE, [
        "tow_truck", "cement_mixer", "tanker", "garbage_truck", "street_sweeper", "ice_cream_truck"]),
    # The green combine on the specials sheet was rerolled as its own sheet (v2)
    ("trf09_stage_specials_2_A_v1.png", TRAFFIC_CAR_WIDTH, CAR_SCALE, [
        "golf_cart", "jeep_red", "limo_white", "dump_truck", "boat_trailer", None, "news_truck",
        "double_decker"]),
    ("trf09_combine_A_v2.png", 220, BIG_SCALE, ["combine"]),
]
# Front views (CP-6): (sheet, the rear views they match, left to right). Each is scaled to its
# rear view's width, so it shares that vehicle's world_per_px and collision width.
FRONTS = [
    ("trf02_cars_front_A_v1.png", ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow"]),
    ("trf05_big_front_A_v1.png", ["semi", "bus", "box_truck", "rv", "carrier"]),
    ("trf07_cars_more_front_A_v1.png", ["pickup_red", "suv_green", "muscle_white", "van_navy", "tuk_tuk", "hatch_purple"]),
]
# Sheet columns painted background before slicing, where two vehicles' mirrors touch
CUTS = {"trf05_big_front_A_v1.png": [692], "trf07_cars_more_front_A_v1.png": [331]}
# The front sheets' windscreens reflect the magenta background too (as GLASS)
FRONT_GLASS = {
    "compact_teal": (0.15, 0.05, 0.85, 0.35),
    "sedan_beige": (0.12, 0.05, 0.88, 0.35),
    "wagon_blue": (0.12, 0.08, 0.88, 0.38),
    "van_red": (0.12, 0.05, 0.88, 0.36),
    "mini_white": (0.15, 0.05, 0.85, 0.35),
    "roadster_yellow": (0.12, 0.02, 0.88, 0.30),
    "pickup_red": (0.18, 0.05, 0.82, 0.35),
    "suv_green": (0.18, 0.12, 0.82, 0.42),
    "muscle_white": (0.18, 0.05, 0.82, 0.32),
    "van_navy": (0.15, 0.10, 0.85, 0.38),
    "tuk_tuk": (0.15, 0.10, 0.85, 0.42),
    "hatch_purple": (0.15, 0.20, 0.85, 0.48),
}
# Light states: the TRF-10 sheet is one car, a tan sedan of its own (not TRF-01's beige one),
# off, braking, signalling left and right. The "off" frame is its rear view.
LIGHT_SHEET = ("trf10_light_states_A_v1.png", "sedan_tan", 137, ["brake", "left", "right"])
# Cars that signal before changing lanes (Traffic.CHANGERS) and have no drawn signal frames get
# them from their own rear view: the taillight pixels (red to orange, bright and saturated, in
# the lower part of the outer thirds) on one side turn amber.
SIGNALLERS = ["compact_teal", "wagon_blue", "van_red", "mini_white", "roadster_yellow",
    "pickup_red", "suv_green", "muscle_white", "van_navy", "hatch_purple"]
TAIL_HUES = ((340.0, 360.0), (0.0, 30.0))
TAIL_MIN_CHROMA = 90
TAIL_MIN_VALUE = 120
TAIL_ROWS = (0.3, 0.85)  # fractions of the height, from the top
TAIL_SIDE = 0.4  # fraction of the width from each edge
# Where a red or yellow body would pass for a taillight: the left lamp's box (fractions of the
# sprite; the right one is its mirror), and only bright, strongly colored pixels in it
TAIL_BOX = {
    "van_red": (0.04, 0.45, 0.22, 0.58),
    "pickup_red": (0.0, 0.3, 0.12, 0.68),
    "roadster_yellow": (0.03, 0.38, 0.25, 0.56),
}
TAIL_BOX_CHROMA = 140
TAIL_BOX_VALUE = 200
AMBER = (255, 184, 40)

# The generator reflected the magenta background into the window glass of these vehicles
# (docs/09 A1). The glass is opaque, so keying can't reach it: the purple inside each box
# (fractions of the sprite: left, top, right, bottom) is turned to blue glass instead.
GLASS = {
    "taxi": (0.15, 0.20, 0.87, 0.42),
    "tractor": (0.24, 0.15, 0.78, 0.40),
    "roadster_yellow": (0.15, 0.02, 0.85, 0.28),
    "van_navy": (0.18, 0.15, 0.83, 0.38),
    "suv_green": (0.18, 0.13, 0.83, 0.37),
    "dump_truck": (0.30, 0.33, 0.70, 0.47),
    "trolley": (0.42, 0.13, 0.58, 0.21),  # one streak on the windscreen; the neon trim stays
    "tuk_tuk": (0.25, 0.15, 0.75, 0.33),  # not in docs/09's list, same fault
}
GLASS_HUES = (240, 340)  # violet through magenta
GLASS_HUE = 212  # the blue of the other vehicles' glass
GLASS_SAT = 0.75


def slice_sheet(path, fringe=PLAYER_FRINGE, spill=PLAYER_DESPILL, cuts=()):
    """Keyed, trimmed sprites left to right. Pixels of other sprites inside a box are cleared.
    Sprites are found on the sheet keyed with a one-pixel fringe and nothing more, so the
    wider fringes can't cut a part (a mirror on a thin stalk) off its vehicle. Each is trimmed
    to its box before the key-hue fringe: that fringe only clears outline pixels, and a
    traffic vehicle's width is its collision width (CarSprites.traffic)."""
    sheet = Image.open(path).convert("RGB")
    for x in cuts:
        sheet.paste(sheet.getpixel((0, 0)), (x, 0, x + 1, sheet.height))
    shape = key_sheet(sheet, PLAYER_FRINGE, hue_fringe=0, spill=0)
    trim = shape if fringe == PLAYER_FRINGE else key_sheet(sheet, fringe, hue_fringe=0, spill=0)
    return slice_row(key_sheet(sheet, fringe, spill=spill), shape, trim)


# (concept sheet, output strip, required, tallest cell as a multiple of the level strip's)
PLAYER_SHEETS = [
    ("car_vega_steer_sheet_A_v2.png", "vega_steer.png", True, None),
    ("car_vega_steer_down_sheet_A_v1.png", "vega_steer_down.png", False, 1.15),
    # The generated uphill sheet looks down from far steeper than the game's pitch, so its
    # car is twice as tall as the level one; it is squashed so the switch doesn't pop.
    ("car_vega_steer_up_sheet_A_v1.png", "vega_steer_up.png", False, 1.35),
]
# The rest of the garage: level strips only; the game fakes their pitch (CarSprites.pitch_warp).
# (car, steering sheet) -> assets/sprites/cars/<car>_steer.png
GARAGE = [
    ("bruiser", "car_bruiser_steer_sheet_A_v2.png"),
    ("kestrel", "car_kestrel_steer_sheet_A_v2.png"),
    ("sol", "car_sol_steer_sheet_A_v2.png"),
    ("mesa", "car_mesa_steer_sheet_A_v2.png"),
    ("phantom", "car_phantom_steer_sheet_A_v2.png"),
    ("hauler", "car_hauler_steer_sheet_A_v1.png"),
    ("zenith", "car_zenith_steer_sheet_A_v1.png"),
    ("tempest", "car_tempest_steer_sheet_A_v1.png"),
    ("skipper", "car_skipper_steer_sheet_A_v1.png"),
    ("halo", "car_halo_steer_sheet_A_v1.png"),
    ("cyclone", "car_cyclone_steer_sheet_A_v2.png"),
]
# Cars whose strips in the game are rendered from a 3D model, not cut from their sheet. Take one
# out of here and rerun to go back to its sheet, and delete its _steer_up and _steer_down.
RENDERED = {"bruiser", "cyclone", "halo", "hauler", "kestrel", "mesa", "phantom", "skipper", "sol", "tempest", "vega", "zenith"}
# Which sheet frame fills each of the seven steering cells, by frame count
STEER_CELLS = {7: [0, 1, 2, 3, 4, 5, 6], 3: [0, 0, 1, 1, 1, 2, 2], 1: [0] * 7}
# Sheets whose right-hand frames were drawn showing the left flank again: their right turns
# are the left ones mirrored (sheet frames 2, 1, 0) instead.
MIRROR_RIGHT = {"car_bruiser_steer_sheet_A_v2.png"}
# The Bruiser sheet draws its blower off to the car's left, so a mirrored right turn would
# swap it over. Per sheet frame: the polygon cleared off the frame (the blower, left of the
# roof pillar and above the mirror) and the box of its intake, which goes back centered on
# the roof (shifted so the straight frame's is in the middle) and behind it.
BLOWERS = {
    "car_bruiser_steer_sheet_A_v2.png": {
        0: ([(30, 0), (100, 0), (100, 10), (84, 12), (79, 25), (75, 45), (30, 45)], (38, 0, 83, 17)),
        1: ([(25, 0), (95, 0), (95, 13), (78, 14), (66, 18), (68, 30), (68, 48), (25, 48)], (33, 0, 82, 19)),
        2: ([(30, 0), (95, 0), (95, 12), (80, 13), (66, 18), (61, 25), (60, 48), (30, 48)], (36, 0, 84, 19)),
        3: ([(30, 0), (95, 0), (95, 12), (82, 13), (70, 21), (64, 32), (57, 47), (30, 47)], (42, 0, 93, 19)),
    },
}


def center_blower(frames, spec):
    """Each frame in `spec` with its blower cleared and its intake put back over the middle
    of the roof, behind the body."""
    x0, _, x1, _ = spec[len(frames) // 2][1]
    shift = round(frames[len(frames) // 2].width / 2 - (x0 + x1) / 2)
    out = list(frames)
    for i, (poly, box) in spec.items():
        scoop = np.array(frames[i].crop(box))
        clear = Image.new("L", frames[i].size, 0)
        ImageDraw.Draw(clear).polygon(poly, fill=255)
        a = rgba(frames[i])
        a[np.array(clear) > 0] = 0
        behind = a[box[1]:box[3], box[0] + shift:box[2] + shift]
        empty = behind[..., 3] == 0
        behind[empty] = scoop[empty]
        out[i] = Image.fromarray(a)
    return out


def make_player(sheet_path, out_path, level_h=None, max_ratio=None):
    frames = slice_sheet(sheet_path)
    if len(frames) not in STEER_CELLS:
        sys.exit("%s: expected 7, 3 or 1 frames, found %d" % (sheet_path, len(frames)))
    name = os.path.basename(sheet_path)
    if name in BLOWERS:
        frames = center_blower(frames, BLOWERS[name])
    if name in MIRROR_RIGHT:
        frames = frames[:len(frames) // 2 + 1] + [ImageOps.mirror(f) for f in reversed(frames[:len(frames) // 2])]
    # Sheets run hard left .. straight .. hard right: steering left shows the left flank.
    # Every strip is scaled so its straight frame is the same width.
    scale = PLAYER_BODY_WIDTH / frames[len(frames) // 2].width
    frames = [pixelate_down(f, scale) for f in frames]
    frames = [frames[i] for i in STEER_CELLS[len(frames)]]
    if level_h and max_ratio and max(f.height for f in frames) > level_h * max_ratio:
        squash = level_h * max_ratio / max(f.height for f in frames)
        frames = [f.resize((f.width, max(1, round(f.height * squash))), Image.NEAREST) for f in frames]
    return save_strip(frames, out_path)


def save_strip(frames, out_path):
    """The seven steering frames on equal cells in one strip, as CarSprites reads it.
    Returns the cell height."""
    cell_w = max(f.width for f in frames)
    cell_h = max(f.height for f in frames)
    strip = Image.new("RGBA", (cell_w * 7, cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        # Bottom-aligned and centered in the cell
        strip.paste(f, (i * cell_w + (cell_w - f.width) // 2, cell_h - f.height))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    strip.save(out_path)
    print("player", os.path.basename(out_path), strip.size, "cell", cell_w, cell_h)
    return cell_h


def make_traffic(concept_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for sheet, width, _, names in TRAFFIC:
        crops = slice_sheet(os.path.join(concept_dir, "traffic", sheet), TRAFFIC_FRINGE, TRAFFIC_DESPILL)
        if len(crops) != len(names):
            print("warning: %s has %d sprites, expected %d" % (sheet, len(crops), len(names)))
        # One scale per sheet keeps the vehicles' sizes relative to each other
        scale = width / max(c.width for c in crops)
        for name, crop in zip(names, crops):
            if name is None:
                continue
            if name in GLASS:
                crop = recolor_hue(crop, GLASS[name], GLASS_HUES, GLASS_HUE, GLASS_SAT)
            sprite = pixelate_down(crop, scale)
            sprite.save(os.path.join(out_dir, name + ".png"))
            print("traffic", name, sprite.size)


def make_fronts(concept_dir, out_dir):
    os.makedirs(os.path.join(out_dir, "front"), exist_ok=True)
    for sheet, names in FRONTS:
        crops = slice_sheet(os.path.join(concept_dir, "traffic", sheet), TRAFFIC_FRINGE, TRAFFIC_DESPILL,
            CUTS.get(sheet, ()))
        if len(crops) != len(names):
            sys.exit("%s: expected %d vehicles, found %d" % (sheet, len(names), len(crops)))
        for name, crop in zip(names, crops):
            if name in FRONT_GLASS:
                crop = recolor_hue(crop, FRONT_GLASS[name], GLASS_HUES, GLASS_HUE, GLASS_SAT)
            rear = Image.open(os.path.join(out_dir, name + ".png"))
            sprite = pixelate_down(crop, rear.width / crop.width)
            sprite.save(os.path.join(out_dir, "front", name + ".png"))
            print("front", name, sprite.size)


def make_lights(concept_dir, out_dir):
    os.makedirs(os.path.join(out_dir, "lights"), exist_ok=True)
    sheet, name, width, states = LIGHT_SHEET
    crops = slice_sheet(os.path.join(concept_dir, "traffic", sheet), TRAFFIC_FRINGE, TRAFFIC_DESPILL)
    if len(crops) != len(states) + 1:
        sys.exit("%s: expected %d frames, found %d" % (sheet, len(states) + 1, len(crops)))
    scale = width / crops[0].width
    pixelate_down(crops[0], scale).save(os.path.join(out_dir, name + ".png"))
    for state, crop in zip(states, crops[1:]):
        sprite = pixelate_down(crop, scale)
        sprite.save(os.path.join(out_dir, "lights", "%s_%s.png" % (name, state)))
        print("lights", name, state, sprite.size)
    for name in SIGNALLERS:
        rear = Image.open(os.path.join(out_dir, name + ".png"))
        for side in ("left", "right"):
            lit = signal_frame(rear, side, name)
            if lit is None:
                sys.exit("%s: no taillights found on the %s" % (name, side))
            lit.save(os.path.join(out_dir, "lights", "%s_%s.png" % (name, side)))
        print("lights", name, "left right")


def taillights(img, side, name=""):
    """Mask of the taillight pixels on one side ("left" or "right") of the rear view of
    vehicle `name`."""
    a = rgba(img)
    h, w = a.shape[:2]
    hh, c = hue(a)
    v = a[..., :3].max(axis=-1)
    red = np.zeros(hh.shape, bool)
    for lo, hi in TAIL_HUES:
        red |= (hh >= lo) & (hh <= hi)
    mask = red & (c >= TAIL_MIN_CHROMA) & (v >= TAIL_MIN_VALUE) & (a[..., 3] > 0)
    if name in TAIL_BOX:
        x0, y0, x1, y1 = TAIL_BOX[name]
        if side == "right":
            x0, x1 = 1.0 - x1, 1.0 - x0
        box = np.zeros(mask.shape, bool)
        box[round(y0 * h):round(y1 * h), round(x0 * w):round(x1 * w)] = True
        return mask & box & (c >= TAIL_BOX_CHROMA) & (v >= TAIL_BOX_VALUE)
    rows = np.zeros(mask.shape, bool)
    rows[round(TAIL_ROWS[0] * h):round(TAIL_ROWS[1] * h)] = True
    cols = np.zeros(mask.shape, bool)
    if side == "left":
        cols[:, :round(TAIL_SIDE * w)] = True
    else:
        cols[:, w - round(TAIL_SIDE * w):] = True
    return mask & rows & cols


def signal_frame(img, side, name=""):
    """The rear view with its taillights on `side` lit amber, or None if it has none there."""
    mask = taillights(img, side, name)
    if mask.sum() < 3:
        return None
    a = rgba(img)
    v = a[..., :3].max(axis=-1).astype(np.float64) / 255.0
    lit = np.array(AMBER, np.float64)[None, :] * np.clip(0.55 + 0.6 * v[mask], 0.0, 1.0)[:, None]
    a[mask, :3] = np.clip(np.round(lit), 0, 255).astype(np.uint8)
    return Image.fromarray(a)


def main():
    concept_dir, project_dir = cli_args(__doc__, 2)
    sprites = sprite_dir(project_dir)
    level_h = None
    for sheet, strip, required, max_ratio in PLAYER_SHEETS:
        path = os.path.join(concept_dir, "cars", sheet)
        if required or os.path.exists(path):
            h = make_player(path, os.path.join(sprites, "cars", strip), level_h, max_ratio)
            level_h = level_h or h
    for car, sheet in GARAGE:
        if car in RENDERED:
            continue
        make_player(os.path.join(concept_dir, "cars", sheet), os.path.join(sprites, "cars", car + "_steer.png"))
    make_traffic(concept_dir, os.path.join(sprites, "traffic"))
    make_fronts(concept_dir, os.path.join(sprites, "traffic"))
    make_lights(concept_dir, os.path.join(sprites, "traffic"))
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
