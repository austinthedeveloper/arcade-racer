class_name Headlights
extends RefCounted
## Headlights at night (WS-17): on the dark stages (a theme with "headlights": Neon Strip,
## Thunderhead, Skyline) and on any stage a Grand Tour shows dark enough (Sundown), every car
## throws a pool of light on the road ahead of it (the player, the rivals, the traffic; the
## oncoming traffic's pool comes toward the camera) and the tail lights glow brighter.
## Display only. The pools are plain functions of a car's z and x, so a test can follow them.

const COLOR := Color(1.0, 0.94, 0.72)  # warm halogen
const TAIL := Color(1.0, 0.16, 0.1)
## A pool starts GAP world units ahead of a car's z (its nose) and runs world/headlight_reach.
const GAP := 300.0
## The headlights come on in a tour on a stage tinted at least this dark (Sundown.darkness).
const DARK_FROM := 0.45
## Pools are drawn within this many segments of the camera (each is more triangles).
const REACH_SEGMENTS := 90


## Whether the headlights are on for a theme (as shown, Sundown.theme_at).
static func on(theme: Dictionary) -> bool:
	return theme.get("headlights", false) or Sundown.darkness(Sundown.light_of(theme)) >= DARK_FROM


## The pool `along` (0 at its start to 1 at its end) of the way out from a car at `x` (road
## half-widths from the center, as PlayerCar.x and a traffic car's offset): x its center,
## which is the car's, y its half-width, z its strength (fading out to the end).
static func pool(x: float, along: float) -> Vector3:
	var a := clampf(along, 0.0, 1.0)
	var half := lerpf(Tuning.v("world/headlight_near"), Tuning.v("world/headlight_spread"), sqrt(a))
	var strength := Tuning.v("world/headlight_alpha") * pow(1.0 - a, 1.5) * smoothstep(0.0, 0.08, a)
	return Vector3(x, half, strength)


## Where a car's pool lies on a segment starting at world z `seg_z` (Cfg.SEGMENT_LENGTH long)
## on a track `length` long: the car's z is `car_z`, its pool going `dir` (1 ahead, -1 toward
## the camera for the oncoming traffic). x and y: the part of the segment lit (0..1 along it,
## near end then far end), z and w: how far out along the pool those are (0..1). Vector4(-1)
## when the pool doesn't reach the segment.
static func slice(seg_z: float, car_z: float, dir: float, length: float) -> Vector4:
	var reach := Tuning.v("world/headlight_reach")
	var start := car_z + dir * GAP
	# The segment's ends, as distances out along the pool (wrapped round the lap)
	var d1 := wrapf((seg_z - start) * dir, -length * 0.5, length * 0.5)
	var d2 := d1 + Cfg.SEGMENT_LENGTH * dir
	var lo := maxf(minf(d1, d2), 0.0)
	var hi := minf(maxf(d1, d2), reach)
	if hi <= lo:
		return Vector4(-1, -1, -1, -1)
	# Back to fractions of the segment, its near end first
	var p_lo := (lo - d1) / (d2 - d1)
	var p_hi := (hi - d1) / (d2 - d1)
	if p_lo <= p_hi:
		return Vector4(p_lo, p_hi, lo / reach, hi / reach)
	return Vector4(p_hi, p_lo, hi / reach, lo / reach)


## The tail lights' glow on a car whose rear is `w` wide and `h` tall standing at `base`: one
## rect each side, low on the back; `halo` the bigger, fainter one around it.
static func tail_rects(base: Vector2, w: float, h: float, halo := false) -> Array[Rect2]:
	var y := base.y - minf(h * 0.32, w * 0.26)
	var size := Vector2(w * 0.17, maxf(1.0, w * 0.06)) * (2.0 if halo else 1.0)
	var out: Array[Rect2] = []
	for side in [-1.0, 1.0]:
		var c := Vector2(base.x + side * w * 0.34, y)
		out.append(Rect2(c - size / 2.0, size))
	return out
