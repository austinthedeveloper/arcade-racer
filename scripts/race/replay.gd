class_name Replay
extends RefCounted
## The instant replay (RC-17): the last seconds before the finish, shown once after the
## finish spectacle from a recorded trace of every car, then the results. Any button skips it.
##
## The trace is the ghost recorder's idea (Ghost) for the whole field: each racing tick, one
## frame of every racer as an online race sends it (CarState: distance, x, steer, speed, air,
## nitro, braking; the player first, then the rivals) and every traffic car's z and offset.
## Only the last SECONDS are kept. `build` cuts the replay out of a trace; `apply` puts a
## frame's cars on the road.

const SECONDS := 6.0
const TICKS_PER_SECOND := 60
## Frames kept: the replay's, and no more.
const KEEP := int(SECONDS * TICKS_PER_SECOND)

## The recorded frames, oldest first: each a PackedFloat32Array of racers x CarState.SIZE,
## then traffic x 2 (z, offset).
var frames: Array[PackedFloat32Array] = []
var racers := 0
var traffic_cars := 0


## Adds one racing tick of the field: `cars` (the player first, then the rivals) and the
## traffic. The oldest frame goes once there are more than KEEP.
func record(cars: Array, traffic: Array) -> void:
	racers = cars.size()
	traffic_cars = traffic.size()
	var f := PackedFloat32Array()
	f.resize(racers * CarState.SIZE + traffic_cars * 2)
	var k := 0
	for car: PlayerCar in cars:
		for v in CarState.of(car):
			f[k] = float(v)
			k += 1
	for t: Traffic.TrafficCar in traffic:
		f[k] = t.z
		f[k + 1] = t.offset
		k += 2
	frames.append(f)
	if frames.size() > KEEP:
		frames.pop_front()


## The replay out of a trace (`frames`, oldest first, ending on the finish frame): the last
## `seconds` of it at `tps` ticks a second, or all of it when shorter. It ends on the finish
## frame.
static func build(trace: Array[PackedFloat32Array], seconds: float = SECONDS, tps: int = TICKS_PER_SECOND) -> Array[PackedFloat32Array]:
	var n := mini(trace.size(), roundi(seconds * tps))
	return trace.slice(trace.size() - n)


## Racer `i` in frame `f` as a CarState array.
static func racer(f: PackedFloat32Array, i: int) -> Array:
	var k := i * CarState.SIZE
	return [f[k], f[k + 1], f[k + 2], f[k + 3], f[k + 4], f[k + 5] > 0.5, f[k + 6] > 0.5]


## Puts frame `f`'s racers on `cars` (as many as both have) and its traffic on `traffic`,
## each car in its segment's list.
static func apply(f: PackedFloat32Array, cars: Array, traffic: Array, track: Track) -> void:
	var base := f.size() - traffic.size() * 2
	if base < 0:
		return
	for i in mini(cars.size(), base / CarState.SIZE):
		var state := racer(f, i)
		CarState.apply(cars[i], state, Vector3(state[CarState.DISTANCE], state[CarState.X], state[CarState.STEER]), track)
	for j in traffic.size():
		var t: Traffic.TrafficCar = traffic[j]
		t.z = f[base + j * 2]
		t.offset = f[base + j * 2 + 1]
		t.percent = fposmod(t.z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
		var seg := track.find_segment(t.z)
		if seg != t.segment:
			t.segment.cars.erase(t)
			seg.cars.append(t)
			t.segment = seg


## Whether this tick's input skips the replay: any button pressed (held pedals and steering
## don't count, so a foot still on the gas from the finish doesn't skip it).
static func skips(inp: DriveInput, m: MenuInput) -> bool:
	return inp.nitro_pressed or inp.pause_pressed or inp.restart_pressed or inp.confirm_pressed \
		or inp.radio_pressed or m.confirm_pressed or m.back_pressed
