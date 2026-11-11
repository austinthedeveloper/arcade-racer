# EQ: Engineering and Quality

The cleanup plan from `docs/09-known-bugs-and-cleanup.md`, tests, performance, releases and
keeping the docs honest. Month 1 is mostly this group, on purpose: rivals and everything after
them build on fixed collision code and stronger golden traces.

## Built today

`tests/run_tests.gd` runs every suite; `tests/e2e_input.gd` drives the real main scene through
the menus, a race and the results screen; golden traces for every stage, with rivals; screenshot
regression (`tools/shots.sh`). CI runs both on every push; a `v*` tag exports Windows, macOS,
Linux and Web and publishes a GitHub Release with an update pack the auto-updater
(`scripts/core/updater.gd`, `BootTree`) downloads. `tools/roadmap_sync.py` checks these docs
against GitHub. Version 0.1.0.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| EQ-1 ✓ | **Doc sync.** Fix the stale statements listed in [00-overview.md](00-overview.md): `docs/02` section 10, the README (eight stages, twelve cars, docs list through `09` and this folder), the `docs/01` roster, `docs/03` style decision, `docs/04` questions 11 and 12. | S | 1 | | Each doc says what the code does on 2026-11-30 |
| EQ-2 ✓ | **Cleanup phase 1.** G1 segment skipping at nitro speed, G2 bump moves `distance`, U1 one overlay and wizard owned by `game.gd`, G5 `DriveInput.copy()`, T1 span test, T4 leftovers. Play changes, so traces regenerated with the reason in the commit. | S | 1 | | Tests from `docs/09` phase 1 pass; one PR |
| EQ-3 ✓ | **Cleanup phase 2: sprite library and manifest.** `tools/spritelib.py` with one copy of keying, components, crop masking, pixelate and background; numpy or `ImageChops` loops; a JSON manifest of sprite names, world heights, collide fractions and anchors that the game loads in place of the hand-kept tables. A2 and A3 keying fixes ride along. | M | 1 | | A full car rebuild takes seconds, not 90; `CarSprites` and `SpriteLibrary` read the manifest; sprite output is pixel-identical except the fixed fringes |
| EQ-4 ✓ | **Cleanup phase 3: GDScript structure.** `Track.finish_stage()`, one text helper, wheel hints in `InputRouter`, the renderer stops writing into the theme dict, `speed_factor` reset, the player strip passed explicitly, magic numbers into `Cfg`, dev flags parsed once and `_frame` reset (U2). Behavior-neutral. | M | 1 | | Golden traces unchanged; no script over about 320 lines |
| EQ-5 ✓ | **Cleanup phase 4: tests.** Golden traces record power-up state and traffic offsets (T2); new tests for nitro-speed pickups, distance after a bump, the overlay across menus and race, a bad span opening, auto gas copying every field; `Golden.STAGE_PREFIXES` from `Stages`. | S | 1 | EQ-2 | Traces regenerated as their own commit; `tools/test.sh` green |
| EQ-6 ✓ | **Determinism with rivals.** Seeded rival RNG, rival columns in the golden traces, the e2e smoke through the results screen. | S | 2 | RC-1 | Two autodrive runs produce identical traces |
| EQ-7 | **Performance budget.** 60 fps at 1080p on a low-end Mac and a Windows laptop with rivals, heavy traffic, FX and parallax on Neon Strip. Atlas batching for sprites, draw distance per stage, FX caps. A headless frame-time probe in the tests that fails over a threshold. | M | 3, 6 | WS-1, WS-3 | The probe passes; numbers in a table in this doc |
| EQ-8 ✓ | **Save and profile migration.** Version fields on `save.cfg`, `settings.cfg` and `input_profiles.cfg`; a migration step per version; tests that old files load. | S | 2 | MP-1 | Fixture files for each version under `tests/fixtures/` |
| EQ-9 ✓ | **Release hygiene.** A pre-release tag each month (v0.2.0 to v0.7.0) with a changelog (`CHANGELOG.md`, [docs/10-releases.md](../10-releases.md)); for the 1.0 candidate, decide on macOS notarization (Apple Developer ID) and Windows signing, and where the game is published (itch.io first, Steam later). Decided 2026-11-01: not signed yet, GitHub Releases only until itch.io is worth it. | M | 6 | | Signed builds, or a written decision not to sign yet; a store page draft |
| EQ-10 | **Web build check.** FFB is a no-op, the gamepad works, profiles persist in browser storage, the download size has a budget. | S | 6 | WH-3 | A checklist run on two browsers, recorded in the README |
| EQ-11 | **GDExtension build pipeline.** CMake or SCons build of the FFB extension for macOS universal and Windows in CI, cached, with the release workflow bundling it. | M | 5 | | CI builds it on every push to the extension; `tools/export.sh` includes it |
| EQ-12 ✓ | **Screenshot regression.** Menu and race screenshots compared against stored images by perceptual hash in CI, with a tolerance and an easy regenerate step. | M | 4 | | A deliberate color change fails the check; `tools/shots.sh --update` regenerates |
| EQ-13 ✓ | **Linux export.** Add the Linux preset so CI can run the exported build headlessly and a Steam Deck test is possible later. Not a supported platform in these six months. | S | 6 | | The zip appears in the release; one smoke run in CI |
| EQ-14 ✓ | **Auto-updater.** Download the game once; it updates itself from GitHub Releases (Pickleball '94's design, port ADR-057). Each release adds `SundownRun-X.Y.Z.pck` and its manifest (version, engine, size, SHA-256). An exported desktop game opens on the update screen: it checks, downloads a newer pack for its engine at once, and restarts on it. It goes on to the title when up to date, offline or after 8 s; a failed download offers retry or play; a release for another Godot version links to the releases page. `BootTree`, the main loop, loads the pack before the autoloads; an update that never reaches the title is skipped. | M | 1 | | An exported older build updates to a release and restarts on it; a damaged pack falls back to the built-in game |
| EQ-15 ✓ | **Tuning registry.** The driving, AI, traffic, drafting, launch, power-up, scoring and camera constants become `Tuning` values with a default, a range and a step, read everywhere the constants were. Overrides load from `user://tuning.cfg` or `--tuning-file`; tests and golden traces run on the defaults. | M | 1 | | `test_tuning`: every value has metadata, an override applies, a missing file is the defaults; traces unchanged |
| EQ-16 ✓ | **Debug panel.** F3 in a race or the menus: a page per area, up and down pick a value, left and right nudge it by its step (held: faster), it applies at once and the HUD shows a TUNED badge. Reset one or all, save and load named presets, and actions: slow motion, jump to a segment, give a power-up, set the clock, a traffic burst. Every change is logged with the stage, car and race time. | M | 1 | EQ-15 | Panel logic in a plain class with tests; `--screen=debug`; a screenshot of two pages |
| EQ-17 ✓ | **Adopt tuned defaults.** `tools/tuning_adopt.py` diffs an override file against the defaults, writes the new defaults into the registry's table, regenerates the golden traces and prints a before-and-after table for the commit. The review before it: the session's tuning log is read and the changes argued for or against, value by value. | S | 1 | EQ-15 | A test on a fixture override file; the workflow in the README |
| EQ-18 ✓ | **Test isolation.** Each test run gets its own `user://` scratch (settings, profiles, save, ghosts), so runs in parallel worktrees stop stepping on each other, and `tools/test.sh test_options` passes on its own. | S | 1 | | Two runs at once both pass; the filtered suite passes |
| EQ-19 ✓ | **Reproducible assets.** `tools/requirements.txt` pins Pillow, numpy and scipy; a CI job rebuilds every sprite and fails on a pixel that differs. | S | 1 | EQ-3 | The job is green on main |
| EQ-20 ✓ | **Crash log.** Uncaught errors and the last 200 log lines go to `user://logs/`; the title's version line offers COPY REPORT. | S | 2 | | Test: a forced error lands in the log; the copy puts it on the clipboard |
| EQ-21 ✓ | **Save backups.** A `.bak` of each cfg before a migration and a RESTORE row in Options > Reset. | S | 2 | EQ-8 | `test_migration` covers backup and restore |
| EQ-22 ✓ | **Soak test.** A headless script races every stage, car and difficulty with random inputs and fails on any error; a nightly CI job. | M | 2 | EQ-6 | The script and the workflow; a run that finds nothing |
| EQ-23 ✓ | **Web load.** A loading screen with progress for the Web build, and a size budget on the `.pck` that CI enforces. | S | 2 | EQ-10 | `test_export` checks the budget; a screenshot of the loader |
| EQ-24 ✓ | **Dev ergonomics.** `tools/test.sh` runs `--import` when a `class_name` script changed, finds Godot on each platform, and `tools/dev.sh` wraps the common flags. | S | 1 | | A fresh clone runs the tests with one command |
| EQ-25 ✓ | **Playtest log.** An opt-in log, off by default, written next to the crash log: per race the stage, car, checkpoints, crashes and time lost per stretch. `tools/playtest_report.py` turns a folder of them into a per-stage chart of where players crash and slow down. Nothing leaves the machine. | M | 4 | EQ-20 | Test the log's lines from a scripted race; the report tool's test on a fixture folder; the option's screenshot |
| EQ-26 ✓ | **1.0 bug bash.** Every open item in `docs/09` and every open bug issue is fixed or deferred with a reason; the README gets a short known-issues list. | M | 5 |  | No open bug issue without a milestone; `docs/09` up to date; the known-issues list in the README |
| EQ-27 ✓ | **Save compatibility promise.** From 1.0 a save, settings and profile file from any released version loads in every later one. A fixture file per release in `tests/fixtures/saves/`, added by the release steps. | S | 5 | EQ-8, EQ-21 | `test_save_data` loads every fixture; `docs/10-releases.md` adds the step |
| EQ-28 | **1.0 release.** Version 1.0.0: the changelog's 1.0 section reads as a whole-game summary, the updater is checked from v0.4.0 and the last 0.x, the release page gets screenshots. | S | 6 | EQ-26, EQ-27 | The tag's release is out; an old build updates itself to it |
| EQ-29 | **Signing for 1.0.** Austin decides: Apple Developer ID notarization and Windows code signing in `release.yml`, or keep unsigned builds and give the README's Gatekeeper and SmartScreen steps screenshots. Needs Austin. | S | 6 | EQ-9 | The decision recorded in `docs/10-releases.md`; signed builds open without a warning, or the README steps have screenshots |
| EQ-30 | **Store page.** If Austin wants one: an itch.io page with the Web build playable in the browser and the desktop zips uploaded by `release.yml` through butler. Needs Austin's call (GitHub Releases only so far). | S | 6 | EQ-28 | The decision recorded; if yes, a tag uploads to itch.io from CI |
| EQ-31 | **Steam Deck check.** The Linux build on a Steam Deck, if one is at hand: controls, the 1280x800 layout, suspend and resume, the frame rate on Neon. Notes in the README. | S | 6 | EQ-13 | A row in the README's platform table |
| EQ-32 | **Split-screen performance.** Two renderers at 60 fps on the low-end Mac and a Windows laptop; draw distance and the FX cap drop per half where needed. | M | 7 | MP-18, EQ-7 | The numbers in the EQ-7 table for split screen |
| EQ-33 | **Determinism across platforms.** A race's input trace replays to the same finish on Windows, macOS, Linux and the Web build, so a time can be checked by replaying it. | M | 9 | EQ-6 | A CI job replays the golden traces' inputs on Linux and the Web build and compares the finishes |
| EQ-34 | **Online service care.** Health checks, logs and a cost alert for the relay and the board on Azure, and a runbook in `docs/` for when it's down. | S | 9 | ON-18 | The alert and checks are set up; the runbook |
| EQ-35 | **Golden traces per branch.** `tests/golden/` holds a trace per branch of each forked stage, and the mirrored check covers them. | S | 10 | WS-22, RC-25 | `test_golden` runs every branch |
| EQ-36 | **Editor tests.** Golden traces for a fixture custom stage, and a soak run on random generated stages. | S | 14 | WS-31, EQ-22 | Both in CI |
| EQ-37 | **Codebase health.** A pass before 2.0: dead code out, `docs/02` checked against the code, the test run back under a time budget. | M | 15 |  | The budget in this doc and met in CI |
| EQ-38 | **Godot upgrade.** Move to the next Godot minor release with the golden traces and screenshots checked. | S | 15 |  | CI green on the new version; traces unchanged or regenerated with the reason |
| EQ-39 | **2.0 release.** Version 2.0.0 with saves from every 1.x carried over. | S | 15 | MP-30, EQ-27 | The release is out; a 1.0 save loads |

## Performance budget (EQ-7)

`tests/perf_probe.gd` drives an autodriven race on Neon Strip (7 rivals, 95 traffic cars,
FX, three-layer parallax, default options) and times each frame: `update` is the race's tick,
`draw` is every `_draw` that tick queued (road projection and sprite list, parallax, FX, HUD),
`frame` the wall time between frames with vsync off (windowed only). `tests/test_perf.gd` runs
it headless in its own Godot and fails when the CPU share averages 12 ms or more, or its 95th
percentile reaches 25 ms (this Mac: 3 to 5 ms mean, so a slow CI runner has room and a change
that doubles the work still fails). `PERF_PROBE=skip` skips it.

```sh
godot --headless --path . -s res://tests/perf_probe.gd                      # what the test runs
godot --path . --resolution 1920x1080 -s res://tests/perf_probe.gd -- --perf-frames=1200   # real frames
# --perf-quiet: no rivals or traffic; --perf-draw-distance=N: weigh the draw distance; --perf-stage=N
```

Levers:
- **Draw distance per stage:** a theme's `draw_distance` (default `Cfg.DRAW_DISTANCE`, 300
  segments). Neon Strip draws 220; fog thickens to match. Display only, golden traces unchanged.
- **Thin runs:** past about 40 segments a segment is under a pixel tall; runs of bare segments
  under `RoadRenderer.THIN_RUN` (1 px) together are drawn as one band, and a segment with the
  same ground on both sides draws one ground quad. Screenshots match the old renderer.
- **FX cap:** `FxLayer.MAX_PARTICLES` (160 alive) and `SPAWN_CAP` (12 a tick), from WS-1; the
  probe reports the peak (98 on Neon).
- **Atlas batching:** not done. The cost is GDScript building draw commands, not texture
  switches (the canvas renders at 640x360 and is scaled up), so an atlas would not move these numbers.

Neon Strip, 1200 frames after the launch. Measured 2026-10-31 on the dev MacBook Pro (M1 Pro,
16 GB, macOS 27) while four other agents built and tested in parallel (load average 15 to 25),
so expect these to be a little pessimistic.

| Machine | Window | Build | Frame mean / p95 (ms) | CPU mean / p95 (ms) | 60 fps? |
|---|---|---|---|---|---|
| M1 Pro MacBook Pro | 1920x1080 | before (draw distance 300, no thin runs) | 12.3 / 17.0 | 6.7 / 8.6 | mostly; p95 misses |
| M1 Pro MacBook Pro | 1920x1080 | thin runs, draw distance 300 | 11.5 / 16.7 | 5.4 / 7.0 | just |
| M1 Pro MacBook Pro | 1920x1080 | thin runs, draw distance 220 (shipped) | 7.9 to 8.2 / 10.6 to 11.7 | 4.1 to 4.2 / 5.2 to 5.7 | yes |
| M1 Pro MacBook Pro | headless (the test) | shipped | | 2.8 to 4.9 / 3.7 to 8.7 | |
| Low-end Mac | 1920x1080 | shipped | not measured: no such machine here (Austin) | | |
| Windows laptop | 1920x1080 | shipped | not measured: no such machine here (Austin) | | |

## Open decisions

- Is the manifest JSON hand-editable, or only tool-written? Default: tool-written, with the tools as the source of truth.
- Perceptual-hash screenshots or exact pixels? Default: hash with a small tolerance; fonts render slightly differently across platforms.

## Working rules carried over from `CLAUDE.md`

Every change adds or extends tests. Golden traces change only when play changes, regenerated as
their own commit with the reason. Logic a test needs lives in a plain function. Look at a
screenshot of anything visual. Feature branches named `feature/CLD-<name>`; Austin merges.
