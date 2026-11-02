extends SceneTree
## Two games through a real relay (ON-1 to ON-3): a host and a guest over RelayLink, through
## the lobby, the start and the GO, then cars and a finish each way. Prints each step and
## quits non-zero on a failure. For a local relay (`PORT=8091 npm start` in pickleball-relay):
##   godot --headless --path . -s res://tools/online_probe.gd -- --relay=ws://127.0.0.1:8091
## Without --relay it uses the live one (RelayLink.URL).

## Loaded here rather than named, as a -s script is compiled before the autoloads exist.
var Session: GDScript
var Link: GDScript
var _host  # OnlineSession
var _guest


func _initialize() -> void:
	Session = load("res://scripts/net/online_session.gd")
	Link = load("res://scripts/net/relay_link.gd")
	var url: String = Link.address()
	print("relay: ", url)
	var h = Link.new()
	h.host(url)
	_host = Session.hosting_on(h, "car_vega")
	if not await _until(func() -> bool: return _host.phase == Session.Phase.LOBBY, "the host's room"):
		return
	print("room ", h.room)
	var g = Link.new()
	g.join(h.room, url)
	_guest = Session.joining_on(g, "car_mesa")
	if not await _until(func() -> bool: return _host.players.size() == 2 and _guest.players.size() == 2, "the guest in the lobby"):
		return
	print("lobby ", _host.players)
	_host.choose(2, false)
	_host.start()
	if not await _until(func() -> bool: return _guest.started and _guest.stage == 2, "START"):
		return
	_host.loaded()
	_guest.loaded()
	if not await _until(func() -> bool: return _host.go and _guest.go, "GO"):
		return
	var p := PlayerCar.new()
	p.distance = 4321.0
	p.speed = 3000.0
	var sent := Time.get_ticks_msec()
	for i in Session.SEND_EVERY:
		_guest.send_car(p)
	if not await _until(func() -> bool: return _host.cars.has(1), "the guest's car at the host"):
		return
	print("a car, guest to host: %d ms" % (Time.get_ticks_msec() - sent))
	p.distance = 999.0
	for i in Session.SEND_EVERY:
		_host.send_car(p)
	if not await _until(func() -> bool: return _guest.cars.has(0) and _guest.cars[0][0][0] == 999.0, "the host's car at the guest"):
		return
	_guest.finish(70.25)
	if not await _until(func() -> bool: return _host.finishes.get(1, 0.0) == 70.25, "the guest's finish"):
		return
	if not await _until(func() -> bool: return _host.round_trip_ms() >= 0.0 and _guest.round_trip_ms() >= 0.0, "a round trip each way"):
		return
	print("round trip (ON-12): host %d ms, guest %d ms" % [_host.round_trip_ms(), _guest.round_trip_ms()])
	_guest.leave()
	_guest = null  # (closed now, by its own choice)
	if not await _until(func() -> bool: return _host.players.size() == 1, "the guest leaving"):
		return
	_host.leave()
	print("OK: lobby, start, GO, cars both ways, a finish, leaving")
	quit(0)


## Polls both games until `cond` holds (true) or 60 s pass (false, and quits 1).
func _until(cond: Callable, what: String) -> bool:
	var start := Time.get_ticks_msec()
	while not cond.call():
		for s in [_host, _guest]:
			if s != null:
				s.poll(1.0 / 60.0)
				if s.phase == Session.Phase.CLOSED:
					print("FAIL waiting for %s: %s" % [what, s.error])
					quit(1)
					return false
		if Time.get_ticks_msec() - start > 60000:
			print("FAIL: no %s in 60 s" % what)
			quit(1)
			return false
		await process_frame
	return true
