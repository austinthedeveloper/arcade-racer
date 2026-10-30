# Cyclone (`car_cyclone`)

**Archetype:** reverse trike (two wheels front, one rear)  
**Unlock:** Stage 4 (proposed)  
**Stats (proposal, 1 to 5):** Accel 4, Top speed 3, Handling 5  
**Default paint:** hot magenta with a black spine and black wheels  
**Design notes:** New in round 4. Original design, no real make or badge. The handling king. From behind it reads instantly: one fat center tire with two front wheels sticking out on exposed arms. Distinct features are spelled out and the prompt says what to avoid, because generators drift toward famous real cars (round 2 flagged five of the first eight). Check the hero against real cars before generating the other sheets.

How to generate: do 01 first. Once the hero looks original, give it to the generator as the **reference image** for 02 to 04 so the design stays on-model. The steering sheet is a design check only: generators can't hold seven consistent frames, so production frames come from the 3D render pipeline (docs/06-concept-review-round2.md).

## CAR-CYCLONE-01 Hero concept (rear three-quarter)
- **Output:** `assets/concept/cars/car_cyclone_hero.png`
- **Aspect:** 4:3
- **Round:** 4

```
Concept art of an original open-cockpit three-wheeled reverse trike with two front wheels on exposed wishbone suspension arms outside the narrow body and one single extra-wide rear tire in the center, a slim pointed nose, two separate small windscreens for side-by-side seats, a tall rear spine fairing behind the seats, and a single horizontal taillight bar across the rear spine directly above the fat rear tire, with twin exhausts on either side of the rear tire, painted hot magenta with a black spine and black wheels, seen from the rear three-quarter view on a sunny coastal road. Exaggerated arcade proportions: wide stance, big wheels, low roof. Clearly fictional design that does not resemble any real production car model. Not a motorcycle, no handlebars, not resembling any real three-wheeler. Fictional badge shapes only, no real brand or logo. {STYLE}
```

## CAR-CYCLONE-02 Orthographic views (rear, front, side)
- **Output:** `assets/concept/cars/car_cyclone_views.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_cyclone_hero_A_v*.png`
- **Round:** 4

```
Vehicle design sheet of an original open-cockpit three-wheeled reverse trike with two front wheels on exposed wishbone suspension arms outside the narrow body and one single extra-wide rear tire in the center, a slim pointed nose, two separate small windscreens for side-by-side seats, a tall rear spine fairing behind the seats, and a single horizontal taillight bar across the rear spine directly above the fat rear tire, with twin exhausts on either side of the rear tire, painted hot magenta with a black spine and black wheels. Three orthographic views in a row with matching scale: straight rear view, straight front view, and side profile. Flat even lighting, isolated on a flat solid magenta #FF00FF background, no ground shadow, no text. Clearly fictional design that does not resemble any real production car model. {STYLE}
```

## CAR-CYCLONE-03 Gameplay sprite sheet (steering frames)
- **Output:** `assets/concept/cars/car_cyclone_steer_sheet.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_cyclone_hero_A_v*.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game: an original open-cockpit three-wheeled reverse trike with two front wheels on exposed wishbone suspension arms outside the narrow body and one single extra-wide rear tire in the center, a slim pointed nose, two separate small windscreens for side-by-side seats, a tall rear spine fairing behind the seats, and a single horizontal taillight bar across the rear spine directly above the fat rear tire, with twin exhausts on either side of the rear tire, painted hot magenta with a black spine and black wheels, seen from directly behind and slightly above, as the player car. Seven frames in one row showing it steering from hard left through straight to hard right, the body yawing and leaning slightly, front wheels visible turning on the outer frames. Consistent size and position in each frame, separate frames with clear gaps, taillights glowing, isolated on a flat solid magenta #FF00FF background, no ground shadow. {STYLE}
```

## CAR-CYCLONE-04 Crash tumble frames
- **Output:** `assets/concept/cars/car_cyclone_crash_sheet.png`
- **Aspect:** 16:9
- **Reference image:** the approved `car_cyclone_hero_A_v*.png`
- **Round:** 4

```
Sprite sheet for an arcade racing game: an original open-cockpit three-wheeled reverse trike with two front wheels on exposed wishbone suspension arms outside the narrow body and one single extra-wide rear tire in the center, a slim pointed nose, two separate small windscreens for side-by-side seats, a tall rear spine fairing behind the seats, and a single horizontal taillight bar across the rear spine directly above the fat rear tire, with twin exhausts on either side of the rear tire, painted hot magenta with a black spine and black wheels, in a cartoonish crash tumble. Six frames in a row showing the car flipping end over end and rolling, with small sparks and debris, seen from behind the chase camera. Consistent scale, isolated on a flat solid magenta #FF00FF background. {STYLE}
```
