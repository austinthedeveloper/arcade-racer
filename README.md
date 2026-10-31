# SUNDOWN RUN (working title)

An original sprite-based, pseudo-3D arcade road racer built in Godot 4. Supports keyboard, gamepads, and steering wheels with pedals.

**Status:** Milestone 1 prototype. Seven stages are drivable back to back (Palm Coast Boulevard, Redrock Canyon, Neon Strip, Timberline Pass, Bayou Causeway, Harvest Valley, Thunderhead Highway), with traffic, checkpoints, a timer, nitro, jumps and crashes, with generated placeholder sound and music. The game opens on a title screen, then stage select (pick where the tour starts) and car select (just the Vega GT for now). Finish a stage and press Enter to go on to the next; after the last one the tour starts over. The art is placeholder: the backgrounds, roadside sprites and cars are cut from the concept art (the player drives the Vega).

## Running it

1. Install **Godot 4.7** (standard build, not .NET).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the Play button).

## Controls

| Action | Keyboard | Gamepad | Wheel |
|---|---|---|---|
| Steer | Left / Right or A / D | Left stick or D-pad | Wheel |
| Gas | Up or W | Right trigger or A | Gas pedal |
| Brake | Down or S | Left trigger, B or X | Brake pedal |
| Nitro (3 per race) | Space or Shift | RB or Y | Button picked during calibration |
| Pause menu (resume, restart, options, quit to title) | Esc or P | Start | |
| Restart the stage | R | Back | |
| Next stage (after a finish; Single Race: back to the menus) | Enter | A | |
| Pause menu: choose / select / resume | Up, Down / Enter / Esc or Backspace | D-pad / A / B or Start | Steer / gas pedal / brake pedal |
| Input debug overlay | F1 | | |
| Calibrate wheel | F2 | | |

### Menus

Menus go left and right only, so every device can drive them:

| Menu action | Keyboard | Gamepad | Wheel |
|---|---|---|---|
| Choose | Left / Right or A / D | Left stick or D-pad | Turn the wheel |
| Select / start | Enter | A or Start | Gas pedal or any wheel button |
| Back | Esc or Backspace | B or Back | Brake pedal |

### Options

Pick **OPTIONS** on the title screen. Options are saved to `user://settings.cfg` as soon as they change.

| Option | What it does |
|---|---|
| Auto gas | The car keeps the gas down, so a young player only has to steer. The brake still works (and lifts the gas while held). |
| Traffic | Light, normal or heavy traffic. |
| Timer | Relaxed (more time per checkpoint), Arcade (as tuned) or Tight. |
| Music / sound FX volume | 0 to 10. |
| Calibrate wheel | Opens the wheel calibration (same as F2). |

On the keyboard and gamepad, Up / Down picks a row and Left / Right changes it; Enter / A also toggles or cycles it. A wheel has no up and down, so there you turn the wheel to pick a row and press the gas to change it. Brake goes back.

### Using a wheel

The game spots most wheels by name and asks you to calibrate. Press **F2** and follow the steps: rest, full left, full right, gas, brake, nitro button. It works out which axis is which, and handles inverted, 0..1 and combined pedal axes. The profile is saved per device in `user://input_profiles.cfg`.

Until the wheel is calibrated, only its steering is used. **F1** shows every raw axis and button, which helps when something doesn't respond. There is no force feedback yet, so turn on your wheel software's centering spring for games without FFB (for example in Logitech G HUB or the Thrustmaster Control Panel).

Steering lock defaults to using 360 of the wheel's 900 degrees. You can change `hardware_range_deg` and `lock_deg` in the profile file (they aren't on the Options screen yet).

## Project layout

```
scripts/
  core/cfg.gd               tuning constants (camera, speeds, physics)
  track/                    segment + track builder, sprite library, stages/
  render/                   road renderer, background, car sprites
  car/                      player driving model, traffic
  input/                    InputRouter autoload, device profiles, DriveInput
  core/game.gd              main scene: title, stage select, car select, then the race
  race/race.gd              race flow: countdown, checkpoints, timer, finish
  ui/                       menu screens, HUD, input debug overlay, calibration wizard
  audio/                    Audio autoload, SoundBank (cue -> file), RaceAudio (race -> cues)
assets/sprites/             in-game sprites (placeholders for now)
assets/audio/               generated placeholder sounds and music (how to swap: its README)
tests/                      test runner, suites, golden traces, end-to-end smoke
tools/                      test.sh, sprite-cutting scripts, make_audio.py (placeholder sound)
```

For a test drive without input, run `godot --path . -- --autodrive`. `--stage=N` starts on stage N (2 is Redrock Canyon), `--no-traffic` removes traffic, and `--screenshots=60,300 --shot-dir=/tmp/shots` saves frames. These flags (and `--race`) skip the menus. `--screen=title|options|stages|cars --menu-shot=/tmp/stages.png` saves a screenshot of a menu and quits.

## Tests

```sh
tools/test.sh                  # every suite, then the end-to-end input smoke
tools/test.sh test_race        # only tests whose name contains "test_race"
```

`test.sh` runs `godot` from your PATH; set `GODOT=/path/to/Godot` to use another binary. The tests cover wheel and pedal normalization, calibration, menu input and the menu flow, options, the driving model, traffic, race flow and renderer regressions. The end-to-end smoke boots the game on the title screen, changes some options, and goes through stage and car select into the race (and later into a second race with auto gas on). `tests/golden/` holds frame-by-frame traces of autodriven races (Palm Coast with and without traffic, every other stage with traffic). If you change gameplay on purpose, regenerate them with `godot --headless --path . -s res://tests/golden.gd`. CI runs the same script on every push.

## Releases

`tools/export.sh [version]` builds Windows, macOS (universal) and Web into `build/release/SundownRun-<version>-<platform>.zip`. It needs the Godot 4.7.2 export templates (Editor > Manage Export Templates). The presets are in `export_presets.cfg`.

To publish, bump `config/version` in `project.godot`, then push a tag:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

`.github/workflows/release.yml` runs the tests, exports the three builds and creates the GitHub Release with the zips and download notes. Running the workflow by hand (Actions > Release > Run workflow) builds the zips as a workflow artifact without publishing. The builds are not code-signed or notarized, so Windows SmartScreen and macOS Gatekeeper warn on first launch; the release notes say how to get past that.

## Docs

- [Game design](docs/01-game-design.md): modes, driving feel, cars, stages, scope
- [Technical design](docs/02-technical-design.md): Godot setup, pseudo-3D road renderer, game logic, wheel/pedal input, milestones
- [Art direction](docs/03-art-direction.md): style options, sprite specs, palettes, UI
- [Open questions](docs/04-open-questions.md): decisions needed before we build
- [Concept review, round 1](docs/05-concept-review-round1.md)
- [Concept review, round 2](docs/06-concept-review-round2.md)
- [Art prompts, round 4](docs/07-art-prompts-round4.md)
- [Concept review, round 4](docs/08-concept-review-round4.md)
- [Known bugs and cleanup plan](docs/09-known-bugs-and-cleanup.md)
- [Roadmap, November 2026 to April 2027](docs/roadmap/00-overview.md): the six-month feature list, split into eight group docs

## Concept art prompts

See [assets/README.md](assets/README.md).
