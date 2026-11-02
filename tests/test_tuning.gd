## The tuning registry (EQ-15) and the debug panel's logic (EQ-16).
extends TestSuite

var SCRATCH := TestSuite.scratch("tuning.cfg")
var SCRATCH_PRESETS := TestSuite.scratch("tuning_presets")
var SCRATCH_LOG := TestSuite.scratch("tuning_log.txt")
const FIXTURE := "res://tests/fixtures/tuning_override.cfg"


## Scratch files for this suite, empty; Tuning.use_defaults again afterwards (_done).
func _scratch() -> void:
	Tuning.use_defaults()
	Tuning.path = SCRATCH
	Tuning.preset_dir = SCRATCH_PRESETS
	Tuning.log_path = SCRATCH_LOG
	for f in [SCRATCH, SCRATCH_LOG]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var d := DirAccess.open(SCRATCH_PRESETS)
	if d != null:
		for f in d.get_files():
			d.remove(f)


func _done() -> void:
	Tuning.use_defaults()
	Tuning.preset_dir = Tuning.PRESET_DIR
	Tuning.log_path = Tuning.LOG_PATH


func _log_lines() -> PackedStringArray:
	if not FileAccess.file_exists(SCRATCH_LOG):
		return PackedStringArray()
	return FileAccess.get_file_as_string(SCRATCH_LOG).strip_edges().split("\n")


func _menu(dx := 0, dy := 0, confirm := false, held := 0.0) -> MenuInput:
	var m := MenuInput.new()
	m.x = dx
	m.left_pressed = dx < 0
	m.right_pressed = dx > 0
	m.up_pressed = dy < 0
	m.down_pressed = dy > 0
	m.confirm_pressed = confirm
	return m


func test_every_value_has_its_metadata() -> void:
	var seen := 0
	for key: String in Tuning.TABLE:
		var area := key.get_slice("/", 0)
		check(Tuning.AREAS.has(area), "%s is in an area" % key)
		check(Tuning.step_of(key) > 0.0, "%s has a step" % key)
		check(Tuning.min_of(key) <= Tuning.default_of(key) and Tuning.default_of(key) <= Tuning.max_of(key),
			"%s's default is in its range" % key)
		check(Tuning.help(key) != "", "%s says what it is" % key)
		check(Tuning.keys_in(area).has(key), "%s is listed on its page" % key)
		seen += 1
	var listed := 0
	for area: String in Tuning.AREAS:
		check(not Tuning.keys_in(area).is_empty(), "%s has values" % area)
		listed += Tuning.keys_in(area).size()
	eq(listed, seen, "every value on one page")
	eq(Tuning.AREA_NAMES.size(), Tuning.AREAS.size(), "every area named")
	check(Tuning.keys_in("driving").size() < DebugPanel.VISIBLE_ROWS, "the longest page fits... (driving)")
	check(Tuning.keys_in("ai").size() < DebugPanel.VISIBLE_ROWS, "...(ai)")


func test_the_defaults_are_the_old_constants() -> void:
	# The numbers the constants had, so the golden traces stay as they were
	eq(Tuning.v("driving/accel_time"), 3.2, "accel")
	eq(Tuning.v("driving/steer_rate"), 2.2, "steer rate")
	eq(Tuning.v("draft/speed_mult"), 1.08, "draft")
	eq(Tuning.i("scoring/no_crash"), 5, "points are whole")
	eq(Cfg.MAX_SPEED / Tuning.v("driving/accel_time"), Cfg.MAX_SPEED / 3.2, "the same float as the old ACCEL")
	check(not Tuning.any_tuned(), "tests run on the defaults")


func test_an_override_applies() -> void:
	_scratch()
	var plain := PlayerCar.new()
	var tuned := PlayerCar.new()
	var t := flat_track()
	for p: PlayerCar in [plain, tuned]:
		p.reset(0.0)
		p.speed = Cfg.MAX_SPEED * 0.8
	var inp := input(1.0, 1.0)
	plain.update(DT, inp, t, true)
	eq(Tuning.set_value("driving/steer_rate", 4.0), 4.0, "set")
	check(Tuning.tuned("driving/steer_rate") and Tuning.any_tuned(), "tuned")
	tuned.update(DT, inp, t, true)
	check(tuned.x > plain.x * 1.5, "a faster steering rate steers further in a tick (%.4f vs %.4f)" % [tuned.x, plain.x])
	Tuning.set_value("scoring/near_miss", 4.0)
	var s := Scoring.new()
	s.add("NEAR MISS", Tuning.i("scoring/near_miss"))
	eq(s.total(), 4, "points read the tuned value")
	_done()


func test_set_value_clamps_snaps_and_drops_the_default() -> void:
	_scratch()
	eq(Tuning.set_value("driving/steer_rate", 99.0), 4.0, "clamped to the top of its range")
	eq(Tuning.set_value("driving/steer_rate", -5.0), 1.0, "and the bottom")
	near(Tuning.set_value("driving/steer_rate", 2.33), 2.35, 0.0001, "snapped to its step")
	eq(Tuning.set_value("scoring/air", 2.4), 2.0, "whole numbers stay whole")
	Tuning.set_value("driving/steer_rate", 2.2)
	check(not Tuning.tuned("driving/steer_rate"), "back at the default is no override")
	near(Tuning.nudge("driving/gravity", 1), 12500.0, 0.001, "a nudge is a step")
	near(Tuning.nudge("driving/gravity", -1, 5), 10000.0, 0.001, "five steps down")
	check(is_nan(Tuning.set_value("driving/no_such", 1.0)), "an unknown key")
	_done()


func test_a_missing_file_is_the_defaults() -> void:
	_scratch()
	Tuning.set_value("draft/width", 0.6)
	check(not Tuning.load_file(TestSuite.scratch("no_such_tuning.cfg")), "nothing to read")
	check(not Tuning.any_tuned(), "the defaults")
	_done()


func test_save_and_load_round_trip() -> void:
	_scratch()
	Tuning.set_value("draft/width", 0.6)
	Tuning.set_value("scoring/big_air", 4.0)
	check(Tuning.save(), "saved")
	Tuning.reset_all()
	check(Tuning.load_file(SCRATCH), "read back")
	near(Tuning.v("draft/width"), 0.6, 0.0001, "a value")
	eq(Tuning.i("scoring/big_air"), 4, "a whole one")
	eq(Tuning.overrides().size(), 2, "only the overrides are written")
	_done()


func test_the_fixture_override_file() -> void:
	# The file tools/test_tuning_adopt.py adopts: unknown keys skipped, out of range clamped
	_scratch()
	check(Tuning.load_file(FIXTURE), "read")
	near(Tuning.v("driving/steer_rate"), 2.5, 0.0001, "steer rate")
	near(Tuning.v("draft/speed_mult"), 1.12, 0.0001, "draft")
	eq(Tuning.i("scoring/near_miss"), 2, "points")
	eq(Tuning.v("camera/shake_crash"), Tuning.max_of("camera/shake_crash"), "out of range: clamped")
	eq(Tuning.overrides().size(), 4, "the unknown key skipped")
	_done()


func test_boot_once_and_use_defaults() -> void:
	_scratch()
	Tuning.set_value("draft/width", 0.6)
	Tuning.save()
	Tuning.use_defaults()
	Tuning.boot(SCRATCH)
	check(not Tuning.any_tuned(), "use_defaults: boot reads nothing")
	_done()


func test_presets() -> void:
	_scratch()
	Tuning.set_value("ai/band_max", 0.12)
	check(Tuning.save_preset("Loose Rivals!"), "saved")
	eq(Tuning.presets(), ["loose_rivals_"] as Array[String], "named as a file can be")
	Tuning.reset_all()
	check(Tuning.load_preset("loose_rivals_"), "loaded")
	near(Tuning.v("ai/band_max"), 0.12, 0.0001, "its value")
	check(not Tuning.save_preset("  "), "no name, no preset")
	_done()


func test_text() -> void:
	eq(Tuning.text("driving/steer_rate", 2.2), "2.20", "to its step")
	eq(Tuning.text("driving/gravity", 12000.0), "12000", "a whole step")
	eq(Tuning.text("ai/line_gain", 0.09), "0.09", "hundredths")
	eq(Tuning.text("scoring/air", 1.0), "1", "points")


func test_panel_pages_and_rows() -> void:
	_scratch()
	var p := TuningPanel.new()
	eq(p.rows()[0], TuningPanel.Row.PAGE, "the page row first")
	eq(p.rows().size(), Tuning.keys_in("driving").size() + 1, "a row per value")
	p.tick(_menu(1), DT)
	eq(TuningPanel.PAGES[p.page], "slide", "right on the page row: the next page")
	p.tick(_menu(-1), DT)
	p.tick(_menu(-1), DT)
	eq(TuningPanel.PAGES[p.page], "presets", "left from the first wraps to the last")
	p.tick(_menu(-1), DT)
	eq(p.rows().size(), 1 + TuningPanel.ACTION_ROWS.size(), "the actions")
	p.tick(_menu(0, -1), DT)
	eq(p.row, p.rows().size() - 1, "up from the page row wraps to the last row")
	_done()


func test_panel_nudges_resets_and_logs() -> void:
	_scratch()
	var p := TuningPanel.new()
	p.context = "stage 1 Palm Coast, car_vega, 12.0 s"
	var key := Tuning.keys_in("driving")[0]
	p.tick(_menu(0, 1), DT)
	eq(p.picked_key(), key, "down onto the first value")
	p.tick(_menu(1), DT)
	p.tick(_menu(1), DT)
	near(Tuning.v(key), Tuning.default_of(key) + 2.0 * Tuning.step_of(key), 0.0001, "two steps up, at once")
	check(FileAccess.file_exists(SCRATCH), "saved as it changes")
	eq(_log_lines().size(), 0, "not logged while it's still being nudged")
	p.tick(_menu(0, 1), DT)
	var log := _log_lines()
	eq(log.size(), 1, "logged once, moving off it")
	check(log[0].contains("Palm Coast") and log[0].contains(key) and log[0].contains("->"), "with where and what: " + log[0])
	p.tick(_menu(0, -1), DT)
	p.tick(_menu(0, 0, true), DT)
	check(not Tuning.tuned(key), "confirm: back to the default")
	check(_log_lines()[-1].contains("reset"), "logged")
	_done()


func test_panel_held_goes_faster() -> void:
	_scratch()
	var p := TuningPanel.new()
	p.row = 1
	var key := p.picked_key()
	var held := _menu(1)
	held.right_pressed = false
	for i in roundi(TuningPanel.FAST_AFTER / DT) + 1:
		p.tick(held, DT)
	eq(p.times(), TuningPanel.FAST, "held a second: bigger steps")
	p.tick(_menu(1), DT)
	near(Tuning.v(key), Tuning.default_of(key) + TuningPanel.FAST * Tuning.step_of(key), 0.0001, "a big step")
	p.tick(_menu(0), DT)
	eq(p.times(), 1, "let go: single steps again")
	_done()


func test_panel_actions() -> void:
	_scratch()
	var p := TuningPanel.new()
	p.page = TuningPanel.PAGES.find("actions")
	p.segments = 1000
	p.row = p.rows().find(TuningPanel.Row.SLOW_MOTION)
	p.tick(_menu(1), DT)
	eq(p.slow_motion(), 0.5, "slow motion")
	p.row = p.rows().find(TuningPanel.Row.JUMP)
	p.tick(_menu(1), DT)
	eq(p.jump_to, TuningPanel.JUMP_STEP, "a segment to jump to")
	eq(p.tick(_menu(0, 0, true), DT), TuningPanel.Action.JUMP, "Enter: jump")
	p.row = p.rows().find(TuningPanel.Row.GIVE)
	p.tick(_menu(1), DT)
	eq(TuningPanel.GIVE_KINDS[p.give], PowerUps.Kind.CLOCK, "the next power-up")
	eq(p.tick(_menu(0, 0, true), DT), TuningPanel.Action.GIVE, "Enter: give it")
	p.row = p.rows().find(TuningPanel.Row.CLOCK)
	eq(p.tick(_menu(0, 0, true), DT), TuningPanel.Action.CLOCK, "set the clock")
	p.row = p.rows().find(TuningPanel.Row.BURST)
	eq(p.tick(_menu(0, 0, true), DT), TuningPanel.Action.BURST, "a traffic burst")
	eq(_log_lines().size(), 4, "every action logged")
	_done()


func test_panel_presets() -> void:
	_scratch()
	var p := TuningPanel.new()
	p.page = TuningPanel.PAGES.find("presets")
	Tuning.set_value("launch/boost_accel", 2.0)
	p.row = p.rows().find(TuningPanel.Row.SAVE)
	p.tick(_menu(0, 0, true), DT)
	check(p.typing, "Enter: type a name")
	for c in "hot":
		p.type_key(c)
	p.type_key("", true)
	p.type_key("", false, true)
	check(not p.typing, "Enter saves")
	eq(Tuning.presets(), ["ho"] as Array[String], "under its name")
	eq(p.tick(_menu(0, 0, true), DT), TuningPanel.Action.NONE, "the Enter that saved doesn't also start typing again")
	check(not p.typing, "still not typing")
	p.row = p.rows().find(TuningPanel.Row.RESET_ALL)
	p.tick(_menu(0, 0, true), DT)
	check(not Tuning.any_tuned(), "reset all")
	p.row = p.rows().find(TuningPanel.Row.LOAD)
	p.tick(_menu(0, 0, true), DT)
	near(Tuning.v("launch/boost_accel"), 2.0, 0.0001, "loaded back")
	_done()


func test_race_actions() -> void:
	_scratch()
	var r := race(false, true, 0)
	var p := TuningPanel.new()
	p.jump_to = 500
	r.debug_action(TuningPanel.Action.JUMP, p)
	eq(r.player.distance, 500 * Cfg.SEGMENT_LENGTH, "jumped along the route")
	eq(r.next_checkpoint, r.checkpoint_distances.filter(func(d: float) -> bool: return d <= r.player.distance).size(),
		"past the checkpoints behind it")
	p.give = TuningPanel.GIVE_KINDS.find(PowerUps.Kind.RAM)
	r.debug_action(TuningPanel.Action.GIVE, p)
	eq(r.player.ram_time, Tuning.v("power_ups/ram_time"), "the ram plate")
	p.clock = 7.0
	r.debug_action(TuningPanel.Action.CLOCK, p)
	eq(r.time_left, 7.0, "the clock set")
	var before: int = r.traffic.cars.size()
	p.burst = 15
	r.debug_action(TuningPanel.Action.BURST, p)
	eq(r.traffic.cars.size(), before + 15, "more traffic")
	_done()


func test_the_race_stands_still_under_the_panel() -> void:
	_scratch()
	var r := race(true, false, 0, false)
	r.countdown = 0.0
	drive(r, 2)
	r.debug_panel.visible = true
	var at: float = r.race_time
	drive(r, 30)
	eq(r.race_time, at, "nothing moves while it's up")
	r.debug_panel.visible = false
	r.debug_panel.logic.slow = TuningPanel.SLOW_MOTION.find(0.5)
	drive(r, 30)
	near(r.race_time - at, 30 * DT * 0.5, 0.0001, "slow motion: half the time in as many ticks")
	r.debug_panel.logic.slow = 0
	_done()


func test_context_and_badge() -> void:
	_scratch()
	eq(DebugPanel.context_of(null), "menus", "the menus")
	var r := race(false, false, 0, false)
	check(DebugPanel.context_of(r).begins_with("stage 1 ") and DebugPanel.context_of(r).contains(r.car_id), DebugPanel.context_of(r))
	var lay := Hud.layout()
	var badge: Rect2 = lay["tuned"]
	check(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H).encloses(badge), "the TUNED badge is on screen")
	for other in ["progress", "nitro", "timer", "stage"]:
		check(not badge.intersects(lay[other]), "clear of the " + other)
	eq(DebugPanel.page_named("camera"), Tuning.AREAS.find("camera"), "a page by name")
	_done()
