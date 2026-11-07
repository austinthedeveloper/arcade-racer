# Tools

Most tools explain themselves at the top of the file, and `CLAUDE.md` lists the commands. This
page covers the one pipeline that spans several tools and a website.

## Car renders: 3D model to sprite strips (CP-1)

The player cars' steering strips (`assets/sprites/cars/<car>_steer.png`, plus `_steer_up` and
`_steer_down`) can come from a 3D model instead of the concept steering sheets. A model gives
every frame the same car, exact uphill and downhill strips, and later the crash frames, paint
masks, rival angles and the car select turntable (CP-3, CP-4, CP-5, CP-10). The game reads the
strips the same way either way.

**1. The pictures for the model** (once per car):

```sh
python3 tools/make_model_inputs.py vega
```

This cuts `assets/concept/cars/car_vega_views_*.png` (the newest) into `build/model_inputs/vega/`:
`back.png`, `front.png`, `left.png`, `right.png` on transparent squares, and `hero.png`.

**2. The model** (a person, on the web, about five minutes):

1. On [Tripo](https://www.tripo3d.ai), choose image to 3D, **multi-view**. Put `front.png`,
   `left.png`, `back.png` and `right.png` in the slots of the same names.
2. Generate. If the result has the wrong proportions or a melted cabin, try again, or try
   `hero.png` alone (single image).
3. Download it as **GLB**. Then shrink it for the repository (Tripo's are about 60 MB, almost
   all mesh) into `assets/models/vega.glb`:

   ```sh
   blender -b --factory-startup -P tools/blender/prepare_model.py -- --model ~/Downloads/car.glb --out assets/models/vega.glb
   ```

Use a paid plan: the free tier's models are not for commercial use. Rodin or Meshy work too,
with any model that comes out as `.glb`, `.fbx` or `.obj`.

**3. The strips:**

```sh
tools/render_car.sh vega             # build/car_renders/vega/strips/ and compare.html
tools/render_car.sh vega --install   # and over assets/sprites/cars/
```

Blender (`brew install --cask blender`; nobody needs to open it) renders 7 steering frames at
3 pitches (`tools/blender/render_car.py`). Then `tools/make_car_renders.py` shrinks them so the
straight frame is 180 px wide, cuts the colors to a small palette and darkens the outline. Open
`build/car_renders/vega/compare.html` to see the concept-sheet strips and the rendered ones
together. If the car is facing the wrong way, pass `--forward=-y` (or `x`, `-x`): the axis its
nose points along when it comes in.

What differs per car is in `tools/blender/car_looks.py`, by strip name: which way the nose faces
(Tripo's come in nose toward the camera), which texels count as lamps and the hue they glow in,
a turn of the paint's hue, the camera tilt, the cabin wall and a part to raise. Lamps on an AI-made model are
only painted on, so the render makes texels of the lamps' color glow (`GLOW_*` in the render
script). `--only=level_3,up_0` renders just those frames, to try a setting in seconds.

`--style=cel` renders flat bands of light instead of the model's own shading, with a hard
highlight (`CEL_*`), closer to pixel art.

`tools/blender/render_car.py` sets the rest of the look in its constants: `STEER_YAW` (the turn
at each frame, matched to the sheets), `PITCH` (the hill tilt), the camera (`CAMERA_LENS`,
`CAMERA_DISTANCE`), the sun (behind the camera, so the tail and deck are lit), the sky the paint
reflects (`SKY`) and the paint (`PAINT_*`, `NEUTRAL_SATURATION`). `tools/blender/blockout_vega.py`
builds a rough Vega from boxes, to try the pipeline without a real model.

What a Tripo model needs, all found on the Bruiser:

- **It is about 0.7 metallic all over**, stripes too, so a white stripe shows the sky and the
  paint shows every lump in the mesh: `PAINT_METALLIC` takes most of that away. Chrome and white
  texels skip the richer color (`NEUTRAL_SATURATION`), or the bumper and stripes go blue.
- **It has no glass.** The windows are holes, and the road shows through the cabin. The strip
  pass fills any hole in the outline with a dark gradient (`fill_glass`), and an invisible wall
  ahead of the seats (`cabin_wall`) clears the dash and engine seen through them.
- **Don't cut the palette.** At 64 colors smooth paint breaks into blotches and at 256 it still
  pales; the concept strips have tens of thousands (`COLORS` is 0).
- **The camera:** the Bruiser's long tail and deep fenders hide the tires at 15 degrees, and a car
  with no tires showing floats however steep the camera is. It uses 9, and `contact_shadow` fills
  from the tires down to the sprite's bottom edge, since tail pipes set that edge.
- **The blower** comes out below the roofline at 9 degrees, where the concept art draws it above.
  `raise_part` lifts the part in the model, as the art does. A stretch shows on a hard turn, but
  not much at sprite size.
- **The lamps** lose their clear coat and specular where they glow, or a lumpy mesh puts white
  streaks across them on a right turn. A fill light from the camera's right (`FILL_*`) keeps that
  flank out of shade.
- **Height:** at 9 degrees the level strip is 0.77 of its width (the concept's was 0.73). The
  uphill strip is 0.98, over `CarSprites.MAX_HEIGHT`; `car_scale` draws every pitch at the level
  strip's scale so the car doesn't shrink when the strip swaps.

Models in `assets/models/` stay out of the Godot project (`.gdignore`); only the strips ship.

**The Vega trial (2026-11-02):** the rendered Vega has the right shape and turns convincingly,
but in a race it looked duller and softer than the concept-sheet sprite, and its taillights
barely showed, even with the lamp glow and extra saturation and contrast. Cel shading, with
the sun moved ahead of the car as in the hero art, came out crisper and redder, but the lamps
still read pale pink and the light bar faint: the concept's glowing triangles are painted
detail the model's texture doesn't have. The concept-sheet strips stay in the game; the models
may still serve the car select turntable (CP-10), a screen of its own. `build/car_renders/vega_ingame_compare.png` (made by hand) had four
race frames side by side.

**The Bruiser trial (2026-11-06):** the first Tripo generation came out right from all sides. With
the fixes above the render sits on the road, its light bar reads as well as the concept's, and it
has real uphill and downhill strips, which the concept sheets don't (they fake it by stretching).
It is plainly better uphill. On level road the concept was a little crisper, and its flanks are
still brighter when airborne. Austin drove it and chose the render: these strips are in the game, `RENDERED` in `tools/make_car_sprites.py` keeps the sheet rebuild
off them, and `tools/check_sprites.py` doesn't cover them.
