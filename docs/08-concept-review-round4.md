# Concept Review: Round 4

Reviewed 2026-10-31. 75 new images from the round 4 prompts (`docs/07-art-prompts-round4.md`), logged in `assets/generation-round4.md`. I looked at every image and ran the sprite slicer (`tools/make_car_sprites.py`'s `slice_sheet`) on the sheets the game would cut.

## Verdict

A strong round. **Level pieces, traffic and power-ups are keepers**, and the Skyline reroll unblocks stage 8. Of the five car redesigns, **four now read as original**. Two new pieces failed and have reroll prompts (round 5): the **Cyclone** (wrong wheel count) and the **Skyline bridge pylon** (its legs stand in the road). Two smaller lookalike fixes also have prompts.

## Unblocked

| What | Image | Notes |
|---|---|---|
| Skyline Finale background | `skyline_composite_A_v2` | Fictional now: stepped tower with a ring crown, white A-pylon cable-stayed bridges. Stage 8 can be built. The L1 to L3 layers still need splitting or their own prompts. |
| Vega hill sheets | `car_vega_steer_down_sheet_A_v1`, `car_vega_steer_up_sheet_A_v1` | Both slice into 7 frames. They match the corrected definitions (downhill shows more bumper, uphill more roof). Running `tools/make_car_sprites.py` puts them in the game in place of the stretched stand-in. Middle frames are near-identical, like the level sheet. |
| Drive-through pieces | `dt_*` | All 11 key as one piece with an open middle, as the renderer needs. Best: Neon tunnel entrance and ring, covered bridge, Bayou truss, Harvest trestle, Thunderhead overpass, Palm arch. |
| Checkpoint gate, start gantry | `shared_checkpoint_gate`, `shared_start_gantry` | Ready to build the checkpoint and start line around. |

## Cars

| Car | Verdict | Notes |
|---|---|---|
| Bruiser v3 | **Original enough, keep** | Notchback, offset blower, box fender pods, full-width bar with a round center light. Still generic early-70s muscle, which suits the archetype. |
| Solano v2 | **Original, keep** | Faceted boat-tail speedster with blade taillights. Steering sheet has real yaw steps, the best one yet. |
| Phantom v2 | **Original, keep** (small note) | Teal faceted car with roof fin lights. The louvered rear window is a familiar 80s cue. Hero is a coupe, views show a hatchback: pick one for the 3D model. |
| Kestrel v2 | **Rear is original, keep** (small note) | Honeycomb lights and tall wing work. Front and side views drift toward a round modern retro compact; give the 3D model a flatter nose and boxier cabin. |
| Mesa v2 | **Original, keep** | Stacked round lights, X tailgate, spare in the bed. |
| Vega views and crash v2 | **Keep** | Rear matches the hero. The front and side views lean toward a famous wedge supercar, so model from the hero and the rear view. |
| Tempest | **Original, keep** | Long tail, center fin, vertical light strips. Side view hides the rear wheel completely, which is fine for an enclosed-wheel design. |
| Dune Skipper | **Original, keep** | Clear see-through silhouette; slices fine. |
| Halo EV | **Original, keep** | The ring taillight reads from any distance, as intended. |
| Cyclone | **Reroll** (CAR-CYCLONE-01R) | Every view shows an extra wheel beside the fat rear tire (the rear view reads as four wheels), and the sharp faceted body reads like a well-known real reverse trike. The reroll asks for exactly three wheels and a rounded pod body. |

Steering sheets: same as round 2. Useful as design checks, not as production frames. Production frames still come from the 3D render pipeline.

## Traffic

All six sheets slice into the right number of vehicles in the order the prompts give. **TRF-10 light states** are exactly what the turn-signal tell needs (off, brake, left, right, same car). One fix: the TRF-09 **combine harvester** is green with a yellow stripe, a famous real livery. TRF-09R recolors it red.

## Level pieces

- **Skyline pylon (DT-SKYLINE-01): reroll.** The A-shaped legs meet the deck in the middle of the road, so cars would drive into them. DT-SKYLINE-01R asks for H-shaped legs at the road edges.
- **Redrock arch:** not symmetrical, which looks natural; keep.
- **Neon tunnel entrance:** the portal stands alone. In engine it will need a wall or building face filling the sides so the tunnel doesn't look like a free-standing gate.
- **Stage extras:** all eight keep. The Bayou riverboat carries a hazy background that will leave a fringe when keyed.

## Power-ups

Pickups, icons, effects and the crate sequence all match and read well. One change: a wooden crate with a big question mark is the signature item of a famous platform game, so PU-01R gives the mystery pickup its own shape (a spinning rainbow hubcap). Power-ups are still a proposal (open question #11).

## Round 5 prompts

| Prompt | File |
|---|---|
| CAR-CYCLONE-01R | `assets/prompts/cars/car_cyclone.md` (then rerun 02 to 04 with it as the reference) |
| DT-SKYLINE-01R | `assets/prompts/roadside/drive-through.md` |
| TRF-09R | `assets/prompts/traffic/traffic.md` |
| PU-01R | `assets/prompts/powerups/powerups.md` (only if power-ups go ahead) |

## Next steps

1. Run `tools/make_car_sprites.py` so the Vega hill sheets replace the stretched stand-in, then check hills in game.
2. Build Skyline Finale from the v2 background.
3. Build the road-spanning sprite type, starting with the Neon tunnel, covered bridge and checkpoint gate.
4. Generate the four round 5 prompts.
