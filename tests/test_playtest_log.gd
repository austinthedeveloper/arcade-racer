## The playtest log (EQ-25): its lines from a scripted race, off by default, and the file a
## race writes. Every file goes in the scratch folder (PlaytestLog.dir_override).
extends TestSuite


func _dir() -> String:
	return TestSuite.scratch("playtest/")


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)
	PlaytestLog.dir_override = _dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	for f in DirAccess.get_files_at(_dir()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir() + f))


func _done() -> void:
	PlaytestLog.dir_override = ""
	TestSuite.use_scratch_settings(Settings)


func test_off_by_default() -> void:
	_clean()
	eq(Settings.playtest_log, false, "off")
	var r := race(true, false, 0, false)
	eq(r.playtest, null, "no log for a race")
	_done()


func test_the_log_from_a_scripted_run() -> void:
	var pl := PlaytestLog.new("redrock", "car_mesa", "single", true, 4.0 * PlaytestLog.STRETCH)
	# Stretch 0 at top speed: nothing lost
	for i in 120:
		pl.tick(1.0 / 60.0, i * Cfg.MAX_SPEED / 60.0, Cfg.MAX_SPEED / 60.0, false)
	pl.checkpoint(1)
	# Stretch 1 at half speed with a crash in it
	var at := PlaytestLog.STRETCH + 10.0
	for i in 60:
		pl.tick(1.0 / 60.0, at, Cfg.MAX_SPEED / 120.0, i == 30)
		at += Cfg.MAX_SPEED / 120.0
	var d := pl.to_dict()
	eq([d["stage"], d["car"], d["mode"], d["mirror"]], ["redrock", "car_mesa", "single", true], "what was raced")
	eq(d["checkpoints"], [{"index": 1, "time": 2.0}], "the checkpoint and when")
	eq(d["crashes"].size(), 1, "one crash")
	eq(d["crashes"][0]["segment"], floori((PlaytestLog.STRETCH + 10.0 + 30 * Cfg.MAX_SPEED / 120.0) / Cfg.SEGMENT_LENGTH), "where")
	eq(d["stretches"].size(), 2, "two stretches driven")
	eq(d["stretches"][0]["lost"], 0.0, "none lost at top speed")
	eq(d["stretches"][1]["lost"], 0.5, "half lost at half speed")
	eq(PlaytestLog.lost(2.0, 0.0), 2.0, "standing still loses it all")
	_clean()
	var path := pl.finish("time_up", _dir())
	check(path.begins_with(_dir()) and path.ends_with(".json"), "written in its folder: " + path)
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	eq([back["result"], int(back["format"]), back["version"]], ["time_up", PlaytestLog.FORMAT, Updater.version()], "how it ended")
	eq(PlaytestLog.new().finish("quit", _dir()), "", "a run that never ticked writes nothing")
	_done()


func test_a_race_writes_its_log() -> void:
	_clean()
	Settings.playtest_log = true
	var r: Node = load("res://scenes/race.tscn").instantiate()
	_nodes.append(r)
	r.set("stage_index", 0)
	r.set("_autodrive", true)
	r.set("_no_traffic", true)
	r.set("_no_rivals", true)
	var track := Stages.build(0)
	r.set("_start_segment", track.checkpoints[-1] - 60)  # just before the last checkpoint
	TestSuite.ready_all(r)
	check(r.playtest != null, "a log with the option on")
	eq(r.playtest.mode, "tour", "the mode")
	var frames := 0
	while r.state != r.State.FINISHED and r.state != r.State.TIME_UP and frames < 3000:
		r._physics_process(TestSuite.DT)
		frames += 1
	eq(r.state, r.State.FINISHED, "the race finished")
	eq(r.playtest, null, "the log ended with it")
	check(FileAccess.file_exists(r.last_playtest_log), "and was written: " + r.last_playtest_log)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(r.last_playtest_log))
	eq([d["stage"], d["car"], d["result"]], ["palm_coast", r.car_id, "finish"], "the stage, car and result")
	eq(d["checkpoints"].size(), 1, "the last checkpoint passed")
	eq(int(d["checkpoints"][0]["index"]), track.checkpoints.size(), "by its number")
	check(float(d["time"]) > 0.0 and d["stretches"].size() > 0, "time and stretches recorded")
	eq(DirAccess.get_files_at(_dir()).size(), 1, "one file a race")
	r.start_race()  # a restart before moving: nothing written for the new run
	r.end_playtest("quit")
	eq(DirAccess.get_files_at(_dir()).size(), 1, "nothing for a run that never moved")
	_done()


func test_the_option_toggles() -> void:
	_clean()
	check(OptionsScreen.PAGE_ROWS[OptionsScreen.Page.DISPLAY].has(OptionsScreen.Row.PLAYTEST), "on the display page")
	var o := OptionsScreen.new()
	_nodes.append(o)
	o.change(OptionsScreen.Row.PLAYTEST, 1, true)
	eq([Settings.playtest_log, OptionsScreen.value_text(OptionsScreen.Row.PLAYTEST)], [true, "ON"], "on")
	Settings.load_settings()
	eq(Settings.playtest_log, true, "saved")
	_done()
