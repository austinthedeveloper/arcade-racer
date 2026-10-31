class_name CarSprites
extends RefCounted
## Car sprites cut from the concept sheets (see tools/make_car_sprites.py): the player cars'
## steering strips and the traffic vehicles, all seen from behind.
##
## The player has one steering strip per pitch: level, plus optional nose-up (uphill) and
## nose-down (downhill) strips laid out the same way. A missing pitched strip falls back to
## the level one, stretched to fake the pitch (pitch_warp).

## Steering strips per car (Cars.LIST "strip"): <car>_steer.png, plus <car>_steer_up.png and
## <car>_steer_down.png when that car has pitched strips.
const PLAYER_DIR := "res://assets/sprites/cars/"
const PITCH_SUFFIXES := {-1: "_up", 1: "_down"}
const PLAYER_FRAMES := 7

# Tallest a player car is drawn, as a multiple of its on-screen width (CarSprites.draw_scale)
const MAX_HEIGHT := 0.85
# |pitch| at which a pitched strip takes over from the level one
const PITCH_SWITCH := 0.4
# Fraction of the car's height, from the top, that is roof and rear deck (above the taillights)
const DECK_SPLIT := 0.55
# Fallback stretch at full pitch: the deck grows this much nose-up and shrinks nose-down,
# the bumper does the opposite at half the rate.
const DECK_STRETCH := 0.35

static var _strip_sets: Dictionary = {}  # car strip id -> its strips
static var traffic: Dictionary = {}


static func load_all() -> void:
	if not traffic.is_empty():
		return
	var m: Dictionary = SpriteLibrary.manifest()["traffic"]
	for id: String in m:
		_add_traffic(id, SpriteLibrary.SPRITES + m[id]["file"], m[id]["world_per_px"])


## A car's steering strips (Cars.LIST "strip"), loaded once per car: pitch row (-1 up, 0
## level, 1 down) -> {"tex", "cell", "body_w"}. The level row is always there.
static func strips(strip_id: String) -> Dictionary:
	if not _strip_sets.has(strip_id):
		var rows := {0: _load_strip(PLAYER_DIR + strip_id + "_steer.png")}
		for row: int in PITCH_SUFFIXES:
			var path: String = PLAYER_DIR + strip_id + "_steer" + PITCH_SUFFIXES[row] + ".png"
			if ResourceLoader.exists(path):
				rows[row] = _load_strip(path)
		_strip_sets[strip_id] = rows
	return _strip_sets[strip_id]


static func _load_strip(path: String) -> Dictionary:
	var tex: Texture2D = load(path)
	var cell := Vector2(tex.get_width() / float(PLAYER_FRAMES), tex.get_height())
	var straight := tex.get_image().get_region(Rect2i(Vector2i(int(cell.x) * (PLAYER_FRAMES / 2), 0), Vector2i(cell)))
	# Opaque width of the straight-ahead frame
	return {"tex": tex, "cell": cell, "body_w": float(straight.get_used_rect().size.x)}


## A traffic vehicle; world_per_px is its sheet's scale (each concept sheet was drawn at its own).
static func _add_traffic(id: String, path: String, world_per_px: float) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("Missing traffic sprite: " + path)
		return
	traffic[id] = {"tex": tex, "world_w": tex.get_width() * world_per_px}


## car: the player car's strips (strips). base: bottom-center of the car on the road.
## w: on-screen body width.
## steer: -1 full left .. 1 full right; beyond that it keeps the hardest frame.
## pitch: 1 full nose-down (downhill) .. -1 full nose-up (see PlayerCar.pitch).
## alpha: below 1 for a see-through car (the ghost power-up).
static func draw_player(ci: CanvasItem, car: Dictionary, base: Vector2, w: float, steer: float, brake: bool, nitro: bool,
		t: float, lift: float = 0.0, pitch: float = 0.0, alpha: float = 1.0) -> void:
	var row := pitch_row(pitch, car.keys())
	var strip: Dictionary = car[row]
	var tex: Texture2D = strip["tex"]
	var cell: Vector2 = strip["cell"]
	var k := draw_scale(w, strip)
	w = float(strip["body_w"]) * k
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
	var mod := Color(1, 1, 1, alpha)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top, roundf(size.x), bumper_h), bumper_src, mod)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top - deck_h, roundf(size.x), deck_h), deck_src, mod)
	var h := deck_h + bumper_h
	if brake:
		# Glow over the triangle taillights
		var ly := y - h * 0.58
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(base.x + side * w * 0.36 - w * 0.13, ly, w * 0.26, h * 0.12), Color(1.0, 0.25, 0.1, 0.35))
	if nitro:
		_flame(ci, Vector2(base.x, y - h * 0.24), w, t)


## Texture-to-screen scale for a strip drawn `w` wide: its body fills `w`, unless that would
## make the car taller than MAX_HEIGHT x `w` (a buggy or trike drawn from higher up), when the
## whole car shrinks to that height.
static func draw_scale(w: float, strip: Dictionary) -> float:
	var cell: Vector2 = strip["cell"]
	return minf(w / float(strip["body_w"]), w * MAX_HEIGHT / cell.y)


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
