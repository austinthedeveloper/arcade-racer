class_name RoadRenderer
extends Node2D
## Classic segment-projection road renderer.
##
## Pass 1 walks segments near-to-far, bending the road by accumulated curvature and
## projecting each segment's ends to the screen. Pass 2 paints far-to-near (road band,
## then that segment's sprites and cars), so nearer road and hills cover what's behind them.

var track: Track
var player: PlayerCar
var camera_z := 0.0
var time := 0.0

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _fog_color := Color.WHITE
var _font: Font


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

	for n in Cfg.DRAW_DISTANCE:
		var seg := segs[(base.index + n) % count]
		var cz := camera_z - (track.length if seg.index < base.index else 0.0)
		_project(seg, cam_x - x, cam_x - x - dx, cam_y, cz)
		x += dx
		dx += seg.curve
		var d := float(n) / Cfg.DRAW_DISTANCE
		seg.fog = 1.0 - exp(-d * d * fog_density)
		seg.clip = max_y
		var in_front := seg.cam_z1 > Cfg.CAMERA_DEPTH
		seg.visible = in_front and seg.s2.y < seg.s1.y and seg.s2.y < max_y
		if seg.visible:
			max_y = minf(max_y, seg.s2.y)
		if in_front:
			drawn.append(seg)

	for i in range(drawn.size() - 1, -1, -1):
		var seg := drawn[i]
		if seg.visible:
			_draw_segment(seg, theme)
		_draw_objects(seg)
	_draw_player()


func _project(seg: Segment, cx1: float, cx2: float, cam_y: float, cz: float) -> void:
	seg.cam_z1 = seg.w1.z - cz
	seg.cam_z2 = seg.w2.z - cz
	seg.scale1 = Cfg.CAMERA_DEPTH / maxf(seg.cam_z1, 1.0)
	seg.scale2 = Cfg.CAMERA_DEPTH / maxf(seg.cam_z2, 1.0)
	var half_w := Cfg.SCREEN_W * 0.5
	seg.s1 = Vector2(half_w - seg.scale1 * cx1 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale1 * (seg.w1.y - cam_y) * Cfg.PROJ)
	seg.s2 = Vector2(half_w - seg.scale2 * cx2 * Cfg.PROJ, Cfg.HORIZON_Y - seg.scale2 * (seg.w2.y - cam_y) * Cfg.PROJ)
	seg.sw1 = seg.scale1 * Cfg.ROAD_WIDTH * Cfg.PROJ
	seg.sw2 = seg.scale2 * Cfg.ROAD_WIDTH * Cfg.PROJ


func _draw_segment(seg: Segment, theme: Dictionary) -> void:
	var b := seg.band
	var fog := seg.fog
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


func _draw_objects(seg: Segment) -> void:
	var tint := Color.WHITE.lerp(_fog_color, seg.fog)
	if seg.flags != 0:
		_draw_gantry(seg, tint)

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

	for car in seg.cars:
		var p: float = car.percent
		var s := lerpf(seg.scale1, seg.scale2, p)
		var w: float = Cfg.CAR_WIDTH * car.width_mult * s * Cfg.PROJ
		var cx: float = lerpf(seg.s1.x, seg.s2.x, p) + s * car.offset * Cfg.ROAD_WIDTH * Cfg.PROJ
		var cy := lerpf(seg.s1.y, seg.s2.y, p)
		if w < 1.0 or cy - w >= seg.clip or cx + w < 0.0 or cx - w > Cfg.SCREEN_W:
			continue
		CarSprites.draw_traffic(self, Vector2(cx, cy), w, car.sprite, tint, seg.fog)


## Screen rect for a roadside sprite whose road-side edge is at sx: left-side sprites end at
## sx, right-side ones start there. A flipped sprite gets a negative width, which mirrors the
## texture within the same rect.
static func sprite_rect(sx: float, base_y: float, w: float, h: float, offset: float, flip: bool) -> Rect2:
	var x0 := sx - w if offset < 0.0 else sx
	return Rect2(x0, base_y - h, -w if flip else w, h)


func _draw_gantry(seg: Segment, tint: Color) -> void:
	var s := seg.scale1
	var x := seg.s1.x
	var y := seg.s1.y
	var half := seg.sw1 * 1.25
	var post_w := maxf(1.0, 150.0 * s * Cfg.PROJ)
	var height := 3200.0 * s * Cfg.PROJ
	var banner_h := height * 0.2
	if y - height >= seg.clip or height < 2.0:
		return
	var post := Color("#d9dbe6") * tint
	draw_rect(Rect2(x - half - post_w, y - height, post_w, height), post)
	draw_rect(Rect2(x + half, y - height, post_w, height), post)
	var banner := Rect2(x - half - post_w, y - height, (half + post_w) * 2.0, banner_h)
	var text := ""
	var text_col := Color.WHITE
	if seg.flags & Segment.FLAG_FINISH:
		var cols := 24
		var cell := banner.size.x / cols
		for row in 2:
			for c in cols:
				var col := Color.WHITE if (c + row) % 2 == 0 else Color("#151515")
				draw_rect(Rect2(banner.position.x + c * cell, banner.position.y + row * banner_h / 2.0, cell + 0.5, banner_h / 2.0), col * tint)
	elif seg.flags & Segment.FLAG_CHECKPOINT:
		draw_rect(banner, Color("#ffd23a") * tint)
		draw_rect(banner.grow(-banner_h * 0.08), Color("#1f4fbf") * tint)
		text = "CHECKPOINT"
		text_col = Color("#ffd23a") * tint
	else:
		draw_rect(banner, Color("#1e9e5a") * tint)
		text = "START"
	var font_size := int(banner_h * 0.6)
	if text != "" and font_size >= 6:
		draw_string(_font, Vector2(banner.position.x, banner.position.y + banner_h * 0.75), text,
			HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, mini(font_size, 96), text_col)


func _draw_player() -> void:
	var p := player
	var s := Cfg.CAMERA_DEPTH / Cfg.PLAYER_Z
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
	CarSprites.draw_player(self, Vector2(Cfg.SCREEN_W * 0.5, roundf(y)), w, steer, p.braking, p.nitro_time > 0.0,
		time, roundf(lift))


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
