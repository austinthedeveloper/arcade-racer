class_name UiScale
extends RefCounted
## UI scale (AC-12): NORMAL or LARGE, for a TV across the room or a small phone. The option is
## Settings.ui_scale. The game still renders at 640x360, so LARGE is not a zoom:
## - the HUD grows each element about its own corner (Hud.layout takes the scale), the text
##   drawn sharp at the bigger size (UiText.begin_scaled), nothing overlapping (test_hud);
## - the menus keep their layout and draw their text bigger (MenuScreen._text goes through
##   menu_px), the small text most, so every page picks it up. A page that measures text for
##   its layout measures it with MenuScreen._width, at the size it is drawn.

enum Size { NORMAL, LARGE }

const NAMES := ["NORMAL", "LARGE"]
## How much bigger each HUD element is drawn.
const HUD := [1.0, 1.25]
## The menus' text at LARGE: a quarter bigger, at least 2 and at most MENU_MAX_GROW pixels more,
## so small print grows the most and big titles little (they still fit their bars).
const MENU_GROW := 0.25
const MENU_MIN_GROW := 2
const MENU_MAX_GROW := 4


## The HUD's scale at `size` (a Size).
static func hud(size: int) -> float:
	return HUD[clampi(size, 0, Size.size() - 1)]


## The size menu text `px` high is drawn at with the UI scale `size`.
static func menu_px(px: int, size: int) -> int:
	if size == Size.NORMAL:
		return px
	return px + clampi(roundi(px * MENU_GROW), MENU_MIN_GROW, MENU_MAX_GROW)


## The scale the options set (Settings.ui_scale).
static func now() -> int:
	return Settings.ui_scale


## A rect scaled by `k` about `anchor` (a point on the screen): a corner element grows away
## from its corner, a centered one about its middle.
static func about(r: Rect2, anchor: Vector2, k: float) -> Rect2:
	return Rect2(anchor + (r.position - anchor) * k, r.size * k)


## The transform that draws a thing laid out at 1x about `anchor` at `k` times the size.
static func transform_about(anchor: Vector2, k: float) -> Transform2D:
	return Transform2D(0.0, Vector2(k, k), 0.0, anchor * (1.0 - k))
