class_name StatsScreen
extends MenuScreen
## The stats page (MP-11), from STATS on the title: races, wins, crashes, near misses and
## miles from the save (SaveData.stats), with the favourite car's showroom picture and the
## favourite stage's postcard. Back (or select) returns to the title.
## It is the first of three tabs (PAGES): left and right go on to the sticker book
## (StickerScreen, MP-12) and the completion page (CompletionScreen, MP-17), which share the
## tab bar (draw_tabs) and go back to the title the same way.

enum Page { STATS, STICKERS, COMPLETION }
const PAGES: Array[String] = ["STATS", "STICKERS", "COMPLETION"]
const TAB_Y := 14.0  # the tab bar's top, right of the header
const TAB_H := 18.0

const PANEL := Rect2(20, 54, 290, 232)
const ROW_H := 30.0
const CAR_PIC := Rect2(338, 70, 243, 113)  # the showroom picture, at 0.8
const POSTCARD := Rect2(338, 226, 112, 63)

var _car_pic: Texture2D
var _postcard: Texture2D


func _ready() -> void:
	super._ready()
	var car := SaveData.favourite_car()
	if car != "":
		_car_pic = load(Cars.picture(Cars.find(car)))
	var stage := SaveData.favourite_stage()
	if stage >= 0:
		_postcard = load(Stages.postcard(stage))


## The page's number rows: {"label", "value"} for races, wins (with the share of races won),
## crashes, near misses and the distance driven in `units` (Settings.Units).
static func rows(stats: Dictionary, units: int) -> Array[Dictionary]:
	var races := int(stats.get("races", 0))
	var wins := int(stats.get("wins", 0))
	var share := "   (%d%%)" % roundi(100.0 * wins / races) if races > 0 else ""
	var miles := float(stats.get("miles", 0.0))
	var distance := "%.1f KM" % (miles * Settings.KPH_PER_MPH) if units == Settings.Units.KPH else "%.1f MI" % miles
	return [
		{"label": "RACES", "value": str(races)},
		{"label": "WINS", "value": str(wins) + share},
		{"label": "CRASHES", "value": str(int(stats.get("crashes", 0)))},
		{"label": "NEAR MISSES", "value": str(int(stats.get("near_misses", 0)))},
		{"label": "DISTANCE", "value": distance},
	]


## The favourite car's and stage's names as the page shows them, "-" before any race.
static func favourites(car_id: String, stage: int) -> Array[String]:
	return [String(Cars.find(car_id)["name"]).to_upper() if car_id != "" else "-",
		Stages.stage_name(stage).to_upper() if stage >= 0 else "-"]


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		Audio.play("tick")
		game.show_records(Page.STATS + m.step())
	elif m.back_pressed or m.confirm_pressed:
		Audio.play("beep")
		game.show_title(TitleScreen.items().find("STATS"))


## The tabs' rectangles, right-aligned along the top: one per PAGES.
static func tab_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x := Cfg.SCREEN_W - 22.0  # (room for the right arrow)
	for i in range(PAGES.size() - 1, -1, -1):
		var w := MenuScreen._width(PAGES[i], 10) + 18.0
		x -= w
		out.push_front(Rect2(x, TAB_Y, w, TAB_H))
		x -= 6.0
	return out


## The tab bar on `screen`, `on` (a Page) lit; `lit` pulses it, for a cursor on the bar.
static func draw_tabs(screen: MenuScreen, on: int, lit := false) -> void:
	var rects := tab_rects()
	screen._arrow(Vector2(rects[0].position.x - 12, TAB_Y + TAB_H / 2.0), -1, Color(1, 1, 1, 0.55))
	screen._arrow(Vector2(rects[-1].end.x + 6, TAB_Y + TAB_H / 2.0), 1, Color(1, 1, 1, 0.55))
	for i in rects.size():
		var r := rects[i]
		var here := i == on
		if here and lit:
			screen.draw_rect(r.grow(3), Color(GOLD, 0.45 + 0.2 * sin(screen.time * 5.0)))
		screen.draw_rect(r.grow(1), Color("#c9d4ff") if here else Color(1, 1, 1, 0.3))
		screen.draw_rect(r, Color("#1d3fa8") if here else Color(0.07, 0.07, 0.2, 0.85))
		screen._text_centered(Vector2(r.get_center().x, r.position.y + 13), PAGES[i], 10, Color.WHITE if here else Color(1, 1, 1, 0.55))


## The footer on the three pages: the tabs, then back.
static func tab_hints(extra := "") -> String:
	var pad := InputRouter.state.kind != DriveInput.Kind.KEYBOARD
	var parts: Array[String] = [("D-pad" if pad else "Left / Right") + ": pages"]
	if extra != "":
		parts.append(extra)
	parts.append("B: back" if pad else "Esc: back")
	return "    ".join(parts)


func _draw() -> void:
	_backdrop(0.8)
	_header("STATS")
	draw_tabs(self, Page.STATS)
	_panel(PANEL, 0.85)
	var list := rows(SaveData.stats, Settings.units)
	for i in list.size():
		var y := PANEL.position.y + 26 + i * ROW_H
		if i > 0:
			draw_rect(Rect2(PANEL.position.x + 10, y - 20, PANEL.size.x - 20, 1), Color(1, 1, 1, 0.12))
		_text(Vector2(PANEL.position.x + 14, y), list[i]["label"], 11, Color(1, 1, 1, 0.75))
		var v: String = list[i]["value"]
		_text(Vector2(PANEL.end.x - 14 - _width(v, 16), y + 1), v, 16, GOLD if i < 2 else Color.WHITE)
	var since := "Kept since this save began" if int(SaveData.stats["races"]) > 0 else "Race to start the count"
	_text_centered(Vector2(PANEL.get_center().x, PANEL.end.y - 12), since, 9, Color(1, 1, 1, 0.5))

	var fav := favourites(SaveData.favourite_car(), SaveData.favourite_stage())
	_text(Vector2(CAR_PIC.position.x, CAR_PIC.position.y - 8), "FAVOURITE CAR", 10, GOLD)
	_frame(CAR_PIC)
	draw_rect(CAR_PIC, UiText.ink(0.85))
	if _car_pic != null:
		draw_texture_rect(_car_pic, CAR_PIC, false)
	_text(Vector2(CAR_PIC.position.x, CAR_PIC.end.y + 14), fav[0], 12, Color.WHITE)
	_text(Vector2(POSTCARD.position.x, POSTCARD.position.y - 8), "FAVOURITE STAGE", 10, GOLD)
	_frame(POSTCARD)
	draw_rect(POSTCARD, UiText.ink(0.85))
	if _postcard != null:
		draw_texture_rect(_postcard, POSTCARD, false)
	_text(Vector2(POSTCARD.end.x + 10, POSTCARD.position.y + 36), fav[1], 10, Color.WHITE)
	_footer(tab_hints())
