class_name SpriteLibrary
extends RefCounted
## Roadside sprite definitions: texture, world size and collision width.

const ROADSIDE := "res://assets/sprites/roadside/palm_coast/"

static var defs: Dictionary = {}


static func load_all() -> void:
	if not defs.is_empty():
		return
	# id, file, world height, fraction of the width that collides
	_add("palm_tall_a", "palm_tall_a.png", 5200.0, 0.2)
	_add("palm_tall_b", "palm_tall_b.png", 4800.0, 0.2)
	_add("palm_lean", "palm_lean.png", 4800.0, 0.2)
	_add("palm_short_a", "palm_short_a.png", 2400.0, 0.35)
	_add("palm_short_b", "palm_short_b.png", 2400.0, 0.35)
	_add("palm_fan", "palm_fan.png", 2200.0, 0.4)
	_add("palm_cluster", "palm_cluster.png", 4400.0, 0.5)
	_add("billboard", "billboard.png", 3400.0, 0.9)
	_add("lifeguard_tower", "lifeguard_tower.png", 3000.0, 0.8)
	_add("umbrella", "umbrella.png", 1300.0, 0.4)
	_add("lamp_post", "lamp_post.png", 3800.0, 0.25)
	_add("hotel", "hotel.png", 7500.0, 1.0)
	_add("bush", "bush.png", 560.0, 0.6)


static func _add(id: String, file: String, world_h: float, collide: float) -> void:
	var tex: Texture2D = load(ROADSIDE + file)
	if tex == null:
		push_warning("Missing sprite: " + file)
		return
	defs[id] = {
		"tex": tex,
		"world_h": world_h,
		"world_w": world_h * tex.get_width() / float(tex.get_height()),
		"collide": collide,
	}
