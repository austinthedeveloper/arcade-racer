## Unlocks: the rule per car and stage, the locked menus and the race earning them.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	runner.root.get_node("Settings").unlock_all = false


func _confirm() -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = true
	return m


func test_starters_are_open_from_the_start() -> void:
	for id in ["car_vega", "car_bruiser", "car_kestrel", "car_sol"]:
		check(Unlocks.car_open(id, 0, [], false), id + " open")
	var locked := 0
	for car: Dictionary in Cars.LIST:
		locked += int(not Unlocks.car_open(car["id"], 0, [], false))
	eq(locked, Cars.count() - 4, "every other car starts locked")


func test_cars_open_by_the_stage_reached() -> void:
	var table := {"car_skipper": 2, "car_mesa": 3, "car_cyclone": 4, "car_phantom": 5, "car_halo": 6, "car_tempest": 7}
	for id: String in table:
		var stage: int = table[id]
		check(not Unlocks.car_open(id, stage - 2, [], false), "%s locked before stage %d" % [id, stage])
		check(Unlocks.car_open(id, stage - 1, [], false), "%s open on reaching stage %d" % [id, stage])
		eq(Unlocks.car_condition(id), "Reach stage %d in the Grand Tour" % stage, id + " says so")


func test_the_zenith_needs_the_tour_finished() -> void:
	check(not Unlocks.car_open("car_zenith", Stages.count() - 1, [], false), "reaching the last stage isn't enough")
	check(Unlocks.car_open("car_zenith", 0, [Tour.FINISH_UNLOCK], false), "the tour's unlock opens it")
	eq(Unlocks.car_condition("car_zenith"), "Finish the Grand Tour", "condition")


func test_the_hauler_is_a_secret() -> void:
	check(not Unlocks.car_open("car_hauler", Stages.count() - 1, [Tour.FINISH_UNLOCK], false), "not by progress")
	check(Unlocks.car_open("car_hauler", 0, ["car_hauler"], false), "by its unlock")
	check(Unlocks.earns_secret(0, false), "a clean Palm Coast earns it")
	check(not Unlocks.earns_secret(0, true), "not after touching traffic")
	check(not Unlocks.earns_secret(1, false), "only on Palm Coast")
	check(Unlocks.car_condition("car_hauler").begins_with("A secret"), "the condition stays a hint")


func test_every_locked_car_says_what_opens_it() -> void:
	for car: Dictionary in Cars.LIST:
		if not Unlocks.STARTERS.has(car["id"]):
			check(Unlocks.car_condition(car["id"]) != "", car["id"] + " has a condition")


func test_stages_open_as_the_tour_reaches_them() -> void:
	check(Unlocks.stage_open(0, 0, false), "stage 1 always")
	check(not Unlocks.stage_open(1, 0, false), "stage 2 locked")
	check(Unlocks.stage_open(3, 3, false), "reached")
	check(not Unlocks.stage_open(4, 3, false), "not yet")
	eq(Unlocks.stage_condition(4), "Reach stage 5 in the Grand Tour", "condition")


func test_unlock_everything_opens_it_all() -> void:
	for car: Dictionary in Cars.LIST:
		check(Unlocks.car_open(car["id"], 0, [], true), car["id"])
	for i in Stages.count():
		check(Unlocks.stage_open(i, 0, true), Stages.stage_name(i))


func test_newly_open_lists_what_a_finish_opened() -> void:
	eq(Unlocks.newly_open(0, [], 1, []), ["car_skipper"] as Array[String], "reaching stage 2: the Skipper")
	eq(Unlocks.newly_open(1, [], 1, []), [] as Array[String], "nothing new")
	eq(Unlocks.newly_open(6, [], 7, [Tour.FINISH_UNLOCK]), ["car_zenith"] as Array[String], "the Zenith")
	eq(Hud.unlock_line(["car_skipper"] as Array[String]), "NEW CAR: DUNE SKIPPER", "the notice")


func test_locked_stages_and_cars_cant_be_picked() -> void:
	_clean()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.show_stage_select()
	g.menu.index = 1
	g.menu.handle(_confirm())
	eq(g.screen, g.Screen.STAGES, "stage 2 locked: stays on stage select")
	g.menu.index = 0
	g.menu.handle(_confirm())
	eq(g.screen, g.Screen.CARS, "stage 1 picked")
	g.menu.index = Cars.count() - 1  # the Zenith
	g.menu.handle(_confirm())
	eq(g.screen, g.Screen.CARS, "a locked car doesn't start the race")
	runner.root.get_node("Settings").unlock_all = true
	g.menu.handle(_confirm())
	eq(g.screen, g.Screen.RACE, "with everything unlocked it does")
	eq(g.race.car_id, "car_zenith", "in the Zenith")
	_clean()


func test_a_clean_palm_coast_finish_unlocks_the_hauler() -> void:
	_clean()
	var save: Node = runner.root.get_node("SaveData")
	var r := race(false, false, 0)
	drive(r, 200, input(1.0))
	check(not r.touched_traffic, "no traffic on the road to touch")
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	check(save.is_unlocked("car_hauler"), "the Hauler unlocks")
	check(r.new_unlocks.has("car_hauler") and r.new_unlocks.has("car_skipper"),
		"announced with the Skipper (stage 2 reached): %s" % [r.new_unlocks])
	_clean()


func test_touching_traffic_spoils_the_secret() -> void:
	_clean()
	var r := race(false, false, 0)
	drive(r, 200, input(1.0))
	r.touched_traffic = true
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	check(not runner.root.get_node("SaveData").is_unlocked("car_hauler"), "no Hauler")
	eq(r.new_unlocks, ["car_skipper"] as Array[String], "just the Skipper")
	_clean()


func test_hitting_traffic_counts_as_a_touch() -> void:
	var track := TestSuite.flat_track()
	var p := PlayerCar.new()
	p.reset(4000.0)
	p.speed = Cfg.MAX_SPEED
	var c := Traffic.TrafficCar.new()
	c.z = p.position + Cfg.PLAYER_Z + 10.0
	c.speed = Cfg.MAX_SPEED * 0.3
	c.segment = track.find_segment(c.z)
	c.segment.cars.append(c)
	p.collide(track)
	check(p.hit_traffic and p.crashed, "the crash is a touch")
	c.segment.cars.clear()
	p.update(DT, input(0.0), track, true)
	check(not p.hit_traffic, "only for the tick")


func test_unlock_everything_is_saved_with_the_options() -> void:
	var s: Node = runner.root.get_node("Settings")
	s.unlock_all = true
	s.save()
	s.unlock_all = false
	s.load_settings()
	check(s.unlock_all, "loads back on")
	s.reset()
	check(not s.unlock_all, "off by default")
	TestSuite.use_scratch_settings(s)
