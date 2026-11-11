## The first drive (MP-15): a new profile's first race on Palm Coast prompts gas, steer,
## nitro on a straight, a draft and a power slide, one at a time when the road allows, each
## cleared by doing it; skippable from the pause menu; never again once done or skipped.
## The prompts are stepped from scripted road readings (FirstDrive.look's dictionary), then
## through a race. Always on the scratch save; onboarding back off after.
extends TestSuite


## The road as FirstDrive.look reads it: racing, nothing held, nothing ahead, plus `over`.
static func road(over := {}) -> Dictionary:
	var v := {"racing": true, "throttle": 0.0, "steer": 0.0, "speed": 0.0, "nitro_charges": 3, "nitro": false,
		"draft_boost": false, "sliding": false, "straight": false, "bend": false, "big_ahead": false}
	v.merge(over, true)
	return v


## Ticks `fd` for `seconds` on `v`; returns the steps cleared on the way.
static func run(fd: FirstDrive, seconds: float, v: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i in roundi(seconds / DT):
		var s := fd.tick(DT, v)
		if s >= 0:
			out.append(s)
	return out


func _clean() -> void:
	TestSuite.use_scratch_save(SaveData)
	Tuning.use_defaults()


func test_every_prompt_steps_from_a_scripted_run() -> void:
	var fd := FirstDrive.new()
	run(fd, 0.5, road({"racing": false}))
	eq(fd.current, -1, "nothing before GO")
	run(fd, DT, road())
	eq(fd.current, FirstDrive.Step.GAS, "GO: HOLD THE GAS first")
	eq(fd.number(), 1, "prompt 1")
	eq(run(fd, 0.5, road({"throttle": 1.0})), [] as Array[int], "half a second of gas isn't enough")
	eq(run(fd, 0.6, road({"throttle": 1.0, "speed": 0.3})), [FirstDrive.Step.GAS] as Array[int], "a second of gas clears it")
	eq(fd.current, -1, "a gap before the next")
	run(fd, Tuning.v("first_drive/gap") + DT, road({"throttle": 1.0, "speed": 0.3}))
	eq(fd.current, FirstDrive.Step.STEER, "then STEER, at speed")
	run(fd, 0.3, road({"steer": 0.1, "speed": 0.3}))
	eq(fd.current, FirstDrive.Step.STEER, "a nudge doesn't clear it")
	eq(run(fd, 0.6, road({"steer": -0.8, "speed": 0.3})), [FirstDrive.Step.STEER] as Array[int], "steering does")
	# No straight, no truck, but a bend: the slide goes ahead of the two waiting for their road
	run(fd, Tuning.v("first_drive/gap") + DT, road({"speed": 0.7, "bend": true}))
	eq(fd.current, FirstDrive.Step.SLIDE, "a bend: POWER SLIDE, ahead of nitro and the draft")
	eq(run(fd, DT, road({"speed": 0.7, "bend": true, "sliding": true})), [FirstDrive.Step.SLIDE] as Array[int], "a slide clears it")
	run(fd, Tuning.v("first_drive/gap") + DT, road({"speed": 0.7, "straight": true}))
	eq(fd.current, FirstDrive.Step.NITRO, "a straight: NITRO")
	eq(run(fd, DT, road({"speed": 0.9, "straight": true, "nitro": true, "nitro_charges": 2})), [FirstDrive.Step.NITRO] as Array[int],
		"firing it clears it")
	run(fd, Tuning.v("first_drive/gap") + DT, road({"speed": 0.5, "big_ahead": true, "nitro_charges": 2}))
	eq(fd.current, FirstDrive.Step.DRAFT, "a truck ahead: DRAFT THE TRUCK")
	eq(fd.number(), 5, "the fifth of five")
	check(not fd.done, "not done yet")
	eq(run(fd, DT, road({"speed": 0.5, "draft_boost": true})), [FirstDrive.Step.DRAFT] as Array[int], "the slipstream boost clears it")
	check(fd.done, "every prompt cleared: done")
	eq(fd.cleared, [FirstDrive.Step.GAS, FirstDrive.Step.STEER, FirstDrive.Step.SLIDE, FirstDrive.Step.NITRO, FirstDrive.Step.DRAFT] as Array[int],
		"in the order the road allowed")


func test_a_prompt_whose_moment_passes_goes_back_to_wait() -> void:
	var fd := FirstDrive.new()
	fd.left = [FirstDrive.Step.NITRO, FirstDrive.Step.SLIDE] as Array[int]
	run(fd, DT, road({"speed": 0.6, "straight": true}))
	eq(fd.current, FirstDrive.Step.NITRO, "a straight: NITRO up")
	run(fd, Tuning.v("first_drive/min_show") - 0.2, road({"speed": 0.6}))
	eq(fd.current, FirstDrive.Step.NITRO, "stays up a while after the straight ends")
	run(fd, Tuning.v("first_drive/withdraw") + 0.3, road({"speed": 0.6}))
	eq(fd.current, -1, "then goes back to wait for the next straight")
	check(fd.left.has(FirstDrive.Step.NITRO), "still to come")
	run(fd, Tuning.v("first_drive/gap") + DT, road({"speed": 0.6, "straight": true}))
	eq(fd.current, FirstDrive.Step.NITRO, "and comes back on one")


func test_nitro_all_burned_drops_its_prompt() -> void:
	var fd := FirstDrive.new()
	fd.left = [FirstDrive.Step.NITRO, FirstDrive.Step.SLIDE] as Array[int]
	run(fd, DT, road({"speed": 0.6, "nitro_charges": 0}))
	check(not fd.left.has(FirstDrive.Step.NITRO), "no charges left: no nitro prompt")
	eq(fd.current, -1, "and nothing up off a bend")


func test_the_road_ahead_is_read_from_the_track() -> void:
	var t := TestSuite.flat_track(400)
	check(FirstDrive.straight_ahead(t, 0.0), "a flat track: a straight")
	check(not FirstDrive.bend_ahead(t, 0.0), "and no bend")
	for i in range(100, 140):
		t.segments[i].curve = 4.0
	check(FirstDrive.bend_ahead(t, 90 * Cfg.SEGMENT_LENGTH), "a bend coming up")
	check(not FirstDrive.straight_ahead(t, 90 * Cfg.SEGMENT_LENGTH), "so not a straight")
	check(FirstDrive.straight_ahead(t, 200 * Cfg.SEGMENT_LENGTH), "straight again past it")


func test_how_says_the_binding_for_the_device() -> void:
	var kb := DeviceProfile.keyboard()
	check(FirstDrive.how(FirstDrive.Step.GAS, ControlsCard.Device.KEYBOARD, kb).contains("UP / W"), "keyboard gas: UP / W")
	check(FirstDrive.how(FirstDrive.Step.NITRO, ControlsCard.Device.KEYBOARD, kb).contains("SPACE"), "keyboard nitro: SPACE")
	kb.bind("nitro", KEY_N)
	check(FirstDrive.how(FirstDrive.Step.NITRO, ControlsCard.Device.KEYBOARD, kb).contains("N for"), "rebound: N")
	var pad := DeviceProfile.new()
	check(FirstDrive.how(FirstDrive.Step.NITRO, ControlsCard.Device.GAMEPAD, pad).contains("RB"), "pad nitro: RB")
	check(FirstDrive.how(FirstDrive.Step.GAS, ControlsCard.Device.WHEEL, pad).contains("pedal"), "wheel: the pedal")
	for s in FirstDrive.Step.size():
		for d in ControlsCard.Device.size():
			check(UiText.width(FirstDrive.how(s, d, ControlsCard.profile_for(d)), 9) < Hud.FIRST_DRIVE_SIZE.x - 8,
				"step %d on device %d fits the prompt" % [s, d])


func test_only_a_new_profile_on_palm_coast_gets_it() -> void:
	_clean()
	check(FirstDrive.wanted(0, SaveData), "a new profile on Palm Coast")
	check(not FirstDrive.wanted(1, SaveData), "not on another stage")
	SaveData.end_first_drive(false)
	check(not FirstDrive.wanted(0, SaveData), "done: never again")
	SaveData.load_save()
	eq(SaveData.first_drive, SaveData.FirstDrive.DONE, "saved done")
	_clean()


func test_a_race_runs_the_prompts_and_the_pause_menu_skips_them() -> void:
	_clean()
	var plain := race(false, false)
	check(plain.first_drive == null, "a race on its own (tests, golden traces): no first drive")
	plain.free()
	var r := race(false, false)
	r.first_drive_on = true
	r.start_race()
	check(r.first_drive != null, "on for a new profile on Palm Coast")
	drive(r, 200, input(1.0))
	eq(r.first_drive.cleared, [] as Array[int], "not cleared yet")
	eq(r.first_drive.current, FirstDrive.Step.GAS, "racing: HOLD THE GAS up")
	drive(r, 60, input(1.0))
	eq(r.first_drive.cleared, [FirstDrive.Step.GAS] as Array[int], "a second of gas clears it")
	eq(r.callouts.current.get("text", ""), FirstDrive.CLEARED, "NICE! bursts")
	r.pause()
	eq(r.pause_menu.items, PauseMenu.rows(true), "SKIP FIRST DRIVE on the pause menu")
	check(r.pause_menu.items.find(PauseMenu.Action.SKIP) == r.pause_menu.items.find(PauseMenu.Action.QUIT) - 1, "just above QUIT")
	r.pause_action(PauseMenu.Action.SKIP)
	check(r.first_drive == null and not r.paused, "skipped: no more prompts, racing on")
	eq(SaveData.first_drive, SaveData.FirstDrive.SKIPPED, "saved as skipped")
	r.pause()
	eq(r.pause_menu.items, PauseMenu.rows(false), "no SKIP after")
	r.resume()
	r.start_race()
	check(r.first_drive == null, "a restart doesn't bring it back")
	check(not FirstDrive.wanted(0, SaveData), "nor does a new race")
	r.free()
	_clean()


func test_finishing_the_race_is_done_too() -> void:
	_clean()
	var r := race(false, false)
	r.first_drive_on = true
	r.start_race()
	drive(r, 200, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	drive(r, 5, input(1.0))
	check(r.state == r.State.FINISHED, "finished")
	check(r.first_drive == null, "the prompts gone at the line")
	eq(SaveData.first_drive, SaveData.FirstDrive.DONE, "done, for good")
	r.free()
	_clean()


func test_the_game_starts_it_only_from_the_menus_for_a_new_profile() -> void:
	_clean()
	WhosDriving.enabled = true
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	check(g.first_drive_for(0, false), "a new profile's race on Palm Coast")
	check(not g.first_drive_for(0, true), "not a demo")
	check(not g.first_drive_for(2, false), "not another stage")
	g.first_drive_allowed = false
	check(not g.first_drive_for(0, false), "not a race the dev flags started")
	g.first_drive_allowed = true
	WhosDriving.enabled = false
	check(not g.first_drive_for(0, false), "not with onboarding off (the test runners)")
	WhosDriving.enabled = true
	SaveData.end_first_drive(true)
	check(not g.first_drive_for(0, false), "not once skipped")
	WhosDriving.enabled = false
	_clean()
