class_name SkylineFinale
extends RefCounted
## Stage 8: Skyline Finale. Sunset into night over a harbor city: a waterfront
## boulevard, a downtown run between glass towers, a long cable-stayed bridge over
## the harbor, and a finish lined with crowds, flags and fireworks barges.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#24124a"),
		"sky_bottom": Color("#f2875a"),
		"fog": Color("#5b3f78"),
		"fog_density": 5.0,
		"below_horizon": Color("#1c2560"),
		"grass": [Color("#77768a"), Color("#6f6e82")],  # waterfront paving
		"sand": [Color("#22307a"), Color("#1e2b70")],  # harbor water
		"rumble": [Color("#e8e6ee"), Color("#d8283a")],
		"road": [Color("#34323e"), Color("#302e3a")],
		"lane": Color("#f2f0f6"),
		"clock": [42, 39, 34, 30],  # seconds on ARCADE: start, then each checkpoint (WS-11)
		"background": "res://assets/sprites/backgrounds/skyline_far.png",
		"specials": ["double_decker", "trolley", "news_truck", "taxi"],
		"traffic": 80,
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Skyline Finale"
	t.theme = theme()
	var bridges: Array[Vector2i] = []

	# The waterfront: harbor on the left, the city on the right
	t.set_ground(Track.GROUND_SAND, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY, Track.HILL_LOW * 0.5)

	# Downtown: towers on both sides, a run of blocks with bends and dips
	var downtown := Vector2i(t.segments.size(), 0)
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM)
	t.low_rolling_hills(Track.LENGTH_SHORT, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM)
	t.s_curves()
	t.straight(Track.LENGTH_MEDIUM)
	downtown.y = t.segments.size()

	# The harbor bridge: up onto the deck, a long sweep over the water, back down
	var start := t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY)
	t.straight(Track.LENGTH_LONG)
	t.hill(Track.LENGTH_MEDIUM, -Track.HILL_MEDIUM)
	bridges.append(Vector2i(start, t.segments.size()))

	# The port: cranes and the ferry terminal, then a second, lower bridge
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_SAND)
	var port := t.segments.size()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM)
	t.straight(Track.LENGTH_MEDIUM)
	t.jump(Track.HILL_LOW * 0.5)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY)
	start = t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)
	bridges.append(Vector2i(start, t.segments.size()))

	# Home along the waterfront to the finish
	t.set_ground(Track.GROUND_SAND, Track.GROUND_GRASS)
	t.s_curves()
	t.downhill_to_end(80)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, downtown, bridges, port)
	for b in bridges:
		# Cable-stay pylons over the deck, and the big towers out on the water
		var i := t.free_spot(b.x + 30, 20)
		while i >= 0 and i < b.y - 20:
			t.add_span(i, "skyline_pylon")
			i = t.free_spot(i + 300, 20)
	t.add_finish_crowd()
	t.add_sprite(t.finish_index - 20, "crowd_barrier_city", -1.3)
	t.add_sprite(t.finish_index + 20, "dolphin_balloon", -2.5)
	return t


static func _decorate(t: Track, downtown: Vector2i, bridges: Array[Vector2i], port: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2088
	var towers := ["tower_twin", "tower_glass", "tower_round", "office_a", "deco_tower", "hotel_sky", "clock_tower"]
	var blocks := ["galleria", "cafe", "apartments", "deco_pink", "brick_loft", "office_b", "office_c"]
	var bridge_towers := ["bridge_tower_x", "bridge_tower_h", "bridge_tower_a", "bridge_tower_slim"]
	var flags := ["flag_a", "flag_b", "flag_c", "flag_d", "flag_e"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0 or not seg.spans.is_empty():
			continue
		var on_bridge := false
		for b in bridges:
			on_bridge = on_bridge or (i >= b.x and i < b.y)

		if on_bridge:
			# Lamps along both rails, guardrail, the odd tower and boat out on the water
			if i % 6 == 0:
				t.add_sprite(i, "harbor_lamp_double", -1.15)
				t.add_sprite(i, "harbor_lamp_double", 1.15)
			if i % 5 == 1:
				t.add_sprite(i, "guardrail_steel", -1.05)
				t.add_sprite(i, "guardrail_steel", 1.05, true)
			if i % 240 == 120:
				t.add_sprite(i, bridge_towers[rng.randi() % bridge_towers.size()], -2.2)
				t.add_sprite(i, bridge_towers[rng.randi() % bridge_towers.size()], 2.2)
			if i % 170 == 100:
				t.add_sprite(i, "fireworks_barge", (1.0 if rng.randf() < 0.5 else -1.0) * (4.0 + rng.randf() * 2.0))
			continue

		var in_town := i >= downtown.x and i < downtown.y
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var left_water := seg.ground_left == Track.GROUND_SAND
		var right_water := seg.ground_right == Track.GROUND_SAND
		if in_town:
			# Downtown: towers shoulder to shoulder, traffic lights at the blocks
			if i % 9 == 0:
				t.add_sprite(i, towers[rng.randi() % towers.size()], -1.6 - rng.randf() * 0.8)
			if i % 9 == 4:
				t.add_sprite(i, towers[rng.randi() % towers.size()], 1.6 + rng.randf() * 0.8)
			if i % 40 == 20:
				t.add_sprite(i, "traffic_light_arm", -1.15)
				t.add_sprite(i, "traffic_light", 1.15)
			if i % 70 == 35:
				t.add_sprite(i, "subway", side * 1.3)
			continue

		# Waterfront and port: lamps on the promenade, blocks and palms on the city side
		if i % 8 == 0:
			t.add_sprite(i, "harbor_lamp", -1.15 if left_water else 1.15)
		for s in [-1.0, 1.0]:
			var water := left_water if s < 0.0 else right_water
			if water:
				if i % 120 == (60 if s < 0.0 else 0):
					t.add_sprite(i, "fireworks_barge" if rng.randf() < 0.5 else "ferry_terminal", s * (3.0 + rng.randf() * 1.5))
			elif i % 11 == (3 if s < 0.0 else 8):
				t.add_sprite(i, blocks[rng.randi() % blocks.size()], s * (1.5 + rng.randf() * 1.0))
			elif i % 11 == (6 if s < 0.0 else 1):
				t.add_sprite(i, "palm_tall_a" if rng.randf() < 0.5 else "palm_tall_b", s * 1.3, rng.randf() < 0.5)
		if i >= port and i < port + 200 and i % 50 == 10:
			t.add_sprite(i, "harbor_crane", side * 2.0)
		if i % 300 == 150:
			t.add_sprite(i, "news_van" if rng.randf() < 0.5 else "dolphin_balloon", side * 1.6)
		if i % 15 == 7 and i > n - 300:
			t.add_sprite(i, flags[rng.randi() % flags.size()], side * 1.25)
