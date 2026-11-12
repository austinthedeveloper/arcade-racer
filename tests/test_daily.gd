## The daily run (MP-14): the day's seed and pick, the tries kept for the day, the race it
## makes and the card.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	runner.root.get_node("Settings").unlock_all = false


## The day's race, as the game starts it (game.start_race with DAILY RUN).
func _daily(day: int, traffic := true) -> Node:
	var p := Daily.pick(day)
	var r := new_race(false, traffic, int(p["stage"]), true)
	r.tour = false
	r.instant_replay = false
	r.daily = p
	r.car_id = p["car"]
	r.start_race()
	_nodes.append(r)
	return r


func test_the_seed_comes_from_the_date() -> void:
	eq(Daily.day_key(2026, 11, 11), 20261111, "the day as a number")
	eq(Daily.day_key(2028, 2, 29), 20280229, "a leap day")
	# 32-bit FNV-1a of the key's digits, worked out apart from the game (Python): the same on
	# every platform, never Godot's own string hash
	eq(Daily.seed_for(20261111), 3591199655, "11 Nov 2026")
	eq(Daily.seed_for(20260101), 2432294219, "1 Jan 2026")
	eq(Daily.seed_for(20271231), 1395659315, "31 Dec 2027")
	eq(Daily.seed_for(20280229), 2838742666, "29 Feb 2028")
	check(Daily.seed_for(20261111) != Daily.seed_for(20261112), "the next day differs")
	var today := Daily.today()
	check(today > 20000101 and today < 30000101, "today is a date: %d" % today)


func test_the_pick_is_fixed_for_a_day() -> void:
	# Worked out apart from the game too (Python, the same generator)
	eq(Daily.pick(20261111), {"day": 20261111, "seed": 3591199655, "stage": 3, "car": "car_tempest", "sky": Daily.Forecast.RAIN,
		"mix": 0, "traffic_seed": 54696}, "11 Nov 2026: Timberline in the Tempest, rain, light traffic")
	eq(Daily.pick(20260101), {"day": 20260101, "seed": 2432294219, "stage": 3, "car": "car_halo", "sky": Daily.Forecast.STORM,
		"mix": 0, "traffic_seed": 84717}, "1 Jan 2026")
	eq(Daily.pick(20271231)["car"], "car_skipper", "31 Dec 2027")
	eq(Daily.pick(20280229)["car"], "car_zenith", "29 Feb 2028")
	eq(Daily.pick(20261111), Daily.pick(20261111), "asked again, the same")


func test_a_year_of_days_covers_everything() -> void:
	var stages := {}
	var cars := {}
	var skies := {}
	var mixes := {}
	var same_as_yesterday := 0
	var last := {}
	var d := Time.get_unix_time_from_datetime_string("2027-01-01T12:00:00")
	for i in 365:
		var t := Time.get_datetime_dict_from_unix_time(d + i * 86400)
		var p := Daily.pick(Daily.day_key(t["year"], t["month"], t["day"]))
		stages[p["stage"]] = true
		cars[p["car"]] = true
		skies[p["sky"]] = true
		mixes[p["mix"]] = true
		if not last.is_empty() and p["stage"] == last["stage"] and p["car"] == last["car"]:
			same_as_yesterday += 1
		last = p
	eq(stages.size(), Stages.count(), "every stage comes up")
	eq(cars.size(), Cars.count() - 1, "every car but one")
	check(not cars.has(Unlocks.SECRET_CAR), "the secret car stays a secret")
	eq(skies.size(), Daily.Forecast.size(), "every weather")
	eq(mixes.size(), Daily.MIXES.size(), "every traffic mix")
	check(same_as_yesterday < 20, "days don't repeat: %d" % same_as_yesterday)


func test_the_weather_and_traffic_follow_the_pick() -> void:
	var p := Daily.pick(20261111)
	eq(Daily.weather(p, {}).get("rain", 0.0), Daily.RAIN["rain"], "rain on a clear stage")
	eq(Daily.weather(p, Weather.STORM), Weather.STORM, "Thunderhead keeps its storm")
	eq(Daily.sky_name(p, {}), "RAIN", "said")
	eq(Daily.sky_name(p, Weather.STORM), "STORM", "the storm said")
	p["sky"] = Daily.Forecast.CLEAR
	eq(Daily.weather(p, {}), {}, "clear")
	p["sky"] = Daily.Forecast.STORM
	check(Daily.weather(p, {})["lightning"], "a storm brings lightning")
	p["mix"] = 2
	eq(Daily.traffic_count(p, 70), 105, "HEAVY: half as much again")
	p["mix"] = 3
	check(Daily.big_share(p) > Traffic.BIG_SHARE, "TRUCKS: more big vehicles")
	eq(Daily.mix_name(p), "TRUCKS", "named")


func test_the_day_keeps_its_best_tries() -> void:
	var kept := Daily.add_try({}, 20261111, 75.5)
	eq(kept, {"day": 20261111, "tries": 1, "times": [75.5]}, "the first try")
	kept = Daily.add_try(kept, 20261111, INF)
	eq([kept["tries"], kept["times"]], [2, [75.5]], "TIME UP is a try with no time")
	for t: float in [80.0, 70.25, 72.0]:
		kept = Daily.add_try(kept, 20261111, t)
	eq([kept["tries"], kept["times"]], [5, [70.25, 72.0, 75.5]], "the best three, fastest first")
	eq(Daily.tries_on(kept, 20261112)["tries"], 0, "the next day: none yet")
	eq(Daily.add_try(kept, 20261112, 90.0), {"day": 20261112, "tries": 1, "times": [90.0]}, "a new day starts over")


func test_the_daily_tries_are_saved_per_profile() -> void:
	_clean()
	SaveData.record_daily(20261111, 70.0)
	SaveData.record_daily(20261111, INF)
	SaveData.load_save()
	eq(SaveData.daily_on(20261111), {"day": 20261111, "tries": 2, "times": [70.0]}, "read back")
	eq(SaveData.daily_on(20261112)["tries"], 0, "not another day's")
	var cfg := ConfigFile.new()
	cfg.load(SaveData.path)
	eq(int(cfg.get_value("meta", "version", 0)), SaveData.VERSION, "no version bump for it")
	SaveData.make_profile("NOVA", "car_mesa", 1)
	SaveData.switch_to(1)
	eq(SaveData.daily_on(20261111)["tries"], 0, "another profile has its own")
	SaveData.switch_to(0)
	eq(SaveData.daily_on(20261111)["tries"], 2, "and back")


func test_a_daily_run_races_the_pick() -> void:
	_clean()
	var r := _daily(20261111)
	eq([r.stage_index, r.car_id], [3, "car_tempest"], "the day's stage and car")
	eq(r.rivals.cars.size(), 0, "solo")
	check(r.timed(), "against the stage's clock")
	eq(Weather.of(r.track.theme).get("rain", 0.0), Daily.RAIN["rain"], "in the day's rain")
	eq(r.fx.weather.get("rain", 0.0), Daily.RAIN["rain"], "drawn")
	eq(r.traffic.cars.size(), Daily.traffic_count(r.daily, Settings.traffic_count(70)), "the day's traffic")
	check(not r.mirror, "as built")
	drive(r, 200, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))
	eq(r.state, r.State.FINISHED, "finished")
	var kept := SaveData.daily_on(20261111)
	eq(kept["tries"], 1, "a try")
	near(float(kept["times"][0]), r.race_time, 0.001, "its time kept")
	eq(SaveData.bests.size(), 0, "no stage best from the day's run")
	eq(ResultsScreen.daily_best_line(r.daily_tries, r.player_finish), "BEST TRY TODAY!", "the results say so")
	r.start_race()
	r.time_left = 0.01
	drive(r, 200, input(1.0))
	eq(r.state, r.State.TIME_UP, "out of time")
	eq(SaveData.daily_on(20261111)["tries"], 2, "a try too")


func test_the_card_says_the_pick_and_the_tries() -> void:
	var p := Daily.pick(20261111)
	var none := DailyCard.lines(p, 20261111, {})
	eq([none["date"], none["stage"], none["car"], none["weather"], none["traffic"], none["tries"]],
		["WED 11 NOV 2026", "TIMBERLINE PASS", "TEMPEST LM", "RAIN", "LIGHT", "NO TRIES YET TODAY"], "before a try")
	var some := DailyCard.lines(p, 20261111, {"day": 20261111, "tries": 4, "times": [70.25, 72.0]})
	eq([some["tries"], some["times"]], ["4 TRIES TODAY", ["1.  " + Hud.clock_text(70.25), "2.  " + Hud.clock_text(72.0)]], "after some")
	eq(DailyCard.lines(p, 20261112, {"day": 20261111, "tries": 4, "times": [70.25]})["tries"], "NO TRIES YET TODAY", "yesterday's don't count")
	eq(Daily.date_text(20280229), "TUE 29 FEB 2028", "a leap day")


func test_mode_select_leads_to_the_card_and_the_race() -> void:
	_clean()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.day = 20261111
	g.choose_mode(ModeSelect.Item.DAILY_RUN)
	eq(g.screen, g.Screen.DAILY, "DAILY RUN opens its card")
	eq(g.menu.pick["stage"], 3, "today's pick on it")
	check(not g.mirror_offered(), "no mirror")
	g.start_race()
	eq(g.screen, g.Screen.RACE, "racing")
	eq([g.race.stage_index, g.race.car_id, g.race.daily["day"]], [3, "car_tempest", 20261111], "the day's run, even locked")
	g._on_race_over()
	eq(g.screen, g.Screen.DAILY, "back to the card after")
	eq(g.stage_index, 0, "stage select keeps its own stage")
	g.choose_mode(ModeSelect.Item.SURVIVAL)
	eq(g.screen, g.Screen.CARS, "SURVIVAL: just the car")
	g.car_select_back()
	eq(g.screen, g.Screen.MODES, "and back to mode select")
	g.mode_index = ModeSelect.Item.SURVIVAL
	g.start_race()
	check(g.race.survival and g.race.rivals.cars.is_empty(), "a Survival run")
	g._on_race_over()
	eq(g.screen, g.Screen.CARS, "after it, car select for another")
