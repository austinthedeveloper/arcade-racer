class_name ControlsCard
extends MenuScreen
## The controls card (PR-22): CONTROLS on the title and on the pause menu lists what every
## control is on the device in use (the keyboard, a pad, a wheel or the touch controls), from
## the bindings as they are now (RemapScreen's rebinds included). Left and right look at the
## other devices; select or back closes it. `rows` is the card's content, for tests.
## Text labels for now: input_label is the one place the button glyphs (WH-14) plug in.

enum Device { KEYBOARD, GAMEPAD, WHEEL, TOUCH }

const DEVICE_NAMES := ["KEYBOARD", "GAMEPAD", "WHEEL", "TOUCH"]
const TOP := 66.0  # the first row's baseline
const ROW_H := 17.0
const LABEL_X := 150.0  # where a row's control name ends (right-aligned)
const VALUE_X := 170.0  # where its input starts
## The touch layout's controls (TouchControls.RACE_BUTTONS), as the card names them.
const TOUCH_ROWS := [
	["STEER", "< and > at the bottom left"],
	["GAS", "GAS at the bottom right"],
	["BRAKE", "BRAKE, left of GAS"],
	["NITRO", "NITRO, above BRAKE"],
	["PAUSE", "II at the top"],
	["MENUS", "the arrows, OK and BACK"],
]

## The device shown (Device): the one in use when the card opens.
var device: int = Device.KEYBOARD
## What closing the card does (select or back): back to the title, or to the pause menu.
var on_back := Callable()
## Set over a race (the pause menu): a dimmer backdrop, the race showing through.
var over_race := false


func _init() -> void:
	device = device_now()


## The device in use, as the card names it: the touch controls when they're up, otherwise
## the kind of input driving (InputRouter.state).
static func device_now() -> int:
	if TouchControls.showing():
		return Device.TOUCH
	match InputRouter.state.kind:
		DriveInput.Kind.GAMEPAD:
			return Device.GAMEPAD
		DriveInput.Kind.WHEEL:
			return Device.WHEEL
	return Device.KEYBOARD


## The profile whose bindings the card shows for `dev`: the keyboard's, the joypad in use's
## when it's that kind, else a fresh one of that kind (its defaults).
static func profile_for(dev: int) -> DeviceProfile:
	if dev == Device.KEYBOARD or dev == Device.TOUCH:
		return InputRouter.keyboard
	var joy: int = InputRouter.last_active_device
	if joy >= 0:
		var p: DeviceProfile = InputRouter.get_profile(joy)
		if (p.kind == DeviceProfile.Kind.WHEEL) == (dev == Device.WHEEL):
			return p
	var fresh := DeviceProfile.new()
	fresh.kind = DeviceProfile.Kind.WHEEL if dev == Device.WHEEL else DeviceProfile.Kind.GAMEPAD
	return fresh


## A key or button as the card shows it. Text for now (DeviceProfile.input_name); the button
## glyphs (WH-14) go here when they exist, as a picture in place of the text.
static func input_label(profile: DeviceProfile, code: int) -> String:
	return profile.input_name(code)


## Several keys or buttons, "UP / W", or "---" for none.
static func inputs_label(profile: DeviceProfile, codes: Array) -> String:
	var names: Array[String] = []
	for code in codes:
		names.append(input_label(profile, code))
	return "---" if names.is_empty() else " / ".join(names)


## The card for `dev` (Device) with `profile`'s bindings: [control, what does it] rows.
static func rows(dev: int, profile: DeviceProfile) -> Array:
	var out: Array = []
	match dev:
		Device.TOUCH:
			return TOUCH_ROWS.duplicate(true)
		Device.KEYBOARD:
			var fixed := DeviceProfile.KEYBOARD_FIXED
			out.append(["STEER", "%s   %s" % [inputs_label(profile, fixed["steer_left"]), inputs_label(profile, fixed["steer_right"])]])
			out.append(["GAS", inputs_label(profile, fixed["accelerate"])])
			out.append(["BRAKE", inputs_label(profile, fixed["brake"])])
		Device.GAMEPAD:
			out.append(["STEER", "LEFT STICK / D-PAD"])
			out.append(["GAS", "RT / " + inputs_label(profile, DeviceProfile.PAD_FIXED["GAS"])])
			out.append(["BRAKE", "LT / " + inputs_label(profile, DeviceProfile.PAD_FIXED["BRAKE"])])
		Device.WHEEL:
			out.append(["STEER", "THE WHEEL"])
			var pedals := "THE PEDALS" if profile.calibrated else "PEDALS AFTER CALIBRATING (F2)"
			out.append(["GAS / BRAKE", pedals])
	for action: String in DeviceProfile.REMAP_ACTIONS:
		out.append([DeviceProfile.ACTION_NAMES[action], inputs_label(profile, profile.binding(action))])
	match dev:
		Device.KEYBOARD:
			out.append(["RESTART", inputs_label(profile, DeviceProfile.KEYBOARD_FIXED["restart"])])
			out.append(["CALIBRATE WHEEL", inputs_label(profile, DeviceProfile.KEYBOARD_FIXED["calibrate"])])
		Device.GAMEPAD:
			out.append(["RESTART", inputs_label(profile, DeviceProfile.PAD_FIXED["RESTART"])])
			out.append(["MENUS", "D-PAD, A SELECT, B BACK"])
		Device.WHEEL:
			out.append(["MENUS", "D-PAD, A SELECT, B BACK"])
	return out


## The rows for the device shown now.
func current_rows() -> Array:
	return rows(device, profile_for(device))


func choice_count() -> int:
	return Device.size()


func handle(m: MenuInput) -> void:
	if m.step() != 0:
		device = posmod(device + m.step(), Device.size())
		Audio.play("tick")
	elif m.confirm_pressed or m.back_pressed:
		Audio.play("beep")
		close()


## Closes the card: what on_back says (the title, the pause menu).
func close() -> void:
	if on_back.is_valid():
		on_back.call()


static func card_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.GAMEPAD, DriveInput.Kind.WHEEL:
			return "D-pad Left / Right: other devices    A / B: back"
	return "Left / Right: other devices    Enter / Esc: back"


func _draw() -> void:
	if over_race:
		draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(NIGHT, 0.82))
	else:
		_backdrop(0.8)
	_header("CONTROLS")
	var w := float(Cfg.SCREEN_W)
	var panel := Rect2(40, 46, w - 80, Cfg.SCREEN_H - 78)
	_panel(panel, 0.88)
	# The device tabs, the one shown lit
	var tab_w := (panel.size.x - 40) / Device.size()
	for i in Device.size():
		var r := Rect2(panel.position.x + 20 + i * tab_w + 3, panel.position.y + 6, tab_w - 6, 16)
		var on := i == device
		draw_rect(r, Color(GOLD, 0.25 + 0.08 * sin(time * 5.0)) if on else Color(1, 1, 1, 0.06))
		if on:
			draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), GOLD)
		var label: String = DEVICE_NAMES[i] + ("  (IN USE)" if i == device_now() else "")
		_text_centered(Vector2(r.get_center().x, r.position.y + 12), label, 9, GOLD if on else Color(1, 1, 1, 0.6))
	var list := current_rows()
	for i in list.size():
		var y := TOP + 14 + i * ROW_H
		if i % 2 == 0:
			draw_rect(Rect2(panel.position.x + 12, y - 12, panel.size.x - 24, ROW_H), Color(1, 1, 1, 0.04))
		var label: String = list[i][0]
		_text(Vector2(panel.position.x + LABEL_X - UiText.width(label, 11), y), label, 11, SKY)
		_text(Vector2(panel.position.x + VALUE_X, y), list[i][1], 11, Color.WHITE)
	_footer(card_hints())
