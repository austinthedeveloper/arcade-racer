class_name Hud
extends Control
## In-race HUD: timer, place, route progress, nitro flames, power-up, slipstream, an analog
## speedometer with a tach, the callouts, and the rivals: a card each before GO and a radar
## arrow for one close by (RC-18). Drawn in code; where each goes is `layout`.
## In an attract-mode demo: the logo and PRESS START instead.

const LOGO := "res://assets/sprites/ui/logo.png"
const DEMO_LOGO_SCALE := 0.6
const CALLOUT_Y := 120.0  # the middle of the callouts
const LINE2_SIZE := 18  # a starburst's second headline (TIME EXTENDED under CHECKPOINT)
const SUB_SIZE := 11  # and its small line
const LINE_GAP := 4.0  # pixels between a starburst's lines
const CARD_SIZE := Vector2(150, 22)  # a rival's card before GO (RC-18)
const CARD_GAP := 2.0
const PORTRAIT := Vector2(18, 18)  # the card's portrait slot (initials until CP-13's portraits)
const RADAR_TIME := 1.0  # seconds behind or ahead a rival gets a radar arrow
const RADAR_REACH := 2.0  # road half-widths either side the radar strip spans
const RADAR_ARROW := Vector2(9, 7)  # an arrow's width and height
const GOLD := Color("#ffd23a")
const DIAL_START := PI * 0.75  # the speedometer's zero, bottom left...
const DIAL_SWEEP := PI * 1.5  # ...round to top speed at the bottom right
const REDLINE := 0.9  # engine revs (RaceAudio.engine_rpm) where the tach turns red
## The HUD colors that carry meaning. Each state also differs in shape (the low clock beats
## and shows a warning sign, the leader's panel has a crown, spent flames are hollow, the
## ghost's dot is a ring, the slipstream boost says BOOST); MUST_DIFFER pairs also differ
## in brightness for the common color deficiencies (ColorVision, AC-4).
const PALETTE := {
	"panel": Color("#0a0818"),
	"lead_panel": Color("#ffd23a"),
	"lead_text": Color("#2a1400"),
	"clock": Color.WHITE,
	"clock_low": Color("#ff4040"),
	"you": Color.WHITE,
	"rival": Color("#ff4f8b"),
	"ghost": Color("#9ad8ff"),
	"nitro_lit": Color("#ff7a1a"),
	"nitro_spent": Color("#5a5a5a"),
	"ahead": Color("#5dff8a"),
	"behind": Color("#ff6a6a"),
	"slip_meter": Color("#2a7ad8"),
	"slip_boost": Color("#fff2a8"),
	"tach": Color("#5dff8a"),
	"tach_red": Color("#ff3a3a"),
	"net_good": Color("#5dff8a"),
	"net_fair": Color("#ffb21a"),
	"net_poor": Color("#c81e28"),
	"net_unknown": Color("#8a8a9a"),
}
const MUST_DIFFER := [
	["clock", "clock_low"], ["panel", "lead_panel"], ["lead_panel", "lead_text"], ["you", "rival"],
	["rival", "ghost"], ["nitro_lit", "nitro_spent"], ["ahead", "behind"], ["slip_meter", "slip_boost"],
	["tach", "tach_red"], ["net_good", "net_poor"], ["net_fair", "net_poor"],
]
## Simulated luminance contrast every MUST_DIFFER pair keeps (1 is none; text on a page
## asks 4.5, a pair of states on one gauge much less).
const MIN_STATE_CONTRAST := 1.5
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

	var lay := layout(TouchControls.showing() and race.touch_driving())
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
	if race.counting_down() and not race.rivals.cars.is_empty():
		_draw_cards(lay["cards"])
	elif race.state == race.State.RACING:
		_draw_radar(lay["radar"], p)
	if Tuning.any_tuned():
		_draw_tuned(lay["tuned"])

	# Device, bottom left
	var device: Rect2 = lay["device"]
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	if device.has_area():  # (not under the touch controls)
		_text(device.position + Vector2(4, 10), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
		_text(device.position + Vector2(4, 22), keys_hint(race.online != null), 8, Color(1, 1, 1, 0.6))
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
	elif watching_shown():
		_draw_watch(Vector2(w / 2.0, 150))
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
		StageIntro.draw(self, race.countdown_elapsed(), lay["intro"], intro_text())
	if not race.callouts.current.is_empty() and not race.results.visible and not watching_shown():
		_draw_callout(race.callouts.current, Vector2(w / 2.0, CALLOUT_Y))
	if Settings.subtitles:
		_draw_subtitle(lay["subtitle"], race.audio.announcer.subtitle())
	if race.notice_time > 0.0:
		_draw_notice(Vector2(w / 2.0, 72), race.notice, notice_alpha(race.notice_time))


## The connection dot (ON-12), top right of the time panel: green, amber or red for the
## relay's round trip, with the milliseconds beside it (not the color alone); a grey ring
## before the first comes back. Red is a ring too, blinking where flashing is allowed.
func _draw_net(c: Vector2, ms: float) -> void:
	var q := OnlineSession.quality(ms)
	var col := net_color(q)
	draw_circle(c, 4.5, Color(0, 0, 0, 0.8))
	if q == OnlineSession.Quality.UNKNOWN:
		draw_arc(c, 3.0, 0.0, TAU, 12, col, 1.5)
		return
	if q == OnlineSession.Quality.POOR and int(time * 3.0) % 2 == 0 and Settings.flash_amount(1.0) > 0.5:
		draw_arc(c, 3.0, 0.0, TAU, 12, col, 1.5)
	else:
		draw_circle(c, 3.5, col)
	var label := "%d" % roundi(ms)
	_text(Vector2(c.x - 7 - UiText.width(label, 8), c.y + 3), label, 8, Color(1, 1, 1, 0.75))


## The dot's color for a quality (OnlineSession.Quality).
static func net_color(q: int) -> Color:
	match q:
		OnlineSession.Quality.GOOD:
			return PALETTE["net_good"]
		OnlineSession.Quality.FAIR:
			return PALETTE["net_fair"]
		OnlineSession.Quality.POOR:
			return PALETTE["net_poor"]
	return PALETTE["net_unknown"]


## An online notice (ON-11), "P2 DROPPED OUT": a dark pill with a red dot, under the route bar
## and the subtitle, fading out over its last half second.
func _draw_notice(center: Vector2, text: String, a: float) -> void:
	var tw := UiText.width(text, 11)
	var r := Rect2(center.x - tw / 2.0 - 18, center.y - 10, tw + 30, 20)
	draw_rect(r, Color(0.04, 0.03, 0.1, 0.8 * a))
	draw_rect(Rect2(r.position.x, r.position.y, 2, r.size.y), Color(PALETTE["behind"], a))
	draw_circle(Vector2(r.position.x + 10, center.y), 3.5, Color(PALETTE["behind"], a))
	_text(Vector2(r.position.x + 20, center.y + 4), text, 11, Color(1, 1, 1, a))


## A notice's alpha with `left` seconds to go: whole, then fading over the last half second.
static func notice_alpha(left: float) -> float:
	return clampf(left / 0.5, 0.0, 1.0)


## The stage intro card's text (PR-16) for this race.
func intro_text() -> Dictionary:
	return StageIntro.lines(race.stage_index, race.mirror, race.track.theme, race.finish_distance, Settings.units,
		SaveData.stage_best(race.stage_index), Settings.difficulty, not race.free_drive)


## Where each HUD element goes on the 640x360 screen (the window scales the whole picture):
## the clock, the place, the route bar (with its markers) and the stage under it, the nitro
## flames, the power-up slot, the bonus feed, the slipstream bar, the speedometer, the
## input device, the announcer's subtitle, the rival cards, the radar and the stage intro card. With the touch controls up (`touch`,
## TouchControls), the speedometer sits between the thumbs and the device line goes.
static func layout(touch := false) -> Dictionary:
	var w := float(Cfg.SCREEN_W)
	var h := float(Cfg.SCREEN_H)
	if touch:
		var lay := layout()
		lay["speedo"] = Rect2(w / 2.0 - 53, h - 98, 106, 92)
		lay["slipstream"] = Rect2(w / 2.0 - 53, h - 112, 106, 10)
		lay["device"] = Rect2()
		lay["cards"] = Rect2(w / 2.0 - CARD_SIZE.x - 3, 150, CARD_SIZE.x * 2 + 6, 4 * (CARD_SIZE.y + CARD_GAP) - CARD_GAP)
		return lay
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
		"subtitle": Rect2(w / 2.0 - 160, 46, 320, 18),
		"tuned": Rect2(w / 2.0 + 118, 10, 40, 13),
		"cards": Rect2(6, 120, CARD_SIZE.x, Rivals.COUNT * (CARD_SIZE.y + CARD_GAP) - CARD_GAP),
		"radar": Rect2(w / 2.0 - 90, 192, 180, 16),
		"intro": Rect2(Vector2(w - 14 - StageIntro.CARD.x, 76), StageIntro.CARD),
	}


## The rival cards' places in `area` (layout's "cards"): down a column, then the next column.
static func card_rects(area: Rect2, count: int) -> Array[Rect2]:
	var rows := maxi(1, floori((area.size.y + CARD_GAP) / (CARD_SIZE.y + CARD_GAP)))
	var out: Array[Rect2] = []
	for i in count:
		var col := i / rows
		out.append(Rect2(area.position + Vector2(col * (CARD_SIZE.x + 6), (i % rows) * (CARD_SIZE.y + CARD_GAP)), CARD_SIZE))
	return out


## Where a card's parts go: the portrait slot, then the name and the car-and-style line by it.
static func card_parts(card: Rect2) -> Dictionary:
	var slot := Rect2(card.position + Vector2(3, 2), PORTRAIT)
	var text_x := slot.end.x + 5
	return {"portrait": slot, "name": Vector2(text_x, card.position.y + 10), "line": Vector2(text_x, card.position.y + 19),
		"text_width": card.end.x - 3 - text_x}


## A card's words: the driver, the car and the style (an online player is ONLINE).
static func card_text(profile: RivalProfile, remote: bool) -> Dictionary:
	var car: Dictionary = Cars.find(profile.car_id)
	return {"name": profile.driver, "car": String(car.get("name", "")).to_upper(),
		"style": "ONLINE" if remote else RivalProfile.style_name(profile.style),
		"initials": "".join(Array(profile.driver.split(" ", false)).map(func(w: String) -> String: return w.left(1))).left(2).to_upper()}


## The radar (RC-18): an arrow for each rival within RADAR_TIME of you at your speed, ahead
## (pointing up) or behind (pointing down), across `area` by where it is across the road.
## `others` are [distance, x] for each rival still racing. Returns {"at", "ahead", "near"}
## ("at" the arrow's middle, "near" 1 alongside down to 0 at RADAR_TIME), nearest last.
static func radar(area: Rect2, distance: float, x: float, speed: float, others: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Array in others:
		var gap: float = o[0] - distance
		var secs := absf(gap) / maxf(speed, 1.0)
		if secs > RADAR_TIME:
			continue
		var across := clampf((o[1] - x) / RADAR_REACH, -1.0, 1.0)
		var ax := area.get_center().x + across * (area.size.x - RADAR_ARROW.x) / 2.0
		out.append({"at": Vector2(roundf(ax), area.get_center().y), "ahead": gap >= 0.0, "near": 1.0 - secs / RADAR_TIME})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["near"] < b["near"])
	return out


## A radar arrow centered on `at`: a triangle pointing up for a rival ahead, down for behind.
static func radar_arrow(at: Vector2, ahead: bool, size := RADAR_ARROW) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	if ahead:
		return PackedVector2Array([at + Vector2(0, -hh), at + Vector2(hw, hh), at + Vector2(-hw, hh)])
	return PackedVector2Array([at + Vector2(-hw, -hh), at + Vector2(hw, -hh), at + Vector2(0, hh)])


## Before GO, a card per rival (RC-18), front of the grid first: a portrait slot with the
## driver's initials (portraits come with CP-13), the name, and the car and style under it.
func _draw_cards(area: Rect2) -> void:
	var order: Array = race.rivals.cars.filter(func(r: RivalCar) -> bool: return r.profile != null)
	order.sort_custom(func(a: RivalCar, b: RivalCar) -> bool: return a.distance > b.distance)
	var rects := card_rects(area, order.size())
	for i in order.size():
		var r: RivalCar = order[i]
		var card: Rect2 = rects[i]
		var parts := card_parts(card)
		var words := card_text(r.profile, r.remote)
		draw_rect(card, Color(0.04, 0.03, 0.1, 0.72))
		draw_rect(Rect2(card.position, Vector2(2, card.size.y)), PALETTE["rival"])
		var slot: Rect2 = parts["portrait"]
		draw_rect(slot, Color(0, 0, 0, 0.6))
		draw_rect(slot, Color(PALETTE["rival"], 0.8), false, 1.0)
		_text_centered(Vector2(slot.get_center().x, slot.end.y - 5), words["initials"], 8, Color(1, 1, 1, 0.8))
		_text(parts["name"], words["name"], 9, Color.WHITE)
		var line: Vector2 = parts["line"]
		_text(line, words["car"], 8, Color(1, 1, 1, 0.75))
		_text(line + Vector2(UiText.width(words["car"] + "  ", 8), 0), words["style"], 8, GOLD)


## The radar arrows over the car (RC-18), brighter the closer the rival.
func _draw_radar(area: Rect2, p: PlayerCar) -> void:
	var others: Array = []
	for r: RivalCar in race.rivals.cars:
		if not r.finished:
			others.append([r.distance, r.x])
	for a in radar(area, p.distance, p.x, p.speed, others):
		var alpha := lerpf(0.55, 1.0, a["near"])
		draw_colored_polygon(radar_arrow(a["at"] + Vector2(0, 1), a["ahead"], RADAR_ARROW + Vector2(4, 4)), Color(0, 0, 0, 0.7 * alpha))
		draw_colored_polygon(radar_arrow(a["at"], a["ahead"]), Color(PALETTE["rival"], alpha))


## TUNED: the debug panel (F3) has changed something from the defaults, so this isn't the
## game as designed.
func _draw_tuned(r: Rect2) -> void:
	_panel(r, Color(1.0, 0.6, 0.23, 0.85))
	_text_centered(Vector2(r.get_center().x, r.end.y - 3), "TUNED", 8, Color(0.08, 0.05, 0.12))


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


## The gear the tach shows for `pct` of top speed (PlayerCar.GEARS, as the engine sound)
## with the automatic; manual gears show PlayerCar.shown_gear.
static func gear(pct: float) -> int:
	return PlayerCar.auto_gear(pct)


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
	if race.free_drive or race.online != null:
		_text(r.position + Vector2(6, 36), clock_text(race.race_time), 20, Color.WHITE)
		var tag: String = "FREE DRIVE" if race.free_drive else "ONLINE  " + race.online.link.room
		_text(r.position + Vector2(6, 52), tag, 9, Color(1, 1, 1, 0.8))
		if race.online != null:
			_draw_net(Vector2(r.end.x - 9, r.position.y + 9), race.online.round_trip_ms())
	elif race.time_attack:
		_text(r.position + Vector2(6, 34), clock_text(race.race_time), 20, Color.WHITE)
		var best: Ghost = race.ghost
		_text(r.position + Vector2(6, 45), "BEST " + (clock_text(best.time) if best != null else "--:--.--"), 9, Color(1, 1, 1, 0.8))
		if not is_nan(race.split) and race.banner_time <= 0.0 and race.state == race.State.RACING:
			var ahead: bool = race.split < 0.0
			_text(r.position + Vector2(6, 55), race.split_text(race.split), 9, PALETTE["ahead"] if ahead else PALETTE["behind"])
	else:
		var size := roundi(36.0 * timer_pulse(t))
		_text_centered(Vector2(r.get_center().x, r.end.y - 8), str(ceili(t)), size, clock_color(t))
		if t < Cfg.LOW_TIME and t > 0.0:  # a warning sign by TIME, not just the color
			var sign := warning_sign(Vector2(r.end.x - 13, r.position.y + 15), 14.0)
			draw_colored_polygon(warning_sign(Vector2(r.end.x - 13, r.position.y + 16), 17.0), Color(0, 0, 0, 0.8))
			draw_colored_polygon(sign, PALETTE["clock_low"])
			draw_rect(Rect2(r.end.x - 14, r.position.y + 12, 2, 4), Color.BLACK)
			draw_rect(Rect2(r.end.x - 14, r.position.y + 17, 2, 2), Color.BLACK)


## The place, under the time: a chunky numeral with a hard shadow, its suffix and the field.
## In the lead the panel turns gold, the figures dark, with a crown: not the color alone.
func _draw_position(r: Rect2, place: int, field: int) -> void:
	var lead := place == 1
	if lead:
		draw_rect(r.grow(1), Color(0, 0, 0, 0.7), false, 1.0)  # (apart from sand and sunsets)
		draw_rect(r, PALETTE["lead_panel"])
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color.WHITE)
	else:
		_panel(r)
	var ink: Color = PALETTE["lead_text"] if lead else Color.WHITE
	_text(r.position + Vector2(6, 13), "POS", 10, ink if lead else GOLD)
	var num := str(place)
	var at := Vector2(r.position.x + 8, r.end.y - 5)
	if not lead:
		_text(at + Vector2(2, 2), num, 38, Color(0, 0, 0, 0.8))
	_text(at, num, 38, ink)
	var nx := at.x + UiText.width(num, 38) + 3
	_text(Vector2(nx, at.y - 16), Rivals.ordinal(place).trim_prefix(num), 12, ink)
	_text(Vector2(nx, at.y), "/%d" % field, 12, ink if lead else Color(1, 1, 1, 0.8))
	if lead:
		draw_colored_polygon(crown(Vector2(r.end.x - 16, r.position.y + 17), 18.0, 11.0), PALETTE["lead_text"])


## A warning triangle, point up, `size` across, its middle at `center`.
static func warning_sign(center: Vector2, size: float) -> PackedVector2Array:
	var h := size * 0.87
	return PackedVector2Array([center + Vector2(0, -h / 2.0), center + Vector2(size / 2.0, h / 2.0), center + Vector2(-size / 2.0, h / 2.0)])


## A three-pointed crown standing on `base` (the middle of its bottom edge), `w` by `h`.
static func crown(base: Vector2, w: float, h: float) -> PackedVector2Array:
	var l := base.x - w / 2.0
	return PackedVector2Array([
		Vector2(l, base.y), Vector2(l, base.y - h), Vector2(l + w * 0.25, base.y - h * 0.45),
		Vector2(base.x, base.y - h), Vector2(l + w * 0.75, base.y - h * 0.45), Vector2(l + w, base.y - h),
		Vector2(l + w, base.y),
	])


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
		draw_circle(Vector2(rx, mid), 2.0, PALETTE["rival"])
	if race.ghost != null:  # a ring, not a dot
		var gx := progress_x(bar, race.ghost_now.x, race.finish_distance)
		draw_circle(Vector2(gx, mid), 4.0, Color(0, 0, 0, 0.8))
		draw_arc(Vector2(gx, mid), 2.5, 0, TAU, 12, PALETTE["ghost"], 1.5)
	var you := bar.position.x + bar.size.x * minf(progress, 1.0)
	draw_rect(Rect2(you - 1, bar.position.y - 1, 2, bar.size.y + 2), PALETTE["you"])
	draw_colored_polygon(PackedVector2Array([Vector2(you, bar.end.y + 1), Vector2(you + 4, bar.end.y + 6), Vector2(you - 4, bar.end.y + 6)]), PALETTE["you"])


## Nitro, top right: a flame for each charge, lit (filled) or spent (hollow), and the burn
## running down.
func _draw_nitro(r: Rect2, p: PlayerCar) -> void:
	_text(r.position + Vector2(4, 12), "NITRO", 10, GOLD)
	var slots := maxi(p.nitro_max, p.nitro_charges)
	var gap := minf(18.0, (r.size.x - 12.0) / slots)
	for i in slots:
		var base := Vector2(r.position.x + 10 + i * gap, r.end.y - 4)
		if i < p.nitro_charges:
			draw_colored_polygon(flame(base + Vector2(0, 1), 14, 23), Color(0, 0, 0, 0.7))
			draw_colored_polygon(flame(base, 12, 21), PALETTE["nitro_lit"])
			draw_colored_polygon(flame(base, 6, 12), Color("#ffe36a"))
		else:
			var outline := flame(base, 11, 20)
			outline.append(outline[0])
			draw_polyline(outline, Color(0, 0, 0, 0.6), 3.0)
			draw_polyline(outline, PALETTE["nitro_spent"], 1.0)
	if p.nitro_time > 0.0:
		draw_rect(Rect2(r.position.x + 4, r.end.y - 1, (r.size.x - 8) * p.nitro_time / p.nitro_duration, 2), Color("#7ad8ff"))


## The speedometer, bottom right: a dial with ticks and a needle, the tach's revs on an
## inner ring with the gear, and the speed in figures in the gap at the bottom.
func _draw_speedo(r: Rect2, p: PlayerCar) -> void:
	var c := Vector2(r.get_center().x, r.position.y + 46)
	var rad := 42.0
	var pct := clampf(p.speed / (Cfg.MAX_SPEED * Tuning.v("driving/nitro_speed")), 0.0, 1.0)
	draw_circle(c, rad + 2, Color(0.04, 0.03, 0.1, 0.7))
	draw_arc(c, rad + 1, 0, TAU, 48, Color(GOLD, 0.8), 2)
	# The tach: revs on the inner ring, red past the redline
	var rpm := RaceAudio.engine_rpm(p.speed_percent(), p.gear if p.manual else 0)
	var tach := rad - 17
	draw_arc(c, tach, DIAL_START, DIAL_START + DIAL_SWEEP, 32, Color(1, 1, 1, 0.12), 4)
	var revs := clampf(rpm / 1.2, 0.0, 1.0)
	if revs > 0.0:
		draw_arc(c, tach, DIAL_START, dial_angle(revs), 32, PALETTE["tach_red"] if rpm > REDLINE else PALETTE["tach"], 4)
	for i in 13:
		var dir := Vector2.from_angle(dial_angle(i / 12.0))
		var major := i % 3 == 0
		var col := Color("#ff5a2a") if i >= 10 else Color.WHITE
		draw_line(c + dir * (rad - (8.0 if major else 4.0)), c + dir * (rad - 1), col, 2.0 if major else 1.0)
	_text_centered(c + Vector2(0, -6), str(p.shown_gear()), 10, Color(GOLD, 0.9))
	# The needle
	var tip := c + Vector2.from_angle(dial_angle(pct)) * (rad - 4)
	draw_line(c + Vector2(1, 1), tip + Vector2(1, 1), Color(0, 0, 0, 0.6), 2.0)
	draw_line(c, tip, Color("#ff3a2a"), 2.0)
	draw_circle(c, 4.0, Color(0.1, 0.1, 0.1))
	draw_circle(c, 2.0, GOLD)
	var shown: Array = Settings.speedometer(p.speed)
	_text_centered(c + Vector2(0, 33), str(shown[0]), 16, Color.WHITE)
	_text_centered(c + Vector2(0, 43), shown[1], 8, GOLD)


## Slipstream, over the speedometer: the meter filling, then the boost (BOOST, a bright bar
## with chevrons) running down; dim while there's no one to draft.
func _draw_slipstream(r: Rect2, p: PlayerCar) -> void:
	var on := p.draft > 0.0 or p.draft_time > 0.0
	var boost := p.draft_time > 0.0
	_text(r.position + Vector2(0, 8), "BOOST" if boost else "SLIPSTREAM", 8,
		PALETTE["slip_boost"] if boost else Color("#7ad8ff", 1.0 if on else 0.4))
	var bar := Rect2(r.position.x + 54, r.position.y + 3, r.size.x - 56, 5)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.55))
	if not on:
		return
	var fill := clampf(p.draft_time / Tuning.v("draft/boost_time") if boost else p.draft, 0.0, 1.0)
	var filled := Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y))
	draw_rect(filled, PALETTE["slip_boost"] if boost else PALETTE["slip_meter"])
	if boost:
		var x := filled.position.x + 2
		while x + 3 <= filled.end.x:
			draw_polyline(PackedVector2Array([Vector2(x, bar.position.y), Vector2(x + 2, bar.get_center().y), Vector2(x, bar.end.y)]), Color(0, 0, 0, 0.5), 1.0)
			x += 5


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
	var size: int = style["size"]
	var lines := burst_lines(c, size)
	var radius := burst_radius_for(lines) * k
	var spin := sin(time * 2.0) * 0.06
	var spikes: int = style["spikes"]
	draw_colored_polygon(Callouts.starburst(center + Vector2(0, 4), radius * 1.12, spikes, 0.74, spin), Color(0, 0, 0, 0.45 * a))
	draw_colored_polygon(Callouts.starburst(center, radius * 1.12, spikes, 0.74, spin), Color(style["rim"], a))
	draw_colored_polygon(Callouts.starburst(center, radius, spikes, 0.74, spin), Color(style["fill"], a))
	draw_colored_polygon(Callouts.starburst(center, radius * 0.7, spikes, 0.86, -spin), Color(style["core"], a))
	if k < 0.9:
		return  # (the text comes in with the burst nearly grown)
	for i in lines.size():
		var line: Dictionary = lines[i]
		var col: Color = style["text"] if i == 0 else (BURSTS[Callouts.Kind.TIME_EXTENDED]["fill"] if line["size"] == LINE2_SIZE else Color.WHITE)
		_text_centered(Vector2(center.x, center.y + line["y"]), line["text"], line["size"], Color(col, a))


## The lines a starburst shows, top to bottom: {"text", "size", "y"} with "y" the baseline
## below the burst's middle. The headline (with its count), a second headline when it has
## one (TIME EXTENDED under CHECKPOINT, PR-15) and the small line under them.
static func burst_lines(c: Dictionary, size: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"text": Callouts.label(c), "size": size}]
	if c.get("line2", "") != "":
		out.append({"text": c["line2"], "size": LINE2_SIZE})
	if c["sub"] != "":
		out.append({"text": c["sub"], "size": SUB_SIZE})
	# Stacked baselines, a little apart, the block's middle on the burst's
	var tall := 0.0
	for line in out:
		tall += line["size"] * 0.75 + (LINE_GAP if not is_same(line, out[0]) else 0.0)
	var y := -tall / 2.0
	for i in out.size():
		y += out[i]["size"] * 0.75 + (LINE_GAP if i > 0 else 0.0)
		out[i]["y"] = roundf(y)
	return out


## The burst's half-size for its lines: wide enough for the widest, tall enough for the stack.
static func burst_radius_for(lines: Array[Dictionary]) -> Vector2:
	var r := burst_radius(lines[0]["text"], lines[0]["size"])
	var top: float = lines[0]["y"] - lines[0]["size"] * 0.75
	var bottom: float = lines[-1]["y"]
	for line in lines.slice(1):
		r.x = maxf(r.x, UiText.width(line["text"], line["size"]) / 2.0 + 30.0)
	r.y = maxf(r.y, maxf(-top, bottom) / 0.62)
	return r


## A starburst's half-size for `text` at `size`: room round the text, and never so flat
## it stops looking like a burst.
## The announcer's words (AC-5), on a dark strip sized to the line.
func _draw_subtitle(r: Rect2, line: String) -> void:
	if line == "":
		return
	var tw := minf(UiText.width(line, 11) + 16.0, r.size.x)
	_panel(Rect2(r.get_center().x - tw / 2.0, r.position.y, tw, r.size.y), Color(0, 0, 0, 0.6))
	_text_centered(Vector2(r.get_center().x, r.position.y + 13), line, 11, Color.WHITE)


static func burst_radius(text: String, size: int) -> Vector2:
	var tw := UiText.width(text, size)
	return Vector2(maxf(tw / 2.0 + 30.0, 70.0), maxf(size * 1.25, 34.0))


## A run's time as m:ss.cc.
## The dev keys under the device line (no R restart online, where restart is off).
static func keys_hint(online: bool) -> String:
	return "F1 input debug   F2 calibrate wheel   F3 tuning" + ("" if online else "   R restart")


static func clock_text(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


## The finish's notice of cars it opened (Unlocks.newly_open) and a stage mirror it won
## (Unlocks.mirror_id).
static func unlock_line(ids: Array[String]) -> String:
	var names: Array[String] = []
	var parts: Array[String] = []
	for id in ids:
		if id.begins_with("mirror_"):
			continue
		names.append(String(Cars.find(id)["name"]).to_upper())
	if not names.is_empty():
		parts.append(("NEW CAR: " if names.size() == 1 else "NEW CARS: ") + ", ".join(names))
	for i in Stages.count():
		if ids.has(Unlocks.mirror_id(i)):
			parts.append("MIRROR MODE: " + Stages.stage_name(i).to_upper())
	return "   ".join(parts)


## Where a racer `distance` along the stage sits on the progress bar.
static func progress_x(bar: Rect2, distance: float, finish_distance: float) -> float:
	return bar.position.x + bar.size.x * clampf(distance / finish_distance, 0.0, 1.0)


## Whether the live standings are up (ON-10): watching, once the finish's own moment is over.
func watching_shown() -> bool:
	return race.state == race.State.FINISHED and race.watching != null and race.finish_age >= race.RESULTS_AFTER


## The live standings while watching after the finish online (ON-10): "WATCHING P2" over
## the field in race order, times for those in and RACING for the rest, the car the camera
## follows marked.
func _draw_watch(top: Vector2) -> void:
	var watched: RivalCar = race.watching
	var rows := watch_rows(race)
	var panel := Rect2(top.x - 110, top.y - 14, 220, 34 + 13 * rows.size())
	draw_rect(panel, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2)), Color(GOLD, 0.8))
	_text_centered(Vector2(top.x, top.y), "WATCHING  " + watched.profile.driver, 11, GOLD)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := top.y + 16 + i * 13
		var on: bool = not r["you"] and r["name"] == watched.profile.driver
		var col := Color("#5dff8a") if r["you"] else (GOLD if on else Color.WHITE)
		if on:
			draw_colored_polygon(PackedVector2Array([Vector2(panel.position.x + 6, y - 7), Vector2(panel.position.x + 11, y - 4),
				Vector2(panel.position.x + 6, y - 1)]), GOLD)
		_text(Vector2(panel.position.x + 14, y), "%d  %s" % [r["place"], r["name"]], 10, col)
		var t: float = r["time"]
		var tt := clock_text(t) if t >= 0.0 else "RACING"
		_text(Vector2(panel.end.x - 10 - UiText.width(tt, 10), y), tt, 10, col if t >= 0.0 else Color(1, 1, 1, 0.6))
	_text_centered(Vector2(top.x, panel.end.y - 6), "Enter: results", 8, Color(1, 1, 1, 0.6))


## The live standings' rows (ResultsScreen.rows) for race `r` (race.gd): everyone in race order.
static func watch_rows(r: Node) -> Array[Dictionary]:
	return ResultsScreen.rows(r.rivals.standings(r.player, r.player_finish), r.player, r.player_finish, r.car_id)


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
		return PALETTE["clock"]
	var red: Color = PALETTE["clock_low"]
	return red if int(t * 4.0) % 2 == 0 else red.lerp(PALETTE["clock"], Settings.flash_amount(1.0))


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


## The size HUD text is drawn at: never under UiText.MIN_SIZE (PR-14).
static func text_size(size: int) -> int:
	return maxi(size, UiText.MIN_SIZE)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw(self, pos, s, text_size(size), col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw_centered(self, pos, s, text_size(size), col)


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
	var left := p.ram_time / Tuning.v("power_ups/ram_time") if p.ram_time > 0.0 else p.ghost_time / Tuning.v("power_ups/ghost_time")
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
