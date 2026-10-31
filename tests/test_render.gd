## Renderer math that has broken before: roadside sprite placement and the player's
## steering frames. Pure functions, no drawing.
extends TestSuite


func test_left_sprite_ends_at_the_road_edge() -> void:
	var r := RoadRenderer.sprite_rect(200.0, 300.0, 50.0, 80.0, -1.2, false)
	eq(r, Rect2(150.0, 220.0, 50.0, 80.0), "unflipped")


func test_flipped_sprites_cover_the_same_screen_area() -> void:
	# Regression: flipped palms used to be drawn one width to the right, onto the road.
	for offset in [-1.3, 1.3]:
		var plain := RoadRenderer.sprite_rect(200.0, 300.0, 50.0, 80.0, offset, false)
		var flipped := RoadRenderer.sprite_rect(200.0, 300.0, 50.0, 80.0, offset, true)
		eq(flipped.position, plain.position, "same corner at offset %s" % offset)
		eq(flipped.size, Vector2(-50.0, 80.0), "mirrored by a negative width at offset %s" % offset)


func test_right_sprite_starts_at_the_road_edge() -> void:
	var r := RoadRenderer.sprite_rect(400.0, 300.0, 50.0, 80.0, 1.2, true)
	eq(r.position.x, 400.0, "starts at the edge")


func test_steering_frames() -> void:
	eq(CarSprites.steer_frame(0.0), 3, "straight")
	eq(CarSprites.steer_frame(-1.0), 0, "full left is the first frame")
	eq(CarSprites.steer_frame(1.0), 6, "full right is the last frame")
	eq(CarSprites.steer_frame(-0.34), 2, "a little left")
	eq(CarSprites.steer_frame(2.0), 6, "crash wobble clamps")
	eq(CarSprites.steer_frame(-2.0), 0, "crash wobble clamps left")


func test_car_sprites_load() -> void:
	for row: int in CarSprites.player_strips:
		var strip: Dictionary = CarSprites.player_strips[row]
		check(strip["tex"] != null, "player strip %d" % row)
		eq(int(strip["cell"].x) * CarSprites.PLAYER_FRAMES, strip["tex"].get_width(), "seven equal cells in strip %d" % row)
		check(strip["body_w"] > 0.0, "body width found in strip %d" % row)
	check(CarSprites.player_strips.has(0), "level strip always there")
	eq(CarSprites.traffic.size(), 37, "traffic vehicles")


func test_pitch_rows() -> void:
	eq(CarSprites.pitch_row(0.0), 0, "flat road is level")
	eq(CarSprites.pitch_row(0.39), 0, "a gentle slope stays level")
	eq(CarSprites.pitch_row(0.6), 1, "downhill is nose-down")
	eq(CarSprites.pitch_row(-0.6), -1, "uphill is nose-up")
	eq(CarSprites.pitch_row(0.6, [0]), 0, "no downhill strip falls back to level")
	eq(CarSprites.pitch_row(-0.6, [0, 1]), 0, "no uphill strip falls back to level")


func test_pitch_warp_shows_more_roof_uphill() -> void:
	# Regression: the stand-in stretch had uphill and downhill swapped.
	eq(CarSprites.pitch_warp(0.0), Vector2.ONE, "level is unscaled")
	var down := CarSprites.pitch_warp(1.0)
	var up := CarSprites.pitch_warp(-1.0)
	check(up.x > 1.0 and up.y < 1.0, "nose-up: taller roof/deck, shorter bumper")
	check(down.x < 1.0 and down.y > 1.0, "nose-down: shorter roof/deck, taller bumper")
	eq(CarSprites.pitch_warp(3.0), down, "clamped")


func test_pitch_warp_matches_the_camera_geometry() -> void:
	# Car faces +z, camera behind and above it. Pitching the nose up by a turns the roof
	# normal (0, 1, 0) to (0, cos a, -sin a) and the tail normal (0, 0, -1) to (0, -sin a, -cos a).
	var to_cam := Vector3(0.0, Cfg.CAMERA_HEIGHT, -Cfg.PLAYER_Z).normalized()
	for slope in [0.3, -0.3]:
		var pitch := PlayerCar.pitch_for_slope(slope)
		var a := atan(slope)  # nose-up angle
		var roof := Vector3(0.0, cos(a), -sin(a)).dot(to_cam) - Vector3.UP.dot(to_cam)
		var tail := Vector3(0.0, -sin(a), -cos(a)).dot(to_cam) - Vector3(0.0, 0.0, -1.0).dot(to_cam)
		var warp := CarSprites.pitch_warp(pitch)
		eq(signf(warp.x - 1.0), signf(roof), "roof grows as it turns to the camera (slope %s)" % slope)
		eq(signf(warp.y - 1.0), signf(tail), "bumper grows as it turns to the camera (slope %s)" % slope)


func test_hill_strips_are_in_and_not_much_taller_than_level() -> void:
	CarSprites.load_all()
	for row in [-1, 1]:
		check(CarSprites.player_strips.has(row), "pitched strip %d is built" % row)
	var level: float = CarSprites.player_strips[0]["cell"].y
	for row in [-1, 1]:
		var h: float = CarSprites.player_strips[row]["cell"].y
		# Taller pops when the pitch switches strips; the tool squashes them (make_car_sprites.py)
		check(h <= level * 1.4, "strip %d is %.0f px, level %.0f px" % [row, h, level])


func test_tall_cars_are_drawn_smaller_not_taller() -> void:
	CarSprites.use_car("vega")
	var vega: Dictionary = CarSprites.player_strips[0]
	near(CarSprites.draw_scale(100.0, vega), 100.0 / vega["body_w"], 0.0001, "the Vega fills the width")
	for id in ["cyclone", "skipper", "mesa", "hauler"]:
		CarSprites.use_car(id)
		var strip: Dictionary = CarSprites.player_strips[0]
		var h: float = strip["cell"].y * CarSprites.draw_scale(100.0, strip)
		check(h <= 100.0 * CarSprites.MAX_HEIGHT + 0.01, "%s at most %.2f x its width tall (%.1f)" % [id, CarSprites.MAX_HEIGHT, h])
	CarSprites.use_car("vega")


func test_player_cars_are_solid() -> void:
	# Regression: the magenta key ate pink and purple paint (Cyclone, Zenith), so the road
	# showed through the car.
	for i in Cars.count():
		var id: String = Cars.get_car(i)["strip"]
		CarSprites.use_car(id)
		var strip: Dictionary = CarSprites.player_strips[0]
		var cell: Vector2 = strip["cell"]
		var img: Image = strip["tex"].get_image()
		var frame := img.get_region(Rect2i(Vector2i(int(cell.x) * (CarSprites.PLAYER_FRAMES / 2), 0), Vector2i(cell)))
		var body := frame.get_used_rect()
		# The middle of the body, below the roof line: rear deck, lights, bumper
		var core := Rect2i(body.position + Vector2i(body.size.x * 3 / 10, body.size.y * 4 / 10),
			Vector2i(body.size.x * 4 / 10, body.size.y * 4 / 10))
		var solid := 0
		for y in range(core.position.y, core.end.y):
			for x in range(core.position.x, core.end.x):
				solid += int(frame.get_pixel(x, y).a > 0.5)
		var frac := solid / float(core.size.x * core.size.y)
		check(frac > 0.98, "%s rear is solid (%.0f%%)" % [id, frac * 100.0])
	CarSprites.use_car("vega")
