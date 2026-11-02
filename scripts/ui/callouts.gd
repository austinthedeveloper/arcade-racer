class_name Callouts
extends RefCounted
## The callouts over the road: starburst banners for GO, CHECKPOINT, NEAR MISS and the rest,
## and plain messages (FINISH!, TIME UP, a pickup). One shows at a time; the rest wait in a
## queue, so a near miss right after a checkpoint doesn't stomp it. A backlog cuts the one
## showing short, but never under MIN_SHOW. The race pushes them (race.gd `_banner`,
## `_callouts_after_tick`); the HUD draws `current` (Hud._draw_callout).

enum Kind { NONE = -1, GO, CHECKPOINT, TIME_EXTENDED, NEAR_MISS, BIG_AIR, FINAL_STRETCH, LAUNCH, FIRST_PLACE, MESSAGE }

## What each starburst says (MESSAGE brings its own text).
const TEXT := {
	Kind.GO: "GO!",
	Kind.CHECKPOINT: "CHECKPOINT",
	Kind.TIME_EXTENDED: "TIME EXTENDED",
	Kind.NEAR_MISS: "NEAR MISS",
	Kind.BIG_AIR: "BIG AIR",
	Kind.FINAL_STRETCH: "FINAL STRETCH",
	Kind.LAUNCH: "LAUNCH!",
	Kind.FIRST_PLACE: "1ST PLACE",
}
## The --callout=ID dev flag's names for the kinds (screenshots of one).
const IDS := {
	"go": Kind.GO, "checkpoint": Kind.CHECKPOINT, "time_extended": Kind.TIME_EXTENDED,
	"near_miss": Kind.NEAR_MISS, "big_air": Kind.BIG_AIR, "final_stretch": Kind.FINAL_STRETCH,
	"launch": Kind.LAUNCH, "first_place": Kind.FIRST_PLACE,
}
const SHOW_TIME := 1.2  # seconds a starburst stays up with nothing waiting behind it
const MIN_SHOW := 0.55  # ...and at least, with a backlog
const MAX_WAITING := 3  # past this the oldest waiting starburst is dropped
const HOLD := 999.0  # seconds for a message that stays until the race restarts (FINISH!, TIME UP)
const POP_TIME := 0.18  # the burst grows in over this
const FADE_TIME := 0.2  # and fades over its last
const FINAL_STRETCH_SHARE := 0.9  # of the route, when FINAL STRETCH comes up
const LEAD_GAP := 6.0  # seconds between two 1ST PLACE callouts, when the lead swaps back and forth

## The one up: {"kind", "text", "sub", "seconds", "age", "count"}, or empty.
var current := {}
var waiting: Array[Dictionary] = []


## A starburst `kind` (not MESSAGE). The same kind up or waiting already counts again
## instead (BIG AIR x2), and the one up pops again. `count` sets the count outright: a
## near-miss chain (RC-15) says how long it is, NEAR MISS x3.
func push(kind: Kind, sub := "", seconds := SHOW_TIME, count := 0) -> void:
	if kind == Kind.NONE:
		return
	if not current.is_empty() and current["kind"] == kind and kind != Kind.MESSAGE:
		current["count"] = count if count > 0 else current["count"] + 1
		current["sub"] = sub
		current["age"] = 0.0
		return
	for w in waiting:
		if w["kind"] == kind and kind != Kind.MESSAGE:
			w["count"] = count if count > 0 else w["count"] + 1
			w["sub"] = sub
			return
	_queue({"kind": kind, "text": TEXT.get(kind, ""), "sub": sub, "seconds": seconds, "age": 0.0, "count": maxi(count, 1)})


## A plain message, e.g. FINISH! or a pickup. HOLD keeps it up until `clear`.
func push_message(text: String, sub := "", seconds := SHOW_TIME) -> void:
	_queue({"kind": Kind.MESSAGE, "text": text, "sub": sub, "seconds": seconds, "age": 0.0, "count": 1})


func _queue(c: Dictionary) -> void:
	waiting.append(c)
	if waiting.size() > MAX_WAITING:
		for i in waiting.size():
			if waiting[i]["seconds"] < HOLD:
				waiting.remove_at(i)
				break
	if current.is_empty():
		_next()


func clear() -> void:
	current = {}
	waiting.clear()


func update(dt: float) -> void:
	if current.is_empty():
		return
	current["age"] += dt
	var held: bool = current["seconds"] >= HOLD
	if current["age"] >= current["seconds"] or (not waiting.is_empty() and current["age"] >= MIN_SHOW and not held) \
			or (held and not waiting.is_empty() and waiting.back()["seconds"] >= HOLD):
		_next()


func _next() -> void:
	current = {} if waiting.is_empty() else waiting.pop_front()


## What the one up says, with its count: "NEAR MISS x3".
static func label(c: Dictionary) -> String:
	return c["text"] if c["count"] <= 1 else "%s x%d" % [c["text"], c["count"]]


## The starburst for a scoring bonus (Scoring.add's names), or NONE. Its count is the
## bonus's "chain" when it has one.
static func for_bonus(bonus_name: String) -> Kind:
	match bonus_name:
		"NEAR MISS":
			return Kind.NEAR_MISS
		"BIG AIR":
			return Kind.BIG_AIR
	return Kind.NONE


## Whether `distance` is into the last stretch of a route `finish_distance` long.
static func in_final_stretch(distance: float, finish_distance: float) -> bool:
	return distance >= finish_distance * FINAL_STRETCH_SHARE and distance < finish_distance


## How big the one up is drawn, 0..1 and a little over: it pops in, overshooting, then
## settles; a held message doesn't pop.
static func pop_scale(age: float) -> float:
	if age >= POP_TIME:
		return 1.0
	var t := age / POP_TIME
	return lerpf(0.3, 1.0, t) + sin(t * PI) * 0.35


## Its alpha: fading out over FADE_TIME at the end (a cut-short one just goes).
static func alpha(c: Dictionary) -> float:
	if c["seconds"] >= HOLD:
		return 1.0
	return clampf((c["seconds"] - c["age"]) / FADE_TIME, 0.0, 1.0)


## A starburst's outline: `spikes` points round an ellipse `radius` across, the valleys at
## `inner` of it, turned by `spin` radians. Rounded to whole pixels for the pixel look.
static func starburst(center: Vector2, radius: Vector2, spikes: int, inner: float, spin := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := spin + PI * i / spikes - PI / 2.0
		var k := 1.0 if i % 2 == 0 else inner
		pts.append((center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * k).round())
	return pts
