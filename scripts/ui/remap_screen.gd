class_name RemapScreen
extends MenuScreen
## Controls > REMAP BUTTONS: binds nitro, shift up and down, horn, pause and view on each
## device (the keyboard, then every connected pad and wheel). Bindings save to that device's
## profile (InputRouter.save_bindings) as soon as they're set; clashes show in red.
## The top row picks the device (left/right; on a wheel, gas cycles it). Selecting an
## action waits for the new key or button: Backspace cancels, Delete leaves it unbound.

enum Row { DEVICE, ACTION, RESET, BACK }

const LISTEN_SECONDS := 6.0  # waiting this long for a key gives up
const SETTLE := 0.25  # seconds after a bind before menu input counts again
const ROW_H := 20.0
const TOP := 54.0
const HELP_DEVICE := "Pick the keyboard or a controller to set up."
const HELP_ACTION := "Select, then press the new key or button."
const HELP_RESET := "This device's buttons back to their defaults."
const HELP_BACK := "Back to the options."

var device_index := 0  # into InputRouter.binding_devices()
var index := 1  # into rows(): 0 is the device row; opens on the first action
var listening := ""  # the action waiting for a key or button, or ""
var listen_left := 0.0
var _settle := 0.0


## The rows: the device, one per REMAP_ACTIONS, reset, back. Actions are [Row.ACTION, name].
func rows() -> Array:
	var out: Array = [[Row.DEVICE, ""]]
	for a: String in DeviceProfile.REMAP_ACTIONS:
		out.append([Row.ACTION, a])
	out.append([Row.RESET, ""])
	out.append([Row.BACK, ""])
	return out


func row_kind() -> int:
	return rows()[index][0]


## The action under the cursor, or "".
func row_action() -> String:
	return rows()[index][1]


## The joypad being set up (-1: the keyboard).
func device() -> int:
	var list := InputRouter.binding_devices()
	return list[clampi(device_index, 0, list.size() - 1)]


func profile() -> DeviceProfile:
	return InputRouter.binding_profile(device())


func device_name() -> String:
	var d := device()
	return "KEYBOARD" if d < 0 else Input.get_joy_name(d).to_upper()


## Puts the cursor on `action`'s row.
func go_to(action: String) -> void:
	index = 1 + DeviceProfile.REMAP_ACTIONS.find(action)


func move(dir: int) -> void:
	index = posmod(index + dir, rows().size())


func flip_device(dir: int) -> void:
	device_index = posmod(device_index + dir, InputRouter.binding_devices().size())


## Starts waiting for `action`'s new key or button.
func listen(action: String) -> void:
	listening = action
	listen_left = LISTEN_SECONDS


## Binds the action being listened for to `code` (UNBOUND for none) and saves it.
func bind(code: int) -> void:
	var p := profile()
	p.bind(listening, code)
	InputRouter.save_bindings(p)
	listening = ""
	_settle = SETTLE


func reset_device() -> void:
	var p := profile()
	p.reset_bindings()
	InputRouter.save_bindings(p)


## Takes a key or joypad button press while listening; returns true when it used it.
## On the keyboard: Backspace cancels and Delete unbinds. On a joypad: a button on that pad.
func capture(event: InputEvent) -> bool:
	if listening == "" or not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_BACKSPACE:
			listening = ""
			_settle = SETTLE
		elif code == KEY_DELETE:
			bind(DeviceProfile.UNBOUND)
		elif device() < 0:
			bind(code)
		else:
			return false
		return true
	if event is InputEventJoypadButton and event.device == device() and device() >= 0:
		bind(event.button_index)
		return true
	return false


func _input(event: InputEvent) -> void:
	if capture(event):
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	super(dt)
	_settle = maxf(0.0, _settle - dt)
	if listening != "":
		listen_left -= dt
		if listen_left <= 0.0:
			listening = ""


func handle(m: MenuInput) -> void:
	if listening != "" or _settle > 0.0:
		return
	var wheel := OptionsScreen.wheel_driven()
	var pick := m.step() if wheel else m.step_y()
	if pick != 0:
		move(pick)
		Audio.play("tick")
	elif not wheel and m.step() != 0 and row_kind() == Row.DEVICE:
		flip_device(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		match row_kind():
			Row.DEVICE:
				flip_device(1)
			Row.ACTION:
				listen(row_action())
			Row.RESET:
				reset_device()
			Row.BACK:
				_leave()
	elif m.back_pressed:
		_leave()


func _leave() -> void:
	game.close_remap()


static func remap_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "Steer: choose    Gas: select    Brake: back"
		DriveInput.Kind.GAMEPAD:
			return "D-pad Up / Down: choose    Left / Right: device    A: select    B: back"
	return "Up / Down: choose    Left / Right: device    Enter: select    Esc: back"


func _draw() -> void:
	_backdrop(0.8)
	_header("CONTROLS")
	var list := rows()
	var panel := Rect2(90, TOP - 6, 460, ROW_H * list.size() + 12)
	_frame(panel)
	draw_rect(panel, Color(0.04, 0.03, 0.1, 0.85))
	var p := profile()
	var mid := ROW_H / 2.0 - 2.0
	var right := panel.end.x - 20
	var clash_help := ""
	for i in list.size():
		var kind: int = list[i][0]
		var action: String = list[i][1]
		var y := TOP + i * ROW_H
		var on := i == index
		if on:
			draw_rect(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(panel.position.x, y, 3, ROW_H - 4), GOLD)
		var col := GOLD if on else Color.WHITE
		match kind:
			Row.DEVICE:
				_text(Vector2(panel.position.x + 16, y + mid + 5), "DEVICE", 12, col)
				var n := device_name()
				_text_centered(Vector2(right - 110, y + mid + 5), n.substr(0, 26), 12, SKY)
				if on and not OptionsScreen.wheel_driven():
					_small_arrow(Vector2(right - 220, y + mid), -1)
					_small_arrow(Vector2(right, y + mid), 1)
			Row.ACTION:
				_text(Vector2(panel.position.x + 16, y + mid + 5), DeviceProfile.ACTION_NAMES[action], 12, col)
				var clashes := p.conflicts(action)
				var t := p.binding_text(action)
				var tcol := col
				if listening == action:
					t = "PRESS A KEY" if device() < 0 else "PRESS A BUTTON"
					tcol = Color(GOLD, 0.5 + 0.5 * sin(time * 10.0))
				elif not clashes.is_empty():
					tcol = Color("#ff5d5d")
					t = "! " + t
					if on:
						clash_help = "%s is also %s." % [p.binding_text(action), " and ".join(clashes)]
				_text_centered(Vector2(right - 110, y + mid + 5), t, 12, tcol)
			Row.RESET:
				_text(Vector2(panel.position.x + 16, y + mid + 5), "RESET TO DEFAULTS", 12, col)
			Row.BACK:
				_text(Vector2(panel.position.x + 16, y + mid + 5), "BACK", 12, col)
	var help := clash_help
	if listening != "":
		help = "Press the new %s for %s. Backspace cancels, Delete clears." % [
			"key" if device() < 0 else "button", DeviceProfile.ACTION_NAMES[listening]]
	elif help == "":
		help = [HELP_DEVICE, HELP_ACTION, HELP_RESET, HELP_BACK][row_kind()]
	var hcol := Color("#ff5d5d") if clash_help != "" and listening == "" else Color(1, 1, 1, 0.85)
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, panel.end.y + 20), help, 10, hcol)
	_footer(remap_hints())


func _small_arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -6), c + Vector2(-4 * d, 6)]), GOLD)
