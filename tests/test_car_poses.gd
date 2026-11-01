## The car-angle review sheet's posing (CarPoses, tools/car_angles.gd): steering values that
## land on every strip frame, and spots on the road that give the pitch asked for.
extends TestSuite


func test_steer_values_hit_every_frame_once() -> void:
	var values := CarPoses.steer_values()
	eq(values.size(), CarSprites.PLAYER_FRAMES, "one value per frame")
	for f in values.size():
		eq(CarSprites.steer_frame(values[f]), f, "value %s shows frame %d" % [values[f], f])
	eq(values[0], -1.0, "hard left first")
	eq(values[-1], 1.0, "hard right last")


func test_slopes_cover_both_ways_past_the_strip_switch() -> void:
	var pitches: Array = CarPoses.SLOPES.map(func(s: Array) -> float: return s[1])
	check(0.0 in pitches, "a level pose")
	for dir in [-1.0, 1.0]:
		check(pitches.any(func(p: float) -> bool: return p * dir >= CarSprites.PITCH_SWITCH and p * dir < 1.0),
			"a gentle slope past the switch, sign %s" % dir)
		check(pitches.has(dir), "a full-pitch slope, sign %s" % dir)


## Flat road, then a straight climb, a crest, and a straight drop
func _hill_track() -> Track:
	var t := Track.new()
	var y := 0.0
	for i in 600:
		if i >= 200 and i < 300:
			y += 120.0  # uphill: about 31 degrees
		elif i >= 300 and i < 400:
			y -= 60.0  # downhill: about 17 degrees
		t.add_segment(0.4 if i >= 500 else 0.0, y)
	t.finish_building(590)
	return t


func test_pitch_at_follows_the_slope() -> void:
	var t := _hill_track()
	near(CarPoses.pitch_at(t, 100.5 * Cfg.SEGMENT_LENGTH), 0.0, 0.001, "flat")
	near(CarPoses.pitch_at(t, 250.5 * Cfg.SEGMENT_LENGTH), -1.0, 0.001, "steep climb is full nose-up")
	near(CarPoses.pitch_at(t, 350.5 * Cfg.SEGMENT_LENGTH), PlayerCar.pitch_for_slope(-60.0 / Cfg.SEGMENT_LENGTH), 0.001,
		"the drop is the car's own pitch for that slope")


func test_find_spot_picks_the_hill_asked_for() -> void:
	var t := _hill_track()
	var up := CarPoses.find_spot(t, -1.0)
	check(up >= 200 and up < 300, "full nose-up on the climb (got %d)" % up)
	var down := CarPoses.find_spot(t, PlayerCar.pitch_for_slope(-0.3))
	check(down >= 300 and down < 400, "nose-down on the drop (got %d)" % down)
	var level := CarPoses.find_spot(t, 0.0)
	check(level >= CarPoses.SKIP_START and level < 200 - CarPoses.STRAIGHT_AHEAD,
		"level on the flat straight past the start, clear of the climb (got %d)" % level)


func test_find_spot_prefers_a_straight() -> void:
	var t := _hill_track()
	check(CarPoses.spot_score(t, 150, 0.0) > CarPoses.spot_score(t, 520, 0.0), "flat straight beats flat bend")


func test_every_stage_has_every_pose() -> void:
	for i in Stages.count():
		var t := Stages.build(i)
		for slope: Array in CarPoses.SLOPES:
			var seg := CarPoses.find_spot(t, slope[1])
			check(seg >= CarPoses.SKIP_START, "stage %d has a %s spot" % [i + 1, slope[0]])
