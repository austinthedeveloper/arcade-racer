class_name StageSelect
extends MenuScreen
## Stage select: the chosen stage's postcard big, every stage as a thumbnail along the
## bottom. The tour runs on from the chosen stage.

const THUMB := Vector2(72, 40)
const THUMB_GAP := 80.0
const THUMB_Y := 284.0

var index := 0
var _cards: Array[Texture2D] = []


func _ready() -> void:
	super._ready()
	for i in Stages.count():
		_cards.append(load(Stages.postcard(i)))


## Moves the selection by `dir`, wrapping around; returns the new index.
func move(dir: int) -> int:
	index = posmod(index + dir, Stages.count())
	return index


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		game.stage_index = index
		game.show_car_select()
	elif m.back_pressed:
		game.show_title()


func _draw() -> void:
	_backdrop(0.72)
	_header("SELECT STAGE")
	var w := float(Cfg.SCREEN_W)

	var big := Rect2(w / 2.0 - 168, 52, 336, 189)
	_frame(big, Color(GOLD, 0.35 + 0.15 * sin(time * 4.0)))
	if index < _cards.size() and _cards[index] != null:
		draw_texture_rect(_cards[index], big, false)
	var pulse := 3.0 * sin(time * 5.0)
	_arrow(Vector2(big.position.x - 22 - pulse, big.get_center().y), -1, GOLD)
	_arrow(Vector2(big.end.x + 22 + pulse, big.get_center().y), 1, GOLD)
	draw_rect(Rect2(big.position.x, big.end.y - 22, big.size.x, 22), Color(0, 0, 0, 0.6))
	_text(Vector2(big.position.x + 8, big.end.y - 7), "STAGE %d" % (index + 1), 12, GOLD)
	_text(Vector2(big.position.x + 66, big.end.y - 7), Stages.stage_name(index).to_upper(), 12, Color.WHITE)
	_text_centered(Vector2(w / 2.0, big.end.y + 22), _tour_line(), 9, Color(1, 1, 1, 0.75))

	var x0 := (w - THUMB_GAP * (Stages.count() - 1) - THUMB.x) / 2.0
	for i in Stages.count():
		var r := Rect2(Vector2(x0 + i * THUMB_GAP, THUMB_Y - (4.0 if i == index else 0.0)), THUMB)
		_frame(r, GOLD if i == index else Color.TRANSPARENT)
		if _cards[i] != null:
			draw_texture_rect(_cards[i], r, false, Color.WHITE if i == index else Color(0.55, 0.55, 0.65))
		_text_centered(Vector2(r.get_center().x, r.end.y + 12), str(i + 1), 9, GOLD if i == index else Color(1, 1, 1, 0.6))
	_footer(hints(true))


func _tour_line() -> String:
	var last := Stages.count() - 1
	if index == last:
		return "The final stage"
	return "Tour from here on to %s  (%d stages)" % [Stages.stage_name(last), Stages.count() - index]
