class_name OptionsScreen
extends MenuScreen
## Options: a list of rows, saved through the Settings autoload on every change.
## Keyboard and gamepad: up/down picks a row, left/right changes it, confirm toggles or
## runs it. A wheel has no up/down, so steering picks the row and gas changes it.

enum Row { AUTO_GAS, TRAFFIC, TIMER, POWER_UPS, MUSIC, SFX, CALIBRATE, BACK }

const LABELS := ["AUTO GAS", "TRAFFIC", "TIMER", "POWER-UPS", "MUSIC VOLUME", "SOUND FX VOLUME", "CALIBRATE WHEEL", "BACK"]
const HELP := [
	"The car keeps the gas down, so you only steer. The brake still works.",
	"How many cars share the road.",
	"Time to reach each checkpoint. Relaxed gives more, Tight less.",
	"Nitro cans, clocks, ram plates and ghosts to grab on the road.",
	"Music loudness.",
	"Engine, crash and menu sound loudness.",
	"Set up a racing wheel and pedals (F2 also works).",
	"Back to the title screen.",
]
const ROW_H := 28.0
const TOP := 58.0

var index := 0  # into Row


## Moves the cursor by `dir`, wrapping around; returns the new row.
func move(dir: int) -> int:
	index = posmod(index + dir, Row.size())
	return index


## Changes the row by `dir` and saves. `wrap` (confirm) cycles round; left/right stops at
## the ends. Returns false for rows that hold no value.
func change(row: int, dir: int, wrap: bool) -> bool:
	var s: Node = Settings
	match row:
		Row.AUTO_GAS:
			s.auto_gas = not s.auto_gas
		Row.TRAFFIC:
			s.traffic = _step(s.traffic, dir, s.Traffic.size(), wrap)
		Row.TIMER:
			s.timer = _step(s.timer, dir, s.Clock.size(), wrap)
		Row.POWER_UPS:
			s.power_ups = not s.power_ups
		Row.MUSIC:
			s.music_volume = _step(s.music_volume, dir, s.VOLUME_STEPS + 1, wrap)
		Row.SFX:
			s.sfx_volume = _step(s.sfx_volume, dir, s.VOLUME_STEPS + 1, wrap)
		_:
			return false
	s.save()
	return true


## What a row shows on the right.
static func value_text(row: int) -> String:
	var s: Node = Settings
	match row:
		Row.AUTO_GAS:
			return "ON" if s.auto_gas else "OFF"
		Row.TRAFFIC:
			return s.TRAFFIC_NAMES[s.traffic]
		Row.TIMER:
			return s.TIMER_NAMES[s.timer]
		Row.POWER_UPS:
			return "ON" if s.power_ups else "OFF"
		Row.MUSIC:
			return str(s.music_volume)
		Row.SFX:
			return str(s.sfx_volume)
	return ""


## Control hints for this screen, worded for the device in use.
static func options_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "Steer: choose    Gas: change    Brake: back"
		DriveInput.Kind.GAMEPAD:
			return "D-pad Up / Down: choose    Left / Right: change    A: select    B: back"
	return "Up / Down: choose    Left / Right: change    Enter: select    Esc: back"


static func wheel_driven() -> bool:
	return InputRouter.state.kind == DriveInput.Kind.WHEEL


func handle(m: MenuInput) -> void:
	var wheel := wheel_driven()
	var pick := m.step() if wheel else m.step_y()
	if pick != 0:
		move(pick)
		Audio.play("tick")
	elif not wheel and m.step() != 0:
		if change(index, m.step(), false):
			Audio.play("tick")
	elif m.confirm_pressed:
		match index:
			Row.CALIBRATE:
				Audio.play("beep")
				game.calibration.open()
			Row.BACK:
				Audio.play("beep")
				game.show_title(1)
			_:
				change(index, 1, true)
				Audio.play("beep")
	elif m.back_pressed:
		game.show_title(1)


func _draw() -> void:
	_backdrop(0.8)
	_header("OPTIONS")
	var panel := Rect2(110, TOP - 6, 420, ROW_H * Row.size() + 12)
	_frame(panel)
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.85))
	var wheel := wheel_driven()
	for row in Row.size():
		var y := TOP + row * ROW_H
		var on := row == index
		if on:
			draw_rect(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(panel.position.x, y, 3, ROW_H - 4), GOLD)
		var col := GOLD if on else Color.WHITE
		_text(Vector2(panel.position.x + 16, y + 17), LABELS[row], 12, col)
		var right := panel.end.x - 20
		match row:
			Row.MUSIC, Row.SFX:
				var v: int = Settings.music_volume if row == Row.MUSIC else Settings.sfx_volume
				for i in Settings.VOLUME_STEPS:
					var seg := Rect2(right - 150 + i * 13, y + 6, 10, 12)
					draw_rect(seg, (SKY if on else Color(SKY, 0.7)) if i < v else Color(1, 1, 1, 0.12))
				_text(Vector2(right - 178, y + 17), value_text(row), 10, col)
			Row.CALIBRATE, Row.BACK:
				pass
			_:
				var t := value_text(row)
				var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var lit := (row == Row.AUTO_GAS and Settings.auto_gas) or (row == Row.POWER_UPS and Settings.power_ups)
				var on_col := Color("#5dff8a") if lit else col
				_text(Vector2(right - 60 - tw / 2.0, y + 17), t, 12, on_col)
				if on and not wheel:
					_small_arrow(Vector2(right - 120, y + 12), -1)
					_small_arrow(Vector2(right, y + 12), 1)
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, panel.end.y + 24), HELP[index], 10, Color(1, 1, 1, 0.85))
	_footer(options_hints())


func _small_arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -6), c + Vector2(-4 * d, 6)]), GOLD)


static func _step(v: int, dir: int, n: int, wrap: bool) -> int:
	return posmod(v + dir, n) if wrap else clampi(v + dir, 0, n - 1)
