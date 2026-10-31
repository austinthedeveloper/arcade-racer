class_name NeonStrip
extends RefCounted
## Stage 3: Neon Strip. A night run down a casino boulevard: towers shoulder to
## shoulder, light-up signs on every block, heavy traffic, and a fountain plaza.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#0b0820"),
		"sky_bottom": Color("#5a1f6e"),
		"fog": Color("#2a1840"),
		"below_horizon": Color("#1a1030"),
		"grass": [Color("#3a2a5c"), Color("#34264f")],  # sidewalk paving
		"sand": [Color("#4b3a6e"), Color("#45346a")],  # plaza tiles
		"kickup": ["smoke", "smoke"],  # FxLayer: what the wheels throw up off the grass, off the sand
		"rumble": [Color("#ff3fb4"), Color("#2fe0ff")],
		"road": [Color("#2a2540"), Color("#262138")],  # wet asphalt
		"lane": Color("#f0e6ff"),
		"clock": [42, 45, 27, 26],  # seconds on ARCADE: start, then each checkpoint (WS-11)
		"background": "res://assets/sprites/backgrounds/neon_far.png",
		"specials": ["taxi", "limo_white", "tuk_tuk"],
		"traffic": 95,
		"tunnel_lights": [Color("#ff3fb4"), Color("#2fe0ff")],  # neon tubes down the tunnel walls
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Neon Strip"
	t.theme = theme()

	# Into town: the boulevard opens up, rolling over the city blocks
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY)
	t.hill(Track.LENGTH_SHORT, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM, -Track.HILL_LOW)
	t.straight(Track.LENGTH_MEDIUM)
	var strip_start := t.segments.size()

	# The Strip: casino towers wall in both sides, gentle bends
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY, Track.HILL_LOW)
	t.jump(Track.HILL_LOW * 0.5)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, -Track.HILL_LOW)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY, -Track.HILL_LOW)
	var strip_end := t.segments.size()

	# Fountain plaza, then the overpass climb and the drop to the finish
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	var plaza_at := t.segments.size() + 30
	t.straight(Track.LENGTH_SHORT)
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.s_curves()
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.jump()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)
	t.downhill_to_end(80)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, strip_start, strip_end, plaza_at)
	t.add_tunnel(t.free_spot(strip_start + 120, 50), 45, "neon_tunnel", "neon_tunnel_ring", 3, "neon_tunnel_exit")
	t.add_spans_at("neon_gantry", [0.08, 0.4, 0.68, 0.85])
	t.scatter(["casino_entrance", "slot_machine", "cowboy_boot", "fountain_show", "palm_lights", "searchlight"], 200, 450, 1.7)
	t.add_road_signs()
	t.add_race_furniture()
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, strip_start: int, strip_end: int, plaza_at: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var casinos := ["casino_spire", "casino_lotus", "casino_round", "casino_star", "casino_wave", "casino_crown"]
	var neon := ["neon_arrow", "neon_star", "neon_cocktail", "neon_chevrons", "neon_card", "neon_stars", "neon_spiral"]
	var boards := ["billboard_sunset", "sign_chevron", "sign_starburst", "sign_lights", "billboard_wide", "sign_stack"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0

		# Street lamps on both sides, every block
		if i % 12 == 0:
			t.add_sprite(i, "street_lamp_a", -1.12)
		if i % 12 == 6:
			t.add_sprite(i, "street_lamp_a", 1.12, true)

		if i >= strip_start and i < strip_end:
			# Casino towers shoulder to shoulder, neon signs at the curb
			if i % 14 == 2:
				t.add_sprite(i, casinos[rng.randi() % casinos.size()], 1.6 + rng.randf() * 0.4)
			if i % 14 == 9:
				t.add_sprite(i, casinos[rng.randi() % casinos.size()], -1.6 - rng.randf() * 0.4)
			if i % 9 == 4:
				t.add_sprite(i, neon[rng.randi() % neon.size()], side * 1.3, rng.randf() < 0.5)
			continue

		# The rest of town: billboards, neon signs, lit palms, the odd tower farther back
		if i % 20 == 3:
			t.add_sprite(i, boards[rng.randi() % boards.size()], side * (1.3 + rng.randf() * 0.6))
		if i % 16 == 11:
			t.add_sprite(i, neon[rng.randi() % neon.size()], -side * 1.25, rng.randf() < 0.5)
		if i % 10 == 7:
			t.add_sprite(i, "palm_lit", side * (1.2 + rng.randf() * 0.8), rng.randf() < 0.5)
		if i % 45 == 20:
			t.add_sprite(i, casinos[rng.randi() % casinos.size()], side * (2.6 + rng.randf() * 1.5))
		if i % 7 == 2:
			t.add_sprite(i, "street_lamp_b", side * (1.6 + rng.randf() * 0.4), side < 0.0)

	# The fountain plaza: a fountain each side, a big billboard over it
	t.add_sprite(plaza_at, "fountain", -1.5)
	t.add_sprite(plaza_at + 8, "fountain", 1.5)
	t.add_sprite(plaza_at + 20, "billboard_wide", 1.4)
	t.add_sprite(plaza_at - 15, "casino_lotus", -2.0)
