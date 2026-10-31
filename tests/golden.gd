## Golden traces: per-frame hashes of the race state over scripted autodriven runs.
## Any change to play changes a hash; display-only work never does.
##
## Regenerate (only for an intended change to play, with a reason in the
## commit): godot --headless --path . -s res://tests/golden.gd
class_name Golden
extends SceneTree

const DIR := "res://tests/golden/"
const SCENARIOS := ["autodrive_traffic", "autodrive_clear_road", "redrock_autodrive_traffic",
	"neon_autodrive_traffic", "timberline_autodrive_traffic", "bayou_autodrive_traffic",
	"harvest_autodrive_traffic", "thunder_autodrive_traffic", "skyline_autodrive_traffic"]
const FRAMES := 7500  # the countdown plus the longest the clock allows (45 s + 3 checkpoint bonuses)


## The stage a scenario runs on: its name starts with the stage's id (Stages.POSTCARDS) and
## an underscore; no prefix is Palm Coast.
static func stage_of(scenario: String) -> int:
	for i in range(1, Stages.count()):
		if scenario.begins_with(Stages.POSTCARDS[i] + "_"):
			return i
	return 0


## Frame hashes for a scenario: [frames..., final snapshot string].
static func run(scenario: String, frames: int = FRAMES) -> PackedStringArray:
	var busy := scenario.ends_with("_traffic")  # traffic and rivals; the clear road has neither
	var r := TestSuite.new_race(true, busy, stage_of(scenario), busy)
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
	var lanes := 0.0
	var flung := 0
	for c in r.traffic.cars:
		cars += c.z
		lanes += c.offset
		flung += int(c.flung > 0.0)
	var rival_z := 0.0
	var rival_x := 0.0
	var rival_crashes := 0
	for rv: RivalCar in r.rivals.cars:
		rival_z += rv.distance
		rival_x += rv.x
		rival_crashes += int(rv.crash_time > 0.0)
	# Rival columns only with rivals, so a race without them keeps its trace
	var rival_cols := "" if r.rivals.cars.is_empty() else " rivals=%.1f rx=%.3f rcrash=%d rdone=%d" % [
		rival_z, rival_x, rival_crashes, r.rivals.finished_count()]
	var taken := ""
	for pu: PowerUps.Pickup in r.power_ups.pickups:
		taken += str(pu.kind) if pu.taken else "-"
	return ("state=%d t=%.2f left=%.2f cp=%d z=%.1f x=%.3f v=%.1f air=%.1f crash=%.2f nitro=%d/%.2f cars=%.0f"
		+ " lanes=%.2f flung=%d ram=%.2f ghost=%.2f taken=%s%s") % [
		r.state, r.race_time, r.time_left, r.next_checkpoint, p.distance, p.x, p.speed,
		p.air_height, p.crash_time, p.nitro_charges, p.nitro_time, cars, lanes, flung, p.ram_time,
		p.ghost_time, taken, rival_cols]


func _initialize() -> void:
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	TestSuite.use_scratch_settings(root.get_node("Settings"))
	TestSuite.use_scratch_save(root.get_node("SaveData"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for sc in SCENARIOS:
		var lines := run(sc)
		var f := FileAccess.open(DIR + sc + ".txt", FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		print("wrote ", sc, " (", lines.size() - 1, " frames)")
	quit(0)
