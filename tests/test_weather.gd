## Weather (WS-2): Thunderhead's rain, wet road and lightning. The strike timing is a plain
## seeded function; the flash follows the flash option; thunder plays a beat after a flash.
extends TestSuite

const THUNDERHEAD := 6  # into Stages


func _clean() -> void:
	TestSuite.use_scratch_settings(Settings)


func test_weather_is_a_theme_option() -> void:
	eq(Weather.of(Thunderhead.theme()), Weather.STORM, "Thunderhead storms")
	for i in Stages.count():
		if i != THUNDERHEAD:
			check(Weather.of(Stages.build(i).theme).is_empty(), "clear skies on " + Stages.stage_name(i))
	eq(Weather.drop_count({}), 0, "no rain without weather")
	eq(Weather.drop_count(Weather.STORM), Weather.RAIN_DROPS, "a storm's full rain")


func test_strikes_are_seeded() -> void:
	var a := Weather.strikes(7, 300.0)
	eq(a, Weather.strikes(7, 300.0), "the same seed, the same storm")
	check(a != Weather.strikes(8, 300.0), "another seed, another storm")
	check(a.size() >= int(300.0 / Weather.GAP_MAX), "strikes all the way through")
	check(a[0].x >= Weather.FIRST_MIN and a[0].x <= Weather.FIRST_MAX, "the first comes a few seconds in")
	for i in a.size():
		var s := a[i]
		check(s.z >= Weather.STRENGTH_MIN and s.z <= 1.0, "strength in range")
		var delay := s.y - s.x
		check(delay >= Weather.THUNDER_NEAR - 0.001 and delay <= Weather.THUNDER_FAR + 0.001, "thunder a beat later")
		if i > 0:
			var gap := s.x - a[i - 1].x
			check(gap >= Weather.GAP_MIN and gap <= Weather.GAP_MAX, "gap between strikes")
	check(Weather.thunder_delay(1.0) < Weather.thunder_delay(Weather.STRENGTH_MIN), "a close strike's thunder comes sooner")


func test_forced_strike_for_screenshots() -> void:
	var a := Weather.strikes(7, 60.0, 2.0)
	eq(a[0], Vector3(2.0, 2.0 + Weather.THUNDER_NEAR, 1.0), "a full strike, first in order")
	eq(a.size(), Weather.strikes(7, 60.0).size() + 1, "added to the storm")


func test_flash_flickers_and_fades() -> void:
	var storm: Array[Vector3] = [Vector3(10.0, 11.0, 1.0)]
	eq(Weather.flash_at(9.99, storm), 0.0, "dark before the strike")
	near(Weather.flash_at(10.0, storm), Weather.FLASH_ALPHA, 0.001, "full at the strike")
	check(Weather.flash_at(10.07, storm) < Weather.flash_at(10.12, storm), "a dip, then a second flicker")
	check(Weather.flash_at(10.3, storm) < Weather.flash_at(10.12, storm), "dying away")
	eq(Weather.flash_at(10.0 + Weather.FLASH_TIME, storm), 0.0, "gone")
	storm = [Vector3(10.0, 11.0, 0.5)]
	near(Weather.flash_at(10.0, storm), Weather.FLASH_ALPHA * 0.5, 0.001, "a far strike is fainter")


func test_thunder_once_a_beat_after() -> void:
	var storm := Weather.strikes(3, 120.0)
	var t := 0.0
	var rolls := 0
	var first := -1.0
	while t < 120.0:
		if Weather.thunder_between(t, t + DT, storm):
			rolls += 1
			if first < 0.0:
				first = t + DT
		t += DT
	eq(rolls, storm.size(), "one roll per strike")
	near(first, storm[0].y, DT, "at its time")
	check(first > storm[0].x, "after the flash")


func test_flash_option() -> void:
	_clean()
	near(Weather.shown_flash(0.7, Settings.flash_amount(1.0)), 0.7, 0.001, "as designed")
	Settings.flash = 5
	near(Weather.shown_flash(0.7, Settings.flash_amount(1.0)), 0.35, 0.001, "half")
	Settings.flash = 0
	eq(Weather.shown_flash(0.7, Settings.flash_amount(1.0)), 0.0, "0: no lightning flash")
	_clean()


func test_rain_streaks() -> void:
	var drop := Vector3(0.5, 0.5, 1.0)
	var still := Weather.rain_streak(drop, 1.0, 0.0)
	var fast := Weather.rain_streak(drop, 1.0, 1.0)
	check(still[1].y > still[0].y, "falls downward")
	check(fast[0].distance_to(fast[1]) > still[0].distance_to(still[1]), "longer at speed")
	var later := Weather.rain_streak(drop, 1.1, 0.0)
	check(later[1].y > still[1].y or later[1].y < still[0].y, "moves on (or wraps to the top)")
	for k in 50:
		var s := Weather.rain_streak(Vector3(randf(), randf(), 1.0), k * 0.37, 0.5)
		check(s[1].x >= 0.0 and s[1].x <= Cfg.SCREEN_W and s[1].y >= 0.0 and s[1].y <= Cfg.SCREEN_H + Weather.RAIN_LENGTH + Weather.RAIN_STRETCH, "on screen")
	var right := Weather.rain_streak(Vector3(0.9, 0.5, 1.0), 0.0, 1.0)
	var left := Weather.rain_streak(Vector3(0.1, 0.5, 1.0), 0.0, 1.0)
	check(right[1].x - right[0].x > left[1].x - left[0].x, "streaming out from the middle at speed")


func test_wet_road_catches_the_sky() -> void:
	var road := Color("#3c3e46")
	var sky := Color("#6d6f96")
	eq(Weather.wet_color(road, sky, 0.0, 1.0), road, "dry")
	eq(Weather.wet_color(road, sky, 0.35, 0.0), road, "under the car, as it is")
	check(Weather.wet_color(road, sky, 0.35, 0.8).b > Weather.wet_color(road, sky, 0.35, 0.2).b, "more sky farther off")


func test_fx_layer_runs_the_storm() -> void:
	_clean()
	var r := race(true, false, THUNDERHEAD, false)
	check(not r.fx.storm.is_empty(), "lightning on Thunderhead")
	r.fx.set_weather(r.track.theme, 1.0)
	drive(r, 59)
	eq(r.fx.flash, 0.0, "dark before")
	drive(r, 1)
	near(r.fx.flash, Weather.FLASH_ALPHA, 0.001, "the forced strike flashes")
	eq(r.fx.flash_share, 1.0, "shown as designed by default")
	Settings.flash = 0
	drive(r, 1)
	eq(r.fx.flash_share, 0.0, "the race passes on the slider")
	eq(Weather.shown_flash(r.fx.flash, r.fx.flash_share), 0.0, "the slider at 0 shows none")
	_clean()
	var thunder := run_until(r, func() -> bool: return r.fx.thunder, 200) + 1
	near(thunder * DT, Weather.THUNDER_NEAR, DT * 1.5, "thunder a beat later")
	var palm := race(true, false, 0, false)
	check(palm.fx.storm.is_empty(), "no lightning on Palm Coast")
	drive(palm, 30)
	eq(palm.fx.flash, 0.0, "nor any flash")
