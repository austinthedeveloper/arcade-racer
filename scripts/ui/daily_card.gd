class_name DailyCard
extends MenuScreen
## The daily run's card (MP-14), from DAILY RUN on mode select and back after each try: the
## day, its stage (the postcard), car (the showroom picture), weather and traffic, and your
## tries today with the best times. Confirm races it; back goes to mode select.

const POSTCARD := Rect2(16, 52, 288, 162)
const CAR_PANEL := Rect2(320, 52, 304, 162)
const TRIES := Rect2(16, 226, 608, 104)

var day := 0  # Daily.day_key of the run shown
var pick := {}  # Daily.pick(day)
var _postcard: Texture2D
var _car: Texture2D


func _ready() -> void:
	super._ready()
	if day <= 0:
		day = Daily.today()
	if pick.is_empty():
		pick = Daily.pick(day)
	_postcard = load(Stages.postcard(int(pick["stage"])))
	_car = load(Cars.picture(Cars.find(pick["car"])))


func handle(m: MenuInput) -> void:
	if m.confirm_pressed:
		Audio.play("go")
		game.start_race()
	elif m.back_pressed:
		game.show_mode_select(ModeSelect.Item.DAILY_RUN)


## The card's words for the run `p` on `day` with `kept` (SaveData.daily): {"date", "stage",
## "car", "weather", "traffic", "tries" (a line), "times" (up to Daily.BEST_TRIES lines)}.
static func lines(p: Dictionary, on_day: int, kept: Dictionary) -> Dictionary:
	var stage := int(p["stage"])
	var tries := Daily.tries_on(kept, on_day)
	var n := int(tries["tries"])
	var times: Array[String] = []
	var t: Array = tries["times"]
	for i in t.size():
		times.append("%d.  %s" % [i + 1, Hud.clock_text(float(t[i]))])
	var said := "NO TRIES YET TODAY" if n == 0 else ("1 TRY TODAY" if n == 1 else "%d TRIES TODAY" % n)
	return {
		"date": Daily.date_text(on_day),
		"stage": Stages.stage_name(stage).to_upper(),
		"stage_no": "STAGE %d" % (stage + 1),
		"car": String(Cars.find(p["car"])["name"]).to_upper(),
		"weather": Daily.sky_name(p, Weather.of(Stages.theme(stage))),
		"traffic": Daily.mix_name(p),
		"tries": said,
		"times": times,
	}


func _draw() -> void:
	_backdrop(0.78)
	_header("DAILY RUN")
	var t := lines(pick, day, SaveData.daily)
	var dw := UiText.width(t["date"], 12)
	_text(Vector2(Cfg.SCREEN_W - 16 - dw, 30), t["date"], 12, GOLD)

	# The stage, on its postcard
	_frame(POSTCARD, Color(GOLD, 0.25 + 0.1 * sin(time * 3.0)))
	if _postcard != null:
		draw_texture_rect(_postcard, POSTCARD, false)
	var band := Rect2(POSTCARD.position.x, POSTCARD.end.y - 30, POSTCARD.size.x, 30)
	draw_rect(band, Color(0, 0, 0, 0.68))
	_text(Vector2(band.position.x + 8, band.position.y + 12), t["stage_no"], 9, GOLD)
	_text(Vector2(band.position.x + 8, band.end.y - 5), t["stage"], 12, Color.WHITE)

	# The car, the weather and the traffic
	_panel(CAR_PANEL, 0.85)
	var pic := Rect2(CAR_PANEL.position.x + 8, CAR_PANEL.position.y + 8, 176, 82)
	if _car != null:
		draw_texture_rect(_car, pic, false)
	var x := CAR_PANEL.position.x + 194
	_text(Vector2(x, CAR_PANEL.position.y + 22), "CAR", 9, GOLD)
	_text(Vector2(x, CAR_PANEL.position.y + 38), t["car"], 11, Color.WHITE)
	_text(Vector2(x, CAR_PANEL.position.y + 60), "WEATHER", 9, GOLD)
	_text(Vector2(x, CAR_PANEL.position.y + 76), t["weather"], 11, Color.WHITE)
	var y := CAR_PANEL.position.y + 104
	_text(Vector2(CAR_PANEL.position.x + 12, y), "TRAFFIC", 9, GOLD)
	_text(Vector2(CAR_PANEL.position.x + 12, y + 16), t["traffic"], 11, Color.WHITE)
	_text(Vector2(x, y), "RIVALS", 9, GOLD)
	_text(Vector2(x, y + 16), "NONE: THE CLOCK", 11, Color.WHITE)
	_text(Vector2(CAR_PANEL.position.x + 12, CAR_PANEL.end.y - 10), "The same run for everyone, all day.", 9, Color(1, 1, 1, 0.65))

	# Your tries today
	_panel(TRIES, 0.8)
	_text(Vector2(TRIES.position.x + 12, TRIES.position.y + 18), "YOUR BEST TODAY", 10, GOLD)
	_text(Vector2(TRIES.position.x + 12, TRIES.position.y + 34), t["tries"], 9, Color(1, 1, 1, 0.75))
	var times: Array[String] = t["times"]
	if times.is_empty():
		_text(Vector2(TRIES.position.x + 200, TRIES.position.y + 56), "Finish inside the clock to set a time.", 11, Color(1, 1, 1, 0.8))
	for i in times.size():
		var col := GOLD if i == 0 else Color.WHITE
		_text(Vector2(TRIES.position.x + 200 + i * 136, TRIES.position.y + 56), times[i], 14 if i == 0 else 12, col)
	var pulse := 0.6 + 0.4 * sin(time * 5.0)
	_text_centered(Vector2(TRIES.get_center().x + 94, TRIES.end.y - 14), "PRESS ENTER TO RACE" if InputRouter.state.kind == DriveInput.Kind.KEYBOARD else "PRESS A TO RACE", 12, Color(GOLD, pulse))
	_footer(hints(false))
