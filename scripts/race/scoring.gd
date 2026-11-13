class_name Scoring
extends RefCounted
## Points for a stage: a table by place, plus bonuses for near misses (chained, RC-15), air time, clean
## sections between checkpoints, a race without a crash, and drafting. Each rule is a plain
## function; the race calls `watch` every tick and `finish` at the line.

const PLACE_POINTS := [20, 15, 12, 10, 8, 6, 4, 2]
const FEED_TIME := 1.6  # seconds a bonus stays up on the HUD

var bonuses: Array[Dictionary] = []  # {"name", "points"} in the order they were earned
var feed: Array[Dictionary] = []  # the latest few for the HUD: {"name", "points", "age"}
var contacts := 0  # bumps and crashes since the last checkpoint
var crashes := 0
var air := 0.0  # seconds in the current jump
var chain := 0  # near misses in the running chain (RC-15): 0 when there's none
var since_near_miss := INF  # seconds since the last near miss
var _was_drafting := false


static func place_points(place: int) -> int:
	return PLACE_POINTS[place - 1] if place >= 1 and place <= PLACE_POINTS.size() else 0


## Passing a car with less than scoring/near_miss_room (Tuning) between your sides (overlapping a little,
## short of a hit), at speed.
static func near_miss(x: float, speed: float, car_offset: float, car_width_mult: float) -> bool:
	if speed < Cfg.MAX_SPEED * Tuning.v("scoring/near_miss_speed"):
		return false
	var half_car := Cfg.HALF_CAR
	var both := half_car * (1.0 + car_width_mult)
	var between := absf(x - car_offset) - both
	return between >= -both * (1.0 - Tuning.v("crashes/hit_overlap")) and between < Tuning.v("scoring/near_miss_room")


## The chain a near miss makes, `since` seconds after the last one, which made `chain`:
## within scoring/chain_window it carries on (x2, x3...), otherwise it starts over at 1.
static func chain_after(chain_before: int, since: float) -> int:
	return chain_before + 1 if chain_before > 0 and since <= Tuning.v("scoring/chain_window") else 1


## Points for a near miss `chain` long: the near miss's points times the chain, up to
## scoring/chain_max times.
static func chain_points(chain_length: int) -> int:
	return Tuning.i("scoring/near_miss") * clampi(chain_length, 1, Tuning.i("scoring/chain_max"))


## What the bonus feed and the tally call a near miss `chain` long: NEAR MISS x3.
static func chain_label(chain_length: int) -> String:
	return "NEAR MISS" if chain_length <= 1 else "NEAR MISS x%d" % chain_length


## Points for a jump `seconds` long.
static func air_points(seconds: float) -> int:
	if seconds >= Tuning.v("scoring/big_air_time"):
		return Tuning.i("scoring/big_air")
	return Tuning.i("scoring/air") if seconds >= Tuning.v("scoring/air_time") else 0


static func clean_section_points(contacts_in_section: int) -> int:
	return Tuning.i("scoring/clean_section") if contacts_in_section == 0 else 0


static func no_crash_points(crash_count: int) -> int:
	return Tuning.i("scoring/no_crash") if crash_count == 0 else 0


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


## A bonus; `label` is what the feed shows when it isn't the name (NEAR MISS x3).
func add(bonus_name: String, points: int, label := "") -> void:
	if points <= 0:
		return
	bonuses.append({"name": bonus_name, "points": points})
	feed.append({"name": label if label != "" else bonus_name, "points": points, "age": 0.0})
	if feed.size() > 3:
		feed.pop_front()


## Every tick, racing or not, so the finish's bonuses fade from the HUD too.
func age_feed(dt: float) -> void:
	for f in feed:
		f["age"] += dt
	feed = feed.filter(func(f: Dictionary) -> bool: return f["age"] < FEED_TIME)


## One racing tick for the player, after it moved and collided.
func watch(dt: float, p: PlayerCar, track: Track) -> void:
	since_near_miss += dt
	if since_near_miss > Tuning.v("scoring/chain_window"):
		chain = 0  # the chain broke
	if p.crashed:
		crashes += 1
		chain = 0  # and a crash breaks it too
	if p.crashed or p.bumped:
		contacts += 1
	if p.airborne:
		air += dt
	elif p.landed or air > 0.0:
		var pts := air_points(air)
		add("BIG AIR" if pts == Tuning.i("scoring/big_air") else "AIR", pts)
		air = 0.0
	var drafting := p.draft_time > 0.0
	if drafting and not _was_drafting:
		add("SLIPSTREAM", Tuning.i("scoring/draft"))
	_was_drafting = drafting
	if p.crash_time > 0.0:
		return
	var nose := p.position + Cfg.PLAYER_Z
	var cars: Array = []
	for seg in p.passed_segments(track):
		cars.append_array(seg.cars.filter(func(c: Traffic.TrafficCar) -> bool: return not c.oncoming))
	# Oncoming traffic (RC-11) can go by without the nose entering its segment
	cars.append_array(Traffic.around(track, nose, Cfg.ONCOMING_REACH).filter(
		func(c: Traffic.TrafficCar) -> bool: return c.oncoming))
	for car: Traffic.TrafficCar in cars:
		if not car.solid():
			continue
		var now := track.gap(nose, car.z)
		if now <= 0.0 and p.gap_when_tick_began(car, track) > 0.0 \
				and near_miss(p.x, p.speed, car.offset, car.width_mult):
			near_miss_scored()


## A near miss this tick: it chains on the last within scoring/chain_window, and scores the
## chain's points. The bonus keeps the name NEAR MISS (one row in the tally) with its "chain".
func near_miss_scored() -> void:
	chain = chain_after(chain, since_near_miss)
	since_near_miss = 0.0
	var before := bonuses.size()
	add("NEAR MISS", chain_points(chain), chain_label(chain))
	if bonuses.size() > before:
		bonuses[-1]["chain"] = chain


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
