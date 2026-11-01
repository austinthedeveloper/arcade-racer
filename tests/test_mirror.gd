## Mirror mode (WS-6): every stage flipped left for right, opened per stage by a win, picked
## on stage select. The mirrored golden runs are in test_golden.
extends TestSuite


func _clean() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	runner.root.get_node("Settings").unlock_all = false


func _menu(up := false, down := false, confirm := false) -> MenuInput:
	var m := MenuInput.new()
	m.up_pressed = up
	m.down_pressed = down
	m.confirm_pressed = confirm
	return m


func test_a_mirrored_stage_is_the_stage_flipped() -> void:
	for i in Stages.count():
		var a := Stages.build(i)
		var b := Stages.build(i, true)
		var name := a.name
		check(not a.mirrored and b.mirrored, name + ": flagged")
		eq([a.side(), b.side()], [1.0, -1.0], name + ": sides")
		eq([b.segments.size(), b.length, b.finish_index, b.checkpoints, b.hazards],
			[a.segments.size(), a.length, a.finish_index, a.checkpoints, a.hazards], name + ": the same distances")
		var bad := []
		for k in a.segments.size():
			var sa := a.segments[k]
			var sb := b.segments[k]
			if sb.curve != -sa.curve or sb.w1 != sa.w1 or sb.w2 != sa.w2 or sb.flags != sa.flags or sb.spans != sa.spans \
					or sb.grip != sa.grip or sb.covered != sa.covered or sb.ground_left != sa.ground_right \
					or sb.ground_right != sa.ground_left or sb.sprites.size() != sa.sprites.size():
				bad.append(k)
				continue
			for n in sa.sprites.size():
				var pa: Dictionary = sa.sprites[n]
				var pb: Dictionary = sb.sprites[n]
				var keeps := Track.MIRROR_KEEPS_ART.has(pa["id"])
				if pb["id"] != pa["id"] or pb["offset"] != -pa["offset"] or pb["flip"] != (pa["flip"] if keeps else not pa["flip"]):
					bad.append(k)
		eq(bad.slice(0, 5), [], name + ": curves the other way, sprites on the other side, ground swapped")


func test_mirroring_twice_is_the_stage_as_built() -> void:
	var a := Stages.build(2)
	var b := Stages.build(2, true)
	b.mirror()
	check(not b.mirrored, "back")
	for k in range(0, a.segments.size(), 97):
		eq([b.segments[k].curve, b.segments[k].sprites], [a.segments[k].curve, a.segments[k].sprites], "segment %d" % k)


func test_whatever_is_placed_across_the_road_goes_by_side() -> void:
	var a := Stages.build(0)
	var b := Stages.build(0, true)
	eq(Traffic.lanes(a), Traffic.LANE_OFFSETS, "lanes as built")
	eq(Traffic.lanes(b), [0.75, 0.25, -0.25, -0.75], "mirrored: each the other side, in the same order")
	var ta := Traffic.new()
	var tb := Traffic.new()
	ta.spawn(a, 30)
	tb.spawn(b, 30)
	for k in 30:
		eq([tb.cars[k].z, tb.cars[k].offset, tb.cars[k].sprite], [ta.cars[k].z, -ta.cars[k].offset, ta.cars[k].sprite], "traffic car %d" % k)
	var pa := PowerUps.layout(a, 11)
	var pb := PowerUps.layout(b, 11)
	eq(pb.size(), pa.size(), "the same pickups")
	for k in pa.size():
		eq([pb[k].segment, pb[k].offset, pb[k].kind], [pa[k].segment, -pa[k].offset, pa[k].kind], "pickup %d" % k)


func test_rivals_line_up_and_drive_mirrored() -> void:
	var ra := race(true, false, 1, true, false)
	var rb := race(true, false, 1, true, true)
	for k in ra.rivals.cars.size():
		var a: RivalCar = ra.rivals.cars[k]
		var b: RivalCar = rb.rivals.cars[k]
		eq([b.x, b.distance, b.driver.lane_bias], [-a.x, a.distance, -a.driver.lane_bias], "rival %d" % k)


func test_spans_are_drawn_and_hit_mirrored() -> void:
	var def := {"world_w": 8000.0, "world_h": 2000.0, "opening": Vector2(0.1, 0.5)}
	var r := RoadRenderer.span_rect(def, 320.0, 300.0, 100.0, true)
	near(r.end.x - r.size.x * 0.3, 320.0, 0.001, "flipped, the off-center opening is still on the road")
	var banner := Rect2(0.1, 0.1, 0.3, 0.2)
	var box := RoadRenderer.banner_box(Rect2(0, 0, 100, 50), banner, true)
	check(box.is_equal_approx(Rect2(60, 5, 30, 10)), "the gate text moves over with the flipped art (%s)" % box)
	var built := RoadRenderer.banner_box(Rect2(0, 0, 100, 50), banner, false)
	check(built.is_equal_approx(Rect2(10, 5, 30, 10)), "as built: where it was (%s)" % built)
	var half := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var inner: Vector2 = SpriteLibrary.span_edges("redrock_arch")["inner"]
	var track := TestSuite.flat_track()
	track.segments[100].spans.append("redrock_arch")
	var p := PlayerCar.new()
	p.offroad = true
	p.x = inner.y + half
	check(p._collide_segment(track.segments[100], track), "as built: the right leg")
	track.mirror()
	p.x = -(inner.y + half)
	check(p._collide_segment(track.segments[100], track), "mirrored: its mirror image")
	p.x = 0.0
	p.offroad = false
	check(not p._collide_segment(track.segments[100], track), "the road through it stays open")


func test_the_ghost_is_shared_with_the_mirror() -> void:
	var g := Ghost.make(0, "car_vega")
	var p := PlayerCar.new()
	p.distance = 120.0
	p.x = 0.4
	p.steer = -0.2
	g.record(p, -1.0)
	eq(g.at(0), Vector3(120.0, -0.4, 0.2), "a mirrored run is saved as built")
	eq(Ghost.sided(g.at(0), -1.0), Vector3(120.0, 0.4, -0.2), "and replayed mirrored")
	eq(Ghost.sided(g.at(0), 1.0), g.at(0), "as built: as saved")


func test_a_stage_mirror_opens_on_a_win() -> void:
	eq(Unlocks.mirror_id(0), "mirror_palm_coast", "the unlock id")
	eq(Unlocks.mirror_id(7), "mirror_skyline", "per stage")
	check(not Unlocks.mirror_open(0, [], false), "locked from the start")
	check(Unlocks.mirror_open(0, ["mirror_palm_coast"], false), "won")
	check(not Unlocks.mirror_open(1, ["mirror_palm_coast"], false), "each stage its own")
	check(Unlocks.mirror_open(5, [], true), "unlock everything opens them all")
	check(Unlocks.earns_mirror(1, true), "first against rivals")
	check(not Unlocks.earns_mirror(2, true), "not second")
	check(not Unlocks.earns_mirror(1, false), "not alone on the road")
	check(Unlocks.mirror_condition(0) != "", "says what opens it")


func _finish(r: Node, first: bool) -> void:
	drive(r, 200, input(1.0))
	for rv: RivalCar in r.rivals.cars:
		rv.distance = 0.0 if first else r.finish_distance + 10.0
		rv.finished = not first
		rv.finish_time = 0.01
	r.player.distance = r.finish_distance + 1.0
	r._check_progress()


func test_winning_a_race_opens_its_mirror() -> void:
	_clean()
	var save: Node = runner.root.get_node("SaveData")
	var r := race(false, true, 0)
	_finish(r, true)
	eq(r.place, 1, "won")
	check(save.is_unlocked("mirror_palm_coast"), "Palm Coast's mirror opens")
	check(r.new_unlocks.has("mirror_palm_coast"), "and is announced: %s" % [r.new_unlocks])
	check(Hud.unlock_line(r.new_unlocks).contains("MIRROR MODE: PALM COAST BOULEVARD"), Hud.unlock_line(r.new_unlocks))
	_clean()
	var lost := race(false, true, 0)
	_finish(lost, false)
	check(lost.place > 1, "beaten")
	check(not save.is_unlocked("mirror_palm_coast"), "no mirror")
	var auto := race(true, true, 0)
	_finish(auto, true)
	check(not save.is_unlocked("mirror_palm_coast"), "an autodriven win saves nothing")
	_clean()


func test_the_unlock_line_names_cars_and_mirrors() -> void:
	eq(Hud.unlock_line(["car_skipper"] as Array[String]), "NEW CAR: DUNE SKIPPER", "a car")
	eq(Hud.unlock_line(["mirror_redrock"] as Array[String]), "MIRROR MODE: REDROCK CANYON", "a mirror")
	eq(Hud.unlock_line(["car_skipper", "mirror_palm_coast"] as Array[String]),
		"NEW CAR: DUNE SKIPPER   MIRROR MODE: PALM COAST BOULEVARD", "both")


func _game(mode: int) -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.mode_index = mode
	g.show_stage_select()
	g.menu.index = 0
	return g


func test_stage_select_toggles_mirror_once_its_won() -> void:
	_clean()
	var g := _game(ModeSelect.Item.SINGLE_RACE)
	check(g.menu.mirror_offered(), "a Single Race offers it")
	g.menu.handle(_menu(true))
	check(not g.mirror, "locked: stays off")
	runner.root.get_node("SaveData").unlock("mirror_palm_coast")
	g.menu.handle(_menu(true))
	check(g.mirror and g.menu.mirrored(), "won: on")
	g.menu.index = 1
	check(not g.menu.mirrored(), "on, but Redrock's mirror isn't won")
	g.menu.handle(_menu(true))
	check(not g.mirror, "off always goes")
	g.menu.handle(_menu(false, true))
	check(not g.mirror, "Down too, with no traffic to switch, on a locked mirror")
	g.menu.index = 0
	g.menu.handle(_menu(false, true))
	check(g.mirror, "Down too")
	g.menu.handle(_menu(false, false, true))
	g.menu.index = 0
	g.menu.handle(_menu(false, false, true))
	eq(g.screen, g.Screen.RACE, "racing")
	TestSuite.ready_all(g.race)  # (the game isn't in the tree)
	check(g.race.mirror and g.race.track.mirrored, "mirrored")
	check(g.race.background.mirrored, "background flipped")
	_clean()


func test_time_attack_keeps_down_for_traffic() -> void:
	_clean()
	var settings: Node = runner.root.get_node("Settings")
	settings.unlock_all = true
	var g := _game(ModeSelect.Item.TIME_ATTACK)
	var traffic: bool = settings.attack_traffic
	g.menu.handle(_menu(false, true))
	eq([settings.attack_traffic, g.mirror], [not traffic, false], "Down: traffic")
	g.menu.handle(_menu(true))
	eq([settings.attack_traffic, g.mirror], [not traffic, true], "Up: mirror")
	settings.attack_traffic = traffic
	TestSuite.use_scratch_settings(settings)
	_clean()


func test_the_grand_tour_races_stages_as_built() -> void:
	_clean()
	runner.root.get_node("Settings").unlock_all = true
	var g := _game(ModeSelect.Item.GRAND_TOUR)
	check(not g.menu.mirror_offered(), "no toggle")
	g.mirror = true
	check(not g.mirror_for(0), "a tour isn't mirrored")
	g.menu.handle(_menu(true))
	check(g.mirror, "Up does nothing")
	_clean()
