class_name Weather
extends RefCounted
## A stage's weather, from its theme's "weather" (Thunderhead's is STORM): rain streaks over
## the road, a wet road that catches the sky, and lightning: a full-screen flash, then thunder
## a beat later. The FX layer draws it and the race audio plays the thunder; like them it is
## purely for show, and its timing comes from a generator of its own, so play can't tell.
##
## Keys: "rain" (0..1, how many streaks), "wet" (0..1, how far the far road goes toward the
## sky's color), "lightning" (strikes or not), "seed" (the strike pattern).

const STORM := {"rain": 1.0, "wet": 0.35, "lightning": true, "seed": 1974}

## Lightning: the first strike FIRST_MIN..FIRST_MAX seconds in, then GAP_MIN..GAP_MAX apart.
## A strike's strength (STRENGTH_MIN..1) sets its flash, and its thunder comes THUNDER_NEAR
## (strongest, closest) to THUNDER_FAR seconds after it.
const FIRST_MIN := 4.0
const FIRST_MAX := 9.0
const GAP_MIN := 7.0
const GAP_MAX := 15.0
const STRENGTH_MIN := 0.5
const THUNDER_NEAR := 0.5
const THUNDER_FAR := 1.6
const STRIKES_UNTIL := 900.0  # seconds of strikes made up front (longer than any race)
## The flash: FLASH_ALPHA at its peak, over FLASH_TIME seconds, in FLASH_COLOR.
const FLASH_ALPHA := 0.7
const FLASH_TIME := 0.5
const FLASH_COLOR := Color(0.88, 0.92, 1.0)

## Rain: up to RAIN_DROPS streaks, falling RAIN_FALL pixels per second, slanted by RAIN_WIND,
## RAIN_LENGTH pixels long standing still and RAIN_STRETCH more at top speed, when they also
## stream out from the middle of the screen (RAIN_SPREAD) as the car drives into them.
const RAIN_DROPS := 90
const RAIN_FALL := 520.0
const RAIN_WIND := -0.2
const RAIN_LENGTH := 8.0
const RAIN_STRETCH := 14.0
const RAIN_SPREAD := 0.5
const RAIN_COLOR := Color(0.8, 0.85, 0.97, 0.5)


## The theme's weather, or {} for clear skies.
static func of(theme: Dictionary) -> Dictionary:
	return theme.get("weather", {})


## The strikes up to `until` seconds for `seed`, in order: x is when the flash comes, y when
## its thunder does, z its strength (STRENGTH_MIN..1). The same seed always gives the same
## storm. `forced` (seconds, NAN for none) adds a full-strength strike then (screenshots).
static func strikes(seed: int, until: float = STRIKES_UNTIL, forced: float = NAN) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[Vector3] = []
	var t := rng.randf_range(FIRST_MIN, FIRST_MAX)
	while t < until:
		var strength := rng.randf_range(STRENGTH_MIN, 1.0)
		out.append(Vector3(t, t + thunder_delay(strength), strength))
		t += rng.randf_range(GAP_MIN, GAP_MAX)
	if not is_nan(forced):
		out.append(Vector3(forced, forced + thunder_delay(1.0), 1.0))
		out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	return out


## Seconds from a strike of `strength` to its thunder: the strong ones are close.
static func thunder_delay(strength: float) -> float:
	return lerpf(THUNDER_FAR, THUNDER_NEAR, inverse_lerp(STRENGTH_MIN, 1.0, clampf(strength, STRENGTH_MIN, 1.0)))


## A flash `age` seconds after its strike, 0..1: a bright flicker, a dip, a second flicker,
## then it dies away by FLASH_TIME.
static func flash_shape(age: float) -> float:
	if age < 0.0 or age >= FLASH_TIME:
		return 0.0
	if age < 0.05:
		return 1.0
	if age < 0.1:
		return 0.35
	if age < 0.15:
		return 0.85
	return 0.85 * (1.0 - (age - 0.15) / (FLASH_TIME - 0.15))


## The flash as designed at time `t` (before the flash option): the brightest of the strikes'.
static func flash_at(t: float, storm: Array[Vector3]) -> float:
	var out := 0.0
	for s in storm:
		if s.x > t:
			break
		out = maxf(out, flash_shape(t - s.x) * s.z * FLASH_ALPHA)
	return out


## Whether thunder rolls between `t0` (not counted) and `t1`.
static func thunder_between(t0: float, t1: float, storm: Array[Vector3]) -> bool:
	for s in storm:
		if s.y > t0 and s.y <= t1:
			return true
	return false


## The flash that shows after the flash option: `share` is Settings.flash_amount(1.0), so
## none at 0.
static func shown_flash(designed: float, share: float) -> float:
	return designed * clampf(share, 0.0, 1.0)


## How many rain streaks show for a theme's weather.
static func drop_count(weather: Dictionary) -> int:
	return int(RAIN_DROPS * clampf(weather.get("rain", 0.0), 0.0, 1.0))


## One rain streak, its two ends on screen: `drop` is where it starts (x and y as fractions
## of the screen, z a speed factor near 1), at time `t` with the car at `pct` of top speed.
static func rain_streak(drop: Vector3, t: float, pct: float) -> PackedVector2Array:
	var w := float(Cfg.SCREEN_W)
	var h := float(Cfg.SCREEN_H)
	var length := RAIN_LENGTH + RAIN_STRETCH * clampf(pct, 0.0, 1.0)
	var y := fposmod(drop.y * h + t * RAIN_FALL * drop.z, h + length)
	var x := fposmod(drop.x * w + y * RAIN_WIND, w)
	var lean := RAIN_WIND + (x - w * 0.5) / w * RAIN_SPREAD * clampf(pct, 0.0, 1.0)
	var head := Vector2(x, y)
	return PackedVector2Array([head - Vector2(lean * length, length), head])


## Cover (WS-12): the stretches of road with a roof over the camera, where the rain stops and
## the thunder comes muffled. Inside a tunnel or covered bridge (Segment.covered) from its
## entrance to its exit, and under a span that is a deck over the road for SHELTER_SPANS
## world units past the span (the sprite is flat, but the bridge it shows is not).
## Real overpasses are 15 to 30 m deep: about 12 segments, a fifth of a second flat out.
const SHELTER_SPANS := {"thunder_overpass": 2400.0, "harvest_trestle": 1200.0, "redrock_arch": 1600.0}
## The rain thins out over this many world units at a cover's edges rather than cutting off.
const SHELTER_FADE := 200.0
## Shelter (0..1) from which the thunder is muffled (Audio.play's muffled: a low-pass, quieter).
const MUFFLE_FROM := 0.5


## A road color `c` wet by `wet` (0..1), reflecting `sky` more the farther off it is (`far`,
## 0 at the car to 1 at the draw distance), as wet asphalt does at a low angle. `sheen`
## multiplies how far it goes (world/wet_sheen, WS-13); `gloss` is the share of that left
## right under the car (world/wet_gloss).
static func wet_color(c: Color, sky: Color, wet: float, far: float, sheen := 1.0, gloss := 0.0) -> Color:
	var k := lerpf(clampf(gloss, 0.0, 1.0), 1.0, sqrt(clampf(far, 0.0, 1.0)))
	return c.lerp(sky, clampf(clampf(wet, 0.0, 1.0) * sheen * k, 0.0, 1.0))


## Reflections in the wet road (WS-13): where in a background strip a road point reflects.
## The strip sits on screen at `layer` (Background.layer_rect: x, y, width, height); a point
## `p` on the road below the `horizon` row shows the strip's point as far above the horizon
## as `p` is below it, divided by `stretch` (the reflection drawn out down the road into
## streaks), as a texture coordinate. `mirrored`: the strip is drawn flipped (WS-6). The row
## is kept inside the strip (half a texel in), so the near road never wraps to its other edge.
static func reflect_uv(p: Vector2, horizon: float, layer: Rect2, stretch: float, mirrored := false) -> Vector2:
	var src_y := horizon - (p.y - horizon) / maxf(stretch, 0.01)
	var v := clampf((src_y - layer.position.y) / layer.size.y, 0.5 / layer.size.y, 1.0 - 0.5 / layer.size.y)
	var u := (p.x - layer.position.x) / layer.size.x
	return Vector2(1.0 - u if mirrored else u, v)


## How strongly the reflections show on a segment: `alpha` (world/reflect_alpha) for a road
## `wet` (0..1), fainter near the car (`far` 0) than off at a low angle (`far` 1), and gone
## into the `fog`.
static func reflect_strength(alpha: float, wet: float, far: float, fog: float) -> float:
	return clampf(alpha * sqrt(clampf(wet, 0.0, 1.0)) * lerpf(0.5, 1.0, sqrt(clampf(far, 0.0, 1.0))) * (1.0 - fog), 0.0, 1.0)


## A puddle on segment `index` (WS-13), or Vector4.ZERO for none: x its center and y its
## half-width across the road (road half-widths, as on an unmirrored road: multiply x by
## Track.side), z and w where it starts and ends along the segment (0..1). `share` of the
## segments have one (world/puddle_share). The same segment always gets the same puddle.
static func puddle(index: int, share: float) -> Vector4:
	var h := hash(index * 7919 + 104729)
	if float(h % 1000) / 1000.0 >= share:
		return Vector4.ZERO
	var a := float((h / 1000) % 1000) / 1000.0
	var b := float((h / 1000000) % 1000) / 1000.0
	var start := 0.1 + 0.3 * b
	return Vector4(lerpf(-0.7, 0.7, a), lerpf(0.12, 0.28, b), start, start + 0.45)


## A puddle's highlight color: the sky it reflects, lightened, at `glint` (world/puddle_glint)
## for a puddle `fog` into the fog, shimmering a little with the rain (`t` seconds, `index`
## its segment).
static func puddle_color(sky: Color, glint: float, fog: float, t: float, index: int) -> Color:
	var shimmer := 0.85 + 0.15 * sin(t * 7.0 + index * 1.7)
	return Color(sky.lightened(0.35), clampf(glint * shimmer * (1.0 - fog), 0.0, 1.0))


## The covered stretches of `track` (cover above), as world z ranges: x where the roof starts,
## y where it ends, in order along the road. A plain function of the track: the same stage
## always gives the same cover, mirrored or not.
static func shelters(track: Track) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var run_start := -1.0
	for seg in track.segments:
		if seg.covered:
			if run_start < 0.0:
				run_start = maxf(0.0, seg.w1.z - Cfg.SEGMENT_LENGTH)  # from the entrance span
		elif run_start >= 0.0:
			out.append(Vector2(run_start, seg.w1.z))  # to the exit span
			run_start = -1.0
		for id in seg.spans:
			if SHELTER_SPANS.has(id):
				out.append(Vector2(seg.w1.z, seg.w1.z + SHELTER_SPANS[id]))
	if run_start >= 0.0:
		out.append(Vector2(run_start, track.length))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## How sheltered the camera at world z is (0 in the open, 1 under a roof), from `cover`
## (shelters): full a SHELTER_FADE in from a cover's ends, fading to 0 at them.
static func shelter_at(cover: Array[Vector2], z: float) -> float:
	var out := 0.0
	for c in cover:
		if c.x > z:
			break
		if z <= c.y:
			out = maxf(out, clampf(minf(z - c.x, c.y - z) / SHELTER_FADE, 0.0, 1.0))
	return out


## How many of `drops` rain streaks show with the camera `shelter`ed (0..1): all in the open,
## none under a roof.
static func drops_shown(drops: int, shelter: float) -> int:
	return int(roundf(drops * (1.0 - clampf(shelter, 0.0, 1.0))))


## Whether thunder heard from `shelter` comes muffled.
static func thunder_muffled(shelter: float) -> bool:
	return shelter >= MUFFLE_FROM
