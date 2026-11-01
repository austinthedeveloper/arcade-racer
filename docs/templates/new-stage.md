# New stage: Claude prompt

Art first: `assets/prompts/templates/stage.md`. When the composite, roadside sheets and span
are in `assets/concept/`, fill the brackets and paste the box into Claude Code. The stage goes
**before Skyline Finale**, which stays the last stage (its fireworks, the tour finish and
several tests assume it).

```text
Add a new stage to Sundown Run. Read CLAUDE.md, scripts/track/track.gd and
scripts/track/stages/redrock.gd first, and work on a feature/CLD-stage-<slug> branch.

Stage:
- slug: <slug>   class_name: <ClassName>   name: <Display Name>
- mood / palette: <from the art brief>
- layout: <sections in order, e.g. "open desert with crests; a canyon of tight bends and bumps; a diner stop; a long downhill run to the finish">
- signature extra: <object name>   span: <span_id>
- traffic: specials <[ids]>, count <70 default, 80-95 for a busy city>
- kickup off grass / sand: <two of smoke, dust, sand, snow, water>
Art:
- assets/concept/backgrounds/<slug>_composite_A_v1.png
- assets/concept/roadside/<slug>_<group>_A_v1.png sheets, each with its objects in reading
  order: <name world_h collide, ...>
- assets/concept/roadside/<slug>_road_colors_A_v1.png (pick theme colors from it)
- assets/concept/roadside/dt_<slug>_<thing>_A_v1.png (+ ring for a tunnel)

Do this:
1. Sprites (PIL venv, tools/requirements.txt):
   - tools/make_stage_sprites.py: add STAGES["<slug>"] = {"background": ("<slug>_composite_A_v1.png",
     <horizon row>), "sheets": [...]}, like "redrock". The horizon row is the first row of flat
     ground under the skyline (existing ones: 560 to 706 of 821); find it by looking at the image.
     Sprite names must not clash with any in assets/sprites/manifest.json.
   - tools/make_span_sprites.py: add the span to SPANS (see docs/templates/new-element.md).
   - tools/make_ui_sprites.py: add "<slug>" to STAGES before "skyline" (the postcard).
   - Run: python3 tools/make_stage_sprites.py assets/concept . <slug>
          python3 tools/make_span_sprites.py assets/concept .
          python3 tools/make_ui_sprites.py assets/concept .
     Commit only the new files (backgrounds/<slug>_far.png, roadside/<slug>/, spans/<span_id>.png,
     ui/postcard_<slug>.png) and the manifest lines; git checkout anything else they rewrote.
2. scripts/track/stages/<slug>.gd, modeled on redrock.gd:
   - class_name <ClassName>, a ## doc line "Stage 8: <Display Name>. ..."
   - static func theme() with: sky_top, sky_bottom, fog, below_horizon, grass [2], sand [2],
     kickup [2], rumble [2], road [2], lane, clock [start, cp1, cp2, cp3] (placeholder
     [45, 25, 25, 25] until step 6), background "res://assets/sprites/backgrounds/<slug>_far.png",
     specials, and optionally traffic, fog_density (default Cfg.FOG_DENSITY), tunnel_lights.
     sky_top, grass[0] and the background must differ from every other stage.
   - static func build() -> Track: t.name = "<Display Name>", t.theme = theme(), the layout from
     Track pieces (set_ground, straight, curve, hill, low_rolling_hills, s_curves, bumps, jump,
     downhill_to_end with LENGTH_*, CURVE_*, HILL_* constants), more than 1000 segments, ending
     var final_straight := t.segments.size(); t.straight(Track.LENGTH_LONG); t.finish_stage(final_straight).
     Then _decorate(t, ...) with a seeded RandomNumberGenerator, the span (add_spans_at or
     add_tunnel), t.scatter([... the extras ...], 200, 450, 1.7), t.add_road_signs(),
     t.add_race_furniture(), t.add_finish_crowd(), in that order. Place every sprite the tool built.
   - godot --headless --path . --import (registers the new class_name).
3. scripts/track/stages/stages.gd: insert at index 7 (before Skyline) in NAMES and POSTCARDS
   ("<slug>"), and in build()'s match (7 -> <ClassName>.build(), Skyline moves to 8). Renumber
   the "## Stage 8: Skyline Finale" doc line in skyline.gd to 9.
4. scripts/ui/stage_select.gd: THUMB and THUMB_GAP lay out 8 thumbnails across 640 px; nine
   overflow. Shrink them so Stages.count() thumbs fit, and check --screen=stages.
5. Tests:
   - tests/test_track.gd: test_stage_order_and_names (count and the name list),
     test_every_stage_has_its_extras_and_a_finish_crowd (insert the signature extra at index 7),
     and a new test_<slug>_has_its_landmarks like test_redrock_has_its_landmarks.
   - tests/test_spans.gd test_every_stage_has_its_drive_through_pieces: append the span to want.
   - tests/test_golden.gd test_every_stage_has_a_golden_scenario: Skyline is now stage_of 8.
   - tests/golden.gd: add "<slug>_autodrive_traffic" to SCENARIOS.
6. Golden trace and clock: godot --headless --path . -s res://tests/golden.gd. Only
   tests/golden/<slug>_autodrive_traffic.txt may be new; every existing trace must be unchanged
   (git diff --stat tests/golden). Set the clock the WS-11 way: from the new trace's event
   lines, the seconds from GO! to each CHECKPOINT! and to FINISH! (frames / 60), times 1.3,
   rounded. Put them in theme()["clock"], regenerate the trace, and give the numbers in the commit.
7. tools/test.sh (test_autodriven_race_finishes_in_time checks a 60 to 120 s autodriven race and
   every rival finishing).
8. Look:
     godot --headless --path . -s res://tools/track_preview.gd -- --out=/tmp/plots --stage=8
     godot --path . -- --autodrive --stage=8 --screenshots=200,1500,3000,4500 --shot-dir=/tmp/shots
     godot --path . -- --screen=stages --menu-shot=/tmp/stages.png
   Check the horizon sits on the road's horizon, sprites are sized like other stages', the span
   frames the road, the postcard reads.
9. tools/shots.sh: menu_stages changes (a ninth thumbnail). Look at it, tools/shots.sh --update,
   and say why in the commit. race_palm and race_stage3 must not change.
10. Note in the commit: saves store the furthest stage by index, so a save that had reached
    Skyline now shows <Display Name> as its furthest. Add the stage to the palette table in
    docs/03-art-direction.md section 6.
Commit on the branch; don't merge.
```

## Checklist

- [ ] `STAGES` (stage tool), `SPANS`, `STAGES` (ui tool) updated; tools run; only new files committed
- [ ] `scripts/track/stages/<slug>.gd` with `theme()`, `build()`, `_decorate`; every built sprite placed
- [ ] `Stages.NAMES`, `Stages.POSTCARDS`, `Stages.build` updated, Skyline still last
- [ ] Stage select thumbnails fit
- [ ] Tests extended; new golden scenario; old traces unchanged
- [ ] Clock set from the trace (x1.3), numbers in the commit
- [ ] Track plot and race screenshots looked at; `tools/shots.sh` updated with a reason
