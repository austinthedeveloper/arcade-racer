## The save compatibility promise (EQ-27): the save, settings and wheel profile files every
## release wrote (tests/fixtures/saves/v<version>/, SaveFixture) load in this build with every
## value they hold, and save again in this build's version. Copied to scratch files first.
extends TestSuite


func _dir() -> String:
	return TestSuite.scratch("compat/")


## Copies release `v`'s folder into the scratch folder (emptied first) and returns that.
func _use(v: String) -> String:
	var to := _dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to))
	for f in DirAccess.get_files_at(to):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(to + f))
	for f in DirAccess.get_files_at(SaveFixture.DIR + v):
		if f.ends_with(".cfg"):
			var out := FileAccess.open(to + f, FileAccess.WRITE)
			out.store_string(FileAccess.get_file_as_string(SaveFixture.DIR + v + "/" + f))
			out.close()
	return to


func _restore() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)
	TestSuite.use_scratch_profiles(InputRouter)


func _raw(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg


func test_a_folder_for_every_release() -> void:
	var all := SaveFixture.versions()
	for v in ["v0.1.0", "v0.2.0", "v0.3.0", "v0.3.1", "v0.4.0", "v0.5.0", "v0.5.1", "v0.5.2"]:
		check(all.has(v), "a fixture for %s" % v)
	# The release steps add this version's (docs/10-releases.md); a bump without one fails here.
	check(all.has("v" + Updater.version()), "a fixture for this version, %s: tests/save_fixture.gd" % Updater.version())
	eq(all[0], "v0.1.0", "oldest first")
	for v in all:
		for f in ["save.cfg", "settings.cfg", "input_profiles.cfg"]:
			check(FileAccess.file_exists(SaveFixture.DIR + v + "/" + f), "%s has %s" % [v, f])


func test_every_release_settings_load() -> void:
	var defaults := {}
	TestSuite.use_scratch_settings(Settings)
	for row in SaveFixture.SETTINGS:
		defaults[row[2]] = Settings.get(row[2])
	for v in SaveFixture.versions():
		var path := _use(v) + "settings.cfg"
		var raw := _raw(path)
		Settings.path = path
		Settings.load_settings()
		eq(Settings.loaded_version, CfgVersion.of(raw), "%s: its version read" % v)
		for row in SaveFixture.SETTINGS:
			# A key the release wrote keeps its value; one it didn't have comes in as the default.
			var want: Variant = row[3] if raw.has_section_key(row[0], row[1]) else defaults[row[2]]
			eq(Settings.get(row[2]), want, "%s: %s" % [v, row[2]])
		if raw.has_section_key("news", "seen"):
			eq(Settings.whats_new_seen, v.trim_prefix("v"), "%s: what's new seen" % v)
		Settings.save()
		eq(CfgVersion.of(_raw(path)), Settings.VERSION, "%s: saved in this version" % v)
		var older := CfgVersion.of(raw) < Settings.VERSION
		eq(FileAccess.file_exists(path + CfgVersion.BACKUP), older, "%s: backed up before migrating" % v)
	_restore()


func test_every_release_save_loads() -> void:
	for v in SaveFixture.versions():
		var base := _use(v) + "save.cfg"
		var raw := _raw(base)
		var version := CfgVersion.of(raw)
		var two_drivers := FileAccess.file_exists(SaveData.roster_path(base))
		SaveData.use_base(base)
		if two_drivers:
			# The second driver was driving: the roster brings them back, then profile 1.
			eq(SaveData.slot, 1, "%s: the driver last driving" % v)
			eq([SaveData.profile_name, SaveData.avatar, SaveData.furthest_stage, SaveData.total_points],
				[SaveFixture.DRIVER_2["name"], SaveFixture.DRIVER_2["avatar"], SaveFixture.DRIVER_2["furthest_stage"],
				SaveFixture.DRIVER_2["total_points"]], "%s: driver 2" % v)
			eq(SaveData.profiles().size(), 2, "%s: both drivers listed" % v)
			SaveData.switch_to(0)
		eq(SaveData.loaded_version, version, "%s: its version read" % v)
		var me: Dictionary = SaveFixture.DRIVER_1 if version >= 4 else SaveData.default_identity(0)
		eq([SaveData.profile_name, SaveData.avatar], [me["name"], me["avatar"]], "%s: the driver" % v)
		eq([SaveData.furthest_stage, SaveData.total_points], [3, 250], "%s: the tour" % v)
		eq(SaveData.bests, SaveFixture.BESTS, "%s: every best" % v)
		for id in SaveFixture.UNLOCKS:
			# (Before 0.3.0 the mirror came with the win: the migration opens it.)
			check(SaveData.unlocks.has(id), "%s: %s open" % [v, id])
		if version >= 3:
			eq(SaveData.stats, SaveFixture.STATS, "%s: the stats" % v)
		else:
			eq([SaveData.stats["races"], SaveData.stats["wins"]], [3, 1], "%s: stats seeded from the bests" % v)
		SaveData.save()
		eq(CfgVersion.of(_raw(base)), SaveData.VERSION, "%s: saved in this version" % v)
		eq(FileAccess.file_exists(base + CfgVersion.BACKUP), version < SaveData.VERSION, "%s: backed up" % v)
		SaveData.load_save()
		eq(SaveData.bests, SaveFixture.BESTS, "%s: and read back the same" % v)
	_restore()


func test_every_release_wheel_profiles_load() -> void:
	for v in SaveFixture.versions():
		InputRouter.profile_path = _use(v) + "input_profiles.cfg"
		InputRouter.load_profiles()
		check(InputRouter._saved.has(SaveFixture.WHEEL_GUID) and InputRouter._saved.has(SaveFixture.PAD_GUID),
			"%s: both profiles" % v)
		if not InputRouter._saved.has(SaveFixture.WHEEL_GUID):
			continue
		var wheel: DeviceProfile = InputRouter._saved[SaveFixture.WHEEL_GUID]
		for k in SaveFixture.WHEEL:
			eq(wheel.get(k), SaveFixture.WHEEL[k], "%s: wheel %s" % [v, k])
		var pad: DeviceProfile = InputRouter._saved[SaveFixture.PAD_GUID]
		eq(pad.bindings, SaveFixture.PAD["bindings"], "%s: the pad's bindings" % v)
		eq(InputRouter.keyboard.bindings, SaveFixture.KEYBOARD_BINDINGS, "%s: the keyboard's" % v)
	_restore()


func test_the_tool_writes_what_the_current_release_did() -> void:
	# tests/save_fixture.gd, run at release time, writes this build's files; this build writes
	# what the newest release folder holds when no format changed since.
	var out := TestSuite.scratch("fixture_now/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveFixture.write_all(out)
	var newest: String = SaveFixture.versions()[-1]
	# A format that moved on since that release (a new version, not yet tagged) is checked by
	# its migration test instead; the next release's folder pins it again.
	for f in ["save.cfg", "save_2.cfg", "save_profiles.cfg", "input_profiles.cfg"]:
		if CfgVersion.of(_raw(out + f)) != CfgVersion.of(_raw(SaveFixture.DIR + newest + "/" + f)):
			continue
		eq(FileAccess.get_file_as_string(out + f), FileAccess.get_file_as_string(SaveFixture.DIR + newest + "/" + f),
			"%s as %s wrote it" % [f, newest])
	var settings := _raw(out + "settings.cfg")
	var want := _raw(SaveFixture.DIR + newest + "/settings.cfg")
	if CfgVersion.of(want) == Settings.VERSION:
		for section in want.get_sections():
			for key in want.get_section_keys(section):
				if not (section == "news" and key == "seen"):
					eq(settings.get_value(section, key), want.get_value(section, key), "%s/%s" % [section, key])
	eq(Settings.path, TestSuite.SCRATCH_SETTINGS, "the autoloads back on the tests' files")
	eq(SaveData.base_path, TestSuite.SCRATCH_SAVE, "and the save")
	_restore()
