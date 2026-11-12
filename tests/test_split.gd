## Split-screen two player (MP-18): two players on one screen, top and bottom, sharing the
## road, the rivals and the traffic. Two scripted players race to both finishes; player 2's
## controls come from its own device (InputRouter.state2); mode select's 2 PLAYERS races in a
## Single Race or Free Drive.
extends TestSuite

const RaceScript := preload("res://scripts/race/race.gd")


## A split race on `stage`, freed after the test.
func _split(stage := 0, traffic := true, rivals := true, autodrive := false) -> Node:
	var r := race(autodrive, traffic, stage, rivals)
	r.instant_replay = false
	r.players = 2
	r.start_race()
	return r


## Runs `r` with both players driven by a script (the autodrive's line, fed in as each
## player's device would), until `cond` or `limit` ticks; returns the ticks, or -1.
func _race_scripted(r: Node, cond: Callable, limit := 20000) -> int:
	var router: Node = runner.root.get_node("InputRouter")
	var keep: DriveInput = router.state
	var keep2: DriveInput = router.state2
	var ticks := -1
	for i in limit:
		if cond.call():
			ticks = i
			break
		router.state = r._autodrive_input(r.player)
		router.state2 = r._autodrive_input(r.p2)
		r._physics_process(DT)
	router.state = keep
	router.state2 = keep2
	return ticks


func _after() -> void:
	InputRouter.split = false  # (a race freed outside the tree doesn't leave the tree to say so)


func test_halves_and_the_split_camera() -> void:
	eq(SplitScreen.half_rect(0), Rect2(0, 0, 640, 180), "P1: the top half")
	eq(SplitScreen.half_rect(1), Rect2(0, 180, 640, 180), "P2: the bottom half")
	eq(SplitScreen.crop_top() + SplitScreen.HORIZON, float(Cfg.HORIZON_Y), "the horizon cropped to its row in the half")
	check(SplitScreen.car_fits(Tuning.v("camera/depth")), "the car fits its half")
	check(SplitScreen.car_fits(RaceScript.camera_depth(Tuning.v("camera/nitro_fov_stretch"))), "and with the nitro stretch")
	var base := CameraView.car_base(CameraView.SPLIT, Tuning.v("camera/depth")).y - SplitScreen.crop_top()
	check(base > SplitScreen.HORIZON + 60.0, "the car well below the horizon (%.0f)" % base)
	check(CameraView.car_width(CameraView.SPLIT, Tuning.v("camera/depth")) < CameraView.car_width(CameraView.View.CHASE_NEAR, Tuning.v("camera/depth")),
		"further back than the near chase")
	eq(CameraView.name_of(CameraView.SPLIT), "SPLIT", "named")
	check(CameraView.SPLIT >= CameraView.View.size(), "not one of the views the VIEW button steps through")


func test_second_car_is_the_next_one_open() -> void:
	var first: String = Cars.LIST[0]["id"]
	eq(SplitScreen.second_car(first, func(_id: String) -> bool: return true), Cars.LIST[1]["id"], "the next car on")
	var last: String = Cars.LIST[Cars.LIST.size() - 1]["id"]
	eq(SplitScreen.second_car(last, func(_id: String) -> bool: return true), first, "round the list")
	eq(SplitScreen.second_car(first, func(id: String) -> bool: return id == Cars.LIST[3]["id"]), Cars.LIST[3]["id"], "skipping locked cars")
	eq(SplitScreen.second_car(first, func(_id: String) -> bool: return false), first, "player 1's own with none other open")


func test_a_split_race_sets_up_two_players() -> void:
	var r := _split()
	check(r.p2 != null, "player 2's car")
	check(r.player is RivalCar, "player 1's car is an extra player car too (the online model)")
	check(r.p2.remote, "player 2 isn't driven by the AI")
	check(r.rivals.cars.has(r.p2), "player 2 in the field")
	eq(r.rivals.cars.size(), Rivals.COUNT + 1, "with the rivals")
	check(r.traffic.cars.size() > 0, "and the traffic")
	eq(r.p2.profile.driver, "P2", "named P2")
	check(r.p2.car_id != r.car_id, "in another car")
	eq(r.p2.distance, r.player.distance, "side by side on the grid")
	check(r.player.x < 0.0 and r.p2.x > 0.0, "P1 left, P2 right")
	check(r.player.slides and r.p2.slides, "both power slide, unlike the rivals")
	eq(r.views.size(), 2, "two halves")
	check(r.views[0].clip_contents and r.views[1].clip_contents, "each clipped to itself")
	eq(r.views[1].position, Vector2(0, 180), "P2's below")
	check(r.road.get_parent().get_parent() == r.views[0], "P1's road in the top half")
	check(r.road2.get_parent().get_parent() == r.views[1], "P2's road in the bottom one")
	eq(r.road.view, CameraView.SPLIT, "P1's split camera")
	eq(r.road2.view, CameraView.SPLIT, "P2's")
	check(r.road2.player == r.p2, "P2's road follows P2")
	check(r.road2.rivals.has(r.player) and not r.road2.rivals.has(r.p2), "and draws P1 among the others")
	check(r.road.rivals.has(r.p2), "P1's road draws P2")
	check(not r.hud.visible and r.split_hud != null, "the compact HUD in place of the full one")
	check(InputRouter.split, "the input router reads player 2 apart")
	check(not r._saves(), "nothing saved from a split race")
	check(not r.replay_offered(), "no instant replay")
	r.start_race()  # a restart: still two halves, a fresh player 2
	eq(r.views.size(), 2, "a restart keeps the halves")
	eq(r.rivals.cars.size(), Rivals.COUNT + 1, "and one player 2")
	_after()


func test_one_player_is_as_ever() -> void:
	var r := race(false, true, 0, true)
	check(r.p2 == null and r.views.is_empty(), "no player 2, no halves")
	check(not (r.player is RivalCar), "the player's own car")
	check(r.hud.visible and r.split_hud == null, "the full HUD")
	eq(r.road.view, Settings.camera_view, "the chosen camera")
	check(not InputRouter.split, "the input router as ever")


func test_two_scripted_players_race_to_both_finishes() -> void:
	var r := _split(0)
	var ticks := _race_scripted(r, func() -> bool: return r.results.visible)
	check(ticks > 0, "the results came up (%d ticks)" % ticks)
	eq(r.state, r.State.FINISHED, "player 1 over the line")
	check(r.p2.finished, "player 2 over the line")
	check(not r.p2_out, "in time")
	check(r.player_finish > 20.0 and r.p2.finish_time > 20.0, "both timed (%.2f, %.2f)" % [r.player_finish, r.p2.finish_time])
	check(r.p2.distance >= r.finish_distance, "player 2 past the finish")
	var field: Array[Dictionary] = ResultsScreen.rows(r.rivals.standings(r.player, r.player_finish), r.player, r.player_finish, r.car_id, true)
	var players := ResultsScreen.split_rows(field)
	eq(players.size(), 2, "the results show both players")
	eq([players[0]["name"], players[1]["name"]], ["P1", "P2"], "P1 and P2")
	near(float(players[1]["time"]), r.p2.finish_time, 0.0001, "P2's time")
	eq(int(players[0]["place"]), r.place, "P1's place")
	eq(int(players[1]["place"]), r.p2_place(), "P2's place")
	check(r.place != r.p2_place(), "in different places")
	_after()


func test_autodriven_split_race_finishes_on_another_stage() -> void:
	var r := _split(2, true, true, true)  # (--autodrive --split: both drive themselves)
	var ticks := run_until(r, func() -> bool: return r.results.visible, 20000)
	check(ticks > 0, "the results came up")
	check(r.state == r.State.FINISHED and r.p2.finished, "both over the line")
	_after()


func test_results_wait_for_player_two() -> void:
	var r := _split(0, false, false)
	drive(r, 200, input(1.0))  # both off the grid (player 2 on its own device)
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))
	eq(r.state, r.State.FINISHED, "player 1 finished")
	check(r.p2_racing(), "player 2 still racing")
	var age_before: float = r.race_time
	drive(r, int(RaceScript.RESULTS_AFTER * 60.0) + 30, input(1.0))
	check(not r.results.visible, "no results while player 2 races")
	check(r.race_time > age_before, "the race clock runs on for player 2")
	var enter := input(1.0)
	enter.confirm_pressed = true
	drive(r, 1, enter)
	check(not r.results.visible and r.state == r.State.FINISHED, "Enter neither brings the results nor restarts")
	r.p2.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))
	check(r.p2.finished, "player 2 over the line")
	near(r.p2.finish_time, r.race_time, 0.02, "at the race clock")
	drive(r, int(RaceScript.RESULTS_AFTER * 60.0) + 5, input(1.0))
	check(r.results.visible, "then the results, a moment after")
	_after()


func test_the_clock_runs_out_on_player_two() -> void:
	var r := _split(0, false, false)
	drive(r, 200, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))
	r.time_left = 0.5
	drive(r, 40, input(1.0))
	check(r.p2_out, "TIME UP for player 2")
	check(not r.p2.finished, "not over the line")
	eq(r.time_left, 0.0, "the clock at nothing")
	drive(r, int(RaceScript.RESULTS_AFTER * 60.0) * 2 + 10, input(1.0))
	check(r.results.visible, "the results")
	var players := ResultsScreen.split_rows(ResultsScreen.rows(r.rivals.standings(r.player, r.player_finish), r.player, r.player_finish, r.car_id, true))
	eq(float(players[1]["time"]), -1.0, "P2 without a time")
	_after()


func test_time_up_for_both() -> void:
	var r := _split(0, false, false)
	drive(r, 200, input(1.0))
	r.time_left = 0.1
	drive(r, 10, input(1.0))
	eq(r.state, r.State.TIME_UP, "TIME UP")
	check(r.p2_out, "for player 2 as well")
	_after()


func test_checkpoints_go_by_the_leader() -> void:
	var r := _split(0, false, false)
	drive(r, 200, input(1.0))
	var before: float = r.time_left
	r.p2.distance = r.checkpoint_distances[0] + 1.0
	drive(r, 1, input(1.0))
	eq(r.next_checkpoint, 1, "player 2 out in front passed the checkpoint")
	check(r.time_left > before, "the shared clock extended")
	_after()


func test_player_two_drives_on_its_own_controls() -> void:
	var r := _split(0, false, false)
	var router: Node = runner.root.get_node("InputRouter")
	var keep: DriveInput = router.state2
	router.state2 = input(1.0, 0.0)
	drive(r, 300, input(0.0))  # player 1 hands off
	check(r.p2.speed > Cfg.MAX_SPEED * 0.3, "player 2 on the gas")
	check(r.player.speed < r.p2.speed * 0.5, "player 1 coasting, well behind")
	router.state2 = input(1.0, 1.0)
	var x: float = r.p2.x
	drive(r, 20, input(0.0))
	check(r.p2.x > x, "player 2 steers right")
	var pause := input(0.0)
	router.state2 = DriveInput.new()
	router.state2.pause_pressed = true
	drive(r, 1, pause)
	check(r.paused, "player 2's pause pauses the race")
	router.state2 = keep
	_after()


func test_split_free_drive() -> void:
	var r := race(false, false, 0, true)
	r.free_drive = true
	r.players = 2
	r.start_race()
	eq(r.rivals.cars.size(), 1, "no rivals: only player 2")
	_race_scripted(r, func() -> bool: return false, 600)
	check(r.p2.speed > 0.0 and r.player.speed > 0.0, "both driving")
	r.p2.distance = r.finish_distance + 10.0
	_race_scripted(r, func() -> bool: return false, 5)
	check(not r.p2.finished and r.p2_racing(), "no finish: the road goes on")
	_after()


func test_split_hud_lines() -> void:
	var r := _split(0, false, true)
	var l := SplitHud.lines(r, 0)
	eq(l["tag"], "P1", "P1's tag")
	eq(l["banner"], "3", "the countdown")
	eq(SplitHud.lines(r, 1)["tag"], "P2", "P2's tag")
	eq(l["place"], "%s/%d" % [Rivals.ordinal(r.place), Rivals.COUNT + 2], "the place in the whole field")
	eq(l["time"], str(ceili(r.time_left)), "the shared clock")
	drive(r, 300, input(1.0))
	check(String(SplitHud.lines(r, 1)["speed"]).begins_with(str(Settings.speedometer(r.p2.speed)[0])), "P2's own speed")
	r.p2.distance = r.finish_distance + 1.0
	drive(r, 1, input(1.0))
	var l2 := SplitHud.lines(r, 1)
	eq(l2["banner"], "FINISH", "P2's finish in P2's half")
	eq(l2["sub"], Rivals.ordinal(r.p2_place()), "with its place")
	eq(SplitHud.lines(r, 0)["banner"], "", "not in P1's")
	_after()


func test_input_router_split_reading() -> void:
	eq(InputRouter.split_pad_of([]), -1, "no joypads: player 2 on the keyboard")
	eq(InputRouter.split_pad_of([0]), -1, "one: player 1's, player 2 on the keyboard")
	eq(InputRouter.split_pad_of([0, 1]), 1, "two: the second is player 2's")
	eq(InputRouter.split_pad_of([0, 3, 4]), 3, "the second connected, whatever its id")
	var held := {KEY_W: true, KEY_A: true, KEY_TAB: true}
	var k := InputRouter.split_keys(func(code: int) -> bool: return held.get(code, false))
	eq([k["steer"], k["throttle"], k["brake"], k["nitro"]], [-1.0, 1.0, 0.0, true], "WASD and Tab")
	held = {KEY_UP: true, KEY_RIGHT: true, KEY_SPACE: true}
	k = InputRouter.split_keys(func(code: int) -> bool: return held.get(code, false))
	eq([k["steer"], k["throttle"], k["nitro"]], [0.0, 0.0, false], "player 1's keys aren't player 2's")
	check(InputRouter.split_key(KEY_W) and InputRouter.split_key(KEY_TAB), "W and Tab are player 2's")
	check(not InputRouter.split_key(KEY_UP) and not InputRouter.split_key(KEY_SPACE), "the arrows and Space stay player 1's")
	var keep: DriveInput = InputRouter.state2
	InputRouter.state2 = DriveInput.new()
	InputRouter.drive_split({"steer": 0.5, "throttle": 1.0, "brake": 0.0, "nitro": true, "pause": false})
	check(InputRouter.state2.nitro_pressed, "nitro pressed on the tick it goes down")
	eq(InputRouter.state2.steer, 0.5, "the steering")
	InputRouter.drive_split({"steer": 0.5, "throttle": 1.0, "brake": 0.0, "nitro": true, "pause": false})
	check(not InputRouter.state2.nitro_pressed, "not while held")
	InputRouter.drive_split({"steer": 0.0, "throttle": 0.0, "brake": 0.0, "nitro": false, "pause": false})
	InputRouter.state2 = keep


func test_two_players_on_mode_select() -> void:
	var m := ModeSelect.new()
	m.index = ModeSelect.Item.TWO_PLAYERS
	eq(m.pick(), ModeSelect.Item.TWO_PLAYERS, "2 PLAYERS can be picked")
	eq(ModeSelect.LABELS[ModeSelect.Item.TWO_PLAYERS], "2 PLAYERS", "labelled")
	eq(ModeSelect.step_two_player(ModeSelect.Item.SINGLE_RACE, 1), ModeSelect.Item.FREE_DRIVE, "down: Free Drive")
	eq(ModeSelect.step_two_player(ModeSelect.Item.FREE_DRIVE, 1), ModeSelect.Item.SINGLE_RACE, "and round")
	eq(ModeSelect.step_two_player(ModeSelect.Item.SINGLE_RACE, -1), ModeSelect.Item.FREE_DRIVE, "up the same")
	check(ModeSelect.two_player_line(ModeSelect.Item.SINGLE_RACE).contains("FREE DRIVE"), "the help line names the other")
	m.free()


func test_two_players_from_the_menus() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.choose_two_players(ModeSelect.Item.FREE_DRIVE)
	eq(g.players, 2, "two players")
	eq(g.mode_index, ModeSelect.Item.FREE_DRIVE, "in Free Drive")
	eq(g.screen, g.Screen.STAGES, "on to stage select")
	g.start_race()
	eq(g.race.players, 2, "the race is split")
	check(g.race.free_drive, "a Free Drive")
	TestSuite.ready_all(g.race)
	check(g.race.p2 != null, "with player 2")
	g.race.quit_requested.emit()
	g.show_mode_select()
	eq(g.menu.index, ModeSelect.Item.TWO_PLAYERS, "mode select opens on 2 PLAYERS")
	eq(g.menu.two_player_mode, ModeSelect.Item.FREE_DRIVE, "in Free Drive")
	g.choose_two_players(ModeSelect.Item.SINGLE_RACE)
	g.start_race()
	check(g.race.players == 2 and not g.race.tour and not g.race.free_drive, "a split Single Race")
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()
	g.choose_mode(ModeSelect.Item.GRAND_TOUR)
	eq(g.players, 1, "any other mode: one player")
	g.start_race()
	eq(g.race.players, 1, "the tour is one player's")
	TestSuite.ready_all(g.race)
	g.race.quit_requested.emit()
	_after()
