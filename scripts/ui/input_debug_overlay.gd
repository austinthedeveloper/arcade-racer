class_name InputDebugOverlay
extends Control
## F1 overlay: every joypad with its raw axes and buttons, plus the resulting DriveInput.
## Makes "my wheel doesn't work" reports diagnosable. Delete resets the active device's profile.

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_DELETE:
		if InputRouter.last_active_device >= 0:
			InputRouter.reset_profile(InputRouter.last_active_device)


func _draw() -> void:
	draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(0, 0, 0, 0.78))
	var y := 14.0
	_line(Vector2(8, y), "INPUT DEBUG  (F1 close, Delete resets the active device's profile)", Color("#ffd23a"))
	y += 14
	var s: DriveInput = InputRouter.state
	_line(Vector2(8, y), "Active: %s  (%s)" % [["Keyboard", "Gamepad", "Wheel"][s.kind], s.device_name], Color.WHITE)
	y += 12
	_bar(Vector2(8, y), "steer", s.steer, true)
	_bar(Vector2(218, y), "gas", s.throttle, false)
	_bar(Vector2(428, y), "brake", s.brake, false)
	y += 18

	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_line(Vector2(8, y), "No joypads connected. Plug in a gamepad or wheel.", Color(1, 1, 1, 0.7))
	for device in pads:
		var prof: DeviceProfile = InputRouter.get_profile(device)
		var kind := "WHEEL" if prof.kind == DeviceProfile.Kind.WHEEL else "GAMEPAD"
		var cal := "calibrated" if prof.calibrated else ("NOT CALIBRATED (F2)" if prof.kind == DeviceProfile.Kind.WHEEL else "default mapping")
		_line(Vector2(8, y), "#%d  %s  [%s, %s]" % [device, Input.get_joy_name(device).left(40), kind, cal], Color("#7ad8ff"))
		y += 11
		_line(Vector2(8, y), "guid " + Input.get_joy_guid(device), Color(1, 1, 1, 0.5))
		y += 11
		var axes := InputRouter.raw_axes(device)
		for a in axes.size():
			var col := a % 5
			var row := a / 5
			var tag := ""
			if prof.kind == DeviceProfile.Kind.WHEEL:
				if a == prof.steer_axis:
					tag = " steer"
				elif a == prof.throttle_axis:
					tag = " gas"
				elif a == prof.brake_axis:
					tag = " brake"
			_bar(Vector2(8 + col * 126, y + row * 14), "a%d%s" % [a, tag], axes[a], true, 60)
		y += 30
		var pressed := InputRouter.pressed_buttons(device)
		_line(Vector2(8, y), "buttons: " + (str(pressed) if not pressed.is_empty() else "-"), Color.WHITE)
		y += 16
		if y > Cfg.SCREEN_H - 20:
			break


func _line(pos: Vector2, text: String, col: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)


func _bar(pos: Vector2, label: String, v: float, signed: bool, width: float = 120.0) -> void:
	_line(pos + Vector2(0, 8), label, Color(1, 1, 1, 0.8))
	var r := Rect2(pos.x + 52, pos.y, width, 8)
	draw_rect(r, Color(1, 1, 1, 0.15))
	if signed:
		var mid := r.position.x + r.size.x / 2.0
		draw_rect(Rect2(minf(mid, mid + v * r.size.x / 2.0), r.position.y, absf(v) * r.size.x / 2.0, r.size.y), Color("#3ad0ff"))
		draw_rect(Rect2(mid, r.position.y - 1, 1, r.size.y + 2), Color.WHITE)
	else:
		draw_rect(Rect2(r.position, Vector2(clampf(v, 0.0, 1.0) * r.size.x, r.size.y)), Color("#7aff8a"))
	_line(Vector2(r.end.x + 3, pos.y + 8), "%.2f" % v, Color(1, 1, 1, 0.7))
