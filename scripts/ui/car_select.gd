class_name CarSelect
extends MenuScreen
## Car select: the showroom picture, name and 1..5 stat bars. Confirm starts the race.
## Cars not yet earned (Unlocks) show darkened, with a lock and what opens them.

const STATS := [["ACCELERATION", "accel"], ["TOP SPEED", "top_speed"], ["HANDLING", "handling"]]
const STAT_COLORS := [Color("#ff7a1a"), Color("#ff3d6e"), Color("#3ad0ff")]

var index := 0
var _pictures: Array[Texture2D] = []


func _ready() -> void:
	super._ready()
	for i in Cars.count():
		_pictures.append(load(Cars.picture(Cars.get_car(i))))


## Moves the selection by `dir`, wrapping around; returns the new index.
func move(dir: int) -> int:
	index = posmod(index + dir, Cars.count())
	return index


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		if not Unlocks.car_unlocked(Cars.get_car(index)["id"]):
			Audio.play("bump")
			return
		Audio.play("go")
		game.car_index = index
		game.start_race()
	elif m.back_pressed:
		game.show_stage_select()


func _draw() -> void:
	_backdrop(0.8)
	_header("SELECT CAR")
	var car := Cars.get_car(index)
	var open := Unlocks.car_unlocked(car["id"])

	# Showroom: spotlight, turntable, car
	var c := Vector2(186, 200)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -150), c + Vector2(40, -150), c + Vector2(170, 40), c + Vector2(-170, 40)]),
		Color(1, 0.9, 0.7, 0.07))
	_ellipse(c + Vector2(0, 52), Vector2(170, 26), Color("#2a2350"))
	_ellipse(c + Vector2(0, 50), Vector2(160, 22), Color("#463a7a"))
	var pic: Texture2D = _pictures[index] if index < _pictures.size() else null
	var pic_rect := Rect2(c.x - 152, c.y - 92 + roundf(sin(time * 1.5)), 304, 141)
	_frame(pic_rect)
	if pic != null:
		draw_texture_rect(pic, pic_rect, false, Color.WHITE if open else LOCKED_TINT)
	if not open:
		_lock(pic_rect.get_center(), 1.6)
	var single := Cars.count() == 1
	var arrow_col := Color(1, 1, 1, 0.25) if single else GOLD
	_arrow(Vector2(18, c.y - 22), -1, arrow_col)
	_arrow(Vector2(354, c.y - 22), 1, arrow_col)
	_text_centered(Vector2(c.x, 284), "%d / %d" % [index + 1, Cars.count()], 10, Color(1, 1, 1, 0.7))
	if single:
		_text_centered(Vector2(c.x, 298), "More cars join the garage soon", 9, Color(1, 1, 1, 0.5))

	# Spec panel
	var panel := Rect2(392, 62, 232, 196)
	_frame(panel)
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.85))
	_text(Vector2(panel.position.x + 12, panel.position.y + 30), String(car["name"]).to_upper(), 22, GOLD if open else Color(1, 1, 1, 0.5))
	if not open:
		_text(Vector2(panel.position.x + 12, panel.position.y + 48), "LOCKED", 10, GOLD)
		_text(Vector2(panel.position.x + 12, panel.position.y + 64), Unlocks.car_condition(car["id"]), 10, Color(1, 1, 1, 0.85))
		_footer(hints(not single))
		return
	_text(Vector2(panel.position.x + 12, panel.position.y + 48), car["archetype"], 10, Color(1, 1, 1, 0.75))
	for i in STATS.size():
		var y := panel.position.y + 78 + i * 38
		_text(Vector2(panel.position.x + 12, y), STATS[i][0], 10, Color.WHITE)
		var value: int = car[STATS[i][1]]
		for s in 5:
			var seg := Rect2(panel.position.x + 12 + s * 42, y + 6, 38, 12)
			draw_rect(seg, STAT_COLORS[i] if s < value else Color(1, 1, 1, 0.12))
	_footer(hints(not single))


func _ellipse(center: Vector2, radius: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, col)
