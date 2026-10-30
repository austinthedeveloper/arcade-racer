# Technical Design Document

How we build a sprite-based pseudo-3D arcade racer in Godot 4, with first-class support for steering wheels and pedals.

---

## 1. Engine and project settings

| Setting | Value | Why |
|---|---|---|
| Engine | Godot 4.x, latest stable | Current input stack, good 2D tooling |
| Language | GDScript | Fast iteration. Hot paths can move to C# or a GDExtension later if profiling says so. |
| Renderer | Compatibility (OpenGL) | Pure 2D work, widest hardware support, fine on macOS |
| Internal resolution | **640 x 360** (pending art decision) | Integer-scales to 720p (x2), 1080p (x3), 1440p (x4), 4K (x6) |
| Stretch mode | `viewport`, aspect `keep`, integer scaling optional | Crisp pixels, no shimmering from non-integer scale |
| Texture filter | Nearest (pixel art) or Linear (hi-res art) | Decided by the art direction question |
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

### 4.7 Dev tooling

- **Input debug overlay** (F1): every connected joypad, name, GUID, all raw axes as bars, buttons lit when pressed, and the resulting `DriveInput`.
- This screen is the first thing we build in the input milestone. It makes every "my wheel doesn't work" report diagnosable.

## 5. Audio

- Engine: 2 to 3 looping samples (idle, mid, high) crossfaded and pitch-shifted by RPM.
- Tire squeal, wind (volume by speed), whoosh on passing traffic (panned left/right), crash, nitro, checkpoint chime.
- Music: streamed OGG per "radio station"; announcer on its own bus with ducking of music.

## 6. Save data

`user://save.cfg` (ConfigFile) for progress, unlocks, best times, options. Input profiles in a separate `user://input_profiles.cfg` so they survive save resets.

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
