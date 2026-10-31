class_name CfgVersion
## Version numbers on the saved .cfg files (settings.cfg, save.cfg, input_profiles.cfg).
## Each file keeps its version under [meta]; a file without one is version 0 (the format
## before versions). Loaders migrate a file up one version at a time, then read it. A file
## newer than the build is read as it is: the loader takes the keys it knows and skips the rest.

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
