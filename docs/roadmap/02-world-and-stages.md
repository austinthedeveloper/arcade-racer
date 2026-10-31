# WS: World and Stages

What the player sees around the road: effects, weather, backgrounds, dressing and the per-stage
features still missing from `docs/01-game-design.md` section 8 and `docs/03-art-direction.md`
section 8.

## Built today

Eight stage classes under `scripts/track/stages/`, each with a theme (colors, background strip,
fog density, traffic count) and a build (road and sprites). Road-spanning sprites and tunnels
with interior rings and darkened road colors. Checkpoint gates, the start gantry, a finish crowd.
Ground colors per stage (sand, snow, water). Jumps. One horizon strip per stage scrolled by
curvature (`scripts/render/background.gd`).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| WS-1 | **FX layer.** A sprite particle layer between the road and the HUD: tire smoke, kick-up by ground type (dust, sand, snow, water), sparks on bumps and barriers, nitro flame and speed lines, a landing puff. Pooled, capped per frame. FX sheets from the round 2 concepts, cut by a `make_fx_sprites.py`. | M | 3 | | Each FX has a trigger test; a screenshot of nitro on Redrock and a splash on Bayou; frame time within budget (EQ-7) |
| WS-2 | **Thunderhead weather.** Rain streaks over the road, wet-road tint, lightning as a full-screen flash with thunder a beat later, grip lowered (RC-12). Flash intensity respects AC-2. | M | 3 | WS-1, AC-2 | Lightning timing in a plain function with a seed; screenshot of a flash; the slider at 0 shows no flash |
| WS-3 | **Multi-layer parallax.** Split each stage background into sky, far and near layers with different scroll rates and a vertical shift on hills. Cut from the round 2 L1/L2/L3 images; the Skyline v2 composite still needs its layers cut or generated (`docs/08`). | L | 3 | | `make_stage_sprites.py` emits three layers per stage; `test_render` checks scroll rates; screenshots of a hill crest on Harvest and a bend on Neon |
| WS-4 | **Neon tunnel walls.** Building faces either side of the tunnel entrance so it is not a free-standing gate; a darker interior ramp and neon strip lights inside. | S | 3 | | Screenshot at the entrance and inside |
| WS-5 | **Race furniture.** Place or drop the nine loaded but unused sprites: tire stack, barrels, cone, barricade, barrier, delineator, inflatable arch, green and brown signs (T4 in `docs/09`). | S | 1 | EQ-2 | No sprite is loaded and never placed; `test_track` asserts it |
| WS-6 | **Mirror mode.** Flip every stage: curves reversed, sprite sides swapped, background mirrored. Unlocked per stage (MP-4). | S | 6 | MP-4 | A mirrored stage finishes in autodrive; its golden trace is the mirror of the original |
| WS-7 | **Road width and lane count.** Per-segment half-width and lanes (2 to 6) in the track builder; narrowings for the Thunderhead roadworks and the Timberline summit; wider boulevards on Palm Coast and Skyline. Traffic lane offsets follow. | M | 4 | | Builder tests for width easing; traffic stays on the road through a narrowing |
| WS-8 | **Stage flow.** Each stage's end dresses like the next stage's start (palette and a landmark), and the results screen crossfades the palette. | S | 6 | RC-5 | Screenshots of each handover |
| WS-9 | **Track preview tool.** An `@tool` script that plots a stage top-down and in side elevation with sprites marked, for authoring. | M | 5 | | Plots all eight stages to PNG headlessly |
| WS-10 | **Round 5 art import.** Skyline pylon v2 (check the opening lines up with the road), red combine, Cyclone v2 sheets after Austin approves the design, hubcap icons. | S | 1 | | Sprites rebuilt by the tools; screenshots of the pylon and the Cyclone |
| WS-11 | **Stage balancing.** Checkpoint spacing and bonuses per timer option, per-stage traffic counts and specials mix, jump sizes. Once with rivals in month 2 and once at the end. | S | 2, 6 | RC-1 | Every stage finishes in autodrive on Tight with time to spare; the table of finish margins is in the commit |

## Open decisions

- Does rain fall on any stage other than Thunderhead, say a wet dawn on Bayou? Default: no, each stage keeps one weather.
- Parallax layer count: three everywhere, or four on stages with a near treeline? Default: three; a fourth only where the concept art has it.
- Is the roadworks chicane a narrowing (WS-7) or cones only, as today? Default: narrowing, once WS-7 lands.

## Stretch

Road forks with a route choice, bridges that show water or canyon under the road edge, a bumper camera.
