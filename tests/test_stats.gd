## The stats page (MP-11): the counters a race adds to the save (races, wins, crashes, near
## misses, miles, races per car and stage), the favourites, the page's rows and the title's
## STATS.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))


func _sd() -> Node:
	return runner.root.get_node("SaveData")


func test_a_fresh_save_has_nothing_counted() -> void:
	_clean()
	eq(_sd().stats, SaveData.fresh_stats(), "all zero")
	eq(_sd().favourite_car(), "", "no favourite car")
	eq(_sd().favourite_stage(), -1, "no favourite stage")


func test_a_finished_race_counts_and_is_saved() -> void:
	_clean()
	var r := race(false, true, 1)
	r.car_id = "car_mesa"
	r.start_race()
	drive(r, 200, input(1.0))
	r.score.crashes = 2
	r.score.add("NEAR MISS", 50)
	r.score.add("AIR", 20)
	r.score.add("NEAR MISS", 50)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.state, r.State.FINISHED, "finished")
	var s: Dictionary = _sd().stats
	eq([s["races"], s["crashes"], s["near_misses"]], [1, 2, 2], "a race, its crashes and near misses")
	eq(s["wins"], 1 if r.place == 1 else 0, "a win only for 1st")
	near(s["miles"], Settings.miles(r.finish_distance + 1.0), 0.0001, "the miles driven")
	eq([s["cars"], s["stages"]], [{"car_mesa": 1}, {"redrock": 1}], "the car and stage")
	# Counted once: the results' retry and leaving afterwards add nothing more
	r.record_stats(false)
	r.record_stats(true)
	eq(_sd().stats["races"], 1, "once")
	_sd().load_save()
	eq(_sd().stats["races"], 1, "saved")
	eq(_sd().stats["cars"], {"car_mesa": 1}, "the cars saved")
	near(_sd().stats["miles"], Settings.miles(r.finish_distance + 1.0), 0.001, "the miles saved")
	r.start_race()  # retry: a new run, nothing driven yet
	eq(_sd().stats["races"], 1, "a retry starts no race of its own")
	_clean()


func test_a_win_counts() -> void:
	_clean()
	var r := race(false, true, 0)
	drive(r, 200, input(1.0))
	for rv: RivalCar in r.rivals.cars:
		rv.distance = 0.0  # everyone well behind
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.place, 1, "first")
	eq(_sd().stats["wins"], 1, "a win")
	_clean()


func test_time_up_counts_a_race_but_no_win() -> void:
	_clean()
	var r := race(false, false, 0, false)
	drive(r, 181)
	r.time_left = 0.1
	drive(r, 10)
	eq(r.state, r.State.TIME_UP, "time up")
	eq([_sd().stats["races"], _sd().stats["wins"]], [1, 0], "a race run to its end, not won")
	_clean()


func test_a_run_left_partway_adds_only_its_miles() -> void:
	_clean()
	var r := race(false, false, 0, false)
	drive(r, 400, input(1.0))
	var driven: float = r.player.distance
	check(driven > 0.0, "it drove")
	r.score.crashes = 1
	r.start_race()  # R: restart
	var s: Dictionary = _sd().stats
	eq([s["races"], s["crashes"]], [0, 1], "no race, but its crash")
	near(s["miles"], Settings.miles(driven), 0.0001, "its miles")
	eq(s["cars"], {}, "no favourite from it")
	r.record_stats(false)  # left at once: never off the grid
	near(_sd().stats["miles"], Settings.miles(driven), 0.0001, "nothing more")
	_clean()


func test_autodriven_and_demo_runs_count_nothing() -> void:
	_clean()
	var r := race(true, false)
	drive(r, 200)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(_sd().stats, SaveData.fresh_stats(), "nothing counted")
	check(not FileAccess.file_exists(TestSuite.SCRATCH_SAVE), "nothing written")
	_clean()


func test_favourites_are_the_most_raced() -> void:
	_clean()
	var sd := _sd()
	sd.record_run(2, "car_mesa", true, false, 0, 0, 1.0)
	sd.record_run(2, "car_vega", true, true, 0, 0, 1.0)
	sd.record_run(4, "car_mesa", true, false, 0, 0, 1.0)
	eq(sd.favourite_car(), "car_mesa", "raced twice")
	eq(sd.favourite_stage(), 2, "Neon Strip, twice")
	sd.record_run(4, "car_vega", true, false, 0, 0, 1.0)
	eq(sd.favourite_car(), "car_vega", "a tie: first in the garage")
	eq(sd.favourite_stage(), 2, "a tie: the earlier stage")
	sd.record_run(4, "car_vega", false, false, 3, 0, 1.0)
	eq(sd.favourite_stage(), 2, "a run quit partway is no race")
	eq([sd.stats["races"], sd.stats["wins"], sd.stats["crashes"]], [4, 1, 3], "the counts")
	_clean()


func test_the_page_rows() -> void:
	var stats := {"races": 8, "wins": 3, "crashes": 5, "near_misses": 12, "miles": 10.0}
	var rows := StatsScreen.rows(stats, Settings.Units.MPH)
	var labels: Array = rows.map(func(r: Dictionary) -> String: return r["label"])
	eq(labels, ["RACES", "WINS", "CRASHES", "NEAR MISSES", "DISTANCE"], "every counter")
	var values: Array = rows.map(func(r: Dictionary) -> String: return r["value"])
	eq(values, ["8", "3   (38%)", "5", "12", "10.0 MI"], "with the share won")
	eq(StatsScreen.rows(stats, Settings.Units.KPH)[4]["value"], "16.1 KM", "the units option")
	eq(StatsScreen.rows(SaveData.fresh_stats(), Settings.Units.MPH)[1]["value"], "0", "no share before a race")
	eq(StatsScreen.favourites("car_mesa", 6), [String(Cars.find("car_mesa")["name"]).to_upper(), "THUNDERHEAD HIGHWAY"],
		"the favourites' names")
	eq(StatsScreen.favourites("", -1), ["-", "-"], "none yet")


func test_miles_follow_the_speedometer() -> void:
	near(Settings.miles(Cfg.MAX_SPEED * 3600.0), Cfg.DISPLAY_TOP_SPEED, 0.001, "an hour at top speed")
	eq(Settings.distance_text(Cfg.MAX_SPEED * 3600.0 / Cfg.DISPLAY_TOP_SPEED, Settings.Units.MPH), "1.0 MI", "a mile")
	eq(Settings.distance_text(Cfg.MAX_SPEED * 3600.0 / Cfg.DISPLAY_TOP_SPEED, Settings.Units.KPH), "1.6 KM", "in kilometres")
