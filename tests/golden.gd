## Golden traces: per-frame hashes of the race state over scripted autodriven runs.
## Any change to play changes a hash; display-only work never does.
##
## Regenerate (only for an intended change to play, with a reason in the
## commit): godot --headless --path . -s res://tests/golden.gd
class_name Golden
extends SceneTree

const DIR := "res://tests/golden/"
const SCENARIOS := ["autodrive_traffic", "autodrive_clear_road", "redrock_autodrive_traffic",
	"neon_autodrive_traffic", "timberline_autodrive_traffic"]
## Scenario name prefix -> stage index (no prefix: Palm Coast).
const STAGE_PREFIXES := {"redrock_": 1, "neon_": 2, "timberline_": 3}
const FRAMES := 7500  # the countdown plus the longest the clock allows (45 s + 3 checkpoint bonuses)


## Frame hashes for a scenario: [frames..., final snapshot string].
static func run(scenario: String, frames: int = FRAMES) -> PackedStringArray:
	var stage := 0
	for prefix in STAGE_PREFIXES:
		if scenario.begins_with(prefix):
			stage = STAGE_PREFIXES[prefix]
	var r := TestSuite.new_race(true, scenario.ends_with("_traffic"), stage)
	var out := PackedStringArray()
	var banner := ""
	for f in frames:
		r._physics_process(TestSuite.DT)
		var snap := snapshot(r)
		var event := ""
		if r.banner != banner:
			banner = r.banner
			event = banner
		out.append("%d %08x %s" % [f, snap.hash(), event])
	out.append(snapshot(r))
	r.free()
	return out


## The state that matters for play, rounded so tiny float differences between
## machines don't count.
static func snapshot(r: Node) -> String:
	var p: PlayerCar = r.player
	var cars := 0.0
	for c in r.traffic.cars:
		cars += c.z
	return "state=%d t=%.2f left=%.2f cp=%d z=%.1f x=%.3f v=%.1f air=%.1f crash=%.2f nitro=%d/%.2f cars=%.0f" % [
		r.state, r.race_time, r.time_left, r.next_checkpoint, p.distance, p.x, p.speed,
		p.air_height, p.crash_time, p.nitro_charges, p.nitro_time, cars]


func _initialize() -> void:
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for sc in SCENARIOS:
		var lines := run(sc)
		var f := FileAccess.open(DIR + sc + ".txt", FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		print("wrote ", sc, " (", lines.size() - 1, " frames)")
	quit(0)
