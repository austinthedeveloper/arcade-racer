class_name CarPainter
extends RefCounted
## Draws placeholder cars (seen from behind) out of flat shapes until real car sprites exist.

enum Style { SPORTS, SEDAN, COMPACT, VAN, TRUCK }

const HEIGHT_RATIO := {
	Style.SPORTS: 0.42,
	Style.SEDAN: 0.52,
	Style.COMPACT: 0.6,
	Style.VAN: 0.82,
	Style.TRUCK: 1.05,
}

const TIRE := Color("#1b1b22")
const TRIM := Color("#24242c")
const GLASS := Color("#2c3e58")
const GLASS_SHINE := Color("#5b7699")
const PLATE := Color("#e8e2c8")
const LIGHT_OFF := Color("#8a1414")
const LIGHT_ON := Color("#ff4a2a")


## base: bottom-center of the car on the road, in screen pixels.
## lift: how far the car is above the road (jumps); the shadow stays on the road.
static func draw_car(ci: CanvasItem, base: Vector2, w: float, body: Color, style: int, steer: float,
		brake: bool, nitro: bool, fog: float, fog_color: Color, t: float, lift: float = 0.0) -> void:
	var h: float = w * HEIGHT_RATIO[style]
	var x := base.x
	var y := base.y - lift
	if w < 3.0:
		ci.draw_rect(Rect2(x - w / 2.0, y - h, w, h), _f(body, fog, fog_color))
		return

	var shadow_alpha := 0.35 * (1.0 - fog) * clampf(1.0 - lift / (w * 0.6), 0.2, 1.0)
	ci.draw_rect(Rect2(x - w * 0.52, base.y - h * 0.06, w * 1.04, h * 0.09), Color(0, 0, 0, shadow_alpha))

	var lean := steer * w * 0.05
	var dark := body.darkened(0.35)
	match style:
		Style.TRUCK:
			_truck(ci, x, y, w, h, body, lean, brake, fog, fog_color)
		Style.VAN:
			_boxy(ci, x, y, w, h, body, dark, lean, brake, fog, fog_color)
		_:
			_car(ci, x, y, w, h, body, dark, lean, brake, style, fog, fog_color)

	if nitro:
		_flames(ci, x, y, w, h, t)


static func _car(ci: CanvasItem, x: float, y: float, w: float, h: float, body: Color, dark: Color,
		lean: float, brake: bool, style: int, fog: float, fc: Color) -> void:
	var sports := style == Style.SPORTS
	var body_top := 0.55 if sports else 0.5
	var cabin_top := 0.97 if sports else 0.98
	var cabin_bot_w := 0.78 if sports else 0.86
	var cabin_top_w := 0.56 if sports else 0.7

	_tires(ci, x, y, w, h, fog, fc)
	# Lower body, slightly narrower at the shoulders
	_poly(ci, [Vector2(x - w * 0.5, y - h * 0.12), Vector2(x + w * 0.5, y - h * 0.12),
		Vector2(x + w * 0.48 + lean * 0.3, y - h * body_top), Vector2(x - w * 0.48 + lean * 0.3, y - h * body_top)], body, fog, fc)
	# Shoulder highlight
	ci.draw_rect(Rect2(x - w * 0.47 + lean * 0.3, y - h * body_top, w * 0.94, maxf(1.0, h * 0.05)), _f(body.lightened(0.3), fog, fc))
	# Cabin and rear glass
	_poly(ci, [Vector2(x - w * cabin_bot_w / 2.0 + lean * 0.6, y - h * body_top), Vector2(x + w * cabin_bot_w / 2.0 + lean * 0.6, y - h * body_top),
		Vector2(x + w * cabin_top_w / 2.0 + lean, y - h * cabin_top), Vector2(x - w * cabin_top_w / 2.0 + lean, y - h * cabin_top)], body.darkened(0.12), fog, fc)
	var gi := 0.06
	_poly(ci, [Vector2(x - w * (cabin_bot_w / 2.0 - gi) + lean * 0.6, y - h * (body_top + 0.04)), Vector2(x + w * (cabin_bot_w / 2.0 - gi) + lean * 0.6, y - h * (body_top + 0.04)),
		Vector2(x + w * (cabin_top_w / 2.0 - gi) + lean, y - h * (cabin_top - 0.07)), Vector2(x - w * (cabin_top_w / 2.0 - gi) + lean, y - h * (cabin_top - 0.07))], GLASS, fog, fc)
	ci.draw_rect(Rect2(x - w * 0.12 + lean * 0.8, y - h * (cabin_top - 0.1), w * 0.06, h * 0.08), _f(GLASS_SHINE, fog, fc))
	# Bumper, plate
	ci.draw_rect(Rect2(x - w * 0.47, y - h * 0.22, w * 0.94, h * 0.09), _f(TRIM, fog, fc))
	ci.draw_rect(Rect2(x - w * 0.09, y - h * 0.34, w * 0.18, h * 0.1), _f(PLATE, fog, fc))
	# Taillights
	var lw := w * (0.26 if sports else 0.18)
	var ly := y - h * (body_top - 0.08)
	_lights(ci, x, ly, w, lw, h * 0.12, brake, fog, fc)
	if sports:
		# Rear wing on posts
		ci.draw_rect(Rect2(x - w * 0.47 + lean * 0.4, y - h * (body_top + 0.14), w * 0.94, maxf(1.0, h * 0.07)), _f(dark, fog, fc))
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(x + side * w * 0.3 - w * 0.02 + lean * 0.35, y - h * (body_top + 0.08), w * 0.04, h * 0.09), _f(dark, fog, fc))
		# Twin exhausts
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(x + side * w * 0.2 - w * 0.04, y - h * 0.17, w * 0.08, h * 0.07), _f(Color("#9a9aa6"), fog, fc))


static func _boxy(ci: CanvasItem, x: float, y: float, w: float, h: float, body: Color, dark: Color,
		lean: float, brake: bool, fog: float, fc: Color) -> void:
	_tires(ci, x, y, w, h * 0.6, fog, fc)
	_poly(ci, [Vector2(x - w * 0.48, y - h * 0.1), Vector2(x + w * 0.48, y - h * 0.1),
		Vector2(x + w * 0.46 + lean, y - h * 0.98), Vector2(x - w * 0.46 + lean, y - h * 0.98)], body, fog, fc)
	ci.draw_rect(Rect2(x - w * 0.36 + lean * 0.8, y - h * 0.9, w * 0.72, h * 0.25), _f(GLASS, fog, fc))
	ci.draw_rect(Rect2(x - w * 0.01 + lean * 0.5, y - h * 0.9, maxf(1.0, w * 0.02), h * 0.72), _f(dark, fog, fc))
	ci.draw_rect(Rect2(x - w * 0.47, y - h * 0.18, w * 0.94, h * 0.08), _f(TRIM, fog, fc))
	ci.draw_rect(Rect2(x - w * 0.09, y - h * 0.3, w * 0.18, h * 0.08), _f(PLATE, fog, fc))
	_lights(ci, x, y - h * 0.42, w, w * 0.09, h * 0.16, brake, fog, fc)


static func _truck(ci: CanvasItem, x: float, y: float, w: float, h: float, body: Color, lean: float,
		brake: bool, fog: float, fc: Color) -> void:
	_tires(ci, x, y, w, h * 0.45, fog, fc)
	var box := Color("#dcdce4")
	_poly(ci, [Vector2(x - w * 0.5, y - h * 0.16), Vector2(x + w * 0.5, y - h * 0.16),
		Vector2(x + w * 0.5 + lean * 0.5, y - h), Vector2(x - w * 0.5 + lean * 0.5, y - h)], box, fog, fc)
	ci.draw_rect(Rect2(x - w * 0.5 + lean * 0.5, y - h, w, h * 0.12), _f(body, fog, fc))
	ci.draw_rect(Rect2(x - w * 0.01, y - h * 0.86, maxf(1.0, w * 0.02), h * 0.68), _f(Color("#9a9aa6"), fog, fc))
	ci.draw_rect(Rect2(x - w * 0.48, y - h * 0.2, w * 0.96, h * 0.05), _f(TRIM, fog, fc))
	_lights(ci, x, y - h * 0.28, w, w * 0.08, h * 0.07, brake, fog, fc)


static func _tires(ci: CanvasItem, x: float, y: float, w: float, h: float, fog: float, fc: Color) -> void:
	var tw := w * 0.16
	var th := h * 0.3
	ci.draw_rect(Rect2(x - w * 0.47, y - th, tw, th), _f(TIRE, fog, fc))
	ci.draw_rect(Rect2(x + w * 0.47 - tw, y - th, tw, th), _f(TIRE, fog, fc))


static func _lights(ci: CanvasItem, x: float, ly: float, w: float, lw: float, lh: float, brake: bool, fog: float, fc: Color) -> void:
	var col := LIGHT_ON if brake else LIGHT_OFF
	for side in [-1.0, 1.0]:
		var lx: float = x + side * w * 0.44 - (lw if side > 0.0 else 0.0)
		if brake:
			ci.draw_rect(Rect2(lx - lw * 0.25, ly - lh * 0.5, lw * 1.5, lh * 2.0), Color(1.0, 0.3, 0.15, 0.25 * (1.0 - fog)))
		ci.draw_rect(Rect2(lx, ly, lw, lh), _f(col, fog, fc))


static func _flames(ci: CanvasItem, x: float, y: float, w: float, h: float, t: float) -> void:
	for side in [-1.0, 1.0]:
		var fx: float = x + side * w * 0.2
		var fy := y - h * 0.13
		var flicker := 0.75 + 0.25 * sin(t * 47.0 + side * 3.0)
		var r := w * 0.08 * flicker
		ci.draw_circle(Vector2(fx, fy), r * 1.6, Color(1.0, 0.45, 0.1, 0.8))
		ci.draw_circle(Vector2(fx, fy), r, Color(1.0, 0.85, 0.3, 0.95))
		ci.draw_circle(Vector2(fx, fy), r * 0.5, Color(0.7, 0.85, 1.0))


static func _poly(ci: CanvasItem, pts: Array, col: Color, fog: float, fc: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), _f(col, fog, fc))


static func _f(c: Color, fog: float, fc: Color) -> Color:
	return c.lerp(fc, fog) if fog > 0.0 else c
