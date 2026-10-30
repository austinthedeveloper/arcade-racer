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
