## Frame-time probe (EQ-7): an autodriven race on Neon Strip with rivals, its heavy traffic,
## FX and parallax, timed frame by frame. Prints one line, "PERF {json}", with the mean, 95th
## percentile and worst of each part in milliseconds:
##   update  the race's physics tick (Race._physics_process: cars, traffic, rivals, FX)
##   draw    building the frame's draw commands (every CanvasItem._draw the tick queued:
##           the road renderer's projection and sprite list, the parallax, FX and HUD)
##   cpu     the two together
##   frame   wall time between frames (windowed runs only; vsync is turned off)
## Headless, nothing reaches a GPU, so update and draw are the CPU's share of a frame;
## tests/test_perf.gd runs it that way and fails over a threshold. Windowed, frame is the
## real thing:
##   godot --headless --path . -s res://tests/perf_probe.gd
##   godot --path . --resolution 1920x1080 -s res://tests/perf_probe.gd -- --perf-frames=1200
## Options: --perf-stage=N (1-based, default 3), --perf-frames=N timed frames (default 480,
## after PERF_WARMUP), --perf-quiet (rivals and traffic off, for comparison),
## --perf-draw-distance=N (the stage's draw distance overridden, to weigh that lever).
extends SceneTree

const PERF_WARMUP := 200  # frames before timing starts: the countdown and the launch

## Marks a point in the frame's deferred work: its _draw runs in the order it was queued.
class Stamp:
	extends Node2D
	var at := 0

	func _draw() -> void:
		at = Time.get_ticks_usec()


var race: Node
var frames := 480
var quiet := false
var stage := 2
var reach := 0  # --perf-draw-distance: the stage's draw distance overridden, 0 for its own
var _before := Stamp.new()
var _after := Stamp.new()
var _frame := 0
var _last := 0
var _pending := 0  # the update time of the frame whose draws are still to come
var update: Array[float] = []
var draw: Array[float] = []
var cpu: Array[float] = []
var frame: Array[float] = []
var _fx_peak := 0


func _initialize() -> void:
	# The probe's own options, save and profiles: never the player's, and not the test
	# runner's scratch files either (another run may be using them)
	root.get_node("Settings").path = "user://perf_probe_settings.cfg"
	root.get_node("Settings").load_settings()
	root.get_node("SaveData").path = "user://perf_probe_save.cfg"
	root.get_node("SaveData").load_save()
	root.get_node("InputRouter").profile_path = "user://perf_probe_profiles.cfg"
	root.get_node("InputRouter").load_profiles()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-frames="):
			frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--perf-stage="):
			stage = clampi(int(arg.get_slice("=", 1)) - 1, 0, Stages.count() - 1)
		elif arg == "--perf-quiet":
			quiet = true
		elif arg.begins_with("--perf-draw-distance="):
			reach = int(arg.get_slice("=", 1))
	race = load("res://scenes/race.tscn").instantiate()
	race.set("stage_index", stage)
	race.set("_autodrive", true)
	race.set("_no_traffic", quiet)
	race.set("_no_rivals", quiet)
	root.add_child(_before)
	root.add_child(race)
	root.add_child(_after)


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _frame == 0:  # the race is ready now
		race.set_physics_process(false)  # ticked here, once a frame, so every frame does the same work
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if reach > 0:
			race.track.theme["draw_distance"] = reach
	if _frame > PERF_WARMUP:
		var d := (_after.at - _before.at) / 1000.0
		update.append(_pending / 1000.0)
		draw.append(d)
		cpu.append(_pending / 1000.0 + d)
		if DisplayServer.window_can_draw():
			frame.append((now - _last) / 1000.0)
		_fx_peak = maxi(_fx_peak, race.fx.alive_count())
	if update.size() >= frames:
		_report()
		return true
	_last = now
	_frame += 1
	_before.queue_redraw()
	var t0 := Time.get_ticks_usec()
	race._physics_process(TestSuite.DT)
	_pending = Time.get_ticks_usec() - t0
	_after.queue_redraw()
	return false


func _report() -> void:
	var out := {
		"stage": Stages.stage_name(stage), "frames": update.size(), "quiet": quiet,
		"traffic": race.traffic.cars.size(), "rivals": race.rivals.cars.size(),
		"draw_distance": RoadRenderer.draw_distance(race.track.theme), "fx_peak": _fx_peak,
		"window": "%dx%d" % [root.get_window().size.x, root.get_window().size.y],
		"update": stats(update), "draw": stats(draw), "cpu": stats(cpu),
	}
	if not frame.is_empty():
		out["frame"] = stats(frame)
	print("PERF ", JSON.stringify(out))

## {mean, p95, max} of `ms`, rounded to a hundredth.
static func stats(ms: Array[float]) -> Dictionary:
	var sorted := ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	return {"mean": snappedf(total / sorted.size(), 0.01), "p95": snappedf(p95, 0.01), "max": snappedf(sorted[-1], 0.01)}
