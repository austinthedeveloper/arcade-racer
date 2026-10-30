class_name MenuInput
extends RefCounted
## Menu controls, whatever device produced them. Most menus only go left and right, so a
## wheel steers through them and its pedals confirm (gas) and go back (brake). The Options
## list also reads up and down (arrows, stick, D-pad); a wheel has none, so there the wheel
## picks the row and gas changes it (see OptionsScreen).

const PUSH := 0.5  # axis past this is a press
const RELEASE := 0.3  # and back under this lets go
const REPEAT_DELAY := 0.4  # seconds held before the first repeat
const REPEAT_RATE := 0.15  # seconds between repeats

var x := 0.0  # combined left/right axis, -1..1
var y := 0.0  # combined up/down axis, -1 up .. 1 down
var left_pressed := false  # edges (with auto-repeat while held)
var right_pressed := false
var up_pressed := false
var down_pressed := false
var confirm_pressed := false
var back_pressed := false

var _x_rep := [0, 0.0]  # held direction, seconds held
var _y_rep := [0, 0.0]


## Turns the axis into left/right presses: one on the push, then repeats while held.
func step_axis(axis: float, dt: float) -> void:
	x = axis
	var d := _repeat(axis, dt, _x_rep)
	left_pressed = d < 0
	right_pressed = d > 0


## The same for up/down.
func step_axis_y(axis: float, dt: float) -> void:
	y = axis
	var d := _repeat(axis, dt, _y_rep)
	up_pressed = d < 0
	down_pressed = d > 0


## -1, 0 or 1 for a left or right press this tick.
func step() -> int:
	return -1 if left_pressed else (1 if right_pressed else 0)


## -1, 0 or 1 for an up or down press this tick.
func step_y() -> int:
	return -1 if up_pressed else (1 if down_pressed else 0)


## The direction that fires this tick (0 for none), with hysteresis and auto-repeat.
static func _repeat(axis: float, dt: float, rep: Array) -> int:
	var dir: int = rep[0]
	if absf(axis) >= PUSH:
		dir = int(signf(axis))
	elif absf(axis) < RELEASE:
		dir = 0
	if dir != rep[0]:
		rep[0] = dir
		rep[1] = 0.0
		return dir
	if dir == 0:
		return 0
	rep[1] += dt
	if rep[1] >= REPEAT_DELAY:
		rep[1] -= REPEAT_RATE
		return dir
	return 0
