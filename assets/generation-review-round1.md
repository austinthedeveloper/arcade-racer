# Round 1 review follow-up

Updated 2026-10-30. Based on [the user's round-one review](../docs/05-concept-review-round1.md).

**Completed for this pass: 3 new v2 images and 7 existing concepts gathered for review.** All ten next-round items are available. These are generated concepts awaiting the user's next review, not production approvals.

**Visual target:** KA-02 A. STYLE-A high-color pixel art remains selected. B/C remain comparison references; C's sunset grading can inform Harvest/Skyline. The new hero renders use KA-02 A as their style reference, and the Vega sheet uses the new Vega hero as its design reference. Earlier image files and the original prompt archive are preserved.

| Prompt | Delivery | Image | Dimensions | Assessment |
|---|---|---|---|---|
| CAR-VEGA-01 | New v2 | [car_vega_hero_A_v2.png](concept/cars/car_vega_hero_A_v2.png) | 1448 × 1086 | New canopy, two separate tail fins, triangular light clusters and connecting bar, smooth deck/sides, one central exhaust. Concept awaiting user review. |
| CAR-BRUISER-01 | New v2 | [car_bruiser_hero_A_v2.png](concept/cars/car_bruiser_hero_A_v2.png) | 1448 × 1086 | Blue/white fastback with ducktail, side-exit exhaust and corrected three stacked light bars per side. Concept awaiting user review. |
| CAR-VEGA-03 | New v2 | [car_vega_steer_sheet_A_v2.png](concept/cars/car_vega_steer_sheet_A_v2.png) | 2135 × 736 | Seven separate frames retain the new Vega identity. Middle yaw steps are too similar; frame registration and pixel cleanup remain. Continuity test, not a production animation. |
| BG-PALM-02 | Existing v1, reused | [palm-coast_l1_sky_A_v1.png](concept/backgrounds/palm-coast_l1_sky_A_v1.png) | 2172 × 724 | Existing sky-only panorama; turquoise/gold clouds and sun. Reused, awaiting user review. Seam and final pixel-scale checks remain. |
| BG-PALM-03 | Existing v1, reused | [palm-coast_l2_far_A_v1.png](concept/backgrounds/palm-coast_l2_far_A_v1.png) | 2172 × 724 | Existing far horizon with hills, rocky island and sailboats on magenta. Reused, awaiting user review. Keying and seam checks remain. |
| BG-PALM-04 | Existing v1, reused | [palm-coast_l3_near_A_v1.png](concept/backgrounds/palm-coast_l3_near_A_v1.png) | 2172 × 724 | Existing near horizon with hotels, palms, pier and ferris wheel on magenta. Reused, awaiting user review. Shared alignment, overlap and seam checks remain. |
| RS-PALM-02 | Existing v1, reused | [palm-coast_beach_A_v1.png](concept/roadside/palm-coast_beach_A_v1.png) | 1672 × 941 | Existing lifeguard tower, umbrellas/towels, surfboard rack and lamp post. Reused, awaiting user review. Key fringe and pixel-scale cleanup remain. |
| RS-PALM-03 | Existing v1, reused | [palm-coast_buildings_A_v1.png](concept/roadside/palm-coast_buildings_A_v1.png) | 1672 × 941 | Existing art-deco hotel, surf shop, juice stand and volleyball net. Reused, awaiting user review. Key fringe and pixel-scale cleanup remain. |
| RS-PALM-04 | Existing v1, reused | [palm-coast_billboards_A_v1.png](concept/roadside/palm-coast_billboards_A_v1.png) | 1672 × 941 | Existing two beach-art billboards. Reused, awaiting user review. Key fringe and pixel-scale cleanup remain. |
| UI-01 | Existing v1, reused | [ui01_logo_A_v1.png](concept/ui/ui01_logo_A_v1.png) | 1672 × 941 | Existing SUNDOWN RUN chrome/sunset/checkered logo concept. Reused, awaiting user review. Final lettering/vector cleanup remains. |

## Vega steering test

Seven complete, separated cars appear in one row. The canopy, two fins, triangular light groups and one central exhaust remain recognizable across all seven. Automated non-magenta column checks find exactly seven separated sprites. Their bottom bounds range from y=444 to y=448 on the 2135 × 736 sheet; those bounds are content measurements, not final frame cells.

The intermediate left/straight/right angles are too similar to establish a dependable seven-step steering animation. Geometry, wheel placement, frame registration and one shared pixel scale still need control. This is a useful design-continuity result, not a production-ready animation. For final steering, fixed-camera 3D renders or manually constructed pixel frames would provide more dependable angle steps, followed by a shared pixel cleanup pass. No 3D model or production sheet was created in this pass.

## Carried-forward review decisions

- KA-02 A is the visual target. Its old Vega and circuit-style minimap remain unsuitable for the updated game; production should use the new Vega and a point-to-point progress bar.
- KA-03 stays a strong keep. Fake wet reflections with tinted reflection sprites and road color bands as proposed in the review.
- KA-01 stays a mood reference. Its car needs the new Vega design on a later reroll.
- The Palm composite stays a keep; separate L1/L2/L3 concepts are now supplied in this review set. They still need alignment, keying, overlap and seam testing before engine use.
- Palms remain near-production concepts pending final sizing, magenta-fringe cleanup and a consistent pixel grid. Mirroring straight palms can be tested during production.
- Roughly 200 px player-car width remains a proposal awaiting a locked spec. The art-direction spec was not changed.

## Design propagation still pending

The v1 Vega orthographic/crash images and v1 Bruiser orthographic/steering/crash images predate the new car prompts. Do not use them as the updated design. The next-round list specifically requested the two heroes and the Vega steering test; those three have been revised here. KA-01/KA-02 rerolls and other dependent views remain future work after the car designs are reviewed.

Exact revised generation prompts, reference roles, the rejected Bruiser attempt and its correction, dimensions, hashes and the steering measurements are in [generation-revisions-round1.json](generation-revisions-round1.json). The initial 137-image run remains archived in [generation-prompts.json](generation-prompts.json).

Generated with the built-in image_gen tool. Source prompt documents and the user's review notes were not edited.
