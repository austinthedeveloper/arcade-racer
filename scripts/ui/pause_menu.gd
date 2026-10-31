class_name PauseMenu
extends MenuScreen
## The in-race pause menu: Resume, Restart, Options, Quit to title over the frozen race.
## Up/down or left/right (a wheel steers) moves, confirm picks, back or pause resumes.
## `choose` turns a tick of input into an Action; the race carries it out.

enum Action { NONE, RESUME, RESTART, OPTIONS, QUIT }

const ITEMS := [Action.RESUME, Action.RESTART, Action.OPTIONS, Action.QUIT]
const LABELS := ["RESUME", "RESTART", "OPTIONS", "QUIT TO TITLE"]
const ROW_H := 30.0

var index := 0  # into ITEMS
var has_options := true  # false when nothing can show the options (a race on its own)
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
	index = posmod(index + dir, ITEMS.size())
	if ITEMS[index] == Action.OPTIONS and not has_options:
		index = posmod(index + dir, ITEMS.size())
	return index


## One tick of menu input (and whether pause was pressed): the action picked, or NONE.
func choose(m: MenuInput, pause_pressed := false) -> int:
	if _hold > 0:
		_hold -= 1
		return Action.NONE
	if pause_pressed or m.back_pressed:
		return Action.RESUME
	if _latched and absf(m.x) < MenuInput.RELEASE and absf(m.y) < MenuInput.RELEASE:
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


## Control hints, worded for the device in use.
static func pause_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "Steer: choose    Gas: select    Brake: resume"
		DriveInput.Kind.GAMEPAD:
			return "D-pad: choose    A: select    B / Start: resume"
	return "Up / Down: choose    Enter: select    Esc: resume"


func _draw() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.6))
	var panel := Rect2(w / 2.0 - 140, 84, 280, 76 + ROW_H * ITEMS.size())
	_frame(panel)
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.9))
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
