#!/usr/bin/env python3
"""Build in-game car sprites from the concept sheets.

- Player car: the seven Vega steering frames, all at one scale, on equal cells in one strip.
  The nose-down (downhill) and nose-up (uphill) sheets, when they exist, become strips laid
  out the same way. Those sheets may hold 7, 3 (left, straight, right) or 1 (straight) frames;
  fewer frames are repeated across the seven steering cells.
- Traffic: rear views from the traffic sheets, one keyed sprite each.

These stand in until the cars get a proper sprite pipeline.

Usage:
    python3 tools/make_car_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

from PIL import Image

from make_placeholder_sprites import components, key_out, pixelate_down

PLAYER_BODY_WIDTH = 180  # straight-ahead frame, in texture pixels (about its on-screen width)
TRAFFIC_CAR_WIDTH = 150  # widest vehicle on each sheet
TRAFFIC_BIG_WIDTH = 170

TRAFFIC = [
    ("trf01_cars_A_v1.png", TRAFFIC_CAR_WIDTH, ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow"]),
    ("trf03_big_A_v1.png", TRAFFIC_BIG_WIDTH, ["semi", "bus", "box_truck", "rv", "carrier"]),
    ("trf04_stage_specials_A_v1.png", TRAFFIC_CAR_WIDTH, ["surf_van", None, None, None, None, "taxi"]),
]


def slice_sheet(path):
    """Keyed, trimmed sprites left to right. Pixels of other sprites inside a box are cleared."""
    keyed = key_out(Image.open(path))
    boxes, label, step = components(keyed)
    crops = []
    for box, comp in boxes:
        part = keyed.crop(box)
        px = part.load()
        for y in range(part.height):
            for x in range(part.width):
                ly, lx = (box[1] + y) // step, (box[0] + x) // step
                if ly >= len(label) or lx >= len(label[0]) or label[ly][lx] != comp:
                    px[x, y] = (0, 0, 0, 0)
        crops.append(part.crop(part.getbbox()))
    return crops


# (concept sheet, output strip, required, tallest cell as a multiple of the level strip's)
PLAYER_SHEETS = [
    ("car_vega_steer_sheet_A_v2.png", "vega_steer.png", True, None),
    ("car_vega_steer_down_sheet_A_v1.png", "vega_steer_down.png", False, 1.15),
    # The generated uphill sheet looks down from far steeper than the game's pitch, so its
    # car is twice as tall as the level one; it is squashed so the switch doesn't pop.
    ("car_vega_steer_up_sheet_A_v1.png", "vega_steer_up.png", False, 1.35),
]
# Which sheet frame fills each of the seven steering cells, by frame count
STEER_CELLS = {7: [0, 1, 2, 3, 4, 5, 6], 3: [0, 0, 1, 1, 1, 2, 2], 1: [0] * 7}


def make_player(sheet_path, out_path, level_h=None, max_ratio=None):
    frames = slice_sheet(sheet_path)
    if len(frames) not in STEER_CELLS:
        sys.exit("%s: expected 7, 3 or 1 frames, found %d" % (sheet_path, len(frames)))
    # Sheets run hard left .. straight .. hard right: steering left shows the left flank.
    # Every strip is scaled so its straight frame is the same width.
    scale = PLAYER_BODY_WIDTH / frames[len(frames) // 2].width
    frames = [pixelate_down(f, scale) for f in frames]
    frames = [frames[i] for i in STEER_CELLS[len(frames)]]
    if level_h and max_ratio and max(f.height for f in frames) > level_h * max_ratio:
        squash = level_h * max_ratio / max(f.height for f in frames)
        frames = [f.resize((f.width, max(1, round(f.height * squash))), Image.NEAREST) for f in frames]
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
    for sheet, width, names in TRAFFIC:
        crops = slice_sheet(os.path.join(concept_dir, "traffic", sheet))
        if len(crops) != len(names):
            print("warning: %s has %d sprites, expected %d" % (sheet, len(crops), len(names)))
        # One scale per sheet keeps the vehicles' sizes relative to each other
        scale = width / max(c.width for c in crops)
        for name, crop in zip(names, crops):
            if name is None:
                continue
            sprite = pixelate_down(crop, scale)
            sprite.save(os.path.join(out_dir, name + ".png"))
            print("traffic", name, sprite.size)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    sprites = os.path.join(project_dir, "assets", "sprites")
    level_h = None
    for sheet, strip, required, max_ratio in PLAYER_SHEETS:
        path = os.path.join(concept_dir, "cars", sheet)
        if required or os.path.exists(path):
            h = make_player(path, os.path.join(sprites, "cars", strip), level_h, max_ratio)
            level_h = level_h or h
    make_traffic(concept_dir, os.path.join(sprites, "traffic"))


if __name__ == "__main__":
    main()
