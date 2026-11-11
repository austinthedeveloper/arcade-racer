## Online (ON-1 to ON-3): rooms over the in-memory relay (LoopLink), the lobby, a race
## between the games, leaving, and the online screen's letter grid.
extends TestSuite


## A host and `guests` guests in one room on an in-memory relay, polled until settled.
func room(guests := 2, cars := ["car_vega", "car_mesa", "car_kestrel", "car_bruiser"]) -> Array:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var out: Array = [OnlineSession.hosting_on(h, cars[0])]
	for i in guests:
		var g := LoopLink.new(relay)
		g.join(h.room)
		out.append(OnlineSession.joining_on(g, cars[i + 1]))
	settle(out)
	return out


## Polls every game a few times, so messages go there and back.
static func settle(sessions: Array, dt := 0.0) -> void:
	for i in 4:
		for s: OnlineSession in sessions:
			s.poll(dt if i == 0 else 0.0)


func test_room_codes_are_cleaned() -> void:
	eq(RelayLink.clean_room("bx-km!"), "BXKM", "capitals from the alphabet")
	eq(RelayLink.clean_room("ioaBXKMZ"), "BXKM", "no vowels, at most four")
	var l := RelayLink.new()
	check(not l.join("BX"), "two letters aren't a room")
	eq(l.error, "A ROOM IS 4 LETTERS", "and it says so")
	eq(RelayLink.GAME, "sundown-run", "the relay's game")


func test_lobby_lists_everyone_with_their_car() -> void:
	var r := room()
	var h: OnlineSession = r[0]
	for s: OnlineSession in r:
		eq(s.phase, OnlineSession.Phase.LOBBY, "in the lobby")
		eq(s.players, {0: "car_vega", 1: "car_mesa", 2: "car_kestrel"}, "everyone and their car")
	eq([r[0].slot, r[1].slot, r[2].slot], [0, 1, 2], "slots: the host first")
	h.choose(3, false)
	settle(r)
	eq(r[2].stage, 3, "the host's stage reaches the guests")


func test_a_fifth_player_is_turned_away() -> void:
	var r := room(3)
	var g := LoopLink.new(r[0].link.relay)
	g.join(r[0].link.room)
	var s := OnlineSession.joining_on(g, "car_vega")
	s.poll(0.0)
	eq(s.phase, OnlineSession.Phase.CLOSED, "closed")
	eq(s.error, "THAT ROOM IS FULL", "full")


func test_a_guest_says_hello_once_while_the_lobby_is_on_its_way() -> void:
	# Over the live relay the lobby takes a round trip to come back; a guest polling every
	# frame meanwhile once sent a HELLO each time, and the relay cut it off (TOO FAST).
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var host := OnlineSession.hosting_on(h, "car_vega")
	host.poll(0.0)
	var g := LoopLink.new(relay)
	g.join(h.room)
	var guest := OnlineSession.joining_on(g, "car_mesa")
	for i in 50:
		guest.poll(1.0 / 60.0)
	var hellos := h._inbox.filter(func(m: Array) -> bool: return m[1][0] == OnlineSession.HELLO)
	eq(hellos.size(), 1, "one HELLO, not one a frame")
	settle([host, guest])
	eq(guest.phase, OnlineSession.Phase.LOBBY, "and the guest is in the lobby")
	eq(host.players, {0: "car_vega", 1: "car_mesa"}, "with its car")


func test_a_wrong_room_and_an_old_version_are_refused() -> void:
	var relay := LoopLink.Relay.new()
	var g := LoopLink.new(relay)
	g.join("ZZZZ")
	var s := OnlineSession.joining_on(g, "car_vega")
	s.poll(0.0)
	eq(s.error, "NO SUCH ROOM", "no such room")
	var h := LoopLink.new(relay)
	h.host("0.0.1")
	var host_room := OnlineSession.hosting_on(h, "car_vega")
	var g2 := LoopLink.new(relay)
	g2.join(h.room)
	var guest := OnlineSession.joining_on(g2, "car_mesa")
	settle([host_room, guest])
	check(guest.error.begins_with("OLD VERSION"), "the guest sees the host's version differs: " + guest.error)
	eq(host_room.players.size(), 1, "and isn't in the room")


func test_start_waits_for_every_game_then_goes() -> void:
	var r := room()
	var h: OnlineSession = r[0]
	h.choose(2, false)
	h.start()
	settle(r)
	for s: OnlineSession in r:
		check(s.started, "everyone's game opens the race")
		eq(s.stage, 2, "on the host's stage")
		check(not s.go, "no GO before every game has the stage")
		eq(s.racers, [0, 1, 2], "with everyone")
	r[0].loaded()
	r[1].loaded()
	settle(r)
	check(not h.go, "still waiting on one")
	r[2].loaded()
	settle(r)
	for s: OnlineSession in r:
		check(s.go, "GO once all three are in")
		eq(s.phase, OnlineSession.Phase.RACING, "racing")


func test_a_game_that_never_loads_is_waited_for_only_so_long() -> void:
	var r := room(1)
	r[0].start()
	settle(r)
	r[0].loaded()
	settle(r, OnlineSession.READY_WAIT / 2.0)
	check(not r[0].go, "waiting on the guest")
	settle(r, OnlineSession.READY_WAIT / 2.0)
	check(r[0].go and r[1].go, "GO after READY_WAIT")


func test_cars_reach_the_other_guests_through_the_host() -> void:
	var r := room()
	r[0].start()
	settle(r)
	var p := PlayerCar.new()
	p.distance = 1234.0
	p.x = 0.5
	p.speed = 3000.0
	for i in OnlineSession.SEND_EVERY:
		r[1].send_car(p)  # P2's car
	settle(r)
	check(r[0].cars.has(1) and r[2].cars.has(1), "the host and P3 both have P2's car")
	eq(r[2].cars[1][0][CarState.DISTANCE], 1234.0, "where it is")
	check(not r[1].cars.has(1), "P2 doesn't get its own back")
	r[1].finish(61.5)
	settle(r)
	eq(r[2].finishes.get(1), 61.5, "a finish reaches everyone")


func test_shown_moves_on_at_the_cars_speed_and_eases() -> void:
	var state := [1000.0, 0.2, 0.0, 600.0, 0.0, false, false]
	var at := OnlineSession.shown_at(state, 0.1, Vector3(1000.0, 0.0, 0.0), DT)
	check(at.x > 1000.0 and at.x < 1060.0, "eased toward where it is by now: %f" % at.x)
	check(at.y > 0.0 and at.y < 0.2, "and across")
	var far := OnlineSession.shown_at(state, 5.0, Vector3(1000.0, 0.0, 0.0), DT)
	near(far.x, 1000.0 + 600.0 * OnlineSession.EXTRAPOLATE_MAX, 200.0, "moved on no more than EXTRAPOLATE_MAX")
	var jump := OnlineSession.shown_at(state, 0.0, Vector3(9000.0, 0.0, 0.0), DT)
	eq(jump.x, 1000.0, "further than SNAP: jumps")


func test_a_guest_leaving_drops_off_everyones_road() -> void:
	var r := room()
	r[0].start()
	settle(r)
	r[1].leave()
	settle(r)
	eq(r[0].players.keys(), [0, 2], "gone from the host's room")
	check(r[0].gone.has(1) and r[2].gone.has(1), "and from the race on every game")


func test_the_host_leaving_closes_the_room() -> void:
	var r := room()
	r[0].leave()
	settle(r)
	eq(r[1].phase, OnlineSession.Phase.CLOSED, "closed")
	eq(r[1].error, "THE HOST LEFT", "says why")


## Two races, one per game, side by side over the room: each draws the other, both finish,
## both have both finishes.
func test_two_games_race_to_the_finish() -> void:
	var r := room(1)
	var races: Array = []
	for s: OnlineSession in r:
		var rc := TestSuite.new_race(false, false, 0, false)
		rc.online = s
		_nodes.append(rc)
		races.append(rc)
	r[0].start()
	settle(r)
	for rc: Node in races:
		rc.start_race()
		eq(rc.rivals.cars.size(), 1, "the other player, no AI rivals")
		check(rc.rivals.cars[0].remote, "moved by its game")
		check(not rc.timed(), "no clock online")
	settle(r)
	ne_x(races)
	check(r[0].go and r[1].go, "GO once both games have the stage")
	for i in 400:
		for rc: Node in races:
			drive(rc, 1, input(1.0))
		settle(r, DT)
	check(races[0].state == races[0].State.RACING, "racing after the GO and the countdown")
	var other: RivalCar = races[0].rivals.cars[0]
	near(other.distance, races[1].player.distance, 400.0, "P2 shows where P2's game has it")
	# Both over the line
	for rc: Node in races:
		rc.player.distance = rc.finish_distance + 1.0
	for i in 10:
		for rc: Node in races:
			drive(rc, 1, input(1.0))
		settle(r, DT)
	for rc: Node in races:
		eq(rc.state, rc.State.FINISHED, "finished")
		check(rc.rivals.cars[0].finished, "and the other's finish came in")
		eq(rc.results.choices(false, false, true), [ResultsScreen.Choice.CONTINUE, ResultsScreen.Choice.QUIT], "lobby or quit")


## The two racers start abreast, not on top of each other.
func ne_x(races: Array) -> void:
	check(absf(races[0].player.x - races[1].player.x) > 0.4, "abreast on the grid")
	near(races[0].rivals.cars[0].x, races[1].player.x, 0.001, "each sees the other in its slot")


func test_the_pause_menu_doesnt_stop_an_online_race() -> void:
	var r := room(1)
	var rc := TestSuite.new_race(false, false, 0, false)
	rc.online = r[0]
	_nodes.append(rc)
	r[0].start()
	settle(r)
	rc.start_race()
	r[1].loaded()
	settle(r)
	drive(rc, 300, input(1.0))
	rc.pause()
	var t0: float = rc.race_time
	drive(rc, 30)
	check(rc.race_time > t0, "the race clock runs on")
	check(not rc.restart(), "no restart online")


func test_letter_grid_moves_and_wraps() -> void:
	eq(OnlineScreen.grid_move(0, 1, 0), 1, "right")
	eq(OnlineScreen.grid_move(4, 1, 0), 0, "wraps along a row")
	eq(OnlineScreen.grid_move(2, 0, -1), OnlineScreen.DEL, "up from the top row: DEL")
	eq(OnlineScreen.grid_move(19, 0, 1), OnlineScreen.GO, "down from the last column: JOIN")
	eq(OnlineScreen.grid_move(OnlineScreen.DEL, 1, 0), OnlineScreen.GO, "DEL to JOIN")
	eq(OnlineScreen.grid_move(OnlineScreen.GO, 0, 1), 4, "down from JOIN: the top row's end")
	eq(OnlineScreen.letter(0) + OnlineScreen.letter(19), "BZ", "the alphabet in order")


func test_typing_a_room() -> void:
	var o := OnlineScreen.new()
	for c in "bxaKMQ":
		o.type_letter(c)
	eq(o.code, "BXKM", "four letters, no vowels")
	eq(o.cell, OnlineScreen.GO, "the cursor on JOIN")
	o.delete_letter()
	eq(o.code, "BXK", "deleted")
	o.free()


func test_the_game_goes_from_join_to_a_race() -> void:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var host_room := OnlineSession.hosting_on(h, "car_vega")
	host_room.poll(0.0)
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()  # outside the tree, as test_menus does
	_nodes.append(g)
	g.make_link = func() -> NetLink: return LoopLink.new(relay)
	g.mode_index = ModeSelect.Item.ONLINE
	g.start_race()
	check(g.menu is OnlineScreen, "car select leads to the online screen")
	var o: OnlineScreen = g.menu
	o.code = h.room
	o.join()
	for i in 4:
		g._physics_process(DT)
		host_room.poll(0.0)
	eq(o.current(), OnlineScreen.View.LOBBY, "in the lobby")
	eq(host_room.players.size(), 2, "the host sees the guest")
	host_room.start()
	g._physics_process(DT)
	check(g.race != null and g.race.online == g.online, "the guest's game is racing online")
	g.leave_room()
	host_room.poll(0.0)
	eq(host_room.players.size(), 1, "leaving tells the host")


func test_online_flags_put_two_games_in_a_race() -> void:
	# --online=host and --online=join:CODE (game.online_from_flags), for two windows hands-off
	var relay := LoopLink.Relay.new()
	var games: Array = []
	for i in 2:
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g._ready()
		_nodes.append(g)
		g.make_link = func() -> NetLink: return LoopLink.new(relay)
		g.on_quit = func() -> void: pass
		games.append(g)
	games[0].stage_index = 2
	games[0].online_from_flags("host", 2)
	eq(games[0].auto_online, "host", "hosting")
	games[1].online_from_flags("join:" + games[0].online.link.room)
	for i in 6:
		for g: Node in games:
			g._physics_process(DT)
	for g: Node in games:
		check(g.race != null and g.race.online == g.online, "both games racing online")
		eq(g.online.stage, 2, "on the host's stage")
	eq(games[1].online.slot, 1, "the guest second on the grid")


## The host leaving mid-race (ON-11) ends the race on the guest's game with the results so far:
## the host's car held where it was last seen, ahead of the guest, and the guest OUT.
func test_the_host_leaving_mid_race_ends_it_with_the_results_so_far() -> void:
	var r := room(1)
	var rc := TestSuite.new_race(false, false, 0, false)
	rc.online = r[1]
	_nodes.append(rc)
	r[0].start()
	settle(r)
	rc.start_race()
	r[0].loaded()
	settle(r)
	drive(rc, 240, input(1.0))
	eq(rc.rivals.cars.size(), 1, "the host on the road")
	var host_car := PlayerCar.new()
	host_car.distance = rc.player.distance + 3000.0
	host_car.speed = 3000.0
	for i in OnlineSession.SEND_EVERY:
		r[0].send_car(host_car)
	settle(r)
	drive(rc, 2, input(1.0))
	r[0].leave()
	settle(r)
	drive(rc, 2, input(1.0))
	check(rc.cut_short, "cut short")
	eq(rc.state, rc.State.FINISHED, "the race is over")
	eq(rc.banner, "THE HOST LEFT", "and it says so")
	eq(rc.notice, "THE HOST LEFT", "on the notice too")
	eq(rc.rivals.cars.size(), 1, "the host's car stays, for the standings")
	var held: float = rc.rivals.cars[0].distance
	eq(rc.place, 2, "behind the host, where they were")
	drive(rc, int(rc.CUT_SHORT_RESULTS * 60.0) + 5, input(1.0))
	check(rc.results.visible, "the results so far come up")
	eq(rc.rivals.cars[0].distance, held, "the host's car held where it was")
	eq(ResultsScreen.online_label(r[1]), "BACK", "back to the online screen, which says why")
	var rows := ResultsScreen.rows(rc.rivals.standings(rc.player, rc.player_finish), rc.player, rc.player_finish, rc.car_id)
	eq([rows[0]["name"], rows[1]["name"]], ["P1", "YOU"], "the standings so far")


## A guest dropping out (ON-11): a notice on everyone else's game, and the car fades off the
## road rather than vanishing; it doesn't touch anyone meanwhile.
func test_a_player_dropping_out_fades_off_the_road_with_a_notice() -> void:
	var r := room(2)
	var races: Array = []
	for i in [0, 2]:
		var rc := TestSuite.new_race(false, false, 0, false)
		rc.online = r[i]
		_nodes.append(rc)
		races.append(rc)
	r[0].start()
	settle(r)
	for rc: Node in races:
		rc.start_race()
	r[1].loaded()
	settle(r)
	for i in 240:
		for rc: Node in races:
			drive(rc, 1, input(1.0))
		settle(r, DT)
	var host_race: Node = races[0]
	eq(host_race.rivals.cars.size(), 2, "P2 and P3 on the host's road")
	r[1].leave()
	settle(r)
	for rc: Node in races:
		drive(rc, 1, input(1.0))
		var p2: RivalCar = rc.rivals.cars.filter(func(c: RivalCar) -> bool: return c.slot == 1)[0]
		eq(rc.notice, "P2 DROPPED OUT", "the notice")
		check(rc.notice_time > 0.0, "up")
		check(p2.fade < 1.0 and p2.fade > 0.0, "P2 fading: %f" % p2.fade)
		check(not rc.solid_cars().has(p2), "and can't be hit meanwhile")
		check(rc.state == rc.State.RACING and not rc.cut_short, "the race goes on")
	drive(host_race, int(host_race.FADE_TIME * 60.0) + 2, input(1.0))
	eq(host_race.rivals.cars.size(), 1, "faded out and gone")
	drive(host_race, int(host_race.NOTICE_TIME * 60.0), input(1.0))
	eq(host_race.notice_time, 0.0, "the notice gone in time")
	near(Hud.notice_alpha(0.25), 0.5, 0.001, "fading over its last half second")


func test_tapping_letters_types_a_room() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.show_online()
	var o: OnlineScreen = g.menu
	o.tap(OnlineScreen.choice_rect(1).get_center())
	eq(o.current(), OnlineScreen.View.CODE, "tapping JOIN opens the grid")
	for i in [1, 18, 8, 9]:  # C X L M
		o.tap(OnlineScreen.grid_rect(i).get_center())
	eq(o.code, "CXLM", "each tap a letter")
	o.tap(OnlineScreen.grid_rect(OnlineScreen.DEL).get_center())
	eq(o.code, "CXL", "DEL deletes")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = OnlineScreen.grid_rect(0).get_center()
	eq(OnlineScreen.tap_at(t), t.position, "a touch is a tap")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.device = InputEvent.DEVICE_ID_EMULATION
	eq(OnlineScreen.tap_at(click), null, "the touch's own emulated click isn't a second tap")


func test_no_restart_hint_online() -> void:
	check(Hud.keys_hint(false).ends_with("R restart"), "offline: R restarts")
	check(not Hud.keys_hint(true).contains("restart"), "online: restart is off, so no hint")


func test_version_refusals() -> void:
	# ON-14: older than the host (or than the relay takes) is the guest's to update.
	eq(OnlineSession.version_refusal("0.5.2", "0.5.2"), "", "the same version: in")
	eq(OnlineSession.version_refusal("0.5.2", ""), "", "a host version unknown: in")
	eq(OnlineSession.version_refusal("0.5.2", "0.6.0"), "UPDATE TO PLAY ONLINE: THE HOST HAS 0.6.0, YOU HAVE 0.5.2", "older than the host")
	eq(OnlineSession.version_refusal("0.5.10", "0.5.9"), "OLD VERSION: THE HOST HAS 0.5.9, YOU HAVE 0.5.10", "newer: the host's is old (by number, not text)")
	eq(OnlineSession.version_refusal("0.5.2", "0.5.2", "0.6.0"), "UPDATE TO PLAY ONLINE: THE SERVER TAKES 0.6.0 OR LATER, YOU HAVE 0.5.2", "older than the relay takes")
	eq(OnlineSession.version_refusal("0.6.0", "0.6.0", "0.6.0"), "", "the oldest it takes is fine")


func test_an_older_guest_is_told_to_update() -> void:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host("99.0.0")
	var host_room := OnlineSession.hosting_on(h, "car_vega")
	var g := LoopLink.new(relay)
	g.join(h.room)
	var guest := OnlineSession.joining_on(g, "car_mesa")
	settle([host_room, guest])
	check(guest.error.begins_with("UPDATE TO PLAY ONLINE: THE HOST HAS 99.0.0"), "update to play: " + guest.error)
	check(guest.needs_update, "with the updater's button")
	eq(guest.phase, OnlineSession.Phase.CLOSED, "the room closed for it")
	eq(host_room.players.size(), 1, "and it isn't in the room")
	# A newer guest: the host is the old one, no update offered
	var h2 := LoopLink.new(relay)
	h2.host("0.0.1")
	var g2 := LoopLink.new(relay)
	g2.join(h2.room)
	var guest2 := OnlineSession.joining_on(g2, "car_mesa")
	settle([OnlineSession.hosting_on(h2, "car_vega"), guest2])
	check(guest2.error.begins_with("OLD VERSION") and not guest2.needs_update, "a newer guest: " + guest2.error)


func test_the_host_tells_an_older_guest_too() -> void:
	# A guest whose relay welcome named no host version learns it from the host's NOPE.
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var host_room := OnlineSession.hosting_on(h, "car_vega")
	var g := LoopLink.new(relay)
	g.join(h.room, "0.0.1")
	g.host_version = ""
	var guest := OnlineSession.joining_on(g, "car_mesa")
	settle([host_room, guest])
	eq(guest.error, "UPDATE TO PLAY ONLINE: THE HOST HAS %s, YOU HAVE 0.0.1" % Updater.version(), "the host's refusal")
	check(guest.needs_update, "offers the update")


func test_the_oldest_version_the_relay_takes() -> void:
	var relay := LoopLink.Relay.new()
	relay.oldest = "99.0.0"
	var h := LoopLink.new(relay)
	h.host()
	var host_room := OnlineSession.hosting_on(h, "car_vega")
	settle([host_room])
	check(host_room.needs_update and host_room.error.contains("THE SERVER TAKES 99.0.0"), "a host too old: " + host_room.error)
	var fine := room()
	for s: OnlineSession in fine:
		eq([s.error, s.needs_update], ["", false], "no oldest named: in")
	# The relay's own words for it, when it refuses outright, and its welcome's field
	var rl := RelayLink.new()
	rl._control({"op": "error", "reason": "OLD VERSION"})
	check(rl.error.begins_with(OnlineSession.UPDATE_TO_PLAY), "a relay refusal reads as update: " + rl.error)
	rl._control({"op": "welcome", "you": 1, "ver": "0.6.0", "oldest": "0.6.0"})
	eq([rl.host_version, rl.oldest_version], ["0.6.0", "0.6.0"], "the welcome's oldest version read")


func test_the_update_screen_from_the_online_error() -> void:
	eq(OnlineScreen.update_route(Updater.State.FULL, false), "screen", "an exported game: the update screen")
	eq(OnlineScreen.update_route(Updater.State.OFF, true), "reload", "the Web build reloads")
	eq(OnlineScreen.update_route(Updater.State.OFF, false), "page", "a checkout: the releases page")
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.show_online()
	var o: OnlineScreen = g.menu
	o.stage_shot("update")
	eq(o.current(), OnlineScreen.View.ERROR, "refused")
	check(g.online.needs_update, "as too old")
	o.updater = g.staged_updater("full")
	o.tap(OnlineScreen.update_rect().get_center())
	eq(g.screen, g.Screen.UPDATE, "UPDATE opens the update screen")
	eq(g.online, null, "out of the room")
	eq((g.menu as UpdateScreen).choices(), ["page", "play"] as Array[String], "with its own buttons")
