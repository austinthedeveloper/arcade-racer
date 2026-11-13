class_name SplitHud
extends Control
## The compact HUD of a split-screen race (MP-18): in each half its player's tag, the time,
## the place and the speed, the countdown and the player's own finish. The full HUD (Hud) is
## hidden in a split race; PR-27 is its polish (the nitro, the power-up slot, the callouts).
## What it shows is `lines`, so a test can read it; _draw only lays it out.

const GOLD := UiText.GOLD
const PANEL := Color(UiText.INK, 0.6)
const PAD := 6.0  # pixels in from a half's edges
const DIVIDER := 2.0  # the line between the halves

var race: Node  # race.gd


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## What player `slot`'s half shows: "tag" (P1, P2), "time" (the clock's seconds, or the run's
## time in Free Drive), "place" ("2ND/9", "" with nobody else on the road), "speed" (number
## and units, Settings.speedometer), "nitro" (charges left), "banner" (the countdown, GO!,
## FINISH, TIME UP; "" for none) and "sub" (under the banner).
static func lines(r: Node, slot: int) -> Dictionary:
	var car: PlayerCar = r.player if slot == 0 else r.p2
	var finished: bool = (r.state == r.State.FINISHED) if slot == 0 else (r.p2.finished as bool)
	var out_of_time: bool = (r.state == r.State.TIME_UP) if slot == 0 else (r.p2_out as bool)
	var field: int = r.rivals.cars.size() + 1
	var place: int = r.place if slot == 0 else r.p2_place()
	var time := Hud.clock_text(r.race_time) if not r.timed() else str(ceili(r.time_left))
	if finished:
		time = Hud.clock_text(r.player_finish if slot == 0 else r.p2.finish_time)
	var shown: Array = Settings.speedometer(car.speed)
	var banner := ""
	var sub := ""
	if r.counting_down():
		banner = str(ceili(r.countdown))
	elif finished:
		banner = "FINISH"
		sub = Rivals.ordinal(place)
	elif out_of_time:
		banner = "TIME UP"
	elif r.banner == "GO!" and r.banner_time > 0.0:
		banner = "GO!"
	return {
		"tag": SplitScreen.NAMES[slot], "time": time, "place": "%s/%d" % [Rivals.ordinal(place), field] if field > 1 else "",
		"speed": "%s %s" % [shown[0], shown[1]], "nitro": car.nitro_charges, "banner": banner, "sub": sub,
	}


func _draw() -> void:
	if race == null or race.p2 == null or race.results.visible:
		return
	var k := UiScale.hud(Settings.ui_scale)
	for slot in SplitScreen.PLAYERS:
		_draw_half(SplitScreen.half_rect(slot), lines(race, slot), SplitScreen.COLORS[slot], k)
	var mid := SplitScreen.HALF.y
	draw_rect(Rect2(0, mid - DIVIDER, Cfg.SCREEN_W, DIVIDER * 2.0), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(0, mid - 0.5, Cfg.SCREEN_W, 1.0), Color(GOLD, 0.6))


func _draw_half(r: Rect2, l: Dictionary, col: Color, k: float) -> void:
	# The tag and the time, top left
	var tag := Rect2(r.position + Vector2(PAD, PAD), Vector2(26, 18) * k)
	draw_rect(tag, col)
	_text_centered(Vector2(tag.get_center().x, tag.end.y - 5 * k), l["tag"], roundi(11 * k), Color("#14102a"))
	var tw := maxf(46.0, UiText.width(l["time"], roundi(16 * k)) + 12.0)
	var time := Rect2(Vector2(tag.end.x + 3, tag.position.y), Vector2(tw, tag.size.y))
	draw_rect(time, PANEL)
	_text(Vector2(time.position.x + 6, time.end.y - 4 * k), l["time"], roundi(16 * k), Hud.clock_color(race.time_left) if race.timed() else Color.WHITE)
	# The place, top right
	if l["place"] != "":
		var size := roundi(16 * k)
		var pw := UiText.width(l["place"], size) + 12.0
		var pos := Rect2(Vector2(r.end.x - PAD - pw, r.position.y + PAD), Vector2(pw, tag.size.y))
		draw_rect(pos, PANEL)
		_text(Vector2(pos.position.x + 6, pos.end.y - 4 * k), l["place"], size, GOLD)
	# The speed bottom right, the nitro bottom left
	var ssize := roundi(14 * k)
	var sw := UiText.width(l["speed"], ssize) + 12.0
	var speed := Rect2(Vector2(r.end.x - PAD - sw, r.end.y - PAD - 18 * k), Vector2(sw, 18 * k))
	draw_rect(speed, PANEL)
	_text(Vector2(speed.position.x + 6, speed.end.y - 4 * k), l["speed"], ssize, Color.WHITE)
	var nitro := Rect2(Vector2(r.position.x + PAD, speed.position.y), Vector2(16 + 10 * Cfg.NITRO_CHARGES, 18) * Vector2(k, k))
	draw_rect(nitro, PANEL)
	for i in Cfg.NITRO_CHARGES:
		var dot := Vector2(nitro.position.x + (8 + i * 10) * k, nitro.get_center().y)
		if i < int(l["nitro"]):
			draw_circle(dot, 3.5 * k, Hud.PALETTE["nitro_lit"])
		else:
			draw_arc(dot, 3.5 * k, 0, TAU, 12, Hud.PALETTE["nitro_spent"], 1.0)
	# The banner, mid-half
	if l["banner"] != "":
		var c := r.get_center() + Vector2(0, -6)
		var bsize := roundi((36 if race.counting_down() else 24) * k)
		_text_centered(c + Vector2(2, 2), l["banner"], bsize, Color(0, 0, 0, 0.7))
		_text_centered(c, l["banner"], bsize, GOLD if race.counting_down() else col)
		if l["sub"] != "":
			_text_centered(c + Vector2(0, 18 * k), l["sub"], roundi(14 * k), Color.WHITE)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw(self, pos, s, Hud.text_size(size), col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw_centered(self, pos, s, Hud.text_size(size), col)
