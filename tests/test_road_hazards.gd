## Road hazards (RC-19): where each stage puts them, what each does to a car that drives
## onto it, who avoids them, and their callouts.
extends TestSuite

const AT := 220  # where the test track's hazard goes (clear of its gates and pickup spots)


## A straight test track with one hazard of `kind` in the lane `across` of the way over.
func _track_with(kind: int, length := 4, across := 0.6) -> Track:
	var t := flat_track(600)
	t.add_hazard(kind, AT, across, length)
	return t


## A car `back` segments short of the hazard, at `x`, at `share` of top speed.
func _car_before(h: RoadHazards.Hazard, x: float, share := 0.8, back := 10) -> PlayerCar:
	var p := PlayerCar.new()
	p.reset((h.segment - back) * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z)
	p.x = x
	p.speed = Cfg.MAX_SPEED * share
	return p


## Drives `p` for `seconds` as the race does each tick (update, collide, hazards); returns
## each hit as [kind, speed before it, speed after].
func _run(p: PlayerCar, t: Track, seconds: float, inp: DriveInput) -> Array:
	var hits := []
	for i in roundi(seconds / DT):
		p.update(DT, inp, t, true)
		p.collide(t)
		var before := p.speed
		RoadHazards.drive_over(p, t)
		RoadHazards.age(t, DT)
		if p.hazard_hit >= 0:
			hits.append([p.hazard_hit, before, p.speed])
	return hits


func _hazard(t: Track) -> RoadHazards.Hazard:
	return t.road_hazards[0]


func test_every_stage_places_its_hazards_in_lanes() -> void:
	var kinds := {}
	for i in Stages.count():
		var t := Stages.build(i)
		check(not t.road_hazards.is_empty(), "%s has road hazards" % t.name)
		for h: RoadHazards.Hazard in t.road_hazards:
			kinds[h.kind] = true
			var seg := t.segments[h.segment]
			check(seg.lane_offsets().has(h.offset), "%s: %s in a lane" % [t.name, RoadHazards.IDS[h.kind]])
			check(h.half < seg.width * 2.0 / seg.lanes, "%s: %s leaves the lane beside it clear" % [t.name, RoadHazards.IDS[h.kind]])
			for k in h.length:
				var s := t.segments[h.segment + k]
				check(s.hazards.has(h), "listed in every segment it covers")
				check(s.flags == 0 and s.spans.is_empty(), "%s: %s not under a gate or span" % [t.name, RoadHazards.IDS[h.kind]])
	for k in RoadHazards.Kind.size():
		check(kinds.has(k), "%s somewhere on the tour" % RoadHazards.IDS[k])


func test_ice_on_timberlines_summit_and_puddles_on_thunderhead() -> void:
	var t := Stages.build(3)
	var ice := t.road_hazards.filter(func(h: RoadHazards.Hazard) -> bool: return h.kind == RoadHazards.Kind.ICE)
	eq(ice.size(), 1, "one ice patch on Timberline")
	for k in ice[0].length:
		check(t.segments[ice[0].segment + k].grip < 1.0, "on the snowy summit (its snow grip)")
	var storm := Stages.build(6)
	var puddles := storm.road_hazards.filter(func(h: RoadHazards.Hazard) -> bool: return h.kind == RoadHazards.Kind.PUDDLE)
	check(puddles.size() >= 3, "puddles along Thunderhead (%d)" % puddles.size())
	var lanes := {}
	for h: RoadHazards.Hazard in puddles:
		lanes[h.offset] = true
	check(lanes.size() >= 3, "lane to lane, not all in one")
	for i in Stages.count():
		if i != 3:
			for h: RoadHazards.Hazard in Stages.build(i).road_hazards:
				check(h.kind != RoadHazards.Kind.ICE, "ice only on Timberline")
		if i != 6:
			for h: RoadHazards.Hazard in Stages.build(i).road_hazards:
				check(h.kind != RoadHazards.Kind.PUDDLE, "puddles only on Thunderhead")


## WS-6: a mirrored stage has them in the same segments, across the road by Track.side.
func test_a_mirrored_stage_mirrors_them() -> void:
	for i in Stages.count():
		var a := Stages.build(i)
		var b := Stages.build(i, true)
		eq(b.road_hazards.size(), a.road_hazards.size(), "%s: as many mirrored" % a.name)
		for k in a.road_hazards.size():
			var ha: RoadHazards.Hazard = a.road_hazards[k]
			var hb: RoadHazards.Hazard = b.road_hazards[k]
			eq([hb.segment, hb.kind, hb.length], [ha.segment, ha.kind, ha.length], "same place along")
			near(hb.offset, -ha.offset, 0.0001, "the other side of the road")


func test_add_hazard_keeps_off_gates_and_pickups() -> void:
	var t := flat_track(600)
	var gate := 240
	t.segments[gate].flags = Segment.FLAG_CHECKPOINT
	var h := t.add_hazard(RoadHazards.Kind.DEBRIS, gate, 0.5, 2)
	check(h != null, "placed")
	check(h.segment > gate + Track.HAZARD_MARGIN, "moved past the checkpoint gate (%d)" % h.segment)
	for f: float in PowerUps.SPOTS:
		check(absi(int(600 * f) - h.segment) >= Track.HAZARD_MARGIN, "clear of the pickup spot at %.2f" % f)
	var again := t.add_hazard(RoadHazards.Kind.CONES, h.segment, 0.5, 2)
	check(again.segment > h.segment + h.length, "a second one doesn't stack on the first")


func test_debris_bumps_the_car_once() -> void:
	var t := _track_with(RoadHazards.Kind.DEBRIS, 2)
	var h := _hazard(t)
	var p := _car_before(h, h.offset)
	var hops := 0
	var hits := []
	for i in roundi(1.5 / DT):
		var was_up := p.airborne
		hits.append_array(_run(p, t, DT, input(1.0)))
		if p.airborne and not was_up:
			hops += 1
	eq(hits.size(), 1, "one hit")
	eq(hits[0][0], RoadHazards.Kind.DEBRIS, "by the debris")
	near(hits[0][2] / hits[0][1], 1.0 - Tuning.v("hazards/debris_loss"), 0.0001, "the bump costs debris_loss of the speed")
	eq(hops, 1, "and bounces the car up once")
	check(not p.airborne, "down again after")


func test_hop_lifts_the_car_and_it_lands() -> void:
	var t := flat_track(600)
	var p := PlayerCar.new()
	p.reset(2000.0)
	p.speed = Cfg.MAX_SPEED * 0.5
	p.hop(1800.0)
	check(p.airborne, "in the air")
	var landed := false
	for i in 60:
		p.update(DT, input(1.0), t, true)
		landed = landed or p.landed
	check(landed, "lands within a second")
	p.hop(0.0)
	check(not p.airborne, "no lift, no hop")


func test_cones_slow_the_car_and_fly_off() -> void:
	var t := _track_with(RoadHazards.Kind.CONES, 6)
	var h := _hazard(t)
	var p := _car_before(h, h.offset)
	var hits := _run(p, t, 1.0, input(1.0))
	eq(hits.size(), 1, "one hit")
	eq(hits[0][0], RoadHazards.Kind.CONES, "by the cones")
	near(hits[0][2] / hits[0][1], 1.0 - Tuning.v("hazards/cones_loss"), 0.0001, "they cost cones_loss of the speed")
	check(not h.live(), "knocked flying")
	check(h.knocked > 0.0, "and flying")
	check(RoadHazards.cone_flight(RoadHazards.CONE_FLY).z <= 0.0, "gone once the flight is over")
	var next := _car_before(h, h.offset)
	eq(_run(next, t, 1.0, input(1.0)).size(), 0, "the next car finds the lane open")


func test_a_puddle_drags_the_car_back() -> void:
	var t := _track_with(RoadHazards.Kind.PUDDLE, 8)
	var h := _hazard(t)
	var p := _car_before(h, h.offset)
	var hits := _run(p, t, 1.0, input(1.0))
	eq(hits.size(), 1, "one hit over the whole puddle")
	eq(hits[0][0], RoadHazards.Kind.PUDDLE, "by the puddle")
	near(hits[0][2] / hits[0][1], 1.0 - Tuning.v("hazards/puddle_loss"), 0.0001, "it drags off puddle_loss of the speed")
	check(h.live(), "still there for the next car")
	eq(_run(_car_before(h, h.offset), t, 1.0, input(1.0)).size(), 1, "which it hits too")


func test_ice_takes_the_steering_and_slides_the_car() -> void:
	var t := _track_with(RoadHazards.Kind.ICE, 10)
	var h := _hazard(t)
	var p := _car_before(h, h.offset, 0.8, 4)
	var hits := _run(p, t, 0.15, input(1.0))
	eq(hits.size(), 1, "one hit as it drives on")
	eq(hits[0][0], RoadHazards.Kind.ICE, "by the ice")
	near(hits[0][2], hits[0][1], 0.001, "no speed lost, just grip")
	check(p.skid_time > 0.0, "sliding")
	# Steering on the ice against the same steering on a dry road: a share of it, ice_grip
	var dry := PlayerCar.new()
	dry.reset(p.position)
	dry.x = p.x
	dry.speed = p.speed
	var x0 := p.x
	p.skid_dir = 0.0  # (the drift aside, the steering alone)
	p.update(DT, input(1.0, 1.0), t, true)
	dry.update(DT, input(1.0, 1.0), flat_track(600), true)
	near((p.x - x0) / (dry.x - x0), Tuning.v("hazards/ice_grip"), 0.01, "ice_grip of the steering")
	eq(p.shown_steer(), 0.0, "the sprite slews the way it slides")


func test_on_ice_the_car_drifts_and_keeps_sliding_past_it() -> void:
	var t := _track_with(RoadHazards.Kind.ICE, 10)
	var h := _hazard(t)
	var p := _car_before(h, h.offset, 0.8, 4)
	_run(p, t, 0.15, input(1.0, 0.3))
	eq(p.skid_dir, 1.0, "sliding the way it was steering")
	var x0 := p.x
	_run(p, t, 0.2, input(1.0))
	check(p.x > x0 + 0.02, "drifting that way with the wheel straight (%.3f)" % (p.x - x0))
	eq(p.shown_steer(), 1.0, "the sprite slewed that way")
	# Off the far end it slides on for ice_time, then grips again
	run_until_off(p, t, h)
	check(p.skid_time > 0.0, "still sliding just past it")
	_run(p, t, Tuning.v("hazards/ice_time") + 0.1, input(1.0))
	eq(p.skid_time, 0.0, "gripping again ice_time after")


func run_until_off(p: PlayerCar, t: Track, h: RoadHazards.Hazard) -> void:
	for i in 600:
		if not h.covers(t.find_segment(p.position + Cfg.PLAYER_Z).index, t.segments.size()):
			return
		_run(p, t, DT, input(1.0))


func test_which_way_ice_slides() -> void:
	eq(RoadHazards.skid_way(-0.5, 3.0, 0.5), -1.0, "the way it steers")
	eq(RoadHazards.skid_way(0.0, 3.0, 0.5), -1.0, "else out of the bend")
	eq(RoadHazards.skid_way(0.0, -3.0, 0.5), 1.0, "either way")
	eq(RoadHazards.skid_way(0.0, 0.0, -0.4), -1.0, "else away from the middle")
	eq(RoadHazards.skid_way(0.0, 0.0, 0.4), 1.0, "on either side")


func test_the_next_lane_and_the_air_pass_it() -> void:
	for kind in RoadHazards.Kind.size():
		var t := _track_with(kind, 4, 0.4)
		var h := _hazard(t)
		var lane_w: float = t.segments[h.segment].width * 2.0 / t.segments[h.segment].lanes
		eq(_run(_car_before(h, h.offset + lane_w), t, 1.0, input(1.0)).size(), 0, "%s: the next lane over passes" % RoadHazards.IDS[kind])
		check(RoadHazards.reach(h) < lane_w, "%s: reaches less than a lane" % RoadHazards.IDS[kind])
		var p := _car_before(h, h.offset, 0.8, 2)
		p.hop(6000.0)
		eq(_run(p, t, 0.1, input(1.0)).size(), 0, "%s: a car in the air passes over" % RoadHazards.IDS[kind])


func test_every_hazard_has_its_callout() -> void:
	var seen := {}
	for kind in RoadHazards.Kind.size():
		var c := RoadHazards.callout(kind)
		check(c != Callouts.Kind.NONE and c != Callouts.Kind.MESSAGE, "%s bursts" % RoadHazards.IDS[kind])
		check(Callouts.TEXT.has(c), "with its text")
		check(Hud.BURSTS.has(c), "and its look")
		check(Callouts.IDS.values().has(c), "and a --callout name")
		seen[c] = true
	eq(seen.size(), RoadHazards.Kind.size(), "each its own")


func test_the_player_gets_the_callout_in_a_race() -> void:
	var r := race(true, false, 6, false)
	r.set("_hazard_shot", RoadHazards.Kind.PUDDLE)
	r.start_race()
	var ticks := run_until(r, func() -> bool: return r.player.hazard_hit == RoadHazards.Kind.PUDDLE, 1200)
	check(ticks > 0, "the --at-hazard start drives into the puddle")
	var c: Dictionary = r.callouts.current
	if not c.is_empty() and c["kind"] != Callouts.Kind.SPLASH:
		c = r.callouts.waiting.back() if not r.callouts.waiting.is_empty() else c
	eq(c.get("kind"), Callouts.Kind.SPLASH, "SPLASH! up")


func test_rivals_and_the_autodrive_pick_a_clear_lane() -> void:
	var t := _track_with(RoadHazards.Kind.DEBRIS, 2, 0.6)
	var h := _hazard(t)
	var me := PlayerCar.new()
	me.reset((h.segment - 30) * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z)
	me.x = h.offset
	me.speed = Cfg.MAX_SPEED * 0.8
	var z := me.position + Cfg.PLAYER_Z
	var lane: Dictionary = AIDriver.open_lane(t, z, h.offset, me, [me])
	check(absf(lane["x"] - h.offset) > RoadHazards.reach(h), "a rival moves out of its lane (%.2f)" % lane["x"])
	eq(lane["gap"], AIDriver.LOOKAHEAD, "without lifting for it: the traffic gap")
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	eq(RoadHazards.room(t, z, h.offset, half_car, 0.0, 50), 30, "it's 30 segments off in that lane")
	eq(RoadHazards.room(t, z, h.offset + 0.5, half_car, 0.0, 50), 50, "the next lane is clear")
	h.knocked = 0.0
	eq(RoadHazards.room(t, z, h.offset, half_car, 0.0, 50), 50, "nothing there once it's gone")


func test_flat_hazards_lay_their_picture_along_the_road() -> void:
	var uv := RoadRenderer.hazard_uvs(0, 4)
	eq(uv[0], Vector2(0, 1), "the near end of the first slice is the picture's bottom")
	eq(uv[3], Vector2(0, 0.75), "its far end a quarter up")
	eq(RoadRenderer.hazard_uvs(3, 4)[2], Vector2(1, 0), "the last slice ends at the top")
	for kind in RoadHazards.Kind.size():
		var tex := RoadHazards.texture(RoadHazards.sprite(kind))
		check(tex.get_width() > 8, "%s has its sprite" % RoadHazards.IDS[kind])
		check(RoadHazards.FLAT.has(kind) or RoadHazards.WORLD_H.has(kind), "%s is flat or stands" % RoadHazards.IDS[kind])


func test_cones_taper_across_the_lane() -> void:
	var t := _track_with(RoadHazards.Kind.CONES, 6)
	var h := _hazard(t)
	near(RoadHazards.cone_offset(h, 0, 6), h.offset - h.half, 0.0001, "the first at one side")
	near(RoadHazards.cone_offset(h, 5, 6), h.offset + h.half, 0.0001, "the last at the other")
	var up := RoadHazards.cone_flight(RoadHazards.CONE_FLY * 0.5)
	check(up.x > 1.0 and up.z > 0.0, "high and still showing midway")


func test_hazards_throw_up_their_effects() -> void:
	var p := PlayerCar.new()
	p.reset()
	p.speed = Cfg.MAX_SPEED * 0.5
	p.hazard_hit = RoadHazards.Kind.DEBRIS
	check(FxLayer.triggers(p, p.speed, 0.0).has("sparks"), "debris: sparks")
	p.hazard_hit = RoadHazards.Kind.PUDDLE
	check(FxLayer.triggers(p, p.speed, 0.0).has("splash"), "a puddle: a splash")
	p.hazard_hit = -1
	check(not FxLayer.triggers(p, p.speed, 0.0).has("skid"), "no skid off the ice")
	p.skid_time = 0.5
	check(FxLayer.triggers(p, p.speed, 0.0).has("skid"), "sliding on ice: snow off the wheels")
