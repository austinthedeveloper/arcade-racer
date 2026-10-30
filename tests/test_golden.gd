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


func test_redrock_run_matches_golden() -> void:
	_check("redrock_autodrive_traffic")


func test_neon_run_matches_golden() -> void:
	_check("neon_autodrive_traffic")


func test_timberline_run_matches_golden() -> void:
	_check("timberline_autodrive_traffic")


func test_bayou_run_matches_golden() -> void:
	_check("bayou_autodrive_traffic")


func test_harvest_run_matches_golden() -> void:
	_check("harvest_autodrive_traffic")


func test_runs_are_reproducible() -> void:
	eq(Golden.run("autodrive_traffic", 900), Golden.run("autodrive_traffic", 900), "same input, same trace")


func test_autodriven_race_finishes_in_time() -> void:
	for stage in Stages.count():
		_finishes_in_time(stage)


func _finishes_in_time(stage: int) -> void:
	var r := race(true, true, stage)
	var ticks := run_until(r, func(): return r.state == r.State.FINISHED or r.state == r.State.TIME_UP, Golden.FRAMES)
	var name: String = r.track.name
	check(ticks > 0, name + ": the race ends")
	eq(r.state, r.State.FINISHED, name + ": finished, not timed out")
	eq(r.next_checkpoint, r.checkpoint_distances.size(), name + ": every checkpoint passed")
	check(r.race_time > 60.0 and r.race_time < 120.0, "%s: a believable lap time (%.1f s)" % [name, r.race_time])
