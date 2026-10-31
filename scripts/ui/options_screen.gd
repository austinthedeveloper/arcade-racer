class_name OptionsScreen
extends MenuScreen
## Options: pages of rows, saved through the Settings autoload on every change.
## The first row is the page bar; every page ends with BACK.
## Keyboard and gamepad: up/down picks a row, left/right changes it (on the page bar, flips
## the page), confirm toggles or runs it (on the page bar, the next page). A wheel has no
## up/down, so steering picks the row and gas changes it (on the page bar, the next page).
## The two reset rows leave the wheel profiles alone; resetting the save asks first.

enum Row { PAGE, AUTO_GAS, TRAFFIC, TIMER, POWER_UPS, MUSIC, SFX, CALIBRATE, RESET_OPTIONS, RESET_SAVE, SCREEN_SHAKE,
	FLASH, UNITS, FULLSCREEN, INTEGER_SCALE, VSYNC, SCANLINES, STEER_ASSIST, BRAKE_ASSIST, BACK }
enum Page { GAME, DISPLAY, AUDIO, CONTROLS, ACCESSIBILITY }

const PAGE_NAMES := ["GAME", "DISPLAY", "AUDIO", "CONTROLS", "ACCESSIBILITY"]
## The rows between the page bar and BACK on each page.
const PAGE_ROWS := [
	[Row.AUTO_GAS, Row.TRAFFIC, Row.TIMER, Row.POWER_UPS, Row.STEER_ASSIST, Row.BRAKE_ASSIST, Row.RESET_OPTIONS,
		Row.RESET_SAVE],
	[Row.FULLSCREEN, Row.INTEGER_SCALE, Row.VSYNC, Row.SCANLINES, Row.UNITS],
	[Row.MUSIC, Row.SFX],
	[Row.CALIBRATE],
	[Row.SCREEN_SHAKE, Row.FLASH],
]
## Shown on a page with no rows yet.
const PAGE_EMPTY := ["", "", "", "", ""]
## The most rows any page has, page bar and BACK included: the panel's height.
const SLOTS := 10
const LABELS := ["PAGE", "AUTO GAS", "TRAFFIC", "TIMER", "POWER-UPS", "MUSIC VOLUME", "SOUND FX VOLUME", "CALIBRATE WHEEL",
	"RESET OPTIONS", "RESET SAVE DATA", "SCREEN SHAKE", "FLASHING", "SPEED UNITS",
	"FULLSCREEN", "INTEGER SCALING", "V-SYNC", "SCANLINES", "STEERING ASSIST", "BRAKING ASSIST", "BACK"]
const HELP := [
	"Pick a page of options.",
	"The car keeps the gas down, so you only steer. The brake still works.",
	"How many cars share the road.",
	"Time to reach each checkpoint. Relaxed gives more, Tight less.",
	"Nitro cans, clocks, ram plates and ghosts to grab on the road.",
	"Music loudness.",
	"Engine, crash and menu sound loudness.",
	"Set up a racing wheel and pedals (F2 also works).",
	"Every option, on every page, back to its default. Wheel setups are kept.",
	"Erase tour progress, best times and unlocks. Wheel setups are kept.",
	"Camera shake and the nitro view stretch. 0 turns them off.",
	"Impact flashes and the blinking clock. 0 turns them off.",
	"Miles or kilometres per hour on the speedometer.",
	"Fill the screen, or play in a window.",
	"Scale by whole steps only, for even, sharp pixels. Leaves a border.",
	"Wait for the display between frames: no tearing.",
	"Dark lines over the picture, like an old arcade monitor.",
	"Keys and pad: at speed, a gentle pull to the middle of your lane.",
	"Brakes for you into corners you're taking too fast.",
	"Back to the title screen.",
]
## The rows that show ON or OFF.
const TOGGLES := [Row.AUTO_GAS, Row.POWER_UPS, Row.INTEGER_SCALE, Row.VSYNC, Row.SCANLINES, Row.STEER_ASSIST,
	Row.BRAKE_ASSIST]
const CONFIRM_HELP := "Select again to erase your progress. Any other key cancels."
const ROW_H := 20.0
const TOP := 54.0

var page := 0  # a Page
var index := 1  # into rows(): 0 is the page bar; opens on the first option
var confirming := false  # RESET SAVE DATA was selected once; selecting it again erases
var done_row := -1  # a reset row that has just run, shown as DONE until the cursor moves


## The page called `page_name` (as in PAGE_NAMES, any case), or -1.
static func page_named(page_name: String) -> int:
	return PAGE_NAMES.find(page_name.to_upper())


## The current page's rows: the page bar, its options, BACK.
func rows() -> Array:
	return [Row.PAGE] + PAGE_ROWS[page] + [Row.BACK]


## The Row under the cursor.
func row() -> int:
	return rows()[index]


## Puts the cursor on `r`, on whichever page has it (BACK and the page bar: this page).
func go_to(r: int) -> void:
	for p in Page.size():
		if PAGE_ROWS[p].has(r):
			page = p
	index = maxi(0, rows().find(r))
	confirming = false
	done_row = -1


## Moves the cursor by `dir`, wrapping around; returns the new Row.
func move(dir: int) -> int:
	index = posmod(index + dir, rows().size())
	confirming = false
	done_row = -1
	return row()


## Flips the page by `dir`, wrapping round; the cursor stays on the page bar. Returns the page.
func flip(dir: int) -> int:
	page = posmod(page + dir, Page.size())
	index = 0
	confirming = false
	done_row = -1
	return page


## Options back to their defaults, saved. The save data and wheel profiles are untouched.
func reset_options() -> void:
	Settings.reset()
	Settings.save()
	done_row = Row.RESET_OPTIONS


## Selecting RESET SAVE DATA: the first time asks, the second erases the save (a fresh one is
## written). Options and wheel profiles are untouched. Returns true when it erased.
func select_reset_save() -> bool:
	if not confirming:
		confirming = true
		done_row = -1
		return false
	confirming = false
	SaveData.reset()
	SaveData.save()
	done_row = Row.RESET_SAVE
	return true


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
		Row.SCREEN_SHAKE:
			s.screen_shake = _step(s.screen_shake, dir, s.EFFECT_STEPS + 1, wrap)
		Row.FLASH:
			s.flash = _step(s.flash, dir, s.EFFECT_STEPS + 1, wrap)
		Row.UNITS:
			s.units = _step(s.units, dir, s.Units.size(), wrap)
		Row.FULLSCREEN:
			s.fullscreen = not s.fullscreen
		Row.INTEGER_SCALE:
			s.integer_scale = not s.integer_scale
		Row.VSYNC:
			s.vsync = not s.vsync
		Row.SCANLINES:
			s.scanlines = not s.scanlines
		Row.STEER_ASSIST:
			s.steer_assist = not s.steer_assist
		Row.BRAKE_ASSIST:
			s.brake_assist = not s.brake_assist
		_:
			return false
	s.save()
	return true


## What a row shows on the right.
static func value_text(row: int) -> String:
	var s: Node = Settings
	match row:
		Row.TRAFFIC:
			return s.TRAFFIC_NAMES[s.traffic]
		Row.TIMER:
			return s.TIMER_NAMES[s.timer]
		Row.MUSIC:
			return str(s.music_volume)
		Row.SFX:
			return str(s.sfx_volume)
		Row.SCREEN_SHAKE:
			return str(s.screen_shake)
		Row.FLASH:
			return str(s.flash)
		Row.UNITS:
			return s.UNIT_NAMES[s.units]
		Row.FULLSCREEN:
			return "FULLSCREEN" if s.fullscreen else "WINDOWED"
	if TOGGLES.has(row):
		return "ON" if toggled(row) else "OFF"
	return ""


## Whether an ON/OFF row (TOGGLES) is on.
static func toggled(row: int) -> bool:
	var s: Node = Settings
	match row:
		Row.AUTO_GAS:
			return s.auto_gas
		Row.POWER_UPS:
			return s.power_ups
		Row.INTEGER_SCALE:
			return s.integer_scale
		Row.VSYNC:
			return s.vsync
		Row.SCANLINES:
			return s.scanlines
		Row.STEER_ASSIST:
			return s.steer_assist
		Row.BRAKE_ASSIST:
			return s.brake_assist
	return false


## The right-hand text on this screen's row: values, or the reset rows' state.
func row_text(row: int) -> String:
	if row == done_row:
		return "DONE"
	if row == Row.RESET_SAVE and confirming:
		return "SURE?"
	return value_text(row)


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
	if confirming and not m.confirm_pressed and (pick != 0 or m.step() != 0 or m.back_pressed):
		confirming = false  # anything but selecting again cancels the save reset
		if pick == 0:
			Audio.play("tick")
			return
	if pick != 0:
		move(pick)
		Audio.play("tick")
	elif not wheel and m.step() != 0:
		if row() == Row.PAGE:
			flip(m.step())
			Audio.play("tick")
		elif change(row(), m.step(), false):
			Audio.play("tick")
	elif m.confirm_pressed:
		match row():
			Row.PAGE:
				flip(1)
				Audio.play("beep")
			Row.CALIBRATE:
				Audio.play("beep")
				game.calibration.open()
			Row.RESET_OPTIONS:
				reset_options()
				Audio.play("beep")
			Row.RESET_SAVE:
				select_reset_save()
				Audio.play("beep")
			Row.BACK:
				Audio.play("beep")
				game.show_title(1)
			_:
				change(row(), 1, true)
				Audio.play("beep")
	elif m.back_pressed:
		game.show_title(1)


func _draw() -> void:
	_backdrop(0.8)
	_header("OPTIONS")
	var panel := Rect2(110, TOP - 6, 420, ROW_H * SLOTS + 12)
	_frame(panel)
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.85))
	var wheel := wheel_driven()
	var mid := ROW_H / 2.0 - 2.0  # the row's vertical centre, above the gap
	var list := rows()
	if PAGE_EMPTY[page] != "":
		_text_centered(Vector2(panel.get_center().x, TOP + 2.5 * ROW_H + mid + 5), PAGE_EMPTY[page], 12, Color(1, 1, 1, 0.6))
	for i in list.size():
		var row: int = list[i]
		var slot := SLOTS - 1 if row == Row.BACK else i  # BACK sits at the bottom of every page
		var y := TOP + slot * ROW_H
		var on := i == index
		if on:
			draw_rect(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(panel.position.x, y, 3, ROW_H - 4), GOLD)
		var col := GOLD if on else Color.WHITE
		if row == Row.PAGE:
			_page_bar(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), on, wheel)
			continue
		_text(Vector2(panel.position.x + 16, y + mid + 5), LABELS[row], 12, col)
		var right := panel.end.x - 20
		match row:
			Row.MUSIC, Row.SFX, Row.SCREEN_SHAKE, Row.FLASH:
				var v := int(value_text(row))
				for k in Settings.VOLUME_STEPS:  # EFFECT_STEPS is the same ten
					var seg := Rect2(right - 150 + k * 13, y + mid - 6, 10, 12)
					draw_rect(seg, (SKY if on else Color(SKY, 0.7)) if k < v else Color(1, 1, 1, 0.12))
				_text(Vector2(right - 178, y + mid + 5), value_text(row), 10, col)
			Row.CALIBRATE, Row.BACK:
				pass
			Row.RESET_OPTIONS, Row.RESET_SAVE:
				var t := row_text(row)
				var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var warn := Color("#ff5d5d") if row == Row.RESET_SAVE and confirming else Color("#5dff8a")
				_text(Vector2(right - 60 - tw / 2.0, y + mid + 5), t, 12, warn)
			_:
				var t := value_text(row)
				var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var lit := toggled(row)
				var on_col := Color("#5dff8a") if lit else col
				_text(Vector2(right - 60 - tw / 2.0, y + mid + 5), t, 12, on_col)
				if on and not wheel:
					_small_arrow(Vector2(right - 120, y + mid), -1)
					_small_arrow(Vector2(right, y + mid), 1)
	var help: String = CONFIRM_HELP if confirming else HELP[row()]
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, panel.end.y + 20), help, 10, Color(1, 1, 1, 0.85))
	_footer(options_hints())


## The page names across row `r`, the current one lit.
func _page_bar(r: Rect2, on: bool, wheel: bool) -> void:
	var w := (r.size.x - 40.0) / Page.size()
	for p in Page.size():
		var c := Vector2(r.position.x + 20 + w * (p + 0.5), r.position.y + r.size.y / 2.0)
		if p == page:
			draw_rect(Rect2(c.x - w / 2.0 + 2, r.position.y + 2, w - 4, r.size.y - 4), Color(SKY, 0.35 if on else 0.2))
			draw_rect(Rect2(c.x - w / 2.0 + 2, r.end.y - 2, w - 4, 2), SKY)
		var col := (GOLD if on else Color.WHITE) if p == page else Color(1, 1, 1, 0.55)
		_text_centered(Vector2(c.x, c.y + 4), PAGE_NAMES[p], 10, col)
	if on and not wheel:
		_small_arrow(Vector2(r.position.x + 10, r.position.y + r.size.y / 2.0), -1)
		_small_arrow(Vector2(r.end.x - 10, r.position.y + r.size.y / 2.0), 1)


func _small_arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -6), c + Vector2(-4 * d, 6)]), GOLD)


static func _step(v: int, dir: int, n: int, wrap: bool) -> int:
	return posmod(v + dir, n) if wrap else clampi(v + dir, 0, n - 1)
