# SUNDOWN RUN (working title)

An original sprite-based, pseudo-3D arcade road racer built in Godot 4. Supports keyboard, gamepads, and steering wheels with pedals.

**Status:** Milestone 1 prototype. Two stages are drivable back to back, Palm Coast Boulevard and then Redrock Canyon, with traffic, checkpoints, a timer, nitro, jumps and crashes, with generated placeholder sound and music. Finish a stage and press Enter to go on to the next; after the last one the tour starts over. The art is placeholder: the backgrounds, roadside sprites and cars are cut from the concept art (the player drives the Vega).

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
| Pause | Esc or P | Start | |
| Restart the stage | R | Back | |
| Next stage (after a finish) | Enter | A | |
| Input debug overlay | F1 | | |
| Calibrate wheel | F2 | | |

### Using a wheel

The game spots most wheels by name and asks you to calibrate. Press **F2** and follow the steps: rest, full left, full right, gas, brake, nitro button. It works out which axis is which, and handles inverted, 0..1 and combined pedal axes. The profile is saved per device in `user://input_profiles.cfg`.

Until the wheel is calibrated, only its steering is used. **F1** shows every raw axis and button, which helps when something doesn't respond. There is no force feedback yet, so turn on your wheel software's centering spring for games without FFB (for example in Logitech G HUB or the Thrustmaster Control Panel).

Steering lock defaults to using 360 of the wheel's 900 degrees. You can change `hardware_range_deg` and `lock_deg` in the profile file until there's an options screen.

## Project layout

```
scripts/
  core/cfg.gd               tuning constants (camera, speeds, physics)
  track/                    segment + track builder, sprite library, stages/
  render/                   road renderer, background, car sprites
  car/                      player driving model, traffic
  input/                    InputRouter autoload, device profiles, DriveInput
  race/race.gd              race flow: countdown, checkpoints, timer, finish
  ui/                       HUD, input debug overlay, calibration wizard
  audio/                    Audio autoload, SoundBank (cue -> file), RaceAudio (race -> cues)
assets/sprites/             in-game sprites (placeholders for now)
assets/audio/               generated placeholder sounds and music (how to swap: its README)
tests/                      test runner, suites, golden traces, end-to-end smoke
tools/                      test.sh, sprite-cutting scripts, make_audio.py (placeholder sound)
```

For a test drive without input, run `godot --path . -- --autodrive`. `--stage=2` starts on Redrock Canyon, `--no-traffic` removes traffic, and `--screenshots=60,300 --shot-dir=/tmp/shots` saves frames.

## Tests

```sh
tools/test.sh                  # every suite, then the end-to-end input smoke
tools/test.sh test_race        # only tests whose name contains "test_race"
```

`test.sh` runs `godot` from your PATH; set `GODOT=/path/to/Godot` to use another binary. The tests cover wheel and pedal normalization, calibration, the driving model, traffic, race flow and renderer regressions. `tests/golden/` holds frame-by-frame traces of three autodriven races (Palm Coast with and without traffic, Redrock with traffic). If you change gameplay on purpose, regenerate them with `godot --headless --path . -s res://tests/golden.gd`. CI runs the same script on every push.

## Docs

- [Game design](docs/01-game-design.md): modes, driving feel, cars, stages, scope
- [Technical design](docs/02-technical-design.md): Godot setup, pseudo-3D road renderer, game logic, wheel/pedal input, milestones
- [Art direction](docs/03-art-direction.md): style options, sprite specs, palettes, UI
- [Open questions](docs/04-open-questions.md): decisions needed before we build
- [Concept review, round 1](docs/05-concept-review-round1.md)
- [Concept review, round 2](docs/06-concept-review-round2.md)

## Concept art prompts

See [assets/README.md](assets/README.md).
