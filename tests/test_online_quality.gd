## Connection quality online (ON-12): the round trip through the relay, the HUD dot's colors
## for it, and the region picker that shows only when the relay lists regions.
extends TestSuite

var _t := [0.0]  # the sessions' clock (OnlineSession.clock), seconds, moved on by `later`


## Moves the made-up clock on `seconds`.
func later(seconds: float) -> void:
	_t[0] += seconds


func on_test_clock(s: OnlineSession) -> OnlineSession:
	s.clock = func() -> float: return _t[0]
	return s


func room(guests := 1) -> Array:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var out: Array = [on_test_clock(OnlineSession.hosting_on(h, "car_vega"))]
	for i in guests:
		var g := LoopLink.new(relay)
		g.join(h.room)
		out.append(on_test_clock(OnlineSession.joining_on(g, ["car_mesa", "car_kestrel"][i])))
	settle(out)
	return out


static func settle(sessions: Array, dt := 0.0) -> void:
	for i in 4:
		for s: OnlineSession in sessions:
			s.poll(dt if i == 0 else 0.0)


func test_the_dots_color_thresholds() -> void:
	eq(OnlineSession.quality(-1.0), OnlineSession.Quality.UNKNOWN, "nothing back yet")
	eq(OnlineSession.quality(0.0), OnlineSession.Quality.GOOD, "0 ms: green")
	eq(OnlineSession.quality(OnlineSession.GOOD_MS - 0.5), OnlineSession.Quality.GOOD, "just under GOOD_MS: green")
	eq(OnlineSession.quality(OnlineSession.GOOD_MS), OnlineSession.Quality.FAIR, "GOOD_MS: amber")
	eq(OnlineSession.quality(OnlineSession.FAIR_MS - 0.5), OnlineSession.Quality.FAIR, "just under FAIR_MS: amber")
	eq(OnlineSession.quality(OnlineSession.FAIR_MS), OnlineSession.Quality.POOR, "FAIR_MS: red")
	eq(OnlineSession.quality(5000.0), OnlineSession.Quality.POOR, "far over: red")
	eq([OnlineSession.GOOD_MS, OnlineSession.FAIR_MS], [150, 300], "green under 150 ms, amber under 300")
	eq(Hud.net_color(OnlineSession.Quality.GOOD), Hud.PALETTE["net_good"], "green")
	eq(Hud.net_color(OnlineSession.Quality.FAIR), Hud.PALETTE["net_fair"], "amber")
	eq(Hud.net_color(OnlineSession.Quality.POOR), Hud.PALETTE["net_poor"], "red")
	eq(Hud.net_color(OnlineSession.Quality.UNKNOWN), Hud.PALETTE["net_unknown"], "grey")
	check(Hud.net_color(OnlineSession.Quality.GOOD).g > Hud.net_color(OnlineSession.Quality.GOOD).r, "green is green")
	check(Hud.net_color(OnlineSession.Quality.POOR).r > 0.6 and Hud.net_color(OnlineSession.Quality.POOR).g < 0.3, "red is red")


func test_the_round_trip_is_measured_both_ways() -> void:
	var relay := LoopLink.Relay.new()
	var h := LoopLink.new(relay)
	h.host()
	var lone := on_test_clock(OnlineSession.hosting_on(h, "car_vega"))
	lone.poll(0.0)
	eq(lone.round_trip_ms(), -1.0, "nobody to answer: nothing yet")
	var r := room(1)
	# A ping out, the clock running on before the answer gets back
	later(OnlineSession.PING_EVERY)
	r[0].poll(0.0)
	r[1].poll(0.0)  # (the guest answers and sends its own)
	later(0.08)
	r[0].poll(0.0)  # 80 ms later the host has the guest's answer
	near(r[0].round_trip_ms(), 80.0, 0.5, "the host's round trip to its guest")
	later(0.04)
	r[1].poll(0.0)
	near(r[1].round_trip_ms(), 120.0, 0.5, "the guest's to the host")
	eq(OnlineSession.quality(r[0].round_trip_ms()), OnlineSession.Quality.GOOD, "green")


func test_a_room_gone_quiet_turns_red() -> void:
	var r := room(1)
	later(OnlineSession.PING_EVERY)
	settle(r)
	check(r[0].round_trip_ms() >= 0.0 and r[0].round_trip_ms() < OnlineSession.GOOD_MS, "answering: green")
	r[1].link.lag_ms = 600000  # the guest stops hearing anything
	for i in 5:
		later(1.0)
		r[0].poll(0.0)
		r[1].poll(0.0)
	check(r[0].round_trip_ms() >= OnlineSession.STALE * 1000.0, "quiet for seconds: %f" % r[0].round_trip_ms())
	eq(OnlineSession.quality(r[0].round_trip_ms()), OnlineSession.Quality.POOR, "red")


func test_the_host_shows_its_worst_guest_and_forgets_one_that_left() -> void:
	var r := room(2)
	later(OnlineSession.PING_EVERY)
	r[0].poll(0.0)
	r[1].poll(0.0)
	later(0.05)
	r[0].poll(0.0)
	r[2].poll(0.0)
	later(0.2)
	r[0].poll(0.0)
	near(r[0].round_trip_ms(), 250.0, 0.5, "the slower guest's")
	r[2].leave()
	r[0].poll(0.0)
	near(r[0].round_trip_ms(), 50.0, 0.5, "P3 gone: P2's")


func test_an_older_game_without_pings_is_no_trouble() -> void:
	var r := room(1)
	var before: float = r[1].round_trip_ms()
	r[0]._host_got(0, [OnlineSession.PING])  # (no time: ignored)
	r[1]._guest_got(["SOMETHING NEW", 1, 2])  # an op it doesn't know
	r[1]._guest_got([OnlineSession.PONG])
	eq(r[1].error, "", "nothing breaks")
	eq(r[1].round_trip_ms(), before, "and no round trip made up")


func test_regions_parse_from_the_relays_list() -> void:
	var body := JSON.stringify({"regions": [{"name": "us east", "url": "wss://a.example"}, {"name": "", "url": "wss://b"},
		{"name": "EU", "url": "http://c"}, {"name": "Asia", "url": "ws://d:8080"}, "junk"]})
	var got := RelayLink.parse_regions(body)
	eq(got, [{"name": "US EAST", "url": "wss://a.example"}, {"name": "ASIA", "url": "ws://d:8080"}], "named ws/wss ones only")
	eq(RelayLink.parse_regions("Not Found"), [], "a 404's page: none")
	eq(RelayLink.parse_regions("{}"), [], "no list: none")
	eq(RelayLink.regions_url("wss://relay.example"), "https://relay.example/v1/regions", "over https")
	eq(RelayLink.regions_url("ws://127.0.0.1:8080/"), "http://127.0.0.1:8080/v1/regions", "a local one")


func test_the_region_picker_shows_only_when_the_relay_lists_some() -> void:
	var keep := RelayLink.chosen
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g._ready()
	_nodes.append(g)
	g.show_online()
	var o: OnlineScreen = g.menu
	var none: Array[Dictionary] = []
	o.set_regions(none)
	check(not o.shows_regions(), "no regions: no picker")
	var down := MenuInput.new()
	down.down_pressed = true
	o.handle(down)
	check(not o.on_region, "and nothing to move to")
	var one: Array[Dictionary] = [{"name": "US EAST", "url": "wss://a"}]
	o.set_regions(one)
	check(not o.shows_regions(), "one region: nothing to pick")
	var two: Array[Dictionary] = [{"name": "US EAST", "url": "wss://a"}, {"name": "EUROPE", "url": "wss://b"}]
	o.set_regions(two)
	check(o.shows_regions(), "two: the picker")
	o.handle(down)
	check(o.on_region, "down to it")
	var right := MenuInput.new()
	right.right_pressed = true
	o.handle(right)
	eq(o.region, 1, "EUROPE")
	eq(RelayLink.chosen, "wss://b", "HOST and JOIN go through it")
	eq(RelayLink.address(), "wss://b", "the address")
	o.tap(OnlineScreen.region_rect().get_center())
	eq(RelayLink.chosen, "wss://a", "a tap picks the next")
	o.tap(OnlineScreen.choice_rect(1).get_center())
	eq(o.current(), OnlineScreen.View.CODE, "HOST and JOIN still work beside it")
	RelayLink.chosen = keep
