class_name BootTree
extends SceneTree
## The game's main loop (project.godot `run/main_loop_type`, EQ-14). Its `_init` runs before
## the engine loads anything else, even the autoloads, so when the Updater has downloaded a
## newer release's .pck it is loaded here over the built-in game, and everything after
## (autoloads, scenes, scripts, art) comes from the update.
##
## An update can change anything but this file and project.godot's settings (only the
## version, which this sets). Keep it small and never use a game script here.
##
## A start on an update is marked `booting` until the title clears it (Updater.mark_good),
## so an update that never reaches the title is skipped the next time.

const CURRENT := "user://updates/current.json"  # {version, engine, file, booting}


func _init() -> void:
	if not OS.has_feature("template") or OS.has_feature("web"):
		return  # a checkout or the Web build: always the game as it is
	var c := read_current(CURRENT)
	var pack := choose(c, str(ProjectSettings.get_setting("application/config/version", "0")), engine())
	if pack == "" or not FileAccess.file_exists(pack):
		return
	c["booting"] = true
	write_current(CURRENT, c)
	if ProjectSettings.load_resource_pack(pack, true):
		ProjectSettings.set_setting("application/config/version", str(c["version"]))


## The pack to load, or "": the update's, when it's newer than the built-in game
## (`built_in`), for this engine (`eng`), and its last start reached the title.
static func choose(c: Dictionary, built_in: String, eng: String) -> String:
	if c.is_empty() or str(c.get("engine", "")) != eng or bool(c.get("booting", false)):
		return ""
	if compare(str(c.get("version", "0")), built_in) <= 0:
		return ""  # a newer full download wins
	return str(c.get("file", ""))


## -1, 0 or 1 as version `a` is older than, the same as or newer than `b` ("0.10.0" is
## newer than "0.9.3"; a leading "v" is ignored).
static func compare(a: String, b: String) -> int:
	var x := a.trim_prefix("v").split(".")
	var y := b.trim_prefix("v").split(".")
	for i in maxi(x.size(), y.size()):
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return 1 if p > q else -1
	return 0


## This engine's MAJOR.MINOR.PATCH: a pack runs only on the engine it was exported with.
static func engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


static func read_current(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


static func write_current(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
