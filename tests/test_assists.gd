## Driving assists (Assists): steering toward the lane, braking into corners, their caps,
## and the two options that turn them on.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func _car(speed: float, x := 0.0) -> PlayerCar:
	var p := PlayerCar.new()
	p.reset()
	p.speed = speed
	p.x = x
	return p


## A straight, then a hard curve, then a straight again.
static func _corner_track() -> Track:
	var t := Track.new()
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_HARD)
	t.straight(Track.LENGTH_LONG)
	t.finish_building(t.segments.size() - 10)
	return t


func test_off_by_default_and_saved() -> void:
	_clean()
	eq([Settings.steer_assist, Settings.brake_assist], [false, false], "both off by default")
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.STEER_ASSIST)
	eq(o.page, OptionsScreen.Page.GAME, "on the Game page, with auto gas")
	o.change(OptionsScreen.Row.STEER_ASSIST, 1, true)
	o.change(OptionsScreen.Row.BRAKE_ASSIST, 1, true)
	eq([OptionsScreen.value_text(OptionsScreen.Row.STEER_ASSIST), OptionsScreen.value_text(OptionsScreen.Row.BRAKE_ASSIST)],
		["ON", "ON"], "shown")
	Settings.reset()
	Settings.load_settings()
	eq([Settings.steer_assist, Settings.brake_assist], [true, true], "saved and loaded back")
	o.free()
	_clean()


func test_off_leaves_the_input_alone() -> void:
	var t := _corner_track()
	var inp := input(1.0, 0.2)
	check(Assists.apply(inp, _car(Cfg.MAX_SPEED, 0.1), t, false, false) == inp, "the same input, untouched")


func test_assists_never_exceed_their_caps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tracks := [_corner_track(), Stages.build(0), Stages.build(2)]
	var cars := [Cars.get_car(0), Cars.get_car(Cars.LIST.size() - 1)]
	var worst_steer := 0.0
	var worst_brake := 0.0
	for i in 4000:
		var t: Track = tracks[i % tracks.size()]
		var p := PlayerCar.new()
		p.setup(cars[i % cars.size()])
		p.reset(rng.randf() * t.length)
		p.speed = rng.randf_range(0.0, Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT)
		p.x = rng.randf_range(-1.4, 1.4)
		var inp := input(rng.randf(), rng.randf_range(-1.0, 1.0), rng.randf() if rng.randf() < 0.3 else 0.0)
		inp.kind = DriveInput.Kind.GAMEPAD if i % 2 else DriveInput.Kind.KEYBOARD
		var out := Assists.apply(inp, p, t, true, true)
		worst_steer = maxf(worst_steer, absf(out.steer - inp.steer))
		if out.brake > inp.brake:
			worst_brake = maxf(worst_brake, out.brake)
		check(out.throttle <= inp.throttle + 0.0001, "never adds gas")
		check(out.brake >= inp.brake, "never takes the player's brake away")
		check(absf(out.steer) <= 1.0, "steering stays in range")
	check(worst_steer <= Assists.STEER_CAP + 0.0001, "steering assist within its cap (%.3f)" % worst_steer)
	check(worst_brake <= Assists.BRAKE_CAP + 0.0001, "braking assist within its cap (%.3f)" % worst_brake)
	check(worst_steer > Assists.STEER_CAP * 0.5, "and the steering assist does work (%.3f)" % worst_steer)
	check(worst_brake > Assists.BRAKE_CAP * 0.5, "and so does the braking (%.3f)" % worst_brake)


func test_steering_pulls_toward_the_lane_at_speed() -> void:
	var p := _car(Cfg.MAX_SPEED)
	eq(Assists.nearest_lane(0.1), 0.25, "nearest lane")
	check(Assists.steer_help(0.0, 0.1, 1.0, 0.0, p) > 0.0, "left of the lane: steers right")
	check(Assists.steer_help(0.0, -0.1, 1.0, 0.0, p) < 0.0, "right of -0.25: steers left")
	eq(Assists.steer_help(0.0, 0.25, 1.0, 0.0, p), 0.0, "on the lane: nothing")
	eq(Assists.steer_help(0.0, 0.1, 0.2, 0.0, p), 0.0, "slow: nothing")
	eq(Assists.steer_help(1.0, 0.1, 1.0, 0.0, p), 0.0, "full lock from the player: nothing")
	eq(Assists.steer_help(0.0, 1.3, 1.0, 0.0, p), 0.0, "off the road: nothing")
	check(Assists.steer_help(0.0, 0.25, 1.0, Track.CURVE_EASY, p) > 0.0, "leans into a right-hand curve")
	var wheel := input(1.0)
	wheel.kind = DriveInput.Kind.WHEEL
	var t := _corner_track()
	eq(Assists.apply(wheel, _car(Cfg.MAX_SPEED, 0.1), t, true, false).steer, 0.0, "a wheel steers for itself")


func test_steering_assist_keeps_the_car_in_its_lane() -> void:
	var t := Track.new()
	t.straight(Track.LENGTH_SHORT)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY)
	t.finish_building(t.segments.size() - 10)
	var helped := _car(Cfg.MAX_SPEED * 0.6, 0.25)
	var alone := _car(Cfg.MAX_SPEED * 0.6, 0.25)
	var worst_helped := 0.0
	var worst_alone := 0.0
	for i in 400:  # through the curve at a steady 60%
		helped.speed = Cfg.MAX_SPEED * 0.6
		alone.speed = Cfg.MAX_SPEED * 0.6
		helped.update(DT, Assists.apply(input(1.0), helped, t, true, false), t, true)
		alone.update(DT, input(1.0), t, true)
		worst_helped = maxf(worst_helped, absf(helped.x - 0.25))
		worst_alone = maxf(worst_alone, absf(alone.x - 0.25))
	check(worst_helped < worst_alone * 0.5, "drifts less through the corner (%.2f against %.2f)" % [worst_helped, worst_alone])


func test_corner_speed_follows_the_car_grip() -> void:
	var p := _car(0.0)
	eq(Assists.corner_speed(0.0, p), INF, "straight: no limit")
	eq(Assists.corner_speed(Track.CURVE_EASY, p), INF, "easy curve: flat out")
	var medium := Assists.corner_speed(Track.CURVE_MEDIUM, p)
	var hard := Assists.corner_speed(-Track.CURVE_HARD, p)
	check(hard < medium and medium < Cfg.MAX_SPEED, "harder is slower (%.0f, %.0f)" % [hard, medium])
	var grippy := _car(0.0)
	grippy.steer_mult = 1.3
	check(Assists.corner_speed(Track.CURVE_HARD, grippy) > hard, "a car that steers better corners faster")
	eq(Assists.brake_help(hard - 1.0, hard), 0.0, "under the corner speed: no brake")
	eq(Assists.brake_help(Cfg.MAX_SPEED, hard), Assists.BRAKE_CAP, "far over: the cap")
	eq(Assists.brake_help(Cfg.MAX_SPEED, INF), 0.0, "no corner: no brake")


func test_braking_assist_slows_for_a_hard_corner() -> void:
	var t := _corner_track()
	var helped := _car(Cfg.MAX_SPEED)
	var alone := _car(Cfg.MAX_SPEED)
	var corner_start := Track.LENGTH_LONG * 3 + Track.LENGTH_MEDIUM  # the hard curve's hold
	var helped_at := -1.0
	var alone_at := -1.0
	var braked := false
	for i in 900:
		var inp := Assists.apply(input(1.0), helped, t, false, true)
		braked = braked or inp.brake > 0.0
		helped.update(DT, inp, t, true)
		alone.update(DT, input(1.0), t, true)
		if helped_at < 0.0 and t.find_segment(helped.position + Cfg.PLAYER_Z).index >= corner_start:
			helped_at = helped.speed
		if alone_at < 0.0 and t.find_segment(alone.position + Cfg.PLAYER_Z).index >= corner_start:
			alone_at = alone.speed
	check(braked, "it braked")
	check(helped_at > 0.0 and alone_at > 0.0, "both reached the corner")
	var limit := Assists.corner_speed(Track.CURVE_HARD, helped)
	check(helped_at < alone_at, "slower into the corner (%.0f against %.0f)" % [helped_at, alone_at])
	check(helped_at <= limit + Cfg.MAX_SPEED * 0.05, "at about the corner speed (%.0f, limit %.0f)" % [helped_at, limit])


func test_race_uses_the_assists_only_when_on() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 400, input(1.0))
	var x_off: float = r.player.x
	_clean()
	Settings.steer_assist = true
	Settings.brake_assist = true
	var r2 := race(false, false)
	drive(r2, 400, input(1.0))
	check(r2.player.speed > 0.0, "races with the assists on")
	check(absf(r2.player.x - Assists.nearest_lane(r2.player.x)) <= absf(x_off - Assists.nearest_lane(x_off)) + 0.01,
		"and keeps nearer a lane (%.2f against %.2f)" % [r2.player.x, x_off])
	_clean()
