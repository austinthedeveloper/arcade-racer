#!/usr/bin/env python3
"""Build a stage's game sprites from its concept sheets.

- Slices each roadside concept sheet (a row of objects on magenta) into keyed sprites,
  one per object, scaled down so the sheet's tallest object is a fixed texture height.
- Cuts the stage's background into three seamless parallax strips: sky, far and near
  (<stage>_sky.png, _far.png, _near.png; scripts/render/background.gd scrolls them).

Stages are described in STAGES below; "shared" holds race furniture (crowds, barriers, signs)
for every stage. Palm Coast's six hand-drawn props come from make_drawn_props.py.

Usage:
    python3 tools/make_stage_sprites.py <concept_dir> <project_dir> [stage ...]
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

import manifest
from spritelib import FOUR, cli_args, key_sheet, pixelate_down, save_sprite, slice_objects

# Background layers, back to front. The sky is opaque and scaled to SKY_HEIGHT pixels; far
# and near are keyed, cropped to their content and scaled to LAYER_WIDTH pixels per half
# strip (each strip is its art followed by its mirror image, so the ends meet).
LAYERS = ("sky", "far", "near")
SKY_HEIGHT = 200
LAYER_WIDTH = {"far": 800, "near": 960}
LAYER_COLORS = 96
# Sky keying for a composite with no layers of its own (key="sky"): a pixel is sky when it
# is within SKY_STEP (sum of RGB differences) of its right and lower neighbours and that
# smooth patch reaches the top edge; then only the opaque parts touching the bottom stay.
SKY_STEP = 36


def layers(prefix):
    """The round 2 concept layers of a stage: <prefix>_l1_sky, _l2_far and _l3_near, the
    far and near ones on magenta."""
    return {
        "sky": layer("%s_l1_sky_A_v1.png" % prefix),
        "far": layer("%s_l2_far_A_v1.png" % prefix, key="sheet"),
        "near": layer("%s_l3_near_A_v1.png" % prefix, key="sheet"),
    }


def layer(file, key=None, rows=None, width=None):
    """A background layer cut from `file`: its `rows` (top, bottom) only when given, keyed
    by `key` ("sheet": spritelib.key_sheet, "sky": key_sky, None: opaque), `width` pixels
    per half strip when given (LAYER_WIDTH otherwise)."""
    return {"file": file, "key": key, "rows": rows, "width": width}


# Per stage: background (sky, far and near layers) and roadside sheets.
# Each sheet lists its objects in reading order (rows top to bottom, left to right) and the
# texture height of its tallest object. An object is (name, world height, fraction of its
# width that collides); the game reads those from the manifest (tools/manifest.py). None skips
# an object (art the renderer can't use yet, such as a tunnel mouth or a covered bridge the
# road would run through). A fourth item, "row", cuts a single row of overlapping objects
# left to right instead (spritelib.slice_row).
STAGES = {
    "redrock": {
        "background": layers("redrock"),
        "sheets": [
            ("redrock_cactus_A_v1.png", 160, [
                ("saguaro_a", 3600, 0.3), ("saguaro_b", 3800, 0.3), ("saguaro_c", 3400, 0.3),
                ("prickly_pear_a", 1100, 0.7), ("prickly_pear_b", 1300, 0.7),
                ("tumbleweed_a", 600, 0), ("tumbleweed_b", 750, 0),
            ]),
            ("redrock_rocks_A_v1.png", 200, [
                ("boulders_a", 2600, 0.8), ("boulders_b", 2000, 0.8), ("rock_pillar", 9000, 0.5),
                ("rock_arch", 6500, 0.9),
            ]),
            ("redrock_buildings_A_v1.png", 180, [
                ("diner", 6000, 1), ("gas_station", 4200, 1), ("windmill", 7000, 0.4),
            ]),
            ("redrock_props_A_v1.png", 110, [
                ("fence", 1300, 1), ("skull_post", 1700, 0.3), ("road_sign", 2400, 0.9),
            ]),
            ("redrock_extras_A_v1.png", 200, [
                ("water_tower_wood", 6500, 0.6), ("rusty_truck", 1800, 1), ("dino", 7000, 0.6),
                ("cattle_sign", 2200, 0.5), ("butte", 9000, 0.9), ("arrow_sign", 4200, 0.4),
            ]),
        ],
    },
    "neon": {
        "background": layers("neon"),
        "sheets": [
            ("neon_buildings_A_v1.png", 200, [
                ("casino_spire", 11000, 1), ("casino_lotus", 11000, 1), ("casino_round", 11000, 1),
                ("casino_star", 11000, 1), ("casino_wave", 11000, 1), ("casino_crown", 11000, 1),
            ]),
            ("neon_billboards_A_v1.png", 170, [
                ("billboard_sunset", 5200, 0.8), ("sign_chevron", 5200, 0.8),
                ("sign_starburst", 5200, 0.8), ("sign_lights", 5200, 0.8),
                ("billboard_wide", 5200, 0.8), ("sign_stack", 5200, 0.8),
            ]),
            ("neon_neon-signs_A_v1.png", 150, [
                ("neon_arrow", 3600, 0.3), ("neon_star", 3600, 0.3), ("neon_cocktail", 3600, 0.3),
                ("neon_chevrons", 3600, 0.3), ("neon_card", 3600, 0.3), ("neon_stars", 3600, 0.3),
                ("neon_spiral", 3600, 0.3),
            ]),
            ("neon_props_A_v1.png", 150, [
                ("street_lamp_a", 3400, 0.2), ("street_lamp_b", 3000, 0.2), ("palm_lit", 4200, 0.3),
                ("fountain", 2800, 1), None,
            ]),
            ("neon_extras_A_v1.png", 200, [
                ("slot_machine", 7500, 1), ("cowboy_boot", 6000, 0.8), ("palm_lights", 4600, 0.3),
                ("casino_entrance", 6500, 1), ("fountain_show", 5000, 0.9),
                ("searchlight", 3000, 0.7),
            ]),
        ],
    },
    "timberline": {
        "background": layers("timberline"),
        "sheets": [
            ("timberline_pines_A_v1.png", 170, [
                ("pine_a", 6400, 0.25), ("pine_b", 6000, 0.25), ("pine_c", 4200, 0.25),
                ("pine_d", 3800, 0.25), ("pine_e", 2500, 0.3), ("pine_f", 2200, 0.3),
                ("fallen_log", 700, 0.9),
            ]),
            ("timberline_buildings_A_v1.png", 150, [
                ("cabin", 5000, 1), ("lodge", 6500, 1), None,
            ]),
            ("timberline_landmarks_A_v1.png", 220, [
                ("waterfall", 12000, 1), ("lookout_tower", 8500, 0.4),
            ]),
            ("timberline_props_A_v1.png", 160, [
                ("snowbank", 1100, 0), ("guardrail", 900, 1), ("chevron_sign", 1900, 0.8),
                ("snow_cliff", 7000, 1),
            ]),
            ("timberline_extras_A_v1.png", 200, [
                ("chairlift", 7500, 0.3), ("chapel", 6500, 1), ("frozen_falls", 9000, 1),
                ("moose", 2600, 0.6), ("woodpile", 1600, 1), ("snowman", 1500, 0.5),
            ]),
        ],
    },
    "bayou": {
        "background": layers("bayou"),
        "sheets": [
            ("bayou_trees_A_v1.png", 220, [
                ("cypress_a", 8000, 0.15), ("cypress_b", 8400, 0.2), ("cypress_c", 6200, 0.15),
                None,
            ]),
            ("bayou_buildings_A_v1.png", 150, [
                ("stilt_shack", 5000, 1), ("boat_dock", 3200, 1), ("bait_shop", 4800, 1),
            ]),
            ("bayou_props_A_v1.png", 90, [
                ("reeds_a", 1000, 0), ("reeds_b", 1000, 0), ("cattails", 1000, 0),
                ("reeds_c", 1000, 0), ("heron", 1100, 0), ("mist_a", 1400, 0), ("mist_b", 1400, 0),
                ("mist_c", 1400, 0),
            ]),
            ("bayou_bridge_A_v1.png", 150, [
                ("rail_wood_a", 1000, 1), ("rail_wood_b", 1000, 1), ("rail_wood_short", 1000, 1),
                ("rail_post", 750, 1), ("rail_end", 1000, 1), None, None, None, None, None,
                ("piling", 2000, 0.8), ("rail_wood_long", 1000, 1), ("rail_concrete", 1000, 1),
                ("rail_concrete_end", 1000, 1),
            ]),
            ("bayou_extras_A_v1.png", 200, [
                ("crab_shack", 5500, 1), ("gator", 700, 0), ("crawfish_sign", 3000, 0.8),
                ("live_oak", 7000, 0.3), ("riverboat", 5500, 1), ("mailboxes", 1300, 0.9),
            ]),
        ],
    },
    "harvest": {
        "background": layers("harvest"),
        "sheets": [
            ("harvest_buildings_A_v1.png", 200, [
                ("barn", 6500, 1), ("silos", 7500, 1), ("water_tower", 8000, 0.4),
            ]),
            ("harvest_landmarks_A_v1.png", 220, [
                ("farm_windmill", 8000, 0.3), ("oak", 6500, 0.2),
            ]),
            ("harvest_plants_A_v1.png", 90, [
                ("sunflowers", 1500, 0), ("corn", 1700, 0), ("farm_stand", 2200, 1),
            ]),
            ("harvest_props_A_v1.png", 100, [
                ("hay_round", 1200, 1), ("hay_bale", 800, 1), ("scarecrow", 1800, 0.3),
                ("farm_fence", 900, 1),
            ]),
            ("harvest_extras_A_v1.png", 200, [
                ("grain_elevator", 10000, 1), ("balloon", 4000, 0), ("farm_truck", 2000, 1),
                ("produce_cart", 2400, 1), ("crop_duster", 4200, 1), ("pumpkins", 1500, 0.9),
            ]),
        ],
    },
    "thunder": {
        "background": layers("thunder"),
        "sheets": [
            ("thunder_buildings_A_v1.png", 160, [
                ("truck_stop", 6500, 1), ("motel", 6000, 1),
            ]),
            ("thunder_hazards_A_v1.png", 110, [
                ("jersey_barrier", 900, 1), ("cone", 650, 0), ("cone_tall", 780, 0),
                ("barricade_post", 1100, 0.5), ("sawhorse", 1000, 0.9), ("drum", 900, 0),
                ("hazard_post", 1000, 0.5), ("a_frame", 950, 0.9),
            ]),
            ("thunder_poles_A_v1.png", 220, [
                ("pole_a", 5200, 0.2), ("pole_b", 5200, 0.2), ("pole_transformer", 5200, 0.2),
                ("pole_c", 5200, 0.2), ("pole_tanks", 5200, 0.2), ("pole_tall", 6000, 0.2),
                ("pylon", 11000, 0.6),
            ]),
            ("thunder_props_A_v1.png", 110, [
                ("tree_windswept", 3200, 0.3), ("tree_snapped", 2600, 0.3),
                ("shrub_windswept", 1700, 0), ("puddle_a", 500, 0), ("puddle_b", 500, 0),
                ("wrecked_sign", 3200, 0.8),
            ]),
            ("thunder_extras_A_v1.png", 200, [
                ("grain_bin", 7000, 0.9), ("storm_cellar", 1800, 1), ("windmill_old", 6500, 0.3),
                ("flasher_barricade", 1100, 0.9), ("radar_dome", 8000, 0.6),
                ("tree_bent", 3600, 0.3),
            ]),
        ],
    },
    "skyline": {
        # The v2 composite has no layers (its v1 layers have the lookalike landmarks): the
        # generic v1 sunset sky, the v2 city with its sky keyed out, and v2's harbor water.
        # The water holds the city's reflections, so it is cut at the city's scale (the far
        # width) and the game moves the two together (WS-14, the theme's "reflection")
        "background": {
            "sky": layer("skyline_l1_sky_A_v1.png"),
            "far": layer("skyline_composite_A_v2.png", key="sky", rows=(0, 568)),
            "near": layer("skyline_composite_A_v2.png", rows=(566, 640), width=LAYER_WIDTH["far"]),
        },
        "sheets": [
            ("skyline_buildings_A_v1.png", 220, [
                ("tower_twin", 11000, 1), ("tower_glass", 11000, 1), ("tower_round", 11000, 1),
                ("office_a", 11000, 1), ("deco_tower", 11000, 1), ("galleria", 7500, 1),
                ("hotel_sky", 11000, 1), ("clock_tower", 11000, 1), ("cafe", 7500, 1),
                ("apartments", 7500, 1), ("deco_pink", 7500, 1), ("brick_loft", 7500, 1),
                ("office_b", 7500, 1), ("office_c", 7500, 1), None,
            ]),
            ("skyline_props_A_v1.png", 150, [
                ("harbor_lamp", 3600, 0.2), ("harbor_lamp_double", 3600, 0.2),
                ("traffic_light", 3000, 0.2), ("traffic_light_arm", 3400, 0.15),
                ("subway", 3200, 1), ("crowd_barrier_city", 1500, 1),
            ]),
            ("skyline_bridge_A_v1.png", 220, [
                ("bridge_tower_x", 16000, 0.4), ("bridge_tower_h", 16000, 0.4),
                ("bridge_tower_a", 16000, 0.4), ("bridge_tower_slim", 16000, 0.4), None, None,
            ]),
            ("skyline_extras_A_v1.png", 200, [
                ("harbor_crane", 11000, 0.6), ("ferry_terminal", 5500, 1),
                ("dolphin_balloon", 6000, 0), ("flag_a", 3800, 0.1), ("flag_b", 3800, 0.1),
                ("flag_c", 3800, 0.1), ("flag_d", 3800, 0.1), ("flag_e", 3800, 0.1),
                ("news_van", 1900, 1), ("fireworks_barge", 2600, 1),
            ]),
        ],
    },
    "palm_coast": {
        "background": layers("palm-coast"),
        "sheets": [
            ("palm-coast_palms_A_v1.png", 190, [
                ("palm_tall_a", 5200, 0.2), ("palm_tall_b", 4800, 0.2), ("palm_lean", 4800, 0.2),
                ("palm_short_a", 2400, 0.35), ("palm_short_b", 2400, 0.35), ("palm_fan", 2200, 0.4),
                ("palm_cluster", 4400, 0.5),
            ], "row"),
            ("palm-coast_extras_A_v1.png", 200, [
                ("pier", 4200, 1), ("ice_cream_stand", 3600, 0.9), ("surfboards", 2200, 0.8),
                ("lighthouse", 8000, 0.5), ("bikes", 1200, 0.9), ("gull_post", 1500, 0.4),
            ]),
        ],
    },
    # Race furniture every stage can use; no background.
    "shared": {
        "sheets": [
            ("shared_barriers_A_v1.png", 60, [
                ("guardrail_steel", 650, 1), ("barrier_red", 900, 1), ("tire_stack", 1000, 1),
                ("barrels_yellow", 900, 1), ("cone_orange", 650, 0), ("barricade", 1000, 0.9),
                ("barrier_orange", 900, 1),
            ]),
            ("shared_crowd_A_v1.png", 120, [
                ("crowd", 1800, 1), ("grandstand", 4200, 1), ("flagman", 1900, 0.4),
                ("camera_tower", 4500, 0.6), None, None, None, ("inflatable_arch", 3800, 0.3),
            ]),
            ("shared_signs_A_v1.png", 110, [
                ("turn_left", 2100, 0.4), ("turn_right", 2100, 0.4), ("chevron_a", 2100, 0.4),
                ("chevron_b", 2100, 0.4), ("chevron_c", 2100, 0.4), ("bump_sign", 2100, 0.4),
                ("sign_green", 3200, 0.8), ("sign_brown", 3200, 0.8), ("delineator", 1100, 0.5),
            ]),
        ],
    },
}


def key_sky(img):
    """The image with its sky keyed out (see SKY_STEP) and anything left floating in the
    sky (fireworks, clouds) with it."""
    a = np.array(img.convert("RGBA"))
    rgb = a[..., :3].astype(np.int16)
    smooth = np.ones(a.shape[:2], dtype=bool)
    step_x = np.abs(rgb[:, 1:] - rgb[:, :-1]).sum(axis=2) >= SKY_STEP
    step_y = np.abs(rgb[1:] - rgb[:-1]).sum(axis=2) >= SKY_STEP
    smooth[:, :-1] &= ~step_x
    smooth[:, 1:] &= ~step_x
    smooth[:-1] &= ~step_y
    smooth[1:] &= ~step_y
    labels, _ = ndimage.label(smooth, structure=FOUR)
    sky = np.isin(labels, np.unique(labels[0][labels[0] > 0]))
    solid, _ = ndimage.label(~sky, structure=FOUR)
    grounded = np.isin(solid, np.unique(solid[-1][solid[-1] > 0]))
    a[~grounded] = 0
    return Image.fromarray(a)


def cut_layer(path, kind, key=None, rows=None, width=None):
    """One background layer as a seamless strip: the art then its mirror image."""
    img = Image.open(path).convert("RGBA")
    if rows:
        img = img.crop((0, rows[0], img.width, rows[1]))
    if key == "sheet":
        img = key_sheet(img)
    elif key == "sky":
        img = key_sky(img)
    if kind == "sky":
        width = round(img.width * SKY_HEIGHT / img.height)
        img = img.resize((width, SKY_HEIGHT), Image.BOX)
    else:
        top, bottom = content_rows(img)
        img = img.crop((0, top, img.width, bottom))
        img = pixelate_down(img, (width or LAYER_WIDTH[kind]) / img.width)
    a = np.array(img)
    colors = Image.fromarray(a[..., :3]).quantize(colors=LAYER_COLORS, method=Image.MEDIANCUT)
    a[..., :3] = np.array(colors.convert("RGB"))
    a[a[..., 3] == 0] = 0
    return np.concatenate([a, a[:, ::-1]], axis=1)


def content_rows(img):
    """The first and one past the last row with any opaque pixel."""
    rows = np.nonzero((np.array(img)[..., 3] > 0).any(axis=1))[0]
    return int(rows[0]), int(rows[-1]) + 1


def build_background(stage, spec, concept_dir, project_dir):
    out_dir = os.path.join(project_dir, "assets", "sprites", "backgrounds")
    os.makedirs(out_dir, exist_ok=True)
    for kind in LAYERS:
        cut = spec[kind]
        strip = cut_layer(os.path.join(concept_dir, "backgrounds", cut["file"]), kind, cut["key"], cut["rows"], cut["width"])
        out = os.path.join(out_dir, "%s_%s.png" % (stage, kind))
        img = Image.fromarray(strip)
        (img.convert("RGB") if kind == "sky" else img).save(out)
        print("background", out, strip.shape[1], "x", strip.shape[0])


def build(stage, concept_dir, project_dir):
    spec = STAGES[stage]
    if "background" in spec:
        build_background(stage, spec["background"], concept_dir, project_dir)
    out_dir = os.path.join(project_dir, "assets", "sprites", "roadside", stage)
    os.makedirs(out_dir, exist_ok=True)
    for sheet, target_height, names, *how in spec["sheets"]:
        path = os.path.join(concept_dir, "roadside", sheet)
        names = [n and n[0] for n in names]
        for name, sprite in slice_objects(path, names, target_height, row=how == ["row"]):
            if name is None:
                continue
            save_sprite(sprite, os.path.join(out_dir, name + ".png"))
            print(stage, name, sprite.size)


def main():
    concept_dir, project_dir, *stages = cli_args(__doc__, 2, more=True)
    for stage in stages or list(STAGES):
        build(stage, concept_dir, project_dir)
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
