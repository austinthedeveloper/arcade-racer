# Template: new player car (art)

Fill the placeholders, paste each prompt into the image generator, save the results under the
exact file names below, then follow `docs/templates/new-car.md`. Keep a filled copy as
`assets/prompts/cars/car_{{id}}.md` (same layout as `car_vega.md`).

## Placeholders

| Placeholder | Meaning | Example (Vega) |
|---|---|---|
| `{{id}}` | lowercase, one word; becomes `car_{{id}}` and the strip id | `vega` |
| `{{body}}` | one sentence: body type plus 4 to 6 *distinct* features, rear first | see example |
| `{{paint}}` | default paint | `glossy candy red` |
| `{{avoid}}` | what generators drift toward for this body type | `no side strakes, no slats, no louvered engine cover` |
| `{{v}}` | version suffix, `A_v1` for the first try, `A_v2` for a reroll | `A_v2` |

Rules for `{{body}}`: original design only, no real make, badge or grille. The rear is what
players see all race, so name the taillight shape and rear silhouette first. Avoid magenta,
pink or purple paint: the sheet's magenta key eats it (it ate the Cyclone's pink and the
Zenith's purple; see `test_player_cars_are_solid` in `tests/test_render.gd`).

## Fixed blocks (copied from `assets/prompts/00-style-guide.md`, do not edit)

`{STYLE}` = STYLE-A:
```
high-color pixel art, 1990s 32-bit arcade racing game sprite style, crisp hard-edged pixels, no anti-aliasing blur, limited but rich palette, bold readable silhouettes, saturated sunny colors, clean dark outlines on key shapes, late-afternoon sun lighting from the upper left
```

Negative prompt (if the generator takes one):
```
photorealistic, resembles a real production car model, real car brand, logo, badge, emblem, license plate text, watermark, signature, text, letters, blurry, muddy colors, desaturated, grunge, low contrast, extra wheels, distorted perspective, 3d polygon low-poly look, cropped subject
```

## Order

1. **01 hero** first. Check it doesn't read as a real car (round 2 flagged five of eight).
2. Give the approved hero to the generator as the **reference image** for 03 (and 02/04).
3. 02 and 04 are design references only; the game uses **01 (showroom picture)** and **03 (steering strip)**.

## CAR-{{ID}}-01 Hero (rear three-quarter) — used for the showroom picture

- **Save as:** `assets/concept/cars/car_{{id}}_hero_{{v}}.png`
- **Aspect:** 4:3 (existing heroes are 1448x1086)
- **Framing (required):** `tools/make_ui_sprites.py` crops every hero with the same box,
  `CAR_CROP = (100, 400, 1348, 979)` on a 1448x1086 image. The whole car must sit inside it:
  centered left to right, spanning about 15% to 87% of the width, and from about halfway
  down to 87% of the height, with road below and scenery above. A car that fills more of
  the frame (the Hauler, the Zenith) needs its own crop.

```
Concept art of an original {{body}}, painted {{paint}}, seen from the rear three-quarter view on a sunny coastal road, the whole car in the lower middle of the frame with road around it and palm-lined scenery above. Exaggerated arcade proportions: wide stance, big wheels, low roof. {{avoid}}. Clearly fictional design that does not resemble any real production car model. Fictional badge shapes only, no real brand or logo. {STYLE}
```

## CAR-{{ID}}-03 Steering sheet — used in game

- **Save as:** `assets/concept/cars/car_{{id}}_steer_sheet_{{v}}.png`
- **Aspect:** 16:9 or wider (existing sheets are 1672x941 to 2172x724)
- **Reference image:** the approved hero
- **Layout the tool depends on (`make_car_sprites.make_player`):**
  - exactly **7** separate cars in **one row**, clear magenta gaps between them
    (`spritelib.slice_row` cuts left to right; touching cars merge and the tool exits);
  - order: frame 1 hard left (car's left flank shows), frame 4 straight, frame 7 hard right;
  - camera directly behind the car, about **30 degrees above** it, level horizon, no
    perspective tilt; same size and baseline in every frame;
  - background flat `#FF00FF`, no ground shadow, no road, taillights lit;
  - the straight frame is scaled to 180 px wide (`PLAYER_BODY_WIDTH`), so draw it at least
    250 px wide on the sheet.
  - If 7 consistent frames won't come out, 3 (hard left, straight, hard right) or 1
    (straight) also work (`STEER_CELLS`); the tool repeats them.

```
Sprite sheet for an arcade racing game: an original {{body}}, painted {{paint}}, seen from directly behind and slightly above, as the player car. Seven frames in one row showing it steering from hard left through straight to hard right, the body yawing and leaning slightly, front wheels visible turning on the outer frames. Consistent size and position in each frame, separate frames with clear gaps, taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow, no road. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

## CAR-{{ID}}-02 Orthographic views (optional, design reference)

- **Save as:** `assets/concept/cars/car_{{id}}_views_{{v}}.png`, 16:9, reference: the hero

```
Vehicle design sheet of an original {{body}}, painted {{paint}}. Three orthographic views in a row with matching scale: straight rear view, straight front view, and side profile. Flat even lighting, isolated on a flat solid magenta #FF00FF background, no ground shadow, no text. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

## CAR-{{ID}}-04 Crash tumble (optional, not used in game yet)

- **Save as:** `assets/concept/cars/car_{{id}}_crash_sheet_{{v}}.png`, 16:9, reference: the hero

```
Sprite sheet for an arcade racing game: an original {{body}}, painted {{paint}}, in a cartoonish crash tumble. Six frames in a row showing the car flipping end over end and rolling, with small sparks and debris, seen from behind the chase camera. Consistent scale, separate frames with clear gaps, isolated on a flat solid magenta #FF00FF background. {STYLE}
```

## Hill sheets (optional; Vega only today)

Nose-down `car_{{id}}_steer_down_sheet_{{v}}.png` and nose-up `car_{{id}}_steer_up_sheet_{{v}}.png`
follow CAR-VEGA-05/06 in `assets/prompts/cars/car_vega.md` (reference image: the approved
steering sheet). Without them the game fakes the pitch (`CarSprites.pitch_warp`), which is
fine. Wiring them for another car needs a change to `PLAYER_SHEETS` in
`tools/make_car_sprites.py` (it scales pitched strips against the Vega's level strip).

## Filled example: the Vega (real prompts, `assets/prompts/cars/car_vega.md`)

- `{{id}}` = `vega`, `{{paint}}` = `glossy candy red`, `{{v}}` = `A_v2`
- `{{body}}` = `low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop`
- `{{avoid}}` = `no side strakes, no slats, no louvered engine cover`

CAR-VEGA-03 as generated (`car_vega_steer_sheet_A_v2.png`, 2135x736, seven frames):
```
Sprite sheet for an arcade racing game: an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red, seen from directly behind and slightly above, as the player car. Seven frames in one row showing it steering from hard left through straight to hard right, the body yawing and leaning slightly, front wheels visible turning on the outer frames. Consistent size and position in each frame, taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow. {STYLE}
```

## Before handing off

- [ ] Hero: car inside the `CAR_CROP` box, reads as original, no text or badges.
- [ ] Steering sheet: 7 (or 3, or 1) cars, one row, gaps between them, flat magenta, no shadow.
- [ ] Files saved under `assets/concept/cars/` with the exact names above.
- [ ] Stats picked (accel, top speed, handling, 1 to 5) and an unlock; see `docs/templates/new-car.md`.
