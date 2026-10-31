# Known Bugs and Cleanup Plan (after round 4/5)

Snapshot taken 2026-10-30, after the round 4/5 build: 12 cars, traffic specials, power-ups, spans and
drive-throughs, the Skyline Finale, menus and options. Paths are relative to the repo root.
"Confirmed" means the defect can be read straight from the code. "Suspected" means it hasn't been
checked in game. "Fixed (phase N)" marks what the cleanup below has done (2026-10-31, branches
`feature/CLD-cleanup-1-fixes` to `-4-golden`).

**G3 and G4 fixed in RC-9.** **Still open:** A1 (magenta painted into window glass: needs rerolled or recolored art), A4 (brake
glow and nitro flame anchors, roadmap CP-3), G6
(a missing traffic sprite crashes; the manifest test makes it unlikely). Every loaded roadside sprite is now placed
(roadmap WS-5): `Track.add_road_signs` and `Track.add_race_furniture`, and `test_track` asserts it.

## Fixed in this pass

- **Magenta under the Mesa (and in small gaps on other vehicles).** `tools/make_car_sprites.py`
  only keyed interior background patches of 150 source pixels or more. The gaps under the Mesa's
  axle and light bar are smaller, so the sheet's magenta showed through. Now an interior patch is a
  gap if it is close to the key color on average (`GAP_DISTANCE`) or if dark parts frame it
  (`GAP_FRAME`). Pink and purple paint (Cyclone, Zenith, the purple hatch) stays. The fix also
  cleared the trolley's windscreen and small gaps on the Skipper, Bruiser, carrier, semi, RV and
  others. A new regression test, `test_render.test_player_cars_show_no_key_magenta`, checks this.

## Known bugs

### Art and sprite pipeline

| # | Sev | Status | Bug | Where |
|---|---|---|---|---|
| A1 | Low | Confirmed | **Magenta painted into the window glass.** The generator reflected the magenta background into the glass of the taxi, tractor cab, roadster, navy van, green SUV, dump truck and the trolley windscreen (one streak left). The glass is opaque and drawn that way, so keying can't help. | concept sheets `trf0*`; fix by rerolling or recoloring the glass |
| A2 | Low | **Fixed (phase 2)** | **Pink halo around glowing parts.** The street sweeper's amber beacons have a pink glow halo: glow blended with magenta, kept because it touches the lamp. | `traffic/street_sweeper.png` |
| A3 | Low | **Fixed (phase 2)** | **Purple line under some vehicles.** A one-pixel purple line runs along the bottom edge of several traffic sprites (double-decker, dump truck, jeep). It is the ground shadow blended with the key and not caught by the one-pixel fringe pass. | `make_car_sprites.key_car_sheet` fringe step |
| A4 | Low | Suspected | **Brake glow and nitro flame placed for the Vega on all 12 cars.** The trike, buggy and van will likely look off. | `scripts/render/car_sprites.gd:115-119` |

### Gameplay

| # | Sev | Status | Bug | Where |
|---|---|---|---|---|
| G1 | Med | **Fixed (phase 1)** | **Segment skipping at nitro speed.** Top nitro speed is 15000 units/s, or 250 per tick, and segments are 200 units long. Pickups and traffic collisions only check the segment under the car, so pickups get missed and traffic can be passed through. Check every segment crossed this tick. | `scripts/race/power_ups.gd:86-91`, `scripts/car/player_car.gd:184,202` |
| G2 | Med | **Fixed (phase 1)** | **A bump moves `position` but not `distance`.** Checkpoints, the finish and the HUD progress bar read `distance`, so they drift up to about 200 units from the drawn gates after each bump. | `player_car.gd:215` vs `:102-103`; `race.gd:224,228` |
| G3 | Low | **Fixed (RC-9)** | **A side-swipe is treated as a rear-end.** `collide` doesn't check which car is ahead within the segment. Steering into a slower car alongside snaps you behind it or crashes you. | `player_car.gd:202-216` |
| G4 | Low | **Fixed (RC-9)** | **Rammed cars never come back onto the road.** They stay at offset ±4 and become solid again after 0.8 s. A player far off-road can then crash into them. | `scripts/car/traffic.gd:59-61`, `player_car.gd:203` |
| G5 | Low | **Fixed (phase 1)** | **Auto gas can drop new input fields.** `Settings.drive_input` copies a hand-written list of `DriveInput` fields, so a field added later is silently lost when auto gas is on. | `scripts/core/settings.gd:73-75` |
| G6 | Low | Confirmed | **A missing traffic sprite crashes the game.** The loader only warns, but `Traffic.spawn` indexes the sprite table directly. `PowerUps.texture` caches a null. Tests check the files exist today, so this is low risk. | `traffic.gd:51`, `car_sprites.gd:78`, `power_ups.gd:100-103` |

### UI and flow

| # | Sev | Status | Bug | Where |
|---|---|---|---|---|
| U1 | Med | **Fixed (phase 1)** | **The F1 input overlay opened in the menus stays up for the whole race.** `start_race` never hides it. The race also builds a second overlay and calibration wizard of its own. | `scripts/core/game.gd:26-32,58,90`; `race.gd:67-70` |
| U2 | Low | **Fixed (phase 3)** | **Dev flags are reparsed every race.** After `--stage=3`, quitting to the menu and picking another stage still gives stage 3. `_frame` isn't reset on restart, which shifts the autodrive's nitro timing. Screenshot names can be off by one because `_frame` is read after an `await`. | `race.gd:53,74,260-277,285,315-319` |

### Tests and docs

| # | Sev | Status | Bug | Where |
|---|---|---|---|---|
| T1 | Low | **Fixed (phase 1)** | **The span "opening is wider than the road" test always passes.** `world_w` is derived from the opening, so the check can't fail. `find_opening` also returns a 1-px opening if the middle pixel is opaque, which makes the span enormous. Test the opening as a fraction of the image width instead. | `tests/test_spans.gd:12-19`, `scripts/track/sprite_library.gd:245-270` |
| T2 | Low | **Fixed (phase 4)** | **The golden traces don't record power-up state.** They skip the ram and ghost timers, which pickups were taken, and traffic offsets, so power-up regressions pass. | `tests/golden.gd:42-49` |
| T3 | Low | **Fixed (phase 4)** | **The technical design doc is stale.** It still says Skyline is held back, the garage is Vega-only and spans are skipped. It says nothing about power-ups, tuning, drive-throughs or traffic specials. | `docs/02-technical-design.md:318-321` |
| T4 | Low | **Fixed (phase 1)** | **Leftovers.** A duplicate `_dir = ROADSIDE + "harvest/"` line, a tracked `tests/probe.gd.uid` with no script, and nine race-furniture sprites that are loaded but never placed (tire stack, barrels, cone, barricade, barrier, delineator, inflatable arch, green and brown signs). | `sprite_library.gd:130,132` |

## Refactor and cleanup plan

The code is in decent shape: no script is over about 320 lines and there are no TODO, FIXME or
HACK markers. The cost is duplication, a few shared-state shortcuts, and magic numbers. The phases
are ordered cheapest and most valuable first. Each is one PR, and golden traces stay unchanged
unless the phase says it changes play.

### Phase 1: quick fixes (one small PR, play changes)

1. Fix G1: walk every segment between the last and current position for pickups and traffic.
2. Fix G2: apply the bump to `distance` as well. Add tests for both. Regenerate the golden traces and give the reason in the commit.
3. Fix U1: `game.gd` owns the only overlay and wizard and hides them on `start_race`. The race reuses them.
4. Add `DriveInput.copy()` and use it in `Settings.drive_input` (G5).
5. Delete the leftovers (T4) and either place the nine unused sprites or drop them.
6. Fix the T1 test and bring `docs/02-technical-design.md` up to date (T3).

### Phase 2: a shared sprite library for the Python tools (no game changes)

- Add `tools/spritelib.py` with one copy each of `key_sheet` (today's `key_car_sheet`, used by every tool that keys a generated sheet), `components`, `mask_crop`, `pixelate_down` and `make_background`. Today:
  - `components` and `label_components` are near-duplicates.
  - `make_background` is copied word for word.
  - The crop-masking loop is written three times.
- Rewrite the per-pixel loops with numpy, or PIL `point` and `ImageChops`. A full car rebuild takes about 90 s today and should take a few seconds.
- Move the Palm Coast palms and backdrop into `make_stage_sprites.STAGES` and rename what is left of `make_placeholder_sprites.py` (six hand-drawn props) to say so. Stop `make_powerup_sprites.py` importing from `make_stage_sprites.py`.
- Have the tools write a JSON manifest of sprite names, world heights and collide fractions that the game loads. This replaces the hand-kept copies in `CarSprites.CAR_SHEET_IDS` and `BIG_SHEET_IDS` and in `sprite_library.gd`.
- Fix A3 and A2 here: grow the fringe pass to two pixels for pixels near the key hue, and add a despill step that pulls magenta out of edge pixels. Then reroll or recolor the glass for A1.

### Phase 3: GDScript structure (behavior-neutral, golden traces unchanged)

- Add a `Track.finish_stage()` helper for the start flag, checkpoints and finish that all eight stage files repeat.
- Move the copied `_text` and `_text_centered` helpers in `hud.gd`, `menu_screen.gd` and `calibration_wizard.gd` into one helper. Move the wheel-hint code shared by `game.gd` and `race.gd` into `InputRouter`.
- Clear up ownership:
  - The renderer should stop writing `_covered` into the stage's theme dict.
  - The race sets `InputRouter.speed_factor` but never resets it.
  - The current player car lives in global static `CarSprites.player_strips`; pass it explicitly.
- Move magic numbers into `Cfg`:
  - crash, bump and collision factors in `player_car.gd`
  - camera shake in `race.gd`
  - traffic speed and mix in `traffic.gd`
  - the three different "low time" thresholds (10, 10, 12) in `hud.gd`, `race_audio.gd` and `power_ups.gd`
- Parse dev flags once at boot, not per race, and reset `_frame` on restart (U2).

### Phase 4: tests

- Extend the golden snapshot with power-up state and traffic offsets (T2), and regenerate it as its own commit.
- Add tests for:
  - picking up at nitro speed
  - `distance` after a bump
  - the overlay across the menus and the race
  - a span with a bad opening
  - auto gas copying every field
- Derive `Golden.STAGE_PREFIXES` from `Stages`.
- Later gameplay fixes (G3, G4, A4) go in after this, so the stronger golden traces catch their side effects.
