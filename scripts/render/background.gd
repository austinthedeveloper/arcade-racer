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
## A theme with "reflection" (Skyline: the harbor water under the city) has a near strip that
## reflects its far one, cut at the same scale and width: the two scroll at the far rate and
## shift with the hills at the near rate (the water sits on the road), so they never part.
const REFLECTION_SCROLL := "far"
const REFLECTION_HILL := "near"
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
## Stage flow (StageFlow): the next stage's theme and layers, crossfaded in by `share`.
var next_theme: Dictionary = {}
var next_textures: Dictionary = {}
var share := 0.0
var mirrored := false  # a mirrored stage (WS-6): every strip drawn flipped


## The stage's theme, and the next stage's (empty for none) that its end turns to.
func set_theme(new_theme: Dictionary, new_next: Dictionary = {}) -> void:
	theme = new_theme
	textures = layers_of(theme)
	next_theme = new_next
	next_textures = layers_of(next_theme)
	share = 0.0


## A theme's layer textures by layer name, for the layers it has.
static func layers_of(of_theme: Dictionary) -> Dictionary:
	var out := {}
	if of_theme.has("background"):
		for layer: String in LAYERS:
			var path := layer_path(of_theme["background"], layer)
			if ResourceLoader.exists(path):
				out[layer] = load(path)
	return out


func _draw() -> void:
	if theme.is_empty():
		return
	var w := float(Cfg.SCREEN_W)
	var k := share if not next_theme.is_empty() else 0.0
	var top := sky_color(theme, next_theme, "sky_top", k)
	var bottom := sky_color(theme, next_theme, "sky_bottom", k)
	var ground_y := Cfg.HORIZON_Y + hill
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, ground_y), Vector2(0, ground_y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for layer: String in LAYERS:
		_draw_layer(textures.get(layer), layer, 1.0 - k, theme)
		_draw_layer(next_textures.get(layer), layer, k, next_theme)
	draw_rect(Rect2(0, ground_y, w, Cfg.SCREEN_H - ground_y), sky_color(theme, next_theme, "below_horizon", k))


## One strip, twice across, at `alpha` (none drawn at 0). On a mirrored stage each copy is
## flipped in place (a negative width), where it was: a strip that tiles seamlessly still does.
func _draw_layer(tex: Texture2D, layer: String, alpha: float, of_theme: Dictionary) -> void:
	if tex == null or alpha <= 0.0:
		return
	var tw := float(tex.get_width())
	var y0 := layer_bottom(layer, hill, of_theme) - tex.get_height()
	var x0 := layer_x(offset, layer, tw, of_theme)
	var tint := Color(1, 1, 1, alpha)
	var size := Vector2(-tw if mirrored else tw, tex.get_height())
	draw_texture_rect(tex, Rect2(Vector2(x0, y0), size), false, tint)
	draw_texture_rect(tex, Rect2(Vector2(x0 + tw, y0), size), false, tint)


## A sky color `key` of `of_theme`, `k` of the way to `next`'s (its own with no next).
static func sky_color(of_theme: Dictionary, next: Dictionary, key: String, k: float) -> Color:
	var c: Color = of_theme[key]
	return c if next.is_empty() else c.lerp(next[key], k)


## The path of a stage's `layer` strip, from the far strip's path.
static func layer_path(far_path: String, layer: String) -> String:
	return far_path.replace("_far.", "_%s." % layer)


## Where `layer`'s first strip copy starts for a scroll of `offset` (turns of the far
## strip) on a strip `width` wide: the layer's scroll_rate times the far strip's pixels.
static func layer_x(offset: float, layer: String, width: float, of_theme: Dictionary = {}) -> float:
	return strip_x(offset * SCROLL_WIDTH * scroll_rate(of_theme, layer) / width, width)


## The screen row of `layer`'s bottom edge with the horizon moved `hill` pixels down.
static func layer_bottom(layer: String, hill: float, of_theme: Dictionary = {}) -> float:
	return roundf(Cfg.HORIZON_Y + SINK[layer] + hill * hill_rate(of_theme, layer))


## How fast `layer` scrolls on `of_theme` (SCROLL_RATE; a reflection moves with its far strip).
static func scroll_rate(of_theme: Dictionary, layer: String) -> float:
	if of_theme.get("reflection", false) and layer in [REFLECTION_SCROLL, REFLECTION_HILL]:
		return SCROLL_RATE[REFLECTION_SCROLL]
	return SCROLL_RATE[layer]


## The share of the hill shift `layer` moves by on `of_theme` (HILL_RATE; a reflection and its
## far strip both sit on the road).
static func hill_rate(of_theme: Dictionary, layer: String) -> float:
	if of_theme.get("reflection", false) and layer in [REFLECTION_SCROLL, REFLECTION_HILL]:
		return HILL_RATE[REFLECTION_HILL]
	return HILL_RATE[layer]


## How far down (pixels; up is negative) the horizon moves when the road HILL_AHEAD ahead
## is `rise` world units above the road under the camera (camera `depth`): as far as that
## road moved on the screen, so a climb lifts the scenery over the rising road and a crest
## drops it onto the falling one.
static func hill_shift(rise: float, depth: float) -> float:
	return roundf(clampf(-rise * depth / HILL_AHEAD * Cfg.PROJ, -HILL_MAX, HILL_MAX))


## The hill shift as the race shows it: none with reduce motion (Settings.motion_amount).
static func shown_hill(rise: float, depth: float) -> float:
	return Settings.motion_amount(hill_shift(rise, depth))


## Where the first of the two strip copies starts (a whole pixel, at or left of 0) for an
## `offset` of 0..1 round a strip `width` wide; the second follows it.
static func strip_x(offset: float, width: float) -> float:
	return roundf(-fposmod(offset * width, width))
