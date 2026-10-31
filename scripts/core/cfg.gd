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
const ACCEL_START := 1.3  # acceleration multiplier from a standstill...
const ACCEL_FADE := 0.8  # ...less this much by top speed
const BRAKING := MAX_SPEED / 1.4
const DECEL := MAX_SPEED / 6.0
const OFFROAD_DECEL := MAX_SPEED / 1.8
const OFFROAD_LIMIT := MAX_SPEED / 3.5
const CENTRIFUGAL := 0.3
const STEER_RATE := 2.2  # road half-widths per second at full speed and full lock
const MAX_X := 3.0  # furthest off the road center the car can go, in road half-widths
const GRAVITY := 12000.0
const NITRO_CHARGES := 3
const NITRO_DURATION := 3.0
const NITRO_SPEED_MULT := 1.25
const NITRO_ACCEL_MULT := 1.8
const CRASH_DURATION := 1.6
const CRASH_BRAKING := MAX_SPEED * 1.2  # how fast a crashed car slows
const CRASH_RECOVER_X := 0.8  # a crashed car slides back to within this of the road center
const CRASH_RECOVER_RATE := 1.5  # road half-widths per second
const AIR_STEER := 0.35  # steering authority in the air
const STEER_SMOOTHING := 12.0  # how fast the shown steering follows the input, per second
const OVERSPEED_DECAY := MAX_SPEED * 0.4  # per second, back down to top speed (after nitro)
const TAKEOFF_SPEED := MAX_SPEED * 0.4  # slower than this, a crest doesn't launch the car

# Hitting traffic
const HIT_OVERLAP := 0.8  # cars hit when they overlap this much of their combined half-widths
const CRASH_CLOSING_SPEED := MAX_SPEED * 0.5  # closing faster than this crashes; slower bumps
const BUMP_GAP := 50.0  # world units a bump leaves between you and the car you hit
const CAR_LENGTH := 400.0  # world units along the road a car counts as beside you
const SIDESWIPE_SPEED_LOSS := 0.05  # share of your speed a side-swipe scrubs off

# Race clock
const LOW_TIME := 10.0  # seconds left when the clock flashes and ticks
