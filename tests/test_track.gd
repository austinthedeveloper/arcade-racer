## Track building and the stages.
extends TestSuite


func _stages() -> Array[Track]:
	var out: Array[Track] = []
	for i in Stages.count():
		out.append(Stages.build(i))
	return out


func test_every_stage_builds() -> void:
	for t in _stages():
		check(t.segments.size() > 1000, "%s is a full stage (%d segments)" % [t.name, t.segments.size()])
		eq(t.length, t.segments.size() * Cfg.SEGMENT_LENGTH, t.name + " length")
		check(t.finish_index > 0 and t.finish_index < t.segments.size(), t.name + " finish on the track")
		check(t.segments[t.finish_index].flags & Segment.FLAG_FINISH, t.name + " finish flag")


func test_stage_order_and_names() -> void:
	eq(Stages.count(), 2, "two stages")
	eq(Stages.build(0).name, "Palm Coast Boulevard", "stage 1")
	eq(Stages.build(1).name, "Redrock Canyon", "stage 2")
	for i in Stages.count():
		eq(Stages.stage_name(i), Stages.build(i).name, "listed name of stage %d" % (i + 1))
	eq(Stages.next(0), 1, "Palm Coast leads to Redrock")
	eq(Stages.next(Stages.count() - 1), -1, "nothing after the last stage")


func test_stages_have_their_own_look() -> void:
	var palm := Stages.build(0).theme
	var rock := Stages.build(1).theme
	check(palm["background"] != rock["background"], "different backgrounds")
	check(palm["grass"][0] != rock["grass"][0], "different ground")
	for t in _stages():
		check(ResourceLoader.exists(t.theme["background"]), t.name + " background exists")


func test_checkpoints_are_in_order_before_the_finish() -> void:
	for t in _stages():
		eq(t.checkpoints.size(), 3, t.name + " has three checkpoints")
		var last := 0
		for c in t.checkpoints:
			check(c > last, "%s checkpoint %d after %d" % [t.name, c, last])
			check(t.segments[c].flags & Segment.FLAG_CHECKPOINT, "checkpoint flag at %d" % c)
			last = c
		check(last < t.finish_index, t.name + " checkpoints all before the finish")


func test_road_height_is_continuous() -> void:
	for t in _stages():
		var jump := -1
		for i in range(1, t.segments.size()):
			if t.segments[i].w1.y != t.segments[i - 1].w2.y:
				jump = i
				break
		eq(jump, -1, t.name + " height jumps at segment")


func test_find_segment_wraps() -> void:
	var t := flat_track(100)
	eq(t.find_segment(0.0).index, 0, "start")
	eq(t.find_segment(Cfg.SEGMENT_LENGTH * 1.5).index, 1, "inside segment 1")
	eq(t.find_segment(t.length + 10.0).index, 0, "past the end wraps")
	eq(t.find_segment(-10.0).index, 99, "before the start wraps")


func test_height_interpolates_within_a_segment() -> void:
	var t := Track.new()
	t.add_segment(0.0, 100.0)
	t.add_segment(0.0, 100.0)
	t.finish_building(1)
	near(t.height_at(Cfg.SEGMENT_LENGTH * 0.5), 50.0, 0.01, "halfway up")


func test_roadside_sprites_stay_off_the_road() -> void:
	for t in _stages():
		var bad := 0
		for seg in t.segments:
			for sp in seg.sprites:
				if absf(sp["offset"]) < 1.0:
					bad += 1
		eq(bad, 0, t.name + " sprites placed on the road")


func test_every_placed_sprite_has_art() -> void:
	for t in _stages():
		var missing := {}
		for seg in t.segments:
			for sp in seg.sprites:
				if not SpriteLibrary.defs.has(sp["id"]):
					missing[sp["id"]] = true
		eq(missing.keys(), [], t.name + " sprites without art")


func test_redrock_has_its_landmarks() -> void:
	var counts := {}
	for seg in Redrock.build().segments:
		for sp in seg.sprites:
			counts[sp["id"]] = counts.get(sp["id"], 0) + 1
	for id in ["diner", "gas_station", "windmill", "rock_arch", "rock_pillar", "saguaro_a", "tumbleweed_a"]:
		check(counts.get(id, 0) > 0, "Redrock has a " + id)
	eq(counts.get("diner", 0), 1, "one diner stop")
	check(not counts.has("palm_tall_a"), "no palms in the desert")
