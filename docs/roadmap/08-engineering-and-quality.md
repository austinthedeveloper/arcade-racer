# EQ: Engineering and Quality

The cleanup plan from `docs/09-known-bugs-and-cleanup.md`, tests, performance, releases and
keeping the docs honest. Month 1 is mostly this group, on purpose: rivals and everything after
them build on fixed collision code and stronger golden traces.

## Built today

`tests/run_tests.gd` runs every suite; `tests/e2e_input.gd` drives the real main scene; golden
traces for every stage. CI runs `tools/test.sh` on every push; a `v*` tag exports Windows, macOS
and Web and publishes a GitHub Release. Version 0.1.0.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| EQ-1 | **Doc sync.** Fix the stale statements listed in [00-overview.md](00-overview.md): `docs/02` section 10, the README (eight stages, twelve cars, docs list through `09` and this folder), the `docs/01` roster, `docs/03` style decision, `docs/04` questions 11 and 12. | S | 1 | | Each doc says what the code does on 2026-11-30 |
| EQ-2 | **Cleanup phase 1.** G1 segment skipping at nitro speed, G2 bump moves `distance`, U1 one overlay and wizard owned by `game.gd`, G5 `DriveInput.copy()`, T1 span test, T4 leftovers. Play changes, so traces regenerated with the reason in the commit. | S | 1 | | Tests from `docs/09` phase 1 pass; one PR |
| EQ-3 | **Cleanup phase 2: sprite library and manifest.** `tools/spritelib.py` with one copy of keying, components, crop masking, pixelate and background; numpy or `ImageChops` loops; a JSON manifest of sprite names, world heights, collide fractions and anchors that the game loads in place of the hand-kept tables. A2 and A3 keying fixes ride along. | M | 1 | | A full car rebuild takes seconds, not 90; `CarSprites` and `SpriteLibrary` read the manifest; sprite output is pixel-identical except the fixed fringes |
| EQ-4 | **Cleanup phase 3: GDScript structure.** `Track.finish_stage()`, one text helper, wheel hints in `InputRouter`, the renderer stops writing into the theme dict, `speed_factor` reset, the player strip passed explicitly, magic numbers into `Cfg`, dev flags parsed once and `_frame` reset (U2). Behavior-neutral. | M | 1 | | Golden traces unchanged; no script over about 320 lines |
| EQ-5 | **Cleanup phase 4: tests.** Golden traces record power-up state and traffic offsets (T2); new tests for nitro-speed pickups, distance after a bump, the overlay across menus and race, a bad span opening, auto gas copying every field; `Golden.STAGE_PREFIXES` from `Stages`. | S | 1 | EQ-2 | Traces regenerated as their own commit; `tools/test.sh` green |
| EQ-6 | **Determinism with rivals.** Seeded rival RNG, rival columns in the golden traces, the e2e smoke through the results screen. | S | 2 | RC-1 | Two autodrive runs produce identical traces |
| EQ-7 | **Performance budget.** 60 fps at 1080p on a low-end Mac and a Windows laptop with rivals, heavy traffic, FX and parallax on Neon Strip. Atlas batching for sprites, draw distance per stage, FX caps. A headless frame-time probe in the tests that fails over a threshold. | M | 3, 6 | WS-1, WS-3 | The probe passes; numbers in a table in this doc |
| EQ-8 | **Save and profile migration.** Version fields on `save.cfg`, `settings.cfg` and `input_profiles.cfg`; a migration step per version; tests that old files load. | S | 2 | MP-1 | Fixture files for each version under `tests/fixtures/` |
| EQ-9 | **Release hygiene.** A pre-release tag each month (v0.2.0 to v0.7.0) with a changelog; for the 1.0 candidate, decide on macOS notarization (Apple Developer ID) and Windows signing, and where the game is published (itch.io first, Steam later). | M | 6 | | Signed builds, or a written decision not to sign yet; a store page draft |
| EQ-10 | **Web build check.** FFB is a no-op, the gamepad works, profiles persist in browser storage, the download size has a budget. | S | 6 | WH-3 | A checklist run on two browsers, recorded in the README |
| EQ-11 | **GDExtension build pipeline.** CMake or SCons build of the FFB extension for macOS universal and Windows in CI, cached, with the release workflow bundling it. | M | 5 | | CI builds it on every push to the extension; `tools/export.sh` includes it |
| EQ-12 | **Screenshot regression.** Menu and race screenshots compared against stored images by perceptual hash in CI, with a tolerance and an easy regenerate step. | M | 4 | | A deliberate color change fails the check; `tools/shots.sh --update` regenerates |
| EQ-13 | **Linux export.** Add the Linux preset so CI can run the exported build headlessly and a Steam Deck test is possible later. Not a supported platform in these six months. | S | 6 | | The zip appears in the release; one smoke run in CI |

## Open decisions

- Is the manifest JSON hand-editable, or only tool-written? Default: tool-written, with the tools as the source of truth.
- Perceptual-hash screenshots or exact pixels? Default: hash with a small tolerance; fonts render slightly differently across platforms.

## Working rules carried over from `CLAUDE.md`

Every change adds or extends tests. Golden traces change only when play changes, regenerated as
their own commit with the reason. Logic a test needs lives in a plain function. Look at a
screenshot of anything visual. Feature branches named `feature/CLD-<name>`; Austin merges.
