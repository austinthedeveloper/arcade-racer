class_name CarSprites
extends RefCounted
## Car sprites cut from the concept sheets (see tools/make_car_sprites.py): the player's
## steering strip and the traffic vehicles, all seen from behind.

const PLAYER_STRIP := "res://assets/sprites/cars/vega_steer.png"
const PLAYER_FRAMES := 7
const TRAFFIC_DIR := "res://assets/sprites/traffic/"

# World units per texture pixel. Each concept sheet was drawn at its own scale.
const CAR_SCALE := 7.0
const BIG_SCALE := 8.2

static var player_tex: Texture2D
static var player_cell := Vector2.ZERO
static var player_body_w := 0.0  # opaque width of the straight-ahead frame
static var traffic: Dictionary = {}


static func load_all() -> void:
	if player_tex != null:
		return
	player_tex = load(PLAYER_STRIP)
	player_cell = Vector2(player_tex.get_width() / float(PLAYER_FRAMES), player_tex.get_height())
	var straight := player_tex.get_image().get_region(Rect2i(Vector2i(int(player_cell.x) * (PLAYER_FRAMES / 2), 0), Vector2i(player_cell)))
	player_body_w = straight.get_used_rect().size.x
	for id in ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow", "surf_van", "taxi"]:
		_add_traffic(id, CAR_SCALE)
	for id in ["semi", "bus", "box_truck", "rv", "carrier"]:
		_add_traffic(id, BIG_SCALE)


static func _add_traffic(id: String, world_per_px: float) -> void:
	var tex: Texture2D = load(TRAFFIC_DIR + id + ".png")
	if tex == null:
		push_warning("Missing traffic sprite: " + id)
		return
	traffic[id] = {"tex": tex, "world_w": tex.get_width() * world_per_px}


## base: bottom-center of the car on the road. w: on-screen body width.
## steer: -1 full left .. 1 full right; beyond that it keeps the hardest frame.
static func draw_player(ci: CanvasItem, base: Vector2, w: float, steer: float, brake: bool, nitro: bool,
		t: float, lift: float = 0.0) -> void:
	var k := w / player_body_w
	var size := player_cell * k
	var y := base.y - lift
	_shadow(ci, base, w, clampf(1.0 - lift / (w * 0.6), 0.2, 1.0))
	var half := PLAYER_FRAMES / 2
	var frame := clampi(half + roundi(steer * half), 0, PLAYER_FRAMES - 1)
	var src := Rect2(Vector2(frame * player_cell.x, 0.0), player_cell)
	ci.draw_texture_rect_region(player_tex, Rect2(roundf(base.x - size.x / 2.0), roundf(y - size.y), roundf(size.x), roundf(size.y)), src)
	if brake:
		# Glow over the triangle taillights
		var ly := y - size.y * 0.58
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(base.x + side * w * 0.36 - w * 0.13, ly, w * 0.26, size.y * 0.12), Color(1.0, 0.25, 0.1, 0.35))
	if nitro:
		_flame(ci, Vector2(base.x, y - size.y * 0.24), w, t)


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
