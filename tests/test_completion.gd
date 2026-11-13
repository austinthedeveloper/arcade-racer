## The completion page (MP-17): each stage's items and percentage, the whole game's, from the
## progress fixture (tests/fixtures/save_progress.cfg) and from a fresh save; and the stats
## page's tabs that reach it.
extends TestSuite

const FIXTURE := "res://tests/fixtures/save_progress.cfg"
const NORMAL := Difficulty.Level.NORMAL


func _sd() -> Node:
	return runner.root.get_node("SaveData")


func _fixture() -> Node:
	TestSuite.use_scratch_save(_sd())
	var out := FileAccess.open(TestSuite.SCRATCH_SAVE, FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(FIXTURE))
	out.close()
	_sd().load_save()
	return _sd()


func test_the_percentage_per_stage_from_a_fixture_save() -> void:
	var sd := _fixture()
	# Palm Coast: won, gold, won mirrored. Redrock and Neon: won, bronze. Timberline: finished.
	eq(Completion.stage_percent(0, sd, NORMAL), 100, "Palm Coast: everything")
	eq(Completion.stage_percent(1, sd, NORMAL), 50, "Redrock: finish, win, bronze")
	eq(Completion.stage_percent(2, sd, NORMAL), 50, "Neon: the same")
	eq(Completion.stage_percent(3, sd, NORMAL), 16, "Timberline: a finish (1 of 6, rounded down)")
	for i in range(4, Stages.count()):
		eq(Completion.stage_percent(i, sd, NORMAL), 0, "%s: nothing yet" % Stages.stage_name(i))
	var items := Completion.stage_items(1, sd, NORMAL)
	eq(items.map(func(it: Dictionary) -> bool: return it["done"]), [true, true, true, false, false, false], "Redrock's items")
	eq(items.map(func(it: Dictionary) -> String: return it["label"]), Completion.STAGE_ITEMS, "in order")
	eq(Completion.next_item(1, sd, NORMAL), "SILVER", "Redrock's next")
	eq(Completion.next_item(0, sd, NORMAL), "", "nothing left on Palm Coast")
	eq(CompletionScreen.next_up(sd, NORMAL), ["SILVER", "REDROCK CANYON"], "the page's next up")
	# The medals go by the difficulty asked about: on Hard Palm Coast's 88.5 is silver
	eq(Completion.stage_percent(0, sd, Difficulty.Level.HARD), 83, "Palm Coast on Hard: 5 of 6")
	TestSuite.use_scratch_save(_sd())


func test_the_whole_game_from_a_fixture_save() -> void:
	var sd := _fixture()
	var parts := Completion.parts(sd, NORMAL)
	eq(parts[0], {"label": "STAGES", "done": 13, "total": 48}, "the stages: 6 + 3 + 3 + 1 of 8 x 6")
	eq(parts[1], {"label": "STICKERS", "done": 12, "total": 24}, "half the stickers")
	eq(parts[2], {"label": "CARS", "done": 8, "total": Cars.LIST.size()}, "four starters and four by stage 5")
	eq(Completion.overall(sd, NORMAL), Completion.percent(33, 48 + 24 + Cars.LIST.size()), "33 of them all")
	eq(Completion.overall(sd, NORMAL), 39, "39%")
	Settings.unlock_all = true
	eq(Completion.car_count(sd), 8, "the unlock-everything option earns nothing")
	Settings.unlock_all = false
	TestSuite.use_scratch_save(_sd())


func test_a_fresh_save_is_at_nothing_and_a_full_one_at_100() -> void:
	TestSuite.use_scratch_save(_sd())
	var sd := _sd()
	eq(Completion.overall(sd, NORMAL), Completion.percent(Unlocks.STARTERS.size(), 48 + 24 + Cars.LIST.size()), "only the starter cars")
	for i in Stages.count():
		sd.bests[SaveData.best_key(i, "car_vega")] = {"time": Medals.time_for(i, NORMAL, Medals.Medal.GOLD), "place": 1}
		sd.unlocks.append(Unlocks.mirror_id(i))
		sd.mirror_wins.append(Stages.POSTCARDS[i])
		eq(Completion.stage_percent(i, sd, NORMAL), 100, "%s done" % Stages.stage_name(i))
	sd.furthest_stage = Stages.count() - 1
	sd.unlocks.append_array([Unlocks.TOUR_CAR, Unlocks.SECRET_CAR])
	for id in Stickers.ids():
		sd.stickers[id] = 1
	eq(Completion.overall(sd, NORMAL), 100, "everything")
	eq(CompletionScreen.next_up(sd, NORMAL), [] as Array[String], "nothing next")
	TestSuite.use_scratch_save(_sd())


func test_percent_rounds_down() -> void:
	eq(Completion.percent(0, 6), 0, "none")
	eq(Completion.percent(5, 6), 83, "83, not 84")
	eq(Completion.percent(83, 84), 98, "never 100 with one left")
	eq(Completion.percent(6, 6), 100, "all")
	eq(Completion.percent(1, 0), 0, "nothing to do")


## Title > STATS, then right to the stickers and completion, round to the stats, back.
func test_the_stats_tabs_reach_the_stickers_and_completion() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.show_stats()
	g.menu.handle(_m(false, false, 1))
	eq(g.screen, g.Screen.STICKERS, "right: the stickers")
	check(g.menu is StickerScreen, "drawn by StickerScreen")
	eq(g.menu.index, -1, "on the tabs")
	g.menu.handle(_m(false, false, 1))
	eq(g.screen, g.Screen.COMPLETION, "right again: completion")
	check(g.menu is CompletionScreen, "drawn by CompletionScreen")
	g.menu.handle(_m(false, false, 1))
	eq(g.screen, g.Screen.STATS, "and round to the stats")
	g.menu.handle(_m(false, false, -1))
	eq(g.screen, g.Screen.COMPLETION, "left: back round")
	g.menu.handle(_m(false, false, -1))
	eq(g.screen, g.Screen.STICKERS, "left: the stickers")
	var down := MenuInput.new()
	down.down_pressed = true
	g.menu.handle(down)
	eq(g.menu.index, 0, "down: the first sticker")
	g.menu.handle(_m(false, false, 1))
	eq([g.screen, g.menu.index], [g.Screen.STICKERS, 1], "right in the grid picks the next sticker")
	g.menu.handle(_m(false, true))
	eq(g.screen, g.Screen.TITLE, "back: the title")
	eq(TitleScreen.items()[g.menu.index], "STATS", "on STATS")
	g.show_completion()
	g.menu.handle(_m(false, true))
	eq(g.screen, g.Screen.TITLE, "back from completion too")


static func _m(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m
