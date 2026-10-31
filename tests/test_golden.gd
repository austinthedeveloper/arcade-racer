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


func test_thunder_run_matches_golden() -> void:
	_check("thunder_autodrive_traffic")


func test_skyline_run_matches_golden() -> void:
	_check("skyline_autodrive_traffic")


func test_runs_are_reproducible() -> void:
	# With rivals on the grid (EQ-6): their RNG is seeded per stage
	var a := Golden.run("autodrive_traffic", 1500)
	check(a[-1].contains("rivals="), "the trace has rival columns")
	eq(a, Golden.run("autodrive_traffic", 1500), "same input, same trace")


func test_a_race_without_rivals_has_no_rival_columns() -> void:
	check(not Golden.run("autodrive_clear_road", 10)[-1].contains("rivals="), "the clear road keeps its old format")


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
	run_until(r, func(): return r.rivals.finished_count() == Rivals.COUNT, 60 * 60)
	eq(r.rivals.finished_count(), Rivals.COUNT, name + ": every rival finishes")


func test_every_stage_has_a_golden_scenario() -> void:
	var stages := {}
	for sc: String in Golden.SCENARIOS:
		stages[Golden.stage_of(sc)] = true
	eq(stages.size(), Stages.count(), "one scenario per stage at least")
	eq(Golden.stage_of("autodrive_traffic"), 0, "no prefix is Palm Coast")
	eq(Golden.stage_of("skyline_autodrive_traffic"), 7, "skyline_ is the Skyline Finale")


func test_the_snapshot_sees_power_ups() -> void:
	# Regression: the snapshot skipped the ram and ghost timers and the pickups taken, so a
	# change to power-ups could pass the golden traces.
	var r := TestSuite.new_race(true, true, 0)
	var before := Golden.snapshot(r)
	r.player.ram_time = 1.0
	check(Golden.snapshot(r) != before, "ram plate time")
	r.player.ram_time = 0.0
	r.power_ups.pickups[0].taken = true
	check(Golden.snapshot(r) != before, "a pickup taken")
	r.power_ups.pickups[0].taken = false
	r.traffic.cars[0].offset += 0.5
	check(Golden.snapshot(r) != before, "a car out of its lane")
	r.traffic.cars[0].offset -= 0.5
	r.rivals.cars[3].x += 0.5
	check(Golden.snapshot(r) != before, "a rival moved")
	r.free()
