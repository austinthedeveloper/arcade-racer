## Device detection and saved profiles (InputRouter autoload).
extends TestSuite


func _router() -> Node:
	return runner.root.get_node("InputRouter")


func test_wheels_are_recognized_by_name() -> void:
	var r := _router()
	for joy_name in ["Logitech G29 Driving Force Racing Wheel", "Thrustmaster T300RS", "FANATEC CSL Elite Wheel Base",
			"MOZA R5 Base", "G923 Racing Wheel for Xbox One and PC"]:
		check(r.looks_like_wheel(joy_name), joy_name + " is a wheel")


func test_gamepads_are_not_wheels() -> void:
	var r := _router()
	for joy_name in ["Xbox Wireless Controller", "PS5 Controller", "Nintendo Switch Pro Controller", "8BitDo SN30 Pro"]:
		check(not r.looks_like_wheel(joy_name), joy_name + " is a gamepad")


func test_profiles_save_to_the_scratch_file_and_reload() -> void:
	var r := _router()
	eq(r.profile_path, TestSuite.SCRATCH_PROFILES, "tests never touch the player's profiles")
	var p := DeviceProfile.new()
	p.guid = "test-guid-1"
	p.kind = DeviceProfile.Kind.WHEEL
	p.calibrated = true
	p.steer_axis = 3
	r.save_profile(p)
	check(FileAccess.file_exists(TestSuite.SCRATCH_PROFILES), "file written")
	r.load_profiles()
	var loaded: DeviceProfile = r._saved.get("test-guid-1")
	if check(loaded != null, "profile reloaded"):
		eq(loaded.steer_axis, 3, "steer axis")
		eq(loaded.calibrated, true, "calibrated")
	TestSuite.use_scratch_profiles(r)
	eq(r._saved.size(), 0, "scratch file wiped")


func test_an_unmapped_pads_axis_1_never_moves_the_menus() -> void:
	# A wheel or pedals read as a pad: a pedal resting at full travel on axis 1 used to
	# scroll Options down forever. Only a mapped gamepad's stick moves up and down.
	var r := _router()
	eq(r.stick_menu_y(1.0, false), 0.0, "unmapped device: axis 1 ignored")
	eq(r.stick_menu_y(-1.0, false), 0.0, "either end")
	eq(r.stick_menu_y(0.8, true), 0.8, "a mapped gamepad's stick still scrolls")
	var m := MenuInput.new()
	var moves := 0
	for i in 120:
		m.step_axis_y(r.stick_menu_y(1.0, false), 1.0 / 60.0)
		moves += absi(m.step_y())
	eq(moves, 0, "two seconds of a resting pedal: no scrolling")


func test_a_wheel_works_the_menus_like_a_pad() -> void:
	# Steering and pedals through menus was miserable: the wheel's D-pad and face buttons do it.
	var r := _router()
	var none: Array[int] = []
	var m: Dictionary = r.wheel_menu(none, false)
	eq([m["menu_x"], m["menu_y"], m["menu_confirm"], m["menu_back"]], [0.0, 0.0, false, false], "nothing held")
	var held: Array[int] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN]
	m = r.wheel_menu(held, false)
	eq([m["menu_x"], m["menu_y"]], [-1.0, 1.0], "D-pad left and down")
	held = [JOY_BUTTON_A]
	check(r.wheel_menu(held, false)["menu_confirm"], "A selects")
	check(not r.wheel_menu(held, false)["menu_back"], "and doesn't go back")
	held = [JOY_BUTTON_B]
	m = r.wheel_menu(held, false)
	check(m["menu_back"] and not m["menu_confirm"], "B goes back (any button used to select)")
	check(r.wheel_menu(none, true)["menu_confirm"], "its pause button selects, as Start does on a pad")
	held = [JOY_BUTTON_Y]
	check(not r.wheel_menu(held, false)["menu_confirm"], "another button does nothing")


func test_shift_keys_reach_the_drive_input_as_presses() -> void:
	var r := _router()
	TestSuite.use_scratch_profiles(r)
	r._register_actions()  # (a -s run starts before the autoload's _ready)
	eq([r.keyboard.binding("shift_up"), r.keyboard.binding("shift_down")], [[KEY_E], [KEY_Q]], "E and Q by default")
	Input.action_press("shift_up")
	r._physics_process(DT)
	eq([r.state.shift_up_pressed, r.state.shift_down_pressed], [true, false], "shift up on the tick it's pressed")
	r._physics_process(DT)
	eq(r.state.shift_up_pressed, false, "once: held is not another shift")
	Input.action_release("shift_up")
	Input.action_press("shift_down")
	r._physics_process(DT)
	eq([r.state.shift_up_pressed, r.state.shift_down_pressed], [false, true], "shift down")
	Input.action_release("shift_down")
	r._physics_process(DT)
	eq(r.state.shift_down_pressed, false, "released")


## A fake joypad's axes at rest, then `axis` at `value`.
func _fake_axis(r: Node, device: int, axis: int, value: float) -> void:
	var axes: PackedFloat32Array = r.fake_axes.get(device, PackedFloat32Array())
	axes.resize(r.AXIS_COUNT)
	axes[axis] = value
	r.fake_axes[device] = axes


func test_an_unmapped_pads_resting_pedal_on_axis_5_is_never_gas() -> void:
	# WH-11: a pedal set read as a pad (no gamepad mapping, no name match) with a pedal resting
	# at -1 on axis 5 and one at full travel on axis 4: no gas, no brake, not the active device.
	var r := _router()
	TestSuite.use_scratch_profiles(r)
	const FAKE := 7
	check(not Input.is_joy_known(FAKE), "the fake pad has no gamepad mapping")
	var prof := DeviceProfile.new()
	prof.guid = "fake-pedals"
	prof.kind = DeviceProfile.Kind.GAMEPAD
	_fake_axis(r, FAKE, JOY_AXIS_TRIGGER_RIGHT, -1.0)
	_fake_axis(r, FAKE, JOY_AXIS_TRIGGER_LEFT, 1.0)
	eq(r.raw_axes(FAKE)[5], -1.0, "axis 5 rests at -1")
	var got: Dictionary = r._read_pad(FAKE, prof, DT)
	eq([got["throttle"], got["brake"], got["active"]], [0.0, 0.0, false], "a resting pedal: nothing, and not active")
	_fake_axis(r, FAKE, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	got = r._read_pad(FAKE, prof, DT)
	eq([got["throttle"], got["active"]], [0.0, false], "pressed, without a profile that says so: still nothing")
	# A calibrated profile says axis 5 is the gas, resting at -1: resting is still no press.
	prof.calibrated = true
	prof.throttle_axis = JOY_AXIS_TRIGGER_RIGHT
	prof.throttle_rest = -1.0
	prof.throttle_full = 1.0
	_fake_axis(r, FAKE, JOY_AXIS_TRIGGER_RIGHT, -1.0)
	got = r._read_pad(FAKE, prof, DT)
	eq([got["throttle"], got["active"]], [0.0, false], "the profile's gas at rest")
	eq(got["brake"], 0.0, "axis 4 isn't the profile's brake: not read")
	_fake_axis(r, FAKE, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	got = r._read_pad(FAKE, prof, DT)
	check(absf(got["throttle"] - 0.5) < 0.001 and got["active"], "half way down: half gas, active")
	r.fake_axes.erase(FAKE)


func test_pad_pedals_read_a_mapped_pads_triggers_and_only_a_profiles_axes_otherwise() -> void:
	var axes := PackedFloat32Array([0, 0, 0, 0, 0.6, -1.0, 0, 0, 0, 0])
	var plain := DeviceProfile.new()
	eq(InputRouter.pad_pedals(axes, false, plain), Vector2.ZERO, "unmapped, no profile: axes 4 and 5 ignored")
	axes[5] = 1.0
	eq(InputRouter.pad_pedals(axes, false, plain), Vector2.ZERO, "even pegged at full travel")
	axes[5] = 0.8
	check(InputRouter.pad_pedals(axes, true, plain).is_equal_approx(Vector2(0.8, 0.6)), "a mapped pad's triggers: RT gas, LT brake")
	axes[4] = 0.02
	eq(InputRouter.pad_pedals(axes, true, plain).y, 0.0, "a trigger barely off its rest is no press")
	var inverted := DeviceProfile.new()
	inverted.calibrated = true
	inverted.brake_axis = 2
	inverted.brake_rest = 1.0
	inverted.brake_full = -1.0
	axes[2] = 1.0
	eq(InputRouter.pad_pedals(axes, false, inverted), Vector2.ZERO, "an inverted brake at rest, its gas unset")
	axes[2] = -1.0
	eq(InputRouter.pad_pedals(axes, false, inverted), Vector2(0.0, 1.0), "pressed fully")
