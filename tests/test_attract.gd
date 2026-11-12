## Attract mode (PR-11) and its tour (PR-20): the demos left on the title, one stage and car
## after another with a title card each, the controls card once a loop (Attract, game.gd).
extends TestSuite


static func menu_input(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


func _game() -> Node:
	TestSuite.use_scratch_save(SaveData)
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()  # outside the tree, like TestSuite.new_race
	_nodes.append(g)
	return g


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


func test_a_loop_is_every_stage_with_the_controls_after_the_first() -> void:
	var cars: Array[int] = [0, 1, 2]
	var loop := Attract.loop_steps(0, 4, cars)
	eq(loop, [
		{"kind": Attract.Step.RACE, "stage": 0, "car": 0},
		{"kind": Attract.Step.CONTROLS},
		{"kind": Attract.Step.RACE, "stage": 1, "car": 1},
		{"kind": Attract.Step.RACE, "stage": 2, "car": 2},
		{"kind": Attract.Step.RACE, "stage": 3, "car": 0},
	], "four stages in order, the cars in turn, the controls once after the first race")
	eq(Attract.loop_length(4), 5, "a race a stage and the controls")
	var next := Attract.loop_steps(1, 4, cars)
	eq([next[0]["stage"], next[0]["car"]], [0, 1], "the next loop: stage 1 again, the cars carrying on")
	eq(next[1]["kind"], Attract.Step.CONTROLS, "the controls again, once")
	eq(Attract.step(5, 4, cars), next[0], "step counts on across loops")
	check(Attract.ends_loop(4, 4) and Attract.ends_loop(9, 4), "a loop's last step")
	check(not Attract.ends_loop(0, 4) and not Attract.ends_loop(5, 4), "not the others")


func test_the_real_tour_shows_every_stage_and_car() -> void:
	var cars := Attract.tour_cars(true)
	eq(cars.size(), Cars.count(), "every car once the secret is found")
	var hidden := Attract.tour_cars(false)
	eq(hidden.size(), Cars.count() - 1, "the secret car kept back until then")
	for i in hidden:
		check(Cars.get_car(i)["id"] != Unlocks.SECRET_CAR, "no secret in the tour: " + Cars.get_car(i)["id"])
	var stages := {}
	var seen := {}
	var controls := 0
	for loop in Cars.count():  # enough loops for the cars to come round
		var steps := Attract.loop_steps(loop, Stages.count(), cars)
		controls += steps.filter(func(s: Dictionary) -> bool: return s["kind"] == Attract.Step.CONTROLS).size()
		for s in steps:
			if s["kind"] == Attract.Step.RACE:
				stages[s["stage"]] = true
				seen[s["car"]] = true
	eq(stages.size(), Stages.count(), "every stage")
	eq(seen.size(), cars.size(), "every car comes round")
	eq(controls, Cars.count(), "the controls once a loop")


func test_the_title_card_says_the_stage_and_the_car() -> void:
	var t := Attract.card_text(2, "car_mesa")
	eq(t["tag"], "STAGE 3 OF %d" % Stages.count(), "which stage of the tour")
	eq(t["stage"], Stages.stage_name(2).to_upper(), "its name")
	eq(t["car"], "MESA RUMBLER", "the car")
	eq(t["kind"], String(Cars.find("car_mesa")["archetype"]).to_upper(), "what it is")
	for i in Stages.count():  # the longest words fit the card
		check(UiText.width(Stages.stage_name(i).to_upper(), 16) <= Attract.CARD.size.x - 20, "fits: " + Stages.stage_name(i))
	for car: Dictionary in Cars.LIST:
		var w := Attract.card_text(0, car["id"])
		check(UiText.width(w["car"], 11) <= Attract.CARD.size.x - 20, "fits: " + w["car"])
		check(UiText.width(w["kind"], 8) <= Attract.CARD.size.x - 20, "fits: " + w["kind"])


func test_the_title_card_slides_in_holds_and_goes() -> void:
	eq(Attract.card_rect(-0.1), Rect2(), "not before the demo")
	check(Attract.card_rect(0.05).position.x < Attract.CARD.position.x, "sliding in from the left")
	eq(Attract.card_rect(1.0), Attract.CARD, "in place")
	eq(Attract.card_rect(Attract.CARD_OUT_AT - 0.01), Attract.CARD, "held")
	check(Attract.card_rect(Attract.CARD_OUT_AT + 0.2).position.x < Attract.CARD.position.x, "going")
	eq(Attract.card_rect(Attract.CARD_OUT_AT + Attract.CARD_OUT + 0.01), Rect2(), "gone")
	var screen := Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)
	check(screen.encloses(Attract.CARD), "on screen")
	check(Attract.CARD.end.y < Cfg.SCREEN_H - 34, "above PRESS START")
	check(Attract.CARD.end.x < Cfg.SCREEN_W / 2.0 - 40, "left of the car")


## PR-20: the game walks the loop: a demo, the controls card, the next demo, ..., the title.
func test_the_tour_steps_through_a_loop() -> void:
	var g := _game()
	g.calibration.visible = false
	var cars := Attract.tour_cars_now()
	g.start_demo()
	check(g.is_demo() and g.race != null, "the first step: a demo race")
	eq([g.race.stage_index, g.race.car_id], [0, Cars.get_car(cars[0])["id"]], "stage 1, the first car")
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()  # (the race emits it when the demo has run its length)
	check(g.race == null and g.menu is ControlsCard, "then the controls card")
	check((g.menu as ControlsCard).attract and g.is_demo(), "as part of the tour")
	_idle_ticks(g, int(Attract.CONTROLS_SECONDS / DT) - 5)
	check(g.menu is ControlsCard, "up for its time")
	_idle_ticks(g, 10)
	check(g.race != null and g.race.demo, "then the next demo")
	eq([g.race.stage_index, g.race.car_id], [1, Cars.get_car(cars[1])["id"]], "on stage 2, in the next car")
	for stage in range(2, Stages.count()):
		TestSuite.ready_all(g.race)
		g.race.quit_requested.emit()
		if not check(g.race != null, "stage %d's demo" % (stage + 1)):
			return
		eq(g.race.stage_index, stage, "stage %d in order" % (stage + 1))
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()
	eq(g.screen, g.Screen.TITLE, "the loop done: the title")
	check(g.race == null, "the last demo dropped")
	g.start_demo()
	eq([g.race.stage_index, g.race.car_id], [0, Cars.get_car(cars[Stages.count() % cars.size()])["id"]],
		"the next loop: stage 1, the cars carrying on")


func test_input_on_the_tour_controls_card_goes_to_the_title() -> void:
	var g := _game()
	g.calibration.visible = false
	g.tour_step = Attract.CONTROLS_AT
	g.start_demo()
	check(g.menu is ControlsCard and g.is_demo(), "the controls card")
	_idle_ticks(g, 1, input(), menu_input(true))
	eq(g.screen, g.Screen.TITLE, "a press: the title")
	var k := InputEventKey.new()
	k.keycode = KEY_Q
	k.pressed = true
	g.tour_step = Attract.CONTROLS_AT
	g.start_demo()
	g._input(k)
	eq(g.screen, g.Screen.TITLE, "a key: the title")


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
	check(g.is_demo() and g.menu is ControlsCard, "idle again: the tour carries on, with the controls card")


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
	eq(g.stage_index, 0, "the player's stage pick is untouched")
