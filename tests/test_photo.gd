## The photo key (PR-21): F12 or a bound PHOTO button saves a picture of the race to
## user://screenshots/ (a scratch folder here) with the HUD hidden for that frame, a shutter
## sound and a flash the flash option scales.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_profiles(InputRouter)
	Photo.dir = TestSuite.scratch("screenshots")
	TestSuite.remove_tree(Photo.dir)


func _done() -> void:
	_clean()
	Photo.dir = Photo.DIR


func _audio() -> Node:
	var a: Node = runner.root.get_node("Audio")
	a._ready()
	return a


func test_f12_by_default_and_a_button_can_be_bound() -> void:
	_clean()
	check("photo" in DeviceProfile.REMAP_ACTIONS, "PHOTO on the remap screen")
	eq(InputRouter.keyboard.binding("photo"), [KEY_F12], "F12 on the keyboard")
	var pad := DeviceProfile.new()
	eq(pad.binding("photo"), [], "a pad has none until one is bound")
	pad.bind("photo", JOY_BUTTON_BACK)
	eq(pad.binding("photo"), [JOY_BUTTON_BACK], "bound")
	check(InputMap.has_action("photo") and InputMap.action_get_events("photo").size() == 1, "the key is in the input map")
	_done()


func test_the_file_lands_and_the_hud_is_hidden_for_that_frame() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 30, input(1.0))
	check(r.ui_layer.visible, "the HUD shows")
	check(r.begin_photo(), "a photo starts")
	check(not r.ui_layer.visible, "the HUD, pause menu and results are hidden for the frame")
	check(not r.begin_photo(), "not a second one over it")
	_audio().history.clear()
	var img := Image.create(Cfg.SCREEN_W, Cfg.SCREEN_H, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE)
	var path: String = r.finish_photo(img)
	check(path.begins_with(Photo.dir) and path.ends_with(".png"), "saved in the screenshots folder (%s)" % path)
	check(FileAccess.file_exists(path), "the file lands")
	var back := Image.load_from_file(ProjectSettings.globalize_path(path))
	eq([back.get_width(), back.get_height()], [Cfg.SCREEN_W, Cfg.SCREEN_H], "the whole frame")
	check(r.ui_layer.visible, "the HUD comes back")
	eq(_audio().history.count("shutter"), 1, "the shutter sounds")
	check(r.photo.flash_left > 0.0, "and the screen flashes")
	check(r.finish_photo(img) != path, "another in the same second gets its own name")
	_done()


func test_the_key_takes_one_paused_or_not() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 10, input(1.0))
	var press := input(1.0)
	press.photo_pressed = true
	drive(r, 1, press)  # (outside the tree there is no frame to grab: nothing is saved)
	check(not r.photo_taking and r.photo.flash_left > 0.0, "taken")
	r.photo.tick(Photo.FLASH_TIME)
	r.pause()
	drive(r, 1, press)
	check(r.photo.flash_left > 0.0, "the pause menu hides for one too")
	_done()


func test_the_flash_follows_the_flash_option() -> void:
	_clean()
	near(Photo.flash_alpha(Photo.FLASH_TIME), Photo.FLASH_ALPHA, 0.001, "as designed at 10")
	near(Photo.flash_alpha(Photo.FLASH_TIME / 2.0), Photo.FLASH_ALPHA / 2.0, 0.001, "fading")
	eq(Photo.flash_alpha(0.0), 0.0, "gone")
	Settings.flash = 4
	near(Photo.flash_alpha(Photo.FLASH_TIME), Photo.FLASH_ALPHA * 0.4, 0.001, "scaled down")
	Settings.flash = 0
	eq(Photo.flash_alpha(Photo.FLASH_TIME), 0.0, "none with the option at 0")
	var p := Photo.new()
	p.flash()
	p.tick(Photo.FLASH_TIME * 0.5)
	near(p.flash_left, Photo.FLASH_TIME * 0.5, 0.0001, "fades with time")
	p.tick(1.0)
	eq(p.flash_left, 0.0, "and stops")
	p.free()
	_done()


func test_file_names() -> void:
	var when := {"year": 2026, "month": 11, "day": 2, "hour": 9, "minute": 5, "second": 7}
	eq(Photo.file_name(when), "photo_20261102_090507.png", "dated")
	eq(Photo.file_name(when, 1), "photo_20261102_090507_2.png", "the second that second")
	eq(Photo.save(null), "", "no picture, no file")
