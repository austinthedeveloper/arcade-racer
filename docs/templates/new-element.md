# New element: Claude prompt

Art first: `assets/prompts/templates/element.md`. When the sheet is in `assets/concept/...`,
fill the brackets of the matching section and paste the box into Claude Code. Each box starts
with the same preamble.

Preamble (paste first):
```text
Read CLAUDE.md first and work on a feature/CLD-<name> branch. Sprite tools need the PIL venv
(pip install -r tools/requirements.txt). After building, run godot --headless --path . --import,
then tools/test.sh, look at a screenshot of the element in a race, and run tools/shots.sh.
Commit only the new sprites and the manifest lines for them; if a tool rewrote other sprites
(a different Pillow version), git checkout them. Commit on the branch; don't merge.
```

## Roadside props

```text
Add roadside props from assets/concept/roadside/<sheet>_A_v1.png to <stage>.
Objects in reading order (rows top to bottom, left to right), name / world height / collide:
  <name_a> <world_h> <collide>, <name_b> ..., (None for one to skip)
Placement: <e.g. every 15 segments both sides in the open stretches; one-offs via scatter>

1. tools/make_stage_sprites.py: append (sheet, texture height, [(name, world_h, collide), ...])
   to STAGES["<key>"]["sheets"] (keys: palm_coast, redrock, neon, timberline, bayou, harvest,
   thunder, skyline, shared). Texture height: 60 small props to 220 big buildings; tallest object
   on the sheet gets it. Add "row" as a fourth item only for one row of overlapping objects.
   Names are global (the manifest is keyed by name): grep assets/sprites/manifest.json first.
2. python3 tools/make_stage_sprites.py assets/concept . <key>
   It exits with "found N objects, expected M" if the sheet and the list disagree: look at
   the sheet and fix the list (None for strays), don't edit the art.
3. Place them in scripts/track/stages/<stage>.gd: in _decorate (seeded rng, `i % k` spacing,
   t.add_sprite(i, id, offset, flip), offset in road half-widths, |offset| >= 1.0 is tested, 1.05+ looks right) or
   t.scatter([...], first, every, offset) for one-offs. Every sprite the tool builds must be
   placed somewhere (tests/test_track.gd test_every_loaded_sprite_is_placed).
4. Tests: add the ids to the stage's landmarks test in tests/test_track.gd (test_redrock_has_its_landmarks, test_harvest_has_its_farm, ...).
5. Golden traces: decoration should leave them unchanged. If a stage's trace changes, a car is
   hitting a new prop: move it out or lower its collide; regenerate only if the change is wanted,
   with the reason in the commit.
6. Look: godot --path . -- --autodrive --stage=<n> --at-segment=<where it is> --no-traffic --no-rivals --screenshots=120 --shot-dir=/tmp/shots
   Check size against the car and the road, bottom on the ground, no magenta fringe.
```

## Traffic vehicles

```text
Add traffic vehicles from assets/concept/traffic/<trfNN_group>_A_v1.png.
Vehicles left to right: <name_a>, <name_b>, ... (None to skip one). Kind: <cars | big>.
Use: <stage specials for <stage> | Traffic.CARS | Traffic.BIG>

1. tools/make_car_sprites.py: append to TRAFFIC
   ("<sheet>", TRAFFIC_CAR_WIDTH, CAR_SCALE, [names]) for cars or
   ("<sheet>", TRAFFIC_BIG_WIDTH, BIG_SCALE, [names]) for trucks and buses.
   A front-view sheet of the same vehicles goes in FRONTS (only vehicles with a front view
   come the other way on undivided roads, RC-11). A car in Traffic.CARS signals before changing
   lanes only with signal frames: add it to SIGNALLERS (its taillights lit amber; TAIL_BOX if
   its body is red or yellow) and check the lights/ frames.
2. python3 tools/make_car_sprites.py assets/concept .  (rebuilds all cars and traffic; it prints
   "warning: ... has N sprites, expected M" when the count is off: fix the names list)
3. Use them: a stage's theme() "specials" list (scripts/track/stages/<stage>.gd), or
   Traffic.CARS / Traffic.BIG / Traffic.SPECIALS in scripts/car/traffic.gd.
4. Tests: tests/test_traffic.gd test_every_traffic_sprite_exists covers the lists and the
   specials; tests/test_render.gd test_every_manifest_sprite_loads covers the manifest. Add a
   check that the stage's traffic includes them if it's a special (see
   test_stage_locals_show_up_in_traffic).
5. Golden traces change for every stage whose traffic mix changes (all of them for
   Traffic.CARS / BIG). Regenerate: godot --headless --path . -s res://tests/golden.gd, reason in
   the commit ("<names> join <stage> traffic").
6. Look: godot --path . -- --autodrive --stage=<n> --no-rivals --screenshots=300,900 --shot-dir=/tmp/shots
   Check the size next to existing traffic and the player car.
```

## Road-spanning piece (arch, bridge, overpass, tunnel, gate)

```text
Add a road-spanning piece from assets/concept/roadside/<dt_file>_A_v1.png as "<span_id>" on <stage>.
Kind: <arch/gate (one sprite) | tunnel or covered bridge (entrance + ring <dt_ring_file>)>
Where: <fractions of the stage, e.g. [0.3, 0.62], or "a tunnel of 45 segments after the canyon">

1. tools/make_span_sprites.py: add "<span_id>": ("<file>", {...}) to SPANS. Look options:
   "fill" (hex color beside/above it; needed for a ring), "ceiling": True for a ring,
   "banner": [x, y, w, h] fractions where gate text goes. For a tunnel also add
   "<span_id>_ring" with {"fill": ..., "ceiling": True}.
2. python3 tools/make_span_sprites.py assets/concept .
   Check the output in assets/sprites/spans/: the road opening must reach the bottom row
   through the middle (SpriteLibrary.find_opening reads the row 90% down; no opening = a
   "has no opening at the bottom" warning and the span is dropped).
3. Place it in the stage's build(), before t.add_road_signs() and t.add_race_furniture():
   t.add_spans_at("<span_id>", [fractions])  (finds free spots clear of gates), or
   t.add_tunnel(t.free_spot(<segment>, 50), <length>, "<span_id>", "<span_id>_ring", 3).
   For a tunnel, a theme "tunnel_lights": [Color, Color] adds wall tubes (Neon Strip).
4. Tests: tests/test_spans.gd test_every_span_loads_with_an_opening_that_fits_the_road covers
   loading; if this is the stage's signature piece, add it to the want list in
   test_every_stage_has_its_drive_through_pieces.
5. Golden traces: span legs stand off the road, so usually unchanged; a tunnel clears the
   roadside in it and can change the trace. Regenerate only with a reason.
6. Look: --stage=<n> --at-segment=<a few segments before it> --no-traffic --no-rivals
   --screenshots=60,120 --autodrive, and check the road runs through the opening.
```

## Power-up art (existing kinds)

```text
Rebuild power-up art from assets/concept/powerups/<file>_A_v1.png.
Pieces in reading order: <pickup_nitro, ...> (None to skip).

1. tools/make_powerup_sprites.py: replace or add the entry in SHEETS (sheet, texture height:
   72 pickups / 30 icons / 96 effects, [names]). Names the game loads: pickup_<kind>,
   pickup_mystery_1..3, icon_<kind>, icon_slot, fx_sparkle, fx_ram, fx_clock, reveal_1..4
   (kinds: PowerUps.IDS in scripts/race/power_ups.gd).
2. python3 tools/make_powerup_sprites.py assets/concept .
3. tests/test_power_ups.gd must pass; golden traces unchanged (art only).
4. Look: a race on default options, screenshots where pickups are on the road, and the HUD slot.
```

A **new power-up kind** is gameplay, not art: it needs a new entry in `PowerUps.IDS` with
matching `ROAD_WEIGHTS` and `MYSTERY_WEIGHTS`, its effect in `scripts/race/power_ups.gd` and
the race, `Hud` icon handling, tests in `tests/test_power_ups.gd`, and regenerated golden
traces. Write it up as a roadmap story first.

## Checklist

- [ ] Tool spec updated (`STAGES` / `TRAFFIC` / `SPANS` / `SHEETS`); names unique
- [ ] Tool run; only the new sprites and their manifest lines in the diff
- [ ] Placed in a stage (props and spans) or a traffic list
- [ ] Test extended; `tools/test.sh` passes
- [ ] Golden traces unchanged, or regenerated with a reason
- [ ] Screenshot looked at; `tools/shots.sh` passes
