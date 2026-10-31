class_name PalmCoast
extends RefCounted
## Stage 1: Palm Coast Boulevard. A beach boulevard with gentle curves, rolling
## hills, a stretch through town and a couple of jump crests.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#2b9fd8"),
		"sky_bottom": Color("#ffd98a"),
		"fog": Color("#f3dcaa"),
		"below_horizon": Color("#2f8fbf"),
		"grass": [Color("#57b23c"), Color("#4ca335")],
		"sand": [Color("#f1d79b"), Color("#e8ca86")],
		"rumble": [Color("#f4f4f4"), Color("#d8262e")],
		"road": [Color("#6e6e79"), Color("#686873")],
		"lane": Color("#f0f0f0"),
		"background": "res://assets/sprites/backgrounds/palm_coast_far.png",
		"specials": ["surf_van", "golf_cart", "ice_cream_truck"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Palm Coast Boulevard"
	t.theme = theme()

	# Beach on the left
	t.set_ground(Track.GROUND_SAND, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY)
	t.low_rolling_hills()
	t.curve(Track.LENGTH_LONG, -Track.CURVE_MEDIUM, Track.HILL_LOW)
	t.jump()
	t.straight(Track.LENGTH_MEDIUM)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.s_curves()
	var town_start := t.segments.size()

	# Through town
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.curve(Track.LENGTH_LONG, Track.CURVE_MEDIUM, -Track.HILL_LOW)
	t.bumps()
	t.straight(Track.LENGTH_SHORT)
	t.jump()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_HARD)
	t.hill(Track.LENGTH_LONG, Track.HILL_HIGH)
	t.hill(Track.LENGTH_MEDIUM, -Track.HILL_MEDIUM)
	var town_end := t.segments.size()

	# Back along the beach to the finish
	t.set_ground(Track.GROUND_SAND, Track.GROUND_GRASS)
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY)
	t.low_rolling_hills()
	t.jump()
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM)
	t.straight(Track.LENGTH_MEDIUM)
	t.downhill_to_end(100)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	var n := t.segments.size()
	t.segments[14].flags |= Segment.FLAG_START
	for f in [0.25, 0.5, 0.75]:
		t.add_checkpoint(int(n * f))
	t.finish_building(final_straight + 60)

	_decorate(t, town_start, town_end)
	t.add_spans_at("palm_arch", [0.03, 0.55])
	t.scatter(["lighthouse", "pier", "ice_cream_stand", "surfboards", "bikes", "gull_post"], 200, 350, 2.2, -1)
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, town_start: int, town_end: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var tall := ["palm_tall_a", "palm_tall_b", "palm_lean"]
	var short := ["palm_short_a", "palm_short_b", "palm_fan"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var in_town := i >= town_start and i < town_end
		var beach_left := seg.ground_left == Track.GROUND_SAND

		# Palm rows along both sides, the backbone of the stage's look
		if i % 12 == 0:
			t.add_sprite(i, tall[rng.randi() % tall.size()], 1.15 + rng.randf() * 0.3, rng.randf() < 0.5)
		if i % 12 == 6:
			t.add_sprite(i, tall[rng.randi() % tall.size()], -1.15 - rng.randf() * 0.3, rng.randf() < 0.5)
		if i % 17 == 5:
			t.add_sprite(i, short[rng.randi() % short.size()], 1.9 + rng.randf() * 1.5)
		if i % 23 == 9:
			t.add_sprite(i, "palm_cluster", 2.6 + rng.randf() * 1.5)
		if i % 9 == 2:
			t.add_sprite(i, "bush", 1.15 + rng.randf() * 0.6)

		if beach_left:
			if i % 37 == 0:
				t.add_sprite(i, "umbrella", -2.0 - rng.randf() * 2.0)
			if i % 37 == 18:
				t.add_sprite(i, "umbrella", -3.2 - rng.randf() * 1.5)
			if i % 160 == 80:
				t.add_sprite(i, "lifeguard_tower", -2.6)
		else:
			if i % 13 == 6:
				t.add_sprite(i, short[rng.randi() % short.size()], -1.9 - rng.randf() * 1.5)

		if in_town:
			if i % 14 == 10:
				t.add_sprite(i, "lamp_post", -1.08)
				t.add_sprite(i, "lamp_post", 1.08, true)
			if i % 70 == 35:
				t.add_sprite(i, "hotel", 2.8 if rng.randf() < 0.5 else -2.8)

		if i % 190 == 120:
			t.add_sprite(i, "billboard", 1.5)
