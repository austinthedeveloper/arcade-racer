class_name CarSprites
extends RefCounted
## Car sprites cut from the concept sheets (see tools/make_car_sprites.py): the player's
## steering strips and the traffic vehicles, all seen from behind.
##
## The player has one steering strip per pitch: level, plus optional nose-up (uphill) and
## nose-down (downhill) strips laid out the same way. A missing pitched strip falls back to
## the level one, stretched to fake the pitch (pitch_warp).

const PLAYER_STRIP := "res://assets/sprites/cars/vega_steer.png"
const PLAYER_PITCH_STRIPS := {
	-1: "res://assets/sprites/cars/vega_steer_up.png",
	1: "res://assets/sprites/cars/vega_steer_down.png",
}
const PLAYER_FRAMES := 7
const TRAFFIC_DIR := "res://assets/sprites/traffic/"

# |pitch| at which a pitched strip takes over from the level one
const PITCH_SWITCH := 0.4
# Fraction of the car's height, from the top, that is roof and rear deck (above the taillights)
const DECK_SPLIT := 0.55
# Fallback stretch at full pitch: the deck grows this much nose-up and shrinks nose-down,
# the bumper does the opposite at half the rate.
const DECK_STRETCH := 0.35

# World units per texture pixel. Each concept sheet was drawn at its own scale.
const CAR_SCALE := 7.0
const BIG_SCALE := 8.2

## pitch row (-1 up, 0 level, 1 down) -> {"tex", "cell", "body_w"}
static var player_strips: Dictionary = {}
static var traffic: Dictionary = {}


static func load_all() -> void:
	if not player_strips.is_empty():
		return
	player_strips[0] = _load_strip(PLAYER_STRIP)
	for row: int in PLAYER_PITCH_STRIPS:
		if ResourceLoader.exists(PLAYER_PITCH_STRIPS[row]):
			player_strips[row] = _load_strip(PLAYER_PITCH_STRIPS[row])
	for id in ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow", "surf_van", "taxi"]:
		_add_traffic(id, CAR_SCALE)
	for id in ["semi", "bus", "box_truck", "rv", "carrier"]:
		_add_traffic(id, BIG_SCALE)


static func _load_strip(path: String) -> Dictionary:
	var tex: Texture2D = load(path)
	var cell := Vector2(tex.get_width() / float(PLAYER_FRAMES), tex.get_height())
	var straight := tex.get_image().get_region(Rect2i(Vector2i(int(cell.x) * (PLAYER_FRAMES / 2), 0), Vector2i(cell)))
	# Opaque width of the straight-ahead frame
	return {"tex": tex, "cell": cell, "body_w": float(straight.get_used_rect().size.x)}


static func _add_traffic(id: String, world_per_px: float) -> void:
	var tex: Texture2D = load(TRAFFIC_DIR + id + ".png")
	if tex == null:
		push_warning("Missing traffic sprite: " + id)
		return
	traffic[id] = {"tex": tex, "world_w": tex.get_width() * world_per_px}


## base: bottom-center of the car on the road. w: on-screen body width.
## steer: -1 full left .. 1 full right; beyond that it keeps the hardest frame.
## pitch: 1 full nose-down (downhill) .. -1 full nose-up (see PlayerCar.pitch).
static func draw_player(ci: CanvasItem, base: Vector2, w: float, steer: float, brake: bool, nitro: bool,
		t: float, lift: float = 0.0, pitch: float = 0.0) -> void:
	var row := pitch_row(pitch, player_strips.keys())
	var strip: Dictionary = player_strips[row]
	var tex: Texture2D = strip["tex"]
	var cell: Vector2 = strip["cell"]
	var k := w / float(strip["body_w"])
	var size := cell * k
	var y := base.y - lift
	_shadow(ci, base, w, clampf(1.0 - lift / (w * 0.6), 0.2, 1.0))
	var src := Rect2(Vector2(steer_frame(steer) * cell.x, 0.0), cell)
	var left := roundf(base.x - size.x / 2.0)
	var warp := pitch_warp(pitch) if row == 0 else Vector2.ONE
	# Deck (top) and bumper (bottom) slices, each scaled on its own, stacked up from the road
	var deck_h := roundf(size.y * DECK_SPLIT * warp.x)
	var bumper_h := roundf(size.y * (1.0 - DECK_SPLIT) * warp.y)
	var split := roundf(cell.y * DECK_SPLIT)  # on a whole texel row
	var deck_src := Rect2(src.position, Vector2(cell.x, split))
	var bumper_src := Rect2(src.position + Vector2(0.0, split), Vector2(cell.x, cell.y - split))
	var bumper_top := roundf(y - bumper_h)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top, roundf(size.x), bumper_h), bumper_src)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top - deck_h, roundf(size.x), deck_h), deck_src)
	var h := deck_h + bumper_h
	if brake:
		# Glow over the triangle taillights
		var ly := y - h * 0.58
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(base.x + side * w * 0.36 - w * 0.13, ly, w * 0.26, h * 0.12), Color(1.0, 0.25, 0.1, 0.35))
	if nitro:
		_flame(ci, Vector2(base.x, y - h * 0.24), w, t)


## Which pitch strip to draw: -1 nose-up, 0 level, 1 nose-down, among the rows that exist.
static func pitch_row(pitch: float, rows: Array = [-1, 0, 1]) -> int:
	var want := 0
	if pitch >= PITCH_SWITCH:
		want = 1
	elif pitch <= -PITCH_SWITCH:
		want = -1
	return want if want in rows else 0


## Height scale of the (deck, bumper) slices that fakes a pitch on the level strip. The camera
## stays level behind the car, so nose-up (uphill) tips the roof toward it: more roof and deck,
## less bumper. Nose-down (downhill) tips the tail up toward it: more bumper, less roof.
static func pitch_warp(pitch: float) -> Vector2:
	var p := clampf(pitch, -1.0, 1.0)
	return Vector2(1.0 - DECK_STRETCH * p, 1.0 + DECK_STRETCH * 0.5 * p)


## Strip frame for a steering value: 0 is hard left, the middle is straight, the last is hard right.
static func steer_frame(steer: float) -> int:
	var half := PLAYER_FRAMES / 2
	return clampi(half + roundi(steer * half), 0, PLAYER_FRAMES - 1)


static func draw_traffic(ci: CanvasItem, base: Vector2, w: float, id: String, tint: Color, fog: float) -> void:
	var def: Dictionary = traffic[id]
	var tex: Texture2D = def["tex"]
	var h := w * tex.get_height() / float(tex.get_width())
	if w >= 3.0:
		_shadow(ci, base, w, 1.0 - fog)
	ci.draw_texture_rect(tex, Rect2(base.x - w / 2.0, base.y - h, w, h), false, tint)


static func _shadow(ci: CanvasItem, base: Vector2, w: float, strength: float) -> void:
	var h := maxf(1.0, w * 0.05)
	ci.draw_rect(Rect2(base.x - w * 0.5, base.y - h * 0.6, w, h), Color(0, 0, 0, 0.35 * strength))


static func _flame(ci: CanvasItem, at: Vector2, w: float, t: float) -> void:
	var flicker := 0.75 + 0.25 * sin(t * 47.0)
	var r := w * 0.07 * flicker
	ci.draw_circle(at, r * 1.6, Color(1.0, 0.45, 0.1, 0.8))
	ci.draw_circle(at, r, Color(1.0, 0.85, 0.3, 0.95))
	ci.draw_circle(at, r * 0.5, Color(0.7, 0.85, 1.0))
