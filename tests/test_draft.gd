## Slipstream (Draft): the wake, the meter filling and emptying, and the boost.
extends TestSuite


func _car(z: float, speed: float) -> PlayerCar:
	var p := PlayerCar.new()
	p.reset(z)
	p.speed = speed
	return p


func _big(t: Track, z: float, offset: float, sprite := "semi") -> Traffic.TrafficCar:
	var c := Traffic.TrafficCar.new()
	c.z = z
	c.offset = offset
	c.sprite = sprite
	c.speed = Cfg.MAX_SPEED * 0.3
	c.segment = t.find_segment(z)
	c.segment.cars.append(c)
	return c


func test_the_wake_of_a_semi() -> void:
	var t := flat_track()
	var me := _car(4000.0, Cfg.MAX_SPEED * 0.8)
	var nose := me.position + Cfg.PLAYER_Z
	var semi := _big(t, nose + 600.0, 0.25)
	me.x = 0.25
	check(Draft.in_wake(me, t, [me]), "right behind it")
	me.x = 0.75
	check(not Draft.in_wake(me, t, [me]), "a lane over")
	me.x = 0.25
	semi.z = nose + Draft.LENGTH + 50.0
	check(not Draft.in_wake(me, t, [me]), "too far back")
	semi.sprite = "sedan_beige"
	semi.z = nose + 600.0
	check(not Draft.in_wake(me, t, [me]), "a car is too small to hide behind")
	semi.sprite = "semi"
	me.speed = Cfg.MAX_SPEED * 0.3
	check(not Draft.in_wake(me, t, [me]), "no wake to speak of at low speed")


func test_the_wake_of_a_racer() -> void:
	var t := flat_track()
	var me := _car(4000.0, Cfg.MAX_SPEED * 0.8)
	var other := _car(4800.0, Cfg.MAX_SPEED * 0.8)
	check(Draft.in_wake(me, t, [me, other]), "behind a rival")
	check(not Draft.in_wake(other, t, [me, other]), "not in front of one")


func test_the_meter_fills_in_the_wake_and_empties_out_of_it() -> void:
	var me := _car(0.0, 0.0)
	for i in roundi(Draft.FILL_TIME / DT * 0.5):
		Draft.update(me, DT, true)
	near(me.draft, 0.5, 0.02, "half full after half the fill time")
	for i in roundi(Draft.DECAY_TIME / DT * 0.25):
		Draft.update(me, DT, false)
	near(me.draft, 0.25, 0.02, "empties out of the wake")
	for i in 600:
		Draft.update(me, DT, false)
	eq(me.draft, 0.0, "never below empty")


func test_a_full_meter_boosts_top_speed() -> void:
	var t := flat_track()
	var plain := _car(0.0, 0.0)
	var drafted := _car(0.0, 0.0)
	for i in roundi(Draft.FILL_TIME / DT) + 1:
		Draft.update(drafted, DT, true)
	check(drafted.draft_time > 0.0, "the boost starts")
	eq(drafted.draft, 0.0, "the meter resets")
	for i in roundi(Draft.BOOST_TIME / DT) - 5:
		plain.update(DT, input(1.0), t, true)
		drafted.update(DT, input(1.0), t, true)
		Draft.update(drafted, DT, false)
		plain.speed = maxf(plain.speed, plain.top_speed)
		drafted.speed = maxf(drafted.speed, plain.top_speed)
	check(drafted.speed > plain.speed * 1.03, "faster than top speed (%.0f vs %.0f)" % [drafted.speed, plain.speed])
	for i in 60 * 3:
		Draft.update(drafted, DT, false)
	eq(drafted.draft_time, 0.0, "the boost runs out")


func test_the_race_drafts() -> void:
	var r := race(false, true, 0, false)
	r.state = r.State.RACING
	r.countdown = 0.0
	var p: PlayerCar = r.player
	p.speed = Cfg.MAX_SPEED * 0.8
	for c: Traffic.TrafficCar in r.traffic.cars:
		c.segment.cars.erase(c)
	r.traffic.cars.clear()
	var semi := _big(r.track, p.position + Cfg.PLAYER_Z + 700.0, 0.0)
	semi.speed = p.speed
	r.traffic.cars.append(semi)
	drive(r, 30, input(0.5))
	check(p.draft > 0.2, "filling behind the semi (%.2f)" % p.draft)
