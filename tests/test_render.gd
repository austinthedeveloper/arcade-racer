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
	eq(CarSprites.traffic.size(), 13, "traffic vehicles")


func test_pitch_rows() -> void:
	eq(CarSprites.pitch_row(0.0), 0, "flat road is level")
	eq(CarSprites.pitch_row(0.39), 0, "a gentle slope stays level")
	eq(CarSprites.pitch_row(0.6), 1, "downhill is nose-down")
	eq(CarSprites.pitch_row(-0.6), -1, "uphill is nose-up")
	eq(CarSprites.pitch_row(0.6, [0]), 0, "no downhill strip falls back to level")
	eq(CarSprites.pitch_row(-0.6, [0, 1]), 0, "no uphill strip falls back to level")


func test_pitch_warp_shows_more_deck_downhill() -> void:
	eq(CarSprites.pitch_warp(0.0), Vector2.ONE, "level is unscaled")
	var down := CarSprites.pitch_warp(1.0)
	var up := CarSprites.pitch_warp(-1.0)
	check(down.x > 1.0 and down.y < 1.0, "nose-down: taller deck, shorter bumper")
	check(up.x < 1.0 and up.y > 1.0, "nose-up: shorter deck, taller bumper")
	eq(CarSprites.pitch_warp(3.0), down, "clamped")
