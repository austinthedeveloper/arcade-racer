## End-to-end smoke: boot the real main scene, go through the menus and drive
## through the input map like a player, and check the flow. Exits non-zero on failure.
##   godot --headless --path . -s res://tests/e2e_input.gd
extends SceneTree

var _game: Node
var _race: Node
var _menu_step := 0
var _in_race := false
var _frame := 0
var _step := 0
var _wait := 0
var _fails := 0
var _mark := 0.0
var _station := 0
var _stage_before := -1  # the player's stage pick, which a demo leaves alone
var _settings: Node
var _save: Node
var _router: Node


func _initialize() -> void:
	# one physics tick per frame: input events flush once a frame, so two
	# ticks in one frame could flush a press and its release together
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	TestSuite.begin_run()  # this run's own scratch folder (EQ-18)
	_router = root.get_node("InputRouter")
	TestSuite.use_scratch_profiles(_router)
	_settings = root.get_node("Settings")  # autoloads aren't globals in a SceneTree script
	TestSuite.use_scratch_settings(_settings)
	_save = root.get_node("SaveData")
	TestSuite.use_scratch_save(_save)  # a new profile: who's driving and the first drive come up
	TestSuite.use_scratch_ghosts()
	TestSuite.use_scratch_logs()  # never the player's user://logs/
	Tuning.use_defaults()  # never the player's user://tuning.cfg
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	physics_frame.connect(_tick)


## The menus, one tap per entry: [action to tap, what should hold after it, message].
func _menu_script() -> Array:
	var g := _game
	return [
		["", func() -> bool: return g.screen == g.Screen.TITLE and g.menu.asking, "the game boots to the title, asking who's driving (AC-16)"],
		["steer_right", func() -> bool: return g.menu.answer == 2, "right picks RACER"],
		["confirm", func() -> bool: return (not g.menu.asking and _save.driver_asked and _settings.difficulty == Difficulty.Level.NORMAL
			and not _settings.steer_assist), "Enter on RACER answers it: no assists, normal"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right on the title picks OPTIONS"],
		["confirm", func() -> bool: return g.screen == g.Screen.OPTIONS, "Enter opens the options"],
		["confirm", func() -> bool: return _settings.auto_gas, "Enter on AUTO GAS turns it on"],
		["brake", func() -> bool: return g.menu.row() == g.menu.Row.TRAFFIC, "Down picks the next row"],
		["steer_left", func() -> bool: return _settings.traffic == _settings.Traffic.LIGHT, "Left lowers the traffic"],
		["steer_right", func() -> bool: return _settings.traffic == _settings.Traffic.NORMAL, "Right raises it back"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.AUTO_GAS, "Up goes back a row"],
		["confirm", func() -> bool: return not _settings.auto_gas, "Enter turns auto gas off again"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.PAGE, "Up from the first option: the page bar"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.DISPLAY, "Right on the page bar: Display"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.AUDIO, "Right: Audio"],
		["brake", func() -> bool: return g.menu.row() == g.menu.Row.MUSIC, "Down on Audio: music volume"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.PAGE, "Up: the page bar again"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.CONTROLS, "Right: Controls"],
		["brake", func() -> bool: return g.menu.row() == g.menu.Row.CALIBRATE, "Down on Controls: calibrate"],
		["brake", func() -> bool: return g.menu.row() == g.menu.Row.WHEEL, "Down: wheel settings"],
		["confirm", func() -> bool: return g.screen == g.Screen.WHEEL, "Enter opens the wheel settings"],
		["back", func() -> bool: return g.screen == g.Screen.OPTIONS and g.menu.row() == g.menu.Row.WHEEL,
			"Backspace goes back to the options, on wheel settings"],
		["brake", func() -> bool: return g.menu.row() == g.menu.Row.REMAP, "Down: remap buttons"],
		["confirm", func() -> bool: return g.screen == g.Screen.REMAP, "Enter opens the remap screen"],
		["confirm", func() -> bool: return g.menu.listening == "nitro", "Enter on NITRO waits for a key"],
		["key:N", func() -> bool: return _router.keyboard.binding("nitro") == [KEY_N] and g.menu.listening == "",
			"pressing N binds nitro to it"],
		["back", func() -> bool: return g.screen == g.Screen.OPTIONS and g.menu.row() == g.menu.Row.REMAP,
			"Backspace goes back to the options, on remap"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.WHEEL, "Up: wheel settings"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.CALIBRATE, "Up: calibrate"],
		["accelerate", func() -> bool: return g.menu.row() == g.menu.Row.PAGE, "Up: the page bar"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.ACCESSIBILITY, "Right: Accessibility"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.GAME, "Right wraps round to Game"],
		["back", func() -> bool: return g.screen == g.Screen.TITLE and g.menu.index == 1, "Backspace goes back to the title, on OPTIONS"],
		["steer_right", func() -> bool: return g.menu.items()[g.menu.index] == "CONTROLS", "right picks CONTROLS"],
		["confirm", func() -> bool: return (g.screen == g.Screen.CONTROLS and g.menu.device == 0
			and g.menu.current_rows()[3][1] == "N"), "Enter opens the keyboard's controls card, nitro on N as rebound (PR-22)"],
		["back", func() -> bool: return g.screen == g.Screen.TITLE and g.menu.items()[g.menu.index] == "CONTROLS", "Backspace goes back to the title, on CONTROLS"],
		["steer_left", func() -> bool: return g.menu.index == 1, "left: OPTIONS"],
		["steer_left", func() -> bool: return g.menu.index == 0, "left picks START"],
		["confirm", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 0, "Enter on the title opens mode select, on GRAND TOUR"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks SINGLE RACE (played at the end)"],
		["steer_right", func() -> bool: return g.menu.index == 2, "right picks TIME ATTACK (played at the end)"],
		["steer_right", func() -> bool: return g.menu.index == 3, "right picks FREE DRIVE (played at the end)"],
		["steer_right", func() -> bool: return g.menu.index == 4, "right picks ONLINE"],
		["confirm", func() -> bool: return g.screen == g.Screen.CARS, "Enter on ONLINE opens car select (the host picks the stage)"],
		["confirm", func() -> bool: return g.screen == g.Screen.ONLINE and g.menu.current() == 0, "a car, then HOST or JOIN"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks JOIN"],
		["confirm", func() -> bool: return g.menu.current() == 1, "JOIN opens the letter grid"],
		["confirm", func() -> bool: return g.menu.code == "B", "Enter picks the letter under the cursor"],
		["back", func() -> bool: return g.menu.code == "", "Backspace deletes it"],
		["back", func() -> bool: return g.menu.current() == 0, "and again goes back to HOST or JOIN"],
		["back", func() -> bool: return g.screen == g.Screen.CARS, "back to car select"],
		["back", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 4, "and to mode select, on ONLINE (no stage select)"],
		["steer_right", func() -> bool: return g.menu.index == 5, "right picks OPTIONS"],
		["confirm", func() -> bool: return g.screen == g.Screen.OPTIONS, "Enter on OPTIONS opens the options"],
		["back", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 5, "back from those options returns to mode select"],
		["steer_right", func() -> bool: return g.menu.index == 0, "right wraps to GRAND TOUR"],
		["confirm", func() -> bool: return g.screen == g.Screen.STAGES, "Enter on GRAND TOUR opens stage select"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks stage 2"],
		["steer_left", func() -> bool: return g.menu.index == 0, "left goes back to stage 1"],
		["steer_left", func() -> bool: return g.menu.index == Stages.count() - 1, "left from stage 1 wraps to the last stage"],
		["steer_right", func() -> bool: return g.menu.index == 0, "and right wraps back"],
		["back", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 0, "Backspace on stage select goes back to mode select"],
		["back", func() -> bool: return g.screen == g.Screen.TITLE, "and Backspace there goes back to the title"],
		["confirm", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 0, "mode select remembers GRAND TOUR"],
		["confirm", func() -> bool: return g.screen == g.Screen.STAGES and g.menu.index == 0, "back into stage select"],
		["confirm", func() -> bool: return g.screen == g.Screen.CARS and g.stage_index == 0, "Enter picks the stage and opens car select"],
		["pause", func() -> bool: return g.screen == g.Screen.STAGES, "Esc on car select goes back to stage select"],
		["confirm", func() -> bool: return g.screen == g.Screen.CARS, "car select again"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks the next car"],
		["steer_left", func() -> bool: return g.menu.index == 0, "left goes back to the Vega"],
		["steer_left", func() -> bool: return g.menu.index == Cars.count() - 1, "left from the Vega wraps to the last car"],
		["steer_right", func() -> bool: return g.menu.index == 0, "and right wraps back"],
		["confirm", func() -> bool: return g.screen == g.Screen.RACE and g.race != null and g.race.car_id == "car_vega",
			"Enter on car select starts the race in the Vega"],
	]


## Taps each menu action (press, release a few frames later) and checks the result.
func _menus() -> bool:
	var steps := _menu_script()
	var entry: Array = steps[_menu_step / 2]
	var key: String = entry[0]
	if _menu_step % 2 == 0:
		if key.begins_with("key:"):
			_send_key(OS.find_keycode_from_string(key.get_slice(":", 1)), true)
		elif key != "":
			_send(key, true)
	else:
		if key.begins_with("key:"):
			_send_key(OS.find_keycode_from_string(key.get_slice(":", 1)), false)
		elif key != "":
			_send(key, false)
		_check(entry[1].call(), entry[2])
	_menu_step += 1
	_wait = 20 if key.begins_with("key:") else 2  # a new binding settles before menu input counts
	return _menu_step < steps.size() * 2


## Through the event queue, as a real key arrives (flushed before physics).
func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


## A key by its physical keycode, as the keyboard sends it (for rebound keys).
func _send_key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


## Stage select to a running Time Attack or Free Drive race, from step `first` (four steps): stage, car,
## then the gas held for the countdown and a second or so.
func _time_attack_start(first: int) -> void:
	match _step - first:
		0:
			_send("confirm", true)
			_next(2)
		1:
			_send("confirm", false)
			_next(2)
		2:
			_check(_game.screen == _game.Screen.CARS, "car select")
			_send("confirm", true)
			_next(2)
		3:
			_send("confirm", false)
			_race = _game.race
			_check(_race != null and (_race.time_attack or _race.free_drive), "the run starts")
			if _race == null:
				quit(1)
				return
			_send("accelerate", true)
			_next(200)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)


func _next(wait_frames: int = 0) -> void:
	_step += 1
	_wait = wait_frames


func _tick() -> void:
	_frame += 1
	if _frame > 4400 + 6 * (Replay.KEEP + 30):  # (six finishes sit through the instant replay, RC-17) first, so a script error in a step can't hang the run
		printerr("  FAIL e2e timed out at step %d" % _step)
		quit(1)
		return
	if _wait > 0:
		_wait -= 1
		return
	if not _in_race:
		if _menus():
			return
		_in_race = true
		_race = _game.race
		if _race == null:
			printerr("  FAIL no race after the menus")
			quit(1)
			return
		_wait = 1
		return
	var p: PlayerCar = _race.player if is_instance_valid(_race) else null
	match _step:
		0:
			_check(_race.state == _race.State.COUNTDOWN, "the race opens on the countdown")
			_send("accelerate", true)
			_next(200)
		1:
			_check(_race.state == _race.State.RACING, "GO after the countdown")
			_check(p.speed > 0.0, "holding gas moves the car")
			_check(_race.first_drive != null and _race.first_drive.current == 0,
				"a new profile's first race is the first drive: HOLD THE GAS up (MP-15)")
			_mark = p.x
			_send("steer_left", true)
			_next(40)
		2:
			_check(p.x < _mark, "steer left moves the car left")
			_send("steer_left", false)
			_send("steer_right", true)
			_mark = p.x
			_next(40)
		3:
			_check(p.x > _mark, "steer right moves the car right")
			_send("steer_right", false)
			_send("brake", true)
			_send("accelerate", false)
			_mark = p.speed
			_next(30)
		4:
			_check(p.speed < _mark, "brake slows the car")
			_check(p.braking, "brake lights on")
			_send("brake", false)
			_send("accelerate", true)
			_send_key(KEY_N, true)  # nitro, rebound to N in the remap screen
			_station = _race.audio.station
			_send("radio", true)
			_next(2)
		5:
			_send_key(KEY_N, false)
			_send("radio", false)
			_check(p.nitro_charges == Cfg.NITRO_CHARGES - 1 and p.nitro_time > 0.0, "the rebound N fires nitro once")
			_check(_race.audio.station == Radio.next(_station), "the radio button (M) changes station once")
			_send("pause", true)
			_next(2)
		6:
			_send("pause", false)
			_check(_race.paused and _race.pause_menu.visible, "pause opens the pause menu")
			_mark = p.distance
			_next(30)
		7:
			_check(p.distance == _mark, "paused car doesn't move")
			_check(_race.pause_menu.index == 0, "on RESUME, and the gas held since before the pause doesn't scroll it")
			_check(_race.pause_menu.items.size() == 6, "SKIP FIRST DRIVE on the pause menu")
			_send("accelerate", false)
			_send("confirm", true)
			_next(2)
		8:
			_send("confirm", false)
			_check(not _race.paused and not _race.pause_menu.visible, "RESUME on the pause menu resumes")
			_send("accelerate", true)
			_send("restart", true)
			_next(2)
		9:
			_send("restart", false)
			_send("accelerate", false)
			_check(_race.state == _race.State.COUNTDOWN and _race.player.distance == 0.0, "restart puts the car back on the grid")
			_send("accelerate", true)
			_next(200)
		10:
			# Jump to the finish line (driving there takes over a minute)
			_check(_race.state == _race.State.RACING, "racing again")
			p.distance = _race.finish_distance + 1.0
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay (RC-17), to the results
		11:
			_check(_race.state == _race.State.FINISHED, "crossing the line finishes the stage")
			_send("accelerate", false)
			_send("confirm", true)
			_next(2)
		12:
			_send("confirm", false)
			_check(_race.track.name == "Redrock Canyon" and _race.state == _race.State.COUNTDOWN,
				"Enter after the finish goes on to Redrock Canyon")
			_check(_race.tour_state.points.get("YOU", 0) >= 20, "the tour scored the first stage")
			_check(_race.first_drive == null and not _save.first_drive_pending(), "the first race run to the end: the first drive is done")
			_next(200)
		13:
			# The second stage of the tour: to the line again
			_race.next_checkpoint = _race.checkpoint_distances.size()
			_race.player.distance = _race.finish_distance + 1.0
			_mark = _race.tour_state.points.get("YOU", 0)
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay (RC-17), to the results
		14:
			_check(_race.state == _race.State.FINISHED and _race.after == _race.After.NEXT_STAGE,
				"the second stage finishes on the podium: " + _race.banner_sub)
			_check(_race.tour_state.points.get("YOU", 0) >= _mark + 20, "and its points add to the standings")
			_check(_race.tour_state.stages_won == 2, "two stages of the tour")
			_send("restart", true)
			_next(2)
		15:
			_send("restart", false)
			_check(_race.stage_index == 2, "R after a podium goes on too")
			_send("pause", true)
			_next(2)
		16:
			_send("pause", false)
			_check(_race.paused, "paused again")
			_next(2)  # (Esc counts as menu back too: let it go first)
		17:
			_send("back", true)
			_next(2)
		18:
			_send("back", false)
			_check(not _race.paused, "Backspace on the pause menu resumes")
			_send("pause", true)
			_next(2)
		19:
			_send("pause", false)
			_send("brake", true)
			_next(2)
		20:
			_send("brake", false)
			_check(_race.pause_menu.index == 1, "Down picks RESTART")
			_next(2)
		21:
			_send("brake", true)
			_next(2)
		22:
			_send("brake", false)
			_check(_race.pause_menu.index == 2, "Down again picks OPTIONS")
			_send("confirm", true)
			_next(2)
		23:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.OPTIONS and _race.paused and not _race.pause_menu.visible,
				"OPTIONS on the pause menu opens the options over the paused race")
			_send("back", true)
			_next(2)
		24:
			_send("back", false)
			_check(_game.screen == _game.Screen.RACE and _game.menu == null and _race.paused
				and _race.pause_menu.visible and _race.pause_menu.index == 2,
				"back from the options: the paused race, its menu on OPTIONS")
			_send("brake", true)
			_next(2)
		25:
			_send("brake", false)
			_check(_race.pause_menu.index == 3, "Down picks CONTROLS")
			_send("confirm", true)
			_next(2)
		26:
			_send("confirm", false)
			_check(_race.paused and _race.pause_menu.card != null, "CONTROLS opens the controls card over the paused race (PR-22)")
			_send("back", true)
			_next(2)
		27:
			_send("back", false)
			_check(_race.paused and _race.pause_menu.card == null and _race.pause_menu.visible, "back: the pause menu again")
			_send("brake", true)
			_next(2)
		28:
			_send("brake", false)
			_check(_race.pause_menu.index == 4, "Down picks QUIT TO TITLE")
			_send("confirm", true)
			_next(2)
		29:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE and _game.race == null, "QUIT TO TITLE on the pause menu quits to the title")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the race is gone")
			_next(2)
		30:
			_send("confirm", true)
			_next(2)
		31:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.MODES, "mode select")
			_next(2)
		32:
			_send("confirm", true)
			_next(2)
		33:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.menu.index == 2,
				"stage select opens on the stage the tour reached")
			_settings.auto_gas = true  # (toggled through the options menu above)
			_next(2)
		34:
			_send("confirm", true)
			_next(2)
		35:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.CARS, "car select")
			_next(2)
		36:
			_send("confirm", true)
			_next(2)
		37:
			_send("confirm", false)
			_race = _game.race
			_check(_race != null and _race.state == _race.State.COUNTDOWN, "a new race with auto gas on")
			if _race == null:
				quit(1)
				return
			_next(260)  # the countdown, then over a second of driving
		38:
			_check(_race.player.speed > Cfg.MAX_SPEED * 0.2, "auto gas: the car drives off with no key held")
			_mark = _race.player.speed
			_send("brake", true)
			_next(30)
		39:
			_send("brake", false)
			_check(_race.player.speed < _mark, "auto gas: brake still slows the car")
			_settings.auto_gas = false
			# Single Race: quit, then title, mode select, stage, car, race once
			_send("pause", true)
			_next(2)
		40:
			_send("pause", false)
			_send("accelerate", true)
			_next(2)
		41:
			_send("accelerate", false)
			_check(_race.pause_menu.index == _race.pause_menu.items.size() - 1, "Up from RESUME wraps to QUIT TO TITLE")
			_send("confirm", true)
			_next(2)
		42:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE, "quit to the title")
			_next(2)
		43:
			_send("confirm", true)
			_next(2)
		44:
			_send("confirm", false)
			_send("steer_right", true)
			_next(2)
		45:
			_send("steer_right", false)
			_check(_game.screen == _game.Screen.MODES and _game.menu.index == 1, "mode select, on SINGLE RACE")
			_send("confirm", true)
			_next(2)
		46:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES, "SINGLE RACE opens stage select")
			_next(2)
		47:
			_send("confirm", true)
			_next(2)
		48:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.CARS, "then car select")
			_next(2)
		49:
			_send("confirm", true)
			_next(2)
		50:
			_send("confirm", false)
			_race = _game.race
			_check(_race != null and not _race.tour, "a Single Race starts")
			_check(_race != null and _race.first_drive == null, "the profile's first drive is done: no prompts")
			if _race == null:
				quit(1)
				return
			_send("accelerate", true)
			_next(200)
		51:
			_check(_race.state == _race.State.RACING, "racing")
			_race.player.distance = _race.finish_distance + 1.0
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay (RC-17), to the results
		52:
			_send("accelerate", false)
			_check(_race.state == _race.State.FINISHED and "menu" in _race.banner_sub,
				"the Single Race finishes, and offers the menu: " + _race.banner_sub)
			_check(_race.results.visible and _race.results.labels[0] == "CONTINUE", "the results screen, on CONTINUE")
			_send("confirm", true)
			_next(2)
		53:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.race == null, "Enter after the finish goes back to stage select")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the race is gone")
			# Time Attack: a first run sets the ghost, the second races it
			_send("back", true)
			_next(2)
		54:
			_send("back", false)
			_check(_game.screen == _game.Screen.MODES, "back to mode select")
			_send("steer_right", true)
			_next(2)
		55:
			_send("steer_right", false)
			_check(_game.menu.index == 2, "on TIME ATTACK")
			_send("confirm", true)
			_next(2)
		56:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.menu.time_attack(), "TIME ATTACK opens stage select")
			_next()
		57, 58, 59, 60:
			_time_attack_start(57)
		61:
			_check(_race.state == _race.State.RACING and _race.rivals.cars.is_empty(), "racing alone")
			_race.player.distance = _race.finish_distance + 1.0
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay (RC-17), to the results
		62:
			_send("accelerate", false)
			_check(_race.state == _race.State.FINISHED and "NEW BEST" in _race.banner_sub,
				"the first run is the best so far: " + _race.banner_sub)
			_send("confirm", true)
			_next(2)
		63:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES, "back to stage select")
			_next()
		64, 65, 66, 67:
			_time_attack_start(64)
		68:
			_check(_race.ghost != null and _race.ghost_now.x > 0.0, "the ghost of the first run drives along")
			_race.player.distance = _race.finish_distance + 1.0
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay (RC-17), to the results
		69:
			_send("accelerate", false)
			_check(_race.state == _race.State.FINISHED and "vs best" in _race.banner_sub,
				"the second run is timed against it: " + _race.banner_sub)
			# Free Drive: in from mode select, past the finish line, then quit from the pause menu
			_send("confirm", true)
			_next(2)
		70:
			_send("confirm", false)
			_next(2)
		71:
			_send("back", true)
			_next(2)
		72:
			_send("back", false)
			_send("steer_right", true)
			_next(2)
		73:
			_send("steer_right", false)
			_check(_game.screen == _game.Screen.MODES and _game.menu.index == 3, "mode select, on FREE DRIVE")
			_send("confirm", true)
			_next(2)
		74:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.menu.solo(), "FREE DRIVE opens stage select")
			_next(2)
		75, 76, 77, 78:
			_time_attack_start(75)
		79:
			_check(_race.free_drive and _race.rivals.cars.is_empty(), "Free Drive: alone on the road")
			_race.player.distance = _race.finish_distance + 1.0
			_next(30)
		80:
			_check(_race.state == _race.State.RACING, "past the line and still driving")
			_send("accelerate", false)
			_send("pause", true)
			_next(2)
		81:
			_send("pause", false)
			_send("accelerate", true)
			_next(2)
		82:
			_send("accelerate", false)
			_check(_race.pause_menu.index == _race.pause_menu.items.size() - 1, "QUIT TO TITLE")
			_next(2)
		83:
			_send("confirm", true)
			_next(2)
		84:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE and _game.race == null, "Free Drive quits to the title")
			# Attract mode: leave the title be (a short wait, not 20 s)
			_game.attract_delay = 0.5
			_stage_before = _game.stage_index
			_next(40)  # the 0.5 s delay and a little
		85:
			_race = _game.race
			_check(_game.screen == _game.Screen.RACE and _race != null and _race.demo,
				"left alone, the title starts a demo race")
			if _race == null:
				quit(1)
				return
			_check(_race.traffic.cars.size() > 0, "with traffic")
			_mark = _race.player.distance
			_next(60)
		86:
			_check(_race.player.distance > _mark and _race.player.speed > 0.0, "the demo drives itself")
			_check(_game.stage_index == _stage_before, "the demo leaves the player's stage pick alone")
			_send("confirm", true)
			_next(2)
		87:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE and _game.race == null, "any input ends the demo, back to the title")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the demo race is gone")
			_next(4)
		88:
			_check(_game.screen == _game.Screen.TITLE, "the press that ended it doesn't also pick START")
			# The Grand Tour's ending (MP-16): a tour on its last stage, scripted to the line
			_game.mode_index = 0  # GRAND_TOUR (ModeSelect.Item; named here, its script would compile before the autoloads)
			_game.stage_index = Stages.count() - 1
			_game.start_race()
			_race = _game.race
			_check(_race != null and _race.tour, "a tour on the last stage")
			if _race == null:
				quit(1)
				return
			_send("accelerate", true)
			_next(200)
		89:
			_check(_race.state == _race.State.RACING, "racing the last stage")
			_race.next_checkpoint = _race.checkpoint_distances.size()
			_race.player.distance = _race.finish_distance + 1.0
			_next(150 + Replay.KEEP + 30)  # past the finish spectacle and the instant replay, to the results
		90:
			_send("accelerate", false)
			_check(_race.state == _race.State.FINISHED and _race.after == _race.After.TOUR_DONE and _race.results.visible,
				"the last stage completes the tour: " + _race.banner_sub)
			_send("confirm", true)
			_next(2)
		91:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.FINALE and _game.race == null, "CONTINUE: the tour's finale, on the podium")
			_next(2)
		92:
			_send("confirm", true)
			_next(2)
		93:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.FINALE and _game.menu.page == 1, "Enter: the tour standings")
			_next(2)
		94:
			_send("confirm", true)
			_next(2)
		95:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.FINALE and _game.menu.page == 2
				and _game.menu.standings[0]["name"] == "YOU", "Enter: the end card, first overall")
			_next(2)
		96:
			_send("confirm", true)
			_next(2)
		97:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.CREDITS and _game.menu.harbor, "Enter: the credits, over the harbor")
			_mark = _game.menu.scroll
			_next(30)
		98:
			_check(_game.menu.scroll > _mark, "the credits roll by themselves")
			_mark = _game.menu.scroll
			_send("accelerate", true)
			_next(30)
		99:
			_send("accelerate", false)
			_check(_game.menu.scroll - _mark > 30.0 * _game.menu.SPEED / Engine.physics_ticks_per_second * 2.0,
				"a button held speeds them up")
			_send("back", true)
			_next(2)
		100:
			_send("back", false)
			_check(_game.screen == _game.Screen.TITLE, "back from the credits: the title")
			_next()
		_:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e: %d failed" % _fails))
			quit(1 if _fails > 0 else 0)


func _finalize() -> void:
	TestSuite.end_run()
