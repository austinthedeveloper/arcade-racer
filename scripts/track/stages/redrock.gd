class_name Redrock
extends RefCounted
## Stage 2: Redrock Canyon. Open desert with long straights and big crests for air
## time, a run between rock pillars and arches, and a dusty diner stop.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#1996fd"),
		"sky_bottom": Color("#ddf0fd"),
		"fog": Color("#f6e3c4"),
		"below_horizon": Color("#d0682e"),
		"grass": [Color("#e8863a"), Color("#dc7b32")],  # red-orange desert dirt
		"sand": [Color("#f2b25e"), Color("#e9a651")],  # pale wash sand
		"rumble": [Color("#f8f8fa"), Color("#d70806")],
		"road": [Color("#4a4a53"), Color("#44444d")],
		"lane": Color("#f4f4f4"),
		"background": "res://assets/sprites/backgrounds/redrock_far.png",
		"specials": ["jeep_red", "tow_truck", "pickup_red"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Redrock Canyon"
	t.theme = theme()

	# Open desert: long straights and big crests
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_LONG)
	t.jump(Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY, Track.HILL_LOW)
	t.straight(Track.LENGTH_MEDIUM)
	t.jump(Track.HILL_MEDIUM * 0.5)
	t.hill(Track.LENGTH_MEDIUM, -Track.HILL_LOW)
	t.straight(Track.LENGTH_LONG)
	t.jump(Track.HILL_MEDIUM * 0.5)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, -Track.HILL_LOW)
	var canyon_start := t.segments.size()

	# Through the canyon: rock walls close on both sides, tighter bends
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_HARD, -Track.HILL_LOW)
	t.bumps()
	t.s_curves()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.jump()
	var canyon_end := t.segments.size()

	# The diner stop, then the long run to the finish
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_MEDIUM)
	var diner_at := t.segments.size() - 40
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY, -Track.HILL_LOW)
	t.jump(Track.HILL_LOW)
	t.straight(Track.LENGTH_MEDIUM)
	t.jump(Track.HILL_MEDIUM * 0.5)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)
	t.downhill_to_end(100)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, canyon_start, canyon_end, diner_at)
	t.add_spans_at("redrock_arch", [0.3, 0.42, 0.62])
	t.scatter(["water_tower_wood", "dino", "rusty_truck", "cattle_sign", "butte", "arrow_sign"], 250, 450, 1.8)
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, canyon_start: int, canyon_end: int, diner_at: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1955
	var saguaro := ["saguaro_a", "saguaro_b", "saguaro_c"]
	var low := ["prickly_pear_a", "prickly_pear_b", "boulders_b"]
	var weeds := ["tumbleweed_a", "tumbleweed_b"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0

		if i >= canyon_start and i < canyon_end:
			# Rock walls: pillars and boulders close to the road, an arch now and then
			if i % 8 == 0:
				t.add_sprite(i, "rock_pillar", 1.3 + rng.randf() * 0.6, rng.randf() < 0.5)
			if i % 8 == 4:
				t.add_sprite(i, "rock_pillar", -1.3 - rng.randf() * 0.6, rng.randf() < 0.5)
			if i % 11 == 2:
				t.add_sprite(i, "boulders_a", side * (1.1 + rng.randf() * 0.4))
			if i % 60 == 30:
				t.add_sprite(i, "rock_arch", side * 1.2)
			continue

		# Open desert: saguaros, low scrub, the odd tumbleweed and ranch fence
		if i % 15 == 0:
			t.add_sprite(i, saguaro[rng.randi() % saguaro.size()], 1.2 + rng.randf() * 1.5, rng.randf() < 0.5)
		if i % 15 == 8:
			t.add_sprite(i, saguaro[rng.randi() % saguaro.size()], -1.2 - rng.randf() * 1.5, rng.randf() < 0.5)
		if i % 10 == 3:
			t.add_sprite(i, low[rng.randi() % low.size()], side * (1.1 + rng.randf() * 2.0))
		if i % 19 == 7:
			t.add_sprite(i, weeds[rng.randi() % weeds.size()], side * (1.05 + rng.randf() * 0.8))
		if i % 120 == 60:
			t.add_sprite(i, "rock_pillar", side * (3.0 + rng.randf() * 2.0))
		if i % 200 == 100:
			t.add_sprite(i, "skull_post", side * 1.15)
		if i % 230 == 40:
			t.add_sprite(i, "road_sign", 1.3)
		if i % 6 == 0 and i % 300 < 60:
			t.add_sprite(i, "fence", -1.6)

	# The diner stop on the right, gas station across the road, windmill behind
	t.add_sprite(diner_at, "diner", 1.6)
	t.add_sprite(diner_at + 6, "gas_station", -1.5)
	t.add_sprite(diner_at + 18, "windmill", 3.2)
	t.add_sprite(diner_at - 30, "road_sign", -1.25)
