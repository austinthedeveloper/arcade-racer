#!/usr/bin/env python3
"""Build a stage's game sprites from its concept sheets.

- Slices each roadside concept sheet (a row of objects on magenta) into keyed sprites,
  one per object, scaled down so the sheet's tallest object is a fixed texture height.
- Turns the stage's background composite into a seamless parallax strip.

Stages are described in STAGES below; "shared" holds race furniture (crowds, barriers, signs)
for every stage. Palm Coast's six hand-drawn props come from make_drawn_props.py.

Usage:
    python3 tools/make_stage_sprites.py <concept_dir> <project_dir> [stage ...]
"""
import os
import sys

from spritelib import make_background, slice_objects

# Per stage: background (composite file, horizon row in it) and roadside sheets.
# Each sheet lists its objects in reading order (rows top to bottom, left to right) and the
# texture height of its tallest object. None skips an object (art the renderer can't use yet,
# such as a tunnel mouth or a covered bridge the road would run through). A fourth item,
# "row", cuts a single row of overlapping objects left to right instead (spritelib.slice_row).
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
            ("redrock_extras_A_v1.png", 200, [
                "water_tower_wood", "rusty_truck", "dino", "cattle_sign", "butte", "arrow_sign"]),
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
            ("neon_extras_A_v1.png", 200, [
                "slot_machine", "cowboy_boot", "palm_lights", "casino_entrance", "fountain_show", "searchlight"]),
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
            ("timberline_extras_A_v1.png", 200, [
                "chairlift", "chapel", "frozen_falls", "moose", "woodpile", "snowman"]),
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
            ("bayou_extras_A_v1.png", 200, [
                "crab_shack", "gator", "crawfish_sign", "live_oak", "riverboat", "mailboxes"]),
        ],
    },
    "harvest": {
        "background": ("harvest_composite_A_v1.png", 600),
        "sheets": [
            ("harvest_buildings_A_v1.png", 200, ["barn", "silos", "water_tower"]),
            ("harvest_landmarks_A_v1.png", 220, ["farm_windmill", "oak"]),
            ("harvest_plants_A_v1.png", 90, ["sunflowers", "corn", "farm_stand"]),
            ("harvest_props_A_v1.png", 100, ["hay_round", "hay_bale", "scarecrow", "farm_fence"]),
            ("harvest_extras_A_v1.png", 200, [
                "grain_elevator", "balloon", "farm_truck", "produce_cart", "crop_duster", "pumpkins"]),
        ],
    },
    "thunder": {
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
            ("thunder_extras_A_v1.png", 200, [
                "grain_bin", "storm_cellar", "windmill_old", "flasher_barricade", "radar_dome", "tree_bent"]),
        ],
    },
    "skyline": {
        "background": ("skyline_composite_A_v2.png", 560),
        "sheets": [
            ("skyline_buildings_A_v1.png", 220, [
                "tower_twin", "tower_glass", "tower_round", "office_a", "deco_tower", "galleria",
                "hotel_sky", "clock_tower", "cafe", "apartments", "deco_pink", "brick_loft", "office_b",
                "office_c", None]),
            ("skyline_props_A_v1.png", 150, [
                "harbor_lamp", "harbor_lamp_double", "traffic_light", "traffic_light_arm", "subway",
                "crowd_barrier_city"]),
            ("skyline_bridge_A_v1.png", 220, [
                "bridge_tower_x", "bridge_tower_h", "bridge_tower_a", "bridge_tower_slim", None, None]),
            ("skyline_extras_A_v1.png", 200, [
                "harbor_crane", "ferry_terminal", "dolphin_balloon", "flag_a", "flag_b", "flag_c",
                "flag_d", "flag_e", "news_van", "fireworks_barge"]),
        ],
    },
    "palm_coast": {
        "background": ("palm-coast_composite_A_v1.png", 584),
        "sheets": [
            ("palm-coast_palms_A_v1.png", 190, [
                "palm_tall_a", "palm_tall_b", "palm_lean", "palm_short_a", "palm_short_b", "palm_fan",
                "palm_cluster"], "row"),
            ("palm-coast_extras_A_v1.png", 200, [
                "pier", "ice_cream_stand", "surfboards", "lighthouse", "bikes", "gull_post"]),
        ],
    },
    # Race furniture every stage can use; no background.
    "shared": {
        "sheets": [
            ("shared_barriers_A_v1.png", 60, [
                "guardrail_steel", "barrier_red", "tire_stack", "barrels_yellow", "cone_orange",
                "barricade", "barrier_orange"]),
            ("shared_crowd_A_v1.png", 120, [
                "crowd", "grandstand", "flagman", "camera_tower", None, None, None, "inflatable_arch"]),
            ("shared_signs_A_v1.png", 110, [
                "turn_left", "turn_right", "chevron_a", "chevron_b", "chevron_c", "bump_sign",
                "sign_green", "sign_brown", "delineator"]),
        ],
    },
}


def build(stage, concept_dir, project_dir):
    spec = STAGES[stage]
    if "background" in spec:
        bg_file, horizon = spec["background"]
        make_background(os.path.join(concept_dir, "backgrounds", bg_file), horizon,
                        os.path.join(project_dir, "assets", "sprites", "backgrounds", stage + "_far.png"))
    out_dir = os.path.join(project_dir, "assets", "sprites", "roadside", stage)
    os.makedirs(out_dir, exist_ok=True)
    for sheet, target_height, names, *how in spec["sheets"]:
        path = os.path.join(concept_dir, "roadside", sheet)
        for name, sprite in slice_objects(path, names, target_height, row=how == ["row"]):
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
