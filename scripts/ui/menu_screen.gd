class_name MenuScreen
extends Control
## Base for the front-end screens (title, stage select, car select). The game feeds each
## physics tick's MenuInput to `handle`; screens draw themselves in the Hud's style.

const GOLD := Color("#ffd23a")
const SKY := Color("#3ad0ff")
const NIGHT := Color("#140c2a")
const TITLE_BG := "res://assets/sprites/ui/title_bg.png"

var game: Node  # game.gd
var time := 0.0  # seconds on this screen, for blinking and bobbing

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


## The bottom line of control hints, worded for the device in use.
static func hints(choose: bool) -> String:
	var kind: int = InputRouter.state.kind
	var parts: Array[String] = []
	match kind:
		DriveInput.Kind.WHEEL:
			if choose:
				parts.append("Steer: choose")
			parts.append_array(["Gas: select", "Brake: back"])
		DriveInput.Kind.GAMEPAD:
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


func _footer(s: String) -> void:
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, Cfg.SCREEN_W, 20), Color(0, 0, 0, 0.6))
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, Cfg.SCREEN_H - 6), s, 9, Color(1, 1, 1, 0.8))


## A chrome-bevelled frame around `r`.
func _frame(r: Rect2, glow: Color = Color.TRANSPARENT) -> void:
	if glow.a > 0.0:
		draw_rect(r.grow(5), glow)
	draw_rect(r.grow(3), Color("#1b2a6b"))
	draw_rect(r.grow(2), Color("#c9d4ff"))
	draw_rect(r.grow(1), Color("#4058b8"))


## A left or right arrowhead centred on `c`, pointing by `dir`.
func _arrow(c: Vector2, dir: int, col: Color) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(8 * d, 0), c + Vector2(-6 * d, -10), c + Vector2(-6 * d, 10)]), col)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 6), Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(pos.x - width / 2.0, pos.y), s, size, col)
