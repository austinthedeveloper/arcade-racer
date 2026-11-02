## Medals (MP-9): the table per stage and difficulty, what a time earns, the medal held from
## the save, and where stage select and the results show them.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	TestSuite.use_scratch_settings(runner.root.get_node("Settings"))


## The autodrive's finish time on `stage` with traffic and rivals: the last line of its golden
## trace (tests/golden/), so the medals follow any change to play that regenerates them.
static func autodrive_time(stage: int) -> float:
	var scenario: String = "autodrive_traffic" if stage == 0 else Stages.POSTCARDS[stage] + "_autodrive_traffic"
	var lines := FileAccess.get_file_as_string(Golden.DIR + scenario + ".txt").strip_edges().split("\n")
	var last := lines[lines.size() - 1]
	return float(last.get_slice(" t=", 1).get_slice(" ", 0))


func test_every_stage_has_a_table_in_order() -> void:
	eq(Medals.TIMES.size(), Stages.count(), "a row per stage")
	for stage in Stages.count():
		for level in Difficulty.Level.size():
			var t := Medals.times(stage, level)
			eq(t.size(), 3, "gold, silver, bronze")
			check(t[0] < t[1] and t[1] < t[2], "%s %s: gold quicker than silver quicker than bronze" % [Stages.POSTCARDS[stage], Difficulty.NAMES[level]])
		var easy := Medals.times(stage, Difficulty.Level.EASY)
		var normal := Medals.times(stage, Difficulty.Level.NORMAL)
		var hard := Medals.times(stage, Difficulty.Level.HARD)
		for i in 3:
			check(easy[i] > normal[i] and normal[i] > hard[i], "%s: Hard asks for quicker times than Easy" % Stages.POSTCARDS[stage])


func test_gold_beats_the_autodrive_and_bronze_is_in_reach() -> void:
	for stage in Stages.count():
		var auto := autodrive_time(stage)
		check(auto > 60.0, "%s: the autodrive's time read (%.2f)" % [Stages.POSTCARDS[stage], auto])
		for level in Difficulty.Level.size():
			var label := "%s %s" % [Stages.POSTCARDS[stage], Difficulty.NAMES[level]]
			check(Medals.time_for(stage, level, Medals.Medal.GOLD) < auto, label + ": gold is quicker than the autodrive")
			check(Medals.earned(stage, level, auto) >= Medals.Medal.BRONZE, label + ": the autodrive earns a medal")
		eq(Medals.earned(stage, Difficulty.Level.NORMAL, auto), Medals.Medal.SILVER, Stages.POSTCARDS[stage] + ": silver for the autodrive on Normal")


func test_what_a_time_earns() -> void:
	var t := Medals.times(0, Difficulty.Level.NORMAL)
	eq(Medals.earned(0, Difficulty.Level.NORMAL, t[0]), Medals.Medal.GOLD, "the gold time itself is gold")
	eq(Medals.earned(0, Difficulty.Level.NORMAL, t[0] + 0.01), Medals.Medal.SILVER, "a hair over: silver")
	eq(Medals.earned(0, Difficulty.Level.NORMAL, t[2]), Medals.Medal.BRONZE, "bronze")
	eq(Medals.earned(0, Difficulty.Level.NORMAL, t[2] + 1.0), Medals.Medal.NONE, "slower: none")
	eq(Medals.earned(0, Difficulty.Level.NORMAL, INF), Medals.Medal.NONE, "no time: none")
	eq(Medals.earned(0, Difficulty.Level.NORMAL, -1.0), Medals.Medal.NONE, "still racing: none")
	var hard_gold := Medals.time_for(0, Difficulty.Level.HARD, Medals.Medal.GOLD)
	eq(Medals.earned(0, Difficulty.Level.NORMAL, hard_gold + 0.5), Medals.Medal.GOLD, "gold on Normal...")
	eq(Medals.earned(0, Difficulty.Level.HARD, hard_gold + 0.5), Medals.Medal.SILVER, "...silver on Hard")


func test_the_medal_held_is_the_best_time_with_any_car() -> void:
	_clean()
	var sd: Node = runner.root.get_node("SaveData")
	eq(Medals.held(1), Medals.Medal.NONE, "nothing raced: none")
	check(is_inf(sd.stage_best(1)), "no best")
	var t := Medals.times(1, Difficulty.Level.NORMAL)
	sd.record_finish(1, "car_vega", t[2] - 0.5, 0, false)
	eq(Medals.held(1), Medals.Medal.BRONZE, "bronze")
	sd.record_finish(1, "car_mesa", t[0] - 0.5, 0, false)
	eq(Medals.held(1), Medals.Medal.GOLD, "a quicker car's time counts")
	eq(sd.stage_best(1), t[0] - 0.5, "the best of every car")
	eq(Medals.held(0), Medals.Medal.NONE, "other stages untouched")
	runner.root.get_node("Settings").difficulty = Difficulty.Level.HARD
	eq(Medals.held(1), Medals.earned(1, Difficulty.Level.HARD, t[0] - 0.5), "against the difficulty picked")
	_clean()


func test_stage_select_lists_the_times_and_the_best() -> void:
	var t := Medals.times(2, Difficulty.Level.NORMAL)
	var rows := StageSelect.medal_rows(2, Difficulty.Level.NORMAL, t[1] - 1.0)
	eq(rows.size(), 4, "three medals and the best")
	eq([rows[0]["medal"], rows[1]["medal"], rows[2]["medal"]], [Medals.Medal.GOLD, Medals.Medal.SILVER, Medals.Medal.BRONZE], "gold first")
	eq(rows[0]["text"], "GOLD  " + Hud.clock_text(t[0]), "with its time")
	eq([rows[0]["lit"], rows[1]["lit"], rows[2]["lit"]], [false, true, false], "the medal held lit")
	eq(rows[3]["text"], "BEST  " + Hud.clock_text(t[1] - 1.0), "the best time")
	var none := StageSelect.medal_rows(2, Difficulty.Level.NORMAL, INF)
	eq([none[0]["lit"], none[1]["lit"], none[2]["lit"], none[3]["lit"]], [false, false, false, false], "nothing raced: nothing lit")
	eq(none[3]["text"], "BEST  -:--.--", "and no best")


func test_a_medal_hangs_on_each_postcard_inside_it() -> void:
	for i in Stages.count():
		check(StageSelect.card_rect(i).has_point(StageSelect.medal_spot(i)), "stage %d's medal on its postcard" % (i + 1))
	for i in Stages.count():
		check(not StageSelect.MEDAL_PANEL.intersects(StageSelect.card_rect(i).grow(3)), "the medal panel clear of stage %d's postcard" % (i + 1))
	check(not StageSelect.MEDAL_PANEL.intersects(StageSelect.BIG.grow(5)), "and of the big one")
	check(StageSelect.MEDAL_PANEL.end.y < StageSelect.BAND.position.y, "above the band")
