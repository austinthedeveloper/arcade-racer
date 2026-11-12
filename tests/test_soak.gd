## The soak test's own parts (EQ-22, tests/soak.gd): what it counts as broken, its random
## driver, and the field it reports (RC-21). The soak itself runs nightly, not here.
extends TestSuite


func test_a_fresh_race_is_not_broken() -> void:
	var r := race(false, true, 0)
	eq(Soak.broken(r), "", "nothing wrong on the grid")
	drive(r, 300, input(1.0))
	eq(Soak.broken(r), "", "nor once under way")


func test_broken_sees_what_should_never_happen() -> void:
	var r := race(false, true, 0)
	r.player.speed = NAN
	check(Soak.broken(r) != "", "a NaN speed")
	r.player.speed = 0.0
	r.rivals.cars[2].x = Cfg.MAX_X + 1.0
	check(Soak.broken(r).contains("edge"), "a rival past the edge of the world")
	r.rivals.cars[2].x = 0.0
	r.time_left = -1.0
	check(Soak.broken(r).contains("clock"), "a clock below zero")
	r.time_left = 10.0
	r.traffic.cars[0].offset = NAN
	check(Soak.broken(r).contains("traffic"), "a traffic car")


func test_the_random_driver_is_seeded() -> void:
	var r := race(false, true, 0)
	var a := Soak.RandomDriver.new(7)
	var b := Soak.RandomDriver.new(7)
	var c := Soak.RandomDriver.new(8)
	var same := true
	var differs := false
	for i in 300:
		var ia := a.next(r, DT)
		var ib := b.next(r, DT)
		var ic := c.next(r, DT)
		same = same and ia.throttle == ib.throttle and ia.steer == ib.steer and ia.brake == ib.brake
		differs = differs or ia.throttle != ic.throttle or ia.brake != ic.brake or ia.horn != ic.horn
		check(ia.steer >= -1.0 and ia.steer <= 1.0 and ia.throttle >= 0.0 and ia.throttle <= 1.0, "inputs in range")
	check(same, "the same seed drives the same")
	check(differs, "another seed drives otherwise")


func test_the_field_and_its_band() -> void:
	var r := race(false, true, 0)
	for i in r.rivals.cars.size():
		r.rivals.cars[i].finished = i < 3
		r.rivals.cars[i].finish_time = 70.0 + i * 4.0
	r.player_finish = 75.0
	r.place = 3
	var f := Soak.field(r)
	eq(str(f["times"]), str([70.0, 74.0, 75.0, 78.0]), "the finishers' times, sorted, the player's among them")
	near(f["spread"], 8.0, 0.001, "first to last")
	near(f["winner_gap"], 5.0, 0.001, "behind the winner")
	eq(Soak.out_of_band(f, Difficulty.Level.NORMAL, 0), "", "in Normal's band")
	f["spread"] = Soak.BANDS[Difficulty.Level.NORMAL]["spread"] + 1.0
	check(Soak.out_of_band(f, Difficulty.Level.NORMAL, 0).contains("spread"), "too spread out")
	eq(Soak.out_of_band(f, Difficulty.Level.NORMAL, 7), "", "Skyline's field may spread further (its downtown jam)")
	f["spread"] = 8.0
	f["place"] = 7
	check(Soak.out_of_band(f, Difficulty.Level.EASY, 0).contains("placed"), "seventh on easy is out of its band")
	f["timed_out"] = true
	f["place"] = 2
	check(Soak.out_of_band(f, Difficulty.Level.EASY, 0).contains("clock"), "and so is running out of time")
	eq(Soak.out_of_band(f, Difficulty.Level.EASY, 0, false), "", "unless the clock isn't asked about")
	for band: Dictionary in Soak.BANDS:
		check(band["places"][0] <= band["places"][1], "a band's places run best to worst")
	eq(Soak.BANDS.size(), Difficulty.Level.size(), "a band per difficulty")
