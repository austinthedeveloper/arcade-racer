class_name Timberline
extends RefCounted
## Stage 4: Timberline Pass. Up from a lakeside valley through pine forest on
## switchback S-curves, over a snowy summit with a fire lookout, down past a waterfall
## to the ski lodge.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#1f6fe0"),
		"sky_bottom": Color("#cfe6ff"),
		"fog": Color("#e4eef8"),
		"below_horizon": Color("#3d6b3a"),
		"grass": [Color("#4f8f3a"), Color("#467f33")],  # forest floor
		"sand": [Color("#f2f6fb"), Color("#e1e9f3")],  # snow
		"rumble": [Color("#f4f4f4"), Color("#c0392b")],
		"road": [Color("#5d6068"), Color("#575a62")],
		"lane": Color("#f4f4f4"),
		"background": "res://assets/sprites/backgrounds/timberline_far.png",
		"specials": ["log_truck", "suv_green", "street_sweeper"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Timberline Pass"
	t.theme = theme()

	# The valley: cabins by the road, then the climb starts
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_MEDIUM)
	var cabins_at := t.segments.size() - 60
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_EASY, Track.HILL_LOW)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY, Track.HILL_LOW)
	t.hill(Track.LENGTH_MEDIUM, Track.HILL_MEDIUM)

	# Switchbacks up through the pines
	t.curve(Track.LENGTH_SHORT, -Track.CURVE_HARD, Track.HILL_LOW)
	t.curve(Track.LENGTH_SHORT, Track.CURVE_HARD, Track.HILL_LOW)
	t.curve(Track.LENGTH_SHORT, -Track.CURVE_HARD, Track.HILL_LOW)
	t.straight(Track.LENGTH_SHORT)
	t.curve(Track.LENGTH_SHORT, Track.CURVE_HARD, Track.HILL_LOW)
	t.curve(Track.LENGTH_SHORT, -Track.CURVE_HARD, Track.HILL_LOW)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, Track.HILL_LOW)
	var snow_start := t.segments.size()

	# The summit: snow on both sides, the fire lookout, a crest to jump
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.straight(Track.LENGTH_MEDIUM)
	var lookout_at := t.segments.size() - 30
	t.jump()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM)
	t.s_curves()
	var snow_end := t.segments.size()

	# The descent: past the waterfall, down to the lodge and the finish
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, -Track.HILL_MEDIUM)
	var waterfall_at := t.segments.size() - 40
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY, -Track.HILL_LOW)
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM)
	t.low_rolling_hills()
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)
	t.downhill_to_end(100)
	var final_straight := t.segments.size()
	var lodge_at := final_straight + 30
	t.straight(Track.LENGTH_LONG)

	t.finish_stage(final_straight)

	_decorate(t, snow_start, snow_end)
	t.add_tunnel(t.free_spot(snow_start - 120, 35), 30, "covered_bridge", "covered_bridge_truss", 2)
	t.add_sprite(cabins_at, "cabin", 1.5)
	t.add_sprite(cabins_at + 25, "cabin", -1.6, true)
	t.add_sprite(lookout_at, "lookout_tower", 1.8)
	t.add_sprite(waterfall_at, "waterfall", -2.2)
	t.add_sprite(lodge_at, "lodge", 1.6)
	t.scatter(["chapel", "moose", "chairlift", "woodpile", "frozen_falls", "snowman"], 200, 450, 1.8)
	# Brown scenic-route signs on the right
	t.scatter(["sign_brown", "sign_brown", "sign_brown", "sign_brown", "sign_brown"], 120, 800, 1.5, 1)
	t.add_road_signs(false)  # the bends have their own chevron boards (_decorate)
	t.add_race_furniture()
	t.add_finish_crowd()
	return t


static func _decorate(t: Track, snow_start: int, snow_end: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1910
	var tall := ["pine_a", "pine_b", "pine_c"]
	var small := ["pine_d", "pine_e", "pine_f"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var bend := absf(seg.curve) >= Track.CURVE_MEDIUM

		# Guardrail and chevrons on the outside of the sharp bends
		if bend:
			var outside := -signf(seg.curve)
			if i % 5 == 0:
				t.add_sprite(i, "guardrail", outside * 1.2)
			if i % 25 == 10:
				t.add_sprite(i, "chevron_sign", outside * 1.5)

		if i >= snow_start and i < snow_end:
			# Above the tree line: snowbanks, rock, a few small snowy pines
			if i % 9 == 0:
				t.add_sprite(i, "snowbank", side * (1.1 + rng.randf() * 0.8), rng.randf() < 0.5)
			if i % 13 == 5:
				t.add_sprite(i, small[rng.randi() % small.size()], -side * (1.3 + rng.randf() * 1.5))
			if i % 70 == 35:
				t.add_sprite(i, "snow_cliff", 2.0, false)
				t.add_sprite(i + 3, "snow_cliff", -2.0, true)
			continue

		# Forest: tall pines both sides, smaller ones between, the odd fallen log
		if i % 6 == 0:
			t.add_sprite(i, tall[rng.randi() % tall.size()], 1.2 + rng.randf() * 1.4, rng.randf() < 0.5)
		if i % 6 == 3:
			t.add_sprite(i, tall[rng.randi() % tall.size()], -1.2 - rng.randf() * 1.4, rng.randf() < 0.5)
		if i % 8 == 5:
			t.add_sprite(i, small[rng.randi() % small.size()], side * (1.1 + rng.randf() * 0.6), rng.randf() < 0.5)
		if i % 50 == 25:
			t.add_sprite(i, "fallen_log", side * 1.3, side < 0.0)
		if i % 90 == 45:
			t.add_sprite(i, "snow_cliff", side * 3.0, side < 0.0)
