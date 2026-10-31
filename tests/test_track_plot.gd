## The authoring plot (TrackPlot, tools/track_preview.gd): the road from above and from the side.
extends TestSuite


func _curved(n: int, curve: float) -> Track:
	var t := Track.new()
	for i in n:
		t.add_segment(curve, 0.0)
	return t


func test_a_straight_road_runs_up_the_plan() -> void:
	var pts := TrackPlot.plan_points(_curved(10, 0.0))
	eq(pts.size(), 11, "a point per segment start, and the end")
	eq(pts[0], Vector2.ZERO, "starts at the origin")
	near(pts[10].x, 0.0, 0.001, "no sideways drift")
	near(pts[10].y, -10.0 * Cfg.SEGMENT_LENGTH, 0.001, "a segment length per segment, up the screen")


func test_curve_turns_the_heading() -> void:
	near(TrackPlot.heading_step(Cfg.SEGMENT_LENGTH), 1.0, 0.0001, "a radian per segment at curve = segment length")
	# A quarter turn to the right: ends heading along +x
	var c := PI / 2.0 / 100.0 * Cfg.SEGMENT_LENGTH
	var pts := TrackPlot.plan_points(_curved(100, c))
	var last := pts[100] - pts[99]
	near(last.normalized().x, 1.0, 0.001, "positive curve turns right")
	check(pts[100].x > 0.0 and pts[100].y < 0.0, "ends up and to the right")
	var left := TrackPlot.plan_points(_curved(100, -c))
	near(left[100].x, -pts[100].x, 0.001, "negative curve mirrors it")
	# A full circle comes back to where it started
	var ring := TrackPlot.plan_points(_curved(200, 2.0 * PI / 200.0 * Cfg.SEGMENT_LENGTH))
	check(ring[200].length() < Cfg.SEGMENT_LENGTH, "a full turn closes (%s)" % ring[200])


func test_side_points_follow_the_road_height() -> void:
	var t := Track.new()
	t.hill(10, 5.0)
	var pts := TrackPlot.side_points(t)
	eq(pts.size(), t.segments.size() + 1, "a point per segment start, and the end")
	eq(pts[0], Vector2(0.0, 0.0), "starts at the bottom")
	eq(pts[15], Vector2(t.segments[15].w1.z, t.segments[15].w1.y), "distance and height")
	eq(pts[-1], Vector2(t.segments[-1].w2.z, t.segments[-1].w2.y), "the far end of the last segment")
	check(pts[-1].y > 4.9 * Cfg.SEGMENT_LENGTH, "near the top of the hill")


func test_sprite_kinds() -> void:
	var want := {"street_lamp_a": "light", "palm_tall_a": "plant", "pine_c": "plant", "casino_spire": "building",
		"barn": "building", "barrier_red": "race", "crowd": "race", "guardrail": "barrier", "cone_tall": "barrier",
		"taxi": "vehicle", "log_truck": "vehicle", "sign_chevron": "sign", "neon_star": "sign",
		"boulders_a": "terrain", "waterfall": "terrain"}
	for id: String in want:
		eq(TrackPlot.sprite_kind(id), want[id], id)
	check(TrackPlot.kind_color("plant") != TrackPlot.kind_color("building"), "kinds have their own colors")


func test_fit_keeps_the_shape_and_centers_it() -> void:
	var xf := TrackPlot.fit(Rect2(0.0, 0.0, 100.0, 50.0), Rect2(10.0, 10.0, 200.0, 200.0))
	eq(xf * Vector2(0.0, 0.0), Vector2(10.0, 60.0), "top left, centered vertically")
	eq(xf * Vector2(100.0, 50.0), Vector2(210.0, 160.0), "bottom right, same scale both ways")
	var side := TrackPlot.stretch(Rect2(0.0, -10.0, 1000.0, 20.0), Rect2(0.0, 0.0, 100.0, 40.0))
	eq(side * Vector2(0.0, -10.0), Vector2(0.0, 40.0), "lowest at the bottom left")
	eq(side * Vector2(1000.0, 10.0), Vector2(100.0, 0.0), "highest at the top right")


func test_gate_labels() -> void:
	var t := TestSuite.flat_track(100)
	t.segments[Track.START_SEGMENT].flags |= Segment.FLAG_START
	t.add_checkpoint(30)
	t.add_checkpoint(60)
	eq(TrackPlot.gate_label(t, Track.START_SEGMENT), "S", "start")
	eq(TrackPlot.gate_label(t, 60), "2", "second checkpoint")
	eq(TrackPlot.gate_label(t, 90), "F", "finish")
	eq(TrackPlot.gate_label(t, 50), "", "nothing")


func test_every_stage_plots() -> void:
	for i in Stages.count():
		var t := Stages.build(i)
		var img := TrackPlot.render(t)
		eq(img.get_size(), TrackPlot.SIZE, t.name + " sheet size")
		var found := {}
		for y in range(TrackPlot.PLAN.position.y, TrackPlot.PLAN.end.y, 2):
			for x in range(TrackPlot.LEGEND.x + 150, TrackPlot.PLAN.end.x, 2):
				var c := img.get_pixel(x, y)
				for col: Color in [TrackPlot.ROAD, TrackPlot.CHECKPOINT, TrackPlot.FINISH]:
					if c.is_equal_approx(col):
						found[col] = true
		check(found.size() == 3, "%s plots its road, checkpoints and finish (%d of 3)" % [t.name, found.size()])
