## Online after the line (ON-10): a player who has finished watches the leader of those still
## racing, with live standings, until the last car is in.
extends TestSuite


## Two (or more) races, one per game in a room on an in-memory relay, through the GO and the
## countdown: [sessions, races].
func racing(guests := 1) -> Array:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var sessions: Array = [OnlineSession.hosting_on(h, "car_vega")]
	for i in guests:
		var g := LoopLink.new(relay)
		g.join(h.room)
		sessions.append(OnlineSession.joining_on(g, ["car_mesa", "car_kestrel", "car_bruiser"][i]))
	settle(sessions)
	sessions[0].start()
	settle(sessions)
	var races: Array = []
	for s: OnlineSession in sessions:
		var rc := race(false, false, 0, false)
		rc.online = s
		rc.start_race()
		races.append(rc)
	settle(sessions)
	tick(sessions, races, 200)
	return [sessions, races]


static func settle(sessions: Array, dt := 0.0) -> void:
	for i in 4:
		for s: OnlineSession in sessions:
			s.poll(dt if i == 0 else 0.0)


func tick(sessions: Array, races: Array, n: int) -> void:
	for i in n:
		for rc: Node in races:
			drive(rc, 1, input(1.0))
		settle(sessions, DT)


func test_watch_target_is_the_leader_still_racing() -> void:
	var a := RivalCar.remote_player(Cars.find("car_mesa"), 1)
	var b := RivalCar.remote_player(Cars.find("car_kestrel"), 2)
	var c := RivalCar.remote_player(Cars.find("car_bruiser"), 3)
	a.distance = 5000.0
	b.distance = 9000.0
	c.distance = 12000.0
	c.finished = true
	eq(RaceScript.watch_target([a, b, c]), b, "the furthest of those still out, not one in")
	var ai := RivalCar.new()
	ai.distance = 20000.0
	eq(RaceScript.watch_target([a, ai]), a, "only other players")
	b.finished = true
	a.finished = true
	eq(RaceScript.watch_target([a, b, c]), null, "nobody left out")


const RaceScript := preload("res://scripts/race/race.gd")


func test_after_the_finish_the_camera_follows_the_one_still_racing() -> void:
	var got := racing(1)
	var sessions: Array = got[0]
	var races: Array = got[1]
	var mine: Node = races[0]
	check(mine.state == mine.State.RACING, "racing")
	eq(mine.road.player, mine.player, "the camera on its own car while racing")
	mine.player.distance = mine.finish_distance + 1.0
	tick(sessions, races, 2)
	eq(mine.state, mine.State.FINISHED, "P1 over the line")
	var p2: RivalCar = mine.rivals.cars[0]
	eq(mine.watching, p2, "watching P2, still racing")
	eq(mine.road.player, p2, "the renderer draws it where the player's car goes")
	eq(mine.road.player_strips, p2.strips, "in its own car")
	check(not mine.road.rivals.has(p2), "and not twice")
	near(mine.road.camera_z, p2.position, 0.001, "the camera behind it")
	tick(sessions, races, int(mine.RESULTS_AFTER * 60.0) + 30)
	check(not mine.results.visible, "no results while someone's still out")
	check(mine.hud.watching_shown(), "the live standings instead")
	var rows := Hud.watch_rows(mine)
	eq(rows[0]["you"], true, "P1 first, in")
	eq(rows[1]["time"], -1.0, "P2 RACING")
	near(mine.road.camera_z, p2.position, 0.001, "still following it")
	races[1].player.distance = races[1].finish_distance + 1.0
	tick(sessions, races, 3)
	eq(mine.watching, null, "P2 in: nobody left to watch")
	eq(mine.road.player, mine.player, "the camera back on P1")
	check(mine.results.visible, "and the results come up")


func test_no_watching_offline_or_before_the_finish() -> void:
	var got := racing(1)
	var races: Array = got[1]
	eq(races[0].watching, null, "racing: its own car")
	var offline := race(false, false, 0, true)
	drive(offline, 200, input(1.0))
	offline.player.distance = offline.finish_distance + 1.0
	drive(offline, 3, input(1.0))
	eq(offline.state, offline.State.FINISHED, "an offline finish")
	eq(offline.watching, null, "no watching the AI rivals")
	eq(offline.road.player, offline.player, "its own car")
