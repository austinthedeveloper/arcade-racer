extends Node
## Autoload. Turns keyboard, gamepad and wheel/pedal input into one DriveInput (and one
## MenuInput, for the menus) per physics tick.
##
## Gamepads and wheels are read per device rather than through the InputMap, so a wheel's
## pedal axes can never leak into gamepad trigger bindings. Wheels go through a saved
## DeviceProfile; until a wheel is calibrated only its steering is used.

signal devices_changed
## The joypad driving (last_active_device) was unplugged; the race pauses (WH-7).
signal driver_unplugged(guid: String, joy_name: String, wheel: bool)
## A joypad plugged in while that one is gone (WH-12): it drives now. `same` when it's the one
## that went (by its GUID, whatever device id it gets, with the same profile); otherwise a
## different device came back in its place, with its own profile.
signal driver_replugged(guid: String, joy_name: String, wheel: bool, same: bool)

const AXIS_COUNT := 10
const BUTTON_COUNT := 24
const WHEEL_NAME_HINTS := [
	"wheel", "racing", "driving force", "g25", "g27", "g29", "g920", "g923", "momo",
	"thrustmaster", "t150", "t248", "t300", "t500", "tmx", "t-gt", "fanatec", "csl", "clubsport",
	"podium", "moza", "simagic", "simucube", "pxn",
]
const PAD_DEADZONE := 0.12
const PAD_GAMMA := 1.6
## The input_profiles.cfg format (CfgVersion). 0: no version field, one section per GUID.
## 1: the same, plus [meta] version. 2: a bindings key per profile, and a [keyboard] section
## of keyboard bindings (missing: the defaults).
const PROFILES_VERSION := 2

## Where wheel and pad profiles are saved. Tests point this at a scratch file.
var profile_path := "user://input_profiles.cfg"
## The version of the profile file last loaded (PROFILES_VERSION when there was no file).
var profiles_version := PROFILES_VERSION
var state := DriveInput.new()
var menu := MenuInput.new()
var speed_factor := 0.0  # set by the race each tick, for speed-sensitive pad steering
var last_active_device := -1  # -1 is the keyboard
## The keyboard's bindings (RemapScreen), put on the InputMap by apply_keyboard_bindings.
var keyboard := DeviceProfile.keyboard()
## The GUID of the joypad that was driving while it's unplugged, or "".
var unplugged_driver := ""

var _saved: Dictionary = {}  # guid -> DeviceProfile
var _transient: Dictionary = {}  # device id -> DeviceProfile, for devices without a saved profile
## Device id -> [guid, name] of every joypad seen, kept after it's unplugged: by then Godot
## has forgotten them.
var _joys: Dictionary = {}
var _parked: Dictionary = {}  # guid -> an unplugged joypad's unsaved profile, for its return
var _kb_steer := 0.0
var _pad_steer: Dictionary = {}
var _prev := {"nitro": false, "pause": false, "restart": false, "confirm": false, "horn": false, "radio": false,
	"shift_up": false, "shift_down": false, "view": false, "photo": false}
var _prev_menu := {"confirm": false, "back": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	# Dev flag: --profiles-file=PATH reads (and saves) another profile file, for screenshots.
	profile_path = DevArgs.value("--profiles-file", profile_path)
	_register_actions()
	load_profiles()
	TouchControls.add_to(get_tree().root)
	for d in Input.get_connected_joypads():
		_joys[d] = [Input.get_joy_guid(d), Input.get_joy_name(d)]
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):  # (tests make it first)
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(dt: float) -> void:
	var steer := 0.0
	var throttle := 0.0
	var brake := 0.0
	var down := {"nitro": false, "pause": false, "restart": false, "confirm": false, "horn": false, "radio": false,
		"shift_up": false, "shift_down": false, "view": false, "photo": false}

	# Keyboard: digital steering ramps in, and snaps back faster than it ramps (key_steer)
	var kb_target := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	_kb_steer = key_steer(_kb_steer, kb_target, dt, Settings.key_steer_rates())
	steer = _kb_steer * lerpf(1.0, 0.75, speed_factor)
	throttle = Input.get_action_strength("accelerate")
	brake = Input.get_action_strength("brake")
	down["nitro"] = Input.is_action_pressed("nitro")
	down["pause"] = Input.is_action_pressed("pause")
	down["restart"] = Input.is_action_pressed("restart")
	down["confirm"] = Input.is_action_pressed("confirm")
	down["horn"] = Input.is_action_pressed("horn")
	down["radio"] = Input.is_action_pressed("radio")
	down["view"] = Input.is_action_pressed("view")
	down["photo"] = Input.is_action_pressed("photo")
	down["shift_up"] = Input.is_action_pressed("shift_up")
	down["shift_down"] = Input.is_action_pressed("shift_down")
	if kb_target != 0.0 or throttle > 0.0 or brake > 0.0:
		last_active_device = -1
	var menu_x := kb_target
	var menu_y := brake - throttle  # Down / S and Up / W
	var menu_down := {
		"confirm": down["confirm"],
		"back": Input.is_action_pressed("back") or down["pause"],
	}

	for device in Input.get_connected_joypads():
		var prof := get_profile(device)
		var r: Dictionary = _read_wheel(device, prof) if prof.kind == DeviceProfile.Kind.WHEEL else _read_pad(device, prof, dt)
		if absf(r["steer"]) > absf(steer):
			steer = r["steer"]
		throttle = maxf(throttle, r["throttle"])
		brake = maxf(brake, r["brake"])
		for key in down:
			down[key] = down[key] or r.get(key, false)
		if absf(r["menu_x"]) > absf(menu_x):
			menu_x = r["menu_x"]
		if absf(r["menu_y"]) > absf(menu_y):
			menu_y = r["menu_y"]
		menu_down["confirm"] = menu_down["confirm"] or r["menu_confirm"]
		menu_down["back"] = menu_down["back"] or r["menu_back"]
		if r["active"]:
			last_active_device = device

	state.steer = clampf(steer, -1.0, 1.0)
	state.throttle = clampf(throttle, 0.0, 1.0)
	state.brake = clampf(brake, 0.0, 1.0)
	state.nitro_pressed = down["nitro"] and not _prev["nitro"]
	state.pause_pressed = down["pause"] and not _prev["pause"]
	state.restart_pressed = down["restart"] and not _prev["restart"]
	state.confirm_pressed = down["confirm"] and not _prev["confirm"]
	state.horn = down["horn"]
	state.radio_pressed = down["radio"] and not _prev["radio"]
	state.view_pressed = down["view"] and not _prev["view"]
	state.photo_pressed = down["photo"] and not _prev["photo"]
	state.shift_up_pressed = down["shift_up"] and not _prev["shift_up"]
	state.shift_down_pressed = down["shift_down"] and not _prev["shift_down"]
	_prev = down
	menu.step_axis(clampf(menu_x, -1.0, 1.0), dt)
	menu.step_axis_y(clampf(menu_y, -1.0, 1.0), dt)
	menu.confirm_pressed = menu_down["confirm"] and not _prev_menu["confirm"]
	menu.back_pressed = menu_down["back"] and not _prev_menu["back"]
	menu.radio_pressed = state.radio_pressed
	_prev_menu = menu_down
	if last_active_device >= 0 and Input.get_connected_joypads().has(last_active_device):
		var p := get_profile(last_active_device)
		state.kind = DriveInput.Kind.WHEEL if p.kind == DeviceProfile.Kind.WHEEL else DriveInput.Kind.GAMEPAD
		state.device_name = Input.get_joy_name(last_active_device)
		state.mapped = p.kind == DeviceProfile.Kind.WHEEL or Input.is_joy_known(last_active_device)
	else:
		state.kind = DriveInput.Kind.KEYBOARD
		state.device_name = "Keyboard"
		state.mapped = true


## The keyboard's steering one tick on: from `current` toward the keys' `target` (-1, 0 or 1)
## at `rates`.x while turning in, `rates`.y coming back (the keys released, or the other way,
## or starting from center) (Settings.key_steer_rates).
static func key_steer(current: float, target: float, dt: float, rates: Vector2) -> float:
	var returning := target == 0.0 or signf(target) != signf(current)
	return move_toward(current, target, dt * (rates.y if returning else rates.x))


func _read_pad(device: int, prof: DeviceProfile, dt: float) -> Dictionary:
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
	var nitro := prof.pressed("nitro", device)
	var menu_x := ax
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		menu_x = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		menu_x = 1.0
	var menu_y := stick_menu_y(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), Input.is_joy_known(device))
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		menu_y = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		menu_y = 1.0
	return {
		"steer": s,
		"throttle": throttle if throttle > 0.05 else 0.0,
		"brake": brake if brake > 0.05 else 0.0,
		"nitro": nitro,
		"pause": prof.pressed("pause", device),
		"horn": prof.pressed("horn", device),
		"radio": prof.pressed("radio", device),
		"view": prof.pressed("view", device),
		"photo": prof.pressed("photo", device),
		"shift_up": prof.pressed("shift_up", device),
		"shift_down": prof.pressed("shift_down", device),
		"restart": Input.is_joy_button_pressed(device, JOY_BUTTON_BACK),
		"confirm": a_btn,
		"active": mag > PAD_DEADZONE or throttle > 0.05 or brake > 0.05 or nitro or a_btn,
		"menu_x": menu_x,
		"menu_y": menu_y,
		"menu_confirm": a_btn or prof.pressed("pause", device),
		"menu_back": Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK),
	}


## The up/down a pad's left stick gives the menus. Only a device with a standard gamepad
## mapping has a stick on axis 1: on an unmapped one (a wheel or a pedal set that isn't
## recognized by name, so it's read as a pad) axis 1 is often a pedal resting at full travel,
## which held the Options list scrolling down with nothing to stop it.
static func stick_menu_y(axis: float, known: bool) -> float:
	return axis if known else 0.0


func _read_wheel(device: int, prof: DeviceProfile) -> Dictionary:
	var steer := prof.normalize_steer(Input.get_joy_axis(device, prof.steer_axis))
	var throttle := 0.0
	var brake := 0.0
	if prof.calibrated:
		if prof.throttle_axis >= 0:
			throttle = DeviceProfile.pedal(Input.get_joy_axis(device, prof.throttle_axis), prof.throttle_rest, prof.throttle_full)
		if prof.brake_axis >= 0:
			brake = DeviceProfile.pedal(Input.get_joy_axis(device, prof.brake_axis), prof.brake_rest, prof.brake_full)
	var nitro := prof.pressed("nitro", device)
	return {
		"steer": steer,
		"throttle": throttle,
		"brake": brake,
		"nitro": nitro,
		"pause": prof.pressed("pause", device),
		"horn": prof.pressed("horn", device),
		"radio": prof.pressed("radio", device),
		"view": prof.pressed("view", device),
		"photo": prof.pressed("photo", device),
		"shift_up": prof.pressed("shift_up", device),
		"shift_down": prof.pressed("shift_down", device),
		"active": absf(steer) > 0.05 or throttle > 0.05 or brake > 0.05 or nitro,
	}.merged(wheel_menu(pressed_buttons(device), prof.pressed("pause", device)))


## A wheel in the menus, as a gamepad: its D-pad moves, A (button 0) or its pause button
## selects, B (button 1) goes back. Steering a wheel through menus was miserable, so the
## wheel and pedals only drive. An unmapped wheel's hat still arrives as the D-pad buttons.
static func wheel_menu(buttons: Array[int], pause_held: bool) -> Dictionary:
	var held := func(b: int) -> float: return 1.0 if buttons.has(b) else 0.0
	return {
		"menu_x": held.call(JOY_BUTTON_DPAD_RIGHT) - held.call(JOY_BUTTON_DPAD_LEFT),
		"menu_y": held.call(JOY_BUTTON_DPAD_DOWN) - held.call(JOY_BUTTON_DPAD_UP),
		"menu_confirm": buttons.has(JOY_BUTTON_A) or pause_held,
		"menu_back": buttons.has(JOY_BUTTON_B),
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


## The title screen's and the race's prompt to calibrate a connected wheel, or "".
func wheel_hint() -> String:
	for d in Input.get_connected_joypads():
		if needs_calibration(d):
			return "Wheel detected: press F2 to calibrate steering and pedals"
	return ""


## The joypads plugged in now: GUID -> name.
func plugged_joypads() -> Dictionary:
	var out := {}
	for d in Input.get_connected_joypads():
		out[Input.get_joy_guid(d)] = Input.get_joy_name(d)
	return out


## The wheel's first run (WH-16): the first of `plugged` (GUID -> name) that the title should
## offer to calibrate, or "": a wheel (by its name) with no saved profile that hasn't been
## offered it yet (`offered`, Settings.wheels_prompted). Never a pad, never a wheel already set up.
func first_run_wheel(plugged: Dictionary, offered: Array) -> String:
	for guid: String in plugged:
		if guid == "" or _saved.has(guid) or offered.has(guid):
			continue
		if looks_like_wheel(str(plugged[guid])):
			return guid
	return ""


## A known wheel's ready-made profile (WH-4) for a wheel called `joy_name`, or null. WH-4 is
## not built yet, so there are none: when it is, the first-run prompt (TitleScreen) offers
## USE ITS PROFILE beside CALIBRATE NOW for a wheel this returns one for.
func known_profile_for(_joy_name: String) -> DeviceProfile:
	return null


func save_profile(profile: DeviceProfile) -> void:
	_saved[profile.guid] = profile
	_write_profiles()
	devices_changed.emit()


func reset_profile(device: int) -> void:
	_saved.erase(Input.get_joy_guid(device))
	_transient.erase(device)
	_write_profiles()
	devices_changed.emit()


## The wheels whose steering can be set (WheelScreen): each connected wheel, then every
## saved wheel profile that isn't plugged in.
func wheel_profiles() -> Array[DeviceProfile]:
	var out: Array[DeviceProfile] = []
	for d in Input.get_connected_joypads():
		var p := get_profile(d)
		if p.kind == DeviceProfile.Kind.WHEEL and not out.has(p):
			out.append(p)
	for guid in _saved:
		var p: DeviceProfile = _saved[guid]
		if p.kind == DeviceProfile.Kind.WHEEL and not out.has(p):
			out.append(p)
	return out


## The connected joypad with `guid`, or -1.
func device_for(guid: String) -> int:
	for d in Input.get_connected_joypads():
		if Input.get_joy_guid(d) == guid:
			return d
	return -1


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


func load_profiles() -> void:
	var cfg := ConfigFile.new()
	_saved.clear()
	_transient.clear()
	keyboard = DeviceProfile.keyboard()
	profiles_version = PROFILES_VERSION
	if cfg.load(profile_path) == OK:
		profiles_version = migrate_profiles(cfg)
		for section in cfg.get_sections():
			if section == DeviceProfile.KEYBOARD_GUID:
				keyboard.bindings = DeviceProfile.load_from(cfg, section).bindings
			elif section != CfgVersion.SECTION:
				_saved[section] = DeviceProfile.load_from(cfg, section)
	apply_keyboard_bindings()


## Brings a loaded input_profiles.cfg up to PROFILES_VERSION; returns the version it had.
static func migrate_profiles(cfg: ConfigFile) -> int:
	return CfgVersion.migrate(cfg, PROFILES_VERSION, [_profiles_v0_to_v1, _profiles_v1_to_v2])


## Version 1 only added the [meta] version: every other section is still a profile by GUID.
static func _profiles_v0_to_v1(_cfg: ConfigFile) -> void:
	pass


## Version 2 added bindings. A profile without them, and no [keyboard] section, means the
## defaults, as before: nothing to change.
static func _profiles_v1_to_v2(_cfg: ConfigFile) -> void:
	pass


## Over a file from a newer build, keys this build doesn't know survive inside each profile
## (CfgVersion.to_write); profiles reset since are dropped.
func _write_profiles() -> void:
	var cfg := CfgVersion.to_write(profile_path, PROFILES_VERSION)
	for section in cfg.get_sections():
		if section != CfgVersion.SECTION and not _saved.has(section):
			cfg.erase_section(section)
	for guid in _saved:
		(_saved[guid] as DeviceProfile).save_to(cfg)
	if not keyboard.bindings.is_empty():
		cfg.set_value(DeviceProfile.KEYBOARD_GUID, "bindings", keyboard.bindings)
	CfgVersion.backup_if_older(profile_path, PROFILES_VERSION)  # (EQ-21)
	cfg.save(profile_path)


# --- Bindings (RemapScreen) ------------------------------------------------------

## The devices bindings can be set for: -1 (the keyboard), then each connected joypad.
func binding_devices() -> Array[int]:
	var out: Array[int] = [-1]
	out.append_array(Input.get_connected_joypads())
	return out


## The profile holding `device`'s bindings (-1: the keyboard).
func binding_profile(device: int) -> DeviceProfile:
	return keyboard if device < 0 else get_profile(device)


## Saves a device's bindings (the keyboard's, or a joypad's whole profile) and uses them.
func save_bindings(profile: DeviceProfile) -> void:
	if profile.kind == DeviceProfile.Kind.KEYBOARD:
		keyboard = profile
		_write_profiles()
		apply_keyboard_bindings()
		devices_changed.emit()
	else:
		save_profile(profile)


## Puts the keyboard's bindings on the InputMap's remappable actions.
func apply_keyboard_bindings() -> void:
	for action: String in DeviceProfile.REMAP_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in keyboard.binding(action):
			InputMap.action_add_event(action, key_event(code))


static func key_event(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


## Input.joy_connection_changed. An unplugged joypad's GUID and name come from _joys; a
## joypad plugged back in that Godot can't name (a test's fake one) is taken to be the one
## that had its device id.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var known: Array = _joys.get(device, ["", ""])
	var named := connected and Input.get_connected_joypads().has(device)
	var guid := Input.get_joy_guid(device) if named else ""
	var joy_name := Input.get_joy_name(device) if named else ""
	joy_changed(device, connected, guid if guid != "" else known[0], joy_name if joy_name != "" else known[1])


## A joypad plugged in or unplugged. Unplugging the one driving says so (driver_unplugged);
## plugging it, or any other joypad, back in, on any device id, says that (driver_replugged,
## WH-12) and lets it drive
## with the profile it had: a saved one by its GUID, an unsaved one kept for it here.
func joy_changed(device: int, connected: bool, guid: String, joy_name: String) -> void:
	var driving := last_active_device == device
	if connected:
		_joys[device] = [guid, joy_name]
		_transient.erase(device)
		if _parked.has(guid):
			_transient[device] = _parked[guid]
			_parked.erase(guid)
	else:
		if _transient.has(device) and guid != "":
			_parked[guid] = _transient[device]
		_transient.erase(device)
	_pad_steer.erase(device)
	if driving:
		last_active_device = -1
	devices_changed.emit()
	if not connected and driving and guid != "":
		unplugged_driver = guid
		var p: DeviceProfile = _saved.get(guid, _parked.get(guid))
		var wheel := p.kind == DeviceProfile.Kind.WHEEL if p != null else looks_like_wheel(joy_name)
		driver_unplugged.emit(guid, joy_name, wheel)
	elif connected and guid != "" and unplugged_driver != "":
		var same := guid == unplugged_driver
		unplugged_driver = ""
		last_active_device = device
		var p: DeviceProfile = _saved.get(guid, _transient.get(device))
		var wheel := p.kind == DeviceProfile.Kind.WHEEL if p != null else looks_like_wheel(joy_name)
		driver_replugged.emit(guid, joy_name, wheel, same)


# --- Keyboard actions ----------------------------------------------------------

## The fixed keys (DeviceProfile.KEYBOARD_FIXED); the remappable ones (nitro, pause, horn,
## radio, shift_up and shift_down, and view, the camera view) come from the
## keyboard's bindings in apply_keyboard_bindings.
func _register_actions() -> void:
	for action: String in DeviceProfile.KEYBOARD_FIXED:
		_add_action(action, DeviceProfile.KEYBOARD_FIXED[action])
	apply_keyboard_bindings()


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		InputMap.action_add_event(action, key_event(k))
