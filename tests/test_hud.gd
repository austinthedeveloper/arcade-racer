## The race HUD's layout and the plain functions behind its gauges (Hud).
extends TestSuite

const SCREEN := Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)


func _rect(name: String) -> Rect2:
	return Hud.layout()[name]


## Elements never up at the same time may share space: the stage intro card is gone before GO,
## and the bonus feed only fills after it.
const NEVER_TOGETHER := [["feed", "intro"]]


func test_every_element_on_screen_and_apart() -> void:
	var lay := Hud.layout()
	var names: Array = lay.keys()
	for n in names:
		check(SCREEN.encloses(lay[n]), "%s on screen: %s" % [n, lay[n]])
	for i in names.size():
		for j in range(i + 1, names.size()):
			if [names[i], names[j]] in NEVER_TOGETHER or [names[j], names[i]] in NEVER_TOGETHER:
				continue
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
	var longest_chain := Scoring.chain_label(10) + " +%d" % Scoring.chain_points(10)
	check(r.size.x >= UiText.width(longest_chain, 12), "a long near-miss chain fits: " + longest_chain)


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
	check(r.size.x >= UiText.width(Hud.keys_hint(false), 8) + 4, "the key line fits")


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


func test_the_tach_shows_the_manual_gear() -> void:
	var p := PlayerCar.new()
	p.reset()
	p.speed = Cfg.MAX_SPEED * 0.5
	eq(p.shown_gear(), Hud.gear(0.5), "automatic: the gear the speed is in")
	p.manual = true
	eq(p.shown_gear(), 1, "manual: the gear it's in, here 1st")
	p.gear = 4
	eq(p.shown_gear(), 4, "4th")


func test_flame_shape() -> void:
	var pts := Hud.flame(Vector2(50, 40), 12, 21)
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	near(box.end.y, 40.0, 0.01, "stands on its base")
	near(box.position.y, 19.0, 0.01, "as tall as asked")
	near(box.size.x, 12.0, 0.01, "as wide")
	check(Geometry2D.triangulate_polygon(pts).size() > 0, "a simple polygon")


## The HUD's text sizes as written in the source: the size argument (the third) of every
## _text, _text_centered and UiText.draw call, where it's a number.
func _literal_sizes(path: String) -> Array[int]:
	var re := RegEx.create_from_string(r"(?:^|[^\w.])(?:_text|_text_centered|UiText\.draw|UiText\.draw_centered)\(")
	var out: Array[int] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("func ") or line.strip_edges().begins_with("#"):
			continue
		for m in re.search_all(line):
			var args := _top_level_args(line.substr(m.get_end()))
			if args.size() >= 4 and args[2].strip_edges().is_valid_int():
				out.append(int(args[2]))
	return out


## The arguments of a call, from just after its "(", split at the commas outside brackets.
func _top_level_args(rest: String) -> Array[String]:
	var args: Array[String] = []
	var depth := 0
	var cur := ""
	for ch in rest:
		if ch == "(" or ch == "[":
			depth += 1
		elif ch == ")" or ch == "]":
			if depth == 0:
				args.append(cur)
				return args
			depth -= 1
		elif ch == "," and depth == 0:
			args.append(cur)
			cur = ""
			continue
		cur += ch
	return args


func test_no_text_under_the_minimum() -> void:
	# PR-14: nothing under 8 px at 640x360 (the MPH label was 7)
	eq(UiText.MIN_SIZE, 8, "8 px")
	for path in ["res://scripts/ui/hud.gd", "res://scripts/ui/results_screen.gd"]:
		var sizes := _literal_sizes(path)
		check(sizes.size() > 10, "found the text in %s (%d)" % [path, sizes.size()])
		for size in sizes:
			check(size >= UiText.MIN_SIZE, "%s draws %d px text" % [path.get_file(), size])
	for kind in Hud.BURSTS:
		check(Hud.BURSTS[kind]["size"] >= UiText.MIN_SIZE, "burst %s" % Callouts.TEXT[kind])
	check(Hud.LINE2_SIZE >= UiText.MIN_SIZE and Hud.SUB_SIZE >= UiText.MIN_SIZE, "a burst's other lines")
	eq(Hud.text_size(7), UiText.MIN_SIZE, "a smaller size is drawn at the minimum")
	eq(Hud.text_size(12), 12, "bigger ones as asked")


func test_rival_cards_layout() -> void:
	# RC-18: a card per rival before GO, in its own corner of the screen
	for touch in [false, true]:
		var lay := Hud.layout(touch)
		var area: Rect2 = lay["cards"]
		check(SCREEN.encloses(area), "cards on screen (touch %s)" % touch)
		for n in lay:
			if n != "cards" and n != "radar":  # (the radar only shows after GO)
				check(not area.intersects(lay[n]), "cards clear of %s (touch %s)" % [n, touch])
		var rects := Hud.card_rects(area, Rivals.COUNT)
		eq(rects.size(), Rivals.COUNT, "one each")
		for i in rects.size():
			check(area.encloses(rects[i]), "card %d inside (touch %s): %s" % [i, touch, rects[i]])
			for j in range(i + 1, rects.size()):
				check(not rects[i].intersects(rects[j]), "cards %d and %d apart" % [i, j])
	check(Hud.layout()["cards"].position.y > Hud.layout()["position"].end.y, "under the place")


func test_rival_card_parts_fit() -> void:
	var card := Rect2(Vector2(6, 120), Hud.CARD_SIZE)
	var parts := Hud.card_parts(card)
	var slot: Rect2 = parts["portrait"]
	check(card.encloses(slot), "the portrait slot inside")
	check(slot.size.x >= 16 and slot.size.y >= 16, "room for a portrait (CP-13)")
	check((parts["name"] as Vector2).x > slot.end.x, "the words right of it")
	for prof in RivalProfile.roster():
		var words := Hud.card_text(prof, false)
		check(UiText.width(words["name"], 9) <= parts["text_width"], "fits: " + words["name"])
		var line: String = words["car"] + "  " + words["style"]
		check(UiText.width(line, 8) <= parts["text_width"], "fits: " + line)
		check(words["initials"].length() == 2, "initials: " + words["initials"])
	var big := Hud.card_text(RivalProfile.roster()[4], false)
	eq([big["name"], big["style"], big["initials"]], ["Big Jo Harlan", "AGGRESSIVE", "BJ"], "Big Jo's card")
	eq(big["car"], String(Cars.find("car_mesa")["name"]).to_upper(), "his car")
	eq(Hud.card_text(RivalProfile.roster()[0], true)["style"], "ONLINE", "an online player")


func test_radar_arrows() -> void:
	var area: Rect2 = Hud.layout()["radar"]
	var speed := 5000.0
	var arrows := Hud.radar(area, 10000.0, 0.0, speed, [
		[10000.0 + speed * 0.5, 0.0],  # half a second ahead, in line with you
		[10000.0 - speed * 0.25, -1.0],  # a quarter behind, on the left
		[10000.0 + speed * 1.5, 0.0],  # too far ahead
		[10000.0 - speed * 3.0, 0.5],  # too far behind
	])
	eq(arrows.size(), 2, "the two within a second")
	var ahead: Dictionary = arrows[0]
	var behind: Dictionary = arrows[1]
	check(ahead["ahead"] and not behind["ahead"], "one ahead, one behind, nearest last")
	near(ahead["at"].x, area.get_center().x, 0.5, "in line: in the middle")
	check(behind["at"].x < area.get_center().x, "the one on the left to the left")
	near(ahead["near"], 0.5, 0.001, "half a second: half near")
	for a in arrows:
		var box := Rect2(a["at"] - Hud.RADAR_ARROW / 2.0, Hud.RADAR_ARROW)
		check(area.grow(0.5).encloses(box), "the arrow inside the strip")
	var far_left := Hud.radar(area, 0.0, 1.0, speed, [[0.0, -3.0]])
	check(area.grow(0.5).encloses(Rect2(far_left[0]["at"] - Hud.RADAR_ARROW / 2.0, Hud.RADAR_ARROW)), "pinned at the edge")
	eq(Hud.radar(area, 0.0, 0.0, 0.0, [[50.0, 0.0]]).size(), 0, "standing still, only a car alongside counts")
	var up := Hud.radar_arrow(Vector2(100, 100), true)
	var down := Hud.radar_arrow(Vector2(100, 100), false)
	check(up[0].y < up[1].y and down[2].y > down[0].y, "up for ahead, down for behind")
	check(area.end.y < 215.0, "over the car's roof")
