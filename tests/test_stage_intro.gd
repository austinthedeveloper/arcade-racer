## The stage intro card (PR-16): it slides in at the countdown's start and out before GO,
## clear of the countdown's number and the HUD, and says the stage, weather, length and best.
extends TestSuite


func test_the_card_slides_in_holds_and_slides_out_before_go() -> void:
	var home: Rect2 = Hud.layout()["intro"]
	var x := home.position.x
	check(not StageIntro.rect(-0.1, home).has_area(), "not before the countdown")
	check(not StageIntro.rect(0.0, home).has_area(), "off screen at the very start")
	var early := StageIntro.rect(0.1, home)
	check(early.has_area() and early.position.x > x, "sliding in from the right")
	eq(StageIntro.rect(StageIntro.SLIDE_IN, home).position, home.position, "in place")
	eq(StageIntro.rect(1.5, home).position.x, x, "held")
	var leaving := StageIntro.rect(StageIntro.OUT_AT + 0.1, home)
	check(leaving.has_area() and leaving.position.x > x, "sliding out")
	check(not StageIntro.rect(StageIntro.OUT_AT + StageIntro.SLIDE_OUT, home).has_area(), "gone")
	check(StageIntro.OUT_AT + StageIntro.SLIDE_OUT <= 3.0, "gone before GO")
	var last := INF
	for i in 8:
		var at := StageIntro.rect(StageIntro.SLIDE_IN * i / 7.0 + 0.001, home).position.x
		check(at <= last, "it only moves in")
		last = at


## Clear of the HUD, the rival cards (which share the countdown) and the touch buttons.
func test_the_card_keeps_clear_of_the_hud() -> void:
	for touch in [false, true]:
		var lay := Hud.layout(touch)
		var card := StageIntro.rect(1.0, lay["intro"])
		var label := "touch: " if touch else ""
		check(card.end.x <= Cfg.SCREEN_W and card.position.y >= 0.0, label + "on screen")
		for key in ["timer", "position", "progress", "stage", "nitro", "power_up", "speedo", "device", "subtitle", "slipstream", "cards", "radar"]:
			check(not card.intersects(lay[key]), label + "clear of the " + key)
		for r in Hud.card_rects(lay["cards"], Rivals.COUNT):
			check(not card.intersects(r), label + "clear of every rival card")
		check(card.position.x > Cfg.SCREEN_W / 2.0 + 30.0, label + "right of the countdown's number")
	var buttons := 0
	for b in TouchControls.RACE_BUTTONS:
		buttons += 1
		check(not StageIntro.rect(1.0, Hud.layout(true)["intro"]).intersects(b["rect"]), "clear of the touch " + b["id"])
	check(buttons > 0, "touch buttons read")


func test_the_card_says_the_stage_weather_length_and_best() -> void:
	var theme := Stages.theme(1)
	var t := Medals.times(1, Difficulty.Level.NORMAL)
	var length := 360000.0 / Cfg.DISPLAY_TOP_SPEED * Cfg.MAX_SPEED  # 100 miles
	var text := StageIntro.lines(1, false, theme, length, Settings.Units.MPH, t[1] - 0.5, Difficulty.Level.NORMAL)
	eq(text["stage"], "STAGE 2", "the stage number")
	eq(text["name"], "REDROCK CANYON", "the name")
	eq(text["info"], "CLEAR    100.0 MI", "weather and length")
	eq(text["best"], "BEST  " + Hud.clock_text(t[1] - 0.5), "the best time")
	eq(text["medal"], Medals.Medal.SILVER, "and its medal")
	var kph := StageIntro.lines(1, true, theme, length, Settings.Units.KPH, INF, Difficulty.Level.NORMAL)
	eq(kph["info"], "CLEAR    160.9 KM", "the units option")
	eq(kph["stage"], "STAGE 2   MIRRORED", "mirrored says so")
	eq([kph["best"], kph["medal"]], ["NO BEST TIME YET", Medals.Medal.NONE], "nothing raced")
	var free := StageIntro.lines(1, false, theme, length, Settings.Units.MPH, 80.0, Difficulty.Level.NORMAL, false)
	eq(free["best"], "", "Free Drive: no best line")


func test_weather_labels() -> void:
	eq(StageIntro.weather_label(Stages.theme(6)), "STORM", "Thunderhead")
	eq(StageIntro.weather_label(Stages.theme(0)), "CLEAR", "Palm Coast")
	eq(StageIntro.weather_label({"weather": {"rain": 0.5}}), "RAIN", "rain alone")


func test_the_race_counts_the_countdown_up() -> void:
	var r := race(true, false, 0, false)
	eq(r.countdown_elapsed(), 0.0, "zero at the start")
	drive(r, 60)
	check(absf(r.countdown_elapsed() - 1.0) < 0.05, "a second in")
	check(StageIntro.rect(r.countdown_elapsed(), Hud.layout()["intro"]).has_area(), "the card is up")
