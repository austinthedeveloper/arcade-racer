class_name Background
extends Node2D
## Sky gradient plus a horizontally scrolling horizon strip. Scrolls with road curvature.

var theme: Dictionary = {}
var texture: Texture2D
var offset := 0.0  # 0..1 around the strip


func set_theme(new_theme: Dictionary) -> void:
	theme = new_theme
	texture = load(theme["background"]) if theme.has("background") else null


func _draw() -> void:
	if theme.is_empty():
		return
	var w := float(Cfg.SCREEN_W)
	var top: Color = theme["sky_top"]
	var bottom: Color = theme["sky_bottom"]
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, Cfg.HORIZON_Y), Vector2(0, Cfg.HORIZON_Y)]),
		PackedColorArray([top, top, bottom, bottom]))
	draw_rect(Rect2(0, Cfg.HORIZON_Y, w, Cfg.SCREEN_H - Cfg.HORIZON_Y), theme["below_horizon"])
	if texture == null:
		return
	var tw := float(texture.get_width())
	var y0 := Cfg.HORIZON_Y + 4.0 - texture.get_height()
	var x0 := -fposmod(offset * tw, tw)
	draw_texture(texture, Vector2(roundf(x0), y0))
	draw_texture(texture, Vector2(roundf(x0) + tw, y0))
