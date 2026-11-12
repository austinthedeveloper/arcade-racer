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
const CREST_SPAN := 8  # segments either side of a crest its slopes are measured over (blind_crests)

## Corner warnings (WS-5, WS-20): what the road signs warn of, decided here and nowhere else.
## A bend is sharp where its curve is SHARP_CURVE or more (sharp_curves): it gets a turn arrow
## before it and chevrons along its outside. A crest is blind by blind_crests (CREST_SPAN and
## traffic/blind_crest, the same crests traffic keeps out from behind): it gets CREST_SIGN
## before it. Every jump and bumpy stretch (hazards) gets one too.
const SHARP_CURVE := CURVE_MEDIUM
const SIGN_AHEAD := 30  # segments before a sharp curve, crest, jump or bumps that its warning sign stands
## Where that spot is taken (a race gate, a span, a tunnel), the sign stands at the nearest open
## segment up to SIGN_SLACK either side of it, so every bend and crest still has one.
const SIGN_SLACK := 20
const CREST_SIGN := "bump_sign"
const HAZARD_REACH := 60  # segments: a jump's length (jump), so its crest is within this of its start
const CHEVRON_EVERY := 8
const RAIL_REACH := 10  # segments: rails stand every 10 (Bayou, Timberline), so a run has one this close
const CHEVRONS := ["chevron_a", "chevron_b", "chevron_c"]
## Scenery (WS-21): roadside on one side of a segment is bare when nothing stands on that side
## within BARE_REACH road half-widths of the road and it isn't under a span or in a tunnel.
## No stage has a bare stretch longer than MAX_BARE segments on either side: fill_bare plants
## something every FILL_EVERY segments of a longer one.
const BARE_REACH := 4.0
const MAX_BARE := 30
const FILL_EVERY := 24
const FILL_OFFSET := 1.8  # road half-widths out, clear of the cars
const FILL_SPREAD := 1.4
## Roadside art that reads wrong mirrored (lettering, numbers): on a mirrored stage it moves
## to the other side but keeps its art the right way round.
const MIRROR_KEEPS_ART := ["slot_machine"]

## Road width (WS-7): a narrowing or widening eases in over WIDTH_EASE segments either side,
## its lanes changing halfway through; MIN_LANES to MAX_LANES lanes. Drivers pick their lane
## from the narrowest road LANES_AHEAD segments ahead, so they move over before it narrows.
const WIDTH_EASE := 40
const MIN_LANES := 2
const MAX_LANES := 6
const LANES_AHEAD := 20

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
## Road hazards (RC-19, add_hazard): debris, cone rows, ice and puddles lying on the road.
var road_hazards: Array = []
## Set pieces (WS-21, add_set_piece): each one's name and the segment it starts at.
var set_pieces: Array[Dictionary] = []
## Stage flow (StageFlow.dress): the next stage's theme, and this stage's palette mixed toward
## it in StageFlow.STEPS steps. Empty on the last stage, which keeps its own end.
var next_theme: Dictionary = {}
var flow: Array[Dictionary] = []

## Mirror mode (WS-6): the stage flipped left for right (mirror). Spans and the background
## are drawn flipped, and whatever is placed across the road (traffic, pickups, rivals'
## lines) goes by side().
var mirrored := false

var _ground_left := GROUND_GRASS
var _ground_right := GROUND_GRASS
var _grip := NAN  # set_grip: NAN for the theme's


## Flips the built stage left for right (mirror mode, WS-6): every curve bends the other way,
## roadside sprites stand on the other side with their art mirrored, the ground either side
## swaps. Distances, heights and everything along the road stay as they are. Spans keep
## their ids; the renderer and PlayerCar.hits_span read them mirrored (side()).
func mirror() -> void:
	mirrored = not mirrored
	for seg in segments:
		seg.curve = -seg.curve
		var left := seg.ground_left
		seg.ground_left = seg.ground_right
		seg.ground_right = left
		for sp: Dictionary in seg.sprites:
			sp["offset"] = -float(sp["offset"])
			if not MIRROR_KEEPS_ART.has(sp["id"]):
				sp["flip"] = not sp["flip"]
	for h: RoadHazards.Hazard in road_hazards:
		h.offset = -h.offset


## 1 for a stage as built, -1 mirrored: what an x across the road is multiplied by to place
## it on the mirrored stage.
func side() -> float:
	return -1.0 if mirrored else 1.0


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


## The road's half-width (in Cfg.ROAD_WIDTH) at `z`: past it, a car is off the road.
func width_at(z: float) -> float:
	return find_segment(z).width_at(fposmod(z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH)


## The narrowest segment from `z` to `ahead` segments on (the fewer lanes on a tie): the
## lanes a driver there should be choosing between.
func narrowest_ahead(z: float, ahead := LANES_AHEAD) -> Segment:
	var here := find_segment(z)
	var best := here
	for k in range(1, ahead + 1):
		var seg := segments[(here.index + k) % segments.size()]
		if seg.width < best.width or (seg.width == best.width and seg.lanes < best.lanes):
			best = seg
	return best


# --- Builder -----------------------------------------------------------------

func set_ground(left: int, right: int) -> void:
	_ground_left = left
	_ground_right = right


## The grip of the road from here on (PlayerCar.grip_for): NAN goes back to the theme's
## "grip" (1, dry, without one).
func set_grip(grip: float) -> void:
	_grip = grip


## How busy the road is along a stretch (RC-20): set_traffic, read by Traffic.spawn_totals.
const TRAFFIC_EMPTY := 0
const TRAFFIC_QUIET := 1
const TRAFFIC_NORMAL := 2
const TRAFFIC_BUSY := 3


## Segments `first` to `first + count` (wrapping) carry `level` traffic: TRAFFIC_EMPTY to
## TRAFFIC_BUSY. A stage's script sets its stretches; the rest stay TRAFFIC_NORMAL.
func set_traffic(first: int, count: int, level: int) -> void:
	for i in range(first, first + count):
		segments[posmod(i, segments.size())].traffic = level


## A traffic level's share of the spawned cars per segment, against TRAFFIC_NORMAL's 1:
## traffic/quiet and traffic/busy (Tuning).
static func traffic_weight(level: int) -> float:
	match level:
		TRAFFIC_EMPTY:
			return 0.0
		TRAFFIC_QUIET:
			return Tuning.v("traffic/quiet")
		TRAFFIC_BUSY:
			return Tuning.v("traffic/busy")
		_:
			return 1.0


## Makes the road `width` half-widths (Cfg.ROAD_WIDTH; 1 is usual) with `lanes` lanes for
## segments `first` to `first + count`, easing from the width either side over `ease`
## segments before and after, its lanes changing halfway through each ease. Call after the
## road is laid; sprites already placed follow the new edge.
func set_width(first: int, count: int, width: float, lanes: int, ease := WIDTH_EASE) -> void:
	assert(lanes >= MIN_LANES and lanes <= MAX_LANES, "2 to 6 lanes")
	var n := segments.size()
	var from := segments[clampi(first - ease, 0, n - 1)]
	var back := segments[clampi(first + count + ease - 1, 0, n - 1)]
	var ends: Array[float] = []  # the width at the near end of each segment, then the last far end
	for i in range(first - ease, first + count + ease + 1):
		ends.append(width_ease_at(i, first, count, ease, from.width, width, back.width_far))
	for i in range(maxi(0, first - ease), mini(n, first + count + ease)):
		var seg := segments[i]
		seg.width = ends[i - (first - ease)]
		seg.width_far = ends[i - (first - ease) + 1]
		if i < first - ease / 2:
			seg.lanes = from.lanes
		elif i >= first + count + ease / 2:
			seg.lanes = back.lanes
		else:
			seg.lanes = lanes


## The width at the near end of segment `i` of a set_width from `first` for `count`
## segments: `before` easing (in and out, over `ease` segments) to `width`, then back to `after`.
static func width_ease_at(i: int, first: int, count: int, ease: int, before: float, width: float, after: float) -> float:
	if i < first:
		return _ease_in_out(before, width, clampf(float(i - (first - ease)) / ease, 0.0, 1.0))
	if i > first + count:
		return _ease_in_out(width, after, clampf(float(i - (first + count)) / ease, 0.0, 1.0))
	return width


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
	seg.grip = theme.get("grip", 1.0) if is_nan(_grip) else _grip
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


## The entrance segment of every tunnel and covered bridge (the segment before its first
## covered one), in order.
func tunnel_mouths() -> Array[int]:
	var out: Array[int] = []
	for i in range(1, segments.size()):
		if segments[i].covered and not segments[i - 1].covered:
			out.append(i - 1)
	return out


## Every blind crest (RC-14), in order: a segment where the road stops climbing and drops away
## so sharply that the road beyond is out of sight. Its slope over CREST_SPAN segments before it
## less the slope over CREST_SPAN after is traffic/blind_crest (Tuning) at least: a jump or a
## big hill's top, not a gentle roll or a bump.
func blind_crests() -> Array[int]:
	var out: Array[int] = []
	var n := segments.size()
	var sharp := Tuning.v("traffic/blind_crest")
	for i in range(1, n - 1):
		var up := segments[i - 1].w2.y - segments[i - 1].w1.y
		var down := segments[i].w2.y - segments[i].w1.y
		if up <= 0.0 or down > 0.0:
			continue
		var before := maxi(0, i - CREST_SPAN)
		var after := mini(n - 1, i + CREST_SPAN)
		var rise := (segments[i].w1.y - segments[before].w1.y) / ((i - before) * Cfg.SEGMENT_LENGTH)
		var fall := (segments[after].w1.y - segments[i].w1.y) / ((after - i) * Cfg.SEGMENT_LENGTH)
		if rise - fall >= sharp:
			out.append(i)
	return out


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


## A road hazard (RoadHazards.Kind) in the lane `across` of the way over the road there (0 its
## left edge, 1 its right: Segment.lane_at, so it finds a lane on a road of any width) from
## segment `index` for `length` segments, at the first spot at or after it clear of race gates,
## spans and jumps (free_spot; Track.hazards) and of the pickups' spots (PowerUps.SPOTS).
## Call once the road's widths are set (set_width): it takes the lane's middle and width
## there. Lanes count from the left of the stage as built; mirror() moves it across. Returns
## the hazard, or null when there's no room.
func add_hazard(kind: int, index: int, across: float, length := 1) -> RoadHazards.Hazard:
	var i := index
	while i >= 0 and i < segments.size() - length and not hazard_spot_clear(i, length):
		i += 1
	if i < 0 or i >= segments.size() - length:
		return null
	var seg := segments[i]
	var h := RoadHazards.Hazard.new()
	h.kind = kind
	h.segment = i
	h.length = length
	h.offset = seg.lane_at(across)
	h.half = RoadHazards.half_for(kind, seg.width * 2.0 / seg.lanes)
	road_hazards.append(h)
	for k in length:
		segments[i + k].hazards.append(h)
	return h


## Whether segments `index` to `index + length` can take a hazard: no race gate or span within
## HAZARD_MARGIN of it, no jump or bumps starting within HAZARD_REACH before it, no pickup spot
## within HAZARD_MARGIN, no other hazard on it.
const HAZARD_MARGIN := 12
func hazard_spot_clear(index: int, length: int) -> bool:
	var n := segments.size()
	for j in range(maxi(0, index - HAZARD_MARGIN), mini(n, index + length + HAZARD_MARGIN)):
		if segments[j].flags != 0 or not segments[j].spans.is_empty() or not segments[j].hazards.is_empty():
			return false
	for start in hazards:
		if index + length >= start and index <= start + HAZARD_REACH:
			return false
	for f: float in PowerUps.SPOTS:
		if absi(int(n * f) - index) < HAZARD_MARGIN + length:
			return false
	return true


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


## A set piece (WS-21): a small roadside scene of `props`, each [id, segments on from its
## start, offset (road half-widths, + right as built), flip], at the first free spot at or after
## `index` (no race gate or span near, no part of it in a tunnel). Kept as `name` in set_pieces.
## The segment it starts at, or -1 if there's no room.
func add_set_piece(name_: String, index: int, props: Array) -> int:
	var reach := 0
	for p: Array in props:
		reach = maxi(reach, p[1])
	var at := free_spot(index, 4)
	while at >= 0 and not _open_run(at, reach):
		at = free_spot(at + 1, 4)
	if at < 0:
		return -1
	for p: Array in props:
		add_sprite(at + int(p[1]), p[0], p[2], p[3] if p.size() > 3 else false)
	set_pieces.append({"name": name_, "at": at})
	return at


func _open_run(first: int, length: int) -> bool:
	for i in range(first, first + length + 1):
		if not open_roadside(i):
			return false
	return true


## Plants `ids` in turn wherever roadside on either side has been bare (bare) for FILL_EVERY
## segments, FILL_OFFSET to FILL_OFFSET + FILL_SPREAD out, so no bare stretch runs past
## MAX_BARE. Call last in a stage's build, once everything else stands.
func fill_bare(ids: Array) -> void:
	var k := 0
	for side: float in [-1.0, 1.0]:
		var run := 0
		for i in segments.size():
			run = run + 1 if bare(i, side) else 0
			if run <= FILL_EVERY or not open_roadside(i):
				continue
			var out := FILL_OFFSET + FILL_SPREAD * fposmod(k * 0.37, 1.0)
			add_sprite(i, ids[k % ids.size()], side * out, side < 0.0)
			k += 1
			run = 0


## Whether nothing stands on `side` (-1 left, 1 right) of segment `index` within BARE_REACH
## and it's out in the open (no span over it, not in a tunnel).
func bare(index: int, side: float) -> bool:
	var seg := segments[index]
	if seg.covered or not seg.spans.is_empty():
		return false
	for sp: Dictionary in seg.sprites:
		var o: float = sp["offset"]
		if signf(o) == side and absf(o) <= BARE_REACH:
			return false
	return true


## The longest run of segments bare on `side` (-1 left, 1 right), as (first segment, length).
func longest_bare(side: float) -> Vector2i:
	var best := Vector2i(0, 0)
	var run := 0
	for i in segments.size():
		run = run + 1 if bare(i, side) else 0
		if run > best.y:
			best = Vector2i(i - run + 1, run)
	return best


## Crowds behind barriers, a grandstand, a camera tower and a flagman before the finish line.
func add_finish_crowd() -> void:
	var f := finish_index
	for k in range(-60, 0, 6):
		add_sprite(f + k, "barrier_red", -1.15)
		add_sprite(f + k, "crowd", 1.3)
	add_sprite(f - 30, "grandstand", 2.0)
	add_sprite(f - 12, "camera_tower", -2.0)
	add_sprite(f - 4, "flagman", 1.15)


## Warning signs (WS-5, WS-20), placed from the track data: a turn arrow before every sharp
## curve (SHARP_CURVE) on its outside and, with `chevrons`, chevrons along its outside where no
## rail already runs; a bump sign before every jump and bumpy stretch, and a crest sign before
## every blind crest (blind_crests) that one doesn't already warn of. Call after the stage's
## spans, tunnels and rails: nothing goes under a span, in a tunnel or on a race gate. Built
## for the stage as it stands; mirror() then moves every sign across with its bend.
func add_road_signs(chevrons := true) -> void:
	for run in sharp_curves():
		var first: int = run.x
		var dir := signf(segments[first].curve)
		var outside := -dir
		_warn(first, "turn_right" if dir > 0.0 else "turn_left", outside * 1.5, false)
		if chevrons:
			var k := 0
			for i in range(first, run.y, CHEVRON_EVERY):
				if railed(i, outside):
					continue
				# The chevron art points right; mirrored, it points into a left-hand curve
				_add_sign(i, CHEVRONS[k % CHEVRONS.size()], outside * 1.5, dir < 0.0)
				k += 1
	for h in hazards:
		_warn(h, CREST_SIGN, 1.3, false)
	for c in blind_crests():
		if hazard_before(c) < 0:
			_warn(c, CREST_SIGN, 1.3, false)


## The jump or bumpy stretch (hazards) that crest `crest` is the top of: one starting at most
## HAZARD_REACH segments before it, or -1. Its bump sign already warns of the crest.
func hazard_before(crest: int) -> int:
	for h in hazards:
		if h <= crest and crest - h <= HAZARD_REACH:
			return h
	return -1


## The farthest before a bend or crest its warning sign can stand (SIGN_AHEAD + SIGN_SLACK).
static func warning_reach() -> int:
	return SIGN_AHEAD + SIGN_SLACK


## Puts sign `id` SIGN_AHEAD segments before segment `target`, or at the nearest open
## segment within SIGN_SLACK of that (nearer first on a tie). The segment it stands on, or -1.
func _warn(target: int, id: String, offset: float, flip: bool) -> int:
	var ideal := target - SIGN_AHEAD
	for d in SIGN_SLACK + 1:
		for i in ([ideal + d, ideal - d] if d > 0 else [ideal]):
			if i < target and open_roadside(i):
				add_sprite(i, id, offset, flip)
				return i
	return -1


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
