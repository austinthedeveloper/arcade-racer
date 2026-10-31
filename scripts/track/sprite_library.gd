class_name SpriteLibrary
extends RefCounted
## Roadside sprite definitions: texture, world size and collision width.

const ROADSIDE := "res://assets/sprites/roadside/"
const SPANS := "res://assets/sprites/spans/"
## World width of a span's opening: the road plus its rumble strips and a little margin.
const SPAN_OPENING := Cfg.ROAD_WIDTH * 2.7

static var defs: Dictionary = {}
## Road-spanning sprites (tunnels, bridges, gates): the road runs through their opening.
static var spans: Dictionary = {}
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
	_add("pier", "pier.png", 4200.0, 1.0)
	_add("ice_cream_stand", "ice_cream_stand.png", 3600.0, 0.9)
	_add("surfboards", "surfboards.png", 2200.0, 0.8)
	_add("lighthouse", "lighthouse.png", 8000.0, 0.5)
	_add("bikes", "bikes.png", 1200.0, 0.9)
	_add("gull_post", "gull_post.png", 1500.0, 0.4)

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
	_add("water_tower_wood", "water_tower_wood.png", 6500.0, 0.6)
	_add("rusty_truck", "rusty_truck.png", 1800.0, 1.0)
	_add("dino", "dino.png", 7000.0, 0.6)
	_add("cattle_sign", "cattle_sign.png", 2200.0, 0.5)
	_add("butte", "butte.png", 9000.0, 0.9)
	_add("arrow_sign", "arrow_sign.png", 4200.0, 0.4)

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
	_add("slot_machine", "slot_machine.png", 7500.0, 1.0)
	_add("cowboy_boot", "cowboy_boot.png", 6000.0, 0.8)
	_add("palm_lights", "palm_lights.png", 4600.0, 0.3)
	_add("casino_entrance", "casino_entrance.png", 6500.0, 1.0)
	_add("fountain_show", "fountain_show.png", 5000.0, 0.9)
	_add("searchlight", "searchlight.png", 3000.0, 0.7)

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
	_add("chairlift", "chairlift.png", 7500.0, 0.3)
	_add("chapel", "chapel.png", 6500.0, 1.0)
	_add("frozen_falls", "frozen_falls.png", 9000.0, 1.0)
	_add("moose", "moose.png", 2600.0, 0.6)
	_add("woodpile", "woodpile.png", 1600.0, 1.0)
	_add("snowman", "snowman.png", 1500.0, 0.5)

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
	_add("crab_shack", "crab_shack.png", 5500.0, 1.0)
	_add("gator", "gator.png", 700.0, 0.0)
	_add("crawfish_sign", "crawfish_sign.png", 3000.0, 0.8)
	_add("live_oak", "live_oak.png", 7000.0, 0.3)
	_add("riverboat", "riverboat.png", 5500.0, 1.0)
	_add("mailboxes", "mailboxes.png", 1300.0, 0.9)

	_dir = ROADSIDE + "harvest/"

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
	_add("grain_elevator", "grain_elevator.png", 10000.0, 1.0)
	_add("balloon", "balloon.png", 4000.0, 0.0)
	_add("farm_truck", "farm_truck.png", 2000.0, 1.0)
	_add("produce_cart", "produce_cart.png", 2400.0, 1.0)
	_add("crop_duster", "crop_duster.png", 4200.0, 1.0)
	_add("pumpkins", "pumpkins.png", 1500.0, 0.9)

	_dir = ROADSIDE + "thunder/"
	_add("truck_stop", "truck_stop.png", 6500.0, 1.0)
	_add("motel", "motel.png", 6000.0, 1.0)
	_add("jersey_barrier", "jersey_barrier.png", 900.0, 1.0)
	_add("cone", "cone.png", 650.0, 0.0)
	_add("cone_tall", "cone_tall.png", 780.0, 0.0)
	_add("drum", "drum.png", 900.0, 0.0)
	_add("barricade_post", "barricade_post.png", 1100.0, 0.5)
	_add("sawhorse", "sawhorse.png", 1000.0, 0.9)
	_add("hazard_post", "hazard_post.png", 1000.0, 0.5)
	_add("a_frame", "a_frame.png", 950.0, 0.9)
	for id in ["pole_a", "pole_b", "pole_c", "pole_transformer", "pole_tanks"]:
		_add(id, id + ".png", 5200.0, 0.2)
	_add("pole_tall", "pole_tall.png", 6000.0, 0.2)
	_add("pylon", "pylon.png", 11000.0, 0.6)
	_add("tree_windswept", "tree_windswept.png", 3200.0, 0.3)
	_add("tree_snapped", "tree_snapped.png", 2600.0, 0.3)
	_add("shrub_windswept", "shrub_windswept.png", 1700.0, 0.0)
	_add("puddle_a", "puddle_a.png", 500.0, 0.0)
	_add("puddle_b", "puddle_b.png", 500.0, 0.0)
	_add("wrecked_sign", "wrecked_sign.png", 3200.0, 0.8)
	_add("grain_bin", "grain_bin.png", 7000.0, 0.9)
	_add("storm_cellar", "storm_cellar.png", 1800.0, 1.0)
	_add("windmill_old", "windmill_old.png", 6500.0, 0.3)
	_add("flasher_barricade", "flasher_barricade.png", 1100.0, 0.9)
	_add("radar_dome", "radar_dome.png", 8000.0, 0.6)
	_add("tree_bent", "tree_bent.png", 3600.0, 0.3)

	_dir = ROADSIDE + "skyline/"
	for id in ["tower_twin", "tower_glass", "tower_round", "office_a", "deco_tower", "hotel_sky", "clock_tower"]:
		_add(id, id + ".png", 11000.0, 1.0)
	for id in ["galleria", "cafe", "apartments", "deco_pink", "brick_loft", "office_b", "office_c"]:
		_add(id, id + ".png", 7500.0, 1.0)
	_add("harbor_lamp", "harbor_lamp.png", 3600.0, 0.2)
	_add("harbor_lamp_double", "harbor_lamp_double.png", 3600.0, 0.2)
	_add("traffic_light", "traffic_light.png", 3000.0, 0.2)
	_add("traffic_light_arm", "traffic_light_arm.png", 3400.0, 0.15)
	_add("subway", "subway.png", 3200.0, 1.0)
	_add("crowd_barrier_city", "crowd_barrier_city.png", 1500.0, 1.0)
	for id in ["bridge_tower_x", "bridge_tower_h", "bridge_tower_a", "bridge_tower_slim"]:
		_add(id, id + ".png", 16000.0, 0.4)
	_add("harbor_crane", "harbor_crane.png", 11000.0, 0.6)
	_add("ferry_terminal", "ferry_terminal.png", 5500.0, 1.0)
	_add("dolphin_balloon", "dolphin_balloon.png", 6000.0, 0.0)
	for id in ["flag_a", "flag_b", "flag_c", "flag_d", "flag_e"]:
		_add(id, id + ".png", 3800.0, 0.1)
	_add("news_van", "news_van.png", 1900.0, 1.0)
	_add("fireworks_barge", "fireworks_barge.png", 2600.0, 1.0)

	# Race furniture for every stage
	_dir = ROADSIDE + "shared/"
	_add("guardrail_steel", "guardrail_steel.png", 650.0, 1.0)
	_add("barrier_red", "barrier_red.png", 900.0, 1.0)
	_add("tire_stack", "tire_stack.png", 1000.0, 1.0)
	_add("barrels_yellow", "barrels_yellow.png", 900.0, 1.0)
	_add("cone_orange", "cone_orange.png", 650.0, 0.0)
	_add("barricade", "barricade.png", 1000.0, 0.9)
	_add("barrier_orange", "barrier_orange.png", 900.0, 1.0)
	_add("crowd", "crowd.png", 1800.0, 1.0)
	_add("grandstand", "grandstand.png", 4200.0, 1.0)
	_add("flagman", "flagman.png", 1900.0, 0.4)
	_add("camera_tower", "camera_tower.png", 4500.0, 0.6)
	_add("inflatable_arch", "inflatable_arch.png", 3800.0, 0.3)
	for id in ["turn_left", "turn_right", "chevron_a", "chevron_b", "chevron_c", "bump_sign"]:
		_add(id, id + ".png", 2100.0, 0.4)
	_add("sign_green", "sign_green.png", 3200.0, 0.8)
	_add("sign_brown", "sign_brown.png", 3200.0, 0.8)
	_add("delineator", "delineator.png", 1100.0, 0.5)


	# id, texture, color that fills beside it (and above it for a tunnel ring), banner text box
	_add_span("neon_tunnel", Color("#140b26"), false)
	_add_span("neon_tunnel_ring", Color("#140b26"), true)
	_add_span("neon_gantry")
	_add_span("covered_bridge")
	_add_span("covered_bridge_truss", Color("#2a1a10"), true)
	_add_span("redrock_arch")
	_add_span("bayou_truss")
	_add_span("harvest_trestle")
	_add_span("thunder_overpass")
	_add_span("skyline_pylon")
	_add_span("palm_arch")
	_add_span("checkpoint_gate", Color.TRANSPARENT, false, Rect2(0.2, 0.09, 0.6, 0.2))
	_add_span("start_gantry", Color.TRANSPARENT, false, Rect2(0.27, 0.33, 0.46, 0.13))
	_add_span("finish_gantry")


## Adds a road-spanning sprite. Its world size comes from its opening, which must fit the road.
static func _add_span(id: String, fill := Color.TRANSPARENT, ceiling := false, banner := Rect2()) -> void:
	var tex: Texture2D = load(SPANS + id + ".png")
	if tex == null:
		push_warning("Missing span sprite: " + id)
		return
	var opening := find_opening(tex.get_image())
	var world_w := SPAN_OPENING / (opening.y - opening.x)
	spans[id] = {
		"tex": tex,
		"world_w": world_w,
		"world_h": world_w * tex.get_height() / float(tex.get_width()),
		"opening": opening,  # left and right edge, as fractions of the width
		"fill": fill,
		"ceiling": ceiling,
		"banner": banner,  # where gate text goes, as fractions of the sprite
	}


## The gap the road runs through: the transparent run through the middle of a row near the
## bottom, as (left, right) fractions of the image width.
static func find_opening(img: Image) -> Vector2:
	var w := img.get_width()
	var y := int(img.get_height() * 0.9)
	var mid := w / 2
	var left := mid
	var right := mid
	while left > 0 and img.get_pixel(left - 1, y).a < 0.5:
		left -= 1
	while right < w - 1 and img.get_pixel(right + 1, y).a < 0.5:
		right += 1
	return Vector2(float(left) / w, float(right + 1) / w)


## A span's (left, right) edges in road half-widths from the road center: its opening and
## its outer edges. Between them is the solid structure the car can hit.
static func span_edges(id: String) -> Dictionary:
	var def: Dictionary = spans[id]
	var w: float = def["world_w"] / Cfg.ROAD_WIDTH
	var o: Vector2 = def["opening"]
	var center := (o.x + o.y) / 2.0
	return {"inner": Vector2(o.x - center, o.y - center) * w, "outer": Vector2(-center, 1.0 - center) * w}


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
