## Save data (SaveData, user://save.cfg): round trip, a missing file, other versions, best
## times, and the race recording a finish. Always on the scratch file.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(SaveData)


func test_tests_use_a_scratch_file() -> void:
	_clean()
	check(SaveData.path != "user://save.cfg", "scratch save")
	eq(SaveData.path, TestSuite.SCRATCH_SAVE, "the suite's scratch path")


func test_missing_file_is_a_fresh_save() -> void:
	_clean()
	check(not FileAccess.file_exists(SaveData.path), "no file")
	eq([SaveData.furthest_stage, SaveData.unlocks.size(), SaveData.bests.size(), SaveData.total_points],
		[0, 0, 0, 0], "fresh")
	eq(SaveData.best(0, "car_vega"), {}, "no best time")


func test_an_unreadable_save_is_kept_aside() -> void:
	# Review on #110: a broken file was read as no file, then overwritten by the next save.
	_clean()
	var f := FileAccess.open(SaveData.path, FileAccess.WRITE)
	f.store_string("[tour]\nfurthest_stage = 5\n[best\n\"garbage")
	f.close()
	SaveData.load_save()
	eq(SaveData.furthest_stage, 0, "a fresh save")
	check(not FileAccess.file_exists(SaveData.path), "the broken file moved off the save path")
	check(FileAccess.file_exists(SaveData.path + ".bad"), "kept as .bad")
	check(FileAccess.get_file_as_string(SaveData.path + ".bad").contains("garbage"), "as it was")
	SaveData.record_finish(0, "car_vega", 80.0)
	check(FileAccess.get_file_as_string(SaveData.path + ".bad").contains("garbage"), "and not overwritten")
	_clean()


func test_saving_leaves_no_side_file() -> void:
	_clean()
	SaveData.record_finish(0, "car_vega", 80.0)
	check(FileAccess.file_exists(SaveData.path), "saved")
	check(not FileAccess.file_exists(SaveData.path + ".tmp"), "the side file renamed over it")
	SaveData.record_finish(0, "car_vega", 70.0)
	SaveData.load_save()
	eq(SaveData.best(0, "car_vega")["time"], 70.0, "a second save replaces the first")


func test_round_trip() -> void:
	_clean()
	SaveData.furthest_stage = 3
	SaveData.total_points = 120
	SaveData.unlocks.append("car_mesa")
	SaveData.record_finish(1, "car_vega", 71.5, 2)
	SaveData.save()
	var cfg := ConfigFile.new()
	eq(cfg.load(SaveData.path), OK, "written")
	eq(cfg.get_value("meta", "version"), SaveData.VERSION, "with the version")
	SaveData.reset()
	eq(SaveData.furthest_stage, 0, "reset")
	SaveData.load_save()
	eq(SaveData.furthest_stage, 3, "furthest stage")
	eq(SaveData.total_points, 120, "points")
	eq(SaveData.unlocks, ["car_mesa"] as Array[String], "unlocks")
	eq(SaveData.best(1, "car_vega"), {"time": 71.5, "place": 2}, "best")
	check(SaveData.is_unlocked("car_mesa") and not SaveData.is_unlocked("car_x"), "is_unlocked")
	_clean()


func test_record_finish_keeps_the_best() -> void:
	_clean()
	check(SaveData.record_finish(0, "car_vega", 80.0), "first time is a best")
	eq(SaveData.furthest_stage, 1, "the tour reaches stage 2")
	check(not SaveData.record_finish(0, "car_vega", 85.0), "slower: not a best")
	eq(SaveData.best(0, "car_vega")["time"], 80.0, "best kept")
	check(SaveData.record_finish(0, "car_vega", 75.25), "faster: a best")
	eq(SaveData.best(0, "car_vega")["time"], 75.25, "new best")
	check(SaveData.record_finish(0, "car_mesa", 90.0), "per car")
	eq(SaveData.best(0, "car_mesa")["time"], 90.0, "the Mesa's own")
	eq(SaveData.best(0, "car_vega")["place"], 0, "no placing given")
	SaveData.record_finish(0, "car_vega", 99.0, 3)
	eq(SaveData.best(0, "car_vega"), {"time": 75.25, "place": 3}, "a placing, the time kept")
	SaveData.record_finish(0, "car_vega", 99.0, 5)
	eq(SaveData.best(0, "car_vega")["place"], 3, "best placing kept")
	SaveData.record_finish(3, "car_vega", 100.0)
	SaveData.record_finish(1, "car_vega", 100.0)
	eq(SaveData.furthest_stage, 4, "furthest never goes back")
	SaveData.record_finish(Stages.count() - 2, "car_vega", 100.0)
	eq(SaveData.furthest_stage, Stages.count() - 1, "the last stage reached")
	SaveData.record_finish(Stages.count() - 1, "car_vega", 100.0)
	eq(SaveData.furthest_stage, Stages.count() - 1, "finishing it stays on the last stage")
	SaveData.load_save()
	eq(SaveData.best(0, "car_vega")["time"], 75.25, "saved as it goes")
	_clean()


func test_older_version_loads() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 0)
	cfg.set_value("tour", "furthest_stage", 2)
	cfg.set_value("best", "palm_coast/car_vega", {"time": 60.0})
	cfg.save(TestSuite.SCRATCH_SAVE)
	SaveData.load_save()
	eq(SaveData.loaded_version, 0, "version read")
	eq(SaveData.furthest_stage, 2, "progress kept")
	eq(SaveData.best(0, "car_vega"), {"time": 60.0, "place": 0}, "a best with no placing")
	SaveData.save()
	cfg = ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(cfg.get_value("meta", "version"), SaveData.VERSION, "written back as the current version")
	_clean()


func test_newer_version_loads_what_it_knows() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveData.VERSION + 5)
	cfg.set_value("tour", "furthest_stage", 99)  # out of range: clamped
	cfg.set_value("tour", "total_points", 40)
	cfg.set_value("tour", "unlocks", "not a list")
	cfg.set_value("tour", "rivals_beaten", 7)  # a key from the future
	cfg.set_value("best", "redrock/car_vega", {"time": 70.0, "place": 1, "ghost": "abc"})
	cfg.set_value("best", "neon/car_vega", 12)  # not a best record
	cfg.save(TestSuite.SCRATCH_SAVE)
	SaveData.load_save()
	eq(SaveData.loaded_version, SaveData.VERSION + 5, "version read")
	eq(SaveData.furthest_stage, Stages.count() - 1, "clamped")
	eq(SaveData.total_points, 40, "points")
	eq(SaveData.unlocks.size(), 0, "bad unlocks skipped")
	eq(SaveData.best(1, "car_vega"), {"time": 70.0, "place": 1}, "the fields it knows")
	eq(SaveData.best(2, "car_vega"), {}, "bad record skipped")
	_clean()


func test_a_finish_in_the_race_is_saved() -> void:
	_clean()
	var r := race(false, false, 2)
	r.car_id = "car_mesa"
	r.start_race()
	drive(r, 200, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.state, r.State.FINISHED, "finished")
	var b: Dictionary = SaveData.best(2, "car_mesa")
	check(not b.is_empty(), "best time saved")
	near(float(b.get("time", 0.0)), r.race_time, 0.001, "the race time")
	eq(SaveData.furthest_stage, 3, "the tour reached the next stage")
	var cfg := ConfigFile.new()
	eq(cfg.load(TestSuite.SCRATCH_SAVE), OK, "written to the scratch file")
	_clean()


func test_autodriven_finishes_are_not_saved() -> void:
	_clean()
	var r := race(true, false)
	drive(r, 200)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.state, r.State.FINISHED, "finished")
	eq(SaveData.bests.size(), 0, "nothing saved")
	check(not FileAccess.file_exists(TestSuite.SCRATCH_SAVE), "no file written")
	_clean()


# --- Player profiles (MP-10) ---

func test_profile_files_sit_beside_profile_one() -> void:
	eq(SaveData.slot_path("user://save.cfg", 0), "user://save.cfg", "profile 1: the save there always was")
	eq(SaveData.slot_path("user://save.cfg", 2), "user://save_3.cfg", "profile 3")
	eq(SaveData.roster_path("user://save.cfg"), "user://save_profiles.cfg", "who is driving")
	eq(SaveData.ghost_dir("user://save.cfg", 0), "user://ghosts", "profile 1's ghosts where they were")
	eq(SaveData.ghost_dir("user://save.cfg", 1), "user://ghosts_2", "profile 2's apart")
	_clean()
	eq(SaveData.profiles(), [{"slot": 0, "name": SaveData.NAMES[0], "avatar": Cars.LIST[0]["id"]}] as Array[Dictionary],
		"a fresh start: profile 1 only")


func test_switching_profiles_keeps_each_save_apart() -> void:
	_clean()
	SaveData.record_finish(0, "car_vega", 70.0, 1)
	SaveData.set_identity(0, "BLAZE", "car_mesa")
	var s := SaveData.make_profile("COMET", "car_sol")
	eq(s, 1, "the second profile, in the next slot")
	eq(SaveData.slot, 0, "making one doesn't switch to it")
	eq(SaveData.profiles().map(func(p: Dictionary) -> String: return p["name"]), ["BLAZE", "COMET"], "both listed")
	SaveData.switch_to(s)
	eq([SaveData.slot, SaveData.path, SaveData.profile_name, SaveData.avatar],
		[1, SaveData.slot_path(TestSuite.SCRATCH_SAVE, 1), "COMET", "car_sol"], "profile 2 driving")
	eq([SaveData.furthest_stage, SaveData.bests.size(), SaveData.stats["races"]], [0, 0, 0], "with a fresh save of its own")
	eq(Ghost.dir, SaveData.ghost_dir(TestSuite.SCRATCH_SAVE, 1), "and its own ghosts")
	SaveData.record_finish(2, "car_sol", 99.0, 3)
	SaveData.switch_to(0)
	eq([SaveData.profile_name, SaveData.avatar, SaveData.best(0, "car_vega")["time"]], ["BLAZE", "car_mesa", 70.0],
		"profile 1 again, its progress as it left it")
	eq(SaveData.best(2, "car_sol"), {}, "not profile 2's")
	SaveData.switch_to(1)
	eq(SaveData.best(2, "car_sol")["time"], 99.0, "and profile 2's still its own")
	# The next start drives as the profile last picked
	SaveData.use_base(TestSuite.SCRATCH_SAVE)
	eq([SaveData.slot, SaveData.profile_name], [1, "COMET"], "remembered")
	SaveData.switch_to(3)
	eq(SaveData.slot, 1, "no switching to a profile that isn't there")
	_clean()
	eq(Ghost.dir, SaveData.ghost_dir(TestSuite.SCRATCH_SAVE, 0), "")
	TestSuite.use_scratch_ghosts()


func test_four_profiles_at_most_and_a_name_each() -> void:
	_clean()
	eq(SaveData.names_free_for(0), SaveData.NAMES, "every name free")
	for i in 3:
		check(SaveData.make_profile(SaveData.names_free_for(-1)[0], "car_vega") > 0, "profile %d made" % (i + 2))
	eq(SaveData.make_profile("ZOOM", "car_vega"), -1, "no fifth")
	eq(SaveData.free_slot(), -1, "every slot taken")
	var free := SaveData.names_free_for(0)
	check(not free.has("BLAZE") and not free.has("COMET") and not free.has("DASH"), "the others' names taken")
	check(free.has(SaveData.profile_name), "its own name still its own")
	SaveData.set_identity(2, "ZOOM", "car_halo")
	eq(SaveData.profile_of(2), {"slot": 2, "name": "ZOOM", "avatar": "car_halo"}, "another profile renamed in its file")
	SaveData.switch_to(2)
	eq([SaveData.profile_name, SaveData.avatar], ["ZOOM", "car_halo"], "and loaded so")
	_clean()


func test_a_profile_save_with_a_bad_name_or_avatar() -> void:
	_clean()
	var s := SaveData.make_profile("COMET", "car_sol")
	var cfg := ConfigFile.new()
	cfg.load(SaveData.slot_path(TestSuite.SCRATCH_SAVE, s))
	cfg.set_value("profile", "name", "Robert'); DROP")
	cfg.set_value("profile", "avatar", "car_nonesuch")
	cfg.save(SaveData.slot_path(TestSuite.SCRATCH_SAVE, s))
	eq(SaveData.profile_of(s), {"slot": s, "name": SaveData.default_identity(s)["name"], "avatar": SaveData.default_identity(s)["avatar"]},
		"the slot's defaults, not what isn't on the list")
	_clean()


func test_reset_save_keeps_who_is_driving() -> void:
	_clean()
	SaveData.set_identity(0, "VIPER", "car_zenith")
	SaveData.record_finish(0, "car_vega", 70.0, 1)
	SaveData.reset()
	SaveData.save(true)
	SaveData.load_save()
	eq([SaveData.bests.size(), SaveData.profile_name, SaveData.avatar], [0, "VIPER", "car_zenith"], "progress gone, the driver kept")
	_clean()
