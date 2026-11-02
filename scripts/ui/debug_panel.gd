class_name DebugPanel
extends Control
## F3 (EQ-16): the tuning panel over the race or the menus. Its logic is TuningPanel; this
## draws it, feeds it the menu input and carries its actions out on the race. The race stands
## still while it is up. Like the F1 overlay, the game makes one for the menus and the races
## it starts; a race run on its own makes its own.

const ROW_H := 14.0
const TOP := 34.0
const VISIBLE_ROWS := 19
const ACCENT := Color("#ffd23a")
const TUNED := Color("#ff9a3a")

var logic := TuningPanel.new()
var race: Node  # the race under it, or null in the menus
var _font: Font
var _scroll := 0


## Hidden from the start, not only once in the tree: a game or race built outside it (tests)
## would otherwise stand still under a panel nobody opened.
func _init() -> void:
	visible = false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(page := -1) -> void:
	if page >= 0:
		logic.page = page
		logic.row = 0
	logic.context = context_of(race)
	logic.segments = 1 if race == null or race.track == null else race.track.segments.size()
	visible = true


func close() -> void:
	logic.settle()
	logic.typing = false
	visible = false


## Where a change is made, for the tuning log: the stage, car and race time, or the menus.
static func context_of(r: Node) -> String:
	if r == null or r.track == null:
		return "menus"
	return "stage %d %s%s, %s, %.1f s" % [r.stage_index + 1, r.track.name, " (mirror)" if r.mirror else "", r.car_id, r.race_time]


## The page named `name` (a Tuning area, "actions" or "presets"), or -1.
static func page_named(name: String) -> int:
	return TuningPanel.PAGES.find(name)


func _physics_process(dt: float) -> void:
	if not visible:
		return
	var action := logic.tick(InputRouter.menu, dt)
	if action != TuningPanel.Action.NONE and race != null:
		race.debug_action(action, logic)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		close() if visible else open()
		get_viewport().set_input_as_handled()
		return
	if not visible or not logic.typing or not (event is InputEventKey and event.pressed):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_BACKSPACE:
			logic.type_key("", true)
		KEY_ENTER, KEY_KP_ENTER:
			logic.type_key("", false, true)
		KEY_ESCAPE:
			logic.type_key("", false, false, true)
		_:
			if k.unicode > 32:
				logic.type_key(char(k.unicode))
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(0, 0, 0, 0.8))
	var tuned := Tuning.overrides().size()
	_line(Vector2(8, 14), "TUNING  (F3 close)   up/down pick   left/right nudge, held faster   Enter: default", ACCENT)
	_line(Vector2(8, 26), "%d tuned%s   %s" % [tuned, "" if Tuning.path == "" else "   saved to " + Tuning.path, logic.context], Color(1, 1, 1, 0.6))
	var rows := logic.rows()
	_scroll = clampi(_scroll, maxi(0, logic.row - VISIBLE_ROWS + 1), logic.row)
	for i in range(_scroll, mini(rows.size(), _scroll + VISIBLE_ROWS)):
		var y := TOP + (i - _scroll) * ROW_H
		if i == logic.row:
			draw_rect(Rect2(4, y, Cfg.SCREEN_W - 8, ROW_H - 1), Color(1, 1, 1, 0.14))
		_row(rows[i], i, y + 10)
	var foot := Cfg.SCREEN_H - 10.0
	var key := logic.picked_key()
	if key != "":
		_line(Vector2(8, foot - 12), Tuning.help(key), Color(1, 1, 1, 0.75))
		_line(Vector2(8, foot), "default %s   range %s to %s   step %s" % [Tuning.text(key, Tuning.default_of(key)),
			Tuning.text(key, Tuning.min_of(key)), Tuning.text(key, Tuning.max_of(key)), Tuning.text(key, Tuning.step_of(key))], Color(1, 1, 1, 0.5))
	elif logic.message != "":
		_line(Vector2(8, foot), logic.message, Color("#5dff8a"))


func _row(kind: int, i: int, y: float) -> void:
	var label := ""
	var value := ""
	var col := Color.WHITE
	match kind:
		TuningPanel.Row.PAGE:
			label = "PAGE"
			value = "<  %s  >   %d / %d" % [TuningPanel.PAGE_NAMES[logic.page], logic.page + 1, TuningPanel.PAGES.size()]
			col = ACCENT
		TuningPanel.Row.VALUE:
			var key := logic.key_at(i)
			label = key.get_slice("/", 1)
			value = Tuning.text(key, Tuning.v(key))
			if Tuning.tuned(key):
				col = TUNED
				value += "   (was %s)" % Tuning.text(key, Tuning.default_of(key))
		TuningPanel.Row.SLOW_MOTION:
			label = "slow motion"
			value = "<  %sx  >" % str(logic.slow_motion())
		TuningPanel.Row.JUMP:
			label = "jump to segment"
			value = "<  %d  >   Enter: go" % logic.jump_to
		TuningPanel.Row.GIVE:
			label = "give power-up"
			value = "<  %s  >   Enter: give" % PowerUps.IDS[TuningPanel.GIVE_KINDS[logic.give]].to_upper()
		TuningPanel.Row.CLOCK:
			label = "set the clock"
			value = "<  %d s  >   Enter: set" % logic.clock
		TuningPanel.Row.BURST:
			label = "traffic burst"
			value = "<  %d cars  >   Enter: send" % logic.burst
		TuningPanel.Row.RESET_ALL:
			label = "reset all"
			value = "Enter: every value back to its default"
		TuningPanel.Row.SAVE:
			label = "save preset"
			value = ("name: " + logic.name_text + "_   Enter: save   Esc: cancel") if logic.typing else "Enter: type a name"
		TuningPanel.Row.LOAD:
			label = "load preset"
			var names := Tuning.presets()
			value = "(none saved)" if names.is_empty() else "<  %s  >   Enter: load" % names[logic.load_pick % names.size()]
	if race == null and kind in TuningPanel.ACTION_ROWS:
		col = Color(1, 1, 1, 0.4)  # (they need a race)
	_line(Vector2(12, y), label, col)
	_line(Vector2(220, y), value, col)


func _line(pos: Vector2, text: String, col: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
