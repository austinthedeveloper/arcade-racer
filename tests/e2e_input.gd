## End-to-end smoke: boot the real main scene, drive it through the input
## map like a player, and check the flow. Exits non-zero on failure.
##   godot --headless --path . -s res://tests/e2e_input.gd
extends SceneTree

var _race: Node
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
	_race = load("res://scenes/main.tscn").instantiate()
	root.add_child(_race)
	physics_frame.connect(_tick)


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
	var p: PlayerCar = _race.player
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
			_next()
		_:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e: %d failed" % _fails))
			quit(1 if _fails > 0 else 0)
	if _frame > 2000:
		printerr("  FAIL e2e timed out at step %d" % _step)
		quit(1)
