# Vega GT (`car_vega`)

**Archetype:** low wedge supercar  
**Unlock:** Start  
**Default paint:** glossy candy red  
**Design notes:** Original design, no real make or badge. Round 1 showed generators drift toward famous real cars, so descriptions name distinct features and say what to avoid. The rear view is what players see all race, so the rear silhouette and taillights must be distinctive.

## CAR-VEGA-01 Hero concept (rear three-quarter)
- **Output:** `assets/concept/cars/car_vega_hero.png`
- **Aspect:** 4:3
- **Round:** 1

```
Concept art of an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red, seen from the rear three-quarter view on a sunny coastal road. Exaggerated arcade proportions: wide stance, big wheels, low roof. Clearly fictional design that does not resemble any real production car model. Fictional badge shapes only, no real brand or logo. {STYLE}
```

## CAR-VEGA-02 Orthographic views (rear, front, side)
- **Output:** `assets/concept/cars/car_vega_views.png`
- **Aspect:** 16:9
- **Round:** 2

```
Vehicle design sheet of an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red. Three orthographic views in a row with matching scale: straight rear view, straight front view, and side profile. Flat even lighting, isolated on a flat solid magenta #FF00FF background, no ground shadow, no text. {STYLE}
```

## CAR-VEGA-03 Gameplay sprite sheet (steering frames)
- **Output:** `assets/concept/cars/car_vega_steer_sheet.png`
- **Aspect:** 16:9
- **Round:** 2

```
Sprite sheet for an arcade racing game: an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red, seen from directly behind and slightly above, as the player car. Seven frames in one row showing it steering from hard left through straight to hard right, the body yawing and leaning slightly, front wheels visible turning on the outer frames. Consistent size and position in each frame, taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow. {STYLE}
```

## CAR-VEGA-04 Crash tumble frames
- **Output:** `assets/concept/cars/car_vega_crash_sheet.png`
- **Aspect:** 16:9
- **Round:** 3

```
Sprite sheet for an arcade racing game: an original low, wide wedge supercar with a smooth wraparound canopy-style glass roof flowing into the rear deck, two short vertical tail fins instead of a rear wing, triangular taillight clusters joined by a glowing center bar, one large central exhaust, and smooth body sides with a single deep air scoop (no side strakes, no slats, no louvered engine cover), painted glossy candy red, in a cartoonish crash tumble. Six frames in a row showing the car flipping end over end and rolling, with small sparks and debris, seen from behind the chase camera. Consistent scale, isolated on a flat solid magenta #FF00FF background. {STYLE}
```

## Hill pitch sheets (CAR-VEGA-05, CAR-VEGA-06)

On hills the road tilts but the camera doesn't, so the player car needs a nose-down (downhill) and a nose-up (uphill) version of its steering strip. The game picks them by road slope (`CarSprites.pitch_row`); until they exist it stretches the level strip as a stand-in.

How to generate: **give the generator `assets/concept/cars/car_vega_steer_sheet_A_v2.png` as the reference image** (that is how the v2 sheet stayed on-model) and ask for the same car, same frames, same size and order, only the camera angle changed. Save as the output names below; `tools/make_car_sprites.py` picks them up. If seven consistent frames won't come out, the 3-frame and 1-frame fallbacks below work too: the tool repeats them across the steering cells (3 = hard left, straight, hard right).

What changes, relative to the level sheet (camera about 30 degrees above, behind):
- **Downhill / nose-down:** the car tips forward and its tail lifts toward the camera, so relative to the car the camera is nearly level with it, about 8 degrees. The canopy is a thin sliver above the deck, the tail fins stand up against the sky, the whole rear fascia (taillights, center bar, diffuser, exhaust) is tall and dominant, the tires look taller and a bit of the dark underside shows below the bumper. Body width stays the same.
- **Uphill / nose-up:** the car tips back and its roof turns toward the camera, so relative to the car we look down on it steeply, about 55 degrees. Much more of the glass canopy and rear deck shows, the roof reads as a big shape, the tail fins point back toward the camera, the bumper, diffuser and exhaust are foreshortened and the tires look shorter. Body width stays the same.

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
