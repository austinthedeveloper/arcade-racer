class_name ResultsScreen
extends MenuScreen
## After the finish, over the race as it runs on: the podium with the top three cars, the
## field's places and times (rivals still out show RACING until they cross), the player's
## place, time, best-time mark, bonuses and points, then what's next: on (the next stage,
## the continue, or the menu), retry, or quit. Laid out after the ui06 results concept.
## In a Grand Tour that's over, the panel shows the final standings instead.
## `choose` turns a tick of input into a Choice; the race carries it out.

enum Choice { NONE, CONTINUE, RETRY, QUIT }

const PANEL := Rect2(384, 44, 244, 248)
const ROW_H := 30.0
const PODIUM_X := 186.0  # centre of the podium
const PODIUM_Y := 276.0  # its foot
## Gold, silver, bronze, then the rest: badge and band colors, after the concept.
const PLACE_COLORS := [Color("#ffc21a"), Color("#c9d4ff"), Color("#e08a3a")]
const BANDS := [Color("#d9a400"), Color("#3a6fe0"), Color("#d97a1a"), Color("#9a2ee0"),
	Color("#16b8c8"), Color("#d92e4a"), Color("#2e7ae0"), Color("#4caa2a")]

var race: Node  # race.gd
var items: Array[int] = []  # the Choices on offer, left to right
var labels: Array[String] = []
var index := 0
var _latched := false  # gas or steering held over the line doesn't move the cursor


func _ready() -> void:
	super._ready()
	visible = false


## Shows the results for the finish just made: what's on offer follows the race's `after`.
func open() -> void:
	items = choices(race.tour, race.time_attack)
	labels.clear()
	for c in items:
		labels.append(choice_label(c, race.after))
	index = 0
	_latched = true
	visible = true


func close() -> void:
	visible = false


## What the results offer: always on and quit; retry outside a Grand Tour (where a stage that
## went wrong offers the continue as its "on").
static func choices(tour: bool, _time_attack: bool) -> Array[int]:
	if tour:
		return [Choice.CONTINUE, Choice.QUIT]
	return [Choice.CONTINUE, Choice.RETRY, Choice.QUIT]


static func choice_label(c: int, after: int) -> String:
	match c:
		Choice.RETRY:
			return "RETRY"
		Choice.QUIT:
			return "QUIT"
	match after:
		0:  # race.After.NEXT_STAGE
			return "NEXT STAGE"
		1:  # RETRY: the tour's continue
			return "USE CONTINUE"
	return "CONTINUE"


func move(dir: int) -> int:
	index = posmod(index + dir, items.size())
	return index


## One tick of menu input (and the race's own confirm press): the choice picked, or NONE.
func choose(m: MenuInput, confirm: bool) -> int:
	if _latched and absf(m.x) < MenuInput.RELEASE and absf(m.y) < MenuInput.RELEASE:
		_latched = false
	var dir := 0 if _latched else m.step()
	if dir != 0:
		move(dir)
		Audio.play("tick")
		return Choice.NONE
	if confirm or m.confirm_pressed:
		Audio.play("beep")
		return items[index]
	return Choice.NONE


## The field in race order: {place, name, car, time (-1 still racing), you}.
static func rows(standings: Array, player: PlayerCar, player_finish: float, player_car: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in standings.size():
		var car: PlayerCar = standings[i]
		var you := car == player
		var r := car as RivalCar
		out.append({
			"place": i + 1,
			"name": "YOU" if you else r.profile.driver,
			"car": player_car if you else r.car_id,
			"time": player_finish if you else (r.finish_time if r.finished else -1.0),
			"you": you,
		})
	return out


## The best-time line: a new best, or the best to beat.
static func best_line(new_best: bool, best_before: Dictionary) -> String:
	if new_best:
		return "NEW BEST TIME!"
	if best_before.has("time"):
		return "BEST  " + Hud.clock_text(float(best_before["time"]))
	return ""


static func results_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "Steer: choose    Gas: select"
		DriveInput.Kind.GAMEPAD:
			return "D-pad: choose    A: select"
	return "Left / Right: choose    Enter: select"


func _draw() -> void:
	if race == null:
		return
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.72))
	_header("RESULTS")
	_text(Vector2(16, 52), ("STAGE %d  " % (race.stage_index + 1)) + race.track.name.to_upper(), 10, Color(1, 1, 1, 0.8))
	var order: Array = race.rivals.standings(race.player, race.player_finish)
	var field := rows(order, race.player, race.player_finish, race.car_id)
	_summary(field)
	_podium(field)
	var tour: Tour = race.tour_state if race.tour else null
	if tour != null and (race.after == race.After.TOUR_DONE or race.after == race.After.TOUR_OVER):
		_standings_panel(tour, "FINAL STANDINGS" if race.after == race.After.TOUR_DONE else "TOUR OVER")
	else:
		_field_panel(field)
	_choices()
	_footer(results_hints())


## Place, time, best mark and bonuses, top left.
func _summary(field: Array[Dictionary]) -> void:
	var with_rivals: bool = field.size() > 1
	var y := 92.0
	if with_rivals:
		_text(Vector2(16, y), Rivals.ordinal(race.place), 34, PLACE_COLORS[race.place - 1] if race.place <= 3 else Color.WHITE)
		_text(Vector2(98, y), "of %d" % field.size(), 12, Color(1, 1, 1, 0.75))
	else:
		_text(Vector2(16, y), "FINISH", 28, GOLD)
	_text(Vector2(16, y + 22), "TIME  " + Hud.clock_text(race.race_time), 14, Color.WHITE)
	var best := best_line(race.new_best or race.new_best_time, race.best_before)
	if best != "":
		var lit: bool = race.new_best or race.new_best_time
		_text(Vector2(16, y + 38), best, 10, Color("#5dff8a") if lit else Color(1, 1, 1, 0.7))
	if race.tour and race.tour_state.points.has(Tour.YOU):
		var tr: Tour = race.tour_state
		_text(Vector2(16, y + 52), "TOUR  %s   %d PTS" % [Rivals.ordinal(tr.standing_of(Tour.YOU)), tr.points[Tour.YOU]], 10, GOLD)
	# Bonuses, beside it
	var bx := 196.0
	var rows_b: Array[Dictionary] = race.score.summary()
	var by := 70.0
	for i in mini(rows_b.size(), 6):
		var r: Dictionary = rows_b[i]
		var label: String = r["name"] if r["count"] == 1 else "%s x%d" % [r["name"], r["count"]]
		_text(Vector2(bx, by + i * 12), label, 9, Color.WHITE)
		_text(Vector2(bx + 136, by + i * 12), "+%d" % r["points"], 9, Color("#5dff8a"))
	var ty := by + mini(rows_b.size(), 6) * 12 + 4
	_text(Vector2(bx, ty), "POINTS", 10, GOLD)
	_text(Vector2(bx + 136, ty), str(race.score.total()), 10, GOLD)
	if not race.new_unlocks.is_empty():
		_text(Vector2(16, 172), Hud.unlock_line(race.new_unlocks), 10, Color("#5dff8a", 0.6 + 0.4 * sin(time * 6.0)))


## The top three on their steps: second left, first middle and higher, third right.
func _podium(field: Array[Dictionary]) -> void:
	var steps := [[1, -110.0, 38.0], [0, 0.0, 56.0], [2, 110.0, 26.0]]  # place index, x, height
	for s in steps:
		var i: int = s[0]
		var x: float = PODIUM_X + s[1]
		var h: float = s[2]
		var block := Rect2(x - 50, PODIUM_Y - h, 100, h)
		draw_rect(block, Color("#5a5f78"))
		draw_rect(Rect2(block.position, Vector2(block.size.x, 4)), Color("#8a90aa"))
		draw_rect(Rect2(block.position.x, block.end.y - 3, block.size.x, 3), Color("#3a3d52"))
		var col: Color = PLACE_COLORS[i]
		_crown(Vector2(x, block.position.y + h * 0.5), col)
		if i >= field.size():
			continue
		var r: Dictionary = field[i]
		var strips := _strips(r["car"])
		if not strips.is_empty():
			CarSprites.draw_player(self, strips, Vector2(x, block.position.y), 64.0 if i == 0 else 56.0, 0.0, false, false, time)
		var name_col := Color("#5dff8a") if r["you"] else Color.WHITE
		_text_centered(Vector2(x, block.end.y + 12), r["name"], 9, name_col)


## The field, a row per car: badge, car, driver, time.
func _field_panel(field: Array[Dictionary]) -> void:
	_panel_frame()
	for i in mini(field.size(), 8):
		var r: Dictionary = field[i]
		var y := PANEL.position.y + 12 + i * ROW_H
		var band := Rect2(PANEL.position.x + 36, y, PANEL.size.x - 44, ROW_H - 4)
		var bcol: Color = BANDS[i % BANDS.size()]
		draw_rect(band, Color(bcol, 0.85 if r["you"] else 0.55))
		if r["you"]:
			draw_rect(band.grow(1), Color(GOLD, 0.0), false)
			draw_rect(Rect2(band.position.x - 2, band.position.y, 2, band.size.y), GOLD)
		_badge(Vector2(PANEL.position.x + 20, y + (ROW_H - 4) / 2.0), int(r["place"]))
		var strips := _strips(r["car"])
		if not strips.is_empty():
			CarSprites.draw_player(self, strips, Vector2(band.position.x + 24, band.end.y - 2), 34.0, 0.0, false, false, time)
		_text(Vector2(band.position.x + 46, y + 12), r["name"], 9, Color.WHITE)
		_text(Vector2(band.position.x + 46, y + 22), String(Cars.find(r["car"])["name"]).to_upper(), 7, Color(1, 1, 1, 0.7))
		var t: float = r["time"]
		var tt := Hud.clock_text(t) if t >= 0.0 else "RACING"
		var tw := _font.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_text(Vector2(band.end.x - 6 - tw, y + 17), tt, 10, Color.WHITE if t >= 0.0 else Color(1, 1, 1, 0.55))


## The tour's points table, most first.
func _standings_panel(tour: Tour, title: String) -> void:
	_panel_frame()
	_text_centered(Vector2(PANEL.get_center().x, PANEL.position.y + 26), title, 13, GOLD)
	var rows_t: Array[Dictionary] = tour.standings()
	for i in mini(rows_t.size(), 8):
		var r: Dictionary = rows_t[i]
		var y := PANEL.position.y + 40 + i * 24
		var col := Color("#5dff8a") if r["name"] == Tour.YOU else Color.WHITE
		_badge(Vector2(PANEL.position.x + 20, y + 9), i + 1)
		_text(Vector2(PANEL.position.x + 40, y + 13), r["name"], 10, col)
		_text(Vector2(PANEL.end.x - 44, y + 13), str(r["points"]), 10, col)


func _panel_frame() -> void:
	_frame(PANEL)
	draw_rect(PANEL, Color(0.04, 0.03, 0.1, 0.9))
	# A chequered strip along the top, after the concept
	for k in int(PANEL.size.x / 6.0):
		for row in 2:
			if (k + row) % 2 == 0:
				draw_rect(Rect2(PANEL.position.x + k * 6, PANEL.position.y + row * 4, 6, 4), Color(1, 1, 1, 0.8))


## Place badge: a medal for the top three, a plain numeral after.
func _badge(c: Vector2, place: int) -> void:
	if place <= 3:
		draw_circle(c, 11.0, PLACE_COLORS[place - 1])
		draw_circle(c, 8.0, Color(PLACE_COLORS[place - 1].darkened(0.25)))
		_text_centered(c + Vector2(0, 4), str(place), 11, Color.WHITE)
	else:
		_text_centered(c + Vector2(0, 6), str(place), 16, Color("#c9d4ff"))


## A little crown on a podium step.
func _crown(c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 6), c + Vector2(-12, -6), c + Vector2(-6, 0),
		c + Vector2(0, -9), c + Vector2(6, 0), c + Vector2(12, -6), c + Vector2(12, 6)]), col)


func _choices() -> void:
	var w := float(Cfg.SCREEN_W)
	var bw := 120.0
	var gap := 10.0
	var x0 := (w - bw * items.size() - gap * (items.size() - 1)) / 2.0
	for i in items.size():
		var r := Rect2(x0 + i * (bw + gap), 308, bw, 24)
		var on := i == index
		_frame(r, Color(GOLD, 0.3 + 0.15 * sin(time * 5.0)) if on else Color.TRANSPARENT)
		draw_rect(r, Color("#1d3fa8") if on else Color(0.04, 0.03, 0.1, 0.9))
		_text_centered(Vector2(r.get_center().x, r.end.y - 8), labels[i], 11, GOLD if on else Color(1, 1, 1, 0.8))


func _strips(car_id: String) -> Dictionary:
	return CarSprites.strips(Cars.find(car_id)["strip"])
