class_name CameraView
extends RefCounted
## The race's camera views (WS-15), stepped through with the VIEW button and remembered in
## Options (Settings.camera_view): CHASE_NEAR (the view every earlier build had), CHASE_FAR
## (higher and further back, more of the road ahead) and BUMPER (low on the front of the car,
## the car itself not drawn). Display only: the car is where it always was (position +
## Cfg.PLAYER_Z) whichever view looks at it, so play, the golden traces and the rivals can't
## tell. Not an autoload, and reads no autoload (the renderer compiles before them in tests).

enum View { CHASE_NEAR, CHASE_FAR, BUMPER }

const NAMES := ["CHASE NEAR", "CHASE FAR", "BUMPER"]


## The next view along, round to the first after the last.
static func next(view: int) -> int:
	return (view + 1) % View.size()


static func name_of(view: int) -> String:
	return NAMES[clampi(view, 0, NAMES.size() - 1)]


## World units the camera rides above the road under the car.
static func height(view: int) -> float:
	match view:
		View.CHASE_FAR:
			return Tuning.v("camera/far_height")
		View.BUMPER:
			return Tuning.v("camera/bumper_height")
	return Tuning.v("camera/height")


## World units from the camera forward to the car (the car's z is position + Cfg.PLAYER_Z):
## Cfg.PLAYER_Z for the near chase view, as ever.
static func distance(view: int) -> float:
	match view:
		View.CHASE_FAR:
			return Tuning.v("camera/far_distance")
		View.BUMPER:
			return Tuning.v("camera/bumper_distance")
	return Cfg.PLAYER_Z


## Whether the player's car is drawn: not from its own bumper.
static func car_shown(view: int) -> bool:
	return view != View.BUMPER


## The camera's track position for a car at `position` (PlayerCar.position) on a track
## `length` long, wrapped onto the lap: `position` itself for the near chase view.
static func camera_z(view: int, position: float, length: float) -> float:
	var z := position + Cfg.PLAYER_Z - distance(view)
	return fposmod(z, length) if length > 0.0 else z


## The screen row of flat road `ahead` world units in front of the camera, for the camera
## `depth` (RoadRenderer.camera_depth): the classic projection, from the view's height.
static func road_row(view: int, ahead: float, depth: float) -> float:
	return Cfg.HORIZON_Y + depth / maxf(ahead, 1.0) * height(view) * Cfg.PROJ


## The player car's base (middle of its bottom edge) on screen in this view, `lift` world
## units in the air: on its road row.
static func car_base(view: int, depth: float, lift := 0.0) -> Vector2:
	var s := depth / distance(view)
	return Vector2(Cfg.SCREEN_W * 0.5, Cfg.HORIZON_Y + s * (height(view) - lift) * Cfg.PROJ)


## The player car's body width on screen in this view.
static func car_width(view: int, depth: float) -> float:
	return Cfg.CAR_WIDTH * depth / distance(view) * Cfg.PROJ


## Segments behind the player's whose cars are drawn over it (RoadRenderer.BEHIND_SEGMENTS
## from the near view, more as the camera falls further back), none from the bumper.
static func behind_segments(view: int, near: int) -> int:
	if not car_shown(view):
		return 0
	return near + maxi(0, ceili((distance(view) - Cfg.PLAYER_Z) / Cfg.SEGMENT_LENGTH))
