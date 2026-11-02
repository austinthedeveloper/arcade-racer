## The instant replay (RC-17): the last six seconds before the finish, from a trace of every
## car, shown once between the finish spectacle and the results; any button skips it.
extends TestSuite


## A race run to its finish line: autodriven with traffic and rivals, put a little way
## short of the line after GO so the trace has more than the replay's six seconds in it.
func _finished_race() -> Node:
	var r := race(true, true, 0, true)
	drive(r, 200)
	r.player.distance = r.finish_distance - 60000.0
	r.player.position = fposmod(r.player.distance, r.track.length)
	run_until(r, func() -> bool: return r.state != r.State.RACING, 3000)
	r.set("_autodrive", false)  # (the player's input from here, for the presses)
	return r


func test_build_cuts_the_last_seconds_and_ends_on_the_last_frame() -> void:
	var trace: Array[PackedFloat32Array] = []
	for i in 500:
		trace.append(PackedFloat32Array([float(i)]))
	var cut := Replay.build(trace, 6.0, 60)
	eq(cut.size(), 360, "six seconds at 60 ticks a second")
	eq([cut[0][0], cut[-1][0]], [140.0, 499.0], "the last of them, ending on the last frame")
	eq(Replay.build(trace.slice(0, 100), 6.0, 60).size(), 100, "a shorter trace: all of it")
	eq(Replay.build([] as Array[PackedFloat32Array]).size(), 0, "nothing recorded: nothing to show")


func test_the_trace_keeps_only_the_replay() -> void:
	var rec := Replay.new()
	var car := PlayerCar.new()
	for i in Replay.KEEP + 50:
		car.distance = float(i)
		rec.record([car], [])
	eq(rec.frames.size(), Replay.KEEP, "no more than the replay's frames")
	eq(Replay.racer(rec.frames[0], 0)[CarState.DISTANCE], 50.0, "the oldest dropped")


func test_the_replay_ends_on_the_finish_frame() -> void:
	var r := _finished_race()
	eq(r.state, r.State.FINISHED, "the race finished")
	var trace: Array[PackedFloat32Array] = r.replay_trace.frames
	eq(trace.size(), Replay.KEEP, "six seconds of the field recorded")
	eq(r.replay_trace.racers, r.rivals.cars.size() + 1, "every racer")
	eq(r.replay_trace.traffic_cars, r.traffic.cars.size(), "and the traffic")
	var last: float = Replay.racer(trace[-1], 0)[CarState.DISTANCE]
	var before: float = Replay.racer(trace[-2], 0)[CarState.DISTANCE]
	check(last >= r.finish_distance and before < r.finish_distance, "the trace ends on the tick the line was crossed")
	var frames := Replay.build(trace)
	eq(frames[-1], trace[-1], "the replay's last frame is the finish frame")

	run_until(r, func() -> bool: return r.replaying, 600)
	check(r.replaying and not r.results.visible, "after the finish spectacle, the replay")
	check(r.road.player == r.replay_player and r.road.player != r.player, "the road draws the replay's cars")
	near(r.replay_player.distance, Replay.racer(trace[0], 0)[CarState.DISTANCE], 0.01, "from six seconds back")
	var shown := 0
	var last_distance := 0.0
	while r.replaying and shown < 1000:
		last_distance = r.replay_player.distance
		drive(r, 1)
		shown += 1
	eq(shown, Replay.KEEP, "it runs its six seconds")
	near(last_distance, last, 0.01, "and ends on the finish frame")
	check(r.results.visible, "then the results")
	check(r.road.player == r.player and r.road.rivals == r.rivals.cars, "the race's own cars back on the road")
	run_until(r, func() -> bool: return r.replaying, 400)
	check(not r.replaying, "it replays once")


func test_any_button_skips_it_and_the_road_is_put_back() -> void:
	var r := _finished_race()
	var traffic_z: Array[float] = []
	run_until(r, func() -> bool: return r.replaying, 600)
	check(r.replaying, "replaying")
	# (the traffic as the finish left it, read back off the replay's saved copy)
	for i in r.traffic.cars.size():
		traffic_z.append(r._traffic_before[i * 2])
	drive(r, 30)
	check(r.replaying, "a foot left on the gas doesn't skip it")
	var nitro := input(1.0)
	nitro.nitro_pressed = true
	drive(r, 1, nitro)
	check(not r.replaying and r.results.visible, "a button does: on to the results")
	var now: Array[float] = []
	for car: Traffic.TrafficCar in r.traffic.cars:
		now.append(car.z)
		check(car.segment.cars.has(car), "every traffic car in its own segment's list")
	eq(now, traffic_z, "the traffic back where the finish left it")
	near(r.road.camera_z, r.player.position, 0.01, "the camera on the player again")


func test_a_key_skips_it_too() -> void:
	var r := _finished_race()
	run_until(r, func() -> bool: return r.replaying, 600)
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	r._input(key)
	drive(r, 1)
	check(not r.replaying and r.results.visible, "a key the game doesn't use skips it")


func test_enter_in_the_spectacle_goes_straight_to_the_results() -> void:
	var r := _finished_race()
	var c := input()
	c.confirm_pressed = true
	drive(r, 1, c)
	check(r.results.visible and not r.replaying, "no replay: Enter asked for the results")


func test_no_replay_in_a_demo_or_free_drive() -> void:
	var r := race(true, false, 0, false)
	check(r.replay_offered(), "a race offers it")
	r.demo = true
	check(not r.replay_offered(), "a demo doesn't")
	r.demo = false
	r.free_drive = true
	check(not r.replay_offered(), "nor Free Drive")
	r.free_drive = false
	r.instant_replay = false
	check(not r.replay_offered(), "nor a race with it turned off")


func test_hud_replay_bar() -> void:
	eq(Hud.replay_share(0, 360), 0.0, "start")
	eq(Hud.replay_share(180, 360), 0.5, "halfway")
	eq(Hud.replay_share(400, 360), 1.0, "clamped")
	eq(Hud.replay_share(0, 0), 1.0, "nothing to show")
