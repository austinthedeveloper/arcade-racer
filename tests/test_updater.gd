## The updater (EQ-14): versions, GitHub's release JSON, the download's checks, BootTree's
## choice of pack, and the update screen in every state. Never touches the network or the
## player's own user://updates/.
extends TestSuite

const SCRATCH := "user://test_updates/"


## An updater as tests use it: not in the tree (no HTTP), on the scratch folder, emptied.
func _updater() -> Updater:
	var u := Updater.new()
	u.dir = SCRATCH
	u.state = Updater.State.IDLE
	var d := DirAccess.open("user://")
	if d.dir_exists("test_updates"):
		for f in DirAccess.get_files_at(SCRATCH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH + f))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	_nodes.append(u)
	return u


func _release(tag: String, with_files := true) -> Dictionary:
	var v := tag.trim_prefix("v")
	var assets := [{"name": "SundownRun-%s-windows.zip" % v, "browser_download_url": "https://x/win.zip"}]
	if with_files:
		assets.append({"name": "SundownRun-%s.pck" % v, "browser_download_url": "https://x/%s.pck" % v})
		assets.append({"name": "SundownRun-%s.json" % v, "browser_download_url": "https://x/%s.json" % v})
	return {"tag_name": tag, "assets": assets}


func test_versions_compare_by_number() -> void:
	eq(BootTree.compare("0.10.0", "0.9.3"), 1, "0.10.0 is newer than 0.9.3")
	eq(BootTree.compare("v0.2.0", "0.2.0"), 0, "a leading v is ignored")
	eq(BootTree.compare("0.1.0", "0.1.1"), -1, "older")
	eq(BootTree.compare("1.0", "1.0.0"), 0, "a missing part is 0")
	check(BootTree.engine().split(".").size() == 3, "engine is MAJOR.MINOR.PATCH: " + BootTree.engine())


func test_the_release_json_names_the_update_files() -> void:
	var r := Updater.parse_release(_release("v0.2.0"))
	eq(r.get("version"), "0.2.0", "version from the tag")
	eq(r.get("pck_url"), "https://x/0.2.0.pck", "the pack")
	eq(r.get("manifest_url"), "https://x/0.2.0.json", "the manifest")
	eq(Updater.parse_release(_release("v0.1.0", false)), {}, "v0.1.0 has no update files")
	eq(Updater.parse_release({}), {}, "an empty answer")


func test_a_newer_release_with_this_engine_is_downloaded_and_checked() -> void:
	var u := _updater()
	u.check()
	eq(u.state, Updater.State.CHECKING, "checking")
	check(u.last_url.ends_with("/repos/austinthedeveloper/arcade-racer/releases/latest"), "asks GitHub: " + u.last_url)
	u.on_release(_release("v99.0.0"))
	eq(u.latest, "99.0.0", "the newest version")
	eq(u.last_url, "https://x/99.0.0.json", "then its manifest")
	var pack := PackedByteArray([1, 2, 3, 4, 5])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pack)
	u.on_manifest({"version": "99.0.0", "engine": BootTree.engine(), "size": pack.size(), "sha256": ctx.finish().hex_encode()})
	eq(u.state, Updater.State.AVAILABLE, "for this engine: available")
	u.download()
	eq(u.state, Updater.State.DOWNLOADING, "downloading")
	eq(u.last_url, "https://x/99.0.0.pck", "the pack")
	var old := FileAccess.open(SCRATCH + "SundownRun-98.0.0.pck", FileAccess.WRITE)
	old.store_8(0)
	old.close()
	var part := FileAccess.open(SCRATCH + "download.part", FileAccess.WRITE)
	part.store_buffer(pack)
	part.close()
	u.on_pck(SCRATCH + "download.part")
	eq(u.state, Updater.State.READY, "checked and ready")
	check(FileAccess.file_exists(SCRATCH + "SundownRun-99.0.0.pck"), "kept under its version")
	check(not FileAccess.file_exists(SCRATCH + "SundownRun-98.0.0.pck"), "the older pack removed")
	var c := BootTree.read_current(u.current_path())
	eq(c.get("version"), "99.0.0", "current.json: version")
	eq(c.get("file"), SCRATCH + "SundownRun-99.0.0.pck", "current.json: the pack")
	eq(c.get("booting"), false, "not booting yet")
	check(not u.restart(), "a checkout never starts another process")


func test_a_damaged_download_is_thrown_away() -> void:
	var u := _updater()
	u.latest = "99.0.0"
	u.manifest = {"sha256": "00", "engine": BootTree.engine()}
	var part := FileAccess.open(SCRATCH + "download.part", FileAccess.WRITE)
	part.store_string("not the pack")
	part.close()
	u.on_pck(SCRATCH + "download.part")
	eq(u.state, Updater.State.FAILED, "failed")
	check(not FileAccess.file_exists(SCRATCH + "download.part"), "deleted")
	eq(BootTree.read_current(u.current_path()), {}, "nothing recorded")


func test_up_to_date_and_full_download_releases() -> void:
	var u := _updater()
	u.on_release(_release("v" + Updater.version()))
	eq(u.state, Updater.State.LATEST, "the same version: up to date")
	u.on_release(_release("v0.0.1"))
	eq(u.state, Updater.State.LATEST, "an older release: up to date")
	u.on_release(_release("v99.0.0", false))
	eq(u.state, Updater.State.FULL, "newer without update files: a full download")
	u.on_release(_release("v99.0.0"))
	u.on_manifest({"engine": "3.0.0"})
	eq(u.state, Updater.State.FULL, "newer for another engine: a full download")


func test_boot_loads_only_a_newer_update_that_reached_the_title() -> void:
	var eng := BootTree.engine()
	var c := {"version": "0.3.0", "engine": eng, "file": "user://updates/SundownRun-0.3.0.pck", "booting": false}
	eq(BootTree.choose(c, "0.2.0", eng), c["file"], "newer than the built-in game")
	eq(BootTree.choose(c, "0.3.0", eng), "", "the same as a full download: the built-in game")
	eq(BootTree.choose(c, "0.4.0", eng), "", "a newer full download wins")
	eq(BootTree.choose(c, "0.2.0", "9.9.9"), "", "for another engine")
	eq(BootTree.choose({}, "0.2.0", eng), "", "no update")
	c["booting"] = true
	eq(BootTree.choose(c, "0.2.0", eng), "", "its last start never reached the title: skipped")


func test_reaching_the_title_keeps_the_update() -> void:
	var u := _updater()
	BootTree.write_current(u.current_path(), {"version": Updater.version(), "booting": true})
	u.mark_good()
	eq(BootTree.read_current(u.current_path()).get("booting"), false, "booting cleared")
	BootTree.write_current(u.current_path(), {"version": "99.0.0", "booting": true})
	u.mark_good()
	eq(BootTree.read_current(u.current_path()).get("booting"), true, "another version's start is left alone")


func test_a_checkout_never_checks() -> void:
	check(not Updater.supported(), "tests run from a checkout")
	eq(runner.root.get_node("Updates").state, Updater.State.OFF, "the autoload stays off")


func _screen(u: Updater) -> UpdateScreen:
	var s := UpdateScreen.new()
	s.updater = u
	_nodes.append(s)
	return s


func test_the_screen_goes_on_when_theres_nothing_to_do() -> void:
	var u := _updater()
	var s := _screen(u)
	u.state = Updater.State.LATEST
	s.step(TestSuite.DT)
	check(s.finished, "up to date: on to the title")
	s = _screen(u)
	u.state = Updater.State.CHECKING
	s.step(UpdateScreen.CHECK_TIMEOUT - 0.5)
	check(not s.finished, "still checking")
	s.step(1.0)
	check(s.finished, "no answer in time: on to the title")
	s = _screen(u)
	u.state = Updater.State.FAILED
	u.manifest = {}
	s.step(TestSuite.DT)
	check(s.finished, "offline: on to the title")


func test_the_screen_downloads_at_once_and_offers_choices_only_when_stuck() -> void:
	var u := _updater()
	var s := _screen(u)
	u.on_release(_release("v99.0.0"))
	u.on_manifest({"version": "99.0.0", "engine": BootTree.engine(), "size": 2097152})
	s.step(TestSuite.DT)
	eq(u.state, Updater.State.DOWNLOADING, "the download starts at once")
	u.staged_progress = 0.5
	eq(s.lines()[0], "Version 99.0.0 is out.", "headline")
	eq(s.lines()[2], "1.0 of 2.0 MB", "how far")
	eq(s.choices(), [] as Array[String], "no skipping a download")
	u.state = Updater.State.FAILED
	u.error = "The download stopped."
	s.step(TestSuite.DT)
	check(not s.finished, "a failed download waits")
	eq(s.choices(), ["retry", "play"] as Array[String], "retry or play")
	var right := MenuInput.new()
	right.right_pressed = true
	s.handle(right)
	var go := MenuInput.new()
	go.confirm_pressed = true
	s.handle(go)
	check(s.finished, "PLAY THIS VERSION goes on")
	s = _screen(u)
	s.handle(go)
	eq(u.state, Updater.State.DOWNLOADING, "RETRY downloads again")
	u.state = Updater.State.FULL
	eq(s.choices(), ["page", "play"] as Array[String], "a full download: the page or play")
	var back := MenuInput.new()
	back.back_pressed = true
	s.handle(back)
	check(s.finished, "back plays this version")


func test_the_screen_restarts_when_ready() -> void:
	var u := _updater()
	var s := _screen(u)
	u.latest = "99.0.0"
	u.state = Updater.State.READY
	s.step(UpdateScreen.RESTART_DELAY / 2.0)
	eq(s.lines()[1], "Restarting...", "restarting")
	s.step(UpdateScreen.RESTART_DELAY)
	check(s.restart_failed, "a checkout can't restart")
	eq(s.lines()[1], "Close the game and open it again to play it.", "so it says how")
	eq(s.choices(), ["play"] as Array[String], "or play this version")


func test_the_game_opens_on_the_title_from_a_checkout() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	eq(g.screen, g.Screen.TITLE, "no update screen without an exported build")
	g.show_update(g.staged_updater("latest"))
	eq(g.screen, g.Screen.UPDATE, "the update screen")
	g.menu.step(TestSuite.DT)
	eq(g.screen, g.Screen.TITLE, "up to date: the title")
