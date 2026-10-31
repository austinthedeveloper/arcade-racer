## Race flow (race.gd): countdown, checkpoints, the timer, finishing, pause and restart.
extends TestSuite


func test_countdown_then_go() -> void:
	var r := race(false, false)
	eq(r.state, r.State.COUNTDOWN, "starts counting down")
	drive(r, 170, input(1.0))
	eq(r.state, r.State.COUNTDOWN, "still counting at 2.8 s")
	eq(r.player.speed, 0.0, "the car waits for GO")
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
	r.player.distance = r.checkpoint_distances[0] + 1.0
	r._check_progress()
	near(r.time_left, before + r.CHECKPOINT_BONUS, 0.001, "bonus added")
	eq(r.next_checkpoint, 1, "next checkpoint")
	r._check_progress()
	near(r.time_left, before + r.CHECKPOINT_BONUS, 0.001, "not added twice")
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
	eq(r.time_left, r.START_TIME, "time reset")
	eq(r.player.distance, 0.0, "back at the start")
	eq(r.player.nitro_charges, Cfg.NITRO_CHARGES, "nitro refilled")
	eq(r.traffic.cars.size(), r.TRAFFIC_COUNT, "traffic respawned")


func _finish(r: Node) -> void:
	drive(r, 181)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()


func _confirm(r: Node) -> void:
	var c := input()
	c.confirm_pressed = true
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
	eq(r.time_left, r.START_TIME, "fresh clock")
	eq(r.player.distance, 0.0, "at the start line")
	eq(r.background.theme, r.track.theme, "the background shows Redrock")


func test_finishing_the_last_stage_starts_the_tour_over() -> void:
	var r := race(false, false, Stages.count() - 1)
	_finish(r)
	check("Tour complete" in r.banner_sub, "tour complete: " + r.banner_sub)
	_confirm(r)
	eq(r.stage_index, 0, "back to stage 1")
	eq(r.track.name, "Palm Coast Boulevard", "Palm Coast again")
	eq(r.state, r.State.COUNTDOWN, "new race")


func test_restart_and_retry_stay_on_the_stage() -> void:
	var r := race(false, false, 1)
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
