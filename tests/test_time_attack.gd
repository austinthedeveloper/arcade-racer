## Time Attack: the ghost file, and the race against the clock and the best run.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	TestSuite.use_scratch_ghosts()
	runner.root.get_node("Settings").attack_traffic = false


func _attack(stage := 0) -> Node:
	var r := new_race(false, true, stage, true)
	r.tour = false
	r.time_attack = true
	r.start_race()
	_nodes.append(r)
	return r


## Drives to the line: `ticks` of gas, then over it.
func _run(r: Node, ticks: int) -> void:
	drive(r, ticks, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))


func _sample(n: int) -> Ghost:
	var g := Ghost.make(2, "car_mesa")
	g.time = 61.25
	for i in n:
		g.ticks.append_array([i * 10.0, 0.25, -0.5])
	return g


func test_ghost_round_trip() -> void:
	var g := _sample(5)
	var back := Ghost.from_bytes(g.to_bytes())
	if not check(back != null, "reads back"):
		return
	eq([back.stage, back.car_id, back.count()], [2, "car_mesa", 5], "stage, car, ticks")
	near(back.time, 61.25, 0.0001, "time")
	eq(back.at(3), Vector3(30.0, 0.25, -0.5), "a tick")
	eq(back.at(99), back.at(4), "held at the last tick")


func test_ghost_files_rejects_junk() -> void:
	check(Ghost.from_bytes(PackedByteArray([1, 2, 3])) == null, "too short")
	check(Ghost.from_bytes("NOPE12345678".to_ascii_buffer()) == null, "not a ghost")
	var b := _sample(3).to_bytes()
	b.encode_s32(4, Ghost.VERSION + 1)
	check(Ghost.from_bytes(b) == null, "a newer version")
	var cut := _sample(3).to_bytes()
	check(Ghost.from_bytes(cut.slice(0, cut.size() - 4)) == null, "cut short")


func test_ghost_saves_per_stage_and_car() -> void:
	_clean()
	check(Ghost.load_best(2, "car_mesa") == null, "none yet")
	check(_sample(4).save(), "saved")
	var g := Ghost.load_best(2, "car_mesa")
	check(g != null and g.count() == 4, "loads")
	check(Ghost.load_best(2, "car_vega") == null, "another car has its own")
	check(Ghost.load_best(3, "car_mesa") == null, "and another stage")
	check(Ghost.path(2, "car_mesa").begins_with(TestSuite.SCRATCH_GHOSTS), "tests use a scratch folder")
	_clean()


func test_time_at_interpolates() -> void:
	var g := _sample(10)  # 10 units a tick
	near(g.time_at(0.0, 0.1), 0.0, 0.0001, "at the start")
	near(g.time_at(5.0, 0.1), 0.15, 0.0001, "halfway between ticks 0 (at 0.1 s) and 1")
	near(g.time_at(25.0, 0.1), 0.35, 0.0001, "halfway between ticks 2 and 3")
	check(is_inf(g.time_at(1000.0, 0.1)), "never got there")
	check(Ghost.beats(10.0, null), "anything beats no ghost")
	check(Ghost.beats(60.0, g) and not Ghost.beats(62.0, g), "faster beats it")


func test_time_attack_is_solo_with_no_time_limit() -> void:
	_clean()
	var r := _attack()
	eq(r.rivals.cars.size(), 0, "no rivals")
	eq(r.traffic.cars.size(), 0, "no traffic by default")
	var start: float = r.time_left
	drive(r, 400, input(1.0))
	eq(r.state, r.State.RACING, "racing")
	near(r.time_left, start, 0.001, "the clock doesn't run down")
	check(r.race_time > 2.0, "the run's time counts up")
	r.time_left = 0.0
	drive(r, 2, input(1.0))
	eq(r.state, r.State.RACING, "no TIME UP")
	runner.root.get_node("Settings").attack_traffic = true
	r.start_race()
	check(r.traffic.cars.size() > 0, "traffic when picked")
	_clean()


func test_a_first_run_becomes_the_ghost() -> void:
	_clean()
	var r := _attack()
	check(r.ghost == null, "no ghost the first time")
	_run(r, 300)
	eq(r.state, r.State.FINISHED, "finished")
	check(r.new_best, "a new best")
	check("NEW BEST" in r.banner_sub, "says so: " + r.banner_sub)
	var g := Ghost.load_best(0, "car_vega")
	if not check(g != null, "saved"):
		return
	near(g.time, r.race_time, 0.0001, "with its time")
	eq(g.count(), r.recording.count(), "every racing tick")
	eq(SaveData.furthest_stage, 0, "a Time Attack run opens no stages")
	check(not SaveData.best(0, "car_vega").is_empty(), "but its time is a best time")
	_clean()


func test_the_next_run_races_the_ghost() -> void:
	_clean()
	var r := _attack()
	_run(r, 300)
	r.start_race()
	if not check(r.ghost != null, "the ghost loads"):
		return
	check(not r.road.ghost_strips.is_empty(), "and is drawn")
	drive(r, 200, input(1.0))
	var g: Ghost = r.ghost
	eq(r.ghost_now, g.at(r.recording.count() - 1), "keeps step with the run")
	check(r.ghost_now.x > 0.0, "and moves")
	_run(r, 20)  # faster than the first
	check(r.new_best, "beaten")
	near(Ghost.load_best(0, "car_vega").time, r.race_time, 0.0001, "replaced")
	r.start_race()
	_run(r, 400)  # slower
	check(not r.new_best, "not a best")
	check("+" in r.banner_sub and "vs best" in r.banner_sub, "how far off: " + r.banner_sub)
	_clean()


func test_checkpoints_split_against_the_ghost() -> void:
	_clean()
	var r := _attack()
	_run(r, 300)
	r.start_race()
	drive(r, 200, input(1.0))
	r.player.distance = r.checkpoint_distances[0] + 1.0
	drive(r, 1, input(1.0))
	check(not is_nan(r.split), "a split")
	check(r.split < 0.0, "ahead of a ghost that took longer to get there (%.2f)" % r.split)
	check(r.banner_sub.ends_with("vs best"), r.banner_sub)
	near(r.time_left, r.START_TIME, 1.0, "no time extension")
	eq(r.split_text(-1.234), "-1.23", "split text")
	eq(r.split_text(0.5), "+0.50", "behind")
	_clean()


func test_autodriven_runs_save_no_ghost() -> void:
	_clean()
	var r := new_race(true, false, 0, false)
	r.tour = false
	r.time_attack = true
	r.start_race()
	_nodes.append(r)
	drive(r, 100)
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1)
	check(Ghost.load_best(0, "car_vega") == null, "nothing saved")
	_clean()


func test_time_attack_is_on_mode_select() -> void:
	check(ModeSelect.available(ModeSelect.Item.TIME_ATTACK), "playable")
	eq(Hud.clock_text(83.456), "1:23.46", "clock text")
