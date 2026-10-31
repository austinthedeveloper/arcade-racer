## The arcade driving model (PlayerCar) on test tracks.
extends TestSuite


func _car(speed: float = 0.0) -> PlayerCar:
	var p := PlayerCar.new()
	p.reset()
	p.speed = speed
	return p


func _drive(p: PlayerCar, track: Track, seconds: float, inp: DriveInput, controls := true) -> void:
	for i in roundi(seconds / DT):
		p.update(DT, inp, track, controls)


func test_full_throttle_accelerates_to_top_speed() -> void:
	var t := flat_track(3000)
	var p := _car()
	_drive(p, t, 3.2, input(1.0))
	check(p.speed > Cfg.MAX_SPEED * 0.6, "past 60%% of top speed in 3.2 s (%.0f)" % p.speed)
	_drive(p, t, 10.0, input(1.0))
	check(p.speed > Cfg.MAX_SPEED * 0.97, "near top speed (%.0f)" % p.speed)
	check(p.speed <= Cfg.MAX_SPEED + 0.01, "never past top speed without nitro")


func test_no_controls_during_countdown() -> void:
	var t := flat_track()
	var p := _car()
	_drive(p, t, 1.0, input(1.0, 1.0), false)
	eq(p.speed, 0.0, "speed")
	eq(p.x, 0.0, "x")


func test_brake_stops_faster_than_coasting() -> void:
	var t := flat_track(3000)
	var braked := _car(Cfg.MAX_SPEED)
	var coasted := _car(Cfg.MAX_SPEED)
	_drive(braked, t, 1.0, input(0.0, 0.0, 1.0))
	_drive(coasted, t, 1.0, input())
	check(braked.speed < coasted.speed, "braking slows more than coasting")
	check(braked.braking, "brake lights on")
	_drive(braked, t, 1.0, input(0.0, 0.0, 1.0))
	eq(braked.speed, 0.0, "stopped within 2 s")


func test_offroad_caps_speed() -> void:
	var t := flat_track(3000)
	var p := _car(Cfg.MAX_SPEED)
	p.x = 1.6
	_drive(p, t, 1.0, input(1.0))
	check(p.offroad, "off the road")
	check(p.speed < Cfg.MAX_SPEED * 0.8, "slowing hard (%.0f)" % p.speed)
	_drive(p, t, 3.0, input(1.0))
	# Within one tick of throttle above the limit
	check(p.speed <= Cfg.OFFROAD_LIMIT + Cfg.ACCEL * DT * 1.3, "held to the off-road limit (%.0f)" % p.speed)


func test_steering_needs_speed() -> void:
	var t := flat_track()
	var parked := _car()
	parked.update(DT, input(0.0, 1.0), t, true)
	eq(parked.x, 0.0, "no steering when stopped")
	var moving := _car(Cfg.MAX_SPEED * 0.5)
	_drive(moving, t, 0.5, input(0.0, 1.0))
	check(moving.x > 0.0, "steers right")
	var left := _car(Cfg.MAX_SPEED * 0.5)
	_drive(left, t, 0.5, input(0.0, -1.0))
	check(left.x < 0.0, "steers left")


func test_curves_pull_outward() -> void:
	var t := Track.new()
	for i in 600:
		t.add_segment(4.0, 0.0)
	t.finish_building(590)
	var p := _car(Cfg.MAX_SPEED)
	_drive(p, t, 1.0, input(1.0))
	check(p.x < 0.0, "a right-hand curve pushes the car left (%.3f)" % p.x)


func test_nitro_uses_one_charge_and_boosts() -> void:
	var t := flat_track(5000)
	var p := _car(Cfg.MAX_SPEED)
	var go := input(1.0)
	go.nitro_pressed = true
	p.update(DT, go, t, true)
	eq(p.nitro_charges, Cfg.NITRO_CHARGES - 1, "one charge used")
	p.update(DT, go, t, true)
	eq(p.nitro_charges, Cfg.NITRO_CHARGES - 1, "pressing again while boosting is ignored")
	_drive(p, t, 2.0, input(1.0))
	check(p.speed > Cfg.MAX_SPEED * 1.05, "faster than top speed on nitro (%.0f)" % p.speed)
	_drive(p, t, 4.0, input(1.0))
	eq(p.nitro_time, 0.0, "boost ends")
	check(p.speed <= Cfg.MAX_SPEED * 1.01, "back to top speed")


func test_nitro_runs_out() -> void:
	var t := flat_track(5000)
	var p := _car(Cfg.MAX_SPEED)
	for i in Cfg.NITRO_CHARGES + 1:
		var go := input(1.0)
		go.nitro_pressed = true
		p.update(DT, go, t, true)
		_drive(p, t, Cfg.NITRO_DURATION + 0.1, input(1.0))
	eq(p.nitro_charges, 0, "all used")
	eq(p.nitro_time, 0.0, "no boost without charges")


func test_sharp_crest_launches_a_fast_car() -> void:
	var t := Track.new()
	t.straight(20)
	t.jump()
	t.straight(100)
	t.finish_building(t.segments.size() - 10)
	var p := _car(Cfg.MAX_SPEED)
	var flew := false
	var landed := false
	for i in 600:
		p.update(DT, input(1.0), t, true)
		flew = flew or p.airborne
		landed = landed or (flew and p.landed)
	check(flew, "took off")
	check(landed, "landed again")
	check(not p.airborne, "on the ground at the end")


func test_slow_car_does_not_jump() -> void:
	var t := Track.new()
	t.straight(20)
	t.jump()
	t.straight(100)
	t.finish_building(t.segments.size() - 10)
	var p := _car()
	var flew := false
	for i in 900:
		p.speed = Cfg.MAX_SPEED * 0.35  # cruise control
		p.update(DT, input(), t, true)
		flew = flew or p.airborne
	check(p.distance > t.segments[100].w1.z, "drove past the crest")
	check(not flew, "stays on the road")


func _traffic_car(t: Track, p: PlayerCar, offset: float, speed: float) -> Traffic.TrafficCar:
	var c := Traffic.TrafficCar.new()
	c.z = p.position + Cfg.PLAYER_Z + 10.0
	c.offset = offset
	c.speed = speed
	c.segment = t.find_segment(c.z)
	c.segment.cars.append(c)
	return c


func test_fast_hit_on_traffic_crashes() -> void:
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED)
	_traffic_car(t, p, 0.0, Cfg.MAX_SPEED * 0.3)
	p.collide(t)
	check(p.crashed and p.crash_time > 0.0, "crashed")
	p.update(DT, input(1.0), t, true)
	check(p.speed < Cfg.MAX_SPEED, "slows down while crashing")


func test_slow_hit_on_traffic_bumps() -> void:
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED * 0.6)
	p.position = 2000.0
	var c := _traffic_car(t, p, 0.0, Cfg.MAX_SPEED * 0.3)
	p.collide(t)
	check(not p.crashed, "no crash")
	check(p.speed <= c.speed, "slowed to the car's pace or below")
	check(p.position + Cfg.PLAYER_Z < c.z, "pushed back behind it")


func test_a_bump_moves_distance_with_position() -> void:
	# Regression: the bump moved `position` but not `distance`, so checkpoints and the finish
	# (which read `distance`) drifted from where their gates are drawn.
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED * 0.6)
	p.reset(2000.0)
	p.speed = Cfg.MAX_SPEED * 0.6
	p.distance = 2000.0
	_traffic_car(t, p, 0.0, Cfg.MAX_SPEED * 0.3)
	p.collide(t)
	check(p.bumped, "bumped")
	near(p.distance, p.position, 0.001, "distance moved back with the car")


func test_a_bump_across_the_start_line_keeps_distance_continuous() -> void:
	var t := flat_track()
	var p := _car()
	p.position = 10.0
	p.distance = 5000.0
	p.move_to(-40.0, t)
	near(p.position, t.length - 40.0, 0.001, "wrapped to the end of the lap")
	near(p.distance, 4950.0, 0.001, "50 back, not a lap forward")


func test_traffic_in_a_skipped_segment_is_hit() -> void:
	# Regression: at nitro speed the car skipped whole segments and drove through the traffic
	# in them.
	var t := flat_track()
	var p := _car()
	p.reset(50 * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z + 190.0)
	p.speed = Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT
	p.nitro_time = 1.0
	var c := Traffic.TrafficCar.new()
	c.z = 51 * Cfg.SEGMENT_LENGTH + 100.0
	c.speed = Cfg.MAX_SPEED * 0.3
	c.segment = t.find_segment(c.z)
	c.segment.cars.append(c)
	p.update(DT, input(0.0), t, true)
	check(t.find_segment(p.position + Cfg.PLAYER_Z).index == 52, "the tick ends a segment past the car")
	p.collide(t)
	check(p.crashed, "crashed into it anyway")


func test_a_teleport_only_checks_where_the_car_lands() -> void:
	var t := flat_track()
	var p := _car()
	p.position = 4000.0
	var segs := p.passed_segments(t)
	eq(segs.size(), 1, "one segment")
	eq(segs[0].index, t.find_segment(4000.0 + Cfg.PLAYER_Z).index, "the one under the car")


func test_traffic_in_another_lane_is_missed() -> void:
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED)
	p.x = -0.75
	_traffic_car(t, p, 0.75, Cfg.MAX_SPEED * 0.3)
	p.collide(t)
	check(not p.crashed, "no crash")
	eq(p.speed, Cfg.MAX_SPEED, "speed kept")


func test_roadside_sprite_crash_only_off_road() -> void:
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED * 0.5)
	var seg := t.find_segment(p.position + Cfg.PLAYER_Z)
	var def: Dictionary = SpriteLibrary.defs["palm_tall_a"]
	var w_units: float = def["world_w"] / Cfg.ROAD_WIDTH
	seg.sprites.append({"id": "palm_tall_a", "offset": -1.3, "flip": true})
	p.x = 0.0
	p.offroad = false
	p.collide(t)
	check(not p.crashed, "on the road: no crash")
	p.x = -1.3 - w_units / 2.0
	p.offroad = true
	p.collide(t)
	check(p.crashed, "hit the palm")


func test_tumbleweeds_never_crash_the_car() -> void:
	var t := flat_track()
	var p := _car(Cfg.MAX_SPEED)
	var seg := t.find_segment(p.position + Cfg.PLAYER_Z)
	var def: Dictionary = SpriteLibrary.defs["tumbleweed_a"]
	var w_units: float = def["world_w"] / Cfg.ROAD_WIDTH
	seg.sprites.append({"id": "tumbleweed_a", "offset": 1.1, "flip": false})
	p.x = 1.1 + w_units / 2.0
	p.offroad = true
	p.collide(t)
	check(not p.crashed, "drove straight through the tumbleweed")


func test_pitch_for_slope() -> void:
	eq(PlayerCar.pitch_for_slope(0.0), 0.0, "flat")
	check(PlayerCar.pitch_for_slope(-0.3) > 0.0, "downhill is nose-down (positive)")
	check(PlayerCar.pitch_for_slope(0.3) < 0.0, "uphill is nose-up (negative)")
	eq(PlayerCar.pitch_for_slope(-2.0), 1.0, "clamped nose-down")
	eq(PlayerCar.pitch_for_slope(2.0), -1.0, "clamped nose-up")


## A track that climbs at a steady `slope` (rise over run) after a flat run-up.
func _ramp_track(slope: float) -> Track:
	var t := Track.new()
	for i in 600:
		t.add_segment(0.0, 0.0 if i < 20 else t.last_y() + slope * Cfg.SEGMENT_LENGTH)
	t.finish_building(590)
	return t


func test_pitch_follows_the_road() -> void:
	var p := _car(Cfg.MAX_SPEED * 0.3)
	_drive(p, flat_track(), 1.0, input(0.3))
	check(absf(p.pitch) < 0.01, "level on a flat road (%.2f)" % p.pitch)
	p = _car(Cfg.MAX_SPEED * 0.3)
	_drive(p, _ramp_track(0.4), 2.0, input(0.3))
	check(p.pitch < -0.5, "nose-up climbing (%.2f)" % p.pitch)
	p = _car(Cfg.MAX_SPEED * 0.3)
	_drive(p, _ramp_track(-0.4), 2.0, input(0.3))
	check(p.pitch > 0.5, "nose-down descending (%.2f)" % p.pitch)
	eq(p.airborne, false, "a steady descent keeps the wheels down")


func test_every_car_has_its_sprites_and_picture() -> void:
	eq(Cars.count(), 12, "the garage")
	for i in Cars.count():
		var car := Cars.get_car(i)
		check(ResourceLoader.exists(Cars.picture(car)), car["name"] + " showroom picture")
		check(CarSprites.strips(car["strip"]).has(0), car["name"] + " steering strip")
	eq(Cars.find("car_nope")["id"], "car_vega", "unknown ids fall back to the Vega")


func test_vega_drives_on_the_base_tuning() -> void:
	var t := Cars.tuning(Cars.find("car_vega"))
	for k in ["top", "accel", "steer", "pull", "offroad", "nitro_time"]:
		eq(t[k], 1.0, "Vega " + k)
	eq(t["nitros"], Cfg.NITRO_CHARGES, "Vega nitros")


func test_car_stats_change_how_it_drives() -> void:
	var zenith := Cars.tuning(Cars.find("car_zenith"))
	var skipper := Cars.tuning(Cars.find("car_skipper"))
	var kestrel := Cars.tuning(Cars.find("car_kestrel"))
	var bruiser := Cars.tuning(Cars.find("car_bruiser"))
	check(skipper["top"] < zenith["top"], "the buggy tops out lower")
	check(skipper["accel"] > Cars.tuning(Cars.find("car_vega"))["accel"], "but it launches harder")
	check(kestrel["steer"] > bruiser["steer"] and kestrel["pull"] < bruiser["pull"], "the rally hatch out-turns the muscle car")
	eq(Cars.tuning(Cars.find("car_mesa"))["offroad"], 0.0, "Mesa ignores the dirt")
	eq(Cars.tuning(Cars.find("car_halo"))["nitros"], 4, "Halo has four nitros")


func _top_speed_on_a_straight(car_id: String) -> float:
	var t := Track.new()
	for i in 3000:
		t.add_segment(0.0, 0.0)
	t.finish_building(2990)
	var p := PlayerCar.new()
	p.setup(Cars.find(car_id))
	p.reset()
	var inp := DriveInput.new()
	inp.throttle = 1.0
	_drive(p, t, 15.0, inp)
	return p.speed


func test_faster_cars_go_faster() -> void:
	var vega := _top_speed_on_a_straight("car_vega")
	var skipper := _top_speed_on_a_straight("car_skipper")
	check(vega > Cfg.MAX_SPEED * 0.97, "Vega reaches top speed (%.0f)" % vega)
	check(skipper < vega * 0.9, "Dune Skipper tops out lower (%.0f)" % skipper)


func test_mesa_keeps_its_speed_off_road() -> void:
	var t := Track.new()
	for i in 500:
		t.add_segment(0.0, 0.0)
	t.finish_building(490)
	for id in ["car_vega", "car_mesa"]:
		var p := PlayerCar.new()
		p.setup(Cars.find(id))
		p.reset()
		p.speed = Cfg.MAX_SPEED * 0.8
		p.x = 1.5
		var inp := DriveInput.new()
		inp.throttle = 1.0
		_drive(p, t, 1.0, inp)
		if id == "car_mesa":
			check(p.speed > Cfg.MAX_SPEED * 0.75, "Mesa keeps its speed on the dirt (%.0f)" % p.speed)
		else:
			check(p.speed < Cfg.MAX_SPEED * 0.5, "Vega slows on the dirt (%.0f)" % p.speed)
