# Sundown Run (working title)

Original sprite-based pseudo-3D arcade racer in Godot 4.7 (GL Compatibility, 640x360).
Design docs are in `docs/`, concept art prompts in `assets/prompts/`.

```sh
tools/test.sh                                       # all Godot tests, headless (must pass)
tools/test.sh test_player_car                       # one suite (filter on suite.test names; skips the e2e)
godot --path .                                      # play
godot --path . -- --autodrive --screenshots=200,700 --shot-dir=/tmp/shots   # hands-off run with screenshots
godot --headless --path . -s res://tests/golden.gd  # regenerate golden traces (play changes only)
python3 tools/make_car_sprites.py <concept_dir> .   # rebuild car sprites from the concept sheets
python3 tools/make_audio.py                         # rebuild the placeholder sounds (assets/audio/README.md)
```

## Tests

No addon. `tests/run_tests.gd` runs every `tests/test_*.gd` (methods named `test_*`, on a
`TestSuite`, see `tests/suite.gd`). `tests/e2e_input.gd` boots the real main scene and drives
it through the input map. `tests/golden/` holds per-frame traces of two autodriven races
(with traffic and on a clear road); `test_golden` replays them and also checks the
autodriven race finishes in time. CI (`.github/workflows/ci.yml`) runs `tools/test.sh`.

- Add or extend tests with every change.
- Tests never touch the player's wheel profiles (`TestSuite.use_scratch_profiles`).
- Logic that a test needs to reach goes in a plain function (see `RoadRenderer.sprite_rect`,
  `CarSprites.steer_frame`, `CalibrationWizard.capture`), not inside `_draw` or `_process`.

## Before finishing a change

1. `tools/test.sh` passes. Golden traces stay unchanged unless the change is meant to alter
   play; regenerate them and give the reason in the commit.
2. Look at a screenshot of anything visual.

## Git

Work on a `feature/CLD-<name>` branch, never on main. Austin merges.
