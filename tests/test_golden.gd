## The golden path: an autodriven race finishes, and play matches its golden traces
## frame for frame (tests/golden.gd).
extends TestSuite


func _check(scenario: String) -> void:
	var path := Golden.DIR + scenario + ".txt"
	if not check(FileAccess.file_exists(path), "golden trace %s exists" % scenario):
		return
	var want := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var got := Golden.run(scenario)
	eq(got.size(), want.size(), scenario + " length")
	for i in mini(got.size(), want.size()):
		if got[i] != want[i]:
			runner.fail("%s diverges at line %d:\n      want %s\n      got  %s" % [scenario, i,
				want[i].left(160), got[i].left(160)])
			return
	check(true)


func test_traffic_run_matches_golden() -> void:
	_check("autodrive_traffic")


func test_clear_road_run_matches_golden() -> void:
	_check("autodrive_clear_road")


func test_runs_are_reproducible() -> void:
	eq(Golden.run("autodrive_traffic", 900), Golden.run("autodrive_traffic", 900), "same input, same trace")


func test_autodriven_race_finishes_in_time() -> void:
	var r := race(true, true)
	var ticks := run_until(r, func(): return r.state == r.State.FINISHED or r.state == r.State.TIME_UP, Golden.FRAMES)
	check(ticks > 0, "the race ends")
	eq(r.state, r.State.FINISHED, "finished, not timed out")
	eq(r.next_checkpoint, r.checkpoint_distances.size(), "every checkpoint passed")
	check(r.race_time > 60.0 and r.race_time < 120.0, "a believable lap time (%.1f s)" % r.race_time)
