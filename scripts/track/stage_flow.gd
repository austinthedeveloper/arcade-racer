class_name StageFlow
extends RefCounted
## Stage flow (WS-8): each stage's end dresses like the next stage's start. Over the run-in
## to the finish the road, ground and sky turn toward the next stage's palette, and past the
## line its roadside (a landmark and its verge) stands among this stage's. The results then
## crossfade the rest of the way: the road turns ROAD_SHARE of the way, the results the rest. Skyline, the last stage, keeps its own end.
##
## Display only: the dressing stands well off the road, and nothing in play reads the palette.

## The palette starts to turn this many segments before the finish line...
const BLEND_FROM := 150
## ...and has turned as far as the road takes it (ROAD_SHARE) this many past it.
const BLEND_TO := 40
const ROAD_SHARE := 0.6
## Seconds the results take to fade the scene the rest of the way (crossfade).
const CROSSFADE := 2.0
## Mixed palettes worked out per stage (Track.flow), so a frame never mixes colors itself.
const STEPS := 8
## The theme keys that are colors (or [band 0, band 1] pairs of them), mixed by mix.
const PALETTE_KEYS := ["sky_top", "sky_bottom", "fog", "below_horizon", "grass", "sand", "rumble", "road", "lane"]
## The verge: a prop each side every VERGE_EVERY segments from BLEND_FROM before the finish
## to the end of the stage, VERGE_OFFSET road half-widths out (and up to VERGE_SPREAD more),
## clear of the finish crowd (CROWD before the line to CROWD_AFTER past it).
const VERGE_EVERY := 10
const VERGE_OFFSET := 2.3
const VERGE_SPREAD := 0.8
const CROWD := 64
const CROWD_AFTER := 6
## The landmark stands this many segments past the line, LANDMARK_OFFSET out on the right:
## in view as the car stops and the results come up.
const LANDMARK_AT := 45
const LANDMARK_OFFSET := 2.6
## What each stage's start looks like, by stage (Stages order): its landmark and the verge
## props that line its first stretch. Palm Coast comes first, so no stage hands over to it.
const DRESSING := [
	{},
	{"landmark": "butte", "verge": ["saguaro_a", "saguaro_b", "saguaro_c"]},  # Redrock's open desert
	{"landmark": "casino_lotus", "verge": ["palm_lit", "neon_star"]},  # into town on the Strip
	{"landmark": "cabin", "verge": ["pine_a", "pine_b", "pine_c"]},  # Timberline's valley cabins
	{"landmark": "bait_shop", "verge": ["cypress_a", "cypress_b", "cypress_c"]},  # the Bayou landing
	{"landmark": "barn", "verge": ["corn", "oak", "sunflowers"]},  # Harvest's pastures and farm
	{"landmark": "truck_stop", "verge": ["pole_a", "tree_windswept", "tree_snapped"]},  # the plains
	{"landmark": "harbor_crane", "verge": ["harbor_lamp", "tower_glass"]},  # Skyline's waterfront
]


## Dresses stage `index`'s end like the next stage's start: its palette (Track.next_theme,
## the mixed steps in Track.flow and each segment's share, Segment.handover) and its
## landmark and verge past the finish crowd. The last stage is left as it is.
static func dress(t: Track, index: int) -> void:
	var next := Stages.next(index)
	if next < 0:
		return
	t.next_theme = Stages.theme(next)
	t.flow.clear()
	for k in STEPS + 1:
		t.flow.append(mix(t.theme, t.next_theme, float(k) / STEPS))
	for seg in t.segments:
		seg.handover = blend(seg.index, t.finish_index)
	var look: Dictionary = DRESSING[next]
	var verge: Array = look["verge"]
	var k := 0
	for i in range(t.finish_index - BLEND_FROM, t.segments.size(), VERGE_EVERY):
		if i >= t.finish_index - CROWD and i <= t.finish_index + CROWD_AFTER:
			continue
		for side: float in [-1.0, 1.0]:
			if t.open_roadside(i):
				var out := VERGE_OFFSET + VERGE_SPREAD * fposmod(k * 0.37, 1.0)
				t.add_sprite(i, verge[k % verge.size()], side * out, side < 0.0)
			k += 1
	var at := t.finish_index + LANDMARK_AT
	if t.open_roadside(at):
		t.add_sprite(at, look["landmark"], LANDMARK_OFFSET)


## A segment's share of the next stage's palette: none until BLEND_FROM before the finish
## line, easing to ROAD_SHARE BLEND_TO past it, and that from there to the end.
static func blend(index: int, finish: int) -> float:
	return ROAD_SHARE * smoothstep(float(finish - BLEND_FROM), float(finish + BLEND_TO), float(index))


## How far the results have faded the scene to the next stage's palette, `age` seconds after
## they came up (negative: not up).
static func crossfade(age: float) -> float:
	return 0.0 if age < 0.0 else smoothstep(0.0, CROSSFADE, age)


## The share of the next stage's palette shown on a stretch of road whose own share is
## `road_share` (Segment.handover): that, then faded the rest of the way to all of it as the
## results come up (`results_age` seconds ago, negative before).
static func share(road_share: float, results_age: float) -> float:
	return lerpf(road_share, 1.0, crossfade(results_age))


## Theme `a` with its palette (PALETTE_KEYS and the fog density) `t` of the way to `b`'s.
## Everything else is `a`'s.
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := a.duplicate()
	for key: String in PALETTE_KEYS:
		var from: Variant = a[key]
		var to: Variant = b[key]
		if from is Color:
			out[key] = (from as Color).lerp(to, t)
		else:
			out[key] = [(from[0] as Color).lerp(to[0], t), (from[1] as Color).lerp(to[1], t)]
	out["fog_density"] = lerpf(a.get("fog_density", Cfg.FOG_DENSITY), b.get("fog_density", Cfg.FOG_DENSITY), t)
	return out


## The mixed palette for `share` of the way to the next stage's (to the nearest step), or the
## stage's own theme on a stage with no next.
static func palette(t: Track, share_of_next: float) -> Dictionary:
	if t.flow.is_empty():
		return t.theme
	return t.flow[roundi(clampf(share_of_next, 0.0, 1.0) * STEPS)]
