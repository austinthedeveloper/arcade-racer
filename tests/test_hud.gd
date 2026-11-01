## The race HUD's layout and the plain functions behind its gauges (Hud).
extends TestSuite

const SCREEN := Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)


func _rect(name: String) -> Rect2:
	return Hud.layout()[name]


func test_every_element_on_screen_and_apart() -> void:
	var lay := Hud.layout()
	var names: Array = lay.keys()
	for n in names:
		check(SCREEN.encloses(lay[n]), "%s on screen: %s" % [n, lay[n]])
	for i in names.size():
		for j in range(i + 1, names.size()):
			check(not (lay[names[i]] as Rect2).intersects(lay[names[j]]), "%s clear of %s" % [names[i], names[j]])


func test_timer_rect() -> void:
	var r := _rect("timer")
	check(r.position.x < 10 and r.position.y < 10, "top left corner")
	check(r.size.x >= UiText.width("0:00.00", 20) + 10, "room for a Time Attack clock")
	check(r.size.y >= 36.0 * 1.25 + 10, "room for the low-time beat at its biggest")


func test_position_rect() -> void:
	var r := _rect("position")
	eq(r.position.x, _rect("timer").position.x, "lined up under the time")
	check(r.position.y > _rect("timer").end.y, "under it")
	check(r.size.x >= UiText.width("8", 38) + UiText.width("/8", 12) + 14, "the numeral and the field fit")


func test_progress_rect() -> void:
	var r := _rect("progress")
	near(r.get_center().x, Cfg.SCREEN_W / 2.0, 0.5, "centered")
	var bar := Hud.progress_bar(r)
	check(r.encloses(bar.grow_individual(0, 4, 0, 6)), "the markers above and the arrow below stay inside")
	check(_rect("stage").position.y >= r.end.y, "the stage name under it")


func test_stage_rect() -> void:
	var r := _rect("stage")
	for i in Stages.count():
		var s := "STAGE %d  %s" % [i + 1, Stages.stage_name(i).to_upper()]
		check(r.size.x >= UiText.width(s, 9), "fits: " + s)


func test_nitro_rect() -> void:
	var r := _rect("nitro")
	check(r.end.x > Cfg.SCREEN_W - 10 and r.position.y < 10, "top right")
	var slots := Cfg.NITRO_CHARGES + 2  # a car with more charges
	var gap := minf(18.0, (r.size.x - 12.0) / slots)
	check(r.position.x + 10 + (slots - 1) * gap + 7 <= r.end.x, "every flame inside")


func test_power_up_rect() -> void:
	var r := _rect("power_up")
	check(r.position.y >= _rect("nitro").end.y, "under the nitro")
	check(SCREEN.encloses(Rect2(r.end.x + 4, r.position.y, 3, r.size.y)), "its time bar too")


func test_feed_rect() -> void:
	var r := _rect("feed")
	check(r.size.y >= 3 * 16, "three bonuses")
	check(r.size.x >= UiText.width("CLEAN SECTION +3", 12), "the longest bonus fits")


func test_speedo_rect() -> void:
	var r := _rect("speedo")
	check(r.end.x > Cfg.SCREEN_W - 10 and r.end.y > Cfg.SCREEN_H - 10, "bottom right")
	check(r.size.x >= 88 and r.size.y >= 46 + 44, "the dial, rim and readout fit")


func test_slipstream_rect() -> void:
	var r := _rect("slipstream")
	check(r.end.y <= _rect("speedo").position.y and r.position.x == _rect("speedo").position.x, "over the speedometer")
	check(r.size.x > UiText.width("SLIPSTREAM", 8) + 20, "the label and a bar")


func test_device_rect() -> void:
	var r := _rect("device")
	check(r.position.x < 10 and r.end.y > Cfg.SCREEN_H - 10, "bottom left")
	check(r.size.x >= UiText.width("F1 input debug   F2 calibrate wheel   R restart", 8), "the key line fits")


func test_timer_pulses_under_the_low_time() -> void:
	eq(Hud.timer_pulse(Cfg.LOW_TIME + 5.0), 1.0, "steady with time left")
	eq(Hud.timer_pulse(Cfg.LOW_TIME + 0.01), 1.0, "steady just above the threshold")
	check(Hud.timer_pulse(Cfg.LOW_TIME - 0.02) > 1.2, "swells as the number drops under it")
	near(Hud.timer_pulse(5.4), 1.0, 0.001, "settled before the next")
	check(Hud.timer_pulse(4.98) > Hud.timer_pulse(4.8), "beats again on the next second")
	eq(Hud.timer_pulse(0.0), 1.0, "still at zero")


func test_one_low_time_threshold() -> void:
	eq(PowerUps.LOW_TIME, Cfg.LOW_TIME + PowerUps.LOW_TIME_LEAD, "power-ups lean to clocks from the shared one")
	check(PowerUps.LOW_TIME_LEAD > 0.0, "a little before the clock beats")


func test_dial_and_gears() -> void:
	near(Hud.dial_angle(0.0), PI * 0.75, 0.0001, "zero bottom left")
	near(fposmod(Hud.dial_angle(1.0), TAU), PI * 0.25, 0.0001, "top speed bottom right")
	near(fposmod(Hud.dial_angle(0.5), TAU), PI * 1.5, 0.0001, "halfway straight up")
	eq(Hud.dial_angle(2.0), Hud.dial_angle(1.0), "pinned at the end")
	eq(Hud.gear(0.0), 1, "first from rest")
	eq(Hud.gear(0.5), 3, "third at half speed")
	eq(Hud.gear(1.1), RaceAudio.GEARS.size() - 1, "top gear on nitro")


func test_flame_shape() -> void:
	var pts := Hud.flame(Vector2(50, 40), 12, 21)
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	near(box.end.y, 40.0, 0.01, "stands on its base")
	near(box.position.y, 19.0, 0.01, "as tall as asked")
	near(box.size.x, 12.0, 0.01, "as wide")
	check(Geometry2D.triangulate_polygon(pts).size() > 0, "a simple polygon")
