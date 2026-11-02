## The stage intro card (PR-16): it slides in at the countdown's start and out before GO,
## clear of the countdown's number and the HUD, and says the stage, weather, length and best.
extends TestSuite


func test_the_card_slides_in_holds_and_slides_out_before_go() -> void:
	check(not StageIntro.rect(-0.1).has_area(), "not before the countdown")
	check(not StageIntro.rect(0.0).has_area(), "off screen at the very start")
	var early := StageIntro.rect(0.1)
	check(early.has_area() and early.position.x < StageIntro.X, "sliding in")
	eq(StageIntro.rect(StageIntro.SLIDE_IN).position.x, StageIntro.X, "in place")
	eq(StageIntro.rect(1.5).position.x, StageIntro.X, "held")
	var leaving := StageIntro.rect(StageIntro.OUT_AT + 0.1)
	check(leaving.has_area() and leaving.position.x < StageIntro.X, "sliding out")
	check(not StageIntro.rect(StageIntro.OUT_AT + StageIntro.SLIDE_OUT).has_area(), "gone")
	check(StageIntro.OUT_AT + StageIntro.SLIDE_OUT <= 3.0, "gone before GO")
	var last := -INF
	for i in 8:
		var x := StageIntro.rect(StageIntro.SLIDE_IN * i / 7.0 + 0.001).position.x
		check(x >= last, "it only moves in")
		last = x


func test_the_card_keeps_clear_of_the_hud() -> void:
	var card := StageIntro.rect(1.0)
	var lay := Hud.layout()
	for key in ["timer", "position", "progress", "speedo", "device", "subtitle", "slipstream"]:
		check(not card.intersects(lay[key]), "clear of the " + key)
	check(card.position.y > 135.0, "under the countdown's number")
	check(card.end.x < Cfg.SCREEN_W / 2.0 - 40.0, "left of the car")


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
	check(StageIntro.rect(r.countdown_elapsed()).has_area(), "the card is up")
