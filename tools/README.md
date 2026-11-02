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

Tripo's Vega comes in nose toward the camera and needs `--forward=-y`. Its lamps are only
painted on, so the render makes orange-to-amber texels glow (`GLOW_*` in the render script).

`tools/blender/render_car.py` sets the look in its constants: `STEER_YAW` (the turn at each
frame, matched to the sheets), `PITCH` (the hill tilt), the camera (`CAMERA_TILT`,
`CAMERA_LENS`, `CAMERA_DISTANCE`) and the sun from the upper left. `tools/blender/blockout_vega.py`
builds a rough Vega from boxes, to try the pipeline without a real model.

Models in `assets/models/` stay out of the Godot project (`.gdignore`); only the strips ship.

**The Vega trial (2026-11-02):** the rendered Vega has the right shape and turns convincingly,
but in a race it looked duller and softer than the concept-sheet sprite, and its taillights
barely showed, even with the lamp glow and extra saturation and contrast. The concept-sheet
strips stay in the game. `build/car_renders/vega_ingame_compare.png` (made by hand) had four
race frames side by side.
