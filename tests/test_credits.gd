## The credits (PR-23): what they list, how they roll, and where they come from and go.
extends TestSuite


static func menu_input(confirm := false, back := false, dir := 0) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	m.left_pressed = dir < 0
	m.right_pressed = dir > 0
	return m


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	return g


## The bold names in README.md's Credits section, under its Tools and Fonts headings.
static func readme_names() -> Array[String]:
	var src := FileAccess.get_file_as_string("res://README.md")
	var at := src.find("\n## Credits")
	var out: Array[String] = []
	if at < 0:
		return out
	var section := src.substr(at + 1)
	var end := section.find("\n## ", 3)
	if end > 0:
		section = section.substr(0, end)
	var bold := RegEx.create_from_string("\\*\\*([^*]+)\\*\\*")
	var listed := false
	for line in section.split("\n"):
		if line.begins_with("### "):
			listed = line.contains("Tools") or line.contains("Fonts")
		elif listed and line.begins_with("- "):
			for m in bold.search_all(line):
				out.append(m.get_string(1))
	return out


func test_the_credits_list_every_tool_and_font_the_readme_names() -> void:
	var names := readme_names()
	check(names.size() >= 8, "the README's Credits names its tools and fonts (%d)" % names.size())
	for want in ["Godot Engine", "Python", "Blender", "Open Sans SemiBold"]:
		check(want in names, "the README names " + want)
	var credits := CreditsScreen.text()
	for n in names:
		check(credits.contains(n), "the credits list " + n)


func test_the_credits_say_who_made_it_and_how_the_sound_is_made() -> void:
	var credits := CreditsScreen.text()
	check(credits.contains("Austin Stewart"), "who made it")
	check(credits.contains("Claude"), "with Claude")
	check(credits.contains("synthesized") or credits.contains("Synthesized"), "the synthesized audio note")
	check(credits.contains("no recordings"), "and no recordings")
	for i in Radio.count():
		check(credits.contains(Radio.station_name(i)), "the station " + Radio.station_name(i))
	# Every font, with its license on the line under it
	var lines: Array = CreditsScreen.LINES
	for i in lines.size():
		if lines[i][1] == "Open Sans SemiBold":
			check(i + 1 < lines.size() and lines[i + 1][1].contains("Open Font License"), "the font's license under it")
	for line: Array in lines:
		check(CreditsScreen.STYLE.has(line[0]), "a known kind of line: " + line[0])


## The font the credits name is the one the game draws with.
func test_the_font_credited_is_the_one_drawn() -> void:
	var font := ThemeDB.fallback_font
	var named := font.get_font_name() if font != null else ""
	check(named == "" or "Open Sans SemiBold".begins_with(named) or named.begins_with("Open Sans"),
		"the fallback font is Open Sans (%s)" % named)


func test_the_roll_scrolls_by_itself_and_faster_with_a_button() -> void:
	near(CreditsScreen.step(1.0, false), CreditsScreen.SPEED, 0.001, "on its own")
	near(CreditsScreen.step(1.0, true), CreditsScreen.SPEED * CreditsScreen.FAST, 0.001, "a button held: faster")
	check(CreditsScreen.FAST > 2.0, "a lot faster")
	var c := CreditsScreen.new()
	var slow := 0
	while not c.advance(DT, false) and slow < 100000:
		slow += 1
	c.scroll = 0.0
	var quick := 0
	while not c.advance(DT, true) and quick < 100000:
		quick += 1
	check(slow > 0 and quick < slow / 4, "held, it ends sooner (%d vs %d ticks)" % [quick, slow])
	check(slow * DT < 150.0 and slow * DT > 30.0, "on its own it rolls about a minute (%.0f s)" % (slow * DT))
	c.free()


func test_credits_from_the_title_and_back() -> void:
	var g := _game()
	var at := TitleScreen.items().find("CREDITS")
	check(at >= 0, "CREDITS on the title")
	if not OS.has_feature("web"):
		eq(TitleScreen.items()[-1], "QUIT", "QUIT stays last")
	g.menu.news = []  # (what's new may be up after another suite's version change)
	g.menu.index = at
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.CREDITS, "CREDITS opens them")
	check(g.menu is CreditsScreen and not g.menu.harbor, "over the title's sunset")
	var c: CreditsScreen = g.menu
	g.menu.handle(menu_input())
	check(c.scroll > 0.0, "it rolls")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "back: the title")
	eq(g.menu.index, at, "on CREDITS")
	# Left to roll, it ends on the title too
	g.show_credits()
	c = g.menu
	c.scroll = CreditsScreen.scroll_end() + CreditsScreen.END_PAUSE * CreditsScreen.SPEED
	g.menu.handle(menu_input())
	eq(g.screen, g.Screen.TITLE, "the end of the roll: the title")


func test_the_title_pills_fit_across() -> void:
	var n := TitleScreen.items(false).size()
	check(TitleScreen.pill_step(n) * n <= Cfg.SCREEN_W - 16.0 + 0.01, "%d pills fit" % n)
	eq(TitleScreen.pill_step(5), TitleScreen.PILL_STEP, "five still at full width")
	var pill_w := TitleScreen.PILL.x - (TitleScreen.PILL_STEP - TitleScreen.pill_step(n))
	for item in TitleScreen.items(false):
		var size := TitleScreen.label_size(item, pill_w)
		check(UiText.width(item, size) < pill_w - 6, "%s fits its pill at %d px" % [item, size])
	eq(TitleScreen.label_size("START", pill_w), 14, "a short label keeps 14 px")


func test_every_line_sits_on_the_dark_column() -> void:
	# AC-17: small grey lines were lost over the sea; each line is inside the column
	var col := CreditsScreen.column()
	check(col.size.x < Cfg.SCREEN_W, "narrower than the screen")
	for line: Array in CreditsScreen.LINES:
		var st: Dictionary = CreditsScreen.STYLE[line[0]]
		if st["size"] > 0:
			var lw := UiText.width(line[1], st["size"])
			check(lw <= col.size.x - CreditsScreen.COLUMN_MARGIN, line[1] + " fits the column")
