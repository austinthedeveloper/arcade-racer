# RC: Racing Core

The systems that run inside a race: rivals, positions, scoring, collisions and the driving
tricks the design doc promises (`docs/01-game-design.md` sections 5, 6, 9 and 10).

## Built today

Player driving model in track space (`scripts/car/player_car.gd`): acceleration curve, braking,
centrifugal pull, off-road slowdown, nitro, air time, hill pitch, bump and crash with respawn.
Same-direction traffic in four lanes with big vehicles and stage specials (`scripts/car/traffic.gd`).
Seven seeded rivals (`RivalCar`, `AIDriver`, `Rivals`) with personalities and rubber banding
(`RivalProfile`), positions on the HUD, drafting (`Draft`), the rolling start and launch boost
(`Launch`), scoring bonuses and points per place (`Scoring`), and the results screen. Side-swipes
and rammed cars behave (RC-9). Countdown, checkpoints with time bonus, finish and time-up
(`scripts/race/race.gd`). Power-ups (`scripts/race/power_ups.gd`). Per-car tuning from the 1 to 5
stats (`scripts/car/cars.gd`).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| RC-1 ✓ | **AI rivals v1.** Seven rivals as `RivalCar` plus `AIDriver`: start from a grid on the first straight, follow a target lateral line derived from the curves, look a few segments ahead to avoid traffic and each other, use nitro on straights. Drawn with the car's existing steer strip (CP-5 replaces it). Seeded RNG so autodrive runs are repeatable. | L | 1 | EQ-2, EQ-5 | Seven rivals finish every stage in autodrive; `test_rivals` covers line following, avoidance and the seed; golden traces regenerated with rivals, as their own commit |
| RC-2 ✓ | **Positions.** Sort player and rivals by distance each tick; "3/8" on the HUD; rival dots on the progress bar. | S | 1 | RC-1 | Position changes when a rival is passed; test on a scripted overtake |
| RC-3 ✓ | **Rolling start and launch boost.** The field rolls on the grid during the countdown; full throttle within a window around GO gives a short speed bonus, too early gives a bog. | S | 2 | RC-1 | Test the window edges; the banner says LAUNCH |
| RC-4 ✓ | **Rival personalities and rubber banding.** Aggressive (blocks the line), clean, erratic (late lane changes). Rivals ahead ease off and rivals behind get a small boost, scaled by difficulty (MP-7), capped so it never looks like cheating. Rivals crash into traffic and respawn like the player. | M | 2 | RC-1 | A `RivalProfile` resource per rival; test that the band cannot exceed its cap; a screenshot of a rival crash |
| RC-5 ✓ | **Results screen.** After the finish: place, race time, each bonus, points, best-time mark; continue to the next stage, retry, or quit. Replaces the finish banner plus Enter. | M | 2 | RC-2, PR-7 | The e2e smoke reaches the results screen and continues; `--autodrive` runs still finish |
| RC-6 ✓ | **Scoring bonuses.** Near miss (passing traffic within a lane fraction at speed), air time, clean section (no contact between checkpoints), no-crash race, drafting. Points per placing. Each bonus fires a callout (PR-5). | M | 2 | RC-2 | Plain functions per bonus with tests; the results screen lists them |
| RC-7 ✓ | **Drafting.** Sitting close behind a rival or big vehicle fills a slipstream meter; full meter gives a few seconds of extra top speed. Shown as a small bar on the HUD. | S | 2 | RC-1 | Test fill, decay and the boost; feels right in a screenshot sequence behind a semi |
| RC-8 ✓ | **Power slide.** Brake while steering above a speed threshold enters a slide: tighter turn, small speed loss, tire squeal, smoke (WS-1), slide sprite frames (CP-3, steer strip extremes until then). | M | 4 | WS-1 | Test entry, exit and the speed loss; golden traces regenerated |
| RC-9 ✓ | **Collision fixes.** Side-swipes are no longer rear-ends (G3): check which car is ahead within the segment. Rammed cars drift back onto the road before they turn solid (G4). | S | 2 | EQ-5 | Tests from `docs/09`; traces regenerated |
| RC-10 ✓ | **Manual gears.** Optional paddles or buttons; a small top-end advantage; the rev model in `race_audio.gd` already has five gears. | S | 6 | WH-2 | Option in AC; test that automatic and manual reach the same speed within the advantage |
| RC-11 ✓ | **Oncoming traffic and lane-change tells.** Oncoming vehicles on undivided roads using the front-view frames; some traffic changes lanes after flashing a turn signal for a second. | M | 4 | CP-6 | A stage flag for divided roads; test that a signalling car changes lanes after the delay; traces regenerated |
| RC-12 ✓ | **Grip per surface.** A theme grip value: Thunderhead's wet road widens slides and off-road feel; snow at Timberline's summit slightly lower. | S | 3 | WS-2 | Test the steer rate scales with grip; traces regenerated |
| RC-13 ✓ | **Horn moves traffic.** Honk close behind a slower car and it eases toward its lane edge after a beat (big rigs and the stage specials ignore it), so the horn does something in play. | S | 1 | PR-3 | Test: a honked car changes lane, a rig doesn't; golden traces unchanged (the autodrive never honks) |
| RC-14 ✓ | **Fair traffic.** No traffic spawns in the lane ahead of a blind crest, a tunnel mouth or the player's respawn point, and a crashed car comes back in a clear lane. | S | 1 | RC-9 | Tests for each spawn rule; traces regenerated with the reason |
| RC-15 ✓ | **Near-miss chains.** Near misses within two seconds of each other chain (x2, x3...), the callout shows the chain and the points scale with it. | S | 1 | RC-6, PR-5 | Scoring test for a chain and its break; a screenshot of NEAR MISS x3 |
| RC-16 ✓ | **Catch-up nitro.** Reaching a checkpoint in the last two places refills one nitro charge, on easy and normal; hard gives nothing. | S | 1 | MP-7 | Test per difficulty and place; traces regenerated |
| RC-17 | **Instant replay.** The last six seconds before the finish replay once from a recorded trace of every car (the ghost recorder's data), skippable with any button. | M | 2 | MP-5, RC-5 | Replay built in a plain function from a trace; a test that it ends on the finish frame; a screenshot |
| RC-18 ✓ | **Rival cards and radar.** Before GO, a card per rival (name, car, style); in the race, a small arrow on the HUD when a rival is within a second behind or ahead. | S | 2 | RC-4, PR-6 | Layout test for the cards and the arrow; screenshots of both |
| RC-19 | **Road hazards.** Debris, a cone row, an ice patch on Timberline's summit and puddles on Thunderhead, placed per stage from the hazard sheets: a bump, a slide or a slow, each with a callout. | M | 2 | RC-12, WS-2 | Tests for each hazard's effect; traces regenerated; a screenshot per hazard |
| RC-20 ✓ | **Traffic density along a stage.** A per-stretch traffic weight in the stage scripts: towns busy, the desert and the summit empty, so each stage has a rhythm. | S | 2 | WS-11 | `test_track` checks every stage's weights; traces regenerated |

## Open decisions

- Does a rival that crashes lose a position for long, or respawn alongside like the player? Default: same respawn, so the field stays close.
- Points per placing: 8 cars, so 20/15/12/10/8/6/4/2 as a starting table, bonuses on top.
- Should the slipstream meter be visible, or only the speed and a wind sound? Default: visible, small.

## Test notes

Rivals are the first system that changes every golden trace. Regenerate them once in RC-1, as
their own commit with the reason, and keep RC-2 to RC-7 behavior-neutral for the traffic (the
rivals get their own trace columns). Every bonus and the rubber-band cap live in plain functions.
