## Wheel and pedal normalization (DeviceProfile): every brand's axes land in -1..1 steering
## and 0..1 pedals.
extends TestSuite


func _wheel(left: float, center: float, right: float) -> DeviceProfile:
	var p := DeviceProfile.new()
	p.steer_left = left
	p.steer_center = center
	p.steer_right = right
	p.hardware_range_deg = 360.0  # full lock at full rotation, so raw maps 1:1
	p.lock_deg = 360.0
	p.steer_deadzone = 0.0
	return p


func test_steer_center_and_full_lock() -> void:
	var p := _wheel(-1.0, 0.0, 1.0)
	near(p.normalize_steer(0.0), 0.0, 0.001, "center")
	near(p.normalize_steer(-1.0), -1.0, 0.001, "full left")
	near(p.normalize_steer(1.0), 1.0, 0.001, "full right")
	near(p.normalize_steer(0.5), 0.5, 0.001, "half right")


func test_inverted_steering_axis() -> void:
	var p := _wheel(1.0, 0.0, -1.0)
	near(p.normalize_steer(1.0), -1.0, 0.001, "raw +1 is left")
	near(p.normalize_steer(-1.0), 1.0, 0.001, "raw -1 is right")


func test_off_center_rest_scales_each_side() -> void:
	var p := _wheel(-0.8, 0.1, 1.0)
	near(p.normalize_steer(0.1), 0.0, 0.001, "rest")
	near(p.normalize_steer(-0.8), -1.0, 0.001, "left end")
	near(p.normalize_steer(-0.35), -0.5, 0.001, "halfway left")
	near(p.normalize_steer(0.55), 0.5, 0.001, "halfway right")


func test_lock_reaches_full_steer_early() -> void:
	# A 900 degree wheel with a 360 degree lock is at full steer 180 degrees from center.
	var p := _wheel(-1.0, 0.0, 1.0)
	p.hardware_range_deg = 900.0
	near(p.normalize_steer(0.4), 1.0, 0.001, "180 of 450 degrees")
	near(p.normalize_steer(0.2), 0.5, 0.001, "90 degrees")
	near(p.normalize_steer(-1.0), -1.0, 0.001, "clamped")


func test_deadzone() -> void:
	var p := _wheel(-1.0, 0.0, 1.0)
	p.steer_deadzone = 0.05
	eq(p.normalize_steer(0.04), 0.0, "inside the deadzone")
	check(p.normalize_steer(0.06) > 0.0, "just outside the deadzone steers")
	near(p.normalize_steer(1.0), 1.0, 0.001, "still reaches full lock")


func test_pedal_ranges() -> void:
	near(DeviceProfile.pedal(0.5, 0.0, 1.0), 0.5, 0.001, "0..1 pedal")
	near(DeviceProfile.pedal(0.0, -1.0, 1.0), 0.5, 0.001, "-1..1 pedal")
	near(DeviceProfile.pedal(-1.0, 1.0, -1.0), 1.0, 0.001, "inverted pedal pressed")
	eq(DeviceProfile.pedal(1.0, 1.0, -1.0), 0.0, "inverted pedal at rest")


func test_pedal_clamps_and_ignores_noise() -> void:
	eq(DeviceProfile.pedal(-0.2, 0.0, 1.0), 0.0, "below rest")
	eq(DeviceProfile.pedal(1.3, 0.0, 1.0), 1.0, "past full")
	eq(DeviceProfile.pedal(0.02, 0.0, 1.0), 0.0, "rest noise")
	eq(DeviceProfile.pedal(0.5, 0.0, 0.01), 0.0, "uncalibrated range")


func test_combined_pedal_axis_splits() -> void:
	# Gas pushes the shared axis to -1, brake to +1, rest at 0.
	near(DeviceProfile.pedal(-1.0, 0.0, -1.0), 1.0, 0.001, "gas full")
	eq(DeviceProfile.pedal(-1.0, 0.0, 1.0), 0.0, "gas reads no brake")
	near(DeviceProfile.pedal(1.0, 0.0, 1.0), 1.0, 0.001, "brake full")
	eq(DeviceProfile.pedal(1.0, 0.0, -1.0), 0.0, "brake reads no gas")


func test_save_and_load_round_trip() -> void:
	var p := DeviceProfile.new()
	p.guid = "03000000-wheel"
	p.name = "Test Wheel"
	p.kind = DeviceProfile.Kind.WHEEL
	p.calibrated = true
	p.steer_axis = 2
	p.steer_left = 0.9
	p.throttle_axis = 1
	p.throttle_rest = 1.0
	p.throttle_full = -1.0
	p.combined_pedals = true
	p.nitro_button = 5
	p.lock_deg = 270.0
	var cfg := ConfigFile.new()
	p.save_to(cfg)
	var q := DeviceProfile.load_from(cfg, "03000000-wheel")
	for key in DeviceProfile.SAVED_KEYS:
		eq(q.get(key), p.get(key), key)
	eq(q.guid, p.guid, "guid")


func test_steer_at_matches_the_raw_axis() -> void:
	var p := _wheel(-1.0, 0.0, 1.0)
	p.hardware_range_deg = 900.0
	p.steer_gamma = 2.0
	p.steer_deadzone = 0.05
	for raw in [-1.0, -0.3, 0.0, 0.1, 0.25, 0.4, 0.8]:
		near(p.steer_at(raw * 450.0), p.normalize_steer(raw), 0.0001, "raw %s" % raw)
	near(p.wheel_turn(-0.5), -0.5, 0.0001, "wheel_turn: half left")
	near(p.steer_at(180.0), 1.0, 0.0001, "full steer at half the lock")


func test_linearity_curves_below_the_line() -> void:
	var p := _wheel(-1.0, 0.0, 1.0)
	near(p.normalize_steer(0.5), 0.5, 0.001, "1.0 is linear")
	p.steer_gamma = 2.0
	near(p.normalize_steer(0.5), 0.25, 0.001, "2.0: half the wheel, a quarter of the steering")
	near(p.normalize_steer(1.0), 1.0, 0.001, "still full at full lock")
	p.steer_gamma = 0.5
	check(p.normalize_steer(0.25) > 0.25, "under 1.0: quicker near center")


func test_range_steps_and_keeps_the_lock_inside() -> void:
	var p := DeviceProfile.new()
	eq([p.hardware_range_deg, p.lock_deg], [900.0, 360.0], "defaults")
	p.step_range(1, false)
	eq(p.hardware_range_deg, 1080.0, "up a step")
	p.hardware_range_deg = 2520.0
	p.step_range(1, false)
	eq(p.hardware_range_deg, 2520.0, "left/right stops at the top")
	p.step_range(1, true)
	eq(p.hardware_range_deg, 180.0, "confirm wraps to the bottom")
	eq(p.lock_deg, 180.0, "the lock comes down with it")
	p.step_range(-1, false)
	eq(p.hardware_range_deg, 180.0, "and stops at the bottom")
	p.step_range(-1, true)
	eq(p.hardware_range_deg, 2520.0, "or wraps to the top")
	p.hardware_range_deg = 1000.0  # off the steps (an older file's, or hand-edited)
	p.step_range(-1, false)
	eq(p.hardware_range_deg, 900.0, "between steps: the next one down")
	p.hardware_range_deg = 1000.0
	p.step_range(1, false)
	eq(p.hardware_range_deg, 1080.0, "or up")


func test_lock_deadzone_and_linearity_steps() -> void:
	var p := DeviceProfile.new()
	p.step_lock(1, false)
	eq(p.lock_deg, 390.0, "lock up 30")
	p.lock_deg = 900.0
	p.step_lock(1, false)
	eq(p.lock_deg, 900.0, "no more than the range")
	p.step_lock(1, true)
	eq(p.lock_deg, DeviceProfile.LOCK_MIN, "wraps to the least")
	p.step_lock(-1, false)
	eq(p.lock_deg, DeviceProfile.LOCK_MIN, "and stops there")
	near(p.steer_deadzone, 0.015, 0.0001, "default deadzone")
	p.step_deadzone(1, false)
	near(p.steer_deadzone, 0.02, 0.0001, "1.5% up: 2%")
	p.steer_deadzone = 0.015
	p.step_deadzone(-1, false)
	near(p.steer_deadzone, 0.01, 0.0001, "1.5% down: 1%")
	p.step_deadzone(-1, false)
	p.step_deadzone(-1, false)
	eq(p.steer_deadzone, 0.0, "stops at none")
	p.step_deadzone(-1, true)
	near(p.steer_deadzone, DeviceProfile.DEADZONE_MAX, 0.0001, "wraps to the most")
	p.step_gamma(1, false)
	near(p.steer_gamma, 1.1, 0.0001, "linearity up 0.1")
	p.steer_gamma = DeviceProfile.GAMMA_MAX
	p.step_gamma(1, true)
	near(p.steer_gamma, DeviceProfile.GAMMA_MIN, 0.0001, "wraps to the least")


func test_reset_and_copy_steering() -> void:
	var p := DeviceProfile.new()
	p.hardware_range_deg = 540.0
	p.lock_deg = 270.0
	p.steer_deadzone = 0.1
	p.steer_gamma = 2.5
	p.steer_axis = 3
	var q := DeviceProfile.new()
	q.copy_steering(p)
	eq([q.hardware_range_deg, q.lock_deg, q.steer_deadzone, q.steer_gamma, q.steer_axis], [540.0, 270.0, 0.1, 2.5, 0],
		"the four settings, not the calibration")
	p.reset_steering()
	for key: String in DeviceProfile.STEERING_KEYS:
		eq(p.get(key), DeviceProfile.new().get(key), "%s back to its default" % key)
		check(DeviceProfile.SAVED_KEYS.has(key), "%s is saved" % key)
	eq(p.steer_axis, 3, "reset leaves the calibration")


func test_edited_steering_saves_and_loads() -> void:
	TestSuite.use_scratch_profiles(InputRouter)
	var p := DeviceProfile.new()
	p.guid = "03000000-wheel-range"
	p.name = "Test Wheel"
	p.kind = DeviceProfile.Kind.WHEEL
	p.step_range(-1, false)
	p.step_lock(-1, false)
	p.step_deadzone(1, false)
	p.step_gamma(1, false)
	InputRouter.save_profile(p)
	InputRouter.load_profiles()
	var q: DeviceProfile = InputRouter._saved[p.guid]
	check(q != p, "a fresh profile from the file")
	for key: String in DeviceProfile.STEERING_KEYS:
		near(q.get(key), p.get(key), 0.0001, key)
	eq([q.hardware_range_deg, q.lock_deg], [720.0, 330.0], "as edited")
	TestSuite.use_scratch_profiles(InputRouter)
