class_name StickerScreen
extends MenuScreen
## The sticker book (MP-12), the stats page's second tab: the twenty-four stickers (Stickers.ALL)
## on a grid, the ones earned in their colors (SaveData.stickers), the rest dim with a "?".
## The cursor starts on the tab bar, where left and right go to the other pages; down goes
## into the grid, where the arrows pick a sticker and the panel under it says what it is, how
## it's earned and when it was. Up from the top row goes back to the tabs. Back returns to the
## title.

const COLS := 8
const CELL := Vector2(72, 62)
const GRID := Vector2(32, 48)  # the grid's top left
const RADIUS := 21.0
const INFO := Rect2(32, 246, 576, 72)  # the panel about the sticker under the cursor
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


func _init() -> void:
	index = -1  # on the tab bar


func choice_count() -> int:
	return Stickers.count()


## Where the cursor goes from `at` (-1: the tab bar) for a press of `dx` across or `dy` down:
## across wraps within a row, up from the top row is the tab bar, down from it the first row.
static func step_from(at: int, dx: int, dy: int) -> int:
	var rows := ceili(float(Stickers.count()) / COLS)
	if at < 0:
		return 0 if dy > 0 else -1
	var row := at / COLS
	var col := at % COLS
	if dx != 0:
		col = posmod(col + dx, COLS)
	if dy < 0:
		if row == 0:
			return -1
		row -= 1
	elif dy > 0:
		row = mini(row + 1, rows - 1)
	return mini(row * COLS + col, Stickers.count() - 1)


## Sticker `i`'s centre on the page.
static func cell_center(i: int) -> Vector2:
	return GRID + Vector2((i % COLS + 0.5) * CELL.x, (i / COLS + 0.5) * CELL.y)


## When a sticker was earned, as the panel says it: "EARNED 11 NOV 2026" (UTC; "EARNED" alone
## for no date).
static func earned_text(unix: int) -> String:
	if unix <= 0:
		return "EARNED"
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "EARNED %d %s %d" % [d["day"], MONTHS[int(d["month"]) - 1], d["year"]]


## The count line: "11 / 24 STICKERS".
static func count_text(have: int) -> String:
	return "%d / %d" % [have, Stickers.count()]


func handle(m: MenuInput) -> void:
	if m.back_pressed:
		Audio.play("beep")
		game.show_title(TitleScreen.items().find("STATS"))
		return
	if index < 0 and m.step() != 0:
		Audio.play("tick")
		game.show_records(StatsScreen.Page.STICKERS + m.step())
		return
	var dy := m.step_y()
	if index < 0 and m.confirm_pressed:
		dy = 1  # (select on the tabs: into the grid)
	if m.step() != 0 or dy != 0:
		var to := step_from(index, m.step(), dy)
		if to != index:
			index = to
			Audio.play("tick")


func _draw() -> void:
	_backdrop(0.8)
	_header("STICKERS")
	var have := Completion.sticker_count(SaveData)
	_text(Vector2(262, 30), count_text(have), 14, Color.WHITE)
	StatsScreen.draw_tabs(self, StatsScreen.Page.STICKERS, index < 0)
	_panel(Rect2(GRID, CELL * Vector2(COLS, 3)), 0.6)
	for i in Stickers.count():
		var id: String = Stickers.ALL[i]["id"]
		var c := cell_center(i)
		if i == index:
			var r := Rect2(c - CELL / 2.0 + Vector2(3, 3), CELL - Vector2(6, 6))
			draw_rect(r.grow(2), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
			draw_rect(r, Color("#1d3fa8"))
		var bob := sin(time * 4.0) * 1.5 if i == index else 0.0
		Stickers.draw(self, c + Vector2(0, bob), id, RADIUS, SaveData.has_sticker(id), Stickers.tilt(i))
	_info()
	_footer(StatsScreen.tab_hints("Down: the stickers") if index < 0 else
		("D-pad: choose    B: back" if InputRouter.state.kind != DriveInput.Kind.KEYBOARD else "Arrows: choose    Esc: back"))


## The panel under the grid: the sticker under the cursor, or how many are left.
func _info() -> void:
	_panel(INFO, 0.85)
	if index < 0:
		var left := Stickers.count() - Completion.sticker_count(SaveData)
		var line := "Every sticker found. Nice driving." if left == 0 else "%d to find. Each one comes once, with a chime." % left
		_text_centered(Vector2(INFO.get_center().x, INFO.position.y + 32), line, 12, Color.WHITE)
		_text_centered(Vector2(INFO.get_center().x, INFO.position.y + 52), "Down to look through them", 9, Color(1, 1, 1, 0.55))
		return
	var s: Dictionary = Stickers.ALL[index]
	var have := SaveData.has_sticker(s["id"])
	Stickers.draw(self, INFO.position + Vector2(40, INFO.size.y / 2.0), s["id"], 26.0, have, -0.08)
	var x := INFO.position.x + 84
	_text(Vector2(x, INFO.position.y + 24), s["name"], 16, GOLD if have else Color(1, 1, 1, 0.6))
	_text(Vector2(x, INFO.position.y + 44), s["how"], 11, Color.WHITE)
	var when := earned_text(int(SaveData.stickers[s["id"]])) if have else "NOT YET"
	_text(Vector2(x, INFO.position.y + 62), when, 9, Color("#5dff8a") if have else Color(1, 1, 1, 0.45))
	var n := "%d / %d" % [index + 1, Stickers.count()]
	_text(Vector2(INFO.end.x - 12 - UiText.width(n, 9), INFO.position.y + 62), n, 9, Color(1, 1, 1, 0.45))
