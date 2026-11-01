## Car-angle review sheet: poses every car (or one) in each steering frame on a level
## straight, up the steepest hill and down the steepest drop of the stages (CarPoses), in
## the real race scene, and saves each frame plus an index.json for tools/car_angles.py.
##
##   godot --path . -s res://tools/car_angles.gd -- --out=/tmp/angles [--car=car_mesa] [--stage=3]
##
## Needs a display (the headless dummy driver draws nothing). Writes
## <out>/<car>_<slope>_<frame>.png (full 640x360 frames) and <out>/index.json.
extends SceneTree

var _out := "user://car_angles"
var _only_car := ""
var _only_stage := -1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--car="):
			_only_car = arg.get_slice("=", 1)
		elif arg.begins_with("--stage="):
			_only_stage = int(arg.get_slice("=", 1)) - 1
	TestSuite.use_scratch_settings(root.get_node("Settings"))
	TestSuite.use_scratch_save(root.get_node("SaveData"))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var spots := _spots()
	var race: Node = load("res://scenes/race.tscn").instantiate()
	race.set("_no_traffic", true)
	race.set("_no_rivals", true)
	root.add_child(race)
	await process_frame
	race.process_mode = Node.PROCESS_MODE_DISABLED
	race.hud.get_parent().visible = false  # the HUD's CanvasLayer
	var index := {"slopes": [], "steer": CarPoses.steer_values(), "cars": []}
	for slope: Array in CarPoses.SLOPES:
		var spot: Dictionary = spots[slope[0]]
		index["slopes"].append({"id": slope[0], "stage": spot["stage"] + 1, "stage_name": spot["stage_name"],
			"segment": spot["segment"], "pitch": snappedf(spot["pitch"], 0.01)})
	for car: Dictionary in Cars.LIST:
		if _only_car != "" and car["id"] != _only_car:
			continue
		var strips := CarSprites.strips(car["strip"])
		var pitched: Array = []
		for row: int in strips:
			if row != 0:
				pitched.append("up" if row < 0 else "down")
		index["cars"].append({"id": car["id"], "name": car["name"], "strip": car["strip"], "pitched_strips": pitched})
		for slope: Array in CarPoses.SLOPES:
			var spot: Dictionary = spots[slope[0]]
			if race.stage_index != spot["stage"]:
				race.stage_index = spot["stage"]
				race.start_race()
			race.road.player_strips = strips
			for f in CarPoses.steer_values().size():
				_pose(race, spot, CarPoses.steer_values()[f])
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var path := "%s/%s_%s_%d.png" % [_out, car["strip"], slope[0], f]
				root.get_viewport().get_texture().get_image().save_png(path)
		print("posed ", car["name"])
	var file := FileAccess.open(_out + "/index.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
	print("wrote ", _out)
	quit(0)


## The spot for each slope (CarPoses.find_spot) on the stage given, or the best of them all
## (the earliest stage on a tie).
func _spots() -> Dictionary:
	var tracks := {}
	for i in Stages.count():
		if _only_stage < 0 or i == _only_stage:
			tracks[i] = Stages.build(i)
	var out := {}
	for slope: Array in CarPoses.SLOPES:
		var best := {}
		for i: int in tracks:
			var track: Track = tracks[i]
			var seg := CarPoses.find_spot(track, slope[1])
			var score := CarPoses.spot_score(track, seg, slope[1])
			if best.is_empty() or score > best["score"]:
				best = {"stage": i, "stage_name": track.name, "segment": seg, "score": score,
					"pitch": CarPoses.pitch_at(track, (seg + 0.5) * Cfg.SEGMENT_LENGTH)}
		out[slope[0]] = best
	return out


## The player's car at rest on the spot, steering `steer`, settled at the road's pitch.
func _pose(race: Node, spot: Dictionary, steer: float) -> void:
	var p: PlayerCar = race.player
	p.position = spot["segment"] * Cfg.SEGMENT_LENGTH + Cfg.SEGMENT_LENGTH * 0.5 - Cfg.PLAYER_Z
	p.x = 0.0
	p.speed = 0.0
	p.steer = steer
	p.braking = false
	p.pitch = spot["pitch"]
	p.road_y = race.track.height_at(p.position + Cfg.PLAYER_Z)
	race.road.camera_z = p.position
	race.road.position = Vector2.ZERO
	race.background.offset = 0.0
	race._redraw()
