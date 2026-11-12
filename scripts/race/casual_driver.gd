class_name CasualDriver
extends RefCounted
## A stand-in for a casual player, for the balance report (tools/soak.sh --report
## --driver=casual) and --casual: the autodrive's own steering, but late (LAG seconds) and on
## a keyboard (full lock or none), the gas down a moment after GO and held (no launch), and no
## brake, no slides and no nitro. Easy should be winnable driving like this; the autodrive is
## what Normal and Hard are measured with.

const LAG := 0.35  # seconds the steering comes late by
const DEAD := 0.3  # steering the autodrive asks for under which the keys stay up

var _queue: Array[float] = []
var _racing_for := 0.0  # seconds since GO


## The casual player's controls this tick from the autodrive's `auto`, at `dt` seconds a tick;
## `racing` is false in the countdown (no gas until GO).
func next(auto: DriveInput, dt: float, racing: bool) -> DriveInput:
	_queue.append(auto.steer)
	var late := maxi(1, roundi(LAG / dt))
	var steer: float = _queue[0] if _queue.size() > late else 0.0
	while _queue.size() > late:
		_queue.pop_front()
	var inp := DriveInput.new()
	inp.steer = keys(steer)
	_racing_for = _racing_for + dt if racing else 0.0
	inp.throttle = 1.0 if _racing_for >= LAG else 0.0  # (late off the line: no launch)
	inp.shift_up_pressed = auto.shift_up_pressed
	inp.shift_down_pressed = auto.shift_down_pressed
	return inp


## Steering as the arrow keys give it: full lock either way, or none.
static func keys(steer: float) -> float:
	return 0.0 if absf(steer) < DEAD else signf(steer)
