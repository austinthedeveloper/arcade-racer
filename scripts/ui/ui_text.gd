class_name UiText
extends RefCounted
## Text the HUD and the menus draw: the fallback font with a dark outline, so it reads over
## any background.

const OUTLINE := Color(0, 0, 0, 0.85)
const MIN_SIZE := 8  # the smallest text the HUD draws, in 640x360 pixels (PR-14)


static func draw(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 6), OUTLINE)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## `pos.x` is the middle of the text.
static func draw_centered(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	draw(ci, Vector2(centered_x(pos.x, s, size), pos.y), s, size, col)


## Where text `size` high starts so its middle is at `x`.
static func centered_x(x: float, s: String, size: int) -> float:
	return x - width(s, size) / 2.0


static func width(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
