## Keyboard steering (AC-11): a held key turns in at one rate and comes back at another, both
## set by the steering feel options (snappy to smooth); STANDARD is the rates every earlier
## build had (5 and 9 shares of full lock per second).
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


## Ticks of `dt` for key_steer to go from `from` to `target` at `rates`.
static func _ticks(from: float, target: float, rates: Vector2, dt := TestSuite.DT) -> int:
	var s := from
	var n := 0
	while s != target and n < 10000:
		s = InputRouter.key_steer(s, target, dt, rates)
		n += 1
	return n


func test_defaults_match_the_old_rates() -> void:
	_clean()
	eq([Settings.key_steer_in, Settings.key_steer_out], [Settings.STEER_FEEL_STANDARD, Settings.STEER_FEEL_STANDARD], "standard both ways")
	eq(Settings.STEER_FEEL_NAMES[Settings.STEER_FEEL_STANDARD], "STANDARD", "named so")
	eq(Settings.key_steer_rates(), Vector2(5.0, 9.0), "turn in at 5, back at 9, exactly as before")
	eq(Settings.STEER_FEEL_NAMES.size(), Settings.STEER_FEEL_MULT.size(), "a multiplier per name")


func test_key_steer_turns_in_and_comes_back_at_their_rates() -> void:
	var rates := Vector2(5.0, 9.0)
	var dt := 0.01
	# From center the first tick counts as coming back (as it always did), then turning in
	near(InputRouter.key_steer(0.0, 1.0, dt, rates), 0.09, 0.0001, "first tick from center")
	near(InputRouter.key_steer(0.5, 1.0, dt, rates), 0.55, 0.0001, "held: turns in at x")
	near(InputRouter.key_steer(0.5, 0.0, dt, rates), 0.41, 0.0001, "released: back at y")
	near(InputRouter.key_steer(0.5, -1.0, dt, rates), 0.41, 0.0001, "reversed: back at y")
	near(InputRouter.key_steer(-0.5, -1.0, dt, rates), -0.55, 0.0001, "left the same")
	eq(InputRouter.key_steer(0.99, 1.0, dt, rates), 1.0, "stops at full lock")
	eq(InputRouter.key_steer(0.05, 0.0, dt, rates), 0.0, "and at center")


func test_snappy_and_smooth_change_both_rates() -> void:
	_clean()
	var standard_in := _ticks(0.0, 1.0, Settings.key_steer_rates())
	var standard_out := _ticks(1.0, 0.0, Settings.key_steer_rates())
	Settings.key_steer_in = 0
	Settings.key_steer_out = Settings.STEER_FEEL_NAMES.size() - 1
	var r: Vector2 = Settings.key_steer_rates()
	near(r.x, 5.0 * Settings.STEER_FEEL_MULT[0], 0.0001, "snappiest turn in")
	near(r.y, 9.0 * Settings.STEER_FEEL_MULT[-1], 0.0001, "smoothest return")
	check(_ticks(0.0, 1.0, r) < standard_in, "snappy: full lock sooner")
	check(_ticks(1.0, 0.0, r) > standard_out, "smooth: back to center later")
	Settings.key_steer_in = Settings.STEER_FEEL_NAMES.size() - 1
	Settings.key_steer_out = 0
	r = Settings.key_steer_rates()
	check(_ticks(0.0, 1.0, r) > standard_in, "smooth turn in: later")
	check(_ticks(1.0, 0.0, r) < standard_out, "snappy return: sooner")
	var last := INF
	for i in Settings.STEER_FEEL_MULT.size():
		check(Settings.STEER_FEEL_MULT[i] < last, "%s gentler than the one before" % Settings.STEER_FEEL_NAMES[i])
		last = Settings.STEER_FEEL_MULT[i]
	_clean()


## Holds steer_right for `ticks` router ticks from center; the steering it reached.
func _hold_right(ticks: int) -> float:
	InputRouter._kb_steer = 0.0
	Input.action_press("steer_right")
	for i in ticks:
		InputRouter._physics_process(TestSuite.DT)
	Input.action_release("steer_right")
	return InputRouter.state.steer


func test_held_key_through_the_router() -> void:
	_clean()
	InputRouter._register_actions()  # (a -s run starts before the autoload's _ready)
	var keep_speed: float = InputRouter.speed_factor
	InputRouter.speed_factor = 0.0
	var standard := _hold_right(6)
	near(standard, 9.0 * TestSuite.DT + 5.0 * 5 * TestSuite.DT, 0.0001, "standard: the old ramp")
	# Let go: comes back at the return rate
	var before: float = InputRouter._kb_steer
	InputRouter._physics_process(TestSuite.DT)
	near(InputRouter._kb_steer, before - 9.0 * TestSuite.DT, 0.0001, "released: back at the standard return")
	Settings.key_steer_in = 0
	check(_hold_right(6) > standard, "snappiest: further in the same time")
	Settings.key_steer_in = Settings.STEER_FEEL_NAMES.size() - 1
	check(_hold_right(6) < standard, "smoothest: less far")
	InputRouter._kb_steer = 0.0
	InputRouter._physics_process(TestSuite.DT)
	InputRouter.speed_factor = keep_speed
	_clean()


func test_steering_feel_options_rows_and_saving() -> void:
	_clean()
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.KEY_STEER_IN)
	eq(o.page, OptionsScreen.Page.CONTROLS, "on the Controls page")
	eq(OptionsScreen.value_text(OptionsScreen.Row.KEY_STEER_IN), "STANDARD", "standard by default")
	o.change(OptionsScreen.Row.KEY_STEER_IN, -1, false)
	eq(OptionsScreen.value_text(OptionsScreen.Row.KEY_STEER_IN), "SNAPPY", "left: snappier")
	for i in 10:
		o.change(OptionsScreen.Row.KEY_STEER_OUT, 1, false)
	eq(OptionsScreen.value_text(OptionsScreen.Row.KEY_STEER_OUT), "SMOOTHEST", "right stops at the smoothest")
	Settings.reset()
	Settings.load_settings()
	eq([Settings.key_steer_in, Settings.key_steer_out], [Settings.STEER_FEEL_STANDARD - 1, Settings.STEER_FEEL_NAMES.size() - 1], "saved")
	o.free()
	_clean()
