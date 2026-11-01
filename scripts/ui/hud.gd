class_name Hud
extends Control
## In-race HUD: timer, place, route progress, nitro flames, power-up, slipstream, an analog
## speedometer with a tach, and the callouts. Drawn in code; where each goes is `layout`.
## In an attract-mode demo: the logo and PRESS START instead.

const LOGO := "res://assets/sprites/ui/logo.png"
const DEMO_LOGO_SCALE := 0.6
const CALLOUT_Y := 120.0  # the middle of the callouts
const GOLD := Color("#ffd23a")
const DIAL_START := PI * 0.75  # the speedometer's zero, bottom left...
const DIAL_SWEEP := PI * 1.5  # ...round to top speed at the bottom right
const REDLINE := 0.9  # engine revs (RaceAudio.engine_rpm) where the tach turns red
## Each starburst's look (Callouts.Kind): the rim, the fill, the lighter core, the text, its
## size and how many spikes.
const BURSTS := {
	Callouts.Kind.GO: {"rim": Color("#1a5a2a"), "fill": Color("#3ad86a"), "core": Color("#a8ffb8"), "text": Color.WHITE, "size": 34, "spikes": 12},
	Callouts.Kind.LAUNCH: {"rim": Color("#6a1a08"), "fill": Color("#ff5a2a"), "core": Color("#ffd23a"), "text": Color.WHITE, "size": 30, "spikes": 14},
	Callouts.Kind.CHECKPOINT: {"rim": Color("#6a3a00"), "fill": Color("#ffb21a"), "core": Color("#ffe36a"), "text": Color.WHITE, "size": 26, "spikes": 16},
	Callouts.Kind.TIME_EXTENDED: {"rim": Color("#0a3a5a"), "fill": Color("#3ad0ff"), "core": Color("#b8f0ff"), "text": Color.WHITE, "size": 22, "spikes": 18},
	Callouts.Kind.NEAR_MISS: {"rim": Color("#5a0a3a"), "fill": Color("#ff4f8b"), "core": Color("#ffa8c8"), "text": Color.WHITE, "size": 22, "spikes": 10},
	Callouts.Kind.BIG_AIR: {"rim": Color("#2a1a6a"), "fill": Color("#8a5aff"), "core": Color("#c8b0ff"), "text": Color.WHITE, "size": 24, "spikes": 14},
	Callouts.Kind.FINAL_STRETCH: {"rim": Color("#5a0a0a"), "fill": Color("#ff3a3a"), "core": Color("#ffb21a"), "text": Color.WHITE, "size": 22, "spikes": 16},
	Callouts.Kind.FIRST_PLACE: {"rim": Color("#6a4a00"), "fill": Color("#ffd23a"), "core": Color("#fff2a8"), "text": Color("#3a1a00"), "size": 28, "spikes": 20},
}

var race: Node  # race.gd
var time := 0.0  # seconds since the HUD appeared, for blinking

var _logo: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo = load(LOGO)


func _process(dt: float) -> void:
	time += dt


func _draw() -> void:
	if race == null or race.player == null or race.results.visible:
		return  # (the results screen covers it)
	if race.demo:
		_draw_demo()
		return
	var p: PlayerCar = race.player
	var w := float(Cfg.SCREEN_W)

	var lay := layout()
	_draw_timer(lay["timer"])
	if not race.rivals.cars.is_empty():
		_draw_position(lay["position"], race.place, race.rivals.cars.size() + 1)
	_draw_progress(lay["progress"], p)
	var stage: Rect2 = lay["stage"]
	_text(stage.position + Vector2(0, 9), ("STAGE %d  " % (race.stage_index + 1)) + race.track.name.to_upper(), 9, Color(1, 1, 1, 0.85))
	_draw_nitro(lay["nitro"], p)
	var pu: PowerUps = race.power_ups
	if not pu.pickups.is_empty():
		_power_up_slot(lay["power_up"])
	_power_up_fx()
	_draw_speedo(lay["speedo"], p)
	_draw_slipstream(lay["slipstream"], p)

	# Device, bottom left
	var device: Rect2 = lay["device"]
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(device.position + Vector2(4, 10), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(device.position + Vector2(4, 22), "F1 input debug   F2 calibrate wheel   R restart", 8, Color(1, 1, 1, 0.45))
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 70), hint, 10, Color("#ffd23a"))

	# Bonuses as they're earned, right of center; the tally under the finish banner
	for i in race.score.feed.size():
		var b: Dictionary = race.score.feed[i]
		var a := clampf((Scoring.FEED_TIME - b["age"]) / 0.4, 0.0, 1.0)
		var feed: Rect2 = lay["feed"]
		_text_centered(Vector2(feed.get_center().x, feed.position.y + 12 + i * 16), "%s +%d" % [b["name"], b["points"]], 12, Color("#5dff8a", a))
	var ended: bool = race.state == race.State.FINISHED or race.state == race.State.TIME_UP
	if race.results.visible:
		pass  # the results screen has the place, time, tally and standings
	elif ended and race.tour and (race.after == race.After.TOUR_DONE or race.after == race.After.TOUR_OVER):
		_tour_standings(Vector2(w / 2.0, 182), "FINAL STANDINGS" if race.after == race.After.TOUR_DONE else "TOUR OVER")
	elif race.state == race.State.FINISHED:
		var end_y := _score_tally(Vector2(w / 2.0, 182))
		if race.tour and race.tour_state.points.has(Tour.YOU):
			var tr: Tour = race.tour_state
			_text_centered(Vector2(w / 2.0, end_y + 14), "TOUR   %s   %d PTS" % [Rivals.ordinal(tr.standing_of(Tour.YOU)),
				tr.points[Tour.YOU]], 11, Color("#ffd23a"))

	if ended and not race.new_unlocks.is_empty() and not race.results.visible:
		_text_centered(Vector2(w / 2.0, 92), unlock_line(race.new_unlocks), 12, Color("#5dff8a", 0.6 + 0.4 * sin(race.road.time * 6.0)))

	# Banners
	if race.counting_down():
		_text_centered(Vector2(w / 2.0, 130), str(ceili(race.countdown)), 64, Color("#ffd23a"))
	if not race.callouts.current.is_empty() and not race.results.visible:
		_draw_callout(race.callouts.current, Vector2(w / 2.0, CALLOUT_Y))


## Where each HUD element goes on the 640x360 screen (the window scales the whole picture):
## the clock, the place, the route bar (with its markers) and the stage under it, the nitro
## flames, the power-up slot, the bonus feed, the slipstream bar, the speedometer and the
## input device.
static func layout() -> Dictionary:
	var w := float(Cfg.SCREEN_W)
	var h := float(Cfg.SCREEN_H)
	return {
		"timer": Rect2(6, 6, 92, 58),
		"position": Rect2(6, 68, 92, 46),
		"progress": Rect2(w / 2.0 - 112, 8, 224, 19),
		"stage": Rect2(w / 2.0 - 110, 29, 220, 11),
		"nitro": Rect2(w - 104, 6, 98, 36),
		"power_up": Rect2(w - 104, 46, 24, 24),
		"feed": Rect2(w * 0.78 - 70, 98, 140, 48),
		"slipstream": Rect2(w - 112, h - 112, 106, 10),
		"speedo": Rect2(w - 112, h - 98, 106, 92),
		"device": Rect2(6, h - 30, 280, 26),
	}


## The route bar inside the progress element (the markers stick out above and below).
static func progress_bar(r: Rect2) -> Rect2:
	return Rect2(r.position.x + 2, r.position.y + 4, r.size.x - 4, 8)


## The clock's size as it beats: under Cfg.LOW_TIME it swells each time the number
## changes and settles back before the next.
static func timer_pulse(t: float) -> float:
	if t >= Cfg.LOW_TIME or t <= 0.0:
		return 1.0
	var since := 1.0 - fposmod(t, 1.0)  # seconds since the number went down
	return 1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.4, since))


## The speedometer's needle angle for `pct` of top speed: 270 degrees clockwise from the
## bottom left, the gap at the bottom for the readout.
static func dial_angle(pct: float) -> float:
	return DIAL_START + DIAL_SWEEP * clampf(pct, 0.0, 1.0)


## The gear the tach shows for `pct` of top speed (RaceAudio.GEARS, as the engine sound).
static func gear(pct: float) -> int:
	for g in RaceAudio.GEARS.size() - 1:
		if pct < RaceAudio.GEARS[g + 1]:
			return g + 1
	return RaceAudio.GEARS.size() - 1


## A nitro flame standing on `base`, `w` wide and `h` tall: round at the bottom, licking up
## to a point with a smaller lick to its left.
static func flame(base: Vector2, w: float, h: float) -> PackedVector2Array:
	var r := w / 2.0
	var c := base - Vector2(0, r)
	var pts := PackedVector2Array()
	for i in 9:  # the round bottom, left to right
		var a := PI - PI * i / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(base + Vector2(r * 0.8, -h * 0.55))
	pts.append(base + Vector2(r * 0.3, -h))
	pts.append(base + Vector2(-r * 0.1, -h * 0.62))
	pts.append(base + Vector2(-r * 0.55, -h * 0.8))
	pts.append(base + Vector2(-r, -h * 0.45))
	return pts


## A dark see-through panel with a gold edge on top, behind a HUD element.
func _panel(r: Rect2, tint := Color(0.04, 0.03, 0.1, 0.5)) -> void:
	draw_rect(r, tint)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(GOLD, 0.8))


## Time, top left: the clock (beating red when it runs low), or in Time Attack the run's
## time, the best and the last split; in Free Drive the run's time.
func _draw_timer(r: Rect2) -> void:
	var t: float = race.time_left
	var beat := (timer_pulse(t) - 1.0) * 4.0 if race.timed() else 0.0
	_panel(r, Color(0.04, 0.03, 0.1, 0.5).lerp(Color(0.6, 0.0, 0.0, 0.6), beat * Settings.flash_amount(1.0)))
	_text(r.position + Vector2(6, 13), "TIME", 10, GOLD)
	if race.free_drive:
		_text(r.position + Vector2(6, 36), clock_text(race.race_time), 20, Color.WHITE)
		_text(r.position + Vector2(6, 52), "FREE DRIVE", 9, Color(1, 1, 1, 0.8))
	elif race.time_attack:
		_text(r.position + Vector2(6, 34), clock_text(race.race_time), 20, Color.WHITE)
		var best: Ghost = race.ghost
		_text(r.position + Vector2(6, 45), "BEST " + (clock_text(best.time) if best != null else "--:--.--"), 9, Color(1, 1, 1, 0.8))
		if not is_nan(race.split) and race.banner_time <= 0.0 and race.state == race.State.RACING:
			var ahead: bool = race.split < 0.0
			_text(r.position + Vector2(6, 55), race.split_text(race.split), 9, Color("#5dff8a") if ahead else Color("#ff6a6a"))
	else:
		var size := roundi(36.0 * timer_pulse(t))
		_text_centered(Vector2(r.get_center().x, r.end.y - 8), str(ceili(t)), size, clock_color(t))


## The place, under the time: a chunky numeral with a hard shadow, its suffix and the field.
func _draw_position(r: Rect2, place: int, field: int) -> void:
	_panel(r)
	_text(r.position + Vector2(6, 13), "POS", 10, GOLD)
	var num := str(place)
	var col := GOLD if place == 1 else Color.WHITE
	var at := Vector2(r.position.x + 8, r.end.y - 5)
	_text(at + Vector2(2, 2), num, 38, Color(0, 0, 0, 0.8))
	_text(at, num, 38, col)
	var nx := at.x + UiText.width(num, 38) + 3
	_text(Vector2(nx, at.y - 16), Rivals.ordinal(place).trim_prefix(num), 12, col)
	_text(Vector2(nx, at.y), "/%d" % field, 12, Color(1, 1, 1, 0.8))


## The route, top center: the run so far, the checkpoints, a checkered finish, a dot for
## each rival (and the ghost) and an arrow for you.
func _draw_progress(r: Rect2, p: PlayerCar) -> void:
	var bar := progress_bar(r)
	draw_rect(bar.grow(2), Color(0, 0, 0, 0.55))
	var progress := clampf(p.distance / race.finish_distance, 0.0, 1.0)
	if race.free_drive:  # the road loops: the bar starts over each time round
		progress = fposmod(p.distance, race.track.length) / race.finish_distance
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("#3ad0ff"))
	for d in race.checkpoint_distances:
		var cx := progress_x(bar, d, race.finish_distance)
		draw_rect(Rect2(cx - 1, bar.position.y - 3, 2, bar.size.y + 6), GOLD)
	for i in 4:  # the finish: a little checkered flag
		draw_rect(Rect2(bar.end.x - 2 + (i % 2) * 3, bar.position.y - 4 + (i / 2) * 3, 3, 3), Color.WHITE if (i + i / 2) % 2 == 0 else Color.BLACK)
	var mid := bar.get_center().y
	for rc: RivalCar in race.rivals.cars:
		var rx := progress_x(bar, rc.distance, race.finish_distance)
		draw_circle(Vector2(rx, mid), 3.0, Color(0, 0, 0, 0.8))
		draw_circle(Vector2(rx, mid), 2.0, Color("#ff4f8b"))
	if race.ghost != null:
		var gx := progress_x(bar, race.ghost_now.x, race.finish_distance)
		draw_circle(Vector2(gx, mid), 3.0, Color(0, 0, 0, 0.8))
		draw_circle(Vector2(gx, mid), 2.0, Color("#9ad8ff"))
	var you := bar.position.x + bar.size.x * minf(progress, 1.0)
	draw_rect(Rect2(you - 1, bar.position.y - 1, 2, bar.size.y + 2), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(you, bar.end.y + 1), Vector2(you + 4, bar.end.y + 6), Vector2(you - 4, bar.end.y + 6)]), Color.WHITE)


## Nitro, top right: a flame for each charge, lit or spent, and the burn running down.
func _draw_nitro(r: Rect2, p: PlayerCar) -> void:
	_text(r.position + Vector2(4, 12), "NITRO", 10, GOLD)
	var slots := maxi(p.nitro_max, p.nitro_charges)
	var gap := minf(18.0, (r.size.x - 12.0) / slots)
	for i in slots:
		var base := Vector2(r.position.x + 10 + i * gap, r.end.y - 4)
		draw_colored_polygon(flame(base + Vector2(0, 1), 14, 23), Color(0, 0, 0, 0.7))
		if i < p.nitro_charges:
			draw_colored_polygon(flame(base, 12, 21), Color("#ff7a1a"))
			draw_colored_polygon(flame(base, 6, 12), Color("#ffe36a"))
		else:
			draw_colored_polygon(flame(base, 12, 21), Color(1, 1, 1, 0.18))
	if p.nitro_time > 0.0:
		draw_rect(Rect2(r.position.x + 4, r.end.y - 1, (r.size.x - 8) * p.nitro_time / p.nitro_duration, 2), Color("#7ad8ff"))


## The speedometer, bottom right: a dial with ticks and a needle, the tach's revs on an
## inner ring with the gear, and the speed in figures in the gap at the bottom.
func _draw_speedo(r: Rect2, p: PlayerCar) -> void:
	var c := Vector2(r.get_center().x, r.position.y + 46)
	var rad := 42.0
	var pct := clampf(p.speed / (Cfg.MAX_SPEED * Cfg.NITRO_SPEED_MULT), 0.0, 1.0)
	draw_circle(c, rad + 2, Color(0.04, 0.03, 0.1, 0.7))
	draw_arc(c, rad + 1, 0, TAU, 48, Color(GOLD, 0.8), 2)
	# The tach: revs on the inner ring, red past the redline
	var rpm := RaceAudio.engine_rpm(p.speed_percent())
	var tach := rad - 17
	draw_arc(c, tach, DIAL_START, DIAL_START + DIAL_SWEEP, 32, Color(1, 1, 1, 0.12), 4)
	var revs := clampf(rpm / 1.2, 0.0, 1.0)
	if revs > 0.0:
		draw_arc(c, tach, DIAL_START, dial_angle(revs), 32, Color("#ff3a3a") if rpm > REDLINE else Color("#5dff8a"), 4)
	for i in 13:
		var dir := Vector2.from_angle(dial_angle(i / 12.0))
		var major := i % 3 == 0
		var col := Color("#ff5a2a") if i >= 10 else Color.WHITE
		draw_line(c + dir * (rad - (8.0 if major else 4.0)), c + dir * (rad - 1), col, 2.0 if major else 1.0)
	_text_centered(c + Vector2(0, -6), str(gear(p.speed_percent())), 10, Color(GOLD, 0.9))
	# The needle
	var tip := c + Vector2.from_angle(dial_angle(pct)) * (rad - 4)
	draw_line(c + Vector2(1, 1), tip + Vector2(1, 1), Color(0, 0, 0, 0.6), 2.0)
	draw_line(c, tip, Color("#ff3a2a"), 2.0)
	draw_circle(c, 4.0, Color(0.1, 0.1, 0.1))
	draw_circle(c, 2.0, GOLD)
	var shown: Array = Settings.speedometer(p.speed)
	_text_centered(c + Vector2(0, 33), str(shown[0]), 16, Color.WHITE)
	_text_centered(c + Vector2(0, 43), shown[1], 7, GOLD)


## Slipstream, over the speedometer: the meter filling, then the boost running down; dim
## while there's no one to draft.
func _draw_slipstream(r: Rect2, p: PlayerCar) -> void:
	var on := p.draft > 0.0 or p.draft_time > 0.0
	_text(r.position + Vector2(0, 8), "SLIPSTREAM", 8, Color("#7ad8ff", 1.0 if on else 0.4))
	var bar := Rect2(r.position.x + 54, r.position.y + 3, r.size.x - 56, 5)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.55))
	if on:
		var fill := p.draft_time / Draft.BOOST_TIME if p.draft_time > 0.0 else p.draft
		var col := Color("#ffe36a") if p.draft_time > 0.0 else Color("#7ad8ff")
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), col)


## A callout (Callouts.current) centered on `center`: a plain message as gold text, or a
## starburst in its kind's colors with the text over it.
func _draw_callout(c: Dictionary, center: Vector2) -> void:
	var kind: Callouts.Kind = c["kind"]
	if kind == Callouts.Kind.MESSAGE:
		_text_centered(center + Vector2(0, 10), c["text"], 44, Color("#ffd23a"))
		if c["sub"] != "":
			_text_centered(center + Vector2(0, 36), c["sub"], 14, Color.WHITE)
		return
	var style: Dictionary = BURSTS[kind]
	var a := Callouts.alpha(c)
	var k := Callouts.pop_scale(c["age"])
	var text := Callouts.label(c)
	var size: int = style["size"]
	var radius := burst_radius(text, size) * k
	var spin := sin(time * 2.0) * 0.06
	var spikes: int = style["spikes"]
	draw_colored_polygon(Callouts.starburst(center + Vector2(0, 4), radius * 1.12, spikes, 0.74, spin), Color(0, 0, 0, 0.45 * a))
	draw_colored_polygon(Callouts.starburst(center, radius * 1.12, spikes, 0.74, spin), Color(style["rim"], a))
	draw_colored_polygon(Callouts.starburst(center, radius, spikes, 0.74, spin), Color(style["fill"], a))
	draw_colored_polygon(Callouts.starburst(center, radius * 0.7, spikes, 0.86, -spin), Color(style["core"], a))
	if k < 0.9:
		return  # (the text comes in with the burst nearly grown)
	var ty := center.y + size * 0.35 - (6.0 if c["sub"] != "" else 0.0)
	_text_centered(Vector2(center.x, ty), text, size, Color(style["text"], a))
	if c["sub"] != "":
		_text_centered(Vector2(center.x, ty + 15), c["sub"], 11, Color(1, 1, 1, a))


## A starburst's half-size for `text` at `size`: room round the text, and never so flat
## it stops looking like a burst.
static func burst_radius(text: String, size: int) -> Vector2:
	var tw := UiText.width(text, size)
	return Vector2(maxf(tw / 2.0 + 30.0, 70.0), maxf(size * 1.25, 34.0))


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


## The clock's color: white, then blinking red under Cfg.LOW_TIME. The flash option scales
## the blink: at 0 the clock turns steady red instead.
static func clock_color(t: float) -> Color:
	if t >= Cfg.LOW_TIME:
		return Color.WHITE
	var red := Color("#ff4040")
	return red if int(t * 4.0) % 2 == 0 else red.lerp(Color.WHITE, Settings.flash_amount(1.0))


## The ram plate's impact flash (0.3 s when it hits) as an alpha, after the flash option.
static func ram_flash_alpha(ram_flash: float) -> float:
	return Settings.flash_amount(clampf(ram_flash / 0.3, 0.0, 1.0))


## The demo's overlay: the logo up top, the stage under it, PRESS START blinking below.
func _draw_demo() -> void:
	var w := float(Cfg.SCREEN_W)
	var y := 8.0
	if _logo != null:
		var size := Vector2(_logo.get_width(), _logo.get_height()) * DEMO_LOGO_SCALE
		draw_texture_rect(_logo, Rect2(Vector2(roundf((w - size.x) / 2.0), y), size.round()), false)
		y += size.y
	draw_rect(Rect2(w / 2.0 - 90, y + 1, 180, 13), Color(0, 0, 0, 0.45))
	_text_centered(Vector2(w / 2.0, y + 11), race.track.name.to_upper(), 9, Color(1, 1, 1, 0.9))
	draw_rect(Rect2(0, Cfg.SCREEN_H - 34, w, 20), Color(0, 0, 0, 0.45))
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, Cfg.SCREEN_H - 19), "PRESS START", 12, Color("#ffd23a"))


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
		draw_texture_rect(tex, Rect2(car + Vector2(0, -30) - size / 2.0, size), false, Color(1, 1, 1, ram_flash_alpha(race.ram_flash)))
