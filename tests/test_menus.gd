## Front end: menu input, the title / stage select / car select screens and the game flow.
extends TestSuite


static func menu_input(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()  # outside the tree, like TestSuite.new_race
	_nodes.append(g)
	return g


func test_axis_push_fires_once_then_repeats() -> void:
	var m := MenuInput.new()
	m.step_axis(0.8, DT)
	check(m.right_pressed and not m.left_pressed, "push right fires")
	var fired := 0
	for i in int(MenuInput.REPEAT_DELAY / DT) - 2:
		m.step_axis(0.8, DT)
		fired += int(m.right_pressed)
	eq(fired, 0, "no repeat before the delay")
	for i in 60:
		m.step_axis(0.8, DT)
		fired += int(m.right_pressed)
	check(fired >= 5 and fired <= 8, "repeats while held (%d in a second)" % fired)
	m.step_axis(0.0, DT)
	check(not m.right_pressed, "letting go fires nothing")
	m.step_axis(-1.0, DT)
	check(m.left_pressed, "push left fires")
	eq(m.step(), -1, "step is -1")


func test_axis_has_hysteresis() -> void:
	var m := MenuInput.new()
	m.step_axis(0.6, DT)
	check(m.right_pressed, "past PUSH presses")
	m.step_axis(0.4, DT)
	m.step_axis(0.6, DT)
	check(not m.right_pressed, "wobbling between RELEASE and PUSH (a wheel held over) doesn't re-press")
	m.step_axis(0.1, DT)
	m.step_axis(0.6, DT)
	check(m.right_pressed, "back under RELEASE, then out again, presses")
	m.step_axis(0.0, DT)
	m.step_axis(0.45, DT)
	check(not m.right_pressed, "a light touch doesn't press")


func test_stage_select_wraps_and_has_every_postcard() -> void:
	var s := StageSelect.new()
	eq(s.move(1), 1, "right")
	eq(s.move(-2), Stages.count() - 1, "left wraps to the last stage")
	eq(s.move(1), 0, "right wraps to the first")
	eq(Stages.POSTCARDS.size(), Stages.count(), "a postcard per stage")
	for i in Stages.count():
		check(ResourceLoader.exists(Stages.postcard(i)), "postcard for " + Stages.stage_name(i))
	s.free()


func test_car_select_lists_the_garage() -> void:
	var v := Cars.get_car(0)
	eq(v["name"], "Vega GT", "the Vega comes first")
	eq([v["accel"], v["top_speed"], v["handling"]], [4, 5, 3], "stats from the design doc")
	eq(Cars.get_car(99)["id"], Cars.get_car(Cars.count() - 1)["id"], "out of range clamps")
	var ids := {}
	for i in Cars.count():
		ids[Cars.get_car(i)["id"]] = true
	eq(ids.size(), Cars.count(), "ids are unique")
	var c := CarSelect.new()
	eq(c.move(1), 1, "right picks the next car")
	eq(c.move(-2), Cars.count() - 1, "left wraps to the last")
	c.free()


func test_prompts_follow_the_device() -> void:
	var keep: DriveInput = InputRouter.state
	var inp := DriveInput.new()
	InputRouter.state = inp
	eq(TitleScreen.start_prompt(), "PRESS ENTER", "keyboard")
	check(MenuScreen.hints(true).contains("Esc: back"), "keyboard hints")
	inp.kind = DriveInput.Kind.GAMEPAD
	eq(TitleScreen.start_prompt(), "PRESS START", "gamepad")
	check(MenuScreen.hints(true).contains("A: select"), "gamepad hints")
	inp.kind = DriveInput.Kind.WHEEL
	check(TitleScreen.start_prompt().contains("GAS"), "wheel")
	check(MenuScreen.hints(true).begins_with("Steer: choose"), "wheel hints")
	check(not MenuScreen.hints(false).contains("choose"), "no choose hint with nothing to choose")
	InputRouter.state = keep


func test_menus_flow_into_the_race_and_back() -> void:
	var g := _game()
	eq(g.screen, g.Screen.TITLE, "boots to the title")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back on the title does nothing")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.MODES, "confirm: mode select")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.STAGES, "confirm on GRAND TOUR: stage select")
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.CARS, "confirm: car select")
	eq(g.stage_index, 2, "picked stage 3")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.STAGES, "back: stage select")
	eq(g.menu.index, 2, "still on stage 3")
	g.menu.handle(menu_input(true))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.RACE, "confirm: race")
	check(g.menu == null, "menus gone")
	if not check(g.race != null, "race started"):
		return
	TestSuite.ready_all(g.race)
	eq(g.race.stage_index, 2, "on the chosen stage")
	eq(g.race.track.name, Stages.stage_name(2), "track built for it")
	eq(g.race.car_id, "car_vega", "in the chosen car")
	g.race.stage_index = 3  # as if the tour went on
	g.race.quit_requested.emit()
	eq(g.screen, g.Screen.TITLE, "quit: back to the title")
	check(g.race == null, "race dropped")
	g.menu.handle(menu_input(true))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.STAGES, "title, mode select, stage select")
	eq(g.menu.index, 3, "stage select opens where the tour got to")


func test_mode_select_lists_every_mode() -> void:
	var m := ModeSelect.new()
	eq(ModeSelect.LABELS.size(), ModeSelect.Item.size(), "a label per mode")
	eq(ModeSelect.HELP.size(), ModeSelect.Item.size(), "a help line per mode")
	eq(m.move(-1), ModeSelect.Item.OPTIONS, "left wraps to OPTIONS")
	eq(m.move(1), ModeSelect.Item.GRAND_TOUR, "right wraps to GRAND TOUR")
	eq(m.pick(), ModeSelect.Item.GRAND_TOUR, "GRAND TOUR can be picked")
	eq(m.notice_time, 0.0, "no notice for a built mode")
	m.index = ModeSelect.Item.SINGLE_RACE
	eq(m.pick(), ModeSelect.Item.SINGLE_RACE, "SINGLE RACE can be picked")
	for item: int in [ModeSelect.Item.TIME_ATTACK, ModeSelect.Item.FREE_DRIVE]:
		m.index = item
		check(not ModeSelect.available(item), "%s isn't built yet" % ModeSelect.LABELS[item])
		eq(m.pick(), -1, "so it can't be picked")
		check(m.notice.ends_with("coming soon") and m.notice_time > 0.0, "a notice instead: " + m.notice)
	m.index = ModeSelect.Item.OPTIONS
	eq(m.pick(), ModeSelect.Item.OPTIONS, "OPTIONS can be picked")
	m.free()


func test_mode_select_leads_on_and_back() -> void:
	var g := _game()
	g.show_mode_select()
	eq(g.menu.index, 0, "opens on GRAND TOUR")
	g.menu.handle(menu_input(false, false, -1))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.OPTIONS, "OPTIONS opens the options")
	g.menu.index = OptionsScreen.Row.BACK
	eq(g.menu.help_text(), "Back to mode select.", "BACK says where it goes")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.MODES, "back from them returns to mode select")
	eq(g.menu.index, ModeSelect.Item.OPTIONS, "on OPTIONS")
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.STAGES, "GRAND TOUR: stage select")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.MODES, "back from stage select: mode select")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back again: the title")
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.OPTIONS, "OPTIONS on the title still opens the options")
	g.menu.index = OptionsScreen.Row.BACK
	eq(g.menu.help_text(), "Back to the title screen.", "BACK says the title")
	check(not g.menu.help_text().contains("next race"), "no race to wait for")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "and those go back to the title")


func test_quitting_needs_the_pause_menu() -> void:
	var r := race(false, false)
	var quits := [0]
	r.quit_requested.connect(func() -> void: quits[0] += 1)
	var keep: MenuInput = InputRouter.menu
	InputRouter.menu = menu_input(false, true)
	drive(r, 1)
	eq(quits[0], 0, "back while racing doesn't quit (it's the brake on a wheel or pad)")
	var p := input()
	p.pause_pressed = true
	drive(r, 1, p)
	eq(quits[0], 0, "Esc pauses rather than quitting")
	check(r.paused, "paused")
	drive(r, 1)
	eq(quits[0], 0, "back while paused resumes rather than quitting")
	check(not r.paused, "resumed")
	InputRouter.menu = keep


func test_options_from_the_pause_menu_return_to_the_race() -> void:
	var g := _game()
	g.start_race()
	TestSuite.ready_all(g.race)
	var r: Node = g.race
	r.pause()
	check(r.pause_menu.has_options, "the game offers OPTIONS")
	r.pause_action(PauseMenu.Action.OPTIONS)
	eq(g.screen, g.Screen.OPTIONS, "the options open")
	check(g.race == r and r.paused, "over the paused race")
	g.menu.index = OptionsScreen.Row.POWER_UPS
	check(g.menu.help_text().ends_with("From the next race."), "says power-ups wait for the next race")
	g.menu.index = OptionsScreen.Row.BACK
	eq(g.menu.help_text(), "Back to the race.", "BACK goes back to the race")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.RACE, "back: the race again")
	check(g.menu == null, "no menu left")
	check(r.paused and r.pause_menu.visible, "paused, on its menu")
	r.pause_action(PauseMenu.Action.QUIT)
	eq(g.screen, g.Screen.TITLE, "QUIT TO TITLE: the title")
	check(g.race == null, "race dropped")


func test_single_race_runs_once_and_returns_to_the_menus() -> void:
	var g := _game()
	g.show_mode_select()
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.STAGES, "SINGLE RACE: stage select")
	eq(g.mode_index, ModeSelect.Item.SINGLE_RACE, "the mode is kept")
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(true))
	g.menu.handle(menu_input(true))
	if not check(g.race != null, "race started"):
		return
	check(not g.race.tour, "the race knows it's a Single Race")
	TestSuite.ready_all(g.race)
	g.race.race_over.emit()
	eq(g.screen, g.Screen.STAGES, "race over: back to stage select")
	check(g.race == null, "race dropped")
	eq(g.menu.index, 1, "on the stage just raced")
	g.menu.handle(menu_input(false, true))
	g.menu.handle(menu_input(false, false, -1))
	g.menu.handle(menu_input(true))
	g.menu.handle(menu_input(true))
	g.menu.handle(menu_input(true))
	check(g.race != null and g.race.tour, "GRAND TOUR races tour on")
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()


func test_only_the_grand_tour_tours() -> void:
	# Review on #114: modes other than Single Race defaulted to tour = true.
	var g := _game()
	for item in [ModeSelect.Item.SINGLE_RACE, ModeSelect.Item.TIME_ATTACK, ModeSelect.Item.FREE_DRIVE]:
		g.mode_index = item
		g.start_race()
		check(not g.race.tour, "%s: no tour" % ModeSelect.Item.keys()[item])
		TestSuite.ready_all(g.race)
		g.race.quit_requested.emit()
	g.mode_index = ModeSelect.Item.GRAND_TOUR
	g.start_race()
	check(g.race.tour, "GRAND TOUR tours")
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()
