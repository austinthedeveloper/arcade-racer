# MP: Modes and Progression

Everything between races: the modes in `docs/01-game-design.md` section 4, the rules in
section 5 and the unlocks and save data in section 11.

## Built today

A mode select after the title: Grand Tour (stage by stage with standings and points), Single
Race, Time Attack (the best run's ghost per stage and car, `user://ghosts/`) and Free Drive.
Difficulty scales the rivals. Progress, best times and unlocks are saved (`user://save.cfg`).
Four cars and stage 1 are open from the start; the rest unlock as the tour goes
(`scripts/core/unlocks.gd`), or all at once with UNLOCK EVERYTHING in Options. Options persist in
`user://settings.cfg`.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| MP-1 ✓ | **Save data.** `user://save.cfg` with a version number: tour progress, unlocks, best time and best placing per stage and car, total points. Separate from options and input profiles, with a reset in AC-9. | S | 2 | | `test_save` covers round-trip, a missing file and a version bump; tests use a scratch path |
| MP-2 ✓ | **Grand Tour rules.** Top three to advance, cumulative standings over eight stages, one continue when the clock runs out, a final standings screen, the Zenith unlock on finishing. Option: leftover checkpoint time carries over. | M | 2 | RC-2, MP-1 | Rules in plain functions with tests; the e2e smoke plays two stages of a tour |
| MP-3 ✓ | **Single Race.** Any unlocked stage, any unlocked car, rivals and traffic, no standings. Today's flow becomes this mode. | S | 2 | MP-8 | e2e smoke runs one |
| MP-4 ✓ | **Unlocks.** Cars by stage reached (Skipper 2, Mesa 3, Cyclone 4, Phantom 5, Halo 6, Tempest 7, Zenith on finishing, Hauler by a secret), stages by tour progress, paint colors by placings (CP-4), mirror mode per stage won (WS-6). Locked entries show their condition. An "unlock everything" toggle for testing and accessibility (AC-8). | M | 3 | MP-1 | Unlock table in data with a test per rule; car select screenshot with locks |
| MP-5 ✓ | **Time Attack with ghost.** Solo against the clock, no rivals, traffic optional. Record the best run per stage and car as per-tick distance, offset and frame; replay it as a translucent car. | M | 6 | MP-1 | Ghost file round-trip test; a race against a recorded ghost in the e2e smoke |
| MP-6 ✓ | **Free Drive.** No timer, no rivals, traffic optional; the wheel test mode. | S | 6 | MP-8 | e2e smoke enters and quits it |
| MP-7 ✓ | **Difficulty.** Easy, normal, hard: rival pace and rubber-band strength, and the timer option's default. | S | 2 | RC-4 | A `Difficulty` resource per level; tests on the band caps |
| MP-8 ✓ | **Mode select.** A screen after the title: Grand Tour, Single Race, Time Attack, Free Drive, Options. Wheel-drivable. | S | 2 | | e2e smoke reaches each mode; `--screen=modes` screenshot |
| MP-9 ✓ | **Medals.** Bronze, silver and gold times per stage and difficulty, shown on the map, the results screen and stage select. | S | 1 | MP-1 | A medal table per stage with a test that gold beats the autodrive's time; screenshots of the map and results |
| MP-10 ✓ | **Player profiles.** Up to four local profiles, each a preset name and avatar picked from a list (no typing), each with its own save; the title screen shows who is driving. | M | 2 | MP-1 | Save files per profile with migration; `test_save` covers switching; a screenshot of the picker |
| MP-11 ✓ | **Stats page.** Races, wins, crashes, near misses, miles, favourite car and stage, kept in the save and shown from the title. | S | 2 | MP-1 | Counters tested across a race; a screenshot |
| MP-12 | **Sticker book.** Twenty-four stickers (first win, a clean race, every stage, a mirror win, a chain of five...), each awarded once with a chime, on a page in the menus. | M | 3 | MP-11 | Each sticker's condition in a plain function with a test; a screenshot of the page half full |
| MP-13 | **Survival.** An endless road with ramping traffic and a clock that only shrinks at each checkpoint; the score is distance. On mode select, with its own best. | M | 3 | WS-8, MP-1 | The stage loop and ramp in plain functions with tests; an autodrive run that ends |
| MP-14 | **Daily run.** A seeded stage, car, weather and traffic mix per calendar day, the same for everyone, with your best tries for the day. | S | 3 | MP-13 | The seed from the date, tested; a screenshot of the card |

## Open decisions

- Does the Grand Tour continue cost points, or just the standings place? Default: no points, you keep racing from the stage you failed.
- Secret Hauler condition: finish Palm Coast without touching traffic, or a code on the title screen? Default: the clean Palm Coast run.
- Ghosts per car or per stage? Default: per stage and car, since cars differ a lot.

## Stretch

Split-screen two player. The renderer would need two viewports and the HUD a layout per half.
Keep `RoadRenderer` free of global state (see `docs/09` phase 3) so this stays possible.
