class_name SpriteLibrary
extends RefCounted
## Roadside sprite definitions: texture, world size and collision width.

const ROADSIDE := "res://assets/sprites/roadside/"

static var defs: Dictionary = {}
static var _dir := ""


static func load_all() -> void:
	if not defs.is_empty():
		return
	# id, file, world height, fraction of the width that collides
	_dir = ROADSIDE + "palm_coast/"
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

	_dir = ROADSIDE + "redrock/"
	_add("saguaro_a", "saguaro_a.png", 3600.0, 0.3)
	_add("saguaro_b", "saguaro_b.png", 3800.0, 0.3)
	_add("saguaro_c", "saguaro_c.png", 3400.0, 0.3)
	_add("prickly_pear_a", "prickly_pear_a.png", 1100.0, 0.7)
	_add("prickly_pear_b", "prickly_pear_b.png", 1300.0, 0.7)
	_add("tumbleweed_a", "tumbleweed_a.png", 600.0, 0.0)
	_add("tumbleweed_b", "tumbleweed_b.png", 750.0, 0.0)
	_add("boulders_a", "boulders_a.png", 2600.0, 0.8)
	_add("boulders_b", "boulders_b.png", 2000.0, 0.8)
	_add("rock_pillar", "rock_pillar.png", 9000.0, 0.5)
	_add("rock_arch", "rock_arch.png", 6500.0, 0.9)
	_add("diner", "diner.png", 6000.0, 1.0)
	_add("gas_station", "gas_station.png", 4200.0, 1.0)
	_add("windmill", "windmill.png", 7000.0, 0.4)
	_add("fence", "fence.png", 1300.0, 1.0)
	_add("skull_post", "skull_post.png", 1700.0, 0.3)
	_add("road_sign", "road_sign.png", 2400.0, 0.9)


static func _add(id: String, file: String, world_h: float, collide: float) -> void:
	var tex: Texture2D = load(_dir + file)
	if tex == null:
		push_warning("Missing sprite: " + file)
		return
	defs[id] = {
		"tex": tex,
		"world_h": world_h,
		"world_w": world_h * tex.get_width() / float(tex.get_height()),
		"collide": collide,
	}
