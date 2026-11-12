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


func test_stage_select_map_places_every_postcard() -> void:
	check(ResourceLoader.exists(StageSelect.MAP), "the country map")
	eq(StageSelect.PINS.size(), Stages.count(), "a pin per stage")
	eq(StageSelect.CARD_ABOVE.size(), Stages.count(), "a postcard side per stage")
	var map := Rect2(0, 40, Cfg.SCREEN_W, StageSelect.BAND.position.y - 40)  # under the header, over the band
	check(map.encloses(StageSelect.BIG), "the big postcard on the map")
	for i in Stages.count():
		var name := Stages.stage_name(i)
		var r := StageSelect.card_rect(i)
		check(map.encloses(r), "postcard on the map: " + name)
		check(map.has_point(StageSelect.pin(i)), "pin on the map: " + name)
		check(not r.has_point(StageSelect.pin(i)), "postcard beside its pin, not over it: " + name)
		check(not r.intersects(StageSelect.BIG), "postcard clear of the big one: " + name)
		for j in Stages.count():
			check(not StageSelect.BIG.has_point(StageSelect.pin(j)), "big postcard clear of pin %d" % (j + 1))
			if j != i:
				check(not r.intersects(StageSelect.card_rect(j)), "postcards %d and %d apart" % [i + 1, j + 1])
				check(not r.grow(2).has_point(StageSelect.pin(j)), "postcard %d clear of pin %d" % [i + 1, j + 1])


func test_stage_select_steps_along_the_tour_route() -> void:
	# Right steps east along the route in tour order, the way the wheel turns.
	var s := StageSelect.new()
	for i in Stages.count() - 1:
		eq(s.move(1), i + 1, "right: the next stage on the route")
	check(StageSelect.pin(Stages.count() - 1).x > StageSelect.pin(0).x + 400, "the tour crosses the country west to east")
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
	eq(TitleScreen.start_prompt(), "PRESS A", "wheel: its buttons, not the gas")
	check(MenuScreen.hints(true).begins_with("D-pad: choose"), "a wheel's hints are a pad's")
	check(not MenuScreen.hints(false).contains("choose"), "no choose hint with nothing to choose")
	InputRouter.state = keep


func test_menus_flow_into_the_race_and_back() -> void:
	SaveData.furthest_stage = 3  # stage 3 reached (Unlocks)
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
	SaveData.furthest_stage = 0


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
	m.index = ModeSelect.Item.TIME_ATTACK
	eq(m.pick(), ModeSelect.Item.TIME_ATTACK, "TIME ATTACK can be picked")
	m.index = ModeSelect.Item.FREE_DRIVE
	eq(m.pick(), ModeSelect.Item.FREE_DRIVE, "FREE DRIVE can be picked")
	eq(m.notice_time, 0.0, "every mode is built: no coming-soon notices")
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
	g.menu.go_to(OptionsScreen.Row.BACK)
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
	g.menu.go_to(OptionsScreen.Row.BACK)
	eq(g.menu.help_text(), "Back to the title screen.", "BACK says the title")
	check(not g.menu.help_text().contains("next race"), "no race to wait for")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "and those go back to the title")


func test_stats_on_the_title_opens_the_stats_page_and_back() -> void:
	var g := _game()
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(false, false, 1))
	g.menu.handle(menu_input(false, false, 1))
	eq(TitleScreen.items()[g.menu.index], "STATS", "three right: STATS")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.STATS, "the stats page")
	check(g.menu is StatsScreen, "drawn by StatsScreen")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back: the title")
	eq(TitleScreen.items()[g.menu.index], "STATS", "on STATS")


func test_quit_on_the_title_closes_the_game() -> void:
	eq(TitleScreen.items(false), ["START", "OPTIONS", "CONTROLS", "STATS", "PROFILE", "CREDITS", "QUIT"], "START, OPTIONS, CONTROLS, STATS, PROFILE, CREDITS, QUIT")
	eq(TitleScreen.items(true), ["START", "OPTIONS", "CONTROLS", "STATS", "PROFILE", "CREDITS"], "no QUIT in a browser")
	var g := _game()
	var quits := [0]
	g.on_quit = func() -> void: quits[0] += 1
	g.menu.handle(menu_input(false, false, -1))
	if not OS.has_feature("web"):
		eq(TitleScreen.items()[g.menu.index], "QUIT", "left from START wraps to QUIT")
		g.menu.handle(menu_input(true))
		eq(quits[0], 1, "QUIT quits")
	eq(g.screen, g.Screen.TITLE, "nothing else happens")


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
	g.menu.go_to(OptionsScreen.Row.POWER_UPS)
	check(g.menu.help_text().ends_with("From the next race."), "says power-ups wait for the next race")
	g.menu.go_to(OptionsScreen.Row.BACK)
	eq(g.menu.help_text(), "Back to the race.", "BACK goes back to the race")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.RACE, "back: the race again")
	check(g.menu == null, "no menu left")
	check(r.paused and r.pause_menu.visible, "paused, on its menu")
	r.pause_action(PauseMenu.Action.QUIT)
	eq(g.screen, g.Screen.TITLE, "QUIT TO TITLE: the title")
	check(g.race == null, "race dropped")


func test_single_race_runs_once_and_returns_to_the_menus() -> void:
	SaveData.furthest_stage = 1  # stage 2 open (Unlocks)
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
	SaveData.furthest_stage = 0


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


static func _menu_y(dir: int) -> MenuInput:
	var m := MenuInput.new()
	m.up_pressed = dir < 0
	m.down_pressed = dir > 0
	return m


# MP-10: PROFILE on the title opens the driver picker; an empty slot is named and made,
# then drives, and the title says who is driving.
func test_profile_on_the_title_picks_who_is_driving() -> void:
	TestSuite.use_scratch_save(SaveData)
	SaveData.record_finish(0, "car_vega", 70.0, 1)
	var g := _game()
	eq(TitleScreen.driver_text(), ["DRIVER  P1", SaveData.NAMES[0]] as Array[String], "profile 1 driving")
	g.menu.index = TitleScreen.items().find("PROFILE")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.PROFILES, "the driver picker")
	var p: ProfileScreen = g.menu
	eq([p.row(), p.card], [ProfileScreen.Row.CARDS, 0], "on the cards, at the driver")
	p.handle(menu_input(false, false, 1))
	eq(p.card, 1, "right: the next slot")
	check(not SaveData.has_profile(1), "empty")
	eq(p.identity(1)["name"], SaveData.names_free_for(1)[0], "offered a name no one has")
	p.handle(_menu_y(1))
	eq(p.row(), ProfileScreen.Row.NAME, "down: NAME")
	p.handle(menu_input(false, false, 1))
	var picked: String = p.identity(1)["name"]
	eq(picked, SaveData.names_free_for(1)[1], "right: the next free name")
	p.handle(_menu_y(1))
	p.handle(menu_input(false, false, -1))
	eq(p.identity(1)["avatar"], Cars.LIST[0]["id"], "AVATAR left: the car before")
	check(not SaveData.has_profile(1), "nothing made yet")
	p.handle(_menu_y(-1))
	p.handle(_menu_y(-1))
	p.handle(menu_input(true))
	eq(g.screen, g.Screen.TITLE, "select: back to the title")
	eq(TitleScreen.items()[g.menu.index], "PROFILE", "on PROFILE")
	eq([SaveData.slot, SaveData.profile_name, SaveData.avatar], [1, picked, Cars.LIST[0]["id"]], "the new driver driving")
	eq(SaveData.bests.size(), 0, "on a save of their own")
	eq(TitleScreen.driver_text(), ["DRIVER  P2", picked] as Array[String], "and the title says so")
	g.show_profiles()
	g.menu.handle(menu_input(false, false, -1))
	g.menu.handle(menu_input(true))
	eq([SaveData.slot, SaveData.best(0, "car_vega")["time"]], [0, 70.0], "back to profile 1, its progress there")
	g.show_profiles()
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back leaves it as it was")
	eq(SaveData.slot, 0, "still profile 1")
	TestSuite.use_scratch_save(SaveData)
	TestSuite.use_scratch_ghosts()
