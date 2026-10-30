# Concept Review: Round 1

Reviewed 2026-10-30. 9 images in `assets/concept/`.

## Verdict

Pixel art is the right call. **`ka02_gameplay_palm_A_v1.png` is the target style frame** for the game. The art should look like that screenshot. B and C are good images but read as "modern illustration", and C loses the pixel crunch that makes speed feel arcade.

## Per image

| Image | Keep? | Notes |
|---|---|---|
| **KA-02 A** (Palm gameplay, pixel) | **Target** | Horizon around 38%, wide 4-lane road, rumble strips, lifeguard tower and blank billboard all read instantly. Pixel density on the car is finer than on the trees; production should use one pixel scale everywhere. Minimap bottom-left suggests a circuit; we're point-to-point, so it becomes a progress bar. |
| KA-02 B (pre-rendered) | Reference only | Motion blur and soft shading. Nice, not our style. |
| KA-02 C (painted) | Reference only | Warmest color of the three. Worth borrowing its **sunset grading** for Harvest Valley / Skyline. |
| **KA-01** (title) | Keep for mood | Great energy, sparks and dust are exactly the tone. Car design needs to change (see below). |
| **KA-03** (Neon night) | **Strong keep** | Best image of the set. Tunnel mouth, neon facades, wet-road reflections. Reflections are the expensive part: in-engine we'll fake them with tinted reflection sprites under cars and signs plus banded road colors, not a real reflection pass. |
| **Vega hero** | Redesign | Reads too much like a famous real 80s Italian supercar (side strakes, louvered deck, wing). |
| **Bruiser hero** | Redesign lightly | Strong silhouette, but too close to a real late-60s American pony car, and the winged badge is close to a real brand mark. |
| **Palm Coast composite** | Keep | Lovely palette and clouds. Pier + ferris wheel + island are great landmarks. Needs splitting into L1 sky / L2 far / L3 near layers next. |
| **Palms roadside** | **Near-production** | 7 good variants, clean silhouettes. Issues: pink anti-aliased fringe from the magenta key on the fronds, inconsistent pixel grid. Needs a downscale to the real sprite size plus a cleanup pass. Tall straight palms can be mirrored for both sides of the road. |

## Big issue: cars look like real cars

Generators drift toward famous real cars when you say "wedge supercar" or "muscle coupe". We can't ship lookalikes. I updated the prompts:

- **Vega GT:** wraparound glass canopy, two short tail fins instead of a wing, triangular taillights joined by a glowing bar, single central exhaust, smooth sides with one deep scoop. Explicitly no strakes, slats or louvers.
- **Bruiser 440:** fastback roof, raised ducktail spoiler, twin snorkel hood scoops, three stacked taillight bars per side, side-exit exhausts.
- Every car prompt and the negative prompt now say "not resembling any real production car".
- KA-01 / KA-02 prompts describe the new Vega so rerolls match.

## Scale check against the spec

At 640x360, the player car in KA-02 A works out to roughly 215 px wide, versus the 160 px in the art doc. The bigger car looks better and matches the genre, so I suggest **~200 px wide player car** and I'll update the spec when we lock it.

## Next round

1. Reroll **CAR-VEGA-01** and **CAR-BRUISER-01** with the new prompts.
2. **CAR-VEGA-03** steering sheet, to test whether the generator can hold a design across 7 frames. If it can't, that settles the "pre-render cars from 3D models" question.
3. **BG-PALM-02/03/04** separate parallax layers.
4. **RS-PALM-02/03/04** (beach props, buildings, billboards).
5. **UI-01** logo (still missing from Round 1).
