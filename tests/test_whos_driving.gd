## Who's driving (AC-16): the first boot, and each new profile, asks KID / NEW / RACER on the
## title, and the answer sets only options that already exist. Scratch options and save;
## onboarding back off after.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	return g


static func menu_input(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


func test_kid_sets_auto_gas_the_co_pilot_and_easy() -> void:
	_clean()
	Settings.timer = Settings.Clock.TIGHT
	WhosDriving.apply(WhosDriving.Answer.KID, Settings)
	eq([Settings.auto_gas, Settings.co_pilot, Settings.steer_assist, Settings.brake_assist], [true, true, false, false],
		"auto gas and the co-pilot")
	eq(Settings.difficulty, Difficulty.Level.EASY, "easy")
	eq(Settings.timer, Difficulty.of(Difficulty.Level.EASY).timer, "the timer goes with the difficulty, as on the options")
	Settings.load_settings()
	eq([Settings.auto_gas, Settings.co_pilot, Settings.difficulty], [true, true, Difficulty.Level.EASY], "saved")
	eq(WhosDriving.answer_of(Settings), WhosDriving.Answer.KID, "the options read as KID")
	_clean()


func test_new_sets_the_steering_and_braking_assists_and_easy() -> void:
	_clean()
	Settings.auto_gas = true
	WhosDriving.apply(WhosDriving.Answer.NEW, Settings)
	eq([Settings.auto_gas, Settings.co_pilot, Settings.steer_assist, Settings.brake_assist], [false, false, true, true],
		"steering and braking assists")
	eq(Settings.difficulty, Difficulty.Level.EASY, "easy")
	eq(WhosDriving.answer_of(Settings), WhosDriving.Answer.NEW, "the options read as NEW")
	_clean()


func test_racer_sets_none_and_normal() -> void:
	_clean()
	WhosDriving.apply(WhosDriving.Answer.KID, Settings)
	WhosDriving.apply(WhosDriving.Answer.RACER, Settings)
	eq([Settings.auto_gas, Settings.co_pilot, Settings.steer_assist, Settings.brake_assist], [false, false, false, false], "no help")
	eq(Settings.difficulty, Difficulty.Level.NORMAL, "normal")
	eq(WhosDriving.answer_of(Settings), WhosDriving.Answer.RACER, "the options read as RACER")
	Settings.steer_assist = true
	eq(WhosDriving.answer_of(Settings), -1, "changed in Options since: none of them")
	_clean()


func test_it_sets_only_options_that_exist() -> void:
	for a in WhosDriving.Answer.size():
		for key: String in WhosDriving.options_for(a):
			check(key in Settings, "%s is an option" % key)
	eq(WhosDriving.NAMES.size(), WhosDriving.Answer.size(), "every answer named")
	eq(WhosDriving.LINES.size(), WhosDriving.Answer.size(), "and explained")


func test_the_title_asks_once_per_profile() -> void:
	_clean()
	WhosDriving.enabled = true
	var g := _game()
	check(g.menu is TitleScreen and g.menu.asking, "the first boot: the title asks")
	check(g.menu.busy(), "no demo while it asks")
	eq(g.menu.answer, WhosDriving.DEFAULT, "on NEW")
	g.menu.handle(menu_input(false, false, -1))
	eq(g.menu.answer, WhosDriving.Answer.KID, "left: KID")
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	eq([Settings.steer_assist, Settings.brake_assist], [true, true], "Enter on NEW sets its assists")
	check(not g.menu.asking, "the question goes")
	check(SaveData.driver_asked, "asked, for this profile")
	eq(g.screen, g.Screen.TITLE, "still on the title")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.MODES, "and its menu answers again: START")
	g.show_title()
	check(not g.menu.asking, "not asked again")
	SaveData.load_save()
	check(SaveData.driver_asked, "saved")
	# A new profile (MP-10) is asked too
	var s: int = SaveData.make_profile("JET", "car_mesa")
	SaveData.switch_to(s)
	g.show_title()
	check(g.menu.asking, "a new profile: asked")
	g.menu.handle(menu_input(false, false, 1))
	eq(g.menu.answer, WhosDriving.Answer.RACER, "right: RACER")
	g.menu.handle(menu_input(true))
	eq([Settings.steer_assist, Settings.difficulty], [false, Difficulty.Level.NORMAL], "RACER: none, normal")
	SaveData.switch_to(0)
	g.show_title()
	check(not g.menu.asking, "back to profile 1: answered already")
	WhosDriving.enabled = false
	_clean()


func test_back_passes_it_over_and_an_older_save_is_not_asked() -> void:
	_clean()
	WhosDriving.enabled = true
	Settings.auto_gas = true
	var g := _game()
	check(g.menu.asking, "asked")
	g.menu.handle(menu_input(false, true))
	check(not g.menu.asking and SaveData.driver_asked, "back: passed over, not asked again")
	check(Settings.auto_gas, "the options left as they were")
	# A save from before (version 4) is a driver who has been playing
	TestSuite.use_scratch_save(SaveData)
	var cfg := ConfigFile.new()
	cfg.load("res://tests/fixtures/save_v4.cfg")
	cfg.save(TestSuite.SCRATCH_SAVE)
	SaveData.load_save()
	g.show_title()
	check(not g.menu.asking, "an older save: not asked")
	check(not SaveData.first_drive_pending(), "nor a first drive")
	WhosDriving.enabled = false
	g.show_title()
	_clean()
	g.show_title()
	check(not g.menu.asking, "onboarding off (the test runners): never asked")


func test_a_staged_screenshot_doesnt_ask() -> void:
	_clean()
	WhosDriving.enabled = true
	var g := _game()
	g.onboarding = false  # (as --menu-shot sets it)
	g.show_title()
	check(not g.menu.asking, "a menu shot: not asked")
	WhosDriving.enabled = false
	_clean()
