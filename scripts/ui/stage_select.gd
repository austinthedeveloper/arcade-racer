class_name StageSelect
extends MenuScreen
## Stage select: a map of the country (KA-06, tools/make_ui_sprites.py) with every stage's
## postcard pinned where the stage is and the tour route drawn between the pins. The chosen
## stage's postcard shows big in the bay; left and right step along the route. A Grand Tour
## runs on from the chosen stage; a Single Race is just that stage. Stages the tour hasn't
## reached yet (Unlocks) show dimmed with a lock and can't be picked.

const MAP := "res://assets/sprites/ui/stage_map.png"
## Each stage's pin on the map, in tour order: the route markers painted on the concept.
const PINS: Array[Vector2] = [Vector2(46, 126), Vector2(144, 100), Vector2(202, 161), Vector2(327, 93),
	Vector2(372, 198), Vector2(474, 199), Vector2(530, 108), Vector2(552, 227)]
## Whether a stage's postcard hangs above its pin (else below), so neighbours don't overlap.
const CARD_ABOVE: Array[bool] = [true, true, false, true, false, false, true, false]
const CARD := Vector2(56, 32)
const CARD_STEM := 12.0  # pin to postcard edge
const BIG := Rect2(10, 196, 144, 81)  # the chosen stage's postcard, in the bay
const BAND := Rect2(0, 296, 640, 42)  # stage name and tour line, above the footer

var _cards: Array[Texture2D] = []
var _map: Texture2D


func _ready() -> void:
	super._ready()
	_map = load(MAP)
	for i in Stages.count():
		_cards.append(load(Stages.postcard(i)))


func choice_count() -> int:
	return Stages.count()


## Stage `i`'s pin on the map.
static func pin(i: int) -> Vector2:
	return PINS[i]


## Where stage `i`'s small postcard sits: centred over or under its pin.
static func card_rect(i: int) -> Rect2:
	var dy := CARD_STEM + CARD.y / 2.0
	var c := PINS[i] + Vector2(0, -dy if CARD_ABOVE[i] else dy)
	return Rect2(c - CARD / 2.0, CARD)


func handle(m: MenuInput) -> void:
	if solo() and m.step_y() != 0:
		Settings.attack_traffic = not Settings.attack_traffic
		Settings.save()
		Audio.play("tick")
	elif m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		if not Unlocks.stage_unlocked(index):
			Audio.play("bump")
			return
		Audio.play("beep")
		game.stage_index = index
		game.show_car_select()
	elif m.back_pressed:
		game.show_mode_select()


func _draw() -> void:
	if _map != null:
		draw_texture_rect(_map, Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), false)
	else:
		_backdrop(0.72)
	_header("SELECT STAGE")
	_route()
	for i in Stages.count():
		_postcard(i)
	_pins()
	_big()
	_band()
	_footer(hints(true))


## The tour route, pin to pin; legs into stages not yet reached are dimmed.
func _route() -> void:
	for i in range(1, Stages.count()):
		var a := PINS[i - 1]
		var b := PINS[i]
		var open := Unlocks.stage_unlocked(i)
		draw_line(a, b, Color(NIGHT, 0.8), 5.0)
		draw_dashed_line(a, b, GOLD if open else Color(0.6, 0.6, 0.7, 0.8), 2.0, 5.0 if open else 3.0)


func _postcard(i: int) -> void:
	var r := card_rect(i)
	var open := Unlocks.stage_unlocked(i)
	var chosen := i == index
	var stem_end := Vector2(PINS[i].x, r.end.y if CARD_ABOVE[i] else r.position.y)
	draw_line(PINS[i], stem_end, Color(1, 1, 1, 0.8) if chosen else Color(NIGHT, 0.8), 2.0)
	_frame(r, Color(GOLD, 0.55 + 0.25 * sin(time * 4.0)) if chosen else Color.TRANSPARENT)
	var tint := Color.WHITE if chosen else Color(0.8, 0.8, 0.88)
	if not open:
		tint = LOCKED_TINT
	if _cards[i] != null:
		draw_texture_rect(_cards[i], r, false, tint)
	if not open:
		_lock(r.get_center(), 0.7)
	var tab := Rect2(r.position, Vector2(11, 11))
	draw_rect(tab, Color(0, 0, 0, 0.7))
	_text_centered(Vector2(tab.get_center().x, tab.end.y - 2), str(i + 1), 9, GOLD if chosen else Color.WHITE)


func _pins() -> void:
	for i in Stages.count():
		var open := Unlocks.stage_unlocked(i)
		var rad := 5.0 + (1.0 + sin(time * 6.0) if i == index else 0.0)
		draw_circle(PINS[i], rad + 1.5, NIGHT)
		draw_circle(PINS[i], rad, GOLD if open else Color(0.5, 0.5, 0.58))
		if i == index:
			draw_circle(PINS[i], rad * 0.45, Color.WHITE)


## The chosen stage's postcard, big.
func _big() -> void:
	var open := Unlocks.stage_unlocked(index)
	_frame(BIG, Color(GOLD, 0.35 + 0.15 * sin(time * 4.0)) if open else Color.TRANSPARENT)
	if index < _cards.size() and _cards[index] != null:
		draw_texture_rect(_cards[index], BIG, false, Color.WHITE if open else LOCKED_TINT)
	if not open:
		_lock(BIG.get_center() + Vector2(0, -10), 1.3)
		_text_centered(BIG.get_center() + Vector2(0, 22), "LOCKED", 12, GOLD)


func _band() -> void:
	var open := Unlocks.stage_unlocked(index)
	draw_rect(BAND, Color(0, 0, 0, 0.62))
	draw_rect(Rect2(BAND.position, Vector2(BAND.size.x, 1)), Color(GOLD, 0.6))
	var c := BAND.get_center().x
	var title := "STAGE %d   " % (index + 1)
	var name := Stages.stage_name(index).to_upper()
	var x := UiText.centered_x(c, title + name, 12)
	_text(Vector2(x, BAND.position.y + 17), title, 12, GOLD)
	_text(Vector2(x + UiText.width(title, 12), BAND.position.y + 17), name, 12, Color.WHITE)
	var line := _tour_line() if open else Unlocks.stage_condition(index)
	_text_centered(Vector2(c, BAND.position.y + 34), line, 9, Color(1, 1, 1, 0.8))
	var pulse := 3.0 * sin(time * 5.0)
	_arrow(Vector2(22 - pulse, BAND.get_center().y), -1, GOLD)
	_arrow(Vector2(BAND.end.x - 22 + pulse, BAND.get_center().y), 1, GOLD)


func time_attack() -> bool:
	return game != null and game.mode_index == ModeSelect.Item.TIME_ATTACK


## Time Attack and Free Drive pick traffic on or off here (Settings.attack_traffic).
func solo() -> bool:
	return game != null and (game.mode_index == ModeSelect.Item.TIME_ATTACK or game.mode_index == ModeSelect.Item.FREE_DRIVE)


func _tour_line() -> String:
	if game != null and game.mode_index == ModeSelect.Item.SINGLE_RACE:
		return "Single Race: one run on this stage"
	var traffic := "Traffic %s  (Up / Down)" % ("ON" if Settings.attack_traffic else "OFF")
	if time_attack():
		return "Time Attack: you and your best run.   " + traffic
	if solo():
		return "Free Drive: no clock, no finish.   " + traffic
	var last := Stages.count() - 1
	if index == last:
		return "The final stage"
	return "Tour from here on to %s  (%d stages)" % [Stages.stage_name(last), Stages.count() - index]
