## Hot-plug (WH-7): unplugging the joypad that's driving pauses the race with a notice, and
## plugging it back in carries on with the same profile. Fake joypads, through
## Input.joy_connection_changed and InputRouter.joy_changed; always on the scratch profiles.
extends TestSuite

const WHEEL := "03000000-hotplug-wheel"
const PAD := "03000000-hotplug-pad"
const ID := 7  # fake device ids: no real joypad has them in a headless run
const OTHER_ID := 8


func _clean() -> void:
	# InputRouter._ready makes this connection; the test runner's tree hasn't run it yet
	if not Input.joy_connection_changed.is_connected(InputRouter._on_joy_connection_changed):
		Input.joy_connection_changed.connect(InputRouter._on_joy_connection_changed)
	TestSuite.use_scratch_profiles(InputRouter)
	InputRouter.unplugged_driver = ""
	InputRouter.last_active_device = -1
	InputRouter._parked.clear()
	for d in [ID, OTHER_ID, 3]:
		InputRouter._joys.erase(d)


## A saved wheel profile, plugged in as device `id` and driving.
func _plug_wheel(id := ID) -> DeviceProfile:
	var p := DeviceProfile.new()
	p.guid = WHEEL
	p.name = "Test Wheel"
	p.kind = DeviceProfile.Kind.WHEEL
	p.calibrated = true
	p.lock_deg = 270.0
	InputRouter.save_profile(p)
	InputRouter.joy_changed(id, true, WHEEL, "Test Wheel")
	InputRouter.last_active_device = id
	return p


## A race under way (past the countdown), the player on the gas.
func _racing() -> Node:
	var r := race(false, false)
	drive(r, 240, input(1.0))
	check(r.state == r.State.RACING, "racing")
	return r


func _done(r: Node) -> void:
	r.free()  # off InputRouter's signals before the next test
	_clean()


static func _menu(confirm := false) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	return m


func test_unplugging_the_wheel_pauses_and_plugging_it_back_resumes() -> void:
	_clean()
	var r := _racing()
	var p := _plug_wheel()
	Input.joy_connection_changed.emit(ID, false)
	check(r.paused and r.pause_menu.visible, "the race pauses, on the pause menu")
	eq(r.pause_menu.notice, PauseMenu.unplugged_notice("Test Wheel", true), "saying so")
	eq(r.pause_menu.notice[0], "WHEEL DISCONNECTED", "a wheel")
	check(r.pause_menu.notice[1].contains("Test Wheel"), "naming it")
	eq([InputRouter.unplugged_driver, InputRouter.last_active_device], [WHEEL, -1], "the router knows which")
	var z: float = r.player.distance
	drive(r, 30, input(1.0))
	eq(r.player.distance, z, "frozen while it's gone")
	Input.joy_connection_changed.emit(ID, true)  # Godot can't name a fake one: the id says who
	check(not r.paused and not r.pause_menu.visible, "plugged back in: the race carries on")
	eq(r.pause_menu.notice, [] as Array[String], "the notice goes")
	eq([InputRouter.unplugged_driver, InputRouter.last_active_device], ["", ID], "and it drives again")
	check(InputRouter._saved[WHEEL] == p, "with the same profile")
	eq((InputRouter._saved[WHEEL] as DeviceProfile).lock_deg, 270.0, "its settings as they were")
	drive(r, 10, input(1.0))
	check(r.player.distance > z, "the car drives on")
	_done(r)


func test_back_on_another_device_id() -> void:
	_clean()
	var r := _racing()
	_plug_wheel()
	InputRouter.joy_changed(ID, false, WHEEL, "Test Wheel")
	check(r.paused, "paused")
	InputRouter.joy_changed(OTHER_ID, true, "03000000-someone-else", "Other Pad")
	check(r.paused, "another joypad plugging in doesn't resume it")
	InputRouter.joy_changed(3, true, WHEEL, "Test Wheel")
	check(not r.paused, "the same wheel on a new id does")
	eq(InputRouter.last_active_device, 3, "and drives, on that id")
	_done(r)


func test_an_unsaved_profile_comes_back_too() -> void:
	_clean()
	var r := _racing()
	InputRouter.joy_changed(ID, true, PAD, "Test Pad")
	var p := DeviceProfile.new()
	p.guid = PAD
	p.name = "Test Pad"
	p.bind("nitro", JOY_BUTTON_X)  # (not saved)
	InputRouter._transient[ID] = p
	InputRouter.last_active_device = ID
	Input.joy_connection_changed.emit(ID, false)
	eq(r.pause_menu.notice[0], "CONTROLLER DISCONNECTED", "a pad")
	check(not InputRouter._transient.has(ID), "the id is free")
	InputRouter.joy_changed(OTHER_ID, true, PAD, "Test Pad")
	check(InputRouter._transient.get(OTHER_ID) == p, "the same profile, on its new id")
	eq(p.binding("nitro"), [JOY_BUTTON_X], "rebinds and all")
	check(not r.paused, "and the race carries on")
	_done(r)


func test_only_the_driving_device_pauses() -> void:
	_clean()
	var r := _racing()
	_plug_wheel()
	InputRouter.last_active_device = -1  # the keyboard is driving
	Input.joy_connection_changed.emit(ID, false)
	check(not r.paused, "the wheel going while the keyboard drives: no pause")
	eq(InputRouter.unplugged_driver, "", "nothing to wait for")
	InputRouter.joy_changed(OTHER_ID, true, PAD, "Test Pad")
	InputRouter.last_active_device = ID  # (gone; nothing drives on it)
	InputRouter.joy_changed(OTHER_ID, false, PAD, "Test Pad")
	check(not r.paused, "another joypad going: no pause")
	_done(r)


func test_a_pause_the_player_made_stays() -> void:
	_clean()
	var r := _racing()
	_plug_wheel()
	r.pause()
	Input.joy_connection_changed.emit(ID, false)
	check(r.paused and r.pause_menu.notice.size() == 2, "already paused: the notice shows")
	Input.joy_connection_changed.emit(ID, true)
	check(r.paused, "back: still paused, as the player left it")
	eq(r.pause_menu.notice, [] as Array[String], "without the notice")
	_done(r)


func test_resuming_without_it_stops_waiting() -> void:
	_clean()
	var r := _racing()
	_plug_wheel()
	Input.joy_connection_changed.emit(ID, false)
	drive(r, 1, input())
	var keep: MenuInput = InputRouter.menu
	InputRouter.menu = _menu(true)
	drive(r, 1, input())  # RESUME, on the keyboard
	InputRouter.menu = keep
	check(not r.paused, "resumed from the menu")
	eq([r.unplugged, r.pause_menu.notice], ["", [] as Array[String]], "no longer waiting")
	r.pause()
	Input.joy_connection_changed.emit(ID, true)
	check(r.paused, "a later pause isn't undone by the wheel coming back")
	_done(r)


func test_the_options_over_the_pause_stay_up() -> void:
	_clean()
	var r := _racing()
	_plug_wheel()
	Input.joy_connection_changed.emit(ID, false)
	r.pause_action(PauseMenu.Action.OPTIONS)
	Input.joy_connection_changed.emit(ID, true)
	check(r.paused and not r.pause_menu.visible, "the options aren't pulled out from under the player")
	r.options_closed()
	eq(r.pause_menu.notice, [] as Array[String], "and the menu they go back to has no notice")
	_done(r)


func test_no_pause_in_a_demo_or_after_the_finish() -> void:
	_clean()
	var r := _racing()
	r.demo = true
	_plug_wheel()
	Input.joy_connection_changed.emit(ID, false)
	check(not r.paused, "a demo plays on")
	r.free()
	_clean()
	r = _racing()
	r.state = r.State.FINISHED
	_plug_wheel()
	Input.joy_connection_changed.emit(ID, false)
	check(not r.paused, "after the finish: nothing to pause")
	_done(r)


func test_the_notice_and_the_staged_screenshot() -> void:
	eq(PauseMenu.unplugged_notice("", false), ["CONTROLLER DISCONNECTED", "Plug it back in to carry on."] as Array[String],
		"no name")
	check(PauseMenu.unplugged_notice("x".repeat(80), true)[1].length() < 100, "a long name is cut")
	_clean()
	var r := _racing()
	load("res://scripts/core/game.gd").stage_unplug()
	check(r.paused, "--screen=unplugged pauses a race as a real unplug does")
	eq(r.pause_menu.notice[0], "WHEEL DISCONNECTED", "a wheel, by its name")
	_done(r)
