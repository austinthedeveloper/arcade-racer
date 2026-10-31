class_name Launch
extends RefCounted
## The launch at GO: gas pressed in a window around GO gives a short burst of acceleration;
## holding it down well before GO bogs the car down for a moment.

enum Grade { PENDING, LAUNCH, BOG, NONE }

const WINDOW_BEFORE := 0.3  # seconds before GO the gas may go down for a launch...
const WINDOW_AFTER := 0.15  # ...and after
const BOOST_TIME := 1.0  # seconds of launch acceleration
const BOOST_ACCEL := 1.7
const BOG_TIME := 0.7
const BOG_ACCEL := 0.35
const ROLL_TIME := 1.5  # the last seconds of the countdown the field rolls forward...
const ROLL_SPEED := 300.0  # ...at this speed
const GAS_DOWN := 0.9  # throttle that counts as pressed


## How a start went, `now` seconds after GO (negative before), with the gas down since
## `pressed_at` (seconds from GO; NAN if it isn't down).
static func grade(pressed_at: float, now: float) -> Grade:
	if not is_nan(pressed_at):
		if pressed_at < -WINDOW_BEFORE:
			return Grade.BOG
		if pressed_at <= WINDOW_AFTER:
			return Grade.LAUNCH
		return Grade.NONE
	return Grade.NONE if now > WINDOW_AFTER else Grade.PENDING


## Starts the launch boost or the bog on `car`.
static func apply(car: PlayerCar, g: Grade) -> void:
	if g == Grade.LAUNCH:
		car.launch_time = BOOST_TIME
	elif g == Grade.BOG:
		car.bog_time = BOG_TIME


## A rival's start, from its driver's dice: mostly good, sometimes slow, now and then bogged.
static func rival_grade(rng: RandomNumberGenerator) -> Grade:
	var roll := rng.randf()
	if roll < 0.6:
		return Grade.LAUNCH
	return Grade.NONE if roll < 0.85 else Grade.BOG
