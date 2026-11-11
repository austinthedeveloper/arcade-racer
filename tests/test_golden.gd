## The golden path: an autodriven race finishes, and play matches its golden traces
## frame for frame (tests/golden.gd).
extends TestSuite


## Compares a scenario's run with its golden trace; `mirror` runs it on the stage mirrored
## (WS-6), which has to give the very same trace mirrored back (Golden.snapshot). A race
## with traffic and rivals, as built, is then also checked for a proper finish.
func _check(scenario: String, mirror := false) -> void:
	var path := Golden.DIR + scenario + ".txt"
	if not check(FileAccess.file_exists(path), "golden trace %s exists" % scenario):
		return
	var want := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var finish := _finishes_in_time if scenario.ends_with("_traffic") and not mirror else Callable()
	var got := Golden.run(scenario, Golden.FRAMES, mirror, finish)
	if mirror:
		scenario += " mirrored"
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


# WS-6: a mirrored stage is the stage as built flipped left for right, so its autodriven
# race is the golden one mirrored: every x and curve the other way, the same distances,
# times, banners and finish. The trace is computed, not stored.
func test_mirrored_runs_mirror_the_golden_traces() -> void:
	for sc: String in Golden.SCENARIOS:
		_check(sc, true)


func test_runs_are_reproducible() -> void:
	# With rivals on the grid (EQ-6): their RNG is seeded per stage
	var a := Golden.run("autodrive_traffic", 1500)
	check(a[-1].contains("rivals="), "the trace has rival columns")
	eq(a, Golden.run("autodrive_traffic", 1500), "same input, same trace")


func test_a_race_without_rivals_has_no_rival_columns() -> void:
	check(not Golden.run("autodrive_clear_road", 10)[-1].contains("rivals="), "the clear road keeps its old format")


## The autodriven race ends inside Golden.FRAMES, the longest the clock allows; this
## looks at how it ended, then runs on until the rivals are home.
func _finishes_in_time(r: Node) -> void:
	var name: String = r.track.name
	check(r.state == r.State.FINISHED or r.state == r.State.TIME_UP, name + ": the race ends")
	eq(r.state, r.State.FINISHED, name + ": finished, not timed out")
	eq(r.next_checkpoint, r.checkpoint_distances.size(), name + ": every checkpoint passed")
	check(r.race_time > 60.0 and r.race_time < 120.0, "%s: a believable lap time (%.1f s)" % [name, r.race_time])
	run_until(r, func(): return r.rivals.finished_count() == Rivals.COUNT, 60 * 60)
	eq(r.rivals.finished_count(), Rivals.COUNT, name + ": every rival finishes")
	# RC-21: the field home within its band on Normal, the autodrive placed in it
	var f := Soak.field(r)
	eq(Soak.out_of_band(f, Difficulty.Level.NORMAL, r.stage_index), "", "%s: in its band (spread %.1f s, placed %d)" % [
		name, f["spread"], f["place"]])


# RC-21: on Easy and Hard too, every stage's autodriven field finishes within its band
# (Soak.BANDS), the autodrive placed where the difficulty says. (Normal: _finishes_in_time.)
# RC-23: and the autodrive reaches every checkpoint with Soak.CLOCK_MARGIN on the clock at
# least, on the difficulty's own timer and checkpoint bonuses.
func test_every_stage_in_its_band_on_easy_and_hard_with_time_to_spare() -> void:
	var settings: Node = runner.root.get_node("Settings")
	for stage in Stages.count():
		for level in [Difficulty.Level.EASY, Difficulty.Level.HARD]:
			var f := Soak.autodrive_field(settings, stage, level)
			eq(f["rivals_home"], Rivals.COUNT, "%s %s: every rival home" % [Stages.POSTCARDS[stage], Difficulty.NAMES[level]])
			eq(Soak.out_of_band(f, level, stage), "", "%s %s: in its band (spread %.1f s, placed %d, %.1f s on the clock)" % [
				Stages.POSTCARDS[stage], Difficulty.NAMES[level], f["spread"], f["place"], f["clock"]])
	eq(settings.difficulty, Difficulty.Level.NORMAL, "Settings left as they were")


func test_every_stage_has_a_golden_scenario() -> void:
	# With traffic and rivals: that run is also each stage's finish check (_finishes_in_time)
	var stages := {}
	for sc: String in Golden.SCENARIOS:
		if sc.ends_with("_traffic"):
			stages[Golden.stage_of(sc)] = true
	eq(stages.size(), Stages.count(), "one scenario with traffic per stage at least")
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
