class_name TourFinale
extends MenuScreen
## The Grand Tour's ending (MP-16): finishing the last stage of a tour leads here instead of
## stage select. First the podium on the Skyline bridge (the top three's cars on the steps
## under the bridge's pylons, fireworks over the harbor), then the tour standings, then the
## end card for where the player finished overall (end_card: the champion, a podium place
## or the rest), then the credits over the harbor (CreditsScreen.harbor). Each page waits for
## select, so nobody has to read the standings against a clock (AC-17); back skips to the
## credits.

enum Page { PODIUM, STANDINGS, CARD }

const SKY_TOP := Color("#24124a")  # Skyline's sky (stages/skyline.gd)
const SKY_BOTTOM := Color("#f2875a")
const WATER := Color("#22307a")
const HORIZON := 196.0  # where the city meets the water
const BACKGROUNDS := "res://assets/sprites/backgrounds/skyline_%s.png"
const PYLON := "res://assets/sprites/spans/skyline_pylon.png"
const PYLON_SCALE := 0.78
const DECK_Y := 292.0  # the bridge deck's far edge
## The podium's steps, 1st, 2nd, 3rd: the middle of each step's top, and its height.
const STEPS := [Vector2(320, 278), Vector2(200, 294), Vector2(440, 304)]
const STEP_W := 112.0
const BASE_Y := 340.0
const CAR_W := 84.0  # the cars' body width on the steps, seen from behind as in the race
const STEP_COLORS := [Color("#ffd23a"), Color("#c9d4ff"), Color("#e09a5a")]

var page: int = Page.PODIUM
## The tour's final standings ({"name", "points"}, Tour.standings) and the player's car.
var standings: Array[Dictionary] = []
var car_id := "car_vega"

var _layers := {}
var _pylon: Texture2D
var _cars := {}  # name -> the car's steering strip (CarSprites.strips' level row), for the top three


func _ready() -> void:
	super._ready()
	_layers = harbor_layers()
	_pylon = load(PYLON)
	for i in mini(3, standings.size()):
		var who: String = standings[i]["name"]
		_cars[who] = CarSprites.strips(Cars.find(car_of(who, car_id))["strip"])[0]
	if page == Page.PODIUM:
		Audio.play("crowd")


## The player's place in `list` (Tour.standings), 1 for first; 0 when not in it.
static func place_of(list: Array[Dictionary]) -> int:
	for i in list.size():
		if list[i]["name"] == Tour.YOU:
			return i + 1
	return 0


## The end card for finishing the tour `place` overall of `field`: the champion (first), a
## podium place (second or third) or the rest, each with its own title, line and color.
static func end_card(place: int, field := Rivals.COUNT + 1) -> Dictionary:
	if place == 1:
		return {"kind": "champion", "title": "TOUR CHAMPION", "line": "The Sundown Run is yours, coast to skyline.",
			"color": Color("#ffd23a"), "sub": "First of %d" % field}
	if place == 2 or place == 3:
		return {"kind": "podium", "title": "ON THE PODIUM", "line": "So close to the top step. The coast is waiting.",
			"color": Color("#c9d4ff") if place == 2 else Color("#e09a5a"), "sub": "%s of %d" % [Rivals.ordinal(place), field]}
	return {"kind": "finisher", "title": "TOUR COMPLETE", "line": "Every mile of it driven. Take the podium next time.",
		"color": Color("#3ad0ff"), "sub": "%s of %d" % [Rivals.ordinal(maxi(1, place)), field]}


## The car a name in the standings drove: the player's, or the rival's own (RivalProfile).
static func car_of(who: String, player_car: String) -> String:
	if who == Tour.YOU:
		return player_car
	for r: RivalProfile in RivalProfile.roster():
		if r.driver == who:
			return r.car_id
	return player_car


## Made-up final standings with the player `place` overall, for --screen=finale and tests.
static func staged_standings(place: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names: Array[String] = []
	for r: RivalProfile in RivalProfile.roster().slice(0, Rivals.COUNT):
		names.append(r.driver)
	names.insert(clampi(place - 1, 0, names.size()), Tour.YOU)
	for i in names.size():
		out.append({"name": names[i], "points": 412 - i * 37})
	return out


## The harbor's layers (Skyline's sky, city and its reflection), by layer name.
static func harbor_layers() -> Dictionary:
	var out := {}
	for layer: String in ["sky", "far", "near"]:
		var path := BACKGROUNDS % layer
		if ResourceLoader.exists(path):
			out[layer] = load(path)
	return out


## Skyline's harbor at dusk on `ci`: the sky, the city on the water and its reflection, the
## strips turned `scroll` pixels (they wrap).
static func draw_harbor(ci: CanvasItem, layers: Dictionary, scroll: float, horizon := HORIZON) -> void:
	var w := float(Cfg.SCREEN_W)
	var h := float(Cfg.SCREEN_H)
	var bands := 24
	for i in bands:
		var y0 := horizon * i / bands
		ci.draw_rect(Rect2(0, y0, w, horizon / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, float(i) / (bands - 1)))
	ci.draw_rect(Rect2(0, horizon, w, h - horizon), WATER)
	var rates := {"sky": 0.3, "far": 1.0, "near": 1.0}
	var tops := {"sky": horizon - 170.0, "far": horizon - 200.0, "near": horizon}
	for layer: String in ["sky", "far", "near"]:
		var tex: Texture2D = layers.get(layer)
		if tex == null:
			continue
		var tw := float(tex.get_width())
		var x := -fposmod(scroll * rates[layer], tw)
		while x < w:
			ci.draw_texture(tex, Vector2(roundf(x), tops[layer]))
			x += tw
	# the water's glints, drifting
	for k in 18:
		var gx := fposmod(k * 97.0 + scroll * 0.6, w)
		var gy := horizon + 36.0 + fposmod(k * 23.0, h - horizon - 40.0)
		ci.draw_rect(Rect2(gx, gy, 6 + (k % 3) * 4, 1), Color(1, 0.8, 0.6, 0.18))


## A firework over the harbor `age` seconds after it went up (none past 1.6 s): a ring of
## sparks spreading from `at`, falling and fading.
static func draw_firework(ci: CanvasItem, at: Vector2, age: float, col: Color) -> void:
	if age < 0.0 or age > 1.6:
		return
	var r := 34.0 * (1.0 - exp(-age * 3.0))
	var a := clampf(1.6 - age, 0.0, 1.0)
	for k in 16:
		var ang := TAU * k / 16.0
		var p := at + Vector2(cos(ang), sin(ang)) * r + Vector2(0, 10.0 * age * age)
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(col, a))


func handle(m: MenuInput) -> void:
	if m.back_pressed:
		Audio.play("beep")
		game.show_credits(true)
		return
	if m.confirm_pressed:
		Audio.play("beep")
		next_page()


func next_page_due() -> bool:
	if page == Page.CARD:
		return true
	page += 1
	return false


## Select: the next page now (from the end card, the credits).
func next_page() -> void:
	if next_page_due() and game != null:
		game.show_credits(true)


func _draw() -> void:
	draw_harbor(self, _layers, time * 6.0)
	match page:
		Page.PODIUM:
			_draw_podium()
		Page.STANDINGS:
			_draw_standings()
		Page.CARD:
			_draw_card()
	var hint := "Enter: next   Esc: credits" if InputRouter.state.kind == DriveInput.Kind.KEYBOARD else "A: next   B: credits"
	_footer(hint)


func _draw_fireworks() -> void:
	var cols := [Color("#ffd23a"), Color("#ff4f8b"), Color("#3ad0ff"), Color("#5dff8a")]
	for k in 4:
		var cycle := 2.2 + k * 0.35
		var age := fmod(time + k * 0.9, cycle)
		var n := floori((time + k * 0.9) / cycle)
		var at := Vector2(90.0 + fposmod(n * 173.0 + k * 151.0, 460.0), 40.0 + fposmod(n * 41.0 + k * 29.0, 80.0))
		draw_firework(self, at, age, cols[k])


func _draw_podium() -> void:
	_draw_fireworks()
	var w := float(Cfg.SCREEN_W)
	# The bridge deck, running away to the pylons
	draw_colored_polygon(PackedVector2Array([Vector2(250, DECK_Y), Vector2(390, DECK_Y), Vector2(w + 40, Cfg.SCREEN_H),
		Vector2(-40, Cfg.SCREEN_H)]), Color("#3a3550"))
	draw_line(Vector2(320, DECK_Y), Vector2(320, Cfg.SCREEN_H), Color(1, 0.9, 0.5, 0.35), 2.0)
	draw_line(Vector2(250, DECK_Y), Vector2(-40, Cfg.SCREEN_H), Color("#c9d4ff", 0.6), 2.0)
	draw_line(Vector2(390, DECK_Y), Vector2(w + 40, Cfg.SCREEN_H), Color("#c9d4ff", 0.6), 2.0)
	if _pylon != null:
		var size := Vector2(_pylon.get_width(), _pylon.get_height()) * PYLON_SCALE
		draw_texture_rect(_pylon, Rect2(Vector2(w / 2.0 - size.x / 2.0, DECK_Y + 6 - size.y), size), false)
	_text_centered(Vector2(w / 2.0, 30), "GRAND TOUR CHAMPIONS", 20, GOLD)
	_text_centered(Vector2(w / 2.0, 46), "SKYLINE FINALE   THE HARBOR BRIDGE", 9, Color(1, 1, 1, 0.8))
	for i in mini(3, standings.size()):
		var top: Vector2 = STEPS[i]
		var step := Rect2(top.x - STEP_W / 2.0, top.y, STEP_W, BASE_Y - top.y)
		draw_rect(step.grow(1), Color("#1b2a6b"))
		draw_rect(step, Color(STEP_COLORS[i], 0.9))
		draw_rect(Rect2(step.position, Vector2(step.size.x, 3)), Color(1, 1, 1, 0.5))
		_text_centered(Vector2(top.x, top.y + 17), str(i + 1), 16, NIGHT)
		var who: String = standings[i]["name"]
		_text_centered(Vector2(top.x, top.y + 28), "%d PTS" % standings[i]["points"], 8, NIGHT)
		var car_h := 40.0
		var strip: Dictionary = _cars.get(who, {})
		if not strip.is_empty():
			var cell: Vector2 = strip["cell"]
			var size := cell * (CAR_W / float(strip["body_w"]))
			car_h = size.y
			var bob := roundf(sin(time * 2.0) * 1.0) if i == 0 else 0.0
			var src := Rect2(Vector2(cell.x * (CarSprites.PLAYER_FRAMES / 2), 0), cell)
			draw_texture_rect_region(strip["tex"], Rect2(Vector2(top.x - size.x / 2.0, top.y - size.y + 3 + bob), size), src)
		var label := "YOU" if who == Tour.YOU else who.to_upper()
		var lw := _width(label, 11) + 12.0
		var ly := top.y - car_h - 18.0
		draw_rect(Rect2(top.x - lw / 2.0, ly - 11, lw, 15), Color(0, 0, 0, 0.55))
		_text_centered(Vector2(top.x, ly), label, 11, GOLD if who == Tour.YOU else Color.WHITE)


func _draw_standings() -> void:
	var w := float(Cfg.SCREEN_W)
	var panel := Rect2(w / 2.0 - 170, 46, 340, 270)
	_panel(panel, 0.88)
	_text_centered(Vector2(w / 2.0, panel.position.y + 24), "FINAL TOUR STANDINGS", 18, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 32, panel.size.x - 40, 2), GOLD)
	for i in standings.size():
		var y := panel.position.y + 56 + i * 26.0
		var who: String = standings[i]["name"]
		var you := who == Tour.YOU
		if you:
			draw_rect(Rect2(panel.position.x + 12, y - 16, panel.size.x - 24, 22), Color(GOLD, 0.22))
		var col := GOLD if you else Color.WHITE
		_text(Vector2(panel.position.x + 24, y), Rivals.ordinal(i + 1), 12, STEP_COLORS[i] if i < 3 else Color(1, 1, 1, 0.6))
		_text(Vector2(panel.position.x + 76, y), "YOU" if you else who.to_upper(), 12, col)
		var pts := "%d PTS" % standings[i]["points"]
		_text(Vector2(panel.end.x - 24 - _width(pts, 12), y), pts, 12, col)


func _draw_card() -> void:
	_draw_fireworks()
	var w := float(Cfg.SCREEN_W)
	var card := end_card(place_of(standings), standings.size())
	var col: Color = card["color"]
	var panel := Rect2(w / 2.0 - 200, 92, 400, 150)
	_frame(panel, Color(col, 0.35 + 0.15 * sin(time * 3.0)))
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.92))
	draw_rect(Rect2(panel.position + Vector2(0, 0), Vector2(panel.size.x, 4)), col)
	_text_centered(Vector2(w / 2.0, panel.position.y + 30), card["sub"].to_upper(), 11, Color(1, 1, 1, 0.75))
	_text_centered(Vector2(w / 2.0, panel.position.y + 72), card["title"], 32, col)
	_text_centered(Vector2(w / 2.0, panel.position.y + 104), card["line"], 11, Color.WHITE)
	var pts := 0
	for s: Dictionary in standings:
		if s["name"] == Tour.YOU:
			pts = s["points"]
	_text_centered(Vector2(w / 2.0, panel.position.y + 130), "%d TOUR POINTS" % pts, 10, GOLD)
	if card["kind"] == "champion":
		var c := Vector2(w / 2.0, panel.position.y - 14)
		draw_colored_polygon(Hud.crown(c + Vector2(0, 8), 34, 18), GOLD)
