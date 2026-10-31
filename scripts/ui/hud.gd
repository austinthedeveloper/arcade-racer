class_name Hud
extends Control
## In-race HUD: timer, route progress, nitro, speedometer and center banners.

var race: Node  # race.gd


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if race == null or race.player == null:
		return
	var p: PlayerCar = race.player
	var w := float(Cfg.SCREEN_W)

	# Time, top left: the clock, or in Time Attack the run's time and the best
	_text(Vector2(12, 18), "TIME", 10, Color("#ffd23a"))
	if race.free_drive:
		_text(Vector2(12, 42), clock_text(race.race_time), 22, Color.WHITE)
		_text(Vector2(12, 58), "FREE DRIVE", 10, Color(1, 1, 1, 0.8))
	elif race.time_attack:
		_text(Vector2(12, 42), clock_text(race.race_time), 22, Color.WHITE)
		var best: Ghost = race.ghost
		_text(Vector2(12, 58), "BEST " + (clock_text(best.time) if best != null else "--:--.--"), 10, Color(1, 1, 1, 0.8))
		if not is_nan(race.split) and race.banner_time <= 0.0 and race.state == race.State.RACING:
			var ahead: bool = race.split < 0.0
			_text(Vector2(12, 72), race.split_text(race.split), 10, Color("#5dff8a") if ahead else Color("#ff6a6a"))
	else:
		var t: float = race.time_left
		var tcol := Color("#ff4040") if t < Cfg.LOW_TIME and int(t * 4.0) % 2 == 0 else Color.WHITE
		_text(Vector2(12, 46), str(ceili(t)), 30, tcol)

	# Place, under the time
	if not race.rivals.cars.is_empty():
		_text(Vector2(12, 64), "POS", 10, Color("#ffd23a"))
		var field: int = race.rivals.cars.size() + 1
		_text(Vector2(12, 88), str(race.place), 24, Color.WHITE)
		_text(Vector2(16 + 16 * str(race.place).length(), 88), "/%d" % field, 12, Color(1, 1, 1, 0.8))

	# Route progress, top center
	var bar := Rect2(w / 2.0 - 110, 12, 220, 8)
	draw_rect(bar.grow(2), Color(0, 0, 0, 0.55))
	var progress := clampf(p.distance / race.finish_distance, 0.0, 1.0)
	if race.free_drive:  # the road loops: the bar starts over each time round
		progress = fposmod(p.distance, race.track.length) / race.finish_distance
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("#3ad0ff"))
	for d in race.checkpoint_distances:
		var cx: float = bar.position.x + bar.size.x * clampf(d / race.finish_distance, 0.0, 1.0)
		draw_rect(Rect2(cx - 1, bar.position.y - 3, 2, bar.size.y + 6), Color("#ffd23a"))
	draw_rect(Rect2(bar.end.x - 2, bar.position.y - 3, 4, bar.size.y + 6), Color.WHITE)
	for r: RivalCar in race.rivals.cars:
		var rx := progress_x(bar, r.distance, race.finish_distance)
		draw_rect(Rect2(rx - 2, bar.position.y + 2, 4, 4), Color("#ff4f8b"))
	if race.ghost != null:
		var gx := progress_x(bar, race.ghost_now.x, race.finish_distance)
		draw_rect(Rect2(gx - 2, bar.position.y + 2, 4, 4), Color("#9ad8ff"))
	var you := bar.position.x + bar.size.x * minf(progress, 1.0)
	draw_rect(Rect2(you - 2, bar.position.y + 1, 4, 6), Color.WHITE)
	_text(Vector2(bar.position.x, bar.end.y + 14), ("STAGE %d  " % (race.stage_index + 1)) + race.track.name.to_upper(), 9, Color(1, 1, 1, 0.85))

	# Nitro, top right
	_text(Vector2(w - 92, 18), "NITRO", 10, Color("#ffd23a"))
	var slots := maxi(p.nitro_max, p.nitro_charges)
	var gap := minf(18.0, 72.0 / slots)
	for i in slots:
		var cx := w - 88 + i * gap
		var lit := i < p.nitro_charges
		var col := Color("#ff7a1a") if lit else Color(1, 1, 1, 0.2)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, 38), Vector2(cx + 6, 24), Vector2(cx + 12, 38)]), col)
		if lit:
			draw_colored_polygon(PackedVector2Array([Vector2(cx + 3, 38), Vector2(cx + 6, 30), Vector2(cx + 9, 38)]), Color("#ffe36a"))
	if p.nitro_time > 0.0:
		draw_rect(Rect2(w - 90, 42, 76 * p.nitro_time / p.nitro_duration, 3), Color("#7ad8ff"))

	var pu: PowerUps = race.power_ups
	if not pu.pickups.is_empty():
		_power_up_slot(Rect2(w - 90, 50, 24, 24))
	_power_up_fx()

	# Speedometer, bottom right
	var center := Vector2(w - 58, Cfg.SCREEN_H - 20)
	var pct := clampf(p.speed / (Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT), 0.0, 1.0)
	draw_arc(center, 44, PI, TAU, 24, Color(0, 0, 0, 0.55), 10)
	draw_arc(center, 44, PI, PI + PI * pct, 24, Color("#ff5a2a") if pct > 0.8 else Color("#3ad0ff"), 6)
	var mph := roundi(p.speed / Cfg.MAX_SPEED * Cfg.DISPLAY_TOP_SPEED)
	_text_centered(Vector2(center.x, center.y - 4), str(mph), 22, Color.WHITE)
	_text_centered(Vector2(center.x, center.y + 10), "MPH", 8, Color("#ffd23a"))

	# Slipstream, over the speedometer: the meter filling, then the boost running down
	var slip := Rect2(w - 98, Cfg.SCREEN_H - 82, 80, 4)
	if p.draft > 0.0 or p.draft_time > 0.0:
		_text(Vector2(slip.position.x, slip.position.y - 3), "SLIPSTREAM", 8, Color("#7ad8ff"))
		draw_rect(slip.grow(1), Color(0, 0, 0, 0.55))
		var fill := p.draft_time / Draft.BOOST_TIME if p.draft_time > 0.0 else p.draft
		var col := Color("#ffe36a") if p.draft_time > 0.0 else Color("#7ad8ff")
		draw_rect(Rect2(slip.position, Vector2(slip.size.x * fill, slip.size.y)), col)

	# Device, bottom left
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 20), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(10, Cfg.SCREEN_H - 8), "F1 input debug   F2 calibrate wheel   R restart", 8, Color(1, 1, 1, 0.45))
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 70), hint, 10, Color("#ffd23a"))

	# Bonuses as they're earned, right of center; the tally under the finish banner
	for i in race.score.feed.size():
		var b: Dictionary = race.score.feed[i]
		var a := clampf((Scoring.FEED_TIME - b["age"]) / 0.4, 0.0, 1.0)
		_text_centered(Vector2(w * 0.78, 110 + i * 16), "%s +%d" % [b["name"], b["points"]], 12, Color("#5dff8a", a))
	var ended: bool = race.state == race.State.FINISHED or race.state == race.State.TIME_UP
	if ended and race.tour and (race.after == race.After.TOUR_DONE or race.after == race.After.TOUR_OVER):
		_tour_standings(Vector2(w / 2.0, 182), "FINAL STANDINGS" if race.after == race.After.TOUR_DONE else "TOUR OVER")
	elif race.state == race.State.FINISHED:
		var end_y := _score_tally(Vector2(w / 2.0, 182))
		if race.tour and race.tour_state.points.has(Tour.YOU):
			var tr: Tour = race.tour_state
			_text_centered(Vector2(w / 2.0, end_y + 14), "TOUR   %s   %d PTS" % [Rivals.ordinal(tr.standing_of(Tour.YOU)),
				tr.points[Tour.YOU]], 11, Color("#ffd23a"))

	if ended and not race.new_unlocks.is_empty():
		_text_centered(Vector2(w / 2.0, 92), unlock_line(race.new_unlocks), 12, Color("#5dff8a", 0.6 + 0.4 * sin(race.road.time * 6.0)))

	# Banners
	if race.counting_down():
		_text_centered(Vector2(w / 2.0, 130), str(ceili(race.countdown)), 64, Color("#ffd23a"))
	if race.banner != "" and race.banner_time > 0.0:
		_text_centered(Vector2(w / 2.0, 130), race.banner, 44, Color("#ffd23a"))
		if race.banner_sub != "":
			_text_centered(Vector2(w / 2.0, 156), race.banner_sub, 14, Color.WHITE)


## A run's time as m:ss.cc.
static func clock_text(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


## The finish's notice of cars it opened (Unlocks.newly_open).
static func unlock_line(ids: Array[String]) -> String:
	var names: Array[String] = []
	for id in ids:
		names.append(String(Cars.find(id)["name"]).to_upper())
	return ("NEW CAR: " if ids.size() == 1 else "NEW CARS: ") + ", ".join(names)


## Where a racer `distance` along the stage sits on the progress bar.
static func progress_x(bar: Rect2, distance: float, finish_distance: float) -> float:
	return bar.position.x + bar.size.x * clampf(distance / finish_distance, 0.0, 1.0)


## The tour's standings, most points first, the player picked out.
func _tour_standings(top: Vector2, title: String) -> void:
	var rows: Array[Dictionary] = race.tour_state.standings()
	var panel := Rect2(top.x - 120, top.y - 12, 240, 30 + 12 * rows.size())
	draw_rect(panel, Color(0, 0, 0, 0.6))
	_text_centered(Vector2(top.x, top.y + 1), title, 11, Color("#ffd23a"))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := top.y + 16 + i * 12
		var col := Color("#5dff8a") if r["name"] == Tour.YOU else Color.WHITE
		_text(Vector2(panel.position.x + 10, y), "%d  %s" % [i + 1, r["name"]], 10, col)
		_text(Vector2(panel.end.x - 40, y), str(r["points"]), 10, col)


## Returns the y under the last row.
func _score_tally(top: Vector2) -> float:
	var rows: Array[Dictionary] = race.score.summary()
	var panel := Rect2(top.x - 120, top.y - 12, 240, 16 + 13 * (rows.size() + 1))
	draw_rect(panel, Color(0, 0, 0, 0.55))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var label: String = r["name"] if r["count"] == 1 else "%s x%d" % [r["name"], r["count"]]
		var y := top.y + i * 13
		_text(Vector2(panel.position.x + 10, y), label, 10, Color.WHITE)
		_text(Vector2(panel.end.x - 40, y), "+%d" % r["points"], 10, Color("#5dff8a"))
	var ty := top.y + rows.size() * 13 + 2
	_text(Vector2(panel.position.x + 10, ty), "POINTS", 11, Color("#ffd23a"))
	_text(Vector2(panel.end.x - 40, ty), str(race.score.total()), 11, Color("#ffd23a"))
	return panel.end.y


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw(self, pos, s, size, col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw_centered(self, pos, s, size, col)


## The power-up slot under the nitro: the running ram plate or ghost with its time left, or
## for a moment what was just picked up (a mystery hubcap spins open first).
func _power_up_slot(slot: Rect2) -> void:
	var p: PlayerCar = race.player
	draw_rect(slot.grow(-2), Color(0, 0, 0, 0.45))
	draw_texture_rect(PowerUps.texture("icon_slot"), slot, false)
	var icon := slot_icon(p.ram_time, p.ghost_time, race.pickup, race.pickup_gave, race.pickup_age)
	if icon == "":
		return
	var tex := PowerUps.texture(icon)
	var k := minf((slot.size.x - 6.0) / tex.get_width(), (slot.size.y - 6.0) / tex.get_height())
	var size := Vector2(tex.get_width(), tex.get_height()) * k
	draw_texture_rect(tex, Rect2(slot.get_center() - size / 2.0, size), false)
	var left := p.ram_time / PowerUps.RAM_TIME if p.ram_time > 0.0 else p.ghost_time / PowerUps.GHOST_TIME
	if left > 0.0:
		draw_rect(Rect2(slot.end.x + 4, slot.end.y - slot.size.y * left, 3, slot.size.y * left), Color("#7ad8ff"))


## Which sprite the power-up slot shows (PowerUps.texture), or "" for an empty slot.
static func slot_icon(ram_time: float, ghost_time: float, pickup: int, gave: int, age: float) -> String:
	if ram_time > 0.0:
		return "icon_ram"
	if ghost_time > 0.0:
		return "icon_ghost"
	if pickup < 0 or age > 1.5:
		return ""
	if pickup == PowerUps.Kind.MYSTERY and age < 0.5:
		return "reveal_%d" % (mini(3, int(age / 0.125)) + 1)
	return "icon_" + PowerUps.IDS[gave]


## Bursts over the car: a sparkle (or the clock) on a pickup, the impact when ramming.
func _power_up_fx() -> void:
	var car := Vector2(Cfg.SCREEN_W / 2.0, 262.0)
	if race.pickup_age < 0.4:
		var fx := "fx_clock" if race.pickup_gave == PowerUps.Kind.CLOCK else "fx_sparkle"
		var tex := PowerUps.texture(fx)
		var grow: float = 0.6 + race.pickup_age * 1.5
		var size: Vector2 = Vector2(tex.get_width(), tex.get_height()) * grow
		draw_texture_rect(tex, Rect2(car - size / 2.0, size), false, Color(1, 1, 1, 1.0 - race.pickup_age / 0.4))
	if race.ram_flash > 0.0:
		var tex := PowerUps.texture("fx_ram")
		var size := Vector2(tex.get_width(), tex.get_height()) * 1.2
		draw_texture_rect(tex, Rect2(car + Vector2(0, -30) - size / 2.0, size), false, Color(1, 1, 1, race.ram_flash / 0.3))
