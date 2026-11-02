## Versioned files (CfgVersion): settings.cfg, save.cfg and input_profiles.cfg at every
## version in tests/fixtures/. Version 0 is the unversioned format and must load exactly as
## before; a newer, unknown version loads what it can. Fixtures are copied to the scratch files.
extends TestSuite

const FIXTURES := "res://tests/fixtures/"
const WHEEL := "030000006d04000018c2000000000000"
const PAD := "03000000de280000ff11000000000000"


## Copies a fixture over a scratch file.
static func _use_fixture(fixture: String, scratch: String) -> void:
	var text := FileAccess.get_file_as_string(FIXTURES + fixture)
	var f := FileAccess.open(scratch, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)
	TestSuite.use_scratch_profiles(InputRouter)


func _settings_values() -> Array:
	return [Settings.auto_gas, Settings.traffic, Settings.timer, Settings.power_ups, Settings.music_volume,
		Settings.sfx_volume, Settings.screen_shake, Settings.flash, Settings.units]


func _load_settings(fixture: String) -> Array:
	_use_fixture(fixture, TestSuite.SCRATCH_SETTINGS)
	Settings.load_settings()
	return _settings_values()


func _load_save(fixture: String) -> Array:
	_use_fixture(fixture, TestSuite.SCRATCH_SAVE)
	SaveData.load_save()
	return [SaveData.furthest_stage, SaveData.total_points, Array(SaveData.unlocks), SaveData.bests.duplicate(true)]


## Every saved key of every loaded profile, by GUID.
func _load_profiles(fixture: String) -> Dictionary:
	_use_fixture(fixture, TestSuite.SCRATCH_PROFILES)
	InputRouter.load_profiles()
	var out := {}
	for guid in InputRouter._saved:
		var p: DeviceProfile = InputRouter._saved[guid]
		var keys := {"guid": p.guid}
		for k in DeviceProfile.SAVED_KEYS:
			keys[k] = p.get(k)
		out[guid] = keys
	return out


func test_version_helper() -> void:
	var cfg := ConfigFile.new()
	eq(CfgVersion.of(cfg), 0, "no field: version 0")
	CfgVersion.stamp(cfg, 3)
	eq(CfgVersion.of(cfg), 3, "stamped")
	var ran: Array[int] = []
	var steps: Array[Callable] = [func(_c: ConfigFile) -> void: ran.append(0),
		func(_c: ConfigFile) -> void: ran.append(1), func(_c: ConfigFile) -> void: ran.append(2)]
	cfg = ConfigFile.new()
	eq(CfgVersion.migrate(cfg, 3, steps), 0, "returns the file's version")
	eq(ran, [0, 1, 2] as Array[int], "every step, in order")
	eq(CfgVersion.of(cfg), 3, "stamped current")
	ran.clear()
	CfgVersion.stamp(cfg, 1)
	CfgVersion.migrate(cfg, 3, steps)
	eq(ran, [1, 2] as Array[int], "from the file's version on")
	ran.clear()
	CfgVersion.stamp(cfg, 9)
	eq(CfgVersion.migrate(cfg, 3, steps), 9, "newer")
	eq(ran.size(), 0, "a newer file runs no steps")
	eq(CfgVersion.of(cfg), 9, "and keeps its number")
	CfgVersion.stamp(cfg, -4)
	eq(CfgVersion.of(cfg), 0, "nonsense counts as 0")


func test_to_write_keeps_only_a_newer_file() -> void:
	var path := TestSuite.scratch("cfg_version.cfg")
	var missing := CfgVersion.to_write(path + ".none", 3)
	eq([CfgVersion.of(missing), missing.get_sections()], [3, PackedStringArray(["meta"])], "no file: empty, stamped current")
	for version in [1, 3, 7]:
		var disk := ConfigFile.new()
		CfgVersion.stamp(disk, version)
		disk.set_value("future", "key", "kept")
		disk.save(path)
		var cfg := CfgVersion.to_write(path, 3)
		if version > 3:
			eq([CfgVersion.of(cfg), cfg.get_value("future", "key", "")], [7, "kept"], "a newer file: written into, its keys kept")
			var fresh := CfgVersion.to_write(path, 3, true)
			eq([CfgVersion.of(fresh), fresh.has_section("future")], [3, false], "but a reset starts empty")
		else:
			eq([CfgVersion.of(cfg), cfg.has_section("future")], [3, false], "version %d: a fresh file" % version)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_settings_v0_loads_as_before() -> void:
	_clean()
	var v0 := _load_settings("settings_v0.cfg")
	eq(Settings.loaded_version, 0, "unversioned is version 0")
	eq(v0, [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 10, 10, Settings.Units.MPH],
		"every option; shake and flash as designed")
	eq(_load_settings("settings_v1.cfg"), v0, "version 1: the same options")
	eq(Settings.loaded_version, 1, "version 1")
	_clean()


func test_settings_v1_to_v2_adds_shake_and_flash() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v1.cfg")
	eq(Settings.migrate(cfg), 1, "from version 1")
	eq([cfg.get_value("accessibility", "screen_shake"), cfg.get_value("accessibility", "flash")],
		[10, 10], "shake and flash at the designed level")
	eq(cfg.get_value("audio", "music"), 3, "the rest untouched")


func test_settings_v2_loads() -> void:
	_clean()
	eq(_load_settings("settings_v2.cfg"), [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 3, 0, Settings.Units.MPH],
		"every option")
	eq(Settings.loaded_version, 2, "version 2")
	_clean()


func test_settings_v2_to_v3_adds_units() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v2.cfg")
	eq(Settings.migrate(cfg), 2, "from version 2")
	eq([CfgVersion.of(cfg), cfg.get_value("display", "units")], [Settings.VERSION, Settings.Units.MPH], "migrated on, MPH as before")
	eq(cfg.get_value("accessibility", "screen_shake"), 3, "the rest untouched")


func test_settings_v3_loads() -> void:
	_clean()
	eq(_load_settings("settings_v3.cfg"), [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 3, 0,
		Settings.Units.KPH], "every option")
	eq(Settings.loaded_version, 3, "version 3")
	_clean()


func _display_values() -> Array:
	return [Settings.fullscreen, Settings.integer_scale, Settings.vsync, Settings.scanlines]


func test_settings_v3_to_v4_adds_display() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v3.cfg")
	eq(Settings.migrate(cfg), 3, "from version 3")
	eq([CfgVersion.of(cfg), cfg.get_value("display", "fullscreen"), cfg.get_value("display", "integer_scale"),
		cfg.get_value("display", "vsync"), cfg.get_value("display", "scanlines")], [Settings.VERSION, false, false, true, false],
		"migrated on: windowed, fractional, V-Sync, no scanlines, as before")
	eq(cfg.get_value("display", "units"), Settings.Units.KPH, "units untouched")
	_clean()
	eq(_load_settings("settings_v3.cfg")[8], Settings.Units.KPH, "v3 loads")
	eq(_display_values(), [false, false, true, false], "with the display defaults")
	_clean()


func test_settings_v4_loads() -> void:
	_clean()
	eq(_load_settings("settings_v4.cfg"), [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 3, 0,
		Settings.Units.KPH], "every earlier option")
	eq(_display_values(), [true, true, false, true], "the display options")
	eq(Settings.loaded_version, 4, "version 4")
	_clean()


func test_settings_v4_to_v5_adds_assists() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v4.cfg")
	eq(Settings.migrate(cfg), 4, "from version 4")
	eq([CfgVersion.of(cfg), cfg.get_value("play", "steer_assist"), cfg.get_value("play", "brake_assist")], [Settings.VERSION, false, false],
		"migrated on: both assists off, as before")
	eq(cfg.get_value("display", "scanlines"), true, "the rest untouched")
	_clean()
	_load_settings("settings_v4.cfg")
	eq([Settings.steer_assist, Settings.brake_assist], [false, false], "v4 loads with the assists off")
	_clean()


func test_settings_v5_to_v6_adds_the_radio() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v5.cfg")
	eq(Settings.migrate(cfg), 5, "from version 5")
	eq([CfgVersion.of(cfg), cfg.get_value("audio", "radio")], [Settings.VERSION, Radio.SHUFFLE], "migrated on: the radio on shuffle")
	_clean()
	_load_settings("settings_v5.cfg")
	eq(Settings.radio, Radio.SHUFFLE, "v5 loads with the radio on shuffle")
	eq(Settings.steer_assist, true, "the rest as saved")
	_clean()


func test_settings_v6_to_v7_adds_subtitles() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v6.cfg")
	eq(Settings.migrate(cfg), 6, "from version 6")
	eq([CfgVersion.of(cfg), cfg.get_value("accessibility", "subtitles")], [Settings.VERSION, true], "migrated on: subtitles on")
	_clean()
	_load_settings("settings_v6.cfg")
	eq([Settings.subtitles, Settings.radio], [true, 2], "v6 loads with subtitles on and its station")
	_clean()


func test_settings_v7_to_v8_adds_manual_gears() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v7.cfg")
	eq(Settings.migrate(cfg), 7, "from version 7")
	eq([CfgVersion.of(cfg), cfg.get_value("play", "manual_gears")], [Settings.VERSION, false], "migrated on: automatic")
	_clean()
	_load_settings("settings_v7.cfg")
	eq(Settings.manual_gears, false, "v7 loads with automatic gears")
	eq([Settings.subtitles, Settings.steer_assist, Settings.radio], [false, true, 2], "the rest as saved")
	Settings.manual_gears = true
	Settings.save()
	Settings.load_settings()
	eq([Settings.loaded_version, Settings.manual_gears], [Settings.VERSION, true], "manual saved and loaded back")
	_clean()


func test_settings_v8_to_v9_adds_keyboard_steering_feel() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v8.cfg")
	eq(Settings.migrate(cfg), 8, "from version 8")
	eq([CfgVersion.of(cfg), cfg.get_value("controls", "key_steer_in"), cfg.get_value("controls", "key_steer_out")],
		[Settings.VERSION, Settings.STEER_FEEL_STANDARD, Settings.STEER_FEEL_STANDARD], "migrated on: standard both ways")
	_clean()
	_load_settings("settings_v8.cfg")
	eq(Settings.key_steer_rates(), Vector2(5.0, 9.0), "v8 steers as it did")
	eq([Settings.manual_gears, Settings.subtitles, Settings.radio], [true, false, 2], "the rest as saved")
	Settings.key_steer_in = 0
	Settings.save()
	Settings.load_settings()
	eq([Settings.loaded_version, Settings.key_steer_in], [Settings.VERSION, 0], "saved and loaded back")
	_clean()


func test_settings_v9_to_v10_adds_reduce_motion() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v9.cfg")
	eq(Settings.migrate(cfg), 9, "from version 9")
	eq([CfgVersion.of(cfg), cfg.get_value("accessibility", "reduce_motion")], [Settings.VERSION, false], "migrated on: off")
	_clean()
	_load_settings("settings_v9.cfg")
	eq(Settings.reduce_motion, false, "v9 loads with everything moving")
	eq([Settings.key_steer_in, Settings.key_steer_out, Settings.screen_shake], [1, 5, 3], "the rest as saved")
	Settings.reduce_motion = true
	Settings.save()
	Settings.load_settings()
	eq([Settings.loaded_version, Settings.reduce_motion], [Settings.VERSION, true], "saved and loaded back")
	_clean()


func test_settings_v10_to_v11_adds_rumble() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v10.cfg")
	eq(Settings.migrate(cfg), 10, "from version 10")
	eq([CfgVersion.of(cfg), cfg.get_value("controls", "rumble")], [Settings.VERSION, Settings.EFFECT_STEPS], "migrated on: as designed")
	_clean()
	_load_settings("settings_v10.cfg")
	eq(Settings.rumble, Settings.EFFECT_STEPS, "v10 loads with rumble on")
	eq([Settings.reduce_motion, Settings.key_steer_in], [true, 1], "the rest as saved")
	Settings.rumble = 4
	Settings.save()
	Settings.load_settings()
	eq([Settings.loaded_version, Settings.rumble], [Settings.VERSION, 4], "saved and loaded back")
	_clean()


func test_settings_v11_to_v12_adds_whats_new_and_the_co_pilot() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v11.cfg")
	eq(Settings.migrate(cfg), 11, "from version 11")
	eq([CfgVersion.of(cfg), cfg.get_value("news", "seen"), cfg.get_value("play", "co_pilot")], [Settings.VERSION, "", false],
		"migrated on: no notes seen, so this build's show; the co-pilot off")
	_clean()
	_load_settings("settings_v11.cfg")
	eq([Settings.whats_new_seen, Settings.had_file, Settings.co_pilot], ["", true, false],
		"v11 loads, an install that ran before, steering itself")
	eq([Settings.rumble, Settings.reduce_motion, Settings.key_steer_in], [6, true, 1], "the rest as saved")
	Settings.whats_new_seen = "0.5.0"
	Settings.co_pilot = true
	Settings.save()
	Settings.load_settings()
	eq([Settings.loaded_version, Settings.whats_new_seen, Settings.co_pilot], [Settings.VERSION, "0.5.0", true],
		"saved and loaded back")
	Settings.reset()
	eq(Settings.whats_new_seen, "0.5.0", "resetting the options keeps it seen")
	_clean()
	eq([Settings.whats_new_seen, Settings.had_file], ["", false], "no file: none seen, a fresh install")


func test_settings_v12_loads() -> void:
	_clean()
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "settings_v12.cfg")
	eq(Settings.migrate(cfg), 12, "version 12: nothing to migrate")
	_load_settings("settings_v12.cfg")
	eq([Settings.loaded_version, Settings.whats_new_seen, Settings.co_pilot], [12, "0.4.0", true], "its keys as saved")
	eq([Settings.rumble, Settings.reduce_motion, Settings.radio], [6, true, 2], "the rest as saved")
	_clean()


func test_settings_newer_version_loads_what_it_knows() -> void:
	_clean()
	var future := _load_settings("settings_future.cfg")
	eq(Settings.loaded_version, 99, "version 99 read")
	eq(future, [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 4, 10, Settings.Units.KPH],
		"the known options (flash clamped to the designed level)")
	_clean()


func test_settings_save_writes_the_version() -> void:
	_clean()
	_load_settings("settings_v0.cfg")
	Settings.save()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SETTINGS)
	eq(CfgVersion.of(cfg), Settings.VERSION, "saved as the current version")
	Settings.load_settings()
	eq(_settings_values(), [true, Settings.Traffic.LIGHT, Settings.Clock.TIGHT, false, 3, 7, 10, 10, Settings.Units.MPH], "same options")
	_clean()
	eq(Settings.loaded_version, Settings.VERSION, "no file: the current version")


func test_save_v0_loads_as_before() -> void:
	_clean()
	var v0 := _load_save("save_v0.cfg")
	eq(SaveData.loaded_version, 0, "unversioned is version 0")
	# Palm Coast won (1st): migrating to version 2 opens its mirror
	eq(v0, [3, 250, ["car_mesa", "mirror_palm_coast"], {"palm_coast/car_vega": {"time": 71.5, "place": 1},
		"neon/car_mesa": {"time": 88.25, "place": 0}}], "everything")
	eq(_load_save("save_v1.cfg"), v0, "version 1: the same save")
	eq(SaveData.loaded_version, 1, "version 1")
	_clean()


func test_save_v1_to_v2_opens_the_mirror_of_every_stage_won() -> void:
	_clean()
	var v1 := _load_save("save_v1.cfg")
	check(SaveData.is_unlocked("mirror_palm_coast"), "Palm Coast won: its mirror")
	check(not SaveData.is_unlocked("mirror_neon"), "Neon Strip finished unplaced: not its mirror")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("tour", "unlocks", ["mirror_palm_coast"])
	cfg.set_value("best", "palm_coast/car_mesa", {"time": 70.0, "place": 1})
	cfg.set_value("best", "palm_coast/car_vega", {"time": 72.0, "place": 1})
	cfg.set_value("best", "skyline/car_vega", {"time": 90.0, "place": 2})
	cfg.set_value("best", "atlantis/car_vega", {"time": 90.0, "place": 1})
	eq(SaveData.migrate(cfg), 1, "from version 1")
	eq(cfg.get_value("tour", "unlocks"), ["mirror_palm_coast"], "once each; 2nd place and an unknown stage open nothing")
	var v2 := _load_save("save_v2.cfg")
	eq(SaveData.loaded_version, 2, "version 2")
	eq(v2[2], ["car_mesa", "mirror_palm_coast", "mirror_redrock"], "its mirrors as saved")
	eq([v2[0], v2[1], v2[3]], [v1[0], v1[1], v1[3]], "the rest as before")
	_clean()


func test_save_v2_to_v3_seeds_the_stats_from_the_bests() -> void:
	_clean()
	var v2 := _load_save("save_v2.cfg")
	eq(SaveData.loaded_version, 2, "version 2")
	eq(SaveData.stats, {"races": 2, "wins": 1, "crashes": 0, "near_misses": 0, "miles": 0.0,
		"cars": {"car_vega": 1, "car_mesa": 1}, "stages": {"palm_coast": 1, "neon": 1}},
		"a race per best on file, a win per 1st; crashes, near misses and miles unknown")
	var v0 := _load_save("save_v0.cfg")
	eq(SaveData.stats["races"], 2, "an unversioned save migrates all the way")
	eq([v0[0], v0[1], v0[3]], [v2[0], v2[1], v2[3]], "the rest as before")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 2)
	cfg.set_value("best", "palm_coast/car_vega", "nonsense")
	eq(SaveData.migrate(cfg), 2, "from version 2")
	eq([cfg.get_value("stats", "races"), cfg.get_value("stats", "cars")], [0, {}], "a bad best counts nothing")
	_clean()


func test_save_v3_loads() -> void:
	_clean()
	var v3 := _load_save("save_v3.cfg")
	eq(SaveData.loaded_version, 3, "version 3")
	eq(SaveData.stats, {"races": 14, "wins": 5, "crashes": 9, "near_misses": 31, "miles": 52.5,
		"cars": {"car_mesa": 4, "car_vega": 10}, "stages": {"neon": 6, "palm_coast": 8}}, "the stats as saved")
	eq(v3[2], ["car_mesa", "mirror_palm_coast", "mirror_redrock"], "the rest as saved")
	SaveData.save()
	SaveData.load_save()
	eq(SaveData.stats["cars"], {"car_mesa": 4, "car_vega": 10}, "and saved back")
	_clean()


func test_save_newer_version_loads_what_it_knows() -> void:
	_clean()
	var future := _load_save("save_future.cfg").duplicate(true)  # (the unlocks are the live array)
	eq(SaveData.loaded_version, 99, "version 99 read")
	var v1 := _load_save("save_v1.cfg")
	v1[2] = ["car_mesa"]  # (a newer file isn't migrated: no mirror added)
	eq(future, v1, "the known fields, unknown ones skipped")
	_clean()


func test_save_writes_the_version() -> void:
	_clean()
	_load_save("save_v0.cfg")
	SaveData.save()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(CfgVersion.of(cfg), SaveData.VERSION, "saved as the current version")
	_clean()


# Review on #112: saving over a newer file used to rebuild it from scratch at this build's
# version, dropping what the newer build wrote, which it would then migrate as an old file.
func test_settings_saved_over_a_newer_file_keep_its_keys() -> void:
	_clean()
	_load_settings("settings_future.cfg")
	Settings.traffic = Settings.Traffic.HEAVY
	Settings.save()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SETTINGS)
	eq(CfgVersion.of(cfg), 99, "still version 99")
	eq(cfg.get_value("play", "traffic"), Settings.Traffic.HEAVY, "the change written")
	eq([cfg.get_value("play", "rivals"), cfg.get_value("audio", "announcer"), cfg.get_value("display", "crt_filter")],
		["HARD", 5, true], "the newer build's options kept")
	eq(cfg.get_value("accessibility", "strobe_filter"), true, "in known sections too")
	Settings.save(true)
	cfg = ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SETTINGS)
	eq([CfgVersion.of(cfg), cfg.has_section_key("display", "crt_filter")], [Settings.VERSION, false], "a reset starts fresh")
	_clean()


func test_save_over_a_newer_file_keeps_its_keys() -> void:
	_clean()
	_load_save("save_future.cfg")
	SaveData.record_finish(0, "car_vega", 70.0)
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(CfgVersion.of(cfg), 99, "still version 99")
	eq(cfg.get_value("medals", "palm_coast"), "gold", "[medals] kept")
	eq(cfg.get_value("tour", "rivals_beaten"), 4, "unknown tour keys kept")
	var b: Dictionary = cfg.get_value("best", "palm_coast/car_vega")
	eq([b.get("time"), b.get("place"), b.get("ghost")], [70.0, 1, "replays/palm.bin"], "the new best, with the newer build's ghost path")
	SaveData.reset()
	SaveData.save(true)
	cfg = ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq([CfgVersion.of(cfg), cfg.has_section("medals")], [SaveData.VERSION, false], "a reset starts fresh")
	_clean()


func test_profiles_saved_over_a_newer_file_keep_its_keys() -> void:
	_clean()
	_load_profiles("input_profiles_future.cfg")
	InputRouter._saved.erase(PAD)
	InputRouter._write_profiles()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_PROFILES)
	eq([CfgVersion.of(cfg), cfg.get_value("meta", "layout")], [99, "per-device"], "version 99 and its [meta] kept")
	eq(cfg.get_value(WHEEL, "ffb_strength"), 0.8, "a key this build doesn't know kept in the profile")
	check(not cfg.has_section(PAD), "a dropped profile is gone")
	_clean()


func test_profiles_v0_load_as_before() -> void:
	_clean()
	var v0 := _load_profiles("input_profiles_v0.cfg")
	eq(InputRouter.profiles_version, 0, "unversioned is version 0")
	eq(v0.keys().size(), 2, "two profiles")
	var wheel: Dictionary = v0.get(WHEEL, {})
	eq([wheel.get("name"), wheel.get("kind"), wheel.get("calibrated"), wheel.get("throttle_axis"),
		wheel.get("lock_deg"), wheel.get("steer_gamma")], ["Test Wheel", DeviceProfile.Kind.WHEEL, true, 2, 540.0, 1.2],
		"the wheel")
	var pad: Dictionary = v0.get(PAD, {})
	eq([pad.get("name"), pad.get("kind"), pad.get("calibrated"), pad.get("lock_deg")],
		["Test Pad", DeviceProfile.Kind.GAMEPAD, false, 360.0], "the pad, defaults for the rest")
	eq(_load_profiles("input_profiles_v1.cfg"), v0, "version 1: the same profiles, [meta] isn't one")
	eq(InputRouter.profiles_version, 1, "version 1")
	_clean()


func test_profiles_newer_version_loads_what_it_knows() -> void:
	_clean()
	var future := _load_profiles("input_profiles_future.cfg")
	eq(InputRouter.profiles_version, 99, "version 99 read")
	eq(future, _load_profiles("input_profiles_v0.cfg"), "the known keys of the same profiles")
	_clean()


func test_profiles_v1_loads_with_default_bindings() -> void:
	_clean()
	var v1 := _load_profiles("input_profiles_v1.cfg")
	eq([v1[WHEEL]["bindings"], v1[PAD]["bindings"], InputRouter.keyboard.bindings], [{}, {}, {}], "no rebinds")
	var wheel: DeviceProfile = InputRouter._saved[WHEEL]
	eq(wheel.binding("nitro"), [4], "the wheel's nitro is its calibrated button")
	eq(InputRouter.keyboard.binding("nitro"), [KEY_SPACE, KEY_SHIFT], "keyboard defaults")
	var cfg := ConfigFile.new()
	cfg.load(FIXTURES + "input_profiles_v1.cfg")
	eq(InputRouter.migrate_profiles(cfg), 1, "from version 1")
	eq(CfgVersion.of(cfg), InputRouter.PROFILES_VERSION, "migrated on")
	eq(cfg.get_value(WHEEL, "nitro_button"), 4, "profiles untouched")
	_clean()


func test_profiles_v2_loads_bindings() -> void:
	_clean()
	var v2 := _load_profiles("input_profiles_v2.cfg")
	eq(InputRouter.profiles_version, 2, "version 2")
	eq(v2[PAD]["bindings"], {"nitro": 2, "view": -1}, "the pad's rebinds")
	var pad: DeviceProfile = InputRouter._saved[PAD]
	eq([pad.binding("nitro"), pad.binding("view"), pad.binding("pause")], [[JOY_BUTTON_X], [], [JOY_BUTTON_START]],
		"rebound, unbound, default")
	eq(InputRouter.keyboard.binding("nitro"), [KEY_N], "the keyboard's rebind")
	check(not InputRouter._saved.has(DeviceProfile.KEYBOARD_GUID), "the keyboard isn't a joypad profile")
	_clean()
	eq(InputRouter.keyboard.binding("nitro"), [KEY_SPACE, KEY_SHIFT], "a fresh file: defaults again")


func test_profiles_write_the_version() -> void:
	_clean()
	var before := _load_profiles("input_profiles_v0.cfg")
	InputRouter._write_profiles()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_PROFILES)
	eq(CfgVersion.of(cfg), InputRouter.PROFILES_VERSION, "saved as the current version")
	InputRouter.load_profiles()
	eq(InputRouter.profiles_version, InputRouter.PROFILES_VERSION, "read back as current")
	var after := {}
	for guid in InputRouter._saved:
		var p: DeviceProfile = InputRouter._saved[guid]
		var keys := {"guid": p.guid}
		for k in DeviceProfile.SAVED_KEYS:
			keys[k] = p.get(k)
		after[guid] = keys
	eq(after, before, "the same profiles")
	_clean()
