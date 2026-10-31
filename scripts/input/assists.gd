class_name Assists
extends RefCounted
## Driving assists (Options, Game page), both off by default. They add to the player's input
## and never take it over: each stays under its cap.
## - Steering assist (keyboard and gamepad): at speed, pulls the car toward the middle of the
##   nearest lane and leans into the curve, fading out while the player steers.
## - Braking assist (any device): brakes before a corner the car is too fast for, judged by
##   the car's own grip: how much lock it would need to hold the curve (PlayerCar.update).

const STEER_CAP := 0.3  # the most the steering assist adds to the steering, of full lock
const BRAKE_CAP := 0.5  # the most the braking assist brakes, of full brake
const STEER_GAIN := 1.5  # lock per road half-width off the lane centre
const STEER_FROM := 0.3  # speed fraction where the steering assist starts...
const STEER_FULL := 0.7  # ...and where it is at full strength
## A corner is taken at the speed that needs this much of full lock to hold it.
const CORNER_LOCK := 0.8
const LOOKAHEAD := 80  # segments of road ahead the braking assist reads
## The braking the assist plans on (under its cap, so it is done braking by the corner).
const PLAN_DECEL := Cfg.BRAKING * BRAKE_CAP * 0.6
const BRAKE_RAMP := Cfg.MAX_SPEED * 0.04  # this far over the corner speed, full assist braking


## The input after the assists that are on. Returns `inp` itself when neither changes it.
static func apply(inp: DriveInput, car: PlayerCar, track: Track, steer_on: bool, brake_on: bool) -> DriveInput:
	if not steer_on and not brake_on:
		return inp
	var out := inp.copy()
	var seg := track.find_segment(car.position + Cfg.PLAYER_Z)
	if steer_on and inp.kind != DriveInput.Kind.WHEEL:
		out.steer = clampf(inp.steer + steer_help(inp.steer, car.x, car.speed_percent(), seg.curve, car), -1.0, 1.0)
	if brake_on:
		var assist := brake_help(car.speed, corner_speed_ahead(car, track, seg.index))
		out.brake = maxf(inp.brake, assist)
		out.throttle = inp.throttle * (1.0 - assist / BRAKE_CAP)  # lift off while it brakes
	return out


## The steering the assist adds (within +-STEER_CAP): toward the nearest lane's centre plus
## the lock that holds the curve, scaled up with speed and down as the player steers.
## Off the road it leaves the car alone.
static func steer_help(steer_in: float, x: float, pct: float, curve: float, car: PlayerCar) -> float:
	if absf(x) > 1.0:
		return 0.0
	var lane := nearest_lane(x)
	var hold := pct * curve * Cfg.CENTRIFUGAL * car.pull_mult / car.steer_mult
	var want := (lane - x) * STEER_GAIN + hold
	var strength := smoothstep(STEER_FROM, STEER_FULL, pct) * (1.0 - clampf(absf(steer_in), 0.0, 1.0))
	return clampf(want, -STEER_CAP, STEER_CAP) * strength


static func nearest_lane(x: float) -> float:
	var best: float = Traffic.LANE_OFFSETS[0]
	for lane: float in Traffic.LANE_OFFSETS:
		if absf(lane - x) < absf(best - x):
			best = lane
	return best


## The fastest the car can hold a curve of `curve` using CORNER_LOCK of its steering
## (world units per second); INF on a straight or a curve it can take flat out.
static func corner_speed(curve: float, car: PlayerCar) -> float:
	var need := absf(curve) * Cfg.CENTRIFUGAL * car.pull_mult / car.steer_mult  # lock per unit of speed fraction
	if need <= 0.0001:
		return INF
	var pct := CORNER_LOCK / need
	return INF if pct >= 1.0 else pct * Cfg.MAX_SPEED


## The fastest the car may go now and still slow (at PLAN_DECEL) for every corner in the
## next LOOKAHEAD segments from segment `from`.
static func corner_speed_ahead(car: PlayerCar, track: Track, from: int) -> float:
	var limit := INF
	var n := track.segments.size()
	for i in LOOKAHEAD:
		var v := corner_speed(track.segments[(from + i) % n].curve, car)
		if v == INF:
			continue
		var dist := i * Cfg.SEGMENT_LENGTH
		limit = minf(limit, sqrt(v * v + 2.0 * PLAN_DECEL * dist))
	return limit


## How hard the assist brakes at `speed` with `limit` allowed: none under it, BRAKE_CAP from
## BRAKE_RAMP over it.
static func brake_help(speed: float, limit: float) -> float:
	if limit == INF or speed <= limit:
		return 0.0
	return clampf((speed - limit) / BRAKE_RAMP, 0.0, 1.0) * BRAKE_CAP
