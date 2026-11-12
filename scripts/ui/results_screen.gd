class_name ResultsScreen
extends MenuScreen
## After the finish, over the race as it runs on: the podium with the top three cars, the
## field's places and times (rivals still out show RACING until they cross), the player's
## place, time, best-time mark, bonuses and points, then what's next: on (the next stage,
## the continue, or the menu), retry, or quit. Laid out after the ui06 results concept.
## In a Grand Tour that's over, the panel shows the final standings instead. Survival's
## (MP-13, at TIME UP) show the distance against the best and the legs driven; the daily
## run's (MP-14) the day's best tries in place of the field.
## `choose` turns a tick of input into a Choice; the race carries it out.

enum Choice { NONE, CONTINUE, RETRY, QUIT }

const PANEL := Rect2(384, 44, 244, 248)
const ROW_H := 30.0
const PODIUM_X := 186.0  # centre of the podium
const PODIUM_Y := 276.0  # its foot
const STICKER_ROW_END := 374.0  # the new stickers' row (MP-12) stops short of the field panel
## Gold, silver, bronze, then the rest: badge and band colors, after the concept.
const PLACE_COLORS := [Color("#ffc21a"), Color("#c9d4ff"), Color("#e08a3a")]
const BANDS := [Color("#d9a400"), Color("#3a6fe0"), Color("#d97a1a"), Color("#9a2ee0"),
	Color("#16b8c8"), Color("#d92e4a"), Color("#2e7ae0"), Color("#4caa2a")]

var race: Node  # race.gd
var items: Array[int] = []  # the Choices on offer, left to right
var labels: Array[String] = []
var flow_share := 0.0  # the race's share of the next stage's palette (StageFlow): the backdrop follows
var _latched := false  # gas or steering held over the line doesn't move the cursor


func _ready() -> void:
	super._ready()
	visible = false


## Shows the results for the finish just made: what's on offer follows the race's `after`.
func open() -> void:
	var online: bool = race.online != null
	items = choices(race.tour, race.time_attack, online)
	labels.clear()
	for c in items:
		labels.append(online_label(race.online) if online and c == Choice.CONTINUE else choice_label(c, race.after))
	index = 0
	_latched = true
	visible = true


func close() -> void:
	visible = false


## What the results offer: always on and quit; retry outside a Grand Tour (where a stage that
## went wrong offers the continue as its "on") and online (where "on" is the room's lobby).
static func choices(tour: bool, _time_attack: bool, online := false) -> Array[int]:
	if tour or online:
		return [Choice.CONTINUE, Choice.QUIT]
	return [Choice.CONTINUE, Choice.RETRY, Choice.QUIT]


## The first button online (ON-9): READY for the next race, then CANCEL READY (the host:
## START NOW, not waiting for the rest); BACK once the room is gone.
static func online_label(room: OnlineSession) -> String:
	if room.phase == OnlineSession.Phase.CLOSED:
		return "BACK"
	if not room.is_ready_again():
		return "READY"
	return "START NOW" if room.hosting() else "CANCEL READY"


## The READY count under the results online (ON-9): "READY  1 / 2".
static func ready_line(room: OnlineSession) -> String:
	return "READY  %d / %d" % [room.ready_count(), room.players.size()]


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
		3:  # TOUR_DONE: on to the tour's ending (MP-16)
			return "FINALE"
	return "CONTINUE"


func choice_count() -> int:
	return items.size()


## One tick of menu input (and the race's own confirm press): the choice picked, or NONE.
func choose(m: MenuInput, confirm: bool) -> int:
	if _latched and m.centred():
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


## The field in race order: {place, name, car, time (-1 still racing), you}. A `split` race
## (MP-18) names its two players P1 and P2, and both are "you".
static func rows(standings: Array, player: PlayerCar, player_finish: float, player_car: String, split := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in standings.size():
		var car: PlayerCar = standings[i]
		var you := car == player
		var r := car as RivalCar
		out.append({
			"place": i + 1,
			"name": (SplitScreen.NAMES[0] if split else "YOU") if you else r.profile.driver,
			"car": player_car if you else r.car_id,
			"time": player_finish if you else (r.finish_time if r.finished else -1.0),
			"you": you or (split and r.remote),
		})
	return out


## A split race's two players (MP-18) in `field` (rows): P1's row, then P2's.
static func split_rows(field: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for player_name: String in SplitScreen.NAMES:
		for r in field:
			if r["you"] and r["name"] == player_name:
				out.append(r)
	return out


## The best-time line: a new best, or the best to beat.
static func best_line(new_best: bool, best_before: Dictionary) -> String:
	if new_best:
		return "NEW BEST TIME!"
	if best_before.has("time"):
		return "BEST  " + Hud.clock_text(float(best_before["time"]))
	return ""


## The daily run's line under the time: this try the day's best, or the best to beat.
static func daily_best_line(tries: Dictionary, finish: float) -> String:
	var times: Array = tries.get("times", [])
	if times.is_empty():
		return ""
	if finish > 0.0 and is_equal_approx(float(times[0]), finish):
		return "BEST TRY TODAY!"
	return "TODAY'S BEST  " + Hud.clock_text(float(times[0]))


## Survival's legs, a row each, the last BEST_ROWS of them: {"leg" (from 1), "stage" (index),
## "current" (the leg the clock ran out on)}.
const LEG_ROWS := 7
static func leg_rows(run: Survival) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in range(maxi(0, run.leg + 1 - LEG_ROWS), run.leg + 1):
		out.append({"leg": n + 1, "stage": Survival.stage_for(n, run.stages), "current": n == run.leg})
	return out


## Survival's distance line against the best before the run (world units).
static func survival_best_line(new_best: bool, best_before: float, units: int) -> String:
	if new_best:
		return "NEW BEST DISTANCE!"
	if best_before > 0.0:
		return "BEST  " + Settings.distance_text(best_before, units)
	return ""


## The footer's hints; `stage_pick` adds the host's next stage on up and down (ON-9).
static func results_hints(stage_pick := false) -> String:
	var more := "    Up / Down: next stage" if stage_pick else ""
	match InputRouter.state.kind:
		DriveInput.Kind.GAMEPAD, DriveInput.Kind.WHEEL:
			return "D-pad: choose    A: select" + more
	return "Left / Right: choose    Enter: select" + more


func _draw() -> void:
	if race == null:
		return
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), backdrop(race.track.theme, race.track.next_theme, flow_share))
	_header("RESULTS")
	if race.survival:
		_survival()
		_choices()
		_footer(results_hints())
		return
	_text(Vector2(16, 52), Hud.stage_line(race), 10, Color(1, 1, 1, 0.8))
	if race.after == race.After.NEXT_STAGE:
		var next := Stages.next(race.stage_index)
		_text(Vector2(16, 64), "NEXT  " + Stages.stage_name(next).to_upper(), 9, Color(GOLD, 0.35 + 0.65 * flow_share))
	var order: Array = race.rivals.standings(race.player, race.player_finish)
	var field := rows(order, race.player, race.player_finish, race.car_id, race.p2 != null)
	if race.p2 != null:
		_split_summary(field)
	else:
		_summary(field)
	_podium(field)
	var tour: Tour = race.tour_state if race.tour else null
	if tour != null and (race.after == race.After.TOUR_DONE or race.after == race.After.TOUR_OVER):
		_standings_panel(tour, "FINAL STANDINGS" if race.after == race.After.TOUR_DONE else "TOUR OVER")
	elif not race.daily.is_empty():
		_daily_panel()
	else:
		_field_panel(field)
	var room: OnlineSession = race.online
	var picking := room != null and room.hosting() and room.phase == OnlineSession.Phase.RACING
	if room != null:
		_online_lines(room, picking)
	_choices()
	_footer(results_hints(picking))


## The dimming over the race: night, tinged with the sky, which crossfades from this stage's
## (`theme`) to the next stage's (`next`, empty for none) by `k` (StageFlow).
static func backdrop(theme: Dictionary, next: Dictionary, k: float) -> Color:
	var sky := Background.sky_color(theme, next, "sky_top", k)
	return Color(NIGHT.lerp(sky.darkened(0.5), 0.35), 0.72)


## Place, time, best mark and bonuses, top left.
func _summary(field: Array[Dictionary]) -> void:
	var with_rivals: bool = field.size() > 1
	var y := 92.0
	if with_rivals:
		_text(Vector2(16, y), Rivals.ordinal(race.place), 34, PLACE_COLORS[race.place - 1] if race.place <= 3 else Color.WHITE)
		_text(Vector2(98, y), "of %d" % field.size(), 12, Color(1, 1, 1, 0.75))
	else:
		_text(Vector2(16, y), "FINISH", 28, GOLD)
	var time_text := "TIME  " + Hud.clock_text(race.race_time)
	_text(Vector2(16, y + 22), time_text, 14, Color.WHITE)
	# The medal this run earned (MP-9), beside the time
	var medal := Medals.earned(race.stage_index, Settings.difficulty, race.player_finish)
	if medal != Medals.Medal.NONE:
		var mx := 16 + _width(time_text, 14) + 12
		Medals.draw(self, Vector2(mx, y + 17), medal, 6.0)
		_text(Vector2(mx + 10, y + 21), Medals.medal_name(medal), 9, Medals.color(medal))
	var best := best_line(race.new_best or race.new_best_time, race.best_before)
	if not race.daily.is_empty():
		var kept: Dictionary = race.daily_tries if not race.daily_tries.is_empty() else SaveData.daily_on(int(race.daily["day"]))
		best = daily_best_line(kept, race.player_finish)
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
	if not race.new_stickers.is_empty():
		_new_stickers(race.new_stickers, Vector2(16, 156))  # (over the unlock line, clear of the podium)


## A split race's two players (MP-18), top left in place of the one player's summary: each
## one's tag, place and time.
func _split_summary(field: Array[Dictionary]) -> void:
	var y := 96.0
	var players := split_rows(field)
	for i in players.size():
		var r: Dictionary = players[i]
		var col: Color = SplitScreen.COLORS[i]
		var tag := Rect2(16, y - 18, 30, 22)
		draw_rect(tag, col)
		_text_centered(Vector2(tag.get_center().x, tag.end.y - 6), r["name"], 12, Color("#14102a"))
		var place: int = r["place"]
		_text(Vector2(56, y + 2), Rivals.ordinal(place), 24, PLACE_COLORS[place - 1] if place <= 3 else Color.WHITE)
		var t: float = r["time"]
		var tt := "TIME  " + Hud.clock_text(t) if t >= 0.0 else "OUT OF TIME"
		_text(Vector2(118, y - 2), tt, 11, Color.WHITE if t >= 0.0 else Color(1, 1, 1, 0.6))
		y += 40.0


## The stickers this run earned (MP-12): NEW STICKER, then each one small with its name, as many
## as fit beside the podium.
func _new_stickers(ids: Array[String], at: Vector2) -> void:
	_text(at + Vector2(0, 4), "NEW STICKER" if ids.size() == 1 else "NEW STICKERS", 9, GOLD)
	var x := at.x + UiText.width("NEW STICKERS", 9) + 18
	for i in ids.size():
		var label: String = Stickers.info(ids[i])["name"]
		var w := 22.0 + UiText.width(label, 8)
		if x + w > STICKER_ROW_END:
			_text(Vector2(x, at.y + 4), "+%d" % (ids.size() - i), 9, Color.WHITE)
			break
		Stickers.draw(self, Vector2(x, at.y), ids[i], 8.0, true, Stickers.tilt(i))
		_text(Vector2(x + 12, at.y + 4), label, 8, Color.WHITE)
		x += w + 8


## Survival's results: how far, against the best, the legs and the time on the left, the car
## on its step, the road the run took on the right.
func _survival() -> void:
	var run: Survival = race.run
	_text(Vector2(16, 52), "SURVIVAL   " + Hud.stage_line(race), 10, Color(1, 1, 1, 0.8))
	var y := 92.0
	_text(Vector2(16, y), "TIME UP", 28, GOLD)
	var dist := "DISTANCE  " + Settings.distance_text(race.survival_distance(), Settings.units)
	_text(Vector2(16, y + 22), dist, 14, Color.WHITE)
	var best := survival_best_line(race.survival_new_best, race.survival_best_before, Settings.units)
	if best != "":
		_text(Vector2(16, y + 38), best, 10, Color("#5dff8a") if race.survival_new_best else Color(1, 1, 1, 0.7))
	_text(Vector2(16, y + 52), "LEGS  %d     TIME  %s" % [run.leg + 1, Hud.clock_text(race.race_time)], 10, GOLD)
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
	# The car on a step of its own
	var block := Rect2(PODIUM_X - 50, PODIUM_Y - 44, 100, 44)
	draw_rect(block, Color("#5a5f78"))
	draw_rect(Rect2(block.position, Vector2(block.size.x, 4)), Color("#8a90aa"))
	draw_rect(Rect2(block.position.x, block.end.y - 3, block.size.x, 3), Color("#3a3d52"))
	var strips := _strips(race.car_id)
	if not strips.is_empty():
		CarSprites.draw_player(self, strips, Vector2(PODIUM_X, block.position.y), 64.0, 0.0, false)
	_text_centered(Vector2(PODIUM_X, block.position.y + 28), Settings.distance_text(race.survival_distance(), Settings.units), 12, Color.WHITE)
	# The road it took
	_panel_frame()
	_text_centered(Vector2(PANEL.get_center().x, PANEL.position.y + 26), "THE ROAD SO FAR", 13, GOLD)
	var legs := leg_rows(run)
	for i in legs.size():
		var r: Dictionary = legs[i]
		var ry := PANEL.position.y + 40 + i * 28
		var band := Rect2(PANEL.position.x + 36, ry, PANEL.size.x - 44, 24)
		var bcol: Color = BANDS[(int(r["stage"]) + 1) % BANDS.size()]  # (not the gold: that's the leg it ended on)
		draw_rect(band, Color(bcol, 0.85 if r["current"] else 0.5))
		if r["current"]:
			draw_rect(Rect2(band.position.x - 2, band.position.y, 2, band.size.y), GOLD)
		draw_circle(Vector2(PANEL.position.x + 20, ry + 12), 10.0, Color(GOLD, 0.9) if r["current"] else Color("#3a4a8a"))
		_text_centered(Vector2(PANEL.position.x + 20, ry + 16), str(r["leg"]), 11, NIGHT if r["current"] else Color.WHITE)
		_text(Vector2(band.position.x + 8, ry + 11), Stages.stage_name(int(r["stage"])).to_upper(), 9, Color.WHITE)
		_text(Vector2(band.position.x + 8, ry + 21), "OUT OF TIME HERE" if r["current"] else "CLEAR", 8, GOLD if r["current"] else Color(1, 1, 1, 0.75))


## The daily run's tries today, in place of the field: the best times, this one marked.
func _daily_panel() -> void:
	_panel_frame()
	var day := int(race.daily["day"])
	_text_centered(Vector2(PANEL.get_center().x, PANEL.position.y + 26), "DAILY RUN", 13, GOLD)
	_text_centered(Vector2(PANEL.get_center().x, PANEL.position.y + 42), Daily.date_text(day), 9, Color(1, 1, 1, 0.75))
	var t := DailyCard.lines(race.daily, day, race.daily_tries if not race.daily_tries.is_empty() else SaveData.daily)
	var times: Array = Daily.tries_on(race.daily_tries if not race.daily_tries.is_empty() else SaveData.daily, day)["times"]
	for i in times.size():
		var ry := PANEL.position.y + 60 + i * ROW_H
		var mine := is_equal_approx(float(times[i]), race.player_finish)
		var band := Rect2(PANEL.position.x + 36, ry, PANEL.size.x - 44, ROW_H - 4)
		draw_rect(band, Color(BANDS[i], 0.85 if mine else 0.5))
		if mine:
			draw_rect(Rect2(band.position.x - 2, band.position.y, 2, band.size.y), GOLD)
		_badge(Vector2(PANEL.position.x + 20, ry + (ROW_H - 4) / 2.0), i + 1)
		_text(Vector2(band.position.x + 8, ry + 17), "THIS TRY" if mine else "TRY", 9, Color.WHITE)
		var tt := Hud.clock_text(float(times[i]))
		_text(Vector2(band.end.x - 6 - _width(tt, 11), ry + 17), tt, 11, Color.WHITE)
	_text_centered(Vector2(PANEL.get_center().x, PANEL.end.y - 40), t["tries"], 10, Color(1, 1, 1, 0.8))
	_text_centered(Vector2(PANEL.get_center().x, PANEL.end.y - 24), "%s   %s TRAFFIC" % [t["weather"], t["traffic"]], 9, Color(1, 1, 1, 0.6))


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
			CarSprites.draw_player(self, strips, Vector2(x, block.position.y), 64.0 if i == 0 else 56.0, 0.0, false)
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
			CarSprites.draw_player(self, strips, Vector2(band.position.x + 24, band.end.y - 2), 34.0, 0.0, false)
		_text(Vector2(band.position.x + 46, y + 12), r["name"], 9, Color.WHITE)
		_text(Vector2(band.position.x + 46, y + 22), String(Cars.find(r["car"])["name"]).to_upper(), 8, Color(1, 1, 1, 0.7))
		var t: float = r["time"]
		var tt := Hud.clock_text(t) if t >= 0.0 else ("OUT" if race.cut_short or (race.p2 != null and r["you"]) else "RACING")
		var tw := _width(tt, 10)
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


## Online (ON-9): the READY count left of the buttons, the next stage right of them; or,
## with the room gone, why.
func _online_lines(room: OnlineSession, picking: bool) -> void:
	labels[items.find(Choice.CONTINUE)] = online_label(room)
	if room.phase == OnlineSession.Phase.CLOSED:
		_text(Vector2(16, 326), room.error, 10, Color("#ff8a5a"))
		return
	_text(Vector2(16, 318), ready_line(room), 12, GOLD)
	_text(Vector2(16, 330), "Starts when all are in", 8, Color(1, 1, 1, 0.6))
	var next := "NEXT  " + Stages.stage_name(room.stage).to_upper() + ("  MIRROR" if room.mirror else "")
	var nw := _width(next, 10)
	_text(Vector2(Cfg.SCREEN_W - 16 - nw, 318), next, 10, GOLD if picking else Color(1, 1, 1, 0.8))
	if picking:
		_arrow_pair(Vector2(Cfg.SCREEN_W - 16 - nw / 2.0, 330))


## Up and down arrows: the host's next stage changes with them.
func _arrow_pair(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 2), c + Vector2(-4, 2), c + Vector2(-7, -3)]), GOLD)
	draw_colored_polygon(PackedVector2Array([c + Vector2(4, -3), c + Vector2(10, -3), c + Vector2(7, 2)]), GOLD)


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
