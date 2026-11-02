class_name Launch
extends RefCounted
## The launch at GO: gas pressed in a window around GO gives a short burst of acceleration;
## holding it down well before GO bogs the car down for a moment.

enum Grade { PENDING, LAUNCH, BOG, NONE }

const GAS_DOWN := 0.9  # throttle that counts as pressed


## How a start went, `now` seconds after GO (negative before), with the gas down since
## `pressed_at` (seconds from GO; NAN if it isn't down).
static func grade(pressed_at: float, now: float) -> Grade:
	if not is_nan(pressed_at):
		if pressed_at < -Tuning.v("launch/window_before"):
			return Grade.BOG
		if pressed_at <= Tuning.v("launch/window_after"):
			return Grade.LAUNCH
		return Grade.NONE
	return Grade.NONE if now > Tuning.v("launch/window_after") else Grade.PENDING


## Starts the launch boost or the bog on `car`.
static func apply(car: PlayerCar, g: Grade) -> void:
	if g == Grade.LAUNCH:
		car.launch_time = Tuning.v("launch/boost_time")
	elif g == Grade.BOG:
		car.bog_time = Tuning.v("launch/bog_time")


## A rival's start, from its driver's dice: mostly good, sometimes slow, now and then bogged.
static func rival_grade(rng: RandomNumberGenerator) -> Grade:
	var roll := rng.randf()
	if roll < 0.6:
		return Grade.LAUNCH
	return Grade.NONE if roll < 0.85 else Grade.BOG
