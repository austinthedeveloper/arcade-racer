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
	# Was 3 before the erratic drivers (RC-4), who swerve into traffic now and then. Keep it here.
	check(crashes <= 8, "rarely crash in double traffic (%d crashes in 40 s, 7 cars)" % crashes)


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


func test_standings_sort_by_distance_then_finishers_first() -> void:
	var t := flat_track()
	var p := _player()
	var f := _field(t, 3)
	p.distance = 5000.0
	f.cars[0].distance = 9000.0
	f.cars[1].distance = 4000.0
	f.cars[2].distance = 6000.0
	eq(f.place(p, -1.0), 3, "two rivals further on")
	f.cars[1].finished = true
	f.cars[1].finish_time = 80.0
	eq(f.standings(p, -1.0)[0], f.cars[1], "a finisher leads whoever is still racing")
	eq(f.place(p, 79.0), 1, "finished before the other finisher")
	eq(f.place(p, 81.0), 2, "finished after it")


func test_the_player_and_rivals_share_a_clock() -> void:
	# Review on #104: race_time skipped the GO tick that Rivals.clock counted, so a
	# same-tick photo finish always went to the player.
	var r := race(true, false, 0)
	run_until(r, func(): return r.state == r.State.RACING)
	near(r.race_time, r.rivals.clock, 0.0001, "on the GO tick")
	run_until(r, func(): return r.race_time > 3.0)
	near(r.race_time, r.rivals.clock, 0.0001, "three seconds in")


func test_ordinals() -> void:
	eq([Rivals.ordinal(1), Rivals.ordinal(2), Rivals.ordinal(3), Rivals.ordinal(4), Rivals.ordinal(8)],
		["1ST", "2ND", "3RD", "4TH", "8TH"], "ordinals")
	eq([Rivals.ordinal(11), Rivals.ordinal(12), Rivals.ordinal(21)], ["11TH", "12TH", "21ST"], "teens")


func test_overtaking_a_rival_moves_you_up() -> void:
	var r := race(true, false, 0)
	r.state = r.State.RACING
	r.countdown = 0.0
	for rv: RivalCar in r.rivals.cars:
		rv.base_top = Cfg.MAX_SPEED * 0.3  # a slow field to pass
	drive(r, 1)
	eq(r.place, Rivals.COUNT + 1, "last off the grid")
	var best: int = r.place
	var passes := 0
	for i in 60 * 20:
		drive(r, 1)
		if r.place < best:
			best = r.place
			passes += 1
	check(passes >= 3, "passed rivals one by one (%d passes)" % passes)
	eq(r.place, 1, "in the lead")


func test_progress_dots() -> void:
	var bar := Rect2(100, 10, 200, 8)
	eq(Hud.progress_x(bar, 0.0, 1000.0), 100.0, "start")
	eq(Hud.progress_x(bar, 500.0, 1000.0), 200.0, "halfway")
	eq(Hud.progress_x(bar, 2000.0, 1000.0), 300.0, "past the finish stays at the end")


func test_a_profile_per_car() -> void:
	var roster := RivalProfile.roster()
	eq(roster.size(), Cars.count(), "one driver per car")
	var styles := {}
	for prof in roster:
		check(Cars.find(prof.car_id)["id"] == prof.car_id, "%s drives a real car" % prof.driver)
		check(prof.pace > 0.85 and prof.pace <= 1.0, "%s pace" % prof.driver)
		styles[prof.style] = true
	eq(styles.size(), RivalProfile.Style.size(), "every style is on the roster")
	var f := _field(flat_track())
	for r in f.cars:
		check(r.profile != null and r.profile.car_id == r.car_id, "each rival has its profile")
		eq(r.driver.style, r.profile.style, "and drives in its style")


func test_the_band_never_exceeds_its_cap() -> void:
	near(Rivals.band(0.0, 0.05, 0.04), 1.0, 0.0001, "level with the player: no band")
	near(Rivals.band(Rivals.BAND_RANGE, 0.05, 0.04), 0.95, 0.0001, "well ahead: eases off in full")
	near(Rivals.band(-Rivals.BAND_RANGE, 0.05, 0.04), 1.04, 0.0001, "well behind: gains in full")
	near(Rivals.band(Rivals.BAND_RANGE * 0.5, 0.05, 0.04), 0.975, 0.0001, "half way: half")
	for gap in [-1e9, -Rivals.BAND_RANGE * 3.0, Rivals.BAND_RANGE * 3.0, 1e9]:
		for strength in [0.0, 0.05, 0.5, 10.0]:
			var b := Rivals.band(gap, strength, strength)
			check(b >= 1.0 - Rivals.BAND_MAX and b <= 1.0 + Rivals.BAND_MAX,
				"capped at %d%% (gap %.0f, strength %.2f: %.3f)" % [Rivals.BAND_MAX * 100, gap, strength, b])


func test_the_band_reaches_the_race() -> void:
	var t := flat_track(2000)
	var p := _player()
	var f := _field(t, 2)
	f.cars[0].distance = p.distance + Rivals.BAND_RANGE * 2.0
	f.cars[1].distance = p.distance - Rivals.BAND_RANGE * 2.0
	f.update(DT, t, p, true, 1e12)
	near(f.cars[0].top_speed, f.cars[0].base_top * (1.0 - Rivals.BAND_EASE), 0.01, "the leader eases off")
	near(f.cars[1].top_speed, f.cars[1].base_top * (1.0 + Rivals.BAND_BOOST), 0.01, "the straggler gains")


func test_an_aggressive_driver_blocks_a_faster_car_behind() -> void:
	var t := flat_track()
	var me := RivalCar.new(Cars.find("car_bruiser"), AIDriver.new(1, 0.0, RivalProfile.Style.AGGRESSIVE))
	me.reset(4000.0)
	me.speed = Cfg.MAX_SPEED * 0.7
	var chaser := _player()
	chaser.reset(4000.0 - 800.0)
	chaser.speed = Cfg.MAX_SPEED
	chaser.x = 0.75
	check(AIDriver.blocking_target(me, t, [me, chaser]) == chaser, "sees the car coming")
	me.driver.drive(me, t, [me, chaser], DT)
	near(me.driver.target, 0.75, 0.001, "moves across to block it")
	var clean := RivalCar.new(Cars.find("car_vega"), AIDriver.new(1, 0.0, RivalProfile.Style.CLEAN))
	clean.reset(4000.0)
	clean.speed = Cfg.MAX_SPEED * 0.7
	clean.driver.drive(clean, t, [clean, chaser], DT)
	near(clean.driver.target, 0.0, 0.001, "a clean driver keeps its line")
	chaser.speed = Cfg.MAX_SPEED * 0.5
	check(AIDriver.blocking_target(me, t, [me, chaser]) == null, "no need to block a slower car")


func test_an_erratic_driver_reacts_late() -> void:
	var t := flat_track()
	var me := RivalCar.new(Cars.find("car_sol"), AIDriver.new(1, 0.0, RivalProfile.Style.ERRATIC))
	me.reset(4000.0)
	me.speed = Cfg.MAX_SPEED * 0.9
	me.driver.drive(me, t, [me], DT)
	eq(me.driver.target, 0.0, "on its line")
	var car := Traffic.TrafficCar.new()
	car.z = me.position + Cfg.PLAYER_Z + 10 * Cfg.SEGMENT_LENGTH
	car.speed = Cfg.MAX_SPEED * 0.3
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	me.driver.drive(me, t, [me], DT)
	eq(me.driver.target, 0.0, "hasn't looked again yet")
	for i in roundi(AIDriver.ERRATIC_REACT / DT):
		me.driver.drive(me, t, [me], DT)
	check(absf(me.driver.target) > 0.3, "then dodges (to %.2f)" % me.driver.target)


func test_an_aggressive_driver_only_blocks_for_a_while() -> void:
	var t := flat_track()
	var me := RivalCar.new(Cars.find("car_bruiser"), AIDriver.new(1, 0.0, RivalProfile.Style.AGGRESSIVE))
	me.reset(4000.0)
	me.speed = Cfg.MAX_SPEED * 0.7
	var chaser := _player()
	chaser.reset(4000.0 - 800.0)
	chaser.speed = Cfg.MAX_SPEED
	chaser.x = 0.75
	var blocked := 0
	for i in roundi((AIDriver.BLOCK_TIME + 1.0) / DT):
		me.driver.drive(me, t, [me, chaser], DT)
		blocked += int(me.driver.target == 0.75)
	check(blocked <= roundi(AIDriver.BLOCK_TIME / DT) + 1, "blocks for BLOCK_TIME at most (%d ticks)" % blocked)
	near(me.driver.target, 0.0, 0.001, "then lets it by")


func test_a_bump_does_not_restart_the_block() -> void:
	# Review on #116: the contact a block causes slows the chaser below the blocker, which
	# used to zero the block clock, so the block started over once the chaser sped up.
	var t := flat_track()
	var me := RivalCar.new(Cars.find("car_bruiser"), AIDriver.new(1, 0.0, RivalProfile.Style.AGGRESSIVE))
	me.reset(4000.0)
	me.speed = Cfg.MAX_SPEED * 0.7
	var chaser := _player()
	chaser.reset(4000.0 - 800.0)
	chaser.x = 0.75
	var blocked := 0
	for i in roundi((AIDriver.BLOCK_TIME + 2.0) / DT):
		var t_s := i * DT
		# faster for 1 s, bumped under the blocker's speed for 0.3 s, then faster again
		chaser.speed = Cfg.MAX_SPEED * (0.6 if t_s >= 1.0 and t_s < 1.3 else 1.0)
		me.driver.drive(me, t, [me, chaser], DT)
		blocked += int(me.driver.target == 0.75)
	check(blocked <= roundi(AIDriver.BLOCK_TIME / DT) + 10, "about BLOCK_TIME of blocking in all (%d ticks)" % blocked)
	near(me.driver.target, 0.0, 0.001, "then lets it by")
