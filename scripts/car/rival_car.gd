class_name RivalCar
extends PlayerCar
## A computer-driven racer: the player's driving model, steered by an AIDriver. Like the
## player, `position + Cfg.PLAYER_Z` is where the car is, and `distance` counts from the
## player's start, so the two compare directly.

var car_id := ""
var profile: RivalProfile
var base_top := 0.0  # top speed before the rubber band (Rivals.band)
var strips: Dictionary = {}  # CarSprites.strips for its car
var driver: AIDriver
var finished := false
var finish_time := 0.0  # race seconds when it crossed the line
## Another player in an online race (ON-3): moved by what its game sends (CarState), not
## driven here. `slot` is its place in the room.
var remote := false
var slot := -1
## How solid it's drawn: 1, or down to 0 as a player who dropped out fades off the road
## (ON-11). Under 1 it neither touches anyone nor is watched.
var fade := 1.0


## Another player's car in an online race, in slot `s` of the room.
static func remote_player(car: Dictionary, s: int) -> RivalCar:
	var r := RivalCar.new(car)
	r.remote = true
	r.slot = s
	# "P2": OnlineSession.player_name, not called here, as the test runner compiles this
	# script before the autoloads exist and OnlineSession needs them.
	r.profile = RivalProfile.make("P%d" % (s + 1), car["id"], RivalProfile.Style.CLEAN, 1.0, 0.0)
	r.strips = CarSprites.strips(car["strip"])
	return r


func _init(car: Dictionary = Cars.find("car_vega"), ai: AIDriver = AIDriver.new()) -> void:
	car_id = car["id"]
	driver = ai
	slides = false
	setup(car)
	base_top = top_speed
