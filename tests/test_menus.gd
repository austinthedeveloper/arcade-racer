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


# --- Attract mode -------------------------------------------------------------------

func test_attract_rotates_through_stages_and_cars() -> void:
	eq(Attract.pick(0), {"stage": 0, "car": 0}, "the first demo: stage 1, the first car")
	eq(Attract.pick(1), {"stage": 1 % Stages.count(), "car": 1 % Cars.count()}, "the next demo: the next of each")
	eq(Attract.pick(Stages.count())["stage"], 0, "stages wrap round")
	eq(Attract.pick(Cars.count())["car"], 0, "cars wrap round")
	var seen := {}
	for n in Stages.count():
		seen[Attract.pick(n)["stage"]] = true
	eq(seen.size(), Stages.count(), "every stage gets a demo")


func test_attract_counts_any_control_as_input() -> void:
	var m := MenuInput.new()
	check(not Attract.is_input(input(), m), "nothing held: no input")
	check(not Attract.is_input(input(0.1, 0.1, 0.1), m), "a resting axis isn't input")
	check(Attract.is_input(input(1.0), m), "gas")
	check(Attract.is_input(input(0.0, -0.8), m), "steering")
	check(Attract.is_input(input(0.0, 0.0, 0.6), m), "brake")
	var d := input()
	d.nitro_pressed = true
	check(Attract.is_input(d, m), "nitro")
	check(Attract.is_input(input(), menu_input(false, true)), "menu back")
	check(Attract.is_input(input(), menu_input(false, false, 1)), "menu right")
	var k := InputEventKey.new()
	k.keycode = KEY_Q  # a key the input map doesn't use
	k.pressed = true
	check(Attract.is_wake_event(k), "any key press")
	k.echo = true
	check(not Attract.is_wake_event(k), "not a key repeat")
	k.echo = false
	k.pressed = false
	check(not Attract.is_wake_event(k), "not a release")
	var b := InputEventJoypadButton.new()
	b.pressed = true
	check(Attract.is_wake_event(b), "a joypad button")
	var ax := InputEventJoypadMotion.new()
	ax.axis_value = 1.0
	check(not Attract.is_wake_event(ax), "not a raw joypad axis (pedals can rest at full travel)")


## Game ticks with this input (none by default) from every device.
func _idle_ticks(g: Node, ticks: int, inp: DriveInput = null, m: MenuInput = null) -> void:
	var router: Node = runner.root.get_node("InputRouter")
	var keep: Array = [router.state, router.menu]
	router.state = inp if inp != null else input()
	router.menu = m if m != null else MenuInput.new()
	for i in ticks:
		g._physics_process(DT)
	router.state = keep[0]
	router.menu = keep[1]


func test_an_idle_title_starts_a_demo() -> void:
	var g := _game()
	eq(g.attract_delay, Attract.IDLE_SECONDS, "the delay defaults to IDLE_SECONDS")
	g.attract_delay = 1.0
	g.stage_index = 2
	g.calibration.visible = false  # (its _ready hides it; the game here is outside the tree)
	_idle_ticks(g, 30)
	eq(g.screen, g.Screen.TITLE, "half the delay: still the title")
	_idle_ticks(g, 20, input(1.0))
	eq(g.idle, 0.0, "input on the title starts the wait over")
	_idle_ticks(g, 58)
	eq(g.screen, g.Screen.TITLE, "not quite the delay")
	_idle_ticks(g, 3)
	eq(g.screen, g.Screen.RACE, "the delay: a race")
	if not check(g.race != null and g.race.demo, "a demo race"):
		return
	eq(g.race.stage_index, 0, "the first demo is stage 1")
	check(not g.race.tour, "a demo doesn't go on to the next stage")
	TestSuite.ready_all(g.race)
	_idle_ticks(g, 5)
	check(g.is_demo(), "no input: the demo goes on")
	_idle_ticks(g, 1, input(0.0, 1.0))
	eq(g.screen, g.Screen.TITLE, "steering: back to the title")
	check(g.race == null, "demo dropped")
	eq(g.stage_index, 2, "the player's stage pick is untouched")
	_idle_ticks(g, 1, input(), menu_input(true))
	eq(g.screen, g.Screen.TITLE, "the press that ended the demo doesn't pick START")
	_idle_ticks(g, 70)
	if not check(g.is_demo(), "idle again: another demo"):
		return
	eq(g.race.stage_index, 1 % Stages.count(), "on the next stage")
	eq(g.race.car_id, Cars.get_car(1 % Cars.count())["id"], "in the next car")


func test_any_key_ends_a_demo() -> void:
	var g := _game()
	g.start_demo()
	TestSuite.ready_all(g.race)
	var k := InputEventKey.new()
	k.keycode = KEY_Q
	k.pressed = true
	g._input(k)
	eq(g.screen, g.Screen.TITLE, "a key: the title")
	check(g.race == null, "demo dropped")


func test_a_demo_that_runs_out_goes_back_to_the_title() -> void:
	var g := _game()
	g.start_demo()
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()  # (the race emits it when the demo is over)
	eq(g.screen, g.Screen.TITLE, "the title")
	check(g.race == null, "demo dropped")
	eq(g.stage_index, 0, "the player's stage pick is untouched")
