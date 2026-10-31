class_name Ghost
extends RefCounted
## A Time Attack run, tick by tick: the player's distance, offset across the road and
## steering, recorded from GO to the line. The best run per stage and car (the roadmap's
## default) is saved to its own file and replayed as a see-through car.

const VERSION := 1
const MAGIC := "SRGH"
const STRIDE := 3  # floats per tick: distance, x, steer

## Where ghosts are saved. Tests point this at a scratch folder.
static var dir := "user://ghosts"

var stage := 0
var car_id := ""
var time := 0.0  # the run's finish time, seconds
var ticks := PackedFloat32Array()


static func make(stage_index: int, car: String) -> Ghost:
	var g := Ghost.new()
	g.stage = stage_index
	g.car_id = car
	return g


static func path(stage_index: int, car: String) -> String:
	return "%s/%s_%s.ghost" % [dir, Stages.POSTCARDS[stage_index], car]


func count() -> int:
	return ticks.size() / STRIDE


## Adds one racing tick of the player.
func record(p: PlayerCar) -> void:
	ticks.append_array([p.distance, p.x, p.steer])


## Tick `i` (held at the last one after the line) as (distance, x, steer).
func at(i: int) -> Vector3:
	if count() == 0:
		return Vector3.ZERO
	var k := clampi(i, 0, count() - 1) * STRIDE
	return Vector3(ticks[k], ticks[k + 1], ticks[k + 2])


## Seconds from GO until the run passed `distance`, between ticks (tick i ends at (i + 1) x
## `dt`; the run starts from distance 0 at GO); INF if it never did.
func time_at(distance: float, dt: float) -> float:
	var prev := 0.0
	for i in count():
		var d := ticks[i * STRIDE]
		if d >= distance:
			var f := 0.0 if d <= prev else clampf((distance - prev) / (d - prev), 0.0, 1.0)
			return (i + f) * dt
		prev = d
	return INF


func to_bytes() -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_data(MAGIC.to_ascii_buffer())
	buf.put_32(VERSION)
	buf.put_32(stage)
	buf.put_utf8_string(car_id)
	buf.put_double(time)
	buf.put_32(ticks.size())
	buf.put_data(ticks.to_byte_array())
	return buf.data_array


## A ghost from to_bytes, or null for anything else (a newer version, a broken file).
static func from_bytes(bytes: PackedByteArray) -> Ghost:
	if bytes.size() < 8 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return null
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(4)
	if buf.get_32() != VERSION:
		return null
	var g := Ghost.new()
	g.stage = buf.get_32()
	g.car_id = buf.get_utf8_string()
	g.time = buf.get_double()
	var n := buf.get_32()
	if n < 0 or n % STRIDE != 0 or buf.get_available_bytes() < n * 4:
		return null
	g.ticks = (buf.get_data(n * 4)[1] as PackedByteArray).to_float32_array()
	return g


func save() -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(stage, car_id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(to_bytes())
	return true


## The saved best run for a stage and car, or null.
static func load_best(stage_index: int, car: String) -> Ghost:
	var p := path(stage_index, car)
	if not FileAccess.file_exists(p):
		return null
	var g := from_bytes(FileAccess.get_file_as_bytes(p))
	if g == null or g.stage != stage_index or g.car_id != car:
		return null
	return g


## Whether a finish in `seconds` beats `best` (none counts as beaten).
static func beats(seconds: float, best: Ghost) -> bool:
	return best == null or seconds < best.time
