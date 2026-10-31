# MP: Modes and Progression

Everything between races: the modes in `docs/01-game-design.md` section 4, the rules in
section 5 and the unlocks and save data in section 11.

## Built today

The tour runs stage by stage from the stage picked on stage select, with a fresh clock each
stage. R restarts; confirm after TIME UP retries. Options persist in `user://settings.cfg`.
Progress, best times and unlocks are saved (`user://save.cfg`). Four cars and stage 1 are open from the start; the rest unlock as the tour goes (`scripts/core/unlocks.gd`), or all at once with UNLOCK EVERYTHING in Options. Time Attack races the best run's ghost per stage and car (`user://ghosts/`).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| MP-1 | **Save data.** `user://save.cfg` with a version number: tour progress, unlocks, best time and best placing per stage and car, total points. Separate from options and input profiles, with a reset in AC-9. | S | 2 | | `test_save` covers round-trip, a missing file and a version bump; tests use a scratch path |
| MP-2 | **Grand Tour rules.** Top three to advance, cumulative standings over eight stages, one continue when the clock runs out, a final standings screen, the Zenith unlock on finishing. Option: leftover checkpoint time carries over. | M | 2 | RC-2, MP-1 | Rules in plain functions with tests; the e2e smoke plays two stages of a tour |
| MP-3 | **Single Race.** Any unlocked stage, any unlocked car, rivals and traffic, no standings. Today's flow becomes this mode. | S | 2 | MP-8 | e2e smoke runs one |
| MP-4 | **Unlocks.** Cars by stage reached (Skipper 2, Mesa 3, Cyclone 4, Phantom 5, Halo 6, Tempest 7, Zenith on finishing, Hauler by a secret), stages by tour progress, paint colors by placings (CP-4), mirror mode per stage won (WS-6). Locked entries show their condition. An "unlock everything" toggle for testing and accessibility (AC-8). | M | 3 | MP-1 | Unlock table in data with a test per rule; car select screenshot with locks |
| MP-5 | **Time Attack with ghost.** Solo against the clock, no rivals, traffic optional. Record the best run per stage and car as per-tick distance, offset and frame; replay it as a translucent car. | M | 6 | MP-1 | Ghost file round-trip test; a race against a recorded ghost in the e2e smoke |
| MP-6 | **Free Drive.** No timer, no rivals, traffic optional; the wheel test mode. | S | 6 | MP-8 | e2e smoke enters and quits it |
| MP-7 | **Difficulty.** Easy, normal, hard: rival pace and rubber-band strength, and the timer option's default. | S | 2 | RC-4 | A `Difficulty` resource per level; tests on the band caps |
| MP-8 | **Mode select.** A screen after the title: Grand Tour, Single Race, Time Attack, Free Drive, Options. Wheel-drivable. | S | 2 | | e2e smoke reaches each mode; `--screen=modes` screenshot |

## Open decisions

- Does the Grand Tour continue cost points, or just the standings place? Default: no points, you keep racing from the stage you failed.
- Secret Hauler condition: finish Palm Coast without touching traffic, or a code on the title screen? Default: the clean Palm Coast run.
- Ghosts per car or per stage? Default: per stage and car, since cars differ a lot.

## Stretch

Split-screen two player. The renderer would need two viewports and the HUD a layout per half.
Keep `RoadRenderer` free of global state (see `docs/09` phase 3) so this stays possible.
