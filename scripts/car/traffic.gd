class_name Traffic
extends RefCounted
## Civilian cars cruising in lanes. Each car lives in its segment's `cars` list for rendering
## and collision. On an undivided road (a stage theme without "divided") the lanes left of the
## middle carry oncoming traffic, drawn from the front (RC-11). Some everyday cars change lanes
## now and then, after signalling for SIGNAL_TIME.

class TrafficCar:
	var z := 0.0
	var offset := 0.0
	var speed := 0.0
	var percent := 0.0
	var sprite := ""
	var width_mult := 1.0
	var segment: Segment
	var flung := 0.0  # seconds left in the air after a ram plate hit
	var fling_dir := 0.0
	var lane := 0.0  # the middle of its lane here: where it drives, and a rammed car drives back to
	## Its lane as a share of the way across the road (0 left edge, 1 right edge), kept through
	## a narrowing or widening (Segment.lane_at); NAN for a car that keeps to `lane` as it is.
	var lane_frac := NAN
	var returning := false  # rammed and landed, drifting back to its lane; not solid yet
	var last_z := NAN  # z before this tick's move (NAN until it has moved)
	var oncoming := false  # drives toward the player (z falls); `speed` is still positive
	var change_in := INF  # seconds to its next lane change; INF for a car that never changes
	## Signalling: -1 left, 1 right on screen, 0 not. It moves over once it has signalled for
	## SIGNAL_TIME, and the signal goes off when it is in its new lane.
	var signal_dir := 0
	var signal_age := 0.0


	## Whether the player can hit it: not while flying off or drifting back after a ram.
	func solid() -> bool:
		return flung <= 0.0 and not returning

const SIGNAL_TIME := 1.0  # seconds a car signals before it moves over
const SIGNAL_GIVE_UP := 4.0  # seconds: the signal goes off even if the car never got there (held at a narrowing edge)
const BLINK := 0.5  # seconds per flash of a signal, on for BLINK_ON of it
const BLINK_ON := 0.3
const CHANGER_SHARE := 0.5  # of the cars that have signal frames (CarSprites), the share that change lanes
const CHANGE_EVERY := [5.0, 16.0]  # seconds between one car's lane changes
const CHANGE_RETRY := 1.5  # seconds before trying again when the next lane is taken
const CHANGE_ROOM := 3  # segments ahead and behind that must be clear in the new lane

## The usual four-lane road's lanes (Segment.lane_offsets for a road of any width, WS-7).
const LANE_OFFSETS := [-0.75, -0.25, 0.25, 0.75]
const MERGE_SPEED := 0.8  # road half-widths per second, moving over where lanes merge or split
const FLING_TIME := 0.8  # how long a rammed car flies
const FLING_SPEED := 4.0  # road half-widths per second sideways
const RETURN_SPEED := 1.2  # road half-widths per second, drifting back to its lane after landing
const CARS := ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow",
	"pickup_red", "suv_green", "muscle_white", "van_navy", "hatch_purple", "sedan_tan"]
const BIG := ["semi", "bus", "box_truck", "rv", "carrier", "garbage_truck"]
## Locals: a stage's theme lists its own under "specials"; these are for a stage without.
const SPECIALS := ["surf_van", "taxi"]
## The mix: this share of the cars are big vehicles, this share locals, the rest cars; each
## kind's speed range as fractions of Cfg.MAX_SPEED.
const BIG_SHARE := 0.15
const SPECIAL_SHARE := 0.1
const BIG_SPEED := [0.25, 0.4]
const SPECIAL_SPEED := [0.3, 0.5]
const CAR_SPEED := [0.3, 0.6]

var cars: Array[TrafficCar] = []
var _rng := RandomNumberGenerator.new()  # spawn's, carried on into lane changes


## The middle of every lane on `seg` (the usual four when none), left to right as built: on a
## mirrored stage (Track.side) each is on the other side, so whatever picks a lane by its place
## in the list picks the mirror of the lane it would pick on the stage as built.
static func lanes(track: Track, seg: Segment = null) -> Array:
	var side := track.side()
	var offsets: Array = LANE_OFFSETS if seg == null else seg.lane_offsets()
	return offsets.map(func(l: float) -> float: return l * side)


## Whether `track`'s road is divided: no oncoming traffic (a stage theme's "divided").
static func divided(track: Track) -> bool:
	return track.theme.get("divided", false)


## The first lane (from the left, as built) that carries traffic the player's way on a road of
## `lane_count` lanes: past the middle on an undivided road.
static func first_lane(track: Track, lane_count: int) -> int:
	return 0 if divided(track) else lane_count / 2


## The vehicles of `kinds` that can be drawn coming the other way, or the everyday cars that
## can if none of them can (Palm Coast's locals have no front views).
static func with_fronts(kinds: Array) -> Array:
	var out := kinds.filter(func(id: String) -> bool: return CarSprites.has_front(id))
	return out if not out.is_empty() else with_fronts(CARS)


func spawn(track: Track, count: int, seed_value: int = 7) -> void:
	for seg in track.segments:
		seg.cars.clear()
	cars.clear()
	CarSprites.load_all()
	var rng := _rng
	rng.seed = seed_value
	var specials: Array = track.theme.get("specials", SPECIALS)
	var big := BIG
	var everyday := CARS
	for i in count:
		var car := TrafficCar.new()
		car.z = rng.randf_range(40.0, track.segments.size() - 10.0) * Cfg.SEGMENT_LENGTH
		car.last_z = car.z
		var at := track.find_segment(car.z)
		var k := rng.randi() % at.lanes
		car.lane_frac = (k + 0.5) / at.lanes
		car.offset = at.lane_x(k) * track.side()
		car.lane = car.offset
		car.oncoming = k < first_lane(track, at.lanes)
		var roll := rng.randf()
		if roll < BIG_SHARE:
			var pool: Array = with_fronts(big) if car.oncoming else big
			car.sprite = pool[rng.randi() % pool.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(BIG_SPEED[0], BIG_SPEED[1])
		elif roll < BIG_SHARE + SPECIAL_SHARE:
			var pool: Array = with_fronts(specials) if car.oncoming else specials
			car.sprite = pool[rng.randi() % pool.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(SPECIAL_SPEED[0], SPECIAL_SPEED[1])
		else:
			var pool: Array = with_fronts(everyday) if car.oncoming else everyday
			car.sprite = pool[rng.randi() % pool.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(CAR_SPEED[0], CAR_SPEED[1])
		var changes := rng.randf() < CHANGER_SHARE
		var first_change := rng.randf_range(CHANGE_EVERY[0], CHANGE_EVERY[1])
		if changes and not car.oncoming and CarSprites.signals(car.sprite):
			car.change_in = first_change
		car.width_mult = CarSprites.traffic[car.sprite]["world_w"] / Cfg.CAR_WIDTH
		car.segment = track.find_segment(car.z)
		car.segment.cars.append(car)
		cars.append(car)


func update(dt: float, track: Track) -> void:
	for car in cars:
		car.last_z = car.z
		car.z = fposmod(car.z + (-car.speed if car.oncoming else car.speed) * dt, track.length)
		car.percent = fposmod(car.z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
		var seg := track.find_segment(car.z)
		if seg != car.segment:
			car.segment.cars.erase(car)
			seg.cars.append(car)
			car.segment = seg
		var follows := not is_nan(car.lane_frac)
		if follows and car.solid():
			_change_lanes(car, dt, track, seg)
		if follows:
			car.lane = seg.lane_at(car.lane_frac) * track.side()
		if car.flung > 0.0:
			car.flung = maxf(0.0, car.flung - dt)
			car.offset = clampf(car.offset + car.fling_dir * FLING_SPEED * dt, -4.0, 4.0)
			car.returning = car.flung <= 0.0
		elif car.returning:
			car.offset = move_toward(car.offset, car.lane, RETURN_SPEED * dt)
			car.returning = car.offset != car.lane
		elif follows:
			# Lanes merge or split here: it moves over, and never runs off a narrowing road
			car.offset = keep_on_road(move_toward(car.offset, car.lane, MERGE_SPEED * dt), track.width_at(car.z))


## A lane-changing car's tick: counting down to its next change, signalling, then moving
## over (into the next lane its way, as built, so a mirrored stage mirrors it).
func _change_lanes(car: TrafficCar, dt: float, track: Track, seg: Segment) -> void:
	if car.signal_dir != 0:
		var was := car.signal_age
		car.signal_age += dt
		if was < SIGNAL_TIME and car.signal_age >= SIGNAL_TIME:
			# The road may have narrowed while it signalled
			var k := clampi(lane_index(car.lane_frac, seg.lanes) + car.signal_dir * track.side(),
				first_lane(track, seg.lanes), seg.lanes - 1)
			car.lane_frac = (k + 0.5) / seg.lanes
		elif car.signal_age >= SIGNAL_TIME and (absf(car.offset - seg.lane_at(car.lane_frac) * track.side()) < 0.001
				or car.signal_age >= SIGNAL_GIVE_UP):
			car.signal_dir = 0
			car.change_in = _rng.randf_range(CHANGE_EVERY[0], CHANGE_EVERY[1])
		return
	car.change_in -= dt
	if car.change_in > 0.0:
		return
	var k := lane_index(car.lane_frac, seg.lanes)
	var d := 1 if _rng.randf() < 0.5 else -1
	var lo := first_lane(track, seg.lanes)
	if k + d < lo or k + d >= seg.lanes:
		d = -d
	if k + d < lo or k + d >= seg.lanes or not lane_clear(track, seg, k + d, car):
		car.change_in = CHANGE_RETRY
		return
	car.signal_dir = d * track.side()
	car.signal_age = 0.0


## The lane (from the left, as built) `frac` of the way across a road of `lane_count` lanes.
static func lane_index(frac: float, lane_count: int) -> int:
	return clampi(floori(frac * lane_count), 0, lane_count - 1)


## Whether lane `k` (as built) of `seg` is free of traffic other than `me` for CHANGE_ROOM
## segments either way.
static func lane_clear(track: Track, seg: Segment, k: int, me: TrafficCar) -> bool:
	var n := track.segments.size()
	for i in range(-CHANGE_ROOM, CHANGE_ROOM + 1):
		var s: Segment = track.segments[(seg.index + i + n) % n]
		for other: TrafficCar in s.cars:
			if other != me and not is_nan(other.lane_frac) and lane_index(other.lane_frac, s.lanes) == k:
				return false
	return true


## Which light frame a car shows now (CarSprites.traffic_texture): "left" or "right" while its
## signal is lit, else "".
static func light_state(car: TrafficCar) -> String:
	if car.signal_dir == 0 or fmod(car.signal_age, BLINK) >= BLINK_ON:
		return ""
	return "left" if car.signal_dir < 0 else "right"


## Traffic in the segments within `reach` of track position `z`.
static func around(track: Track, z: float, reach: int) -> Array:
	var out := []
	var n := track.segments.size()
	var here := track.find_segment(z).index
	for i in range(-reach, reach + 1):
		out.append_array(track.segments[(here + i + n) % n].cars)
	return out


## A traffic car's `offset` held on a road `width` half-widths wide: its middle no nearer the
## edge than a car's half-width, so it stays on the road through a narrowing.
static func keep_on_road(offset: float, width: float) -> float:
	var edge := maxf(0.0, width - Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH)
	return clampf(offset, -edge, edge)


## Knocks a car flying off the road, away from `from_x`. It lands, then drives back to its lane.
static func fling(car: TrafficCar, from_x: float) -> void:
	if car.flung <= 0.0 and not car.returning:
		car.lane = car.offset
	car.flung = FLING_TIME
	car.fling_dir = 1.0 if car.offset >= from_x else -1.0
