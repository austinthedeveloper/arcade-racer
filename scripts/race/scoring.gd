class_name Scoring
extends RefCounted
## Points for a stage: a table by place, plus bonuses for near misses, air time, clean
## sections between checkpoints, a race without a crash, and drafting. Each rule is a plain
## function; the race calls `watch` every tick and `finish` at the line.

const PLACE_POINTS := [20, 15, 12, 10, 8, 6, 4, 2]
const NEAR_MISS := 1
const NEAR_MISS_ROOM := 0.15  # road half-widths between the two cars' sides, at most
const NEAR_MISS_SPEED := 0.6  # share of Cfg.MAX_SPEED, at least
const AIR := 1
const BIG_AIR := 2
const AIR_TIME := 0.5  # seconds off the ground for AIR...
const BIG_AIR_TIME := 1.0  # ...and for BIG AIR
const CLEAN_SECTION := 3
const NO_CRASH := 5
const DRAFT := 1
const FEED_TIME := 1.6  # seconds a bonus stays up on the HUD

var bonuses: Array[Dictionary] = []  # {"name", "points"} in the order they were earned
var feed: Array[Dictionary] = []  # the latest few for the HUD: {"name", "points", "age"}
var contacts := 0  # bumps and crashes since the last checkpoint
var crashes := 0
var air := 0.0  # seconds in the current jump
var _was_drafting := false


static func place_points(place: int) -> int:
	return PLACE_POINTS[place - 1] if place >= 1 and place <= PLACE_POINTS.size() else 0


## Passing a car with no more than NEAR_MISS_ROOM between your sides, at speed.
static func near_miss(x: float, speed: float, car_offset: float, car_width_mult: float) -> bool:
	if speed < Cfg.MAX_SPEED * NEAR_MISS_SPEED:
		return false
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var both := half_car * (1.0 + car_width_mult)
	var between := absf(x - car_offset) - both
	return between >= -both * (1.0 - Cfg.HIT_OVERLAP) and between <= NEAR_MISS_ROOM


## Points for a jump `seconds` long.
static func air_points(seconds: float) -> int:
	if seconds >= BIG_AIR_TIME:
		return BIG_AIR
	return AIR if seconds >= AIR_TIME else 0


static func clean_section_points(contacts_in_section: int) -> int:
	return CLEAN_SECTION if contacts_in_section == 0 else 0


static func no_crash_points(crash_count: int) -> int:
	return NO_CRASH if crash_count == 0 else 0


func total() -> int:
	var n := 0
	for b in bonuses:
		n += int(b["points"])
	return n


## Each bonus kind once, with how many times and the points: for the finish.
func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := {}
	for b in bonuses:
		if not at.has(b["name"]):
			at[b["name"]] = out.size()
			out.append({"name": b["name"], "count": 0, "points": 0})
		var row: Dictionary = out[at[b["name"]]]
		row["count"] += 1
		row["points"] += b["points"]
	return out


func add(bonus_name: String, points: int) -> void:
	if points <= 0:
		return
	bonuses.append({"name": bonus_name, "points": points})
	feed.append({"name": bonus_name, "points": points, "age": 0.0})
	if feed.size() > 3:
		feed.pop_front()


## One racing tick for the player, after it moved and collided.
func watch(dt: float, p: PlayerCar, track: Track) -> void:
	for f in feed:
		f["age"] += dt
	feed = feed.filter(func(f: Dictionary) -> bool: return f["age"] < FEED_TIME)
	if p.crashed:
		crashes += 1
	if p.crashed or p.bumped:
		contacts += 1
	if p.airborne:
		air += dt
	elif p.landed or air > 0.0:
		var pts := air_points(air)
		add("BIG AIR" if pts == BIG_AIR else "AIR", pts)
		air = 0.0
	var drafting := p.draft_time > 0.0
	if drafting and not _was_drafting:
		add("SLIPSTREAM", DRAFT)
	_was_drafting = drafting
	if p.crash_time > 0.0:
		return
	var nose := p.position + Cfg.PLAYER_Z
	for seg in p.passed_segments(track):
		for car: Traffic.TrafficCar in seg.cars:
			if not car.solid():
				continue
			var now := wrapf(car.z - nose, -track.length * 0.5, track.length * 0.5)
			if now <= 0.0 and p.gap_when_tick_began(car, track) > 0.0 \
					and near_miss(p.x, p.speed, car.offset, car.width_mult):
				add("NEAR MISS", NEAR_MISS)


## Passing a checkpoint: a clean section if nothing was touched since the last one.
func checkpoint() -> void:
	add("CLEAN SECTION", clean_section_points(contacts))
	contacts = 0


## At the line: the last section, the no-crash bonus and the place.
func finish(place: int, with_rivals: bool) -> void:
	checkpoint()
	add("NO CRASHES", no_crash_points(crashes))
	if with_rivals:
		add(Rivals.ordinal(place) + " PLACE", place_points(place))
