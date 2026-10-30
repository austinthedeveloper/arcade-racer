# Concept Review: Round 2

Reviewed 2026-10-30. 140 images in `assets/concept/`: the full 137-image run plus 3 round 1 revisions.

## Verdict

The environment art is close to production and should drive the look of the game. **Backgrounds, roadside props, traffic and FX are keepers.** They need keying, downscaling and one shared pixel grid, but no redesign. **Player cars are the weak spot**: several still look like real cars, and the generator can't produce steering frames. Cars should move to a different pipeline (below).

## Generation checklist

I checked `assets/generation-progress.md` against the folder and the prompt files:

- All 137 images it links exist on disk.
- Every one of the 125 prompt IDs in `assets/prompts/` has an entry. Nothing was skipped.
- The 3 files not in that table (`car_vega_hero_A_v2`, `car_bruiser_hero_A_v2`, `car_vega_steer_sheet_A_v2`) are listed in `generation-review-round1.md`.

So the checklist is accurate: everything requested was generated.

## By category

| Category | Verdict | Notes |
|---|---|---|
| **Backgrounds** (8 stages, L1/L2/L3) | **Keep** | Excellent across all eight stages, and the layer split is what the renderer needs. Seams and alignment still need a test in engine. **Skyline** resembles real Hong Kong (an IFC-like tower) and has a Golden Gate-like bridge. Reroll those landmarks so the city is fictional. |
| **Roadside** (all 8 stage sets) | **Keep, near production** | Strongest category. Palm Coast beach and buildings sets can replace my procedural props right away. The road_colors sheets are good palette references for each stage. |
| **Traffic** | **Keep** | Generic compacts, sedans, vans, trucks, bus, RV, car carrier and stage specials (surf van, log truck, tractor, airboat, taxi). They read as generic, which is right for traffic. Front views are useful for oncoming lanes. |
| **FX** | **Keep** | Smoke, nitro, sparks, surface kick-up (dirt, sand, snow, water), rain and lightning, fireworks, speed lines. All usable after slicing. |
| **UI / HUD** | **Keep as reference** | Logo, speedo, icons, callouts and countdown are good. The title, car select and results screens are useful layout mockups, but their cars look like famous real sports and muscle cars, so use the layouts only. The calibration mockup fits the F2 wizard well. |
| **Key art** | **Keep for mood** | KA-02 A is still the style target. KA-04 (canyon jump) and KA-06 (world map) are new highlights. KA-05 postcards work as stage-select thumbnails. |
| **Cars** | **Mixed** | See below. |

## Cars

| Car | Status |
|---|---|
| Vega v2 | **Original now.** Canopy, tail fins, triangular lights. Approve as the hero car's design. |
| Bruiser v2 | Still reads as a late-60s Mustang fastback. Needs a bigger change, such as a different roof line or a mid-engine stance. |
| Solano Spyder | Reads as a Shelby Cobra. |
| Phantom | Reads as a Dodge Charger police car. |
| Kestrel | Reads as a Lancia Delta Integrale / Renault 5 Turbo. |
| Mesa | Reads as a Ford Raptor (C-shaped lights). |
| Hauler, Zenith | Original. Keep. |
| Crash sheets | Fun and useful as reference for the crash tumble. |

**Steering sheets don't work.** Every steering sheet has 7 nearly identical frames. The generator cannot hold one car steady and change only the angle, and the round 1 revision notes reached the same conclusion.

**Recommendation:** make the player cars from simple low-poly 3D models (one per car), render them from a fixed camera at the 7 steering angles plus a few pitch angles, then downscale and run a pixel cleanup pass. That gives exact frame registration and the same pixel scale on every car. Use the generated heroes as the design reference for each model. This can wait, as you said. The flat-shape placeholder cars are fine for tuning gameplay.

## Next steps (art)

1. Reroll Bruiser, Solano, Phantom, Kestrel and Mesa with stronger "distinct features" lists.
2. Reroll the Skyline landmarks as fictional ones.
3. Slice and key Palm Coast roadside, traffic and FX into `assets/sprites/` to replace the placeholders.
4. Start the 3D-to-sprite pipeline for the Vega first.

## Bug fixed: palms in the road

Mirrored roadside sprites were drawn one sprite-width to the right of where they belonged. Left-side palms are anchored by their right edge at the road's edge, so a flipped one landed on the asphalt. Fixed in `scripts/render/road_renderer.gd`. Right-side flipped palms had the same offset but moved further from the road, which is why it looked like only some palms were wrong.
