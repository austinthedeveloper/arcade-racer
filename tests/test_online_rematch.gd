## Online after the line (ON-9): the room stays open, the host picks the next stage, everyone
## says READY on the results and the next race starts when all are in.
extends TestSuite


## A host and `guests` guests in one room on an in-memory relay, polled until settled.
func room(guests := 1) -> Array:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var out: Array = [OnlineSession.hosting_on(h, "car_vega")]
	for i in guests:
		var g := LoopLink.new(relay)
		g.join(h.room)
		out.append(OnlineSession.joining_on(g, ["car_mesa", "car_kestrel", "car_bruiser"][i]))
	settle(out)
	return out


static func settle(sessions: Array, dt := 0.0) -> void:
	for i in 4:
		for s: OnlineSession in sessions:
			s.poll(dt if i == 0 else 0.0)


## A room through a race to the GO, everyone loaded.
func raced(guests := 1) -> Array:
	var r := room(guests)
	r[0].start()
	settle(r)
	for s: OnlineSession in r:
		s.loaded()
		s.started = false  # (the game would have opened the race)
	settle(r)
	return r


func test_the_room_goes_lobby_race_ready_and_races_again() -> void:
	var r := room(1)
	var h: OnlineSession = r[0]
	var g: OnlineSession = r[1]
	eq([h.phase, g.phase], [OnlineSession.Phase.LOBBY, OnlineSession.Phase.LOBBY], "the lobby")
	h.start()
	settle(r)
	eq([h.phase, g.phase], [OnlineSession.Phase.LOADING, OnlineSession.Phase.LOADING], "loading")
	h.loaded()
	g.loaded()
	settle(r)
	eq([h.phase, g.phase], [OnlineSession.Phase.RACING, OnlineSession.Phase.RACING], "racing")
	h.started = false
	g.started = false
	h.finish(60.0)
	g.finish(61.0)
	settle(r)
	h.choose(4, false)
	h.ready_again()
	settle(r)
	eq([h.ready_count(), g.ready_count()], [1, 1], "the host ready: one of two, on both")
	eq(g.stage, 4, "the host's next stage reaches the guest")
	eq(h.phase, OnlineSession.Phase.RACING, "no start until all are in")
	check(not g.started, "the guest's results stay up")
	g.ready_again()
	settle(r)
	for s: OnlineSession in r:
		check(s.started, "everyone ready: the next race opens")
		eq(s.phase, OnlineSession.Phase.LOADING, "loading it")
		eq(s.stage, 4, "on the stage the host picked")
		check(s.finishes.is_empty() and s.again.is_empty(), "a fresh race: no finishes, nobody ready yet")
	h.loaded()
	g.loaded()
	settle(r)
	check(h.go and g.go, "and it goes")


func test_ready_can_be_taken_back_and_is_only_after_a_race() -> void:
	var r := room(1)
	r[1].ready_again()
	settle(r)
	eq(r[0].ready_count(), 0, "nothing to be ready for in the lobby")
	r = raced(1)
	r[1].ready_again()
	settle(r)
	eq(r[0].ready_count(), 1, "the guest ready")
	check(r[1].is_ready_again(), "and it knows")
	r[1].ready_again(false)
	settle(r)
	eq([r[0].ready_count(), r[1].ready_count()], [0, 0], "taken back")


func test_the_last_one_not_ready_leaving_starts_the_rematch() -> void:
	var r := raced(2)
	r[0].ready_again()
	r[1].ready_again()
	settle(r)
	check(not r[0].started, "P3 not ready yet")
	r[2].leave()
	settle(r)
	check(r[0].started and r[1].started, "P3 gone: the two left are all in")
	eq(r[0].racers, [0, 1], "racing without P3")


func test_the_host_can_start_the_rematch_without_waiting() -> void:
	var r := raced(1)
	var rc := race(false, false, 0, false)
	rc.online = r[0]
	rc.online_continue()
	settle(r)
	check(r[0].is_ready_again() and not r[0].started, "READY first")
	eq(ResultsScreen.online_label(r[0]), "START NOW", "then the host's button starts it")
	eq(ResultsScreen.ready_line(r[1]), "READY  1 / 2", "the count, as the guest sees it")
	rc.online_continue()
	settle(r)
	check(r[0].started and r[1].started, "started for everyone, the guest still on its results")


func test_the_results_buttons_online() -> void:
	var r := raced(1)
	eq(ResultsScreen.online_label(r[1]), "READY", "READY")
	r[1].ready_again()
	eq(ResultsScreen.online_label(r[1]), "CANCEL READY", "then a way back")
	r[0].leave()
	settle(r)
	eq(ResultsScreen.online_label(r[1]), "BACK", "the room gone: back to the online screen")
	check(ResultsScreen.results_hints(true).contains("next stage"), "the host's hint")
	check(not ResultsScreen.results_hints(false).contains("next stage"), "not a guest's")


func test_the_host_picks_the_next_stage_on_the_results() -> void:
	var r := raced(1)
	var rc := race(false, false, 0, false)
	rc.online = r[0]
	var m := MenuInput.new()
	m.down_pressed = true
	var before: int = r[0].stage
	rc.online_results_input(m)
	settle(r)
	eq(r[0].stage, OnlineScreen.next_stage(before, 1), "the next open stage")
	eq(r[1].stage, r[0].stage, "and the guest's results show it")
	var picked: int = r[0].stage
	rc.online = r[1]
	m.down_pressed = true
	rc.online_results_input(m)
	settle(r)
	eq(r[1].stage, picked, "a guest can't pick")


## --online=host / join with --races=2 (two windows, two races): each game says READY after
## the first, the host moves on a stage, and the second race starts on both.
func test_online_flags_race_twice() -> void:
	var relay := LoopLink.Relay.new()
	var games: Array = []
	var quits := [0]
	for i in 2:
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g._ready()
		g.calibration.visible = false  # (shut by their own _ready, in the tree)
		g.debug_panel.visible = false
		_nodes.append(g)
		g.make_link = func() -> NetLink: return LoopLink.new(relay)
		g.on_quit = func() -> void: quits[0] += 1
		games.append(g)
	games[0].stage_index = 0
	games[0].online_from_flags("host", 2)
	games[1].online_from_flags("join:" + games[0].online.link.room)
	for g: Node in games:
		g.auto_races = 2
	var seen: Array = []
	for race_no in 2:
		for i in 6:
			for g: Node in games:
				g._physics_process(DT)
		var races: Array = []
		for g: Node in games:
			check(g.race != null and not seen.has(g.race), "race %d open on both" % (race_no + 1))
			TestSuite.ready_all(g.race)
			races.append(g.race)
		eq(games[1].online.stage, OnlineScreen.next_stage(0, race_no) if race_no > 0 else 0, "race %d's stage" % (race_no + 1))
		seen.append_array(races)
		for i in 200:
			for g: Node in games:
				g._physics_process(DT)
			for rc: Node in races:
				drive(rc, 1, input(1.0))
		for rc: Node in races:
			check(rc.state == rc.State.RACING, "racing: %s go %s phase %s countdown %s" % [rc.state, rc.online.go, rc.online.phase, rc.countdown])
			rc.player.distance = rc.finish_distance + 1.0
		for i in 3:
			for rc: Node in races:
				drive(rc, 1, input(1.0))
			for g: Node in games:
				g._physics_process(DT)
		if race_no == 0:
			eq(quits[0], 0, "on to a second race")
	eq(quits[0], 2, "both done after the second race")


## --online=bot (screenshots): the game hosts on an in-memory relay with a made-up guest, which
## joins, loads and races.
func test_online_bot_joins_and_races() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	g.calibration.visible = false
	g.debug_panel.visible = false
	_nodes.append(g)
	g.on_quit = func() -> void: pass
	g.online_from_flags("bot", 2)
	for i in 6:
		g._physics_process(DT)
	check(g.race != null, "racing")
	TestSuite.ready_all(g.race)
	eq(g.online.players.size(), 2, "with the bot")
	for i in 240:
		g._physics_process(DT)
		drive(g.race, 1, input(1.0))
	var bot: RivalCar = g.race.rivals.cars[0]
	check(bot.remote and bot.distance > 1000.0, "the bot on the road, moving: %f" % bot.distance)


func test_a_lagged_loop_link_holds_messages() -> void:
	var r := room(1)
	r[1].link.lag_ms = 60000
	r[0].start()
	settle(r)
	check(not r[1].started, "a minute late, START hasn't come")
