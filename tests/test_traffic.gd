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
		near(moved, fposmod(c.speed * 10.0, t.length), 1.0, "car %d moved speed x time" % i)
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
		if seg.index > 450 and seg.index < 500:
			seen += 1
			check(seg.lane_offsets().has(c.offset), "a boulevard car in one of its six lanes (%.3f)" % c.offset)
			if absf(c.offset) > 1.0:
				outer += 1
	check(seen > 0, "cars on the boulevard")
	check(outer > 0, "some in the outer lanes, past the usual road's edge")
