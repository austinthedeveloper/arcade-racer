## The save compatibility fixtures (EQ-27): the save, settings and wheel profile files a
## release writes, in tests/fixtures/saves/v<version>/. test_save_compat loads every folder in
## the current build. A release adds its own folder as it is cut (docs/10-releases.md):
##
##   godot --headless --path . -s res://tests/save_fixture.gd [-- --version=0.6.0 --out=DIR]
##
## The files are written by this build's own save functions (Settings.save, SaveData.save and
## make_profile, InputRouter's profile write) from the values below, so they are exactly what
## the release writes. Two drivers (MP-10), the second one driving. The folders for v0.1.0 to
## v0.5.2 were recreated from each tag's save code with the same values.
class_name SaveFixture
extends SceneTree

const DIR := "res://tests/fixtures/saves/"

## [section, key, Settings property, value]: none of them the default, each in range.
const SETTINGS := [
	["play", "auto_gas", "auto_gas", true], ["play", "traffic", "traffic", 0], ["play", "timer", "timer", 2],
	["play", "power_ups", "power_ups", false], ["play", "difficulty", "difficulty", 2],
	["play", "carry_time", "carry_time", true], ["play", "steer_assist", "steer_assist", true],
	["play", "brake_assist", "brake_assist", true], ["play", "co_pilot", "co_pilot", true],
	["play", "manual_gears", "manual_gears", true], ["controls", "key_steer_in", "key_steer_in", 1],
	["controls", "key_steer_out", "key_steer_out", 5], ["controls", "rumble", "rumble", 6],
	["play", "unlock_all", "unlock_all", true], ["play", "attack_traffic", "attack_traffic", true],
	["audio", "music", "music_volume", 3], ["audio", "sfx", "sfx_volume", 7], ["audio", "radio", "radio", 2],
	["accessibility", "screen_shake", "screen_shake", 3], ["accessibility", "flash", "flash", 0],
	["accessibility", "subtitles", "subtitles", false], ["accessibility", "reduce_motion", "reduce_motion", true],
	["display", "units", "units", 1], ["display", "camera_view", "camera_view", 2],
	["display", "fullscreen", "fullscreen", true], ["display", "integer_scale", "integer_scale", true],
	["display", "vsync", "vsync", false], ["display", "scanlines", "scanlines", true],
]
## Profile 1's progress (the second driver's is the same with DRIVER_2's name and stage).
const UNLOCKS := ["car_hauler", "mirror_palm_coast"]
const BESTS := {
	"palm_coast/car_vega": {"place": 1, "time": 71.5},
	"neon/car_mesa": {"place": 0, "time": 88.25},
	"redrock/car_sol": {"place": 2, "time": 80.125},
}
const STATS := {"races": 14, "wins": 5, "crashes": 9, "near_misses": 31, "miles": 52.5,
	"cars": {"car_mesa": 4, "car_vega": 10}, "stages": {"neon": 6, "palm_coast": 8}}
const DRIVER_1 := {"name": "NOVA", "avatar": "car_mesa", "furthest_stage": 3, "total_points": 250}
const DRIVER_2 := {"name": "JET", "avatar": "car_halo", "furthest_stage": 1, "total_points": 40}
const WHEEL_GUID := "030000006d04000018c2000000000000"
const PAD_GUID := "03000000de280000ff11000000000000"
const WHEEL := {"name": "Test Wheel", "kind": DeviceProfile.Kind.WHEEL, "calibrated": true, "steer_axis": 0,
	"steer_left": -0.9, "steer_center": 0.02, "steer_right": 0.95, "throttle_axis": 2, "throttle_rest": 1.0,
	"throttle_full": -1.0, "brake_axis": 3, "brake_rest": 1.0, "brake_full": -1.0, "nitro_button": 4,
	"steer_deadzone": 0.03, "steer_gamma": 1.2, "lock_deg": 540.0}
const PAD := {"name": "Test Pad", "kind": DeviceProfile.Kind.GAMEPAD, "bindings": {"nitro": 2, "view": -1}}
const KEYBOARD_BINDINGS := {"nitro": 78}


## The release folders there are, oldest first ("v0.1.0", ...).
static func versions() -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(DIR):
		if d.begins_with("v"):
			out.append(d)
	out.sort_custom(func(a: String, b: String) -> bool: return BootTree.compare(a.substr(1), b.substr(1)) < 0)
	return out


func _initialize() -> void:
	_write.call_deferred()


func _write() -> void:
	var version := DevArgs.value("--version", str(ProjectSettings.get_setting("application/config/version")))
	var out := DevArgs.value("--out", DIR + "v" + version)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	write_all(out)
	print("wrote ", out)
	quit()


## Writes the three files (and the second driver's save and the roster) into `out`, then points
## the autoloads back at the player's own files, unchanged.
static func write_all(out: String) -> void:
	var settings_path: String = Settings.path
	var save_base: String = SaveData.base_path
	var profile_path: String = InputRouter.profile_path
	var settings: Node = Settings
	settings.path = out.path_join("settings.cfg")
	settings.reset()
	for row in SETTINGS:
		settings.set(row[2], row[3])
	settings.whats_new_seen = out.get_file().trim_prefix("v")
	settings.save(true)

	SaveData.use_base(out.path_join("save.cfg"))
	_fill_save(DRIVER_1)
	var s := SaveData.make_profile(DRIVER_2["name"], DRIVER_2["avatar"], 1)
	SaveData.switch_to(s)
	_fill_save(DRIVER_2)

	InputRouter.profile_path = out.path_join("input_profiles.cfg")
	InputRouter._saved.clear()
	var wheel := DeviceProfile.new()
	wheel.guid = WHEEL_GUID
	var pad := DeviceProfile.new()
	pad.guid = PAD_GUID
	for k in WHEEL:
		wheel.set(k, WHEEL[k])
	for k in PAD:
		pad.set(k, PAD[k])
	InputRouter._saved[WHEEL_GUID] = wheel
	InputRouter._saved[PAD_GUID] = pad
	InputRouter.keyboard.bindings = KEYBOARD_BINDINGS.duplicate()
	InputRouter._write_profiles()

	settings.path = settings_path
	settings.load_settings()
	SaveData.use_base(save_base)
	InputRouter.profile_path = profile_path
	InputRouter.load_profiles()


static func _fill_save(who: Dictionary) -> void:
	SaveData.reset()
	SaveData.profile_name = who["name"]
	SaveData.avatar = who["avatar"]
	SaveData.furthest_stage = who["furthest_stage"]
	SaveData.total_points = who["total_points"]
	SaveData.unlocks.assign(UNLOCKS)
	SaveData.bests = BESTS.duplicate(true)
	SaveData.stats = STATS.duplicate(true)
	SaveData.save(true)
