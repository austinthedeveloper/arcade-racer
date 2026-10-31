# Roadmap: November 2026 to April 2027

Written 2026-10-31 from the design docs (`docs/01` to `04`), the concept reviews (`05` to `08`),
the known-bugs doc (`09`), the README and the code. This folder is the feature list for the next
six months, split into eight groups so each area can be planned and ticked off on its own.

| Group | Doc | Covers |
|---|---|---|
| RC | [01-racing-core.md](01-racing-core.md) | Rivals, positions, scoring, results, drafting, slides, collisions |
| WS | [02-world-and-stages.md](02-world-and-stages.md) | FX, weather, parallax layers, stage dressing, mirror mode |
| CP | [03-cars-and-art-pipeline.md](03-cars-and-art-pipeline.md) | Production car sprites, paint colors, traffic frames, UI art |
| WH | [04-input-and-wheels.md](04-input-and-wheels.md) | Steering lock, remapping, force feedback, Windows wheel pass |
| PR | [05-presentation-audio-ui.md](05-presentation-audio-ui.md) | Sound pack, music radio, announcer, HUD v2, menus, callouts |
| MP | [06-modes-and-progression.md](06-modes-and-progression.md) | Save data, Grand Tour rules, unlocks, Time Attack, Free Drive |
| AC | [07-options-and-accessibility.md](07-options-and-accessibility.md) | Display, assists, sliders, colorblind HUD, subtitles, units |
| EQ | [08-engineering-and-quality.md](08-engineering-and-quality.md) | Cleanup phases, tests, performance, releases, doc sync |

## Where the game stands (2026-10-31, v0.1.0)

**Built.** Pseudo-3D renderer with curves, hills, jumps, hill pitch, fog, road-spanning sprites
and tunnels. Eight stages drivable back to back. Twelve cars with stat-based tuning. Same-direction
traffic with stage specials. Five power-ups with an option to turn them off. Checkpoint timer,
nitro, crash and respawn. Title, options, stage and car select; options for auto gas, traffic,
timer and volume. Wheel calibration, saved profiles, the F1 input overlay. Placeholder audio with
a gear-and-rev engine model. Windows, macOS and Web exports, CI, a tag-driven release workflow,
golden traces for every stage.

**Not built.** AI rivals, positions, a results screen, scoring and bonuses, Grand Tour standings,
unlocks and save data, drafting, power slides, the launch boost, manual gears, an FX layer,
weather, multi-layer parallax, the music radio, the announcer, force feedback, steering lock and
remap options, Time Attack, Free Drive, production car sprites, paint colors, oncoming traffic
and turn-signal tells.

## The six months at a glance

Capacity assumption: one developer part time, plus Claude. About four medium items a month,
or one large item and two small ones. Each month ends with a tagged pre-release so there is
always a build to play.

| Month | Theme | Headline features | Release |
|---|---|---|---|
| **1. Nov 2026** | Stabilize and race the field | Cleanup phases 1 to 4 ([EQ-2](08-engineering-and-quality.md) to EQ-5), doc sync (EQ-1), round 5 art import (WS-10), AI rivals v1 (RC-1) and positions (RC-2), steering lock option (WH-1) | v0.2.0 |
| **2. Dec 2026** | Finish the race loop | Results screen (RC-5), scoring and callouts (RC-6, PR-5), rival personalities and rubber banding (RC-4), drafting (RC-7), launch boost (RC-3), save data (MP-1), Grand Tour rules (MP-2), Single Race and mode select (MP-3, MP-8), pause menu (PR-12), difficulty (MP-7) | v0.3.0 |
| **3. Jan 2027** | Stages come alive | FX layer (WS-1), Thunderhead weather (WS-2), multi-layer parallax (WS-3), Neon tunnel walls (WS-4), HUD v2 (PR-6), finish fireworks (PR-9), unlocks (MP-4), display and slider options (AC-1, AC-2), colorblind HUD (AC-4), MPH/KPH (AC-6), first performance pass (EQ-7) | v0.4.0 |
| **4. Feb 2027** | Production cars | 3D-to-sprite pipeline on the Vega (CP-1), roll-out starts (CP-2), crash and slide frames (CP-3), rival angle frames (CP-5), traffic front views and light states (CP-6), oncoming traffic and lane-change tells (RC-11), power slide (RC-8), lane count and road width (WS-7) | v0.5.0 |
| **5. Mar 2027** | Sound and wheels | Sound pack (PR-1), music radio (PR-2), wind and whooshes (PR-3), announcer (PR-4), force feedback extension (WH-3, EQ-11), known-wheel profiles (WH-4), Windows wheel pass (WH-5), remapping (WH-2), paint colors (CP-4), remaining car roll-out (CP-2), sprite LOD (CP-9) | v0.6.0 |
| **6. Apr 2027** | Modes and polish | Time Attack with ghost (MP-5), Free Drive (MP-6), mirror mode (WS-6), map stage select and turntable (PR-8, CP-10), attract mode (PR-11), assists (AC-3), subtitles (AC-5), manual gears (RC-10), balancing (WS-11), signing and notarization (EQ-9), web and Linux checks (EQ-10, EQ-13), legal art pass (CP-12) | v0.7.0, the 1.0 candidate |

## Dependency chain

The order above follows these dependencies. Moving an item earlier means moving what it needs.

- **Cleanup before rivals.** EQ-2 fixes the collision and bump code (G1, G2) and EQ-5 strengthens
  the golden traces. Rivals (RC-1) build on both, so they land first.
- **Rivals before everything that scores.** Positions (RC-2), results (RC-5), scoring (RC-6),
  Grand Tour standings (MP-2) and difficulty (MP-7) all need rivals on the road.
- **Save data before unlocks.** MP-1 before MP-4, and before best times and ghosts (MP-5).
- **FX layer before weather.** WS-1 gives rain, lightning and kick-up a place to draw; AC-2's
  sliders ship with it so lightning is never forced on.
- **The Vega pipeline before the other cars.** CP-1 proves the 3D-to-sprite pipeline; CP-2 to
  CP-5 and paint colors (CP-4) reuse it. Rivals use today's steer strips until CP-5 arrives.
- **Traffic front views before oncoming traffic.** CP-6 before RC-11.
- **The FFB extension needs a build pipeline.** EQ-11 ships with WH-3.
- **Sound pack and music are sourcing problems first.** PR-1, PR-2 and PR-4 need original audio
  found or commissioned; start the search in month 3 so month 5 is integration, not waiting.

## Risks

| Risk | Where it bites | Mitigation |
|---|---|---|
| Original music and voice lines are not in hand | PR-2, PR-4 | Pick a source by month 3; a license-safe library is the fallback, synthesized placeholders stay until then |
| The 3D-to-sprite pipeline is new work with new tools | CP-1 | One car first, time-boxed to two weeks; if it fails, hand-pixel the Vega and keep the concept-sheet cars |
| Force feedback on macOS is patchy | WH-3 | Build and test on Windows first; the FFB autoload is a no-op where unsupported |
| Rivals change every golden trace | RC-1 | Seed the rivals' RNG and regenerate the traces as their own commit |
| One developer, six themes | Everything | Each month has a release, so slipping an item moves it to the next month rather than breaking a build |

## Tracking on GitHub

The feature list is mirrored on GitHub (populated 2026-10-31), and the docs stay the source of the
wording while GitHub tracks state:

- **Issues.** One per feature, titled with its ID (`RC-8 Power slide`), labelled with its group
  (`RC: racing core` and so on), its size (`size: S`, `M`, `L`) and `roadmap`. Dependencies in the
  body read `WS-1 (#28)`, so GitHub cross-links them.
- **Milestones.** M1 (November 2026) to M6 (April 2027), one per month of the table above, each
  with its theme and due date. The milestones page is the month-by-month roadmap.
- **Project.** [arcade racer roadmap](https://github.com/users/austinthedeveloper/projects/4) holds
  every issue with Month, Group, Size, Start date and Target date fields, and a Status of Backlog,
  Todo, In progress or Done. Month 1 starts in Todo, the rest in Backlog.

When a feature is finished, close its issue; the project item follows. When a group doc changes a
feature, update its issue to match. A new feature takes the next ID in its group doc and gets an
issue in the same shape.

## Reading the group docs

Each group doc has the same shape: what is built today, a feature table, open decisions and test
notes. Feature IDs are the group code plus a number (RC-1). Columns:

- **Size.** S is a day or two. M is about a week. L is two weeks or more.
- **Month.** 1 to 6 as in the table above. "Stretch" means after April 2027 unless a month runs light.
- **Needs.** Other feature IDs or docs this depends on.
- **Done when.** The check that closes the item, including the test it adds.

## Out of these six months

Split-screen two player, road forks and route choice, online play, car customization beyond paint,
Steam Deck and Linux as supported platforms (EQ-13 only checks the build), and polygon anything.
Open questions 3 (which wheel) and 10 (which image generator) in `docs/04-open-questions.md`
still need answers from Austin; 11 and 12 are decided by what was built.

## Doc debt found in this analysis

These are tracked as EQ-1 and should be fixed in month 1.

- `docs/02-technical-design.md` section 10 still says Skyline is held back, the garage is
  Vega-only and spans are skipped. It has nothing on power-ups, tuning, drive-throughs or traffic
  specials (bug T3 in `docs/09`).
- `README.md` says seven stages and one car; it is eight and twelve. Its docs list stops at `06`.
- `docs/01-game-design.md` lists eight cars and calls Skyline a reroll in progress. The four
  round 4 cars are in the game, so the roster table should be twelve.
- `docs/03-art-direction.md` still presents the style choice as open; `docs/05` decided pixel art.
- `docs/04-open-questions.md` marks power-ups and the four cars as proposals; both are built.
