class_name Cfg
extends RefCounted
## Fixed constants for the road renderer and the driving model. The numbers worth tuning
## (driving, crashes, camera feel, ...) are in Tuning (EQ-15).

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
const PLAYER_Z := 1500.0  # distance from the camera to the player's car

# Cars
const CAR_WIDTH := 1000.0  # world units; a lane is 1000 wide
const HALF_CAR := CAR_WIDTH * 0.5 / ROAD_WIDTH  # half a car's width, in road half-widths (the x racers drive at)
const MAX_SPEED := 12000.0  # world units per second
const DISPLAY_TOP_SPEED := 198.0  # mph shown at MAX_SPEED
const MAX_X := 3.0  # furthest off the road center the car can go, in road half-widths
const NITRO_CHARGES := 3
const CRASH_RECOVER_X := 0.8  # a crashed car slides back to within this of the road center

# Hitting traffic
const BUMP_GAP := 50.0  # world units a bump leaves between you and the car you hit
const CAR_LENGTH := 400.0  # world units along the road a car counts as beside you
const ONCOMING_REACH := 3  # segments either side of the nose searched for oncoming traffic each tick

# Race clock
## Seconds left when time runs low, the one threshold for all of it: the HUD's clock beats
## red (Hud.timer_pulse), the audio ticks, and mystery hubcaps lean to clocks a little before
## (PowerUps.LOW_TIME).
const LOW_TIME := 10.0
