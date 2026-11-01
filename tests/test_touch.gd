## Touch controls (ON-4, ON-5): the hit areas, fingers holding actions, sliding between
## buttons, letting go, the layouts, and a menu worked by touch.
extends TestSuite


## The controls, with the InputMap's actions there to hold (the runner's tests run before the
## autoloads are ready, so InputRouter hasn't registered them yet).
func controls() -> TouchControls:
	runner.root.get_node("InputRouter")._register_actions()
	var t := TouchControls.new()
	t._ready()
	_nodes.append(t)
	return t


func centre(layout: TouchControls.Layout, id: String) -> Vector2:
	for b: Dictionary in TouchControls.buttons(layout):
		if b["id"] == id:
			return (b["rect"] as Rect2).get_center()
	return Vector2(-100, -100)


func test_buttons_dont_overlap_and_stay_on_screen() -> void:
	controls()
	var screen := Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)
	for layout in [TouchControls.Layout.RACE, TouchControls.Layout.MENU]:
		var bs := TouchControls.buttons(layout)
		for i in bs.size():
			var r: Rect2 = bs[i]["rect"]
			check(screen.encloses(r), "%s on screen" % bs[i]["id"])
			check(InputMap.has_action(bs[i]["action"]), "%s holds a real action" % bs[i]["id"])
			for j in range(i + 1, bs.size()):
				check(not r.intersects(bs[j]["rect"]), "%s clear of %s" % [bs[i]["id"], bs[j]["id"]])


func test_race_buttons_clear_the_hud() -> void:
	var lay := Hud.layout(true)
	for b: Dictionary in TouchControls.RACE_BUTTONS:
		for el in ["timer", "position", "progress", "nitro", "speedo", "slipstream"]:
			check(not (b["rect"] as Rect2).intersects(lay[el]), "%s clear of the HUD's %s" % [b["id"], el])


func test_hit_finds_the_button_under_a_finger() -> void:
	eq(TouchControls.hit(TouchControls.Layout.RACE, centre(TouchControls.Layout.RACE, "gas")), "gas", "gas")
	eq(TouchControls.hit(TouchControls.Layout.RACE, Vector2(320, 180)), "", "nothing mid-screen")
	eq(TouchControls.hit(TouchControls.Layout.MENU, centre(TouchControls.Layout.MENU, "ok")), "ok", "OK in the menus")


func test_two_fingers_steer_and_gas_together_then_let_go() -> void:
	var t := controls()
	t._layout = TouchControls.Layout.RACE
	t.touch(0, centre(TouchControls.Layout.RACE, "gas"), true)
	t.touch(1, centre(TouchControls.Layout.RACE, "left"), true)
	check(t.shown, "a touch shows them")
	check(Input.is_action_pressed("accelerate") and Input.is_action_pressed("steer_left"), "both held")
	t.drag(1, centre(TouchControls.Layout.RACE, "right"))
	check(not Input.is_action_pressed("steer_left") and Input.is_action_pressed("steer_right"), "slid across to steer right")
	t.touch(0, centre(TouchControls.Layout.RACE, "gas"), false)
	check(not Input.is_action_pressed("accelerate"), "gas let go")
	check(Input.is_action_pressed("steer_right"), "still steering")
	t.release_all()
	check(not Input.is_action_pressed("steer_right"), "all let go")


func test_a_finger_off_every_button_holds_nothing() -> void:
	var t := controls()
	t._layout = TouchControls.Layout.RACE
	t.touch(3, Vector2(320, 150), true)
	eq(t.held_actions(), {}, "nothing held")
	t.drag(3, centre(TouchControls.Layout.RACE, "brake"))
	check(Input.is_action_pressed("brake"), "sliding onto BRAKE brakes")
	t.release_all()


func test_a_key_hides_them() -> void:
	var t := controls()
	t.touch(0, centre(TouchControls.Layout.MENU, "ok"), true)
	var k := InputEventKey.new()
	k.keycode = KEY_ENTER
	k.pressed = true
	t._input(k)
	check(not t.shown, "hidden")
	check(not Input.is_action_pressed("confirm"), "and let go")


func test_the_race_shows_the_driving_layout_only_while_racing() -> void:
	var r := race(false, false)
	var t := controls()
	t.race = r
	check(r.touch_driving(), "racing: the driving layout")
	r.pause()
	check(not r.touch_driving(), "paused: the menu layout")
	r.resume()
	r.results.visible = true
	check(not r.touch_driving(), "the results: the menu layout")


## OK and the D-pad drive mode select as Enter and the arrows do.
func test_touch_works_a_menu() -> void:
	var router: Node = runner.root.get_node("InputRouter")
	var t := controls()
	t._layout = TouchControls.Layout.MENU
	t.touch(0, centre(TouchControls.Layout.MENU, "right"), true)
	router._physics_process(DT)
	check(router.menu.right_pressed, "the D-pad's right is a menu right")
	t.touch(0, centre(TouchControls.Layout.MENU, "right"), false)
	router._physics_process(DT)
	t.touch(1, centre(TouchControls.Layout.MENU, "down"), true)
	router._physics_process(DT)
	check(router.menu.down_pressed, "down is a menu down")
	t.release_all()
	router._physics_process(DT)
	t.touch(2, centre(TouchControls.Layout.MENU, "ok"), true)
	router._physics_process(DT)
	check(router.menu.confirm_pressed, "OK confirms")
	t.release_all()
	router._physics_process(DT)
