class_name DeviceProfile
extends RefCounted
## Per-joypad mapping and calibration, saved by GUID. Wheels need this because axis numbers,
## ranges and pedal direction vary by brand, driver mode and operating system.
## Every device also has button bindings for the remappable actions (REMAP_ACTIONS); the
## keyboard's are a profile too, saved under KEYBOARD_GUID.

enum Kind { KEYBOARD = 0, GAMEPAD = 1, WHEEL = 2 }

## The section the keyboard's bindings are saved under in input_profiles.cfg.
const KEYBOARD_GUID := "keyboard"
## The actions the player can rebind on every device (RemapScreen), in screen order.
## shift_up, shift_down and view have no effect in play yet; horn only sounds (RaceAudio).
const REMAP_ACTIONS := ["nitro", "shift_up", "shift_down", "horn", "pause", "view"]
const ACTION_NAMES := {"nitro": "NITRO", "shift_up": "SHIFT UP", "shift_down": "SHIFT DOWN", "horn": "HORN",
	"pause": "PAUSE", "view": "VIEW"}
## Default bindings: physical keycodes on the keyboard, joypad buttons on a pad. A wheel's
## buttons differ by model, so only its nitro has one (from calibration, nitro_button).
const KEYBOARD_DEFAULTS := {
	"nitro": [KEY_SPACE, KEY_SHIFT], "shift_up": [KEY_E], "shift_down": [KEY_Q], "horn": [KEY_H],
	"pause": [KEY_ESCAPE, KEY_P], "view": [KEY_V],
}
const PAD_DEFAULTS := {
	"nitro": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y], "shift_up": [], "shift_down": [JOY_BUTTON_LEFT_SHOULDER],
	"horn": [JOY_BUTTON_LEFT_STICK], "pause": [JOY_BUTTON_START], "view": [JOY_BUTTON_RIGHT_STICK],
}
## The keyboard's fixed actions (InputRouter registers them), which a binding can clash with:
## input action -> keys, and the name a clash shows.
const KEYBOARD_FIXED := {
	"steer_left": [KEY_LEFT, KEY_A], "steer_right": [KEY_RIGHT, KEY_D], "accelerate": [KEY_UP, KEY_W],
	"brake": [KEY_DOWN, KEY_S], "restart": [KEY_R], "confirm": [KEY_ENTER, KEY_KP_ENTER], "back": [KEY_BACKSPACE],
	"debug_input": [KEY_F1], "calibrate": [KEY_F2],
}
const FIXED_NAMES := {
	"steer_left": "STEER LEFT", "steer_right": "STEER RIGHT", "accelerate": "GAS", "brake": "BRAKE",
	"restart": "RESTART", "confirm": "SELECT", "back": "BACK", "debug_input": "INPUT DEBUG", "calibrate": "CALIBRATE",
}
## A pad's buttons with a fixed job (InputRouter._read_pad): name -> buttons.
const PAD_FIXED := {
	"GAS": [JOY_BUTTON_A], "BRAKE": [JOY_BUTTON_B, JOY_BUTTON_X], "RESTART": [JOY_BUTTON_BACK],
	"STEER": [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT], "MENU": [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN],
}
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_GUIDE: "GUIDE", JOY_BUTTON_START: "START", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-PAD UP",
	JOY_BUTTON_DPAD_DOWN: "D-PAD DOWN", JOY_BUTTON_DPAD_LEFT: "D-PAD LEFT", JOY_BUTTON_DPAD_RIGHT: "D-PAD RIGHT",
}
const UNBOUND := -1
## The steering settings (WheelScreen): their defaults, and the steps the screen moves by.
## RANGE_STEPS are common wheels' rotations, lock to lock; the lock moves in LOCK_STEP
## degrees up to the range.
const STEERING_KEYS := ["hardware_range_deg", "lock_deg", "steer_deadzone", "steer_gamma"]
const STEERING_DEFAULTS := {"hardware_range_deg": 900.0, "lock_deg": 360.0, "steer_deadzone": 0.015, "steer_gamma": 1.0}
const RANGE_STEPS := [180.0, 270.0, 360.0, 450.0, 540.0, 720.0, 900.0, 1080.0, 1440.0, 1800.0, 2520.0]
const LOCK_MIN := 90.0
const LOCK_STEP := 30.0
const DEADZONE_MAX := 0.2
const DEADZONE_STEP := 0.01
const GAMMA_MIN := 0.5
const GAMMA_MAX := 3.0
const GAMMA_STEP := 0.1

const SAVED_KEYS := [
	"name", "kind", "calibrated",
	"steer_axis", "steer_left", "steer_center", "steer_right",
	"throttle_axis", "throttle_rest", "throttle_full",
	"brake_axis", "brake_rest", "brake_full", "combined_pedals",
	"nitro_button", "steer_deadzone", "steer_gamma", "hardware_range_deg", "lock_deg", "bindings",
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
var steer_gamma := 1.0  # linearity: 1 is linear, more is gentler near center
## Full rotation of the wheel hardware, and how much of it the game uses for full lock.
## A 900 degree wheel with a 360 degree lock reaches full steering at 180 degrees each way.
var hardware_range_deg := 900.0
var lock_deg := 360.0
## The player's rebinds: action -> one key or button (UNBOUND for none). An action not in
## here uses its default (default_binding).
var bindings := {}


func normalize_steer(raw: float) -> float:
	return shape_steer(wheel_turn(raw))


## How far a raw steering axis has the wheel turned: -1 and 1 at the hardware's ends.
func wheel_turn(raw: float) -> float:
	var d := raw - steer_center
	var to_left := steer_left - steer_center
	var to_right := steer_right - steer_center
	var v := d
	if absf(to_left) > 0.001 and absf(to_right) > 0.001:
		v = -d / to_left if signf(d) == signf(to_left) else d / to_right
	return v


## The steering for the wheel `deg` degrees from center (minus is left).
func steer_at(deg: float) -> float:
	return shape_steer(deg / maxf(hardware_range_deg / 2.0, 1.0))


## Steering from a wheel turn (wheel_turn): the lock, then the deadzone and linearity.
func shape_steer(turn: float) -> float:
	var v := clampf(turn * hardware_range_deg / maxf(lock_deg, 1.0), -1.0, 1.0)
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


# --- Steering settings (WheelScreen) --------------------------------------------

## The hardware range one step up or down RANGE_STEPS (wrapping round, or stopping at the
## ends). A range between steps goes to the next one that way. The lock stays inside it.
func step_range(dir: int, wrap: bool) -> void:
	var i := -1
	if dir > 0:
		i = RANGE_STEPS.size()
		for k in RANGE_STEPS.size():
			if RANGE_STEPS[k] > hardware_range_deg + 0.5:
				i = k
				break
		if i == RANGE_STEPS.size():
			i = 0 if wrap else i - 1
	else:
		for k in RANGE_STEPS.size():
			if RANGE_STEPS[k] < hardware_range_deg - 0.5:
				i = k
		if i < 0:
			i = RANGE_STEPS.size() - 1 if wrap else 0
	hardware_range_deg = RANGE_STEPS[i]
	lock_deg = minf(lock_deg, hardware_range_deg)


func step_lock(dir: int, wrap: bool) -> void:
	lock_deg = _stepped(lock_deg, dir, LOCK_STEP, LOCK_MIN, hardware_range_deg, wrap)


func step_deadzone(dir: int, wrap: bool) -> void:
	steer_deadzone = _stepped(steer_deadzone, dir, DEADZONE_STEP, 0.0, DEADZONE_MAX, wrap)


func step_gamma(dir: int, wrap: bool) -> void:
	steer_gamma = _stepped(steer_gamma, dir, GAMMA_STEP, GAMMA_MIN, GAMMA_MAX, wrap)


## Range, lock, deadzone and linearity back to their defaults.
func reset_steering() -> void:
	for key: String in STEERING_KEYS:
		set(key, STEERING_DEFAULTS[key])


## Takes `other`'s range, lock, deadzone and linearity (a recalibration keeps them).
func copy_steering(other: DeviceProfile) -> void:
	for key: String in STEERING_KEYS:
		set(key, other.get(key))


## `v` moved by `dir` to the next multiple of `step` inside lo..hi. A value off the grid (a
## default, or an older file's) goes to the nearest multiple that way.
static func _stepped(v: float, dir: int, step: float, lo: float, hi: float, wrap: bool) -> float:
	var n := floori(v / step + 0.001) + 1 if dir > 0 else ceili(v / step - 0.001) - 1
	var lo_n := ceili(lo / step - 0.001)
	var hi_n := floori(hi / step + 0.001)
	if wrap and n > hi_n:
		n = lo_n
	elif wrap and n < lo_n:
		n = hi_n
	return snappedf(clampi(n, lo_n, hi_n) * step, 0.0001)


# --- Bindings (RemapScreen) -------------------------------------------------------

## The keyboard's profile: bindings only.
static func keyboard() -> DeviceProfile:
	var p := DeviceProfile.new()
	p.guid = KEYBOARD_GUID
	p.name = "Keyboard"
	p.kind = Kind.KEYBOARD
	return p


## What `action` is bound to before any rebind.
func default_binding(action: String) -> Array:
	match kind:
		Kind.KEYBOARD:
			return KEYBOARD_DEFAULTS.get(action, []).duplicate()
		Kind.WHEEL:
			return [nitro_button] if action == "nitro" and nitro_button >= 0 else []
	return PAD_DEFAULTS.get(action, []).duplicate()


## The keys (keyboard) or buttons (joypads) that do `action` on this device.
func binding(action: String) -> Array:
	if not bindings.has(action):
		return default_binding(action)
	var code := int(bindings[action])
	return [] if code == UNBOUND else [code]


## Binds `action` to one key or button (UNBOUND for none), in place of what it had.
func bind(action: String, code: int) -> void:
	bindings[action] = code
	if action == "nitro" and kind == Kind.WHEEL:
		nitro_button = code  # what calibration set; kept in step


## Every binding back to its default.
func reset_bindings() -> void:
	bindings.clear()


## True while one of `action`'s buttons on joypad `device` is held.
func pressed(action: String, device: int) -> bool:
	for b in binding(action):
		if Input.is_joy_button_pressed(device, b):
			return true
	return false


## What else uses one of `action`'s keys or buttons: other actions (by ACTION_NAMES) and
## fixed controls (KEYBOARD_FIXED, PAD_FIXED). Empty when it's clear.
func conflicts(action: String) -> Array[String]:
	var out: Array[String] = []
	var mine := binding(action)
	if mine.is_empty():
		return out
	for other: String in REMAP_ACTIONS:
		if other != action and _shares(mine, binding(other)):
			out.append(ACTION_NAMES[other])
	if kind == Kind.KEYBOARD:
		for job: String in KEYBOARD_FIXED:
			if _shares(mine, KEYBOARD_FIXED[job]):
				out.append(FIXED_NAMES[job])
	elif kind == Kind.GAMEPAD:
		for job: String in PAD_FIXED:
			if _shares(mine, PAD_FIXED[job]):
				out.append(job)
	return out


static func _shares(a: Array, b: Array) -> bool:
	for code in a:
		if b.has(code):
			return true
	return false


## A key or button as the remap screen shows it.
func input_name(code: int) -> String:
	if kind == Kind.KEYBOARD:
		return OS.get_keycode_string(code).to_upper()
	if kind == Kind.GAMEPAD and PAD_BUTTON_NAMES.has(code):
		return PAD_BUTTON_NAMES[code]
	return "BUTTON %d" % code


## `action`'s binding as the remap screen shows it: "SPACE / SHIFT", or "---" for none.
func binding_text(action: String) -> String:
	var names: Array[String] = []
	for code in binding(action):
		names.append(input_name(code))
	return "---" if names.is_empty() else " / ".join(names)
