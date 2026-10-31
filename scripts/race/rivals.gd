class_name Rivals
extends RefCounted
## The computer-driven field: lines up on a grid ahead of the player, drives each rival with
## its AIDriver, and settles contact between racers (rivals and the player). Seeded, so the
## same stage plays out the same way every time.

const COUNT := 7
const SEED := 4021
const GRID_FRONT := 1250.0  # world units the front of the grid is ahead of the player's nose
const GRID_STEP := 150.0  # between one grid slot and the next, staggered left and right
const GRID_X := 0.5
## Rubber band: rivals ahead of the player ease off and rivals behind get a little more, in
## full at BAND_RANGE away. BAND_MAX caps either way, whatever a difficulty asks for.
const BAND_RANGE := 4000.0
const BAND_MAX := 0.08
const BAND_EASE := 0.05  # normal difficulty: most a rival ahead gives up...
const BAND_BOOST := 0.04  # ...and most a rival behind gains
const CONTACT_LENGTH := 300.0  # world units along the road two racers touch within
const CONTACT_SLOWDOWN := 0.97  # the car behind drops to this share of the one in front's speed
const SIDE_PUSH_LOSS := 0.02  # share of speed a racer-to-racer side contact scrubs off

var cars: Array[RivalCar] = []
var band_ease := BAND_EASE
var band_boost := BAND_BOOST
var clock := 0.0  # seconds since GO; runs on after the player finishes, unlike the race clock


## Puts `count` rivals on the grid ahead of `player` (already reset at its start), in cars
## other than `player_car_id`, picked and tuned by `seed_value`.
func spawn(track: Track, player: PlayerCar, player_car_id: String, count: int = COUNT, seed_value: int = SEED) -> void:
	cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = []
	for prof in RivalProfile.roster():
		if prof.car_id != player_car_id:
			pool.append(prof)
	for i in mini(count, pool.size()):
		var prof: RivalProfile = pool.pop_at(rng.randi() % pool.size())
		var car := Cars.find(prof.car_id)
		var r := RivalCar.new(car, AIDriver.new(rng.randi(), prof.lane_bias, prof.style))
		r.profile = prof
		r.top_speed *= prof.pace
		r.base_top = r.top_speed
		var ahead := GRID_FRONT - i * GRID_STEP
		r.reset(player.position + ahead)
		r.distance = player.distance + ahead
		r.x = -GRID_X if i % 2 == 0 else GRID_X
		r.road_y = track.height_at(r.position + Cfg.PLAYER_Z)
		r.strips = CarSprites.strips(car["strip"])
		cars.append(r)


## One tick: every rival drives (no controls until `racing`), then hits traffic and roadside
## sprites like the player. Records each finish at `finish_distance`.
func update(dt: float, track: Track, player: PlayerCar, racing: bool, finish_distance: float) -> void:
	if racing:
		if clock == 0.0:
			for r in cars:
				Launch.apply(r, Launch.rival_grade(r.driver.rng))
		clock += dt
	var racers := everyone(player)
	for r in cars:
		var gap := r.distance - player.distance
		r.top_speed = r.base_top * (1.0 if r.finished else band(gap, band_ease, band_boost))
		var inp := r.driver.drive(r, track, racers, dt) if racing else DriveInput.new()
		r.update(dt, inp, track, racing)
	for r in cars:
		Draft.update(r, dt, racing and Draft.in_wake(r, track, racers))
	for r in cars:
		r.collide(track)
		if not r.finished and r.distance >= finish_distance:
			r.finished = true
			r.finish_time = clock


## A rival's top speed multiplier `gap` world units ahead of the player (negative: behind):
## easing off by up to `ease` ahead, gaining up to `boost` behind, never more than BAND_MAX.
static func band(gap: float, ease: float, boost: float) -> float:
	var t := clampf(gap / BAND_RANGE, -1.0, 1.0)
	if t > 0.0:
		return 1.0 - t * clampf(ease, 0.0, BAND_MAX)
	return 1.0 - t * clampf(boost, 0.0, BAND_MAX)


func everyone(player: PlayerCar) -> Array:
	var all: Array = [player]
	all.append_array(cars)
	return all


## Everyone in race order: finishers first by finish time, then the rest by distance.
## `player_finish` is the player's finish time, or a negative number while still racing.
func standings(player: PlayerCar, player_finish: float) -> Array:
	var order := everyone(player)
	var done := func(car: PlayerCar) -> float:
		if car == player:
			return player_finish
		return (car as RivalCar).finish_time if (car as RivalCar).finished else -1.0
	order.sort_custom(func(a: PlayerCar, b: PlayerCar) -> bool:
		var ta: float = done.call(a)
		var tb: float = done.call(b)
		if ta >= 0.0 or tb >= 0.0:
			if ta < 0.0 or tb < 0.0:
				return ta >= 0.0
			if ta != tb:
				return ta < tb
		return a.distance > b.distance)
	return order


## The player's place, 1 for the lead.
func place(player: PlayerCar, player_finish: float) -> int:
	return standings(player, player_finish).find(player) + 1


## 1ST, 2ND, 3RD, 4TH...
static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return str(n) + suffix


func finished_count() -> int:
	var n := 0
	for r in cars:
		n += int(r.finished)
	return n


## Racers bumping each other. A car that comes up behind another drops behind it at a little
## under its speed; two already side by side are pushed apart. Nobody crashes. A ghosted car
## (the GHOST power-up) drives right through the others.
static func resolve_contacts(racers: Array, track: Track) -> void:
	var half_car := Cfg.CAR_WIDTH * 0.5 / Cfg.ROAD_WIDTH
	var reach := half_car * 2.0 * Cfg.HIT_OVERLAP
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a: PlayerCar = racers[i]
			var b: PlayerCar = racers[j]
			if a.airborne or b.airborne or a.ghost_time > 0.0 or b.ghost_time > 0.0 or absf(a.x - b.x) >= reach:
				continue
			var dz := wrapf(b.position - a.position, -track.length * 0.5, track.length * 0.5)
			if absf(dz) >= CONTACT_LENGTH:
				continue
			var was := wrapf(b.last_position - a.last_position, -track.length * 0.5, track.length * 0.5)
			if absf(was) >= CONTACT_LENGTH:
				# Ran into the back of it
				var front := b if dz > 0.0 else a
				var back := a if dz > 0.0 else b
				back.speed = minf(back.speed, front.speed * CONTACT_SLOWDOWN)
				back.move_to(front.position - CONTACT_LENGTH, track)
				back.bumped = true
			else:
				var push := (reach - absf(a.x - b.x)) * 0.5
				var side := 1.0 if a.x >= b.x else -1.0
				a.x += side * push
				b.x -= side * push
				a.speed *= 1.0 - SIDE_PUSH_LOSS
				b.speed *= 1.0 - SIDE_PUSH_LOSS
				a.bumped = true
				b.bumped = true
