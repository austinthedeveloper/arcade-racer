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
	CarSprites.load_all()
	var vega := CarSprites.strips("vega")
	for row: int in vega:
		var strip: Dictionary = vega[row]
		check(strip["tex"] != null, "player strip %d" % row)
		eq(int(strip["cell"].x) * CarSprites.PLAYER_FRAMES, strip["tex"].get_width(), "seven equal cells in strip %d" % row)
		check(strip["body_w"] > 0.0, "body width found in strip %d" % row)
	check(vega.has(0), "level strip always there")
	eq(CarSprites.traffic.size(), 38, "traffic vehicles")


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
	var to_cam := Vector3(0.0, Tuning.v("camera/height"), -Cfg.PLAYER_Z).normalized()
	for slope in [0.3, -0.3]:
		var pitch := PlayerCar.pitch_for_slope(slope)
		var a := atan(slope)  # nose-up angle
		var roof := Vector3(0.0, cos(a), -sin(a)).dot(to_cam) - Vector3.UP.dot(to_cam)
		var tail := Vector3(0.0, -sin(a), -cos(a)).dot(to_cam) - Vector3(0.0, 0.0, -1.0).dot(to_cam)
		var warp := CarSprites.pitch_warp(pitch)
		eq(signf(warp.x - 1.0), signf(roof), "roof grows as it turns to the camera (slope %s)" % slope)
		eq(signf(warp.y - 1.0), signf(tail), "bumper grows as it turns to the camera (slope %s)" % slope)


func test_hill_strips_are_in_and_not_much_taller_than_level() -> void:
	var vega := CarSprites.strips("vega")
	for row in [-1, 1]:
		check(vega.has(row), "pitched strip %d is built" % row)
	var level: float = vega[0]["cell"].y
	for row in [-1, 1]:
		var h: float = vega[row]["cell"].y
		# Taller pops when the pitch switches strips; the tool squashes them (make_car_sprites.py)
		check(h <= level * 1.4, "strip %d is %.0f px, level %.0f px" % [row, h, level])


func test_tall_cars_are_drawn_smaller_not_taller() -> void:
	var vega: Dictionary = CarSprites.strips("vega")[0]
	near(CarSprites.draw_scale(100.0, vega), 100.0 / vega["body_w"], 0.0001, "the Vega fills the width")
	for id in ["cyclone", "skipper", "mesa", "hauler"]:
		var strip: Dictionary = CarSprites.strips(id)[0]
		var h: float = strip["cell"].y * CarSprites.draw_scale(100.0, strip)
		check(h <= 100.0 * CarSprites.MAX_HEIGHT + 0.01, "%s at most %.2f x its width tall (%.1f)" % [id, CarSprites.MAX_HEIGHT, h])


func test_every_pitch_draws_at_the_level_strips_scale() -> void:
	# A tall nose-up strip mustn't shrink the car as the road starts to climb
	var level := {"cell": Vector2(200.0, 130.0), "body_w": 180.0}
	var tall := {"cell": Vector2(200.0, 170.0), "body_w": 180.0}
	var car := {0: level, -1: tall}
	near(CarSprites.car_scale(100.0, car), 100.0 / 180.0, 0.0001, "the level strip's scale")
	check(CarSprites.draw_scale(100.0, tall) < CarSprites.car_scale(100.0, car), "alone, the tall strip would draw smaller")
	# A car too tall on the level still comes down, by its level strip
	var hauler := {0: {"cell": Vector2(200.0, 200.0), "body_w": 180.0}}
	near(CarSprites.car_scale(100.0, hauler), 100.0 * CarSprites.MAX_HEIGHT / 200.0, 0.0001, "the height limit still holds")


func test_player_cars_are_solid() -> void:
	# Regression: the magenta key ate pink and purple paint (Cyclone, Zenith), so the road
	# showed through the car. The Skipper is an open tube-frame buggy: its gaps are real.
	const OPEN_FRAME := {"skipper": 0.9}
	for i in Cars.count():
		var id: String = Cars.get_car(i)["strip"]
		var strip: Dictionary = CarSprites.strips(id)[0]
		var cell: Vector2 = strip["cell"]
		var img: Image = strip["tex"].get_image()
		var frame := img.get_region(Rect2i(Vector2i(int(cell.x) * (CarSprites.PLAYER_FRAMES / 2), 0), Vector2i(cell)))
		var body := frame.get_used_rect()
		# The middle of the body, below the roof line: rear deck, lights, bumper. It stops above
		# the axle, which a lifted truck (the Mesa) really does show the road under.
		var core := Rect2i(body.position + Vector2i(body.size.x * 3 / 10, body.size.y * 4 / 10),
			Vector2i(body.size.x * 4 / 10, body.size.y * 3 / 10))
		var solid := 0
		for y in range(core.position.y, core.end.y):
			for x in range(core.position.x, core.end.x):
				solid += int(frame.get_pixel(x, y).a > 0.5)
		var frac := solid / float(core.size.x * core.size.y)
		check(frac > OPEN_FRAME.get(id, 0.98), "%s rear is solid (%.0f%%)" % [id, frac * 100.0])


func test_right_turns_show_the_right_flank() -> void:
	# Regression: the Bruiser's sheet drew its right turns from the left again, so steering
	# right showed the left flank. Each right-turn frame looks more like its left-turn frame
	# mirrored than like that frame as it is (the gentlest turns are too close to straight).
	for i in Cars.count():
		var id: String = Cars.get_car(i)["strip"]
		var strip: Dictionary = CarSprites.strips(id)[0]
		var img: Image = strip["tex"].get_image()
		var cell: Vector2i = Vector2i(strip["cell"])
		for left in [0, 1]:
			var l := img.get_region(Rect2i(Vector2i(cell.x * left, 0), cell))
			var r := img.get_region(Rect2i(Vector2i(cell.x * (CarSprites.PLAYER_FRAMES - 1 - left), 0), cell))
			var same := _difference(l, r)
			l.flip_x()
			var mirrored := _difference(l, r)
			check(mirrored < same, "%s frame %d mirrors its left turn (%.3f vs %.3f as is)" % [id, left, mirrored, same])


## The cars whose strips are rendered from a 3D model (RENDERED in tools/make_car_sprites.py).
const RENDERED_CARS := ["bruiser", "halo", "hauler", "skipper", "sol"]


func test_rendered_cars_have_strips_at_every_pitch() -> void:
	for id in RENDERED_CARS:
		var car: Dictionary = CarSprites.strips(id)
		check(car.has(-1) and car.has(0) and car.has(1), "%s: uphill, level and downhill" % id)
		# A pitch strip over the height limit mustn't shrink the car when it swaps in
		near(CarSprites.car_scale(100.0, car), CarSprites.draw_scale(100.0, car[0]), 0.0001, "%s keeps its level size at every pitch" % id)
		check(car[0]["cell"].y * CarSprites.car_scale(100.0, car) <= 100.0 * CarSprites.MAX_HEIGHT + 0.001, "%s is no taller than the limit" % id)
		for pitch in [-1, 1]:
			check(car[pitch]["cell"].y * CarSprites.car_scale(100.0, car) < 100.0 * 1.2, "%s pitch %d stays in proportion" % [id, pitch])


func test_rendered_cars_glow_at_their_own_lamps() -> void:
	for id in RENDERED_CARS:
		var car: Dictionary = CarSprites.strips(id)
		for row: int in car:
			check(car[row].has("lamps"), "%s pitch %d has its lamps placed" % [id, row])
			for box: Array in car[row].get("lamps", []):
				var rects := CarSprites.lamp_rects(box, Vector2(0.0, 100.0), 100.0, 60.0)
				for r in rects:
					check(r.position.x >= -50.0 and r.end.x <= 50.0 and r.position.y >= 40.0 and r.end.y <= 100.0,
						"%s pitch %d lamp %s inside the car" % [id, row, r])
	check(not CarSprites.strips("vega")[0].has("lamps"), "a concept strip keeps the sheets' taillights")


func test_lamp_rects_mirror_the_left_lamp() -> void:
	var rects := CarSprites.lamp_rects([0.3, 0.4, 0.1, 0.2], Vector2(50.0, 200.0), 100.0, 50.0)
	check(rects.size() == 2, "a lamp each side")
	near(rects[0].get_center().x, 80.0, 0.001, "right lamp 0.3 widths out")
	near(rects[1].get_center().x, 20.0, 0.001, "left lamp mirrors it")
	near(rects[0].get_center().y, 180.0, 0.001, "0.4 heights up from the base")
	near(rects[0].size.x, 10.0, 0.001, "width in body widths")
	near(rects[0].size.y, 10.0, 0.001, "height in car heights")


## Mean channel difference (alpha included) between two images of one size.
static func _difference(a: Image, b: Image) -> float:
	var d := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			d += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a)
	return d / (a.get_width() * a.get_height())


## The player's straight-ahead frame of a car strip.
static func _straight_frame(id: String) -> Image:
	var strip: Dictionary = CarSprites.strips(id)[0]
	var cell: Vector2i = Vector2i(strip["cell"])
	return strip["tex"].get_image().get_region(Rect2i(Vector2i(cell.x * (CarSprites.PLAYER_FRAMES / 2), 0), cell))


## Opaque pixels of `img` close to the sheets' magenta key color.
static func _key_magenta(img: Image) -> int:
	var key := Color8(248, 5, 250)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var d := absf(c.r - key.r) + absf(c.g - key.g) + absf(c.b - key.b)
			n += int(c.a > 0.5 and d < 60.0 / 255.0)
	return n


## Outline pixels of `img` (opaque, next to a clear pixel or the edge) that lean magenta:
## red and blue both well above green, the key blended into the vehicle's edge.
static func _pink_outline(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.5 or minf(c.r, c.b) - c.g < 50.0 / 255.0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + o
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or img.get_pixelv(p).a <= 0.5:
					n += 1
					break
	return n


func test_player_cars_show_no_key_magenta() -> void:
	# Regression: small background gaps (under the Mesa's axle and light bar) were kept as
	# paint, so the sheet's magenta showed under the truck. The Zenith's paint really is purple.
	for i in Cars.count():
		var id: String = Cars.get_car(i)["strip"]
		if id == "zenith":
			continue
		var magenta := _key_magenta(_straight_frame(id))
		check(magenta <= 20, "%s straight frame has %d key-magenta pixels" % [id, magenta])


func test_traffic_shows_no_key_magenta() -> void:
	# docs/09 A1: magenta painted into the glass of seven vehicles, recolored by the tool. The
	# trolley's neon trim really is that pink.
	const NEON := {"trolley": 40}
	CarSprites.load_all()
	for id: String in CarSprites.traffic:
		var magenta := _key_magenta(CarSprites.traffic[id]["tex"].get_image())
		check(magenta <= NEON.get(id, 20), "%s has %d key-magenta pixels" % [id, magenta])


func test_recolored_glass_is_not_purple() -> void:
	# docs/09 A1: the generator reflected the magenta background into these vehicles' window
	# glass; make_car_sprites.GLASS turns it blue. Counted over the top half, where the glass
	# is. (The trolley's one streak sits among its pink neon, so the key check covers it.)
	CarSprites.load_all()
	for id: String in ["taxi", "tractor", "roadster_yellow", "van_navy", "suv_green", "dump_truck", "tuk_tuk"]:
		var img: Image = CarSprites.traffic[id]["tex"].get_image()
		var purple := 0
		for y in img.get_height() / 2:
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				purple += int(c.a > 0.5 and c.h >= 260.0 / 360.0 and c.h <= 325.0 / 360.0 and c.s > 0.4 and c.v > 0.3)
		check(purple <= 10, "%s has %d purple pixels in its top half" % [id, purple])


func test_vehicle_outlines_carry_no_magenta_spill() -> void:
	# docs/09 A2 and A3: a pink halo around the sweeper's beacons, a purple line under the
	# double-decker, dump truck and jeep, a purple tinge on every car's outline. The Cyclone
	# and the Zenith are painted pink and purple to the edge.
	const PAINTED := ["cyclone", "zenith"]
	CarSprites.load_all()
	for id: String in CarSprites.traffic:
		var pink := _pink_outline(CarSprites.traffic[id]["tex"].get_image())
		check(pink <= 4, "traffic %s has %d magenta outline pixels" % [id, pink])
	for i in Cars.count():
		var id: String = Cars.get_car(i)["strip"]
		if id in PAINTED:
			continue
		var pink := _pink_outline(_straight_frame(id))
		check(pink <= 4, "%s straight frame has %d magenta outline pixels" % [id, pink])


func test_every_manifest_sprite_loads() -> void:
	# The sprite tools write the manifest (tools/manifest.py); a name there with no texture
	# would be skipped with only a warning.
	SpriteLibrary.load_all()
	CarSprites.load_all()
	var m := SpriteLibrary.manifest()
	eq(SpriteLibrary.defs.size(), m["roadside"].size(), "every roadside sprite")
	eq(SpriteLibrary.spans.size(), m["spans"].size(), "every span")
	eq(CarSprites.traffic.size(), m["traffic"].size(), "every traffic vehicle")
	for id: String in Traffic.CARS + Traffic.BIG + Traffic.SPECIALS:
		check(CarSprites.traffic.has(id), "traffic %s is in the manifest" % id)


func test_cars_behind_the_player_are_drawn_over_it() -> void:
	# Review on #103: a rival just behind the player (between it and the camera) was drawn
	# under the player's car.
	check(RoadRenderer.behind(1000.0, 1200.0, 50000.0), "200 back is behind")
	check(not RoadRenderer.behind(1300.0, 1200.0, 50000.0), "100 ahead is not")
	check(RoadRenderer.behind(49900.0, 100.0, 50000.0), "behind across the wrap")
	var drawn: Array[Segment] = []
	for i in 5:
		var seg := Segment.new()
		seg.index = 40 + i
		drawn.append(seg)
	eq(RoadRenderer.player_slot(drawn, 42), 2, "the player's segment in the near-to-far list")
	eq(RoadRenderer.player_slot(drawn, 7), -1, "not drawn: the player goes last")


func test_background_layers_scroll_at_their_own_rates() -> void:
	# WS-3: the sky drifts, the far strip turns once per unit of offset, the near one faster.
	check(Background.SCROLL_RATE["sky"] < Background.SCROLL_RATE["far"], "the sky is slower than the far layer")
	check(Background.SCROLL_RATE["far"] < Background.SCROLL_RATE["near"], "the far layer is slower than the near one")
	var wide := 100000.0  # wide enough not to wrap
	for layer: String in Background.LAYERS:
		var moved := -Background.layer_x(0.01, layer, wide)
		eq(moved, roundf(0.01 * Background.SCROLL_WIDTH * Background.SCROLL_RATE[layer]),
			"%s: SCROLL_RATE times the far strip's pixels" % layer)
	eq(Background.layer_x(1.0, "far", Background.SCROLL_WIDTH), 0.0, "a full turn of a far strip as wide as SCROLL_WIDTH")
	eq(Background.layer_x(0.0, "near", 1920.0), 0.0, "no scroll: flush left")
	for o: float in [0.13, -0.4, 2.7]:
		for layer: String in Background.LAYERS:
			var x := Background.layer_x(o, layer, 1200.0)
			check(x <= 0.0 and x > -1200.0, "%s at %s: the first copy starts at or left of 0" % [layer, o])


func test_skyline_harbor_reflections_move_with_the_city() -> void:
	# WS-14: Skyline's near strip is the harbor water holding the city's reflections, so it
	# scrolls and rises with the far strip and the two never slide apart.
	var theme := SkylineFinale.theme()
	check(theme.get("reflection", false), "Skyline's near strip reflects its far one")
	eq(Background.scroll_rate(theme, "near"), Background.scroll_rate(theme, "far"), "the water scrolls at the city's rate")
	eq(Background.hill_rate(theme, "near"), Background.hill_rate(theme, "far"), "and rises with the hills at the city's rate")
	eq(Background.hill_rate(theme, "near"), Background.HILL_RATE["near"], "the water still sits on the road")
	eq(Background.scroll_rate(theme, "sky"), Background.SCROLL_RATE["sky"], "the sky drifts on its own")
	var layers := Background.layers_of(theme)
	var far: Texture2D = layers["far"]
	var near: Texture2D = layers["near"]
	eq(near.get_width(), far.get_width(), "cut at the city's scale: the strips are as wide")
	for o: float in [0.0, 0.013, 0.37, -0.42, 2.71]:
		eq(Background.layer_x(o, "near", near.get_width(), theme), Background.layer_x(o, "far", far.get_width(), theme),
			"offset %s: the water's columns stay under the city's" % o)
	var rest := Background.layer_bottom("near", 0.0, theme) - Background.layer_bottom("far", 0.0, theme)
	for h: float in [-Background.HILL_MAX, -13.0, 7.0, Background.HILL_MAX]:
		eq(Background.layer_bottom("near", h, theme) - Background.layer_bottom("far", h, theme), rest,
			"hill %s: the water stays at the city's foot" % h)
	# Every other stage keeps its parallax
	check(not Stages.build(0).theme.get("reflection", false), "Palm Coast's layers part as before")
	eq(Background.scroll_rate({}, "near"), Background.SCROLL_RATE["near"], "no reflection: the near strip's own rate")


func test_background_layers_shift_with_the_hills() -> void:
	eq(Background.hill_shift(0.0, Tuning.v("camera/depth")), 0.0, "flat road: the horizon stays")
	check(Background.hill_shift(1500.0, Tuning.v("camera/depth")) < 0.0, "a climb ahead lifts the scenery")
	check(Background.hill_shift(-1500.0, Tuning.v("camera/depth")) > 0.0, "a crest drops it")
	eq(Background.hill_shift(1e6, Tuning.v("camera/depth")), -Background.HILL_MAX, "at most HILL_MAX up")
	eq(Background.hill_shift(-1e6, Tuning.v("camera/depth")), Background.HILL_MAX, "and down")
	# Where the road HILL_AHEAD ahead lands on the screen, relative to the flat horizon
	var rise := -1000.0
	var road_dy := -rise * Tuning.v("camera/depth") / Background.HILL_AHEAD * Cfg.PROJ
	eq(Background.hill_shift(rise, Tuning.v("camera/depth")), roundf(road_dy), "follows the road's far end")
	var hill := 20.0
	var sky := Background.layer_bottom("sky", hill) - Background.layer_bottom("sky", 0.0)
	var far := Background.layer_bottom("far", hill) - Background.layer_bottom("far", 0.0)
	var near := Background.layer_bottom("near", hill) - Background.layer_bottom("near", 0.0)
	check(sky < far and far <= near, "the sky moves least, the near layer most (%s, %s, %s)" % [sky, far, near])
	eq(near, hill, "the near layer sits on the road's far end")
	eq(Background.layer_path("res://bg/neon_far.png", "sky"), "res://bg/neon_sky.png", "layers sit beside the far strip")


func test_only_cars_close_behind_are_drawn_over_the_player() -> void:
	# Cars nearer the camera than that filled the screen at a grid start.
	eq(RoadRenderer.behind_from(7), 7 - RoadRenderer.BEHIND_SEGMENTS, "one segment behind the player's")
	eq(RoadRenderer.behind_from(1), 0, "no further than the camera's own")


func test_sprite_lod_picks_the_smallest_level_at_least_as_tall() -> void:
	var heights := [190, 95, 48]
	eq(SpriteLibrary.lod_level(heights, 250.0), 0, "drawn larger than the texture: the texture")
	eq(SpriteLibrary.lod_level(heights, 190.0), 0, "drawn at its own size: the texture")
	eq(SpriteLibrary.lod_level(heights, 120.0), 0, "under the texture but over half: still the texture")
	eq(SpriteLibrary.lod_level(heights, 95.0), 1, "half size: the half copy")
	eq(SpriteLibrary.lod_level(heights, 60.0), 1, "between a half and a quarter: the half")
	eq(SpriteLibrary.lod_level(heights, 48.0), 2, "a quarter: the quarter copy")
	eq(SpriteLibrary.lod_level(heights, 6.0), 2, "far off: the smallest there is")
	eq(SpriteLibrary.lod_level([40], 6.0), 0, "a sprite with no copies")
	for h in range(1, 300):
		var level := SpriteLibrary.lod_level(heights, float(h))
		check(float(heights[level]) < 2.0 * h or level == heights.size() - 1,
			"never sampled down by half or more at %d px (level %d)" % [h, level])


func test_tall_sprites_load_their_reduced_copies() -> void:
	SpriteLibrary.load_all()
	var palm: Dictionary = SpriteLibrary.defs["palm_tall_a"]
	eq(palm["levels"].size(), 3, "a tall palm: itself, a half and a quarter")
	var h: int = palm["tex"].get_height()
	eq(palm["heights"], [h, roundi(h / 2.0), roundi(h / 4.0)] as Array[int], "each a power of two smaller")
	eq(SpriteLibrary.defs["bush"]["levels"].size(), 1, "a low bush has none")
	eq(SpriteLibrary.texture_for(palm, 400.0), palm["tex"], "close up: the texture")
	eq(SpriteLibrary.texture_for(palm, 10.0), palm["levels"][2], "far off: the quarter")
	eq(SpriteLibrary.lod_path("res://a/b/palm.png", 4), "res://a/b/lod/palm_4.png", "beside it in lod/")
	var with := 0
	for id: String in SpriteLibrary.defs:
		var def: Dictionary = SpriteLibrary.defs[id]
		if def["levels"].size() > 1:
			with += 1
		eq(def["levels"].size(), SpriteLibrary.manifest()["roadside"][id].get("lod", []).size() + 1, id + " loads every copy listed")
	check(with > 150, "most roadside sprites have copies (%d)" % with)


func test_sprite_rects_sit_on_the_pixel_grid() -> void:
	# The right side: starts at the road edge, 10.4 to 40.7 across, 20.6 down to 60.8
	eq(RoadRenderer.pixel_sprite_rect(10.4, 60.8, 30.3, 40.2, 1.2, false), Rect2(10, 21, 31, 40), "edges rounded")
	eq(RoadRenderer.pixel_sprite_rect(200.0, 300.0, 50.0, 80.0, -1.2, false),
		RoadRenderer.sprite_rect(200.0, 300.0, 50.0, 80.0, -1.2, false), "already on the grid: as sprite_rect")
	for offset in [-1.3, 1.3]:
		var plain := RoadRenderer.pixel_sprite_rect(200.3, 300.4, 50.4, 80.2, offset, false)
		var flipped := RoadRenderer.pixel_sprite_rect(200.3, 300.4, 50.4, 80.2, offset, true)
		eq(flipped.position, plain.position, "a mirrored sprite covers the same pixels at %s" % offset)
		eq(flipped.size, Vector2(-plain.size.x, plain.size.y), "still mirrored at %s" % offset)
		var exact := RoadRenderer.sprite_rect(200.3, 300.4, 50.4, 80.2, offset, false)
		check(absf(plain.position.x - exact.position.x) <= 0.5 and absf(plain.end.x - exact.end.x) <= 0.5,
			"within half a pixel of where it was at %s" % offset)
	eq(RoadRenderer.pixel_sprite_rect(5.2, 5.4, 0.2, 0.3, 1.2, false).size, Vector2(1, 1), "at least a pixel")
	var r := RoadRenderer.pixel_sprite_rect(3.7, 9.0, 12.9, 7.7, -1.5, true)
	eq(r.position, r.position.round(), "whole-pixel corner")
	eq(r.size, r.size.round(), "whole-pixel size")
