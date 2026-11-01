## Stage flow (WS-8): each stage's end dresses like the next stage's start, and the results
## crossfade the palette the rest of the way.
extends TestSuite


func test_blend_turns_over_the_run_in_and_holds() -> void:
	var f := 1000
	eq(StageFlow.blend(0, f), 0.0, "none at the start")
	eq(StageFlow.blend(f - StageFlow.BLEND_FROM, f), 0.0, "none until the run-in")
	var at_line := StageFlow.blend(f, f)
	check(at_line > 0.0 and at_line < StageFlow.ROAD_SHARE, "partway at the line (%.2f)" % at_line)
	near(StageFlow.blend(f + StageFlow.BLEND_TO, f), StageFlow.ROAD_SHARE, 0.001, "the road's share past it")
	near(StageFlow.blend(f + 200, f), StageFlow.ROAD_SHARE, 0.001, "held to the end")
	var last := -1.0
	for i in range(f - 200, f + 100, 5):
		var b := StageFlow.blend(i, f)
		check(b >= last, "never turns back (segment %d)" % i)
		last = b


func test_results_crossfade_the_rest_of_the_way() -> void:
	eq(StageFlow.crossfade(-1.0), 0.0, "not before the results")
	eq(StageFlow.crossfade(0.0), 0.0, "starts from where the road left it")
	eq(StageFlow.crossfade(StageFlow.CROSSFADE), 1.0, "done after CROSSFADE")
	near(StageFlow.share(0.6, -1.0), 0.6, 0.001, "the road's share while racing")
	near(StageFlow.share(0.6, StageFlow.CROSSFADE * 0.5), 0.8, 0.001, "halfway on")
	near(StageFlow.share(0.6, 10.0), 1.0, 0.001, "all the next stage's once faded")
	near(RoadRenderer.segment_shade(0.3, 0.0, false), 0.3, 0.001, "a segment in its own share")
	near(RoadRenderer.segment_shade(0.3, 1.0, false), 1.0, 0.001, "faded on by the results")
	eq(RoadRenderer.segment_shade(0.0, 0.0, true), 1.0, "past the end of the stage: the next stage")


func test_mix_lerps_the_palette_only() -> void:
	var a := PalmCoast.theme()
	var b := Redrock.theme()
	eq(StageFlow.mix(a, b, 0.0)["road"], a["road"], "none of the way: the stage's own")
	eq(StageFlow.mix(a, b, 1.0)["sky_top"], b["sky_top"], "all the way: the next stage's")
	var half := StageFlow.mix(a, b, 0.5)
	eq(half["grass"][1], (a["grass"][1] as Color).lerp(b["grass"][1], 0.5), "band colors mixed")
	eq(half["background"], a["background"], "the background strip stays the stage's")
	eq(half["clock"], a["clock"], "and so does its clock")
	near(half["fog_density"], Cfg.FOG_DENSITY, 0.001, "fog density mixed (both the default)")
	near(StageFlow.mix(a, BayouCauseway.theme(), 1.0)["fog_density"], 9.0, 0.001, "to Bayou's thick fog")


func test_every_stage_but_the_last_hands_over() -> void:
	for i in Stages.count():
		var t := Stages.build(i)
		if Stages.next(i) < 0:
			check(t.flow.is_empty() and t.next_theme.is_empty(), t.name + " (the finale) keeps its own end")
			eq(StageFlow.palette(t, 1.0), t.theme, "and draws in its own palette")
			continue
		eq(t.flow.size(), StageFlow.STEPS + 1, t.name + " palette steps")
		eq(t.next_theme["background"], Stages.theme(i + 1)["background"], t.name + " turns to the next stage")
		eq(StageFlow.palette(t, 1.0)["road"], t.next_theme["road"], t.name + " all the way is the next road")
		eq(StageFlow.palette(t, 0.0)["road"], t.theme["road"], t.name + " none of the way is its own")
		eq(t.segments[0].handover, 0.0, t.name + " starts in its own palette")
		check(t.segments[-1].handover > 0.5, t.name + " ends in the next stage's")


func test_every_handover_has_the_next_stages_landmark_and_verge() -> void:
	for i in Stages.count() - 1:
		var t := Stages.build(i)
		var look: Dictionary = StageFlow.DRESSING[i + 1]
		var landmark := 0
		var verge := 0
		var too_close := 0
		for seg in t.segments:
			for sp in seg.sprites:
				if seg.index > t.finish_index and sp["id"] == look["landmark"]:
					landmark += 1
				if seg.index >= t.finish_index - StageFlow.BLEND_FROM and look["verge"].has(sp["id"]):
					verge += 1
					if absf(sp["offset"]) < StageFlow.VERGE_OFFSET:
						too_close += 1
		check(landmark >= 1, "%s: %s past the line" % [t.name, look["landmark"]])
		check(verge >= 20, "%s: the next stage's verge (%d)" % [t.name, verge])
		eq(too_close, 0, t.name + ": the verge stands well off the road")


func test_dressing_names_only_sprites_with_art() -> void:
	SpriteLibrary.load_all()
	for i in range(1, StageFlow.DRESSING.size()):
		var look: Dictionary = StageFlow.DRESSING[i]
		check(SpriteLibrary.defs.has(look["landmark"]), "art for " + look["landmark"])
		for id: String in look["verge"]:
			check(SpriteLibrary.defs.has(id), "art for " + id)
	eq(StageFlow.DRESSING.size(), Stages.count(), "an entry per stage")


func test_the_race_fades_the_sky_to_the_next_stage_at_the_results() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var r := race(false, false, 0, false)
	drive(r, 200, input(1.0))
	eq(r.road.flow_share, 0.0, "the start: its own sky")
	r.player.distance = r.finish_distance + 1.0
	r.player.position = r.player.distance
	drive(r, 1, input(1.0))
	check(r.road.flow_share > 0.0 and r.road.flow_share <= StageFlow.ROAD_SHARE, "turning at the line (%.2f)" % r.road.flow_share)
	run_until(r, func() -> bool: return r.results.visible, 600)
	check(r.results.visible, "the results came up")
	drive(r, roundi(StageFlow.CROSSFADE * 60.0) + 2)
	near(r.road.flow_share, 1.0, 0.001, "the results faded it all the way")
	near(r.background.share, 1.0, 0.001, "the background too")
	eq(r.road.flow_fade, 1.0, "and every segment")
	r.start_race()
	eq(r.road.flow_share, 0.0, "a new race starts in its own palette")
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))


func test_a_single_race_results_keep_the_road_share() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var r := race(false, false, 0, false)
	r.tour = false
	r.start_race()
	drive(r, 200, input(1.0))
	r.player.distance = r.finish_distance + 1.0
	r.player.position = r.player.distance
	drive(r, 1, input(1.0))
	run_until(r, func() -> bool: return r.results.visible, 600)
	drive(r, roundi(StageFlow.CROSSFADE * 60.0) + 2)
	check(r.road.flow_share <= StageFlow.ROAD_SHARE, "no fade to a stage it doesn't go on to (%.2f)" % r.road.flow_share)
	eq(r.road.flow_fade, 0.0, "segments keep their own share")
	r.tour = true
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))


func test_free_drive_keeps_its_own_palette() -> void:
	var r := race(false, false, 0, false)
	r.free_drive = true
	r.start_race()
	check(not r.road.flow, "the stage flow is off: the road loops to its own start")
	r.free_drive = false


func test_sky_and_results_backdrop_follow_the_crossfade() -> void:
	var a := PalmCoast.theme()
	var b := Redrock.theme()
	eq(Background.sky_color(a, b, "sky_top", 0.0), a["sky_top"], "own sky at 0")
	eq(Background.sky_color(a, b, "sky_top", 1.0), b["sky_top"], "the next stage's at 1")
	eq(Background.sky_color(a, {}, "sky_top", 1.0), a["sky_top"], "no next stage: its own")
	var from := ResultsScreen.backdrop(a, b, 0.0)
	var to := ResultsScreen.backdrop(a, b, 1.0)
	check(from != to, "the results backdrop changes with the crossfade")
	near(to.a, 0.72, 0.001, "and dims the race as before")
	eq(ResultsScreen.backdrop(b, {}, 1.0), ResultsScreen.backdrop(b, {}, 0.0), "the finale's stays put")
	check(Background.layers_of(b).has("far"), "the next stage's layers load for the crossfade")
