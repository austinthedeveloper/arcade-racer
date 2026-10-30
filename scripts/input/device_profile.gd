class_name DeviceProfile
extends RefCounted
## Per-joypad mapping and calibration, saved by GUID. Wheels need this because axis numbers,
## ranges and pedal direction vary by brand, driver mode and operating system.

enum Kind { GAMEPAD = 1, WHEEL = 2 }

const SAVED_KEYS := [
	"name", "kind", "calibrated",
	"steer_axis", "steer_left", "steer_center", "steer_right",
	"throttle_axis", "throttle_rest", "throttle_full",
	"brake_axis", "brake_rest", "brake_full", "combined_pedals",
	"nitro_button", "steer_deadzone", "steer_gamma", "hardware_range_deg", "lock_deg",
]

var guid := ""
var name := ""
var kind := Kind.GAMEPAD
var calibrated := false

var steer_axis := 0
var steer_left := -1.0
var steer_center := 0.0
var steer_right := 1.0

var throttle_axis := -1
var throttle_rest := 0.0
var throttle_full := 1.0
var brake_axis := -1
var brake_rest := 0.0
var brake_full := 1.0
var combined_pedals := false  # gas and brake share one axis, moving in opposite directions

var nitro_button := -1

var steer_deadzone := 0.015
var steer_gamma := 1.0
## Full rotation of the wheel hardware, and how much of it the game uses for full lock.
## A 900 degree wheel with a 360 degree lock reaches full steering at 180 degrees each way.
var hardware_range_deg := 900.0
var lock_deg := 360.0


func normalize_steer(raw: float) -> float:
	var d := raw - steer_center
	var to_left := steer_left - steer_center
	var to_right := steer_right - steer_center
	var v := d
	if absf(to_left) > 0.001 and absf(to_right) > 0.001:
		v = -d / to_left if signf(d) == signf(to_left) else d / to_right
	v = clampf(v * hardware_range_deg / maxf(lock_deg, 1.0), -1.0, 1.0)
	var mag := absf(v)
	if mag < steer_deadzone:
		return 0.0
	mag = (mag - steer_deadzone) / (1.0 - steer_deadzone)
	return signf(v) * pow(mag, steer_gamma)


static func pedal(raw: float, rest: float, full: float) -> float:
	if absf(full - rest) < 0.05:
		return 0.0
	var v := clampf((raw - rest) / (full - rest), 0.0, 1.0)
	return 0.0 if v < 0.03 else v


func save_to(cfg: ConfigFile) -> void:
	for key in SAVED_KEYS:
		cfg.set_value(guid, key, get(key))


static func load_from(cfg: ConfigFile, section: String) -> DeviceProfile:
	var p := DeviceProfile.new()
	p.guid = section
	for key in SAVED_KEYS:
		if cfg.has_section_key(section, key):
			p.set(key, cfg.get_value(section, key))
	return p
