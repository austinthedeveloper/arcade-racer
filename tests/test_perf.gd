## Performance budget (EQ-7): the frame-time probe (tests/perf_probe.gd) on Neon Strip with
## rivals, heavy traffic, FX and parallax, run in its own headless Godot so its frames draw.
## Headless there is no GPU, so this is the CPU's share of a frame: the race's tick plus
## building its draw commands. The thresholds leave a slow CI runner plenty of headroom
## (this Mac: about 4 to 5 ms mean, docs/roadmap/08-engineering-and-quality.md); a
## regression that doubles the work still fails. PERF_PROBE=skip skips it.
extends TestSuite

const CPU_MEAN_MS := 12.0  # of a 16.7 ms frame: the GPU needs the rest
const CPU_P95_MS := 25.0  # one slow frame in twenty, this slow at most


func test_neon_strip_frame_time_is_within_budget() -> void:
	if OS.get_environment("PERF_PROBE") == "skip":
		check(true)
		return
	var perf := run_probe()
	if not check(not perf.is_empty(), "the probe printed its PERF line"):
		return
	eq(perf["stage"], "Neon Strip", "on Neon Strip")
	eq(int(perf["rivals"]), Rivals.COUNT, "with the full field of rivals")
	eq(int(perf["traffic"]), int(NeonStrip.theme()["traffic"]), "and its heavy traffic")
	check(int(perf["fx_peak"]) > 0, "FX were on")
	check(int(perf["fx_peak"]) <= FxLayer.MAX_PARTICLES, "within the FX cap")
	eq(int(perf["draw_distance"]), RoadRenderer.draw_distance(NeonStrip.theme()), "at the stage's draw distance")
	var cpu: Dictionary = perf["cpu"]
	print("      Neon Strip CPU per frame: mean %.2f ms, p95 %.2f ms (update %.2f, draw %.2f)" % [
		cpu["mean"], cpu["p95"], perf["update"]["mean"], perf["draw"]["mean"]])
	check(float(cpu["mean"]) < CPU_MEAN_MS, "mean CPU per frame %.2f ms under %.0f ms" % [cpu["mean"], CPU_MEAN_MS])
	check(float(cpu["p95"]) < CPU_P95_MS, "95th percentile %.2f ms under %.0f ms" % [cpu["p95"], CPU_P95_MS])


## The probe's numbers, or {} if it printed none.
static func run_probe(extra: Array[String] = []) -> Dictionary:
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/perf_probe.gd", "--"]
	args.append_array(extra)
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("PERF "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("PERF "))
			return parsed if parsed is Dictionary else {}
	return {}


func test_draw_distance_is_a_stage_setting() -> void:
	eq(RoadRenderer.draw_distance({}), Cfg.DRAW_DISTANCE, "the default")
	eq(RoadRenderer.draw_distance({"draw_distance": 180}), 180, "a stage's own")
	check(RoadRenderer.draw_distance(NeonStrip.theme()) < Cfg.DRAW_DISTANCE, "Neon Strip, the busiest stage, draws less")


func test_thin_far_segments_draw_as_one_band() -> void:
	var far := Segment.new()
	far.s1 = Vector2(320, 152.0)
	far.s2 = Vector2(320, 151.8)
	var near := Segment.new()
	near.s1 = Vector2(320, 152.5)
	near.s2 = far.s1
	check(RoadRenderer.thin_run(far, near), "under a pixel from the far edge to the near one")
	near.s1 = Vector2(320, 153.0)
	check(not RoadRenderer.thin_run(far, near), "a pixel or more is drawn on its own")
	# Only bare road waits for a nearer segment: anything standing on it is drawn after it
	var road := RoadRenderer.new()
	var bare := Segment.new()
	check(not road._stands_on(bare, false), "bare road can wait")
	check(road._stands_on(bare, true), "not under the player")
	for dress: Callable in [
		func(s: Segment): s.sprites.append({"id": "palm", "offset": 1.2, "flip": false}),
		func(s: Segment): s.cars.append(null),
		func(s: Segment): s.spans.append("tunnel"),
		func(s: Segment): s.pickups.append(null),
		func(s: Segment): s.covered = true,
		func(s: Segment): s.flags = Segment.FLAG_CHECKPOINT,
	]:
		var seg := Segment.new()
		dress.call(seg)
		check(road._stands_on(seg, false), "something on it")
	road.free()
