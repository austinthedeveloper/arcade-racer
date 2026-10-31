## Track building and the stages.
extends TestSuite


func _stages() -> Array[Track]:
	var out: Array[Track] = []
	for i in Stages.count():
		out.append(Stages.build(i))
	return out


func test_every_stage_builds() -> void:
	for t in _stages():
		check(t.segments.size() > 1000, "%s is a full stage (%d segments)" % [t.name, t.segments.size()])
		eq(t.length, t.segments.size() * Cfg.SEGMENT_LENGTH, t.name + " length")
		check(t.finish_index > 0 and t.finish_index < t.segments.size(), t.name + " finish on the track")
		check(t.segments[t.finish_index].flags & Segment.FLAG_FINISH, t.name + " finish flag")


func test_stage_order_and_names() -> void:
	eq(Stages.count(), 8, "eight stages")
	eq(Stages.build(0).name, "Palm Coast Boulevard", "stage 1")
	eq(Stages.build(1).name, "Redrock Canyon", "stage 2")
	eq(Stages.build(2).name, "Neon Strip", "stage 3")
	eq(Stages.build(3).name, "Timberline Pass", "stage 4")
	eq(Stages.build(4).name, "Bayou Causeway", "stage 5")
	eq(Stages.build(5).name, "Harvest Valley", "stage 6")
	eq(Stages.build(6).name, "Thunderhead Highway", "stage 7")
	eq(Stages.build(7).name, "Skyline Finale", "stage 8")
	for i in Stages.count():
		eq(Stages.stage_name(i), Stages.build(i).name, "listed name of stage %d" % (i + 1))
	eq(Stages.next(0), 1, "Palm Coast leads to Redrock")
	eq(Stages.next(Stages.count() - 1), -1, "nothing after the last stage")


func test_stages_have_their_own_look() -> void:
	var backgrounds := {}
	var grounds := {}
	var skies := {}
	for t in _stages():
		backgrounds[t.theme["background"]] = true
		grounds[t.theme["grass"][0]] = true
		skies[t.theme["sky_top"]] = true
	eq(backgrounds.size(), Stages.count(), "a background per stage")
	eq(grounds.size(), Stages.count(), "a ground color per stage")
	eq(skies.size(), Stages.count(), "a sky per stage")
	for t in _stages():
		check(ResourceLoader.exists(t.theme["background"]), t.name + " background exists")


func test_checkpoints_are_in_order_before_the_finish() -> void:
	for t in _stages():
		eq(t.checkpoints.size(), 3, t.name + " has three checkpoints")
		var last := 0
		for c in t.checkpoints:
			check(c > last, "%s checkpoint %d after %d" % [t.name, c, last])
			check(t.segments[c].flags & Segment.FLAG_CHECKPOINT, "checkpoint flag at %d" % c)
			last = c
		check(last < t.finish_index, t.name + " checkpoints all before the finish")


func test_road_height_is_continuous() -> void:
	for t in _stages():
		var jump := -1
		for i in range(1, t.segments.size()):
			if t.segments[i].w1.y != t.segments[i - 1].w2.y:
				jump = i
				break
		eq(jump, -1, t.name + " height jumps at segment")


func test_find_segment_wraps() -> void:
	var t := flat_track(100)
	eq(t.find_segment(0.0).index, 0, "start")
	eq(t.find_segment(Cfg.SEGMENT_LENGTH * 1.5).index, 1, "inside segment 1")
	eq(t.find_segment(t.length + 10.0).index, 0, "past the end wraps")
	eq(t.find_segment(-10.0).index, 99, "before the start wraps")


func test_height_interpolates_within_a_segment() -> void:
	var t := Track.new()
	t.add_segment(0.0, 100.0)
	t.add_segment(0.0, 100.0)
	t.finish_building(1)
	near(t.height_at(Cfg.SEGMENT_LENGTH * 0.5), 50.0, 0.01, "halfway up")


func test_roadside_sprites_stay_off_the_road() -> void:
	for t in _stages():
		var bad := 0
		for seg in t.segments:
			for sp in seg.sprites:
				if absf(sp["offset"]) < 1.0:
					bad += 1
		eq(bad, 0, t.name + " sprites placed on the road")


func test_every_placed_sprite_has_art() -> void:
	for t in _stages():
		var missing := {}
		for seg in t.segments:
			for sp in seg.sprites:
				if not SpriteLibrary.defs.has(sp["id"]):
					missing[sp["id"]] = true
		eq(missing.keys(), [], t.name + " sprites without art")


func test_every_loaded_sprite_is_placed() -> void:
	var placed := {}
	for t in _stages():
		for seg in t.segments:
			for sp in seg.sprites:
				placed[sp["id"]] = true
	var stray: Array = []
	for id: String in SpriteLibrary.defs:
		if not placed.has(id):
			stray.append(id)
	eq(stray, [], "sprites no stage places (place them, or drop them from the sprite tools)")


func test_redrock_has_its_landmarks() -> void:
	var counts := {}
	for seg in Redrock.build().segments:
		for sp in seg.sprites:
			counts[sp["id"]] = counts.get(sp["id"], 0) + 1
	for id in ["diner", "gas_station", "windmill", "rock_arch", "rock_pillar", "saguaro_a", "tumbleweed_a"]:
		check(counts.get(id, 0) > 0, "Redrock has a " + id)
	eq(counts.get("diner", 0), 1, "one diner stop")
	check(not counts.has("palm_tall_a"), "no palms in the desert")


func _sprite_counts(t: Track) -> Dictionary:
	var counts := {}
	for seg in t.segments:
		for sp in seg.sprites:
			counts[sp["id"]] = counts.get(sp["id"], 0) + 1
	return counts


func test_neon_strip_has_its_landmarks() -> void:
	var counts := _sprite_counts(NeonStrip.build())
	for id in ["casino_spire", "casino_lotus", "neon_cocktail", "billboard_wide", "street_lamp_a", "palm_lit"]:
		check(counts.get(id, 0) > 0, "Neon Strip has a " + id)
	eq(counts.get("fountain", 0), 2, "a fountain each side of the plaza")
	check(not counts.has("saguaro_a"), "no cactus on the Strip")


func test_neon_strip_has_heavier_traffic() -> void:
	var r := race(false, true, 2)
	check(r.traffic.cars.size() > r.TRAFFIC_COUNT, "more cars than usual (%d)" % r.traffic.cars.size())
	eq(race(false, true, 0).traffic.cars.size(), r.TRAFFIC_COUNT, "Palm Coast keeps the usual count")


func test_timberline_has_its_landmarks() -> void:
	var t := Timberline.build()
	var counts := _sprite_counts(t)
	for id in ["pine_a", "pine_d", "cabin", "snowbank", "guardrail", "chevron_sign", "snow_cliff"]:
		check(counts.get(id, 0) > 0, "Timberline has a " + id)
	for id in ["lookout_tower", "waterfall", "lodge"]:
		eq(counts.get(id, 0), 1, "one " + id)
	var snow := 0
	for seg in t.segments:
		if seg.ground_left == Track.GROUND_SAND:
			snow += 1
	check(snow > 300, "snow at the summit (%d segments)" % snow)


func test_timberline_guardrails_sit_on_the_outside_of_bends() -> void:
	var wrong := 0
	var rails := 0
	for seg in Timberline.build().segments:
		for sp in seg.sprites:
			if sp["id"] == "guardrail":
				rails += 1
				if signf(sp["offset"]) == signf(seg.curve):
					wrong += 1
	check(rails > 20, "rails on the bends (%d)" % rails)
	eq(wrong, 0, "guardrails on the inside of a bend")


func test_bayou_has_causeways_over_water() -> void:
	var t := BayouCauseway.build()
	var counts := _sprite_counts(t)
	for id in ["cypress_a", "reeds_a", "mist_a", "piling", "heron"]:
		check(counts.get(id, 0) > 0, "Bayou has a " + id)
	for id in ["bait_shop", "stilt_shack", "boat_dock"]:
		eq(counts.get(id, 0), 1, "one " + id)
	var water := 0
	for seg in t.segments:
		if seg.ground_left != Track.GROUND_SAND:
			continue
		water += 1
		for sp in seg.sprites:
			if sp["id"] == "cypress_a" or sp["id"] == "cypress_b" or sp["id"] == "cypress_c":
				check(absf(sp["offset"]) >= 3.0, "cypress out in the water, not on the causeway")
	check(water > 1000, "long stretches over water (%d segments)" % water)


func test_bayou_fog_is_thicker() -> void:
	check(BayouCauseway.theme()["fog_density"] > Cfg.FOG_DENSITY, "thicker fog than the default")
	for i in Stages.count():
		if i != 4:
			check(Stages.build(i).theme.get("fog_density", Cfg.FOG_DENSITY) < BayouCauseway.theme()["fog_density"],
				Stages.stage_name(i) + " is clearer than the Bayou")


func test_harvest_has_its_farm() -> void:
	var t := HarvestValley.build()
	var counts := _sprite_counts(t)
	for id in ["farm_windmill", "oak", "corn", "sunflowers", "hay_round", "hay_bale", "farm_fence", "scarecrow"]:
		check(counts.get(id, 0) > 0, "Harvest has a " + id)
	for id in ["barn", "silos", "water_tower", "farm_stand"]:
		eq(counts.get(id, 0), 1, "one " + id)
	var top := 0.0
	for seg in t.segments:
		top = maxf(top, seg.w2.y)
	check(top >= Track.HILL_MEDIUM * Cfg.SEGMENT_LENGTH, "big rolling hills (top %.0f)" % top)


func test_thunderhead_has_its_landmarks() -> void:
	var t := Thunderhead.build()
	var counts := _sprite_counts(t)
	for id in ["pole_a", "pylon", "tree_windswept", "puddle_a", "cone", "jersey_barrier", "wrecked_sign"]:
		check(counts.get(id, 0) > 0, "Thunderhead has a " + id)
	for id in ["truck_stop", "motel"]:
		eq(counts.get(id, 0), 1, "one " + id)
	var poles_left := 0
	for seg in t.segments:
		for sp in seg.sprites:
			if sp["id"].begins_with("pole_") and sp["offset"] < 0.0:
				poles_left += 1
	eq(poles_left, 0, "the power line stays on the right")


func test_road_work_cones_never_crash_the_car() -> void:
	for id in ["cone", "cone_tall", "drum"]:
		eq(SpriteLibrary.defs[id]["collide"], 0.0, id + " gets knocked aside, not crashed into")


func test_skyline_has_its_landmarks() -> void:
	var t := SkylineFinale.build()
	var counts := _sprite_counts(t)
	for id in ["tower_twin", "harbor_lamp_double", "bridge_tower_x", "traffic_light", "harbor_crane", "fireworks_barge", "crowd"]:
		check(counts.get(id, 0) > 0, "Skyline has a " + id)
	var pylons := 0
	for seg in t.segments:
		pylons += seg.spans.count("skyline_pylon")
	check(pylons >= 4, "cable-stay pylons over the bridges (%d)" % pylons)


func test_every_stage_has_its_extras_and_a_finish_crowd() -> void:
	var extras := ["lighthouse", "dino", "slot_machine", "chapel", "gator", "balloon", "radar_dome", "dolphin_balloon"]
	for i in Stages.count():
		var t := Stages.build(i)
		var counts := _sprite_counts(t)
		check(counts.get(extras[i], 0) > 0, "%s has a %s" % [t.name, extras[i]])
		eq(counts.get("grandstand", 0), 1, t.name + " has a grandstand at the finish")


func test_sharp_curves_get_a_turn_sign_and_chevrons_on_the_outside() -> void:
	var t := Track.new()
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_SHORT, Track.CURVE_HARD)
	t.curve(Track.LENGTH_SHORT, -Track.CURVE_EASY)
	t.finish_building(t.segments.size() - 5)
	var runs := t.sharp_curves()
	eq(runs.size(), 1, "one sharp curve; the easy one is not")
	t.add_road_signs()
	var turn := 0
	var chevrons := 0
	for seg in t.segments:
		for sp in seg.sprites:
			if sp["id"] == "turn_right":
				turn += 1
				check(seg.index < runs[0].x, "the turn sign stands before the curve")
			if sp["id"].begins_with("chevron_"):
				chevrons += 1
				check(seg.index >= runs[0].x and seg.index < runs[0].y, "chevrons along the curve")
				check(sp["offset"] < -1.0, "chevrons on the outside of a right-hand curve")
				check(not sp["flip"], "chevrons point right, into the curve")
	eq(turn, 1, "a turn sign before the curve")
	check(chevrons >= 3, "chevrons along the curve (%d)" % chevrons)


func test_jumps_and_bumps_get_a_bump_sign_before_them() -> void:
	for t in _stages():
		var signs: Array[int] = []
		for seg in t.segments:
			for sp in seg.sprites:
				if sp["id"] == "bump_sign":
					signs.append(seg.index)
		check(not t.hazards.is_empty(), t.name + " has jumps or bumps")
		for h in t.hazards:
			if t.open_roadside(h - Track.SIGN_AHEAD):
				check(signs.has(h - Track.SIGN_AHEAD), "%s: a bump sign before segment %d" % [t.name, h])


func test_race_furniture_around_the_start_and_checkpoints() -> void:
	for t in _stages():
		var near_start := {}
		var near_checkpoints := {}
		for seg in t.segments:
			for sp in seg.sprites:
				if absi(seg.index - Track.START_SEGMENT) <= 20:
					near_start[sp["id"]] = true
				for c in t.checkpoints:
					if absi(seg.index - c) <= 24:
						near_checkpoints[sp["id"]] = true
		for id in ["tire_stack", "barrels_yellow", "inflatable_arch"]:
			check(near_start.has(id), "%s: %s at the start" % [t.name, id])
		for id in ["cone_orange", "delineator", "barricade", "barrier_orange"]:
			check(near_checkpoints.has(id), "%s: %s at the checkpoints" % [t.name, id])


func test_signs_and_furniture_stay_clear_of_spans_tunnels_and_gates() -> void:
	var furniture := ["turn_left", "turn_right", "chevron_a", "chevron_b", "chevron_c", "bump_sign",
		"tire_stack", "barrels_yellow", "cone_orange", "barricade", "barrier_orange", "inflatable_arch", "delineator"]
	for t in _stages():
		var bad := 0
		for seg in t.segments:
			for sp in seg.sprites:
				if furniture.has(sp["id"]) and not t.open_roadside(seg.index):
					bad += 1
		eq(bad, 0, t.name + " signs and furniture under a span, in a tunnel or on a gate")
