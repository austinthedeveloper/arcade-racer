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


func _init(car: Dictionary = Cars.find("car_vega"), ai: AIDriver = AIDriver.new()) -> void:
	car_id = car["id"]
	driver = ai
	setup(car)
	base_top = top_speed
