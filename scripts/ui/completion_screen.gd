class_name CompletionScreen
extends MenuScreen
## The completion page (MP-17), the stats page's third tab: what's left, stage by stage. A row
## a stage with its items (Completion.STAGE_ITEMS: finished, won, the three medals at the
## difficulty picked, won mirrored) ticked off and its percentage; beside it the whole game's
## percentage, the stickers and the cars, and the next thing to go for. Left and right go to
## the other pages, back returns to the title.

const TABLE := Rect2(16, 48, 410, 270)
const SIDE := Rect2(440, 48, 184, 270)
const ROW_Y := 88.0  # the first stage row's baseline
const ROW_H := 28.0
const NAME_X := 26.0
## The item columns' centres (STAGE_ITEMS order), and the percentage bar's left and width.
const COLS: Array[float] = [196.0, 226.0, 258.0, 280.0, 302.0, 336.0]
const COL_LABELS: Array[String] = ["FIN", "WIN", "B", "S", "G", "MIR"]
const BAR := Vector2(356, 34)
const GREEN := Color("#5dff8a")


## The page's "next up" line: the first stage with an item left, and that item
## ("GOLD  REDROCK CANYON"), or "" when everything is done.
static func next_up(save, level: int) -> Array[String]:
	for i in Stages.count():
		var item := Completion.next_item(i, save, level)
		if item != "":
			return [item, Stages.stage_name(i).to_upper()]
	return []


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		Audio.play("tick")
		game.show_records(StatsScreen.Page.COMPLETION + m.step())
	elif m.back_pressed or m.confirm_pressed:
		Audio.play("beep")
		game.show_title(TitleScreen.items().find("STATS"))


func _draw() -> void:
	_backdrop(0.8)
	_header("COMPLETION")
	StatsScreen.draw_tabs(self, StatsScreen.Page.COMPLETION)
	var level: int = Settings.difficulty
	_panel(TABLE, 0.85)
	_text(Vector2(NAME_X, TABLE.position.y + 16), "STAGE", 9, GOLD)
	for k in COLS.size():
		_text_centered(Vector2(COLS[k], TABLE.position.y + 16), COL_LABELS[k], 8, GOLD)
	_text(Vector2(BAR.x, TABLE.position.y + 16), "DONE", 9, GOLD)
	for i in Stages.count():
		var y := ROW_Y + i * ROW_H
		if i > 0:
			draw_rect(Rect2(TABLE.position.x + 8, y - 18, TABLE.size.x - 16, 1), Color(1, 1, 1, 0.1))
		var items := Completion.stage_items(i, SaveData, level)
		var pct := Completion.percent(Completion.done_count(items), items.size())
		var open := Unlocks.stage_open(i, SaveData.furthest_stage, false)
		_text(Vector2(NAME_X, y), "%d  %s" % [i + 1, Stages.stage_name(i).to_upper()], 9,
			Color.WHITE if open else Color(1, 1, 1, 0.4))
		for k in items.size():
			var c := Vector2(COLS[k], y - 3)
			if k >= 2 and k <= 4:  # the medals
				Medals.draw(self, c + Vector2(0, 2), Medals.Medal.BRONZE + k - 2 if items[k]["done"] else Medals.Medal.NONE, 5.0)
			elif items[k]["done"]:
				_tick(c)
			else:
				draw_circle(c, 2.0, Color(1, 1, 1, 0.25))
		var bar := Rect2(BAR.x, y - 8, BAR.y, 6)
		draw_rect(bar, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * pct / 100.0, bar.size.y)), GREEN if pct == 100 else GOLD)
		var t := "%d%%" % pct
		_text(Vector2(TABLE.end.x - 8 - UiText.width(t, 9), y - 1), t, 9, GREEN if pct == 100 else Color.WHITE)
	var diff: String = ["EASY", "NORMAL", "HARD"][clampi(level, 0, 2)]
	_text_centered(Vector2(TABLE.get_center().x, TABLE.end.y - 8), "Medals at " + diff + ", the difficulty picked in Options", 8, Color(1, 1, 1, 0.5))
	_side(level)
	_footer(StatsScreen.tab_hints())


## The whole game: its percentage, the parts, and the next thing to go for.
func _side(level: int) -> void:
	_panel(SIDE, 0.85)
	var cx := SIDE.get_center().x
	_text_centered(Vector2(cx, SIDE.position.y + 18), "THE WHOLE GAME", 9, GOLD)
	var all := Completion.overall(SaveData, level)
	_text_centered(Vector2(cx, SIDE.position.y + 58), "%d%%" % all, 36, GREEN if all == 100 else Color.WHITE)
	var y := SIDE.position.y + 86
	for p in Completion.parts(SaveData, level):
		var n := "%d / %d" % [p["done"], p["total"]]
		_text(Vector2(SIDE.position.x + 12, y), p["label"], 10, Color(1, 1, 1, 0.8))
		_text(Vector2(SIDE.end.x - 12 - UiText.width(n, 10), y), n, 10, Color.WHITE)
		var bar := Rect2(SIDE.position.x + 12, y + 5, SIDE.size.x - 24, 4)
		draw_rect(bar, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(p["done"]) / maxf(1.0, float(p["total"])), bar.size.y)), GOLD)
		y += 30
	draw_rect(Rect2(SIDE.position.x + 10, y - 6, SIDE.size.x - 20, 1), Color(1, 1, 1, 0.15))
	var tour := SaveData.is_unlocked(Tour.FINISH_UNLOCK)
	_text(Vector2(SIDE.position.x + 12, y + 10), "GRAND TOUR", 10, Color(1, 1, 1, 0.8))
	var tt := "DONE" if tour else "STAGE %d" % (SaveData.furthest_stage + 1)
	_text(Vector2(SIDE.end.x - 12 - UiText.width(tt, 10), y + 10), tt, 10, GREEN if tour else Color.WHITE)
	var next := next_up(SaveData, level)
	_text(Vector2(SIDE.position.x + 12, y + 36), "NEXT UP", 9, GOLD)
	if next.is_empty():
		_text(Vector2(SIDE.position.x + 12, y + 52), "Nothing left. Take a bow.", 9, Color.WHITE)
	else:
		_text(Vector2(SIDE.position.x + 12, y + 52), next[0], 12, Color.WHITE)
		_text(Vector2(SIDE.position.x + 12, y + 66), next[1], 9, Color(1, 1, 1, 0.75))


## A green tick centred on `c`.
func _tick(c: Vector2) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3), c + Vector2(4, -3)]), GREEN, 2.0)
