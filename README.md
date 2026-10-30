# SUNDOWN RUN (working title)

An original sprite-based, pseudo-3D arcade road racer built in Godot 4. Supports keyboard, gamepads, and steering wheels with pedals.

**Status:** Milestone 1 prototype. One stage (Palm Coast Boulevard) is drivable with traffic, checkpoints, a timer, nitro, jumps and crashes. The art is placeholder: the palms and background are cut from the round 1 concepts, and the cars are drawn from flat shapes.

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
| Restart | R | Back | |
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
  render/                   road renderer, background, placeholder car painter
  car/                      player driving model, traffic
  input/                    InputRouter autoload, device profiles, DriveInput
  race/race.gd              race flow: countdown, checkpoints, timer, finish
  ui/                       HUD, input debug overlay, calibration wizard
assets/sprites/             in-game sprites (placeholders for now)
tools/                      helper scripts (placeholder sprite slicer)
```

For a test drive without input, run `godot --path . -- --autodrive`. `--no-traffic` removes traffic, and `--screenshots=60,300 --shot-dir=/tmp/shots` saves frames.

## Docs

- [Game design](docs/01-game-design.md): modes, driving feel, cars, stages, scope
- [Technical design](docs/02-technical-design.md): Godot setup, pseudo-3D road renderer, game logic, wheel/pedal input, milestones
- [Art direction](docs/03-art-direction.md): style options, sprite specs, palettes, UI
- [Open questions](docs/04-open-questions.md): decisions needed before we build
- [Concept review, round 1](docs/05-concept-review-round1.md)

## Concept art prompts

See [assets/README.md](assets/README.md).
