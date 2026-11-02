## The crash log (EQ-20): errors and the last log lines go to a report in the log folder,
## and the title's COPY REPORT puts it on the clipboard.
extends TestSuite


func _fresh(name: String) -> CrashLog:
	var dir := scratch(name)
	var path := CrashLog.report_path(dir)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return CrashLog.new(dir)


func test_a_forced_error_lands_in_the_log() -> void:
	var log := _fresh("crash_forced/")
	OS.add_logger(log)
	print("crash log test: a line before the error")
	push_error("crash log test: a forced error (expected in this output)")
	OS.remove_logger(log)
	var path := CrashLog.report_path(log.dir)
	check(FileAccess.file_exists(path), "the report is written straight away")
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("--- errors (1) ---"), "one error")
	check(text.contains("ERROR: crash log test: a forced error"), "the error")
	check(text.contains("test_crash_log.gd"), "with its GDScript backtrace")
	check(text.contains("crash log test: a line before the error"), "and the log lines before it")
	check(text.begins_with("Sundown Run %s crash report" % ProjectSettings.get_setting("application/config/version")),
		"headed with the game's version")


func test_it_keeps_the_last_200_lines() -> void:
	var log := _fresh("crash_lines/")
	for i in 250:
		log._log_message("line %d\n" % i, false)
	eq(log.lines.size(), CrashLog.LINES, "200 lines")
	eq(log.lines[0], "line 50", "the oldest kept")
	log.record_error("ERROR: boom")
	var text := FileAccess.get_file_as_string(CrashLog.report_path(log.dir))
	check(text.contains("line 249") and not text.contains("line 50\n"), "the report has the last lines only")
	check(text.contains("--- the last 200 log lines ---"), "and says so")


func test_a_message_of_several_lines_counts_each() -> void:
	var log := _fresh("crash_multi/")
	log._log_message("one\ntwo\nthree\n", false)
	eq(log.lines, PackedStringArray(["one", "two", "three"]), "three lines")


func test_a_warning_is_logged_but_writes_no_report() -> void:
	var log := _fresh("crash_warn/")
	var traces: Array[ScriptBacktrace] = []
	log._log_error("f", "a.gd", 3, "careful", "", false, Logger.ERROR_TYPE_WARNING, traces)
	eq(log.error_count, 0, "not an error")
	check(not FileAccess.file_exists(CrashLog.report_path(log.dir)), "no report")
	check(log.lines[-2].begins_with("WARNING: careful"), "in the lines")
	log._log_error("f", "a.gd", 3, "code", "bad index", false, Logger.ERROR_TYPE_SCRIPT, traces)
	eq(log.error_count, 1, "a script error is")
	check(FileAccess.get_file_as_string(CrashLog.report_path(log.dir)).contains("SCRIPT ERROR: bad index\n   at: f (a.gd:3)"),
		"written as Godot prints it, the rationale over the code")


func test_an_error_every_frame_writes_at_most_every_two_seconds() -> void:
	var log := _fresh("crash_throttle/")
	for i in CrashLog.FREE_WRITES:
		log.record_error("ERROR: %d" % i, 1000)
	eq(log.writes, CrashLog.FREE_WRITES, "the first ones straight away")
	log.record_error("ERROR: more", 1500)
	eq(log.writes, CrashLog.FREE_WRITES, "then held back")
	check(log.dirty, "and owed")
	log.record_error("ERROR: later", 1000 + CrashLog.THROTTLE_MSEC)
	eq(log.writes, CrashLog.FREE_WRITES + 1, "until the wait is up")
	for i in CrashLog.MAX_ERRORS + 5:
		log.record_error("ERROR: flood", 1001 + CrashLog.THROTTLE_MSEC)
	log.flush()
	eq(log.errors.size(), CrashLog.MAX_ERRORS, "the first 20 errors listed")
	check(FileAccess.get_file_as_string(CrashLog.report_path(log.dir)).contains("--- errors (32; the first 20) ---"),
		"and the count of all of them")


func test_install_keeps_the_first_log() -> void:
	var first := CrashLog.install(scratch("logs/"))
	eq(CrashLog.install("user://elsewhere/"), first, "a second install keeps the runner's")
	eq(first.dir, scratch("logs/"), "in scratch, not the player's user://logs/")


func test_copy_report_puts_it_on_the_clipboard() -> void:
	var log := _fresh("crash_copy/")
	var clipboard := [""]
	var paste := func(text: String) -> void: clipboard[0] = text
	check(not CrashLog.copy_report(log.dir, paste), "nothing to copy without a report")
	eq(clipboard[0], "", "the clipboard untouched")
	log.record_error(CrashLog.describe("_process", "res://scripts/race/race.gd", 42, "", "Invalid access to 'speed'",
		Logger.ERROR_TYPE_SCRIPT))
	check(CrashLog.copy_report(log.dir, paste), "copied")
	check(clipboard[0].contains("SCRIPT ERROR: Invalid access to 'speed'"), "the error on the clipboard")
	eq(clipboard[0], log.report(), "the whole report")


func test_the_title_offers_copy_report_after_an_error() -> void:
	eq(TitleScreen.report_offer(false, false), "", "nothing without a report")
	eq(TitleScreen.report_offer(true, false), "F4 COPY REPORT", "F4 COPY REPORT with one")
	eq(TitleScreen.report_offer(true, true), "REPORT COPIED", "REPORT COPIED once copied")
	eq(DeviceProfile.KEYBOARD_FIXED["copy_report"], [KEY_F4], "on F4")
	var runner_log := CrashLog.installed
	CrashLog.installed = _fresh("crash_title/")  # the title asks the installed log
	var t := TitleScreen.new()
	_nodes.append(t)
	var clipboard := [""]
	t.set_clipboard = func(text: String) -> void: clipboard[0] = text
	eq(t.report_text(), "", "a clean run: the version line alone")
	CrashLog.installed.record_error("ERROR: from the title test")
	eq(t.report_text(), "F4 COPY REPORT", "after an error: COPY REPORT")
	runner.root.get_node("InputRouter")._register_actions()  # F4 (its _ready may not have run yet)
	var f4 := InputEventKey.new()
	f4.keycode = KEY_F4
	f4.physical_keycode = KEY_F4
	f4.pressed = true
	t._unhandled_input(f4)
	check(clipboard[0].contains("ERROR: from the title test"), "F4 copies the report")
	eq(t.report_text(), "REPORT COPIED", "and says so")
	t.time += TitleScreen.COPIED_SECONDS
	eq(t.report_text(), "F4 COPY REPORT", "for a moment")
	CrashLog.installed = runner_log
