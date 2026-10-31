class_name Traffic
extends RefCounted
## Civilian cars cruising in lanes. Each car lives in its segment's `cars` list for rendering
## and collision.

class TrafficCar:
	var z := 0.0
	var offset := 0.0
	var speed := 0.0
	var percent := 0.0
	var sprite := ""
	var width_mult := 1.0
	var segment: Segment

const LANE_OFFSETS := [-0.75, -0.25, 0.25, 0.75]
const CARS := ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow",
	"pickup_red", "suv_green", "muscle_white", "van_navy", "hatch_purple"]
const BIG := ["semi", "bus", "box_truck", "rv", "carrier", "garbage_truck"]
## Locals: a stage's theme lists its own under "specials"; these are for a stage without.
const SPECIALS := ["surf_van", "taxi"]

var cars: Array[TrafficCar] = []


func spawn(track: Track, count: int, seed_value: int = 7) -> void:
	for seg in track.segments:
		seg.cars.clear()
	cars.clear()
	CarSprites.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var specials: Array = track.theme.get("specials", SPECIALS)
	for i in count:
		var car := TrafficCar.new()
		car.z = rng.randf_range(40.0, track.segments.size() - 10.0) * Cfg.SEGMENT_LENGTH
		car.offset = LANE_OFFSETS[rng.randi() % LANE_OFFSETS.size()]
		var roll := rng.randf()
		if roll < 0.15:
			car.sprite = BIG[rng.randi() % BIG.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.25, 0.4)
		elif roll < 0.25:
			car.sprite = specials[rng.randi() % specials.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.3, 0.5)
		else:
			car.sprite = CARS[rng.randi() % CARS.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(0.3, 0.6)
		car.width_mult = CarSprites.traffic[car.sprite]["world_w"] / Cfg.CAR_WIDTH
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
