# Captured round-four prompt sections

Original source: `assets/prompts/cars/car_vega.md`. These are the selected sections read before generation, not a restoration of the complete source document. Final augmented prompts and reference roles are recorded in generation-round4.json.

## CAR-VEGA-02 Orthographic views (rear, front, side)
- **Output:** `assets/concept/cars/car_vega_views.png`
- **Aspect:** 16:9
- **Round:** 2

```
Vehicle design sheet of an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red. Three orthographic views in a row with matching scale: straight rear view, straight front view, and side profile. Flat even lighting, isolated on a flat solid magenta #FF00FF background, no ground shadow, no text. {STYLE}
```


## CAR-VEGA-04 Crash tumble frames
- **Output:** `assets/concept/cars/car_vega_crash_sheet.png`
- **Aspect:** 16:9
- **Round:** 3

```
Sprite sheet for an arcade racing game: an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red, in a cartoonish crash tumble. Six frames in a row showing the car flipping end over end and rolling, with small sparks and debris, seen from behind the chase camera. Consistent scale, isolated on a flat solid magenta #FF00FF background. {STYLE}
```


## CAR-VEGA-05 Downhill steering sheet (nose-down)
- **Output:** `assets/concept/cars/car_vega_steer_down_sheet_A_v1.png`
- **Aspect:** 16:9
- **Reference image:** `assets/concept/cars/car_vega_steer_sheet_A_v2.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game, matching the reference sprite sheet exactly: the same original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, three small triangular taillights on each side joined by a thin glowing center bar, one large hexagonal central exhaust, and a single deep side air scoop, painted glossy candy red. Same seven frames in one row, same order (hard left, through straight, to hard right), same size, spacing and pixel scale as the reference. The only change: the car is pitched nose-down driving down a steep hill with its tail lifted toward the camera, so the camera sits almost level with the car, low behind it at about 8 degrees. The glass canopy is only a thin sliver above the rear deck, the two tail fins stand up as clear shapes, the whole rear fascia with the taillights, glowing center bar, diffuser and big exhaust is tall and dominant, the tires look taller, and a little of the dark underside shows below the bumper. Body width unchanged. Taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow, no road. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

Fallbacks (same reference image, same output name):
- 3 frames: replace "Same seven frames ... as the reference." with `Exactly THREE frames in one row, evenly spaced: hard left, straight, hard right, matching the first, middle and last frames of the reference in size and pixel scale.`
- 1 frame: replace it with `ONE car only, centered, the straight-ahead frame, matching the middle frame of the reference in size and pixel scale.`


## CAR-VEGA-06 Uphill steering sheet (nose-up)
- **Output:** `assets/concept/cars/car_vega_steer_up_sheet_A_v1.png`
- **Aspect:** 16:9
- **Reference image:** `assets/concept/cars/car_vega_steer_sheet_A_v2.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game, matching the reference sprite sheet exactly: the same original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, three small triangular taillights on each side joined by a thin glowing center bar, one large hexagonal central exhaust, and a single deep side air scoop, painted glossy candy red. Same seven frames in one row, same order (hard left, through straight, to hard right), same size, spacing and pixel scale as the reference. The only change: the car is pitched nose-up climbing a steep hill with its roof tipped back toward the camera, so the camera looks down on the car from high above and behind, about 55 degrees. Show much more of the glass canopy and the top of the rear deck, the roof is a large readable shape, the bumper, diffuser and exhaust are foreshortened and the tires look shorter. Body width unchanged. Taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow, no road. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

Fallbacks: the same 3-frame and 1-frame swaps as CAR-VEGA-05.
