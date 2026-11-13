class_name Autodrive
extends RefCounted
## The autodrive (--autodrive, the attract mode's demo races, the golden traces, the balance
## report): full gas from GO, steering for the lane with the most open road ahead, a power
## slide through the hard bends, nitro every ten seconds. Its every number shapes the golden
## traces, so a change here is a play change (regenerate them).


## The controls for `car` on `track` among `racers` (the rivals, and in a split race player 2):
## no gas while `waiting` (the countdown, but for its last tenth), nitro on tick `frame` of
## every 600, and steering for `drive_x` across the road when it isn't NAN (--drive-x), the
## best lane (lane) otherwise.
static func input(car: PlayerCar, track: Track, racers: Array, waiting: bool, frame: int, drive_x: float) -> DriveInput:
	var inp := DriveInput.new()
	var seg := track.find_segment(car.position + Cfg.PLAYER_Z + 3000.0)
	inp.throttle = 0.0 if waiting else 1.0
	var aim := drive_x if not is_nan(drive_x) else lane(car, track, racers)
	inp.steer = clampf((seg.curve * 0.25) + (aim - car.x) * 1.5, -1.0, 1.0)
	# A dab of brake with the lock on throws it into a power slide through a hard bend (RC-8)
	if slides(seg.curve, inp.steer, car):
		inp.brake = 1.0
	inp.nitro_pressed = frame % 600 == 300
	inp.shift_up_pressed = car.on_limiter()
	inp.shift_down_pressed = car.manual and car.gear > 1 and car.speed < PlayerCar.gear_limit(car.gear - 1) * 0.8
	return inp


## Whether the autodrive brakes into a power slide: a hard bend ahead (Track.CURVE_HARD), the
## lock on for it and the speed for a slide, on the road and not sliding already (the brake
## would only brake).
static func slides(curve_ahead: float, steer: float, car: PlayerCar) -> bool:
	return car.slide == 0.0 and not car.airborne and not car.offroad and absf(curve_ahead) >= Track.CURVE_HARD \
		and absf(steer) >= Tuning.v("slide/steer") and car.speed >= Cfg.MAX_SPEED * Tuning.v("slide/speed")


## The lane with the most open road ahead, keeping the current one on a tie. Anything slower
## than cruising speed blocks a lane, so a slowed car doesn't sit behind a tractor.
static func lane(me: PlayerCar, track: Track, racers: Array) -> float:
	const LOOKAHEAD := 40  # segments
	var want := maxf(me.speed, Cfg.MAX_SPEED * 0.8)
	var here := track.find_segment(me.position + Cfg.PLAYER_Z).index
	var lanes: Array = Traffic.lanes(track, track.narrowest_ahead(me.position + Cfg.PLAYER_Z))
	var best: float = lanes[0]
	var best_gap := -1
	lanes.sort_custom(func(a: float, b: float) -> bool: return absf(a - me.x) < absf(b - me.x))
	for x: float in lanes:
		# A hazard (RC-19) blocks a lane like a slow car
		var gap := RoadHazards.room(track, me.position + Cfg.PLAYER_Z, x, Cfg.HALF_CAR, AIDriver.LANE_CLEARANCE, LOOKAHEAD)
		for r in racers:
			if r == me:
				continue  # (player 2 itself, in a split race)
			var ahead := track.gap(me.position, r.position)
			if ahead > 0.0 and absf(r.x - x) < 0.3 and r.speed < want:
				gap = mini(gap, int(ahead / Cfg.SEGMENT_LENGTH))
		for n in gap:
			var seg := track.segments[(here + n) % track.segments.size()]
			var blocked := false
			for car in seg.cars:
				if absf(car.offset - x) < 0.3 and car.speed < want:
					blocked = true
			if blocked:
				gap = n
				break
		if gap > best_gap:
			best_gap = gap
			best = x
	return best
