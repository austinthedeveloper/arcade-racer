class_name PadGlyphs
extends RefCounted
## Button glyphs (WH-14): the hints, the remap screen and the controls card show a pad's or a
## wheel's buttons as small pictures, drawn here in code, of the family the device's name says
## (family_for): Xbox's coloured A/B/X/Y, PlayStation's cross, circle, square and triangle, a
## generic pad's face buttons by where they sit, a wheel's buttons as labelled tabs. The
## keyboard, and any key or word without a glyph, stays text (pieces leaves it as it was).
## `--pad-family=xbox|playstation|generic|wheel` forces a family, for screenshots (forced).

enum Family { NONE, XBOX, PLAYSTATION, GENERIC, WHEEL }

const FAMILY_NAMES := {"xbox": Family.XBOX, "playstation": Family.PLAYSTATION, "generic": Family.GENERIC, "wheel": Family.WHEEL}
## A made-up device of each family, for a screenshot that forces one (InputRouter.staged).
const SAMPLE_NAMES := {
	Family.XBOX: "Xbox Wireless Controller", Family.PLAYSTATION: "DualSense Wireless Controller",
	Family.GENERIC: "USB Gamepad", Family.WHEEL: "Thrustmaster TMX Racing Wheel",
}
const XBOX_HINTS := ["xbox", "xinput", "x-box", "microsoft"]
const PLAYSTATION_HINTS := ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]

## Codes past the joypad buttons for what isn't a button: the triggers and sticks, and the
## whole D-pad (or its two axes).
const TRIGGER_LEFT := 200
const TRIGGER_RIGHT := 201
const STICK_LEFT := 202
const DPAD := 203
const DPAD_UP_DOWN := 204
const DPAD_LEFT_RIGHT := 205

enum Shape { FACE, SHOULDER, TRIGGER, PILL, STICK, DPAD, TAB }

## The words hints and labels name pad inputs with (any case) -> code.
const WORDS := {
	"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
	"START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK, "GUIDE": JOY_BUTTON_GUIDE,
	"LB": JOY_BUTTON_LEFT_SHOULDER, "RB": JOY_BUTTON_RIGHT_SHOULDER, "LT": TRIGGER_LEFT, "RT": TRIGGER_RIGHT,
	"L3": JOY_BUTTON_LEFT_STICK, "R3": JOY_BUTTON_RIGHT_STICK, "LEFT STICK": STICK_LEFT,
	"D-PAD": DPAD, "D-PAD UP": JOY_BUTTON_DPAD_UP, "D-PAD DOWN": JOY_BUTTON_DPAD_DOWN,
	"D-PAD LEFT": JOY_BUTTON_DPAD_LEFT, "D-PAD RIGHT": JOY_BUTTON_DPAD_RIGHT,
	"UP": JOY_BUTTON_DPAD_UP, "DOWN": JOY_BUTTON_DPAD_DOWN, "LEFT": JOY_BUTTON_DPAD_LEFT, "RIGHT": JOY_BUTTON_DPAD_RIGHT,
}
const XBOX_FACE := {
	JOY_BUTTON_A: ["A", Color("#5fd35a")], JOY_BUTTON_B: ["B", Color("#ff5d5d")],
	JOY_BUTTON_X: ["X", Color("#4aa8ff")], JOY_BUTTON_Y: ["Y", Color("#ffd23a")],
}
const PS_FACE := {
	JOY_BUTTON_A: ["cross", Color("#7aa8ff")], JOY_BUTTON_B: ["circle", Color("#ff6a6a")],
	JOY_BUTTON_X: ["square", Color("#ff8ad8")], JOY_BUTTON_Y: ["triangle", Color("#4fe0b0")],
}
## A generic pad's face buttons by where they sit in the diamond: bottom, right, left, top.
const POSITIONS := {
	JOY_BUTTON_A: Vector2(0, 1), JOY_BUTTON_B: Vector2(1, 0), JOY_BUTTON_X: Vector2(-1, 0), JOY_BUTTON_Y: Vector2(0, -1),
}
## Each family's names for the shoulders, triggers and middle buttons.
const LABELS := {
	Family.XBOX: {JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", TRIGGER_LEFT: "LT", TRIGGER_RIGHT: "RT",
		JOY_BUTTON_START: "MENU", JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_GUIDE: "XBOX"},
	Family.PLAYSTATION: {JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", TRIGGER_LEFT: "L2", TRIGGER_RIGHT: "R2",
		JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_BACK: "SHARE", JOY_BUTTON_GUIDE: "PS"},
	Family.GENERIC: {JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", TRIGGER_LEFT: "L2", TRIGGER_RIGHT: "R2",
		JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_GUIDE: "HOME"},
}
const INK := Color("#140c2a")  # the dark the glyphs are cut from
const RIM := Color("#c9d4ff")
const LIT := Color("#ffd23a")


## The family of a joypad called `joy_name` (`wheel`: read as a wheel, InputRouter). A plain
## lookup on the name: Xbox before PlayStation (Sony's pads call themselves a "Wireless
## Controller" too, but never "Xbox"); anything else is a generic pad.
static func family_for(joy_name: String, wheel: bool) -> int:
	if wheel:
		return Family.WHEEL
	var lower := joy_name.to_lower()
	for hint: String in XBOX_HINTS:
		if lower.contains(hint):
			return Family.XBOX
	for hint: String in PLAYSTATION_HINTS:
		if lower.contains(hint):
			return Family.PLAYSTATION
	return Family.GENERIC


## The family `--pad-family=NAME` in `args` forces, or NONE.
static func forced_in(args: PackedStringArray) -> int:
	return FAMILY_NAMES.get(DevArgs.value_in(args, "--pad-family").to_lower(), Family.NONE)


static func forced() -> int:
	return forced_in(OS.get_cmdline_user_args())


## The family of the device driving now (InputRouter.state): NONE on the keyboard or touch.
static func family_now() -> int:
	if TouchControls.showing():
		return Family.NONE
	var st: DriveInput = InputRouter.state
	match st.kind:
		DriveInput.Kind.GAMEPAD:
			return family_for(st.device_name, false)
		DriveInput.Kind.WHEEL:
			return Family.WHEEL
	return Family.NONE


## The family a device profile's buttons are drawn in: NONE for the keyboard.
static func family_of(profile: DeviceProfile) -> int:
	if profile == null or profile.kind == DeviceProfile.Kind.KEYBOARD:
		return Family.NONE
	return family_for(profile.name, profile.kind == DeviceProfile.Kind.WHEEL)


## The code a hint's or a label's word names (WORDS, or a wheel's "BUTTON 5"), or -1.
static func code_for(word: String) -> int:
	var w := word.strip_edges().to_upper()
	if WORDS.has(w):
		return WORDS[w]
	if w.begins_with("BUTTON ") and w.trim_prefix("BUTTON ").is_valid_int():
		return int(w.trim_prefix("BUTTON "))
	return -1


## What `code` looks like in `family`: {shape (Shape), label, color, mark (a PlayStation
## shape's name), dir (a generic face button's place, or the D-pad's lit arms)}. Empty when
## there's no glyph for it (the keyboard; a code the family doesn't have): the text stays.
static func glyph(family: int, code: int) -> Dictionary:
	if family == Family.NONE or code < 0:
		return {}
	match code:
		DPAD:
			return {"shape": Shape.DPAD, "dir": Vector2.ZERO}
		DPAD_UP_DOWN:
			return {"shape": Shape.DPAD, "dir": Vector2(0, 2)}
		DPAD_LEFT_RIGHT:
			return {"shape": Shape.DPAD, "dir": Vector2(2, 0)}
		JOY_BUTTON_DPAD_UP:
			return {"shape": Shape.DPAD, "dir": Vector2(0, -1)}
		JOY_BUTTON_DPAD_DOWN:
			return {"shape": Shape.DPAD, "dir": Vector2(0, 1)}
		JOY_BUTTON_DPAD_LEFT:
			return {"shape": Shape.DPAD, "dir": Vector2(-1, 0)}
		JOY_BUTTON_DPAD_RIGHT:
			return {"shape": Shape.DPAD, "dir": Vector2(1, 0)}
	if family == Family.WHEEL:
		# A wheel's buttons differ by model: a labelled tab, the letter Godot's mapping gives
		# the first four, the number past them.
		if code > JOY_BUTTON_SDL_MAX:
			return {}
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"}
		return {"shape": Shape.TAB, "label": names.get(code, str(code))}
	match code:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			match family:
				Family.XBOX:
					return {"shape": Shape.FACE, "label": XBOX_FACE[code][0], "color": XBOX_FACE[code][1]}
				Family.PLAYSTATION:
					return {"shape": Shape.FACE, "mark": PS_FACE[code][0], "color": PS_FACE[code][1]}
			return {"shape": Shape.FACE, "dir": POSITIONS[code]}
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			return {"shape": Shape.SHOULDER, "label": LABELS[family][code]}
		TRIGGER_LEFT, TRIGGER_RIGHT:
			return {"shape": Shape.TRIGGER, "label": LABELS[family][code]}
		JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE:
			return {"shape": Shape.PILL, "label": LABELS[family][code]}
		JOY_BUTTON_LEFT_STICK:
			return {"shape": Shape.STICK, "label": "L", "click": true}
		JOY_BUTTON_RIGHT_STICK:
			return {"shape": Shape.STICK, "label": "R", "click": true}
		STICK_LEFT:
			return {"shape": Shape.STICK, "label": "L"}
	return {}


## `s` cut into what to draw: Strings stay text, ints are glyphs (codes). A hint ("D-pad Up /
## Down: choose    A: select") has the keys before each ": " turned into glyphs, when every
## key of that part has one; `whole` reads all of `s` as keys ("RT / A", a binding). Up and
## Down (Left and Right) side by side make one D-pad with both arms lit.
static func pieces(s: String, family: int, whole := false) -> Array:
	if family == Family.NONE:
		return [s]
	var out: Array = []
	var parts: PackedStringArray = [s] if whole else s.split("    ")
	for i in parts.size():
		if i > 0:
			out.append("    ")
		var part := parts[i]
		var colon := part.length() if whole else part.find(": ")
		var keys := _keys(part.substr(0, colon) if colon >= 0 else "", family)
		if keys.is_empty():
			out.append(part)
			continue
		for k in keys.size():
			if k > 0 and keys[k] is int and keys[k - 1] is int:
				out.append(" ")
			out.append(keys[k])
		if colon < part.length():
			out.append(part.substr(colon))
	return _merged(out)


## The glyph codes for "A / B" (with the " / " between them), or [] when one hasn't a glyph.
static func _keys(keys: String, family: int) -> Array:
	if keys.strip_edges() == "":
		return []
	var words := keys.split(" / ")
	var codes: Array = []
	for w in words:
		var c := code_for(w)
		if glyph(family, c).is_empty():
			return []
		codes.append(c)
	var out: Array = []
	var i := 0
	while i < codes.size():
		var pair := codes.slice(i, i + 2)
		if pair == [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN] or pair == [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP]:
			_add_key(out, DPAD_UP_DOWN)
			i += 2
		elif pair == [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT] or pair == [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT]:
			_add_key(out, DPAD_LEFT_RIGHT)
			i += 2
		else:
			_add_key(out, codes[i])
			i += 1
	return out


static func _add_key(out: Array, code: int) -> void:
	if not out.is_empty():
		out.append(" / ")
	out.append(code)


## Neighbouring strings joined.
static func _merged(list: Array) -> Array:
	var out: Array = []
	for p in list:
		if p is String and not out.is_empty() and out[-1] is String:
			out[-1] += p
		elif not (p is String and p == ""):
			out.append(p)
	return out


## Whether `list` (pieces) has a glyph in it.
static func has_glyph(list: Array) -> bool:
	for p in list:
		if p is int:
			return true
	return false


# --- Drawing ----------------------------------------------------------------------

## How wide a glyph `h` pixels high is (`label_px`: its label's text size).
static func width(g: Dictionary, h: float, label_px: int) -> float:
	match g.get("shape", -1):
		Shape.FACE, Shape.STICK, Shape.DPAD:
			return h
		Shape.SHOULDER, Shape.TRIGGER, Shape.PILL, Shape.TAB:
			return maxf(h, UiText.width(g.get("label", ""), label_px) + 6.0)
	return 0.0


## Draws glyph `g` on `ci`, `h` high, its left side at `x` and its middle at `mid_y`.
static func draw(ci: CanvasItem, g: Dictionary, x: float, mid_y: float, h: float, label_px: int, col := Color.WHITE) -> void:
	var w := width(g, h, label_px)
	var c := Vector2(roundf(x + w / 2.0), roundf(mid_y))
	var r := floorf(h / 2.0)
	var label: String = g.get("label", "")
	match g.get("shape", -1):
		Shape.FACE:
			var tint: Color = g.get("color", RIM)
			if g.has("dir"):
				# A generic pad: the diamond of four buttons, the one meant lit.
				var dot := maxf(2.5, r * 0.45)
				for d: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
					var at := c + d * (r - dot + 0.5)
					var on: bool = d == g["dir"]
					ci.draw_circle(at, dot + 1.0, INK)
					ci.draw_circle(at, dot, LIT if on else Color(RIM, 0.45))
				return
			ci.draw_circle(c, r, INK)
			ci.draw_circle(c, r - 1.0, Color("#262040") if g.has("mark") else tint)
			if g.has("mark"):
				_mark(ci, g["mark"], c, r - 2.5, tint.lightened(0.3))
			else:
				_label(ci, label, c, label_px, INK)
		Shape.STICK:
			ci.draw_circle(c, r, INK)
			ci.draw_circle(c, r - 1.0, Color("#5a6080"))
			ci.draw_circle(c, r - 3.0, RIM if g.get("click", false) else Color("#8890b0"))
			_label(ci, label, c, label_px, INK)
		Shape.DPAD:
			var arm := maxf(2.0, floorf(h / 3.0))
			ci.draw_rect(Rect2(c.x - arm / 2.0 - 1, c.y - r, arm + 2, h), INK)
			ci.draw_rect(Rect2(c.x - r, c.y - arm / 2.0 - 1, h, arm + 2), INK)
			ci.draw_rect(Rect2(c.x - arm / 2.0, c.y - r + 1, arm, h - 2), RIM)
			ci.draw_rect(Rect2(c.x - r + 1, c.y - arm / 2.0, h - 2, arm), RIM)
			var dir: Vector2 = g.get("dir", Vector2.ZERO)
			for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				var lit := (dir == d) or (dir.y == 2 and d.x == 0) or (dir.x == 2 and d.y == 0)
				if lit:
					var tip := c + d * (r - arm / 2.0 - 0.5)
					ci.draw_rect(Rect2(tip - Vector2(arm, arm) / 2.0, Vector2(arm, arm)), LIT)
		Shape.SHOULDER, Shape.TRIGGER, Shape.PILL, Shape.TAB:
			var box := Rect2(roundf(x), roundf(mid_y - r), roundf(w), h)
			var face := Color("#2a3260")
			match g["shape"]:
				Shape.SHOULDER:
					face = Color("#3a4a90")
				Shape.TRIGGER:
					box = Rect2(box.position.x, box.position.y - 1, box.size.x, box.size.y + 1)
					face = Color("#4a3a90")
				Shape.TAB:
					face = Color("#30384a")
			_rounded(ci, box, INK)
			_rounded(ci, box.grow(-1), face)
			if g["shape"] == Shape.TRIGGER:  # a trigger's top rounds over: lighter on top
				ci.draw_rect(Rect2(box.position.x + 2, box.position.y + 1, box.size.x - 4, 1), Color(RIM, 0.5))
			elif g["shape"] == Shape.TAB:
				ci.draw_rect(Rect2(box.position.x + 2, box.end.y - 2, box.size.x - 4, 1), Color(RIM, 0.35))
			_label(ci, label, c, label_px, col)


## A rectangle with its corners cut (pixel-rounded).
static func _rounded(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), col)


static func _label(ci: CanvasItem, s: String, c: Vector2, size: int, col: Color) -> void:
	if s == "":
		return
	var font := ThemeDB.fallback_font
	var w := UiText.width(s, size)
	var asc := font.get_ascent(size) - font.get_descent(size) * 0.0
	var pos := Vector2(roundf(c.x - w / 2.0), roundf(c.y + asc * 0.36))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A PlayStation face button's shape, `r` from the middle `c`.
static func _mark(ci: CanvasItem, mark: String, c: Vector2, r: float, col: Color) -> void:
	var t := 1.5
	match mark:
		"cross":
			ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, t)
			ci.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, t)
		"circle":
			ci.draw_arc(c, r, 0.0, TAU, 16, col, t)
		"square":
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), col, false, t)
		"triangle":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8), c + Vector2(0, -r)])
			ci.draw_polyline(pts, col, t)


## Lays `list` (pieces) out on `ci` from `pos` (the text's baseline): text in `col` at
## `size` pixels, glyphs a little taller than the text, centred on its middle.
static func draw_pieces(ci: CanvasItem, pos: Vector2, list: Array, size: int, col: Color, family: int) -> void:
	var x := pos.x
	var h := glyph_height(size)
	var mid := pos.y - size * 0.36
	for p in list:
		if p is String:
			UiText.draw(ci, Vector2(x, pos.y), p, size, col)
			x += UiText.width(p, size)
		else:
			var g := glyph(family, p)
			draw(ci, g, x, mid, h, label_size(size), Color(Color.WHITE, col.a))
			x += width(g, h, label_size(size))


## How wide `list` (pieces) comes out at `size` pixels.
static func pieces_width(list: Array, size: int, family: int) -> float:
	var w := 0.0
	for p in list:
		w += UiText.width(p, size) if p is String else width(glyph(family, p), glyph_height(size), label_size(size))
	return w


## A glyph's height beside text `size` pixels high: odd, so its middle is a pixel, and never
## under 13, where a PlayStation shape or a D-pad's arm stops reading.
static func glyph_height(size: int) -> float:
	return float(maxi(13, int(size * 1.25)) | 1)


## Its labels' text size.
static func label_size(size: int) -> int:
	return maxi(6, size - 3)
