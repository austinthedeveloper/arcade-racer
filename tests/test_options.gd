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
	check(r.time_left > r.clock[0], "relaxed: more time (%.0f)" % r.time_left)
	check(r.checkpoint_bonus > r.clock[1], "and bigger bonuses")
	Settings.traffic = Settings.Traffic.HEAVY
	Settings.timer = Settings.Clock.TIGHT
	r.start_race()
	check(r.traffic.cars.size() > r.TRAFFIC_COUNT, "heavy traffic")
	check(r.time_left < r.clock[0], "tight: less time")
	_clean()
	r.start_race()
	eq([r.traffic.cars.size(), r.time_left, r.checkpoint_bonus], [r.TRAFFIC_COUNT, r.clock[0], r.clock[1]],
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


func test_options_on_a_wheel_use_its_dpad_like_a_pad() -> void:
	_clean()
	var keep := _as_device(DriveInput.Kind.WHEEL)
	check(not OptionsScreen.steer_driven(), "a wheel doesn't steer through the rows")
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	var a := MenuInput.new()
	a.confirm_pressed = true
	o.handle(a)
	check(Settings.auto_gas, "A on the first row turns auto gas on")
	var down := MenuInput.new()
	down.down_pressed = true
	o.handle(down)
	eq(o.row(), OptionsScreen.Row.TRAFFIC, "D-pad down goes down a row")
	var right := MenuInput.new()
	right.right_pressed = true
	o.handle(right)
	eq(o.row(), OptionsScreen.Row.TRAFFIC, "D-pad right stays on the row...")
	check(Settings.traffic != Settings.Traffic.NORMAL, "...and changes it")
	check(OptionsScreen.options_hints().begins_with("D-pad"), "pad hints on a wheel")
	var b := MenuInput.new()
	b.back_pressed = true
	o.handle(b)
	eq(g.screen, g.Screen.TITLE, "B: back to the title")
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


func test_radio_station_option_and_car_select_pick() -> void:
	_clean()
	var o := OptionsScreen.new()
	eq(OptionsScreen.value_text(OptionsScreen.Row.RADIO), "SHUFFLE", "shuffle by default")
	o.change(OptionsScreen.Row.RADIO, 1, true)
	eq(OptionsScreen.value_text(OptionsScreen.Row.RADIO), "ROCK", "then each station")
	o.change(OptionsScreen.Row.RADIO, -1, true)
	o.change(OptionsScreen.Row.RADIO, -1, true)
	eq(Settings.radio, Radio.count() - 1, "left from shuffle wraps to the last")
	Settings.load_settings()
	eq(Settings.radio, Radio.count() - 1, "saved")
	o.free()
	var c := CarSelect.new()
	var m := MenuInput.new()
	m.radio_pressed = true
	c.handle(m)
	eq(Settings.radio, Radio.SHUFFLE, "the radio button on car select steps the station")
	c.handle(m)
	eq(Settings.radio, 0, "and on")
	Settings.load_settings()
	eq(Settings.radio, 0, "saved there too")
	c.free()
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


func test_reset_save_on_an_unmapped_pad_cancels_on_steer() -> void:
	_fill_all_three()
	var keep := _as_device(DriveInput.Kind.GAMEPAD)
	InputRouter.state.mapped = false
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
	eq(o.row(), OptionsScreen.Row.RESTORE, "and moves on")
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
	eq(o.rows(), [OptionsScreen.Row.PAGE, OptionsScreen.Row.MUSIC, OptionsScreen.Row.SFX, OptionsScreen.Row.RADIO,
		OptionsScreen.Row.BACK], "Audio rows")
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
	eq(o.rows(), [OptionsScreen.Row.PAGE, OptionsScreen.Row.FULLSCREEN, OptionsScreen.Row.INTEGER_SCALE,
		OptionsScreen.Row.VSYNC, OptionsScreen.Row.SCANLINES, OptionsScreen.Row.UNITS, OptionsScreen.Row.BACK], "Display rows")
	o.handle(up)
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


func test_speed_units() -> void:
	_clean()
	eq(Settings.units, Settings.Units.MPH, "MPH by default")
	eq(Settings.speed_in(Cfg.MAX_SPEED, Settings.Units.MPH), roundi(Cfg.DISPLAY_TOP_SPEED), "top speed in mph")
	eq(Settings.speed_in(Cfg.MAX_SPEED, Settings.Units.KPH), roundi(Cfg.DISPLAY_TOP_SPEED * 1.609344), "in kph (319)")
	eq(Settings.speed_in(Cfg.MAX_SPEED * 0.5, Settings.Units.MPH), 99, "half")
	eq(Settings.speed_in(0.0, Settings.Units.KPH), 0, "standing")
	eq(Settings.speedometer(Cfg.MAX_SPEED), [198, "MPH"], "speedometer in MPH")
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.UNITS)
	eq(o.page, OptionsScreen.Page.DISPLAY, "on the Display page")
	o.change(OptionsScreen.Row.UNITS, 1, false)
	eq(OptionsScreen.value_text(OptionsScreen.Row.UNITS), "KPH", "shown")
	Settings.load_settings()
	eq(Settings.speedometer(Cfg.MAX_SPEED), [319, "KPH"], "saved, and the speedometer says KPH")
	o.change(OptionsScreen.Row.UNITS, 1, true)
	eq(Settings.units, Settings.Units.MPH, "confirm cycles back")
	o.free()
	_clean()


func test_display_options_round_trip() -> void:
	_clean()
	eq([Settings.fullscreen, Settings.integer_scale, Settings.vsync, Settings.scanlines], [false, false, true, false],
		"defaults: windowed, fractional, V-Sync on, no scanlines")
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.FULLSCREEN)
	eq(o.page, OptionsScreen.Page.DISPLAY, "on the Display page")
	eq(OptionsScreen.value_text(OptionsScreen.Row.FULLSCREEN), "WINDOWED", "shown windowed")
	for r in [OptionsScreen.Row.FULLSCREEN, OptionsScreen.Row.INTEGER_SCALE, OptionsScreen.Row.VSYNC, OptionsScreen.Row.SCANLINES]:
		check(o.change(r, 1, true), "%s changes" % OptionsScreen.LABELS[r])
	eq([OptionsScreen.value_text(OptionsScreen.Row.FULLSCREEN), OptionsScreen.value_text(OptionsScreen.Row.INTEGER_SCALE),
		OptionsScreen.value_text(OptionsScreen.Row.VSYNC), OptionsScreen.value_text(OptionsScreen.Row.SCANLINES)],
		["FULLSCREEN", "ON", "OFF", "ON"], "shown")
	Settings.reset()
	eq(Settings.fullscreen, false, "reset")
	Settings.load_settings()
	eq([Settings.fullscreen, Settings.integer_scale, Settings.vsync, Settings.scanlines], [true, true, false, true],
		"saved and loaded back")
	o.free()
	_clean()


func test_display_plan_follows_the_options() -> void:
	_clean()
	var plan: Dictionary = Settings.display_plan()
	eq([plan["window_mode"], plan["stretch"], plan["vsync"], plan["scanlines"]],
		[DisplayServer.WINDOW_MODE_WINDOWED, Window.CONTENT_SCALE_STRETCH_FRACTIONAL, DisplayServer.VSYNC_ENABLED, false],
		"defaults")
	Settings.fullscreen = true
	Settings.integer_scale = true
	Settings.vsync = false
	plan = Settings.display_plan()
	eq([plan["window_mode"], plan["stretch"], plan["vsync"]],
		[DisplayServer.WINDOW_MODE_FULLSCREEN, Window.CONTENT_SCALE_STRETCH_INTEGER, DisplayServer.VSYNC_DISABLED], "all on")
	_clean()


func test_applying_display_headless_leaves_the_window_alone() -> void:
	_clean()
	check(Settings.headless(), "the tests run headless")
	var mode := DisplayServer.window_get_mode()
	var stretch: int = runner.root.content_scale_stretch
	Settings.fullscreen = true
	Settings.integer_scale = true
	Settings.vsync = false
	Settings.scanlines = true
	Settings.save()
	eq(DisplayServer.window_get_mode(), mode, "window mode untouched")
	eq(runner.root.content_scale_stretch, stretch, "stretch untouched")
	if check(Settings.scanline_layer != null, "the scanline overlay is made"):
		check(Settings.scanline_layer.visible, "and shows")
		eq(Settings.scanline_layer.layer, Settings.SCANLINE_LAYER, "on top")
	_clean()
	check(Settings.scanline_layer == null or not Settings.scanline_layer.visible, "defaults hide it")


func test_view_rect_integer_and_fractional() -> void:
	var view := Vector2i(640, 360)
	eq(Settings.view_rect(Vector2i(1920, 1080), view, true), Rect2i(0, 0, 1920, 1080), "1080p: 3x either way")
	eq(Settings.view_rect(Vector2i(1920, 1080), view, false), Rect2i(0, 0, 1920, 1080), "fractional too")
	eq(Settings.view_rect(Vector2i(1600, 900), view, true), Rect2i(160, 90, 1280, 720), "900p: 2x with a border")
	eq(Settings.view_rect(Vector2i(1600, 900), view, false), Rect2i(0, 0, 1600, 900), "fractional fills it")
	eq(Settings.view_rect(Vector2i(1920, 929), view, true), Rect2i(320, 104, 1280, 720), "a short window: 2x")
	eq(Settings.view_rect(Vector2i(320, 180), view, true), Rect2i(-160, -90, 640, 360), "never under 1x")


## A saved wheel profile in the scratch profile file, for the wheel settings screen.
func _saved_wheel(guid := "03000000-wheel-options", wheel_name := "Test Wheel") -> DeviceProfile:
	var p := DeviceProfile.new()
	p.guid = guid
	p.name = wheel_name
	p.kind = DeviceProfile.Kind.WHEEL
	p.calibrated = true
	InputRouter.save_profile(p)
	return p


func test_wheel_settings_from_the_options_and_back() -> void:
	_clean()
	TestSuite.use_scratch_profiles(InputRouter)
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	o.go_to(OptionsScreen.Row.WHEEL)
	eq(o.page, OptionsScreen.Page.CONTROLS, "on the Controls page")
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	o.handle(confirm)
	eq(g.screen, g.Screen.WHEEL, "opens the wheel settings")
	var w: WheelScreen = g.menu
	eq(w.row(), WheelScreen.Row.RANGE, "on the first setting")
	check(w.profile() == null, "no wheel in a fresh profile file")
	eq(w.device_name(), "NO WHEEL FOUND", "and says so")
	eq(w.help_text(), WheelScreen.NO_WHEEL, "with how to get one")
	check(not w.change(WheelScreen.Row.RANGE, 1, false), "nothing to change")
	eq(WheelScreen.value_text(null, WheelScreen.Row.LOCK), "---", "no values")
	var back := MenuInput.new()
	back.back_pressed = true
	w.handle(back)
	eq(g.screen, g.Screen.OPTIONS, "back to the options")
	eq([g.menu.page, g.menu.row()], [OptionsScreen.Page.CONTROLS, OptionsScreen.Row.WHEEL], "on the wheel row")
	g._open("wheel")
	eq(g.screen, g.Screen.WHEEL, "--screen=wheel")
	InputRouter.state = keep
	TestSuite.use_scratch_profiles(InputRouter)
	_clean()


func test_wheel_settings_edit_and_save_with_keys() -> void:
	_clean()
	TestSuite.use_scratch_profiles(InputRouter)
	var keep := _as_device(DriveInput.Kind.KEYBOARD)
	var first := _saved_wheel()
	var second := _saved_wheel("03000000-wheel-two", "Other Wheel")
	var g := _game()
	g.show_wheel()
	var w: WheelScreen = g.menu
	eq(InputRouter.wheel_profiles().size(), 2, "both saved wheels")
	eq(w.device_name(), "TEST WHEEL (UNPLUGGED)", "a saved wheel that isn't plugged in")
	eq([WheelScreen.value_text(first, WheelScreen.Row.RANGE), WheelScreen.value_text(first, WheelScreen.Row.LOCK),
		WheelScreen.value_text(first, WheelScreen.Row.DEADZONE), WheelScreen.value_text(first, WheelScreen.Row.LINEARITY)],
		["900°", "360°", "1.5%", "1.0"], "the defaults")
	var left := MenuInput.new()
	left.left_pressed = true
	var right := MenuInput.new()
	right.right_pressed = true
	var down := MenuInput.new()
	down.down_pressed = true
	var up := MenuInput.new()
	up.up_pressed = true
	w.handle(left)
	eq(first.hardware_range_deg, 720.0, "left: less range")
	w.handle(down)
	w.handle(left)
	w.handle(left)
	eq(first.lock_deg, 300.0, "lock down two steps")
	w.handle(down)
	w.handle(right)
	near(first.steer_deadzone, 0.02, 0.0001, "deadzone up")
	w.handle(down)
	w.handle(right)
	w.handle(right)
	near(first.steer_gamma, 1.2, 0.0001, "linearity up two")
	eq(WheelScreen.value_text(first, WheelScreen.Row.LINEARITY), "1.2", "shown")
	eq(second.hardware_range_deg, 900.0, "the other wheel untouched")
	# Saved on every change: a fresh load has them
	InputRouter.load_profiles()
	var back: DeviceProfile = InputRouter._saved[first.guid]
	eq([back.hardware_range_deg, back.lock_deg], [720.0, 300.0], "range and lock saved")
	near(back.steer_deadzone, 0.02, 0.0001, "deadzone saved")
	near(back.steer_gamma, 1.2, 0.0001, "linearity saved")
	eq((InputRouter._saved[second.guid] as DeviceProfile).hardware_range_deg, 900.0, "and only on that wheel")
	# The device row flips to the other wheel; RESET puts this one back
	w.index = WheelScreen.Row.DEVICE
	w.handle(right)
	eq(w.device_name(), "OTHER WHEEL (UNPLUGGED)", "right on the wheel row: the next wheel")
	w.handle(right)
	w.index = WheelScreen.Row.RESET
	w.handle(right)
	eq(w.profile().hardware_range_deg, 720.0, "left/right don't reset")
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	w.handle(confirm)
	InputRouter.load_profiles()
	back = InputRouter._saved[first.guid]
	eq([back.hardware_range_deg, back.lock_deg, back.steer_gamma], [900.0, 360.0, 1.0], "reset, and saved")
	w.handle(down)
	eq(w.row(), WheelScreen.Row.BACK, "down to BACK")
	w.handle(confirm)
	eq(g.screen, g.Screen.OPTIONS, "BACK: the options")
	InputRouter.state = keep
	TestSuite.use_scratch_profiles(InputRouter)
	_clean()


func test_wheel_settings_on_an_unmapped_pad_steer_and_confirm() -> void:
	_clean()
	TestSuite.use_scratch_profiles(InputRouter)
	var keep := _as_device(DriveInput.Kind.GAMEPAD)
	InputRouter.state.mapped = false
	var p := _saved_wheel()
	var g := _game()
	g.show_wheel()
	var w: WheelScreen = g.menu
	var gas := MenuInput.new()
	gas.confirm_pressed = true
	w.handle(gas)
	eq(p.hardware_range_deg, 1080.0, "gas: the range up a step")
	var steer := MenuInput.new()
	steer.right_pressed = true
	w.handle(steer)
	eq([w.row(), p.lock_deg], [WheelScreen.Row.LOCK, 360.0], "steering picks the row and changes nothing")
	for i in 3:
		w.handle(gas)
	eq(p.lock_deg, 450.0, "gas: the lock up")
	p.lock_deg = p.hardware_range_deg
	w.handle(gas)
	eq(p.lock_deg, DeviceProfile.LOCK_MIN, "and round past the range")
	InputRouter.load_profiles()
	eq((InputRouter._saved[p.guid] as DeviceProfile).lock_deg, DeviceProfile.LOCK_MIN, "saved")
	var brake := MenuInput.new()
	brake.back_pressed = true
	g.menu.handle(brake)
	eq(g.screen, g.Screen.OPTIONS, "brake: back to the options")
	InputRouter.state = keep
	TestSuite.use_scratch_profiles(InputRouter)
	_clean()


func test_wheel_settings_curve() -> void:
	var p := DeviceProfile.new()
	p.steer_deadzone = 0.0
	var c := WheelScreen.curve(p, 10)
	eq(c.size(), 11, "a point per sample and the end")
	eq(c[0], Vector2.ZERO, "center: no steer")
	near(c[10].x, 450.0, 0.001, "out to half the range")
	near(c[4].y, 1.0, 0.001, "full steer at half the lock (180 of 450)")
	near(c[2].y, 0.5, 0.001, "linear on the way")
	p.steer_gamma = 2.0
	near(WheelScreen.curve(p, 10)[2].y, 0.25, 0.001, "gentler with more linearity")
	eq([WheelScreen.percent(0.015), WheelScreen.percent(0.2), WheelScreen.percent(0.0)], ["1.5%", "20%", "0%"], "percent")


func test_an_unmapped_pad_steers_through_options() -> void:
	# A wheel the game doesn't recognize by name is read as a pad without a gamepad layout:
	# it has no stick for up and down, so it steers through the rows like a wheel.
	_clean()
	var keep := _as_device(DriveInput.Kind.GAMEPAD)
	InputRouter.state.mapped = false
	check(OptionsScreen.steer_driven(), "steering picks the rows")
	check(OptionsScreen.options_hints().begins_with("Steer: choose"), "and the hints say so")
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	var start := o.row()
	var steer := MenuInput.new()
	steer.right_pressed = true
	o.handle(steer)
	eq(o.row(), start + 1, "steering right goes down a row")
	InputRouter.state.mapped = true
	check(not OptionsScreen.steer_driven(), "a mapped gamepad uses up and down")
	InputRouter.state = keep
	_clean()


func test_gears_option_saves_and_reaches_the_race() -> void:
	_clean()
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.GEARS)
	eq(o.page, OptionsScreen.Page.ACCESSIBILITY, "with the assists")
	eq(OptionsScreen.value_text(OptionsScreen.Row.GEARS), "AUTOMATIC", "automatic by default")
	o.change(OptionsScreen.Row.GEARS, 1, true)
	eq(OptionsScreen.value_text(OptionsScreen.Row.GEARS), "MANUAL", "manual")
	Settings.load_settings()
	check(Settings.manual_gears, "saved")
	o.in_race = true
	check(o.help_text().ends_with("From the next race."), "from the pause menu: the next race")
	var r := race(false, false)
	check(r.player.manual, "the race shifts by hand")
	o.free()
	_clean()
	r.start_race()
	check(not r.player.manual, "the default keeps the automatic (golden traces)")
