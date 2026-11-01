## Shared UI pieces: MenuScreen's selection, MenuInput's let-go, UiText centring, the HUD
## clock, the Background strip, and every stage theme the Background reads.
extends TestSuite


func test_menu_screens_wrap_their_selection() -> void:
	var t := TitleScreen.new()
	eq(t.index, 0, "the title opens on START")
	var n := TitleScreen.items().size()
	eq(t.move(1), 1, "right: OPTIONS")
	t.index = n - 1
	eq(t.move(1), 0, "and wraps back to START")
	eq(t.move(-1), n - 1, "left wraps too")
	eq(t.move(n + 1), 0, "a big step wraps by the count")
	t.free()
	var m := MenuScreen.new()
	eq(m.choice_count(), 1, "a screen with nothing to choose has the one choice")
	eq(m.move(1), 0, "so moving stays put")
	m.free()


func test_lists_with_a_header_row_open_below_it() -> void:
	var o := OptionsScreen.new()
	eq(o.index, 1, "options open on the first option, not the page bar")
	o.move(-1)
	eq(o.index, 0, "up: the page bar")
	o.move(-1)
	eq(o.index, o.choice_count() - 1, "and wraps to the last row")
	o.free()
	var r := RemapScreen.new()
	eq(r.index, 1, "remap opens on the first action, not the device row")
	eq(r.choice_count(), DeviceProfile.REMAP_ACTIONS.size() + 3, "device, actions, reset, back")
	eq(r.move(-2), r.choice_count() - 1, "wraps to BACK")
	r.free()


func test_results_move_over_what_is_on_offer() -> void:
	var s := ResultsScreen.new()
	s.items = [ResultsScreen.Choice.CONTINUE, ResultsScreen.Choice.RETRY, ResultsScreen.Choice.QUIT] as Array[int]
	eq(s.choice_count(), 3, "three choices")
	eq(s.move(-1), 2, "left wraps to QUIT")
	eq(s.move(1), 0, "right wraps to CONTINUE")
	s.free()


func test_pause_menu_skips_options_both_ways() -> void:
	var p := PauseMenu.new()
	p.has_options = false
	p.index = 3  # QUIT
	eq(p.move(1), 0, "down from QUIT wraps to RESUME")
	eq(p.move(-1), 3, "up from RESUME wraps to QUIT")
	eq(p.move(-1), 1, "up from QUIT skips OPTIONS")
	p.free()


func test_menu_input_lets_go_under_release() -> void:
	var m := MenuInput.new()
	check(m.centred(), "nothing held")
	m.x = MenuInput.RELEASE
	check(not m.centred(), "steer at RELEASE is still held")
	m.x = MenuInput.RELEASE - 0.01
	m.y = -0.9
	check(not m.centred(), "up held")
	m.y = 0.1
	check(m.centred(), "both back under RELEASE")


func test_centred_text_straddles_the_point() -> void:
	var font := ThemeDB.fallback_font
	var s := "SELECT STAGE"
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	near(UiText.centered_x(320.0, s, 12), 320.0 - w / 2.0, 0.001, "half the width to the left")
	check(UiText.centered_x(320.0, s, 24) < UiText.centered_x(320.0, s, 12), "bigger text starts further left")
	eq(UiText.centered_x(100.0, "", 12), 100.0, "empty text starts at the point")


func test_clock_text() -> void:
	eq(Hud.clock_text(0.0), "0:00.00", "zero")
	eq(Hud.clock_text(9.5), "0:09.50", "seconds padded")
	eq(Hud.clock_text(75.25), "1:15.25", "a minute and more")
	eq(Hud.clock_text(600.0), "10:00.00", "ten minutes")


func test_background_strip_tiles_from_the_left() -> void:
	eq(Background.strip_x(0.0, 1280.0), 0.0, "no scroll: flush left")
	eq(Background.strip_x(0.25, 1280.0), -320.0, "a quarter round")
	eq(Background.strip_x(1.0, 1280.0), 0.0, "a full turn is back to the start")
	eq(Background.strip_x(-0.25, 1280.0), -960.0, "scrolling the other way stays left of 0")
	eq(Background.strip_x(0.3333, 100.0), -33.0, "a whole pixel")
	for o: float in [0.0, 0.1, 0.5, 0.99, 3.7, -2.2]:
		var x := Background.strip_x(o, 640.0)
		check(x <= 0.0 and x > -640.0 and x + 2 * 640.0 >= Cfg.SCREEN_W, "two copies cover the screen at %s" % o)


func test_every_stage_theme_has_what_the_background_draws() -> void:
	var bg := Background.new()
	bg.set_theme({"sky_top": Color.BLACK, "sky_bottom": Color.BLACK, "below_horizon": Color.BLACK})
	check(bg.textures.is_empty(), "no strips without a background")
	for i in Stages.count():
		var theme := Stages.build(i).theme
		for key in ["sky_top", "sky_bottom", "below_horizon"]:
			check(theme.get(key) is Color, "%s: %s" % [Stages.stage_name(i), key])
		bg.set_theme(theme)
		for layer: String in Background.LAYERS:
			var tex: Texture2D = bg.textures.get(layer)
			check(tex != null, "%s: the %s strip loads" % [Stages.stage_name(i), layer])
			if tex != null:
				check(tex.get_width() >= Cfg.SCREEN_W, "%s: the %s strip is at least a screen wide" % [Stages.stage_name(i), layer])
				# The sky covers the top of the screen even with the scenery dropped all the way
				if layer == "sky":
					check(Background.layer_bottom(layer, Background.HILL_MAX) - tex.get_height() <= 0.0,
						"%s: the sky reaches the top of the screen" % Stages.stage_name(i))
	bg.free()
