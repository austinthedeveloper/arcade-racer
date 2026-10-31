# Round 5 art revisions and round-four review follow-up

Updated 2026-10-30. **Saved: 9/9 images.** Built-in image_gen, STYLE-A high-color pixel art. Based on [the round-four review](round5-source-snapshot/docs/08-concept-review-round4.md). Earlier image versions are retained.

The user explicitly requested the matching rainbow-hubcap concept set. This approves generating concept artwork; power-up mechanics and new roster stats remain proposals. Exact source/final prompts, description substitutions, reference roles, corrections and image hashes are in [generation-round5.json](generation-round5.json). Full source files were captured before generation under `assets/round5-source-snapshot/`.

| Prompt | Status | Image | Notes |
|---|---|---|---|
| CAR-CYCLONE-02 | complete | [car_cyclone_views_A_v2.png](concept/cars/car_cyclone_views_A_v2.png) | 1672 × 941. Three orthographic-style concept views of the rounded tandem-seat pod. Rear shows two front tires and one wide central rear; side has two wheel stations. |
| CAR-CYCLONE-03 | complete | [car_cyclone_steer_sheet_A_v2.png](concept/cars/car_cyclone_steer_sheet_A_v2.png) | 2048 × 768. Seven separated steering concepts retain two front tires and one wide central rear. Middle yaw steps remain subtle; use controlled 3D renders for production. |
| CAR-CYCLONE-04 | complete | [car_cyclone_crash_sheet_A_v2.png](concept/cars/car_cyclone_crash_sheet_A_v2.png) | 2103 × 748. Six separated crash poses carry through the rounded three-wheel design. Particle grouping, timing and exact registration remain production work. |
| CAR-CYCLONE-01R | complete | [car_cyclone_hero_A_v2.png](concept/cars/car_cyclone_hero_A_v2.png) | 1447 × 1087. Rounded tandem-seat pod; three visible wheels after viewpoint correction: two front, one continuous wide rear. New candidate awaiting user design review. |
| DT-SKYLINE-01R | complete | [dt_skyline_pylon_A_v2.png](concept/roadside/dt_skyline_pylon_A_v2.png) | 1672 × 941. H-shaped portal with vertical piers outside a wide magenta opening; crossbeam lowered to bring aperture width/height close to 2.5. Engine alignment remains to be checked. |
| TRF-09R | complete | [trf09_combine_A_v2.png](concept/traffic/trf09_combine_A_v2.png) | 1448 × 1086. One rear-view combine, red body/cream stripe/black spout; replaces only the green combine in TRF-09. |
| PU-02 | complete | [pu02_icons_A_v2.png](concept/powerups/pu02_icons_A_v2.png) | 1672 × 940. Six-icon HUD set: first four pickup designs and empty slot retained; fifth icon replaced with matching rainbow hubcap. |
| PU-04 | complete | [pu04_hubcap_reveal_A_v2.png](concept/powerups/pu04_hubcap_reveal_A_v2.png) | 1672 × 941. Five-frame light-based hubcap reveal; no crate, planks or question mark. Concept timing/registration remain. |
| PU-01R | complete | [pu01_mystery_A_v2.png](concept/powerups/pu01_mystery_A_v2.png) | 1672 × 941. Three rainbow-chrome hubcap spin concepts replace the mystery crate; matching HUD icon and five-frame reveal are also complete. |

## Review decisions carried forward

- Keep the fictional Skyline v2 background, Vega hill sheets, stage extras, accepted drive-through pieces, race gates, traffic and power-up effects. The pylon portal and Cyclone v1 are rejected and replaced by this pass's candidates.
- Keep Bruiser v3, Solano v2, Phantom v2, Kestrel v2 rear, Mesa v2, Vega v2 rear/hero, Tempest, Dune Skipper and Halo as design references. Newly generated Cyclone v2 still needs the user's review.
- Phantom: reconcile coupe versus hatchback before building the 3D model. Kestrel: flatter nose and boxier cabin for the model; retain honeycomb rear lights. Vega: model primarily from the approved hero and rear view, since the front/side views drift toward a familiar wedge design.
- Steering sheets remain design checks. Controlled 3D renders/manual frames are still required for production yaw steps, exact registration and consistent pixel scale.
- The red combine is a single replacement sprite for the sixth vehicle in TRF-09; the other seven accepted traffic designs remain unchanged.
- The hubcap replaces the mystery crate concept. PU-02 updates the HUD set to match; PU-04 becomes a light-based hubcap reveal sequence, saved as `pu04_hubcap_reveal_A_v2.png`. The other four pickup identities and PU-03 effects are retained.

## Production and engine handoff

The review's engine tasks remain implementation work: import the Vega hill sheets and check hills in game; build Skyline Finale; add road-spanning sprites starting with the Neon tunnel, covered bridge and checkpoint gate. The revised Skyline still needs L1/L2/L3 layers derived from its fictional landmarks. The Neon entrance needs surrounding wall/building faces in engine. The Bayou riverboat needs haze/fringe cleanup when keyed.

This pass supplies art and documentation. It does not run the sprite importer, alter game code, create 3D models, or claim in-engine validation. Magenta-key conversion, particle grouping, pixel-grid cleanup and final sizing remain production checks.
