class_name ModeSelect
extends MenuScreen
## Mode select, after the title: a row of cards a wheel steers along. A mode that isn't
## built yet (none, now) stays on the row, marked COMING SOON; picking it shows a short notice.

enum Item { GRAND_TOUR, SINGLE_RACE, TIME_ATTACK, FREE_DRIVE, OPTIONS }

const LABELS := ["GRAND TOUR", "SINGLE RACE", "TIME ATTACK", "FREE DRIVE", "OPTIONS"]
const HELP := [
	"Race stage to stage, on from the one you pick.",
	"One stage, one car, one race.",
	"Solo against the clock and your best run.",
	"No timer, no rivals: just the road.",
	"Driving aids, traffic, sound and wheel setup.",
]
## Card art: a stage postcard per mode ("" draws the options gear).
const ART := ["palm_coast", "neon", "redrock", "timberline", ""]
const CARD := Vector2(104, 120)
const GAP := 12.0
const CARD_Y := 64.0
const NOTICE_TIME := 2.0

var index := 0  # into Item
var notice := ""  # the coming-soon line, while notice_time runs
var notice_time := 0.0
var _art: Array[Texture2D] = []


func _ready() -> void:
	super._ready()
	for a: String in ART:
		_art.append(load("res://assets/sprites/ui/postcard_%s.png" % a) if a != "" else null)


## Whether a mode can be played yet.
static func available(item: int) -> bool:
	return item >= 0 and item < Item.size()


## Moves the selection by `dir`, wrapping around; returns the new index.
func move(dir: int) -> int:
	index = posmod(index + dir, Item.size())
	return index


## Confirms the selected mode: returns it, or -1 (with a notice) when it isn't built yet.
func pick() -> int:
	if available(index):
		return index
	notice = "%s is coming soon" % String(LABELS[index]).capitalize()
	notice_time = NOTICE_TIME
	return -1


func _process(dt: float) -> void:
	super._process(dt)
	notice_time = maxf(0.0, notice_time - dt)


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		move(m.step())
		notice_time = 0.0
		Audio.play("tick")
	elif m.confirm_pressed:
		var item := pick()
		if item < 0:
			Audio.play("bump")
			return
		Audio.play("beep")
		match item:
			Item.OPTIONS:
				game.show_options_from_modes()
			_:
				game.choose_mode(item)
	elif m.back_pressed:
		game.show_title()


func _draw() -> void:
	_backdrop(0.72)
	_header("SELECT MODE")
	var w := float(Cfg.SCREEN_W)
	var x0 := (w - CARD.x * Item.size() - GAP * (Item.size() - 1)) / 2.0
	for i in Item.size():
		var on := i == index
		var open := available(i)
		var r := Rect2(Vector2(x0 + i * (CARD.x + GAP), CARD_Y - (6.0 if on else 0.0)), CARD)
		_frame(r, Color(GOLD, 0.4 + 0.15 * sin(time * 4.0)) if on else Color.TRANSPARENT)
		draw_rect(r, Color(0.04, 0.03, 0.1, 1.0))
		var tint := Color.WHITE if on else Color(0.55, 0.55, 0.65)
		if not open:
			tint = Color(0.4, 0.4, 0.48) if on else Color(0.28, 0.28, 0.34)
		if _art[i] != null:
			var tex := _art[i]
			var src_w := tex.get_height() * CARD.x / CARD.y
			draw_texture_rect_region(tex, r, Rect2((tex.get_width() - src_w) / 2.0, 0, src_w, tex.get_height()), tint)
		else:
			_gear(r.get_center() + Vector2(0, -8), 26.0, Color(SKY, 0.9) if on else Color(SKY, 0.5))
		if not open:
			var band := Rect2(r.position.x, r.get_center().y - 10, r.size.x, 18)
			draw_rect(band, Color(0, 0, 0, 0.7))
			_text_centered(Vector2(band.get_center().x, band.end.y - 5), "COMING SOON", 9, Color(GOLD, 0.9 if on else 0.6))
		var bar := Rect2(r.position.x, r.end.y - 22, r.size.x, 22)
		draw_rect(bar, Color("#1d3fa8") if on else Color(0, 0, 0, 0.65))
		var col := Color.WHITE if on else Color(1, 1, 1, 0.6)
		if not open:
			col = Color(1, 1, 1, 0.75 if on else 0.4)
		_text_centered(Vector2(bar.get_center().x, bar.end.y - 7), LABELS[i], 10, col)
	var pulse := 2.0 * sin(time * 5.0)
	_arrow(Vector2(x0 - 12 - pulse, CARD_Y + CARD.y / 2.0), -1, GOLD)
	_arrow(Vector2(w - x0 + 12 + pulse, CARD_Y + CARD.y / 2.0), 1, GOLD)

	var panel := Rect2(w / 2.0 - 230, 222, 460, 44)
	draw_rect(panel, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(panel.position.x, panel.position.y, panel.size.x, 2), GOLD)
	_text_centered(Vector2(w / 2.0, panel.position.y + 19), LABELS[index], 13, GOLD)
	_text_centered(Vector2(w / 2.0, panel.position.y + 36), HELP[index], 10, Color(1, 1, 1, 0.85))
	if notice_time > 0.0:
		var a := minf(1.0, notice_time * 3.0)
		var n := Rect2(w / 2.0 - 150, 284, 300, 26)
		draw_rect(n.grow(2), Color(GOLD, 0.8 * a))
		draw_rect(n, Color(0.07, 0.04, 0.16, 0.95 * a))
		_text_centered(Vector2(w / 2.0, n.end.y - 9), notice.to_upper(), 11, Color(1, 1, 1, a))
	_footer(hints(true))


## A cog for the options card.
func _gear(c: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	const TEETH := 8
	for i in TEETH * 4:
		var a := TAU * i / (TEETH * 4.0) + time * 0.3
		var rr := radius if (i % 4) < 2 else radius * 0.74
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	var hole := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		hole.append(c + Vector2(cos(a), sin(a)) * radius * 0.36)
	draw_colored_polygon(hole, Color(0.04, 0.03, 0.1))
