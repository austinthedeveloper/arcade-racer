class_name AIDriver
extends RefCounted
## Drives a RivalCar: holds a line through the curves ahead, moves to an open lane round
## slower cars, and uses nitro on straights. Every choice comes from its own seeded RNG, so a
## race plays the same every time.

const LINE_FROM := 5  # segments ahead the racing line starts looking...
const LINE_TO := 30  # ...and stops
const STEER_AHEAD := 3000.0  # world units ahead the steering reads the curve (as the autodrive)
const STEER_CURVE := 0.25
const LOOKAHEAD := 50  # segments checked for slower cars in the way
const ONCOMING_SCAN := 2  # times LOOKAHEAD looked ahead for oncoming traffic
const ONCOMING_CAUTION := 0.4  # oncoming room counts this much of a standing car's (oncoming_gap)
const ONCOMING_CROSS_TIME := 1.0  # seconds before an oncoming car arrives that its lane can still be crossed
const LANE_CLEARANCE := 0.05  # road half-widths of room kept beside a car when passing
const CROSS_TIME := 0.3  # seconds ahead within which the way across to a new lane must be clear
const CORNER_AHEAD := 8  # segments ahead the corner speed reads the sharpest curve
const STRAIGHT_AHEAD := 40  # segments that must be nearly straight for nitro
const STRAIGHT_CURVE := 0.5
const BLOCK_FORGET := 0.5  # block seconds forgotten per second without a car to block, so a
                           # chaser dropping back for a moment doesn't restart the clock
const ERRATIC_REACT := 0.35  # seconds an erratic driver sticks to a lane before looking again...
const ERRATIC_LOOKAHEAD := 25  # ...seeing this many segments ahead
const SWERVE_BIAS := 0.5

var rng := RandomNumberGenerator.new()
var lane_bias := 0.0  # this driver's own spot across the road, added to the racing line
var side := 1.0  # -1 on a mirrored stage (Track.side): its spot and swerves go the other way
var style: RivalProfile.Style = RivalProfile.Style.CLEAN
var target := 0.0  # where across the road it is heading, after avoiding traffic
var _gap := LOOKAHEAD  # room in segments ahead in `target`'s lane, as last looked
var _react := 0.0  # erratic: seconds before it looks at the lanes again
var _blocking := 0.0  # aggressive: seconds spent blocking the car behind...
var _resting := 0.0  # ...and seconds left letting it by afterwards


func _init(seed_value: int = 0, bias: float = 0.0, s: RivalProfile.Style = RivalProfile.Style.CLEAN, mirror_side := 1.0) -> void:
	rng.seed = seed_value
	side = mirror_side
	lane_bias = bias * side
	style = s


## This tick's input for `me`. `racers` is everyone in the race, `me` included.
func drive(me: PlayerCar, track: Track, racers: Array, dt: float) -> DriveInput:
	var inp := DriveInput.new()
	var z := me.position + Cfg.PLAYER_Z
	var edge: float = track.narrowest_ahead(z).lane_offsets()[-1]
	if style == RivalProfile.Style.ERRATIC and rng.randf() < Tuning.v("ai/swerve_rate") * dt:
		lane_bias = rng.randf_range(-SWERVE_BIAS, SWERVE_BIAS) * side
	var want := clampf(racing_line(track, z) + lane_bias, -edge, edge)
	if style == RivalProfile.Style.AGGRESSIVE:
		var chaser := blocking_target(me, track, racers) if _resting <= 0.0 else null
		_resting = maxf(0.0, _resting - dt)
		if chaser == null:
			_blocking = maxf(0.0, _blocking - dt * BLOCK_FORGET)
		else:
			want = clampf(chaser.x, -edge, edge)
			_blocking += dt
			if _blocking >= Tuning.v("ai/block_time"):
				_blocking = 0.0
				_resting = Tuning.v("ai/block_rest")
	want = keep_to_own_side(track, z, want)
	_react -= dt
	if style != RivalProfile.Style.ERRATIC or _react <= 0.0:
		var looking := ERRATIC_LOOKAHEAD if style == RivalProfile.Style.ERRATIC else LOOKAHEAD
		var lane := open_lane(track, z, want, me, racers, looking)
		target = lane["x"]
		_gap = lane["gap"] if lane["gap"] < looking else LOOKAHEAD
		_react = ERRATIC_REACT
	var lane := {"x": target, "gap": _gap}
	var seg := track.find_segment(z + STEER_AHEAD)
	inp.steer = clampf(seg.curve * STEER_CURVE + (target - me.x) * Tuning.v("ai/steer_gain"), -1.0, 1.0)
	inp.throttle = 1.0
	var room: float = lane["gap"] * Cfg.SEGMENT_LENGTH
	if lane["gap"] < LOOKAHEAD and room < me.speed * Tuning.v("ai/lift_time"):
		# Boxed in: ease off rather than run into the back of it
		inp.throttle = 0.0
		inp.brake = 1.0 if room < me.speed * Tuning.v("ai/brake_time") else 0.0
	elif me.speed > corner_speed(me, track, z):
		inp.throttle = 0.0
	elif me.nitro_charges > 0 and me.nitro_time <= 0.0 and me.speed > me.top_speed * Tuning.v("ai/nitro_speed") \
			and lane["gap"] >= LOOKAHEAD and straight_ahead(track, z):
		inp.nitro_pressed = rng.randf() < Tuning.v("ai/nitro_rate") * dt
	return inp


## The nearest faster racer coming up close behind `me`, for an aggressive driver to block.
static func blocking_target(me: PlayerCar, track: Track, racers: Array) -> PlayerCar:
	var best: PlayerCar = null
	var nearest := Tuning.v("ai/block_range")
	for other: PlayerCar in racers:
		if other == me or other.speed <= me.speed:
			continue
		var behind := wrapf(me.position - other.position, -track.length * 0.5, track.length * 0.5)
		if behind > 0.0 and behind < nearest:
			nearest = behind
			best = other
	return best


## The line through the curves ahead: toward the inside of the coming bend, 0 on a straight.
## A right-hand curve (positive) puts it right of center (positive x).
## The fastest `me` can take the sharpest curve just ahead and still hold its line: a curve
## pulls harder the faster the car goes, and full lock only holds so much (less on a wet or
## snowy road, Segment.grip: the bend is taken slower).
static func corner_speed(me: PlayerCar, track: Track, z: float) -> float:
	var here := track.find_segment(z).index
	var sharpest := 0.0
	for k in CORNER_AHEAD:
		var seg := track.segments[(here + k) % track.segments.size()]
		sharpest = maxf(sharpest, absf(seg.curve) / seg.grip)
	if sharpest <= 0.0:
		return INF
	return Cfg.MAX_SPEED * Tuning.v("ai/corner_grip") * me.steer_mult / (sharpest * Tuning.v("driving/centrifugal") * me.pull_mult)


static func racing_line(track: Track, z: float) -> float:
	var here := track.find_segment(z).index
	var n := track.segments.size()
	var sum := 0.0
	for k in range(LINE_FROM, LINE_TO):
		sum += track.segments[(here + k) % n].curve
	return clampf(sum / (LINE_TO - LINE_FROM) * Tuning.v("ai/line_gain"), -Tuning.v("ai/line_max"), Tuning.v("ai/line_max"))


static func straight_ahead(track: Track, z: float) -> bool:
	var here := track.find_segment(z).index
	var n := track.segments.size()
	for k in STRAIGHT_AHEAD:
		if absf(track.segments[(here + k) % n].curve) > STRAIGHT_CURVE:
			return false
	return true


## On an undivided road (RC-11), `want` kept out of the oncoming lanes: no nearer the middle
## than the middle of the nearest lane going its way. open_lane still passes on the other side.
static func keep_to_own_side(track: Track, z: float, want: float) -> float:
	if Traffic.divided(track):
		return want
	var seg := track.narrowest_ahead(z)
	var inner: float = seg.lane_x(Traffic.first_lane(track, seg.lanes)) * track.side()
	return maxf(want * track.side(), inner * track.side()) * track.side()


## `k` segments to an oncoming car as the room before a standing one: what is left when
## `me` (at `speed`) has covered its share of the closing gap, cut by ONCOMING_CAUTION since
## braking won't get out of its way.
static func oncoming_gap(k: int, speed: float, car_speed: float) -> int:
	return floori(k * ONCOMING_CAUTION * maxf(speed, 0.0) / maxf(speed + car_speed, 1.0))


## Where to drive across the road: `want` if it's clear for LOOKAHEAD segments, otherwise the
## lane (nearest `want` first) with the most room before a slower car or a road hazard. The lanes are those of
## the narrowest road just ahead (Track.narrowest_ahead). Returns {"x", "gap"}, gap in
## segments (LOOKAHEAD when clear).
static func open_lane(track: Track, z: float, want: float, me: PlayerCar, racers: Array,
		lookahead: int = LOOKAHEAD) -> Dictionary:
	var lanes: Array = [want]
	var by_distance: Array = Traffic.lanes(track, track.narrowest_ahead(z))
	by_distance.sort_custom(func(a: float, b: float) -> bool: return absf(a - want) < absf(b - want))
	lanes.append_array(by_distance)
	var best := {"x": want, "gap": -1}
	var best_room := -1
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	for x: float in lanes:
		var gap := clear_for(track, z, x, me, racers, lookahead)
		# A road hazard (RC-19) ahead in a lane rules it out like a slower car, but only for
		# choosing: the gap returned (what the driver lifts for) is the traffic's
		var room := mini(gap, RoadHazards.room(track, z, x, half_car, LANE_CLEARANCE, lookahead))
		if room >= lookahead:
			return {"x": x, "gap": gap}
		if room > best_room:
			best_room = room
			best = {"x": x, "gap": gap}
	return best


## Segments ahead of `z` before a car slower than `me` blocks a car at `x`, or LOOKAHEAD.
static func clear_for(track: Track, z: float, x: float, me: PlayerCar, racers: Array,
		lookahead: int = LOOKAHEAD) -> int:
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var here := track.find_segment(z).index
	var n := track.segments.size()
	var first := lookahead
	for other: PlayerCar in racers:
		if other == me or other.speed >= me.speed:
			continue
		var ahead := wrapf(other.position - me.position, -track.length * 0.5, track.length * 0.5)
		if ahead > 0.0 and absf(other.x - x) < half_car * 2.0 + LANE_CLEARANCE:
			first = mini(first, int(ahead / Cfg.SEGMENT_LENGTH))
	# Close ahead, a car between here and `x` blocks the way across too, not just `x` itself
	var near := ceili(me.speed * CROSS_TIME / Cfg.SEGMENT_LENGTH)
	# Oncoming traffic (RC-11) closes at both speeds: it is looked for further out, and its
	# gap counted as the room before a standing car (oncoming_gap)
	var best := first
	for k in first * ONCOMING_SCAN:
		if k >= best and oncoming_gap(k, me.speed, Cfg.MAX_SPEED) >= best:
			break
		for car: Traffic.TrafficCar in track.segments[(here + k) % n].cars:
			# Slower than it could go is in the way, even at its speed: stuck on the tail of a
			# car (bumped down to its speed) it would otherwise see a clear road and never pull out
			if not car.solid() or (not car.oncoming and (k >= best or car.speed >= maxf(me.speed, me.top_speed))):
				continue
			var room := half_car * (1.0 + car.width_mult) + LANE_CLEARANCE
			var gap := oncoming_gap(k, me.speed, car.speed) if car.oncoming else k
			if absf(car.offset - x) < room:
				best = mini(best, gap)
				continue
			var on_the_way := (car.offset - me.x) * (x - me.x) > 0.0 \
				and absf(car.offset - me.x) < absf(x - me.x) + room
			# An oncoming car in the way across is crossed only well before it arrives
			var soon := k * Cfg.SEGMENT_LENGTH < (me.speed + car.speed) * ONCOMING_CROSS_TIME if car.oncoming \
				else k < near
			if soon and on_the_way:
				best = mini(best, gap)
	return best
