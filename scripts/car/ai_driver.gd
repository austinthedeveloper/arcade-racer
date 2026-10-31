class_name AIDriver
extends RefCounted
## Drives a RivalCar: holds a line through the curves ahead, moves to an open lane round
## slower cars, and uses nitro on straights. Every choice comes from its own seeded RNG, so a
## race plays the same every time.

const LINE_FROM := 5  # segments ahead the racing line starts looking...
const LINE_TO := 30  # ...and stops
const LINE_GAIN := 0.09  # road half-widths toward the inside per unit of average curve
const LINE_MAX := 0.55  # furthest inside the line goes
const STEER_AHEAD := 3000.0  # world units ahead the steering reads the curve (as the autodrive)
const STEER_CURVE := 0.25
const STEER_GAIN := 1.5
const LOOKAHEAD := 50  # segments checked for slower cars in the way
const LANE_CLEARANCE := 0.05  # road half-widths of room kept beside a car when passing
const CROSS_TIME := 0.3  # seconds ahead within which the way across to a new lane must be clear
const LIFT_TIME := 0.5  # seconds: closer than this behind a car with nowhere to go, lift...
const BRAKE_TIME := 0.25  # ...and closer than this, brake
const CORNER_AHEAD := 8  # segments ahead the corner speed reads the sharpest curve
const CORNER_GRIP := 0.85  # share of full lock a bend may take at speed; the rest is for the line
const STRAIGHT_AHEAD := 40  # segments that must be nearly straight for nitro
const STRAIGHT_CURVE := 0.5
const NITRO_SPEED := 0.85  # share of top speed before nitro
const NITRO_RATE := 0.6  # chance per second of firing nitro once everything allows it

var rng := RandomNumberGenerator.new()
var lane_bias := 0.0  # this driver's own spot across the road, added to the racing line
var target := 0.0  # where across the road it is heading, after avoiding traffic


func _init(seed_value: int = 0, bias: float = 0.0) -> void:
	rng.seed = seed_value
	lane_bias = bias


## This tick's input for `me`. `racers` is everyone in the race, `me` included.
func drive(me: PlayerCar, track: Track, racers: Array, dt: float) -> DriveInput:
	var inp := DriveInput.new()
	var z := me.position + Cfg.PLAYER_Z
	var want := clampf(racing_line(track, z) + lane_bias, -Traffic.LANE_OFFSETS[-1], Traffic.LANE_OFFSETS[-1])
	var lane := open_lane(track, z, want, me, racers)
	target = lane["x"]
	var seg := track.find_segment(z + STEER_AHEAD)
	inp.steer = clampf(seg.curve * STEER_CURVE + (target - me.x) * STEER_GAIN, -1.0, 1.0)
	inp.throttle = 1.0
	var room: float = lane["gap"] * Cfg.SEGMENT_LENGTH
	if lane["gap"] < LOOKAHEAD and room < me.speed * LIFT_TIME:
		# Boxed in: ease off rather than run into the back of it
		inp.throttle = 0.0
		inp.brake = 1.0 if room < me.speed * BRAKE_TIME else 0.0
	elif me.speed > corner_speed(me, track, z):
		inp.throttle = 0.0
	elif me.nitro_charges > 0 and me.nitro_time <= 0.0 and me.speed > me.top_speed * NITRO_SPEED \
			and lane["gap"] >= LOOKAHEAD and straight_ahead(track, z):
		inp.nitro_pressed = rng.randf() < NITRO_RATE * dt
	return inp


## The line through the curves ahead: toward the inside of the coming bend, 0 on a straight.
## A right-hand curve (positive) puts it right of center (positive x).
## The fastest `me` can take the sharpest curve just ahead and still hold its line: a curve
## pulls harder the faster the car goes, and full lock only holds so much.
static func corner_speed(me: PlayerCar, track: Track, z: float) -> float:
	var here := track.find_segment(z).index
	var sharpest := 0.0
	for k in CORNER_AHEAD:
		sharpest = maxf(sharpest, absf(track.segments[(here + k) % track.segments.size()].curve))
	if sharpest <= 0.0:
		return INF
	return Cfg.MAX_SPEED * CORNER_GRIP * me.steer_mult / (sharpest * Cfg.CENTRIFUGAL * me.pull_mult)


static func racing_line(track: Track, z: float) -> float:
	var here := track.find_segment(z).index
	var n := track.segments.size()
	var sum := 0.0
	for k in range(LINE_FROM, LINE_TO):
		sum += track.segments[(here + k) % n].curve
	return clampf(sum / (LINE_TO - LINE_FROM) * LINE_GAIN, -LINE_MAX, LINE_MAX)


static func straight_ahead(track: Track, z: float) -> bool:
	var here := track.find_segment(z).index
	var n := track.segments.size()
	for k in STRAIGHT_AHEAD:
		if absf(track.segments[(here + k) % n].curve) > STRAIGHT_CURVE:
			return false
	return true


## Where to drive across the road: `want` if it's clear for LOOKAHEAD segments, otherwise the
## lane (nearest `want` first) with the most room before a slower car. Returns {"x", "gap"},
## gap in segments (LOOKAHEAD when clear).
static func open_lane(track: Track, z: float, want: float, me: PlayerCar, racers: Array) -> Dictionary:
	var lanes: Array = [want]
	var by_distance: Array = Traffic.LANE_OFFSETS.duplicate()
	by_distance.sort_custom(func(a: float, b: float) -> bool: return absf(a - want) < absf(b - want))
	lanes.append_array(by_distance)
	var best := {"x": want, "gap": -1}
	for x: float in lanes:
		var gap := clear_for(track, z, x, me, racers)
		if gap >= LOOKAHEAD:
			return {"x": x, "gap": gap}
		if gap > best["gap"]:
			best = {"x": x, "gap": gap}
	return best


## Segments ahead of `z` before a car slower than `me` blocks a car at `x`, or LOOKAHEAD.
static func clear_for(track: Track, z: float, x: float, me: PlayerCar, racers: Array) -> int:
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var here := track.find_segment(z).index
	var n := track.segments.size()
	var first := LOOKAHEAD
	for other: PlayerCar in racers:
		if other == me or other.speed >= me.speed:
			continue
		var ahead := wrapf(other.position - me.position, -track.length * 0.5, track.length * 0.5)
		if ahead > 0.0 and absf(other.x - x) < half_car * 2.0 + LANE_CLEARANCE:
			first = mini(first, int(ahead / Cfg.SEGMENT_LENGTH))
	# Close ahead, a car between here and `x` blocks the way across too, not just `x` itself
	var near := ceili(me.speed * CROSS_TIME / Cfg.SEGMENT_LENGTH)
	for k in first:
		for car: Traffic.TrafficCar in track.segments[(here + k) % n].cars:
			if not car.solid() or car.speed >= me.speed:
				continue
			var room := half_car * (1.0 + car.width_mult) + LANE_CLEARANCE
			if absf(car.offset - x) < room:
				return k
			var on_the_way := (car.offset - me.x) * (x - me.x) > 0.0 \
				and absf(car.offset - me.x) < absf(x - me.x) + room
			if k < near and on_the_way:
				return k
	return first
