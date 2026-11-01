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


## A road color `c` wet by `wet` (0..1), reflecting `sky` more the farther off it is (`far`,
## 0 at the car to 1 at the draw distance), as wet asphalt does at a low angle.
static func wet_color(c: Color, sky: Color, wet: float, far: float) -> Color:
	return c.lerp(sky, clampf(wet, 0.0, 1.0) * sqrt(clampf(far, 0.0, 1.0)))
