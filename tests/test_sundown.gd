## Sundown across the tour (WS-16): an hour per stage in its theme, a Grand Tour that runs the
## clock from the afternoon to night on Skyline, a tint function for the light, longer shadows
## while the sun is low. Single races keep each stage's own hour.
extends TestSuite

const PALM := 0
const NEON := 2
const HARVEST := 5
const SKYLINE := 7


func test_every_stage_has_its_hour() -> void:
	for i in Stages.count():
		var theme := Stages.theme(i)
		check(theme.has("hour"), Stages.stage_name(i) + " has an hour")
		var h := Sundown.own_hour(theme)
		check(h >= 0.0 and h < 24.0, Stages.stage_name(i) + "'s hour is a time of day")
	check(Sundown.own_hour(Stages.theme(NEON)) > 21.0, "Neon Strip is a night stage")
	eq(Sundown.own_hour({}), Sundown.DEFAULT_HOUR, "a theme without one: the afternoon")


func test_the_tour_runs_from_afternoon_to_night() -> void:
	var n := Stages.count()
	eq(Sundown.tour_hour(0, n), Tuning.v("world/tour_start_hour"), "starts at tour_start_hour")
	eq(Sundown.tour_hour(n - 1, n), Tuning.v("world/tour_end_hour"), "ends at tour_end_hour")
	check(Sundown.tour_hour(0, n) >= 12.0 and Sundown.tour_hour(0, n) < 17.0, "the first stage in the afternoon")
	for i in range(1, n):
		check(Sundown.tour_hour(i, n) > Sundown.tour_hour(i - 1, n), "the sun drops stage by stage (%d)" % i)
	check(Sundown.light(Sundown.tour_hour(SKYLINE, n)).get_luminance() < 0.5, "night on Skyline")
	eq(Sundown.shown_hour(Stages.theme(HARVEST), HARVEST, n, false), Sundown.own_hour(Stages.theme(HARVEST)), "a single race: the stage's own hour")
	eq(Sundown.shown_hour(Stages.theme(HARVEST), HARVEST, n, true), Sundown.tour_hour(HARVEST, n), "a tour: the tour's")


func test_tint_function() -> void:
	eq(Sundown.tint(18.0, 18.0), Color.WHITE, "at its own hour: as drawn")
	eq(Sundown.tint(22.5, 17.0), Color.WHITE, "shown earlier than its hour: as drawn, never brighter")
	var dusk := Sundown.tint(15.0, 19.5)
	var night := Sundown.tint(15.0, 22.0)
	check(dusk.get_luminance() < 1.0 and night.get_luminance() < dusk.get_luminance(), "darker as the sun drops")
	check(dusk.r > dusk.b, "the low sun is warm")
	check(night.b > night.r, "the night is blue")
	for h in range(0, 24):
		var t := Sundown.tint(12.0, float(h))
		check(t.r <= 1.0 and t.g <= 1.0 and t.b <= 1.0 and t.r > 0.0, "a tint, not a light (%d h)" % h)
	eq(Sundown.tint(15.0, 22.0, 0.0), Color.WHITE, "strength 0: none")
	near(Sundown.tint(15.0, 22.0, 0.5).r, lerpf(1.0, night.r, 0.5), 0.0001, "strength: part of the way")
	near(Sundown.light(24.0).r, Sundown.light(0.0).r, 0.0001, "the clock wraps")
	check(Sundown.darkness(night) > Sundown.darkness(dusk), "darkness rises with it")
	eq(Sundown.darkness(Color.WHITE), 0.0, "none as drawn")


func test_theme_at_tints_the_colors_only() -> void:
	var theme := Stages.theme(HARVEST)
	var same := Sundown.theme_at(theme, Sundown.own_hour(theme))
	for key: String in Sundown.TINTED:
		eq(same[key], theme[key], "its own hour: %s as drawn" % key)
	var late := Sundown.theme_at(theme, 21.0)
	check((late["sky_top"] as Color).get_luminance() < (theme["sky_top"] as Color).get_luminance(), "the sky darker")
	check((late["road"][0] as Color).get_luminance() < (theme["road"][0] as Color).get_luminance(), "the road too")
	eq(late["clock"], theme["clock"], "the clock untouched")
	eq(late["background"], theme["background"], "everything else as it was")
	eq(late["hour_shown"], 21.0, "the hour it shows")
	eq(Sundown.light_of(late), late["light"], "and its light")
	eq(Sundown.light_of(theme), Color.WHITE, "an untinted theme's light is white")
	check(RoadRenderer.sprite_light(late).get_luminance() > Sundown.light_of(late).get_luminance(), "the sprites take a lighter tint")
	var thunder := Sundown.theme_at(Thunderhead.theme(), 21.0)
	eq(thunder["weather"], Weather.STORM, "the weather kept")


func test_shadows_grow_with_the_sun_low() -> void:
	eq(Sundown.shadow_length(12.0), 1.0, "noon: the plain shadow")
	check(Sundown.shadow_length(18.0) > 1.5, "the golden hour: long")
	near(Sundown.shadow_length(Sundown.SHADOW_LONGEST), Tuning.v("world/shadow_stretch"), 0.001, "longest just before sunset")
	eq(Sundown.shadow_length(22.0), 1.0, "night: back under the car")
	var plain := CarSprites.shadow_rect(Vector2(320, 300), 100.0)
	var long := CarSprites.shadow_rect(Vector2(320, 300), 100.0, 2.5)
	eq(long.position, plain.position, "from the same place")
	near(long.size.y, plain.size.y * 2.5, 0.001, "two and a half times as long")
	eq(long.size.x, plain.size.x, "as wide")


func test_apply_to_a_track() -> void:
	var n := Stages.count()
	var t := Stages.build(HARVEST)
	var drawn := t.theme.duplicate()
	var next_drawn := t.next_theme.duplicate()
	eq(Sundown.apply(t, HARVEST, n, false), Sundown.own_hour(drawn), "a single race: its own hour")
	eq(t.theme["sky_top"], drawn["sky_top"], "as drawn")
	eq(t.next_theme["sky_top"], next_drawn["sky_top"], "the next stage too")
	var tour := Stages.build(HARVEST)
	eq(Sundown.apply(tour, HARVEST, n, true), Sundown.tour_hour(HARVEST, n), "a tour: the tour's hour")
	check(tour.theme["sky_top"] != drawn["sky_top"], "tinted for it")
	eq(tour.next_theme["hour_shown"], Sundown.tour_hour(HARVEST + 1, n), "the next stage at its tour hour")
	eq(tour.flow[0]["sky_top"], tour.theme["sky_top"], "the handover starts from the tinted palette")
	check((tour.flow[-1]["sky_top"] as Color).is_equal_approx(tour.next_theme["sky_top"]), "and ends at the next one's")
	var last := Stages.build(SKYLINE)
	Sundown.apply(last, SKYLINE, n, true)
	check(last.next_theme.is_empty(), "the last stage has none after it")


## In a race: a Grand Tour shows Harvest at the tour's hour, a single race at its own, and
## Palm Coast's tour hour is its own (the tour starts as the stage was drawn).
func test_a_race_shows_its_hour() -> void:
	var tour := race(false, false, HARVEST, false)
	check(tour.tour, "a race is a tour unless told")
	eq(tour.hour, Sundown.tour_hour(HARVEST, Stages.count()), "the tour's hour")
	check(Sundown.light_of(tour.track.theme) != Color.WHITE, "Harvest tinted toward dusk")
	near(CarSprites.shadow_length, Sundown.shadow_length(tour.hour), 0.0001, "the shadows for it")
	var neon := race(false, false, NEON, false)
	eq(Sundown.lit_hour(neon.track.theme), Sundown.own_hour(Stages.theme(NEON)), "Neon in a tour: still night")
	eq(CarSprites.shadow_length, 1.0, "no long shadows at night")
	var single := race(false, false, HARVEST, false)
	single.tour = false
	single.start_race()
	eq(single.hour, Sundown.own_hour(Stages.theme(HARVEST)), "a single race: its own hour")
	eq(Sundown.light_of(single.track.theme), Color.WHITE, "as drawn")
	var palm := race(false, false, PALM, false)
	eq(Sundown.light_of(palm.track.theme), Color.WHITE, "Palm Coast in a tour: as drawn")
	CarSprites.shadow_length = 1.0
