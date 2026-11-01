class_name Background
extends Node2D
## Sky gradient plus three horizontally scrolling strips, back to front: sky, far and near
## (tools/make_stage_sprites.py). They scroll with road curvature, each at its own rate, and
## shift up and down with the hills ahead.

## Layers back to front, read from the theme's "background" (the far strip) by swapping
## its "_far" for the layer's name. A missing layer is skipped.
const LAYERS := ["sky", "far", "near"]
## Pixels per unit of `offset`, per layer: the far strip turns once per unit (its
## SCROLL_WIDTH), the sky slower and the near strip faster.
const SCROLL_WIDTH := 2560.0
const SCROLL_RATE := {"sky": 0.3, "far": 1.0, "near": 1.6}
## Share of the hill shift (hill_shift) each layer moves by: the sky barely.
const HILL_RATE := {"sky": 0.25, "far": 0.75, "near": 1.0}
## Where each strip's bottom edge sits below the horizon, in pixels (the road covers it).
const SINK := {"sky": 30.0, "far": 6.0, "near": 4.0}
## hill_shift: the road this far ahead (world units) sets the horizon...
const HILL_AHEAD := 16000.0
## ...moved at most this many pixels either way.
const HILL_MAX := 36.0

var theme: Dictionary = {}
var textures: Dictionary = {}  # layer name -> Texture2D, for the layers this stage has
var offset := 0.0  # scroll, in turns of the far strip
var hill := 0.0  # pixels the horizon moved down (hill_shift)
var mirrored := false  # a mirrored stage (WS-6): every strip drawn flipped


func set_theme(new_theme: Dictionary) -> void:
	theme = new_theme
	textures.clear()
	if theme.has("background"):
		for layer: String in LAYERS:
			var path := layer_path(theme["background"], layer)
			if ResourceLoader.exists(path):
				textures[layer] = load(path)


func _draw() -> void:
	if theme.is_empty():
		return
	var w := float(Cfg.SCREEN_W)
	var top: Color = theme["sky_top"]
	var bottom: Color = theme["sky_bottom"]
	var ground_y := Cfg.HORIZON_Y + hill
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, ground_y), Vector2(0, ground_y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for layer: String in LAYERS:
		if not textures.has(layer):
			continue
		var tex: Texture2D = textures[layer]
		var tw := float(tex.get_width())
		var y0 := layer_bottom(layer, hill) - tex.get_height()
		var x0 := layer_x(offset, layer, tw)
		if mirrored:
			# Flipped in place (a negative width), each copy where it was: a strip that tiles
			# seamlessly still does
			var flipped := Vector2(-tw, tex.get_height())
			draw_texture_rect(tex, Rect2(Vector2(x0, y0), flipped), false)
			draw_texture_rect(tex, Rect2(Vector2(x0 + tw, y0), flipped), false)
		else:
			draw_texture(tex, Vector2(x0, y0))
			draw_texture(tex, Vector2(x0 + tw, y0))
	draw_rect(Rect2(0, ground_y, w, Cfg.SCREEN_H - ground_y), theme["below_horizon"])


## The path of a stage's `layer` strip, from the far strip's path.
static func layer_path(far_path: String, layer: String) -> String:
	return far_path.replace("_far.", "_%s." % layer)


## Where `layer`'s first strip copy starts for a scroll of `offset` (turns of the far
## strip) on a strip `width` wide: SCROLL_RATE times the far strip's pixels.
static func layer_x(offset: float, layer: String, width: float) -> float:
	return strip_x(offset * SCROLL_WIDTH * SCROLL_RATE[layer] / width, width)


## The screen row of `layer`'s bottom edge with the horizon moved `hill` pixels down.
static func layer_bottom(layer: String, hill: float) -> float:
	return roundf(Cfg.HORIZON_Y + SINK[layer] + hill * HILL_RATE[layer])


## How far down (pixels; up is negative) the horizon moves when the road HILL_AHEAD ahead
## is `rise` world units above the road under the camera (camera `depth`): as far as that
## road moved on the screen, so a climb lifts the scenery over the rising road and a crest
## drops it onto the falling one.
static func hill_shift(rise: float, depth: float) -> float:
	return roundf(clampf(-rise * depth / HILL_AHEAD * Cfg.PROJ, -HILL_MAX, HILL_MAX))


## Where the first of the two strip copies starts (a whole pixel, at or left of 0) for an
## `offset` of 0..1 round a strip `width` wide; the second follows it.
static func strip_x(offset: float, width: float) -> float:
	return roundf(-fposmod(offset * width, width))
