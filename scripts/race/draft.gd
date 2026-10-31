class_name Draft
extends RefCounted
## Slipstream: sitting close behind a racer or a big vehicle fills a meter; a full meter gives a
## few seconds of extra top speed.

const LENGTH := 1200.0  # world units behind a car its wake reaches
const WIDTH := 0.35  # road half-widths either side of its center
const MIN_SPEED := 0.5  # share of Cfg.MAX_SPEED below which there's no wake to sit in
const FILL_TIME := 1.5  # seconds in the wake to fill the meter
const DECAY_TIME := 1.0  # seconds out of it to empty
const BOOST_TIME := 3.0
const SPEED_MULT := 1.08  # on top speed while the boost runs


## Whether `me` sits in the wake of a racer or a big vehicle (Traffic.BIG) ahead.
static func in_wake(me: PlayerCar, track: Track, racers: Array) -> bool:
	if me.speed < Cfg.MAX_SPEED * MIN_SPEED or me.airborne or me.crash_time > 0.0:
		return false
	var nose := me.position + Cfg.PLAYER_Z
	for other: PlayerCar in racers:
		if other == me:
			continue
		var ahead := wrapf(other.position - me.position, -track.length * 0.5, track.length * 0.5)
		if ahead > 0.0 and ahead < LENGTH and absf(other.x - me.x) < WIDTH:
			return true
	var here := track.find_segment(nose).index
	for k in ceili(LENGTH / Cfg.SEGMENT_LENGTH) + 1:
		for car: Traffic.TrafficCar in track.segments[(here + k) % track.segments.size()].cars:
			if not Traffic.BIG.has(car.sprite) or not car.solid():
				continue
			var ahead := wrapf(car.z - nose, -track.length * 0.5, track.length * 0.5)
			if ahead > 0.0 and ahead < LENGTH and absf(car.offset - me.x) < WIDTH:
				return true
	return false


## One tick of the meter and the boost.
static func update(me: PlayerCar, dt: float, wake: bool) -> void:
	me.draft_time = maxf(0.0, me.draft_time - dt)
	if me.draft_time > 0.0:
		me.draft = 0.0
		return
	me.draft = clampf(me.draft + (dt / FILL_TIME if wake else -dt / DECAY_TIME), 0.0, 1.0)
	if me.draft >= 1.0:
		me.draft = 0.0
		me.draft_time = BOOST_TIME
