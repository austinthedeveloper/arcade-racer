#!/usr/bin/env python3
"""Build a stage's game sprites from its concept sheets.

- Slices each roadside concept sheet (a row of objects on magenta) into keyed sprites,
  one per object, scaled down so the sheet's tallest object is a fixed texture height.
- Turns the stage's background composite into a seamless parallax strip.

Stages are described in STAGES below. Palm Coast still comes from
make_placeholder_sprites.py (its props are hand-drawn stand-ins).

Usage:
    python3 tools/make_stage_sprites.py <concept_dir> <project_dir> [stage ...]
"""
import os
import sys

from PIL import Image

from make_placeholder_sprites import key_out, pixelate_down

# Per stage: background (composite file, horizon row in it) and roadside sheets.
# Each sheet lists its objects in reading order (rows top to bottom, left to right) and the
# texture height of its tallest object. None skips an object (art the renderer can't use yet,
# such as a tunnel mouth or a covered bridge the road would run through).
STAGES = {
    "redrock": {
        "background": ("redrock_composite_A_v1.png", 636),
        "sheets": [
            ("redrock_cactus_A_v1.png", 160, [
                "saguaro_a", "saguaro_b", "saguaro_c", "prickly_pear_a", "prickly_pear_b",
                "tumbleweed_a", "tumbleweed_b"]),
            ("redrock_rocks_A_v1.png", 200, ["boulders_a", "boulders_b", "rock_pillar", "rock_arch"]),
            ("redrock_buildings_A_v1.png", 180, ["diner", "gas_station", "windmill"]),
            ("redrock_props_A_v1.png", 110, ["fence", "skull_post", "road_sign"]),
        ],
    },
    "neon": {
        "background": ("neon_composite_A_v1.png", 676),
        "sheets": [
            ("neon_buildings_A_v1.png", 200, [
                "casino_spire", "casino_lotus", "casino_round", "casino_star", "casino_wave",
                "casino_crown"]),
            ("neon_billboards_A_v1.png", 170, [
                "billboard_sunset", "sign_chevron", "sign_starburst", "sign_lights", "billboard_wide",
                "sign_stack"]),
            ("neon_neon-signs_A_v1.png", 150, [
                "neon_arrow", "neon_star", "neon_cocktail", "neon_chevrons", "neon_card", "neon_stars",
                "neon_spiral"]),
            ("neon_props_A_v1.png", 150, ["street_lamp_a", "street_lamp_b", "palm_lit", "fountain", None]),
        ],
    },
    "timberline": {
        "background": ("timberline_composite_A_v1.png", 706),
        "sheets": [
            ("timberline_pines_A_v1.png", 170, [
                "pine_a", "pine_b", "pine_c", "pine_d", "pine_e", "pine_f", "fallen_log"]),
            ("timberline_buildings_A_v1.png", 150, ["cabin", "lodge", None]),
            ("timberline_landmarks_A_v1.png", 220, ["waterfall", "lookout_tower"]),
            ("timberline_props_A_v1.png", 160, ["snowbank", "guardrail", "chevron_sign", "snow_cliff"]),
        ],
    },
    "bayou": {
        "background": ("bayou_composite_A_v1.png", 600),
        "sheets": [
            ("bayou_trees_A_v1.png", 220, ["cypress_a", "cypress_b", "cypress_c", None]),
            ("bayou_buildings_A_v1.png", 150, ["stilt_shack", "boat_dock", "bait_shop"]),
            ("bayou_props_A_v1.png", 90, [
                "reeds_a", "reeds_b", "cattails", "reeds_c", "heron", "mist_a", "mist_b", "mist_c"]),
            ("bayou_bridge_A_v1.png", 150, [
                "rail_wood_a", "rail_wood_b", "rail_wood_short", "rail_post", "rail_end",
                None, None, None, None, None, "piling",
                "rail_wood_long", "rail_concrete", "rail_concrete_end"]),
        ],
    },
    "harvest": {
        "background": ("harvest_composite_A_v1.png", 600),
        "sheets": [
            ("harvest_buildings_A_v1.png", 200, ["barn", "silos", "water_tower"]),
            ("harvest_landmarks_A_v1.png", 220, ["farm_windmill", "oak"]),
            ("harvest_plants_A_v1.png", 90, ["sunflowers", "corn", "farm_stand"]),
            ("harvest_props_A_v1.png", 100, ["hay_round", "hay_bale", "scarecrow", "farm_fence"]),
        ],
    },    "thunder": {
        "background": ("thunder_composite_A_v1.png", 630),
        "sheets": [
            ("thunder_buildings_A_v1.png", 160, ["truck_stop", "motel"]),
            ("thunder_hazards_A_v1.png", 110, [
                "jersey_barrier", "cone", "cone_tall", "barricade_post", "sawhorse", "drum",
                "hazard_post", "a_frame"]),
            ("thunder_poles_A_v1.png", 220, [
                "pole_a", "pole_b", "pole_transformer", "pole_c", "pole_tanks", "pole_tall", "pylon"]),
            ("thunder_props_A_v1.png", 110, [
                "tree_windswept", "tree_snapped", "shrub_windswept", "puddle_a", "puddle_b",
                "wrecked_sign"]),
        ],
    },
}


def label_components(img, step=2, min_area=12):
    """Connected opaque regions on a downsampled alpha mask: (label grid, list of boxes)."""
    alpha = img.getchannel("A")
    w, h = img.size[0] // step, img.size[1] // step
    small = alpha.resize((w, h), Image.NEAREST).load()
    label = [[-1] * w for _ in range(h)]
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if label[sy][sx] >= 0 or small[sx, sy] == 0:
                continue
            n = len(boxes)
            stack, area = [(sx, sy)], 0
            label[sy][sx] = n
            x0, y0, x1, y1 = sx, sy, sx, sy
            while stack:
                x, y = stack.pop()
                area += 1
                x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and label[ny][nx] < 0 and small[nx, ny] > 0:
                        label[ny][nx] = n
                        stack.append((nx, ny))
            boxes.append((x0, y0, x1 + 1, y1 + 1, area))
    return label, boxes, step


def overlap(a, b):
    """Area of the intersection of two boxes over the smaller box's area."""
    ix = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    smaller = min((a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1]))
    return ix * iy / max(1, smaller)


def group_objects(boxes, min_area=400):
    """Groups components into objects: big components seed objects, and every other
    component (pebbles, grass tufts, a detached sign) joins the object whose box holds most of it."""
    seeds = [i for i, b in enumerate(boxes) if b[4] >= min_area]
    # Two big components that mostly overlap are one object (a sign above its posts)
    groups = []
    for i in sorted(seeds, key=lambda i: -boxes[i][4]):
        for g in groups:
            if overlap(g["box"], boxes[i]) > 0.5:
                g["members"].append(i)
                g["box"] = union(g["box"], boxes[i])
                break
        else:
            groups.append({"members": [i], "box": boxes[i][:4]})
    for i, b in enumerate(boxes):
        if i in seeds:
            continue
        best = max(groups, key=lambda g: overlap(g["box"], b), default=None)
        if best is not None and overlap(best["box"], b) > 0.5:
            best["members"].append(i)
    _merge_stacked(groups)
    return in_reading_order(groups)


def _merge_stacked(groups, max_gap=12):
    """Joins a part that sits on top of or under another part (a sign on its pole, a
    dome on its tower): one box's columns lie mostly within the other's, with at most a
    small vertical gap between them. Boxes are in label-grid cells (half the sheet's pixels)."""
    merged = True
    while merged:
        merged = False
        for a in groups:
            for b in groups:
                if a is b:
                    continue
                ax0, ay0, ax1, ay1 = a["box"]
                bx0, by0, bx1, by1 = b["box"]
                shared = min(ax1, bx1) - max(ax0, bx0)
                narrower = min(ax1 - ax0, bx1 - bx0)
                gap = max(ay0, by0) - min(ay1, by1)
                if shared > 0.8 * narrower and gap < max_gap:
                    a["members"] += b["members"]
                    a["box"] = union(a["box"], b["box"])
                    groups.remove(b)
                    merged = True
                    break
            if merged:
                break


def in_reading_order(groups):
    """Rows top to bottom (a row is every object overlapping the one above it vertically),
    left to right within a row."""
    rows = []
    for g in sorted(groups, key=lambda g: g["box"][1]):
        if rows and g["box"][1] < rows[-1]["bottom"]:
            rows[-1]["items"].append(g)
            rows[-1]["bottom"] = max(rows[-1]["bottom"], g["box"][3])
        else:
            rows.append({"items": [g], "bottom": g["box"][3]})
    return [g for row in rows for g in sorted(row["items"], key=lambda g: g["box"][0])]


def union(a, b):
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def slice_sheet(path, names, target_height):
    keyed = key_out(Image.open(path))
    label, boxes, step = label_components(keyed)
    groups = group_objects(boxes)
    if len(groups) != len(names):
        raise SystemExit("%s: found %d objects, expected %d (%s)" % (path, len(groups), len(names), names))
    crops = []
    for g in groups:
        members = set(g["members"])
        box = tuple(v * step for v in g["box"])
        part = keyed.crop(box)
        px = part.load()
        for y in range(part.height):
            for x in range(part.width):
                ly, lx = (box[1] + y) // step, (box[0] + x) // step
                if ly >= len(label) or lx >= len(label[0]) or label[ly][lx] not in members:
                    px[x, y] = (0, 0, 0, 0)
        crops.append(part.crop(part.getbbox()))
    scale = target_height / max(c.height for c in crops)
    return [(name, pixelate_down(c, scale)) for name, c in zip(names, crops)]


def make_background(path, horizon, out_path):
    src = Image.open(path).convert("RGB")
    strip = src.crop((0, 0, src.width, horizon))
    width = 1280
    height = round(strip.height * width / strip.width)
    strip = strip.resize((width, height), Image.BOX)
    seamless = Image.new("RGB", (width * 2, height))
    seamless.paste(strip, (0, 0))
    seamless.paste(strip.transpose(Image.FLIP_LEFT_RIGHT), (width, 0))
    seamless = seamless.quantize(colors=96, method=Image.MEDIANCUT).convert("RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    seamless.save(out_path)
    print("background", out_path, seamless.size)


def build(stage, concept_dir, project_dir):
    spec = STAGES[stage]
    bg_file, horizon = spec["background"]
    make_background(os.path.join(concept_dir, "backgrounds", bg_file), horizon,
                    os.path.join(project_dir, "assets", "sprites", "backgrounds", stage + "_far.png"))
    out_dir = os.path.join(project_dir, "assets", "sprites", "roadside", stage)
    os.makedirs(out_dir, exist_ok=True)
    for sheet, target_height, names in spec["sheets"]:
        for name, sprite in slice_sheet(os.path.join(concept_dir, "roadside", sheet), names, target_height):
            if name is None:
                continue
            sprite.save(os.path.join(out_dir, name + ".png"))
            print(stage, name, sprite.size)


def main():
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    for stage in sys.argv[3:] or list(STAGES):
        build(stage, concept_dir, project_dir)


if __name__ == "__main__":
    main()
