class_name PlaytestLog
extends RefCounted
## The playtest log (EQ-25): with Options > Display > PLAYTEST LOG on (off by default), each race
## writes one JSON file into the playtest folder beside the crash log (CrashLog, EQ-20): the
## stage, car and mode, how it ended, when each checkpoint was passed, every crash (time and
## place on the route), and per STRETCH of the route the seconds spent and the time lost
## against top speed. tools/playtest_report.py turns a folder of them into a per-stage chart
## of where players crash and slow down. Nothing leaves the machine: the files stay in the
## log folder until the player deletes them.
##
## The race feeds it (tick, checkpoint) and ends it (finish); everything here is plain
## functions of what it's given, so a test can drive it without a race.

const FOLDER := "playtest"
const FORMAT := 1
## World units per stretch: 100 segments, about two seconds at top speed.
const STRETCH := 100 * Cfg.SEGMENT_LENGTH

var stage := ""  # Stages.POSTCARDS id
var car := ""
var mode := ""  # "tour", "single", "time_attack", "free_drive", "online"
var mirror := false
var length := 0.0  # the route's length to the finish line, world units
var started := ""  # the date and time it started, from the system clock
var checkpoints: Array[Dictionary] = []  # {"index" from 1, "time"}
var crashes: Array[Dictionary] = []  # {"time", "distance", "segment"}
## By stretch index (distance / STRETCH): [seconds spent in it, world units covered in it].
var stretches := {}
var time := 0.0  # race seconds so far
var result := ""  # set by finish: "finish", "time_up" or "quit"


func _init(stage_id := "", car_id := "", race_mode := "", mirrored := false, route_length := 0.0) -> void:
	stage = stage_id
	car = car_id
	mode = race_mode
	mirror = mirrored
	length = route_length
	started = Time.get_datetime_string_from_system()


## Where tests point the logs instead ("" for the crash log's folder).
static var dir_override := ""


## The folder the logs go in: the crash log's (--log-dir moves both), its playtest folder.
static func folder() -> String:
	if dir_override != "":
		return dir_override
	var base := CrashLog.installed.dir if CrashLog.installed != null else CrashLog.DIR
	return base.path_join(FOLDER)


## One racing tick: `dt` seconds with the car at route distance `distance`, having moved
## `moved` world units; `crashed` when a crash started this tick (PlayerCar.crashed).
func tick(dt: float, distance: float, moved: float, crashed: bool) -> void:
	time += dt
	var i := maxi(0, floori(distance / STRETCH))
	var s: Array = stretches.get(i, [0.0, 0.0])
	s[0] += dt
	s[1] += maxf(0.0, moved)
	stretches[i] = s
	if crashed:
		crashes.append({"time": snappedf(time, 0.01), "distance": roundf(distance),
			"segment": floori(distance / Cfg.SEGMENT_LENGTH)})


## Checkpoint `index` (from 1) passed now.
func checkpoint(index: int) -> void:
	checkpoints.append({"index": index, "time": snappedf(time, 0.01)})


## Seconds lost in a stretch: those spent over what top speed would have taken for the ground
## covered (never below 0).
static func lost(seconds: float, covered: float) -> float:
	return maxf(0.0, seconds - covered / Cfg.MAX_SPEED)


## The log as written: a Dictionary of plain values (JSON).
func to_dict() -> Dictionary:
	var rows: Array = []
	var keys := stretches.keys()
	keys.sort()
	for i: int in keys:
		var s: Array = stretches[i]
		rows.append({"index": i, "from": i * STRETCH, "seconds": snappedf(s[0], 0.01),
			"lost": snappedf(lost(s[0], s[1]), 0.01)})
	return {"format": FORMAT, "version": Updater.version(), "started": started, "stage": stage, "car": car,
		"mode": mode, "mirror": mirror, "result": result, "time": snappedf(time, 0.01), "length": length,
		"stretch_length": STRETCH, "checkpoints": checkpoints, "crashes": crashes, "stretches": rows}


## The race is over (`how`: "finish", "time_up" or "quit"): writes the file into `dir` and
## returns its path ("" when it couldn't, or when the car never got going).
func finish(how: String, dir := folder()) -> String:
	result = how
	if time <= 0.0:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := started.replace(":", "").replace("-", "").replace("T", "_")
	var path := dir.path_join("race_%s_%s_%d.json" % [stamp, stage, Time.get_ticks_msec() % 100000])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't write the playtest log %s" % path)
		return ""
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return path
