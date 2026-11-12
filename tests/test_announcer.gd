## The announcer (Announcer) and its subtitles (AC-5): one line at a time, the music ducked
## under it, the words on screen while it speaks.
extends TestSuite


func audio_node() -> Node:
	var a: Node = runner.root.get_node("Audio")
	a._ready()
	return a


func test_every_line_has_a_voice_and_words() -> void:
	for id: String in Announcer.LINES:
		var cue := Announcer.cue(id)
		check(SoundBank.path_for(cue) != "", "a voice file for " + id)
		check(SoundBank.stream(cue) != null, cue + " loads")
		check(String(Announcer.LINES[id]).length() > 2, id + " has words")
		check(Announcer.PRIORITY.has(id), id + " has a priority")
		check(Announcer.duration(id) > 0.3, id + " takes time to say")
		check(not SoundBank.loops(cue), cue + " plays once")


## Starts of every line spoken while a flood of `ids` is said at once, then `extra` later.
func _run(a: Announcer, seconds: float, says: Dictionary) -> Array:
	var starts := []
	var t := 0.0
	var frame := 0
	while t < seconds:
		for id: String in says.get(frame, []):
			a.say(id)
		var line := a.update(DT)
		if line != "":
			starts.append([t, line])
		t += DT
		frame += 1
	return starts


func test_no_two_lines_overlap() -> void:
	var a := Announcer.new()
	a.reset()
	var says := {0: Announcer.LINES.keys()}
	for f in range(10, 900, 37):  # and more keep coming
		says[f] = [["near_miss", "big_air", "checkpoint", "first_place"][f % 4]]
	var starts := _run(a, 30.0, says)
	check(starts.size() >= 5, "several lines spoken (%d)" % starts.size())
	for i in range(1, starts.size()):
		var prev_end: float = starts[i - 1][0] + Announcer.duration(starts[i - 1][1])
		check(starts[i][0] >= prev_end - 0.0001, "%s starts after %s ends" % [starts[i][1], starts[i - 1][1]])


func test_the_finish_goes_first_and_stale_lines_drop() -> void:
	var a := Announcer.new()
	a.reset()
	a.say("near_miss")
	eq(a.update(DT), "near_miss", "said at once")
	a.say("big_air")
	a.say("finish_1")
	var starts := _run(a, 10.0, {})
	eq(starts[0][1], "finish_1", "the finish jumps the queue")
	for s in starts:
		check(s[1] != "big_air", "a near miss's moment had passed")
	a.reset()
	a.say("checkpoint")
	a.update(DT)
	a.say("time_extended")
	var later := _run(a, 6.0, {})
	eq(later.size(), 1, "time extended still follows a checkpoint")


func test_the_music_ducks_under_a_line() -> void:
	var au := audio_node()
	for i in 600:  # let any duck from an earlier race run out
		au.step_duck(DT)
	au.duck(0.5)
	for i in 30:
		au.step_duck(DT)
	near(au.duck_db, Audio.DUCK_DB, 0.01, "down while it speaks")
	for i in 60:
		au.step_duck(DT)
	near(au.duck_db, 0.0, 0.01, "and back up after")


func test_subtitles_follow_the_cue_in_a_race() -> void:
	var r := race(false, false)
	var au := audio_node()
	au.history.clear()
	r.audio.update(DT)
	for i in 3:
		r.audio.update(DT)
	eq(au.history.count("vo_ready"), 1, "the ready line with the countdown")
	eq(r.audio.announcer.subtitle(), Announcer.LINES["ready"], "its words up")
	for i in 260:
		drive(r, 1, input(1.0))
		r.audio.update(DT)
	eq(au.history.count("vo_go"), 1, "GO said once")
	r.player.distance = r.finish_distance + 1.0
	for i in 200:
		drive(r, 1, input(1.0))
		r.audio.update(DT)
	check(au.history.has("vo_" + Announcer.finish_line(r.place, true)), "the finish line for the place")


func test_subtitles_option() -> void:
	TestSuite.use_scratch_settings(Settings)
	eq(Settings.subtitles, true, "on by default")
	var o := OptionsScreen.new()
	check(OptionsScreen.Row.SUBTITLES in OptionsScreen.PAGE_ROWS[OptionsScreen.Page.ACCESSIBILITY], "on the accessibility page")
	o.change(OptionsScreen.Row.SUBTITLES, 1, true)
	Settings.load_settings()
	eq(Settings.subtitles, false, "turned off and saved")
	o.free()
	TestSuite.use_scratch_settings(Settings)


func test_finish_lines_by_place() -> void:
	eq(Announcer.finish_line(1, true), "finish_1", "a win")
	eq(Announcer.finish_line(3, true), "finish_3", "the podium")
	eq(Announcer.finish_line(5, true), "finish", "off the podium")
	eq(Announcer.finish_line(1, false), "finish", "no rivals: just finished")
	eq(Announcer.syllables("Big air!"), 2, "syllables by vowel groups")


## The voiceover script (docs/announcer/lines.csv, tools/announcer_script.py) has every line the
## race says, under the same id and with the same words, so its recordings drop in as they are.
func test_the_voiceover_script_has_every_line_the_race_says() -> void:
	var f := FileAccess.open("res://docs/announcer/lines.csv", FileAccess.READ)
	if not check(f != null, "docs/announcer/lines.csv is there"):
		return
	var header := f.get_csv_line()
	eq(Array(header), ["id", "file", "text", "delivery", "max_seconds", "group", "status"], "its columns")
	var rows := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == header.size():
			rows[row[0]] = row
	check(rows.size() > Announcer.LINES.size(), "more lines than the race says today (variants, stage intros)")
	for id in Announcer.LINES:
		if not check(rows.has(id), id + " is in the script"):
			continue
		var row: PackedStringArray = rows[id]
		eq([row[1], row[2], row[6]], [Announcer.cue(id) + ".wav", Announcer.LINES[id], "said"],
			id + ": its file, its words as the subtitle shows them, marked said")
		check(Announcer.duration(id) <= float(row[4]) + 0.75, "%s: today's placeholder fits the script's %s s" % [id, row[4]])
	for id in rows:
		if rows[id][6] == "said":
			check(Announcer.LINES.has(id), id + ": marked said, and the race says it")
