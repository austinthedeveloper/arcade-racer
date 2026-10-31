class_name SpriteLibrary
extends RefCounted
## Roadside and road-spanning sprite definitions: texture, world size and collision width,
## from the manifest the sprite tools write (tools/manifest.py).

const SPRITES := "res://assets/sprites/"
const MANIFEST := SPRITES + "manifest.json"
## World width of a span's opening: the road plus its rumble strips and a little margin.
const SPAN_OPENING := Cfg.ROAD_WIDTH * 2.7
## Roadside sprites that load but no stage places yet; test_track keeps this list honest.
const UNPLACED := ["turn_left", "turn_right", "chevron_a", "chevron_b", "chevron_c", "bump_sign",
	"tire_stack", "barrels_yellow", "cone_orange", "barricade", "barrier_orange", "inflatable_arch",
	"sign_green", "sign_brown", "delineator", "rail_wood_a", "rail_wood_b", "rail_wood_short",
	"rail_end", "rail_wood_long", "rail_concrete", "rail_concrete_end"]
const MIN_OPENING := 0.2  # narrowest opening, as a fraction of a span's width, that is one

static var defs: Dictionary = {}
## Road-spanning sprites (tunnels, bridges, gates): the road runs through their opening.
static var spans: Dictionary = {}
static var _manifest: Dictionary = {}


static func load_all() -> void:
	if not defs.is_empty():
		return
	var m := manifest()
	for id: String in m["roadside"]:
		var e: Dictionary = m["roadside"][id]
		_add(id, SPRITES + e["file"], e["world_h"], e["collide"])
	for id: String in m["spans"]:
		var e: Dictionary = m["spans"][id]
		var fill: Color = Color(e["fill"]) if e["fill"] != null else Color.TRANSPARENT
		var b: Array = e["banner"] if e["banner"] != null else [0.0, 0.0, 0.0, 0.0]
		var solid: Array = e.get("solid", [0.0, 1.0])
		_add_span(id, SPRITES + e["file"], fill, e["ceiling"], Rect2(b[0], b[1], b[2], b[3]), Vector2(solid[0], solid[1]))


## Every roadside sprite, span and traffic vehicle with its numbers (world height, collide
## fraction, scale), written by the sprite tools (tools/manifest.py), loaded once.
static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var json: JSON = load(MANIFEST)
		_manifest = json.data
	return _manifest


## Adds a road-spanning sprite. Its world size comes from its opening, which must fit the road.
## `solid` is the part of it (left and right, as fractions of the width) that collides: all
## of it, or the tunnel mouth between building faces drawn either side.
static func _add_span(id: String, path: String, fill: Color, ceiling: bool, banner: Rect2, solid := Vector2(0.0, 1.0)) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("Missing span sprite: " + path)
		return
	var opening := find_opening(tex.get_image())
	if opening.y - opening.x < MIN_OPENING:
		push_warning("Span sprite %s has no opening at the bottom" % id)
		return
	var world_w := SPAN_OPENING / (opening.y - opening.x)
	spans[id] = {
		"tex": tex,
		"world_w": world_w,
		"world_h": world_w * tex.get_height() / float(tex.get_width()),
		"opening": opening,  # left and right edge, as fractions of the width
		"fill": fill,
		"ceiling": ceiling,
		"banner": banner,  # where gate text goes, as fractions of the sprite
		"solid": solid,  # the part that collides, as fractions of the width
	}


## The gap the road runs through: the transparent run through the middle of a row near the
## bottom, as (left, right) fractions of the image width. (0.5, 0.5) if the middle is solid.
static func find_opening(img: Image) -> Vector2:
	var w := img.get_width()
	var y := int(img.get_height() * 0.9)
	var mid := w / 2
	if img.get_pixel(mid, y).a >= 0.5:
		return Vector2(0.5, 0.5)
	var left := mid
	var right := mid
	while left > 0 and img.get_pixel(left - 1, y).a < 0.5:
		left -= 1
	while right < w - 1 and img.get_pixel(right + 1, y).a < 0.5:
		right += 1
	return Vector2(float(left) / w, float(right + 1) / w)


## A span's (left, right) edges in road half-widths from the road center: its opening and
## the outer edges of its solid part. Between them is the structure the car can hit.
static func span_edges(id: String) -> Dictionary:
	var def: Dictionary = spans[id]
	var w: float = def["world_w"] / Cfg.ROAD_WIDTH
	var o: Vector2 = def["opening"]
	var solid: Vector2 = def["solid"]
	var center := (o.x + o.y) / 2.0
	return {"inner": Vector2(o.x - center, o.y - center) * w, "outer": Vector2(solid.x - center, solid.y - center) * w}


static func _add(id: String, path: String, world_h: float, collide: float) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("Missing sprite: " + path)
		return
	defs[id] = {
		"tex": tex,
		"world_h": world_h,
		"world_w": world_h * tex.get_width() / float(tex.get_height()),
		"collide": collide,
	}
