## The Grand Tour's ending (MP-16): the end card each standings place gets, and the finish of
## the last stage leading to the podium, the standings, the card and the credits.
extends TestSuite


static func menu_input(confirm := false, back := false) -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = confirm
	m.back_pressed = back
	return m


func _game() -> Node:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	return g


func test_each_standings_place_picks_its_end_card() -> void:
	var field := Rivals.COUNT + 1
	eq(TourFinale.end_card(1, field)["kind"], "champion", "first: the champion's card")
	eq(TourFinale.end_card(2, field)["kind"], "podium", "second: a podium card")
	eq(TourFinale.end_card(3, field)["kind"], "podium", "third: a podium card")
	for place in range(4, field + 1):
		eq(TourFinale.end_card(place, field)["kind"], "finisher", "%s: the rest's card" % Rivals.ordinal(place))
	var titles := {}
	for place in [1, 2, 5]:
		titles[TourFinale.end_card(place, field)["title"]] = true
	eq(titles.size(), 3, "three cards, each with its own title")
	check(TourFinale.end_card(2, field)["color"] != TourFinale.end_card(3, field)["color"], "silver and bronze")
	check(TourFinale.end_card(5, field)["sub"].to_lower().begins_with("5th"), "the card says the place")
	# From the standings: the player's place in them picks it
	for place in range(1, field + 1):
		var list := TourFinale.staged_standings(place)
		eq(list.size(), field, "the whole field")
		eq(TourFinale.place_of(list), place, "staged %s" % Rivals.ordinal(place))
	var t := Tour.new()
	t.award([Tour.YOU, "Dani Vance", "Rook Maddox"], 0)
	t.award(["Dani Vance", Tour.YOU, "Rook Maddox"], 0)
	t.award(["Dani Vance", "Rook Maddox", Tour.YOU], 0)
	eq(TourFinale.place_of(t.standings()), t.standing_of(Tour.YOU), "the tour's own standing")
	eq(TourFinale.end_card(TourFinale.place_of(t.standings()))["kind"], "podium", "second over the tour: the podium card")


func test_the_podium_shows_each_drivers_own_car() -> void:
	eq(TourFinale.car_of(Tour.YOU, "car_mesa"), "car_mesa", "the player's own car")
	for r: RivalProfile in RivalProfile.roster():
		eq(TourFinale.car_of(r.driver, "car_mesa"), r.car_id, r.driver + "'s car")


func test_the_pages_go_on_by_themselves_and_with_select() -> void:
	var f := TourFinale.new()
	f.standings = TourFinale.staged_standings(1)
	eq(f.page, TourFinale.Page.PODIUM, "opens on the podium")
	var ticks := 0
	while not f.advance(DT) and ticks < 10000:
		ticks += 1
	eq(f.page, TourFinale.Page.CARD, "the clock runs through the standings to the card")
	var total := 0.0
	for p: int in TourFinale.PAGE_TIME:
		total += TourFinale.PAGE_TIME[p]
	near(ticks * DT, total, 0.1, "a page at a time")
	f.page = TourFinale.Page.PODIUM
	f.page_time = 0.0
	check(not f.next_page_due(), "select on the podium")
	eq(f.page, TourFinale.Page.STANDINGS, "the standings")
	check(not f.next_page_due(), "select again")
	eq(f.page, TourFinale.Page.CARD, "the end card")
	check(f.next_page_due(), "and from the card, the credits")
	f.free()


func test_finishing_the_tour_leads_to_the_finale_then_the_credits() -> void:
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))
	var g := _game()
	g.mode_index = ModeSelect.Item.GRAND_TOUR
	var r := race(false, false, Stages.count() - 1)
	check(r.tour, "the last stage of a tour")
	g.race = r  # as the game's own race (start_race), finished by hand
	r.state = r.State.RACING
	r.countdown = 0.0
	r.race_time = 60.0
	r.next_checkpoint = r.checkpoint_distances.size()
	for car: RivalCar in r.rivals.cars:
		car.distance = r.finish_distance * 0.1
	r.player.distance = r.finish_distance + 1.0
	drive(r, 1)
	eq(r.after, r.After.TOUR_DONE, "the tour is done")
	eq(ResultsScreen.choice_label(ResultsScreen.Choice.CONTINUE, r.after), "FINALE", "the results lead on to the finale")
	check(r.banner_sub.contains("finale"), "and the banner says so: " + r.banner_sub)
	var standings: Array[Dictionary] = r.tour_state.standings()
	g._on_race_over()  # (CONTINUE on the results)
	eq(g.screen, g.Screen.FINALE, "the finale, not stage select")
	check(g.race == null, "the race dropped")
	var f: TourFinale = g.menu
	eq(f.standings, standings, "with the tour's standings")
	eq(f.car_id, "car_vega", "and the player's car")
	eq(TourFinale.place_of(f.standings), 1, "first on the podium")
	g.menu.handle(menu_input(true))
	eq(f.page, TourFinale.Page.STANDINGS, "select: the standings")
	g.menu.handle(menu_input(true))
	eq(f.page, TourFinale.Page.CARD, "the end card")
	g.menu.handle(menu_input(true))
	eq(g.screen, g.Screen.CREDITS, "then the credits")
	check(g.menu is CreditsScreen and g.menu.harbor, "over the harbor")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.TITLE, "and the title after them")
	TestSuite.use_scratch_save(runner.root.get_node("SaveData"))


func test_a_tour_that_ends_early_has_no_finale() -> void:
	var g := _game()
	g.mode_index = ModeSelect.Item.GRAND_TOUR
	g.stage_index = 0
	g.start_race()
	var r: Node = g.race
	TestSuite.ready_all(r)
	r.after = r.After.TOUR_OVER
	r.race_over.emit()
	eq(g.screen, g.Screen.STAGES, "a tour over without finishing: stage select as before")
	g.mode_index = ModeSelect.Item.SINGLE_RACE
	g.stage_index = Stages.count() - 1
	g.start_race()
	r = g.race
	TestSuite.ready_all(r)
	r.after = r.After.MENU
	r.race_over.emit()
	eq(g.screen, g.Screen.STAGES, "a Single Race on the last stage: no finale either")


func test_back_skips_to_the_credits() -> void:
	var g := _game()
	g.show_finale(TourFinale.staged_standings(4), "car_mesa")
	g.menu.handle(menu_input(false, true))
	eq(g.screen, g.Screen.CREDITS, "back: straight to the credits")
