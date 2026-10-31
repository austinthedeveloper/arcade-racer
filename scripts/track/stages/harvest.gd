class_name HarvestValley
extends RefCounted
## Stage 6: Harvest Valley. Wide-open farmland at sunset: rolling hills between corn
## and sunflower fields, a farm stop with barn, silos and water tower, and windmills
## turning on the ridges.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#7a5aa8"),
		"sky_bottom": Color("#ffb05a"),
		"fog": Color("#f4c48a"),
		"below_horizon": Color("#c99a3a"),
		"grass": [Color("#8fae3e"), Color("#84a238")],  # pasture
		"sand": [Color("#e0b44a"), Color("#d6a942")],  # wheat stubble
		"rumble": [Color("#f4efe2"), Color("#b5402a")],
		"road": [Color("#66625c"), Color("#605c56")],
		"lane": Color("#f6efd8"),
		"clock": [48, 38, 25, 19],  # seconds on ARCADE: start, then each checkpoint (WS-11)
		"background": "res://assets/sprites/backgrounds/harvest_far.png",
		"specials": ["tractor", "combine", "pickup_red"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Harvest Valley"
	t.theme = theme()

	# Out of town through the pastures
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_MEDIUM)
	t.low_rolling_hills()
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY, Track.HILL_LOW)
	var farm_at := t.segments.size()
	t.straight(Track.LENGTH_MEDIUM)

	# The wheat country: big rolling hills, crests to jump
	var fields_start := t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.jump()
	t.hill(Track.LENGTH_MEDIUM, -Track.HILL_MEDIUM)
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY, Track.HILL_LOW)
	t.low_rolling_hills(Track.LENGTH_SHORT, Track.HILL_MEDIUM)
	t.jump(Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, -Track.HILL_LOW)
	t.straight(Track.LENGTH_LONG)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)
	t.jump(Track.HILL_LOW)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY, -Track.HILL_MEDIUM)
	var fields_end := t.segments.size()

	# Back through the pastures to the finish
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM)
	t.straight(Track.LENGTH_MEDIUM)
	var stand_at := t.segments.size() - 40
	t.low_rolling_hills()
	t.downhill_to_end(100)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, fields_start, fields_end)
	t.add_spans_at("harvest_trestle", [0.35, 0.7])
	# The farm stop: barn and silos on the right, water tower across the road
	t.add_sprite(farm_at, "barn", 1.7)
	t.add_sprite(farm_at + 14, "silos", 1.6)
	t.add_sprite(farm_at + 8, "water_tower", -1.9)
	t.add_sprite(stand_at, "farm_stand", 1.3)
	t.add_sprite(stand_at + 4, "scarecrow", -1.4)
	t.scatter(["grain_elevator", "produce_cart", "balloon", "farm_truck", "crop_duster", "pumpkins"], 200, 450, 2.0)
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, fields_start: int, fields_end: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1936
	var hay := ["hay_round", "hay_bale"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0

		# Windmills on the skyline and big lone oaks, far back, all the way through
		if i % 90 == 45:
			t.add_sprite(i, "farm_windmill", side * (3.0 + rng.randf() * 3.0))
		if i % 130 == 20:
			t.add_sprite(i, "oak", -side * (2.2 + rng.randf() * 2.0), rng.randf() < 0.5)

		if i >= fields_start and i < fields_end:
			# Wheat country: hay bales in the stubble, the odd scarecrow
			if i % 9 == 2:
				t.add_sprite(i, hay[rng.randi() % hay.size()], side * (1.3 + rng.randf() * 3.0), rng.randf() < 0.5)
			if i % 70 == 33:
				t.add_sprite(i, "scarecrow", side * (1.6 + rng.randf()))
			continue

		# Pastures: fenced rows of corn and sunflowers along the road
		if i % 5 == 0:
			t.add_sprite(i, "farm_fence", -1.15)
		if i % 5 == 2:
			t.add_sprite(i, "farm_fence", 1.15, true)
		if i % 12 == 6:
			t.add_sprite(i, "corn" if rng.randf() < 0.6 else "sunflowers", side * (1.6 + rng.randf() * 1.0), rng.randf() < 0.5)
		if i % 25 == 11:
			t.add_sprite(i, hay[rng.randi() % hay.size()], side * (2.0 + rng.randf() * 2.0))
