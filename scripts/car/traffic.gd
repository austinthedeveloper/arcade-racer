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
	var flung := 0.0  # seconds left in the air after a ram plate hit
	var fling_dir := 0.0

const LANE_OFFSETS := [-0.75, -0.25, 0.25, 0.75]
const FLING_TIME := 0.8  # how long a rammed car flies
const FLING_SPEED := 4.0  # road half-widths per second sideways
const CARS := ["compact_teal", "sedan_beige", "wagon_blue", "van_red", "mini_white", "roadster_yellow",
	"pickup_red", "suv_green", "muscle_white", "van_navy", "hatch_purple"]
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
		if roll < BIG_SHARE:
			car.sprite = BIG[rng.randi() % BIG.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(BIG_SPEED[0], BIG_SPEED[1])
		elif roll < BIG_SHARE + SPECIAL_SHARE:
			car.sprite = specials[rng.randi() % specials.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(SPECIAL_SPEED[0], SPECIAL_SPEED[1])
		else:
			car.sprite = CARS[rng.randi() % CARS.size()]
			car.speed = Cfg.MAX_SPEED * rng.randf_range(CAR_SPEED[0], CAR_SPEED[1])
		car.width_mult = CarSprites.traffic[car.sprite]["world_w"] / Cfg.CAR_WIDTH
		car.segment = track.find_segment(car.z)
		car.segment.cars.append(car)
		cars.append(car)


func update(dt: float, track: Track) -> void:
	for car in cars:
		if car.flung > 0.0:
			car.flung = maxf(0.0, car.flung - dt)
			car.offset = clampf(car.offset + car.fling_dir * FLING_SPEED * dt, -4.0, 4.0)
		car.z = fposmod(car.z + car.speed * dt, track.length)
		car.percent = fposmod(car.z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
		var seg := track.find_segment(car.z)
		if seg != car.segment:
			car.segment.cars.erase(car)
			seg.cars.append(car)
			car.segment = seg


## Knocks a car flying off the road, away from `from_x`.
static func fling(car: TrafficCar, from_x: float) -> void:
	car.flung = FLING_TIME
	car.fling_dir = 1.0 if car.offset >= from_x else -1.0
