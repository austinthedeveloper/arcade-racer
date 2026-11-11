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


func test_grip_per_surface() -> void:
	var thunder := Thunderhead.build()
	for seg in thunder.segments:
		if not near(seg.grip, Thunderhead.theme()["grip"], 0.0001, "Thunderhead's wet road, all of it"):
			break
	var timber := Timberline.build()
	var snowy := 0
	var first := -1
	var last := -1
	for seg in timber.segments:
		if seg.grip < 1.0:
			snowy += 1
			first = seg.index if first < 0 else first
			last = seg.index
			eq(seg.ground_left, Track.GROUND_SAND, "low grip only in the snow")
	check(snowy > 100, "the summit's road is snowy (%d segments)" % snowy)
	eq(last - first + 1, snowy, "in one stretch")
	near(timber.segments[first].grip, Timberline.theme()["snow_grip"], 0.0001, "the summit's grip")
	check(Timberline.theme()["snow_grip"] > Thunderhead.theme()["grip"], "slightly lower: not as slippery as the storm")
	for i in [0, 2, 4, 5, 7]:
		for seg in Stages.build(i).segments:
			if not eq(seg.grip, 1.0, Stages.stage_name(i) + " is dry"):
				break


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


func test_no_chevrons_where_a_rail_lines_the_bend() -> void:
	# Review on #108: Bayou's island fence stood right behind the chevrons.
	var t := Track.new()
	t.straight(Track.LENGTH_MEDIUM)
	t.curve(Track.LENGTH_SHORT, Track.CURVE_HARD)
	t.finish_building(t.segments.size() - 5)
	var run := t.sharp_curves()[0]
	for i in range(run.x, run.y, 10):
		t.add_sprite(i, "rail_wood_a", -1.4)
	t.add_road_signs()
	var counts := _sprite_counts(t)
	eq(counts.get("chevron_a", 0) + counts.get("chevron_b", 0) + counts.get("chevron_c", 0), 0, "no chevrons on the railed side")
	eq(counts.get("turn_right", 0), 1, "the turn sign still stands")
	var bayou := BayouCauseway.build()
	for r in bayou.sharp_curves():
		var side := -signf(bayou.segments[r.x].curve)
		for i in range(r.x, r.y):
			for sp in bayou.segments[i].sprites:
				if sp["id"].begins_with("chevron_"):
					check(not bayou.railed(i, side), "Bayou: no chevron on a railed bend (segment %d)" % i)


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


## The arrow a turn sign shows as drawn: 1 right, -1 left (mirror() flips the art, not the id).
func _arrow(sp: Dictionary) -> float:
	var right: bool = (sp["id"] == "turn_right") != bool(sp["flip"])
	return 1.0 if right else -1.0


func _signs_before(t: Track, at: int, ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(0, at - Track.warning_reach()), at):
		for sp: Dictionary in t.segments[i].sprites:
			if ids.has(sp["id"]):
				out.append(sp)
	return out


func test_every_sharp_bend_is_signed_on_its_outside_mirrored_too() -> void:
	# WS-20: a turn arrow before every sharp bend on every stage, on the outside, pointing into
	# it; chevrons (or a rail) along the outside; the same on the stage mirrored.
	for i in Stages.count():
		for mirror in [false, true]:
			var t := Stages.build(i, mirror)
			var label := t.name + (" mirrored" if mirror else "")
			var runs := t.sharp_curves()
			check(not runs.is_empty(), label + " has sharp bends")
			for run in runs:
				var dir := signf(t.segments[run.x].curve)
				var signs := _signs_before(t, run.x, ["turn_left", "turn_right"])
				check(not signs.is_empty(), "%s: a turn sign before the bend at %d" % [label, run.x])
				check(signs.any(func(sp: Dictionary) -> bool: return signf(sp["offset"]) == -dir and _arrow(sp) == dir),
					"%s: the sign before %d on the outside, pointing into the bend" % [label, run.x])
				var lined := false
				for k in range(run.x, run.y):
					if t.railed(k, -dir):
						lined = true
					for sp: Dictionary in t.segments[k].sprites:
						if sp["id"].begins_with("chevron_"):
							lined = true
							check(signf(sp["offset"]) == -dir, "%s: chevron at %d on the outside" % [label, k])
				check(lined or run.y - run.x < Track.CHEVRON_EVERY, "%s: chevrons or a rail along the bend at %d" % [label, run.x])


func test_every_blind_crest_has_a_crest_sign_mirrored_too() -> void:
	for i in Stages.count():
		for mirror in [false, true]:
			var t := Stages.build(i, mirror)
			var label := t.name + (" mirrored" if mirror else "")
			var crests := t.blind_crests()
			check(not crests.is_empty(), label + " has blind crests")
			for c in crests:
				# A jump's crest is warned of by the bump sign before the jump itself
				var h := t.hazard_before(c)
				var signs := _signs_before(t, c if h < 0 else h, [Track.CREST_SIGN])
				check(not signs.is_empty(), "%s: a crest sign before the crest at %d" % [label, c])
				# On the right as built, so on the left mirrored
				check(signs.any(func(sp: Dictionary) -> bool: return signf(sp["offset"]) == t.side()),
					"%s: the crest sign at %d on its side of the road" % [label, c])


func test_a_warning_sign_moves_off_a_taken_spot() -> void:
	var t := Track.new()
	t.straight(Track.LENGTH_MEDIUM)
	t.jump()
	t.straight(Track.LENGTH_MEDIUM)
	t.finish_building(t.segments.size() - 5)
	var h: int = t.hazards[0]
	t.add_span(h - Track.SIGN_AHEAD, "palm_arch")
	t.add_road_signs()
	var at := -1
	for seg in t.segments:
		for sp in seg.sprites:
			if sp["id"] == Track.CREST_SIGN:
				at = seg.index
	check(at >= 0 and at != h - Track.SIGN_AHEAD, "the sign stands elsewhere (%d)" % at)
	check(at < h and h - at <= Track.warning_reach(), "but still before the jump (%d)" % at)
	eq(t.blind_crests().size(), 1, "the jump is a blind crest")
	eq(t.hazard_before(t.blind_crests()[0]), h, "the jump's own")
	var count := 0
	for seg in t.segments:
		for sp in seg.sprites:
			count += 1 if sp["id"] == Track.CREST_SIGN else 0
	eq(count, 1, "one sign for the jump and its crest")


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


# --- Road width (WS-7) -----------------------------------------------------------

func _narrowed(width := 0.6, lanes := 2) -> Track:
	var t := flat_track(600)
	t.set_width(200, 100, width, lanes, 40)
	return t


func test_set_width_eases_in_holds_and_eases_out() -> void:
	var t := _narrowed()
	for i in 160:
		eq([t.segments[i].width, t.segments[i].lanes], [1.0, 4], "segment %d before the ease" % i)
	for i in range(160, 199):
		check(t.segments[i].width_far < t.segments[i].width, "segment %d narrows" % i)
	for i in range(200, 300):
		eq([t.segments[i].width, t.segments[i].lanes], [0.6, 2], "segment %d narrowed" % i)
	for i in range(301, 340):
		check(t.segments[i].width_far > t.segments[i].width, "segment %d widens again" % i)
	for i in range(340, 600):
		eq([t.segments[i].width, t.segments[i].lanes], [1.0, 4], "segment %d after" % i)
	eq([t.segments[179].lanes, t.segments[180].lanes], [4, 2], "lanes merge halfway through the ease in")
	eq([t.segments[319].lanes, t.segments[320].lanes], [2, 4], "and split halfway through the ease out")
	near(t.segments[180].width, 0.8, 0.001, "half narrowed halfway in")


func test_road_width_is_continuous() -> void:
	var tracks: Array[Track] = [_narrowed(), _narrowed(1.5, 6)]
	tracks.append_array(_stages())
	for t in tracks:
		var bad := ""
		for i in t.segments.size() - 1:
			var seg := t.segments[i]
			if seg.width_far != t.segments[i + 1].width:
				bad = "the road jumps width after segment %d" % i
			elif absf(seg.width_far - seg.width) > 0.02:
				bad = "segment %d changes width too fast" % i
			elif seg.lanes < Track.MIN_LANES or seg.lanes > Track.MAX_LANES:
				bad = "segment %d has %d lanes" % [i, seg.lanes]
			if bad != "":
				break
		eq(bad, "", t.name + " eases from width to width")


func test_width_ease_at() -> void:
	eq(Track.width_ease_at(0, 100, 50, 40, 1.0, 0.5, 1.2), 1.0, "before the ease")
	eq(Track.width_ease_at(60, 100, 50, 40, 1.0, 0.5, 1.2), 1.0, "where it starts")
	near(Track.width_ease_at(80, 100, 50, 40, 1.0, 0.5, 1.2), 0.75, 0.0001, "halfway in")
	eq(Track.width_ease_at(100, 100, 50, 40, 1.0, 0.5, 1.2), 0.5, "eased in")
	eq(Track.width_ease_at(150, 100, 50, 40, 1.0, 0.5, 1.2), 0.5, "held")
	near(Track.width_ease_at(170, 100, 50, 40, 1.0, 0.5, 1.2), 0.85, 0.0001, "halfway out, to the width after")
	eq(Track.width_ease_at(500, 100, 50, 40, 1.0, 0.5, 1.2), 1.2, "after")
	# Eased in and out: slow at both ends of the ease, quickest in the middle
	var a := Track.width_ease_at(61, 100, 50, 40, 1.0, 0.5, 1.0) - Track.width_ease_at(60, 100, 50, 40, 1.0, 0.5, 1.0)
	var m := Track.width_ease_at(81, 100, 50, 40, 1.0, 0.5, 1.0) - Track.width_ease_at(80, 100, 50, 40, 1.0, 0.5, 1.0)
	check(absf(m) > absf(a) * 5.0, "eases in gently (%.4f, %.4f)" % [a, m])


func _lanes_near(actual: Array[float], expected: Array, msg: String) -> void:
	if eq(actual.size(), expected.size(), msg + ": lane count"):
		for k in expected.size():
			near(actual[k], expected[k], 0.0001, "%s: lane %d" % [msg, k])


func test_lane_offsets_follow_the_width() -> void:
	var seg := Segment.new()
	_lanes_near(seg.lane_offsets(), Traffic.LANE_OFFSETS, "the usual road")
	seg.width = 1.5
	seg.lanes = 6
	_lanes_near(seg.lane_offsets(), [-1.25, -0.75, -0.25, 0.25, 0.75, 1.25], "a boulevard")
	seg.width = 0.6
	seg.lanes = 2
	_lanes_near(seg.lane_offsets(), [-0.3, 0.3], "a narrowing")
	var merged: Array[float] = [seg.lane_at(0.125), seg.lane_at(0.375), seg.lane_at(0.625), seg.lane_at(0.875)]
	_lanes_near(merged, [-0.3, -0.3, 0.3, 0.3], "four lanes merge two into each")


func test_width_at_and_narrowest_ahead() -> void:
	var t := _narrowed()
	eq(t.width_at(100.0 * Cfg.SEGMENT_LENGTH), 1.0, "the usual road")
	eq(t.width_at(250.5 * Cfg.SEGMENT_LENGTH), 0.6, "the narrowing")
	var s := t.segments[170]
	near(t.width_at(170.5 * Cfg.SEGMENT_LENGTH), (s.width + s.width_far) / 2.0, 0.0001, "between a segment's ends")
	eq(t.narrowest_ahead(100.0 * Cfg.SEGMENT_LENGTH).lanes, 4, "nothing narrow just ahead")
	eq(t.narrowest_ahead(170.0 * Cfg.SEGMENT_LENGTH).lanes, 2, "two lanes coming up")


func test_stages_narrow_and_widen() -> void:
	var want := {"Palm Coast Boulevard": 6, "Skyline Finale": 6, "Timberline Pass": 2, "Thunderhead Highway": 2}
	for t in _stages():
		var lanes := {}
		for seg in t.segments:
			lanes[seg.lanes] = true
		if want.has(t.name):
			check(lanes.has(want[t.name]), "%s has a %d-lane stretch" % [t.name, want[t.name]])
		else:
			eq(lanes.keys(), [Cfg.LANES], t.name + " keeps to four lanes")
		for i in [Track.START_SEGMENT, t.finish_index]:
			eq(t.segments[i].lanes, Cfg.LANES, "%s: four lanes at segment %d" % [t.name, i])


# --- Traffic density along a stage (RC-20) ------------------------------------------

## Segments of `t` at each traffic level, Track.TRAFFIC_EMPTY to TRAFFIC_BUSY.
func _levels(t: Track) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	for seg in t.segments:
		out[seg.traffic] += 1
	return out


func test_every_stage_has_a_traffic_rhythm() -> void:
	for i in Stages.count():
		var t := Stages.build(i)
		for seg in t.segments:
			if not check(seg.traffic >= Track.TRAFFIC_EMPTY and seg.traffic <= Track.TRAFFIC_BUSY,
					"%s segment %d: a traffic level (%d)" % [t.name, seg.index, seg.traffic]):
				break
		var levels := _levels(t)
		check(levels[Track.TRAFFIC_BUSY] >= 100, "%s has a busy stretch (%s)" % [t.name, levels])
		check(levels[Track.TRAFFIC_EMPTY] + levels[Track.TRAFFIC_QUIET] >= 100, "%s has a quiet one (%s)" % [t.name, levels])
		check(levels[Track.TRAFFIC_NORMAL] + levels[Track.TRAFFIC_BUSY] > t.segments.size() / 3,
			"%s carries traffic on much of it (%s)" % [t.name, levels])
		var totals := Traffic.spawn_totals(t, Traffic.keep_clear(t, Track.START_SEGMENT))
		check(totals[totals.size() - 1] > 500.0, t.name + " has room for its traffic")
		eq(_levels(Stages.build(i, true)), levels, t.name + " mirrored keeps its stretches")


func test_towns_are_busy_and_the_desert_and_summit_empty() -> void:
	var palm := PalmCoast.build()
	var skyline := Stages.build(7)
	for t: Track in [palm, skyline]:
		for seg in t.segments:
			if seg.width >= PalmCoast.BOULEVARD_WIDTH and not eq(seg.traffic, Track.TRAFFIC_BUSY, t.name + ": the six-lane town is busy"):
				break
	var neon := NeonStrip.build()
	var mouth := neon.tunnel_mouths()[0]
	eq(neon.segments[mouth].traffic, Track.TRAFFIC_BUSY, "the Strip (its tunnel too) is busy")
	var redrock := Redrock.build()
	for i in 1000:
		if not eq(redrock.segments[i].traffic, Track.TRAFFIC_EMPTY, "Redrock's open desert is empty (segment %d)" % i):
			break
	var timber := Timberline.build()
	var snow := 0
	for seg in timber.segments:
		if seg.grip < 1.0:
			snow += 1
			if not eq(seg.traffic, Track.TRAFFIC_EMPTY, "Timberline's snowy summit is empty (segment %d)" % seg.index):
				break
	check(snow > 100, "over the whole summit")


func test_traffic_weights() -> void:
	eq(Track.traffic_weight(Track.TRAFFIC_EMPTY), 0.0, "empty: none")
	eq(Track.traffic_weight(Track.TRAFFIC_NORMAL), 1.0, "normal: the usual share")
	check(Track.traffic_weight(Track.TRAFFIC_QUIET) < 1.0, "quiet: less")
	check(Track.traffic_weight(Track.TRAFFIC_BUSY) > 1.5, "busy: plenty more")
	var t := flat_track(100)
	t.set_traffic(90, 20, Track.TRAFFIC_BUSY)
	eq([t.segments[89].traffic, t.segments[90].traffic, t.segments[99].traffic, t.segments[9].traffic, t.segments[10].traffic],
		[Track.TRAFFIC_NORMAL, Track.TRAFFIC_BUSY, Track.TRAFFIC_BUSY, Track.TRAFFIC_BUSY, Track.TRAFFIC_NORMAL], "a stretch over the loop's end wraps")
