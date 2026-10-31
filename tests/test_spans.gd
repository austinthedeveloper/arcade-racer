## Road-spanning sprites: tunnels, bridges, arches and the race gates.
extends TestSuite


func _flat(n: int) -> Track:
	var t := Track.new()
	for i in n:
		t.add_segment(0.0, 0.0)
	return t


func test_every_span_loads_with_an_opening_that_fits_the_road() -> void:
	eq(SpriteLibrary.spans.size(), 14, "span sprites")
	for id: String in SpriteLibrary.spans:
		var e := SpriteLibrary.span_edges(id)
		var inner: Vector2 = e["inner"]
		var outer: Vector2 = e["outer"]
		check(inner.x < -1.0 and inner.y > 1.0, "%s opening is wider than the road" % id)
		check(outer.x < inner.x and outer.y > inner.y, "%s has structure on both sides" % id)


func test_find_opening_reads_the_gap_near_the_bottom() -> void:
	var img := Image.create(100, 50, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.fill_rect(Rect2i(20, 10, 60, 40), Color.TRANSPARENT)
	eq(SpriteLibrary.find_opening(img), Vector2(0.2, 0.8), "legs at 0-20% and 80-100%")


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
