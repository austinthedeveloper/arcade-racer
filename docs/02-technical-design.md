# Technical Design Document

How we build a sprite-based pseudo-3D arcade racer in Godot 4, with first-class support for steering wheels and pedals.

---

## 1. Engine and project settings

| Setting | Value | Why |
|---|---|---|
| Engine | Godot 4.x, latest stable | Current input stack, good 2D tooling |
| Language | GDScript | Fast iteration. Hot paths can move to C# or a GDExtension later if profiling says so. |
| Renderer | Compatibility (OpenGL) | Pure 2D work, widest hardware support, fine on macOS |
| Internal resolution | **640 x 360** (pixel art, decided) | Integer-scales to 720p (x2), 1080p (x3), 1440p (x4), 4K (x6) |
| Stretch mode | `viewport`, aspect `keep`, integer scaling optional | Crisp pixels, no shimmering from non-integer scale |
| Texture filter | Nearest | Pixel art |
| Physics tick | 60 Hz fixed, game logic in `_physics_process` | Deterministic-ish feel, simple ghost replays later |
| Target frame rate | Locked 60 fps, V-Sync on | Arcade smoothness |

If we go with a hi-res painted look instead of pixel art, the internal resolution moves to 1280 x 720 (or native) with linear filtering. Nothing else in this document changes.

## 2. Rendering approach: classic pseudo-3D

We will **not** use Godot's 3D engine for the road. We use the classic segment-projection technique from 80s/90s arcade road games, drawn with Godot's 2D API. This gives the authentic look (scaled sprites, banding stripes, sprite pop) and keeps the game logic in simple track coordinates.

> Alternative considered: a real 3D scene with a flat road mesh and `Sprite3D` billboards. Easier hills/tunnels, but it looks "modern 2.5D", fights pixel-perfect rendering, and makes the arcade-style physics harder to tune. We can revisit if the classic approach hits a wall.

Good references for the technique (algorithms, not code to copy):
- Lou's Pseudo 3D Page (the classic write-up on road rendering)
- Jake Gordon's "javascript-racer" articles (segment-based curves, hills, sprites)

### 2.1 Track data model

A track is a long list of **segments**. Each segment is a short slice of road (e.g. 200 world units long).

```gdscript
# res://scripts/track/segment.gd
class_name Segment
var index: int
var z: float                # start distance along track
var curve: float            # horizontal bend applied per segment (+right, -left)
var y: float                # world height at segment start (hills)
var width: float            # half-width of road in world units
var lanes: int
var surface: int            # ROAD, BRIDGE, TUNNEL, DIRT...
var color_band: int         # alternates for stripe/rumble pattern
var sprites: Array[RoadsideSprite]   # static roadside objects
var cars: Array                      # dynamic cars currently in this segment
var flags: int              # CHECKPOINT, FINISH, JUMP, SPLIT, ...
```

Tracks are authored as **Godot Resources** (`.tres`) built from high-level commands, so designers write intent, not thousands of segments:

```gdscript
# Example track script (builder API)
b.straight(50)
b.curve(length=100, strength=CURVE_MEDIUM)      # eases in, holds, eases out
b.hill(length=60, height=HILL_HIGH)
b.s_curves()
b.checkpoint()
b.sprites_every(4, "palm_tall", side=BOTH, offset=1.4)
```

Later, an in-editor `@tool` preview (a top-down and side-elevation plot of the track) makes authoring much faster. That's a nice-to-have after MVP.

### 2.2 Frame rendering

Each frame, the `RoadRenderer` node (a `Node2D` using `_draw()` or a rebuilt `ArrayMesh`):

1. Finds the segment under the camera.
2. Walks forward `draw_distance` segments (about 200 to 300), accumulating curve offsets (`dx`, `x`) to bend the road.
3. Projects each segment edge from world to screen: `scale = camera_depth / (z_world - z_camera)`; `screen_x`, `screen_y`, `screen_w` derive from that.
4. Skips segments hidden behind a hill (tracks the lowest drawn `screen_y` so far, a.k.a. the "clip line").
5. Draws, back to front: grass band, rumble strips, road, lane markings, as filled quads with per-stage colors.
6. Draws sprites (roadside objects and cars) back to front, scaled by the segment's projection, clipped against the hill line above them.
7. Draws fog: blend each segment's colors toward a fog color with distance (also gives depth on clear days).

Performance notes:
- ~300 segments x 4 quads = ~1,200 quads per frame. Batch them into one `ArrayMesh` (or `draw_polygon` with a single canvas item) to keep draw calls tiny.
- Sprites come from **texture atlases** per stage, drawn with `draw_texture_rect_region`. One atlas = one batch.
- No per-pixel shader needed for the road. Optional post shaders: scanlines/CRT, heat haze, rain.

### 2.3 Background

- 3 to 4 **parallax layers** (sky gradient, far mountains/skyline, mid hills, near treeline) as wide repeating textures.
- Layers scroll horizontally based on the accumulated track curve (turning right pans the scene left) and vertically with hills.
- Time-of-day tint via a `CanvasModulate`-style color multiply per layer.

### 2.4 Sprite scaling and pixel look

- Sprites are authored at their **closest on-screen size** (the size they'd appear when right next to the camera), and downscaled by projection.
- For pixel art, use nearest filtering and optionally pick from 2 or 3 **mip "LOD" versions** (hand-made smaller sprites) to avoid shimmer at distance.
- Every sprite has a **bottom-center pivot**, defined in a sprite metadata table (atlas region, world width, pivot, collision width).

### 2.5 Car sprites

| Car | Frames needed |
|---|---|
| **Player car** | Steer: 7 frames (hard left -> straight -> hard right) x Pitch: 3 (uphill, flat, downhill) = 21 frames. Plus: brake lights on/off overlay, nitro flame overlay, 6 to 8 crash tumble frames, power-slide variants (2 per side). |
| **Rival cars** | Same car designs seen from behind at different angles: 5 frames (far left, left, center, right, far right) chosen by relative screen position, + brake light overlay. |
| **Traffic** | Rear view, 3 angles. Oncoming traffic needs front view, 3 angles. |

Paint colors via a **palette-swap shader** (body pixels painted in a key ramp of colors, replaced at runtime), so we don't redraw every car per color.

## 3. Game logic

### 3.1 Scene / node structure

```
Main (Node)
├── GameState (autoload)          # mode, progression, save/load
├── InputRouter (autoload)        # device detection, profiles, normalized DriveInput
├── Audio (autoload)              # music "radio", announcer, SFX bus
└── Race (Node)
    ├── SubViewport (640x360)
    │   ├── Background (parallax layers)
    │   ├── RoadRenderer (Node2D)
    │   └── FX (particles: smoke, sparks, dust)
    ├── RaceDirector               # countdown, checkpoints, timer, finish, positions
    ├── PlayerCar (CarController)
    ├── RivalManager (7 x CarController + AIDriver)
    ├── TrafficManager             # spawns/despawns traffic around the player
    └── HUD (CanvasLayer, may render at native resolution for crisp text)
```

### 3.2 Car simulation (track space)

```gdscript
# Per physics tick
speed += accel_curve.sample(speed / max_speed) * throttle * dt
speed -= brake_force * brake * dt
speed -= drag * speed * dt
x += steer * steer_rate(speed) * dt
x -= segment.curve * centrifugal * (speed / max_speed) * dt   # pushed outward in curves
if abs(x) > 1.0: speed = move_toward(speed, offroad_limit, offroad_decel * dt)
z += speed * dt
```

- **Air time:** If the road's height drops away faster than gravity would pull the car down at the current speed, the car goes airborne (`vertical_velocity` integrated separately, sprite offset upward, steering reduced).
- **Collisions:** Simple 1D overlap: same/neighboring segment and `|x_a - x_b| < (w_a + w_b) / 2`. Severity by closing speed decides bump vs big crash.
- **Nitro / drafting:** Modifiers on max speed and accel with timers.
- All tuning values live in a `CarStats` Resource per car, editable in the inspector.

### 3.3 AI

- **Rivals:** `AIDriver` follows a target lateral line (data-authored or derived from curves), avoids traffic by checking cars a few segments ahead, uses nitro on straights. Difficulty and rubber-band settings in a Resource.
- **Traffic:** Fixed lane, fixed speed per type, occasional lane change. Spawned in a window around the player (e.g. 50 segments behind to 250 ahead) from a pool, so we never simulate the whole route.
- **Positions:** Sorted by `z` (total distance) every tick.

### 3.4 Data-driven content

| Data | Format |
|---|---|
| Tracks | `.tres` Resources produced by track builder scripts |
| Car stats | `CarStats.tres` per car |
| Sprite metadata | `SpriteDef.tres` per atlas (regions, pivots, world sizes, collision) |
| Stage theme | `StageTheme.tres`: road/grass/rumble colors, fog color, background layers, music default, weather |

## 4. Input system (gamepads, wheels, pedals)

This is the area most likely to cause trouble, so it gets its own design.

### 4.1 Goal

Every frame, gameplay reads one normalized struct, regardless of device:

```gdscript
class_name DriveInput
var steer: float      # -1.0 (full left) .. 1.0 (full right)
var throttle: float   # 0.0 .. 1.0
var brake: float      # 0.0 .. 1.0
var nitro: bool       # pressed this frame
var shift_up: bool
var shift_down: bool
var horn: bool
var pause: bool
var device_kind: int  # KEYBOARD, GAMEPAD, WHEEL
```

`InputRouter` (autoload) owns producing it.

### 4.2 How Godot sees devices

- Gamepads and wheels both appear as **joypads**. Godot exposes `Input.get_joy_name()`, `Input.get_joy_guid()`, `Input.get_joy_axis()`, and fires `Input.joy_connection_changed` on hot-plug.
- Gamepads with a known SDL mapping get standard axes (left stick X = `JOY_AXIS_LEFT_X`, triggers = `JOY_AXIS_TRIGGER_LEFT/RIGHT`). These work fine through the normal **InputMap**.
- **Wheels usually have no standard mapping.** They expose raw axes whose numbering, range, and direction vary by brand, model, OS, and driver mode. Examples of what we must handle:
  - Steering on axis 0, range -1..1 (usually fine).
  - Pedals as separate axes that **rest at +1.0 and go to -1.0 when pressed** (inverted, full range).
  - Pedals that rest at 0 and go to 1.
  - Gas and brake **combined on one axis** (older wheels / some driver modes).
  - Clutch on a third pedal axis (we ignore it or allow binding).
- So for wheels we **read raw axes and apply a per-device calibration profile**, rather than relying on the InputMap's fixed axis/sign bindings.

### 4.3 Device profiles

```
Profile (saved per joypad GUID in user://input_profiles.cfg)
  kind: GAMEPAD | WHEEL
  steer_axis, steer_min, steer_center, steer_max
  steer_range_deg (e.g. 900 hardware), in-game lock (e.g. use 270 deg of it)
  steer_deadzone, steer_linearity (gamma curve)
  throttle_axis, throttle_rest, throttle_full
  brake_axis, brake_rest, brake_full
  combined_pedals: bool
  button bindings: nitro, shift up/down (paddles), horn, pause, view
```

- **Auto-detect:** On connect, check the device name for wheel hints ("wheel", "racing", "G29", "G920", "G923", "T300", "T150", "TMX", "Fanatec", "Moza", ...). Known names get a starting profile; unknown wheels go to the calibration wizard.
- **Calibration wizard** (also reachable from Options):
  1. "Let go of everything." Sample all axes for 1 second, record rest values.
  2. "Turn the wheel fully left, then fully right." Detect the axis with the largest swing; record min/max and center.
  3. "Press the gas fully." Detect the axis that moved most from rest; record full value. Works for inverted and 0..1 pedals alike.
  4. "Press the brake fully." Same. If it's the same axis as gas but opposite direction, mark `combined_pedals`.
  5. "Press the button you want for Nitro / Shift up / Shift down." (Optional.)
  6. Live test screen with bars for each value.
- **Normalization:** `value = clamp(inverse_lerp(rest, full, raw), 0, 1)`, then deadzone and response curve.

### 4.4 Steering feel per device

| Device | Steering processing |
|---|---|
| **Wheel** | Direct. `steer = raw_normalized * (hardware_range / in_game_lock)`, clamped. Small deadzone (1 to 2%), no smoothing, no speed sensitivity. Default in-game lock ~270 to 360 deg. |
| **Gamepad stick** | Deadzone ~10%, response curve (gamma ~1.5) for precision near center, speed-sensitive reduction at top speed, light smoothing. Optional steering assist. |
| **Keyboard / D-pad** | Digital: steer ramps toward -1/1 over ~0.15 s and returns to center faster. |

Throttle/brake: triggers and pedals are analog; keyboard and face buttons are digital (0 or 1).

### 4.5 Force feedback

- Godot's built-in `Input.start_joy_vibration()` is **rumble only**. Most wheels ignore it; it cannot do a centering spring or road effects.
- Without force feedback, many wheels go limp (no self-centering). **MVP workaround:** document enabling the "centering spring for non-FFB games" option in the wheel vendor's software (e.g. Logitech G HUB, Thrustmaster Control Panel).
- **Post-MVP:** a small **GDExtension wrapping SDL's haptic API** to drive constant force (curve pull), spring (centering), periodic (off-road rumble), and jolts (collisions). Abstracted behind an `FFB` autoload so the game calls `FFB.jolt(strength)`, `FFB.set_spring(k)`, etc., and it's a no-op when unsupported.

### 4.6 Platform notes

- Primary dev platform appears to be **macOS**. Wheel support on macOS is patchier than on Windows: some Xbox-branded wheels (e.g. G920/G923 Xbox editions) need vendor software and may not enumerate correctly. **Test early with your actual wheel.**
- Windows is the most important target for wheel players. Plan to test there before calling wheel support done.
- Steam Input can remap gamepads but can interfere with wheels. Document that players may need to disable Steam Input for wheels.
- Release builds (`tools/export.sh`, `.github/workflows/release.yml`): Windows x86_64 (one .exe, pck embedded), macOS universal (ad-hoc signed, not notarized), and Web (single-threaded, so any static host works without COOP/COEP headers). Browsers expose wheels through the Gamepad API with their own axis mapping, so the web build is mainly for keyboard and gamepad; calibration (F2) still runs there, but the profile lives in browser storage.

### 4.7 Dev tooling

- **Input debug overlay** (F1): every connected joypad, name, GUID, all raw axes as bars, buttons lit when pressed, and the resulting `DriveInput`.
- This screen is the first thing we build in the input milestone. It makes every "my wheel doesn't work" report diagnosable.

## 5. Audio

- Engine: 2 to 3 looping samples (idle, mid, high) crossfaded and pitch-shifted by RPM.
- Tire squeal, wind (volume by speed), whoosh on passing traffic (panned left/right), crash, nitro, checkpoint chime.
- Music: streamed OGG per "radio station"; announcer on its own bus with ducking of music.

## 6. Save data

`user://save.cfg` (ConfigFile) for progress, unlocks, best times. Options live in `user://settings.cfg` (built, see section 10). Input profiles in a separate `user://input_profiles.cfg` so they survive save resets. Built (MP-1): the `SaveData` autoload (`scripts/core/save_data.gd`) holds the furthest stage reached, unlocks (storage only), best time and placing per stage and car (`best` section, keys `<stage id>/<car id>`) and total points, with a `version` under `[meta]`. The race calls `SaveData.record_finish` on a finish (not for autodriven runs or `--at-segment` starts). Tests, golden and the e2e use `TestSuite.use_scratch_save`. Versions (EQ-8): `save.cfg`, `settings.cfg` and `input_profiles.cfg` each carry `[meta] version` (`CfgVersion`); a file without one is version 0 (the format before versions), today's is 1. Loaders migrate one version at a time (0 to 1 changes no keys) and read a newer file as far as the keys they know go. Fixtures for each version are in `tests/fixtures/` (`tests/test_migration.gd`).

## 7. Project folder layout (planned)

```
arcade racer/
├── project.godot
├── docs/                    # these documents
├── assets/
│   ├── prompts/             # image-generation prompts (concept phase)
│   ├── concept/             # generated concept images (not shipped)
│   ├── sprites/             # production sprites + atlases
│   ├── backgrounds/
│   ├── ui/
│   ├── fonts/
│   └── audio/{music,sfx,voice}/
├── data/
│   ├── tracks/              # .tres track resources + builder scripts
│   ├── cars/                # CarStats .tres
│   └── themes/              # StageTheme .tres
├── scenes/                  # .tscn: main, race, menus, hud
└── scripts/
    ├── render/              # road renderer, background, sprite batching
    ├── track/               # segment, track builder
    ├── car/                 # car controller, AI, traffic
    ├── input/               # InputRouter, profiles, calibration
    ├── race/                # race director, checkpoints, scoring
    └── ui/
```

## 8. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | **Concept** | Docs agreed, style frames chosen from concept images |
| M1 | **Road prototype** | Placeholder colors: curves, hills, sprites, parallax, player car driving with keyboard at 60 fps |
| M2 | **Input** | Debug overlay, gamepad + wheel + pedals with calibration wizard and saved profiles |
| M3 | **Racing** | Traffic, 7 AI rivals, collisions, crashes, nitro, air time, checkpoints, timer, finish |
| M4 | **Vertical slice** | Palm Coast Boulevard with real art, HUD, title/results screens, audio pass |
| M5 | **Content** | More stages, cars, Grand Tour progression |
| M6 | **Polish** | Force feedback extension, options, accessibility, Windows wheel testing |

## 9. Risks

| Risk | Mitigation |
|---|---|
| Wheel axis chaos across brands/OS | Calibration wizard + debug overlay from day one; test with real hardware early |
| No force feedback in stock Godot | Vendor centering spring for MVP; GDExtension later |
| Car sprite consistency (many angles, many frames) | Consider pre-rendering car frames from simple 3D models (see art direction doc) |
| Sprite count per frame on dense stages | Atlases, batching, draw distance and sprite LOD per stage |
| AI-generated concepts not usable as production art | Treat generated images as concept/reference only; production sprites are cleaned up or redrawn |

## 10. As built (milestone 1, 2026-10-30)

Notes where the prototype differs from or adds detail to the plan above:

- **Projection** uses one scale factor (`Cfg.PROJ`, half the screen width) for both x and y, so sprites keep their aspect ratio. The horizon sits at y = 151 (42%), and the player's car is drawn `PLAYER_Z` = 1500 units ahead of the camera, which makes it about 180 px wide.
- **Draw order** is painter's: one pass near-to-far projects segments and records how far up the screen nearer road already reaches, then a second pass draws far-to-near (road band, then that segment's sprites and cars). Hills hide what's behind them without per-sprite clipping. Each segment's road is one `canvas_item_add_triangle_array` call.
- **Jumps** come from short, sharp crests (`Track.jump()`): the car leaves the road when the road drops away faster than `GRAVITY` pulls it down.
- **Hill pitch (added 2026-10-30):** the camera never pitches, so on a slope the player car has to. `PlayerCar.pitch` follows the road's slope over the car's length (or its flight path in the air), 1 = 30 degrees nose-down. `CarSprites` draws a nose-down or nose-up steering strip past |pitch| 0.4 (`vega_steer_down.png` / `vega_steer_up.png`, built by `tools/make_car_sprites.py` from the CAR-VEGA-05/06 sheets). Until those exist it stretches the level strip's roof/deck and bumper slices against each other (`CarSprites.pitch_warp`). The camera stays level, so uphill (nose-up) tips the roof toward it and shows more roof; downhill tips the tail up and shows more bumper and less roof. Traffic isn't pitched: it's small and far enough away that it doesn't read.
- **Input:** gamepads and wheels are read per device in `InputRouter`, not through the InputMap, so wheel pedal axes can't leak into trigger bindings. The keyboard uses InputMap actions registered in code.
- **Sprite tools (updated 2026-10-31):** every `tools/make_*_sprites.py` shares `tools/spritelib.py` (keying, finding objects, crop masking, pixel-art scaling, background strips; numpy and scipy, `tools/requirements.txt`). A full rebuild takes about 20 s. Palm Coast's palms and background are built with the other stages; `tools/make_drawn_props.py` draws its six simple props. The tool specs hold each sprite's world height, collide fraction and scale, and every tool rewrites `assets/sprites/manifest.json`, which `SpriteLibrary` and `CarSprites` load (`tools/manifest.py` rewrites it alone after a number changes).
- **Stages (added 2026-10-30):** `Stages` (`scripts/track/stages/stages.gd`) lists the stages in tour order; each stage is a class with `theme()` (colors + background strip) and `build()` (road + roadside sprites). Stage 2 is Redrock Canyon (`redrock.gd`): open desert with long straights and big crests, a canyon run lined with rock pillars and arches, and a diner stop. Finishing a stage and pressing confirm loads the next with a fresh clock; R restarts the current stage, and confirm after TIME UP retries it. Time doesn't carry over between stages yet. `SpriteLibrary` loads every stage's roadside sprites from `assets/sprites/roadside/<stage>/`. A sprite with `collide` 0 (tumbleweeds) never crashes the car.
- **Stage art:** `tools/make_stage_sprites.py <concept_dir> . [stage]` slices each roadside concept sheet into one keyed sprite per object (small detached bits like pebbles join the object they sit in) and makes the mirrored background strip. Each stage's sheets, object names and texture heights are listed at the top of the script. Neon Strip and the rest only need an entry there plus a stage class. Parts of an object that only touch at a seam (a sign on its pole, a dome on its tower) are joined, sheets with more than one row are read top to bottom, and `None` skips an object.
- **Stages 3 and 4 (added 2026-10-30):** Neon Strip (`neon.gd`) is a night casino boulevard with towers walling in the middle stretch, neon signs, a fountain plaza and heavier traffic: a theme can set `"traffic"` to change the car count (Neon uses 95, the default is 70). Timberline Pass (`timberline.gd`) climbs switchbacks through pines to a snowy summit (the `sand` ground color is snow), with guardrails and chevrons on the outside of the sharp bends, a fire lookout, a waterfall and the lodge at the finish. The tunnel and covered bridge are built as road-spanning sprites (see spans below).
- **Stages 5 and 6 (added 2026-10-30):** Bayou Causeway (`bayou.gd`) runs long, low causeways over still water (the `sand` ground color is water) between cypress islands, with railing posts, pilings and mist on the water. Its theme sets `"fog_density"` (9 against the default 4), so the road fades out sooner. Harvest Valley (`harvest.gd`) rolls through fenced pastures and wheat stubble at sunset, with a farm stop (barn, silos, water tower), windmills and hay bales. The bridge pier sheets are skipped: there's nothing under the road to show them.
- **Stage 7 (added 2026-10-30):** Thunderhead Highway (`thunder.gd`): storm plains with a power line along the right side, pylons far off on the left, windswept trees and puddles, a truck stop and motel, and a road-works chicane lined with cones and drums (collide 0, like tumbleweeds) on gravel shoulders. Slightly thicker fog (5.5). Rain, lightning flashes and a slippery road are not in yet; they need an FX layer and a grip setting. Stage 8 (Skyline Finale, `skyline.gd`) is built on the rerolled v2 background.
- **Menus (added 2026-10-30):** `scenes/main.tscn` is now the game (`scripts/core/game.gd`): title screen, then stage select, then car select, then the race (`scenes/race.tscn`). Picking a stage starts the tour from there; the tour still runs on stage by stage after each finish. Backspace / B / brake while paused quits the race to the title, and stage select then opens on the stage the tour reached. Menus only go left and right so a wheel can drive them: `InputRouter` fills a `MenuInput` each tick next to the `DriveInput` (axis from arrows, stick/D-pad or the wheel, with hysteresis and auto-repeat; confirm is Enter, A/Start, the gas pedal or any wheel button, so an uncalibrated wheel still gets in; back is Esc/Backspace, B/Back or the brake pedal). The title, F1 overlay and F2 calibration also work in the menus. `Cars` lists the twelve select-screen cars with the design doc's 1-5 stats; `Cars.tuning` turns those into multipliers on the Vega's base values: top speed -4% per point under 5, acceleration +10% per point over 4, steering +8% and curve pull -10% per point of handling over 3. Optional `offroad`, `nitros` and `nitro_time` keys on a car change the off-road slowdown and the nitro charges and length (the Mesa Rumbler has no off-road slowdown, the Dune Skipper half, the Halo EV four shorter nitros). Art: `tools/make_ui_sprites.py` keys the UI-01 logo, crops a title backdrop and one postcard per stage from the background composites, and crops one showroom picture per car from its approved hero art. The UI-03/04/05 screen mockups are layout reference only (their cars look like real cars). `--race` (or any race dev flag) skips the menus; `--screen=title|options|stages|cars --menu-shot=<png>` saves a menu screenshot and quits.
- **Options (added 2026-10-30):** the title screen has START and OPTIONS side by side (left/right, so a wheel can pick). `OptionsScreen` lists auto gas, traffic (light/normal/heavy, x0.5/1/1.4 cars), timer (relaxed/arcade/tight, x1.35/1/0.85 on the start time and checkpoint bonuses), music and SFX volume (0-10 on the Music and SFX buses; 0 mutes) and a calibrate-wheel entry. The `Settings` autoload (`scripts/core/settings.gd`) holds them and saves `user://settings.cfg` on every change (separate from the input profiles). The race reads traffic and timer when a stage starts, and runs `InputRouter.state` through `Settings.drive_input` each tick: with auto gas on, the throttle is 1 unless the brake is past 0.05, then 0. `MenuInput` gained an up/down axis (arrows / W S, left stick, D-pad; wheels report none). On the Options screen keyboard and pad use up/down for the row and left/right for the value; a wheel steers through the rows and gas changes the value. Golden traces and tests run on the defaults (`TestSuite.use_scratch_settings`). Two reset rows (AC-9): RESET OPTIONS puts every option back to its default and saves; RESET SAVE DATA asks first (the row shows SURE?, selecting again erases, anything else cancels) and writes a fresh `save.cfg`. Neither touches the other file or the wheel profiles. Pages (AC-10): Game (auto gas, traffic, difficulty, timer, carry time, power-ups, the resets), Display (empty), Audio (volumes), Controls (calibrate), Accessibility (empty). The first row is a page bar: left/right on it flips the page, confirm (gas on a wheel) goes to the next one; BACK sits at the bottom of every page. `--screen=options:<page>` opens a page for a screenshot.
- **Spans and drive-throughs (added 2026-10-31):** tunnels, bridges, arches and the race gates are sprites the road runs through (`SpriteLibrary.spans`, built by `tools/make_span_sprites.py`). The game finds each one's opening near its bottom (`find_opening`) and sizes the span so the opening fits the road; off the road the car crashes into the legs (`PlayerCar.hits_span`). `Track.add_tunnel` repeats a ring for a tunnel or covered bridge, with a fill color around it and darker road inside.
- **Power-ups (added 2026-10-31):** `PowerUps` places up to five pickups per stage at fixed fractions of its length, in lanes (nitro can, clock, ram plate, ghost, mystery hubcap), the same every time for a stage, and can be turned off in Options. A clock adds 3 s; the ram plate (5 s) flings traffic you hit instead of crashing you; the ghost (4 s) lets you drive through traffic; a mystery hubcap turns into one of the others, and into a clock more often when under 12 s are left. The HUD shows the running ram or ghost under the nitro. Pickups and collisions check every segment the car entered in a tick (`PlayerCar.passed_segments`), since at nitro speed it covers more than one.
- **Traffic specials (added 2026-10-31):** every stage theme's `"specials"` lists its local vehicles (Skyline's double-decker, trolley, news truck and taxi; Timberline's log truck, SUV and street sweeper; Harvest Valley's tractor and combine). `Traffic` mixes them in with the cars and big vehicles: 15% big vehicles, 10% locals, the rest cars. A theme without `"specials"` gets `Traffic.SPECIALS`.
- **Not built yet:** AI rivals, positions, results screen, force feedback, steering lock and remapping options.
- **Audio (placeholder):** every sound is synthesized by `tools/make_audio.py` until sound packs replace them (see `assets/audio/README.md`). `SoundBank` maps cue names to files (`.ogg` beats `.wav` beats `.mp3`, so a pack file with the cue's name wins) and sets looping in code. The `Audio` autoload owns the Music and SFX buses (Master has a hard limiter), the music player and a pool of one-shot players. `RaceAudio` is a child of the race that only reads it each tick, after the race updates, and turns changes into cues: countdown beeps, GO, checkpoint, nitro, crash, bump, landing, low-time ticks, finish and time up. The engine is two loops crossfaded and pitched by a simulated five-gear rev curve (`RaceAudio.engine_rpm`); tire squeal and offroad rumble are loops with levels from the car's state. Not built yet: the music "radio", wind, panned traffic whooshes, announcer.
