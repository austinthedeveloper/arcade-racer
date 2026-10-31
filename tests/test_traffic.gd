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
		check(Traffic.LANE_OFFSETS.has(c.offset), "lane offset %s" % c.offset)
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
