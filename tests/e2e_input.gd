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
var _settings: Node


func _initialize() -> void:
	# one physics tick per frame: input events flush once a frame, so two
	# ticks in one frame could flush a press and its release together
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	_settings = root.get_node("Settings")  # autoloads aren't globals in a SceneTree script
	TestSuite.use_scratch_settings(_settings)
	TestSuite.use_scratch_save(root.get_node("SaveData"))
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	physics_frame.connect(_tick)


## The menus, one tap per entry: [action to tap, what should hold after it, message].
func _menu_script() -> Array:
	var g := _game
	return [
		["", func() -> bool: return g.screen == g.Screen.TITLE, "the game boots to the title screen"],
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
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.ACCESSIBILITY, "Right: Accessibility"],
		["steer_right", func() -> bool: return g.menu.page == g.menu.Page.GAME, "Right wraps round to Game"],
		["back", func() -> bool: return g.screen == g.Screen.TITLE and g.menu.index == 1, "Backspace goes back to the title, on OPTIONS"],
		["steer_left", func() -> bool: return g.menu.index == 0, "left picks START"],
		["confirm", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 0, "Enter on the title opens mode select, on GRAND TOUR"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks SINGLE RACE (played at the end)"],
		["steer_right", func() -> bool: return g.menu.index == 2, "right picks TIME ATTACK"],
		["confirm", func() -> bool: return g.screen == g.Screen.MODES and g.menu.notice.begins_with("Time Attack"), "TIME ATTACK says it's coming soon"],
		["steer_right", func() -> bool: return g.menu.index == 3, "right picks FREE DRIVE"],
		["confirm", func() -> bool: return g.screen == g.Screen.MODES and g.menu.notice.begins_with("Free Drive"), "FREE DRIVE says it's coming soon"],
		["steer_right", func() -> bool: return g.menu.index == 4, "right picks OPTIONS"],
		["confirm", func() -> bool: return g.screen == g.Screen.OPTIONS, "Enter on OPTIONS opens the options"],
		["back", func() -> bool: return g.screen == g.Screen.MODES and g.menu.index == 4, "back from those options returns to mode select"],
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
	if _menu_step % 2 == 0:
		if entry[0] != "":
			_send(entry[0], true)
	else:
		if entry[0] != "":
			_send(entry[0], false)
		_check(entry[1].call(), entry[2])
	_menu_step += 1
	_wait = 2
	return _menu_step < steps.size() * 2


## Through the event queue, as a real key arrives (flushed before physics).
func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


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
	if _frame > 2500:  # first, so a script error in a step can't hang the run
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
			_send("nitro", true)
			_next(2)
		5:
			_send("nitro", false)
			_check(p.nitro_charges == Cfg.NITRO_CHARGES - 1 and p.nitro_time > 0.0, "nitro fires once")
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
			_next(2)
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
			_next(200)
		13:
			# The second stage of the tour: to the line again
			_race.next_checkpoint = _race.checkpoint_distances.size()
			_race.player.distance = _race.finish_distance + 1.0
			_mark = _race.tour_state.points.get("YOU", 0)
			_next(2)
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
			_check(_race.pause_menu.index == 3, "Down picks QUIT TO TITLE")
			_send("confirm", true)
			_next(2)
		26:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE and _game.race == null, "QUIT TO TITLE on the pause menu quits to the title")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the race is gone")
			_next(2)
		27:
			_send("confirm", true)
			_next(2)
		28:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.MODES, "mode select")
			_next(2)
		29:
			_send("confirm", true)
			_next(2)
		30:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.menu.index == 2,
				"stage select opens on the stage the tour reached")
			_settings.auto_gas = true  # (toggled through the options menu above)
			_next(2)
		31:
			_send("confirm", true)
			_next(2)
		32:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.CARS, "car select")
			_next(2)
		33:
			_send("confirm", true)
			_next(2)
		34:
			_send("confirm", false)
			_race = _game.race
			_check(_race != null and _race.state == _race.State.COUNTDOWN, "a new race with auto gas on")
			if _race == null:
				quit(1)
				return
			_next(260)  # the countdown, then over a second of driving
		35:
			_check(_race.player.speed > Cfg.MAX_SPEED * 0.2, "auto gas: the car drives off with no key held")
			_mark = _race.player.speed
			_send("brake", true)
			_next(30)
		36:
			_send("brake", false)
			_check(_race.player.speed < _mark, "auto gas: brake still slows the car")
			_settings.auto_gas = false
			# Single Race: quit, then title, mode select, stage, car, race once
			_send("pause", true)
			_next(2)
		37:
			_send("pause", false)
			_send("accelerate", true)
			_next(2)
		38:
			_send("accelerate", false)
			_check(_race.pause_menu.index == 3, "Up from RESUME wraps to QUIT TO TITLE")
			_send("confirm", true)
			_next(2)
		39:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.TITLE, "quit to the title")
			_next(2)
		40:
			_send("confirm", true)
			_next(2)
		41:
			_send("confirm", false)
			_send("steer_right", true)
			_next(2)
		42:
			_send("steer_right", false)
			_check(_game.screen == _game.Screen.MODES and _game.menu.index == 1, "mode select, on SINGLE RACE")
			_send("confirm", true)
			_next(2)
		43:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES, "SINGLE RACE opens stage select")
			_next(2)
		44:
			_send("confirm", true)
			_next(2)
		45:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.CARS, "then car select")
			_next(2)
		46:
			_send("confirm", true)
			_next(2)
		47:
			_send("confirm", false)
			_race = _game.race
			_check(_race != null and not _race.tour, "a Single Race starts")
			if _race == null:
				quit(1)
				return
			_send("accelerate", true)
			_next(200)
		48:
			_check(_race.state == _race.State.RACING, "racing")
			_race.player.distance = _race.finish_distance + 1.0
			_next(2)
		49:
			_send("accelerate", false)
			_check(_race.state == _race.State.FINISHED and "menu" in _race.banner_sub,
				"the Single Race finishes, and offers the menu: " + _race.banner_sub)
			_send("confirm", true)
			_next(2)
		50:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.race == null, "Enter after the finish goes back to stage select")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the race is gone")
			_next()
		_:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e: %d failed" % _fails))
			quit(1 if _fails > 0 else 0)
