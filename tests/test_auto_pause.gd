## Auto-pause (AC-15): the window losing focus or the app going to the background pauses a
## race under way, through the notifications, but never the attract demo, an autodriven run
## or an online race.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


## A race under way (past the countdown), the player on the gas.
func _racing() -> Node:
	var r := race(false, false)
	drive(r, 240, input(1.0))
	check(r.state == r.State.RACING, "racing")
	return r


func test_each_notification_pauses_a_race() -> void:
	_clean()
	for what: int in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
			Node.NOTIFICATION_APPLICATION_PAUSED]:
		var r := _racing()
		r.notification(what)
		check(r.paused and r.pause_menu.visible, "notification %d: paused, on the pause menu" % what)
		var z: float = r.player.distance
		drive(r, 30, input(1.0))
		eq(r.player.distance, z, "frozen")
		r.resume()
		drive(r, 10, input(1.0))
		check(r.player.distance > z, "resumed: drives on")


func test_other_notifications_and_focus_back_leave_it_alone() -> void:
	_clean()
	var r := _racing()
	for what: int in [Node.NOTIFICATION_WM_WINDOW_FOCUS_IN, Node.NOTIFICATION_APPLICATION_FOCUS_IN,
			Node.NOTIFICATION_APPLICATION_RESUMED]:
		r.notification(what)
	check(not r.paused, "focus coming back doesn't pause")
	r.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	r.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(r.paused, "nor resume: the player picks RESUME")


func test_the_countdown_pauses_too() -> void:
	_clean()
	var r := race(false, false)
	drive(r, 10)
	eq(r.state, r.State.COUNTDOWN, "counting down")
	check(r.focus_lost(), "pauses")
	check(not r.focus_lost(), "already paused: nothing more")


func test_not_when_it_wouldnt_help() -> void:
	_clean()
	var auto := race(true, false)
	drive(auto, 240)
	auto.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not auto.paused, "an autodriven run (golden traces, screenshots) races on")
	var demo := race(false, false)
	demo.demo = true
	demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not demo.paused, "the attract demo plays on")
	var r := _racing()
	r.state = r.State.FINISHED
	check(not r.auto_pauses(), "a finished race: the results are up")
	r.state = r.State.RACING
	r.online = OnlineSession.new()
	check(not r.auto_pauses(), "online: the race can't stop, so the menu doesn't open by itself")
	r.online = null
	check(r.auto_pauses(), "offline again: it would")
