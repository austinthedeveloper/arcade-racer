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

	_dir = ROADSIDE + "neon/"
	for id in ["casino_spire", "casino_lotus", "casino_round", "casino_star", "casino_wave", "casino_crown"]:
		_add(id, id + ".png", 11000.0, 1.0)
	for id in ["billboard_sunset", "sign_chevron", "sign_starburst", "sign_lights", "billboard_wide", "sign_stack"]:
		_add(id, id + ".png", 5200.0, 0.8)
	for id in ["neon_arrow", "neon_star", "neon_cocktail", "neon_chevrons", "neon_card", "neon_stars", "neon_spiral"]:
		_add(id, id + ".png", 3600.0, 0.3)
	_add("street_lamp_a", "street_lamp_a.png", 3400.0, 0.2)
	_add("street_lamp_b", "street_lamp_b.png", 3000.0, 0.2)
	_add("palm_lit", "palm_lit.png", 4200.0, 0.3)
	_add("fountain", "fountain.png", 2800.0, 1.0)

	_dir = ROADSIDE + "timberline/"
	_add("pine_a", "pine_a.png", 6400.0, 0.25)
	_add("pine_b", "pine_b.png", 6000.0, 0.25)
	_add("pine_c", "pine_c.png", 4200.0, 0.25)
	_add("pine_d", "pine_d.png", 3800.0, 0.25)
	_add("pine_e", "pine_e.png", 2500.0, 0.3)
	_add("pine_f", "pine_f.png", 2200.0, 0.3)
	_add("fallen_log", "fallen_log.png", 700.0, 0.9)
	_add("cabin", "cabin.png", 5000.0, 1.0)
	_add("lodge", "lodge.png", 6500.0, 1.0)
	_add("waterfall", "waterfall.png", 12000.0, 1.0)
	_add("lookout_tower", "lookout_tower.png", 8500.0, 0.4)
	_add("snowbank", "snowbank.png", 1100.0, 0.0)
	_add("guardrail", "guardrail.png", 900.0, 1.0)
	_add("chevron_sign", "chevron_sign.png", 1900.0, 0.8)
	_add("snow_cliff", "snow_cliff.png", 7000.0, 1.0)

	_dir = ROADSIDE + "bayou/"
	_add("cypress_a", "cypress_a.png", 8000.0, 0.15)
	_add("cypress_b", "cypress_b.png", 8400.0, 0.2)
	_add("cypress_c", "cypress_c.png", 6200.0, 0.15)
	_add("stilt_shack", "stilt_shack.png", 5000.0, 1.0)
	_add("boat_dock", "boat_dock.png", 3200.0, 1.0)
	_add("bait_shop", "bait_shop.png", 4800.0, 1.0)
	for id in ["reeds_a", "reeds_b", "reeds_c", "cattails"]:
		_add(id, id + ".png", 1000.0, 0.0)
	_add("heron", "heron.png", 1100.0, 0.0)
	for id in ["mist_a", "mist_b", "mist_c"]:
		_add(id, id + ".png", 1400.0, 0.0)
	_add("rail_post", "rail_post.png", 750.0, 1.0)
	_add("piling", "piling.png", 2000.0, 0.8)
	for id in ["rail_wood_a", "rail_wood_b", "rail_wood_short", "rail_end", "rail_wood_long", "rail_concrete", "rail_concrete_end"]:
		_add(id, id + ".png", 1000.0, 1.0)

	_dir = ROADSIDE + "harvest/"
	_add("barn", "barn.png", 6500.0, 1.0)
	_add("silos", "silos.png", 7500.0, 1.0)
	_add("water_tower", "water_tower.png", 8000.0, 0.4)
	_add("farm_windmill", "farm_windmill.png", 8000.0, 0.3)
	_add("oak", "oak.png", 6500.0, 0.2)
	_add("sunflowers", "sunflowers.png", 1500.0, 0.0)
	_add("corn", "corn.png", 1700.0, 0.0)
	_add("farm_stand", "farm_stand.png", 2200.0, 1.0)
	_add("hay_round", "hay_round.png", 1200.0, 1.0)
	_add("hay_bale", "hay_bale.png", 800.0, 1.0)
	_add("scarecrow", "scarecrow.png", 1800.0, 0.3)
	_add("farm_fence", "farm_fence.png", 900.0, 1.0)


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
