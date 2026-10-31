## Points and bonuses (Scoring): one test per rule, then the race keeping score.
extends TestSuite


func test_place_points() -> void:
	eq([Scoring.place_points(1), Scoring.place_points(2), Scoring.place_points(3), Scoring.place_points(8)],
		[20, 15, 12, 2], "the table")
	eq(Scoring.place_points(9), 0, "past the table")
	eq(Scoring.place_points(0), 0, "no place")


func test_near_miss() -> void:
	var fast := Cfg.MAX_SPEED * 0.9
	var half := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	check(Scoring.near_miss(0.0, fast, half * 2.0 + 0.05, 1.0), "a hand's width off its side")
	check(not Scoring.near_miss(0.0, fast, half * 2.0 + Scoring.NEAR_MISS_ROOM + 0.05, 1.0), "a lane away")
	check(not Scoring.near_miss(0.0, fast, 0.1, 1.0), "that would have been a hit")
	check(not Scoring.near_miss(0.0, Cfg.MAX_SPEED * 0.3, half * 2.0 + 0.05, 1.0), "too slow to count")
	check(Scoring.near_miss(0.0, fast, half * 2.6 + 0.05, 1.6), "a wide truck's side")


func test_air() -> void:
	eq(Scoring.air_points(0.3), 0, "a hop")
	eq(Scoring.air_points(Scoring.AIR_TIME), Scoring.AIR, "air")
	eq(Scoring.air_points(Scoring.BIG_AIR_TIME + 0.2), Scoring.BIG_AIR, "big air")


func test_clean_section_and_no_crash() -> void:
	eq(Scoring.clean_section_points(0), Scoring.CLEAN_SECTION, "untouched")
	eq(Scoring.clean_section_points(1), 0, "one bump spoils it")
	eq(Scoring.no_crash_points(0), Scoring.NO_CRASH, "no crash")
	eq(Scoring.no_crash_points(2), 0, "crashed")


func test_the_tally() -> void:
	var s := Scoring.new()
	s.add("NEAR MISS", 1)
	s.add("NEAR MISS", 1)
	s.add("BIG AIR", 2)
	s.add("NOTHING", 0)
	eq(s.total(), 4, "total")
	eq(s.summary(), [{"name": "NEAR MISS", "count": 2, "points": 2}, {"name": "BIG AIR", "count": 1, "points": 2}] as Array[Dictionary], "grouped")
	s.checkpoint()
	s.contacts = 1
	s.finish(2, true)
	eq(s.total(), 4 + Scoring.CLEAN_SECTION + Scoring.NO_CRASH + 15, "a clean first section, no crashes and 2nd place")


func test_watch_counts_contacts_air_and_drafts() -> void:
	var t := flat_track()
	var s := Scoring.new()
	var p := PlayerCar.new()
	p.reset(2000.0)
	p.bumped = true
	s.watch(DT, p, t)
	eq(s.contacts, 1, "a bump is a contact")
	p.bumped = false
	p.airborne = true
	for i in 70:
		s.watch(DT, p, t)
	p.airborne = false
	p.landed = true
	s.watch(DT, p, t)
	eq(s.bonuses[-1]["name"], "BIG AIR", "a long jump")
	p.draft_time = 1.0
	s.watch(DT, p, t)
	s.watch(DT, p, t)
	eq(s.bonuses[-1]["name"], "SLIPSTREAM", "a draft boost, once")
	eq(s.bonuses.size(), 2, "only those")


func test_passing_close_to_traffic_is_a_near_miss() -> void:
	var t := flat_track()
	var s := Scoring.new()
	var p := PlayerCar.new()
	p.reset(4000.0)
	p.speed = Cfg.MAX_SPEED
	p.x = 0.0
	p.last_position = p.position - 200.0
	var car := Traffic.TrafficCar.new()
	car.z = p.position + Cfg.PLAYER_Z - 20.0  # its rear passed your nose this tick
	car.last_z = car.z - 5.0
	car.offset = 0.55
	car.speed = Cfg.MAX_SPEED * 0.3
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	s.watch(DT, p, t)
	eq(s.bonuses.size(), 1, "one near miss")
	car.offset = 0.75
	s.bonuses.clear()
	s.watch(DT, p, t)
	eq(s.bonuses.size(), 0, "a lane over is no near miss")


func test_the_race_keeps_score() -> void:
	var r := race(true, true, 0)
	run_until(r, func(): return r.state == r.State.FINISHED, Golden.FRAMES)
	var names := {}
	for b in r.score.bonuses:
		names[b["name"]] = true
	check(names.has(Rivals.ordinal(r.place) + " PLACE"), "points for the place")
	check(r.score.total() >= Scoring.place_points(r.place), "a total (%d)" % r.score.total())
	check(names.has("NEAR MISS") or names.has("AIR") or names.has("BIG AIR"), "some bonuses on the way (%s)" % str(names.keys()))
