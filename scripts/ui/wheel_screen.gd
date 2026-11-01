class_name WheelScreen
extends MenuScreen
## Controls > WHEEL SETTINGS: each wheel's hardware range, steering lock, deadzone and
## linearity (DeviceProfile), saved to its profile (InputRouter.save_profile) on every
## change. The top row picks the wheel: the connected ones, then saved ones not plugged in.
## Beside the rows, the steering curve those four make, with the wheel's live position.
## Controls as on the Options screen: up/down picks a row, left/right changes it, confirm
## cycles it; a wheel uses its D-pad and A button, as a pad does.

enum Row { DEVICE, RANGE, LOCK, DEADZONE, LINEARITY, RESET, BACK }

const LABELS := ["WHEEL", "WHEEL RANGE", "STEERING LOCK", "DEADZONE", "LINEARITY", "RESET TO DEFAULTS", "BACK"]
const HELP := [
	"Pick the wheel to set up.",
	"How far the wheel turns, lock to lock. Match the wheel's own setting.",
	"How much of that turn steers fully. Less is quicker.",
	"How far from center the wheel turns before the car steers.",
	"1.0 steers in step with the wheel. More is gentler near center.",
	"This wheel's range, lock, deadzone and linearity back to their defaults.",
	"Back to the options.",
]
const NO_WHEEL := "No wheel yet. Plug one in, or calibrate it (F2), to set it up here."
const CURVE_SAMPLES := 32
const NAME_CHARS := 34  # the wheel's name fits the row in this many
const ROW_H := 20.0
const TOP := 56.0

var device_index := 0  # into InputRouter.wheel_profiles()


func _init() -> void:
	index = Row.RANGE  # opens on the first setting


func choice_count() -> int:
	return Row.size()


func row() -> int:
	return index


## The wheel being set up, or null when there is none.
func profile() -> DeviceProfile:
	var list := InputRouter.wheel_profiles()
	if list.is_empty():
		return null
	return list[clampi(device_index, 0, list.size() - 1)]


func device_name() -> String:
	var p := profile()
	if p == null:
		return "NO WHEEL FOUND"
	var n := (p.name if p.name != "" else "WHEEL").to_upper()
	var tag := "" if InputRouter.device_for(p.guid) >= 0 else " (UNPLUGGED)"
	return n.substr(0, NAME_CHARS - tag.length()).strip_edges() + tag


func flip_device(dir: int) -> void:
	device_index = posmod(device_index + dir, maxi(1, InputRouter.wheel_profiles().size()))


## Changes `r` by `dir` on the wheel being set up and saves it. `wrap` (confirm) cycles
## round; left/right stops at the ends. Returns false when nothing changed.
func change(r: int, dir: int, wrap: bool) -> bool:
	var p := profile()
	if p == null:
		return false
	match r:
		Row.RANGE:
			p.step_range(dir, wrap)
		Row.LOCK:
			p.step_lock(dir, wrap)
		Row.DEADZONE:
			p.step_deadzone(dir, wrap)
		Row.LINEARITY:
			p.step_gamma(dir, wrap)
		Row.RESET:
			p.reset_steering()
		_:
			return false
	InputRouter.save_profile(p)
	return true


## What a row shows on the right.
static func value_text(p: DeviceProfile, r: int) -> String:
	if p == null:
		return "---"
	match r:
		Row.RANGE:
			return "%d°" % roundi(p.hardware_range_deg)
		Row.LOCK:
			return "%d°" % roundi(p.lock_deg)
		Row.DEADZONE:
			return percent(p.steer_deadzone)
		Row.LINEARITY:
			return "%.1f" % p.steer_gamma
	return ""


## A fraction as a percentage: "2%", or "1.5%" when it isn't whole.
static func percent(v: float) -> String:
	var pc := snappedf(v * 100.0, 0.1)
	return ("%d%%" % roundi(pc)) if is_equal_approx(pc, roundf(pc)) else ("%.1f%%" % pc)


## The steering curve for `p` over one side of the wheel: points (degrees from center,
## steering 0..1) from center to the hardware's end.
static func curve(p: DeviceProfile, samples := CURVE_SAMPLES) -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := p.hardware_range_deg / 2.0
	for i in samples + 1:
		var deg := half * i / samples
		out.append(Vector2(deg, p.steer_at(deg)))
	return out


func handle(m: MenuInput) -> void:
	var wheel := OptionsScreen.steer_driven()
	var pick := m.step() if wheel else m.step_y()
	if pick != 0:
		move(pick)
		Audio.play("tick")
	elif not wheel and m.step() != 0:
		if row() == Row.DEVICE:
			flip_device(m.step())
			Audio.play("tick")
		elif row() != Row.RESET and change(row(), m.step(), false):
			Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		match row():
			Row.DEVICE:
				flip_device(1)
			Row.BACK:
				game.close_wheel()
			_:
				change(row(), 1, true)
	elif m.back_pressed:
		game.close_wheel()


func help_text() -> String:
	if profile() == null and row() != Row.BACK:
		return NO_WHEEL
	return HELP[row()]


func _draw() -> void:
	_backdrop(0.8)
	_header("WHEEL")
	var panel := Rect2(40, TOP - 6, 340, ROW_H * Row.size() + 12)
	_panel(panel, 0.85)
	var p := profile()
	var wheel := OptionsScreen.steer_driven()
	var mid := ROW_H / 2.0 - 2.0
	var right := panel.end.x - 20
	for r in Row.size():
		var y := TOP + r * ROW_H
		var on := r == index
		if on:
			draw_rect(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(panel.position.x, y, 3, ROW_H - 4), GOLD)
		var col := GOLD if on else Color.WHITE
		if r == Row.DEVICE:
			_text_centered(Vector2(panel.get_center().x, y + mid + 5), device_name(), 12, SKY)
			if on and not wheel and p != null:
				_small_arrow(Vector2(panel.position.x + 14, y + mid), -1)
				_small_arrow(Vector2(right + 6, y + mid), 1)
			continue
		_text(Vector2(panel.position.x + 16, y + mid + 5), LABELS[r], 12, col)
		var t := value_text(p, r)
		if t != "":
			_text_centered(Vector2(right - 40, y + mid + 5), t, 12, col)
			if on and not wheel and p != null:
				_small_arrow(Vector2(right - 80, y + mid), -1)
				_small_arrow(Vector2(right, y + mid), 1)
	if p != null:
		_curve_box(Rect2(400, TOP - 6, 200, ROW_H * Row.size() + 12), p)
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, panel.end.y + 20), help_text(), 10, Color(1, 1, 1, 0.85))
	_footer(OptionsScreen.options_hints())


## The steering curve in `r`: wheel angle across, steering up, the lock marked, and the
## wheel's live position when it's plugged in.
func _curve_box(r: Rect2, p: DeviceProfile) -> void:
	_panel(r, 0.85)
	var plot := Rect2(r.position + Vector2(14, 22), r.size - Vector2(28, 50))
	_text(Vector2(r.position.x + 8, r.position.y + 14), "STEERING", 9, Color(1, 1, 1, 0.7))
	draw_rect(plot, Color(1, 1, 1, 0.05))
	draw_line(plot.position + Vector2(0, plot.size.y), plot.end, Color(1, 1, 1, 0.4))
	draw_line(plot.position, plot.position + Vector2(0, plot.size.y), Color(1, 1, 1, 0.4))
	var half := p.hardware_range_deg / 2.0
	var at := func(pt: Vector2) -> Vector2:
		return Vector2(plot.position.x + plot.size.x * pt.x / half, plot.end.y - plot.size.y * pt.y)
	var lock_x: float = at.call(Vector2(p.lock_deg / 2.0, 0.0)).x
	draw_line(Vector2(lock_x, plot.position.y), Vector2(lock_x, plot.end.y), Color(GOLD, 0.5))
	_text_centered(Vector2(lock_x, plot.end.y + 11), "%d°" % roundi(p.lock_deg / 2.0), 9, GOLD)
	_text(Vector2(plot.end.x - 22, plot.end.y + 11), "%d°" % roundi(half), 9, Color(1, 1, 1, 0.6))
	var pts := PackedVector2Array()
	for pt in curve(p):
		pts.append(at.call(pt))
	draw_polyline(pts, SKY, 2.0)
	var d := InputRouter.device_for(p.guid)
	if d >= 0:
		var turn := absf(p.wheel_turn(Input.get_joy_axis(d, p.steer_axis)))
		var deg := minf(turn, 1.0) * half
		var dot: Vector2 = at.call(Vector2(deg, absf(p.steer_at(deg))))
		draw_circle(dot, 3.0, GOLD)
	_text_centered(Vector2(r.get_center().x, r.end.y - 6), "WHEEL ANGLE", 9, Color(1, 1, 1, 0.7))


func _small_arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -6), c + Vector2(-4 * d, 6)]), GOLD)
