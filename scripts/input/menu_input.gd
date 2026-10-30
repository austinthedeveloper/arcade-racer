class_name MenuInput
extends RefCounted
## Menu controls, whatever device produced them. Menus only go left and right, so a wheel
## steers through them and its pedals confirm (gas) and go back (brake).

const PUSH := 0.5  # axis past this is a press
const RELEASE := 0.3  # and back under this lets go
const REPEAT_DELAY := 0.4  # seconds held before the first repeat
const REPEAT_RATE := 0.15  # seconds between repeats

var x := 0.0  # combined left/right axis, -1..1
var left_pressed := false  # edges (with auto-repeat while held)
var right_pressed := false
var confirm_pressed := false
var back_pressed := false

var _dir := 0
var _held := 0.0


## Turns the axis into left/right presses: one on the push, then repeats while held.
func step_axis(axis: float, dt: float) -> void:
	x = axis
	left_pressed = false
	right_pressed = false
	var dir := _dir
	if absf(axis) >= PUSH:
		dir = int(signf(axis))
	elif absf(axis) < RELEASE:
		dir = 0
	if dir != _dir:
		_dir = dir
		_held = 0.0
		_fire()
		return
	if _dir == 0:
		return
	_held += dt
	if _held >= REPEAT_DELAY:
		_held -= REPEAT_RATE
		_fire()


## -1, 0 or 1 for a left or right press this tick.
func step() -> int:
	return -1 if left_pressed else (1 if right_pressed else 0)


func _fire() -> void:
	left_pressed = _dir < 0
	right_pressed = _dir > 0
