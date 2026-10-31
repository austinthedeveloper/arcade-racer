# Art Direction

**One line:** A sun-soaked, saturated, optimistic arcade postcard, rendered as scaled sprites on a pseudo-3D road.

---

## 1. Visual pillars

1. **Postcard color.** Big skies, strong gradients, saturated hues. Each stage owns a dominant palette (Palm Coast = turquoise + gold, Redrock = orange + violet, Neon Strip = magenta + cyan on black).
2. **Readable at 200 mph.** Silhouettes first. Roadside objects, traffic, and the player car must read instantly by shape and value, even when small.
3. **Chunky and confident.** Bold outlines or strong value separation, no muddy detail. Cars are slightly exaggerated: wide stance, big wheels, low roofs.
4. **Arcade attitude.** Chrome logos, italic type, lens flares, starbursts, "CHECKPOINT!" banners. Loud, fun, never gritty.

## 2. Style (decided: pixel art)

| Option | Look | Pros | Cons |
|---|---|---|---|
| **A. High-color pixel art** (chosen) | 640x360, crisp pixels, 32-bit era arcade sprites, rich but controlled palettes | Cohesive, authentic, scales cleanly, achievable sprite sizes | Pixel art takes skilled cleanup; generated images need redrawing |
| **B. Hi-res pre-rendered sprites** | 1280x720+, smooth shaded sprites like late-90s pre-rendered CG | Easier to produce car rotations by rendering 3D models; very "90s arcade cabinet" | Can look dated or plasticky without care; bigger textures |
| **C. Painted / illustrated sprites** | Hand-painted, flat-shaded vector-ish look | Distinctive, modern-retro | Hardest to keep consistent across many sprites and frames |

**Decision:** Option A. The round 1 concept review (`docs/05-concept-review-round1.md`) picked pixel art and named `ka02_gameplay_palm_A_v1.png` the target style frame: B and C read as modern illustration, and C loses the pixel crunch that makes speed feel arcade. The game runs at 640x360 and `assets/prompts/00-style-guide.md` has the pixel art style block (STYLE-A) for prompts. B and C stay in the table as the options that were not taken.

## 3. Screen composition

```
+--------------------------------------------------------------+
| POS 3/8      TIME 42        [==progress=====>-----]   NITRO x3|  <- HUD top band
|                                                              |
|        sky gradient + clouds                                 |
|   ___/\____/\___ far mountains / skyline (parallax 1)         |
|  ~~~~ mid hills / ocean (parallax 2)                         |
| ------------------- horizon line ~ 40% from top ------------ |
|      roadside sprites         road        roadside sprites   |
|                         /          \                         |
|                       /   [PLAYER]   \                       |
|                     /                  \          188 MPH   |  <- speedo bottom right
+--------------------------------------------------------------+
```

- Horizon sits around **40% from the top** on flat road.
- Player car occupies roughly **25% of screen width**, centered, bottom ~10% margin.
- HUD stays in the top band and bottom corners; never over the road center.

## 4. Sprite specifications (Option A, 640x360)

| Asset | Authored size (approx) | Pivot | Notes |
|---|---|---|---|
| Player car | 160 x 96 px per frame | bottom center | 7 steer x 3 pitch, plus crash + slide frames |
| Rival / traffic cars | 160 x 96 px (scaled down in game) | bottom center | 5 angle frames (rear), 3 for oncoming (front) |
| Semi truck / bus | 200 x 180 px | bottom center | Rear and front views |
| Palm tree | 96 x 256 px | bottom center | Tall sprites sell speed |
| Billboard | 256 x 192 px | bottom center | Original fake brands only |
| Small props (cones, signs, cactus) | 32 to 96 px | bottom center | |
| Background layers | 1280 to 2560 x 360 px, tiling horizontally | — | 3 to 4 layers per stage |
| HUD elements | Native resolution | — | May render at output res for crisp text |

**Rules for all sprites:**
- Transparent background, no baked shadows on the ground (the engine draws a simple blob shadow).
- Lit from **upper left, late-afternoon sun** by default; stage themes can override (night stage uses emissive signs).
- Consistent outline treatment per style option.
- Car body paint uses a **4 to 5 color key ramp** (e.g. pure reds) so the palette-swap shader can recolor it.

## 5. Car design language

- **Original designs only.** No real makes, badges, grilles, or logos. Invent badges for our fictional brands.
- Exaggerated proportions: wide rear, big rear wheels, low greenhouse, aggressive taillights. The rear view is what players stare at all race, so **taillights and rear silhouettes must be iconic** and different per car.
- Every car needs: rear 3/4 hero view (select screen), straight rear view (gameplay), front view (oncoming / rival behind).

### Production note on car sprites

Many consistent frames per car are hard to draw and very hard to get from image generators. Two production paths:

1. **Pre-render from simple 3D models:** model each car once (low poly is fine), render the 21+ frames with a fixed camera, then paint over / pixelate. Consistent and fast to iterate.
2. **Hand-pixel each frame** from the concept art.

Recommendation: concept with image generation, then **pre-render + cleanup** for production cars. Roadside and backgrounds can be drawn or cleaned up directly from generated images.

## 6. Stage palettes (starting points)

| Stage | Sky | Ground / grass | Road | Accent |
|---|---|---|---|---|
| Palm Coast Boulevard | Turquoise to warm gold | Bright green lawns, sand | Warm gray asphalt, white/red rumble | Coral pink, ocean teal |
| Redrock Canyon | Pale blue to hot white | Orange sand | Sun-bleached gray | Deep violet shadows |
| Neon Strip | Black to deep purple | Dark wet pavement | Near-black with reflections | Magenta, cyan, gold neon |
| Timberline Pass | Crisp blue | Dark pine green, snow white | Cool gray | Cabin red |
| Bayou Causeway | Peach dawn into mist | Olive water, moss | Weathered concrete | Pale mint fog |
| Harvest Valley | Orange sunset to lavender | Gold wheat, green rows | Dusty asphalt | Barn red |
| Thunderhead Highway | Bruised indigo, lightning white | Wet green-gray | Glossy dark | Electric yellow |
| Skyline Finale | Dusk purple to orange | City concrete | Bridge steel | Firework colors |

## 7. UI direction

- **Logo:** Chrome and sunset-gradient lettering, italic, with speed lines. Original working title until named.
- **Fonts:** Heavy italic display face for big callouts; a clean, highly readable pixel or geometric font for numbers. Must be license-safe (open fonts or custom).
- **HUD:** Analog-styled speedometer with digital MPH readout, chunky position number, checkpoint timer that pulses red under 10 seconds, nitro charges as flame icons, thin route progress bar with rival dots.
- **Menus:** Car select on a rotating turntable (pre-rendered rotation frames), stage select as postcards on a map of the fictional country.
- **Callouts:** "GO!", "CHECKPOINT!", "TIME EXTENDED", "NEAR MISS!", "BIG AIR!", "FINAL STRETCH", "1ST PLACE!" with starburst backing.

## 8. FX

Sprite-based effects only: tire smoke puffs, sparks, dust plumes off-road, water splash, nitro exhaust flame, rain streaks, lightning flash (full-screen tint), confetti/fireworks at the finish, speed lines at nitro.

## 9. Things to avoid

- Any real car brands, logos, license plate formats from real jurisdictions, or real sponsor brands.
- Copying layouts, logos, tracks, or characters from existing racing games.
- Muddy, desaturated palettes. Grit. Photorealism.
- Text baked into generated images (generators mangle it); add text in-engine.

## 10. Concept phase plan

1. **Round 1, style frames:** the key art + one mock gameplay screenshot of Palm Coast Boulevard, generated in each style option (A, B, C). Done: pixel art was picked (`docs/05`).
2. **Round 2, hero assets:** 3 to 4 cars, Palm Coast roadside set and background layers, logo concepts.
3. **Round 3, breadth:** remaining stages, traffic, UI, FX.

Prompt files live in `assets/prompts/`. See `assets/README.md`.
