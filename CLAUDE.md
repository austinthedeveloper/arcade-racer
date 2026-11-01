# Sundown Run (working title)

Original sprite-based pseudo-3D arcade racer in Godot 4.7 (GL Compatibility, 640x360).
Design docs are in `docs/`, the six-month roadmap in `docs/roadmap/` (feature IDs like RC-1), concept art prompts in `assets/prompts/`.
Adding a car, prop, traffic vehicle, span or stage: art and Claude prompt templates in `docs/templates/`.

```sh
tools/test.sh                                       # all Godot tests, headless (must pass)
tools/test.sh test_player_car                       # one suite (filter on suite.test names; skips the e2e)
godot --path .                                      # play
godot --path . -- --autodrive --screenshots=200,700 --shot-dir=/tmp/shots   # hands-off run with screenshots (race flags skip the menus)
godot --path . -- --autodrive --stage=3 --at-segment=850 --car=car_mesa --screenshots=300 --shot-dir=/tmp/shots   # start partway in, in another car
godot --path . -- --autodrive --callout=near_miss --screenshots=300 --shot-dir=/tmp/shots   # hold a starburst callout up after GO (Callouts.IDS); --time-left=9 for the low clock
godot --path . -- --autodrive --stage=7 --at-segment=300 --lightning-at=5 --screenshots=303 --shot-dir=/tmp/shots   # force a full lightning strike on Thunderhead at 5 s
godot --path . -- --autodrive --stage=2 --mirror --screenshots=300 --shot-dir=/tmp/shots   # race the stage mirrored (WS-6), locked or not
godot --path . -- --save-file=/tmp/save.cfg --mode=single_race --mirror --screen=stages --menu-shot=/tmp/s.png   # stage select on another save, in a mode (ModeSelect.Item), MIRROR on
python3 tools/colorblind.py /tmp/shots/frame_00300.png --all   # the shot as seen with protanopia, deuteranopia, tritanopia (+ a sheet)
godot --path . -- --screen=stages --menu-shot=/tmp/stages.png   # screenshot a menu (title, modes, options, stages, cars, pause, unplugged, results, demo, update (update:failed etc.); options:audio etc. for an options page; --car=car_mesa opens car select on it)
godot --path . --resolution 1600x900 -- --settings-file=/tmp/opts.cfg --profiles-file=/tmp/prof.cfg --screen=options:display --shot-as-window --menu-shot=/tmp/d.png   # other options and binding files; the shot laid out as the window shows it (also --screen=remap, --screen=wheel, and race --screenshots)
godot --headless --path . -s res://tests/golden.gd  # regenerate golden traces (play changes only)
godot --headless --path . -s res://tools/track_preview.gd -- --out=/tmp/plots   # plot every stage top-down and side-on to PNG (--stage=N for one)
tools/shots.sh                                      # screenshot regression vs tests/shots/ (needs a display, PIL; SHOTS_PYTHON=...)
tools/shots.sh --update                             # rewrite tests/shots/ after a deliberate visual change
tools/car_angles.sh [--car=car_mesa]                # every car x steering frame x slope on the road -> build/car_angles/car_angles.html (needs a display, PIL)
python3 tools/roadmap_sync.py [--fix-board --write-docs]   # docs/roadmap vs GitHub issues and project 4; fixes board status, ticks rows
python3 tools/make_car_sprites.py <concept_dir> .   # rebuild car sprites from the concept sheets
python3 tools/make_stage_sprites.py assets/concept . neon      # rebuild a stage's background + roadside sprites (shared: race furniture)
python3 tools/make_ui_sprites.py assets/concept .   # rebuild the logo, title backdrop, stage postcards, car pictures
python3 tools/make_icon.py assets/concept .         # rebuild the game icon (icon.png, icon.ico, icon.icns)
python3 tools/make_span_sprites.py assets/concept . # rebuild tunnels, bridges, arches and race gates
python3 tools/make_powerup_sprites.py assets/concept .   # rebuild the power-up pickups, icons and effects
python3 tools/make_fx_sprites.py assets/concept .      # rebuild the FX layer's smoke, kick-up, sparks, nitro, speed lines, fireworks
python3 tools/make_drawn_props.py .                 # redraw Palm Coast's six hand-drawn props
python3 tools/manifest.py .                         # rewrite assets/sprites/manifest.json after editing a world height or collide fraction
python3 tools/make_audio.py                         # rebuild the placeholder sounds (assets/audio/README.md)
tools/export.sh 0.1.0                               # Windows/macOS/Web zips in build/release (needs export templates)
```

The sprite tools share `tools/spritelib.py` and need `pip install -r tools/requirements.txt`. Their
specs (`STAGES`, `TRAFFIC`, `SPANS`, `DRAWN`) are the source of each sprite's world height, collide
fraction and scale; every tool rewrites `assets/sprites/manifest.json`, which the game loads.

## Tests

No addon. `tests/run_tests.gd` runs every `tests/test_*.gd` (methods named `test_*`, on a
`TestSuite`, see `tests/suite.gd`). `tests/e2e_input.gd` boots the real main scene (title screen) and drives
it through the input map: menus, then the race. The race itself is `scenes/race.tscn`. `tests/golden/` holds per-frame traces of autodriven races
(Palm Coast with traffic and rivals and on a clear road with neither, every other stage with traffic and rivals, default options so power-ups on); `test_golden` replays them
and also checks every stage's autodriven race finishes in time and every rival finishes, and that each stage run mirrored (WS-6) gives its trace again once mirrored back (`Golden.snapshot` takes x times `Track.side`), so anything placed across the road must go by `Track.side` / `Traffic.lanes`. `--no-rivals` and `--no-traffic` empty the road for screenshots. `tools/shots.sh` renders five menus (the update screen staged mid-download) and two race frames at a fixed 60 fps and compares them with
`tests/shots/` (`tools/shots.py`: a difference hash plus a color difference). CI (`.github/workflows/ci.yml`) runs `tools/test.sh`, and `tools/shots.sh` under xvfb. A pushed `v*` tag runs
`.github/workflows/release.yml`: tests, `tools/export.sh`, then a GitHub Release with the zips.

- Add or extend tests with every change.
- Tests never touch the player's wheel profiles or options (`TestSuite.use_scratch_profiles`,
  `TestSuite.use_scratch_settings`). Golden traces run on the default options.
- Logic that a test needs to reach goes in a plain function (see `RoadRenderer.sprite_rect`,
  `CarSprites.steer_frame`, `CalibrationWizard.capture`), not inside `_draw` or `_process`.

## Before finishing a change

1. `tools/test.sh` passes. Golden traces stay unchanged unless the change is meant to alter
   play; regenerate them and give the reason in the commit.
2. Look at a screenshot of anything visual. `tools/shots.sh` passes; after a deliberate visual
   change, `tools/shots.sh --update`, look at the new `tests/shots/` images and say why in the commit.

## Git

Work on a `feature/CLD-<name>` branch, never on main. Austin merges.
