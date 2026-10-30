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
