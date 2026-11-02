class_name TitleScreen
extends MenuScreen
## Attract screen: the logo over the Palm Coast sunset, with START (on to mode select),
## OPTIONS, STATS (MP-11), PROFILE (MP-10: who is driving) and QUIT side by side. A browser
## tab can't be quit, so the web build has no QUIT. The driver's avatar and name show top left.

const LOGO := "res://assets/sprites/ui/logo.png"
const PILL_STEP := 124.0
const PILL := Vector2(112, 26)
const DRIVER := Rect2(8, 8, 150, 34)  # who is driving (MP-10), top left
const DRIVER_PIC := Vector2(56, 26)

var _logo: Texture2D
var _avatar: Texture2D
var _avatar_id := ""


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
	var out: Array[String] = ["START", "OPTIONS", "STATS", "PROFILE"]
	if not web:
		out.append("QUIT")
	return out


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
			"PROFILE":
				game.show_profiles()
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
		var pill := Rect2(w / 2.0 - names.size() * PILL_STEP / 2.0 + (PILL_STEP - PILL.x) / 2.0 + i * PILL_STEP, 270, PILL.x, PILL.y)
		var on := i == index
		if on:
			draw_rect(pill.grow(4), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
		draw_rect(pill.grow(2), Color("#c9d4ff") if on else Color(1, 1, 1, 0.35))
		draw_rect(pill, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.85))
		_text_centered(Vector2(pill.get_center().x, 288), names[i], 14, Color.WHITE if on else Color(1, 1, 1, 0.55))
	_draw_driver()
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, 314), start_prompt(), 10, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, w, 20), Color(0, 0, 0, 0.6))
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 8), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(w - 150, Cfg.SCREEN_H - 8), "F2 calibrate wheel   v" + str(ProjectSettings.get_setting("application/config/version", "")), 8, Color(1, 1, 1, 0.6))
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 330), hint, 10, GOLD)


## The words in the driver badge: who is driving and which profile slot (P1 to P4).
static func driver_text() -> Array[String]:
	return ["DRIVER  P%d" % (SaveData.slot + 1), SaveData.profile_name]


## Who is driving (MP-10): the profile's avatar and name, top left.
func _draw_driver() -> void:
	if _avatar_id != SaveData.avatar:
		_avatar_id = SaveData.avatar
		_avatar = load(Cars.picture(Cars.find(_avatar_id)))
	draw_rect(DRIVER, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(DRIVER.position.x, DRIVER.end.y, DRIVER.size.x, 2), GOLD)
	var pic := Rect2(DRIVER.position + Vector2(4, 4), DRIVER_PIC)
	draw_rect(pic, Color(0.1, 0.12, 0.3, 0.9))
	if _avatar != null:
		var k := minf(pic.size.x / _avatar.get_width(), pic.size.y / _avatar.get_height())
		var size := Vector2(_avatar.get_width(), _avatar.get_height()) * k
		draw_texture_rect(_avatar, Rect2(pic.get_center() - size / 2.0, size), false)
	draw_rect(pic, Color("#c9d4ff", 0.6), false, 1.0)
	var words := driver_text()
	_text(Vector2(pic.end.x + 8, DRIVER.position.y + 14), words[0], 8, Color(1, 1, 1, 0.65))
	_text(Vector2(pic.end.x + 8, DRIVER.position.y + 30), words[1], 14, GOLD)
