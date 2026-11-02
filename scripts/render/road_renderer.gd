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

## Tunnel interiors: COVERED_RAMP more darkening deep inside than at a mouth, in COVERED_STEPS
## steps; neon tubes (theme "tunnel_lights") TUBE_OFFSET road half-widths out, on the frames'
## inner walls, TUBE_HEIGHT up and TUBE_THICK tall, broken every TUBE_EVERY segments.
const COVERED_RAMP := 0.3
const COVERED_STEPS := 8
const TUBE_OFFSET := 1.34
const TUBE_HEIGHT := 1250.0
const TUBE_THICK := 70.0
const TUBE_EVERY := 4

## The background strips the wet road reflects (WS-13), back to front.
const REFLECT_LAYERS := ["sky", "far"]
const REFLECT_MIN := 0.02  # fainter than this, a reflection isn't drawn

const BEHIND_SEGMENTS := 1  # segments behind the player whose cars are drawn (over it)
const THIN_RUN := 1.0  # pixels: far segments thinner than this together are drawn as one band (EQ-7)

var track: Track
## The Background, whose strips the wet road reflects (WS-13). Untyped on purpose: Background
## reads the Settings autoload, which a script run with -s (the test runner) can't see yet
## when this file compiles.
var background: Node2D
var player: PlayerCar
var player_strips: Dictionary = {}  # the player car's CarSprites.strips
var rivals: Array[RivalCar] = []
var ghost := Vector3.ZERO  # Time Attack's ghost: distance, x, steer (Ghost.at)
var ghost_strips: Dictionary = {}  # its car's strips; empty for no ghost
var camera_z := 0.0
var view: int = CameraView.View.CHASE_NEAR  # the camera view (WS-15): where camera_z and the car sit
var camera_depth := Tuning.v("camera/depth")  # the race eases it down for the nitro stretch
var flash := 1.0  # the FLASHING option's share of the designed blink (Settings.flash_amount(1.0))
var time := 0.0
## Stage flow (StageFlow): the end of the stage drawn in the next stage's palette. Off for Free
## Drive, whose road loops straight back to its own start.
var flow := true
var flow_share := 0.0  # the share of the next stage's palette where the camera is (sky and fog)
var flow_fade := 0.0  # the results' crossfade (StageFlow.crossfade): every segment that far on to all of it

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _fog_color := Color.WHITE
var _wet := 0.0  # the stage's wet road (Weather "wet"), this frame
var _wet_sky := Color.WHITE  # and the sky it reflects
var _horizon := float(Cfg.HORIZON_Y)  # the background's horizon row this frame (reflections mirror on it)
var _reflect: Array = []  # [texture, layer rect] per background strip the wet road reflects, this frame
var _covered: Array[Dictionary] = []  # _covered_theme: the darkened colors, per depth step
var _covered_from: Dictionary = {}  # and the theme they were made from
var _font: Font
var _rivals_in: Dictionary = {}  # segment index -> the rivals in it, this frame
var _ghost_seg := -1  # the ghost's segment index this frame, -1 for none
var _rivals_behind: Array = []  # rivals in the player's segment but behind it, this frame


func _ready() -> void:
	_font = ThemeDB.fallback_font
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the reflections run on round the strips


func _draw() -> void:
	if track == null or player == null:
		return
	var theme := track.theme
	var here := StageFlow.palette(track, flow_share) if flow else theme
	_fog_color = here["fog"]
	var fog_density: float = here.get("fog_density", Cfg.FOG_DENSITY)
	_wet = Weather.of(theme).get("wet", 0.0)
	_wet_sky = here.get("sky_bottom", _fog_color)
	_reflect = reflect_layers(background) if _wet > 0.0 else []
	_horizon = Cfg.HORIZON_Y + (float(background.get("hill")) if background != null else 0.0)
	var segs := track.segments
	var count := segs.size()
	var base := track.find_segment(camera_z)
	var base_percent := fposmod(camera_z, Cfg.SEGMENT_LENGTH) / Cfg.SEGMENT_LENGTH
	var cam_y := player.road_y + CameraView.height(view)
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

	var reach := draw_distance(theme)
	for n in reach:
		var seg := segs[(base.index + n) % count]
		var wrapped := seg.index < base.index
		var cz := camera_z - (track.length if wrapped else 0.0)
		seg.shade = segment_shade(seg.handover, flow_fade, wrapped) if flow else 0.0
		_project(seg, cam_x - x, cam_x - x - dx, cam_y, cz)
		x += dx
		dx += seg.curve
		var d := float(n) / reach
		seg.fog = 1.0 - exp(-d * d * fog_density)
		seg.clip = max_y
		var in_front := seg.cam_z1 > camera_depth
		seg.visible = in_front and seg.s2.y < seg.s1.y and seg.s2.y < max_y
		if seg.visible:
			max_y = minf(max_y, seg.s2.y)
		if in_front:
			drawn.append(seg)

	var at := player_slot(drawn, player_seg)
	# Far off, a segment is a sliver of a pixel: a run of them with nothing standing on them
	# is drawn as one band, from the run's far edge to its nearest segment (thin_run). The
	# next segment is visible whenever one is held back, so it always gets drawn.
	var run_far: Segment = null  # the farthest segment of the run not drawn yet
	for i in range(drawn.size() - 1, -1, -1):
		var seg := drawn[i]
		if seg.visible:
			var far := seg if run_far == null else run_far
			if i > 0 and drawn[i - 1].visible and thin_run(far, seg) and not _stands_on(seg, i == at):
				run_far = far
			else:
				_draw_segment(seg, StageFlow.palette(track, seg.shade), far, float(i) / reach)
				run_far = null
		_draw_objects(seg, i >= at)
		if i == at:
			_draw_player()
	if at < 0:
		_draw_player()
	elif CameraView.car_shown(view):
		# Cars just behind the player, over the player's car; nearer the camera than that
		# they would fill the screen, so they aren't drawn (from the bumper, they're behind it)
		for r: RivalCar in _rivals_behind:
			_draw_rival(drawn[at], r, Color.WHITE.lerp(_fog_color, drawn[at].fog))
		for i in range(at - 1, behind_from(at, CameraView.behind_segments(view, BEHIND_SEGMENTS)) - 1, -1):
			_draw_cars(drawn[i])


## The share of the next stage's palette a segment is drawn in: its own (Segment.handover),
## faded `fade` of the rest of the way by the results, and all of it past the end of the
## stage (`wrapped`: the road looped round to the start, which stands in for the next stage).
static func segment_shade(handover: float, fade: float, wrapped: bool) -> float:
	return 1.0 if wrapped else lerpf(handover, 1.0, fade)


## Segments drawn ahead of the camera on a stage: its theme's "draw_distance" (a busy stage
## can trade horizon for frame time, EQ-7), else Cfg.DRAW_DISTANCE. Display only: fog
## thickens to match, and nothing in play reads it.
static func draw_distance(theme: Dictionary) -> int:
	return int(theme.get("draw_distance", Cfg.DRAW_DISTANCE))


## Whether the road from `far`'s far edge to `near`'s near edge is under THIN_RUN pixels
## tall, so it can be drawn as one band.
static func thin_run(far: Segment, near: Segment) -> bool:
	return near.s1.y - far.s2.y < THIN_RUN


## Whether anything is drawn on a segment after its road (sprites, pickups, cars, spans, a
## gate, tunnel walls, the player), so its road can't wait to be drawn with a nearer one.
func _stands_on(seg: Segment, player_here: bool) -> bool:
	return player_here or seg.covered or not seg.sprites.is_empty() or not seg.pickups.is_empty() \
		or not seg.cars.is_empty() or not seg.spans.is_empty() or gate_for(seg.flags) != "" \
		or _rivals_in.has(seg.index) or seg.index == _ghost_seg


## The nearest slot in `drawn` whose cars are still drawn when the player is at slot `at`:
## `behind` (BEHIND_SEGMENTS; more from further back, CameraView.behind_segments) at most.
static func behind_from(at: int, behind := BEHIND_SEGMENTS) -> int:
	return maxi(0, at - behind)


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
	project(seg, cx1, cx2, cam_y, cz, camera_depth)


## Projects a segment's ends onto the screen for a camera at track position `cz`, `cam_y` up,
## `cx1` and `cx2` across from each end's road center (world units), with camera `depth`.
static func project(seg: Segment, cx1: float, cx2: float, cam_y: float, cz: float, depth: float) -> void:
	seg.cam_z1 = seg.w1.z - cz
	seg.cam_z2 = seg.w2.z - cz
	seg.scale1 = depth / maxf(seg.cam_z1, 1.0)
	seg.scale2 = depth / maxf(seg.cam_z2, 1.0)
	var half_w := Cfg.SCREEN_W * 0.5
	seg.s1 = Vector2(half_w - seg.scale1 * cx1 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale1 * (seg.w1.y - cam_y) * Cfg.PROJ)
	seg.s2 = Vector2(half_w - seg.scale2 * cx2 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale2 * (seg.w2.y - cam_y) * Cfg.PROJ)
	seg.sw1 = seg.scale1 * Cfg.ROAD_WIDTH * seg.width * Cfg.PROJ
	seg.sw2 = seg.scale2 * Cfg.ROAD_WIDTH * seg.width_far * Cfg.PROJ


## A segment's road and ground in its colors, from its near edge to `far`'s far edge (itself,
## or the far end of a thin run of segments behind it). `depth`: how far off it is, 0 (the
## camera) to 1 (the draw distance).
func _draw_segment(seg: Segment, theme: Dictionary, far: Segment, depth: float) -> void:
	var b := seg.band
	var fog := seg.fog
	var lights: Array = theme.get("tunnel_lights", []) if seg.covered else []
	if seg.covered:
		theme = _covered_theme(theme, seg.depth)
	var x1 := seg.s1.x
	var y1 := seg.s1.y
	var w1 := seg.sw1
	var x2 := far.s2.x
	var y2 := far.s2.y
	var w2 := far.sw2
	var sw := float(Cfg.SCREEN_W)
	_pts.clear()
	_cols.clear()
	_idx.clear()

	# Ground on each side of the road center (one band when both sides match: the road
	# covers the middle)
	var left := _ground(theme, seg.ground_left, b, fog)
	if seg.ground_left == seg.ground_right:
		_quad(Vector2(0, y2), Vector2(sw, y2), Vector2(sw, y1), Vector2(0, y1), left)
	else:
		_quad(Vector2(0, y2), Vector2(x2, y2), Vector2(x1, y1), Vector2(0, y1), left)
		_quad(Vector2(x2, y2), Vector2(sw, y2), Vector2(sw, y1), Vector2(x1, y1), _ground(theme, seg.ground_right, b, fog))

	# Rumble strips, as wide on any road (sizes from the usual road's half-width, u1 and u2)
	var u1 := w1 / seg.width
	var u2 := w2 / far.width_far
	var r1 := u1 / maxf(6.0, 2.0 * Cfg.LANES)
	var r2 := u2 / maxf(6.0, 2.0 * Cfg.LANES)
	var rumble := _fogged(theme["rumble"][b], fog)
	_quad(Vector2(x1 - w1 - r1, y1), Vector2(x1 - w1, y1), Vector2(x2 - w2, y2), Vector2(x2 - w2 - r2, y2), rumble)
	_quad(Vector2(x1 + w1, y1), Vector2(x1 + w1 + r1, y1), Vector2(x2 + w2 + r2, y2), Vector2(x2 + w2, y2), rumble)

	# Asphalt, catching the sky when it's wet (not under cover), with puddles on the near road
	# (WS-13)
	var asphalt: Color = theme["road"][b]
	var wet := _wet > 0.0 and not seg.covered
	if wet:
		asphalt = Weather.wet_color(asphalt, _wet_sky, _wet, depth, Tuning.v("world/wet_sheen"), Tuning.v("world/wet_gloss"))
	var road_pts := PackedVector2Array([Vector2(x1 - w1, y1), Vector2(x1 + w1, y1), Vector2(x2 + w2, y2), Vector2(x2 - w2, y2)])
	_quad_pts(road_pts, _fogged(asphalt, fog))
	var ahead := depth * draw_distance(track.theme)  # segments from the camera
	if wet and is_same(far, seg) and ahead < Tuning.v("world/puddle_reach"):
		_puddle(seg, theme["road"][b])

	# Dashed lane markings on alternate bands, this segment's lanes
	if b == 0:
		var lane_col := _fogged(theme["lane"], fog)
		var l1 := u1 / maxf(32.0, 8.0 * Cfg.LANES)
		var l2 := u2 / maxf(32.0, 8.0 * Cfg.LANES)
		var lane_w1 := w1 * 2.0 / seg.lanes
		var lane_w2 := w2 * 2.0 / seg.lanes
		var lx1 := x1 - w1 + lane_w1
		var lx2 := x2 - w2 + lane_w2
		for lane in range(1, seg.lanes):
			_quad(Vector2(lx1 - l1 / 2.0, y1), Vector2(lx1 + l1 / 2.0, y1), Vector2(lx2 + l2 / 2.0, y2), Vector2(lx2 - l2 / 2.0, y2), lane_col)
			lx1 += lane_w1
			lx2 += lane_w2

	if not lights.is_empty() and seg.index % TUBE_EVERY != TUBE_EVERY - 1:
		_tunnel_lights(seg, lights)

	_flush()
	# The sky and the skyline reflected over it all, lane markings too (they shine wet as well);
	# only so far off, where the fog hasn't swallowed them, as each one is another draw (WS-13)
	if wet and ahead < Tuning.v("world/reflect_reach"):
		_reflections(road_pts, Weather.reflect_strength(Tuning.v("world/reflect_alpha"), _wet, depth, fog))


## Draws the triangles gathered so far and starts afresh.
func _flush() -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cols)
	_pts.clear()
	_cols.clear()
	_idx.clear()


## The background strips the wet road reflects (REFLECT_LAYERS), as [texture, screen rect]
## pairs, for the ones this stage has; none without a background.
static func reflect_layers(bg: Node2D) -> Array:
	var out: Array = []
	if bg == null:
		return out
	for layer: String in REFLECT_LAYERS:
		var rect: Rect2 = bg.call("layer_rect", layer)
		if rect.has_area():
			out.append([bg.get("textures")[layer], rect])
	return out


## The reflections on a stretch of wet road (its four corners, `pts`) at `alpha`.
func _reflections(pts: PackedVector2Array, alpha: float) -> void:
	if _reflect.is_empty() or alpha < REFLECT_MIN:
		return
	var mirrored: bool = background.get("mirrored")
	var stretch := Tuning.v("world/reflect_stretch")
	var c := Color(1, 1, 1, alpha)
	var cols := PackedColorArray([c, c, c, c])
	for r: Array in _reflect:
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(Weather.reflect_uv(p, _horizon, r[1], stretch, mirrored))
		draw_primitive(pts, cols, uvs, r[0])


## A puddle on a near segment (Weather.puddle), if it has one: a dark wet patch with the sky's
## highlight in it, across the road by Track.side like anything placed on it.
func _puddle(seg: Segment, road: Color) -> void:
	var p := Weather.puddle(seg.index, Tuning.v("world/puddle_share"))
	if p == Vector4.ZERO:
		return
	var center := p.x * track.side() * seg.width
	var half := p.y * seg.width
	_quad_pts(road_patch(seg, center - half, center + half, p.z, p.w), _fogged(road.darkened(0.4), seg.fog))
	var glint := Weather.puddle_color(_wet_sky, Tuning.v("world/puddle_glint"), seg.fog, time, seg.index)
	_quad_pts(road_patch(seg, center - half * 0.6, center + half * 0.6, lerpf(p.z, p.w, 0.3), lerpf(p.z, p.w, 0.6)), glint)


## A patch of a segment's road on screen: from `left` to `right` across it (road half-widths of
## the usual road from its center, as a car's offset) and from `near` to `far` along it
## (0..1): near left, near right, far right, far left.
static func road_patch(seg: Segment, left: float, right: float, near: float, far: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for at: Array in [[near, left], [near, right], [far, right], [far, left]]:
		var k: float = at[0]
		var s := lerpf(seg.scale1, seg.scale2, k)
		out.append(Vector2(lerpf(seg.s1.x, seg.s2.x, k) + s * float(at[1]) * Cfg.ROAD_WIDTH * Cfg.PROJ, lerpf(seg.s1.y, seg.s2.y, k)))
	return out


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
		var sx := seg.s1.x + s * offset * seg.width * Cfg.ROAD_WIDTH * Cfg.PROJ
		var rect := pixel_sprite_rect(sx, seg.s1.y, w, h, offset, sp["flip"])
		if h < 0.5 or rect.position.x > Cfg.SCREEN_W or rect.position.x + w < 0.0 or rect.position.y >= seg.clip:
			continue
		draw_texture_rect(SpriteLibrary.texture_for(def, h), rect, false, tint)  # (CP-9: LOD)

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

	# Spans sit at the segment's near end, in front of its sprites and cars; a tunnel's
	# frames dim with depth like its road
	for id in seg.spans:
		_draw_span(seg, id, "", tint.darkened(COVERED_RAMP * seg.depth))
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
			cy -= sin((1.0 - car.flung / Tuning.v("traffic/fling_time")) * PI) * w * 0.9
		CarSprites.draw_traffic(self, Vector2(cx, cy), w, car.sprite, tint, seg.fog, car.oncoming, Traffic.light_state(car))

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
## road `road_w` half-width on screen there. `mirrored` (a mirrored stage, WS-6): for the art
## drawn flipped, its opening mirrored too.
static func span_rect(def: Dictionary, road_x: float, base_y: float, road_w: float, mirrored := false) -> Rect2:
	var w: float = def["world_w"] / Cfg.ROAD_WIDTH * road_w
	var h: float = w * def["world_h"] / def["world_w"]
	var o: Vector2 = def["opening"]
	var center := (o.x + o.y) / 2.0
	if mirrored:
		center = 1.0 - center
	return Rect2(road_x - w * center, base_y - h, w, h)


## Where a span's gate text goes (its "banner", fractions of the sprite) in its screen
## `rect`; on a mirrored stage the art is flipped, the text not, so the box moves over.
static func banner_box(rect: Rect2, banner: Rect2, mirrored: bool) -> Rect2:
	var x := 1.0 - banner.end.x if mirrored else banner.position.x
	return Rect2(rect.position + Vector2(x, banner.position.y) * rect.size, banner.size * rect.size)


func _draw_span(seg: Segment, id: String, label: String, tint: Color) -> void:
	var def: Dictionary = SpriteLibrary.spans.get(id, {})
	if def.is_empty():
		return
	var mirrored := track.mirrored
	var rect := span_rect(def, seg.s1.x, seg.s1.y, seg.sw1 / seg.width * SpriteLibrary.span_scale(seg.width), mirrored)
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
	# Mirrored, a negative width flips the art within the same rect (as sprite_rect)
	draw_texture_rect(def["tex"], Rect2(rect.position, Vector2(-rect.size.x, rect.size.y)) if mirrored else rect, false, tint)
	var banner: Rect2 = def["banner"]
	if label == "" or banner.size.x <= 0.0:
		return
	var box := banner_box(rect, banner, mirrored)
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


## sprite_rect on the screen's pixel grid (CP-9): its edges rounded to whole pixels, so a
## sprite never starts partway into a pixel and every one is sampled on the same grid. A
## mirrored sprite (negative width, the same area) stays mirrored. At least a pixel each way.
static func pixel_sprite_rect(sx: float, base_y: float, w: float, h: float, offset: float, flip: bool) -> Rect2:
	var left := sx - w if offset < 0.0 else sx
	var x0 := roundf(left)
	var y0 := roundf(base_y - h)
	var pw := maxf(1.0, roundf(left + w) - x0)
	return Rect2(x0, y0, -pw if flip else pw, maxf(1.0, roundf(base_y) - y0))


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
		lift += sin(r.crash_time / r.crash_length * PI) * w * 0.3
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
	if not CameraView.car_shown(view):
		return
	var p := player
	var s := camera_depth / CameraView.distance(view)
	var w := CameraView.car_width(view, camera_depth)
	var y := CameraView.car_base(view, camera_depth).y
	var lift := p.air_height * s * Cfg.PROJ
	var steer := p.shown_steer()
	if p.crash_time > 0.0:
		var k := p.crash_time / p.crash_length
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


## A stage's road colors darkened for `depth` into a tunnel or covered bridge (worked out
## once per stage, in COVERED_STEPS steps; the stage's theme is left alone).
func _covered_theme(theme: Dictionary, depth: float) -> Dictionary:
	if not is_same(theme, _covered_from):
		_covered.clear()
		for step in COVERED_STEPS + 1:
			_covered.append(covered_colors(theme, float(step) / COVERED_STEPS))
		_covered_from = theme
	return _covered[roundi(clampf(depth, 0.0, 1.0) * COVERED_STEPS)]


## The road colors inside a tunnel: darkened at the mouth, darker still at `depth` 1.
static func covered_colors(theme: Dictionary, depth: float) -> Dictionary:
	var extra := COVERED_RAMP * depth
	var out := {}
	for key in ["grass", "sand", "rumble", "road"]:
		out[key] = [theme[key][0].darkened(0.45 + extra), theme[key][1].darkened(0.5 + extra)]
	out["lane"] = theme["lane"].darkened(0.3 + extra)
	return out


## Neon tubes down a tunnel's walls, one color each side, with a glow around each and a
## thin line along the foot of the wall. Drawn with the segment, so nearer frames cover them.
func _tunnel_lights(seg: Segment, lights: Array) -> void:
	for k in 2:
		var side := (-1.0 if k == 0 else 1.0) * track.side()  # each color on its own wall, mirrored too
		var col: Color = _fogged(lights[k], seg.fog)
		var glow := Color(col, 0.35)
		_quad_pts(wall_strip(seg, side * TUBE_OFFSET, TUBE_HEIGHT - TUBE_THICK, TUBE_THICK * 3.0), glow)
		_quad_pts(wall_strip(seg, side * TUBE_OFFSET, TUBE_HEIGHT, TUBE_THICK), col)
		_quad_pts(wall_strip(seg, side * TUBE_OFFSET, TUBE_HEIGHT - TUBE_THICK * 0.35, TUBE_THICK * 0.3), col.lightened(0.6))
		_quad_pts(wall_strip(seg, side * TUBE_OFFSET * 0.97, 0.0, TUBE_THICK * 0.5), Color(col, 0.7))


## A strip along a segment `offset` road half-widths from the center, its bottom `height`
## above the road and `thick` tall (world units): near bottom, far bottom, far top, near top.
## At least a pixel tall on screen.
static func wall_strip(seg: Segment, offset: float, height: float, thick: float) -> PackedVector2Array:
	var y1 := seg.s1.y - seg.scale1 * height * Cfg.PROJ
	var y2 := seg.s2.y - seg.scale2 * height * Cfg.PROJ
	var t1 := maxf(1.0, seg.scale1 * thick * Cfg.PROJ)
	var t2 := maxf(1.0, seg.scale2 * thick * Cfg.PROJ)
	var x1 := seg.s1.x + offset * seg.sw1
	var x2 := seg.s2.x + offset * seg.sw2
	return PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2), Vector2(x2, y2 - t2), Vector2(x1, y1 - t1)])


func _ground(theme: Dictionary, kind: int, b: int, fog: float) -> Color:
	var key := "sand" if kind == Track.GROUND_SAND else "grass"
	return _fogged(theme[key][b], fog)


func _fogged(c: Color, fog: float) -> Color:
	return c.lerp(_fog_color, fog)


func _quad_pts(p: PackedVector2Array, col: Color) -> void:
	_quad(p[0], p[1], p[2], p[3], col)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i := _pts.size()
	_pts.append_array([a, b, c, d])
	_cols.append_array([col, col, col, col])
	_idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3])
