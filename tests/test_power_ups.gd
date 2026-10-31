## Power-ups: where they go, what they give, and what they do to the car and traffic.
extends TestSuite


func _flat(n: int) -> Track:
	var t := Track.new()
	for i in n:
		t.add_segment(0.0, 0.0)
	t.finish_building(n - 10)
	return t


func test_every_stage_gets_its_pickups_in_lanes() -> void:
	for i in Stages.count():
		var t := Stages.build(i)
		var pu := PowerUps.new()
		pu.place(t)
		eq(pu.pickups.size(), PowerUps.SPOTS.size(), t.name + " pickups")
		for p in pu.pickups:
			check(Traffic.LANE_OFFSETS.has(p.offset), "%s pickup in a lane" % t.name)
			check(t.segments[p.segment].flags == 0, "%s pickup not on a gate" % t.name)
			check(t.segments[p.segment].pickups.has(p), "listed in its segment")


func test_layout_is_the_same_every_time() -> void:
	var t := PalmCoast.build()
	var a := PowerUps.layout(t, 11)
	var b := PowerUps.layout(t, 11)
	for k in a.size():
		eq([a[k].segment, a[k].offset, a[k].kind], [b[k].segment, b[k].offset, b[k].kind], "pickup %d" % k)


func test_weighted_pick() -> void:
	eq(PowerUps.pick([1.0, 1.0], 0.2), 0, "low roll, first")
	eq(PowerUps.pick([1.0, 1.0], 0.7), 1, "high roll, second")
	eq(PowerUps.pick([0.0, 1.0, 0.0], 0.5), 1, "zero weights never come up")
	for r in [0.0, 0.3, 0.6, 0.99]:
		check(PowerUps.mystery(r, 40.0) != PowerUps.Kind.MYSTERY, "a mystery never gives another mystery")


func test_mystery_favors_the_clock_when_time_runs_out() -> void:
	var clocks_plenty := 0
	var clocks_low := 0
	for i in 100:
		var r := (i + 0.5) / 100.0
		clocks_plenty += int(PowerUps.mystery(r, 40.0) == PowerUps.Kind.CLOCK)
		clocks_low += int(PowerUps.mystery(r, 5.0) == PowerUps.Kind.CLOCK)
	check(clocks_low > clocks_plenty * 2, "clocks: %d with time to spare, %d when low" % [clocks_plenty, clocks_low])


func test_driving_over_a_pickup_takes_it_once() -> void:
	var t := _flat(200)
	var pu := PowerUps.new()
	var p := PowerUps.Pickup.new()
	p.segment = 50
	p.offset = 0.25
	pu.pickups.append(p)
	t.segments[50].pickups.append(p)
	var here: Array[Segment] = [t.segments[50]]
	check(pu.take(here, -0.75) == null, "another lane misses it")
	check(pu.take(here, 0.3) == p, "driving over it takes it")
	check(pu.take(here, 0.3) == null, "only once")


func test_nitro_speed_takes_a_pickup_in_a_skipped_segment() -> void:
	# Regression: at nitro speed the car covers more than a segment a tick, and only the one it
	# landed in was checked, so a pickup in the segment it skipped over was missed.
	var t := _flat(200)
	var pu := PowerUps.new()
	var p := PowerUps.Pickup.new()
	p.segment = 51
	p.offset = 0.25
	t.segments[51].pickups.append(p)
	var car := PlayerCar.new()
	car.reset(50 * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z + 190.0)
	car.speed = Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT
	car.nitro_time = 1.0
	car.x = 0.25
	car.update(DT, DriveInput.new(), t, true)
	var segs := car.passed_segments(t)
	eq(segs.size(), 2, "one tick at nitro speed enters two segments")
	check(pu.take(segs, car.x) == p, "the pickup in the first one is taken")


func test_ghost_drives_through_traffic() -> void:
	var t := _flat(200)
	var p := PlayerCar.new()
	p.reset()
	p.speed = Cfg.MAX_SPEED
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var car := Traffic.TrafficCar.new()
	car.offset = 0.0
	car.speed = Cfg.MAX_SPEED * 0.3
	car.z = Cfg.PLAYER_Z + 10.0
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	p.ghost_time = PowerUps.GHOST_TIME
	p.collide(t)
	check(p.crash_time <= 0.0, "no crash as a ghost")
	p.ghost_time = 0.0
	p.collide(t)
	check(p.crash_time > 0.0, "the same hit crashes without it")


func test_ram_plate_knocks_traffic_flying() -> void:
	var t := _flat(200)
	var p := PlayerCar.new()
	p.reset()
	p.speed = Cfg.MAX_SPEED
	var tr := Traffic.new()
	var car := Traffic.TrafficCar.new()
	car.offset = 0.25
	car.speed = Cfg.MAX_SPEED * 0.3
	car.z = Cfg.PLAYER_Z + 10.0
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	tr.cars.append(car)
	p.ram_time = PowerUps.RAM_TIME
	p.collide(t)
	check(p.crash_time <= 0.0, "no crash with the ram plate")
	check(p.rammed, "rammed")
	check(car.flung > 0.0 and car.fling_dir > 0.0, "the car flies off to its side")
	eq(p.speed, Cfg.MAX_SPEED, "no speed lost")
	for i in 60:
		tr.update(DT, t)
	check(car.offset > 1.5 and car.flung == 0.0, "landed off the road (%.2f)" % car.offset)


func test_pickups_reach_the_race() -> void:
	var r := TestSuite.new_race(true, false, 0)
	check(not r.power_ups.pickups.is_empty(), "power-ups on by default")
	var p: PowerUps.Pickup = r.power_ups.pickups[0]
	p.kind = PowerUps.Kind.CLOCK
	r.state = r.State.RACING
	r.player.position = p.segment * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z + 5.0
	r.player.x = p.offset
	var before: float = r.time_left
	r._check_pickups()
	near(r.time_left, before + PowerUps.CLOCK_BONUS, 0.001, "clock adds time")
	eq(r.pickup, PowerUps.Kind.CLOCK, "HUD knows what was taken")
	r.player.nitro_charges = 0
	var q: PowerUps.Pickup = r.power_ups.pickups[1]
	q.kind = PowerUps.Kind.NITRO
	r.player.position = q.segment * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z + 5.0
	r.player.x = q.offset
	r._check_pickups()
	eq(r.player.nitro_charges, 1, "nitro can adds a charge")
	r.free()


func test_power_ups_option_turns_them_off() -> void:
	Settings.power_ups = false
	var r := TestSuite.new_race(true, false, 0)
	check(r.power_ups.pickups.is_empty(), "no pickups with the option off")
	r.free()
	Settings.power_ups = true


func test_hud_slot_icon() -> void:
	eq(Hud.slot_icon(0.0, 0.0, -1, -1, 99.0), "", "empty")
	eq(Hud.slot_icon(2.0, 0.0, PowerUps.Kind.RAM, PowerUps.Kind.RAM, 3.0), "icon_ram", "ram running")
	eq(Hud.slot_icon(0.0, 1.0, PowerUps.Kind.GHOST, PowerUps.Kind.GHOST, 3.0), "icon_ghost", "ghost running")
	eq(Hud.slot_icon(0.0, 0.0, PowerUps.Kind.MYSTERY, PowerUps.Kind.CLOCK, 0.1), "reveal_1", "mystery spins open")
	eq(Hud.slot_icon(0.0, 0.0, PowerUps.Kind.MYSTERY, PowerUps.Kind.CLOCK, 0.8), "icon_clock", "then shows what it gave")
	eq(Hud.slot_icon(0.0, 0.0, PowerUps.Kind.NITRO, PowerUps.Kind.NITRO, 2.0), "", "fades after a moment")
	for name in ["pickup_nitro", "pickup_mystery_3", "icon_slot", "fx_ram", "reveal_4"]:
		check(PowerUps.texture(name) != null, name + " sprite")
