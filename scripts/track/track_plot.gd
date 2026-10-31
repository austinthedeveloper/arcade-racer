@tool
class_name TrackPlot
extends RefCounted
## Plots a stage for authoring: the road from above and in side elevation, with the start,
## checkpoints, finish, spans (tunnels, bridges, arches) and roadside sprites marked by kind.
## tools/track_preview.gd writes one PNG per stage; render() works in the editor too.
##
## The road has no real geometry: a segment's `curve` bends the renderer's view by that many
## world units sideways per segment per segment, so from above it turns the heading by
## curve / SEGMENT_LENGTH radians a segment (heading_step).

const SIZE := Vector2i(1280, 960)
const PLAN := Rect2i(16, 40, 1248, 640)  # the top-down plot
const SIDE := Rect2i(16, 720, 1248, 200)  # the elevation, distance across, height up
const LEGEND := Vector2i(24, 48)

const BG := Color("#14121c")
const PANEL := Color("#1d1a29")
const GRID := Color("#2c2840")
const TEXT := Color("#e8e4f0")
const ROAD := Color("#c9c4d6")
const COVERED := Color("#8a5cff")
const START := Color("#3fd46a")
const CHECKPOINT := Color("#ffd23f")
const FINISH := Color("#ff4a4a")
const SPAN := Color("#ffffff")

## Roadside sprite kinds, in the order sprite_kind tries them: name, color, id fragments.
## Order matters: "street_lamp" has "tree" in it, so lights come before plants.
const KINDS := [
	["race", Color("#ff6ad5"), ["crowd", "grandstand", "flagman", "camera_tower", "barrier_red", "news_"]],
	["barrier", Color("#ff5a36"), ["barrier", "rail", "fence", "cone", "barricade", "sawhorse", "hazard",
		"drum", "delineator", "tire", "barrels", "_post", "piling"]],
	["light", Color("#fff3a0"), ["lamp", "pole", "traffic_light", "searchlight"]],
	["plant", Color("#4cc35a"), ["palm", "pine", "tree", "oak", "cypress", "saguaro", "prickly", "bush",
		"shrub", "reeds", "cattails", "corn", "sunflower", "hay", "tumbleweed", "pumpkin"]],
	["sign", Color("#ffa630"), ["sign", "billboard", "neon", "arrow", "chevron", "flag", "turn_", "mailbox"]],
	["vehicle", Color("#3fd0ff"), ["truck", "van", "trailer", "boat", "cart", "jeep", "pickup", "tractor",
		"combine", "mixer", "taxi", "limo", "bikes", "trolley", "subway", "double_decker", "airboat",
		"riverboat", "duster", "golf"]],
	["terrain", Color("#b07a4a"), ["rock", "boulder", "butte", "cliff", "snow", "falls", "waterfall",
		"log", "mist", "puddle", "woodpile", "arch"]],
	["building", Color("#8f8cff"), []],  # anything else that stands: casinos, barns, towers...
]

## 3x5 pixel font for labels: each glyph is five rows of three bits.
const FONT := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
	"2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001111",
	"-": "000000111000000", ".": "000000000000010", ":": "000010000010000", "/": "001001010100100",
	"(": "010100100100010", ")": "010001001001010", ",": "000000000010100", " ": "000000000000000",
}


## Heading change per segment for a segment's curve, in radians (see the class notes).
static func heading_step(curve: float) -> float:
	return curve / Cfg.SEGMENT_LENGTH


## The road from above: the point at the start of each segment and one past the last, in
## world units, starting at the origin heading up the screen (negative y). Curve > 0 turns
## right, as it does on screen.
static func plan_points(track: Track) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var heading := 0.0
	var p := Vector2.ZERO
	for seg in track.segments:
		heading += heading_step(seg.curve)
		p += Vector2(sin(heading), -cos(heading)) * Cfg.SEGMENT_LENGTH
		pts.append(p)
	return pts


## The road in side elevation: (distance, height) at the start of each segment and the end
## of the last, in world units.
static func side_points(track: Track) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for seg in track.segments:
		pts.append(Vector2(seg.w1.z, seg.w1.y))
	if not track.segments.is_empty():
		var last: Segment = track.segments[-1]
		pts.append(Vector2(last.w2.z, last.w2.y))
	return pts


## Which kind of roadside thing a sprite id is (a KINDS name), for its color on the plot.
static func sprite_kind(id: String) -> String:
	for kind: Array in KINDS:
		for frag: String in kind[2]:
			if id.contains(frag):
				return kind[0]
	return KINDS[-1][0]


static func kind_color(kind: String) -> Color:
	for k: Array in KINDS:
		if k[0] == kind:
			return k[1]
	return GRID


## Maps `bounds` into `into`, uniformly scaled and centered, y kept as is (flip_y false) or
## turned up the screen (flip_y true, for heights).
static func fit(bounds: Rect2, into: Rect2, flip_y := false) -> Transform2D:
	var size := bounds.size.max(Vector2(1.0, 1.0))
	var s := minf(into.size.x / size.x, into.size.y / size.y)
	var center_in := into.get_center()
	var center_b := bounds.get_center()
	var sy := -s if flip_y else s
	return Transform2D(Vector2(s, 0.0), Vector2(0.0, sy), center_in - Vector2(center_b.x * s, center_b.y * sy))


## Like fit, but x and y scaled separately to fill `into` (the elevation is far longer than
## it is tall), heights up the screen.
static func stretch(bounds: Rect2, into: Rect2) -> Transform2D:
	var size := bounds.size.max(Vector2(1.0, 1.0))
	var sx := into.size.x / size.x
	var sy := -into.size.y / size.y
	return Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), Vector2(into.position.x - bounds.position.x * sx, into.end.y - bounds.position.y * sy))


static func bounds_of(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## The whole sheet for a stage: title, top-down plan with legend, side elevation.
static func render(track: Track, title := "") -> Image:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	img.fill_rect(PLAN, PANEL)
	img.fill_rect(SIDE, PANEL)
	var head := title if title != "" else track.name
	text(img, Vector2i(16, 12), ("%s - %d segments, %d checkpoints, finish at %d" % [head,
		track.segments.size(), track.checkpoints.size(), track.finish_index]).to_upper(), TEXT, 3)
	_draw_plan(img, track)
	_draw_side(img, track)
	_draw_legend(img)
	return img


static func _draw_plan(img: Image, track: Track) -> void:
	var pts := plan_points(track)
	var area := Rect2(PLAN).grow(-40.0)
	area.position.x += 150.0  # leave the legend clear
	area.size.x -= 150.0
	var xf := fit(bounds_of(pts), area)
	var n := track.segments.size()
	for i in n:
		var seg := track.segments[i]
		var a := Vector2i((xf * pts[i]).round())
		var b := Vector2i((xf * pts[i + 1]).round())
		if seg.covered:
			line(img, a, b, COVERED, 7)
		line(img, a, b, ROAD, 2)
	# Roadside sprites: a dot off to their side of the road, farther out for a bigger offset
	for i in n:
		var seg := track.segments[i]
		if seg.sprites.is_empty():
			continue
		var dir := (pts[i + 1] - pts[i]).normalized()
		var normal := Vector2(-dir.y, dir.x)  # left of the direction of travel
		for sp: Dictionary in seg.sprites:
			var off: float = sp["offset"]
			var px := xf * pts[i] - normal * signf(off) * (6.0 + minf(absf(off), 4.0) * 3.0)
			dot(img, Vector2i(px.round()), kind_color(sprite_kind(sp["id"])), 1)
	# Spans across the road, then the race gates over everything
	for i in n:
		var seg := track.segments[i]
		var dir := (pts[i + 1] - pts[i]).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var at := xf * pts[i]
		if not seg.spans.is_empty() and not seg.covered:  # a tunnel's frames show as the tunnel
			line(img, Vector2i((at - normal * 7.0).round()), Vector2i((at + normal * 7.0).round()), SPAN, 1)
		var gate := _gate_color(seg.flags)
		if gate.a > 0.0:
			line(img, Vector2i((at - normal * 12.0).round()), Vector2i((at + normal * 12.0).round()), gate, 3)
			text(img, Vector2i((at + normal * 22.0).round()) - Vector2i(4, 5), gate_label(track, i), gate, 2)
	dot(img, Vector2i((xf * pts[0]).round()), START, 4)  # where the road begins


static func _draw_side(img: Image, track: Track) -> void:
	var pts := side_points(track)
	var b := bounds_of(pts)
	b = b.grow_individual(0.0, b.size.y * 0.1 + 100.0, 0.0, b.size.y * 0.1 + 100.0)
	var area := Rect2(SIDE).grow_individual(-8.0, -20.0, -8.0, -8.0)
	var xf := stretch(b, area)
	# Zero height line
	var zero := int(round((xf * Vector2(0.0, 0.0)).y))
	if zero > area.position.y and zero < area.end.y:
		line(img, Vector2i(int(area.position.x), zero), Vector2i(int(area.end.x), zero), GRID, 1)
	var n := track.segments.size()
	for i in n:
		var seg := track.segments[i]
		var a := Vector2i((xf * pts[i]).round())
		var c := Vector2i((xf * pts[i + 1]).round())
		if seg.covered:
			line(img, a + Vector2i(0, -6), c + Vector2i(0, -6), COVERED, 3)
		line(img, a, c, ROAD, 2)
		if not seg.spans.is_empty() and not seg.covered:
			line(img, a + Vector2i(0, -10), a + Vector2i(0, -3), SPAN, 1)
		var gate := _gate_color(seg.flags)
		if gate.a > 0.0:
			line(img, Vector2i(a.x, int(area.position.y)), Vector2i(a.x, int(area.end.y)), Color(gate, 0.6), 1)
	text(img, Vector2i(SIDE.position.x + 6, SIDE.position.y + 6), "SIDE ELEVATION (HEIGHT EXAGGERATED) %d TO %d" % [
		int(b.position.y), int(b.end.y)], TEXT, 2)


## A race gate's short label on the plot: S, F, or the checkpoint's number.
static func gate_label(track: Track, index: int) -> String:
	var flags := track.segments[index].flags
	if flags & Segment.FLAG_FINISH:
		return "F"
	if flags & Segment.FLAG_CHECKPOINT:
		return str(track.checkpoints.find(index) + 1)
	return "S" if flags & Segment.FLAG_START else ""


static func _gate_color(flags: int) -> Color:
	if flags & Segment.FLAG_FINISH:
		return FINISH
	if flags & Segment.FLAG_CHECKPOINT:
		return CHECKPOINT
	if flags & Segment.FLAG_START:
		return START
	return Color.TRANSPARENT


static func _draw_legend(img: Image) -> void:
	var rows: Array = [["START", START], ["CHECKPOINT", CHECKPOINT], ["FINISH", FINISH], ["SPAN", SPAN],
		["TUNNEL", COVERED]]
	for k: Array in KINDS:
		rows.append([String(k[0]).to_upper(), k[1]])
	var box := Rect2i(LEGEND - Vector2i(6, 6), Vector2i(140, rows.size() * 16 + 10))
	img.fill_rect(box, BG)
	for r in rows.size():
		var at := LEGEND + Vector2i(0, r * 16)
		img.fill_rect(Rect2i(at, Vector2i(12, 10)), rows[r][1])
		text(img, at + Vector2i(18, 0), rows[r][0], TEXT, 2)


## A line `width` pixels thick from a to b.
static func line(img: Image, a: Vector2i, b: Vector2i, col: Color, width := 1) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in steps + 1:
		var t := float(s) / maxf(steps, 1)
		dot(img, Vector2i(Vector2(a).lerp(Vector2(b), t).round()), col, width / 2)


## A square `radius` pixels out from p, blended over what is there, clipped to the image.
static func dot(img: Image, p: Vector2i, col: Color, radius := 0) -> void:
	for y in range(p.y - radius, p.y + radius + 1):
		for x in range(p.x - radius, p.x + radius + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col) if col.a < 1.0 else col)


## Text in the 3x5 FONT, `scale` pixels per font pixel; unknown characters are blanks.
static func text(img: Image, at: Vector2i, s: String, col: Color, scale := 2) -> void:
	var x := at.x
	for ch in s:
		var glyph: String = FONT.get(ch, FONT[" "])
		for row in 5:
			for c in 3:
				if glyph[row * 3 + c] == "1":
					img.fill_rect(Rect2i(x + c * scale, at.y + row * scale, scale, scale), col)
		x += 4 * scale
