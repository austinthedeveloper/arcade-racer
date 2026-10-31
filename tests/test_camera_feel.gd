## Camera feel and the accessibility sliders: shake (crashes, landings, crests, rough ground),
## the nitro FOV stretch, and flashes, each scaled by Settings.screen_shake / flash.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func test_slider_functions() -> void:
	_clean()
	eq([Settings.screen_shake, Settings.flash], [10, 10], "default: as designed")
	eq(Settings.shake_amount(4.0), 4.0, "10: the designed amount")
	eq(Settings.flash_amount(0.8), 0.8, "10: the designed flash")
	Settings.screen_shake = 5
	Settings.flash = 5
	eq(Settings.shake_amount(4.0), 2.0, "5: half")
	eq(Settings.flash_amount(0.8), 0.4, "5: half")
	Settings.screen_shake = 0
	Settings.flash = 0
	eq(Settings.shake_amount(4.0), 0.0, "0: no shake")
	eq(Settings.flash_amount(0.8), 0.0, "0: no flash")
	Settings.screen_shake = 25
	Settings.flash = 25
	eq(Settings.shake_amount(4.0), 4.0, "never more than designed")
	eq(Settings.flash_amount(0.8), 0.8, "never more than designed")
	_clean()


func test_sliders_save_and_reset() -> void:
	_clean()
	Settings.screen_shake = 2
	Settings.flash = 7
	Settings.save()
	Settings.load_settings()
	eq([Settings.screen_shake, Settings.flash], [2, 7], "saved")
	Settings.reset()
	eq([Settings.screen_shake, Settings.flash], [10, 10], "reset to designed")
	_clean()


func test_shake_kicks() -> void:
	var p := PlayerCar.new()
	eq(_kick(p, 0.0, false), 0.0, "nothing: still")
	p.crashed = true
	near(_kick(p, 0.0, false), Cfg.SHAKE_CRASH - Cfg.SHAKE_SETTLE * DT, 0.001, "crash")
	p.crashed = false
	p.landed = true
	near(_kick(p, 0.0, false), Cfg.SHAKE_LANDING - Cfg.SHAKE_SETTLE * DT, 0.001, "landing")
	p.landed = false
	near(_kick(p, 0.0, true), Cfg.SHAKE_TAKEOFF - Cfg.SHAKE_SETTLE * DT, 0.001, "taking off over a crest")
	check(Cfg.SHAKE_TAKEOFF < Cfg.SHAKE_LANDING, "takeoff is the smaller one")
	near(_kick(p, 4.0, true), 4.0 - Cfg.SHAKE_SETTLE * DT, 0.001, "doesn't cut a bigger shake short")
	var s := 3.0
	for i in 60:
		s = _kick(p, s, false)
	eq(s, 0.0, "settles")


func _kick(p: PlayerCar, shake: float, took_off: bool) -> float:
	return load("res://scripts/race/race.gd").shake_after(shake, p, took_off, DT)


func test_no_shake_at_zero() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 200, input(1.0))
	var moved := false
	for i in 20:
		r.player.crashed = true  # a crash every tick: the most shake there is
		r._shake = Cfg.SHAKE_CRASH
		drive(r, 1, input(1.0))
		moved = moved or r.road.position != Vector2.ZERO
	check(moved, "10: the road shakes")
	Settings.screen_shake = 0
	for i in 20:
		r._shake = Cfg.SHAKE_CRASH
		drive(r, 1, input(1.0))
		eq(r.road.position, Vector2.ZERO, "0: no shake")
	_clean()


func test_nitro_fov_stretch() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 200, input(1.0))
	eq(r.road.camera_depth, Cfg.CAMERA_DEPTH, "no nitro: the designed depth")
	var nitro := input(1.0)
	nitro.nitro_pressed = true
	drive(r, 1, nitro)
	drive(r, 60, input(1.0))
	check(r.player.nitro_time > 0.0, "nitro burning")
	check(r.road.camera_depth < Cfg.CAMERA_DEPTH, "the view widens (%.3f)" % r.road.camera_depth)
	check(r.road.camera_depth >= Cfg.CAMERA_DEPTH * (1.0 - Cfg.NITRO_FOV_STRETCH) - 0.0001, "a few percent at most")
	Settings.screen_shake = 0
	drive(r, 1, input(1.0))
	eq(r.road.camera_depth, Cfg.CAMERA_DEPTH, "0: no stretch")
	eq(r.camera_depth(Cfg.NITRO_FOV_STRETCH), Cfg.CAMERA_DEPTH, "camera_depth at 0")
	Settings.screen_shake = 10
	near(r.camera_depth(Cfg.NITRO_FOV_STRETCH), Cfg.CAMERA_DEPTH * (1.0 - Cfg.NITRO_FOV_STRETCH), 0.0001, "at 10")
	drive(r, 400, input(1.0))
	eq(r.player.nitro_time, 0.0, "nitro over")
	eq(r.road.camera_depth, Cfg.CAMERA_DEPTH, "eases back")
	_clean()


func test_flashes_scale() -> void:
	_clean()
	eq(Hud.ram_flash_alpha(0.3), 1.0, "ram flash: full on impact")
	eq(Hud.ram_flash_alpha(0.15), 0.5, "fading")
	eq(Hud.clock_color(20.0), Color.WHITE, "clock white with time left")
	var red := Color("#ff4040")
	eq([Hud.clock_color(5.0), Hud.clock_color(5.3)], [red, Color.WHITE], "10: blinks red and white")
	Settings.flash = 0
	eq(Hud.ram_flash_alpha(0.3), 0.0, "0: no ram flash")
	eq([Hud.clock_color(5.0), Hud.clock_color(5.3)], [red, red], "0: steady red, no blink")
	eq(Hud.clock_color(20.0), Color.WHITE, "and white with time left")
	_clean()


func test_accessibility_page_rows() -> void:
	_clean()
	var o := OptionsScreen.new()
	o.go_to(OptionsScreen.Row.SCREEN_SHAKE)
	eq(o.page, OptionsScreen.Page.ACCESSIBILITY, "on Accessibility")
	o.change(OptionsScreen.Row.SCREEN_SHAKE, 1, false)
	eq(Settings.screen_shake, 10, "stops at the designed level")
	o.change(OptionsScreen.Row.SCREEN_SHAKE, -1, false)
	o.change(OptionsScreen.Row.FLASH, -1, false)
	Settings.load_settings()
	eq([Settings.screen_shake, Settings.flash], [9, 9], "changed and saved")
	eq(OptionsScreen.value_text(OptionsScreen.Row.FLASH), "9", "shown")
	o.free()
	_clean()
