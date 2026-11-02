class_name TitleScreen
extends MenuScreen
## Attract screen: the logo over the Palm Coast sunset, with START (on to mode select),
## OPTIONS, STATS (MP-11) and QUIT side by side. A browser tab can't be quit, so the web build has no QUIT.
## After an error (CrashLog, EQ-20) the version line offers COPY REPORT: F4, or a click or tap
## on it, puts the report on the clipboard.

const LOGO := "res://assets/sprites/ui/logo.png"
const PILL_STEP := 160.0
const VERSION_X := 150.0  # the version line, from the right edge
const COPIED_SECONDS := 2.5  # how long REPORT COPIED shows

var _logo: Texture2D
## `time` when the report was last copied, or a negative number.
var copied_at := -100.0
## Where the report goes (copy_report): the clipboard, unless a test hands it another.
var set_clipboard := Callable()


func _ready() -> void:
	super._ready()
	_logo = load(LOGO)


## What the start prompt says for the device in use.
static func start_prompt() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "PRESS A"
		DriveInput.Kind.GAMEPAD:
			return "PRESS START"
	return "PRESS ENTER"


## The title's choices: QUIT too, except in a browser.
static func items(web := OS.has_feature("web")) -> Array[String]:
	var out: Array[String] = ["START", "OPTIONS", "STATS"]
	if not web:
		out.append("QUIT")
	return out


## What the version line offers about the crash report: nothing without one.
static func report_offer(has_report: bool, copied: bool) -> String:
	if not has_report:
		return ""
	return "REPORT COPIED" if copied else "F4 COPY REPORT"


func report_text() -> String:
	return report_offer(CrashLog.has_report(), time - copied_at < COPIED_SECONDS)


## Where COPY REPORT is on the screen, for a click or tap.
func report_rect() -> Rect2:
	var wide := UiText.width("F4 COPY REPORT", 8)
	return Rect2(Cfg.SCREEN_W - VERSION_X - wide - 16, Cfg.SCREEN_H - 20, wide + 12, 20)


## COPY REPORT: the crash report on the clipboard. False when there's none to copy.
func copy_report() -> bool:
	if not CrashLog.copy_report("", set_clipboard):
		return false
	copied_at = time
	Audio.play("beep")
	return true


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
		and report_rect().has_point((make_input_local(event) as InputEventMouseButton).position)
	var f4 := InputMap.has_action("copy_report") and event.is_action_pressed("copy_report")
	if (f4 or click) and report_text() != "":
		copy_report()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func choice_count() -> int:
	return items().size()


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		match items()[index]:
			"START":
				game.show_mode_select()
			"OPTIONS":
				game.show_options()
			"STATS":
				game.show_stats()
			"QUIT":
				game.quit()


func _draw() -> void:
	_backdrop(0.15)
	var w := float(Cfg.SCREEN_W)
	if _logo != null:
		var bob := roundf(sin(time * 2.0) * 2.0)
		draw_texture(_logo, Vector2(roundf((w - _logo.get_width()) / 2.0), 22 + bob))
	var names := items()
	for i in names.size():
		var pill := Rect2(w / 2.0 - names.size() * PILL_STEP / 2.0 + 10 + i * PILL_STEP, 270, 140, 26)
		var on := i == index
		if on:
			draw_rect(pill.grow(4), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
		draw_rect(pill.grow(2), Color("#c9d4ff") if on else Color(1, 1, 1, 0.35))
		draw_rect(pill, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.85))
		_text_centered(Vector2(pill.get_center().x, 288), names[i], 14, Color.WHITE if on else Color(1, 1, 1, 0.55))
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, 314), start_prompt(), 10, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, w, 20), Color(0, 0, 0, 0.6))
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 8), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(w - VERSION_X, Cfg.SCREEN_H - 8), "F2 calibrate wheel   v" + str(ProjectSettings.get_setting("application/config/version", "")), 8, Color(1, 1, 1, 0.6))
	var report := report_text()
	if report != "":
		var r := report_rect()
		_text(Vector2(r.end.x - 6 - UiText.width(report, 8), Cfg.SCREEN_H - 8), report, 8, GOLD)
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 330), hint, 10, GOLD)
