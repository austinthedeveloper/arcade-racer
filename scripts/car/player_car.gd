class_name PlayerCar
extends RefCounted
## Arcade driving model in track space: z along the road, x across it (-1..1 is the road).

var position := 0.0  # camera z, wrapped to the track length
var distance := 0.0  # total distance driven, not wrapped
var x := 0.0
var speed := 0.0
var steer := 0.0  # smoothed steering, for visuals
var braking := false
var offroad := false

var nitro_charges := Cfg.NITRO_CHARGES
var nitro_time := 0.0

var road_y := 0.0  # road height under the car
var air_height := 0.0  # car height above the road
var airborne := false
var landed := false  # true for the tick the car touches down
var crashed := false  # true for the tick a crash starts
var bumped := false  # true for the tick the car nudges slower traffic without crashing
var crash_time := 0.0

var _alt := 0.0
var _vy := 0.0


func reset(start_position: float = 0.0) -> void:
	position = start_position
	distance = 0.0
	x = 0.0
	speed = 0.0
	nitro_charges = Cfg.NITRO_CHARGES
	nitro_time = 0.0
	crash_time = 0.0
	airborne = false
	air_height = 0.0
	_vy = 0.0


func speed_percent() -> float:
	return speed / Cfg.MAX_SPEED


func update(dt: float, inp: DriveInput, track: Track, controls: bool) -> void:
	landed = false
	crashed = false
	bumped = false
	var seg := track.find_segment(position + Cfg.PLAYER_Z)
	var pct := speed / Cfg.MAX_SPEED
	var top := Cfg.MAX_SPEED * (Cfg.NITRO_SPEED_MULT if nitro_time > 0.0 else 1.0)

	var throttle := 0.0
	var brake := 0.0
	var steer_in := 0.0
	if controls and crash_time <= 0.0:
		throttle = inp.throttle
		brake = inp.brake
		steer_in = inp.steer
		if inp.nitro_pressed and nitro_charges > 0 and nitro_time <= 0.0:
			nitro_charges -= 1
			nitro_time = Cfg.NITRO_DURATION
	nitro_time = maxf(0.0, nitro_time - dt)

	var step := speed * dt
	position = fposmod(position + step, track.length)
	distance += step

	# Steering and the outward pull of curves
	var rate := dt * Cfg.STEER_RATE * pct
	if airborne:
		rate *= 0.35
	x += steer_in * rate
	if not airborne:
		x -= rate * pct * seg.curve * Cfg.CENTRIFUGAL
	steer = lerpf(steer, steer_in, minf(1.0, dt * 12.0))

	# Speed
	if crash_time > 0.0:
		crash_time -= dt
		speed = move_toward(speed, 0.0, Cfg.MAX_SPEED * 1.2 * dt)
		x = move_toward(x, clampf(x, -0.8, 0.8), dt * 1.5)
	elif not airborne:
		if throttle > 0.01:
			var boost := Cfg.NITRO_ACCEL_MULT if nitro_time > 0.0 else 1.0
			speed += Cfg.ACCEL * boost * throttle * (1.3 - 0.8 * speed / top) * dt
		if brake > 0.01:
			speed -= Cfg.BRAKING * brake * dt
		if throttle <= 0.01 and brake <= 0.01:
			speed -= Cfg.DECEL * dt
	offroad = absf(x) > 1.0
	if offroad and not airborne and speed > Cfg.OFFROAD_LIMIT:
		speed = maxf(Cfg.OFFROAD_LIMIT, speed - Cfg.OFFROAD_DECEL * dt)
	if speed > top:
		speed = move_toward(speed, top, Cfg.MAX_SPEED * 0.4 * dt)
	speed = maxf(speed, 0.0)
	x = clampf(x, -3.0, 3.0)
	braking = brake > 0.1

	_update_air(dt, track.height_at(position + Cfg.PLAYER_Z))


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


## Checks roadside sprites and traffic in the player's segment.
func collide(track: Track) -> void:
	if crash_time > 0.0 or airborne:
		return
	var seg := track.find_segment(position + Cfg.PLAYER_Z)
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
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
				return
	for car in seg.cars:
		if speed <= car.speed:
			continue
		var car_half: float = half_car * car.width_mult
		if absf(x - car.offset) < (half_car + car_half) * 0.8:
			if speed - car.speed > Cfg.MAX_SPEED * 0.5:
				crash()
			else:
				speed = car.speed * (car.speed / speed)
				bumped = true
				position = fposmod(car.z - Cfg.PLAYER_Z - 50.0, track.length)
			return


func crash() -> void:
	crash_time = Cfg.CRASH_DURATION
	crashed = true
	nitro_time = 0.0
