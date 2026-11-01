class_name TouchControls
extends CanvasLayer
## Autoload (Touch). On-screen controls for a touchscreen (ON-4, ON-5): the Web build on a
## phone or tablet, or a touch laptop. Racing: steer left and right under the left thumb,
## gas, brake and nitro under the right, pause at the top. Everywhere else (menus, the pause
## menu, the results): a D-pad, OK and BACK. Each button holds an InputMap action down, as
## its key would (Input.action_press), so InputRouter, the menus and the race need nothing of
## their own. Multi-touch: every finger holds its own button, and a finger sliding off one
## onto another moves with it (steering from left to right without lifting).
##
## They show at the first touch (from the start on a phone's browser, or with --touch) and
## hide on a key or a pad button.

enum Layout { RACE, MENU }

const ALPHA := 0.32  # a button at rest
const HELD_ALPHA := 0.62
const FILL := Color("#0b1020")
const EDGE := Color("#c9d4ff")
const LIT := Color("#ffd23a")

## Each layout's buttons: id, where (640x360), the action it holds, its label.
const RACE_BUTTONS := [
	{"id": "left", "rect": Rect2(8, 228, 86, 124), "action": "steer_left", "label": "<"},
	{"id": "right", "rect": Rect2(100, 228, 86, 124), "action": "steer_right", "label": ">"},
	{"id": "gas", "rect": Rect2(546, 220, 86, 132), "action": "accelerate", "label": "GAS"},
	{"id": "brake", "rect": Rect2(454, 276, 86, 76), "action": "brake", "label": "BRAKE"},
	{"id": "nitro", "rect": Rect2(454, 220, 86, 50), "action": "nitro", "label": "NITRO"},
	{"id": "pause", "rect": Rect2(118, 6, 40, 26), "action": "pause", "label": "II"},
]
const MENU_BUTTONS := [
	{"id": "up", "rect": Rect2(60, 214, 48, 46), "action": "accelerate", "label": "^"},
	{"id": "down", "rect": Rect2(60, 304, 48, 46), "action": "brake", "label": "v"},
	{"id": "left", "rect": Rect2(10, 259, 48, 46), "action": "steer_left", "label": "<"},
	{"id": "right", "rect": Rect2(110, 259, 48, 46), "action": "steer_right", "label": ">"},
	{"id": "ok", "rect": Rect2(556, 262, 76, 66), "action": "confirm", "label": "OK"},
	{"id": "back", "rect": Rect2(478, 284, 70, 44), "action": "back", "label": "BACK"},
]

var shown := false
## The race on now (race.gd sets it): racing, it shows the driving layout.
var race: Node
var _fingers := {}  # touch index -> the button id it holds ("" for none)
var _held := {}  # actions this layer is holding down
var _layout := Layout.MENU
var _font: Font


func _ready() -> void:
	layer = 20  # over the menus, the race's HUD and the pause menu
	_font = ThemeDB.fallback_font
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_on.bind(c))
	add_child(c)
	shown = DevArgs.has("--touch") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func buttons(layout: Layout) -> Array:
	return RACE_BUTTONS if layout == Layout.RACE else MENU_BUTTONS


## The button under `pos` in `layout`, or "".
static func hit(layout: Layout, pos: Vector2) -> String:
	for b: Dictionary in buttons(layout):
		if (b["rect"] as Rect2).grow(4.0).has_point(pos):
			return b["id"]
	return ""


## The layout for now: driving while a race runs uncovered, the menu one otherwise.
func layout_now() -> Layout:
	if race != null and is_instance_valid(race) and race.is_inside_tree() and race.touch_driving():
		return Layout.RACE
	return Layout.MENU


## A finger down (or up) at `pos`.
func touch(finger: int, pos: Vector2, down: bool) -> void:
	if down:
		shown = true
		_fingers[finger] = hit(_layout, pos)
	else:
		_fingers.erase(finger)
	_apply()


## A finger moving: it holds whatever it's over now.
func drag(finger: int, pos: Vector2) -> void:
	if _fingers.has(finger):
		_fingers[finger] = hit(_layout, pos)
		_apply()


## The actions the fingers are holding.
func held_actions() -> Dictionary:
	var out := {}
	for id: String in _fingers.values():
		for b: Dictionary in buttons(_layout):
			if b["id"] == id:
				out[b["action"]] = true
	return out


## Lets go of everything (a layout change, the controls hiding).
func release_all() -> void:
	_fingers.clear()
	_apply()


func _apply() -> void:
	var want := held_actions()
	for a: String in _held.keys():
		if not want.has(a):
			Input.action_release(a)
			_held.erase(a)
	for a: String in want:
		if not _held.has(a):
			Input.action_press(a)
			_held[a] = true


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		touch(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		drag(d.index, d.position)
	elif shown and (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		shown = false  # a keyboard or pad in use: out of the way
		release_all()


func _process(_dt: float) -> void:
	var now := layout_now()
	if now != _layout:
		_layout = now
		release_all()
	(get_child(0) as Control).queue_redraw()


func _draw_on(c: Control) -> void:
	if not shown:
		return
	var held := {}
	for id: String in _fingers.values():
		held[id] = true
	for b: Dictionary in buttons(_layout):
		var r: Rect2 = b["rect"]
		var on: bool = held.has(b["id"])
		c.draw_rect(r, Color(FILL, HELD_ALPHA if on else ALPHA))
		c.draw_rect(r, Color(LIT if on else EDGE, 0.75 if on else 0.45), false, 2.0)
		var label: String = b["label"]
		var size := 22 if label.length() <= 2 else 11
		var col := Color(LIT if on else Color.WHITE, 0.95 if on else 0.7)
		match label:
			"<", ">", "^", "v":
				_chevron(c, r.get_center(), label, col)
			_:
				var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				c.draw_string(_font, r.get_center() + Vector2(-tw / 2.0, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A filled arrowhead pointing the way `label` says.
static func _chevron(c: Control, at: Vector2, label: String, col: Color) -> void:
	var dir: Vector2 = {"<": Vector2.LEFT, ">": Vector2.RIGHT, "^": Vector2.UP, "v": Vector2.DOWN}[label]
	var side := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([at + dir * 12, at - dir * 8 + side * 12, at - dir * 8 - side * 12]), col)
