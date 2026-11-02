## The callout queue (Callouts) and where the race feeds it.
extends TestSuite


func _tick(c: Callouts, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		c.update(1.0 / 60.0)


func test_one_at_a_time_in_order() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.CHECKPOINT)
	c.push(Callouts.Kind.BIG_AIR, "+2")
	eq(c.current["kind"], Callouts.Kind.CHECKPOINT, "the first is up")
	eq(c.waiting.size(), 1, "the second waits")
	_tick(c, Callouts.MIN_SHOW * 0.5)
	eq(c.current["kind"], Callouts.Kind.CHECKPOINT, "not stomped by the one behind it")
	_tick(c, Callouts.MIN_SHOW)
	eq(c.current["kind"], Callouts.Kind.BIG_AIR, "then the next")
	eq(c.current["sub"], "+2", "with its line")
	_tick(c, Callouts.SHOW_TIME)
	check(c.current.is_empty(), "and then nothing")


func test_alone_it_stays_its_full_time() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.GO, "", 1.0)
	_tick(c, 0.9)
	eq(c.current.get("kind"), Callouts.Kind.GO, "up for its second")
	_tick(c, 0.2)
	check(c.current.is_empty(), "gone after")


func test_the_same_kind_counts_again() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.NEAR_MISS)
	_tick(c, 0.3)
	c.push(Callouts.Kind.NEAR_MISS)
	eq(c.current["count"], 2, "counted")
	eq(c.current["age"], 0.0, "and pops again")
	eq(Callouts.label(c.current), "NEAR MISS x2", "says so")
	c.push(Callouts.Kind.BIG_AIR)
	c.push(Callouts.Kind.BIG_AIR)
	eq(c.waiting.size(), 1, "a waiting one counts again too")
	eq(c.waiting[0]["count"], 2, "BIG AIR x2 waiting")


func test_a_chain_sets_the_count() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.NEAR_MISS, "", Callouts.SHOW_TIME, 3)
	eq(Callouts.label(c.current), "NEAR MISS x3", "a new burst at the chain's length")
	c.push(Callouts.Kind.NEAR_MISS, "", Callouts.SHOW_TIME, 4)
	eq(c.current["count"], 4, "the one up takes the next length, not +1")
	c.push(Callouts.Kind.NEAR_MISS, "", Callouts.SHOW_TIME, 1)
	eq(Callouts.label(c.current), "NEAR MISS", "a fresh chain says so")


func test_race_near_miss_chain_bursts() -> void:
	var r := race(false, false)
	drive(r, 200)
	r.callouts.clear()
	for i in 3:
		var earned: int = r.score.bonuses.size()
		r.score.near_miss_scored()
		r._callouts_after_tick(earned, r.place)
	eq(Callouts.label(r.callouts.current), "NEAR MISS x3", "the burst shows the chain")


func test_messages_dont_merge() -> void:
	var c := Callouts.new()
	c.push_message("NITRO +1")
	c.push_message("NITRO +1")
	eq(c.waiting.size(), 1, "two pickups, two messages")


func test_checkpoint_and_time_extended_are_one_burst() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.CHECKPOINT)
	c.push(Callouts.Kind.TIME_EXTENDED, "+25 SEC")
	eq(c.current["kind"], Callouts.Kind.CHECKPOINT, "the checkpoint is up")
	eq(c.current["line2"], "TIME EXTENDED", "with TIME EXTENDED as its second line")
	eq(c.current["sub"], "+25 SEC", "and the seconds under them")
	check(c.waiting.is_empty(), "nothing behind it")
	c.clear()
	c.push(Callouts.Kind.GO)
	c.push(Callouts.Kind.CHECKPOINT)
	c.push(Callouts.Kind.TIME_EXTENDED, "+20 SEC")
	eq(c.waiting.size(), 1, "behind GO, still one burst")
	eq(c.waiting[0]["line2"], "TIME EXTENDED", "merged into the waiting checkpoint")
	c.clear()
	c.push(Callouts.Kind.TIME_EXTENDED, "+5 SEC")
	eq(c.current["kind"], Callouts.Kind.TIME_EXTENDED, "with no checkpoint it bursts on its own")


func test_the_merged_burst_fits() -> void:
	var c := {"kind": Callouts.Kind.CHECKPOINT, "text": "CHECKPOINT", "line2": "TIME EXTENDED", "sub": "+25 SEC", "count": 1}
	var lines := Hud.burst_lines(c, Hud.BURSTS[Callouts.Kind.CHECKPOINT]["size"])
	eq(lines.map(func(l: Dictionary) -> String: return l["text"]), ["CHECKPOINT", "TIME EXTENDED", "+25 SEC"], "three lines, in order")
	for i in range(1, lines.size()):
		check(lines[i]["y"] - lines[i]["size"] * 0.75 >= lines[i - 1]["y"], "line %d under the one above" % i)
	var r := Hud.burst_radius_for(lines)
	check(r.x * 2.0 > UiText.width("TIME EXTENDED", Hud.LINE2_SIZE) + 40.0, "as wide as the widest line, with room")
	check(r.y * 0.74 >= -lines[0]["y"] + lines[0]["size"] * 0.75 - 4.0, "the top line inside the valleys")
	check(r.x * 1.12 < Cfg.SCREEN_W / 2.0, "on screen")
	var one := Hud.burst_lines({"kind": Callouts.Kind.GO, "text": "GO!", "line2": "", "sub": "", "count": 1}, 34)
	eq(Hud.burst_radius_for(one), Hud.burst_radius("GO!", 34), "a one-line burst as before")


func test_a_kind_does_not_repeat_too_soon() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.BIG_AIR)
	_tick(c, Callouts.SHOW_TIME + 0.1)
	check(c.current.is_empty(), "the first came and went")
	c.push(Callouts.Kind.BIG_AIR)
	check(c.current.is_empty(), "another BIG AIR straight after is dropped")
	c.push(Callouts.Kind.NEAR_MISS)
	eq(c.current.get("kind"), Callouts.Kind.NEAR_MISS, "another kind still bursts")
	c.push(Callouts.Kind.NEAR_MISS, "", Callouts.SHOW_TIME, 1)
	eq(c.current["count"], 1, "a new chain counts into the one up")
	_tick(c, Callouts.SHOW_TIME + 0.1)
	c.push(Callouts.Kind.NEAR_MISS, "", Callouts.SHOW_TIME, 2)
	eq(Callouts.label(c.current), "NEAR MISS x2", "a chain growing is news: never capped")
	_tick(c, Callouts.REPEAT_GAP)
	c.push(Callouts.Kind.BIG_AIR)
	eq(c.current.get("kind"), Callouts.Kind.BIG_AIR, "after REPEAT_GAP it bursts again")
	check(Callouts.too_soon(10.0, 10.0 + Callouts.REPEAT_GAP - 0.01), "too soon")
	check(not Callouts.too_soon(10.0, 10.0 + Callouts.REPEAT_GAP), "not")


func test_first_place_never_ahead_of_finish() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.FIRST_PLACE)  # took the lead a moment before the line
	c.push(Callouts.Kind.NEAR_MISS)
	c.finish("FINISH!", "1ST of 6", true)
	eq(c.current["text"], "FINISH!", "FINISH! first, at once")
	eq(c.waiting.map(func(w: Dictionary) -> String: return w["text"]), ["1ST PLACE", "FINISH!"], "then 1ST PLACE, then FINISH! again")
	c.push(Callouts.Kind.BIG_AIR)
	c.push_message("NITRO +1")
	eq(c.waiting.size(), 2, "nothing more after the line")
	_tick(c, Callouts.MIN_SHOW + 0.05)
	eq(c.current["text"], "FINISH!", "not cut short by the burst behind it")
	_tick(c, Callouts.FINISH_LEAD)
	eq(c.current["kind"], Callouts.Kind.FIRST_PLACE, "then the win")
	_tick(c, Callouts.SHOW_TIME + 0.05)
	eq(c.current["text"], "FINISH!", "and the finish holds")
	_tick(c, 20.0)
	eq(c.current["seconds"], Callouts.HOLD, "held")
	c.clear()
	c.push(Callouts.Kind.BIG_AIR)
	check(not c.current.is_empty(), "a restart takes callouts again")
	c.clear()
	c.finish("FINISH!", "", false)
	check(c.current["seconds"] >= Callouts.HOLD and c.waiting.is_empty(), "no win: FINISH! held alone")


func test_a_backlog_drops_the_oldest_waiting() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.GO)
	for k in [Callouts.Kind.CHECKPOINT, Callouts.Kind.FINAL_STRETCH, Callouts.Kind.NEAR_MISS, Callouts.Kind.BIG_AIR]:
		c.push(k)
	eq(c.waiting.size(), Callouts.MAX_WAITING, "capped")
	eq(c.waiting[0]["kind"], Callouts.Kind.FINAL_STRETCH, "the oldest went")


func test_a_held_message_stays_until_cleared() -> void:
	var c := Callouts.new()
	c.push(Callouts.Kind.BIG_AIR)
	c.push_message("FINISH!", "Time 1:02.00", Callouts.HOLD)
	_tick(c, Callouts.MIN_SHOW + 0.05)
	eq(c.current["text"], "FINISH!", "the burst, then the finish")
	c.push(Callouts.Kind.NEAR_MISS)
	_tick(c, 30.0)
	eq(c.current["text"], "FINISH!", "held, even with one waiting")
	eq(Callouts.alpha(c.current), 1.0, "and doesn't fade")
	c.clear()
	check(c.current.is_empty() and c.waiting.is_empty(), "cleared")


func test_pop_and_fade() -> void:
	near(Callouts.pop_scale(0.0), 0.3, 0.001, "starts small")
	check(Callouts.pop_scale(Callouts.POP_TIME * 0.75) > 1.0, "overshoots on the way")
	eq(Callouts.pop_scale(1.0), 1.0, "settles")
	var c := {"kind": Callouts.Kind.GO, "text": "GO!", "sub": "", "seconds": 1.0, "age": 0.5, "count": 1}
	eq(Callouts.alpha(c), 1.0, "solid mid-way")
	c["age"] = 1.0 - Callouts.FADE_TIME * 0.5
	near(Callouts.alpha(c), 0.5, 0.001, "fading at the end")


func test_starburst_points() -> void:
	var pts := Callouts.starburst(Vector2(100, 50), Vector2(60, 30), 12, 0.75)
	eq(pts.size(), 24, "a spike and a valley each")
	eq(pts[0], Vector2(100, 20), "the first spike straight up")
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	eq(r, Rect2(40, 20, 120, 60), "spans the ellipse")
	for i in pts.size():
		var outer := i % 2 == 0
		var d := ((pts[i] - Vector2(100, 50)) / Vector2(60, 30)).length()
		check(absf(d - (1.0 if outer else 0.75)) < 0.05, "point %d on its ring: %.2f" % [i, d])


func test_burst_fits_its_text() -> void:
	var small := Hud.burst_radius("GO!", 34)
	var long := Hud.burst_radius("TIME EXTENDED", 22)
	check(long.x > UiText.width("TIME EXTENDED", 22) / 2.0, "the text inside")
	check(small.x >= 70.0, "short text still a burst")
	for kind in Callouts.TEXT:
		check(Hud.BURSTS.has(kind), "a look for %s" % Callouts.TEXT[kind])
		var rx: float = Hud.burst_radius(Callouts.TEXT[kind] + " x9", Hud.BURSTS[kind]["size"]).x * 1.12
		check(rx < Cfg.SCREEN_W / 2.0, "%s x9 fits the screen" % Callouts.TEXT[kind])


func test_bonus_and_stretch_rules() -> void:
	eq(Callouts.for_bonus("NEAR MISS"), Callouts.Kind.NEAR_MISS, "near miss")
	eq(Callouts.for_bonus("BIG AIR"), Callouts.Kind.BIG_AIR, "big air")
	eq(Callouts.for_bonus("AIR"), Callouts.Kind.NONE, "a small jump has none")
	check(not Callouts.in_final_stretch(800.0, 1000.0), "not yet")
	check(Callouts.in_final_stretch(950.0, 1000.0), "the last tenth")
	check(not Callouts.in_final_stretch(1000.0, 1000.0), "over at the line")


func test_race_go_checkpoint_and_stretch() -> void:
	var r := race(false, false)
	drive(r, 181)
	eq(r.callouts.current.get("kind"), Callouts.Kind.GO, "GO bursts")
	drive(r, 120)
	r.player.distance = r.checkpoint_distances[0] + 1.0
	r._check_progress()
	eq(r.callouts.current.get("kind"), Callouts.Kind.CHECKPOINT, "CHECKPOINT")
	eq(r.callouts.current.get("line2"), "TIME EXTENDED", "TIME EXTENDED in the same burst")
	check(r.callouts.waiting.is_empty(), "not a burst of its own")
	eq(r.banner, "CHECKPOINT!", "the race's banner as before")
	r.callouts.clear()
	r.next_checkpoint = r.checkpoint_distances.size()  # (past them all)
	r.player.distance = r.finish_distance * 0.95
	drive(r, 1, input(1.0))
	eq(r.callouts.current.get("kind"), Callouts.Kind.FINAL_STRETCH, "FINAL STRETCH")
	r.callouts.clear()
	drive(r, 1, input(1.0))
	check(r.callouts.current.is_empty(), "only once")


func test_race_near_miss_and_lead() -> void:
	var r := race(false, false)
	drive(r, 200)
	r.callouts.clear()
	r.score.add("NEAR MISS", Tuning.i("scoring/near_miss"))  # as if scored this tick
	r._callouts_after_tick(r.score.bonuses.size() - 1, r.place)
	eq(r.callouts.current.get("kind"), Callouts.Kind.NEAR_MISS, "a near miss bursts")
	r.callouts.clear()
	r.place = 1
	r._callouts_after_tick(r.score.bonuses.size(), 3)
	eq(r.callouts.current.get("kind"), Callouts.Kind.FIRST_PLACE, "taking the lead")
	r.callouts.clear()
	r._callouts_after_tick(r.score.bonuses.size(), 2)
	check(r.callouts.current.is_empty(), "not again straight after")


func test_race_finish_in_first_shows_finish_first() -> void:
	var r := race(false, true)
	drive(r, 181)
	r.place = 1
	r.callouts.push(Callouts.Kind.FIRST_PLACE)  # the lead taken just before the line
	for car: RivalCar in r.rivals.cars:
		car.distance = 0.0
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	eq(r.place, 1, "won")
	eq(r.callouts.current.get("text"), "FINISH!", "FINISH! first")
	eq(r.callouts.waiting[0]["kind"], Callouts.Kind.FIRST_PLACE, "1ST PLACE after it")


func test_race_finish_holds() -> void:
	var r := race(false, false)
	drive(r, 181)
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()
	_tick(r.callouts, 3.0)
	eq(r.callouts.current.get("text"), "FINISH!", "the finish stays up")
	r.start_race()
	check(r.callouts.current.is_empty(), "a restart clears it")
