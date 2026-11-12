## The sticker book (MP-12): every sticker's condition (Stickers), awarding once and saving
## ([stickers]), the race awarding them at the line, TIME UP and a run left partway, the
## HUD's card and the sticker page's cursor.
extends TestSuite

const FIXTURE := "res://tests/fixtures/save_progress.cfg"


func _sd() -> Node:
	return runner.root.get_node("SaveData")


func _clean() -> void:
	TestSuite.use_scratch_save(_sd())


## The scratch save made the progress fixture's, loaded.
func _fixture() -> Node:
	_clean()
	var out := FileAccess.open(TestSuite.SCRATCH_SAVE, FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(FIXTURE))
	out.close()
	_sd().load_save()
	return _sd()


## A finished race's facts, `extra` over them.
static func _run(extra := {}) -> Dictionary:
	var r := {"finished": true, "stage": 0, "mode": "single", "difficulty": Difficulty.Level.NORMAL,
		"rivals": true, "place": 3, "traffic": true, "touched_traffic": true, "crashes": 2, "time": 200.0,
		"timed": true, "time_left": 20.0}
	r.merge(extra, true)
	return r


func test_twenty_four_stickers_each_with_a_name_a_way_and_art() -> void:
	eq(Stickers.count(), 24, "twenty-four")
	var seen := {}
	for s: Dictionary in Stickers.ALL:
		check(not seen.has(s["id"]), "%s once" % s["id"])
		seen[s["id"]] = true
		check(str(s["name"]) != "" and str(s["how"]) != "" and str(s["glyph"]) != "", "%s has a name, a way and a glyph" % s["id"])
		check(UiText.width(s["how"], 11) < 480.0, "%s: its way fits the panel" % s["id"])
		check(Stickers.Shape.values().has(s["shape"]), "%s: a shape" % s["id"])
	eq(Stickers.ids().size(), 24, "the ids")
	check(Stickers.info("nope").is_empty(), "an unknown id has no row")


func test_a_plain_finish_earns_only_the_first_finish() -> void:
	_clean()
	eq(Stickers.earned(_run(), _sd(), {}), ["first_finish"] as Array[String], "3rd, crashed, touched traffic")
	eq(Stickers.earned({}, _sd(), {}), [] as Array[String], "nothing happening earns nothing")


func test_the_race_stickers() -> void:
	_clean()
	var sd := _sd()
	# [id, a run that earns it, one just short]
	var cases := [
		["first_finish", _run(), _run({"finished": false})],
		["first_win", _run({"place": 1}), _run({"place": 1, "rivals": false})],
		["no_crash", _run({"crashes": 0}), _run({"crashes": 1})],
		["untouched", _run({"touched_traffic": false}), _run({"touched_traffic": false, "traffic": false})],
		["chain_5", {"best_chain": 5}, {"best_chain": 4}],
		["near_miss_10", {"near_misses": 10}, {"near_misses": 9}],
		["big_air", {"big_airs": 1}, {"big_airs": 0}],
		["drafter", {"slipstreams": 3}, {"slipstreams": 2}],
		["launch", {"launch": true}, {"launch": false}],
		["scavenger", {"pickups": 5}, {"pickups": 4}],
		["last_gasp", _run({"time_left": 3.0}), _run({"time_left": 3.1})],
		["out_of_time", {"time_up": true}, _run()],
		["mirror_win", _run({"place": 1, "mirror": true}), _run({"place": 2, "mirror": true})],
		["hard_win", _run({"place": 1, "difficulty": Difficulty.Level.HARD}), _run({"place": 1})],
		["gold", _run({"time": Medals.time_for(2, 1, Medals.Medal.GOLD), "stage": 2}),
			_run({"time": Medals.time_for(2, 1, Medals.Medal.GOLD) + 0.5, "stage": 2})],
		["ghost", {"ghost_beaten": true}, {"ghost_beaten": false}],
		["free_roam", {"mode": "free_drive", "miles": 5.0}, {"mode": "free_drive", "miles": 4.9}],
		["champion", {"tour_champion": true}, {"tour_champion": false}],
	]
	for c in cases:
		check(Stickers.met(c[0], c[1], sd), "%s: earned" % c[0])
		check(not Stickers.met(c[0], c[2], sd), "%s: just short" % c[0])
	check(not Stickers.last_gasp(_run({"timed": false, "time_left": 0.0}), sd), "last gasp needs a clock")
	check(not Stickers.free_roam({"mode": "single", "miles": 9.0}, sd), "only in Free Drive")
	check(Stickers.gold(_run({"time": Medals.time_for(2, 2, Medals.Medal.GOLD), "stage": 2, "difficulty": 2}), sd),
		"gold at the run's own difficulty")


func test_the_save_stickers() -> void:
	_clean()
	var sd := _sd()
	for id in ["globetrotter", "clean_sweep", "all_gold", "tourist", "showroom", "long_haul"]:
		check(not Stickers.met(id, {}, sd), "%s: not on a fresh save" % id)
	for i in Stages.count():
		var gold := Medals.time_for(i, Difficulty.Level.NORMAL, Medals.Medal.GOLD)
		sd.bests[SaveData.best_key(i, "car_vega")] = {"time": gold + (5.0 if i == 7 else 0.0), "place": 2}
	check(Stickers.globetrotter({}, sd), "a best on every stage")
	check(not Stickers.all_gold({}, sd), "all but Skyline gold")
	sd.bests[SaveData.best_key(7, "car_mesa")] = {"time": Medals.time_for(7, 1, Medals.Medal.GOLD), "place": 2}
	check(Stickers.all_gold({}, sd), "every stage gold, in any car")
	check(not Stickers.all_gold({"difficulty": Difficulty.Level.HARD}, sd), "Hard asks for quicker")
	for i in Stages.count() - 1:
		sd.unlocks.append(Unlocks.mirror_id(i))
	check(not Stickers.clean_sweep({}, sd), "seven wins of eight")
	sd.unlocks.append(Unlocks.mirror_id(7))
	check(Stickers.clean_sweep({}, sd), "every stage won")
	sd.unlocks.append(Tour.FINISH_UNLOCK)
	check(Stickers.tourist({}, sd), "the tour finished")
	for car: Dictionary in Cars.LIST:
		if car["id"] != "car_zenith":
			sd.stats["cars"][car["id"]] = 1
	check(not Stickers.showroom({}, sd), "every car but one")
	sd.stats["cars"]["car_zenith"] = 2
	check(Stickers.showroom({}, sd), "every car raced")
	sd.stats["miles"] = 99.9
	check(not Stickers.long_haul({}, sd), "short of 100 miles")
	sd.stats["miles"] = 100.0
	check(Stickers.long_haul({}, sd), "100 miles")
	check(not Settings.unlock_all, "(the unlock-everything option plays no part)")
	_clean()


func test_each_sticker_is_awarded_once_and_saved() -> void:
	_clean()
	var sd := _sd()
	eq(sd.award_stickers(["first_win", "chain_5", "nope"] as Array[String], 1793000000), ["first_win", "chain_5"] as Array[String], "the new ones")
	eq(sd.award_stickers(["chain_5", "launch"] as Array[String], 1794000000), ["launch"] as Array[String], "chain_5 again is nothing new")
	eq(int(sd.stickers["chain_5"]), 1793000000, "kept from the first time")
	eq(sd.award_stickers([] as Array[String]), [] as Array[String], "none")
	sd.load_save()
	eq(sd.stickers.keys().size(), 3, "saved")
	check(sd.has_sticker("launch") and not sd.has_sticker("gold"), "has_sticker")
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(int(cfg.get_value("stickers", "first_win")), 1793000000, "in [stickers], dated")
	eq(int(cfg.get_value("meta", "version")), SaveData.VERSION, "this version")
	_clean()
	eq(sd.stickers, {}, "another save starts with none")


func test_the_fixture_has_half_the_book() -> void:
	var sd := _fixture()
	eq(Completion.sticker_count(sd), 12, "twelve of twenty-four")
	check(sd.has_sticker("gold") and not sd.has_sticker("champion"), "gold, not the champion")
	eq(sd.mirror_wins, ["palm_coast"], "a mirror win")
	_clean()


func test_a_saves_unknown_stickers_are_left_alone() -> void:
	_clean()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveData.VERSION)
	cfg.set_value("stickers", "first_win", 5)
	cfg.set_value("stickers", "from_a_newer_build", 6)
	cfg.save(TestSuite.SCRATCH_SAVE)
	_sd().load_save()
	eq(_sd().stickers, {"first_win": 5}, "the known one")
	_sd().award_stickers(["launch"] as Array[String])
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(int(cfg.get_value("stickers", "from_a_newer_build", 0)), 6, "a newer build's kept on save")
	_clean()


func test_a_finished_race_awards_its_stickers_at_the_line() -> void:
	_clean()
	var r := race(false, true, 0)
	drive(r, 200, input(1.0))
	for rv: RivalCar in r.rivals.cars:
		rv.distance = 0.0
	r.score.near_miss_scored()
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.place, 1, "a win")
	check(r.new_stickers.has("first_finish") and r.new_stickers.has("first_win"), "the first finish and win: %s" % [r.new_stickers])
	check(_sd().has_sticker("first_win"), "saved")
	eq(r.sticker_age, 0.0, "the card's clock started")
	var run: Dictionary = r.sticker_run()
	eq([run["finished"], run["place"], run["rivals"], run["best_chain"], run["mode"]], [true, 1, true, 1, "tour"], "the run's facts")
	drive(r, 10)
	check(r.sticker_age > 0.0, "and runs")
	r.start_race()
	eq(r.new_stickers, [] as Array[String], "a new run has none")
	r.player.distance = r.finish_distance + 1.0
	for rv: RivalCar in r.rivals.cars:
		rv.distance = 0.0
	r._check_progress()
	check(not r.new_stickers.has("first_win"), "the second win earns it no more")
	_clean()


func test_a_mirrored_win_is_kept_for_the_completion_page() -> void:
	_clean()
	_sd().unlock(Unlocks.mirror_id(1))
	var r := race(false, false, 1, true, true)
	drive(r, 200, input(1.0))
	for rv: RivalCar in r.rivals.cars:
		rv.distance = 0.0
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(_sd().mirror_wins, ["redrock"], "Redrock won mirrored")
	check(r.new_stickers.has("mirror_win"), "LOOKING GLASS")
	_sd().load_save()
	eq(_sd().mirror_wins, ["redrock"], "saved")
	_clean()


func test_time_up_awards_out_of_time() -> void:
	_clean()
	var r := race(false, false, 0, false)
	drive(r, 181)
	r.time_left = 0.1
	drive(r, 10)
	eq(r.state, r.State.TIME_UP, "time up")
	eq(r.new_stickers, ["out_of_time"] as Array[String], "OUT OF TIME")
	_clean()


func test_autodriven_runs_earn_nothing() -> void:
	_clean()
	var r := race(true, false)
	drive(r, 200)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.new_stickers, [] as Array[String], "none shown")
	eq(_sd().stickers, {}, "none saved")
	_clean()


func test_the_hud_card_comes_up_and_cycles() -> void:
	var ids: Array[String] = ["first_win", "chain_5"]
	check(Hud.sticker_card(ids, -0.1).is_empty(), "not before it's due")
	check(Hud.sticker_card([] as Array[String], 1.0).is_empty(), "none earned")
	var c := Hud.sticker_card(ids, 0.0)
	eq([c["id"], c["slide"], c["more"]], ["first_win", 0.0, 1], "the first, sliding in, one more")
	eq(Hud.sticker_card(ids, 0.5)["slide"], 1.0, "in")
	eq(Hud.sticker_card(ids, Hud.STICKER_CARD_TIME + 0.1)["id"], "chain_5", "then the next")


func test_the_sticker_pages_cursor() -> void:
	eq(StickerScreen.step_from(-1, 0, 1), 0, "down from the tabs: the first sticker")
	eq(StickerScreen.step_from(-1, 1, 0), -1, "across on the tabs stays there (the page changes)")
	eq(StickerScreen.step_from(0, -1, 0), 7, "left wraps in the row")
	eq(StickerScreen.step_from(7, 1, 0), 0, "and right")
	eq(StickerScreen.step_from(3, 0, 1), 11, "down a row")
	eq(StickerScreen.step_from(19, 0, 1), 19, "the bottom row stays")
	eq(StickerScreen.step_from(11, 0, -1), 3, "up a row")
	eq(StickerScreen.step_from(5, 0, -1), -1, "up from the top row: the tabs")
	eq(StickerScreen.earned_text(1793000000), "EARNED 26 OCT 2026", "the date it was earned")
	eq(StickerScreen.earned_text(0), "EARNED", "no date")
	eq(StickerScreen.count_text(12), "12 / 24", "the count")
