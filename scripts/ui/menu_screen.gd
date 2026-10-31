class_name MenuScreen
extends Control
## Base for the front-end screens (title, stage select, car select). The game feeds each
## physics tick's MenuInput to `handle`; screens draw themselves in the Hud's style.

const GOLD := Color("#ffd23a")
const SKY := Color("#3ad0ff")
const NIGHT := Color("#140c2a")
const TITLE_BG := "res://assets/sprites/ui/title_bg.png"
const LOCKED_TINT := Color(0.18, 0.16, 0.26)  # a locked car or stage's picture

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


## A padlock centred on `c`, `scale` times its 20-pixel height.
func _lock(c: Vector2, scale: float) -> void:
	var body := Rect2(c + Vector2(-7, -1) * scale, Vector2(14, 11) * scale)
	draw_arc(c + Vector2(0, -2) * scale, 4.5 * scale, PI, TAU, 12, GOLD, 2.0 * scale)
	draw_line(c + Vector2(-4.5, -2) * scale, c + Vector2(-4.5, 0) * scale, GOLD, 2.0 * scale)
	draw_line(c + Vector2(4.5, -2) * scale, c + Vector2(4.5, 0) * scale, GOLD, 2.0 * scale)
	draw_rect(body, GOLD)
	draw_rect(Rect2(c + Vector2(-1, 3) * scale, Vector2(2, 4) * scale), NIGHT)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw(self, pos, s, size, col)


func _text_centered(pos: Vector2, s: String, size: int, col: Color) -> void:
	UiText.draw_centered(self, pos, s, size, col)
