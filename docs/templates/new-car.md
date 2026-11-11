# New car: Claude prompt

Art first: `assets/prompts/templates/car.md`. When the hero and steering sheet are in
`assets/concept/cars/`, fill the brackets and paste everything in the box into Claude Code.

```text
Add a new player car to Sundown Run. Read CLAUDE.md first and work on a feature/CLD-car-<id> branch.

Car:
- id: car_<id>   (strip id: <id>)
- name: <Display Name>          archetype: <short line shown on the select screen>
- stats 1..5: accel <a>, top_speed <t>, handling <h>
- extras (optional): offroad <0..1, 1 = normal slowdown>, nitros <n>, nitro_time <x of normal>
- unlock: <starter | reach stage N | other>
- rival driver: <Name>, style <CLEAN | AGGRESSIVE | ERRATIC>, pace <0.92..0.97>, lane_bias <-0.3..0.3>
- art: assets/concept/cars/car_<id>_hero_<v>.png and car_<id>_steer_sheet_<v>.png

Do this:
1. tools/make_car_sprites.py: add ("<id>", "car_<id>_steer_sheet_<v>.png") to GARAGE.
2. tools/make_ui_sprites.py: add ("<id>", "car_<id>_hero_<v>.png", CAR_CROP) to CARS. Look at
   the cropped picture; if the car is cut off, give it its own crop box like the Hauler's.
   Every car in the garage now has its strips and picture rendered from a 3D model instead
   (tools/README.md): once this one has a model, tools/render_car_hero.sh <id> replaces the crop,
   and adding it to RENDERED in make_car_sprites.py keeps both tools off it.
3. Build (needs the PIL venv from tools/requirements.txt):
     python3 tools/make_car_sprites.py assets/concept .
     python3 tools/make_ui_sprites.py assets/concept .
   Both rebuild every car, traffic sprite, logo and postcard. Commit only the new
   assets/sprites/cars/<id>_steer.png and assets/sprites/ui/car_<id>.png; if git shows other
   sprites changed (a different Pillow version), git checkout them.
   Then godot --headless --path . --import so Godot picks up the new textures.
4. scripts/car/cars.gd: add the entry to Cars.LIST (keys id, name, archetype, accel,
   top_speed, handling, strip, plus offroad / nitros / nitro_time if set). Put it before
   car_hauler and car_zenith (the secret and tour cars stay last).
5. scripts/car/rival_profile.gd: add make("<Name>", "car_<id>", Style.<STYLE>, <pace>, <bias>)
   to RivalProfile.roster() (one driver per car is tested).
6. scripts/core/unlocks.gd: add the id to STARTERS or to BY_STAGE with its stage number.
7. Tests:
   - tests/test_player_car.gd test_every_car_has_its_sprites_and_picture: bump the garage count.
   - tests/test_unlocks.gd: add it to the table in test_cars_open_by_the_stage_reached (or
     fix the starter count in test_starters_are_open_from_the_start).
   - tests/test_render.gd: test_player_cars_are_solid and test_player_cars_show_no_key_magenta
     must pass for it. If they fail, fix the sheet or the keying, not the test; an open frame
     (like the Skipper) goes in OPEN_FRAME with a comment.
   - If it has offroad / nitros / nitro_time, add a check to test_car_stats_change_how_it_drives.
8. tools/test.sh. The golden traces WILL change: the rival pool is drawn from the roster, so a
   new driver changes who races. Regenerate with godot --headless --path . -s res://tests/golden.gd
   and say so in the commit ("new rival in the pool").
9. Look at it:
     godot --path . -- --screen=cars --car=car_<id> --menu-shot=/tmp/cars.png
     godot --path . -- --autodrive --car=car_<id> --screenshots=200,700 --shot-dir=/tmp/shots
     godot --path . -- --autodrive --stage=2 --at-segment=600 --car=car_<id> --screenshots=300 --shot-dir=/tmp/shots
     tools/car_angles.sh --car=car_<id>   (open build/car_angles/car_angles.html)
   Check: same on-screen size as the other cars, no magenta fringe, steering frames in the
   right direction (steering left shows the car's left flank), taillights visible, and it
   still sits right on the road uphill and downhill (the car-angle page).
10. tools/shots.sh. menu_cars may change if the car list layout moves; if it does, look at the
    new image, tools/shots.sh --update, and say why in the commit.
11. Record the car: add a row to the roster table in docs/07-art-prompts-round4.md if it is
    not there, and save the filled art prompts as assets/prompts/cars/car_<id>.md.
Commit on the branch; don't merge.
```

## Checklist

- [ ] `GARAGE`, `CARS` (ui), `Cars.LIST`, `RivalProfile.roster()`, `Unlocks` updated
- [ ] `assets/sprites/cars/<id>_steer.png` and `assets/sprites/ui/car_<id>.png` committed, nothing else from the rebuild
- [ ] Tests extended; `tools/test.sh` passes
- [ ] Golden traces regenerated, reason in the commit
- [ ] Screenshots looked at: car select and in race
- [ ] `tools/shots.sh` passes (or updated with a reason)
