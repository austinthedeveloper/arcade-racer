# RC: Racing Core

The systems that run inside a race: rivals, positions, scoring, collisions and the driving
tricks the design doc promises (`docs/01-game-design.md` sections 5, 6, 9 and 10).

## Built today

Player driving model in track space (`scripts/car/player_car.gd`): acceleration curve, braking,
centrifugal pull, off-road slowdown, nitro, air time, hill pitch, bump and crash with respawn.
Same-direction traffic in four lanes with big vehicles and stage specials (`scripts/car/traffic.gd`).
Countdown, checkpoints with time bonus, finish and time-up (`scripts/race/race.gd`). Power-ups
(`scripts/race/power_ups.gd`). Per-car tuning from the 1 to 5 stats (`scripts/car/cars.gd`).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| RC-1 | **AI rivals v1.** Seven rivals as `RivalCar` plus `AIDriver`: start from a grid on the first straight, follow a target lateral line derived from the curves, look a few segments ahead to avoid traffic and each other, use nitro on straights. Drawn with the car's existing steer strip (CP-5 replaces it). Seeded RNG so autodrive runs are repeatable. | L | 1 | EQ-2, EQ-5 | Seven rivals finish every stage in autodrive; `test_rivals` covers line following, avoidance and the seed; golden traces regenerated with rivals, as their own commit |
| RC-2 | **Positions.** Sort player and rivals by distance each tick; "3/8" on the HUD; rival dots on the progress bar. | S | 1 | RC-1 | Position changes when a rival is passed; test on a scripted overtake |
| RC-3 | **Rolling start and launch boost.** The field rolls on the grid during the countdown; full throttle within a window around GO gives a short speed bonus, too early gives a bog. | S | 2 | RC-1 | Test the window edges; the banner says LAUNCH |
| RC-4 | **Rival personalities and rubber banding.** Aggressive (blocks the line), clean, erratic (late lane changes). Rivals ahead ease off and rivals behind get a small boost, scaled by difficulty (MP-7), capped so it never looks like cheating. Rivals crash into traffic and respawn like the player. | M | 2 | RC-1 | A `RivalProfile` resource per rival; test that the band cannot exceed its cap; a screenshot of a rival crash |
| RC-5 | **Results screen.** After the finish: place, race time, each bonus, points, best-time mark; continue to the next stage, retry, or quit. Replaces the finish banner plus Enter. | M | 2 | RC-2, PR-7 | The e2e smoke reaches the results screen and continues; `--autodrive` runs still finish |
| RC-6 | **Scoring bonuses.** Near miss (passing traffic within a lane fraction at speed), air time, clean section (no contact between checkpoints), no-crash race, drafting. Points per placing. Each bonus fires a callout (PR-5). | M | 2 | RC-2 | Plain functions per bonus with tests; the results screen lists them |
| RC-7 | **Drafting.** Sitting close behind a rival or big vehicle fills a slipstream meter; full meter gives a few seconds of extra top speed. Shown as a small bar on the HUD. | S | 2 | RC-1 | Test fill, decay and the boost; feels right in a screenshot sequence behind a semi |
| RC-8 | **Power slide.** Brake while steering above a speed threshold enters a slide: tighter turn, small speed loss, tire squeal, smoke (WS-1), slide sprite frames (CP-3, steer strip extremes until then). | M | 4 | WS-1 | Test entry, exit and the speed loss; golden traces regenerated |
| RC-9 | **Collision fixes.** Side-swipes are no longer rear-ends (G3): check which car is ahead within the segment. Rammed cars drift back onto the road before they turn solid (G4). | S | 2 | EQ-5 | Tests from `docs/09`; traces regenerated |
| RC-10 | **Manual gears.** Optional paddles or buttons; a small top-end advantage; the rev model in `race_audio.gd` already has five gears. | S | 6 | WH-2 | Option in AC; test that automatic and manual reach the same speed within the advantage |
| RC-11 | **Oncoming traffic and lane-change tells.** Oncoming vehicles on undivided roads using the front-view frames; some traffic changes lanes after flashing a turn signal for a second. | M | 4 | CP-6 | A stage flag for divided roads; test that a signalling car changes lanes after the delay; traces regenerated |
| RC-12 | **Grip per surface.** A theme grip value: Thunderhead's wet road widens slides and off-road feel; snow at Timberline's summit slightly lower. | S | 3 | WS-2 | Test the steer rate scales with grip; traces regenerated |

## Open decisions

- Does a rival that crashes lose a position for long, or respawn alongside like the player? Default: same respawn, so the field stays close.
- Points per placing: 8 cars, so 20/15/12/10/8/6/4/2 as a starting table, bonuses on top.
- Should the slipstream meter be visible, or only the speed and a wind sound? Default: visible, small.

## Test notes

Rivals are the first system that changes every golden trace. Regenerate them once in RC-1, as
their own commit with the reason, and keep RC-2 to RC-7 behavior-neutral for the traffic (the
rivals get their own trace columns). Every bonus and the rubber-band cap live in plain functions.
