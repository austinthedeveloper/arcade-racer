## What's new (PR-17): after an update the title shows that version's changelog section once
## (WhatsNew), from the notes tools/export.sh bundles, or CHANGELOG.md in a checkout.
extends TestSuite

const NOTES := """### Added

- Photo key (PR-21): F12 saves a picture of the race without the HUD, with a
  shutter and a flash.
- Co-pilot (AC-14, AC-3): steers for you.

### Fixed

- The radio no longer skips. It plays on.
"""


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)
	TestSuite.use_scratch_save(SaveData)
	WhatsNew.bundled = TestSuite.scratch("whats_new.json")
	if FileAccess.file_exists(WhatsNew.bundled):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WhatsNew.bundled))


func _done() -> void:
	_clean()
	WhatsNew.bundled = WhatsNew.BUNDLED


func test_due_once_per_version_on_an_install_that_ran_before() -> void:
	check(WhatsNew.due("", "0.5.0", true), "an update from a build before what's new")
	check(WhatsNew.due("0.4.0", "0.5.0", true), "an update from 0.4.0")
	check(not WhatsNew.due("0.5.0", "0.5.0", true), "seen already")
	check(not WhatsNew.due("", "0.5.0", false), "a fresh install: nothing to catch up on")


func test_a_changelog_section() -> void:
	var text := "# Changelog\n\n## [Unreleased]\n\n## [0.5.0] - 2026-12-01\n\n" + NOTES + "\n## [0.4.0] - 2026-11-02\n\n- Old.\n"
	eq(WhatsNew.section(text, "0.5.0"), NOTES.strip_edges(), "its own section")
	eq(WhatsNew.section(text, "0.5.0-beta"), NOTES.strip_edges(), "a pre-release: its base version's")
	eq(WhatsNew.section(text, "0.4.0"), "- Old.", "the last section")
	eq(WhatsNew.section(text, "0.6.0"), "", "none")
	var running: String = ProjectSettings.get_setting("application/config/version", "")
	check(WhatsNew.section(FileAccess.get_file_as_string(WhatsNew.CHANGELOG), running) != "",
		"CHANGELOG.md describes the version running (" + running + ")")


func test_the_list_names_each_entry() -> void:
	eq(WhatsNew.items(NOTES), [[true, "ADDED"], [false, "Photo key"], [false, "Co-pilot"], [true, "FIXED"],
		[false, "The radio no longer skips"]], "headings, then each entry by its name")
	eq(WhatsNew.short("A very long change with no colon in it that goes on and on and on"),
		"A very long change with no colon in it...", "cut to SHORT_MAX")
	check(WhatsNew.short("x".repeat(80)).length() <= WhatsNew.SHORT_MAX, "never longer")


func test_the_layout_fills_columns_and_counts_the_rest() -> void:
	var list: Array = []
	for i in 5:
		list.append([false, "item %d" % i])
	eq(WhatsNew.layout(list, 3, 2), [[0, 0, list[0]], [0, 1, list[1]], [0, 2, list[2]], [1, 0, list[3]], [1, 1, list[4]]],
		"down the first column, then the next")
	list.append([false, "item 5"])
	list.append([false, "item 6"])
	var out := WhatsNew.layout(list, 3, 2)
	eq(out.size(), 6, "every slot used")
	eq(out[5], [1, 2, [false, "...AND 2 MORE"]], "the last says how many more")


func test_the_bundled_notes_win_for_their_version() -> void:
	_clean()
	var f := FileAccess.open(WhatsNew.bundled, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": "9.9.9", "notes": NOTES}))
	f.close()
	eq(WhatsNew.notes("9.9.9"), NOTES, "bundled at export")
	var running: String = ProjectSettings.get_setting("application/config/version", "")
	eq(WhatsNew.notes(running), WhatsNew.section(FileAccess.get_file_as_string(WhatsNew.CHANGELOG), running),
		"another version's bundle: CHANGELOG.md")
	_done()


func test_shown_once_per_version() -> void:
	_clean()
	eq(WhatsNew.take(), [], "a fresh install: nothing")
	eq(Settings.whats_new_seen, Updater.version(), "but marked seen")
	Settings.whats_new_seen = "0.0.1"  # an older build's, as an update finds it
	Settings.save()
	Settings.load_settings()
	var shown := WhatsNew.take()
	check(not shown.is_empty() and shown[0][0], "after an update: the notes, a heading first")
	eq(Settings.whats_new_seen, Updater.version(), "marked seen")
	Settings.load_settings()
	eq(Settings.whats_new_seen, Updater.version(), "and saved")
	eq(WhatsNew.take(), [], "never twice")
	_done()


func test_the_title_shows_it_until_enter() -> void:
	_clean()
	Settings.whats_new_seen = "0.0.1"
	Settings.save()
	Settings.load_settings()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()  # (outside the tree) the game opens on the title
	_nodes.append(g)
	eq(g.screen, g.Screen.TITLE, "the title")
	var t: TitleScreen = g.menu
	check(not t.news.is_empty(), "up over the title")
	eq(t.news_version, Updater.version(), "this version's")
	t.handle(_menu(false, false, 1))
	eq(t.index, 0, "the title's choices wait under it")
	t.handle(_menu(true))
	check(t.news.is_empty(), "Enter puts it away")
	eq(g.screen, g.Screen.TITLE, "on the title, nothing picked")
	g.show_title()
	check((g.menu as TitleScreen).news.is_empty(), "back to the title later: not again")
	_done()


static func _menu(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.right_pressed = dir > 0
	return m
