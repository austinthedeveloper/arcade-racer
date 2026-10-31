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
	eq(v0, [3, 250, ["car_mesa"], {"palm_coast/car_vega": {"time": 71.5, "place": 1},
		"neon/car_mesa": {"time": 88.25, "place": 0}}], "everything")
	eq(_load_save("save_v1.cfg"), v0, "version 1: the same save")
	eq(SaveData.loaded_version, 1, "version 1")
	_clean()


func test_save_newer_version_loads_what_it_knows() -> void:
	_clean()
	var v2 := _load_save("save_v2.cfg")
	eq(SaveData.loaded_version, 2, "version 2 read")
	eq(v2, _load_save("save_v1.cfg"), "the known fields, unknown ones skipped")
	_clean()


func test_save_writes_the_version() -> void:
	_clean()
	_load_save("save_v0.cfg")
	SaveData.save()
	var cfg := ConfigFile.new()
	cfg.load(TestSuite.SCRATCH_SAVE)
	eq(CfgVersion.of(cfg), SaveData.VERSION, "saved as the current version")
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
