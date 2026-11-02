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
	check(Scoring.near_miss(0.0, fast, half * 2.0 - 0.05, 1.0), "shaving its side")
	# Review on #118: lane center to lane center in the next lane is an ordinary pass
	check(not Scoring.near_miss(0.0, fast, Traffic.LANE_OFFSETS[1] - Traffic.LANE_OFFSETS[0], 1.0), "a pass in the next lane")
	check(not Scoring.near_miss(0.0, fast, half * 2.0 + 0.05, 1.0), "a hand's width off its side")
	check(not Scoring.near_miss(0.0, fast, 0.1, 1.0), "that would have been a hit")
	check(not Scoring.near_miss(0.0, Cfg.MAX_SPEED * 0.3, half * 2.0 - 0.05, 1.0), "too slow to count")
	check(Scoring.near_miss(0.0, fast, half * 2.6 - 0.05, 1.6), "a wide truck's side")


func test_near_miss_chain_rules() -> void:
	var window := Tuning.v("scoring/chain_window")
	eq(Scoring.chain_after(0, 0.5), 1, "the first starts a chain")
	eq(Scoring.chain_after(1, window - 0.1), 2, "the next within the window: x2")
	eq(Scoring.chain_after(2, window), 3, "x3 right at its edge")
	eq(Scoring.chain_after(3, window + 0.1), 1, "too late: it starts over")
	var pts := Tuning.i("scoring/near_miss")
	eq([Scoring.chain_points(1), Scoring.chain_points(2), Scoring.chain_points(3)], [pts, pts * 2, pts * 3], "points scale with the chain")
	eq(Scoring.chain_points(99), pts * Tuning.i("scoring/chain_max"), "up to chain_max")
	eq(Scoring.chain_label(1), "NEAR MISS", "one is plain")
	eq(Scoring.chain_label(3), "NEAR MISS x3", "a chain says so")


func test_a_near_miss_chain_and_its_break() -> void:
	var t := flat_track()
	var s := Scoring.new()
	var p := PlayerCar.new()
	p.reset(2000.0)
	var pts := Tuning.i("scoring/near_miss")
	for i in 3:  # three, a second apart
		s.near_miss_scored()
		for k in 60:
			s.watch(DT, p, t)
	eq(s.chain, 3, "a chain of three")
	eq(s.bonuses.map(func(b: Dictionary) -> int: return b["points"]), [pts, pts * 2, pts * 3], "1x, 2x, 3x")
	eq(s.bonuses[-1]["chain"], 3, "the bonus knows its chain")
	eq(s.feed[-1]["name"], "NEAR MISS x3", "the feed shows it")
	eq(s.summary(), [{"name": "NEAR MISS", "count": 3, "points": pts * 6}] as Array[Dictionary], "one row in the tally")
	for k in roundi(Tuning.v("scoring/chain_window") / DT):
		s.watch(DT, p, t)
	eq(s.chain, 0, "broken after the window")
	s.near_miss_scored()
	eq(s.bonuses[-1]["points"], pts, "the next starts over")
	eq(s.bonuses[-1]["chain"], 1, "at one")
	s.near_miss_scored()
	p.crashed = true
	s.watch(DT, p, t)
	eq(s.chain, 0, "a crash breaks it too")


func test_air() -> void:
	eq(Scoring.air_points(0.3), 0, "a hop")
	eq(Scoring.air_points(Tuning.v("scoring/air_time")), Tuning.i("scoring/air"), "air")
	eq(Scoring.air_points(Tuning.v("scoring/big_air_time") + 0.2), Tuning.i("scoring/big_air"), "big air")


func test_clean_section_and_no_crash() -> void:
	eq(Scoring.clean_section_points(0), Tuning.i("scoring/clean_section"), "untouched")
	eq(Scoring.clean_section_points(1), 0, "one bump spoils it")
	eq(Scoring.no_crash_points(0), Tuning.i("scoring/no_crash"), "no crash")
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
	eq(s.total(), 4 + Tuning.i("scoring/clean_section") + Tuning.i("scoring/no_crash") + 15, "a clean first section, no crashes and 2nd place")


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
	car.offset = 0.45
	car.speed = Cfg.MAX_SPEED * 0.3
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	s.watch(DT, p, t)
	eq(s.bonuses.size(), 1, "one near miss")
	car.offset = 0.5
	s.bonuses.clear()
	s.watch(DT, p, t)
	eq(s.bonuses.size(), 0, "a lane over is no near miss")


func test_missing_oncoming_traffic_is_a_near_miss() -> void:
	# An oncoming car passes the nose from its far side, a segment the nose never enters
	var t := flat_track()
	var s := Scoring.new()
	var p := PlayerCar.new()
	p.reset(4000.0)
	p.speed = Cfg.MAX_SPEED
	p.x = 0.0
	p.last_position = p.position - 200.0
	var car := Traffic.TrafficCar.new()
	car.oncoming = true
	car.last_z = p.last_position + Cfg.PLAYER_Z + 30.0
	car.z = p.position + Cfg.PLAYER_Z - 300.0
	car.offset = -0.45
	car.speed = Cfg.MAX_SPEED * 0.4
	car.segment = t.find_segment(car.z)
	car.segment.cars.append(car)
	check(not p.passed_segments(t).has(car.segment), "in a segment behind the ones entered")
	s.watch(DT, p, t)
	eq(s.bonuses.size(), 1, "a near miss")


func test_the_feed_fades_after_the_finish() -> void:
	# Review on #118: the feed only aged while racing, so the finish's bonuses stayed up.
	var r := race(true, false, 0)
	r.score.add("NO CRASHES", Tuning.i("scoring/no_crash"))
	r.state = r.State.FINISHED
	drive(r, roundi(Scoring.FEED_TIME / DT) + 2, input(0.0))
	eq(r.score.feed.size(), 0, "gone after FEED_TIME")
	eq(r.score.bonuses.size(), 1, "still counted")


func test_the_race_keeps_score() -> void:
	var r := race(true, true, 0)
	run_until(r, func(): return r.state == r.State.FINISHED, Golden.FRAMES)
	var names := {}
	for b in r.score.bonuses:
		names[b["name"]] = true
	check(names.has(Rivals.ordinal(r.place) + " PLACE"), "points for the place")
	check(r.score.total() >= Scoring.place_points(r.place), "a total (%d)" % r.score.total())
	check(names.has("NEAR MISS") or names.has("AIR") or names.has("BIG AIR"), "some bonuses on the way (%s)" % str(names.keys()))
