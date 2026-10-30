class_name Hud
extends Control
## In-race HUD: timer, route progress, nitro, speedometer and center banners.

var race: Node  # race.gd
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if race == null or race.player == null:
		return
	var p: PlayerCar = race.player
	var w := float(Cfg.SCREEN_W)

	# Time, top left
	_text(Vector2(12, 18), "TIME", 10, Color("#ffd23a"))
	var t: float = race.time_left
	var tcol := Color("#ff4040") if t < 10.0 and int(t * 4.0) % 2 == 0 else Color.WHITE
	_text(Vector2(12, 46), str(ceili(t)), 30, tcol)

	# Route progress, top center
	var bar := Rect2(w / 2.0 - 110, 12, 220, 8)
	draw_rect(bar.grow(2), Color(0, 0, 0, 0.55))
	var progress := clampf(p.distance / race.finish_distance, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("#3ad0ff"))
	for d in race.checkpoint_distances:
		var cx: float = bar.position.x + bar.size.x * clampf(d / race.finish_distance, 0.0, 1.0)
		draw_rect(Rect2(cx - 1, bar.position.y - 3, 2, bar.size.y + 6), Color("#ffd23a"))
	draw_rect(Rect2(bar.end.x - 2, bar.position.y - 3, 4, bar.size.y + 6), Color.WHITE)
	_text(Vector2(bar.position.x, bar.end.y + 14), ("STAGE %d  " % (race.stage_index + 1)) + race.track.name.to_upper(), 9, Color(1, 1, 1, 0.85))

	# Nitro, top right
	_text(Vector2(w - 92, 18), "NITRO", 10, Color("#ffd23a"))
	for i in Cfg.NITRO_CHARGES:
		var cx := w - 88 + i * 18
		var lit := i < p.nitro_charges
		var col := Color("#ff7a1a") if lit else Color(1, 1, 1, 0.2)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, 38), Vector2(cx + 6, 24), Vector2(cx + 12, 38)]), col)
		if lit:
			draw_colored_polygon(PackedVector2Array([Vector2(cx + 3, 38), Vector2(cx + 6, 30), Vector2(cx + 9, 38)]), Color("#ffe36a"))
	if p.nitro_time > 0.0:
		draw_rect(Rect2(w - 90, 42, 76 * p.nitro_time / Cfg.NITRO_DURATION, 3), Color("#7ad8ff"))

	# Speedometer, bottom right
	var center := Vector2(w - 58, Cfg.SCREEN_H - 20)
	var pct := clampf(p.speed / (Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT), 0.0, 1.0)
	draw_arc(center, 44, PI, TAU, 24, Color(0, 0, 0, 0.55), 10)
	draw_arc(center, 44, PI, PI + PI * pct, 24, Color("#ff5a2a") if pct > 0.8 else Color("#3ad0ff"), 6)
	var mph := roundi(p.speed / Cfg.MAX_SPEED * Cfg.DISPLAY_TOP_SPEED)
	_text_centered(Vector2(center.x, center.y - 4), str(mph), 22, Color.WHITE)
	_text_centered(Vector2(center.x, center.y + 10), "MPH", 8, Color("#ffd23a"))

	# Device, bottom left
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 20), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(10, Cfg.SCREEN_H - 8), "F1 input debug   F2 calibrate wheel   R restart", 8, Color(1, 1, 1, 0.45))
	if race.wheel_hint != "":
		_text_centered(Vector2(w / 2.0, 70), race.wheel_hint, 10, Color("#ffd23a"))

	# Banners
	if race.counting_down():
		_text_centered(Vector2(w / 2.0, 130), str(ceili(race.countdown)), 64, Color("#ffd23a"))
	if race.banner != "" and race.banner_time > 0.0:
		_text_centered(Vector2(w / 2.0, 130), race.banner, 44, Color("#ffd23a"))
		if race.banner_sub != "":
			_text_centered(Vector2(w / 2.0, 156), race.banner_sub, 14, Color.WHITE)
	if race.paused:
		draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(0, 0, 0, 0.5))
		_text_centered(Vector2(w / 2.0, 150), "PAUSED", 40, Color.WHITE)
		_text_centered(Vector2(w / 2.0, 176), "Esc / Start to resume    R / Back to restart", 12, Color(1, 1, 1, 0.8))
		_text_centered(Vector2(w / 2.0, 194), "Backspace / B / brake to quit to the title screen", 12, Color(1, 1, 1, 0.8))


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 6), Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(pos.x - width / 2.0, pos.y), s, size, col)
