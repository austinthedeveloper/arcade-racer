## The results screen after a finish (RC-5, PR-7): what it lists and what it offers.
extends TestSuite


func _menu(dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


func _finish(r: Node, ahead: int) -> void:
	drive(r, 200, input(1.0))
	for i in r.rivals.cars.size():
		if i < ahead:
			r.rivals.cars[i].distance = r.finish_distance + 100.0
			r.rivals.cars[i].finished = true
			r.rivals.cars[i].finish_time = 0.01 * (i + 1)
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))


func test_choices_follow_the_mode() -> void:
	eq(ResultsScreen.choices(true, false), [ResultsScreen.Choice.CONTINUE, ResultsScreen.Choice.QUIT] as Array[int], "tour: on or quit")
	eq(ResultsScreen.choices(false, false).size(), 3, "single race: on, retry, quit")
	eq(ResultsScreen.choice_label(ResultsScreen.Choice.CONTINUE, 0), "NEXT STAGE", "a podium goes on")
	eq(ResultsScreen.choice_label(ResultsScreen.Choice.CONTINUE, 1), "USE CONTINUE", "a setback")
	eq(ResultsScreen.choice_label(ResultsScreen.Choice.CONTINUE, 4), "CONTINUE", "the menu")


func test_best_line() -> void:
	eq(ResultsScreen.best_line(true, {}), "NEW BEST TIME!", "new best")
	eq(ResultsScreen.best_line(false, {"time": 75.5}), "BEST  1:15.50", "the best to beat")
	eq(ResultsScreen.best_line(false, {}), "", "none yet")


func test_the_finish_opens_the_results() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var r := race(false, false, 0)
	check(not r.results.visible, "not during the race")
	_finish(r, 1)
	check(r.results.visible, "shown at the finish")
	eq(r.results.labels, ["NEXT STAGE", "QUIT"] as Array[String], "a tour podium: on or quit")
	check(r.new_best_time, "the first time is a best")
	var rows: Array[Dictionary] = ResultsScreen.rows(r.rivals.standings(r.player, r.player_finish), r.player, r.player_finish, r.car_id)
	eq(rows.size(), 8, "the whole field")
	check(not rows[0]["you"] and is_equal_approx(rows[0]["time"], 0.01), "the rival who finished first")
	check(rows[1]["you"] and rows[1]["name"] == "YOU", "then you")
	eq(rows[2]["time"], -1.0, "the rest still racing")
	r.start_race()
	check(not r.results.visible, "gone on a restart")
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))


func test_retry_and_quit_from_a_single_race() -> void:
	var r := race(false, false, 1)
	r.tour = false
	r.start_race()
	_finish(r, 0)
	eq(r.results.labels, ["CONTINUE", "RETRY", "QUIT"] as Array[String], "single race")
	var held := _menu(1)
	held.x = 1.0
	eq(r.results.choose(held, false), ResultsScreen.Choice.NONE, "steering held over the line doesn't move it")
	eq(r.results.index, 0, "still on CONTINUE")
	r.results.choose(_menu(1), false)
	eq(r.results.index, 1, "right: RETRY")
	var c := input()
	c.confirm_pressed = true
	drive(r, 1, c)
	eq(r.state, r.State.COUNTDOWN, "retry: the stage again")
	eq(r.stage_index, 1, "the same stage")
	_finish(r, 0)
	r.results.choose(_menu(-1), false)
	eq(r.results.index, 2, "left wraps to QUIT")
	var quit := [false]
	r.quit_requested.connect(func() -> void: quit[0] = true)
	drive(r, 1, c)
	check(quit[0], "quit asks for the title")


func test_confirm_goes_on_from_the_results() -> void:
	var r := race(false, false, 0)
	_finish(r, 0)
	var c := input()
	c.confirm_pressed = true
	drive(r, 1, c)
	eq(r.stage_index, 1, "on to the next stage")
	check(not r.results.visible, "results closed")
