## Options: the Settings autoload (saving, auto gas, traffic, timer, volumes) and the
## Options screen on every device.
extends TestSuite


## Every test leaves the options on their defaults, in the scratch file.
func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	return g


func _as_device(kind: DriveInput.Kind) -> DriveInput:
	var keep: DriveInput = InputRouter.state
	var inp := DriveInput.new()
	inp.kind = kind
	InputRouter.state = inp
	return keep


func test_defaults_and_round_trip() -> void:
	_clean()
	eq([Settings.auto_gas, Settings.traffic, Settings.timer, Settings.music_volume, Settings.sfx_volume],
		[false, Settings.Traffic.NORMAL, Settings.Clock.ARCADE, 10, 10], "defaults")
	check(Settings.path != "user://settings.cfg", "tests use a scratch file")
	Settings.auto_gas = true
	Settings.traffic = Settings.Traffic.LIGHT
	Settings.timer = Settings.Clock.RELAXED
	Settings.music_volume = 3
	Settings.sfx_volume = 0
	Settings.save()
	Settings.reset()
	eq(Settings.auto_gas, false, "reset")
	Settings.load_settings()
	eq([Settings.auto_gas, Settings.traffic, Settings.timer, Settings.music_volume, Settings.sfx_volume],
		[true, Settings.Traffic.LIGHT, Settings.Clock.RELAXED, 3, 0], "loaded back")
	_clean()


func test_bad_values_in_the_file_are_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("play", "traffic", 9)
	cfg.set_value("play", "timer", -3)
	cfg.set_value("audio", "music", 40)
	cfg.save(TestSuite.SCRATCH_SETTINGS)
	Settings.load_settings()
	eq(Settings.traffic, Settings.Traffic.HEAVY, "traffic")
	eq(Settings.timer, Settings.Clock.RELAXED, "timer")
	eq(Settings.music_volume, Settings.VOLUME_STEPS, "music")
	_clean()


func test_auto_gas_holds_the_throttle_until_braking() -> void:
	_clean()
	var inp := input(0.0, -0.4)
	inp.nitro_pressed = true
	check(Settings.drive_input(inp) == inp, "off: input untouched")
	Settings.auto_gas = true
	var out := Settings.drive_input(inp)
	eq(out.throttle, 1.0, "gas held")
	eq(out.steer, -0.4, "steering is the player's")
	check(out.nitro_pressed, "nitro passes through")
	eq(inp.throttle, 0.0, "the router's state isn't changed")
	out = Settings.drive_input(input(0.0, 0.0, 0.8))
	eq(out.throttle, 0.0, "braking lifts the gas")
	eq(out.brake, 0.8, "and brakes")
	_clean()


func test_auto_gas_copies_every_input_field() -> void:
	# Regression: auto gas copied a hand-written list of fields, so a new one would be dropped.
	_clean()
	Settings.auto_gas = true
	var inp := DriveInput.new()
	for prop in inp.get_property_list():
		if not prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		match typeof(inp.get(prop["name"])):
			TYPE_BOOL:
				inp.set(prop["name"], true)
			TYPE_FLOAT:
				inp.set(prop["name"], 0.01)  # under the brake threshold, so gas stays on
			TYPE_INT:
				inp.set(prop["name"], 2)
			TYPE_STRING:
				inp.set(prop["name"], "Test wheel")
	var out := Settings.drive_input(inp)
	for prop in inp.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["name"] != "throttle":
			eq(out.get(prop["name"]), inp.get(prop["name"]), "%s copied" % prop["name"])
	eq(out.throttle, 1.0, "gas held")
	_clean()


func test_one_input_overlay_across_the_menus_and_the_race() -> void:
	# Regression: an F1 overlay opened in the menus stayed up through the race, which had a
	# second overlay of its own that F1 toggled instead.
	var g := _game()
	g.debug_overlay.visible = true
	g.start_race()
	TestSuite.ready_all(g.race)
	check(g.race.debug_overlay == g.debug_overlay, "the race uses the game's overlay")
	check(g.race.calibration == g.calibration, "and its calibration wizard")
	eq(g.race.find_children("*", "InputDebugOverlay", true, false).size(), 0, "the race makes no second one")


func test_auto_gas_drives_the_race_and_brake_still_works() -> void:
	_clean()
	Settings.auto_gas = true
	var r := race(false, false, 0, false)  # an empty road: the field would box the car in
	drive(r, 260, input())
	eq(r.state, r.State.RACING, "racing")
	check(r.player.speed > Cfg.MAX_SPEED * 0.3, "car accelerates with no gas pressed")
	var fast: float = r.player.speed
	drive(r, 30, input(0.0, 0.0, 1.0))
	check(r.player.speed < fast * 0.8, "brake slows it")
	check(r.player.braking, "brake lights")
	_clean()


func test_traffic_and_timer_options_reach_the_race() -> void:
	_clean()
	Settings.traffic = Settings.Traffic.LIGHT
	Settings.timer = Settings.Clock.RELAXED
	var r := race(false, true)
	eq(r.traffic.cars.size(), roundi(r.TRAFFIC_COUNT * 0.5), "light traffic")
	check(r.time_left > r.START_TIME, "relaxed: more time (%.0f)" % r.time_left)
	check(r.checkpoint_bonus > r.CHECKPOINT_BONUS, "and bigger bonuses")
	Settings.traffic = Settings.Traffic.HEAVY
	Settings.timer = Settings.Clock.TIGHT
	r.start_race()
	check(r.traffic.cars.size() > r.TRAFFIC_COUNT, "heavy traffic")
	check(r.time_left < r.START_TIME, "tight: less time")
	_clean()
	r.start_race()
	eq([r.traffic.cars.size(), r.time_left, r.checkpoint_bonus], [r.TRAFFIC_COUNT, r.START_TIME, r.CHECKPOINT_BONUS],
		"defaults keep the tuned race (golden traces)")


func test_volumes_set_the_buses() -> void:
	_clean()
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	if not check(music >= 0 and sfx >= 0, "buses exist"):
		return
	near(AudioServer.get_bus_volume_db(music), 0.0, 0.01, "full volume is the authored mix")
	Settings.music_volume = 5
	Settings.sfx_volume = 0
	Settings.apply_volumes()
	near(AudioServer.get_bus_volume_db(music), -6.02, 0.05, "half is -6 dB")
	check(AudioServer.is_bus_mute(sfx), "0 mutes")
	_clean()
	check(not AudioServer.is_bus_mute(sfx), "unmuted again")


func test_menu_input_up_down_repeats() -> void:
	var m := MenuInput.new()
	m.step_axis_y(1.0, DT)
	check(m.down_pressed and not m.up_pressed, "push down fires")
	eq(m.step_y(), 1, "step_y")
	m.step_axis_y(1.0, DT)
	eq(m.step_y(), 0, "once")
	m.step_axis(0.8, DT)
	check(m.right_pressed, "x is separate from y")
	m.step_axis_y(0.0, DT)
	m.step_axis_y(-0.7, DT)
	eq(m.step_y(), -1, "up")


func test_options_rows_change_with_keys_and_pad() -> void:
	_clean()
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	var m := MenuInput.new()
	m.down_pressed = true
	o.handle(m)
	eq(o.row(), OptionsScreen.Row.TRAFFIC, "down: next row")
	m = MenuInput.new()
	m.right_pressed = true
	o.handle(m)
	eq(Settings.traffic, Settings.Traffic.HEAVY, "right: more traffic")
	o.handle(m)
	eq(Settings.traffic, Settings.Traffic.HEAVY, "left/right stops at the end")
	m = MenuInput.new()
	m.confirm_pressed = true
	o.handle(m)
	eq(Settings.traffic, Settings.Traffic.LIGHT, "confirm cycles round")
	m = MenuInput.new()
	m.up_pressed = true
	o.handle(m)
	o.handle(m)
	eq(o.row(), OptionsScreen.Row.PAGE, "up from the first option: the page bar")
	o.handle(m)
	eq(o.row(), OptionsScreen.Row.BACK, "up from the page bar wraps to BACK")
	var cfg := ConfigFile.new()
	eq(cfg.load(Settings.path), OK, "saved on change")
	eq(cfg.get_value("play", "traffic"), Settings.Traffic.LIGHT, "saved value")
	InputRouter.state = keep
	_clean()


func test_options_on_a_wheel_steer_and_gas() -> void:
	_clean()
	var keep := _as_device(DriveInput.Kind.WHEEL)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	var gas := MenuInput.new()
	gas.confirm_pressed = true
	o.handle(gas)
	check(Settings.auto_gas, "gas on the first row turns auto gas on")
	var steer := MenuInput.new()
	steer.right_pressed = true
	o.handle(steer)
	eq(o.row(), OptionsScreen.Row.TRAFFIC, "steering right goes down a row")
	eq(Settings.traffic, Settings.Traffic.NORMAL, "and doesn't change the value")
	var left := MenuInput.new()
	left.left_pressed = true
	o.handle(left)
	o.handle(left)
	eq(o.row(), OptionsScreen.Row.PAGE, "steering left up to the page bar")
	for i in OptionsScreen.Page.CONTROLS:
		o.handle(gas)
	eq(o.page, OptionsScreen.Page.CONTROLS, "gas on the page bar flips pages")
	o.handle(steer)
	eq(o.row(), OptionsScreen.Row.CALIBRATE, "on calibrate")
	o.handle(gas)
	check(g.calibration.visible, "gas opens the wheel calibration")
	g.calibration.visible = false
	check(OptionsScreen.options_hints().begins_with("Steer: choose"), "wheel hints")
	var brake := MenuInput.new()
	brake.back_pressed = true
	o.handle(brake)
	eq(g.screen, g.Screen.TITLE, "brake: back to the title")
	eq(g.menu.index, 1, "on OPTIONS")
	InputRouter.state = keep
	_clean()


func test_title_reaches_options_and_back() -> void:
	_clean()
	var g := _game()
	var m := MenuInput.new()
	m.right_pressed = true
	g.menu.handle(m)
	eq(g.menu.index, 1, "right: OPTIONS")
	m = MenuInput.new()
	m.confirm_pressed = true
	g.menu.handle(m)
	eq(g.screen, g.Screen.OPTIONS, "confirm: options")
	g.menu.go_to(OptionsScreen.Row.BACK)
	g.menu.handle(m)
	eq(g.screen, g.Screen.TITLE, "BACK row: title")
	m = MenuInput.new()
	m.left_pressed = true
	g.menu.handle(m)
	m = MenuInput.new()
	m.confirm_pressed = true
	g.menu.handle(m)
	eq(g.screen, g.Screen.MODES, "START: mode select")
	eq(OptionsScreen.LABELS.size(), OptionsScreen.Row.size(), "a label per row")
	eq(OptionsScreen.HELP.size(), OptionsScreen.Row.size(), "help per row")
	_clean()


func test_power_ups_option_saves() -> void:
	var o := OptionsScreen.new()
	eq(OptionsScreen.value_text(OptionsScreen.Row.POWER_UPS), "ON", "on by default")
	o.change(OptionsScreen.Row.POWER_UPS, 1, true)
	check(not Settings.power_ups, "toggled off")
	Settings.load_settings()
	check(not Settings.power_ups, "saved off")
	o.change(OptionsScreen.Row.POWER_UPS, 1, true)
	check(Settings.power_ups, "back on")
	o.free()


func test_difficulty_saves_and_sets_the_timer() -> void:
	_clean()
	var o := OptionsScreen.new()
	eq(OptionsScreen.value_text(OptionsScreen.Row.DIFFICULTY), "NORMAL", "normal by default")
	o.change(OptionsScreen.Row.DIFFICULTY, 1, false)
	eq(Settings.difficulty, Difficulty.Level.HARD, "harder")
	eq(Settings.timer, Settings.Clock.TIGHT, "hard puts the timer on tight")
	o.change(OptionsScreen.Row.TIMER, -1, false)
	eq(Settings.timer, Settings.Clock.ARCADE, "the timer can still be changed")
	Settings.load_settings()
	eq(Settings.difficulty, Difficulty.Level.HARD, "saved")
	eq(Settings.timer, Settings.Clock.ARCADE, "and the timer kept")
	o.change(OptionsScreen.Row.DIFFICULTY, -1, false)
	o.change(OptionsScreen.Row.DIFFICULTY, -1, false)
	eq(Settings.timer, Settings.Clock.RELAXED, "easy relaxes it")
	o.free()
	_clean()


func test_difficulty_reaches_the_race() -> void:
	_clean()
	Settings.difficulty = Difficulty.Level.EASY
	var easy := race(false, false)
	Settings.difficulty = Difficulty.Level.HARD
	var hard := race(false, false)
	check(easy.rivals.cars[0].base_top < hard.rivals.cars[0].base_top, "slower rivals on easy")
	_clean()


## The scratch options, save and wheel profiles, each with something non-default in it.
func _fill_all_three() -> void:
	_clean_all()
	Settings.traffic = Settings.Traffic.HEAVY
	Settings.music_volume = 4
	Settings.save()
	SaveData.record_finish(0, "car_vega", 70.0)
	var cfg := ConfigFile.new()
	cfg.set_value("test-wheel-guid", "steer_deadzone", 0.2)
	cfg.save(TestSuite.SCRATCH_PROFILES)
	InputRouter.load_profiles()


func _clean_all() -> void:
	_clean()
	TestSuite.use_scratch_save(SaveData)
	TestSuite.use_scratch_profiles(InputRouter)


static func _file(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_reset_options_leaves_save_and_profiles() -> void:
	_fill_all_three()
	var save_before := _file(TestSuite.SCRATCH_SAVE)
	var profiles_before := _file(TestSuite.SCRATCH_PROFILES)
	check(profiles_before != "" and save_before != "", "files written")
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	o.go_to(OptionsScreen.Row.RESET_OPTIONS)
	var m := MenuInput.new()
	m.confirm_pressed = true
	o.handle(m)
	eq([Settings.traffic, Settings.music_volume], [Settings.Traffic.NORMAL, 10], "options back to defaults")
	Settings.load_settings()
	eq([Settings.traffic, Settings.music_volume], [Settings.Traffic.NORMAL, 10], "and saved")
	eq(o.row_text(OptionsScreen.Row.RESET_OPTIONS), "DONE", "shows it ran")
	eq(_file(TestSuite.SCRATCH_SAVE), save_before, "save file untouched")
	eq(SaveData.best(0, "car_vega")["time"], 70.0, "best time kept")
	eq(_file(TestSuite.SCRATCH_PROFILES), profiles_before, "profiles file untouched")
	o.move(1)
	eq(o.row_text(OptionsScreen.Row.RESET_OPTIONS), "", "DONE goes when the cursor moves")
	InputRouter.state = keep
	_clean_all()


func test_reset_save_asks_then_leaves_options_and_profiles() -> void:
	_fill_all_three()
	var settings_before := _file(TestSuite.SCRATCH_SETTINGS)
	var profiles_before := _file(TestSuite.SCRATCH_PROFILES)
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	o.go_to(OptionsScreen.Row.RESET_SAVE)
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	o.handle(confirm)
	check(o.confirming, "the first select asks")
	eq(o.row_text(OptionsScreen.Row.RESET_SAVE), "SURE?", "shown on the row")
	eq(SaveData.best(0, "car_vega")["time"], 70.0, "nothing erased yet")
	var back := MenuInput.new()
	back.back_pressed = true
	o.handle(back)
	check(not o.confirming, "back cancels")
	eq(g.screen, g.Screen.OPTIONS, "and stays on the options")
	o.handle(confirm)
	var right := MenuInput.new()
	right.right_pressed = true
	o.handle(right)
	check(not o.confirming, "left/right cancels")
	eq(SaveData.best(0, "car_vega")["time"], 70.0, "still nothing erased")
	o.handle(confirm)
	o.handle(confirm)
	check(not o.confirming, "the second select erases")
	eq([SaveData.bests.size(), SaveData.furthest_stage], [0, 0], "save reset")
	SaveData.load_save()
	eq([SaveData.bests.size(), SaveData.furthest_stage], [0, 0], "and written")
	eq(o.row_text(OptionsScreen.Row.RESET_SAVE), "DONE", "shows it ran")
	eq(_file(TestSuite.SCRATCH_SETTINGS), settings_before, "options file untouched")
	eq([Settings.traffic, Settings.music_volume], [Settings.Traffic.HEAVY, 4], "options kept")
	eq(_file(TestSuite.SCRATCH_PROFILES), profiles_before, "profiles file untouched")
	InputRouter.state = keep
	_clean_all()


func test_reset_save_on_a_wheel_cancels_on_steer() -> void:
	_fill_all_three()
	var keep := _as_device(DriveInput.Kind.WHEEL)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	o.go_to(OptionsScreen.Row.RESET_SAVE)
	var gas := MenuInput.new()
	gas.confirm_pressed = true
	o.handle(gas)
	check(o.confirming, "gas asks")
	var steer := MenuInput.new()
	steer.right_pressed = true
	o.handle(steer)
	check(not o.confirming, "steering away cancels")
	eq(o.row(), OptionsScreen.Row.BACK, "and moves on")
	eq(SaveData.bests.size(), 1, "nothing erased")
	o.go_to(OptionsScreen.Row.RESET_SAVE)
	o.handle(gas)
	o.handle(gas)
	eq(SaveData.bests.size(), 0, "gas twice erases")
	InputRouter.state = keep
	_clean_all()


func test_option_pages() -> void:
	_clean()
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	eq([o.page, o.row()], [OptionsScreen.Page.GAME, OptionsScreen.Row.AUTO_GAS], "opens on Game, first option")
	var up := MenuInput.new()
	up.up_pressed = true
	o.handle(up)
	var right := MenuInput.new()
	right.right_pressed = true
	var left := MenuInput.new()
	left.left_pressed = true
	o.handle(right)
	eq(o.page, OptionsScreen.Page.DISPLAY, "right on the page bar: next page")
	eq(o.row(), OptionsScreen.Row.PAGE, "still on the page bar")
	eq(Settings.auto_gas, false, "no option changed")
	o.handle(right)
	eq(o.rows(), [OptionsScreen.Row.PAGE, OptionsScreen.Row.MUSIC, OptionsScreen.Row.SFX, OptionsScreen.Row.BACK], "Audio rows")
	var down := MenuInput.new()
	down.down_pressed = true
	o.handle(down)
	o.handle(left)
	eq(Settings.music_volume, 9, "left on a volume row turns it down")
	o.handle(up)
	o.handle(left)
	o.handle(left)
	o.handle(left)
	eq(o.page, OptionsScreen.Page.ACCESSIBILITY, "left from Game wraps to the last page")
	o.handle(right)
	eq(o.page, OptionsScreen.Page.GAME, "and right wraps back")
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	o.handle(confirm)
	eq(o.page, OptionsScreen.Page.DISPLAY, "confirm on the page bar: next page")
	eq(o.rows(), [OptionsScreen.Row.PAGE, OptionsScreen.Row.BACK], "an empty page still has BACK")
	o.handle(down)
	o.handle(confirm)
	eq(g.screen, g.Screen.TITLE, "BACK from any page")
	InputRouter.state = keep
	_clean()


func test_every_row_is_on_one_page() -> void:
	var seen := {}
	for p in OptionsScreen.Page.size():
		for r in OptionsScreen.PAGE_ROWS[p]:
			check(not seen.has(r), "%s on one page" % OptionsScreen.LABELS[r])
			seen[r] = p
	for r in OptionsScreen.Row.size():
		if r != OptionsScreen.Row.PAGE and r != OptionsScreen.Row.BACK:
			check(seen.has(r), "%s has a page" % OptionsScreen.LABELS[r])
	eq(OptionsScreen.PAGE_NAMES.size(), OptionsScreen.Page.size(), "a name per page")
	eq(OptionsScreen.PAGE_EMPTY.size(), OptionsScreen.Page.size(), "an empty note per page")
	for p in OptionsScreen.Page.size():
		check(OptionsScreen.PAGE_ROWS[p].size() + 2 <= OptionsScreen.SLOTS, "%s fits the panel" % OptionsScreen.PAGE_NAMES[p])
		eq(OptionsScreen.page_named(OptionsScreen.PAGE_NAMES[p].to_lower()), p, "page_named")
	eq(OptionsScreen.page_named("nope"), -1, "unknown page")
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.SFX)
	eq([o.page, o.row()], [OptionsScreen.Page.AUDIO, OptionsScreen.Row.SFX], "go_to finds the page")
	o.free()


func test_screen_flag_opens_a_page() -> void:
	var g := _game()
	g._open("options:controls")
	var o: OptionsScreen = g.menu
	eq([g.screen, o.page, o.row()], [g.Screen.OPTIONS, OptionsScreen.Page.CONTROLS, OptionsScreen.Row.PAGE], "options:controls")
