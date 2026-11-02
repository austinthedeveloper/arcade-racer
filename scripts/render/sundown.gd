class_name Sundown
extends RefCounted
## Sundown across the tour (WS-16): every stage has its own hour of the day (its theme's
## "hour", 0..24), the light it was drawn in. A Grand Tour runs the clock instead, from
## world/tour_start_hour on the first stage to world/tour_end_hour on the last, so the sun
## drops stage by stage and the tour ends at night on Skyline; a single race keeps the stage's
## own hour. A stage shown later than its own hour is tinted toward that light (its sky, road
## and ground colors, its background strips and its sprites) and the cars' shadows grow long
## while the sun is low; one shown earlier than its own hour stays as drawn (Neon Strip is a
## night stage, in a tour or not). Display only, like the weather.

## The color of the light through the day, (hour, color) in order: night, dawn, day, the
## golden hour, dusk, night again. light() blends between them.
const LIGHT := [
	[0.0, Color(0.32, 0.34, 0.55)],
	[5.0, Color(0.36, 0.38, 0.6)],
	[6.5, Color(1.0, 0.82, 0.72)],
	[9.0, Color(1.0, 1.0, 1.0)],
	[16.0, Color(1.0, 1.0, 1.0)],
	[17.5, Color(1.0, 0.9, 0.76)],
	[19.0, Color(0.98, 0.72, 0.56)],
	[20.0, Color(0.74, 0.56, 0.64)],
	[21.0, Color(0.46, 0.43, 0.63)],
	[22.0, Color(0.33, 0.35, 0.56)],
	[24.0, Color(0.32, 0.34, 0.55)],
]
## The theme's colors the tint applies to (one color or a pair each). Neon tubes
## ("tunnel_lights") are lights themselves and keep their color.
const TINTED := ["sky_top", "sky_bottom", "fog", "below_horizon", "grass", "sand", "rumble", "road", "lane"]
## The sun is low from SHADOW_FROM to SHADOW_LONGEST (shadows grow to world/shadow_stretch),
## then sets by SHADOW_GONE (back to the plain shadow under the car).
const SHADOW_FROM := 15.0
const SHADOW_LONGEST := 19.5
const SHADOW_GONE := 20.5
const DEFAULT_HOUR := 15.0  # a theme without an "hour"


## A theme's own hour.
static func own_hour(theme: Dictionary) -> float:
	return float(theme.get("hour", DEFAULT_HOUR))


## The tour's hour on stage `index` of `count`: tour_start_hour on the first, tour_end_hour
## on the last, evenly between.
static func tour_hour(index: int, count: int) -> float:
	var k := float(index) / float(maxi(1, count - 1))
	return lerpf(Tuning.v("world/tour_start_hour"), Tuning.v("world/tour_end_hour"), clampf(k, 0.0, 1.0))


## The hour a stage is shown at: the tour's in a Grand Tour, else its own.
static func shown_hour(theme: Dictionary, index: int, count: int, in_tour: bool) -> float:
	return tour_hour(index, count) if in_tour else own_hour(theme)


## The color of the light at `hour` (LIGHT, blended).
static func light(hour: float) -> Color:
	var h := fposmod(hour, 24.0)
	for i in range(1, LIGHT.size()):
		if h <= LIGHT[i][0]:
			var a: Array = LIGHT[i - 1]
			var b: Array = LIGHT[i]
			return (a[1] as Color).lerp(b[1], inverse_lerp(a[0], b[0], h))
	return LIGHT[-1][1]


## The tint for a stage drawn at `own` shown at `hour`: the light then over the light it was
## drawn in, channel by channel, never brighter than drawn; `strength` of the way there
## (world/sundown_tint). White when the hours match.
static func tint(own: float, hour: float, strength := 1.0) -> Color:
	var from := light(own)
	var to := light(hour)
	var ratio := Color(minf(1.0, to.r / from.r), minf(1.0, to.g / from.g), minf(1.0, to.b / from.b))
	return Color.WHITE.lerp(ratio, clampf(strength, 0.0, 1.0))


## How dark a tint is, 0 (as drawn) to 1 (black): the headlights come on past a point.
static func darkness(t: Color) -> float:
	return clampf(1.0 - t.get_luminance(), 0.0, 1.0)


## A theme shown at `hour`: a copy with its colors (TINTED) multiplied by the tint, and
## "hour_shown" and "light" (the tint) for the renderer. Everything else as it was.
static func theme_at(theme: Dictionary, hour: float) -> Dictionary:
	if theme.is_empty():
		return theme
	var t := tint(own_hour(theme), hour, Tuning.v("world/sundown_tint"))
	var out := theme.duplicate()
	for key: String in TINTED:
		if not out.has(key):
			continue
		var v: Variant = out[key]
		if v is Color:
			out[key] = (v as Color) * t
		elif v is Array:
			var pair: Array = []
			for c: Color in v:
				pair.append(c * t)
			out[key] = pair
	out["hour_shown"] = hour
	out["light"] = t
	return out


## Shows `track` (stage `index` of `count`) at its hour: the tour's in a Grand Tour
## (`in_tour`), else its own. Its theme and the next stage's, which its end turns to, are
## tinted for their hours, and the steps between them (StageFlow.dress) made again. Returns
## the hour.
static func apply(track: Track, index: int, count: int, in_tour: bool) -> float:
	var hour := shown_hour(track.theme, index, count, in_tour)
	track.theme = theme_at(track.theme, hour)
	if not track.next_theme.is_empty():
		track.next_theme = theme_at(track.next_theme, shown_hour(track.next_theme, index + 1, count, in_tour))
		track.flow.clear()
		for k in StageFlow.STEPS + 1:
			track.flow.append(StageFlow.mix(track.theme, track.next_theme, float(k) / StageFlow.STEPS))
	return hour


## A theme's tint as shown (theme_at's "light"): white for one shown at its own hour.
static func light_of(theme: Dictionary) -> Color:
	return theme.get("light", Color.WHITE)


## The hour a theme is lit for: the hour it is shown at (theme_at's "hour_shown"), or its own
## when that is later (a stage is never shown in an earlier light than it was drawn in).
static func lit_hour(theme: Dictionary) -> float:
	return maxf(own_hour(theme), float(theme.get("hour_shown", own_hour(theme))))


## How long the cars' shadows are at `hour`, times the plain one: 1 by day, growing to
## world/shadow_stretch as the sun gets low, back to 1 once it has set.
static func shadow_length(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= SHADOW_GONE or h <= SHADOW_FROM:
		return 1.0
	var longest := Tuning.v("world/shadow_stretch")
	if h <= SHADOW_LONGEST:
		return lerpf(1.0, longest, smoothstep(SHADOW_FROM, SHADOW_LONGEST, h))
	return lerpf(longest, 1.0, inverse_lerp(SHADOW_LONGEST, SHADOW_GONE, h))
