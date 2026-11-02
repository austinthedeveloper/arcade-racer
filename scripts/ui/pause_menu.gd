class_name PauseMenu
extends MenuScreen
## The in-race pause menu: Resume, Restart, Options, Quit to title over the frozen race.
## Up/down or left/right (a D-pad, a wheel's too) moves, confirm picks, back or pause resumes.
## `choose` turns a tick of input into an Action; the race carries it out. A notice above it
## says why the race paused when it wasn't the player (the wheel unplugged, WH-7). Plugged
## back in, the menu gives way to a 3, 2, 1 count (counting, WH-12) before the race resumes.

enum Action { NONE, RESUME, RESTART, OPTIONS, QUIT }

const ITEMS := [Action.RESUME, Action.RESTART, Action.OPTIONS, Action.QUIT]
const LABELS := ["RESUME", "RESTART", "OPTIONS", "QUIT TO TITLE"]
const ROW_H := 30.0
const REPLUG_COUNT := 3.0  # seconds the count runs after the joypad comes back (WH-12)
const WARN := Color("#ff5d5d")  # the notice's heading
const BACK_OK := Color("#5dff8a")  # the same joypad back (replugged_notice)

var has_options := true  # false when nothing can show the options (a race on its own)
## Why the race paused, over the menu: [heading, line] (unplugged_notice), or empty.
var notice: Array[String] = []
## Seconds left on the replug countdown (Race.replug_tick), 0 when not counting: the count
## shows in place of the menu.
var counting := 0.0
var _hold := 0  # ticks to ignore input for, after coming back from the options
## Gas or steering held when the menu opened would auto-repeat through it, so it doesn't
## move until they're let go.
var _latched := false


func _ready() -> void:
	super._ready()
	visible = false


## Shows the menu on RESUME.
func open() -> void:
	index = 0
	visible = true
	_hold = 0
	_latched = true


## Shows it again where it was (back from the options). The tick that closed the options
## still has its back press, so it waits a tick before reading input.
func reopen() -> void:
	visible = true
	_hold = 1


func close() -> void:
	visible = false


## Moves the selection by `dir`, wrapping round and skipping OPTIONS without options;
## returns the new index.
func move(dir: int) -> int:
	super.move(dir)
	if ITEMS[index] == Action.OPTIONS and not has_options:
		super.move(dir)
	return index


func choice_count() -> int:
	return ITEMS.size()


## One tick of menu input (and whether pause was pressed): the action picked, or NONE.
func choose(m: MenuInput, pause_pressed := false) -> int:
	if _hold > 0:
		_hold -= 1
		return Action.NONE
	if pause_pressed or m.back_pressed:
		return Action.RESUME
	if _latched and m.centred():
		_latched = false
	var dir := 0 if _latched else (m.step_y() if m.step_y() != 0 else m.step())
	if dir != 0:
		move(dir)
		Audio.play("tick")
		return Action.NONE
	if m.confirm_pressed:
		Audio.play("beep")
		return ITEMS[index]
	return Action.NONE


## The notice for the joypad driving, `joy_name`, unplugged mid-race (WH-7).
static func unplugged_notice(joy_name: String, wheel: bool) -> Array[String]:
	var what := "WHEEL" if wheel else "CONTROLLER"
	var n := joy_name.strip_edges()
	if n == "":
		n = "it"
	elif n.length() > 40:
		n = n.substr(0, 40).strip_edges()
	return ["%s DISCONNECTED" % what, "Plug %s back in to carry on." % n]


## The notice for a joypad plugged in while the driving one was gone (WH-12): it's back, or
## a different one (`same` false) is driving now, on its own settings.
static func replugged_notice(joy_name: String, wheel: bool, same: bool) -> Array[String]:
	var what := "WHEEL" if wheel else "CONTROLLER"
	var n := joy_name.strip_edges()
	if n.length() > 40:
		n = n.substr(0, 40).strip_edges()
	if same:
		return ["%s CONNECTED" % what, "Get ready..."]
	if n == "":
		n = "It"
	return ["A DIFFERENT %s" % what, "%s is driving now, with its own settings." % n]


## The notice heading's color: red for a disconnect, green for the same joypad back, gold
## for a different one.
static func notice_tint(n: Array[String]) -> Color:
	if n.is_empty() or n[0].ends_with("DISCONNECTED"):
		return WARN
	return GOLD if n[0].begins_with("A DIFFERENT") else BACK_OK


## The number the replug countdown shows with `left` seconds to go: 3, 2, 1.
static func count_number(left: float) -> int:
	return clampi(ceili(left), 1, 3)


## Control hints, worded for the device in use.
static func pause_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.GAMEPAD, DriveInput.Kind.WHEEL:
			return "D-pad: choose    A: select    B / Start: resume"
	return "Up / Down: choose    Enter: select    Esc: resume"


func _draw() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.6 if counting <= 0.0 else 0.35))
	if counting > 0.0:
		_draw_count(w)
		return
	var panel := Rect2(w / 2.0 - 140, 84, 280, 76 + ROW_H * ITEMS.size())
	_panel(panel, 0.9)
	_text_centered(Vector2(w / 2.0, panel.position.y + 32), "PAUSED", 24, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 42, panel.size.x - 40, 2), GOLD)
	for i in ITEMS.size():
		var y := panel.position.y + 52 + i * ROW_H
		var on := i == index
		var off: bool = ITEMS[i] == Action.OPTIONS and not has_options
		var row := Rect2(panel.position.x + 16, y, panel.size.x - 32, ROW_H - 6)
		if on:
			draw_rect(row, Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(row.position.x, row.position.y, 3, row.size.y), GOLD)
		var col := GOLD if on else Color(1, 1, 1, 0.3 if off else 0.85)
		_text_centered(Vector2(w / 2.0, y + 17), LABELS[i], 14, col)
	_text_centered(Vector2(w / 2.0, panel.end.y - 10), pause_hints(), 9, Color(1, 1, 1, 0.7))
	_draw_notice(w)


## The notice, over the menu (or the count): why it paused, or what came back.
func _draw_notice(w: float) -> void:
	if notice.size() == 2:
		var box := Rect2(w / 2.0 - 210, 26, 420, 46)
		_panel(box, 0.92)
		var tint := notice_tint(notice)
		draw_rect(Rect2(box.position.x, box.position.y, 4, box.size.y), tint)
		_text_centered(Vector2(w / 2.0, box.position.y + 19), notice[0], 15, Color(tint, 0.85 + 0.15 * sin(time * 4.0)))
		_text_centered(Vector2(w / 2.0, box.position.y + 37), notice[1], 10, Color.WHITE)


## The replug countdown: the notice, then a panel where the menu was with the number in it,
## big, shrinking through each second.
func _draw_count(w: float) -> void:
	_draw_notice(w)
	var panel := Rect2(w / 2.0 - 140, 84, 280, 150)
	_panel(panel, 0.9)
	_text_centered(Vector2(w / 2.0, panel.position.y + 32), "RESUMING IN", 20, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 42, panel.size.x - 40, 2), GOLD)
	var k := counting - floorf(counting)  # 1 as the number comes up, toward 0 as it goes
	if k == 0.0:
		k = 1.0
	var size := int(36 + 24 * k)
	_text_centered(Vector2(w / 2.0, panel.position.y + 92 + size * 0.35), str(count_number(counting)), size,
		Color(Color.WHITE, 0.55 + 0.45 * k))
	_text_centered(Vector2(w / 2.0, panel.end.y - 10), "Pause: stop the count", 9, Color(1, 1, 1, 0.7))
