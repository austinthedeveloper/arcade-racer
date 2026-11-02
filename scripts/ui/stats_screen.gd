class_name StatsScreen
extends MenuScreen
## The stats page (MP-11), from STATS on the title: races, wins, crashes, near misses and
## miles from the save (SaveData.stats), with the favourite car's showroom picture and the
## favourite stage's postcard. Back (or select) returns to the title.

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
	if m.back_pressed or m.confirm_pressed:
		Audio.play("beep")
		game.show_title(TitleScreen.items().find("STATS"))


func _draw() -> void:
	_backdrop(0.8)
	_header("STATS")
	_panel(PANEL, 0.85)
	var list := rows(SaveData.stats, Settings.units)
	for i in list.size():
		var y := PANEL.position.y + 26 + i * ROW_H
		if i > 0:
			draw_rect(Rect2(PANEL.position.x + 10, y - 20, PANEL.size.x - 20, 1), Color(1, 1, 1, 0.12))
		_text(Vector2(PANEL.position.x + 14, y), list[i]["label"], 11, Color(1, 1, 1, 0.75))
		var v: String = list[i]["value"]
		_text(Vector2(PANEL.end.x - 14 - UiText.width(v, 16), y + 1), v, 16, GOLD if i < 2 else Color.WHITE)
	var since := "Kept since this save began" if int(SaveData.stats["races"]) > 0 else "Race to start the count"
	_text_centered(Vector2(PANEL.get_center().x, PANEL.end.y - 12), since, 9, Color(1, 1, 1, 0.5))

	var fav := favourites(SaveData.favourite_car(), SaveData.favourite_stage())
	_text(Vector2(CAR_PIC.position.x, CAR_PIC.position.y - 8), "FAVOURITE CAR", 10, GOLD)
	_frame(CAR_PIC)
	draw_rect(CAR_PIC, Color(0.04, 0.03, 0.1, 0.85))
	if _car_pic != null:
		draw_texture_rect(_car_pic, CAR_PIC, false)
	_text(Vector2(CAR_PIC.position.x, CAR_PIC.end.y + 14), fav[0], 12, Color.WHITE)
	_text(Vector2(POSTCARD.position.x, POSTCARD.position.y - 8), "FAVOURITE STAGE", 10, GOLD)
	_frame(POSTCARD)
	draw_rect(POSTCARD, Color(0.04, 0.03, 0.1, 0.85))
	if _postcard != null:
		draw_texture_rect(_postcard, POSTCARD, false)
	_text(Vector2(POSTCARD.end.x + 10, POSTCARD.position.y + 36), fav[1], 10, Color.WHITE)
	_footer("Esc: back" if InputRouter.state.kind == DriveInput.Kind.KEYBOARD else "B: back")
