class_name TuningPanel
extends RefCounted
## The debug panel's logic (EQ-16), apart from its drawing (DebugPanel): a page per Tuning
## area, then ACTIONS and PRESETS. The top row of every page flips pages with left and right;
## on a value, left and right nudge it by its step (held, faster) and confirm puts it back to
## its default. A change applies at once, is saved to Tuning.path and is logged with where it
## happened (`context`). Actions are handed back from `tick` for the race to carry out.

enum Action { NONE, JUMP, GIVE, CLOCK, BURST }
enum Row { PAGE, VALUE, SLOW_MOTION, JUMP, GIVE, CLOCK, BURST, RESET_ALL, SAVE, LOAD }

const PAGES := Tuning.AREAS + ["actions", "presets"]
const PAGE_NAMES := Tuning.AREA_NAMES + ["ACTIONS", "PRESETS"]
const ACTION_ROWS := [Row.SLOW_MOTION, Row.JUMP, Row.GIVE, Row.CLOCK, Row.BURST]
const PRESET_ROWS := [Row.RESET_ALL, Row.SAVE, Row.LOAD]
const SLOW_MOTION := [1.0, 0.5, 0.25, 0.1]
const GIVE_KINDS := [PowerUps.Kind.NITRO, PowerUps.Kind.CLOCK, PowerUps.Kind.RAM, PowerUps.Kind.GHOST]
## Held left or right: after FAST_AFTER seconds each repeat is FAST steps, after FASTER_AFTER
## FASTER steps.
const FAST_AFTER := 1.0
const FAST := 5
const FASTER_AFTER := 2.5
const FASTER := 25
const JUMP_STEP := 25  # segments per nudge of JUMP TO SEGMENT
const CLOCK_STEP := 5.0  # seconds per nudge of SET CLOCK
const BURST_STEP := 5  # cars per nudge of TRAFFIC BURST

var page := 0
var row := 0
var slow := 0  # into SLOW_MOTION
var jump_to := 0  # segment
var segments := 1  # the race's track length in segments (for JUMP), 1 in the menus
var give := 0  # into GIVE_KINDS
var clock := 30.0
var burst := 20
var load_pick := 0  # into Tuning.presets()
var name_text := ""  # SAVE: the preset name being typed
var typing := false
var message := ""  # the last thing done, under the rows
## Where changes happen, for the log: "stage 1 Palm Coast, car_vega, 32.4 s", or "menus".
var context := "menus"
var _held := 0.0  # seconds left or right has been held
var _swallow := 0  # ticks to ignore: the Enter that ended typing is still a confirm press
var _pending := {}  # the change being nudged: key, from, to (logged once it settles)


## The rows of the page showing: PAGE first, then its values or actions.
func rows() -> Array:
	var out: Array = [Row.PAGE]
	match PAGES[page]:
		"actions":
			out.append_array(ACTION_ROWS)
		"presets":
			out.append_array(PRESET_ROWS)
		_:
			for k in Tuning.keys_in(PAGES[page]):
				out.append(Row.VALUE)
	return out


## The Tuning key on `r` of this page ("" for a row that isn't a value).
func key_at(r: int) -> String:
	if PAGES[page] == "actions" or PAGES[page] == "presets" or r < 1:
		return ""
	var keys := Tuning.keys_in(PAGES[page])
	return keys[r - 1] if r - 1 < keys.size() else ""


func picked_key() -> String:
	return key_at(row)


func slow_motion() -> float:
	return SLOW_MOTION[slow]


## One tick of menu input. Returns an Action for the race (and leaves its value in the
## panel: jump_to, GIVE_KINDS[give], clock, burst), or NONE.
func tick(m: MenuInput, dt: float) -> int:
	if typing:
		return Action.NONE
	if _swallow > 0:
		_swallow -= 1
		return Action.NONE
	if absf(m.x) >= MenuInput.PUSH:
		_held += dt
	else:
		_held = 0.0
	var n := rows().size()
	if m.step_y() != 0:
		settle()
		row = posmod(row + m.step_y(), n)
		Audio.play("tick")
	var dir := m.step()
	if dir != 0:
		_nudge(dir, times())
	if m.confirm_pressed:
		return _confirm()
	return Action.NONE


## Steps per press while left or right is held this long.
func times() -> int:
	if _held >= FASTER_AFTER:
		return FASTER
	return FAST if _held >= FAST_AFTER else 1


func _nudge(dir: int, n: int) -> void:
	var r: int = rows()[row]
	match r:
		Row.PAGE:
			settle()
			page = posmod(page + dir, PAGES.size())
			row = 0
		Row.VALUE:
			var key := picked_key()
			var was := Tuning.v(key)
			var now := Tuning.nudge(key, dir, n)
			if now != was:
				if _pending.get("key", "") != key:
					settle()
					_pending = {"key": key, "from": was}
				_pending["to"] = now
				Tuning.save()
		Row.SLOW_MOTION:
			slow = clampi(slow + dir, 0, SLOW_MOTION.size() - 1)
		Row.JUMP:
			jump_to = posmod(jump_to + dir * JUMP_STEP * n, maxi(segments, 1))
		Row.GIVE:
			give = posmod(give + dir, GIVE_KINDS.size())
		Row.CLOCK:
			clock = clampf(clock + dir * CLOCK_STEP * n, 0.0, 999.0)
		Row.BURST:
			burst = clampi(burst + dir * BURST_STEP * n, BURST_STEP, 200)
		Row.LOAD:
			var names := Tuning.presets()
			load_pick = posmod(load_pick + dir, maxi(names.size(), 1))
	Audio.play("tick")


func _confirm() -> int:
	Audio.play("beep")
	match rows()[row]:
		Row.VALUE:
			reset(picked_key())
		Row.JUMP:
			message = "Jumped to segment %d" % jump_to
			_log("jump to segment %d" % jump_to)
			return Action.JUMP
		Row.GIVE:
			message = "Gave a power-up"
			_log("give %s" % PowerUps.IDS[GIVE_KINDS[give]])
			return Action.GIVE
		Row.CLOCK:
			message = "Clock set to %d s" % clock
			_log("clock %d" % clock)
			return Action.CLOCK
		Row.BURST:
			message = "%d more cars ahead" % burst
			_log("traffic burst %d" % burst)
			return Action.BURST
		Row.RESET_ALL:
			reset_all()
		Row.SAVE:
			typing = true
			name_text = ""
		Row.LOAD:
			var names := Tuning.presets()
			if not names.is_empty():
				load_preset(names[load_pick % names.size()])
	return Action.NONE


## Puts one value back to its default.
func reset(key: String) -> void:
	settle()
	var was := Tuning.v(key)
	Tuning.reset(key)
	Tuning.save()
	if was != Tuning.v(key):
		_log("%s %s -> %s (reset)" % [key, Tuning.text(key, was), Tuning.text(key, Tuning.v(key))])
	message = key + " reset"


func reset_all() -> void:
	settle()
	var n := Tuning.overrides().size()
	Tuning.reset_all()
	Tuning.save()
	_log("reset all (%d values)" % n)
	message = "All values reset"


## Typing a preset name: a character, or Backspace (`backspace`), Enter (`done`) or Escape
## (`cancel`). Enter saves the overrides under the name.
func type_key(ch: String, backspace := false, done := false, cancel := false) -> void:
	if cancel or done:
		_swallow = 1
	if cancel:
		typing = false
	elif done:
		typing = false
		settle()
		if Tuning.save_preset(name_text):
			_log("saved preset %s" % name_text)
			message = "Saved preset " + name_text
		else:
			message = "Not saved: give it a name"
	elif backspace:
		name_text = name_text.left(-1)
	elif ch != "" and name_text.length() < 24:
		name_text += ch


func load_preset(name: String) -> void:
	settle()
	if Tuning.load_preset(name):
		Tuning.save()
		_log("loaded preset %s (%d values)" % [name, Tuning.overrides().size()])
		message = "Loaded preset " + name
	else:
		message = "Couldn't read preset " + name


## Logs the change being nudged, if any (moving off it, another change, closing the panel).
func settle() -> void:
	if _pending.is_empty():
		return
	var key: String = _pending["key"]
	var from: float = _pending["from"]
	_pending = {}
	if Tuning.v(key) != from:
		_log("%s %s -> %s" % [key, Tuning.text(key, from), Tuning.text(key, Tuning.v(key))])


func _log(what: String) -> void:
	Tuning.log_change(context + "  " + what)
