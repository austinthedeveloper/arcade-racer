class_name Track
extends RefCounted
## A looping list of road segments plus builder helpers for authoring stages.

const LENGTH_SHORT := 25
const LENGTH_MEDIUM := 50
const LENGTH_LONG := 100

const CURVE_EASY := 2.0
const CURVE_MEDIUM := 4.0
const CURVE_HARD := 6.0

const HILL_LOW := 20.0
const HILL_MEDIUM := 40.0
const HILL_HIGH := 60.0

const START_SEGMENT := 14  # where the start line is drawn
const CHECKPOINT_FRACTIONS := [0.25, 0.5, 0.75]
const FINISH_INTO_STRAIGHT := 60  # segments into the final straight
const TUNNEL_RAMP := 10.0  # segments from a tunnel mouth to its darkest

## Curves this sharp or sharper get a turn sign before them and chevrons on the outside.
const SHARP_CURVE := CURVE_MEDIUM
const SIGN_AHEAD := 30  # segments before a sharp curve, jump or bumps that its warning sign stands
const CHEVRON_EVERY := 8
const RAIL_REACH := 10  # segments: rails stand every 10 (Bayou, Timberline), so a run has one this close
const CHEVRONS := ["chevron_a", "chevron_b", "chevron_c"]

const GROUND_GRASS := 0
const GROUND_SAND := 1

var name := ""
var theme: Dictionary = {}
var segments: Array[Segment] = []
var length := 0.0
var checkpoints: Array[int] = []
var finish_index := 0
## First segment of every jump and bumpy stretch, for the bump signs (add_road_signs).
var hazards: Array[int] = []

var _ground_left := GROUND_GRASS
var _ground_right := GROUND_GRASS


func find_segment(z: float) -> Segment:
	return segments[posmod(floori(z / Cfg.SEGMENT_LENGTH), segments.size())]


## The segments a point moving forward from `from_z` to `to_z` (both wrapped, less than a lap
## apart) enters, in order; just the one under it if it stays in its segment. At nitro speed a
## car covers more than a segment a tick, so pickups and collisions check all of these.
func segments_entered(from_z: float, to_z: float) -> Array[Segment]:
	var n := segments.size()
	var first := floori(from_z / Cfg.SEGMENT_LENGTH)
	var steps := posmod(floori(to_z / Cfg.SEGMENT_LENGTH) - first, n)
	var out: Array[Segment] = []
	for k in range(1, steps + 1):
		out.append(segments[posmod(first + k, n)])
	if out.is_empty():
		out.append(find_segment(to_z))
	return out


func height_at(z: float) -> float:
	var seg := find_segment(z)
	var t := fposmod(z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
	return lerpf(seg.w1.y, seg.w2.y, t)


# --- Builder -----------------------------------------------------------------

func set_ground(left: int, right: int) -> void:
	_ground_left = left
	_ground_right = right


func last_y() -> float:
	return 0.0 if segments.is_empty() else segments[-1].w2.y


func add_segment(curve_amount: float, y: float) -> void:
	var n := segments.size()
	var seg := Segment.new()
	seg.index = n
	seg.w1 = Vector3(0.0, last_y(), n * Cfg.SEGMENT_LENGTH)
	seg.w2 = Vector3(0.0, y, (n + 1) * Cfg.SEGMENT_LENGTH)
	seg.curve = curve_amount
	seg.band = posmod(floori(float(n) / Cfg.RUMBLE_LENGTH), 2)
	seg.ground_left = _ground_left
	seg.ground_right = _ground_right
	segments.append(seg)


## Adds a stretch of road that eases into a curve, holds it and eases out, while
## moving the road height by `height` segment-lengths over the whole stretch.
func add_road(enter: int, hold: int, leave: int, curve_amount: float, height: float) -> void:
	var start_y := last_y()
	var end_y := start_y + height * Cfg.SEGMENT_LENGTH
	var total := float(enter + hold + leave)
	for n in enter:
		add_segment(_ease_in(0.0, curve_amount, float(n) / enter), _ease_in_out(start_y, end_y, n / total))
	for n in hold:
		add_segment(curve_amount, _ease_in_out(start_y, end_y, (enter + n) / total))
	for n in leave:
		add_segment(_ease_in_out(curve_amount, 0.0, float(n) / leave), _ease_in_out(start_y, end_y, (enter + hold + n) / total))


func straight(n: int = LENGTH_MEDIUM) -> void:
	add_road(n, n, n, 0.0, 0.0)


func hill(n: int, height: float) -> void:
	add_road(n, n, n, 0.0, height)


func curve(n: int, curve_amount: float, height: float = 0.0) -> void:
	add_road(n, n, n, curve_amount, height)


func low_rolling_hills(n: int = LENGTH_SHORT, height: float = HILL_LOW) -> void:
	add_road(n, n, n, 0.0, height / 2.0)
	add_road(n, n, n, 0.0, -height)
	add_road(n, n, n, CURVE_EASY, height)
	add_road(n, n, n, 0.0, 0.0)
	add_road(n, n, n, -CURVE_EASY, height / 2.0)
	add_road(n, n, n, 0.0, 0.0)


func s_curves() -> void:
	add_road(LENGTH_MEDIUM, LENGTH_MEDIUM, LENGTH_MEDIUM, -CURVE_EASY, 0.0)
	add_road(LENGTH_MEDIUM, LENGTH_MEDIUM, LENGTH_MEDIUM, CURVE_MEDIUM, HILL_MEDIUM)
	add_road(LENGTH_MEDIUM, LENGTH_MEDIUM, LENGTH_MEDIUM, CURVE_EASY, -HILL_LOW)
	add_road(LENGTH_MEDIUM, LENGTH_MEDIUM, LENGTH_MEDIUM, -CURVE_EASY, HILL_MEDIUM)
	add_road(LENGTH_MEDIUM, LENGTH_MEDIUM, LENGTH_MEDIUM, -CURVE_MEDIUM, -HILL_MEDIUM)


func bumps() -> void:
	hazards.append(segments.size())
	for h in [5.0, -2.0, -5.0, 8.0, 5.0, -7.0, 5.0, -2.0]:
		add_road(10, 10, 10, 0.0, h)


## A short, sharp crest that launches fast cars into the air.
func jump(height: float = HILL_LOW * 0.6) -> void:
	hazards.append(segments.size())
	add_road(10, 15, 5, 0.0, height)
	add_road(5, 15, 10, 0.0, -height)


func downhill_to_end(n: int = 200) -> void:
	add_road(n, n, n, -CURVE_EASY, -last_y() / Cfg.SEGMENT_LENGTH)


func add_sprite(index: int, id: String, offset: float, flip: bool = false) -> void:
	if index < 0 or index >= segments.size():
		return
	segments[index].sprites.append({"id": id, "offset": offset, "flip": flip})


## A road-spanning sprite (SpriteLibrary.spans) across the road at the start of segment `index`.
func add_span(index: int, id: String) -> void:
	if index >= 0 and index < segments.size():
		segments[index].spans.append(id)


## A tunnel or covered bridge from segment `start` for `length` segments: the entrance, then
## an interior frame every `every` segments, with the roadside cleared and the road darkened,
## more so deeper in. The far end is `exit` (the entrance again if "").
func add_tunnel(start: int, length: int, entrance: String, ring: String, every := 3, exit := "") -> void:
	add_span(start, entrance)
	var end := mini(start + length, segments.size() - 1)
	for i in range(start + 1, mini(start + length, segments.size())):
		segments[i].covered = true
		segments[i].depth = tunnel_depth(i - start, end - start)
		segments[i].sprites.clear()
		if (i - start) % every == 0:
			add_span(i, ring)
	add_span(end, exit if exit != "" else entrance)


## How far into a tunnel `length` segments long segment `k` of it is: 0 at either mouth, up to
## 1 once TUNNEL_RAMP segments in.
static func tunnel_depth(k: int, length: int) -> float:
	return clampf(float(mini(k, length - k)) / TUNNEL_RAMP, 0.0, 1.0)


## The first segment at or after `index` with no race gate or span within `margin` segments.
func free_spot(index: int, margin := 8) -> int:
	var i := index
	while i < segments.size() - margin:
		var clear := true
		for j in range(maxi(0, i - margin), i + margin + 1):
			if segments[j].flags != 0 or not segments[j].spans.is_empty():
				clear = false
				break
		if clear:
			return i
		i += 1
	return -1


## Spans `id` across the road near each fraction of the stage's length.
func add_spans_at(id: String, fractions: Array) -> void:
	for f: float in fractions:
		var i := free_spot(int(segments.size() * f))
		if i >= 0:
			add_span(i, id)


## One-off landmarks: each id in turn, every `every` segments from `first`, at a free spot
## (no race gate or span nearby), `offset` road half-widths out. side -1 left, 1 right,
## 0 alternating.
func scatter(ids: Array, first: int, every: int, offset: float, side := 0) -> void:
	var at := first
	for k in ids.size():
		var i := free_spot(at, 4)
		if i < 0:
			return
		var s := float(side) if side != 0 else (-1.0 if k % 2 == 0 else 1.0)
		add_sprite(i, ids[k], s * offset)
		at = i + every


## Crowds behind barriers, a grandstand, a camera tower and a flagman before the finish line.
func add_finish_crowd() -> void:
	var f := finish_index
	for k in range(-60, 0, 6):
		add_sprite(f + k, "barrier_red", -1.15)
		add_sprite(f + k, "crowd", 1.3)
	add_sprite(f - 30, "grandstand", 2.0)
	add_sprite(f - 12, "camera_tower", -2.0)
	add_sprite(f - 4, "flagman", 1.15)


## Warning signs: a turn arrow before every sharp curve (SHARP_CURVE) and, with `chevrons`,
## chevrons along its outside where no rail already runs; a bump sign before every jump and
## bumpy stretch. Call after the stage's spans, tunnels and rails: nothing goes under a span,
## in a tunnel or on a race gate.
func add_road_signs(chevrons := true) -> void:
	for run in sharp_curves():
		var first: int = run.x
		var dir := signf(segments[first].curve)
		var outside := -dir
		_add_sign(first - SIGN_AHEAD, "turn_right" if dir > 0.0 else "turn_left", outside * 1.5, false)
		if chevrons:
			var k := 0
			for i in range(first, run.y, CHEVRON_EVERY):
				if railed(i, outside):
					continue
				# The chevron art points right; mirrored, it points into a left-hand curve
				_add_sign(i, CHEVRONS[k % CHEVRONS.size()], outside * 1.5, dir < 0.0)
				k += 1
	for h in hazards:
		_add_sign(h - SIGN_AHEAD, "bump_sign", 1.3, false)


## Whether a rail (a "rail_" or "guardrail" sprite) stands on `side` (-1 left, 1 right) within
## RAIL_REACH segments of `index`: the bend is lined already, chevrons would stand on it.
func railed(index: int, side: float) -> bool:
	for i in range(maxi(0, index - RAIL_REACH), mini(segments.size(), index + RAIL_REACH + 1)):
		for sp in segments[i].sprites:
			var id: String = sp["id"]
			if (id.begins_with("rail_") or id == "guardrail") and signf(sp["offset"]) == side:
				return true
	return false


## Each stretch of sharp curve as (first segment, end): segments in a row at least
## SHARP_CURVE sharp, bending the same way.
func sharp_curves() -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var i := 0
	while i < segments.size():
		var c := segments[i].curve
		if absf(c) < SHARP_CURVE:
			i += 1
			continue
		var j := i
		while j < segments.size() and absf(segments[j].curve) >= SHARP_CURVE and signf(segments[j].curve) == signf(c):
			j += 1
		runs.append(Vector2i(i, j))
		i = j
	return runs


## True if a roadside prop can stand at segment `index`: on the track, not on a race gate,
## under a span or in a tunnel.
func open_roadside(index: int) -> bool:
	if index < 0 or index >= segments.size():
		return false
	var seg := segments[index]
	return seg.flags == 0 and seg.spans.is_empty() and not seg.covered


func _add_sign(index: int, id: String, offset: float, flip: bool) -> void:
	if open_roadside(index):
		add_sprite(index, id, offset, flip)


## Race furniture: tire stacks, barrels and a sponsor arch around the start line, cones,
## delineators, barricades and barriers at every checkpoint. Call after the stage's spans and
## tunnels, like add_road_signs.
func add_race_furniture() -> void:
	var s := START_SEGMENT
	for k in [-12, -8, -4, 4, 8, 12]:
		_add_sign(s + k, "tire_stack", -1.15, false)
		_add_sign(s + k, "tire_stack", 1.15, true)
	_add_sign(s - 6, "barrels_yellow", -1.5, false)
	_add_sign(s + 6, "barrels_yellow", 1.5, true)
	_add_sign(s + 18, "inflatable_arch", 1.35, false)
	for c in checkpoints:
		for k in range(-24, -12, 4):
			_add_sign(c + k, "delineator", -1.1, false)
			_add_sign(c + k, "delineator", 1.1, true)
		for k in range(-12, 0, 3):
			_add_sign(c + k, "cone_orange", -1.05, false)
			_add_sign(c + k, "cone_orange", 1.05, true)
		_add_sign(c - 2, "barricade", -1.2, false)
		_add_sign(c - 2, "barricade", 1.2, true)
		_add_sign(c + 4, "barrier_orange", -1.2, false)
		_add_sign(c + 4, "barrier_orange", 1.2, true)


func add_checkpoint(index: int) -> void:
	segments[index].flags |= Segment.FLAG_CHECKPOINT
	checkpoints.append(index)


## Every stage ends the same way: the start line a little way in, checkpoints at a quarter,
## a half and three quarters of the way, and the finish FINISH_INTO_STRAIGHT segments into the
## final straight (which starts at segment `final_straight`). Call after the last road piece.
func finish_stage(final_straight: int) -> void:
	var n := segments.size()
	segments[START_SEGMENT].flags |= Segment.FLAG_START
	for f: float in CHECKPOINT_FRACTIONS:
		add_checkpoint(int(n * f))
	finish_building(final_straight + FINISH_INTO_STRAIGHT)


func finish_building(finish_at: int) -> void:
	length = segments.size() * Cfg.SEGMENT_LENGTH
	finish_index = finish_at
	segments[finish_at].flags |= Segment.FLAG_FINISH


static func _ease_in(a: float, b: float, p: float) -> float:
	return a + (b - a) * p * p


static func _ease_in_out(a: float, b: float, p: float) -> float:
	return a + (b - a) * (-cos(p * PI) / 2.0 + 0.5)
