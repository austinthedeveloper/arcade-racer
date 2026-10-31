# CP: Cars and the Art Pipeline

Turning the approved concept designs into production sprites, and finishing the car-side
features from `docs/02-technical-design.md` section 2.5 and `docs/03-art-direction.md` section 5.
The pipeline decision from `docs/06`: pre-render each car from a simple 3D model, then clean up.

## Built today

Twelve cars cut from the concept steering sheets by `tools/make_car_sprites.py` (seven steer
frames each; the Vega also has uphill and downhill strips). Magenta keying with interior gap
detection. Brake glow and nitro flame drawn at the Vega's anchors on every car (bug A4).
Twenty-four traffic vehicles, rear view only. Showroom pictures on car select. Roadside, span,
power-up and UI sprites from their own tools.

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| CP-1 | **3D-to-sprite pipeline, Vega first.** A low-poly Blender model from the approved hero and rear view; a render script with a fixed camera at 7 steer angles times 3 pitches; downscale to the 200 px player width, pixel cleanup, one pixel grid. Output lands where `make_car_sprites.py` writes today, so the game needs no change. Time-boxed to two weeks. | L | 4 | | The Vega strips come from renders; a side-by-side screenshot against the concept-sheet strips; the pipeline is documented in `tools/README` |
| CP-2 | **Roll-out to the other eleven cars.** Decide Phantom coupe versus hatchback and flatten the Kestrel's nose first (`docs/08`). | L | 4, 5 | CP-1 | Every car's strips are rendered; car select shows them |
| CP-3 | **Crash, slide and overlay frames.** Six to eight tumble frames, two slide frames per side, brake-light and nitro overlays per car with their own anchors in the manifest (fixes A4). | M | 4 | CP-1, EQ-3 | A crash screenshot per car type (coupe, truck, trike); `test_render` reads anchors from the manifest |
| CP-4 | **Paint colors.** Body pixels in a key ramp, a palette-swap shader, four to six colors per car, color pick on car select, rivals in signature colors. | M | 5 | CP-2 | Shader test on a known pixel; screenshot of the garage in two colors; unlocks hook (MP-4) |
| CP-5 | **Rival angle frames.** Five rear frames per car chosen by relative screen position, plus the brake overlay. Rivals stop using the player's steer strip. | M | 4 | CP-1, RC-1 | `CarSprites.rival_frame` has a test; screenshot of the field in a bend |
| CP-6 | **Traffic front views and light states.** Front frames for oncoming traffic, and the TRF-10 states (off, brake, left signal, right signal) for the tell in RC-11. | M | 4 | | Sheets sliced by the tool; `test_traffic` picks the right frame per state |
| CP-7 | **Keying fixes.** A2 despill of magenta from edge pixels, A3 two-pixel fringe near the key hue, A1 glass rerolled or recolored on the seven affected vehicles (`docs/09`). | S | 2 | EQ-3 | `test_render` key-color checks extend to traffic; before and after crops |
| CP-8 | **Shared sprite library and manifest.** See EQ-3; listed here because every CP item builds on it. | | 1 | | |
| CP-9 | **Sprite LOD.** Two or three hand-reduced sizes per tall sprite, picked by projected height, to stop shimmer at distance; one pixel grid everywhere. | M | 5 | EQ-3 | A distance screenshot on Palm Coast before and after; no frame-time regression |
| CP-10 | **Car select turntable.** Rotation frames rendered from the 3D models; the select screen spins the car. | M | 6 | CP-2 | Screenshot of the turntable; the e2e smoke still picks a car |
| CP-11 | **UI art.** Analog speedo and tach, flame icons, position numeral, callout banners with starbursts, final logo, map art for stage select. From the round 2 UI concepts, text added in engine. | M | 5, 6 | PR-6 | Each HUD element has a sprite; menu screenshots updated |
| CP-12 | **Legal pass.** Every car, traffic vehicle and landmark checked against the "no lookalikes" rule once more at production size (Cyclone v2 still awaits Austin's review); fonts confirmed license-safe. | S | 6 | CP-2 | A short checklist in `docs/`; any failure gets a reroll prompt |

## Open decisions

- Blender for the models, or a simpler tool? Default: Blender, scripted renders, since it is free and scriptable.
- Does paint recolor only the body, or trim too? Default: body ramp only; trim stays per design.
- Keep the concept-sheet traffic as production, or also re-render it? Default: keep; traffic reads fine as it is.

## Test notes

Sprite work is checked by screenshots plus a few pixel assertions (key color absent, anchors
within the frame, frame counts). The manifest from EQ-3 is what makes per-car anchors testable.
