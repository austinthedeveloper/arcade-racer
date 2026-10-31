## Free Drive: no clock, no rivals, no finish.
extends TestSuite


func _free(traffic := false) -> Node:
	runner.root.get_node("Settings").attack_traffic = traffic
	var r := new_race(false, true, 0, true)
	r.tour = false
	r.free_drive = true
	r.start_race()
	_nodes.append(r)
	return r


func test_free_drive_is_solo_and_untimed() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var r := _free()
	eq(r.rivals.cars.size(), 0, "no rivals")
	eq(r.traffic.cars.size(), 0, "no traffic unless picked")
	check(not r.timed(), "no clock")
	r.time_left = 0.0
	drive(r, 300, input(1.0))
	eq(r.state, r.State.RACING, "no TIME UP")
	r.player.distance = r.finish_distance + 10.0
	drive(r, 5, input(1.0))
	eq(r.state, r.State.RACING, "no finish: the road goes on")
	eq(r.banner, "GO!", "no checkpoint or finish banners")
	eq(SaveData.bests.size(), 0, "nothing saved")
	runner.root.get_node("Settings").attack_traffic = false


func test_free_drive_traffic_when_picked() -> void:
	var r := _free(true)
	check(r.traffic.cars.size() > 0, "traffic")
	runner.root.get_node("Settings").attack_traffic = false
