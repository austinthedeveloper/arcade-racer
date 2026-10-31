## Race flow (race.gd): countdown, checkpoints, the timer, finishing, pause and restart.
extends TestSuite


func test_countdown_then_go() -> void:
	var r := race(false, false)
	eq(r.state, r.State.COUNTDOWN, "starts counting down")
	drive(r, 60, input(1.0))
	eq(r.player.speed, 0.0, "the car waits")
	drive(r, 110, input(1.0))
	eq(r.state, r.State.COUNTDOWN, "still counting at 2.8 s")
	check(r.player.speed > 0.0 and r.player.speed <= Launch.ROLL_SPEED, "rolling slowly to the line")
	drive(r, 20, input(1.0))
	eq(r.state, r.State.RACING, "racing after 3 s")
	eq(r.banner, "GO!", "GO banner")
	drive(r, 60, input(1.0))
	check(r.player.speed > 0.0, "the car moves once racing")


func test_timer_runs_out() -> void:
	var r := race(false, false)
	drive(r, 181)
	r.time_left = 0.1
	drive(r, 10)
	eq(r.state, r.State.TIME_UP, "time up")
	eq(r.time_left, 0.0, "clock stops at zero")
	var t0: float = r.race_time
	drive(r, 30, input(1.0))
	eq(r.race_time, t0, "race clock stopped")


func test_checkpoints_extend_time_once_each() -> void:
	var r := race(false, false)
	drive(r, 181)
	var before: float = r.time_left
	var bonus: float = r.clock[1]
	r.player.distance = r.checkpoint_distances[0] + 1.0
	r._check_progress()
	near(r.time_left, before + bonus, 0.001, "the stage's first bonus added")
	eq(r.next_checkpoint, 1, "next checkpoint")
	eq(r.checkpoint_bonus, r.clock[2], "the next one is the second bonus")
	r._check_progress()
	near(r.time_left, before + bonus, 0.001, "not added twice")
	eq(r.banner, "CHECKPOINT!", "banner")


func test_crossing_the_finish_ends_the_race() -> void:
	var r := race(false, false)
	drive(r, 181)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.state, r.State.FINISHED, "finished")
	eq(r.banner, "FINISH!", "banner")
	drive(r, 30, input(1.0))
	eq(r.state, r.State.FINISHED, "stays finished")


func test_starting_partway_in_counts_the_road_behind() -> void:
	var r := race(false, false)
	var seg: int = r.track.checkpoints[1] + 5
	r.set("_start_segment", seg)
	r.start_race()
	eq(r.player.distance, seg * Cfg.SEGMENT_LENGTH, "distance from the start of the route")
	eq(r.next_checkpoint, 2, "the checkpoints behind are passed")
	r.set("_start_segment", 0)
	r.start_race()
	eq(r.player.distance, 0.0, "from the start again")
	eq(r.next_checkpoint, 0, "no checkpoints passed")


func test_slow_motion_past_the_line() -> void:
	var race_script: GDScript = load("res://scripts/race/race.gd")
	var slow: float = race_script.FINISH_SLOWMO
	eq(race_script.finish_time_scale(0.0), slow, "slow right after the line")
	check(race_script.finish_time_scale(1.2) > slow, "speeding back up")
	eq(race_script.finish_time_scale(10.0), 1.0, "full speed in the end")


func test_the_car_brakes_to_a_stop_after_the_line() -> void:
	var r := race(false, false)
	drive(r, 181)
	drive(r, 300, input(1.0))
	var v: float = r.player.speed
	check(v > Cfg.MAX_SPEED * 0.5, "flat out before the line")
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	var z: float = r.player.distance
	drive(r, 1, input(1.0))
	check(r.player.distance - z < v / 60.0 * 0.5, "the first tick past the line is in slow motion")
	check(r.player.braking, "brake lights on")
	var stopped := run_until(r, func() -> bool: return r.player.speed == 0.0, 600, input(1.0))
	check(stopped > 0, "comes to a stop (%d ticks)" % stopped)
	check(not r.player.braking, "brake lights off once stopped")


func test_pause_freezes_the_race() -> void:
	var r := race(false, false)
	drive(r, 240, input(1.0))
	var p := input(1.0)
	p.pause_pressed = true
	drive(r, 1, p)
	check(r.paused, "paused")
	var z: float = r.player.distance
	var t: float = r.time_left
	drive(r, 60, input(1.0))
	eq(r.player.distance, z, "car frozen")
	eq(r.time_left, t, "timer frozen")
	drive(r, 1, p)
	check(not r.paused, "resumed")


func test_restart_resets_everything() -> void:
	var r := race(false, true)
	drive(r, 400, input(1.0))
	r.time_left = 3.0
	r.player.nitro_charges = 0
	var rs := input()
	rs.restart_pressed = true
	drive(r, 1, rs)
	eq(r.state, r.State.COUNTDOWN, "counting down again")
	eq(r.time_left, r.clock[0], "time reset")
	eq(r.player.distance, 0.0, "back at the start")
	eq(r.player.nitro_charges, Cfg.NITRO_CHARGES, "nitro refilled")
	eq(r.traffic.cars.size(), r.TRAFFIC_COUNT, "traffic respawned")


func _finish(r: Node) -> void:
	drive(r, 181)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()


## Enter after a finish or TIME UP. During the finish spectacle the first press brings up
## the results; a second picks their first choice (on, or back to the menus).
func _confirm(r: Node) -> void:
	var c := input()
	c.confirm_pressed = true
	var was_up: bool = r.results.visible
	drive(r, 1, c)
	if r.results.visible and not was_up:
		drive(r, 1, c)


func test_finishing_palm_coast_continues_to_redrock() -> void:
	var r := race(false, false)
	eq(r.track.name, "Palm Coast Boulevard", "the tour opens on Palm Coast")
	_finish(r)
	check("Redrock Canyon" in r.banner_sub, "the finish names the next stage: " + r.banner_sub)
	r.time_left = 2.0
	_confirm(r)
	eq(r.stage_index, 1, "stage 2")
	eq(r.track.name, "Redrock Canyon", "on to Redrock")
	eq(r.state, r.State.COUNTDOWN, "counting down on the new stage")
	eq(r.time_left, r.clock[0], "fresh clock: Redrock's own")
	eq(r.player.distance, 0.0, "at the start line")
	eq(r.background.theme, r.track.theme, "the background shows Redrock")


func test_finishing_the_last_stage_completes_the_tour() -> void:
	var r := race(false, false, Stages.count() - 1)
	_finish(r)
	check("Tour complete" in r.banner_sub, "tour complete: " + r.banner_sub)
	var over := [false]
	r.race_over.connect(func(): over[0] = true)
	_confirm(r)
	check(over[0], "Enter goes back to the menus")


func test_restart_and_retry_stay_on_the_stage() -> void:
	var r := race(false, false, 1)
	r.tour = false  # in a tour, restarts spend the continue (test_tour)
	drive(r, 400, input(1.0))
	var rs := input()
	rs.restart_pressed = true
	drive(r, 1, rs)
	eq(r.track.name, "Redrock Canyon", "restart keeps the stage")
	drive(r, 181)
	r.time_left = 0.1
	drive(r, 10)
	eq(r.state, r.State.TIME_UP, "time up")
	_confirm(r)
	eq(r.stage_index, 1, "retry the same stage")
	eq(r.state, r.State.COUNTDOWN, "counting down again")


func test_confirm_does_nothing_mid_race() -> void:
	var r := race(false, false)
	drive(r, 240, input(1.0))
	_confirm(r)
	eq(r.state, r.State.RACING, "still racing")
	eq(r.stage_index, 0, "still on stage 1")


func test_the_tour_runs_through_every_stage_in_order() -> void:
	var r := race(false, false)
	for i in range(1, Stages.count()):
		_finish(r)
		check(Stages.stage_name(i) in r.banner_sub, "the finish names %s: %s" % [Stages.stage_name(i), r.banner_sub])
		_confirm(r)
		eq(r.stage_index, i, "stage %d" % (i + 1))
		eq(r.track.name, Stages.stage_name(i), "on to " + Stages.stage_name(i))


func test_the_renderer_draws_the_chosen_car() -> void:
	var r := race(false, false)
	check(r.road.player_strips == CarSprites.strips("vega"), "the Vega by default")
	r.car_id = "car_mesa"
	r.start_race()
	check(r.road.player_strips == CarSprites.strips("mesa"), "the Mesa once chosen")


func test_a_restart_starts_the_clocks_over() -> void:
	# Regression: the frame count (autodrive nitro timing, screenshot frames) ran on across
	# restarts, and the pad's speed sensitivity kept the last race's speed.
	var r := race(true, false)
	drive(r, 400)
	check(r._frame > 0 and InputRouter.speed_factor > 0.0, "counting while racing")
	r.start_race()
	eq(r._frame, 0, "frames from zero")
	eq(InputRouter.speed_factor, 0.0, "pad steering back at rest")


func test_launch_window_edges() -> void:
	var G := Launch.Grade
	eq(Launch.grade(-Launch.WINDOW_BEFORE - 0.01, 0.0), G.BOG, "just too early bogs")
	eq(Launch.grade(-Launch.WINDOW_BEFORE, 0.0), G.LAUNCH, "the first moment of the window")
	eq(Launch.grade(0.0, 0.0), G.LAUNCH, "on GO")
	eq(Launch.grade(Launch.WINDOW_AFTER, Launch.WINDOW_AFTER), G.LAUNCH, "the last moment of the window")
	eq(Launch.grade(Launch.WINDOW_AFTER + 0.01, 0.2), G.NONE, "just too late is a plain start")
	eq(Launch.grade(NAN, 0.05), G.PENDING, "no gas yet, still in the window")
	eq(Launch.grade(NAN, Launch.WINDOW_AFTER + 0.01), G.NONE, "no gas through the window")


## Counts down with the gas off, presses it `before` seconds before GO (negative: after), and
## drives a second past GO.
func _start(before: float) -> Node:
	var r := race(false, false, 0, false)
	var gas_at := roundi((3.0 - before) / DT)
	for i in 240:
		drive(r, 1, input(1.0 if i >= gas_at else 0.0))
	return r


func test_gas_in_the_window_launches() -> void:
	var r := _start(0.2)
	eq(r.launch, Launch.Grade.LAUNCH, "launched")
	check(r.banner == "LAUNCH!" or r.player.launch_time < Launch.BOOST_TIME, "LAUNCH banner")
	var plain := _start(-0.5)
	eq(plain.launch, Launch.Grade.NONE, "a late start is plain")
	check(r.player.speed > plain.player.speed * 1.2, "the launch is quicker off the line (%.0f vs %.0f)" % [r.player.speed, plain.player.speed])


func test_gas_held_from_the_start_bogs() -> void:
	var r := race(false, false, 0, false)
	drive(r, 182, input(1.0))
	eq(r.launch, Launch.Grade.BOG, "bogged")
	eq(r.banner_sub, "Too early!", "told why")
	check(r.player.bog_time > 0.0, "bogging")
	var clean := _start(0.2)
	drive(r, 58, input(1.0))
	check(r.player.speed < clean.player.speed, "slower away than a launch")


func test_the_banner_says_launch() -> void:
	var r := race(false, false, 0, false)
	for i in 182:
		drive(r, 1, input(1.0 if i >= 170 else 0.0))
	eq(r.banner, "LAUNCH!", "LAUNCH banner")


func test_rivals_launch_from_their_seed() -> void:
	var a := race(false, false, 0)
	var b := race(false, false, 0)
	drive(a, 182)
	drive(b, 182)
	var launched := 0
	for i in a.rivals.cars.size():
		eq(a.rivals.cars[i].launch_time, b.rivals.cars[i].launch_time, "rival %d launches the same each time" % i)
		launched += int(a.rivals.cars[i].launch_time > 0.0)
	check(launched > 0 and launched < Rivals.COUNT, "some launch, not all (%d)" % launched)


func test_auto_gas_never_bogs() -> void:
	var settings: Node = runner.root.get_node("Settings")
	settings.auto_gas = true
	var r := race(false, false, 0, false)
	drive(r, 182, input())
	eq(r.launch, Launch.Grade.NONE, "a plain start")
	settings.load_settings()


func test_a_single_race_ends_at_the_finish() -> void:
	var r := race(false, false)
	r.tour = false
	var overs := [0]
	r.race_over.connect(func() -> void: overs[0] += 1)
	_finish(r)
	eq(r.state, r.State.FINISHED, "finished")
	check("menu" in r.banner_sub and not "Redrock" in r.banner_sub, "no next stage, the menu instead: " + r.banner_sub)
	_confirm(r)
	eq(overs[0], 1, "Enter: race over, back to the menus")
	eq(r.stage_index, 0, "no stage-to-stage continuation")
	var rs := input()
	rs.restart_pressed = true
	drive(r, 1, rs)
	eq(r.state, r.State.COUNTDOWN, "R after the finish races the stage again")
	eq(r.track.name, "Palm Coast Boulevard", "the same stage")


func test_a_single_race_retries_after_time_up() -> void:
	var r := race(false, false, 2)
	r.tour = false
	var overs := [0]
	r.race_over.connect(func() -> void: overs[0] += 1)
	drive(r, 181)
	r.time_left = 0.1
	drive(r, 10)
	eq(r.state, r.State.TIME_UP, "time up")
	_confirm(r)
	eq(overs[0], 0, "no race over on a retry")
	eq(r.state, r.State.COUNTDOWN, "Enter retries")
	eq(r.stage_index, 2, "on the same stage")


static func _menu(confirm := false, back := false, down := 0, x := 0.0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.down_pressed = down > 0
	m.up_pressed = down < 0
	m.x = x
	return m


## One race tick with this menu input (the pause menu reads InputRouter.menu).
func _menu_tick(r: Node, m: MenuInput, inp: DriveInput = null) -> void:
	var router: Node = runner.root.get_node("InputRouter")
	var keep: MenuInput = router.menu
	router.menu = m
	drive(r, 1, inp if inp != null else input())
	router.menu = keep


func _pause(r: Node) -> void:
	var p := input()
	p.pause_pressed = true
	_menu_tick(r, _menu(), p)


func test_the_pause_menu_resumes() -> void:
	var r := race(false, false)
	drive(r, 240, input(1.0))
	_pause(r)
	check(r.paused and r.pause_menu.visible, "pause opens the menu")
	eq(r.pause_menu.index, 0, "on RESUME")
	var z: float = r.player.distance
	_menu_tick(r, _menu(true))
	check(not r.paused and not r.pause_menu.visible, "RESUME resumes")
	drive(r, 10, input(1.0))
	check(r.player.distance > z, "and the car drives on")
	_pause(r)
	_menu_tick(r, _menu(false, true))
	check(not r.paused, "back resumes too")
	_pause(r)
	_pause(r)
	check(not r.paused, "and so does pause again")


func test_the_pause_menu_restarts() -> void:
	var r := race(false, false, 1)
	drive(r, 400, input(1.0))
	_pause(r)
	_menu_tick(r, _menu(false, false, 1))
	eq(r.pause_menu.index, 1, "down: RESTART")
	_menu_tick(r, _menu(true))
	check(not r.paused and not r.pause_menu.visible, "unpaused")
	eq(r.state, r.State.COUNTDOWN, "counting down again")
	eq(r.player.distance, 0.0, "back at the start")
	eq(r.track.name, "Redrock Canyon", "on the same stage")


func test_the_pause_menu_quits() -> void:
	var r := race(false, false)
	var quits := [0]
	r.quit_requested.connect(func() -> void: quits[0] += 1)
	drive(r, 240, input(1.0))
	_pause(r)
	_menu_tick(r, _menu(false, false, -1))
	eq(r.pause_menu.index, PauseMenu.ITEMS.find(PauseMenu.Action.QUIT), "up from RESUME wraps to QUIT TO TITLE")
	eq(quits[0], 0, "not yet")
	_menu_tick(r, _menu(true))
	eq(quits[0], 1, "QUIT TO TITLE asks to quit")


func test_the_pause_menu_options_come_back_paused() -> void:
	var r := race(false, false)
	var asks := [0]
	r.options_requested.connect(func() -> void: asks[0] += 1)
	drive(r, 240, input(1.0))
	_pause(r)
	check(r.pause_menu.has_options, "OPTIONS offered when someone shows them")
	_menu_tick(r, _menu(false, false, 1))
	_menu_tick(r, _menu(false, false, 1))
	_menu_tick(r, _menu(true))
	eq(asks[0], 1, "OPTIONS asks for the options")
	check(r.paused and not r.pause_menu.visible, "still paused, menu hidden under them")
	var z: float = r.player.distance
	_menu_tick(r, _menu(true))
	eq(asks[0], 1, "the hidden menu takes no input")
	eq(r.player.distance, z, "the race stays frozen")
	r.options_closed()
	check(r.pause_menu.visible and r.pause_menu.index == 2, "back on the menu, on OPTIONS")
	_menu_tick(r, _menu(false, true))
	check(r.paused, "the back press that closed the options doesn't also resume")
	_menu_tick(r, _menu(false, true))
	check(not r.paused, "the next one does")


func test_pause_menu_selection() -> void:
	var m := PauseMenu.new()
	m.open()
	m.has_options = false
	eq(m.move(1), 1, "down: RESTART")
	eq(m.move(1), 3, "down skips OPTIONS with no options to show")
	eq(m.move(-1), 1, "and so does up")
	m.has_options = true
	eq(m.move(1), 2, "OPTIONS when there are")
	m.open()
	eq(m.index, 0, "opens on RESUME")
	eq(m.choose(_menu(false, false, 1, 0.0)), PauseMenu.Action.NONE, "a move picks nothing")
	eq(m.choose(_menu(true)), PauseMenu.Action.RESTART, "confirm picks RESTART")
	eq(m.choose(_menu(false, true)), PauseMenu.Action.RESUME, "back resumes")
	eq(m.choose(_menu(), true), PauseMenu.Action.RESUME, "pause resumes")
	m.open()
	var held := _menu(false, false, -1)
	held.y = -1.0  # gas held through the pause, auto-repeating
	m.choose(held)
	eq(m.index, 0, "a direction held since before the pause doesn't move it")
	m.choose(_menu())
	m.choose(held)
	eq(m.index, 3, "once let go, it does")
	m.free()


func test_every_stage_has_its_own_clock() -> void:
	var race_script: GDScript = load("res://scripts/race/race.gd")
	for i in Stages.count():
		var t := Stages.build(i)
		var given: Array = t.theme.get("clock", [])
		eq(given.size(), t.checkpoints.size() + 1, "%s: a start and a bonus per checkpoint" % t.name)
		var c: Array[float] = race_script.stage_clock(t.theme, t.checkpoints.size())
		eq(c[0], float(given[0]), "%s starts on its own time" % t.name)
	var fallback: Array[float] = race_script.stage_clock({}, 2)
	eq(fallback, [45.0, 25.0, 25.0] as Array[float], "a theme without one gets the defaults")


# --- Attract-mode demo ----------------------------------------------------------------

func _demo(stage := 0) -> Node:
	var r := race(false, true, stage)
	r.demo = true
	r.start_race()
	return r


func test_a_demo_drives_itself_with_traffic() -> void:
	var s: Node = runner.root.get_node("Settings")
	s.traffic = s.Traffic.LIGHT
	var r := _demo()
	s.traffic = s.Traffic.NORMAL
	eq(r.state, r.State.RACING, "no countdown")
	eq(r.traffic.cars.size(), int(r.track.theme.get("traffic", r.TRAFFIC_COUNT)), "full traffic whatever the options say")
	var held := input(0.0, -1.0, 1.0)
	held.pause_pressed = true
	drive(r, 120, held)
	check(r.player.speed > Cfg.MAX_SPEED * 0.3, "autodriven, the player's brake ignored")
	check(not r.paused, "and their pause")


func test_a_demo_ends_itself() -> void:
	var r := _demo()
	var quits := [0]
	r.quit_requested.connect(func() -> void: quits[0] += 1)
	drive(r, 10)
	eq(quits[0], 0, "driving along")
	r.race_time = Attract.DEMO_SECONDS
	drive(r, 1)
	eq(quits[0], 1, "after DEMO_SECONDS")
	r.start_race()
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1)
	eq(quits[0], 2, "at the finish")
	r.start_race()
	r.time_left = 0.01
	drive(r, 1)
	eq(quits[0], 3, "at time up")


func test_a_demo_saves_nothing() -> void:
	TestSuite.use_scratch_settings(runner.root.get_node("Settings"))
	TestSuite.use_scratch_profiles(runner.root.get_node("InputRouter"))
	var r := _demo(1)
	run_until(r, func() -> bool: return r.demo_over(), 5000)
	check(r.demo_over(), "the demo ran to its end")
	check(not FileAccess.file_exists(TestSuite.SCRATCH_SETTINGS), "no options written")
	check(not FileAccess.file_exists(TestSuite.SCRATCH_PROFILES), "no input profiles written")
	# Nor progress: a demo that reaches the line records no best time
	var save: Node = runner.root.get_node("SaveData")
	TestSuite.use_scratch_save(save)
	r.start_race()
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1)
	eq(r.state, r.State.FINISHED, "a demo at the finish")
	check(save.bests.is_empty() and not FileAccess.file_exists(TestSuite.SCRATCH_SAVE), "no best time or save written")
	TestSuite.use_scratch_save(save)


func test_the_results_wait_for_the_finish_spectacle() -> void:
	var r := race(false, false, 0)
	r.tour = false
	drive(r, 200)
	r.player.distance = r.finish_distance + 1.0
	drive(r, 2)
	eq(r.state, r.State.FINISHED, "finished")
	check(not r.results.visible, "the slow-down and celebration first")
	drive(r, roundi(r.RESULTS_AFTER * 60.0) + 2)
	check(r.results.visible, "then the results")
	r.start_race()
	drive(r, 200)
	r.player.distance = r.finish_distance + 1.0
	drive(r, 2)
	var c := input()
	c.confirm_pressed = true
	drive(r, 1, c)
	check(r.results.visible and r.state == r.State.FINISHED, "Enter brings them sooner, and only that")
