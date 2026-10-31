## Grand Tour rules (Tour) and the race playing them.
extends TestSuite


func test_the_top_three_go_through() -> void:
	check(Tour.advances(1) and Tour.advances(3), "podium")
	check(not Tour.advances(4) and not Tour.advances(0), "4th or no place")


func test_points_add_up_into_standings() -> void:
	var t := Tour.new()
	t.award(["Ann", Tour.YOU, "Bo"], 5)
	eq(t.points, {"Ann": 20, Tour.YOU: 20, "Bo": 12}, "place points, plus your bonuses")
	t.award([Tour.YOU, "Bo", "Ann"], 0)
	eq(t.points, {"Ann": 32, Tour.YOU: 40, "Bo": 27}, "added up")
	var s := t.standings()
	eq([s[0]["name"], s[1]["name"], s[2]["name"]], [Tour.YOU, "Ann", "Bo"], "most points first")
	eq(t.standing_of("Bo"), 3, "standing")
	var tie := Tour.new()
	tie.award(["Zed", Tour.YOU], 5)
	eq(tie.standings()[0]["name"], Tour.YOU, "20 + 5 beats 20")
	tie.points = {"Zed": 10, "Amy": 10, Tour.YOU: 10}
	eq(tie.standings().map(func(r): return r["name"]), [Tour.YOU, "Amy", "Zed"], "ties: you, then by name")


func test_one_continue() -> void:
	var t := Tour.new()
	check(t.use_continue(), "the continue")
	check(not t.use_continue(), "only one")


func test_carried_time() -> void:
	eq(Tour.carry(12.5, true), 12.5, "on: carried")
	eq(Tour.carry(12.5, false), 0.0, "off: not")
	eq(Tour.carry(-1.0, true), 0.0, "never negative")


func _finish(r: Node, place_ahead: int) -> void:
	r.state = r.State.RACING
	r.countdown = 0.0
	r.race_time = 60.0
	r.next_checkpoint = r.checkpoint_distances.size()
	for i in r.rivals.cars.size():
		r.rivals.cars[i].distance = r.finish_distance * (2.0 if i < place_ahead else 0.1)
		if i < place_ahead:
			r.rivals.cars[i].finished = true
			r.rivals.cars[i].finish_time = 50.0
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1)


## Enter after a finish or TIME UP. During the finish spectacle the first press brings up
## the results; a second picks their first choice (on, or back to the menus).
func _confirm(r: Node) -> void:
	var c := input()
	c.confirm_pressed = true
	var was_up: bool = r.results.visible
	drive(r, 1, c)
	if r.results.visible and not was_up:
		drive(r, 1, c)


func test_a_podium_goes_on_with_the_same_drivers() -> void:
	var r := race(false, false, 0)
	var drivers: Array[String] = r.rivals.driver_names()
	_finish(r, 1)
	eq(r.place, 2, "2nd")
	eq(r.after, r.After.NEXT_STAGE, "through")
	check(r.tour_state.points[Tour.YOU] >= 15, "15 points and bonuses")
	_confirm(r)
	eq(r.stage_index, 1, "on to Redrock")
	eq(r.rivals.driver_names(), drivers, "the same seven drivers")


func test_outside_the_top_three_spends_the_continue_then_ends_the_tour() -> void:
	var r := race(false, false, 0)
	_finish(r, 4)
	eq(r.place, 5, "5th")
	eq(r.after, r.After.RETRY, "another go")
	check(r.banner_sub.contains("continue"), "offers the continue: " + r.banner_sub)
	check(not r.tour_state.points.has(Tour.YOU), "no points")
	_confirm(r)
	eq([r.stage_index, r.state, r.tour_state.continues], [0, r.State.COUNTDOWN, 0], "the same stage again, continue spent")
	_finish(r, 4)
	eq(r.after, r.After.TOUR_OVER, "no continue left: the tour is over")
	var over := [false]
	r.race_over.connect(func(): over[0] = true)
	_confirm(r)
	check(over[0], "back to the menus")


func test_time_up_spends_the_continue() -> void:
	var r := race(false, false, 0)
	drive(r, 200)
	r.time_left = 0.01
	drive(r, 2)
	eq(r.state, r.State.TIME_UP, "time up")
	eq(r.after, r.After.RETRY, "the continue")
	var rs := input()
	rs.restart_pressed = true
	drive(r, 1, rs)
	eq(r.tour_state.continues, 0, "R spends it too")
	drive(r, 200)
	r.time_left = 0.01
	drive(r, 2)
	eq(r.after, r.After.TOUR_OVER, "then the tour is over")


func test_the_last_stage_completes_the_tour_and_unlocks_the_zenith() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var r := race(false, false, Stages.count() - 1)
	r.tour_state.start_stage = 0  # as if it had run from Palm Coast
	_finish(r, 0)
	eq(r.after, r.After.TOUR_DONE, "tour complete")
	check(r.tour_state.complete, "complete")
	var save: Node = runner.root.get_node("SaveData")
	check(save.is_unlocked(Tour.FINISH_UNLOCK), "the Zenith unlocks")
	check(save.total_points >= 20, "points saved (%d)" % save.total_points)
	TestSuite.use_scratch_save(save)


func test_carry_time_option() -> void:
	var settings: Node = runner.root.get_node("Settings")
	settings.carry_time = true
	var r := race(false, false, 0)
	r.time_left = 17.0
	_finish(r, 0)
	near(r.tour_state.carried, 17.0, 0.1, "carried")
	_confirm(r)
	var start: float = settings.race_time(r.clock[0])
	near(r.time_left, start + 17.0, 0.1, "into the next stage's clock")
	settings.carry_time = false


func test_a_single_race_has_no_tour() -> void:
	var r := new_race(false, false, 0)
	r.tour = false
	r.start_race()
	_nodes.append(r)
	_finish(r, 5)
	eq(r.after, r.After.MENU, "back to the menu whatever the place")


# Review on #119 from here: restarts that dodged the continue, a tour that carried on after
# it ended, and a one-stage tour unlocking the Zenith.
func _restart_key(r: Node) -> void:
	var rs := input()
	rs.restart_pressed = true
	drive(r, 1, rs)


func test_restarting_a_stage_spends_the_continue() -> void:
	var r := race(false, false, 0)
	drive(r, 200)
	_restart_key(r)
	eq([r.tour_state.continues, r.state], [0, r.State.COUNTDOWN], "R mid-race: the continue spent, the stage again")
	drive(r, 200)
	var t: float = r.race_time
	_restart_key(r)
	eq(r.state, r.State.RACING, "no continue left: R does nothing")
	check(r.race_time >= t, "the race goes on")
	r.pause()
	r.pause_action(PauseMenu.Action.RESTART)
	eq(r.state, r.State.RACING, "nor does RESTART on the pause menu")
	check(not r.paused, "which goes back to the race")


func test_pause_restart_after_the_tour_is_over_ends_it() -> void:
	var r := race(false, false, 0)
	r.tour_state.continues = 0
	_finish(r, 4)
	eq(r.after, r.After.TOUR_OVER, "tour over")
	var over := [false]
	r.race_over.connect(func(): over[0] = true)
	r.pause()
	r.pause_action(PauseMenu.Action.RESTART)
	check(over[0], "RESTART goes to the menus, not round again")


func test_a_tour_from_the_last_stage_unlocks_nothing() -> void:
	var save: Node = runner.root.get_node("SaveData")
	TestSuite.use_scratch_save(save)
	var r := race(false, false, Stages.count() - 1)
	eq(r.tour_state.start_stage, Stages.count() - 1, "started on the last stage")
	_finish(r, 0)
	eq(r.after, r.After.TOUR_DONE, "it still completes")
	check(not save.is_unlocked(Tour.FINISH_UNLOCK), "no Zenith")
	eq(save.total_points, 0, "no points banked")
	TestSuite.use_scratch_save(save)


func test_only_a_tour_going_on_moves_the_save_on() -> void:
	var save: Node = runner.root.get_node("SaveData")
	TestSuite.use_scratch_save(save)
	var r := race(false, false, 0)
	r._autodrive = false
	_finish(r, 4)
	eq(save.furthest_stage, 0, "5th: the tour didn't reach stage 2")
	check(not save.best(0, r.car_id).is_empty(), "the time is still saved")
	r = race(false, false, 0)
	r._autodrive = false
	_finish(r, 1)
	eq(save.furthest_stage, 1, "2nd: on to stage 2")
	TestSuite.use_scratch_save(save)

