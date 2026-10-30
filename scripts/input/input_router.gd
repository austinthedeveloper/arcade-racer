extends Node
## Autoload. Turns keyboard, gamepad and wheel/pedal input into one DriveInput per physics tick.
##
## Gamepads and wheels are read per device rather than through the InputMap, so a wheel's
## pedal axes can never leak into gamepad trigger bindings. Wheels go through a saved
## DeviceProfile; until a wheel is calibrated only its steering is used.

signal devices_changed

const PROFILE_PATH := "user://input_profiles.cfg"
const AXIS_COUNT := 10
const BUTTON_COUNT := 24
const WHEEL_NAME_HINTS := [
	"wheel", "racing", "driving force", "g25", "g27", "g29", "g920", "g923", "momo",
	"thrustmaster", "t150", "t248", "t300", "t500", "tmx", "t-gt", "fanatec", "csl", "clubsport",
	"podium", "moza", "simagic", "simucube", "pxn",
]
const PAD_DEADZONE := 0.12
const PAD_GAMMA := 1.6

var state := DriveInput.new()
var speed_factor := 0.0  # set by the race each tick, for speed-sensitive pad steering
var last_active_device := -1  # -1 is the keyboard

var _saved: Dictionary = {}  # guid -> DeviceProfile
var _transient: Dictionary = {}  # device id -> DeviceProfile, for devices without a saved profile
var _kb_steer := 0.0
var _pad_steer: Dictionary = {}
var _prev := {"nitro": false, "pause": false, "restart": false, "confirm": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	_register_actions()
	_load_profiles()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(dt: float) -> void:
	var steer := 0.0
	var throttle := 0.0
	var brake := 0.0
	var down := {"nitro": false, "pause": false, "restart": false, "confirm": false}

	# Keyboard: digital steering ramps in, and snaps back faster than it ramps
	var kb_target := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var returning := kb_target == 0.0 or signf(kb_target) != signf(_kb_steer)
	_kb_steer = move_toward(_kb_steer, kb_target, dt * (9.0 if returning else 5.0))
	steer = _kb_steer * lerpf(1.0, 0.75, speed_factor)
	throttle = Input.get_action_strength("accelerate")
	brake = Input.get_action_strength("brake")
	down["nitro"] = Input.is_action_pressed("nitro")
	down["pause"] = Input.is_action_pressed("pause")
	down["restart"] = Input.is_action_pressed("restart")
	down["confirm"] = Input.is_action_pressed("confirm")
	if kb_target != 0.0 or throttle > 0.0 or brake > 0.0:
		last_active_device = -1

	for device in Input.get_connected_joypads():
		var prof := get_profile(device)
		var r: Dictionary = _read_wheel(device, prof) if prof.kind == DeviceProfile.Kind.WHEEL else _read_pad(device, dt)
		if absf(r["steer"]) > absf(steer):
			steer = r["steer"]
		throttle = maxf(throttle, r["throttle"])
		brake = maxf(brake, r["brake"])
		for key in down:
			down[key] = down[key] or r.get(key, false)
		if r["active"]:
			last_active_device = device

	state.steer = clampf(steer, -1.0, 1.0)
	state.throttle = clampf(throttle, 0.0, 1.0)
	state.brake = clampf(brake, 0.0, 1.0)
	state.nitro_pressed = down["nitro"] and not _prev["nitro"]
	state.pause_pressed = down["pause"] and not _prev["pause"]
	state.restart_pressed = down["restart"] and not _prev["restart"]
	state.confirm_pressed = down["confirm"] and not _prev["confirm"]
	_prev = down
	if last_active_device >= 0 and Input.get_connected_joypads().has(last_active_device):
		var p := get_profile(last_active_device)
		state.kind = DriveInput.Kind.WHEEL if p.kind == DeviceProfile.Kind.WHEEL else DriveInput.Kind.GAMEPAD
		state.device_name = Input.get_joy_name(last_active_device)
	else:
		state.kind = DriveInput.Kind.KEYBOARD
		state.device_name = "Keyboard"


func _read_pad(device: int, dt: float) -> Dictionary:
	var ax := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var mag := absf(ax)
	var target := 0.0
	if mag > PAD_DEADZONE:
		target = signf(ax) * pow((mag - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), PAD_GAMMA)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		target = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		target = 1.0
	target *= lerpf(1.0, 0.65, speed_factor)
	var s := move_toward(_pad_steer.get(device, 0.0), target, dt * 7.0)
	_pad_steer[device] = s

	var a_btn := Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	var throttle := maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), 1.0 if a_btn else 0.0)
	var brake_btn := Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
	var brake := maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT), 1.0 if brake_btn else 0.0)
	var nitro := Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
	return {
		"steer": s,
		"throttle": throttle if throttle > 0.05 else 0.0,
		"brake": brake if brake > 0.05 else 0.0,
		"nitro": nitro,
		"pause": Input.is_joy_button_pressed(device, JOY_BUTTON_START),
		"restart": Input.is_joy_button_pressed(device, JOY_BUTTON_BACK),
		"confirm": a_btn,
		"active": mag > PAD_DEADZONE or throttle > 0.05 or brake > 0.05 or nitro or a_btn,
	}


func _read_wheel(device: int, prof: DeviceProfile) -> Dictionary:
	var steer := prof.normalize_steer(Input.get_joy_axis(device, prof.steer_axis))
	var throttle := 0.0
	var brake := 0.0
	if prof.calibrated:
		if prof.throttle_axis >= 0:
			throttle = DeviceProfile.pedal(Input.get_joy_axis(device, prof.throttle_axis), prof.throttle_rest, prof.throttle_full)
		if prof.brake_axis >= 0:
			brake = DeviceProfile.pedal(Input.get_joy_axis(device, prof.brake_axis), prof.brake_rest, prof.brake_full)
	var nitro := prof.nitro_button >= 0 and Input.is_joy_button_pressed(device, prof.nitro_button)
	return {
		"steer": steer,
		"throttle": throttle,
		"brake": brake,
		"nitro": nitro,
		"active": absf(steer) > 0.05 or throttle > 0.05 or brake > 0.05 or nitro,
	}


# --- Profiles ------------------------------------------------------------------

func get_profile(device: int) -> DeviceProfile:
	var guid := Input.get_joy_guid(device)
	if _saved.has(guid):
		return _saved[guid]
	if not _transient.has(device):
		var p := DeviceProfile.new()
		p.guid = guid
		p.name = Input.get_joy_name(device)
		p.kind = DeviceProfile.Kind.WHEEL if looks_like_wheel(p.name) else DeviceProfile.Kind.GAMEPAD
		_transient[device] = p
	return _transient[device]


func looks_like_wheel(joy_name: String) -> bool:
	var lower := joy_name.to_lower()
	for hint in WHEEL_NAME_HINTS:
		if lower.contains(hint):
			return true
	return false


func needs_calibration(device: int) -> bool:
	var p := get_profile(device)
	return p.kind == DeviceProfile.Kind.WHEEL and not p.calibrated


func save_profile(profile: DeviceProfile) -> void:
	_saved[profile.guid] = profile
	_write_profiles()
	devices_changed.emit()


func reset_profile(device: int) -> void:
	_saved.erase(Input.get_joy_guid(device))
	_transient.erase(device)
	_write_profiles()
	devices_changed.emit()


func raw_axes(device: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for a in AXIS_COUNT:
		out.append(Input.get_joy_axis(device, a))
	return out


func pressed_buttons(device: int) -> Array[int]:
	var out: Array[int] = []
	if device < 0:
		return out
	for b in BUTTON_COUNT:
		if Input.is_joy_button_pressed(device, b):
			out.append(b)
	return out


func _load_profiles() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	for section in cfg.get_sections():
		_saved[section] = DeviceProfile.load_from(cfg, section)


func _write_profiles() -> void:
	var cfg := ConfigFile.new()
	for guid in _saved:
		(_saved[guid] as DeviceProfile).save_to(cfg)
	cfg.save(PROFILE_PATH)


func _on_joy_connection_changed(device: int, _connected: bool) -> void:
	_transient.erase(device)
	_pad_steer.erase(device)
	if last_active_device == device:
		last_active_device = -1
	devices_changed.emit()


# --- Keyboard actions ----------------------------------------------------------

func _register_actions() -> void:
	_add_action("steer_left", [KEY_LEFT, KEY_A])
	_add_action("steer_right", [KEY_RIGHT, KEY_D])
	_add_action("accelerate", [KEY_UP, KEY_W])
	_add_action("brake", [KEY_DOWN, KEY_S])
	_add_action("nitro", [KEY_SPACE, KEY_SHIFT])
	_add_action("pause", [KEY_ESCAPE, KEY_P])
	_add_action("restart", [KEY_R])
	_add_action("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_add_action("debug_input", [KEY_F1])
	_add_action("calibrate", [KEY_F2])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
