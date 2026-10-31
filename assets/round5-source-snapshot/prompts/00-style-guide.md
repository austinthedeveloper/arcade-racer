# Prompt Style Guide

Every prompt in this folder ends with `{STYLE}`. Replace it with one of the blocks below. Keep the same block across a whole round so results are comparable.

## STYLE-A: High-color pixel art (recommended)

```
high-color pixel art, 1990s 32-bit arcade racing game sprite style, crisp hard-edged pixels, no anti-aliasing blur, limited but rich palette, bold readable silhouettes, saturated sunny colors, clean dark outlines on key shapes, late-afternoon sun lighting from the upper left
```

## STYLE-B: Pre-rendered 90s CG sprites

```
late-1990s pre-rendered CG sprite style, glossy smooth shading, slightly exaggerated toy-like proportions, saturated arcade colors, crisp edges, soft studio rim light, bright warm sun from the upper left, looks like a sprite rendered from a 3D model for a 1990s arcade cabinet
```

## STYLE-C: Painted / illustrated

```
bold flat-shaded illustration, cel-shaded with 2 to 3 tone steps, clean confident linework, retro 1980s travel-poster color palette, saturated warm sunset tones, graphic and readable, modern-retro arcade game art
```

## Negative prompt (if supported)

```
photorealistic, resembles a real production car model, real car brand, logo, badge, emblem, license plate text, watermark, signature, text, letters, blurry, muddy colors, desaturated, grunge, low contrast, extra wheels, distorted perspective, 3d polygon low-poly look, cropped subject
```

## General rules

- Name original brands only when needed: Vega, Bruiser, Kestrel, Solano, Mesa, Phantom, Hauler, Zenith, Tempest, Skipper, Halo, Cyclone (cars); fake roadside brands are listed in the roadside files.
- For single sprites or sprite sheets, add: `isolated on a flat solid magenta #FF00FF background, centered, full subject visible, no ground shadow`.
- For backgrounds, add: `wide horizontal panorama, seamless left and right edges, no foreground objects, no road`.
- Sheets the tools slice (traffic, roadside, power-ups) need a clear gap between objects: the slicer finds each sprite as one connected shape.
- Road-spanning pieces (tunnels, bridges, gates) are straight-on and symmetrical with the opening filled with magenta; see `roadside/drive-through.md`.
- Aspect ratios: key art 16:9, sprites 1:1 or 4:3, background layers 4:1 (or the widest your generator allows).
