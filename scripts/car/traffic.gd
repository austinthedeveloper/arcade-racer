class_name Traffic
extends RefCounted
## Civilian cars cruising in lanes. Each car lives in its segment's `cars` list for rendering
## and collision.

class TrafficCar:
	var z := 0.0
	var offset := 0.0
	var speed := 0.0
	var percent := 0.0
	var style := 0
	var color := Color.WHITE
	var width_mult := 1.0
	var segment: Segment

const LANE_OFFSETS := [-0.75, -0.25, 0.25, 0.75]
const COLORS := ["#f2f2f2", "#9fd8c8", "#e8d8b0", "#5b8fd6", "#8a2a3a", "#f5e663", "#3f4a5a", "#e07a3a"]

var cars: Array[TrafficCar] = []


func spawn(track: Track, count: int, seed_value: int = 7) -> void:
	for seg in track.segments:
		seg.cars.clear()
	cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var car := TrafficCar.new()
		car.z = rng.randf_range(40.0, track.segments.size() - 10.0) * Cfg.SEGMENT_LENGTH
		car.offset = LANE_OFFSETS[rng.randi() % LANE_OFFSETS.size()]
		var roll := rng.randf()
		if roll < 0.15:
			car.style = CarPainter.Style.TRUCK
			car.width_mult = 1.15
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.25, 0.4)
		elif roll < 0.38:
			car.style = CarPainter.Style.VAN
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.3, 0.5)
		elif roll < 0.65:
			car.style = CarPainter.Style.COMPACT
			car.width_mult = 0.9
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.3, 0.55)
		else:
			car.style = CarPainter.Style.SEDAN
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.35, 0.6)
		car.color = Color(COLORS[rng.randi() % COLORS.size()])
		car.segment = track.find_segment(car.z)
		car.segment.cars.append(car)
		cars.append(car)


func update(dt: float, track: Track) -> void:
	for car in cars:
		car.z = fposmod(car.z + car.speed * dt, track.length)
		car.percent = fposmod(car.z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
		var seg := track.find_segment(car.z)
		if seg != car.segment:
			car.segment.cars.erase(car)
			seg.cars.append(car)
			car.segment = seg
