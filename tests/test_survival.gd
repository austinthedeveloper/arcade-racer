## Survival (MP-13): the stage loop, the clock that only shrinks, the traffic ramp, and runs
## that end.
extends TestSuite


func _clean(unlock_all := false) -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	runner.root.get_node("Settings").unlock_all = unlock_all
	Tuning.use_defaults()


func _survival(autodrive := false, traffic := true) -> Node:
	var r := new_race(autodrive, traffic, 0, true)
	r.tour = false
	r.survival = true
	r.start_race()
	_nodes.append(r)
	return r


func _done() -> void:
	runner.root.get_node("Settings").unlock_all = false
	Tuning.use_defaults()


func test_the_loop_goes_round_the_open_stages() -> void:
	var open := func(i: int) -> bool: return i <= 2
	var stages: Array[int] = Survival.loop(open)
	eq(stages, [0, 1, 2] as Array[int], "Palm Coast, then the open stages in tour order")
	eq(Survival.loop(func(_i: int) -> bool: return false), [0] as Array[int], "a new save: Palm Coast alone")
	eq(Survival.loop(func(_i: int) -> bool: return true).size(), Stages.count(), "everything open: every stage")
	eq([Survival.stage_for(0, stages), Survival.stage_for(2, stages), Survival.stage_for(3, stages), Survival.stage_for(7, stages)],
		[0, 2, 0, 1], "round and back to Palm Coast")
	var run := Survival.make(stages)
	eq([run.stage(), run.next_stage()], [0, 1], "the first leg and the one its end looks like")
	run.leg = 2
	eq([run.stage(), run.next_stage()], [2, 0], "the last open stage hands back to Palm Coast")


func test_the_bonus_only_shrinks_until_it_is_gone() -> void:
	Tuning.use_defaults()
	near(Survival.shrink(0), 1.0, 0.0001, "the first is whole")
	var step := Tuning.v("survival/bonus_shrink")
	near(Survival.shrink(4), 1.0 - 4.0 * step, 0.0001, "a share gone for each passed")
	eq(Survival.shrink(Survival.last_bonus()), 0.0, "nothing after the last")
	eq(Survival.shrink(1000), 0.0, "and never below nothing")
	var last := INF
	var total := 0.0
	for n in 200:
		var b := Survival.bonus(30.0, n)
		check(b <= last, "checkpoint %d gives no more than the one before" % n)
		last = b
		total += b
	eq(last, 0.0, "the bonuses run out")
	check(total < 30.0 * Survival.last_bonus(), "so a run's clock is finite: it ends")
	near(Survival.start_time(42.0), 42.0, 0.0001, "the start is the stage's own")


func test_the_traffic_ramps_up_to_its_cap() -> void:
	Tuning.use_defaults()
	eq(Survival.traffic_for(0, 70), 70, "the first leg has the stage's own")
	check(Survival.traffic_for(1, 70) > 70, "the next more")
	check(Survival.traffic_for(2, 70) > Survival.traffic_for(1, 70), "and more")
	var cap := roundi(70 * Tuning.v("survival/traffic_cap"))
	eq(Survival.traffic_for(50, 70), cap, "up to the cap")
	check(Survival.checkpoint_cars() > 0, "each checkpoint adds cars")


func test_a_run_banks_its_legs() -> void:
	Tuning.use_defaults()
	var run := Survival.make([0, 1] as Array[int])
	near(run.checkpoint(40.0), 40.0, 0.0001, "the first checkpoint: the whole bonus")
	near(run.checkpoint(40.0), 40.0 * Survival.shrink(1), 0.0001, "the second: a share less")
	near(run.distance(1000.0), 1000.0, 0.0001, "the first leg's distance")
	var b := run.finish_leg(5000.0, 30.0)
	near(b, 30.0 * Survival.shrink(2), 0.0001, "the line counts as a checkpoint")
	eq([run.leg, run.passed, run.stage()], [1, 3, 1], "on to the next leg")
	near(run.distance(250.0), 5250.0, 0.0001, "the legs driven and this one")
	near(run.distance(-10.0), 5000.0, 0.0001, "never less than what's banked")


func test_survival_is_solo_and_timed_from_palm_coast() -> void:
	_clean(true)
	var r := _survival()
	eq(r.stage_index, 0, "it starts on Palm Coast")
	eq(r.rivals.cars.size(), 0, "no rivals")
	check(r.timed(), "on the clock")
	eq(r.run.stages.size(), Stages.count(), "round every open stage")
	near(r.time_left, Settings.race_time(r.stage_clock(r.track.theme, 3)[0]), 0.01, "the stage's start time")
	check(not r.replay_offered(), "no instant replay: no finish line")
	check(not r.track.next_theme.is_empty(), "its end is dressed for the next leg")
	_done()


func test_the_finish_line_goes_on_into_the_next_stage() -> void:
	_clean(true)
	var r := _survival()
	drive(r, 200, input(1.0))
	var first_traffic: int = r.traffic.cars.size()
	var left: float = r.time_left
	r.player.distance = r.finish_distance + 3.0
	r.player.position = fposmod(r.player.distance, r.track.length)
	var speed: float = r.player.speed
	drive(r, 1, input(1.0))
	eq(r.state, r.State.RACING, "no finish: the road goes on")
	eq([r.run.leg, r.stage_index, r.track.name], [1, 1, Stages.stage_name(1)], "the second leg, on Redrock")
	eq(r.banner, "LEG 2", "the banner says so")
	check(r.time_left > left, "the next stage's start time added")
	check(r.player.distance < 1000.0, "at the new stage's start")
	near(r.player.speed, speed, Cfg.MAX_SPEED * 0.05, "at the same speed")
	check(r.traffic.cars.size() > first_traffic * 1.1, "more traffic than the first leg")
	check(r.survival_distance() > r.run.banked - 1.0 and r.run.banked > 900000.0, "the first leg banked")
	eq(r.next_checkpoint, 0, "the new stage's checkpoints ahead")
	_done()


func test_each_checkpoint_gives_less() -> void:
	_clean()
	var r := _survival(false, false)
	drive(r, 200, input(1.0))
	var given: Array[float] = []
	for k in r.checkpoint_distances.size():
		var before: float = r.time_left
		r.player.distance = r.checkpoint_distances[k] + 1.0
		drive(r, 1, input(1.0))
		given.append(r.time_left - before + DT)
	eq(r.run.passed, 3, "three checkpoints passed")
	for k in given.size():
		var base: float = r.clock[k + 1]
		near(given[k], Settings.race_time(base * Survival.shrink(k), r.difficulty.clock_bonus), 0.05,
			"checkpoint %d: the stage's bonus, cut for the %d before" % [k + 1, k])
	_done()


func test_an_autodriven_run_ends() -> void:
	_clean()
	Tuning.set_value("survival/clock_scale", Tuning.min_of("survival/clock_scale"))  # a short clock: the test stays quick
	var r := _survival(true)
	var ticks := run_until(r, func() -> bool: return r.state == r.State.TIME_UP, 3000)
	check(ticks > 0, "TIME UP comes")
	check(r.survival_distance() > 0.0, "having driven some way")
	run_until(r, func() -> bool: return r.results.visible, 400)
	check(r.results.visible, "then the results")
	eq(r.after, r.After.MENU, "on to the menus from there")
	eq(int(SaveData.survival["runs"]), 0, "an autodriven run isn't saved")
	_done()


func test_the_best_distance_is_kept() -> void:
	_clean()
	Tuning.set_value("survival/clock_scale", Tuning.min_of("survival/clock_scale"))
	var r := _survival()
	run_until(r, func() -> bool: return r.state == r.State.TIME_UP, 3000, input(1.0))
	var far: float = r.survival_distance()
	check(far > 0.0, "driven")
	check(r.survival_new_best, "the first run is a best")
	near(float(SaveData.survival["best"]), far, 0.01, "kept")
	eq([int(SaveData.survival["runs"]), int(SaveData.survival["best_leg"]), SaveData.survival["best_car"]], [1, 1, r.car_id], "the run counted")
	r.start_race()
	run_until(r, func() -> bool: return r.state == r.State.TIME_UP, 3000, input(0.3))
	check(not r.survival_new_best, "a slower run isn't")
	near(float(SaveData.survival["best"]), far, 0.01, "the best stays")
	eq(int(SaveData.survival["runs"]), 2, "both counted")
	SaveData.load_save()
	near(float(SaveData.survival["best"]), far, 0.01, "saved to the profile's file")
	_done()


func test_the_results_list_the_legs() -> void:
	var run := Survival.make([0, 1, 2] as Array[int])
	eq(ResultsScreen.leg_rows(run), [{"leg": 1, "stage": 0, "current": true}] as Array[Dictionary], "one leg")
	run.leg = 9
	var rows := ResultsScreen.leg_rows(run)
	eq(rows.size(), ResultsScreen.LEG_ROWS, "the last few")
	eq([rows[-1]["leg"], rows[-1]["stage"], rows[-1]["current"]], [10, 0, true], "ending on the leg it ran out on")
	eq(ResultsScreen.survival_best_line(true, 5.0, 0), "NEW BEST DISTANCE!", "a best")
	eq(ResultsScreen.survival_best_line(false, 0.0, 0), "", "nothing to beat yet")
	check(ResultsScreen.survival_best_line(false, 160934.0, 0).begins_with("BEST  "), "the best to beat")


func test_a_save_without_the_sections_is_fresh() -> void:
	_clean()
	var cfg := ConfigFile.new()
	CfgVersion.stamp(cfg, SaveData.VERSION)
	cfg.set_value("tour", "furthest_stage", 2)
	cfg.save(SaveData.path)
	SaveData.load_save()
	eq(SaveData.furthest_stage, 2, "the save read")
	eq(SaveData.survival, SaveData.fresh_survival(), "no [survival]: no best yet")
	eq(SaveData.daily, {}, "no [daily]: no tries")
	SaveData.save()
	var back := ConfigFile.new()
	back.load(SaveData.path)
	check(not back.has_section("survival") and not back.has_section("daily"), "and none written until there is something")
