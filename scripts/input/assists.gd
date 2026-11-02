class_name Assists
extends RefCounted
## Driving assists (Options, Game page), both off by default. They add to the player's input
## and never take it over: each stays under its cap.
## - Steering assist (keyboard and gamepad): at speed, pulls the car toward the middle of the
##   nearest lane and leans into the curve, fading out while the player steers.
## - Braking assist (any device): brakes before a corner the car is too fast for, judged by
##   the car's own grip: how much lock it would need to hold the curve (PlayerCar.update).
## Both read a slippery road's curves as sharper (curve / Segment.grip), as the steering does.
## - Co-pilot (AC-14, off by default): for the youngest drivers, the whole steering. It holds
##   the car in the middle of its lane and round the bends (co_pilot), and the player's
##   steering nudges it: held over, the car changes lane, and the co-pilot keeps it on the road.

const STEER_CAP := 0.3  # the most the steering assist adds to the steering, of full lock
const BRAKE_CAP := 0.5  # the most the braking assist brakes, of full brake
const STEER_GAIN := 1.5  # lock per road half-width off the lane centre
const STEER_FROM := 0.3  # speed fraction where the steering assist starts...
const STEER_FULL := 0.7  # ...and where it is at full strength
## A corner is taken at the speed that needs this much of full lock to hold it.
const CORNER_LOCK := 0.8
const LOOKAHEAD := 80  # segments of road ahead the braking assist reads
const BRAKE_RAMP := Cfg.MAX_SPEED * 0.04  # this far over the corner speed, full assist braking


## The input after the assists that are on. Returns `inp` itself when neither changes it.
static func apply(inp: DriveInput, car: PlayerCar, track: Track, steer_on: bool, brake_on: bool) -> DriveInput:
	if not steer_on and not brake_on:
		return inp
	var out := inp.copy()
	var seg := track.find_segment(car.position + Cfg.PLAYER_Z)
	if steer_on and inp.kind != DriveInput.Kind.WHEEL:
		out.steer = clampf(inp.steer + steer_help(inp.steer, car.x, car.speed_percent(), seg.curve / seg.grip, car, seg), -1.0, 1.0)
	if brake_on:
		var assist := brake_help(car.speed, corner_speed_ahead(car, track, seg.index))
		out.brake = maxf(inp.brake, assist)
		out.throttle = inp.throttle * (1.0 - assist / BRAKE_CAP)  # lift off while it brakes
	return out


## The input with the co-pilot steering (AC-14): the lock that holds the car in the middle of
## the nearest lane and against the curve's pull (co_pilot_steer), with the player's steering
## blended over it (co_pilot_share). Gas and brake are left to the player; the race adds the
## braking assist under it, for the bends too sharp to steer round flat out.
static func co_pilot(inp: DriveInput, car: PlayerCar, track: Track) -> DriveInput:
	var out := inp.copy()
	var seg := track.find_segment(car.position + Cfg.PLAYER_Z)
	var lanes := seg.lane_offsets()
	var auto := co_pilot_steer(car.x, car.speed_percent(), seg.curve, seg.grip, car, lanes)
	var share := co_pilot_share(inp.steer, car.x, outer_lane(lanes), seg.width)
	out.steer = clampf(auto * (1.0 - share) + signf(inp.steer) * share, -1.0, 1.0)
	return out


## How much of the steering the player's `steer` takes over from the co-pilot: up to
## assists/co_pilot_nudge for a full push, fading to none for a push further out past the
## outer lane's middle (`outer`) toward the road's edge (`edge`), so it stays on the road.
static func co_pilot_share(steer: float, x: float, outer: float, edge: float) -> float:
	var share := clampf(absf(steer), 0.0, 1.0) * Tuning.v("assists/co_pilot_nudge")
	if signf(steer) == signf(x) and absf(x) > outer:
		share *= clampf(1.0 - (absf(x) - outer) / maxf(edge - outer, 0.01), 0.0, 1.0)
	return share


## The middle of the outermost of `lanes`, either side (road half-widths from the middle).
static func outer_lane(lanes: Array) -> float:
	var out := 0.0
	for lane: float in lanes:
		out = maxf(out, absf(lane))
	return out


## The co-pilot's own steering for a car at `x` going `pct` of top speed on a road of `curve`
## and `grip` with `lanes` (Segment.lane_offsets): toward the nearest lane's middle, harder
## once past the outer lanes, plus the lock that cancels the curve's pull (PlayerCar.update).
static func co_pilot_steer(x: float, pct: float, curve: float, grip: float, car: PlayerCar, lanes: Array) -> float:
	var lane := nearest_lane(x, lanes)
	var want := (lane - x) * Tuning.v("assists/co_pilot_gain")
	var outer := outer_lane(lanes)
	if absf(x) > outer:
		want += (signf(x) * outer - x) * Tuning.v("assists/co_pilot_edge")
	if pct > 0.0:
		want += pct * curve * Tuning.v("driving/centrifugal") * car.pull_mult / (car.steer_mult * maxf(grip, 0.05))
	return clampf(want, -1.0, 1.0)


## The steering the assist adds (within +-STEER_CAP): toward the nearest lane's centre plus
## the lock that holds the curve, scaled up with speed and down as the player steers.
## Off the road it leaves the car alone. `seg` is the road under the car (its width and lanes,
## WS-7); null for the usual four lanes.
static func steer_help(steer_in: float, x: float, pct: float, curve: float, car: PlayerCar, seg: Segment = null) -> float:
	var lanes: Array = Traffic.LANE_OFFSETS if seg == null else seg.lane_offsets()
	if absf(x) > (1.0 if seg == null else seg.width):
		return 0.0
	var lane := nearest_lane(x, lanes)
	var hold := pct * curve * Tuning.v("driving/centrifugal") * car.pull_mult / car.steer_mult
	var want := (lane - x) * STEER_GAIN + hold
	var strength := smoothstep(STEER_FROM, STEER_FULL, pct) * (1.0 - clampf(absf(steer_in), 0.0, 1.0))
	return clampf(want, -STEER_CAP, STEER_CAP) * strength


## The middle of the lane nearest `x`, of `lanes` (the usual four by default).
static func nearest_lane(x: float, lanes: Array = Traffic.LANE_OFFSETS) -> float:
	var best: float = lanes[0]
	for lane: float in lanes:
		if absf(lane - x) < absf(best - x):
			best = lane
	return best


## The fastest the car can hold a curve of `curve` using CORNER_LOCK of its steering
## (world units per second); INF on a straight or a curve it can take flat out.
static func corner_speed(curve: float, car: PlayerCar) -> float:
	var need := absf(curve) * Tuning.v("driving/centrifugal") * car.pull_mult / car.steer_mult  # lock per unit of speed fraction
	if need <= 0.0001:
		return INF
	var pct := CORNER_LOCK / need
	return INF if pct >= 1.0 else pct * Cfg.MAX_SPEED


## The fastest the car may go now and still slow (planning on 60% of BRAKE_CAP, so it is done braking by the corner) for every
## corner in the next LOOKAHEAD segments from segment `from`.
static func corner_speed_ahead(car: PlayerCar, track: Track, from: int) -> float:
	var plan_decel := Cfg.MAX_SPEED / Tuning.v("driving/braking_time") * BRAKE_CAP * 0.6
	var limit := INF
	var n := track.segments.size()
	for i in LOOKAHEAD:
		var seg := track.segments[(from + i) % n]
		var v := corner_speed(seg.curve / seg.grip, car)
		if v == INF:
			continue
		var dist := i * Cfg.SEGMENT_LENGTH
		limit = minf(limit, sqrt(v * v + 2.0 * plan_decel * dist))
	return limit


## How hard the assist brakes at `speed` with `limit` allowed: none under it, BRAKE_CAP from
## BRAKE_RAMP over it.
static func brake_help(speed: float, limit: float) -> float:
	if limit == INF or speed <= limit:
		return 0.0
	return clampf((speed - limit) / BRAKE_RAMP, 0.0, 1.0) * BRAKE_CAP
