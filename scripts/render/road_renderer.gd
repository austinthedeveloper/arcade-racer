class_name RoadRenderer
extends Node2D
## Classic segment-projection road renderer.
##
## Pass 1 walks segments near-to-far, bending the road by accumulated curvature and
## projecting each segment's ends to the screen. Pass 2 paints far-to-near (road band,
## then that segment's sprites and cars), so nearer road and hills cover what's behind them.
## The player's car goes in after its own segment; cars between it and the camera are
## drawn over it.

const GHOST_ALPHA := 0.45  # the Time Attack ghost, see-through...
const GHOST_TINT := Color(0.6, 0.85, 1.0)  # ...and cooled blue

var track: Track
var player: PlayerCar
var player_strips: Dictionary = {}  # the player car's CarSprites.strips
var rivals: Array[RivalCar] = []
var ghost := Vector3.ZERO  # Time Attack's ghost: distance, x, steer (Ghost.at)
var ghost_strips: Dictionary = {}  # its car's strips; empty for no ghost
var camera_z := 0.0
var camera_depth := Cfg.CAMERA_DEPTH  # the race eases it down for the nitro stretch
var flash := 1.0  # the FLASHING option's share of the designed blink (Settings.flash_amount(1.0))
var time := 0.0

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _fog_color := Color.WHITE
var _covered: Dictionary = {}  # _covered_theme: the darkened colors
var _covered_from: Dictionary = {}  # and the theme they were made from
var _font: Font
var _rivals_in: Dictionary = {}  # segment index -> the rivals in it, this frame
var _ghost_seg := -1  # the ghost's segment index this frame, -1 for none
var _rivals_behind: Array = []  # rivals in the player's segment but behind it, this frame


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _draw() -> void:
	if track == null or player == null:
		return
	var theme := track.theme
	_fog_color = theme["fog"]
	var fog_density: float = theme.get("fog_density", Cfg.FOG_DENSITY)
	var segs := track.segments
	var count := segs.size()
	var base := track.find_segment(camera_z)
	var base_percent := fposmod(camera_z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
	var cam_y := player.road_y + Cfg.CAMERA_HEIGHT
	var cam_x := player.x * Cfg.ROAD_WIDTH
	var x := 0.0
	var dx := -base.curve * base_percent
	var max_y := float(Cfg.SCREEN_H)
	var drawn: Array[Segment] = []
	_ghost_seg = -1 if ghost_strips.is_empty() else track.find_segment(ghost_z()).index
	var player_seg := track.find_segment(player.position + Cfg.PLAYER_Z).index
	_rivals_in.clear()
	_rivals_behind.clear()
	for r in rivals:
		var i := track.find_segment(r.position + Cfg.PLAYER_Z).index
		if i == player_seg and behind(r.position, player.position, track.length):
			_rivals_behind.append(r)
			continue
		if not _rivals_in.has(i):
			_rivals_in[i] = []
		_rivals_in[i].append(r)

	for n in Cfg.DRAW_DISTANCE:
		var seg := segs[(base.index + n) % count]
		var cz := camera_z - (track.length if seg.index < base.index else 0.0)
		_project(seg, cam_x - x, cam_x - x - dx, cam_y, cz)
		x += dx
		dx += seg.curve
		var d := float(n) / Cfg.DRAW_DISTANCE
		seg.fog = 1.0 - exp(-d * d * fog_density)
		seg.clip = max_y
		var in_front := seg.cam_z1 > camera_depth
		seg.visible = in_front and seg.s2.y < seg.s1.y and seg.s2.y < max_y
		if seg.visible:
			max_y = minf(max_y, seg.s2.y)
		if in_front:
			drawn.append(seg)

	var at := player_slot(drawn, player_seg)
	for i in range(drawn.size() - 1, -1, -1):
		var seg := drawn[i]
		if seg.visible:
			_draw_segment(seg, theme)
		_draw_objects(seg, i >= at)
		if i == at:
			_draw_player()
	if at < 0:
		_draw_player()
	else:
		# Cars between the player and the camera, over the player's car
		for r: RivalCar in _rivals_behind:
			_draw_rival(drawn[at], r, Color.WHITE.lerp(_fog_color, drawn[at].fog))
		for i in range(at - 1, -1, -1):
			_draw_cars(drawn[i])


## Where in the near-to-far `drawn` list the player's segment is, or -1.
static func player_slot(drawn: Array[Segment], player_seg: int) -> int:
	for i in drawn.size():
		if drawn[i].index == player_seg:
			return i
	return -1


## Whether a car at track position `z` is behind one at `player_z` (both wrapped).
static func behind(z: float, player_z: float, length: float) -> bool:
	return wrapf(z - player_z, -length * 0.5, length * 0.5) < 0.0


func _project(seg: Segment, cx1: float, cx2: float, cam_y: float, cz: float) -> void:
	seg.cam_z1 = seg.w1.z - cz
	seg.cam_z2 = seg.w2.z - cz
	seg.scale1 = camera_depth / maxf(seg.cam_z1, 1.0)
	seg.scale2 = camera_depth / maxf(seg.cam_z2, 1.0)
	var half_w := Cfg.SCREEN_W * 0.5
	seg.s1 = Vector2(half_w - seg.scale1 * cx1 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale1 * (seg.w1.y - cam_y) * Cfg.PROJ)
	seg.s2 = Vector2(half_w - seg.scale2 * cx2 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale2 * (seg.w2.y - cam_y) * Cfg.PROJ)
	seg.sw1 = seg.scale1 * Cfg.ROAD_WIDTH * Cfg.PROJ
	seg.sw2 = seg.scale2 * Cfg.ROAD_WIDTH * Cfg.PROJ


func _draw_segment(seg: Segment, theme: Dictionary) -> void:
	var b := seg.band
	var fog := seg.fog
	if seg.covered:
		theme = _covered_theme(theme)
	var x1 := seg.s1.x
	var y1 := seg.s1.y
	var w1 := seg.sw1
	var x2 := seg.s2.x
	var y2 := seg.s2.y
	var w2 := seg.sw2
	var sw := float(Cfg.SCREEN_W)
	_pts.clear()
	_cols.clear()
	_idx.clear()

	# Ground on each side of the road center
	_quad(Vector2(0, y2), Vector2(x2, y2), Vector2(x1, y1), Vector2(0, y1), _ground(theme, seg.ground_left, b, fog))
	_quad(Vector2(x2, y2), Vector2(sw, y2), Vector2(sw, y1), Vector2(x1, y1), _ground(theme, seg.ground_right, b, fog))

	# Rumble strips
	var r1 := w1 / maxf(6.0, 2.0 * Cfg.LANES)
	var r2 := w2 / maxf(6.0, 2.0 * Cfg.LANES)
	var rumble := _fogged(theme["rumble"][b], fog)
	_quad(Vector2(x1 - w1 - r1, y1), Vector2(x1 - w1, y1), Vector2(x2 - w2, y2), Vector2(x2 - w2 - r2, y2), rumble)
	_quad(Vector2(x1 + w1, y1), Vector2(x1 + w1 + r1, y1), Vector2(x2 + w2 + r2, y2), Vector2(x2 + w2, y2), rumble)

	# Asphalt
	_quad(Vector2(x1 - w1, y1), Vector2(x1 + w1, y1), Vector2(x2 + w2, y2), Vector2(x2 - w2, y2), _fogged(theme["road"][b], fog))

	# Dashed lane markings on alternate bands
	if b == 0:
		var lane_col := _fogged(theme["lane"], fog)
		var l1 := w1 / maxf(32.0, 8.0 * Cfg.LANES)
		var l2 := w2 / maxf(32.0, 8.0 * Cfg.LANES)
		var lane_w1 := w1 * 2.0 / Cfg.LANES
		var lane_w2 := w2 * 2.0 / Cfg.LANES
		var lx1 := x1 - w1 + lane_w1
		var lx2 := x2 - w2 + lane_w2
		for lane in range(1, Cfg.LANES):
			_quad(Vector2(lx1 - l1 / 2.0, y1), Vector2(lx1 + l1 / 2.0, y1), Vector2(lx2 + l2 / 2.0, y2), Vector2(lx2 - l2 / 2.0, y2), lane_col)
			lx1 += lane_w1
			lx2 += lane_w2

	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cols)


## A segment's sprites, pickups and spans, and its cars too when `cars` (the segments
## nearer than the player draw theirs after it, with _draw_cars).
func _draw_objects(seg: Segment, cars := true) -> void:
	var tint := Color.WHITE.lerp(_fog_color, seg.fog)
	for sp in seg.sprites:
		var def: Dictionary = SpriteLibrary.defs.get(sp["id"], {})
		if def.is_empty():
			continue
		var s := seg.scale1
		var w: float = def["world_w"] * s * Cfg.PROJ
		var h: float = def["world_h"] * s * Cfg.PROJ
		var offset: float = sp["offset"]
		var sx := seg.s1.x + s * offset * Cfg.ROAD_WIDTH * Cfg.PROJ
		var rect := sprite_rect(sx, seg.s1.y, w, h, offset, sp["flip"])
		if h < 0.5 or rect.position.x > Cfg.SCREEN_W or rect.position.x + w < 0.0 or rect.position.y >= seg.clip:
			continue
		draw_texture_rect(def["tex"], rect, false, tint)

	for pu: PowerUps.Pickup in seg.pickups:
		if pu.taken:
			continue
		var s := seg.scale1
		var tex := PowerUps.texture(PowerUps.road_sprite(pu.kind, time))
		var h: float = PowerUps.WORLD_H * s * Cfg.PROJ
		var w := h * tex.get_width() / float(tex.get_height())
		var cx: float = seg.s1.x + s * pu.offset * Cfg.ROAD_WIDTH * Cfg.PROJ
		var bob := roundf(sin(time * 4.0 + pu.segment) * h * 0.06)
		if h < 1.0 or seg.s1.y - h >= seg.clip:
			continue
		draw_texture_rect(tex, Rect2(cx - w / 2.0, seg.s1.y - h + bob - h * 0.15, w, h), false, tint)

	if cars:
		_draw_cars(seg)

	# Spans sit at the segment's near end, in front of its sprites and cars
	for id in seg.spans:
		_draw_span(seg, id, "", tint)
	var gate := gate_for(seg.flags)
	if gate != "":
		_draw_span(seg, gate, gate_label(seg.flags), tint)


## A segment's traffic and rivals.
func _draw_cars(seg: Segment) -> void:
	var tint := Color.WHITE.lerp(_fog_color, seg.fog)
	for car in seg.cars:
		var p: float = car.percent
		var s := lerpf(seg.scale1, seg.scale2, p)
		var w: float = Cfg.CAR_WIDTH * car.width_mult * s * Cfg.PROJ
		var cx: float = lerpf(seg.s1.x, seg.s2.x, p) + s * car.offset * Cfg.ROAD_WIDTH * Cfg.PROJ
		var cy := lerpf(seg.s1.y, seg.s2.y, p)
		if w < 1.0 or cy - w >= seg.clip or cx + w < 0.0 or cx - w > Cfg.SCREEN_W:
			continue
		if car.flung > 0.0:
			# Rammed: arcs up and off the road
			cy -= sin((1.0 - car.flung / Traffic.FLING_TIME) * PI) * w * 0.9
		CarSprites.draw_traffic(self, Vector2(cx, cy), w, car.sprite, tint, seg.fog)

	for r: RivalCar in _rivals_in.get(seg.index, []):
		_draw_rival(seg, r, tint)
	if seg.index == _ghost_seg:
		_draw_ghost(seg)


## The race gate drawn for a segment's flags, or "" for none.
static func gate_for(flags: int) -> String:
	if flags & Segment.FLAG_FINISH:
		return "finish_gantry"
	if flags & Segment.FLAG_CHECKPOINT:
		return "checkpoint_gate"
	if flags & Segment.FLAG_START:
		return "start_gantry"
	return ""


static func gate_label(flags: int) -> String:
	if flags & Segment.FLAG_CHECKPOINT:
		return "CHECKPOINT"
	if flags & Segment.FLAG_START and not flags & Segment.FLAG_FINISH:
		return "START"
	return ""


## Screen rect of a span whose opening is centered on the road at (road_x, base_y), the
## road `road_w` half-width on screen there.
static func span_rect(def: Dictionary, road_x: float, base_y: float, road_w: float) -> Rect2:
	var w: float = def["world_w"] / Cfg.ROAD_WIDTH * road_w
	var h: float = w * def["world_h"] / def["world_w"]
	var o: Vector2 = def["opening"]
	return Rect2(road_x - w * (o.x + o.y) / 2.0, base_y - h, w, h)


func _draw_span(seg: Segment, id: String, label: String, tint: Color) -> void:
	var def: Dictionary = SpriteLibrary.spans.get(id, {})
	if def.is_empty():
		return
	var rect := span_rect(def, seg.s1.x, seg.s1.y, seg.sw1)
	if rect.size.y < 1.0 or rect.position.y >= seg.clip or rect.end.x < 0.0 or rect.position.x > Cfg.SCREEN_W:
		return
	var fill: Color = def["fill"]
	if fill.a > 0.0:
		var col := fill.lerp(_fog_color, seg.fog)
		var top := 0.0 if def["ceiling"] else rect.position.y
		draw_rect(Rect2(-8.0, top, rect.position.x + 9.0, rect.end.y - top), col)
		draw_rect(Rect2(rect.end.x - 1.0, top, Cfg.SCREEN_W - rect.end.x + 9.0, rect.end.y - top), col)
		if def["ceiling"]:
			draw_rect(Rect2(rect.position.x, top, rect.size.x, rect.position.y - top + 1.0), col)
	draw_texture_rect(def["tex"], rect, false, tint)
	var banner: Rect2 = def["banner"]
	if label == "" or banner.size.x <= 0.0:
		return
	var box := Rect2(rect.position + banner.position * rect.size, banner.size * rect.size)
	var font_size := mini(int(box.size.y * 0.7), 96)
	if font_size >= 6:
		draw_string(_font, Vector2(box.position.x, box.position.y + box.size.y * 0.78), label,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, font_size, Color("#c8102e") * tint)


## Screen rect for a roadside sprite whose road-side edge is at sx: left-side sprites end at
## sx, right-side ones start there. A flipped sprite gets a negative width, which mirrors the
## texture within the same rect.
static func sprite_rect(sx: float, base_y: float, w: float, h: float, offset: float, flip: bool) -> Rect2:
	var x0 := sx - w if offset < 0.0 else sx
	return Rect2(x0, base_y - h, -w if flip else w, h)


## A rival in its segment, drawn with its car's steering strip like the player's.
func _draw_rival(seg: Segment, r: RivalCar, tint: Color) -> void:
	var p := fposmod(r.position + Cfg.PLAYER_Z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
	var s := lerpf(seg.scale1, seg.scale2, p)
	var w := Cfg.CAR_WIDTH * s * Cfg.PROJ
	var cx := lerpf(seg.s1.x, seg.s2.x, p) + s * r.x * Cfg.ROAD_WIDTH * Cfg.PROJ
	var cy := lerpf(seg.s1.y, seg.s2.y, p)
	if w < 1.0 or cy - w >= seg.clip or cx + w < 0.0 or cx - w > Cfg.SCREEN_W:
		return
	var steer := r.steer
	var lift := r.air_height * s * Cfg.PROJ
	if r.crash_time > 0.0:
		steer = sin(r.crash_time * 20.0) * 2.0
		lift += sin(r.crash_time / Cfg.CRASH_DURATION * PI) * w * 0.3
	CarSprites.draw_player(self, r.strips, Vector2(roundf(cx), roundf(cy)), w, steer, r.braking,
		roundf(lift), r.pitch, 1.0, tint)


## Where the ghost is on the track (its distance from the start line, wrapped).
func ghost_z() -> float:
	return fposmod(ghost.x + Cfg.PLAYER_Z, track.length)


## The Time Attack ghost: the player's car, see-through and cooled blue.
func _draw_ghost(seg: Segment) -> void:
	var p := fposmod(ghost_z(), Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
	var s := lerpf(seg.scale1, seg.scale2, p)
	var w := Cfg.CAR_WIDTH * s * Cfg.PROJ
	var cx := lerpf(seg.s1.x, seg.s2.x, p) + s * ghost.y * Cfg.ROAD_WIDTH * Cfg.PROJ
	var cy := lerpf(seg.s1.y, seg.s2.y, p)
	if w < 1.0 or cy - w >= seg.clip or cx + w < 0.0 or cx - w > Cfg.SCREEN_W:
		return
	CarSprites.draw_player(self, ghost_strips, Vector2(roundf(cx), roundf(cy)), w, ghost.z, false,
		0.0, 0.0, GHOST_ALPHA, GHOST_TINT)


func _draw_player() -> void:
	var p := player
	var s := camera_depth / Cfg.PLAYER_Z
	var w := Cfg.CAR_WIDTH * s * Cfg.PROJ
	var y := Cfg.HORIZON_Y + s * Cfg.CAMERA_HEIGHT * Cfg.PROJ
	var lift := p.air_height * s * Cfg.PROJ
	var steer := p.steer
	if p.crash_time > 0.0:
		var k := p.crash_time / Cfg.CRASH_DURATION
		steer = sin(p.crash_time * 20.0) * 2.0
		lift += sin(k * PI) * w * 0.3
	elif p.speed > 50.0 and not p.airborne:
		y += roundf(randf_range(-1.0, 1.0) * (1.5 if p.offroad else 0.4) * p.speed / Cfg.MAX_SPEED)
	# A ghost flickers see-through, brighter as it runs out
	var alpha := 1.0
	if p.ghost_time > 0.0:
		alpha = ghost_alpha(p.ghost_time, time, flash)
	CarSprites.draw_player(self, player_strips, Vector2(Cfg.SCREEN_W * 0.5, roundf(y)), w, steer, p.braking,
		roundf(lift), p.pitch, alpha)


## The ghosted player's see-through alpha: it blinks brighter in its last second, by as much
## as the FLASHING option allows (`flash`, 0..1; steady at 0).
static func ghost_alpha(ghost_time: float, t: float, flash_share: float) -> float:
	var blink := ghost_time < 1.0 and int(t * 10.0) % 2 == 0
	return 0.45 + (0.35 * flash_share if blink else 0.0)


## A stage's road colors, darkened for inside a tunnel or covered bridge (worked out once
## per stage; the stage's theme is left alone).
func _covered_theme(theme: Dictionary) -> Dictionary:
	if not is_same(theme, _covered_from):
		_covered = {}
		for key in ["grass", "sand", "rumble", "road"]:
			_covered[key] = [theme[key][0].darkened(0.45), theme[key][1].darkened(0.5)]
		_covered["lane"] = theme["lane"].darkened(0.3)
		_covered_from = theme
	return _covered


func _ground(theme: Dictionary, kind: int, b: int, fog: float) -> Color:
	var key := "sand" if kind == Track.GROUND_SAND else "grass"
	return _fogged(theme[key][b], fog)


func _fogged(c: Color, fog: float) -> Color:
	return c.lerp(_fog_color, fog)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i := _pts.size()
	_pts.append_array([a, b, c, d])
	_cols.append_array([col, col, col, col])
	_idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3])
