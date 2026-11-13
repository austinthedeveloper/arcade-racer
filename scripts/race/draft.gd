class_name Draft
extends RefCounted
## Slipstream: sitting close behind a racer or a big vehicle fills a meter; a full meter gives a
## few seconds of extra top speed. Its numbers are Tuning's "draft" area. Big vehicles run at
## 0.25 to 0.4 of top speed (Traffic.BIG_SPEED): their wake counts while you keep up with one,
## at draft/keep_up of its speed or more.


## Whether `me` sits in the wake of a racer or a big vehicle (Traffic.BIG) ahead.
static func in_wake(me: PlayerCar, track: Track, racers: Array) -> bool:
	if me.airborne or me.crash_time > 0.0:
		return false
	var nose := me.position + Cfg.PLAYER_Z
	for other: PlayerCar in racers:
		if other == me or me.speed < Cfg.MAX_SPEED * Tuning.v("draft/min_speed"):
			continue
		var ahead := track.gap(me.position, other.position)
		if ahead > 0.0 and ahead < Tuning.v("draft/length") and absf(other.x - me.x) < Tuning.v("draft/width"):
			return true
	var here := track.find_segment(nose).index
	for k in ceili(Tuning.v("draft/length") / Cfg.SEGMENT_LENGTH) + 1:
		for car: Traffic.TrafficCar in track.segments[(here + k) % track.segments.size()].cars:
			if not Traffic.BIG.has(car.sprite) or not car.solid() or car.oncoming or me.speed < car.speed * Tuning.v("draft/keep_up"):
				continue
			var ahead := track.gap(nose, car.z)
			if ahead > 0.0 and ahead < Tuning.v("draft/length") and absf(car.offset - me.x) < Tuning.v("draft/width"):
				return true
	return false


## One tick of the meter and the boost.
static func update(me: PlayerCar, dt: float, wake: bool) -> void:
	me.draft_time = maxf(0.0, me.draft_time - dt)
	if me.draft_time > 0.0:
		me.draft = 0.0
		return
	me.draft = clampf(me.draft + (dt / Tuning.v("draft/fill_time") if wake else -dt / Tuning.v("draft/decay_time")), 0.0, 1.0)
	if me.draft >= 1.0:
		me.draft = 0.0
		me.draft_time = Tuning.v("draft/boost_time")
