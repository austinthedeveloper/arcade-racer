class_name Rivals
extends RefCounted
## The computer-driven field: lines up on a grid ahead of the player, drives each rival with
## its AIDriver, and settles contact between racers (rivals and the player). Seeded, so the
## same stage plays out the same way every time.

const COUNT := 7
const SEED := 4021
## The grid: the back slot grid/back world units ahead of the player's nose, then a slot
## every grid/step on up the road, staggered between the outermost lanes either side
## (grid_x), the player starting in the middle (Tuning). Strung out and clear of the middle,
## so the player's launch doesn't plough into the back of it and the race is a chase.
## The most a rival's base pace comes to, of its car's top speed, whatever the difficulty and
## the stage ask for (the rubber band can still add a little).
const MAX_PACE := 1.0
const CONTACT_LENGTH := 300.0  # world units along the road two racers touch within
const STANDSTILL := 100.0  # world units per second under which a car in the way counts as stopped
const SQUEEZE := 0.01  # road half-widths a tick a car stuck behind a stopped one edges round it

var cars: Array[RivalCar] = []
## Rubber band: rivals ahead of the player ease off and rivals behind get a little more, in
## full at ai/band_range away (Tuning), by as much as the difficulty says (difficulty/*_ease,
## difficulty/*_boost). ai/band_max caps either way, whatever a difficulty asks for.
var band_ease := 0.05  # (spawn sets both from the difficulty)
var band_boost := 0.04
var clock := 0.0  # seconds since GO; runs on after the player finishes, unlike the race clock


## Puts `count` rivals on the grid ahead of `player` (already reset at its start), in cars
## other than `player_car_id`, picked and tuned by `seed_value`, at the difficulty's pace times
## `stage_pace` (stage_pace_of, RC-21).
func spawn(track: Track, player: PlayerCar, player_car_id: String, count: int = COUNT, seed_value: int = SEED,
		difficulty: Difficulty = Difficulty.of(Difficulty.Level.NORMAL), drivers: Array = [], stage_pace := 1.0) -> void:
	cars.clear()
	band_ease = difficulty.band_ease
	band_boost = difficulty.band_boost
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = []
	for prof in RivalProfile.roster():
		if prof.car_id != player_car_id:
			pool.append(prof)
	var named: Array = []  # a tour keeps its drivers stage to stage
	for want: String in drivers:
		for prof: RivalProfile in pool:
			if prof.driver == want:
				named.append(prof)
	var n := mini(count, pool.size())
	for i in n:
		var pick := rng.randi() % pool.size()
		var prof: RivalProfile = named[i] if i < named.size() else pool.pop_at(pick)
		var car := Cars.find(prof.car_id)
		var r := RivalCar.new(car, AIDriver.new(rng.randi(), prof.lane_bias, prof.style, track.side()))
		r.profile = prof
		r.top_speed *= minf(prof.pace * difficulty.rival_pace * stage_pace, MAX_PACE)
		r.base_top = r.top_speed
		var ahead := grid_ahead(i, n)
		r.reset(player.position + ahead)
		r.distance = player.distance + ahead
		r.x = grid_x(track, r.position + Cfg.PLAYER_Z, i)
		r.driver.grid_hold = Tuning.v("grid/hold")
		r.driver.hold_x = r.x
		r.road_y = track.height_at(r.position + Cfg.PLAYER_Z)
		r.strips = CarSprites.strips(car["strip"])
		cars.append(r)


## How far ahead of the player's nose grid slot `slot` of `count` starts: slot 0 at the front.
static func grid_ahead(slot: int, count: int) -> float:
	return Tuning.v("grid/back") + (count - 1 - slot) * Tuning.v("grid/step")


## Across the road, grid slot `slot` at `z`: the outermost lane, left for even slots and
## right for odd ones (swapped on a mirrored stage), clear of the player's car in the middle.
static func grid_x(track: Track, z: float, slot: int) -> float:
	var outer: float = absf(track.find_segment(z).lane_offsets()[-1])
	return (-outer if slot % 2 == 0 else outer) * track.side()


## How far ahead of the player's nose the front of a full grid starts: traffic keeps clear of
## that much road ahead of the start (Traffic.keep_clear).
static func grid_length() -> float:
	return grid_ahead(0, COUNT)


## The rivals' pace on stage `stage` (into Stages), on top of the difficulty's: the stage's
## balance/* value (Tuning), so a stage whose field runs slow or fast is evened out (RC-21).
static func stage_pace_of(stage: int) -> float:
	return Tuning.v("balance/" + Stages.POSTCARDS[clampi(stage, 0, Stages.POSTCARDS.size() - 1)])


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
		if r.remote:
			continue  # another player online: its own game drives it (CarState)
		var gap := r.distance - player.distance
		r.top_speed = r.base_top * (1.0 if r.finished else band(gap, band_ease, band_boost))
		var inp := r.driver.drive(r, track, racers, dt) if racing else DriveInput.new()
		r.update(dt, inp, track, racing)
	for r in cars:
		if not r.remote:
			Draft.update(r, dt, racing and Draft.in_wake(r, track, racers))
	for r in cars:
		if r.remote:
			continue
		r.collide(track)
		RoadHazards.drive_over(r, track)  # (RC-19)
		if not r.finished and r.distance >= finish_distance:
			r.finished = true
			r.finish_time = clock


## A rival's top speed multiplier `gap` world units ahead of the player (negative: behind):
## easing off by up to `ease` ahead, gaining up to `boost` behind, never more than ai/band_max.
static func band(gap: float, ease: float, boost: float) -> float:
	var t := clampf(gap / Tuning.v("ai/band_range"), -1.0, 1.0)
	if t > 0.0:
		return 1.0 - t * clampf(ease, 0.0, Tuning.v("ai/band_max"))
	return 1.0 - t * clampf(boost, 0.0, Tuning.v("ai/band_max"))


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


## The drivers' names, grid order.
func driver_names() -> Array[String]:
	var out: Array[String] = []
	for r in cars:
		out.append(r.profile.driver)
	return out


func finished_count() -> int:
	var n := 0
	for r in cars:
		n += int(r.finished)
	return n


## Racers bumping each other. A car that comes up behind another drops behind it at a little
## under its speed; two already side by side are pushed apart, scrubbing speed when they first
## touch but not again while they rub doors (that took 2% every tick, and held the player at a
## quarter of top speed beside a rival). Nobody crashes. A ghosted car (the GHOST power-up, or
## one just back from a crash) drives right through the others.
static func resolve_contacts(racers: Array, track: Track) -> void:
	var half_car := Cfg.HALF_CAR
	var reach := half_car * 2.0 * Tuning.v("crashes/hit_overlap")
	var was_rubbing := {}
	for r: PlayerCar in racers:
		was_rubbing[r] = r.rubbing
		r.rubbing = false
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a: PlayerCar = racers[i]
			var b: PlayerCar = racers[j]
			if a.airborne or b.airborne or a.ghosted() or b.ghosted() or absf(a.x - b.x) >= reach:
				continue
			var dz := track.gap(a.position, b.position)
			if absf(dz) >= CONTACT_LENGTH:
				continue
			var was := track.gap(a.last_position, b.last_position)
			if absf(was) >= CONTACT_LENGTH:
				# Ran into the back of it
				var front := b if dz > 0.0 else a
				var back := a if dz > 0.0 else b
				back.speed = minf(back.speed, front.speed * Tuning.v("ai/contact_slowdown"))
				back.move_to(front.position - CONTACT_LENGTH, track)
				back.bumped = true
				# Held to a standstill behind a car stopped for good (not one crashed, which gets
				# going again), it couldn't steer out, steering needs speed, and sat there for good
				# (EQ-22's soak found one): it edges round instead, to a little past touching (edged
				# to exactly the reach, it still touched, and sat there again: the 2026-11-14 soak)
				if front.speed < STANDSTILL and front.crash_time <= 0.0:
					var way := signf(back.x - front.x) if back.x != front.x else track.side()
					back.x = move_toward(back.x, front.x + way * (reach + AIDriver.LANE_CLEARANCE), SQUEEZE)
			else:
				var push := (reach - absf(a.x - b.x)) * 0.5
				var side := 1.0 if a.x >= b.x else -1.0
				a.x += side * push
				b.x -= side * push
				if not (was_rubbing[a] and was_rubbing[b]):
					a.speed *= 1.0 - Tuning.v("ai/side_push_loss")
					b.speed *= 1.0 - Tuning.v("ai/side_push_loss")
				a.rubbing = true
				b.rubbing = true
				a.bumped = true
				b.bumped = true
