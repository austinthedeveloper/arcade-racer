## The wheel's first run (WH-16): a wheel plugged in with no saved profile gets a prompt on
## the title to calibrate now, once per device, never for a pad. Fake joypads (GUID -> name);
## scratch profiles and options; onboarding back off after.
extends TestSuite

const WHEEL := "03000000-firstrun-wheel"
const WHEEL_2 := "03000000-firstrun-wheel-2"
const PAD := "03000000-firstrun-pad"


func _clean() -> void:
	TestSuite.use_scratch_profiles(InputRouter)
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)


func _title() -> TitleScreen:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	SaveData.driver_asked = true  # (who's driving answered: test_whos_driving)
	g.show_title()
	return g.menu


func test_an_unknown_wheel_is_offered_once_and_a_pad_never() -> void:
	_clean()
	var plugged := {PAD: "Xbox Wireless Controller", WHEEL: "Logitech G29 Driving Force Racing Wheel"}
	eq(InputRouter.first_run_wheel({PAD: "Xbox Wireless Controller"}, []), "", "a pad: no offer")
	eq(InputRouter.first_run_wheel(plugged, []), WHEEL, "the wheel beside it: offered")
	eq(InputRouter.first_run_wheel(plugged, [WHEEL]), "", "offered before: not again")
	var p := DeviceProfile.new()
	p.guid = WHEEL
	p.name = "Logitech G29"
	p.kind = DeviceProfile.Kind.WHEEL
	p.calibrated = true
	InputRouter.save_profile(p)
	eq(InputRouter.first_run_wheel(plugged, []), "", "a wheel with a saved profile: not offered")
	check(InputRouter.known_profile_for("Logitech G29 Driving Force Racing Wheel") == null, "no known profiles yet (WH-4)")
	_clean()


func test_the_title_offers_it_once_per_device() -> void:
	_clean()
	WhosDriving.enabled = true
	var t := _title()
	check(not t.asking and t.wheel_offer == "", "nothing up")
	eq(t.offer_wheel({PAD: "Xbox Wireless Controller"}), "", "a pad plugged in: no offer")
	eq(t.wheel_offer, "", "nothing up for a pad")
	eq(t.offer_wheel({WHEEL: "Thrustmaster T300RS Racing Wheel"}), WHEEL, "a new wheel: offered")
	check(t.busy(), "up over the title (no demo)")
	eq(t.wheel_offer_name, "Thrustmaster T300RS Racing Wheel", "naming it")
	eq(TitleScreen.wheel_choices(), ["CALIBRATE NOW", "LATER"] as Array[String], "calibrate now or later")
	eq(Settings.wheels_prompted, [WHEEL] as Array[String], "remembered")
	Settings.load_settings()
	eq(Settings.wheels_prompted, [WHEEL] as Array[String], "and saved")
	t.take_wheel_offer(false)
	eq(t.wheel_offer, "", "LATER: gone")
	eq(t.offer_wheel({WHEEL: "Thrustmaster T300RS Racing Wheel"}), "", "the same wheel again: not offered")
	eq(t.offer_wheel({WHEEL: "Thrustmaster T300RS Racing Wheel", WHEEL_2: "Fanatec CSL DD"}), WHEEL_2, "another wheel: offered")
	Settings.reset()
	eq(Settings.wheels_prompted.size(), 2, "resetting the options doesn't forget them")
	WhosDriving.enabled = false
	_clean()


func test_calibrate_now_opens_the_calibration() -> void:
	_clean()
	WhosDriving.enabled = true
	var t := _title()
	t.game.calibration.visible = false  # (its _ready hides it; outside the tree it hasn't run)
	t.offer_wheel({WHEEL: "Logitech G29 Driving Force Racing Wheel"})
	check(not t.game.calibration.visible, "not open yet")
	t.handle(_confirm())
	eq(t.wheel_offer, "", "the offer taken")
	check(t.game.calibration.visible, "CALIBRATE NOW: the calibration opens")
	t.game.calibration.visible = false
	WhosDriving.enabled = false
	_clean()


func test_no_offer_with_onboarding_off_or_on_a_screenshot() -> void:
	_clean()
	var t := _title()
	eq(t.offer_wheel({WHEEL: "Logitech G29"}), "", "onboarding off (the test runners): none")
	WhosDriving.enabled = true
	t.offers = false  # (a staged --menu-shot)
	eq(t.offer_wheel({WHEEL: "Logitech G29"}), "", "a staged screenshot: none")
	check(Settings.wheels_prompted.is_empty(), "and nothing remembered")
	WhosDriving.enabled = false
	_clean()


static func _confirm() -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = true
	return m
