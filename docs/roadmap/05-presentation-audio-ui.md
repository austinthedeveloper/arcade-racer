# PR: Presentation, Audio and UI

The arcade attitude from `docs/01-game-design.md` section 12 and `docs/03-art-direction.md`
section 7: sound, music, the announcer, the HUD and the screens around the race.

## Built today

Original sounds synthesized by `tools/make_audio.py`, mapped by cue name in `SoundBank` so a
recorded file can replace any of them. A two-loop engine pitched by a five-gear rev model, skid,
off-road, wind, slipstream, nearest-rival and horn loops, panned whooshes past traffic and
rivals, a pickup sound per power-up, countdown, checkpoint, nitro, crash, bump, landing,
low-time ticks, finish, crowd, thunder and time-up cues. A four-station radio (`Radio`). HUD with speed, time, place, nitro, draft meter, progress bar with rival dots,
power-up slot and banners. Title, mode select, Options pages, stage select with postcards, car
select with showroom pictures, a pause menu, the results and standings screen, the finish
spectacle, an attract-mode demo, camera shake and the nitro view stretch. A game icon.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| PR-1 ✓ | **Sound pack.** Replace every placeholder cue with a real sound, add cues for rivals, drafting, slides and power-ups, then a mix pass on the three buses. Decided 2026-11-01: original synthesized sounds (`tools/make_audio.py`), not a library or recordings; a recorded file still replaces any cue. The slide cue waits for RC-8. | M | 5 | | Every cue remade; `test_audio` lists the pack and checks every level |
| PR-2 ✓ | **Music radio.** Four original stations (rock, synthwave, funk, techno), a station pick before the race, a button to switch mid-race, ducking under the announcer. Synthesized in `tools/make_audio.py` (decided 2026-11-01). | M | 5 | | Streams per station in `assets/audio/music/`; the race switches stations without a gap; e2e smoke switches once |
| PR-3 ✓ | **Wind, whooshes and horn.** Wind volume by speed, traffic whooshes panned by side, a horn button. | S | 5 | | `test_audio` checks the pan sign and wind curve |
| PR-4 ✓ | **Announcer.** Original lines for countdown, GO, checkpoint, time extended, final stretch, near miss, big air, finish positions. Subtitles (AC-5). The voice is synthesized patter in each line's rhythm (decided 2026-11-01); a recorded `vo_<id>` file replaces any line. | M | 5, 6 | PR-1 | Each line has a cue and a subtitle string; a test that no two lines overlap |
| PR-5 ✓ | **Callouts.** Starburst banners: GO, CHECKPOINT, TIME EXTENDED, NEAR MISS, BIG AIR, FINAL STRETCH, LAUNCH, 1ST PLACE. Driven by RC-6 events. | S | 2 | RC-6 | Banner queue test; screenshots of two callouts |
| PR-6 ✓ | **HUD v2.** Analog speedo with digital readout and tach, chunky position numeral, timer that pulses red under ten seconds, flame icons for nitro, slipstream bar, progress bar with rival dots. One low-time threshold shared with audio and power-ups (`docs/09` phase 3). | M | 3 | RC-2, CP-11 | Layout in a plain function with a test per element's rect; screenshots at 640x360 and 1920x1080 |
| PR-7 ✓ | **Results and standings screens.** Art and layout for RC-5 and MP-2: placing, times, bonuses, tour points table. | M | 2 | RC-5 | Menu screenshots via `--screen=results` |
| PR-8 ✓ | **Map stage select.** Postcards placed on a map of the fictional country (KA-06 concept), the tour route drawn between them, locked stages dimmed. The map is built from the concept by `tools/make_ui_sprites.py`. | M | 6 | MP-4 | Wheel still drives it left and right; screenshot |
| PR-9 ✓ | **Finish spectacle.** Fireworks on Skyline, confetti and a louder crowd everywhere, a slow-down after the line. | S | 3 | WS-1 | Screenshot of the Skyline finish |
| PR-10 ✓ | **Camera feel.** Shake on crests, crashes and off-road, behind the AC-2 slider; a small FOV stretch on nitro. | S | 3 | AC-2 | Shake amounts in `Cfg`; slider at 0 gives none |
| PR-11 ✓ | **Attract mode.** The title screen starts an autodrive demo after idling, with the logo over it; any input returns to the title. | S | 6 | | e2e smoke waits for the demo and interrupts it |
| PR-12 ✓ | **Pause menu.** Resume, restart, options, quit to title, instead of today's key combinations. | S | 2 | | e2e smoke uses it; wheel-drivable |
| PR-13 ✓ | **Game icon.** The striped sunset disc from the logo shapes sheet on a night-blue tile with a gold rim (`tools/make_icon.py`): the project and window icon, the Windows .exe (`icon.ico`), the macOS app (`icon.icns`) and the Web favicon. | S | 1 | | The exported .exe, .app and Web build show it |
| PR-14 | **HUD legibility pass.** No text under 8 px at 640x360 (the MPH label is 7), every label checked at 1920x1080 and on a phone. | S | 1 | PR-6 | `test_hud` asserts the minimum font size; screenshots at both sizes |
| PR-15 | **Callout pacing.** From Austin's play notes: CHECKPOINT and TIME EXTENDED as one two-line burst, a cap on how often a kind repeats, 1ST PLACE never ahead of FINISH. | S | 1 | PR-5 | `test_callouts` covers the merged burst and the cap; a screenshot |
| PR-16 | **Stage intro card.** During the countdown: the stage name, its weather, length, your best time and medal, slid in and out. | S | 2 | MP-9 | Layout in a plain function with a test; a screenshot |
| PR-17 | **What's new.** After an update, the title screen shows that version's changelog section once (from `tools/changelog.py`'s output bundled at export). | S | 2 | EQ-14 | Test: shown once per version; a screenshot |
| PR-18 | **Engine note per car.** Three engine models (small, V8, turbo) in the gear-and-rev synth, picked per car in `cars.gd`, so the Hauler and the Halo don't sound the same. | M | 2 | PR-1 | `test_audio` checks each car maps to a model and the pitch curves differ; listen in Free Drive |
| PR-19 | **A station per stage.** Each stage names its default station (Neon on synthwave, Redrock on rock); SHUFFLE follows it, a picked station still wins, the radio button still switches. | S | 2 | PR-2 | `test_audio` covers the three cases |
| PR-20 | **Attract tour.** The demo cycles stages and cars with a title card for each, and shows the controls once per loop. | S | 3 | PR-11 | `test_attract` steps through the loop; a screenshot of a title card |
| PR-21 | **Photo key.** F12 (or a bound button) saves a shot without the HUD to `user://screenshots/`, with a shutter sound and a flash the flash slider scales. | S | 1 | | Test: the file lands and the HUD is hidden for that frame |

## Open decisions

- Music: commission four tracks, or a license-safe library with a clear credit? Default: library if nothing is commissioned by month 3.
- Announcer: a recorded voice or a synthesized one with character? Default: recorded, one voice, under forty lines.
- Radio switch on the horn button or its own? Default: its own, so the horn stays a toy.

## Test notes

Audio logic (which cue, which pan, which station) is tested; audio output is not. Screens get a
`--screen=` flag each so a screenshot is one command.
