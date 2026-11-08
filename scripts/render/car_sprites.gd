class_name CarSprites
extends RefCounted
## Car sprites cut from the concept sheets (see tools/make_car_sprites.py): the player cars'
## steering strips and the traffic vehicles, seen from behind, plus (CP-6) the front views
## of the ones that come the other way and the light-state frames of the ones that signal.
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

## How long the cars' shadows are, times the plain one (Sundown.shadow_length): the race sets
## it for the stage's hour (WS-16); they stretch toward the camera, away from the low sun.
static var shadow_length := 1.0
## Where the tail lights sit on the cars rendered from a 3D model (tools/make_car_renders.py),
## whose lamps aren't where the concept sheets drew them: strip id -> pitch row -> the right-hand
## lamp's boxes, each [centre x from the car's middle in body widths, centre y up from the base
## in car heights, width, height]; the left lamp mirrors them. Measured on the straight frame.
## A car not here glows at the concept sheets' triangle taillights. The renders' lamps are lit
## already, so braking lays a hotter core and a halo over them (BRAKE_CORE).
const LAMPS := {
	"bruiser": {-1: [[0.23, 0.24, 0.40, 0.07]], 0: [[0.24, 0.33, 0.39, 0.10]], 1: [[0.23, 0.47, 0.40, 0.12]]},
	"hauler": {-1: [[0.39, 0.30, 0.08, 0.20]], 0: [[0.39, 0.33, 0.08, 0.21]], 1: [[0.39, 0.36, 0.08, 0.20]]},
	# Halo: a ring, as its top and bottom bands and its round end
	"halo": {
		-1: [[0.21, 0.35, 0.36, 0.06], [0.21, 0.11, 0.36, 0.06], [0.37, 0.23, 0.07, 0.27]],
		0: [[0.21, 0.49, 0.36, 0.06], [0.21, 0.21, 0.36, 0.06], [0.37, 0.35, 0.07, 0.32]],
		1: [[0.20, 0.66, 0.36, 0.06], [0.20, 0.36, 0.36, 0.06], [0.36, 0.51, 0.07, 0.35]]},
	# Skipper: no tail lights; the round lamps on the cage
	"skipper": {-1: [[0.19, 0.46, 0.06, 0.05]], 0: [[0.17, 0.44, 0.06, 0.05]], 1: [[0.17, 0.42, 0.06, 0.05]]},
	"sol": {-1: [[0.41, 0.23, 0.07, 0.33]], 0: [[0.40, 0.22, 0.07, 0.28]], 1: [[0.41, 0.46, 0.07, 0.40]]},
}
## Braking on a LAMPS car: a pale hot core over the lit lamp, and the night halo round it
const BRAKE_CORE := Color(1.0, 0.62, 0.45, 0.55)
const BRAKE_HALO := 0.3

static var _strip_sets: Dictionary = {}  # car strip id -> its strips
static var traffic: Dictionary = {}


static func load_all() -> void:
	if not traffic.is_empty():
		return
	var m: Dictionary = SpriteLibrary.manifest()["traffic"]
	for id: String in m:
		_add_traffic(id, SpriteLibrary.SPRITES + m[id]["file"], m[id]["world_per_px"])
		if not traffic.has(id):
			continue
		if m[id].has("front"):
			traffic[id]["front"] = load(SpriteLibrary.SPRITES + m[id]["front"])
		var lights := {}
		for state: String in m[id].get("lights", {}):
			lights[state] = load(SpriteLibrary.SPRITES + m[id]["lights"][state])
		traffic[id]["lights"] = lights


## Whether traffic vehicle `id` has a front view, so it can come the other way.
static func has_front(id: String) -> bool:
	return traffic.has(id) and traffic[id].get("front") != null


## Whether traffic vehicle `id` has both signal frames, so it can change lanes with a tell.
static func signals(id: String) -> bool:
	return traffic.has(id) and traffic[id]["lights"].has("left") and traffic[id]["lights"].has("right")


## The frame to draw for vehicle `id`: its front view when `oncoming`, else its rear view in
## light state `state` ("brake", "left", "right"; "" or one it lacks for lights off).
static func traffic_texture(id: String, oncoming: bool, state: String = "") -> Texture2D:
	var def: Dictionary = traffic[id]
	if oncoming and def.get("front") != null:
		return def["front"]
	return def["lights"].get(state, def["tex"])


## A car's steering strips (Cars.LIST "strip"), loaded once per car: pitch row (-1 up, 0
## level, 1 down) -> {"tex", "cell", "body_w"}. The level row is always there.
static func strips(strip_id: String) -> Dictionary:
	if not _strip_sets.has(strip_id):
		var rows := {0: _load_strip(PLAYER_DIR + strip_id + "_steer.png")}
		for row: int in PITCH_SUFFIXES:
			var path: String = PLAYER_DIR + strip_id + "_steer" + PITCH_SUFFIXES[row] + ".png"
			if ResourceLoader.exists(path):
				rows[row] = _load_strip(path)
		for row: int in LAMPS.get(strip_id, {}):
			if rows.has(row):
				rows[row]["lamps"] = LAMPS[strip_id][row]
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
## alpha: below 1 for a see-through car (the ghost power-up). tint: fog, for a rival far off.
## glow: the tail lights lit in the dark (Headlights, WS-17), 0 by day.
## The nitro flame is the FX layer's (FxLayer), drawn over the car.
static func draw_player(ci: CanvasItem, car: Dictionary, base: Vector2, w: float, steer: float, brake: bool,
		lift: float = 0.0, pitch: float = 0.0, alpha: float = 1.0, tint: Color = Color.WHITE, glow: float = 0.0) -> void:
	var row := pitch_row(pitch, car.keys())
	var strip: Dictionary = car[row]
	var tex: Texture2D = strip["tex"]
	var cell: Vector2 = strip["cell"]
	var k := car_scale(w, car)
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
	var mod := Color(tint, alpha)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top, roundf(size.x), bumper_h), bumper_src, mod)
	ci.draw_texture_rect_region(tex, Rect2(left, bumper_top - deck_h, roundf(size.x), deck_h), deck_src, mod)
	var h := deck_h + bumper_h
	if strip.has("lamps"):
		var halo := maxf(0.18 * glow, BRAKE_HALO if brake else 0.0)
		for box: Array in strip["lamps"]:
			for r in lamp_rects(box, Vector2(base.x, y), w, h):
				if halo > 0.0:
					ci.draw_rect(r.grow(minf(w, h) * 0.04), Color(Headlights.TAIL, halo * alpha))
				if brake:
					ci.draw_rect(r, Color(BRAKE_CORE, BRAKE_CORE.a * alpha))
		return
	var ly := y - h * 0.58
	if glow > 0.0:
		# Tail lights on in the dark: a halo round the triangle taillights
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(base.x + side * w * 0.36 - w * 0.2, ly - h * 0.05, w * 0.4, h * 0.22), Color(Headlights.TAIL, 0.18 * glow * alpha))
	if brake or glow > 0.0:
		# Glow over the triangle taillights (braking, or lit at night; brighter braking)
		var a := (0.35 if brake else 0.0) + 0.3 * glow
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(base.x + side * w * 0.36 - w * 0.13, ly, w * 0.26, h * 0.12), Color(1.0, 0.25, 0.1, minf(0.8, a) * alpha))


## The two tail-light rects on screen for a LAMPS entry, a car drawn `w` wide and `h` tall
## standing on `base`: the right-hand one, then the left mirrored.
static func lamp_rects(lamp: Array, base: Vector2, w: float, h: float) -> Array[Rect2]:
	var size := Vector2(lamp[2] * w, lamp[3] * h)
	var cy: float = base.y - lamp[1] * h
	var out: Array[Rect2] = []
	for side in [1.0, -1.0]:
		out.append(Rect2(Vector2(base.x + side * lamp[0] * w, cy) - size / 2.0, size))
	return out


## Texture-to-screen scale for a strip drawn `w` wide: its body fills `w`, unless that would
## make the car taller than MAX_HEIGHT x `w` (a buggy or trike drawn from higher up), when the
## whole car shrinks to that height.
static func draw_scale(w: float, strip: Dictionary) -> float:
	var cell: Vector2 = strip["cell"]
	return minf(w / float(strip["body_w"]), w * MAX_HEIGHT / cell.y)


## draw_scale for a whole car: every pitch at its level strip's scale, or a tall nose-up strip
## would shrink the car as the road starts to climb.
static func car_scale(w: float, car: Dictionary) -> float:
	return draw_scale(w, car[0])


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


## glow: the tail lights lit in the dark (Headlights, WS-17), 0 by day; a car coming the other
## way shows its headlights instead, as drawn.
static func draw_traffic(ci: CanvasItem, base: Vector2, w: float, id: String, tint: Color, fog: float,
		oncoming := false, state := "", glow := 0.0) -> void:
	var tex := traffic_texture(id, oncoming, state)
	var h := w * tex.get_height() / float(tex.get_width())
	if w >= 3.0:
		_shadow(ci, base, w, 1.0 - fog)
	ci.draw_texture_rect(tex, Rect2(base.x - w / 2.0, base.y - h, w, h), false, tint)
	if glow > 0.0 and not oncoming and w >= 4.0:
		var a := glow * (1.0 - fog)
		for r in Headlights.tail_rects(base, w, h, true):
			ci.draw_rect(r, Color(Headlights.TAIL, 0.2 * a))
		for r in Headlights.tail_rects(base, w, h):
			ci.draw_rect(r, Color(Headlights.TAIL, 0.55 * a))


static func _shadow(ci: CanvasItem, base: Vector2, w: float, strength: float) -> void:
	var r := shadow_rect(base, w, shadow_length)
	ci.draw_rect(r, Color(0, 0, 0, 0.35 * strength / sqrt(maxf(1.0, shadow_length))))


## The shadow under a car `w` wide standing at `base`, `length` times as long as by day: from
## just under its bumper toward the camera, the low sun being ahead.
static func shadow_rect(base: Vector2, w: float, length := 1.0) -> Rect2:
	var h := maxf(1.0, w * 0.05)
	return Rect2(base.x - w * 0.5, base.y - h * 0.6, w, h * maxf(1.0, length))

