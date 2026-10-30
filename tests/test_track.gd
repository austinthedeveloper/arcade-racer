## Track building and the Palm Coast stage.
extends TestSuite


func test_palm_coast_builds() -> void:
	var t := PalmCoast.build()
	check(t.segments.size() > 1000, "a full stage (%d segments)" % t.segments.size())
	eq(t.length, t.segments.size() * Cfg.SEGMENT_LENGTH, "length")
	check(t.finish_index > 0 and t.finish_index < t.segments.size(), "finish on the track")
	check(t.segments[t.finish_index].flags & Segment.FLAG_FINISH, "finish flag")


func test_checkpoints_are_in_order_before_the_finish() -> void:
	var t := PalmCoast.build()
	eq(t.checkpoints.size(), 3, "three checkpoints")
	var last := 0
	for c in t.checkpoints:
		check(c > last, "checkpoint %d after %d" % [c, last])
		check(t.segments[c].flags & Segment.FLAG_CHECKPOINT, "checkpoint flag at %d" % c)
		last = c
	check(last < t.finish_index, "all before the finish")


func test_road_height_is_continuous() -> void:
	var t := PalmCoast.build()
	for i in range(1, t.segments.size()):
		if t.segments[i].w1.y != t.segments[i - 1].w2.y:
			check(false, "height jumps at segment %d" % i)
			return
	check(true)


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
	var t := PalmCoast.build()
	var bad := 0
	for seg in t.segments:
		for sp in seg.sprites:
			if absf(sp["offset"]) < 1.0:
				bad += 1
	eq(bad, 0, "sprites placed on the road")
