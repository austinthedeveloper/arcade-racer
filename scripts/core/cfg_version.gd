class_name CfgVersion
## Version numbers on the saved .cfg files (settings.cfg, save.cfg, input_profiles.cfg).
## Each file keeps its version under [meta]; a file without one is version 0 (the format
## before versions). Loaders migrate a file up one version at a time, then read it. A file
## newer than the build is read as it is: the loader takes the keys it knows and skips the rest,
## and saving writes into that file (`to_write`), so what the newer build wrote survives.

const SECTION := "meta"
const KEY := "version"


## The file's version: 0 when it has none.
static func of(cfg: ConfigFile) -> int:
	return maxi(0, int(cfg.get_value(SECTION, KEY, 0)))


static func stamp(cfg: ConfigFile, version: int) -> void:
	cfg.set_value(SECTION, KEY, version)


## Brings `cfg` up to `current`: steps[v] turns a version v file into version v + 1 in place.
## Returns the version the file had. A newer file is left alone.
static func migrate(cfg: ConfigFile, current: int, steps: Array[Callable]) -> int:
	var from := of(cfg)
	for v in range(from, current):
		steps[v].call(cfg)
	if from < current:
		stamp(cfg, current)
	return from


## What a save should fill in and write to `path`: the file on disk when it is newer than
## `current` (its other keys, sections and version kept, the known keys overwritten), else
## an empty file stamped `current`. `fresh` always starts empty, for a reset.
static func to_write(path: String, current: int, fresh := false) -> ConfigFile:
	var cfg := ConfigFile.new()
	if not fresh and cfg.load(path) == OK and of(cfg) > current:
		return cfg
	cfg = ConfigFile.new()
	stamp(cfg, current)
	return cfg


# --- Backups (EQ-21) ----------------------------------------------------------------------
# A loader migrates an older file as it reads it; the first save after writes it over in the
# new version. Just before that write, the file as it was is copied to `path`.bak
# (backup_if_older), so nothing is written until something is saved. Options > Game >
# RESTORE BACKUP copies every .bak back over its file and loads them again.

const BACKUP := ".bak"


static func backup_path(path: String) -> String:
	return path + BACKUP


static func has_backup(path: String) -> bool:
	return FileAccess.file_exists(backup_path(path))


## Before a save writes `path` in version `current`: when the file there is older (a save
## from before this version, about to be written over migrated), a copy of it as it is goes to
## `path`.bak. Returns true when it made one.
static func backup_if_older(path: String, current: int) -> bool:
	var disk := ConfigFile.new()
	if not FileAccess.file_exists(path) or disk.load(path) != OK or of(disk) >= current:
		return false
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path(path)))
	if err != OK:
		push_warning("Couldn't back up %s before migrating it (error %d)" % [path, err])
	return err == OK


## Puts `path`.bak back over `path` (copied to a side file first, then renamed over it, so a
## cut-off copy never replaces the file). The backup is kept. Returns true when it did.
static func restore(path: String) -> bool:
	if not has_backup(path):
		return false
	var tmp := ProjectSettings.globalize_path(path + ".restoring")
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path(path)), tmp)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Couldn't restore %s from its backup (error %d)" % [path, err])
	return err == OK
