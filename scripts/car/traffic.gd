class_name Traffic
extends RefCounted
## Civilian cars cruising in lanes. Each car lives in its segment's `cars` list for rendering
## and collision. On an undivided road (a stage theme without "divided") the lanes left of the
## middle carry oncoming traffic, drawn from the front (RC-11). Some everyday cars change lanes
## now and then, after signalling for traffic/signal_time (Tuning).

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
	## traffic/signal_time, and the signal goes off when it is in its new lane.
	var signal_dir := 0
	var signal_age := 0.0


	## Whether the player can hit it: not while flying off or drifting back after a ram.
	func solid() -> bool:
		return flung <= 0.0 and not returning

const SIGNAL_GIVE_UP := 4.0  # seconds: the signal goes off even if the car never got there (held at a narrowing edge)
const BLINK := 0.5  # seconds per flash of a signal, on for BLINK_ON of it
const BLINK_ON := 0.3
const CHANGE_EVERY := [5.0, 16.0]  # seconds between one car's lane changes
const CHANGE_ROOM := 3  # segments ahead and behind that must be clear in the new lane
const SPAWN_FROM := 40  # segments past the start line before traffic spawns
const SPAWN_TO_END := 10  # and none in the last of the loop

## The usual four-lane road's lanes (Segment.lane_offsets for a road of any width, WS-7).
const LANE_OFFSETS := [-0.75, -0.25, 0.25, 0.75]
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


## `count` cars spread over the road, none where keep_clear says not (RC-14); `start_z` is
## where the player starts (or starts again).
func spawn(track: Track, count: int, seed_value: int = 7, start_z := 0.0) -> void:
	for seg in track.segments:
		seg.cars.clear()
	cars.clear()
	CarSprites.load_all()
	var rng := _rng
	rng.seed = seed_value
	var specials: Array = track.theme.get("specials", SPECIALS)
	var start := track.find_segment(start_z).index
	var clear := keep_clear(track, start)
	var totals := spawn_totals(track, clear)
	for i in count:
		_add_car(track, _spawn_z(totals), specials, start, clear)


## Fair traffic (RC-14): the segments no car spawns in, by index. The stretch just past a blind
## crest (Track.blind_crests), through a tunnel mouth (Track.tunnel_mouths) and ahead of
## `start_index`, where the player starts: traffic/spawn_clear segments each (Tuning), the whole
## road across, so a mirrored stage clears the same.
static func keep_clear(track: Track, start_index: int) -> Array[bool]:
	var n := track.segments.size()
	var out: Array[bool] = []
	out.resize(n)
	out.fill(false)
	var reach := Tuning.i("traffic/spawn_clear")
	var froms: Array[int] = [start_index]
	froms.append_array(track.blind_crests())
	froms.append_array(track.tunnel_mouths())
	for from in froms:
		for k in reach:
			out[(from + k) % n] = true
	return out


## The running total of every segment's share of the spawned traffic, from the first: none
## near the start line (before SPAWN_FROM) or the loop's end (the last SPAWN_TO_END) or where
## `clear` says so, the same everywhere else.
static func spawn_totals(track: Track, clear: Array[bool]) -> PackedFloat64Array:
	var n := track.segments.size()
	var out := PackedFloat64Array()
	out.resize(n)
	var sum := 0.0
	for i in n:
		if i >= SPAWN_FROM and i < n - SPAWN_TO_END and not clear[i]:
			sum += 1.0
		out[i] = sum
	return out


## Where the next spawned car goes: one roll of the dice into `totals` (spawn_totals), so a
## segment gets cars in proportion to its share and a kept-clear one gets none.
func _spawn_z(totals: PackedFloat64Array) -> float:
	var roll := _rng.randf() * totals[totals.size() - 1]
	var k := mini(totals.bsearch(roll, false), totals.size() - 1)
	var below := totals[k - 1] if k > 0 else 0.0
	var share := totals[k] - below
	return (k + clampf((roll - below) / share, 0.0, 0.999)) * Cfg.SEGMENT_LENGTH


## The debug panel's traffic burst (EQ-16): `count` more cars spread over the road from
## `from_z` to `span` world units on, wherever the player is.
func burst(track: Track, from_z: float, count: int, span := 20000.0) -> void:
	var specials: Array = track.theme.get("specials", SPECIALS)
	for i in count:
		_add_car(track, fposmod(from_z + _rng.randf_range(0.0, span), track.length), specials)


## Where an oncoming car spawned at `z` goes instead if it would meet the grid at `start`
## (RC-14): as far again on, past any stretch `clear` keeps clear. `z` itself if it wouldn't.
static func past_the_grid(track: Track, z: float, start: int, clear: Array[bool]) -> float:
	var n := track.segments.size()
	var reach := Tuning.i("traffic/oncoming_clear")
	var k := floori(z / Cfg.SEGMENT_LENGTH)
	if posmod(k - start, n) >= reach:
		return z
	var moved := reach
	while clear[(k + moved) % n] and moved < n:
		moved += 1
	return fposmod(z + moved * Cfg.SEGMENT_LENGTH, track.length)


## A car at `z` in a lane picked by the dice, of a kind and speed picked by them too. With a
## `start` (spawn), an oncoming car that would meet the grid there goes on past it.
func _add_car(track: Track, z: float, specials: Array, start := -1, clear: Array[bool] = []) -> void:
	var rng := _rng
	var car := TrafficCar.new()
	var lane_roll := rng.randi()
	var at := track.find_segment(z)
	if start >= 0 and lane_roll % at.lanes < first_lane(track, at.lanes):
		z = past_the_grid(track, z, start, clear)
		at = track.find_segment(z)
	car.z = z
	car.last_z = car.z
	var k := lane_roll % at.lanes
	var first := first_lane(track, at.lanes)
	car.lane_frac = (k + 0.5) / at.lanes
	car.offset = at.lane_x(k) * track.side()
	car.lane = car.offset
	car.oncoming = k < first
	var roll := rng.randf()
	if roll < BIG_SHARE:
		var pool: Array = with_fronts(BIG) if car.oncoming else BIG
		car.sprite = pool[rng.randi() % pool.size()]
		car.speed = Cfg.MAX_SPEED * rng.randf_range(BIG_SPEED[0], BIG_SPEED[1])
	elif roll < BIG_SHARE + SPECIAL_SHARE:
		var pool: Array = with_fronts(specials) if car.oncoming else specials
		car.sprite = pool[rng.randi() % pool.size()]
		car.speed = Cfg.MAX_SPEED * rng.randf_range(SPECIAL_SPEED[0], SPECIAL_SPEED[1])
	else:
		var pool: Array = with_fronts(CARS) if car.oncoming else CARS
		car.sprite = pool[rng.randi() % pool.size()]
		car.speed = Cfg.MAX_SPEED * rng.randf_range(CAR_SPEED[0], CAR_SPEED[1])
	var changes := rng.randf() < Tuning.v("traffic/changer_share")
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
			car.offset = clampf(car.offset + car.fling_dir * Tuning.v("traffic/fling_speed") * dt, -4.0, 4.0)
			car.returning = car.flung <= 0.0
			if car.returning and follows:
				# Landed: back into a lane with room (RC-14), its signal forgotten
				car.lane_frac = landing_lane(track, seg, car)
				car.lane = seg.lane_at(car.lane_frac) * track.side()
				car.signal_dir = 0
		elif car.returning:
			car.offset = move_toward(car.offset, car.lane, Tuning.v("traffic/return_speed") * dt)
			car.returning = car.offset != car.lane
		elif follows:
			# Lanes merge or split here: it moves over, and never runs off a narrowing road
			car.offset = keep_on_road(move_toward(car.offset, car.lane, Tuning.v("traffic/merge_speed") * dt), track.width_at(car.z))


## A lane-changing car's tick: counting down to its next change, signalling, then moving
## over (into the next lane its way, as built, so a mirrored stage mirrors it).
func _change_lanes(car: TrafficCar, dt: float, track: Track, seg: Segment) -> void:
	if car.signal_dir != 0:
		var was := car.signal_age
		car.signal_age += dt
		if was < Tuning.v("traffic/signal_time") and car.signal_age >= Tuning.v("traffic/signal_time"):
			# The road may have narrowed while it signalled
			var k := clampi(lane_index(car.lane_frac, seg.lanes) + car.signal_dir * track.side(),
				first_lane(track, seg.lanes), seg.lanes - 1)
			car.lane_frac = (k + 0.5) / seg.lanes
		elif car.signal_age >= Tuning.v("traffic/signal_time") and (absf(car.offset - seg.lane_at(car.lane_frac) * track.side()) < 0.001
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
		car.change_in = Tuning.v("traffic/change_retry")
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


## The lane a rammed car drives back to once it lands (RC-14), as a share of the way across
## `seg`: its own lane if lane_clear, else the nearest clear one of the lanes running its way
## (nearer the side it was knocked to first on a tie); its own if none is clear.
static func landing_lane(track: Track, seg: Segment, car: TrafficCar) -> float:
	var own := lane_index(car.lane_frac, seg.lanes)
	var first := first_lane(track, seg.lanes)
	var lo := 0 if car.oncoming else first
	var hi := first if car.oncoming else seg.lanes
	var toward := 1 if car.fling_dir * track.side() > 0.0 else -1  # as built
	for d in seg.lanes:
		for k: int in [own + d * toward, own - d * toward]:
			if k >= lo and k < hi and lane_clear(track, seg, k, car):
				return (k + 0.5) / seg.lanes
	return (own + 0.5) / seg.lanes


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
	car.flung = Tuning.v("traffic/fling_time")
	car.fling_dir = 1.0 if car.offset >= from_x else -1.0
