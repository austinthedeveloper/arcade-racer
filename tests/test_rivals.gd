## AI rivals: the grid, the line they drive, avoiding slower cars, contact between racers and
## the seed (Rivals, RivalCar, AIDriver).
extends TestSuite


func _curved_track(curve: float) -> Track:
	var t := Track.new()
	for i in 600:
		t.add_segment(curve if i > 100 and i < 400 else 0.0, 0.0)
	t.finish_building(590)
	return t


func _player() -> PlayerCar:
	var p := PlayerCar.new()
	p.reset()
	return p


func _field(t: Track, count := Rivals.COUNT, seed_value := Rivals.SEED) -> Rivals:
	var f := Rivals.new()
	f.spawn(t, _player(), "car_vega", count, seed_value)
	return f


func test_grid_lines_up_ahead_of_the_player() -> void:
	var t := flat_track()
	var f := _field(t)
	eq(f.cars.size(), Rivals.COUNT, "seven rivals")
	var ids := {}
	for r in f.cars:
		check(r.car_id != "car_vega", "not the player's car")
		ids[r.car_id] = true
		check(r.distance > Cfg.CAR_LENGTH * 0.5, "%s starts ahead of the player" % r.car_id)
		near(r.distance, r.position, 0.001, "distance counts from the player's start")
		check(absf(r.x) == Rivals.GRID_X, "on a grid slot")
		check(not r.strips.is_empty(), "has its car's sprites")
		check(r.top_speed < Cars.find(r.car_id)["top_speed"] * 1e9, "tuned")
	eq(ids.size(), Rivals.COUNT, "seven different cars")


func test_the_same_seed_gives_the_same_field() -> void:
	var t := flat_track()
	var a := _field(t)
	var b := _field(t)
	var c := _field(t, Rivals.COUNT, Rivals.SEED + 1)
	var differs := false
	for i in Rivals.COUNT:
		eq([a.cars[i].car_id, a.cars[i].top_speed, a.cars[i].driver.lane_bias],
			[b.cars[i].car_id, b.cars[i].top_speed, b.cars[i].driver.lane_bias], "rival %d" % i)
		differs = differs or a.cars[i].car_id != c.cars[i].car_id or a.cars[i].top_speed != c.cars[i].top_speed
	check(differs, "another seed, another field")


func test_no_one_moves_in_the_countdown() -> void:
	var t := flat_track()
	var p := _player()
	var f := Rivals.new()
	f.spawn(t, p, "car_vega")
	var start := f.cars[0].position
	for i in 60:
		f.update(DT, t, p, false, 1e9)
	eq(f.cars[0].position, start, "still on the grid")
	eq(f.clock, 0.0, "the clock waits for GO")


func test_racing_line_takes_the_inside_of_a_bend() -> void:
	var right := _curved_track(Track.CURVE_HARD)
	var left := _curved_track(-Track.CURVE_HARD)
	var z := 90 * Cfg.SEGMENT_LENGTH
	check(AIDriver.racing_line(right, z) > 0.2, "right of center into a right-hand bend")
	check(AIDriver.racing_line(left, z) < -0.2, "left of center into a left-hand bend")
	eq(AIDriver.racing_line(right, 450 * Cfg.SEGMENT_LENGTH), 0.0, "center on a straight")
	check(absf(AIDriver.racing_line(right, z)) <= AIDriver.LINE_MAX, "never past LINE_MAX")


func test_a_rival_follows_the_line_through_a_bend() -> void:
	var t := _curved_track(Track.CURVE_MEDIUM)
	var r := RivalCar.new(Cars.find("car_vega"), AIDriver.new(1, 0.0))
	r.reset(60 * Cfg.SEGMENT_LENGTH)
	r.speed = r.top_speed * 0.8
	var worst := 0.0
	for i in 600:
		r.update(DT, r.driver.drive(r, t, [r], DT), t, true)
		var seg := t.find_segment(r.position + Cfg.PLAYER_Z).index
		if seg > 150 and seg < 380:
			worst = maxf(worst, absf(r.x - r.driver.target))
	check(worst < 0.35, "stays near its line through the bend (off by %.2f at worst)" % worst)
	check(absf(r.x) < 1.0, "on the road")
	eq(r.crash_time, 0.0, "no crash")


func test_open_lane_steers_round_slower_traffic() -> void:
	var t := flat_track()
	var r := RivalCar.new()
	r.reset(1000.0)
	r.speed = Cfg.MAX_SPEED * 0.9
	var car := Traffic.TrafficCar.new()
	car.z = r.position + Cfg.PLAYER_Z + 5 * Cfg.SEGMENT_LENGTH
	car.offset = 0.25
	car.speed = Cfg.MAX_SPEED * 0.3
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	var lane := AIDriver.open_lane(t, r.position + Cfg.PLAYER_Z, 0.25, r, [r])
	check(absf(lane["x"] - 0.25) > 0.4, "moves off the blocked lane (to %.2f)" % lane["x"])
	eq(lane["gap"], AIDriver.LOOKAHEAD, "to a clear one")
	eq(AIDriver.clear_for(t, r.position + Cfg.PLAYER_Z, 0.25, r, [r]), 5, "the car blocks 5 segments ahead")


func test_open_lane_sees_slower_racers() -> void:
	var t := flat_track()
	var me := RivalCar.new()
	me.reset(1000.0)
	me.speed = Cfg.MAX_SPEED * 0.9
	var other := RivalCar.new()
	other.reset(1000.0 + 3 * Cfg.SEGMENT_LENGTH)
	other.x = -0.25
	other.speed = Cfg.MAX_SPEED * 0.5
	eq(AIDriver.clear_for(t, me.position + Cfg.PLAYER_Z, -0.25, me, [me, other]), 3, "blocked by the slower racer")
	eq(AIDriver.clear_for(t, me.position + Cfg.PLAYER_Z, 0.75, me, [me, other]), AIDriver.LOOKAHEAD, "not in another lane")
	other.speed = Cfg.MAX_SPEED
	eq(AIDriver.clear_for(t, me.position + Cfg.PLAYER_Z, -0.25, me, [me, other]), AIDriver.LOOKAHEAD, "a faster racer isn't in the way")


func test_rivals_avoid_heavy_traffic() -> void:
	var t := PalmCoast.build()
	var tr := Traffic.new()
	tr.spawn(t, 140)
	var p := _player()
	var f := Rivals.new()
	f.spawn(t, p, "car_vega")
	var crashes := 0
	for i in 60 * 40:
		tr.update(DT, t)
		f.update(DT, t, p, true, 1e12)
		for r in f.cars:
			crashes += int(r.crashed)
	check(crashes <= 3, "rarely crash in double traffic (%d crashes in 40 s, 7 cars)" % crashes)


func test_nitro_only_on_straights() -> void:
	var t := _curved_track(Track.CURVE_HARD)
	check(not AIDriver.straight_ahead(t, 90 * Cfg.SEGMENT_LENGTH), "a bend ahead")
	check(AIDriver.straight_ahead(t, 420 * Cfg.SEGMENT_LENGTH), "straight ahead")
	var r := RivalCar.new(Cars.find("car_vega"), AIDriver.new(3))
	r.reset(90 * Cfg.SEGMENT_LENGTH)
	r.speed = r.top_speed
	for i in 600:
		check(not r.driver.drive(r, t, [r], DT).nitro_pressed, "no nitro into a bend")
		if i > 0:
			break
	r.reset(420 * Cfg.SEGMENT_LENGTH)
	r.speed = r.top_speed
	var fired := false
	for i in 600:
		fired = fired or r.driver.drive(r, t, [r], DT).nitro_pressed
	check(fired, "nitro on a long straight")


func test_running_into_a_racer_drops_in_behind_it() -> void:
	var t := flat_track()
	var front := RivalCar.new()
	front.reset(2000.0)
	front.speed = 5000.0
	var back := PlayerCar.new()
	back.reset(1500.0)
	back.speed = 9000.0
	back.position = 1900.0  # moved 400 this tick, into it
	Rivals.resolve_contacts([back, front], t)
	check(back.bumped and not back.crashed, "a bump, no crash")
	near(back.position, 2000.0 - Rivals.CONTACT_LENGTH, 0.001, "dropped in behind")
	near(back.speed, 5000.0 * Rivals.CONTACT_SLOWDOWN, 0.01, "at a little under its speed")
	eq(front.speed, 5000.0, "the car in front keeps its speed")


func test_racers_side_by_side_are_pushed_apart() -> void:
	var t := flat_track()
	var a := RivalCar.new()
	a.reset(2000.0)
	a.x = 0.1
	a.speed = 8000.0
	var b := RivalCar.new()
	b.reset(2050.0)
	b.x = -0.1
	b.speed = 8000.0
	Rivals.resolve_contacts([a, b], t)
	check(a.x > 0.1 and b.x < -0.1, "pushed apart")
	near(a.x - b.x, Cfg.CAR_WIDTH / Cfg.ROAD_WIDTH * Cfg.HIT_OVERLAP, 0.001, "just touching")
	near(a.position, 2000.0, 0.001, "no one moved along the road")


func test_a_ghosted_car_drives_through_racers() -> void:
	var t := flat_track()
	var front := RivalCar.new()
	front.reset(2000.0)
	front.speed = 5000.0
	var back := PlayerCar.new()
	back.reset(1500.0)
	back.speed = 9000.0
	back.position = 1900.0
	back.ghost_time = 2.0
	Rivals.resolve_contacts([back, front], t)
	check(not back.bumped and not front.bumped, "no contact")
	eq(back.position, 1900.0, "not dropped behind")
	eq(back.speed, 9000.0, "speed kept")


func test_the_race_runs_its_rivals() -> void:
	var r := race(true, false, 0)
	eq(r.rivals.cars.size(), Rivals.COUNT, "a full field")
	eq(r.road.rivals, r.rivals.cars, "drawn by the renderer")
	drive(r, 60 * 6)
	var moved := 0
	for rv: RivalCar in r.rivals.cars:
		moved += int(rv.speed > 0.0)
	eq(moved, Rivals.COUNT, "everyone pulled away after GO")
	var none := race(true, false, 0, false)
	check(none.rivals.cars.is_empty(), "a race can run without rivals")
