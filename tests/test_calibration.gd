## The F2 wizard finds the steering and pedal axes from snapshots, whatever the layout.
extends TestSuite


func _wizard() -> CalibrationWizard:
	var w := CalibrationWizard.new()
	_nodes.append(w)
	w.device = 0
	w.step = CalibrationWizard.Step.REST
	return w


## Axis snapshot: ten axes at `rest` with the given axes overridden.
static func _axes(values: Dictionary, rest: float = 0.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in 10:
		a.append(values.get(i, rest))
	return a


func _run(w: CalibrationWizard, snaps: Array) -> void:
	for s in snaps:
		w.capture(s)


func test_separate_pedal_axes() -> void:
	var w := _wizard()
	var rest := {0: 0.0, 1: -1.0, 2: -1.0}
	_run(w, [_axes(rest), _axes({0: -1.0, 1: -1.0, 2: -1.0}), _axes({0: 1.0, 1: -1.0, 2: -1.0}),
		_axes({0: 0.0, 1: 1.0, 2: -1.0}), _axes({0: 0.0, 1: -1.0, 2: 1.0})])
	eq(w.step, CalibrationWizard.Step.NITRO, "reaches the nitro step")
	var p := w.profile
	eq(p.steer_axis, 0, "steering axis")
	eq(p.steer_left, -1.0, "left end")
	eq(p.steer_right, 1.0, "right end")
	eq(p.throttle_axis, 1, "gas axis")
	eq(p.brake_axis, 2, "brake axis")
	eq(p.combined_pedals, false, "separate pedals")
	near(DeviceProfile.pedal(1.0, p.throttle_rest, p.throttle_full), 1.0, 0.001, "gas reads full")


func test_inverted_pedals() -> void:
	# Many wheels rest at +1 and press toward -1.
	var w := _wizard()
	var rest := {3: 1.0, 4: 1.0}
	_run(w, [_axes(rest), _axes({0: -1.0, 3: 1.0, 4: 1.0}), _axes({0: 1.0, 3: 1.0, 4: 1.0}),
		_axes({3: -1.0, 4: 1.0}), _axes({3: 1.0, 4: -1.0})])
	var p := w.profile
	eq(p.throttle_axis, 3, "gas axis")
	eq(p.brake_axis, 4, "brake axis")
	near(DeviceProfile.pedal(1.0, p.throttle_rest, p.throttle_full), 0.0, 0.001, "gas at rest")
	near(DeviceProfile.pedal(-1.0, p.throttle_rest, p.throttle_full), 1.0, 0.001, "gas pressed")


func test_combined_pedals() -> void:
	var w := _wizard()
	_run(w, [_axes({}), _axes({0: -1.0}), _axes({0: 1.0}), _axes({1: -1.0}), _axes({1: 1.0})])
	var p := w.profile
	eq(p.throttle_axis, 1, "gas axis")
	eq(p.brake_axis, 1, "brake shares it")
	eq(p.combined_pedals, true, "combined")


func test_brake_that_moves_like_the_gas_is_rejected() -> void:
	var w := _wizard()
	_run(w, [_axes({}), _axes({0: -1.0}), _axes({0: 1.0}), _axes({1: 1.0}), _axes({1: 1.0})])
	eq(w.step, CalibrationWizard.Step.BRAKE, "stays on the brake step")
	check(w.message != "", "explains why")


func test_wheel_that_did_not_move_restarts_left() -> void:
	var w := _wizard()
	_run(w, [_axes({}), _axes({0: -0.1}), _axes({0: 0.1})])
	eq(w.step, CalibrationWizard.Step.LEFT, "asks for left again")
	check(w.profile == null, "no profile yet")


func test_pedal_that_did_not_move_waits() -> void:
	var w := _wizard()
	_run(w, [_axes({}), _axes({0: -1.0}), _axes({0: 1.0}), _axes({})])
	eq(w.step, CalibrationWizard.Step.GAS, "stays on the gas step")


func test_steering_axis_is_never_taken_as_a_pedal() -> void:
	# The wheel drifting during the gas step must not be picked as the gas.
	var w := _wizard()
	_run(w, [_axes({}), _axes({0: -1.0}), _axes({0: 1.0}), _axes({0: 1.0, 1: 0.9})])
	eq(w.profile.throttle_axis, 1, "gas axis")
