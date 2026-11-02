extends Node
## Autoload. The player's progress, saved to user://save.cfg: how far the tour has reached,
## unlocks, best time and placing per stage and car, total points, and the stats page's
## counters (MP-11). Kept apart from the
## options (Settings, settings.cfg) and the wheel profiles (InputRouter, input_profiles.cfg),
## so resetting one never touches the others.
##
## Player profiles (MP-10): up to MAX_PROFILES drivers, each a preset name (NAMES) and an
## avatar (a car's showroom picture, by car id) picked from a list, each with its own save.
## Profile 1's is save.cfg, the others save_2.cfg to save_4.cfg beside it (slot_path); a
## profile is there when its file is (profile 1 always is). The save holds its own name and
## avatar under [profile]; which profile is driving is kept in save_profiles.cfg (roster_path).
## Each profile's Time Attack ghosts go in a folder of its own (ghost_dir).

signal changed

## The save.cfg format (CfgVersion). A file with another number still loads: older ones are
## migrated, newer ones are read as far as the keys this build knows go.
## 0: no version field. 1: the same keys, versioned. 2: stage mirrors (WS-6) in the unlocks.
## 3: [stats] (MP-11). 4: [profile] (MP-10): the save that was there becomes profile 1's.
const VERSION := 4
const MAX_PROFILES := 4
## The names a profile can have (no typing: picked from this list).
const NAMES: Array[String] = ["ACE", "BLAZE", "COMET", "DASH", "ECHO", "FLASH", "JET", "NOVA", "ROCKET",
	"TURBO", "VIPER", "ZOOM"]
## The stats page's counters (MP-11), in [stats]: races run to the end (a finish or TIME UP),
## wins (1st against rivals), crashes, near misses, miles driven (any run, Free Drive and runs
## quit partway too), and races per car id and per stage id (Stages.POSTCARDS) for the
## favourites.
const STAT_COUNTS := ["races", "wins", "crashes", "near_misses"]

## Profile 1's save; the other profiles' files and the roster are named after it. Tests and
## --save-file point it elsewhere (use_base).
var base_path := "user://save.cfg"
## The profile driving (0 is profile 1).
var slot := 0
## Where the driving profile's progress is saved (slot_path of base_path and slot).
var path := "user://save.cfg"
## This profile's name (one of NAMES) and avatar (a car id, Cars.LIST).
var profile_name: String = NAMES[0]
var avatar := "car_vega"
## The furthest stage the tour has reached (index into Stages); stage 1 is always open.
var furthest_stage := 0
## Unlock ids. Nothing unlocks yet; this is the storage for it.
var unlocks: Array[String] = []
## Best results, by best_key(stage, car): {"time": seconds, "place": 1 = first}.
var bests := {}
var total_points := 0
## The stats (MP-11): STAT_COUNTS, "miles", "cars" {id: races}, "stages" {id: races}.
var stats := fresh_stats()
## The version of the file last loaded (VERSION when there was no file).
var loaded_version := VERSION


func _ready() -> void:
	# Dev flag: --save-file=PATH reads (and saves) another save, for screenshots.
	use_base(DevArgs.value("--save-file", base_path))


## Profiles named after `base` (profile 1's save): the driving one from its roster, loaded.
func use_base(base: String) -> void:
	base_path = base
	slot = clampi(int(_roster().get_value("profiles", "active", 0)), 0, MAX_PROFILES - 1)
	if not has_profile(slot):
		slot = 0
	_use_slot()


## The save file of profile `s` (0 is profile 1) for profile 1's `base`.
static func slot_path(base: String, s: int) -> String:
	return base if s == 0 else "%s_%d.%s" % [base.get_basename(), s + 1, base.get_extension()]


## The file that says which profile is driving, beside profile 1's `base`.
static func roster_path(base: String) -> String:
	return "%s_profiles.cfg" % base.get_basename()


## Profile `s`'s Time Attack ghosts (Ghost.dir), beside profile 1's `base`: profile 1's are
## where they always were.
static func ghost_dir(base: String, s: int) -> String:
	return base.get_base_dir().path_join("ghosts" if s == 0 else "ghosts_%d" % (s + 1))


## A profile's default name and avatar, before one is picked: a different name and car for each.
static func default_identity(s: int) -> Dictionary:
	return {"name": NAMES[s % NAMES.size()], "avatar": Cars.get_car(s)["id"]}


## Whether profile `s` exists: profile 1 always does, the others once made (make_profile).
func has_profile(s: int) -> bool:
	return s == 0 or (s > 0 and s < MAX_PROFILES and FileAccess.file_exists(slot_path(base_path, s)))


## Every profile's save file there is, profile 1's first (whether written yet or not).
func profile_paths() -> Array[String]:
	var out: Array[String] = []
	for s in MAX_PROFILES:
		if has_profile(s):
			out.append(slot_path(base_path, s))
	return out


## The profiles, by slot: {"slot", "name", "avatar"} for each that exists.
func profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in MAX_PROFILES:
		if has_profile(s):
			out.append(profile_of(s))
	return out


## Profile `s`'s name and avatar: the loaded ones for the profile driving, else from its file.
func profile_of(s: int) -> Dictionary:
	if s == slot:
		return {"slot": s, "name": profile_name, "avatar": avatar}
	var cfg := ConfigFile.new()
	cfg.load(slot_path(base_path, s))
	var id := _identity(cfg, s)
	id["slot"] = s
	return id


## A name and avatar from a save's [profile], checked against NAMES and Cars.LIST; the
## slot's defaults for anything missing or unknown.
static func _identity(cfg: ConfigFile, s: int) -> Dictionary:
	var out := default_identity(s)
	var n := str(cfg.get_value("profile", "name", out["name"]))
	if NAMES.has(n):
		out["name"] = n
	var a := str(cfg.get_value("profile", "avatar", out["avatar"]))
	if Cars.find(a)["id"] == a:
		out["avatar"] = a
	return out


## The first slot with no profile yet, or -1 when all MAX_PROFILES are taken.
func free_slot() -> int:
	for s in MAX_PROFILES:
		if not has_profile(s):
			return s
	return -1


## The names no other profile than `s` has (a name is one driver's).
func names_free_for(s: int) -> Array[String]:
	var taken: Array[String] = []
	for p in profiles():
		if p["slot"] != s:
			taken.append(p["name"])
	var out: Array[String] = []
	for n in NAMES:
		if not taken.has(n):
			out.append(n)
	return out


## Makes a new profile with this name and avatar (a fresh save written to its own file) in
## slot `at` (-1: the first free one) and returns its slot, or -1 when that slot is taken or
## there is no room. The profile driving stays as it is.
func make_profile(new_name: String, new_avatar: String, at := -1) -> int:
	var s := free_slot() if at < 0 else at
	if s < 0 or s >= MAX_PROFILES or has_profile(s):
		return -1
	var cfg := ConfigFile.new()
	CfgVersion.stamp(cfg, VERSION)
	cfg.set_value("profile", "name", new_name)
	cfg.set_value("profile", "avatar", new_avatar)
	cfg.set_value("tour", "furthest_stage", 0)
	if cfg.save(slot_path(base_path, s)) != OK:
		push_error("Couldn't make a profile at %s" % slot_path(base_path, s))
		return -1
	return s


## Renames profile `s` and changes its avatar, saved to its file.
func set_identity(s: int, new_name: String, new_avatar: String) -> void:
	if s == slot:
		profile_name = new_name
		avatar = new_avatar
		save()
		return
	if not has_profile(s):
		return
	var p := slot_path(base_path, s)
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return
	cfg.set_value("profile", "name", new_name)
	cfg.set_value("profile", "avatar", new_avatar)
	cfg.save(p)


## Profile `s` drives from now on: its save loaded, remembered for the next start.
func switch_to(s: int) -> void:
	if not has_profile(s):
		return
	slot = s
	var roster := _roster()
	CfgVersion.stamp(roster, 1)
	roster.set_value("profiles", "active", s)
	roster.save(roster_path(base_path))
	_use_slot()


func _roster() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(roster_path(base_path))
	return cfg


func _use_slot() -> void:
	path = slot_path(base_path, slot)
	Ghost.dir = ghost_dir(base_path, slot)
	load_save()
	changed.emit()


## Back to a fresh save (not written).
func reset() -> void:
	furthest_stage = 0
	unlocks.clear()
	bests.clear()
	total_points = 0
	stats = fresh_stats()
	loaded_version = VERSION


static func fresh_stats() -> Dictionary:
	return {"races": 0, "wins": 0, "crashes": 0, "near_misses": 0, "miles": 0.0, "cars": {}, "stages": {}}


func load_save() -> void:
	reset()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	var who := _identity(cfg, slot)  # (a missing or broken file: the slot's defaults)
	profile_name = who["name"]
	avatar = who["avatar"]
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		# Unreadable (a cut-off write, a bad hand edit): kept aside, not overwritten by the
		# next save, so it can be recovered.
		var bad := ProjectSettings.globalize_path(path + ".bad")
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), bad)
		push_warning("Couldn't read %s (error %d); moved it to %s and started fresh" % [path, err, bad])
		return
	loaded_version = migrate(cfg)
	who = _identity(cfg, slot)
	profile_name = who["name"]
	avatar = who["avatar"]
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
	for k: String in STAT_COUNTS:
		stats[k] = maxi(0, int(cfg.get_value("stats", k, 0)))
	stats["miles"] = maxf(0.0, float(cfg.get_value("stats", "miles", 0.0)))
	for k in ["cars", "stages"]:
		var d = cfg.get_value("stats", k, {})
		if d is Dictionary:
			for id in d:
				stats[k][str(id)] = maxi(0, int(d[id]))


## Brings a loaded save.cfg up to VERSION; returns the version it had.
static func migrate(cfg: ConfigFile) -> int:
	return CfgVersion.migrate(cfg, VERSION, [_v0_to_v1, _v1_to_v2, _v2_to_v3, _v3_to_v4])


## Version 1 only added the version field: the keys are as they were.
static func _v0_to_v1(_cfg: ConfigFile) -> void:
	pass


## Version 2 opens a stage's mirror on a win (Unlocks.mirror_id): a stage already won (a best
## placing of 1st, with any car) gets its mirror.
static func _v1_to_v2(cfg: ConfigFile) -> void:
	var u = cfg.get_value("tour", "unlocks", [])
	var unlocked: Array = u if u is Array else []
	if cfg.has_section("best"):
		for key: String in cfg.get_section_keys("best"):
			var b = cfg.get_value("best", key)
			var stage := Stages.POSTCARDS.find(key.get_slice("/", 0))
			if stage >= 0 and b is Dictionary and int(b.get("place", 0)) == 1 and not unlocked.has(Unlocks.mirror_id(stage)):
				unlocked.append(Unlocks.mirror_id(stage))
	cfg.set_value("tour", "unlocks", unlocked)


## Version 3 adds [stats] (MP-11). Every best time on file was a race run to the line, so
## they seed the races, the wins (a best placing of 1st) and the races per car and stage;
## crashes, near misses and miles weren't kept, so start at 0.
static func _v2_to_v3(cfg: ConfigFile) -> void:
	var races := 0
	var wins := 0
	var cars := {}
	var stages := {}
	if cfg.has_section("best"):
		for key: String in cfg.get_section_keys("best"):
			var b = cfg.get_value("best", key)
			if not b is Dictionary:
				continue
			races += 1
			wins += int(int(b.get("place", 0)) == 1)
			var stage := key.get_slice("/", 0)
			var car := key.get_slice("/", 1)
			cars[car] = int(cars.get(car, 0)) + 1
			stages[stage] = int(stages.get(stage, 0)) + 1
	for k: String in STAT_COUNTS:
		cfg.set_value("stats", k, 0)
	cfg.set_value("stats", "races", races)
	cfg.set_value("stats", "wins", wins)
	cfg.set_value("stats", "miles", 0.0)
	cfg.set_value("stats", "cars", cars)
	cfg.set_value("stats", "stages", stages)


## Version 4 adds player profiles (MP-10): the save there was is profile 1's, given
## profile 1's default name and avatar (one already set is kept).
static func _v3_to_v4(cfg: ConfigFile) -> void:
	var id := default_identity(0)
	if not cfg.has_section_key("profile", "name"):
		cfg.set_value("profile", "name", id["name"])
	if not cfg.has_section_key("profile", "avatar"):
		cfg.set_value("profile", "avatar", id["avatar"])


## Writes the save. Over a file from a newer build, its other keys are kept (CfgVersion.to_write);
## `fresh` (resetting the save) writes only this build's keys.
func save(fresh := false) -> void:
	var cfg := CfgVersion.to_write(path, VERSION, fresh)
	cfg.set_value("profile", "name", profile_name)
	cfg.set_value("profile", "avatar", avatar)
	cfg.set_value("tour", "furthest_stage", furthest_stage)
	cfg.set_value("tour", "total_points", total_points)
	cfg.set_value("tour", "unlocks", Array(unlocks))
	for key in bests:
		var b = cfg.get_value("best", key, {})
		var entry: Dictionary = b.duplicate() if b is Dictionary else {}
		entry.merge(bests[key], true)
		cfg.set_value("best", key, entry)
	for k: String in stats:
		cfg.set_value("stats", k, stats[k])
	# Written whole to a side file and then renamed over the save, so a crash mid-write
	# never leaves a cut-off save.
	CfgVersion.backup_if_older(path, VERSION)  # (EQ-21)
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


## The best time on a stage with any car (mirrored or not: they share bests), INF for none.
func stage_best(stage: int) -> float:
	var out := INF
	var prefix: String = Stages.POSTCARDS[stage] + "/"
	for key: String in bests:
		if key.begins_with(prefix):
			out = minf(out, float(bests[key]["time"]))
	return out


## Records a finished stage: the best time and placing for the stage and car (place 0 is
## "no placing"; lower is better), and with `reach_next` the tour reaching the stage after it
## (a Time Attack run or a Single Race opens nothing). Saves when anything changed. Returns
## true for a new best time.
func record_finish(stage: int, car_id: String, time: float, place: int = 0, reach_next := true) -> bool:
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
	var next := Stages.next(stage) if reach_next else -1
	if next > furthest_stage:
		furthest_stage = next
		dirty = true
	if dirty:
		save()
	return new_best


## Adds a run to the stats (MP-11) and saves: `counted` for a race run to the end (a finish
## or TIME UP; a run quit partway or Free Drive adds only its miles, crashes and near misses),
## `won` for 1st against rivals.
func record_run(stage: int, car_id: String, counted: bool, won: bool, crashes: int, near_misses: int, miles: float) -> void:
	stats["crashes"] += maxi(0, crashes)
	stats["near_misses"] += maxi(0, near_misses)
	stats["miles"] += maxf(0.0, miles)
	if counted:
		stats["races"] += 1
		stats["wins"] += int(won)
		var stage_id: String = Stages.POSTCARDS[stage]
		stats["cars"][car_id] = int(stats["cars"].get(car_id, 0)) + 1
		stats["stages"][stage_id] = int(stats["stages"].get(stage_id, 0)) + 1
	save()


## The car raced most (a car id), "" before any race. A tie goes to the car first in the garage.
func favourite_car() -> String:
	var best := ""
	var most := 0
	for car: Dictionary in Cars.LIST:
		var n := int(stats["cars"].get(car["id"], 0))
		if n > most:
			most = n
			best = car["id"]
	return best


## The stage raced most (index into Stages), -1 before any race. A tie goes to the earlier stage.
func favourite_stage() -> int:
	var best := -1
	var most := 0
	for i in Stages.count():
		var n := int(stats["stages"].get(Stages.POSTCARDS[i], 0))
		if n > most:
			most = n
			best = i
	return best


func unlock(id: String) -> void:
	if not unlocks.has(id):
		unlocks.append(id)
		save()


func is_unlocked(id: String) -> bool:
	return unlocks.has(id)
