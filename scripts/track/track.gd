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

const GROUND_GRASS := 0
const GROUND_SAND := 1

var name := ""
var theme: Dictionary = {}
var segments: Array[Segment] = []
var length := 0.0
var checkpoints: Array[int] = []
var finish_index := 0

var _ground_left := GROUND_GRASS
var _ground_right := GROUND_GRASS


func find_segment(z: float) -> Segment:
	return segments[posmod(floori(z / Cfg.SEGMENT_LENGTH), segments.size())]


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
	for h in [5.0, -2.0, -5.0, 8.0, 5.0, -7.0, 5.0, -2.0]:
		add_road(10, 10, 10, 0.0, h)


## A short, sharp crest that launches fast cars into the air.
func jump(height: float = HILL_LOW * 0.6) -> void:
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
## an interior frame every `every` segments, with the roadside cleared and the road darkened.
func add_tunnel(start: int, length: int, entrance: String, ring: String, every := 3) -> void:
	add_span(start, entrance)
	for i in range(start + 1, mini(start + length, segments.size())):
		segments[i].covered = true
		segments[i].sprites.clear()
		if (i - start) % every == 0:
			add_span(i, ring)
	add_span(mini(start + length, segments.size() - 1), entrance)


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


func add_checkpoint(index: int) -> void:
	segments[index].flags |= Segment.FLAG_CHECKPOINT
	checkpoints.append(index)


func finish_building(finish_at: int) -> void:
	length = segments.size() * Cfg.SEGMENT_LENGTH
	finish_index = finish_at
	segments[finish_at].flags |= Segment.FLAG_FINISH


static func _ease_in(a: float, b: float, p: float) -> float:
	return a + (b - a) * p * p


static func _ease_in_out(a: float, b: float, p: float) -> float:
	return a + (b - a) * (-cos(p * PI) / 2.0 + 0.5)
