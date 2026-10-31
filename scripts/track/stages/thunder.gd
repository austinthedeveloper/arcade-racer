class_name Thunderhead
extends RefCounted
## Stage 7: Thunderhead Highway. Open storm plains under a dark sky: power lines
## marching beside the road, windswept trees, a truck stop and motel, and a
## construction zone lined with cones and barrels.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#1b2140"),
		"sky_bottom": Color("#6d6f96"),
		"fog": Color("#59607e"),
		"fog_density": 5.5,
		"below_horizon": Color("#2f3d2c"),
		"grass": [Color("#3f5a32"), Color("#38512d")],  # wet prairie
		"sand": [Color("#57594f"), Color("#505248")],  # gravel shoulder
		"rumble": [Color("#d8d8dc"), Color("#e0a020")],
		"road": [Color("#3c3e46"), Color("#373941")],  # rain-soaked asphalt
		"lane": Color("#e6e6ea"),
		"background": "res://assets/sprites/backgrounds/thunder_far.png",
		"specials": ["tanker", "cement_mixer", "dump_truck"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Thunderhead Highway"
	t.theme = theme()

	# Out onto the plains: long straights, gentle sweepers
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY, Track.HILL_LOW)
	t.jump(Track.HILL_LOW * 0.5)
	t.straight(Track.LENGTH_MEDIUM)
	var stop_at := t.segments.size() - 60
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM, -Track.HILL_LOW)

	# Road works: gravel shoulders, cones and barrels at the edge, a chicane
	var works_start := t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.straight(Track.LENGTH_SHORT)
	t.curve(Track.LENGTH_SHORT, Track.CURVE_MEDIUM)
	t.curve(Track.LENGTH_SHORT, -Track.CURVE_MEDIUM)
	t.straight(Track.LENGTH_MEDIUM)
	var works_end := t.segments.size()

	# Into the heart of the storm: rolling hills and big crests
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.low_rolling_hills(Track.LENGTH_SHORT, Track.HILL_MEDIUM)
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY)
	t.jump()
	t.s_curves()
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, Track.HILL_LOW)
	t.downhill_to_end(100)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, works_start, works_end)
	t.add_spans_at("thunder_overpass", [0.15, 0.45, 0.6, 0.88])
	t.add_sprite(stop_at, "truck_stop", 1.6)
	t.add_sprite(stop_at + 20, "motel", -1.7)
	t.scatter(["grain_bin", "storm_cellar", "windmill_old", "radar_dome", "flasher_barricade", "tree_bent"], 250, 450, 1.9)
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, works_start: int, works_end: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1974
	var poles := ["pole_a", "pole_b", "pole_c", "pole_transformer", "pole_tanks", "pole_tall"]
	var trees := ["tree_windswept", "tree_snapped", "shrub_windswept"]
	var cones := ["cone", "cone_tall", "drum"]
	var signs := ["barricade_post", "hazard_post", "sawhorse", "a_frame"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0

		# A power line runs the length of the stage on the right; pylons far off on the left
		if i % 10 == 0:
			t.add_sprite(i, poles[rng.randi() % poles.size()], 1.5)
		if i % 60 == 30:
			t.add_sprite(i, "pylon", -3.5 - rng.randf() * 2.0)

		if i >= works_start and i < works_end:
			# Road works: cones and drums at the edge, barriers and signs behind them
			if i % 3 == 0:
				t.add_sprite(i, cones[rng.randi() % cones.size()], -1.05)
				t.add_sprite(i, cones[rng.randi() % cones.size()], 1.05)
			if i % 12 == 6:
				t.add_sprite(i, "jersey_barrier", side * 1.4)
			if i % 15 == 9:
				t.add_sprite(i, signs[rng.randi() % signs.size()], -side * 1.3)
			continue

		# The plains: windswept trees, puddles, the odd wrecked billboard
		if i % 8 == 3:
			t.add_sprite(i, trees[rng.randi() % trees.size()], -1.2 - rng.randf() * 2.5, rng.randf() < 0.5)
		if i % 13 == 7:
			t.add_sprite(i, trees[rng.randi() % trees.size()], 2.0 + rng.randf() * 2.0, rng.randf() < 0.5)
		if i % 9 == 5:
			t.add_sprite(i, "puddle_a" if rng.randf() < 0.5 else "puddle_b", side * (1.1 + rng.randf() * 1.5))
		if i % 140 == 70:
			t.add_sprite(i, "wrecked_sign", side * 1.4)
