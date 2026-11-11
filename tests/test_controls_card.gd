## The controls card (PR-22): CONTROLS on the title and the pause menu lists the controls for
## the device in use (keyboard, pad, wheel, touch) from the bindings as they are now. Text
## labels until the glyphs (WH-14), through ControlsCard.input_label. Scratch profiles.
extends TestSuite


static func menu_input(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


static func row(rows: Array, label: String) -> String:
	for r: Array in rows:
		if r[0] == label:
			return r[1]
	return "(none)"


func test_the_keyboard_card_has_every_control_as_bound() -> void:
	TestSuite.use_scratch_profiles(InputRouter)
	var kb := DeviceProfile.keyboard()
	var rows := ControlsCard.rows(ControlsCard.Device.KEYBOARD, kb)
	eq(row(rows, "GAS"), "UP / W", "gas")
	eq(row(rows, "BRAKE"), "DOWN / S", "brake")
	check(row(rows, "STEER").contains("LEFT / A") and row(rows, "STEER").contains("RIGHT / D"), "steer: " + row(rows, "STEER"))
	eq(row(rows, "NITRO"), "SPACE / SHIFT", "nitro")
	eq(row(rows, "PAUSE"), "ESCAPE / P", "pause")
	for action: String in DeviceProfile.REMAP_ACTIONS:
		check(row(rows, DeviceProfile.ACTION_NAMES[action]) != "(none)", "%s on the card" % action)
	kb.bind("nitro", KEY_N)
	kb.bind("photo", DeviceProfile.UNBOUND)
	rows = ControlsCard.rows(ControlsCard.Device.KEYBOARD, kb)
	eq(row(rows, "NITRO"), "N", "a rebind shows as it is now")
	eq(row(rows, "PHOTO"), "---", "unbound: ---")


func test_the_pad_wheel_and_touch_cards() -> void:
	var pad := DeviceProfile.new()
	var rows := ControlsCard.rows(ControlsCard.Device.GAMEPAD, pad)
	eq(row(rows, "NITRO"), "RB", "pad nitro on RB")
	eq(row(rows, "GAS"), "RT / A", "pad gas")
	eq(row(rows, "PAUSE"), "START", "pad pause")
	pad.bind("nitro", JOY_BUTTON_X)
	eq(row(ControlsCard.rows(ControlsCard.Device.GAMEPAD, pad), "NITRO"), "X", "rebound")
	var wheel := DeviceProfile.new()
	wheel.kind = DeviceProfile.Kind.WHEEL
	rows = ControlsCard.rows(ControlsCard.Device.WHEEL, wheel)
	check(row(rows, "GAS / BRAKE").contains("CALIBRAT"), "an uncalibrated wheel: calibrate for the pedals")
	eq(row(rows, "NITRO"), "---", "no nitro button before calibrating")
	wheel.calibrated = true
	wheel.nitro_button = 4
	rows = ControlsCard.rows(ControlsCard.Device.WHEEL, wheel)
	eq(row(rows, "GAS / BRAKE"), "THE PEDALS", "calibrated: the pedals")
	eq(row(rows, "NITRO"), "BUTTON 4", "its nitro button")
	rows = ControlsCard.rows(ControlsCard.Device.TOUCH, DeviceProfile.keyboard())
	for label in ["STEER", "GAS", "BRAKE", "NITRO", "PAUSE"]:
		check(row(rows, label) != "(none)", "touch: %s" % label)


func test_every_card_fits_its_panel() -> void:
	for dev in ControlsCard.Device.size():
		var rows := ControlsCard.rows(dev, ControlsCard.profile_for(dev))
		check(ControlsCard.TOP + 14 + rows.size() * ControlsCard.ROW_H < Cfg.SCREEN_H - 34, "device %d: %d rows fit" % [dev, rows.size()])
		for r: Array in rows:
			check(UiText.width(r[0], 11) < ControlsCard.LABEL_X - 4, "%s fits its column" % r[0])
			check(ControlsCard.VALUE_X + UiText.width(r[1], 11) < Cfg.SCREEN_W - 90, "%s fits" % r[1])


func test_input_label_is_the_glyph_hook() -> void:
	var pad := DeviceProfile.new()
	eq(ControlsCard.input_label(pad, JOY_BUTTON_START), pad.input_name(JOY_BUTTON_START), "text until the glyphs (WH-14)")


func test_it_opens_on_the_device_in_use_and_steps_through_the_others() -> void:
	var c := ControlsCard.new()
	_nodes.append(c)
	eq(c.device, ControlsCard.device_now(), "the device in use")
	eq(c.device, ControlsCard.Device.KEYBOARD, "the keyboard, in a headless run")
	c.handle(menu_input(false, false, 1))
	eq(c.device, ControlsCard.Device.GAMEPAD, "right: the pad's")
	c.handle(menu_input(false, false, -1))
	c.handle(menu_input(false, false, -1))
	eq(c.device, ControlsCard.Device.TOUCH, "left wraps round to touch")
	var closed := [0]
	c.on_back = func() -> void: closed[0] += 1
	c.handle(menu_input(false, true))
	eq(closed[0], 1, "back closes it")


func test_controls_on_the_title_opens_the_card_and_back() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.menu.news = []  # (what's new, if an earlier suite left it due)
	g.menu.asking = false
	g.menu.index = TitleScreen.items().find("CONTROLS")
	eq(g.menu.index, 2, "CONTROLS after OPTIONS")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.CONTROLS, "the controls card")
	check(g.menu is ControlsCard, "drawn by ControlsCard")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back: the title")
	eq(TitleScreen.items()[g.menu.index], "CONTROLS", "on CONTROLS")
	eq(TitleScreen.pill_step(6) * 6, Cfg.SCREEN_W - 16.0, "six pills share the width")
	eq(TitleScreen.pill_step(5), TitleScreen.PILL_STEP, "five as before")


func test_controls_on_the_pause_menu_opens_the_card_over_the_race() -> void:
	var r := race(false, false)
	drive(r, 200, input(1.0))
	r.pause()
	eq(r.pause_menu.items, PauseMenu.ITEMS, "no first drive: no SKIP")
	r.pause_menu.index = r.pause_menu.items.find(PauseMenu.Action.CONTROLS)
	eq(r.pause_menu.choose(menu_input(true)), PauseMenu.Action.NONE, "CONTROLS is the menu's own")
	check(r.pause_menu.card != null and r.pause_menu.card.over_race, "the card over the race")
	check(r.paused, "still paused")
	r.pause_menu.choose(menu_input())
	r.pause_menu.choose(menu_input(false, true))
	check(r.pause_menu.card == null and r.pause_menu.visible and r.paused, "back: the pause menu again, still paused")
	eq(r.pause_menu.choose(menu_input()), PauseMenu.Action.NONE, "the back that closed it doesn't resume too")
	eq(r.pause_menu.choose(menu_input(false, true)), PauseMenu.Action.RESUME, "then back resumes")
	r.pause_menu.open_controls()
	r.pause_menu.choose(menu_input(), true)
	check(r.pause_menu.card == null, "pause closes the card too")
