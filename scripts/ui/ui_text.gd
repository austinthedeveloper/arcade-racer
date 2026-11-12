class_name UiText
extends RefCounted
## Text the HUD and the menus draw: the fallback font with a dark outline, so it reads over
## any background.
## Inside begin_scaled (a HUD element drawn bigger, UiScale) text is drawn with the transform
## undone, at the size it scales to: sharp glyphs, not stretched ones.

const OUTLINE := Color(0, 0, 0, 0.85)
const MIN_SIZE := 8  # the smallest text the HUD draws, in 640x360 pixels (PR-14)

static var _xf := Transform2D.IDENTITY  # what begin_scaled set
static var _k := 1.0  # its scale


## Draws on `ci` under `xf` (UiScale.transform_about) until end_scaled; text included.
static func begin_scaled(ci: CanvasItem, xf: Transform2D) -> void:
	_xf = xf
	_k = xf.get_scale().x
	ci.draw_set_transform_matrix(xf)


static func end_scaled(ci: CanvasItem) -> void:
	_xf = Transform2D.IDENTITY
	_k = 1.0
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The scale begin_scaled has text drawn at (1 outside it).
static func scale() -> float:
	return _k


static func draw(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	if _k != 1.0:
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_plain(ci, (_xf * pos).round(), s, roundi(size * _k), col)
		ci.draw_set_transform_matrix(_xf)
		return
	_draw_plain(ci, pos, s, size, col)


static func _draw_plain(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 6), OUTLINE)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## `pos.x` is the middle of the text.
static func draw_centered(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	if _k != 1.0:  # (centered at the size it's drawn, not at 1x and stretched)
		var at := _xf * pos
		var px := roundi(size * _k)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_plain(ci, Vector2(centered_x(at.x, s, px), at.y).round(), s, px, col)
		ci.draw_set_transform_matrix(_xf)
		return
	draw(ci, Vector2(centered_x(pos.x, s, size), pos.y), s, size, col)


## Where text `size` high starts so its middle is at `x`.
static func centered_x(x: float, s: String, size: int) -> float:
	return x - width(s, size) / 2.0


static func width(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
