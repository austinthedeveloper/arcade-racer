# Template: new stage (art)

A stage needs one background composite (it becomes both the parallax strip and the stage
select postcard), four or five roadside sheets, a road color study for the theme, and one
road-spanning piece. Traffic locals are optional (existing vehicles can be reused). Fill the
brief, generate, save under the exact names, then follow `docs/templates/new-stage.md`. Keep
filled copies as `assets/prompts/backgrounds/{{slug}}.md` and `assets/prompts/roadside/{{slug}}.md`.

## Brief

| Placeholder | Meaning | Example (Redrock) |
|---|---|---|
| `{{slug}}` | one lowercase word, no dashes (file prefix, sprite folder, postcard id) | `redrock` |
| `{{stage_name}}` | display name | `Redrock Canyon` |
| `{{stage_mood}}` | place and light, a few words | `desert mesas, hot noon` |
| `{{sky}}` | sky gradient and weather | `pale blue to hot white sky` |
| `{{far}}` | far horizon band | `distant red mesas and buttes` |
| `{{near}}` | near horizon band | `orange sand dunes and scrub` |
| `{{palette}}` | sky / ground / road / accent (see `docs/03-art-direction.md` section 6) | `pale blue, orange sand, sun-bleached gray, deep violet` |
| `{{landmark}}` | the one signature extra this stage is known for | `a giant fiberglass dinosaur` |

Pick a palette no other stage uses: tests require a distinct sky top, ground color and background per stage.

## Fixed blocks (copied from `assets/prompts/00-style-guide.md`, do not edit)

`{STYLE}` = STYLE-A:
```
high-color pixel art, 1990s 32-bit arcade racing game sprite style, crisp hard-edged pixels, no anti-aliasing blur, limited but rich palette, bold readable silhouettes, saturated sunny colors, clean dark outlines on key shapes, late-afternoon sun lighting from the upper left
```

Negative prompt (if supported):
```
photorealistic, resembles a real production car model, real car brand, logo, badge, emblem, license plate text, watermark, signature, text, letters, blurry, muddy colors, desaturated, grunge, low contrast, extra wheels, distorted perspective, 3d polygon low-poly look, cropped subject
```

## BG-{{SLUG}}-01 Background composite (required)

- **Save as:** `assets/concept/backgrounds/{{slug}}_composite_A_v1.png`
- **Aspect:** 21:9 (every existing composite is 1916x821)
- **How it's used** (`spritelib.make_background`): everything **above the horizon row** is
  cut out, scaled to 1280 wide and joined to its own mirror image to tile. So: a flat, level
  horizon line about 70 to 85% of the way down (existing horizons are rows 560 to 706 of
  821), nothing important below it, no text (it gets mirrored), no road, no cars. The
  stage select postcard is a 16:9 center crop of the whole image, so keep the middle
  interesting.
- The per-layer prompts (sky, far, near) in older background files are not used by the game; skip them.

```
Wide horizon panorama for an arcade racing game, {{stage_name}}: {{sky}}; {{far}}; in front of that {{near}}. Clear horizontal layering for parallax scrolling, a flat level horizon line about three quarters of the way down, nothing in the lower quarter except flat ground at the horizon line. Wide horizontal panorama, seamless left and right edges, no road, no cars, no text. {STYLE}
```

**Filled example** (BG-NEON-01, `neon_composite_A_v1.png`, horizon row 676):
```
Wide horizon panorama for an arcade racing game, Neon Strip: deep purple-to-black night sky with a big moon and faint stars; a distant skyline of glowing towers in magenta, cyan and gold; in front of that silhouetted palm trees and closer illuminated mid-rise hotels. Clear horizontal layering for parallax scrolling, nothing in the lower third except flat ground at the horizon line. Wide horizontal panorama, seamless left and right edges, no road, no cars. {STYLE}
```

## RS-{{SLUG}}-COLORS Road color study (reference for the theme colors)

- **Save as:** `assets/concept/roadside/{{slug}}_road_colors_A_v1.png`, 16:9. Not sliced:
  Claude picks the theme's sky, ground, rumble, road and lane colors from it.

```
Color palette study for a pseudo-3D arcade racing game road in {{stage_name}} ({{stage_mood}}): a straight road seen from behind the car stretching to the horizon, showing the asphalt color, alternating rumble strip colors, lane markings, and the roadside ground (grass, sand, snow, water or pavement as fits the place). Flat color bands, no cars, no sprites. {STYLE}
```

## RS-{{SLUG}}-01..05 Roadside sheets (required: four or five)

Use the roadside section of `assets/prompts/templates/element.md` for each, with the rules
there (count, gaps, reading order). A stage that reads well has:

| Sheet | Save as | Contents | Count |
|---|---|---|---|
| 01 vegetation | `{{slug}}_trees_A_v1.png` | the repeating tall plant (3 to 4 variants) plus a low one | 5 to 7 |
| 02 buildings | `{{slug}}_buildings_A_v1.png` | 2 to 3 local buildings, front-facing | 2 to 3 |
| 03 props | `{{slug}}_props_A_v1.png` | small roadside things: fences, signs, posts | 3 to 6 |
| 04 landmarks | `{{slug}}_landmarks_A_v1.png` | 2 big one-offs | 2 |
| 05 extras | `{{slug}}_extras_A_v1.png` | six one-off set pieces, including `{{landmark}}` | 6 |

All in `assets/concept/roadside/`. Keep each sheet's objects similar in height (each sheet is
scaled by its tallest object).

## DT-{{SLUG}}-01 Road-spanning piece (required: one)

Use the road-spanning section of `element.md`; save as
`assets/concept/roadside/dt_{{slug}}_{{thing}}_A_v1.png`. A tunnel or covered bridge also
needs its interior ring (`dt_{{slug}}_{{thing}}_ring_A_v1.png`).

## Traffic locals (optional)

Two or three local vehicles, rear view, on a traffic sheet (`element.md` section 2). Or reuse
existing ones: `surf_van`, `trolley`, `log_truck`, `tractor`, `airboat_trailer`, `taxi`,
`golf_cart`, `jeep_red`, `limo_white`, `dump_truck`, `boat_trailer`, `news_truck`,
`double_decker`, `combine`, `tow_truck`, `ice_cream_truck`, `pickup_red`, `tuk_tuk` (the full
list is `traffic` in `assets/sprites/manifest.json`).

## Before handing off

- [ ] Composite: flat horizon, no road, no text; note the horizon row (y pixel) if you can.
- [ ] 4 or 5 roadside sheets, one span, the road color study, all named as above.
- [ ] Brief filled in: name, slug, mood, palette, landmark, and the stage's layout in a few
      sentences (sections, e.g. "open desert with crests, then a canyon of tight bends, then a
      diner stop and a long run to the finish").
