class_name PlayerCar
extends RefCounted
## Arcade driving model in track space: z along the road, x across it (-1..1 is the road).

const PITCH_SPAN := 400.0  # world units of road the car's pitch is measured over (about its length)
const PITCH_FULL_DEG := 30.0
const PITCH_RATE := 8.0
const MAX_TICK_SEGMENTS := 4  # more segments than this in one tick is a teleport

var position := 0.0  # camera z, wrapped to the track length
var last_position := 0.0  # position before this tick's move
var distance := 0.0  # total distance driven, not wrapped
var x := 0.0
var speed := 0.0
var steer := 0.0  # smoothed steering, for visuals
var pitch := 0.0  # smoothed nose angle for visuals: 1 full nose-down (downhill), -1 full nose-up
var braking := false
var offroad := false

var nitro_charges := Cfg.NITRO_CHARGES
var nitro_time := 0.0

# The car's tuning (Cars.tuning); the defaults are the Vega's
var top_speed := Cfg.MAX_SPEED
var accel_mult := 1.0
var steer_mult := 1.0
var pull_mult := 1.0
var offroad_mult := 1.0
var nitro_max := Cfg.NITRO_CHARGES
var nitro_duration := Cfg.NITRO_DURATION

# Power-ups (PowerUps): seconds left on each
var ram_time := 0.0  # traffic you hit flies off instead of crashing you
var ghost_time := 0.0  # drive through traffic
var rammed := false  # true for the tick the ram plate knocks a car away

var road_y := 0.0  # road height under the car
var air_height := 0.0  # car height above the road
var airborne := false
var landed := false  # true for the tick the car touches down
var crashed := false  # true for the tick a crash starts
var bumped := false  # true for the tick the car nudges slower traffic without crashing
var crash_time := 0.0

var _alt := 0.0
var _vy := 0.0


## Tunes the driving model for a car from Cars.LIST. Call before reset.
func setup(car: Dictionary) -> void:
	var t := Cars.tuning(car)
	top_speed = Cfg.MAX_SPEED * t["top"]
	accel_mult = t["accel"]
	steer_mult = t["steer"]
	pull_mult = t["pull"]
	offroad_mult = t["offroad"]
	nitro_max = t["nitros"]
	nitro_duration = Cfg.NITRO_DURATION * t["nitro_time"]


func reset(start_position: float = 0.0) -> void:
	position = start_position
	last_position = start_position
	distance = 0.0
	x = 0.0
	speed = 0.0
	nitro_charges = nitro_max
	nitro_time = 0.0
	ram_time = 0.0
	ghost_time = 0.0
	crash_time = 0.0
	airborne = false
	air_height = 0.0
	pitch = 0.0
	_vy = 0.0


func speed_percent() -> float:
	return speed / Cfg.MAX_SPEED


func update(dt: float, inp: DriveInput, track: Track, controls: bool) -> void:
	landed = false
	crashed = false
	bumped = false
	var seg := track.find_segment(position + Cfg.PLAYER_Z)
	var pct := speed / Cfg.MAX_SPEED
	var top := top_speed * (Cfg.NITRO_SPEED_MULT if nitro_time > 0.0 else 1.0)

	var throttle := 0.0
	var brake := 0.0
	var steer_in := 0.0
	if controls and crash_time <= 0.0:
		throttle = inp.throttle
		brake = inp.brake
		steer_in = inp.steer
		if inp.nitro_pressed and nitro_charges > 0 and nitro_time <= 0.0:
			nitro_charges -= 1
			nitro_time = nitro_duration
	nitro_time = maxf(0.0, nitro_time - dt)
	ram_time = maxf(0.0, ram_time - dt)
	ghost_time = maxf(0.0, ghost_time - dt)

	var step := speed * dt
	last_position = position
	position = fposmod(position + step, track.length)
	distance += step

	# Steering and the outward pull of curves
	var rate := dt * Cfg.STEER_RATE * steer_mult * pct
	if airborne:
		rate *= 0.35
	x += steer_in * rate
	if not airborne:
		x -= rate / steer_mult * pct * seg.curve * Cfg.CENTRIFUGAL * pull_mult
	steer = lerpf(steer, steer_in, minf(1.0, dt * 12.0))

	# Speed
	if crash_time > 0.0:
		crash_time -= dt
		speed = move_toward(speed, 0.0, Cfg.MAX_SPEED * 1.2 * dt)
		x = move_toward(x, clampf(x, -0.8, 0.8), dt * 1.5)
	elif not airborne:
		if throttle > 0.01:
			var boost := Cfg.NITRO_ACCEL_MULT if nitro_time > 0.0 else 1.0
			speed += Cfg.ACCEL * accel_mult * boost * throttle * (1.3 - 0.8 * speed / top) * dt
		if brake > 0.01:
			speed -= Cfg.BRAKING * brake * dt
		if throttle <= 0.01 and brake <= 0.01:
			speed -= Cfg.DECEL * dt
	offroad = absf(x) > 1.0
	if offroad and not airborne and offroad_mult > 0.0 and speed > Cfg.OFFROAD_LIMIT / offroad_mult:
		speed = maxf(Cfg.OFFROAD_LIMIT / offroad_mult, speed - Cfg.OFFROAD_DECEL * offroad_mult * dt)
	if speed > top:
		speed = move_toward(speed, top, Cfg.MAX_SPEED * 0.4 * dt)
	speed = maxf(speed, 0.0)
	x = clampf(x, -3.0, 3.0)
	braking = brake > 0.1

	_update_air(dt, track.height_at(position + Cfg.PLAYER_Z))
	_update_pitch(dt, track)


## Leaves the road when it drops away faster than gravity can pull the car down.
func _update_air(dt: float, new_road_y: float) -> void:
	var road_vy := (new_road_y - road_y) / dt if dt > 0.0 else 0.0
	if airborne:
		_vy -= Cfg.GRAVITY * dt
		_alt += _vy * dt
		if _alt <= new_road_y:
			_alt = new_road_y
			_vy = road_vy
			airborne = false
			landed = true
	elif _vy - road_vy > Cfg.GRAVITY * dt and speed > Cfg.MAX_SPEED * 0.4:
		airborne = true
		_vy -= Cfg.GRAVITY * dt
		_alt = road_y + _vy * dt
	else:
		_vy = road_vy
		_alt = new_road_y
	road_y = new_road_y
	air_height = maxf(0.0, _alt - road_y)


## Follows the road's slope under the car, or the flight path in the air.
func _update_pitch(dt: float, track: Track) -> void:
	var slope := 0.0
	if airborne:
		slope = _vy / maxf(speed, 1.0)
	else:
		var z := position + Cfg.PLAYER_Z
		slope = (track.height_at(z + PITCH_SPAN * 0.5) - track.height_at(z - PITCH_SPAN * 0.5)) / PITCH_SPAN
	pitch = lerpf(pitch, pitch_for_slope(slope), minf(1.0, dt * PITCH_RATE))


## Road slope (rise over run) to display pitch: downhill is positive, PITCH_FULL_DEG or
## steeper is the most there is.
static func pitch_for_slope(slope: float) -> float:
	return clampf(-rad_to_deg(atan(slope)) / PITCH_FULL_DEG, -1.0, 1.0)


## The segments the car's nose entered this tick (two at nitro speed). A longer jump is a
## teleport (a test or a restart placing the car), which only checks where it landed.
func passed_segments(track: Track) -> Array[Segment]:
	var segs := track.segments_entered(last_position + Cfg.PLAYER_Z, position + Cfg.PLAYER_Z)
	if segs.size() > MAX_TICK_SEGMENTS:
		return [track.find_segment(position + Cfg.PLAYER_Z)]
	return segs


## Checks roadside sprites and traffic in every segment the car entered this tick.
func collide(track: Track) -> void:
	rammed = false
	if crash_time > 0.0 or airborne:
		return
	for seg in passed_segments(track):
		if _collide_segment(seg, track):
			return


## Collides with one segment's spans, sprites and traffic. True once something was hit.
func _collide_segment(seg: Segment, track: Track) -> bool:
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	if offroad and hits_span(seg, x, half_car):
		crash()
		return true
	if offroad:
		for sp in seg.sprites:
			var def: Dictionary = SpriteLibrary.defs.get(sp["id"], {})
			if def.is_empty() or def["collide"] <= 0.0:
				continue
			var w_units: float = def["world_w"] / Cfg.ROAD_WIDTH
			var offset: float = sp["offset"]
			var center := offset - w_units / 2.0 if offset < 0.0 else offset + w_units / 2.0
			if absf(x - center) < w_units * def["collide"] / 2.0 + half_car:
				crash()
				return true
	if ghost_time > 0.0:
		return false
	for car in seg.cars:
		if speed <= car.speed or car.flung > 0.0:
			continue
		var car_half: float = half_car * car.width_mult
		if absf(x - car.offset) < (half_car + car_half) * 0.8:
			if ram_time > 0.0:
				Traffic.fling(car, x)
				rammed = true
			elif speed - car.speed > Cfg.MAX_SPEED * 0.5:
				crash()
			else:
				speed = car.speed * (car.speed / speed)
				bumped = true
				move_to(car.z - Cfg.PLAYER_Z - 50.0, track)
			return true
	return false


## Puts the car at track position `z` (wrapped), moving `distance` by the same amount so
## checkpoints and the finish stay where they are drawn.
func move_to(z: float, track: Track) -> void:
	var to := fposmod(z, track.length)
	distance += wrapf(to - position, -track.length * 0.5, track.length * 0.5)
	position = to


## Whether a car at `car_x` (half-width `half_car`, both in road half-widths) hits the
## legs or walls of a span or race gate in `seg`.
static func hits_span(seg: Segment, car_x: float, half_car: float) -> bool:
	var ids: Array[String] = seg.spans.duplicate()
	var gate := RoadRenderer.gate_for(seg.flags)
	if gate != "":
		ids.append(gate)
	for id in ids:
		if not SpriteLibrary.spans.has(id):
			continue
		var e := SpriteLibrary.span_edges(id)
		var inner: Vector2 = e["inner"]
		var outer: Vector2 = e["outer"]
		if (car_x - half_car < inner.x and car_x + half_car > outer.x) or (car_x + half_car > inner.y and car_x - half_car < outer.y):
			return true
	return false


func crash() -> void:
	crash_time = Cfg.CRASH_DURATION
	crashed = true
	nitro_time = 0.0
