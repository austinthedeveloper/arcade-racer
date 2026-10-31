## The FX layer (FxLayer): what sets off each effect, the pool and its caps, and that it
## stays out of play. Triggers are plain functions; no drawing.
extends TestSuite


## A car at `pct` of top speed on the road, on the ground, nothing happening.
func _car(pct: float = 0.6) -> PlayerCar:
	var p := PlayerCar.new()
	p.speed = Cfg.MAX_SPEED * pct
	return p


func _has(p: PlayerCar, effect: String, last_speed: float = -1.0, last_nitro: float = 0.0) -> bool:
	return FxLayer.triggers(p, p.speed if last_speed < 0.0 else last_speed, last_nitro).has(effect)


func test_cruising_sets_nothing_off() -> void:
	eq(FxLayer.triggers(_car(), _car().speed, 0.0).size(), 0, "steady on the road")


func test_tire_smoke() -> void:
	var p := _car(0.7)
	p.braking = true
	check(_has(p, "smoke"), "braking hard at speed")
	p.speed = Cfg.MAX_SPEED * 0.2
	check(not _has(p, "smoke"), "not braking gently at low speed")
	p = _car(0.1)
	check(_has(p, "smoke", p.speed - 10.0), "wheelspin pulling away")
	check(not _has(p, "smoke", p.speed + 10.0), "not while slowing down")
	p = _car(0.9)
	p.steer = 1.0
	check(_has(p, "smoke"), "cornering on the limit")
	p.airborne = true
	check(not _has(p, "smoke"), "not in the air")
	p = _car(0.5)
	p.crash_time = 1.0
	check(_has(p, "smoke"), "a crash slide")


func test_kickup_off_the_road_only() -> void:
	var p := _car(0.3)
	p.x = 1.5
	p.offroad = true
	check(_has(p, "kickup"), "off the road")
	p.airborne = true
	check(not _has(p, "kickup"), "not in the air")
	p.airborne = false
	p.speed = 0.0
	check(not _has(p, "kickup"), "not standing still")
	p.offroad = false
	p.speed = Cfg.MAX_SPEED * 0.3
	check(not _has(p, "kickup"), "not on the asphalt")


func test_kickup_by_ground_type() -> void:
	var g := Track.GROUND_GRASS
	var s := Track.GROUND_SAND
	eq(FxLayer.kickup_kind(Redrock.theme(), g), "dust", "Redrock desert dirt")
	eq(FxLayer.kickup_kind(PalmCoast.theme(), s), "sand", "Palm Coast beach")
	eq(FxLayer.kickup_kind(Timberline.theme(), s), "snow", "Timberline snow")
	eq(FxLayer.kickup_kind(BayouCauseway.theme(), s), "water", "Bayou open water")
	eq(FxLayer.kickup_kind(SkylineFinale.theme(), s), "water", "Skyline harbor")
	eq(FxLayer.kickup_kind({}, s), "sand", "a theme without its own falls back")
	for i in Stages.count():
		var theme := Stages.build(i).theme
		for ground in [g, s]:
			check(FxLayer.EFFECTS.has(FxLayer.kickup_kind(theme, ground)), "stage %d ground %d is an effect" % [i + 1, ground])


func test_kickup_reads_the_side_the_car_is_on() -> void:
	var t := Track.new()
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_SAND)
	for i in 50:
		t.add_segment(0.0, 0.0)
	t.finish_building(40)
	var p := _car()
	p.x = -1.5
	eq(FxLayer.ground_under(p, t), Track.GROUND_GRASS, "left")
	p.x = 1.5
	eq(FxLayer.ground_under(p, t), Track.GROUND_SAND, "right")


func test_sparks_on_hits() -> void:
	for hit in ["crashed", "bumped", "rammed"]:
		var p := _car()
		p.set(hit, true)
		check(_has(p, "sparks"), "sparks when %s" % hit)
		eq(_has(p, "impact"), hit == "crashed", "impact star only on a crash (%s)" % hit)


func test_landing_puff() -> void:
	var p := _car()
	p.landed = true
	check(_has(p, "puff"), "touching down")


func test_nitro_flame_burst_and_speed_lines() -> void:
	var p := _car(0.8)
	p.nitro_time = 3.0
	check(_has(p, "nitro_burst", -1.0, 0.0), "burst the tick it lights")
	check(not _has(p, "nitro_burst", -1.0, 3.0 + 1.0 / 60.0), "not while it burns down")
	eq(FxLayer.nitro_frame(0.0, 3.0, 0.0), 0, "no flame without nitro")
	eq(FxLayer.nitro_frame(3.0, 3.0, 0.0), 1, "lights small")
	eq(FxLayer.nitro_frame(0.1, 3.0, 0.0), FxLayer.NITRO_FRAMES, "dies down")
	for t in [0.0, 0.05, 0.1, 0.15, 0.3]:
		var f := FxLayer.nitro_frame(1.5, 3.0, t)
		check(f >= 2 and f < FxLayer.NITRO_FRAMES, "burns in the middle frames (%d at %s)" % [f, t])
	eq(FxLayer.speed_lines(p), 1.0, "full speed lines on nitro")
	eq(FxLayer.speed_line_frame(1.0), FxLayer.SPEED_LINE_FRAMES, "heaviest lines on nitro")
	p.nitro_time = 0.0
	eq(FxLayer.speed_lines(p), 0.0, "none at 80%")
	p.speed = Cfg.MAX_SPEED
	check(FxLayer.speed_lines(p) > 0.0, "some at top speed")
	eq(FxLayer.speed_line_frame(FxLayer.speed_lines(p)), 2, "lighter than nitro")


func test_frames_play_through_a_particle_life() -> void:
	eq(FxLayer.frame_at("smoke", 0.0), 1, "first frame at birth")
	eq(FxLayer.frame_at("smoke", FxLayer.EFFECTS["smoke"]["life"] - 0.001), 8, "last frame at the end")
	eq(FxLayer.frame_at("impact", 0.1), 1, "one-frame effect")


func test_every_effect_frame_loads() -> void:
	for id: String in FxLayer.EFFECTS:
		var e: Dictionary = FxLayer.EFFECTS[id]
		for f in range(1, e["frames"] + 1):
			var name: String = e["sprite"] if e["frames"] == 1 else "%s_%d" % [e["sprite"], f]
			check(FxLayer.texture(name) != null, "%s frame %d" % [id, f])
	for f in range(1, FxLayer.NITRO_FRAMES + 1):
		check(FxLayer.texture("nitro_%d" % f) != null, "nitro flame %d" % f)
	for f in range(1, FxLayer.SPEED_LINE_FRAMES + 1):
		check(FxLayer.texture("speed_%d" % f) != null, "speed lines %d" % f)


func test_react_starts_particles_at_the_car() -> void:
	var fx := FxLayer.new()
	var t := TestSuite.flat_track()
	var p := _car(0.7)
	p.crashed = true
	p.crash_time = 1.0
	fx.react(p, t)
	check(fx.count("sparks") > 0, "sparks")
	eq(fx.count("impact"), 1, "one impact star")
	p = _car()
	p.landed = true
	fx.react(p, t)
	eq(fx.count("puff"), 2, "a puff at each rear wheel")
	fx.free()


func test_pool_caps_spawns_per_tick_and_in_all() -> void:
	var fx := FxLayer.new()
	var started := 0
	for i in FxLayer.SPAWN_CAP + 5:
		started += int(fx.spawn("smoke", Vector2(320, 300), false))
	eq(started, FxLayer.SPAWN_CAP, "capped per tick")
	eq(fx.dropped, 5, "the rest dropped")
	var t := TestSuite.flat_track()
	var p := _car()
	for tick in 60:
		fx.update(1.0 / 600.0, p, t)  # short ticks: nothing dies yet
		for i in FxLayer.SPAWN_CAP:
			fx.spawn("smoke", Vector2(320, 300), false)
	eq(fx.alive_count(), FxLayer.MAX_PARTICLES, "the pool fills up and stops")
	for tick in 120:
		fx.update(1.0 / 60.0, p, t)
	eq(fx.alive_count(), 0, "particles die and go back to the pool")
	fx.free()


func test_fx_randomness_leaves_the_global_generator_alone() -> void:
	seed(4242)
	var want := randf()
	seed(4242)
	var fx := FxLayer.new()
	var t := TestSuite.flat_track()
	var p := _car(0.7)
	p.braking = true
	for tick in 30:
		fx.update(1.0 / 60.0, p, t)
	check(fx.alive_count() > 0, "made some smoke")
	eq(randf(), want, "global generator untouched")
	fx.free()


func test_splash_off_the_bayou_causeway() -> void:
	var r := race(false, false, 4)
	r.set("_start_segment", 700)  # out on the first causeway
	r.start_race()
	drive(r, 181, input())  # through the countdown
	r.player.x = 1.8  # in the water, past the railing
	var splashed := run_until(r, func() -> bool: return r.fx.count("water") > 0, 120, input(1.0))
	check(splashed >= 0, "water kicked up off the causeway")
	eq(r.fx.count("dust"), 0, "no dust over water")
