## Gamepad rumble (WH-13): which car events rumble, how hard and how long at each level of
## the rumble option, and that the race sends nothing at 0, on the keyboard or in a demo.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func _car(speed := Cfg.MAX_SPEED) -> PlayerCar:
	var p := PlayerCar.new()
	p.reset()
	p.speed = speed
	return p


func test_events_from_the_car() -> void:
	var p := _car()
	eq(Rumble.events(p, 0.0), PackedStringArray(), "driving clean: nothing")
	p.crashed = true
	p.hit_traffic = true
	p.crash_time = 1.0
	eq(Rumble.events(p, 0.0), PackedStringArray(["crash"]), "a crash (not a bump too)")
	p = _car()
	p.bumped = true
	eq(Rumble.events(p, 0.0), PackedStringArray(["bump"]), "a bump")
	p = _car()
	p.hit_traffic = true
	eq(Rumble.events(p, 0.0), PackedStringArray(["bump"]), "a side swipe")
	p = _car()
	p.landed = true
	p.nitro_time = 3.0
	eq(Rumble.events(p, 0.0), PackedStringArray(["landing", "nitro"]), "a landing, nitro lit")
	eq(Rumble.events(p, 3.5), PackedStringArray(["landing"]), "nitro already burning: no new kick")
	p = _car()
	p.offroad = true
	eq(Rumble.events(p, 0.0), PackedStringArray(["offroad"]), "off the road")
	p.airborne = true
	eq(Rumble.events(p, 0.0), PackedStringArray(), "not in the air")
	p = _car(0.0)
	p.offroad = true
	eq(Rumble.events(p, 0.0), PackedStringArray(), "nor standing still")


func test_strength_and_length() -> void:
	for e: String in Rumble.EVENTS:
		var c := Rumble.command(e, Settings.EFFECT_STEPS)
		var d: Array = Rumble.EVENTS[e]
		eq(c, Vector3(d[0], d[1], d[2]), "%s at 10: as designed" % e)
		check(c.x <= 1.0 and c.y <= 1.0 and c.z > 0.0 and c.z <= 1.0, "%s: motors 0..1, under a second" % e)
		eq(Rumble.command(e, 0), Vector3.ZERO, "%s at 0: nothing" % e)
		var half := Rumble.command(e, 5)
		near(half.x, d[0] * 0.5, 0.0001, "%s at 5: half" % e)
		near(half.z, d[2], 0.0001, "as long")
	check(Rumble.command("crash", 10).y > Rumble.command("bump", 10).y, "a crash hits harder than a bump")
	near(Rumble.command("offroad", 10, 0.5).x, Rumble.EVENTS["offroad"][0] * 0.5, 0.0001, "off the road slower: gentler")
	eq(Rumble.command("nope", 10), Vector3.ZERO, "unknown: nothing")
	eq(Rumble.command("crash", 25), Rumble.command("crash", 10), "never more than designed")


func test_tick_sends_once_and_keeps_the_stronger() -> void:
	var r := Rumble.new()
	var p := _car()
	p.crashed = true
	p.crash_time = 1.0
	eq(r.tick(DT, p, 10), Rumble.command("crash", 10), "the crash")
	p.crashed = false
	p.bumped = true
	eq(r.tick(DT, p, 10), Vector3.ZERO, "a bump doesn't cut the crash short")
	for i in 30:
		r.tick(DT, _car(), 10)
	p = _car()
	p.bumped = true
	eq(r.tick(DT, p, 10), Rumble.command("bump", 10), "after it: the bump")
	var q := _car()
	q.offroad = true
	var sent := 0
	for i in 60:
		if r.tick(DT, q, 10) != Vector3.ZERO:
			sent += 1
	check(sent >= 8 and sent <= 11, "off the road: renewed every %.1f s (%d in a second)" % [Rumble.OFFROAD_EVERY, sent])
	eq(Rumble.send(-1, Rumble.command("crash", 10)), false, "nothing to the keyboard")
	eq(Rumble.send(0, Vector3.ZERO), false, "nor a ZERO command")


func test_slider_at_zero_sends_nothing() -> void:
	var r := Rumble.new()
	var p := _car()
	p.crashed = true
	p.landed = true
	p.offroad = true
	p.nitro_time = 3.0
	eq(r.tick(DT, p, 0), Vector3.ZERO, "every event at once, at 0: nothing")


## The gas down on `kind` of device.
static func _gas(kind: DriveInput.Kind) -> DriveInput:
	var inp := input(1.0)
	inp.kind = kind
	return inp


## A race off the road at speed on `kind` of device: how many rumbles it sent.
func _offroad_race(kind: DriveInput.Kind, demo := false) -> int:
	var r := race(false, false)
	r.demo = demo
	drive(r, 240, _gas(kind))
	for i in 60:
		r.player.x = 1.6
		drive(r, 1, _gas(kind))
	return r.rumble_sent


func test_the_race_rumbles_a_gamepad_at_its_level() -> void:
	_clean()
	check(_offroad_race(DriveInput.Kind.GAMEPAD) > 0, "a pad off the road: rumbles")
	eq(_offroad_race(DriveInput.Kind.KEYBOARD), 0, "the keyboard: nothing")
	eq(_offroad_race(DriveInput.Kind.WHEEL), 0, "a wheel: nothing")
	eq(_offroad_race(DriveInput.Kind.GAMEPAD, true), 0, "the attract demo: nothing")
	Settings.rumble = 0
	eq(_offroad_race(DriveInput.Kind.GAMEPAD), 0, "the slider at 0: nothing sent")
	_clean()
	var auto := race(true, false)
	drive(auto, 400, _gas(DriveInput.Kind.GAMEPAD))
	eq(auto.rumble_sent, 0, "an autodriven run: nothing")
	var p := race(false, false)
	var keep: DriveInput = InputRouter.state
	InputRouter.state = _gas(DriveInput.Kind.GAMEPAD)
	eq(p.rumble_level(), Settings.EFFECT_STEPS, "a pad: the option's level")
	p.pause()
	eq(p.rumble_level(), 0, "paused: off")
	InputRouter.state = keep
	_clean()


func test_rumble_option_on_the_controls_page() -> void:
	_clean()
	eq(Settings.rumble, Settings.EFFECT_STEPS, "as designed by default")
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.RUMBLE)
	eq(o.page, OptionsScreen.Page.CONTROLS, "on Controls")
	o.change(OptionsScreen.Row.RUMBLE, -1, false)
	eq(OptionsScreen.value_text(OptionsScreen.Row.RUMBLE), "9", "shown")
	for i in 12:
		o.change(OptionsScreen.Row.RUMBLE, -1, false)
	Settings.reset()
	Settings.load_settings()
	eq(Settings.rumble, 0, "down to 0, saved")
	o.free()
	_clean()
