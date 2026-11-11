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
| RC-17 ✓ | **Instant replay.** The last six seconds before the finish replay once from a recorded trace of every car (the ghost recorder's data), skippable with any button. | M | 2 | MP-5, RC-5 | Replay built in a plain function from a trace; a test that it ends on the finish frame; a screenshot |
| RC-18 ✓ | **Rival cards and radar.** Before GO, a card per rival (name, car, style); in the race, a small arrow on the HUD when a rival is within a second behind or ahead. | S | 2 | RC-4, PR-6 | Layout test for the cards and the arrow; screenshots of both |
| RC-19 | **Road hazards.** Debris, a cone row, an ice patch on Timberline's summit and puddles on Thunderhead, placed per stage from the hazard sheets: a bump, a slide or a slow, each with a callout. | M | 2 | RC-12, WS-2 | Tests for each hazard's effect; traces regenerated; a screenshot per hazard |
| RC-20 ✓ | **Traffic density along a stage.** A per-stretch traffic weight in the stage scripts: towns busy, the desert and the summit empty, so each stage has a rhythm. | S | 2 | WS-11 | `test_track` checks every stage's weights; traces regenerated |
| RC-21 ✓ | **Rival balance pass.** Every stage at every difficulty gets a target finishing spread (the field within a set number of seconds, the player's autodrive placing where the difficulty says). A soak run (EQ-22) reports the gaps per stage, the rival numbers are tuned in `Tuning.TABLE` and adopted with EQ-17. | M | 4 | EQ-22, EQ-17 | A report table in this doc per stage and difficulty; `test_golden` checks each stage's spread stays in its band; traces regenerated with the reason |
| RC-22 ✓ | **Crash feel v2.** The tumble scales with the speed of the hit, a big hit holds a few frames of slow motion (off with reduce motion), and the respawned car is ghosted for a second so it can't be hit again at once. | S | 4 | CP-3, AC-13 | Tests for the tumble length by speed and the ghost window; reduce motion skips the slow motion; traces regenerated |
| RC-23 ✓ | **Clock per difficulty.** The checkpoint time bonuses scale with difficulty, so easy is generous and hard is tight, each checked against the autodrive. | S | 5 | MP-7 | Test the autodrive reaches every checkpoint on hard with a set margin; traces unchanged on normal |
| RC-24 | **Handicap.** A 2-player handicap slider: the trailing player gets a capped speed and nitro boost, off by default. | S | 7 | MP-18 | Test the boost cap and that it's zero when off |
| RC-25 | **Rivals and traffic at forks.** Rivals pick a branch by personality and position; traffic keeps to its branch. | M | 10 | WS-22 | Tests for the branch choice and traffic per branch; traces for a forked stage |
| RC-26 | **Patrol car.** On the open stages a patrol car joins after a run of near misses at top speed and tries to box you in for a stretch; outrun it for a bonus. | M | 10 | RC-15, RC-11 | Tests for the trigger, the chase and the bonus; a screenshot |
| RC-27 | **Car traits v2.** Each new car gets a trait like the Mesa's and the Halo's: the microcar is narrower in traffic, the wagon drafts harder, the tourer's nitro lasts longer, the pickup shrugs off bumps. | M | 12 | CP-18 | A test per trait; traces unchanged for the old cars |
| RC-28 | **Nemesis.** One rival becomes your nemesis over a tour: picked from who beats you most, they drive harder against you and get a line before and after each race. | M | 12 | RC-4, RC-18 | Tests for the pick and the extra aggression's cap; a screenshot of the card |
| RC-29 | **Car setup.** Two arcade sliders per car, grip against top speed and nitro length against count, inside capped ranges. Leaderboards split stock and tuned times. | M | 13 | ON-18 | Tests for the caps; traces unchanged on stock |

## Rival balance (RC-21)

The autodrive's race (traffic, rivals, the Vega, each difficulty's own timer) per stage and
difficulty, from `tools/soak.sh --report` after the pass. *Spread* is first to last across the
line with the autodrive among them; *Clock* the least time left arriving at a checkpoint or the
line (below zero: the clock ran out first; RC-23 is about that). Seconds.

| Stage | Difficulty | Autodrive | Place | Winner | Last | Spread | Clock |
|---|---|---|---|---|---|---|---|
| Palm Coast Boulevard | Easy | 108.1 | 1ST | 108.1 | 118.4 | 10.3 | 23.7 |
| Palm Coast Boulevard | Normal | 102.0 | 2ND | 98.3 | 120.7 | 22.3 | 18.3 |
| Palm Coast Boulevard | Hard | 102.4 | 2ND | 98.9 | 111.1 | 12.2 | 6.2 |
| Redrock Canyon | Easy | 98.1 | 2ND | 90.5 | 101.6 | 11.1 | 15.8 |
| Redrock Canyon | Normal | 100.0 | 5TH | 84.5 | 101.6 | 17.0 | 4.4 |
| Redrock Canyon | Hard | 97.7 | 5TH | 84.5 | 101.2 | 16.6 | -5.6 |
| Neon Strip | Easy | 79.4 | 1ST | 79.4 | 100.1 | 20.8 | 38.7 |
| Neon Strip | Normal | 79.4 | 2ND | 73.3 | 98.7 | 25.4 | 23.8 |
| Neon Strip | Hard | 85.7 | 3RD | 73.5 | 99.1 | 25.6 | 16.8 |
| Timberline Pass | Easy | 103.0 | 1ST | 103.0 | 112.4 | 9.5 | 13.6 |
| Timberline Pass | Normal | 84.0 | 1ST | 84.0 | 112.8 | 28.8 | 6.8 |
| Timberline Pass | Hard | 98.6 | 3RD | 96.2 | 113.2 | 17.0 | -7.1 |
| Bayou Causeway | Easy | 76.3 | 1ST | 76.3 | 105.1 | 28.8 | 16.6 |
| Bayou Causeway | Normal | 82.5 | 2ND | 80.0 | 96.0 | 16.0 | 7.4 |
| Bayou Causeway | Hard | 86.8 | 2ND | 85.5 | 97.5 | 12.0 | -2.0 |
| Harvest Valley | Easy | 91.8 | 1ST | 91.8 | 107.0 | 15.2 | 37.4 |
| Harvest Valley | Normal | 87.8 | 1ST | 87.8 | 104.1 | 16.3 | 20.3 |
| Harvest Valley | Hard | 85.6 | 2ND | 84.9 | 107.2 | 22.3 | 17.2 |
| Thunderhead Highway | Easy | 71.3 | 1ST | 71.3 | 93.9 | 22.6 | 10.2 |
| Thunderhead Highway | Normal | 75.7 | 1ST | 75.7 | 89.8 | 14.1 | 1.7 |
| Thunderhead Highway | Hard | 77.3 | 3RD | 69.3 | 89.5 | 20.2 | -0.2 |
| Skyline Finale | Easy | 103.8 | 1ST | 103.8 | 142.1 | 38.3 | 31.5 |
| Skyline Finale | Normal | 101.3 | 1ST | 101.3 | 139.4 | 38.1 | 16.3 |
| Skyline Finale | Hard | 101.3 | 1ST | 101.3 | 127.1 | 25.7 | 10.5 |

The bands (`Soak.BANDS`, checked by `test_golden` on every stage and difficulty): the spread
at most 38 s on every difficulty, Skyline's 46; the autodrive 1st to 4th on Easy, to 6th on
Normal, to 7th on Hard. They were 30 s (Skyline 42) and 3rd, 5th and 6th after this pass; the
crash feel (RC-22) then reshuffled the close fields (Redrock: the autodrive 4th on Easy and
6th on Normal; Timberline on Easy 36 s from first to last), which is what a play change does
to a field this close, so the bands are as wide as several draws of the field went.

What the pass changed, deliberately little since the game is balanced by feel:

- **A stuck rival** (found by the soak, EQ-22): a rival that ran up behind a car standing still
  (the player after TIME UP) sat behind it for good. It now edges round.
- **Easy waits a little longer**: `difficulty/easy_ease` 0.07 to 0.08 (the band's cap). Over
  three draws of the field per stage the autodrive finished off the podium on Easy in 3 of 24
  races before, 1 after (a pack finish on Redrock).
- **Skyline left as it is**: whoever reaches the downtown jam (RC-20) among the traffic loses
  about half a minute there, so its last rival comes home near 140 s on every difficulty. A
  quicker field (`balance/skyline` 1.03 to 1.07) didn't bring that rival home sooner, only
  got in the autodrive's way, so the band allows it instead.
- **Hard's clock** runs out on Redrock, Timberline, Bayou and Thunderhead for the autodrive:
  that's RC-23's.
- The rival numbers are now in `Tuning.TABLE` for the F3 panel: each difficulty's pace and
  rubber band (`difficulty/*`) and a pace per stage on top (`balance/*`, all 1), with a rival's
  base pace capped at its car's top speed (`Rivals.MAX_PACE`).

## Clock per difficulty (RC-23)

Each checkpoint's time bonus is the stage's (WS-11) after the timer option, times the
difficulty's `difficulty/*_clock`: 1.1 on Easy, 1 on Normal, 0.9 on Hard. Hard used to put the
timer on TIGHT (x0.85 on the start time and every bonus), and on that the autodrive's clock ran
out on Redrock, Timberline, Bayou and Thunderhead, the last three before the first checkpoint,
where no bonus helps. So Hard now starts on ARCADE and is tight through its bonuses alone.
The least time the autodrive has left at a checkpoint or the line on Hard (with crash feel,
RC-22): Palm Coast 13.3 s, Redrock 2.9, Neon 22.8, Timberline 4.9, Bayou 3.2, Harvest 20.3,
Thunderhead 3.0, Skyline 16.5 (Normal: 10.5, 6.8, 23.7, 5.6, 7.2, 22.0, 3.2, 16.3).
`test_golden` holds every stage on Easy and Hard to `Soak.CLOCK_MARGIN`, 2 s; 0.85 would leave
Redrock 0.9 s. Normal is unchanged, so are its traces.

## Open decisions

- Does a rival that crashes lose a position for long, or respawn alongside like the player? Default: same respawn, so the field stays close.
- Points per placing: 8 cars, so 20/15/12/10/8/6/4/2 as a starting table, bonuses on top.
- Should the slipstream meter be visible, or only the speed and a wind sound? Default: visible, small.

## Test notes

Rivals are the first system that changes every golden trace. Regenerate them once in RC-1, as
their own commit with the reason, and keep RC-2 to RC-7 behavior-neutral for the traffic (the
rivals get their own trace columns). Every bonus and the rubber-band cap live in plain functions.
