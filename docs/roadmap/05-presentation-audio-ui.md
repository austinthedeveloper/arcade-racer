# PR: Presentation, Audio and UI

The arcade attitude from `docs/01-game-design.md` section 12 and `docs/03-art-direction.md`
section 7: sound, music, the announcer, the HUD and the screens around the race.

## Built today

Placeholder sounds synthesized by `tools/make_audio.py`, mapped by cue name in `SoundBank` so a
pack can replace them file by file. A two-loop engine pitched by a five-gear rev model, skid and
off-road loops, countdown, checkpoint, nitro, crash, bump, landing, low-time ticks, finish and
time-up cues. HUD with speed, time, nitro, progress bar, power-up slot and banners. Title,
Options, stage select with postcards and car select with showroom pictures.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| PR-1 | **Sound pack.** Replace every placeholder cue with a real sound (recorded or license-safe library), add cues for rivals, drafting, slides and power-ups, then a mix pass on the three buses. | M | 5 | | No synthesized file is still the first match for any cue; `test_audio` lists the pack |
| PR-2 | **Music radio.** Four original stations (rock, synthwave, funk, techno), a station pick before the race, a button to switch mid-race, ducking under the announcer. Sourcing starts in month 3. | M | 5 | | Streams per station in `assets/audio/music/`; the race switches stations without a gap; e2e smoke switches once |
| PR-3 | **Wind, whooshes and horn.** Wind volume by speed, traffic whooshes panned by side, a horn button. | S | 5 | | `test_audio` checks the pan sign and wind curve |
| PR-4 | **Announcer.** Original lines for countdown, GO, checkpoint, time extended, final stretch, near miss, big air, finish positions. Subtitles (AC-5). Voice sourcing with the music. | M | 5, 6 | PR-1 | Each line has a cue and a subtitle string; a test that no two lines overlap |
| PR-5 | **Callouts.** Starburst banners: GO, CHECKPOINT, TIME EXTENDED, NEAR MISS, BIG AIR, FINAL STRETCH, LAUNCH, 1ST PLACE. Driven by RC-6 events. | S | 2 | RC-6 | Banner queue test; screenshots of two callouts |
| PR-6 | **HUD v2.** Analog speedo with digital readout and tach, chunky position numeral, timer that pulses red under ten seconds, flame icons for nitro, slipstream bar, progress bar with rival dots. One low-time threshold shared with audio and power-ups (`docs/09` phase 3). | M | 3 | RC-2, CP-11 | Layout in a plain function with a test per element's rect; screenshots at 640x360 and 1920x1080 |
| PR-7 | **Results and standings screens.** Art and layout for RC-5 and MP-2: placing, times, bonuses, tour points table. | M | 2 | RC-5 | Menu screenshots via `--screen=results` |
| PR-8 | **Map stage select.** Postcards placed on a map of the fictional country (KA-06 concept), the tour route drawn between them, locked stages dimmed. | M | 6 | MP-4 | Wheel still drives it left and right; screenshot |
| PR-9 | **Finish spectacle.** Fireworks on Skyline, confetti and a louder crowd everywhere, a slow-down after the line. | S | 3 | WS-1 | Screenshot of the Skyline finish |
| PR-10 | **Camera feel.** Shake on crests, crashes and off-road, behind the AC-2 slider; a small FOV stretch on nitro. | S | 3 | AC-2 | Shake amounts in `Cfg`; slider at 0 gives none |
| PR-11 | **Attract mode.** The title screen starts an autodrive demo after idling, with the logo over it; any input returns to the title. | S | 6 | | e2e smoke waits for the demo and interrupts it |
| PR-12 | **Pause menu.** Resume, restart, options, quit to title, instead of today's key combinations. | S | 2 | | e2e smoke uses it; wheel-drivable |

## Open decisions

- Music: commission four tracks, or a license-safe library with a clear credit? Default: library if nothing is commissioned by month 3.
- Announcer: a recorded voice or a synthesized one with character? Default: recorded, one voice, under forty lines.
- Radio switch on the horn button or its own? Default: its own, so the horn stays a toy.

## Test notes

Audio logic (which cue, which pan, which station) is tested; audio output is not. Screens get a
`--screen=` flag each so a screenshot is one command.
