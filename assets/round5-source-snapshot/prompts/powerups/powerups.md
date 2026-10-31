# Power-ups (proposal)

**Status:** proposal, not in the game design yet. See `docs/07-art-prompts-round4.md` for the design and the open question.

Five pickups that float above the road. None of them are weapons: they keep the race about driving through traffic, and none of them punishes anyone for more than a few seconds (design pillar 3).

| Pickup | Effect |
|---|---|
| **Nitro can** | +1 nitro charge (up to the car's max) |
| **Time clock** | +3 seconds on the checkpoint timer |
| **Ram plate** | 5 seconds: traffic you hit gets knocked flying instead of crashing you |
| **Ghost** | 4 seconds: drive through traffic and rivals |
| **Mystery crate** | One of the four above, weighted toward what helps a player in last place |

Pickups spin and bob in engine, so the art is one front view each. The generator only has to make clean single objects.

## PU-01 Pickups on the road
- **Output:** `assets/concept/powerups/pu01_pickups.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet of floating power-up pickups for an arcade racing game, five objects in a row, each hovering over its own small glowing ring of light: a chunky blue nitro canister with a flame symbol, a gold stopwatch with a plus sign, a heavy steel bumper plate with yellow and black hazard stripes, a translucent pale cyan ghost-shaped car silhouette with sparkles, and a wooden crate with a big glowing question mark. Big, bold, readable at small sizes, thick dark outlines, each object separate with clear gaps, isolated on a flat solid magenta #FF00FF background, front-facing, consistent scale, no ground shadow. {STYLE}
```

## PU-02 HUD icons
- **Output:** `assets/concept/powerups/pu02_icons.png`
- **Aspect:** 16:9
- **Round:** 4
- **Reference image:** `assets/concept/ui/hud03_icons_A_v1.png` (match its outline and shading)

```
Set of arcade racing game HUD icons in one row, matching the power-ups: a blue nitro canister, a gold stopwatch with a plus sign, a hazard-striped bumper plate, a cyan ghost car silhouette, and a crate with a question mark, plus an empty rounded square slot frame for holding a power-up. Bold, chunky, consistent outline, each icon separate with clear gaps, isolated on a flat solid magenta #FF00FF background. {STYLE}
```

## PU-03 Power-up effects
- **Output:** `assets/concept/powerups/pu03_effects.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet of visual effects for an arcade racing game, in a row: a burst of gold and white sparkles for collecting a pickup, a large glowing yellow-and-black energy plow shape that sits in front of a car, a cyan ghostly outline glow with flickering scan lines that wraps around a car shape, a small traffic car knocked spinning into the air with stars and debris, and a big pop-up plus-time burst with a clock shape. Bright, readable, thick outlines, each effect separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text. {STYLE}
```

## PU-04 Mystery crate open sequence
- **Output:** `assets/concept/powerups/pu04_crate_open.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game, five frames in a row: a wooden crate with a glowing question mark bursting open, from closed, to lid popping, to planks flying apart with a flash of light, to an empty bright starburst, to a few fading sparkles. Consistent scale, each frame separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text. {STYLE}
```

## PU-01R Mystery pickup reshaped
- **Output:** `assets/concept/powerups/pu01_mystery_A_v2.png`
- **Aspect:** 16:9
- **Round:** 5
- **Why:** round 4 review (docs/08-concept-review-round4.md): a wooden crate with a big question mark is the signature item of a famous platform game series. Give the mystery pickup its own shape; the other four pickups stay. If this is used, PU-02 and PU-04 need the same shape.

```
Sprite sheet for an arcade racing game, three frames in a row: an original mystery power-up pickup shaped like a chunky chrome hubcap spinning on its edge, its center glowing with swirling rainbow colors and small sparkles, hovering over a glowing ring of light. Frame 1 face-on, frame 2 turned three quarters, frame 3 edge-on. No question mark, no crate, no box, no text. Big, bold, readable at small sizes, thick dark outlines, each frame separate with clear gaps, isolated on a flat solid magenta #FF00FF background, consistent scale, no ground shadow. {STYLE}
```
