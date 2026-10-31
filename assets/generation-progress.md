# Image Generation Completion Log

Updated: 2026-10-30 (America/Chicago). Generation began 2026-10-29.

**Saved: 224 images — 215 from earlier passes plus 9/9 round-five revisions.** Generation completion is separate from user approval and production readiness.

**Main direction:** STYLE-A, high-color pixel art (confirmed by the user). STYLE-B and STYLE-C are comparison variants for KA-01 and KA-02 only.

**Generator:** built-in image_gen. Source prompts are preserved. Final prompts substitute the exact chosen style block and add aspect ratio, stage context, and layout constraints. Targeted correction prompts are recorded where used. Selected final prompts and results: [generation-prompts.json](generation-prompts.json).

**Usage:** concept/reference images. Sprite sheets still need production cleanup, frame registration, keying/alpha conversion, and animation checks. Background layers need seam testing before use. Wide layers are generally about 3:1, the width returned by the generator; actual dimensions are recorded below.

## Round 5 review revisions

**9/9 images saved.** [Round-five log and review decisions](generation-round5.md) · [Exact prompts and provenance](generation-round5.json). This pass covers the rounded three-wheel Cyclone and three dependent sheets, H-shaped Skyline portal, red combine and user-requested rainbow-hubcap concept set. Accepted round-four designs and model-building notes are recorded in the new log.

## Round 4 generation — 2026-10-30

**75/75 images saved.** [Round-four completion log](generation-round4.md) · [Exact prompts and provenance](generation-round4.json). Earlier review decisions and source documents are retained. Car redesigns use the new 01R descriptions for their dependent sheets; old files are preserved.

## Round 1 review follow-up — 2026-10-30

**3 new v2 revisions saved; 7 requested existing concepts gathered for review.** [Review and current selections](generation-review-round1.md) · [Revised prompts and validation](generation-revisions-round1.json).

KA-02 A is the visual target. New Vega/Bruiser heroes and the new Vega seven-frame sheet supersede their v1 counterparts for the next design review. Those old Vega and Bruiser views are superseded by the round-four outputs linked above. KA-01/KA-02 retain mood/style value but show the prior Vega. Production keying, one pixel grid, steering geometry/registration and parallax seams remain outstanding. The proposed ~200 px player-car width is not locked.

The round tables below document the **initial run**. The three additional files are listed in the review follow-up document. Their existence does not imply that all later source-prompt revisions have been regenerated.

## Completion by round

| Round | Saved | Total |
|---|---:|---:|
| 1 | 12 | 12 |
| 2 | 47 | 47 |
| 3 | 78 | 78 |

## Round 1

| Status | Prompt | Style | Output | Notes |
|---|---|---|---|---|
| complete | [BG-PALM-01](prompts/backgrounds/palm-coast.md) | A | [palm-coast_composite_A_v1.png](concept/backgrounds/palm-coast_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-BRUISER-01](prompts/cars/car_bruiser.md) | A | [car_bruiser_hero_A_v1.png](concept/cars/car_bruiser_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| superseded by v2 | [CAR-VEGA-01](prompts/cars/car_vega.md) | A | [car_vega_hero_A_v1.png](concept/cars/car_vega_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| complete | [KA-01](prompts/key-art/key-art.md) | A | [ka01_title_A_v1.png](concept/key-art/ka01_title_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-01](prompts/key-art/key-art.md) | B | [ka01_title_B_v1.png](concept/key-art/ka01_title_B_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [KA-01](prompts/key-art/key-art.md) | C | [ka01_title_C_v1.png](concept/key-art/ka01_title_C_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-02](prompts/key-art/key-art.md) | A | [ka02_gameplay_palm_A_v1.png](concept/key-art/ka02_gameplay_palm_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-02](prompts/key-art/key-art.md) | B | [ka02_gameplay_palm_B_v1.png](concept/key-art/ka02_gameplay_palm_B_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-02](prompts/key-art/key-art.md) | C | [ka02_gameplay_palm_C_v1.png](concept/key-art/ka02_gameplay_palm_C_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-03](prompts/key-art/key-art.md) | A | [ka03_gameplay_neon_A_v1.png](concept/key-art/ka03_gameplay_neon_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-PALM-01](prompts/roadside/palm-coast.md) | A | [palm-coast_palms_A_v1.png](concept/roadside/palm-coast_palms_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-01](prompts/ui/logo-and-menus.md) | A | [ui01_logo_A_v1.png](concept/ui/ui01_logo_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |

## Round 2

| Status | Prompt | Style | Output | Notes |
|---|---|---|---|---|
| complete | [BG-NEON-01](prompts/backgrounds/neon.md) | A | [neon_composite_A_v1.png](concept/backgrounds/neon_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-NEON-02](prompts/backgrounds/neon.md) | A | [neon_l1_sky_A_v1.png](concept/backgrounds/neon_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-NEON-03](prompts/backgrounds/neon.md) | A | [neon_l2_far_A_v1.png](concept/backgrounds/neon_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-NEON-04](prompts/backgrounds/neon.md) | A | [neon_l3_near_A_v1.png](concept/backgrounds/neon_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-PALM-02](prompts/backgrounds/palm-coast.md) | A | [palm-coast_l1_sky_A_v1.png](concept/backgrounds/palm-coast_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-PALM-03](prompts/backgrounds/palm-coast.md) | A | [palm-coast_l2_far_A_v1.png](concept/backgrounds/palm-coast_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-PALM-04](prompts/backgrounds/palm-coast.md) | A | [palm-coast_l3_near_A_v1.png](concept/backgrounds/palm-coast_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-REDROCK-01](prompts/backgrounds/redrock.md) | A | [redrock_composite_A_v1.png](concept/backgrounds/redrock_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-REDROCK-02](prompts/backgrounds/redrock.md) | A | [redrock_l1_sky_A_v1.png](concept/backgrounds/redrock_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-REDROCK-03](prompts/backgrounds/redrock.md) | A | [redrock_l2_far_A_v1.png](concept/backgrounds/redrock_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-REDROCK-04](prompts/backgrounds/redrock.md) | A | [redrock_l3_near_A_v1.png](concept/backgrounds/redrock_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-BRUISER-02](prompts/cars/car_bruiser.md) | A | [car_bruiser_views_A_v1.png](concept/cars/car_bruiser_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-BRUISER-03](prompts/cars/car_bruiser.md) | A | [car_bruiser_steer_sheet_A_v1.png](concept/cars/car_bruiser_steer_sheet_A_v1.png) | 2114 × 744. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-KESTREL-01](prompts/cars/car_kestrel.md) | A | [car_kestrel_hero_A_v1.png](concept/cars/car_kestrel_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-KESTREL-02](prompts/cars/car_kestrel.md) | A | [car_kestrel_views_A_v1.png](concept/cars/car_kestrel_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-KESTREL-03](prompts/cars/car_kestrel.md) | A | [car_kestrel_steer_sheet_A_v1.png](concept/cars/car_kestrel_steer_sheet_A_v1.png) | 2048 × 768. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-SOL-01](prompts/cars/car_sol.md) | A | [car_sol_hero_A_v1.png](concept/cars/car_sol_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-SOL-02](prompts/cars/car_sol.md) | A | [car_sol_views_A_v1.png](concept/cars/car_sol_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-SOL-03](prompts/cars/car_sol.md) | A | [car_sol_steer_sheet_A_v1.png](concept/cars/car_sol_steer_sheet_A_v1.png) | 2117 × 743. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-VEGA-02](prompts/cars/car_vega.md) | A | [car_vega_views_A_v1.png](concept/cars/car_vega_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by v2 | [CAR-VEGA-03](prompts/cars/car_vega.md) | A | [car_vega_steer_sheet_A_v1.png](concept/cars/car_vega_steer_sheet_A_v1.png) | 2098 × 749. Generated and visually reviewed as concept reference. |
| complete | [FX-01](prompts/fx/fx.md) | A | [fx01_tire_smoke_A_v1.png](concept/fx/fx01_tire_smoke_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [FX-02](prompts/fx/fx.md) | A | [fx02_nitro_A_v1.png](concept/fx/fx02_nitro_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [KA-04](prompts/key-art/key-art.md) | A | [ka04_gameplay_canyon_A_v1.png](concept/key-art/ka04_gameplay_canyon_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-05](prompts/key-art/key-art.md) | A | [ka05_postcards_A_v1.png](concept/key-art/ka05_postcards_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-NEON-01](prompts/roadside/neon.md) | A | [neon_neon-signs_A_v1.png](concept/roadside/neon_neon-signs_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-NEON-02](prompts/roadside/neon.md) | A | [neon_buildings_A_v1.png](concept/roadside/neon_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-NEON-03](prompts/roadside/neon.md) | A | [neon_props_A_v1.png](concept/roadside/neon_props_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-NEON-04](prompts/roadside/neon.md) | A | [neon_billboards_A_v1.png](concept/roadside/neon_billboards_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-NEON-ROAD](prompts/roadside/neon.md) | A | [neon_road_colors_A_v1.png](concept/roadside/neon_road_colors_A_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [RS-PALM-02](prompts/roadside/palm-coast.md) | A | [palm-coast_beach_A_v1.png](concept/roadside/palm-coast_beach_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-PALM-03](prompts/roadside/palm-coast.md) | A | [palm-coast_buildings_A_v1.png](concept/roadside/palm-coast_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-PALM-04](prompts/roadside/palm-coast.md) | A | [palm-coast_billboards_A_v1.png](concept/roadside/palm-coast_billboards_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-PALM-COAST-ROAD](prompts/roadside/palm-coast.md) | A | [palm-coast_road_colors_A_v1.png](concept/roadside/palm-coast_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-REDROCK-01](prompts/roadside/redrock.md) | A | [redrock_cactus_A_v1.png](concept/roadside/redrock_cactus_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-REDROCK-02](prompts/roadside/redrock.md) | A | [redrock_rocks_A_v1.png](concept/roadside/redrock_rocks_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-REDROCK-03](prompts/roadside/redrock.md) | A | [redrock_buildings_A_v1.png](concept/roadside/redrock_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-REDROCK-04](prompts/roadside/redrock.md) | A | [redrock_props_A_v1.png](concept/roadside/redrock_props_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-REDROCK-ROAD](prompts/roadside/redrock.md) | A | [redrock_road_colors_A_v1.png](concept/roadside/redrock_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [TRF-01](prompts/traffic/traffic.md) | A | [trf01_cars_A_v1.png](concept/traffic/trf01_cars_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [TRF-03](prompts/traffic/traffic.md) | A | [trf03_big_A_v1.png](concept/traffic/trf03_big_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [HUD-01](prompts/ui/hud.md) | A | [hud01_overlay_A_v1.png](concept/ui/hud01_overlay_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [HUD-02](prompts/ui/hud.md) | A | [hud02_speedo_A_v1.png](concept/ui/hud02_speedo_A_v1.png) | 1254 × 1254. Generated and visually reviewed as concept reference. |
| complete | [HUD-04](prompts/ui/hud.md) | A | [hud04_callouts_A_v1.png](concept/ui/hud04_callouts_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-02](prompts/ui/logo-and-menus.md) | A | [ui02_logo_shapes_A_v1.png](concept/ui/ui02_logo_shapes_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-03](prompts/ui/logo-and-menus.md) | A | [ui03_title_screen_A_v1.png](concept/ui/ui03_title_screen_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-04](prompts/ui/logo-and-menus.md) | A | [ui04_car_select_A_v1.png](concept/ui/ui04_car_select_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |

## Round 3

| Status | Prompt | Style | Output | Notes |
|---|---|---|---|---|
| complete | [BG-BAYOU-01](prompts/backgrounds/bayou.md) | A | [bayou_composite_A_v1.png](concept/backgrounds/bayou_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-BAYOU-02](prompts/backgrounds/bayou.md) | A | [bayou_l1_sky_A_v1.png](concept/backgrounds/bayou_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-BAYOU-03](prompts/backgrounds/bayou.md) | A | [bayou_l2_far_A_v1.png](concept/backgrounds/bayou_l2_far_A_v1.png) | 1983 × 793. Generated and visually reviewed as concept reference. |
| complete | [BG-BAYOU-04](prompts/backgrounds/bayou.md) | A | [bayou_l3_near_A_v1.png](concept/backgrounds/bayou_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-HARVEST-01](prompts/backgrounds/harvest.md) | A | [harvest_composite_A_v1.png](concept/backgrounds/harvest_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-HARVEST-02](prompts/backgrounds/harvest.md) | A | [harvest_l1_sky_A_v1.png](concept/backgrounds/harvest_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-HARVEST-03](prompts/backgrounds/harvest.md) | A | [harvest_l2_far_A_v1.png](concept/backgrounds/harvest_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-HARVEST-04](prompts/backgrounds/harvest.md) | A | [harvest_l3_near_A_v1.png](concept/backgrounds/harvest_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [BG-SKYLINE-01](prompts/backgrounds/skyline.md) | A | [skyline_composite_A_v1.png](concept/backgrounds/skyline_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-SKYLINE-02](prompts/backgrounds/skyline.md) | A | [skyline_l1_sky_A_v1.png](concept/backgrounds/skyline_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-SKYLINE-03](prompts/backgrounds/skyline.md) | A | [skyline_l2_far_A_v1.png](concept/backgrounds/skyline_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-SKYLINE-04](prompts/backgrounds/skyline.md) | A | [skyline_l3_near_A_v1.png](concept/backgrounds/skyline_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-THUNDER-01](prompts/backgrounds/thunder.md) | A | [thunder_composite_A_v1.png](concept/backgrounds/thunder_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-THUNDER-02](prompts/backgrounds/thunder.md) | A | [thunder_l1_sky_A_v1.png](concept/backgrounds/thunder_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-THUNDER-03](prompts/backgrounds/thunder.md) | A | [thunder_l2_far_A_v1.png](concept/backgrounds/thunder_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-THUNDER-04](prompts/backgrounds/thunder.md) | A | [thunder_l3_near_A_v1.png](concept/backgrounds/thunder_l3_near_A_v1.png) | 2092 × 752. Generated and visually reviewed as concept reference. |
| complete | [BG-TIMBER-01](prompts/backgrounds/timberline.md) | A | [timberline_composite_A_v1.png](concept/backgrounds/timberline_composite_A_v1.png) | 1916 × 821. Generated and visually reviewed as concept reference. |
| complete | [BG-TIMBER-02](prompts/backgrounds/timberline.md) | A | [timberline_l1_sky_A_v1.png](concept/backgrounds/timberline_l1_sky_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-TIMBER-03](prompts/backgrounds/timberline.md) | A | [timberline_l2_far_A_v1.png](concept/backgrounds/timberline_l2_far_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [BG-TIMBER-04](prompts/backgrounds/timberline.md) | A | [timberline_l3_near_A_v1.png](concept/backgrounds/timberline_l3_near_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-BRUISER-04](prompts/cars/car_bruiser.md) | A | [car_bruiser_crash_sheet_A_v1.png](concept/cars/car_bruiser_crash_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [CAR-HAULER-01](prompts/cars/car_hauler.md) | A | [car_hauler_hero_A_v1.png](concept/cars/car_hauler_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| complete | [CAR-HAULER-02](prompts/cars/car_hauler.md) | A | [car_hauler_views_A_v1.png](concept/cars/car_hauler_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [CAR-HAULER-03](prompts/cars/car_hauler.md) | A | [car_hauler_steer_sheet_A_v1.png](concept/cars/car_hauler_steer_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [CAR-HAULER-04](prompts/cars/car_hauler.md) | A | [car_hauler_crash_sheet_A_v1.png](concept/cars/car_hauler_crash_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-KESTREL-04](prompts/cars/car_kestrel.md) | A | [car_kestrel_crash_sheet_A_v1.png](concept/cars/car_kestrel_crash_sheet_A_v1.png) | 2048 × 768. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-MESA-01](prompts/cars/car_mesa.md) | A | [car_mesa_hero_A_v1.png](concept/cars/car_mesa_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-MESA-02](prompts/cars/car_mesa.md) | A | [car_mesa_views_A_v1.png](concept/cars/car_mesa_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-MESA-03](prompts/cars/car_mesa.md) | A | [car_mesa_steer_sheet_A_v1.png](concept/cars/car_mesa_steer_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-MESA-04](prompts/cars/car_mesa.md) | A | [car_mesa_crash_sheet_A_v1.png](concept/cars/car_mesa_crash_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-PHANTOM-01](prompts/cars/car_phantom.md) | A | [car_phantom_hero_A_v1.png](concept/cars/car_phantom_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-PHANTOM-02](prompts/cars/car_phantom.md) | A | [car_phantom_views_A_v1.png](concept/cars/car_phantom_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-PHANTOM-03](prompts/cars/car_phantom.md) | A | [car_phantom_steer_sheet_A_v1.png](concept/cars/car_phantom_steer_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-PHANTOM-04](prompts/cars/car_phantom.md) | A | [car_phantom_crash_sheet_A_v1.png](concept/cars/car_phantom_crash_sheet_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-SOL-04](prompts/cars/car_sol.md) | A | [car_sol_crash_sheet_A_v1.png](concept/cars/car_sol_crash_sheet_A_v1.png) | 2048 × 768. Generated and visually reviewed as concept reference. |
| superseded by round 4 | [CAR-VEGA-04](prompts/cars/car_vega.md) | A | [car_vega_crash_sheet_A_v1.png](concept/cars/car_vega_crash_sheet_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [CAR-ZENITH-01](prompts/cars/car_zenith.md) | A | [car_zenith_hero_A_v1.png](concept/cars/car_zenith_hero_A_v1.png) | 1448 × 1086. Generated and visually reviewed as concept reference. |
| complete | [CAR-ZENITH-02](prompts/cars/car_zenith.md) | A | [car_zenith_views_A_v1.png](concept/cars/car_zenith_views_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [CAR-ZENITH-03](prompts/cars/car_zenith.md) | A | [car_zenith_steer_sheet_A_v1.png](concept/cars/car_zenith_steer_sheet_A_v1.png) | 2117 × 743. Generated and visually reviewed as concept reference. |
| complete | [CAR-ZENITH-04](prompts/cars/car_zenith.md) | A | [car_zenith_crash_sheet_A_v1.png](concept/cars/car_zenith_crash_sheet_A_v1.png) | 2172 × 724. Generated and visually reviewed as concept reference. |
| complete | [FX-03](prompts/fx/fx.md) | A | [fx03_sparks_A_v1.png](concept/fx/fx03_sparks_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [FX-04](prompts/fx/fx.md) | A | [fx04_surface_kickup_A_v1.png](concept/fx/fx04_surface_kickup_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [FX-05](prompts/fx/fx.md) | A | [fx05_weather_A_v1.png](concept/fx/fx05_weather_A_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [FX-06](prompts/fx/fx.md) | A | [fx06_celebration_A_v1.png](concept/fx/fx06_celebration_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [FX-07](prompts/fx/fx.md) | A | [fx07_speed_A_v1.png](concept/fx/fx07_speed_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [KA-06](prompts/key-art/key-art.md) | A | [ka06_map_A_v1.png](concept/key-art/ka06_map_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-BAYOU-01](prompts/roadside/bayou.md) | A | [bayou_trees_A_v1.png](concept/roadside/bayou_trees_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-BAYOU-02](prompts/roadside/bayou.md) | A | [bayou_bridge_A_v1.png](concept/roadside/bayou_bridge_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-BAYOU-03](prompts/roadside/bayou.md) | A | [bayou_buildings_A_v1.png](concept/roadside/bayou_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-BAYOU-04](prompts/roadside/bayou.md) | A | [bayou_props_A_v1.png](concept/roadside/bayou_props_A_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [RS-BAYOU-ROAD](prompts/roadside/bayou.md) | A | [bayou_road_colors_A_v1.png](concept/roadside/bayou_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-HARVEST-01](prompts/roadside/harvest.md) | A | [harvest_buildings_A_v1.png](concept/roadside/harvest_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-HARVEST-02](prompts/roadside/harvest.md) | A | [harvest_props_A_v1.png](concept/roadside/harvest_props_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-HARVEST-03](prompts/roadside/harvest.md) | A | [harvest_landmarks_A_v1.png](concept/roadside/harvest_landmarks_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-HARVEST-04](prompts/roadside/harvest.md) | A | [harvest_plants_A_v1.png](concept/roadside/harvest_plants_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-HARVEST-ROAD](prompts/roadside/harvest.md) | A | [harvest_road_colors_A_v1.png](concept/roadside/harvest_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-SKYLINE-01](prompts/roadside/skyline.md) | A | [skyline_buildings_A_v1.png](concept/roadside/skyline_buildings_A_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [RS-SKYLINE-02](prompts/roadside/skyline.md) | A | [skyline_bridge_A_v1.png](concept/roadside/skyline_bridge_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-SKYLINE-03](prompts/roadside/skyline.md) | A | [skyline_props_A_v1.png](concept/roadside/skyline_props_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-SKYLINE-04](prompts/roadside/skyline.md) | A | [skyline_finish_A_v1.png](concept/roadside/skyline_finish_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-SKYLINE-ROAD](prompts/roadside/skyline.md) | A | [skyline_road_colors_A_v1.png](concept/roadside/skyline_road_colors_A_v1.png) | 1672 × 940. Generated and visually reviewed as concept reference. |
| complete | [RS-THUNDER-01](prompts/roadside/thunder.md) | A | [thunder_poles_A_v1.png](concept/roadside/thunder_poles_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-THUNDER-02](prompts/roadside/thunder.md) | A | [thunder_props_A_v1.png](concept/roadside/thunder_props_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-THUNDER-03](prompts/roadside/thunder.md) | A | [thunder_buildings_A_v1.png](concept/roadside/thunder_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-THUNDER-04](prompts/roadside/thunder.md) | A | [thunder_hazards_A_v1.png](concept/roadside/thunder_hazards_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-THUNDER-ROAD](prompts/roadside/thunder.md) | A | [thunder_road_colors_A_v1.png](concept/roadside/thunder_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-TIMBER-01](prompts/roadside/timberline.md) | A | [timberline_pines_A_v1.png](concept/roadside/timberline_pines_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-TIMBER-02](prompts/roadside/timberline.md) | A | [timberline_props_A_v1.png](concept/roadside/timberline_props_A_v1.png) | 2048 × 768. Generated and visually reviewed as concept reference. |
| complete | [RS-TIMBER-03](prompts/roadside/timberline.md) | A | [timberline_buildings_A_v1.png](concept/roadside/timberline_buildings_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-TIMBER-04](prompts/roadside/timberline.md) | A | [timberline_landmarks_A_v1.png](concept/roadside/timberline_landmarks_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [RS-TIMBERLINE-ROAD](prompts/roadside/timberline.md) | A | [timberline_road_colors_A_v1.png](concept/roadside/timberline_road_colors_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [TRF-02](prompts/traffic/traffic.md) | A | [trf02_cars_front_A_v1.png](concept/traffic/trf02_cars_front_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [TRF-04](prompts/traffic/traffic.md) | A | [trf04_stage_specials_A_v1.png](concept/traffic/trf04_stage_specials_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [HUD-03](prompts/ui/hud.md) | A | [hud03_icons_A_v1.png](concept/ui/hud03_icons_A_v1.png) | 2103 × 748. Generated and visually reviewed as concept reference. |
| complete | [HUD-05](prompts/ui/hud.md) | A | [hud05_countdown_A_v1.png](concept/ui/hud05_countdown_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [HUD-06](prompts/ui/hud.md) | A | [hud06_calibration_A_v1.png](concept/ui/hud06_calibration_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-05](prompts/ui/logo-and-menus.md) | A | [ui05_stage_select_A_v1.png](concept/ui/ui05_stage_select_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |
| complete | [UI-06](prompts/ui/logo-and-menus.md) | A | [ui06_results_A_v1.png](concept/ui/ui06_results_A_v1.png) | 1672 × 941. Generated and visually reviewed as concept reference. |

## Initial-run verification

All 133 source prompts are covered by 137 unique saved PNGs: 133 STYLE-A images plus four STYLE-B/STYLE-C comparisons for KA-01 and KA-02. All PNG chunk checksums, file hashes, dimensions, and 275 completion-log links passed validation.

| Category | Saved images |
|---|---:|
| backgrounds | 32 |
| cars | 32 |
| key-art | 10 |
| roadside | 40 |
| ui | 12 |
| fx | 7 |
| traffic | 4 |

Project image folder: `/Users/txdevs/Documents/Development/arcade racer/assets/concept`

Completion document: `/Users/txdevs/Documents/Development/arcade racer/assets/generation-progress.md`

Final prompt archive: `/Users/txdevs/Documents/Development/arcade racer/assets/generation-prompts.json`

The source prompt documents were retained. Final names use the documented style and variation suffixes (`_A_v1`, with `_B_v1` and `_C_v1` for the comparison images). These remain concept/reference assets as specified by the project docs.
