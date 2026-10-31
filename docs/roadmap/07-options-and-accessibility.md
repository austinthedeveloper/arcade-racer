# AC: Options and Accessibility

The settings list from `docs/01-game-design.md` section 13, plus display options. Most items are
small and pair with a feature elsewhere; they are listed here so the Options screen is planned as
one piece rather than growing a row at a time.

## Built today

Auto gas, traffic density, timer, power-ups on or off, music and SFX volume, calibrate wheel.
Saved in `user://settings.cfg` on every change (`scripts/core/settings.gd`). Keyboard and pad
use up and down for rows; a wheel steers through rows and presses gas to change a value.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| AC-1 | **Display.** Fullscreen or windowed, integer scaling on or off, V-Sync, an optional scanline filter. | S | 3 | | Settings round-trip tests; screenshots at 1080p with integer scaling on and off |
| AC-2 | **Shake and flash sliders.** Screen shake 0 to 10 and flash intensity 0 to 10. Lightning (WS-2) and camera shake (PR-10) read them; both default to the designed level and never exceed it. | S | 3 | | At 0 no shake and no flash; test through the functions that compute them |
| AC-3 | **Assists.** Steering assist and braking assist toggles (WH-6). Off by default. | S | 6 | WH-6 | Settings tests; golden traces unchanged |
| AC-4 | **Colorblind-safe HUD.** Position, timer state and power-up icons distinguished by shape and brightness, not hue alone; a palette check against the common deficiencies. | S | 3 | PR-6 | HUD screenshots passed through a deuteranopia filter still read; icons differ in silhouette |
| AC-5 | **Subtitles.** Announcer lines (PR-4) as text in the banner area, on by default. | S | 6 | PR-4 | Every line has a string; test that subtitles follow the cue |
| AC-6 | **Units.** MPH or KPH on the speedometer. | S | 3 | | A conversion test; the HUD label changes |
| AC-7 | **Controls.** Steering lock and range (WH-1), remapping (WH-2), FFB strength (WH-3). Cross-referenced; the Options screen gets a Controls sub-screen when WH-2 lands. | | 1, 5 | | |
| AC-8 | **Game.** Difficulty (MP-7) and the unlock-everything toggle (MP-4). | | 2, 3 | | |
| AC-9 | **Reset.** Reset options to defaults, and reset save data (with a confirm), each leaving input profiles alone. | S | 2 | MP-1 | Tests on scratch files |
| AC-10 | **Options screen structure.** Pages: Game, Display, Audio, Controls, Accessibility. Still wheel-drivable left and right, with a page bar at the top. | S | 3 | | `--screen=options` screenshots per page; e2e smoke visits each |

## Open decisions

- Does a wheel-only player need a way to type nothing at all anywhere? Yes: every option must stay a list or slider; no text entry.
- Scanline filter: ship it or leave it? Default: ship, off by default, it is cheap.

## Test notes

Options tests run on scratch settings (`TestSuite.use_scratch_settings`) and golden traces run on
the defaults, so every new option must default to today's behavior.
