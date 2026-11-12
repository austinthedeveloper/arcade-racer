# MP: Modes and Progression

Everything between races: the modes in `docs/01-game-design.md` section 4, the rules in
section 5 and the unlocks and save data in section 11.

## Built today

A mode select after the title: Grand Tour (stage by stage with standings and points), Single
Race, Time Attack (the best run's ghost per stage and car, `user://ghosts/`), Free Drive,
Survival (the open stages chained into one endless road, the checkpoint bonuses shrinking until
the clock runs out, the distance kept as a best: `scripts/race/survival.gd`) and the Daily Run
(a stage, car, weather and traffic mix seeded from the date, the same for everyone, with the
day's best tries: `scripts/race/daily.gd`).
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
| MP-12 ✓ | **Sticker book.** Twenty-four stickers (first win, a clean race, every stage, a mirror win, a chain of five...), each awarded once with a chime, on a page in the menus. | M | 3 | MP-11 | Each sticker's condition in a plain function with a test; a screenshot of the page half full |
| MP-13 ✓ | **Survival.** An endless road with ramping traffic and a clock that only shrinks at each checkpoint; the score is distance. On mode select, with its own best. | M | 3 | WS-8, MP-1 | The stage loop and ramp in plain functions with tests; an autodrive run that ends |
| MP-14 ✓ | **Daily run.** A seeded stage, car, weather and traffic mix per calendar day, the same for everyone, with your best tries for the day. | S | 3 | MP-13 | The seed from the date, tested; a screenshot of the card |
| MP-15 ✓ | **First drive.** A new profile's first race is a guided run on Palm Coast: one prompt at a time when the road allows it (gas, steer, nitro on a straight, draft behind a truck, a power slide), each cleared by doing it. Skippable from the pause menu, never shown again once done or skipped. | M | 4 | MP-10, PR-5 | `test_first_drive` steps every prompt from a scripted run and checks skip; the e2e smoke on a new profile sees the first prompt, an existing profile doesn't; a screenshot of a prompt |
| MP-16 ✓ | **Grand Tour ending.** Finishing the tour ends on a finale: the podium on the Skyline bridge, the tour standings, then credits over the harbor. First place, a podium place and the rest get their own end card. | M | 5 | PR-9, MP-2 | A test that each standings place picks its end card; the e2e reaches the credits from a scripted last stage; screenshots |
| MP-17 ✓ | **Completion page.** One page with what's left: medals, stickers, unlocks, mirror wins, as a percentage per stage. | S | 6 | MP-9, MP-12 | Test the percentage from a fixture save; a menu screenshot |
| MP-18 ✓ | **Split-screen two player.** Two players on one screen, top and bottom halves, each with its own camera and road, sharing the rivals and the traffic. From mode select as 2 PLAYERS, in Single Race and Free Drive. | L | 7 | EQ-7 | `test_split` races two scripted players to both finishes; a screenshot; golden traces unchanged for one player |
| MP-19 | **Two-player select.** Both players pick their car side by side on car select, then one picks the stage. | S | 7 | MP-18 | The e2e drives two players through select; a screenshot |
| MP-20 | **Party modes.** Two party rules for split screen and online: TAG (one car carries the flag, passing it steals it, most time holding wins) and ELIMINATION (last at each checkpoint drops out). | M | 8 | MP-18, ON-3 | Rule tests per mode; screenshots of each HUD |
| MP-21 | **Hot-seat tournament.** Two to four players take turns at Time Attack on the same stages, with a standings board between runs. | S | 8 | MP-5, MP-10 | Test the standings over a scripted round; a screenshot of the board |
| MP-22 | **Stunt run.** A score attack on any stage: no clock, points from air time, near-miss chains and drafting, with a best per stage. | S | 8 | RC-6, RC-15 | Scoring test on a scripted run; a screenshot of the results |
| MP-23 | **Weekly challenge.** A rule set that changes each week (a stage, a car, a twist like no nitro or night), with its own board. | S | 9 | MP-14, ON-18 | The week's seed tested from a date; a screenshot |
| MP-24 | **Friend codes.** Each profile has a code; adding a friend's code shows their times next to yours on the boards. | S | 9 | ON-18 | Test adding and removing a friend; a screenshot |
| MP-25 | **Route tour.** A Grand Tour where each stage's end picks the next stage by the branch you took, so one run covers five of the stages and a full tour needs several. | M | 10 | WS-22, MP-2 | Test the route from a scripted set of choices; a screenshot of the map after a choice |
| MP-26 | **The second tour.** A second Grand Tour on the new stages, unlocked by finishing the first; its own standings, medals and stickers. | S | 11 | WS-25, WS-26, WS-27, WS-28 | The e2e reaches it from a finished save; medal times from its traces |
| MP-27 | **Car mastery.** Races in a car fill its mastery; each level unlocks a livery or paint for that car. | S | 12 | CP-19, MP-10 | Test the levels from a fixture save; a screenshot |
| MP-28 | **Garage screen.** A garage on car select to pick paint, decals, rims and underglow, previewed on the turntable and saved per car and profile. | M | 13 | CP-20, CP-10 | The e2e changes a part and races with it; save test; a screenshot |
| MP-29 | **Custom stages in races.** Saved stages in Single Race, Time Attack and Free Drive, with their own bests and ghosts. | S | 14 | WS-31 | Test a custom stage's best is kept apart |
| MP-30 | **Championship season.** A season of three tours with points carried across, the rivals' standings, and a trophy at the end. | M | 15 | MP-26, MP-2 | Test the points across tours; a screenshot of the standings |
| MP-31 | **Career page.** A summary across seasons: titles, wins, favourite car, distance. | S | 15 | MP-30, MP-11 | Test from a fixture save; a screenshot |

## Sticker book (MP-12)

Twenty-four stickers, each awarded once (the save's `[stickers]`, dated) with a chime (the
checkpoint's, pitched up) and a NEW STICKER card after the line, listed again on the results.
Each condition is a plain function in `scripts/core/stickers.gd`, of the run's facts and the
save; `test_stickers` tests every one. Only the player's own runs earn them (no autodrive, demo,
partway start or online race). The page is the second tab beside STATS, on the title.

| Sticker | Earned by |
|---|---|
| FIRST FINISH | Running a race to the line |
| FIRST WIN | Winning a race against rivals |
| NO CRASHES | Finishing a race without a crash |
| UNTOUCHED | Finishing with traffic on the road without touching it |
| CHAIN OF FIVE | A chain of five near misses |
| THREAD THE NEEDLE | Ten near misses in one race |
| BIG AIR | A BIG AIR jump |
| SLIPSTREAMER | Three slipstreams in one race |
| PERFECT LAUNCH | A LAUNCH! start (not with auto gas) |
| SCAVENGER | Five power-ups in one race |
| LAST GASP | Finishing with 3 seconds or less on the clock |
| OUT OF TIME | Running out of time |
| LOOKING GLASS | Winning a stage mirrored |
| HARD CHARGER | Winning a race on Hard |
| GOLD RUSH | A gold medal time |
| GHOST BUSTER | Beating your ghost in Time Attack |
| SUNDAY DRIVE | 5 miles in one Free Drive |
| GLOBETROTTER | A finish on every stage |
| CLEAN SWEEP | A win on every stage (every mirror opened) |
| ALL GOLD | Gold on every stage, at the difficulty raced |
| GRAND TOURIST | Finishing the Grand Tour |
| CHAMPION | Winning the Grand Tour from stage 1 |
| SHOWROOM | A race in every car |
| LONG HAUL | 100 miles in all |

The save goes to version 6 (`_v5_to_v6`). A save from before the sticker book has none: the save-based ones (GLOBETROTTER, SHOWROOM and
the rest) come with its next race. Mirror wins weren't kept before either, so the completion
page counts them from now on (`mirror_wins` in the save's `[tour]`).

## Completion page (MP-17)

The third tab: a row a stage with its six items ticked off (finish, win, bronze, silver, gold
at the difficulty picked in Options, a mirrored win) and its percentage, and beside it the whole
game's percentage over the stages' items, the stickers and the cars unlocked, the Grand Tour and
the next thing to go for. The sums are `scripts/core/completion.gd`, tested from
`tests/fixtures/save_progress.cfg` (`test_completion`). The unlock-everything option counts for
nothing.

## Split screen (MP-18)

2 PLAYERS on mode select (up and down on its card: SINGLE RACE or FREE DRIVE) races two players
on one screen, player 1 on the top half and player 2 on the bottom, 640x180 each. Each half is
a clipped `Control` holding its own `Background`, `RoadRenderer` and `FxLayer`, which draw their
usual 640x360 frame moved up by `SplitScreen.crop_top()` so the horizon sits a third down the
half; the split camera (`CameraView.SPLIT`, `camera/split_height` and `camera/split_distance`)
sits further back than the near chase so the car fits under it. The two players' cars are the
online model's extra player cars (`RivalCar.remote_player`): player 1's is the race's `player`,
player 2's is in `rivals.cars`, so the standings, the contacts and both roads take them like
any car. The rivals, the traffic, the pickups and the clock are shared; a checkpoint extends the
clock for the first player to reach it, and after player 1's finish the clock runs on for player
2. The results wait for both players and show both.

Controls: player 1 as ever. Player 2 takes the second joypad connected
(`InputRouter.split_pad_of`); with one joypad or none, the keyboard's second set, W A S D with
Tab for nitro, which player 1's keyboard then leaves out (player 1 keeps the arrows and its
other bindings). A split race saves nothing (no bests, stickers, unlocks or stats) and has no
instant replay, hit slow motion or finish slow motion while the other player still races.
`--split` starts one from the command line (`--car2=ID` for player 2's car).

Left for later: two-player select (MP-19; player 2 gets the next car open after player 1's,
`SplitScreen.second_car`), the split HUD's polish (PR-27, `SplitHud`), device assignment
(WH-18) and assists per player (AC-19; `Race.split_input` gives player 2 none yet).

## Open decisions

- Does the Grand Tour continue cost points, or just the standings place? Default: no points, you keep racing from the stage you failed.
- Secret Hauler condition: finish Palm Coast without touching traffic, or a code on the title screen? Default: the clean Palm Coast run.
- Ghosts per car or per stage? Default: per stage and car, since cars differ a lot.

## Stretch

Split-screen two player is built (MP-18, above).
