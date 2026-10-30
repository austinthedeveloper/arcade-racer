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


func _initialize() -> void:
	# one physics tick per frame: input events flush once a frame, so two
	# ticks in one frame could flush a press and its release together
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	physics_frame.connect(_tick)


## The menus, one tap per entry: [action to tap, what should hold after it, message].
func _menu_script() -> Array:
	var g := _game
	return [
		["", func() -> bool: return g.screen == g.Screen.TITLE, "the game boots to the title screen"],
		["confirm", func() -> bool: return g.screen == g.Screen.STAGES, "Enter on the title opens stage select"],
		["steer_right", func() -> bool: return g.menu.index == 1, "right picks stage 2"],
		["steer_left", func() -> bool: return g.menu.index == 0, "left goes back to stage 1"],
		["steer_left", func() -> bool: return g.menu.index == Stages.count() - 1, "left from stage 1 wraps to the last stage"],
		["steer_right", func() -> bool: return g.menu.index == 0, "and right wraps back"],
		["back", func() -> bool: return g.screen == g.Screen.TITLE, "Backspace on stage select goes back to the title"],
		["confirm", func() -> bool: return g.screen == g.Screen.STAGES and g.menu.index == 0, "back into stage select"],
		["confirm", func() -> bool: return g.screen == g.Screen.CARS and g.stage_index == 0, "Enter picks the stage and opens car select"],
		["pause", func() -> bool: return g.screen == g.Screen.STAGES, "Esc on car select goes back to stage select"],
		["confirm", func() -> bool: return g.screen == g.Screen.CARS, "car select again"],
		["steer_right", func() -> bool: return g.menu.index == 0, "only the Vega so far"],
		["confirm", func() -> bool: return g.screen == g.Screen.RACE and g.race != null, "Enter on car select starts the race"],
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
			_check(_race.paused, "pause")
			_mark = p.distance
			_next(30)
		7:
			_check(p.distance == _mark, "paused car doesn't move")
			_send("pause", true)
			_next(2)
		8:
			_send("pause", false)
			_check(not _race.paused, "unpause")
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
			_send("pause", true)
			_next(2)
		13:
			_send("pause", false)
			_check(_race.paused, "paused again")
			_next(2)
		14:
			_send("back", true)
			_next(2)
		15:
			_send("back", false)
			_check(_game.screen == _game.Screen.TITLE and _game.race == null, "Backspace while paused quits to the title")
			_check(not is_instance_valid(_race) or _race.is_queued_for_deletion(), "the race is gone")
			_send("confirm", true)
			_next(2)
		16:
			_send("confirm", false)
			_check(_game.screen == _game.Screen.STAGES and _game.menu.index == 1,
				"stage select opens on the stage the tour reached")
			_next()
		_:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e: %d failed" % _fails))
			quit(1 if _fails > 0 else 0)
	if _frame > 2000:
		printerr("  FAIL e2e timed out at step %d" % _step)
		quit(1)
