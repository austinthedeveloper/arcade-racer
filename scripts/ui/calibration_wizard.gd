class_name CalibrationWizard
extends Control
## F2: step-by-step wheel and pedal calibration. Finds the steering and pedal axes by
## watching which axis moves most, so it works for inverted pedals, 0..1 or -1..1 ranges,
## and combined gas/brake axes. Confirm each step with Enter or any button on the wheel.

enum Step { NO_DEVICE, REST, LEFT, RIGHT, GAS, BRAKE, NITRO, DONE }

const MIN_MOVE := 0.3
const INSTRUCTIONS := {
	Step.REST: "Press each pedal down fully once, then let go of everything.\nConfirm while nothing is touched.",
	Step.LEFT: "Turn the wheel fully LEFT and hold it there.\nConfirm while holding.",
	Step.RIGHT: "Turn the wheel fully RIGHT and hold it there.\nConfirm while holding.",
	Step.GAS: "Center the wheel. Press the GAS pedal fully and hold.\nConfirm while holding.",
	Step.BRAKE: "Press the BRAKE pedal fully and hold.\nConfirm while holding.",
	Step.NITRO: "Press the wheel button you want for NITRO.\n(Enter to skip.)",
	Step.DONE: "Calibration saved. Enter or any wheel button to close.",
	Step.NO_DEVICE: "No controller found. Plug in your wheel and try again.\nEnter to close.",
}

var device := -1
var step := Step.REST
var message := ""
var profile: DeviceProfile

var _rest := PackedFloat32Array()
var _left := PackedFloat32Array()
var _prev_buttons: Array[int] = []
var _cooldown := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	device = InputRouter.last_active_device
	var pads := Input.get_connected_joypads()
	if device < 0 or not pads.has(device):
		device = -1
		for d in pads:
			if InputRouter.looks_like_wheel(Input.get_joy_name(d)):
				device = d
				break
		if device < 0 and not pads.is_empty():
			device = pads[0]
	step = Step.NO_DEVICE if device < 0 else Step.REST
	message = ""
	profile = null
	_prev_buttons = InputRouter.pressed_buttons(device)
	_cooldown = 0.3
	visible = true


func _process(dt: float) -> void:
	if not visible:
		return
	_cooldown -= dt
	var buttons := InputRouter.pressed_buttons(device)
	var new_button := -1
	for b in buttons:
		if not _prev_buttons.has(b):
			new_button = b
			break
	_prev_buttons = buttons
	if Input.is_action_just_pressed("pause"):
		visible = false
		return
	var enter := Input.is_action_just_pressed("confirm")
	if _cooldown <= 0.0:
		match step:
			Step.NITRO:
				if new_button >= 0 or enter:
					profile.nitro_button = new_button
					profile.calibrated = true
					InputRouter.save_profile(profile)
					step = Step.DONE
					_cooldown = 0.3
			Step.DONE, Step.NO_DEVICE:
				if enter or new_button >= 0:
					visible = false
			_:
				if enter or new_button >= 0:
					_capture()
					_cooldown = 0.3
	queue_redraw()


func _capture() -> void:
	var axes := InputRouter.raw_axes(device)
	message = ""
	match step:
		Step.REST:
			_rest = axes
			step = Step.LEFT
		Step.LEFT:
			_left = axes
			step = Step.RIGHT
		Step.RIGHT:
			var a := _most_moved(_left, axes, [])
			if absf(_left[a] - axes[a]) < MIN_MOVE:
				message = "Didn't see the wheel move. Let's try left again."
				step = Step.LEFT
				return
			profile = DeviceProfile.new()
			profile.guid = Input.get_joy_guid(device)
			profile.name = Input.get_joy_name(device)
			profile.kind = DeviceProfile.Kind.WHEEL
			profile.steer_axis = a
			profile.steer_left = _left[a]
			profile.steer_right = axes[a]
			profile.steer_center = _rest[a]
			step = Step.GAS
		Step.GAS:
			var a := _most_moved(_rest, axes, [profile.steer_axis])
			if absf(axes[a] - _rest[a]) < MIN_MOVE:
				message = "Didn't see a pedal move. Press the gas fully."
				return
			profile.throttle_axis = a
			profile.throttle_rest = _rest[a]
			profile.throttle_full = axes[a]
			step = Step.BRAKE
		Step.BRAKE:
			var a := _most_moved(_rest, axes, [profile.steer_axis])
			var moved := axes[a] - _rest[a]
			if absf(moved) < MIN_MOVE:
				message = "Didn't see a pedal move. Press the brake fully."
				return
			if a == profile.throttle_axis and signf(moved) == signf(profile.throttle_full - profile.throttle_rest):
				message = "That looks like the gas pedal again. Press the BRAKE."
				return
			profile.brake_axis = a
			profile.brake_rest = _rest[a]
			profile.brake_full = axes[a]
			profile.combined_pedals = a == profile.throttle_axis
			step = Step.NITRO


func _most_moved(from: PackedFloat32Array, to: PackedFloat32Array, skip: Array) -> int:
	var best := 0
	var best_d := -1.0
	for a in mini(from.size(), to.size()):
		if skip.has(a):
			continue
		var d := absf(to[a] - from[a])
		if d > best_d:
			best_d = d
			best = a
	return best


func _draw() -> void:
	draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(0.02, 0.03, 0.08, 0.9))
	var joy_name := Input.get_joy_name(device) if device >= 0 else "-"
	_text(Vector2(20, 30), "WHEEL CALIBRATION", 20, Color("#ffd23a"))
	_text(Vector2(20, 48), joy_name.left(60), 10, Color("#7ad8ff"))
	var steps := ["Rest", "Left", "Right", "Gas", "Brake", "Nitro"]
	for i in steps.size():
		var reached := step >= i + 1
		_text(Vector2(20 + i * 70, 72), steps[i], 10, Color.WHITE if reached else Color(1, 1, 1, 0.35))
	var lines: PackedStringArray = INSTRUCTIONS[step].split("\n")
	for i in lines.size():
		_text(Vector2(20, 104 + i * 18), lines[i], 13, Color.WHITE)
	if message != "":
		_text(Vector2(20, 150), message, 11, Color("#ff7a5a"))
	if device >= 0:
		var axes := InputRouter.raw_axes(device)
		for a in axes.size():
			var r := Rect2(20 + (a % 5) * 122, 176 + (a / 5) * 26, 100, 8)
			_text(r.position + Vector2(0, -3), "axis %d  %.2f" % [a, axes[a]], 8, Color(1, 1, 1, 0.75))
			draw_rect(r, Color(1, 1, 1, 0.12))
			var mid := r.position.x + r.size.x / 2.0
			draw_rect(Rect2(minf(mid, mid + axes[a] * 50.0), r.position.y, absf(axes[a]) * 50.0, r.size.y), Color("#3ad0ff"))
		_text(Vector2(20, 246), "buttons: " + str(InputRouter.pressed_buttons(device)), 9, Color(1, 1, 1, 0.75))
	_text(Vector2(20, Cfg.SCREEN_H - 16), "Enter or any wheel button: next      Esc: cancel", 10, Color(1, 1, 1, 0.6))


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
