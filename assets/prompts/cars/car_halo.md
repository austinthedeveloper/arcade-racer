# Halo EV (`car_halo`)

**Archetype:** electric streamliner  
**Unlock:** Stage 6 (proposed)  
**Stats (proposal, 1 to 5):** Accel 5, Top speed 4, Handling 3 (4 shorter nitro charges)  
**Default paint:** pearl mint green with a chrome-white lower half  
**Design notes:** New in round 4. Original design, no real make or badge. The modern car of the roster. The glowing ring taillight is designed to be recognizable from a single frame at a distance. Distinct features are spelled out and the prompt says what to avoid, because generators drift toward famous real cars (round 2 flagged five of the first eight). Check the hero against real cars before generating the other sheets.

How to generate: do 01 first. Once the hero looks original, give it to the generator as the **reference image** for 02 to 04 so the design stays on-model. The steering sheet is a design check only: generators can't hold seven consistent frames, so production frames come from the 3D render pipeline (docs/06-concept-review-round2.md).

## CAR-HALO-01 Hero concept (rear three-quarter)
- **Output:** `assets/concept/cars/car_halo_hero.png`
- **Aspect:** 4:3
- **Round:** 4

```
Concept art of an original smooth electric streamliner coupe shaped like a long teardrop, with skirts covering the rear wheels, a seamless glass bubble roof, no grille, a short flat cut-off tail, and one large glowing oval ring taillight that frames the whole rear panel with an empty dark center, plus a thin glowing light line along the lower edge of the body, painted pearl mint green with a chrome-white lower half, seen from the rear three-quarter view on a sunny coastal road. Exaggerated arcade proportions: wide stance, big wheels, low roof. Clearly fictional design that does not resemble any real production car model. No horizontal full-width light bar, not resembling any real electric car. Fictional badge shapes only, no real brand or logo. {STYLE}
```

## CAR-HALO-02 Orthographic views (rear, front, side)
- **Output:** `assets/concept/cars/car_halo_views.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_halo_hero_A_v*.png`
- **Round:** 4

```
Vehicle design sheet of an original smooth electric streamliner coupe shaped like a long teardrop, with skirts covering the rear wheels, a seamless glass bubble roof, no grille, a short flat cut-off tail, and one large glowing oval ring taillight that frames the whole rear panel with an empty dark center, plus a thin glowing light line along the lower edge of the body, painted pearl mint green with a chrome-white lower half. Three orthographic views in a row with matching scale: straight rear view, straight front view, and side profile. Flat even lighting, isolated on a flat solid magenta #FF00FF background, no ground shadow, no text. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

## CAR-HALO-03 Gameplay sprite sheet (steering frames)
- **Output:** `assets/concept/cars/car_halo_steer_sheet.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_halo_hero_A_v*.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game: an original smooth electric streamliner coupe shaped like a long teardrop, with skirts covering the rear wheels, a seamless glass bubble roof, no grille, a short flat cut-off tail, and one large glowing oval ring taillight that frames the whole rear panel with an empty dark center, plus a thin glowing light line along the lower edge of the body, painted pearl mint green with a chrome-white lower half, seen from directly behind and slightly above, as the player car. Seven frames in one row showing it steering from hard left through straight to hard right, the body yawing and leaning slightly, front wheels visible turning on the outer frames. Consistent size and position in each frame, separate frames with clear gaps, taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow. {STYLE}
```

## CAR-HALO-04 Crash tumble frames
- **Output:** `assets/concept/cars/car_halo_crash_sheet.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_halo_hero_A_v*.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game: an original smooth electric streamliner coupe shaped like a long teardrop, with skirts covering the rear wheels, a seamless glass bubble roof, no grille, a short flat cut-off tail, and one large glowing oval ring taillight that frames the whole rear panel with an empty dark center, plus a thin glowing light line along the lower edge of the body, painted pearl mint green with a chrome-white lower half, in a cartoonish crash tumble. Six frames in a row showing the car flipping end over end and rolling, with small sparks and debris, seen from behind the chase camera. Consistent scale, isolated on a flat solid magenta #FF00FF background. {STYLE}
```
