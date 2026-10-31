## Button remapping: DeviceProfile bindings, saving them per device, the keyboard's on the
## InputMap, conflicts, and the RemapScreen. Always on the scratch profile file.
extends TestSuite

const PAD := "03000000de280000ff11000000000000"


func _clean() -> void:
	TestSuite.use_scratch_profiles(InputRouter)


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	return g


static func _key(code: int, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


static func _pad(guid := PAD) -> DeviceProfile:
	var p := DeviceProfile.new()
	p.guid = guid
	p.name = "Test Pad"
	p.kind = DeviceProfile.Kind.GAMEPAD
	return p


static func _keys(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		out.append((ev as InputEventKey).physical_keycode)
	return out


func test_defaults_on_every_device() -> void:
	_clean()
	check(InputRouter.profile_path != "user://input_profiles.cfg", "tests use a scratch file")
	var kb := InputRouter.keyboard
	for a: String in DeviceProfile.REMAP_ACTIONS:
		check(InputMap.has_action(a), "%s is an input action" % a)
		eq(_keys(a), kb.binding(a), "%s on the InputMap" % a)
		check(kb.conflicts(a).is_empty(), "keyboard %s: no clash by default" % a)
		check(_pad().conflicts(a).is_empty(), "pad %s: no clash by default" % a)
	eq(kb.binding_text("nitro"), "SPACE / SHIFT", "two keys")
	eq(_pad().binding_text("nitro"), "RB / Y", "pad names")
	eq(_pad().binding_text("shift_up"), "---", "unbound")
	var wheel := DeviceProfile.new()
	wheel.kind = DeviceProfile.Kind.WHEEL
	eq(wheel.binding("nitro"), [], "an uncalibrated wheel: nothing")
	wheel.nitro_button = 5
	eq([wheel.binding("nitro"), wheel.binding_text("nitro")], [[5], "BUTTON 5"], "the calibrated nitro button")
	_clean()


func test_bind_replaces_and_unbinds() -> void:
	var p := _pad()
	p.bind("nitro", JOY_BUTTON_LEFT_SHOULDER)
	eq(p.binding("nitro"), [JOY_BUTTON_LEFT_SHOULDER], "one button, in place of both")
	p.bind("horn", DeviceProfile.UNBOUND)
	eq(p.binding("horn"), [], "unbound")
	p.reset_bindings()
	eq([p.binding("nitro"), p.binding("horn")], [[JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y], [JOY_BUTTON_LEFT_STICK]], "reset")
	var wheel := DeviceProfile.new()
	wheel.kind = DeviceProfile.Kind.WHEEL
	wheel.bind("nitro", 7)
	eq(wheel.nitro_button, 7, "a wheel's nitro keeps calibration's button in step")


func test_conflicts_are_flagged() -> void:
	var kb := DeviceProfile.keyboard()
	kb.bind("horn", KEY_SPACE)
	eq(kb.conflicts("horn"), ["NITRO"], "horn on nitro's key")
	eq(kb.conflicts("nitro"), ["HORN"], "and the other way")
	kb.bind("view", KEY_W)
	eq(kb.conflicts("view"), ["GAS"], "a fixed key")
	var pad := _pad()
	pad.bind("pause", JOY_BUTTON_A)
	eq(pad.conflicts("pause"), ["GAS"], "a pad's fixed button")
	pad.bind("shift_up", JOY_BUTTON_LEFT_SHOULDER)
	eq(pad.conflicts("shift_up"), ["SHIFT DOWN"], "two actions on LB")
	pad.bind("shift_up", DeviceProfile.UNBOUND)
	check(pad.conflicts("shift_up").is_empty(), "nothing bound: no clash")


func test_bindings_persist_per_device() -> void:
	_clean()
	var kb := InputRouter.keyboard
	kb.bind("nitro", KEY_N)
	InputRouter.save_bindings(kb)
	eq(_keys("nitro"), [KEY_N], "the InputMap has the new key")
	check(InputMap.event_is_action(_key(KEY_N), "nitro"), "N is nitro")
	check(not InputMap.event_is_action(_key(KEY_SPACE), "nitro"), "Space no longer is")
	var pad := _pad()
	pad.bind("nitro", JOY_BUTTON_X)
	InputRouter.save_bindings(pad)
	var other := _pad("0300000000000000ffff000000000000")
	other.bind("horn", JOY_BUTTON_B)
	InputRouter.save_bindings(other)
	InputRouter.keyboard = DeviceProfile.keyboard()
	InputRouter.apply_keyboard_bindings()
	eq(_keys("nitro"), [KEY_SPACE, KEY_SHIFT], "(forgotten in memory)")
	InputRouter.load_profiles()
	eq(InputRouter.keyboard.binding("nitro"), [KEY_N], "the keyboard's, loaded back")
	eq(_keys("nitro"), [KEY_N], "and on the InputMap again")
	var pad_back: DeviceProfile = InputRouter._saved[PAD]
	eq([pad_back.binding("nitro"), pad_back.binding("horn")], [[JOY_BUTTON_X], [JOY_BUTTON_LEFT_STICK]], "this pad's own")
	var other_back: DeviceProfile = InputRouter._saved[other.guid]
	eq([other_back.binding("nitro"), other_back.binding("horn")], [[JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y], [JOY_BUTTON_B]],
		"and the other pad's")
	_clean()
	eq(_keys("nitro"), [KEY_SPACE, KEY_SHIFT], "a fresh profile file: defaults")


func test_remap_screen_binds_a_key() -> void:
	_clean()
	var s := RemapScreen.new()
	eq(s.rows().size(), DeviceProfile.REMAP_ACTIONS.size() + 3, "device, actions, reset, back")
	eq([s.device(), s.row_action()], [-1, "nitro"], "opens on the keyboard, on nitro")
	check(not s.capture(_key(KEY_N)), "not listening: keys pass through")
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	s.handle(confirm)
	eq(s.listening, "nitro", "select: waits for a key")
	var down := MenuInput.new()
	down.down_pressed = true
	s.handle(down)
	eq(s.row_action(), "nitro", "menu input waits too")
	var pad_button := InputEventJoypadButton.new()
	pad_button.button_index = JOY_BUTTON_A
	pad_button.pressed = true
	check(not s.capture(pad_button), "a pad button doesn't bind the keyboard")
	check(not s.capture(_key(KEY_N, false)), "a release doesn't either")
	check(s.capture(_key(KEY_N)), "N is taken")
	eq([s.listening, InputRouter.keyboard.binding("nitro"), _keys("nitro")], ["", [KEY_N], [KEY_N]], "bound, saved and used")
	s.handle(confirm)
	eq(s.listening, "", "a press just after binding doesn't start again")
	s._process(RemapScreen.SETTLE + 0.01)
	s.listen("horn")
	s.capture(_key(KEY_BACKSPACE))
	eq([s.listening, InputRouter.keyboard.binding("horn")], ["", [KEY_H]], "Backspace cancels")
	s.listen("horn")
	s.capture(_key(KEY_DELETE))
	eq(InputRouter.keyboard.binding_text("horn"), "---", "Delete unbinds")
	s.listen("view")
	s._process(RemapScreen.LISTEN_SECONDS + 0.1)
	eq(s.listening, "", "gives up after a while")
	s.reset_device()
	eq([InputRouter.keyboard.binding("nitro"), InputRouter.keyboard.binding("horn")], [[KEY_SPACE, KEY_SHIFT], [KEY_H]],
		"reset to defaults")
	s.free()
	_clean()


func test_remap_screen_from_the_options_and_back() -> void:
	_clean()
	var g := _game()
	g.show_options()
	var o: OptionsScreen = g.menu
	o.go_to(OptionsScreen.Row.REMAP)
	eq(o.page, OptionsScreen.Page.CONTROLS, "on the Controls page")
	var confirm := MenuInput.new()
	confirm.confirm_pressed = true
	o.handle(confirm)
	eq(g.screen, g.Screen.REMAP, "opens the remap screen")
	var r: RemapScreen = g.menu
	var back := MenuInput.new()
	back.back_pressed = true
	r.handle(back)
	eq(g.screen, g.Screen.OPTIONS, "back to the options")
	eq([g.menu.page, g.menu.row()], [OptionsScreen.Page.CONTROLS, OptionsScreen.Row.REMAP], "on the remap row")
	g._open("remap")
	eq(g.screen, g.Screen.REMAP, "--screen=remap")
	# From mode select's options, the options still go back to mode select afterwards
	g.show_options_from_modes()
	g.menu.go_to(OptionsScreen.Row.REMAP)
	g.menu.handle(confirm)
	g.menu.handle(back)
	eq(g.screen, g.Screen.OPTIONS, "back to the options")
	eq(g.menu.back_name, "mode select", "which still lead back to mode select")
	g.menu.handle(back)
	eq(g.screen, g.Screen.MODES, "and do")
	_clean()
