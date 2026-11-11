## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd [-- filter | --skip=substring]
## Runs every tests/test_*.gd suite (methods named test_*), prints a
## summary, and exits non-zero on any failure. A filter runs only the suite.test
## names containing it; --skip runs all but those (CI runs test_golden on its own).
extends SceneTree

var failures := 0
var passes := 0
var current := ""


func _initialize() -> void:
	TestSuite.begin_run()  # this run's own scratch folder (EQ-18)
	# Never read or write the player's own wheel profiles.
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	TestSuite.use_scratch_settings(root.get_node("Settings"))
	TestSuite.use_scratch_save(root.get_node("SaveData"))
	TestSuite.use_scratch_ghosts()
	TestSuite.use_scratch_logs()  # never the player's user://logs/
	Tuning.use_defaults()  # never the player's user://tuning.cfg
	WhosDriving.enabled = false  # no onboarding over the title or in races (test_onboarding turns it on)
	root.get_node("Audio")._ready()  # its buses, before the autoloads' own _ready (a filtered run)
	SpriteLibrary.load_all()
	CarSprites.load_all()
	var filter := ""
	var skip := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		if args[0].begins_with("--skip="):
			skip = args[0].trim_prefix("--skip=")
		else:
			filter = args[0]
	var dir := DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			current = f
			fail("suite failed to load (parse/compile error)")
			continue
		var suite = script.new()
		suite.set("runner", self)
		var methods: Array = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				methods.append(String(m.name))
		methods.sort()
		for m in methods:
			current = f.get_basename() + "." + m
			if filter != "" and current.find(filter) < 0:
				continue
			if skip != "" and current.find(skip) >= 0:
				continue
			var before := failures
			suite.set("asserts", 0)
			suite.call(m)
			if int(suite.get("asserts")) == 0:
				fail("no assertions ran (script error?)")
			if failures == before:
				passes += 1
				print("  ok   ", current)
		suite.call("free_nodes")
	var ms := Time.get_ticks_msec() - t0
	print("\n%d passed, %d failed (%d ms)" % [passes, failures, ms])
	quit(1 if failures > 0 else 0)


func fail(msg: String) -> void:
	failures += 1
	printerr("  FAIL ", current, ": ", msg)


func _finalize() -> void:
	TestSuite.end_run()
