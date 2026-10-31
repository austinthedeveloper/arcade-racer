class_name BayouCauseway
extends RefCounted
## Stage 5: Bayou Causeway. Dawn in the swamp: long, low causeways over open water
## between cypress islands, mist on the water, and a bait shop at the landing. Thick
## fog keeps the draw distance short.

static func theme() -> Dictionary:
	return {
		"sky_top": Color("#9cc4b4"),
		"sky_bottom": Color("#f6c9a8"),
		"fog": Color("#d9dccd"),
		"fog_density": 9.0,
		"below_horizon": Color("#7d8a62"),
		"grass": [Color("#5e7a3a"), Color("#557034")],  # swamp bank
		"sand": [Color("#6f8f86"), Color("#67877e")],  # still water
		"rumble": [Color("#e9e4d4"), Color("#8a6a42")],
		"road": [Color("#6a6a68"), Color("#646462")],
		"lane": Color("#efe9d6"),
		"background": "res://assets/sprites/backgrounds/bayou_far.png",
		"specials": ["airboat_trailer", "boat_trailer", "pickup_red"],
	}


static func build() -> Track:
	var t := Track.new()
	t.name = "Bayou Causeway"
	t.theme = theme()
	var causeways: Array[Vector2i] = []

	# The landing: bait shop and shacks on the bank
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.straight(Track.LENGTH_SHORT)
	t.straight(Track.LENGTH_MEDIUM)
	var landing_at := t.segments.size() - 50
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)

	# First causeway: long and flat over open water
	var start := t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_LONG, Track.CURVE_EASY)
	t.straight(Track.LENGTH_LONG)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_EASY)
	causeways.append(Vector2i(start, t.segments.size()))

	# A cypress island: bumpy, twisty swamp road
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.curve(Track.LENGTH_MEDIUM, -Track.CURVE_MEDIUM, Track.HILL_LOW * 0.5)
	t.bumps()
	t.curve(Track.LENGTH_MEDIUM, Track.CURVE_MEDIUM, -Track.HILL_LOW * 0.5)
	t.jump(Track.HILL_LOW * 0.5)

	var island := Vector2i(causeways[0].y, t.segments.size())

	# Second causeway, with a hump over the channel
	start = t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.straight(Track.LENGTH_MEDIUM)
	var channel := Vector2i(t.segments.size(), 0)
	t.hill(Track.LENGTH_SHORT, Track.HILL_LOW)
	t.hill(Track.LENGTH_SHORT, -Track.HILL_LOW)
	channel.y = t.segments.size()
	t.curve(Track.LENGTH_LONG, -Track.CURVE_EASY)
	t.straight(Track.LENGTH_MEDIUM)
	causeways.append(Vector2i(start, t.segments.size()))

	# Back onto the bank, then one last stretch over the water to the finish
	t.set_ground(Track.GROUND_GRASS, Track.GROUND_GRASS)
	t.s_curves()
	start = t.segments.size()
	t.set_ground(Track.GROUND_SAND, Track.GROUND_SAND)
	t.downhill_to_end(80)
	var final_straight := t.segments.size()
	t.straight(Track.LENGTH_LONG)
	causeways.append(Vector2i(start, t.segments.size()))

	t.finish_stage(final_straight)

	_decorate(t, causeways)
	_rails(t, island, channel)
	# An old steel truss bridge partway along the first causeway
	var truss := t.free_spot(causeways[0].x + 60, 30)
	for k in 5:
		t.add_span(truss + k * 6, "bayou_truss")
	t.add_sprite(landing_at, "bait_shop", 1.5)
	t.add_sprite(landing_at + 12, "stilt_shack", -1.8)
	t.add_sprite(landing_at + 30, "boat_dock", -1.4)
	t.scatter(["crab_shack", "gator", "crawfish_sign", "live_oak", "mailboxes", "riverboat"], 150, 450, 1.8)
	# Brown scenic-route signs on the right
	t.scatter(["sign_brown", "sign_brown", "sign_brown", "sign_brown", "sign_brown"], 120, 800, 1.5, 1)
	t.add_road_signs()
	t.add_race_furniture()
	t.add_finish_crowd()
	return t


## Old wooden fence rails along the cypress island, a concrete parapet over the channel hump.
## The fence stands back from the verge, behind the reeds.
static func _rails(t: Track, island: Vector2i, channel: Vector2i) -> void:
	var wood := ["rail_wood_a", "rail_wood_long", "rail_wood_b", "rail_wood_short"]
	_rail_run(t, island.x + 10, island.y - 10, wood, "rail_end", 1.4)
	_rail_run(t, channel.x, channel.y, ["rail_concrete"], "rail_concrete_end", 1.1)


## Rail panels both sides every 10 segments from `first` to `last`, an end piece at each end.
static func _rail_run(t: Track, first: int, last: int, panels: Array, end: String, offset: float) -> void:
	var k := 0
	for i in range(first, last, 10):
		var id: String = end if i == first or i + 10 >= last else panels[k % panels.size()]
		if t.open_roadside(i):
			t.add_sprite(i, id, -offset)
			t.add_sprite(i, id, offset, true)
		k += 1


static func _on_causeway(i: int, causeways: Array[Vector2i]) -> bool:
	for c in causeways:
		if i >= c.x and i < c.y:
			return true
	return false


static func _decorate(t: Track, causeways: Array[Vector2i]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1803
	var cypress := ["cypress_a", "cypress_b", "cypress_c"]
	var reeds := ["reeds_a", "reeds_b", "reeds_c", "cattails"]
	var mist := ["mist_a", "mist_b", "mist_c"]
	var n := t.segments.size()
	for i in range(12, n - 5):
		var seg := t.segments[i]
		if seg.flags != 0:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0

		if _on_causeway(i, causeways):
			# Railing posts both sides, pilings and mist out on the water, a cypress now and then
			if i % 4 == 0:
				t.add_sprite(i, "rail_post", -1.05)
				t.add_sprite(i, "rail_post", 1.05, true)
			if i % 17 == 5:
				t.add_sprite(i, "piling", side * (1.6 + rng.randf() * 1.5))
			if i % 11 == 3:
				t.add_sprite(i, mist[rng.randi() % mist.size()], side * (1.4 + rng.randf() * 3.0), rng.randf() < 0.5)
			if i % 40 == 20:
				t.add_sprite(i, cypress[rng.randi() % cypress.size()], side * (3.0 + rng.randf() * 3.0), rng.randf() < 0.5)
			if i % 150 == 75:
				t.add_sprite(i, "heron", side * (1.5 + rng.randf()), side < 0.0)
			continue

		# The banks: cypress trees hung with moss, reeds at the roadside
		if i % 7 == 0:
			t.add_sprite(i, cypress[rng.randi() % cypress.size()], 1.3 + rng.randf() * 1.8, rng.randf() < 0.5)
		if i % 7 == 4:
			t.add_sprite(i, cypress[rng.randi() % cypress.size()], -1.3 - rng.randf() * 1.8, rng.randf() < 0.5)
		if i % 3 == 1:
			t.add_sprite(i, reeds[rng.randi() % reeds.size()], side * (1.05 + rng.randf() * 0.6), rng.randf() < 0.5)
		if i % 23 == 9:
			t.add_sprite(i, mist[rng.randi() % mist.size()], side * (2.0 + rng.randf() * 2.0))
