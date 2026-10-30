class_name TitleScreen
extends MenuScreen
## Attract screen: the logo over the Palm Coast sunset. Any confirm goes to stage select.

const LOGO := "res://assets/sprites/ui/logo.png"

var _logo: Texture2D


func _ready() -> void:
	super._ready()
	_logo = load(LOGO)


## What the start prompt says for the device in use.
static func start_prompt() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "PRESS GAS OR ANY WHEEL BUTTON"
		DriveInput.Kind.GAMEPAD:
			return "PRESS START"
	return "PRESS ENTER"


func handle(m: MenuInput) -> void:
	if m.confirm_pressed:
		Audio.play("beep")
		game.show_stage_select()


func _draw() -> void:
	_backdrop(0.15)
	var w := float(Cfg.SCREEN_W)
	if _logo != null:
		var bob := roundf(sin(time * 2.0) * 2.0)
		draw_texture(_logo, Vector2(roundf((w - _logo.get_width()) / 2.0), 22 + bob))
	if fmod(time, 1.0) < 0.65:
		var pill := Rect2(w / 2.0 - 130, 278, 260, 26)
		draw_rect(pill.grow(2), Color("#c9d4ff"))
		draw_rect(pill, Color("#1d3fa8"))
		_text_centered(Vector2(w / 2.0, 296), start_prompt(), 14, Color.WHITE)
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, w, 20), Color(0, 0, 0, 0.6))
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 8), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(w - 150, Cfg.SCREEN_H - 8), "F2 calibrate wheel   v" + str(ProjectSettings.get_setting("application/config/version", "")), 8, Color(1, 1, 1, 0.6))
	if game != null and game.wheel_hint != "":
		_text_centered(Vector2(w / 2.0, 326), game.wheel_hint, 10, GOLD)
