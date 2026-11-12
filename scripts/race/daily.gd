class_name Daily
extends RefCounted
## The daily run (MP-14): one stage, car, weather and traffic mix a calendar day, the same on
## every machine, raced solo against the stage's clock. Each finish (or TIME UP) is a try,
## and the day's best tries are kept (SaveData.daily) until the date changes.
##
## The pick comes from the local date alone: seed_for hashes the year, month and day with
## 32-bit FNV-1a, and pick rolls the choices from that seed with a little generator of its
## own (next_roll), so it never depends on Godot's string hashes or its random number
## generators and is the same on every platform and build.
##
## It picks from every stage and every car, unlocked or not: the run is the same for
## everyone, so it can't follow one save's progress, and a day in a car or on a stage you
## haven't reached is a taste of it (nothing it does unlocks anything or sets a stage's
## best). Only the secret car (Unlocks.SECRET_CAR) is left out, to stay a secret.

## Weather: the stage's own (Thunderhead's storm), or one of these over it.
enum Forecast { CLEAR, RAIN, STORM }
const SKY_NAMES := ["CLEAR", "RAIN", "STORM"]
## The weather's odds, out of the sum: mostly clear.
const SKY_WEIGHTS := [5, 3, 2]
const RAIN := {"rain": 0.6, "wet": 0.25, "lightning": false}
## Traffic mixes: a name, the traffic option's count times `count`, and the share of big
## vehicles (Traffic.BIG_SHARE is the usual).
const MIXES := [
	{"name": "LIGHT", "count": 0.6, "big": 0.15},
	{"name": "NORMAL", "count": 1.0, "big": 0.15},
	{"name": "HEAVY", "count": 1.5, "big": 0.15},
	{"name": "TRUCKS", "count": 1.0, "big": 0.45},
]
## How many of the day's best tries are kept and shown.
const BEST_TRIES := 3


## The calendar day as one number: 20261111 for 11 November 2026.
static func day_key(year: int, month: int, day: int) -> int:
	return year * 10000 + month * 100 + day


## Today on this machine's calendar (local time), as day_key.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return day_key(int(d["year"]), int(d["month"]), int(d["day"]))


## A day's seed: 32-bit FNV-1a over the digits of its key. Plain integer arithmetic, masked
## to 32 bits, so the same on every platform.
static func seed_for(key: int) -> int:
	var h := 2166136261
	for c in str(key).to_ascii_buffer():
		h = ((h ^ c) * 16777619) & 0xFFFFFFFF
	return h


## The next roll from `state` (a 32-bit xorshift); returns the new state, never 0.
static func next_roll(state: int) -> int:
	var x := state & 0xFFFFFFFF
	if x == 0:
		x = 0x9E3779B9
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	return x & 0xFFFFFFFF


## One weighted pick among `weights` from `roll`.
static func weighted(roll: int, weights: Array) -> int:
	var total := 0
	for w: int in weights:
		total += w
	var r := roll % total
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return weights.size() - 1


## The cars the day can pick: all but the secret one.
static func cars() -> Array[String]:
	var out: Array[String] = []
	for car: Dictionary in Cars.LIST:
		if car["id"] != Unlocks.SECRET_CAR:
			out.append(car["id"])
	return out


## The day `key`'s run: {"day", "seed", "stage" (index), "car" (id), "sky" (a Forecast), "mix"
## (into MIXES), "traffic_seed"}.
static func pick(key: int) -> Dictionary:
	var s := seed_for(key)
	var r := next_roll(s)
	var stage := r % Stages.count()
	r = next_roll(r)
	var garage := cars()
	var car: String = garage[r % garage.size()]
	r = next_roll(r)
	var sky := weighted(r, SKY_WEIGHTS)
	r = next_roll(r)
	var mix := r % MIXES.size()
	r = next_roll(r)
	return {"day": key, "seed": s, "stage": stage, "car": car, "sky": sky, "mix": mix, "traffic_seed": r % 100000}


## The weather a picked run has on a stage whose theme has `own` (Weather.of): the stage's
## own when it has any (Thunderhead keeps its storm), else the day's sky.
static func weather(p: Dictionary, own: Dictionary) -> Dictionary:
	if not own.is_empty():
		return own
	match int(p["sky"]):
		Forecast.RAIN:
			var w := RAIN.duplicate()
			w["seed"] = int(p["seed"]) % 10000
			return w
		Forecast.STORM:
			var w := Weather.STORM.duplicate()
			w["seed"] = int(p["seed"]) % 10000
			return w
	return {}


## The weather's name for the card: the stage's own storm shows as STORM.
static func sky_name(p: Dictionary, own: Dictionary) -> String:
	var w := weather(p, own)
	if w.is_empty():
		return SKY_NAMES[Forecast.CLEAR]
	return SKY_NAMES[Forecast.STORM] if w.get("lightning", false) else SKY_NAMES[Forecast.RAIN]


## The traffic for a picked run on a stage whose usual count is `base` (after the option).
static func traffic_count(p: Dictionary, base: int) -> int:
	return roundi(base * float(MIXES[int(p["mix"])]["count"]))


static func big_share(p: Dictionary) -> float:
	return float(MIXES[int(p["mix"])]["big"])


static func mix_name(p: Dictionary) -> String:
	return MIXES[int(p["mix"])]["name"]


## The day as the card shows it: "WED 11 NOV 2026".
static func date_text(key: int) -> String:
	var y := key / 10000
	var m := (key / 100) % 100
	var d := key % 100
	var unix := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	var wd := int(Time.get_datetime_dict_from_unix_time(unix)["weekday"])
	const DAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	return "%s %d %s %d" % [DAYS[wd], d, MONTHS[clampi(m - 1, 0, 11)], y]


## The tries kept for `day` after one more, `time` seconds (INF for a try that ran out of
## time): `tries` counts them all, `times` the best BEST_TRIES finishes, fastest first. A
## different day than `kept`'s starts over.
static func add_try(kept: Dictionary, day: int, time: float) -> Dictionary:
	var out := {"day": day, "tries": 0, "times": []}
	if int(kept.get("day", 0)) == day:
		out["tries"] = int(kept.get("tries", 0))
		out["times"] = (kept.get("times", []) as Array).duplicate()
	out["tries"] += 1
	if not is_inf(time) and time > 0.0:
		var times: Array = out["times"]
		times.append(time)
		times.sort()
		out["times"] = times.slice(0, BEST_TRIES)
	return out


## The tries kept, as of `day`: nothing when they are from another day.
static func tries_on(kept: Dictionary, day: int) -> Dictionary:
	if int(kept.get("day", 0)) != day:
		return {"day": day, "tries": 0, "times": []}
	return kept
