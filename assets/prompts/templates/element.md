# Template: new elements (art)

Four kinds, one section each: roadside props, traffic vehicles, road-spanning pieces
(arches, bridges, tunnels, gates) and power-ups. Fill the placeholders, generate, save under
the exact names given, then follow `docs/templates/new-element.md`. Keep a filled copy in the
matching folder (`assets/prompts/roadside/<stage>.md`, `traffic/traffic.md`,
`roadside/drive-through.md`, `powerups/powerups.md`).

## Fixed blocks (copied from `assets/prompts/00-style-guide.md`, do not edit)

`{STYLE}` = STYLE-A:
```
high-color pixel art, 1990s 32-bit arcade racing game sprite style, crisp hard-edged pixels, no anti-aliasing blur, limited but rich palette, bold readable silhouettes, saturated sunny colors, clean dark outlines on key shapes, late-afternoon sun lighting from the upper left
```

Negative prompt (if supported):
```
photorealistic, resembles a real production car model, real car brand, logo, badge, emblem, license plate text, watermark, signature, text, letters, blurry, muddy colors, desaturated, grunge, low contrast, extra wheels, distorted perspective, 3d polygon low-poly look, cropped subject
```

## Rules for every sheet the tools slice

- Flat solid `#FF00FF` background, no ground shadow, no road, no readable text, no real brands.
- **Clear magenta gap around every object.** The slicer (`spritelib.slice_objects`) finds
  each object as one connected shape and cuts them in **reading order: rows top to bottom,
  left to right**. Touching objects merge; the tool exits if the count is off ("found N
  objects, expected M"). Numbering the objects in the prompt ("six objects in a row") helps.
- One row is safest. Avoid magenta, pink and purple paint near the edges (keyed out).
- Ask for the count you will name; a stray extra (a glow, a puddle) can be skipped with
  `None` in the tool spec, but only if you know where it falls in reading order.
- Save as `<name>_A_v1.png` (reroll: `_A_v2`) under the folder given.

## Placeholders shared by all sections

| Placeholder | Example |
|---|---|
| `{{stage_name}}` | `Redrock Canyon` |
| `{{stage_mood}}` | `desert mesas, hot noon` (the mood line at the top of `assets/prompts/roadside/<stage>.md`) |
| `{{n}}` | `six` |
| `{{objects}}` | comma list, in left-to-right order, each with its distinct look |

---

## 1. Roadside props sheet

- **Save as:** `assets/concept/roadside/{{stage}}_{{group}}_A_v1.png` (`{{stage}}` is the
  roadside file prefix: `palm-coast`, `redrock`, `neon`, `timberline`, `bayou`, `harvest`,
  `thunder`, `skyline`, or `shared` for race furniture every stage uses)
- **Aspect:** 16:9
- **Count:** 3 to 8 objects. Objects on one sheet are scaled together so the tallest is the
  sheet's texture height (60 to 220 px), so keep tall and tiny things on separate sheets.
- **View:** front-facing as seen from the road (the car drives past them), upright, bottom
  edge flat (the pivot is bottom center).

```
Sprite sheet of roadside objects for an arcade racing game set in {{stage_name}} ({{stage_mood}}): {{objects}}. {{n}} objects arranged in a row, separate objects with clear gaps, isolated on a flat solid magenta #FF00FF background, front-facing as seen from the road, consistent scale, no ground shadow, no readable text. {STYLE}
```

**Filled example** (RS-REDROCK-05, `redrock_extras_A_v1.png`, six objects; in game as
`water_tower_wood`, `rusty_truck`, `dino`, `cattle_sign`, `butte`, `arrow_sign`):
```
Sprite sheet of roadside objects for an arcade racing game set in Redrock Canyon (desert mesas, hot noon): A tall wooden water tower with no text, a rusty old pickup truck parked on blocks, a giant fiberglass dinosaur roadside attraction, a cattle guard sign post, a mesa-shaped rock spire, and a desert motel sign shaped like a big arrow with bulbs and no text. Arranged in a row, separate objects with clear gaps, isolated on a flat solid magenta #FF00FF background, front-facing as seen from the road, consistent scale, no ground shadow, no readable text. {STYLE}
```

Also decide per object (goes in the tool spec, see `docs/templates/new-element.md`):
in-game height in world units (cone 650, person 1900, palm 5000, house 6000, tower 11000)
and how much of its width the car hits (0 drive-through like reeds or mist, 0.2 to 0.4 poles
and trees, 0.8 to 1 buildings and walls).

---

## 2. Traffic vehicles sheet

- **Save as:** `assets/concept/traffic/trf{{nn}}_{{group}}_A_v1.png` (next free number: `trf11`)
- **Aspect:** 16:9 or wider
- **View:** **straight from behind**, level, the way the player sees traffic ahead (the game
  only uses rear views; front views are not wired up).
- **Scale matters:** one scale per sheet, so the vehicles' sizes relative to each other are
  kept. Put cars on one sheet and big vehicles (trucks, buses) on another.
- Taillights visible, no plates, no text.

```
Sprite sheet for an arcade racing game: {{n}} original unbranded {{kind}} vehicles in a row, seen straight from behind: {{objects}}. Bold silhouettes, big taillights, same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

**Filled example** (TRF-08, `trf08_service_A_v1.png`; in game as `tow_truck`,
`cement_mixer`, `tanker`, `garbage_truck`, `street_sweeper`, `ice_cream_truck`):
```
Sprite sheet for an arcade racing game, original unbranded work vehicles seen straight from behind: a tow truck with a hook boom, a cement mixer truck with a striped drum, a round fuel tanker truck, a garbage truck, a slow street sweeper with flashing amber lights, and an ice cream truck with a giant cone shape on the roof. Bold silhouettes, big taillights, same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

---

## 3. Road-spanning piece (arch, bridge, overpass, tunnel mouth, gate)

- **Save as:** `assets/concept/roadside/dt_{{stage}}_{{thing}}_A_v1.png` (race gates:
  `shared_{{thing}}_A_v1.png`). **One piece per image.**
- **Aspect:** 16:9
- **Layout the game depends on** (`tools/make_span_sprites.py`, `SpriteLibrary.find_opening`):
  - straight-on front view, symmetrical left to right, as a driver in the middle of the road sees it;
  - the opening is flat `#FF00FF` and runs **down to the bottom edge** of the piece, through
    its center: the game reads the gap on the row 90% of the way down, and the road's width
    is fitted to it;
  - the opening is about **2.5 times wider than tall** (a four-lane road), pillars or walls
    just outside it;
  - banners blank (gate text is drawn in game).
- Tunnels and covered bridges also need an **interior ring**: a thin cross-section frame,
  everything inside it magenta; the game repeats it every few segments inside.

```
Road-spanning sprite for an arcade racing game set in {{stage_name}} ({{stage_mood}}): {{piece}}. Straight-on front view, perfectly symmetrical, the opening is filled with flat solid magenta #FF00FF, isolated on a flat solid magenta #FF00FF background, no ground shadow, no road, no cars, no readable text. {STYLE}
```

Interior ring `{{piece}}`: `one thin cross-section ring of {{the tunnel}} interior, {{walls, ceiling and lights}}, meant to repeat along the tunnel. Thin frame only, everything inside it empty`.

**Filled example** (DT-REDROCK-01, `dt_redrock_arch_A_v1.png`; in game as `redrock_arch`):
```
Road-spanning sprite for an arcade racing game set in Redrock Canyon (desert mesas, hot noon): a huge natural red sandstone arch spanning a four-lane road, layered orange and violet rock bands, a thick rough span on top with a few desert shrubs, deep violet shadow on the inner faces. Straight-on front view, perfectly symmetrical in its overall shape, the opening is filled with flat solid magenta #FF00FF, isolated on a flat solid magenta #FF00FF background, no ground shadow, no road, no cars, no readable text. {STYLE}
```

---

## 4. Power-ups

Every kind needs a **road pickup** and a **HUD icon**, matching the existing sets so the
sheet can be sliced with them or alone:

- Pickups: `assets/concept/powerups/pu{{nn}}_{{group}}_A_v1.png`, 16:9, objects floating over
  a glowing ring, front-facing, thick dark outlines. Sliced to 72 px tall.
- Icons: same naming, 16:9, flat badge icons matching `pu02_icons_A_v2.png` (give it as the
  reference image). Sliced to 30 px tall, so keep them bold and simple.
- An animated pickup is a row of frames (the mystery hubcap is 3: face, three-quarter, edge).
- Never a weapon (design rule, `docs/07-art-prompts-round4.md` section 3).

```
Sprite sheet of floating power-up pickups for an arcade racing game, {{n}} objects in a row, each hovering over its own small glowing ring of light: {{objects}}. Big, bold, readable at small sizes, thick dark outlines, each object separate with clear gaps, isolated on a flat solid magenta #FF00FF background, front-facing, consistent scale, no ground shadow, no text. {STYLE}
```

**Filled example** (PU-01R, `pu01_mystery_A_v2.png`; in game as `pickup_mystery_1..3`):
```
Sprite sheet for an arcade racing game, three frames in a row: an original mystery power-up pickup shaped like a chunky chrome hubcap spinning on its edge, its center glowing with swirling rainbow colors and small sparkles, hovering over a glowing ring of light. Frame 1 face-on, frame 2 turned three quarters, frame 3 edge-on. No question mark, no crate, no box, no text. Big, bold, readable at small sizes, thick dark outlines, each frame separate with clear gaps, isolated on a flat solid magenta #FF00FF background, consistent scale, no ground shadow. {STYLE}
```

## Before handing off

- [ ] Object count on the sheet matches your list; gaps around every object.
- [ ] Flat magenta background, no shadows, no text.
- [ ] Spans: one piece, symmetrical, magenta opening reaching the bottom edge through the center.
- [ ] Each object has a snake_case name (unique across all stages) and, for roadside, a world height and collide fraction.
