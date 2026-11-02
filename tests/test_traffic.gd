## Traffic spawning and movement.
extends TestSuite


func _count_in_segments(t: Track) -> int:
	var n := 0
	for seg in t.segments:
		n += seg.cars.size()
	return n


func test_spawn_places_cars_in_lanes() -> void:
	var t := PalmCoast.build()
	var tr := Traffic.new()
	tr.spawn(t, 70)
	eq(tr.cars.size(), 70, "count")
	eq(_count_in_segments(t), 70, "each car in exactly one segment")
	for c in tr.cars:
		check(c.segment.lane_offsets().has(c.offset), "lane offset %s" % c.offset)
		check(CarSprites.traffic.has(c.sprite), "known sprite %s" % c.sprite)
		check(c.width_mult > 0.5 and c.width_mult < 2.0, "%s width %.2f" % [c.sprite, c.width_mult])
		check(c.speed > 0.0 and c.speed < Cfg.MAX_SPEED, "slower than the player")
		check(c.segment.cars.has(c), "listed in its segment")


func test_spawn_is_deterministic() -> void:
	var a := Traffic.new()
	var b := Traffic.new()
	a.spawn(PalmCoast.build(), 20)
	b.spawn(PalmCoast.build(), 20)
	for i in 20:
		eq([a.cars[i].z, a.cars[i].sprite, a.cars[i].offset], [b.cars[i].z, b.cars[i].sprite, b.cars[i].offset], "car %d" % i)


func test_spawn_clears_old_cars() -> void:
	var t := PalmCoast.build()
	var tr := Traffic.new()
	tr.spawn(t, 30)
	tr.spawn(t, 10)
	eq(_count_in_segments(t), 10, "only the new cars")


func test_cars_move_and_change_segments() -> void:
	var t := flat_track(200)
	var tr := Traffic.new()
	tr.spawn(t, 15)
	var start: Array[float] = []
	for c in tr.cars:
		start.append(c.z)
	for i in 600:
		tr.update(DT, t)
	for i in tr.cars.size():
		var c: Traffic.TrafficCar = tr.cars[i]
		var moved := fposmod(c.z - start[i], t.length)
		var way := -1.0 if c.oncoming else 1.0
		near(moved, fposmod(way * c.speed * 10.0, t.length), 1.0, "car %d moved speed x time, its way" % i)
		check(c.segment == t.find_segment(c.z), "car %d listed in the right segment" % i)
	eq(_count_in_segments(t), 15, "no car lost or doubled")


func test_every_traffic_sprite_exists() -> void:
	for id in Traffic.CARS + Traffic.BIG + Traffic.SPECIALS:
		check(CarSprites.traffic.has(id), id + " has a sprite")
	for i in Stages.count():
		var t := Stages.build(i)
		var specials: Array = t.theme.get("specials", [])
		check(not specials.is_empty(), t.name + " has its own locals")
		for id in specials:
			check(CarSprites.traffic.has(id), "%s local %s has a sprite" % [t.name, id])


func test_stage_locals_show_up_in_traffic() -> void:
	var t := HarvestValley.build()
	var tr := Traffic.new()
	tr.spawn(t, 200)
	var seen := {}
	for car in tr.cars:
		seen[car.sprite] = true
	check(seen.has("combine") or seen.has("tractor"), "farm machines on the Harvest road")
	check(not seen.has("surf_van"), "no Palm Coast surf vans in Harvest Valley")


# --- Road width (WS-7) -----------------------------------------------------------

## A flat track that narrows to two lanes from segment 200 to 300 and opens out to six from
## 400 to 500.
func _narrows_and_widens() -> Track:
	var t := flat_track(700)
	t.set_width(200, 100, 0.6, 2)
	t.set_width(400, 100, 1.5, 6)
	return t


func test_traffic_stays_on_the_road_through_a_narrowing() -> void:
	var t := _narrows_and_widens()
	var tr := Traffic.new()
	tr.spawn(t, 120)
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var worst := 0.0
	var narrowed := 0
	var in_lane := 0
	for i in 1200:
		tr.update(DT, t)
		for c in tr.cars:
			worst = maxf(worst, absf(c.offset) + half_car - t.width_at(c.z))
			if c.segment.index >= 220 and c.segment.index < 300:
				narrowed += 1
				if c.segment.lane_offsets().has(c.offset):
					in_lane += 1
	check(narrowed > 1000, "cars drove through the narrowing (%d car-ticks)" % narrowed)
	check(worst <= 0.0001, "every car's wheels on the road (worst %.3f over the edge)" % worst)
	check(in_lane > narrowed * 0.9, "and in its two lanes once there (%d of %d)" % [in_lane, narrowed])


func test_traffic_moves_into_the_lanes_of_a_wider_road() -> void:
	var t := _narrows_and_widens()
	var tr := Traffic.new()
	tr.spawn(t, 120)
	for i in 1200:
		tr.update(DT, t)
	var outer := 0
	var seen := 0
	for c in tr.cars:
		var seg := c.segment
		if seg.index > 450 and seg.index < 500 and c.signal_dir == 0:
			seen += 1
			check(seg.lane_offsets().has(c.offset), "a boulevard car in one of its six lanes (%.3f)" % c.offset)
			if absf(c.offset) > 1.0:
				outer += 1
	check(seen > 0, "cars on the boulevard")
	check(outer > 0, "some in the outer lanes, past the usual road's edge")


# --- Oncoming traffic and lane-change tells (RC-11, CP-6) -------------------------

func test_an_undivided_road_has_oncoming_traffic_in_its_left_lanes() -> void:
	var t := PalmCoast.build()
	var tr := Traffic.new()
	tr.spawn(t, 200)
	var oncoming := 0
	for c in tr.cars:
		check(c.oncoming == (c.offset < 0.0), "%s at %.2f: oncoming only left of the middle" % [c.sprite, c.offset])
		if c.oncoming:
			oncoming += 1
			check(CarSprites.has_front(c.sprite), "an oncoming %s has a front view" % c.sprite)
			check(c.change_in == INF, "oncoming cars keep their lane")
	check(oncoming > 50 and oncoming < 150, "about half oncoming (%d of 200)" % oncoming)


func test_a_divided_road_has_none() -> void:
	for t: Track in [NeonStrip.build(), Stages.build(Stages.count() - 1)]:
		check(Traffic.divided(t), t.name + " is divided")
		var tr := Traffic.new()
		tr.spawn(t, 100)
		check(tr.cars.all(func(c: Traffic.TrafficCar) -> bool: return not c.oncoming), t.name + ": all one way")


func test_oncoming_traffic_on_a_mirrored_stage_keeps_to_the_other_side() -> void:
	var t := PalmCoast.build()
	t.mirrored = true
	var tr := Traffic.new()
	tr.spawn(t, 100)
	for c in tr.cars:
		check(c.oncoming == (c.offset > 0.0), "mirrored: oncoming on the right (%.2f)" % c.offset)


## One car alone on a flat road, in lane `k` of 4, set to change lanes on the next tick.
func _changer(t: Track, k: int, sprite := "sedan_tan") -> Traffic:
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var c := Traffic.TrafficCar.new()
	c.z = 50.0 * Cfg.SEGMENT_LENGTH
	c.speed = Cfg.MAX_SPEED * 0.4
	c.sprite = sprite
	c.lane_frac = (k + 0.5) / 4.0
	c.offset = t.segments[0].lane_x(k) * t.side()
	c.lane = c.offset
	c.change_in = 0.001
	c.segment = t.find_segment(c.z)
	c.segment.cars.append(c)
	tr.cars.append(c)
	return tr


func test_a_signalling_car_changes_lanes_after_the_delay() -> void:
	var t := flat_track()
	var tr := _changer(t, 2)
	var c: Traffic.TrafficCar = tr.cars[0]
	tr.update(DT, t)
	eq(c.signal_dir, 1, "on an undivided road it can only go right, away from the oncoming lanes")
	eq(Traffic.light_state(c), "right", "the right signal lights at once")
	var ticks := 0
	while c.signal_age < Tuning.v("traffic/signal_time") - DT:
		tr.update(DT, t)
		ticks += 1
		eq(c.offset, 0.25, "holds its lane while signalling")
	check(ticks > 50, "signals for a second first")
	var lit := 0
	for i in 120:
		tr.update(DT, t)
		if Traffic.light_state(c) != "":
			lit += 1
	near(c.offset, 0.75, 0.001, "then moves over a lane")
	eq(c.signal_dir, 0, "and the signal goes off")
	eq(Traffic.light_state(c), "", "lights off")
	check(lit > 0 and lit < 100, "it blinks on the way (%d lit ticks)" % lit)
	check(c.change_in >= Traffic.CHANGE_EVERY[0], "and waits before the next change")


func test_a_changer_never_moves_into_the_oncoming_lanes() -> void:
	var t := flat_track()
	var tr := _changer(t, 3)
	var c: Traffic.TrafficCar = tr.cars[0]
	for i in 60 * 120:
		tr.update(DT, t)
		check(c.lane_frac > 0.5, "stays on its side of the road")
		if c.lane_frac < 0.5:
			break


func test_a_divided_road_lets_a_changer_use_every_lane() -> void:
	var t := flat_track()
	t.theme["divided"] = true
	var tr := _changer(t, 1)
	var c: Traffic.TrafficCar = tr.cars[0]
	var seen := {}
	for i in 60 * 240:
		tr.update(DT, t)
		seen[Traffic.lane_index(c.lane_frac, 4)] = true
	eq(seen.size(), 4, "all four lanes over four minutes")


func test_a_mirrored_stage_mirrors_the_signal() -> void:
	var t := flat_track()
	t.mirrored = true
	var tr := _changer(t, 2)
	var c: Traffic.TrafficCar = tr.cars[0]
	tr.update(DT, t)
	eq(c.signal_dir, -1, "the mirror image: left, toward the edge")
	for i in 150:
		tr.update(DT, t)
	near(c.offset, -0.75, 0.001, "and moves left")


func test_no_change_into_a_taken_lane() -> void:
	var t := flat_track()
	var tr := _changer(t, 2)
	var c: Traffic.TrafficCar = tr.cars[0]
	var other := Traffic.TrafficCar.new()
	other.z = c.z + Cfg.SEGMENT_LENGTH
	other.speed = c.speed
	other.sprite = "semi"
	other.lane_frac = 3.5 / 4.0
	other.offset = 0.75
	other.lane = 0.75
	other.segment = t.find_segment(other.z)
	other.segment.cars.append(other)
	tr.cars.append(other)
	tr.update(DT, t)
	eq(c.signal_dir, 0, "the next lane is taken: no signal")
	near(c.change_in, Tuning.v("traffic/change_retry"), 0.001, "tries again shortly")


func test_the_right_frame_per_state() -> void:
	CarSprites.load_all()
	var def: Dictionary = CarSprites.traffic["sedan_tan"]
	eq(CarSprites.traffic_texture("sedan_tan", false), def["tex"], "lights off: the rear view")
	for state in ["brake", "left", "right"]:
		eq(CarSprites.traffic_texture("sedan_tan", false, state), def["lights"][state], state + " frame (TRF-10)")
	eq(CarSprites.traffic_texture("semi", true), CarSprites.traffic["semi"]["front"], "oncoming: the front view")
	eq(CarSprites.traffic_texture("semi", false, "left"), CarSprites.traffic["semi"]["tex"], "no signal frames: the rear view")
	for id in Traffic.CARS:
		if id != "sedan_beige":
			check(CarSprites.signals(id), id + " can signal")
	for id in Traffic.CARS:
		if id != "sedan_tan":
			check(CarSprites.has_front(id), id + " can come the other way")
	var front: Texture2D = CarSprites.traffic["bus"]["front"]
	eq(front.get_width(), CarSprites.traffic["bus"]["tex"].get_width(), "a front view is as wide as the rear")


func test_signal_frames_differ_only_on_their_side() -> void:
	CarSprites.load_all()
	for id in Traffic.CARS:
		if not CarSprites.signals(id) or id == "sedan_tan":
			continue
		var rear: Image = CarSprites.traffic[id]["tex"].get_image()
		for side in ["left", "right"]:
			var lit: Image = CarSprites.traffic[id]["lights"][side].get_image()
			var changed := 0
			var wrong_side := 0
			for y in rear.get_height():
				for x in rear.get_width():
					if rear.get_pixel(x, y) != lit.get_pixel(x, y):
						changed += 1
						if (x < rear.get_width() / 2) != (side == "left"):
							wrong_side += 1
			check(changed > 2, "%s %s: some lamp lit" % [id, side])
			eq(wrong_side, 0, "%s %s: only that side" % [id, side])


# --- Fair traffic (RC-14) ----------------------------------------------------------

## The first of `tr`'s cars within traffic/spawn_clear segments past segment `from`, or null.
func _car_past(t: Track, tr: Traffic, from: int) -> Traffic.TrafficCar:
	var n := t.segments.size()
	for c in tr.cars:
		if posmod(c.segment.index - from, n) < Tuning.i("traffic/spawn_clear"):
			return c
	return null


func test_jumps_are_blind_crests_but_rolls_and_bumps_are_not() -> void:
	var t := flat_track(100)
	t.jump()
	var jump_end := t.segments.size()
	t.straight(50)
	var rolls := t.segments.size()
	t.low_rolling_hills()
	t.bumps()
	t.straight(50)
	var crests := t.blind_crests()
	eq(crests.size(), 1, "one blind crest: %s" % [crests])
	check(not crests.is_empty() and crests[0] > 100 and crests[0] < jump_end, "the jump's top")
	check(crests.all(func(i: int) -> bool: return i < rolls), "none over the rolls or the bumps")
	for s in Stages.count():
		check(not Stages.build(s).blind_crests().is_empty(), "stage %d has a blind crest" % s)


func test_no_traffic_spawns_past_a_blind_crest() -> void:
	for s in Stages.count():
		var t := Stages.build(s)
		var tr := Traffic.new()
		tr.spawn(t, 300)
		for crest in t.blind_crests():
			var c := _car_past(t, tr, crest)
			check(c == null, "%s: no car spawned just past the crest at %d (one at %d)" % [t.name, crest, c.segment.index if c else -1])


func test_no_traffic_spawns_in_a_tunnel_mouth() -> void:
	for t: Track in [NeonStrip.build(), Timberline.build()]:
		var mouths := t.tunnel_mouths()
		eq(mouths.size(), 1, t.name + " has one tunnel")
		var tr := Traffic.new()
		tr.spawn(t, 300)
		for m in mouths:
			check(_car_past(t, tr, m) == null, "%s: nothing spawned through the mouth at %d" % [t.name, m])


func test_no_traffic_spawns_ahead_of_the_players_start() -> void:
	var t := PalmCoast.build()
	var tr := Traffic.new()
	tr.spawn(t, 1000, 7, 800 * Cfg.SEGMENT_LENGTH)
	check(_car_past(t, tr, 800) == null, "the road ahead of a start partway in is clear")
	var plain := Traffic.new()
	plain.spawn(t, 1000)
	check(_car_past(t, plain, 800) != null, "where it would have had traffic")


func test_keep_clear_is_the_same_mirrored() -> void:
	eq(Traffic.keep_clear(PalmCoast.build(), 14), Traffic.keep_clear(Stages.build(0, true), 14),
		"mirroring clears the same stretches")


## A car in lane `k` of 4 on `t`, rammed away from `from_x`.
func _rammed(t: Track, tr: Traffic, k: int, from_x: float) -> Traffic.TrafficCar:
	var c := Traffic.TrafficCar.new()
	c.z = 50.0 * Cfg.SEGMENT_LENGTH
	c.speed = Cfg.MAX_SPEED * 0.4
	c.sprite = "sedan_tan"
	c.lane_frac = (k + 0.5) / 4.0
	c.offset = t.segments[0].lane_x(k) * t.side()
	c.lane = c.offset
	c.segment = t.find_segment(c.z)
	c.segment.cars.append(c)
	tr.cars.append(c)
	Traffic.fling(c, from_x)
	return c


## A car in lane `k`, `ahead` segments on from `like`, going as fast.
func _blocker(t: Track, tr: Traffic, k: int, like: Traffic.TrafficCar, ahead: int) -> void:
	var o := Traffic.TrafficCar.new()
	o.z = like.z + ahead * Cfg.SEGMENT_LENGTH
	o.speed = like.speed
	o.sprite = "semi"
	o.lane_frac = (k + 0.5) / 4.0
	o.offset = t.segments[0].lane_x(k) * t.side()
	o.lane = o.offset
	o.segment = t.find_segment(o.z)
	o.segment.cars.append(o)
	tr.cars.append(o)


func _land(t: Track, tr: Traffic, c: Traffic.TrafficCar) -> void:
	for i in 600:
		tr.update(DT, t)
	check(c.solid(), "solid again")


func test_a_rammed_car_lands_back_in_its_own_lane_when_clear() -> void:
	var t := flat_track()
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var c := _rammed(t, tr, 2, 0.0)
	_land(t, tr, c)
	near(c.offset, 0.25, 0.001, "its own lane")


func test_a_rammed_car_comes_back_in_a_clear_lane() -> void:
	var t := flat_track()
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var c := _rammed(t, tr, 2, 0.5)  # knocked left, toward the oncoming lanes
	_blocker(t, tr, 2, c, 1)  # its lane taken while it flies
	_land(t, tr, c)
	near(c.offset, 0.75, 0.001, "the clear lane its way, not its taken one or an oncoming one")
	eq(Traffic.lane_index(c.lane_frac, 4), 3, "and keeps to it")


func test_a_rammed_car_on_a_mirrored_stage_comes_back_mirrored() -> void:
	var t := flat_track()
	t.mirrored = true
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var c := _rammed(t, tr, 2, -0.5)
	_blocker(t, tr, 2, c, 1)
	_land(t, tr, c)
	near(c.offset, -0.75, 0.001, "the mirror image")


func test_with_every_lane_its_way_taken_it_goes_home() -> void:
	var t := flat_track()
	var tr := Traffic.new()
	tr.spawn(t, 0)
	var c := _rammed(t, tr, 2, 0.0)
	_blocker(t, tr, 2, c, 1)
	_blocker(t, tr, 3, c, 2)
	_land(t, tr, c)
	near(c.offset, 0.25, 0.001, "its own lane")


func test_nothing_spawns_coming_the_other_way_to_meet_the_grid() -> void:
	for mirror in [false, true]:
		var t := Stages.build(0, mirror)
		var tr := Traffic.new()
		tr.spawn(t, 1000)
		var near_start := 0
		for c in tr.cars:
			if c.segment.index < Tuning.i("traffic/oncoming_clear"):
				near_start += 1
				check(not c.oncoming, "no oncoming car at segment %d, ahead of the grid" % c.segment.index)
				check(c.oncoming == (c.offset * t.side() < 0.0), "and each on its side of the road")
		check(near_start > 0, "cars there, all going the player's way")
