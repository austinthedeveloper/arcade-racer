class_name MenuScreen
extends Control
## Base for the front-end screens (title, stage select, car select). The game feeds each
## physics tick's MenuInput to `handle`; screens draw themselves in the Hud's style.
## The UI scale (AC-12, UiScale): text drawn with _text and _text_centered comes out bigger at
## LARGE; a screen that lines text up by its width measures it with _width (the drawn size).

const GOLD := Color("#ffd23a")
const SKY := Color("#3ad0ff")
const NIGHT := Color("#140c2a")
const TITLE_BG := "res://assets/sprites/ui/title_bg.png"
const LOCKED_TINT := Color(0.18, 0.16, 0.26)  # a locked car or stage's picture

var game: Node  # game.gd
var time := 0.0  # seconds on this screen, for blinking and bobbing
var index := 0  # the selection, into the screen's choices (choice_count)

var _font: Font
var _bg: Texture2D


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_bg = load(TITLE_BG)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(dt: float) -> void:
	time += dt
	queue_redraw()


## One tick of menu input. Screens override this.
func handle(_m: MenuInput) -> void:
	pass


## How many choices `index` runs over. Screens with a selection override this.
func choice_count() -> int:
	return 1


## Moves the selection by `dir`, wrapping around; returns the new index.
func move(dir: int) -> int:
	index = posmod(index + dir, choice_count())
	return index


## The bottom line of control hints, worded for the device in use.
static func hints(choose: bool) -> String:
	var kind: int = InputRouter.state.kind
	var parts: Array[String] = []
	match kind:
		DriveInput.Kind.GAMEPAD, DriveInput.Kind.WHEEL:
			if choose:
				parts.append("D-pad: choose")
			parts.append_array(["A: select", "B: back"])
		_:
			if choose:
				parts.append("Left / Right: choose")
			parts.append_array(["Enter: select", "Esc: back"])
	return "    ".join(parts)


func _backdrop(dim: float) -> void:
	if _bg != null:
		draw_texture(_bg, Vector2.ZERO)
	draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(NIGHT, dim))


func _header(s: String) -> void:
	draw_rect(Rect2(0, 10, 250, 26), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(0, 36, 250, 2), GOLD)
	_text(Vector2(16, 30), s, 18, GOLD)


## The hints along the bottom; a pad's or a wheel's buttons in them as glyphs (WH-14).
func _footer(s: String) -> void:
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, Cfg.SCREEN_W, 20), Color(0, 0, 0, 0.6))
	_hint_centered(Vector2(Cfg.SCREEN_W / 2.0, Cfg.SCREEN_H - 6), s, 9, Cfg.SCREEN_W - 12.0, Color(1, 1, 1, 0.8))


## Hints `s` centred on `pos`, as big as fits `room` up to `size`: with the device in use's
## button glyphs (PadGlyphs.family_now) when it's a pad or a wheel, text otherwise.
func _hint_centered(pos: Vector2, s: String, size: int, room: float, col: Color) -> void:
	var family := PadGlyphs.family_now()
	var list := PadGlyphs.pieces(s, family)
	if not PadGlyphs.has_glyph(list):
		_text_centered(pos, s, fit_size(s, size, room), col)
		return
	var at := size
	while at > UiText.MIN_SIZE and PadGlyphs.pieces_width(list, px(at), family) > room:
		at -= 1
	var w := PadGlyphs.pieces_width(list, px(at), family)
	PadGlyphs.draw_pieces(self, Vector2(roundf(pos.x - w / 2.0), pos.y), list, px(at), col, family)


## Keys or buttons `s` ("RT / A", a binding's text) from `pos` (its baseline) in `family`'s
## glyphs, or as text when they haven't all got one; `centered`: `pos.x` is its middle.
## Returns how wide it came out.
func _keys(pos: Vector2, s: String, size: int, col: Color, family: int, centered := false) -> float:
	var list := PadGlyphs.pieces(s, family, true)
	if not PadGlyphs.has_glyph(list):
		if centered:
			_text_centered(pos, s, size, col)
		else:
			_text(pos, s, size, col)
		return _width(s, size)
	var w := PadGlyphs.pieces_width(list, px(size), family)
	var x := pos.x - w / 2.0 if centered else pos.x
	PadGlyphs.draw_pieces(self, Vector2(roundf(x), pos.y), list, px(size), col, family)
	return w


## A chrome-bevelled frame around `r`.
func _frame(r: Rect2, glow: Color = Color.TRANSPARENT) -> void:
	if glow.a > 0.0:
		draw_rect(r.grow(5), glow)
	draw_rect(r.grow(3), Color("#1b2a6b"))
	draw_rect(r.grow(2), Color("#c9d4ff"))
	draw_rect(r.grow(1), Color("#4058b8"))


## A framed dark panel over `r`, `alpha` opaque.
func _panel(r: Rect2, alpha: float) -> void:
	_frame(r)
	draw_rect(r, Color(0.04, 0.03, 0.1, alpha))


## A left or right arrowhead centred on `c`, pointing by `dir`.
func _arrow(c: Vector2, dir: int, col: Color) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(8 * d, 0), c + Vector2(-6 * d, -10), c + Vector2(-6 * d, 10)]), col)


## A padlock centred on `c`, `scale` times its 20-pixel height.
func _lock(c: Vector2, scale: float) -> void:
	var body := Rect2(c + Vector2(-7, -1) * scale, Vector2(14, 11) * scale)
	draw_arc(c + Vector2(0, -2) * scale, 4.5 * scale, PI, TAU, 12, GOLD, 2.0 * scale)
	draw_line(c + Vector2(-4.5, -2) * scale, c + Vector2(-4.5, 0) * scale, GOLD, 2.0 * scale)
	draw_line(c + Vector2(4.5, -2) * scale, c + Vector2(4.5, 0) * scale, GOLD, 2.0 * scale)
	draw_rect(body, GOLD)
	draw_rect(Rect2(c + Vector2(-1, 3) * scale, Vector2(2, 4) * scale), NIGHT)


## Text laid out `size` high, drawn at the UI scale's size for it (UiScale.menu_px).
func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw(self, pos, s, px(size), col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw_centered(self, pos, s, px(size), col)


## The size menu text laid out `size` high is drawn at, with the UI scale the options set.
static func px(size: int) -> int:
	return UiScale.menu_px(size, UiScale.now())


## How wide `s` comes out drawn with _text at `size`.
static func _width(s: String, size: int) -> float:
	return UiText.width(s, px(size))


## The biggest size up to `size` at which `s`, drawn with _text, is no wider than `room`: for
## labels in a fixed box, which the UI scale's bigger text could overrun (never under 8).
static func fit_size(s: String, size: int, room: float) -> int:
	var at := size
	while at > UiText.MIN_SIZE and _width(s, at) > room:
		at -= 1
	return at


## Where text drawn with _text at `size` starts so its middle is at `x`.
static func _centered_x(x: float, s: String, size: int) -> float:
	return x - _width(s, size) / 2.0
