# Assets

```
assets/
├── prompts/        # image-generation prompts for concept work (this phase)
│   ├── 00-style-guide.md   # style blocks + negative prompt, used by every prompt
│   ├── key-art/            # title art, style frames, mock gameplay screenshots
│   ├── cars/               # one file per playable car
│   ├── traffic/            # civilian vehicles
│   ├── roadside/           # roadside sprite sets, one file per stage
│   ├── backgrounds/        # parallax sky/horizon layers, one file per stage
│   ├── ui/                 # logo, HUD, menus, callouts
│   └── fx/                 # smoke, sparks, nitro, weather
└── concept/        # put generated images here, mirroring the prompts folders
```

## How to use the prompts

1. Open `prompts/00-style-guide.md` and pick a style block (`STYLE-A`, `STYLE-B`, or `STYLE-C`).
2. In any prompt, replace `{STYLE}` with that block's text. Add the negative prompt if your generator supports one.
3. Save results to the **Output** path listed under each prompt (in `assets/concept/...`). Add `_v1`, `_v2`, etc. for variations, e.g. `car_vega_hero_A_v2.png` (the `A` is the style used).
4. Each prompt has a **Round** tag. Do Round 1 first; it decides the style before we spend time on everything else.

## Round 1 checklist (style alignment)

| ID | File | What it decides |
|---|---|---|
| KA-01 | key-art/key-art.md | Overall mood, logo vibe |
| KA-02 | key-art/key-art.md | Gameplay screen look (generate in A, B, and C) |
| KA-03 | key-art/key-art.md | Night-stage look |
| CAR-VEGA-01 | cars/car_vega.md | Car design language |
| CAR-BRUISER-01 | cars/car_bruiser.md | Second car, to compare silhouettes |
| BG-PALM-01 | backgrounds/palm-coast.md | Background painting style |
| RS-PALM-01 | roadside/palm-coast.md | Roadside sprite style |
| UI-01 | ui/logo-and-menus.md | Logo direction |

## Notes on generated images

- These are **concept and reference images**, not shipping art. Production sprites will be cleaned up, redrawn, or pre-rendered (see `docs/03-art-direction.md`).
- Generators handle text badly. Logos and HUD prompts ask for blank shapes or placeholder lettering; real text gets added later.
- For sprite-sheet prompts, ask for a **flat solid magenta (#FF00FF) background** so it can be keyed out.
- Never use real car brands, logos, or existing game assets as references in prompts.
