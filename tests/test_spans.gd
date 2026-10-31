## Road-spanning sprites: tunnels, bridges, arches and the race gates.
extends TestSuite


func _flat(n: int) -> Track:
	var t := Track.new()
	for i in n:
		t.add_segment(0.0, 0.0)
	return t


func test_every_span_loads_with_an_opening_that_fits_the_road() -> void:
	eq(SpriteLibrary.spans.size(), 15, "span sprites")
	for id: String in SpriteLibrary.spans:
		var e := SpriteLibrary.span_edges(id)
		var inner: Vector2 = e["inner"]
		var outer: Vector2 = e["outer"]
		check(inner.x < -1.0 and inner.y > 1.0, "%s opening is wider than the road" % id)
		check(outer.x < inner.x and outer.y > inner.y, "%s has structure on both sides" % id)
		# The two checks above follow from how world_w is worked out; this one can fail.
		var opening: Vector2 = SpriteLibrary.spans[id]["opening"]
		check(opening.y - opening.x > SpriteLibrary.MIN_OPENING and opening.x > 0.0 and opening.y < 1.0,
			"%s opening %.2f..%.2f of the sprite" % [id, opening.x, opening.y])


func test_find_opening_reads_the_gap_near_the_bottom() -> void:
	var img := Image.create(100, 50, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.fill_rect(Rect2i(20, 10, 60, 40), Color.TRANSPARENT)
	eq(SpriteLibrary.find_opening(img), Vector2(0.2, 0.8), "legs at 0-20% and 80-100%")


func test_find_opening_with_a_solid_middle_finds_none() -> void:
	# Regression: a solid middle pixel came back as a 1 px opening, which made the span huge.
	var img := Image.create(100, 50, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var o := SpriteLibrary.find_opening(img)
	check(o.y - o.x < SpriteLibrary.MIN_OPENING, "no opening (%s)" % o)


func test_span_rect_centers_the_opening_on_the_road() -> void:
	var def := {"world_w": 8000.0, "world_h": 2000.0, "opening": Vector2(0.2, 0.8)}
	var r := RoadRenderer.span_rect(def, 320.0, 300.0, 100.0)
	eq(r.size, Vector2(400.0, 100.0), "4 road half-widths wide, aspect kept")
	eq(r.end.y, 300.0, "stands on the road")
	near(r.position.x + r.size.x * 0.5, 320.0, 0.001, "symmetric opening is centered")
	var lopsided := RoadRenderer.span_rect({"world_w": 8000.0, "world_h": 2000.0, "opening": Vector2(0.1, 0.5)}, 320.0, 300.0, 100.0)
	near(lopsided.position.x + lopsided.size.x * 0.3, 320.0, 0.001, "off-center opening is centered on the road")


func test_race_gates() -> void:
	eq(RoadRenderer.gate_for(0), "", "no gate")
	eq(RoadRenderer.gate_for(Segment.FLAG_START), "start_gantry", "start")
	eq(RoadRenderer.gate_for(Segment.FLAG_CHECKPOINT), "checkpoint_gate", "checkpoint")
	eq(RoadRenderer.gate_for(Segment.FLAG_FINISH | Segment.FLAG_START), "finish_gantry", "finish wins")
	eq(RoadRenderer.gate_label(Segment.FLAG_START), "START", "start banner")
	eq(RoadRenderer.gate_label(Segment.FLAG_CHECKPOINT), "CHECKPOINT", "checkpoint banner")


func test_car_hits_span_legs_only_offroad() -> void:
	var seg := Segment.new()
	seg.spans.append("redrock_arch")
	var half := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var inner: Vector2 = SpriteLibrary.span_edges("redrock_arch")["inner"]
	check(not PlayerCar.hits_span(seg, 0.0, half), "center of the road passes")
	check(not PlayerCar.hits_span(seg, 1.05, half), "just off the road passes")
	check(PlayerCar.hits_span(seg, inner.y + half, half), "right leg")
	check(PlayerCar.hits_span(seg, inner.x - half, half), "left leg")
	check(not PlayerCar.hits_span(seg, 50.0, half), "far beyond the structure")
	var gate := Segment.new()
	gate.flags = Segment.FLAG_CHECKPOINT
	var gi: Vector2 = SpriteLibrary.span_edges("checkpoint_gate")["inner"]
	check(PlayerCar.hits_span(gate, gi.y + half, half), "checkpoint gate legs")


func test_free_spot_avoids_gates_and_spans() -> void:
	var t := _flat(100)
	t.add_checkpoint(50)
	eq(t.free_spot(10), 10, "clear road")
	eq(t.free_spot(45), 59, "past the checkpoint and its margin")
	t.add_span(70, "palm_arch")
	eq(t.free_spot(65), 79, "past the span too")
	eq(t.free_spot(95), -1, "nothing near the end")


func test_tunnel_covers_and_clears_its_segments() -> void:
	var t := _flat(60)
	for i in 60:
		t.add_sprite(i, "palm_tall_a", -1.5)
	t.add_tunnel(10, 12, "neon_tunnel", "neon_tunnel_ring")
	eq(t.segments[10].spans, ["neon_tunnel"] as Array[String], "entrance")
	check(not t.segments[10].covered, "open sky at the entrance")
	for i in range(11, 22):
		check(t.segments[i].covered, "segment %d covered" % i)
		check(t.segments[i].sprites.is_empty(), "segment %d roadside cleared" % i)
	eq(t.segments[13].spans, ["neon_tunnel_ring"] as Array[String], "a ring every 3 segments")
	check(t.segments[14].spans.is_empty(), "none between")
	eq(t.segments[22].spans, ["neon_tunnel"] as Array[String], "exit")
	check(not t.segments[30].sprites.is_empty(), "roadside past the tunnel untouched")
	t.add_tunnel(35, 8, "neon_tunnel", "neon_tunnel_ring", 3, "neon_tunnel_exit")
	eq(t.segments[43].spans, ["neon_tunnel_exit"] as Array[String], "a separate exit piece")


func test_tunnel_darkens_toward_the_middle() -> void:
	var t := _flat(80)
	t.add_tunnel(10, 40, "neon_tunnel", "neon_tunnel_ring")
	eq(t.segments[10].depth, 0.0, "open at the mouth")
	check(t.segments[11].depth > 0.0 and t.segments[11].depth < t.segments[15].depth, "ramps in")
	eq(t.segments[30].depth, 1.0, "darkest in the middle")
	check(t.segments[49].depth < t.segments[45].depth, "ramps out toward the exit")
	eq(t.segments[50].depth, 0.0, "open at the exit")
	eq(Track.tunnel_depth(0, 40), 0.0, "mouth")
	near(Track.tunnel_depth(5, 40), 5.0 / Track.TUNNEL_RAMP, 0.0001, "partway in")
	eq(Track.tunnel_depth(20, 4), 0.0, "past the end clamps")
	var theme := NeonStrip.theme()
	var mouth := RoadRenderer.covered_colors(theme, 0.0)
	var deep := RoadRenderer.covered_colors(theme, 1.0)
	for key in ["grass", "road", "rumble"]:
		var c0: Color = mouth[key][0]
		var c1: Color = deep[key][0]
		check(c1.get_luminance() < c0.get_luminance(), "%s darker deep inside" % key)
		check(c0.get_luminance() < (theme[key][0] as Color).get_luminance(), "%s darker than outside" % key)


func test_neon_tunnel_has_building_faces_that_do_not_collide() -> void:
	var faced: Dictionary = SpriteLibrary.spans["neon_tunnel"]
	var plain: Dictionary = SpriteLibrary.spans["neon_tunnel_exit"]
	check(faced["world_w"] > plain["world_w"] * 2.0, "buildings either side make it much wider")
	check(faced["world_h"] > plain["world_h"], "and taller")
	var a := SpriteLibrary.span_edges("neon_tunnel")
	var b := SpriteLibrary.span_edges("neon_tunnel_exit")
	for k in 2:
		near(a["inner"][k], b["inner"][k], 0.0001, "same opening")
		near(a["outer"][k], b["outer"][k], 0.0001, "only the mouth collides")
	var outer: Vector2 = a["outer"]
	var outside := outer.y + 1.0
	var seg := Segment.new()
	seg.spans.append("neon_tunnel")
	check(not PlayerCar.hits_span(seg, outside, 0.25), "driving past the building faces")


func test_wall_strip_follows_the_road_edge() -> void:
	var seg := Segment.new()
	seg.s1 = Vector2(320.0, 300.0)
	seg.s2 = Vector2(330.0, 200.0)
	seg.sw1 = 200.0
	seg.sw2 = 100.0
	seg.scale1 = 0.01
	seg.scale2 = 0.005
	var p := RoadRenderer.wall_strip(seg, 1.5, 100.0, 50.0)
	eq(p[0], Vector2(320.0 + 300.0, 300.0 - 0.01 * 100.0 * Cfg.PROJ), "near end, out on the right, raised")
	eq(p[1], Vector2(330.0 + 150.0, 200.0 - 0.005 * 100.0 * Cfg.PROJ), "far end")
	near(p[0].y - p[3].y, 0.01 * 50.0 * Cfg.PROJ, 0.0001, "near thickness")
	near(p[1].y - p[2].y, 0.005 * 50.0 * Cfg.PROJ, 0.0001, "far thickness")
	var thin := RoadRenderer.wall_strip(seg, -1.0, 0.0, 1.0)
	check(thin[0].y - thin[3].y >= 1.0, "at least a pixel tall")
	check(thin[0].x < seg.s1.x, "negative offset is on the left")


func test_every_stage_has_its_drive_through_pieces() -> void:
	var want := ["palm_arch", "redrock_arch", "neon_tunnel", "covered_bridge", "bayou_truss", "harvest_trestle", "thunder_overpass"]
	for i in want.size():
		var t := Stages.build(i)
		var found := false
		for seg in t.segments:
			if want[i] in seg.spans:
				found = true
				check(seg.flags == 0, "%s: %s not on a race gate" % [t.name, want[i]])
		check(found, "%s has a %s" % [t.name, want[i]])
