## Camera views (WS-15): chase near (as ever), chase far and the bumper, on the VIEW button and
## remembered in Options. A projection test per view: the car sits on its own road row; and
## the view is display only, so the drive is the same from any of them.
extends TestSuite

const VIEWS := [CameraView.View.CHASE_NEAR, CameraView.View.CHASE_FAR, CameraView.View.BUMPER]


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func test_views_step_round_and_are_named() -> void:
	eq(CameraView.next(CameraView.View.CHASE_NEAR), CameraView.View.CHASE_FAR, "near, then far")
	eq(CameraView.next(CameraView.View.CHASE_FAR), CameraView.View.BUMPER, "far, then the bumper")
	eq(CameraView.next(CameraView.View.BUMPER), CameraView.View.CHASE_NEAR, "and round")
	eq(CameraView.NAMES.size(), CameraView.View.size(), "every view named")
	check(CameraView.car_shown(CameraView.View.CHASE_NEAR) and CameraView.car_shown(CameraView.View.CHASE_FAR), "the car in the chase views")
	check(not CameraView.car_shown(CameraView.View.BUMPER), "not from its own bumper")


func test_chase_near_is_the_camera_as_it_was() -> void:
	var v := CameraView.View.CHASE_NEAR
	eq(CameraView.height(v), Tuning.v("camera/height"), "the tuned height")
	eq(CameraView.distance(v), Cfg.PLAYER_Z, "PLAYER_Z behind the car")
	eq(CameraView.camera_z(v, 5000.0, 100000.0), 5000.0, "the camera where the car's position is")
	var s := Tuning.v("camera/depth") / Cfg.PLAYER_Z
	eq(FxLayer.car_base(PlayerCar.new()), Vector2(Cfg.SCREEN_W * 0.5, Cfg.HORIZON_Y + s * Tuning.v("camera/height") * Cfg.PROJ), "the FX layer's car, as before")
	eq(CameraView.behind_segments(v, RoadRenderer.BEHIND_SEGMENTS), RoadRenderer.BEHIND_SEGMENTS, "the cars drawn over it, as before")


## The projection per view: a flat road projected from each view's camera puts the car's own
## road row (where its z lands) at the base the car is drawn on, in the middle of the screen,
## and its road as wide as the car is drawn for that distance.
func test_projection_per_view() -> void:
	var t := flat_track()
	var depth := Tuning.v("camera/depth")
	var car_pos := 19500.0  # PlayerCar.position: the car itself is PLAYER_Z on, at a segment's near edge
	for v: int in VIEWS:
		var cz := CameraView.camera_z(v, car_pos, t.length)
		var seg := t.find_segment(car_pos + Cfg.PLAYER_Z)
		RoadRenderer.project(seg, 0.0, 0.0, CameraView.height(v), cz, depth)
		var k := fposmod(car_pos + Cfg.PLAYER_Z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
		var row := lerpf(seg.s1.y, seg.s2.y, k)
		var name := CameraView.name_of(v)
		near(seg.cam_z1 + k * Cfg.SEGMENT_LENGTH, CameraView.distance(v), 0.01, name + ": the car this far ahead of the camera")
		near(row, CameraView.car_base(v, depth).y, 0.01, name + ": the car sits on its road row")
		near(row, CameraView.road_row(v, CameraView.distance(v), depth), 0.01, name + ": road_row agrees")
		near(seg.s1.x, Cfg.SCREEN_W * 0.5, 0.01, name + ": straight ahead, mid-screen")
		var scale := lerpf(seg.scale1, seg.scale2, k)
		near(scale * Cfg.CAR_WIDTH * Cfg.PROJ, CameraView.car_width(v, depth), 0.01, name + ": the car as wide as the road there says")
	var near_v := CameraView.View.CHASE_NEAR
	var far_v := CameraView.View.CHASE_FAR
	var bumper := CameraView.View.BUMPER
	check(CameraView.car_width(far_v, depth) < CameraView.car_width(near_v, depth), "chase far: the car smaller")
	check(CameraView.car_base(far_v, depth).y < CameraView.car_base(near_v, depth).y, "and higher up the screen")
	check(CameraView.road_row(far_v, 6000.0, depth) > CameraView.road_row(near_v, 6000.0, depth), "chase far: higher, the road below drops away")
	check(CameraView.road_row(bumper, 6000.0, depth) < CameraView.road_row(near_v, 6000.0, depth), "bumper: low, the road ahead flattens to the horizon")
	check(CameraView.camera_z(bumper, car_pos, t.length) > car_pos, "bumper: the camera ahead of the chase camera, at the car")
	check(CameraView.camera_z(far_v, car_pos, t.length) < car_pos, "chase far: behind it")
	check(CameraView.behind_segments(far_v, 1) > 1, "chase far: more cars between it and the car are drawn over it")
	eq(CameraView.behind_segments(bumper, 1), 0, "bumper: none")
	var wrapped := CameraView.camera_z(far_v, 0.0, t.length)
	check(wrapped >= 0.0 and wrapped < t.length, "wrapped onto the lap at the start line")


## Display only: the same drive from every view, tick for tick.
func test_the_view_does_not_change_the_drive() -> void:
	_clean()
	var runs: Array = []
	for v: int in VIEWS:
		Settings.camera_view = v
		var r := race(true, true, 0, true)
		eq(r.road.view, v, "the race draws from the option's view")
		eq(r.fx.view, v, "and so does the FX layer")
		drive(r, 240)
		runs.append([r.player.position, r.player.x, r.player.speed, r.place])
		near(r.road.camera_z, CameraView.camera_z(v, r.player.position, r.track.length), 0.001, "the camera where the view puts it")
	eq(runs[1], runs[0], "chase far drives the same as near")
	eq(runs[2], runs[0], "the bumper too")
	_clean()


## The VIEW button steps the view, says which, and the option remembers it.
func test_view_button_steps_and_is_remembered() -> void:
	_clean()
	var r := race(false, false, 0, false)
	eq(r.road.view, CameraView.View.CHASE_NEAR, "chase near by default")
	var press := input(1.0)
	press.view_pressed = true
	drive(r, 1, press)
	eq(Settings.camera_view, CameraView.View.CHASE_FAR, "VIEW: chase far")
	eq(r.road.view, CameraView.View.CHASE_FAR, "drawn from it at once")
	drive(r, 1, input(1.0))
	eq(r.road.view, CameraView.View.CHASE_FAR, "held to the next press")
	drive(r, 1, press)
	eq(r.road.view, CameraView.View.BUMPER, "VIEW again: the bumper")
	Settings.load_settings()
	eq(Settings.camera_view, CameraView.View.BUMPER, "saved: the next race starts in it")
	var again := race(false, false, 0, false)
	eq(again.road.view, CameraView.View.BUMPER, "and it does")
	Settings.camera_view = CameraView.View.CHASE_NEAR  # Options from the pause menu
	drive(again, 1, input(1.0))
	eq(again.road.view, CameraView.View.CHASE_NEAR, "an Options change shows when the race goes on")
	_clean()


## Options: the DISPLAY page has the camera view, stepping through the three.
func test_options_row() -> void:
	_clean()
	check(OptionsScreen.PAGE_ROWS[OptionsScreen.Page.DISPLAY].has(OptionsScreen.Row.CAMERA), "on the DISPLAY page")
	eq(OptionsScreen.LABELS.size(), OptionsScreen.Row.size(), "every row labelled")
	eq(OptionsScreen.HELP.size(), OptionsScreen.Row.size(), "every row explained")
	eq(OptionsScreen.value_text(OptionsScreen.Row.CAMERA), "CHASE NEAR", "shows the view")
	var o := OptionsScreen.new()
	o.change(OptionsScreen.Row.CAMERA, 1, true)
	eq(Settings.camera_view, CameraView.View.CHASE_FAR, "right: the next view")
	o.change(OptionsScreen.Row.CAMERA, 1, true)
	o.change(OptionsScreen.Row.CAMERA, 1, true)
	eq(Settings.camera_view, CameraView.View.CHASE_NEAR, "confirm wraps round")
	o.change(OptionsScreen.Row.CAMERA, -1, false)
	eq(Settings.camera_view, CameraView.View.CHASE_NEAR, "left stops at the first")
	o.free()
	_clean()
