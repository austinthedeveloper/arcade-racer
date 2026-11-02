class_name TitleScreen
extends MenuScreen
## Attract screen: the logo over the Palm Coast sunset, with START (on to mode select),
## OPTIONS, STATS (MP-11) and QUIT side by side. A browser tab can't be quit, so the web build has no QUIT.
## After an update, what's new in it (WhatsNew, PR-17) is up over the title until Enter or back.

const LOGO := "res://assets/sprites/ui/logo.png"
const PILL_STEP := 160.0

var _logo: Texture2D
## What's new up over the title (WhatsNew.items), and its version; empty when it's not up.
var news: Array = []
var news_version := ""


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


func choice_count() -> int:
	return items().size()


func handle(m: MenuInput) -> void:
	if not news.is_empty():
		if m.confirm_pressed or m.back_pressed:
			Audio.play("beep")
			news = []
		return
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
	_text(Vector2(w - 150, Cfg.SCREEN_H - 8), "F2 calibrate wheel   v" + str(ProjectSettings.get_setting("application/config/version", "")), 8, Color(1, 1, 1, 0.6))
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 330), hint, 10, GOLD)
	if not news.is_empty():
		_draw_news()


## What's new: a panel over the title listing the update's additions, changes and fixes.
func _draw_news() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.7))
	var panel := Rect2(30, 22, w - 60, Cfg.SCREEN_H - 44)
	_panel(panel, 0.95)
	_text_centered(Vector2(w / 2.0, panel.position.y + 24), "WHAT'S NEW IN v" + news_version, 18, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 32, panel.size.x - 40, 2), GOLD)
	var col_w := (panel.size.x - 40) / WhatsNew.COLUMNS
	for slot: Array in WhatsNew.layout(news):
		var item: Array = slot[2]
		var at := Vector2(panel.position.x + 20 + slot[0] * col_w, panel.position.y + 52 + slot[1] * 15)
		if item[0]:
			_text(at, item[1], 10, SKY)
		else:
			draw_rect(Rect2(at + Vector2(2, -5), Vector2(3, 3)), GOLD)
			_text(at + Vector2(10, 0), item[1], 9, Color(1, 1, 1, 0.9))
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, panel.end.y - 10), "Enter: carry on", 9, Color(1, 1, 1, 0.75))
