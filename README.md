# SUNDOWN RUN (working title)

An original sprite-based, pseudo-3D arcade road racer built in Godot 4. Supports keyboard, gamepads, and steering wheels with pedals.

**Status:** pre-release (v0.2.0; the roadmap aims at a 1.0 candidate in April 2027). Eight stages (Palm Coast Boulevard, Redrock Canyon, Neon Strip, Timberline Pass, Bayou Causeway, Harvest Valley, Thunderhead Highway, Skyline Finale) and twelve cars, each with its own stats. Seven AI rivals with personalities, traffic with each stage's local vehicles, checkpoints against the clock, nitro, drafting, power slides, jumps, crashes and power-ups on the road. Grand Tour, Single Race, Time Attack against your ghost and Free Drive, on three difficulties, with a results screen, standings, saved best times and unlocks, including a mirrored version of each stage you win. Thunderhead has rain and lightning; every stage has parallax backgrounds and an FX layer. All the sound is synthesized: engines, a four-station radio and an announcer with subtitles. Wheels are calibrated in the game, and every button can be rebound. The art is cut from generated concept art; production car sprites (from 3D renders) and force feedback are still to come ([roadmap](docs/roadmap/00-overview.md)).

A player and developer guide is on the [wiki](https://github.com/austinthedeveloper/arcade-racer/wiki); the docs in this repository are the source of truth.

## Running it

Download the latest build from [Releases](https://github.com/austinthedeveloper/arcade-racer/releases) (Windows, macOS, Web), or run it from source:

1. Install **Godot 4.7** (standard build, not .NET).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the Play button).

The game opens on the title screen, then mode select, stage select (postcards pinned on a map of the country; outside the Grand Tour, Up switches a won stage to its mirror) and car select.

## Controls

| Action | Keyboard | Gamepad | Wheel |
|---|---|---|---|
| Steer | Left / Right or A / D | Left stick or D-pad | Wheel |
| Gas | Up or W | Right trigger or A | Gas pedal |
| Brake | Down or S | Left trigger, B or X | Brake pedal |
| Nitro (3 per race; 4 in the Halo EV) | Space or Shift | RB | Button picked during calibration |
| Shift up / down (manual gears only) | E / Q | Y / LB | Bind the paddles in Options > Controls > Remap buttons |
| Horn | H | L3 | Bind in Remap buttons |
| Change radio station | M | Bind in Remap buttons | Bind in Remap buttons |
| Pause menu (resume, restart, options, quit to title) | Esc or P | Start | |
| Restart the stage | R | Back | |
| Next stage (after a finish; Single Race: back to the menus), retry (after TIME UP) | Enter | A | |
| Pause menu: choose / select / resume | Up, Down / Enter / Esc or Backspace | D-pad / A / B or Start | Steer / gas pedal / brake pedal |
| Input debug overlay | F1 | | |
| Calibrate wheel | F2 | | |

Power slide: brake while steering at speed, then keep the steering on. The car slides round
tighter for a little speed; it ends when you straighten up.

Nitro, shift up and down, horn, radio, pause and view can be rebound on every device in
**Options > Controls > Remap buttons**. Unplugging the pad or wheel you're driving with pauses the
race; plugging it back in carries on.

### Menus

Menus go left and right only, so every device can drive them:

| Menu action | Keyboard | Gamepad | Wheel |
|---|---|---|---|
| Choose | Left / Right or A / D | Left stick or D-pad | Turn the wheel |
| Select / start | Enter | A or Start | Gas pedal or any wheel button |
| Back | Esc or Backspace | B or Back | Brake pedal |

### Options

Pick **OPTIONS** on the title screen or in the pause menu. Options are saved to `user://settings.cfg` as soon as they change. They're on five pages; the first row flips the page.

| Page | Option | What it does |
|---|---|---|
| Game | Auto gas | The car keeps the gas down, so a young player only has to steer. The brake still works (and lifts the gas while held). |
| Game | Traffic | Light, normal or heavy traffic. |
| Game | Difficulty | Easy, normal or hard: the rivals' pace and rubber band. Sets the timer to match. |
| Game | Timer | Relaxed (more time per checkpoint), Arcade (as tuned) or Tight. |
| Game | Carry time | Grand Tour: time left at a finish carries into the next stage. |
| Game | Power-ups | On or off: the nitro cans, clocks, ram plates, ghosts and mystery hubcaps on the road. |
| Game | Unlock everything | Every car and stage open now; progress is kept. |
| Game | Reset options / Reset save data | Options back to defaults, or erase progress (asks first). Wheel setups are kept either way. |
| Display | Fullscreen, integer scaling, V-Sync, scanlines | |
| Display | Speed units | MPH or KPH. |
| Audio | Music / sound FX volume | 0 to 10. |
| Audio | Radio station | The station races start on, or shuffle. M changes it mid-race. |
| Controls | Calibrate wheel | Opens the wheel calibration (same as F2). |
| Controls | Wheel settings | Each wheel's range, steering lock, deadzone and linearity. |
| Controls | Remap buttons | Keys and buttons for nitro, gears, horn, radio, pause and view, per device. |
| Accessibility | Screen shake, flashing | 0 to 10; 0 turns them off. |
| Accessibility | Subtitles | The announcer's words on screen; on by default. |
| Accessibility | Steering assist, braking assist | Off by default. |
| Accessibility | Gears | Automatic (the default) or manual: you shift through five gears, each with a rev limiter, for about 3% more top speed. |

On the keyboard and gamepad, Up / Down picks a row and Left / Right changes it; Enter / A also toggles or cycles it. A wheel has no up and down, so there you turn the wheel to pick a row and press the gas to change it. Brake goes back.

### Using a wheel

The game spots most wheels by name and asks you to calibrate. Press **F2** and follow the steps: rest, full left, full right, gas, brake, nitro button. It works out which axis is which, and handles inverted, 0..1 and combined pedal axes. The profile is saved per device in `user://input_profiles.cfg`.

Until the wheel is calibrated, only its steering is used. **F1** shows every raw axis and button, which helps when something doesn't respond. There is no force feedback yet, so turn on your wheel software's centering spring for games without FFB (for example in Logitech G HUB or the Thrustmaster Control Panel).

Steering lock defaults to using 360 of the wheel's 900 degrees. Change it, the wheel's range, the deadzone and the linearity in **Options > Controls > Wheel settings**.

### Online

Pick **ONLINE** on mode select, then your car, then **HOST** or **JOIN**. HOST opens a room on the
relay and shows its four letters (no vowels, so no I or O to mix up); friends pick ONLINE, their
car, JOIN, and type or pick the letters. Up to four players, on Windows, macOS, Linux or the Web
build (desktop or a phone's browser), all together. The host picks the stage (and MIRROR where
the host has it open) and starts. Online races have no clock and no AI rivals: first over the
line wins, and the results show everyone. Each game drives its own traffic; the pause menu
doesn't stop the race. Nothing from an online race is saved.

Rooms go through the same relay as Pickleball '94
([pickleball-relay](https://github.com/austinthedeveloper/pickleball-relay), game `sundown-run`).
If nobody has played for a while, the first room takes about 20 seconds while the server wakes.
`--relay=ws://127.0.0.1:8080` points the game at a local relay (`npm start` in that repo), and
`godot --headless --path . -s res://tools/online_probe.gd -- --relay=ws://127.0.0.1:8080` runs a
host and a guest through it: the lobby, the start, cars both ways, a finish and leaving.

To race two windows hands-off (the second joins the first's room from `--room-file`):

```sh
godot --path . -- --online=host --stage=1 --autodrive --room-file=/tmp/room
godot --path . -- --online=join:$(cat /tmp/room) --car=car_mesa --autodrive
```

The host starts once `--players=N` (default 2) are in; each game prints the finishes and quits
when everyone is over the line.

### Touch

On a touchscreen (a phone or tablet's browser, or a touch laptop) the controls show at the first
touch, and from the start in a phone's browser: steer left and right under the left thumb, gas,
brake and nitro under the right, pause at the top left. In the menus they're a D-pad, OK and
BACK, and the online letter grid can be tapped directly. A key or a pad button hides them;
`--touch` shows them for screenshots.

## Project layout

```
scripts/
  core/cfg.gd               tuning constants (camera, speeds, physics)
  track/                    segment + track builder, sprite library, stages/
  render/                   road renderer, background, car sprites, FX layer, weather
  car/                      player driving model, rivals and their AI, traffic, the garage (cars.gd)
  input/                    InputRouter autoload, device profiles, DriveInput
  core/game.gd              main scene: title, mode select, options, stage and car select, then the race
  core/                     settings, save data, unlocks, difficulty, attract mode, updater (boot_tree.gd)
  core/settings.gd          Settings autoload: the options, saved to user://settings.cfg
  race/                     race flow (race.gd), rivals, scoring, drafting, launch, tour, ghosts, power-ups
  ui/                       menu screens, HUD, results, pause, remap, input debug overlay, calibration wizard
  audio/                    Audio autoload, SoundBank (cue -> file), RaceAudio (race -> cues), Radio, Announcer
assets/sprites/             in-game sprites (placeholders for now)
assets/audio/               synthesized sounds, radio and announcer (how to swap in recordings: its README)
tests/                      test runner, suites, golden traces, end-to-end smoke
tools/                      test.sh, shots.sh, sprite-cutting scripts, make_audio.py, export.sh,
                            car_angles.sh (car review page), roadmap_sync.py (docs vs GitHub)
```

For a test drive without input, run `godot --path . -- --autodrive`. `--stage=N` starts on stage N (2 is Redrock Canyon), `--car=car_mesa` picks a car by id (the ids are in `scripts/car/cars.gd`), `--at-segment=N` starts N segments into the stage, `--no-traffic` removes traffic, `--no-rivals` removes the rivals, `--drive-x=1.8` starts the car on that line (past 1 is off the road) and keeps autodrive on it, and `--screenshots=60,300 --shot-dir=/tmp/shots` saves frames. These flags (and `--race`) skip the menus. `--screen=title|modes|options|stages|cars|pause|unplugged|results|update|remap|wheel --menu-shot=/tmp/stages.png` saves a screenshot of a menu and quits (`options:audio` opens an options page, `update:failed` an update state). `--callout=near_miss` holds a callout up after GO, `--time-left=9` starts on a low clock, and `--lightning-at=5` forces a lightning strike on Thunderhead. `CLAUDE.md` lists more examples. Left on the title for 20 seconds, the game plays an autodriven demo race (attract mode) until any key or button; `--attract-delay=N` changes the wait and `--screen=demo` starts one straight away.

## Tests

```sh
tools/test.sh                  # every suite, then the end-to-end input smoke
tools/test.sh test_race        # only tests whose name contains "test_race"
```

`test.sh` runs `godot` from your PATH; set `GODOT=/path/to/Godot` to use another binary. The tests cover wheel and pedal normalization, calibration, remapping, menu input and the menu flow, options and saves, the driving model, rivals, traffic, scoring, the modes, the updater and renderer regressions. The end-to-end smoke boots the game on the title screen, changes some options, and goes through the menus into races and the results screen. `tests/golden/` holds frame-by-frame traces of autodriven races (Palm Coast with traffic and rivals and on a clear road, every other stage with traffic and rivals, power-ups on). `tools/shots.sh` compares menu and race screenshots with `tests/shots/`. If you change gameplay on purpose, regenerate them with `godot --headless --path . -s res://tests/golden.gd`. CI runs the same script on every push.

### Looking at the cars

`tools/car_angles.sh` poses every car in each of its seven steering frames on level road, gentle
and steep uphills and gentle and steep downhills, in the real race scene, and builds one page to
look through them, flag shots and write notes: `build/car_angles/car_angles.html`. It needs a
display and PIL (`SHOTS_PYTHON=...`); `--car=car_mesa` does one car.

### Roadmap and GitHub

`python3 tools/roadmap_sync.py` checks `docs/roadmap/` against the GitHub issues and project board;
`--fix-board --write-docs` moves closed issues to Done, ticks their rows and rewrites the status
table in the overview.

## Releases

`tools/export.sh [version]` builds Windows, macOS (universal), Web and Linux into `build/release/SundownRun-<version>-<platform>.zip`. It needs the Godot 4.7.2 export templates (Editor > Manage Export Templates). The presets are in `export_presets.cfg`.

To publish, rename **Unreleased** in `CHANGELOG.md` to the version and date, bump `config/version` in `project.godot`, then push a tag (the steps and the signing and store decisions are in [docs/10-releases.md](docs/10-releases.md)):

```sh
git tag v0.1.0 && git push origin v0.1.0
```

`.github/workflows/release.yml` runs the tests, exports the builds and creates the GitHub Release with the zips, that version's `CHANGELOG.md` section (`tools/changelog.py`; a tag without one stops the workflow) and download notes. Running the workflow by hand (Actions > Release > Run workflow) builds the zips as a workflow artifact without publishing. The builds are not code-signed or notarized, so Windows SmartScreen and macOS Gatekeeper warn on first launch; the release notes say how to get past that. The Linux x86_64 zip is not a supported platform and is for testing only (CI smoke-runs it headlessly; a Steam Deck test may follow).

### Updates

From 0.2.0 on, the desktop games update themselves: download once, and every start checks GitHub for the latest release. Each release also carries `SundownRun-<version>.pck` (the whole game without the engine, about 18 MB) and `SundownRun-<version>.json` (version, Godot version, size, SHA-256), written by `tools/export.sh`. When a newer release is for the same Godot version, the update screen downloads its pack into `user://updates/`, checks it and restarts. `BootTree` (`scripts/core/boot_tree.gd`, the main loop) loads the pack before anything else at every start. A release that moves to another Godot version, or changes a `project.godot` setting other than the version, needs a full download; the update screen links to the releases page. 0.1.0 has no updater, so 0.2.0 has to be downloaded by hand once.

To try it without publishing: export two versions, serve the newer one's `.pck`, `.json` and a `release.json` in GitHub's shape from a local web server, and start the older build with `-- --update-api=http://127.0.0.1:8765/release.json`.

## Docs

- [Game design](docs/01-game-design.md): modes, driving feel, cars, stages, scope
- [Technical design](docs/02-technical-design.md): Godot setup, pseudo-3D road renderer, game logic, wheel/pedal input, milestones
- [Art direction](docs/03-art-direction.md): the pixel art style, sprite specs, palettes, UI
- [Open questions](docs/04-open-questions.md): decisions made and still needed
- [Concept review, round 1](docs/05-concept-review-round1.md)
- [Concept review, round 2](docs/06-concept-review-round2.md)
- [Art prompts, round 4](docs/07-art-prompts-round4.md)
- [Concept review, round 4](docs/08-concept-review-round4.md)
- [Known bugs and cleanup plan](docs/09-known-bugs-and-cleanup.md)
- [Releases](docs/10-releases.md): monthly tags, the changelog, why the builds aren't signed yet, where the game is published
- [Roadmap, November 2026 to April 2027](docs/roadmap/00-overview.md): the six-month feature list (feature IDs like RC-1), split into eight group docs in `docs/roadmap/`

## Concept art prompts

See [assets/README.md](assets/README.md).
