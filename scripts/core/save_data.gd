extends Node
## Autoload. The player's progress, saved to user://save.cfg: how far the tour has reached,
## unlocks, best time and placing per stage and car, and total points. Kept apart from the
## options (Settings, settings.cfg) and the wheel profiles (InputRouter, input_profiles.cfg),
## so resetting one never touches the others.

signal changed

## The file format. A file with another number still loads: older ones by the rules for
## their version, newer ones as far as the keys this build knows go.
const VERSION := 1

## Where progress is saved. Tests point this at a scratch file.
var path := "user://save.cfg"
## The furthest stage the tour has reached (index into Stages); stage 1 is always open.
var furthest_stage := 0
## Unlock ids. Nothing unlocks yet; this is the storage for it.
var unlocks: Array[String] = []
## Best results, by best_key(stage, car): {"time": seconds, "place": 1 = first}.
var bests := {}
var total_points := 0
## The version of the file last loaded (VERSION when there was none).
var loaded_version := VERSION


func _ready() -> void:
	load_save()


## Back to a fresh save (not written).
func reset() -> void:
	furthest_stage = 0
	unlocks.clear()
	bests.clear()
	total_points = 0
	loaded_version = VERSION


func load_save() -> void:
	reset()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		# Unreadable (a cut-off write, a bad hand edit): kept aside, not overwritten by the
		# next save, so it can be recovered.
		var bad := ProjectSettings.globalize_path(path + ".bad")
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), bad)
		push_warning("Couldn't read %s (error %d); moved it to %s and started fresh" % [path, err, bad])
		return
	loaded_version = int(cfg.get_value("meta", "version", VERSION))
	furthest_stage = clampi(int(cfg.get_value("tour", "furthest_stage", 0)), 0, Stages.count() - 1)
	total_points = maxi(0, int(cfg.get_value("tour", "total_points", 0)))
	var u = cfg.get_value("tour", "unlocks", [])
	if u is Array:
		for id in u:
			if not unlocks.has(str(id)):
				unlocks.append(str(id))
	if cfg.has_section("best"):
		for key in cfg.get_section_keys("best"):
			var b = cfg.get_value("best", key)
			if b is Dictionary and b.has("time"):
				bests[key] = {"time": float(b["time"]), "place": int(b.get("place", 0))}


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("tour", "furthest_stage", furthest_stage)
	cfg.set_value("tour", "total_points", total_points)
	cfg.set_value("tour", "unlocks", Array(unlocks))
	for key in bests:
		cfg.set_value("best", key, bests[key])
	# Written whole to a side file and then renamed over the save, so a crash mid-write
	# never leaves a cut-off save.
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Couldn't save progress to %s (error %d)" % [path, err])
		return
	changed.emit()


static func best_key(stage: int, car_id: String) -> String:
	return "%s/%s" % [Stages.POSTCARDS[stage], car_id]


## The best result for a stage and car, or an empty dictionary.
func best(stage: int, car_id: String) -> Dictionary:
	return bests.get(best_key(stage, car_id), {})


## Records a finished stage: the best time and placing for the stage and car (place 0 is
## "no placing"; lower is better), and the tour reaching the stage after it. Saves when
## anything changed. Returns true for a new best time.
func record_finish(stage: int, car_id: String, time: float, place: int = 0) -> bool:
	var dirty := false
	var key := best_key(stage, car_id)
	var old: Dictionary = bests.get(key, {})
	var new_best := old.is_empty() or time < float(old["time"])
	var best_place := int(old.get("place", 0))
	if place > 0 and (best_place <= 0 or place < best_place):
		best_place = place
		dirty = true
	if new_best or dirty:
		bests[key] = {"time": time if new_best else float(old["time"]), "place": best_place}
		dirty = true
	var next := Stages.next(stage)
	if next > furthest_stage:
		furthest_stage = next
		dirty = true
	if dirty:
		save()
	return new_best


func unlock(id: String) -> void:
	if not unlocks.has(id):
		unlocks.append(id)
		save()


func is_unlocked(id: String) -> bool:
	return unlocks.has(id)
