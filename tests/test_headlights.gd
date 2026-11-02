## Headlights at night (WS-17): on the dark stages every car throws a pool of light ahead of
## it, which follows the car across the road, and the tail lights glow brighter.
extends TestSuite

const PALM := 0
const NEON := 2
const HARVEST := 5
const THUNDERHEAD := 6
const SKYLINE := 7


func test_on_for_the_dark_stages() -> void:
	for i in Stages.count():
		var dark := i in [NEON, THUNDERHEAD, SKYLINE]
		eq(Headlights.on(Stages.theme(i)), dark, "%s: headlights %s" % [Stages.stage_name(i), "on" if dark else "off"])
	var n := Stages.count()
	for i in n:
		var t := Sundown.theme_at(Stages.theme(i), Sundown.tour_hour(i, n))
		eq(Headlights.on(t), i in [NEON, THUNDERHEAD, SKYLINE], "%s in a tour" % Stages.stage_name(i))
	check(Headlights.on(Sundown.theme_at(Stages.theme(PALM), 23.0)), "any stage shown at night")


## The test the story asks for: the pool follows the car's x, at every step out along it.
func test_the_pool_follows_the_car_x() -> void:
	for x in [-0.9, -0.3, 0.0, 0.4, 1.2]:
		for k in 11:
			near(Headlights.pool(x, k / 10.0).x, x, 0.00001, "centered on the car (x %s, %d0%%)" % [x, k])
	check(Headlights.pool(0.0, 0.9).y > Headlights.pool(0.0, 0.1).y, "it widens out")
	check(Headlights.pool(0.0, 0.2).z > Headlights.pool(0.0, 0.8).z, "and fades")
	eq(Headlights.pool(0.0, 1.0).z, 0.0, "gone at its end")
	# On screen: a segment ahead, the pool drawn from two cars' x. Its middle is where each
	# car's x lands on that segment, so it moves across with the car.
	var seg := Segment.new()
	seg.s1 = Vector2(300.0, 250.0)
	seg.s2 = Vector2(305.0, 240.0)
	seg.scale1 = 0.0004
	seg.scale2 = 0.00035
	for x in [-0.5, 0.0, 0.7]:
		var a := Headlights.pool(x, 0.3)
		var b := Headlights.pool(x, 0.35)
		var pts := RoadRenderer.road_trapezoid(seg, Vector3(0.0, a.x - a.y, a.x + a.y), Vector3(1.0, b.x - b.y, b.x + b.y))
		near((pts[0].x + pts[1].x) / 2.0, seg.s1.x + seg.scale1 * x * Cfg.ROAD_WIDTH * Cfg.PROJ, 0.001, "the near edge's middle under the car's x (%s)" % x)
		near((pts[2].x + pts[3].x) / 2.0, seg.s2.x + seg.scale2 * x * Cfg.ROAD_WIDTH * Cfg.PROJ, 0.001, "and the far edge's (%s)" % x)


## The pool lies on the road from just ahead of the car out to its reach, and nowhere else;
## the oncoming traffic's points back toward the camera; it runs on round the lap.
func test_the_pool_lies_ahead_of_the_car() -> void:
	var length := 200000.0
	var reach := Tuning.v("world/headlight_reach")
	var car_z := 50000.0
	var lit := 0.0
	var first := INF
	var last := -INF
	for i in range(240, 280):
		var z := i * Cfg.SEGMENT_LENGTH
		var sl := Headlights.slice(z, car_z, 1.0, length)
		if sl.x < 0.0:
			continue
		check(sl.x <= sl.y and sl.x >= 0.0 and sl.y <= 1.0, "a part of the segment")
		lit += (sl.y - sl.x) * Cfg.SEGMENT_LENGTH
		first = minf(first, z + sl.x * Cfg.SEGMENT_LENGTH)
		last = maxf(last, z + sl.y * Cfg.SEGMENT_LENGTH)
		check(sl.w >= sl.z, "further out at the far end")
	near(lit, reach, 0.01, "as long as its reach")
	near(first, car_z + Headlights.GAP, 0.01, "from the car's nose")
	near(last, car_z + Headlights.GAP + reach, 0.01, "to the reach")
	eq(Headlights.slice(car_z - 1000.0, car_z, 1.0, length).x, -1.0, "nothing behind the car")
	var back := Headlights.slice(car_z - Headlights.GAP - 1000.0, car_z, -1.0, length)
	check(back.x >= 0.0, "oncoming: the pool comes toward the camera")
	check(back.z > back.w, "its near end further out from that car")
	eq(Headlights.slice(car_z + 1000.0, car_z, -1.0, length).x, -1.0, "and nothing behind it")
	var wrap := Headlights.slice(0.0, length - 500.0, 1.0, length)
	check(wrap.x >= 0.0, "across the start line")


func test_tail_lights_glow_either_side() -> void:
	var rects := Headlights.tail_rects(Vector2(320.0, 300.0), 100.0, 60.0)
	eq(rects.size(), 2, "one each side")
	near(rects[0].get_center().x + rects[1].get_center().x, 640.0, 0.001, "either side of the middle")
	check(rects[0].end.y <= 300.0, "on the back of the car, not under it")
	var halo := Headlights.tail_rects(Vector2(320.0, 300.0), 100.0, 60.0, true)
	check(halo[0].size.x > rects[0].size.x, "a halo round them")
	check(halo[0].get_center().is_equal_approx(rects[0].get_center()), "centered on them")


## In a race: on for Neon Strip, the player's car lamp at its x; off on Palm Coast.
func test_in_a_race() -> void:
	var neon := race(false, true, NEON, true)
	drive(neon, 30, input(1.0))
	check(Headlights.on(neon.track.theme), "Neon Strip: on")
	var drawn: Array[Segment] = []
	for i in 60:
		drawn.append(neon.track.find_segment(neon.player.position + i * Cfg.SEGMENT_LENGTH))
	var lamps: Array[Vector3] = neon.road.lamps(drawn, neon.player.position + Cfg.PLAYER_Z, neon.player.x)
	eq(lamps[0], Vector3(neon.player.position + Cfg.PLAYER_Z, neon.player.x, 1.0), "the player's lamp at its z and x")
	eq(lamps.size(), 1 + neon.rivals.cars.size() + _cars_in(drawn), "and every rival's and car's")
	var palm := race(false, true, PALM, true)
	check(not Headlights.on(palm.track.theme), "Palm Coast: off")


func _cars_in(drawn: Array[Segment]) -> int:
	var n := 0
	for s in drawn:
		n += s.cars.size()
	return n
