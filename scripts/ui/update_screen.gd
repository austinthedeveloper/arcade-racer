class_name UpdateScreen
extends MenuScreen
## The first screen of an exported desktop game (EQ-14): checks for a newer version, and if
## there is one downloads it at once with a progress bar, says it's installed and restarts on
## it. Up to date, it goes straight on to the title.
##
## It also goes on to the title with no answer in CHECK_TIMEOUT seconds or no connection, so
## a dropped line never locks anyone out. A failed download offers RETRY or PLAY THIS
## VERSION; a release that needs a full download (another Godot version) offers the releases
## page or PLAY THIS VERSION. Back is PLAY THIS VERSION too.

const CHECK_TIMEOUT := 8.0  # seconds without an answer before going on to the title
const RESTART_DELAY := 1.25  # seconds "installed" shows before the restart
const CHOICE_TEXT := {"retry": "RETRY", "page": "GET IT", "play": "PLAY THIS VERSION"}

var updater: Updater  # the Updates autoload unless a test gives its own
var choice := 0  # into choices()
var restart_failed := false
var finished := false

var _waited := 0.0
var _ready_time := 0.0


func _ready() -> void:
	super._ready()
	if updater == null:
		updater = get_node("/root/Updates")


## What the screen says for the updater's state: a headline and two lines under it.
func lines() -> Array[String]:
	var u := updater
	match u.state:
		Updater.State.AVAILABLE, Updater.State.DOWNLOADING:
			var mb := float(u.manifest.get("size", 0)) / 1048576.0
			return ["Version %s is out." % u.latest, "Downloading it now.",
				"%.1f of %.1f MB" % [mb * u.progress(), mb]]
		Updater.State.READY:
			if restart_failed:
				return ["Version %s is installed." % u.latest, "Close the game and open it again to play it.", ""]
			return ["Version %s is installed." % u.latest, "Restarting...", ""]
		Updater.State.FULL:
			return ["Version %s is out." % u.latest, "It needs a full download from the releases page.", ""]
		Updater.State.FAILED:
			return ["The download didn't finish.", u.error, ""]
	return ["Checking for a new version...", "", ""]


## The choices offered: none while checking, downloading or restarting.
func choices() -> Array[String]:
	match updater.state:
		Updater.State.FULL:
			return ["page", "play"]
		Updater.State.FAILED:
			return ["retry", "play"]
		Updater.State.READY:
			return ["play"] if restart_failed else []
	return []


## One frame of the update: starts the download, times out the check, restarts when ready,
## and goes on to the title when there's nothing to do.
func step(dt: float) -> void:
	if finished:
		return
	match updater.state:
		Updater.State.OFF, Updater.State.LATEST:
			_finish()
		Updater.State.IDLE, Updater.State.CHECKING:
			_waited += dt
			if _waited >= CHECK_TIMEOUT:
				_finish()  # no answer: play what we have
		Updater.State.AVAILABLE:
			updater.download()  # at once
		Updater.State.FAILED:
			if updater.manifest.is_empty():
				_finish()  # the check failed (offline): play what we have
		Updater.State.READY:
			_ready_time += dt
			if _ready_time >= RESTART_DELAY and not restart_failed:
				restart_failed = not updater.restart()
	choice = clampi(choice, 0, maxi(choices().size() - 1, 0))


func _process(dt: float) -> void:
	super._process(dt)
	step(dt)


func handle(m: MenuInput) -> void:
	var ids := choices()
	if ids.is_empty():
		return
	if m.step() != 0:
		choice = posmod(choice + m.step(), ids.size())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		press(ids[choice])
	elif m.back_pressed and ids.has("play"):
		press("play")


func press(id: String) -> void:
	match id:
		"retry":
			_waited = 0.0
			updater.state = Updater.State.AVAILABLE
			updater.download()
		"page":
			updater.open_page()
		"play":
			_finish()


func _finish() -> void:
	finished = true
	if game != null:
		game.show_title()


func _draw() -> void:
	_backdrop(0.55)
	_header("UPDATE")
	var w := float(Cfg.SCREEN_W)
	var panel := Rect2(90, 92, w - 180, 150)
	_frame(panel)
	draw_rect(panel, Color(NIGHT, 0.92))
	var ls := lines()
	_text_centered(Vector2(w / 2.0, 132), ls[0], 16, GOLD)
	_text_centered(Vector2(w / 2.0, 162), ls[1], 11, Color.WHITE)
	var st := updater.state
	if st in [Updater.State.AVAILABLE, Updater.State.DOWNLOADING, Updater.State.READY]:
		var bar := Rect2(130, 184, w - 260, 14)
		draw_rect(bar.grow(2), Color("#c9d4ff"))
		draw_rect(bar, Color(0.07, 0.07, 0.2))
		var p := 1.0 if st == Updater.State.READY else updater.progress()
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), GOLD)
		_text_centered(Vector2(w / 2.0, 222), ls[2], 9, Color(1, 1, 1, 0.7))
	elif ls[2] != "":
		_text_centered(Vector2(w / 2.0, 192), ls[2], 9, Color(1, 1, 1, 0.7))
	var ids := choices()
	for i in ids.size():
		var pill := Rect2(w / 2.0 - ids.size() * 85 + 10 + i * 170, 270, 150, 26)
		var on := i == choice
		if on:
			draw_rect(pill.grow(4), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
		draw_rect(pill.grow(2), Color("#c9d4ff") if on else Color(1, 1, 1, 0.35))
		draw_rect(pill, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.85))
		_text_centered(Vector2(pill.get_center().x, 288), CHOICE_TEXT[ids[i]], 12, Color.WHITE if on else Color(1, 1, 1, 0.55))
	_footer(hints(true) if not ids.is_empty() else "v" + Updater.version())
