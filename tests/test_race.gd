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


func test_confirm_after_the_finish_races_again() -> void:
	var r := race(false, false)
	drive(r, 181)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	var c := input()
	c.confirm_pressed = true
	drive(r, 1, c)
	eq(r.state, r.State.COUNTDOWN, "new race")
