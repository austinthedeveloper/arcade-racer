class_name Cfg
extends RefCounted
## Global tuning constants for the road renderer and the driving model.

# Screen (internal resolution; the window scales it up)
const SCREEN_W := 640
const SCREEN_H := 360
const HORIZON_Y := 151.0  # flat-road horizon, about 42% from the top
const PROJ := 320.0  # world-to-screen scale (half the screen width)

# Road
const SEGMENT_LENGTH := 200.0
const RUMBLE_LENGTH := 3  # segments per rumble-strip color band
const ROAD_WIDTH := 2000.0  # half-width of the road in world units
const LANES := 4
const DRAW_DISTANCE := 300  # segments
const FOG_DENSITY := 4.0

# Camera
const CAMERA_HEIGHT := 1000.0
const CAMERA_DEPTH := 0.84  # 1 / tan(fov / 2), roughly a 100 degree field of view
const PLAYER_Z := 1500.0  # distance from the camera to the player's car

# Cars
const CAR_WIDTH := 1000.0  # world units; a lane is 1000 wide
const MAX_SPEED := 12000.0  # world units per second
const DISPLAY_TOP_SPEED := 198.0  # mph shown at MAX_SPEED
const ACCEL := MAX_SPEED / 3.2
const BRAKING := MAX_SPEED / 1.4
const DECEL := MAX_SPEED / 6.0
const OFFROAD_DECEL := MAX_SPEED / 1.8
const OFFROAD_LIMIT := MAX_SPEED / 3.5
const CENTRIFUGAL := 0.3
const STEER_RATE := 2.2  # road half-widths per second at full speed and full lock
const GRAVITY := 12000.0
const NITRO_CHARGES := 3
const NITRO_DURATION := 3.0
const NITRO_SPEED_MULT := 1.25
const NITRO_ACCEL_MULT := 1.8
const CRASH_DURATION := 1.6
