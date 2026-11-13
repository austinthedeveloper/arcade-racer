## The casual player stand-in for the balance report (CasualDriver): late steering on the
## keys, no launch, no nitro, no brake.
extends TestSuite


func _auto(steer: float) -> DriveInput:
	var inp := DriveInput.new()
	inp.steer = steer
	inp.throttle = 1.0
	inp.brake = 1.0
	inp.nitro_pressed = true
	return inp


func test_the_keys_are_full_lock_or_none() -> void:
	eq(CasualDriver.keys(0.1), 0.0, "a small correction: no key")
	eq(CasualDriver.keys(0.6), 1.0, "right")
	eq(CasualDriver.keys(-0.4), -1.0, "left")


func test_the_steering_comes_late() -> void:
	var c := CasualDriver.new()
	var late := roundi(CasualDriver.LAG / DT)
	var got: Array[float] = []
	for i in late + 5:
		got.append(c.next(_auto(1.0 if i >= 2 else 0.0), DT, true).steer)
	eq(got[late + 1], 0.0, "not yet, LAG after the autodrive turned")
	eq(got[late + 2], 1.0, "then it does")


func test_no_brake_no_nitro_and_late_off_the_line() -> void:
	var c := CasualDriver.new()
	var inp := c.next(_auto(0.0), DT, false)
	eq(inp.throttle, 0.0, "no gas in the countdown")
	inp = c.next(_auto(0.0), DT, true)
	eq(inp.throttle, 0.0, "nor right at GO: no launch")
	for i in roundi(CasualDriver.LAG / DT):
		inp = c.next(_auto(0.0), DT, true)
	eq(inp.throttle, 1.0, "then held down")
	eq(inp.brake, 0.0, "never brakes")
	check(not inp.nitro_pressed, "never fires nitro")


func test_a_casual_race_finishes() -> void:
	var r := race(true, false, 0, true)
	r.casual = true
	var ticks := run_until(r, func() -> bool: return r.state == r.State.FINISHED or r.state == r.State.TIME_UP, 60 * 240)
	check(ticks > 0, "the race ends")
	check(r.state == r.State.FINISHED, "a casual player finishes Palm Coast on the clear road")
