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
