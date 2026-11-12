class_name OnlineSession
extends RefCounted
## An online room (ON-2, ON-3; docs/roadmap/09-online-and-mobile.md), from the lobby through
## its races. The host keeps the room: who's in it with which car, the stage and mirror, the
## start. Every game drives its own car and sends it 20 times a second; guests send theirs to
## the host, which passes each on to the other guests. The game polls it every tick (poll), in
## the menus and in the race; the online screen and the race read what came in.
##
## Messages (Arrays, the op first):
##   guest to host: [HELLO, car, name, avatar], [CAR, state...], [READY], [FIN, time], [AGAIN, on]
##   host to guests: [LOBBY, stage, mirror, players, who], [START, stage, mirror, players, who], [GO],
##     [CAR, slot, state...], [FIN, slot, time], [GONE, slot], [NOPE, reason], [AGAIN, slots]
##   both ways: [PING, sent], answered [PONG, sent] (the round trip through the relay, ON-12)
## Slots: the host is 0, guest n is n + 1. A car's state is CarState. A game ignores an op it
## doesn't know, so a newer one's messages don't trouble an older one, and reads only the
## fields it knows: names and avatars (ON-8) ride at the ends of HELLO, LOBBY and START, so an
## older game's HELLO without them shows as P2 and an older guest skips `who`. `who` is
## slot -> [name, avatar]; both are cleaned on the way in (clean_name, clean_avatar).
##
## The room's phases: DIALING, then LOBBY until the host starts, LOADING until every game has
## the stage (or READY_WAIT), RACING from the GO. After a race the room stays open (ON-9): from
## the results each player says AGAIN (ready), the host picks the next stage, and once everyone
## in the room is ready the host starts it (LOADING again). The host can also start it without
## waiting for the rest (start).

enum Phase { DIALING, LOBBY, LOADING, RACING, CLOSED }

const MAX_PLAYERS := 4
const SEND_EVERY := 3  # physics ticks between car messages: 20 a second
const READY_WAIT := 10.0  # seconds the host waits for every game to load the stage before GO
## A remote car is moved on at its last speed for at most this long past its last message.
const EXTRAPOLATE_MAX := 0.3
const SNAP := 1500.0  # world units: further off than this, a remote car jumps rather than eases
const EASE := 0.35  # share of the gap a remote car closes each tick
const HELLO := "HELLO"
const LOBBY := "LOBBY"
const START := "START"
const READY := "READY"
const GO := "GO"
const CAR := "CAR"
const FIN := "FIN"
const GONE := "GONE"
const NOPE := "NOPE"
const AGAIN := "AGAIN"
const PING := "PING"
const PONG := "PONG"
const UPDATE_TO_PLAY := "UPDATE TO PLAY ONLINE"
## Connection quality (ON-12): a PING every PING_EVERY seconds each way; the round trip shown
## is the worst of the room's (the host's to each guest, a guest's to the host), and one not
## heard from in STALE seconds counts as at least that slow. Under GOOD_MS green, under
## FAIR_MS amber, else red (not gameplay numbers, so not Tuning's).
const PING_EVERY := 1.0
const STALE := 3.0
const GOOD_MS := 150
const FAIR_MS := 300
enum Quality { UNKNOWN, GOOD, FAIR, POOR }
## Where each slot starts, across the road (times Track.side): four abreast, clear of contact.
const GRID_X: Array[float] = [-0.25, 0.25, -0.75, 0.75]
## A name from the wire (ON-8) is cut to this many characters, from NAME_CHARS.
const NAME_MAX := 10
const NAME_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -."

var link: NetLink
var phase := Phase.DIALING
var slot := -1  # this game's: 0 hosting, a guest's once in
var car_id := "car_vega"  # this game's car
var profile_name := ""  # this game's player's profile name (MP-10), "" for none: shown as P1 etc.
var avatar := ""  # and avatar, a car id
## Slot -> [name, avatar] (ON-8), cleaned: everyone in the room who said theirs.
var who := {}
var players := {}  # slot -> car id: everyone in the room, this game too
var stage := 0  # into Stages, the host's pick
var mirror := false
var error := ""  # why the room is gone, in capitals for the screen
## The room is gone because this game is older than the host's (or than the oldest the relay
## takes, NetLink.oldest_version): the screen says UPDATE TO PLAY ONLINE and offers the
## updater (ON-14). `error` then holds the versions.
var needs_update := false
## A START came in (or the host started): the game opens the race and clears it.
var started := false
var go := false  # the GO came in: the race's countdown runs from it
var racers: Array[int] = []  # the slots in this race, from its START
var cars := {}  # slot -> [CarState Array, seconds since it came in]: the others' latest
var finishes := {}  # slot -> race seconds that player finished in
var gone: Array[int] = []  # slots that left during this race (the race drops their cars)
## Slots ready for the next race (ON-9), said from the results: the host's word, on a guest.
var again := {}

var _ticks := 0
var _loaded := {}  # the host's: slots whose games have the stage loaded
var _wait := 0.0
## The pings' clock, in seconds: real time (frames hitch, or run fast headless), or a test's.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var _ping_at := -INF
var _rtt := {}  # the other end's slot (a guest's: the host, 0) -> its last round trip, seconds
var _heard := {}  # and the clock when that came back
var _hello := false  # a guest's HELLO is sent (once: the relay cuts off a game sending 200 a second)


## A room opened on `l`, with this game's car and its player's profile name and avatar (ON-8).
static func hosting_on(l: NetLink, car: String, player := "", pic := "") -> OnlineSession:
	var s := OnlineSession.new()
	s.link = l
	s.car_id = car
	s.profile_name = clean_name(player)
	s.avatar = clean_avatar(pic)
	return s


## A room joined on `l`, with this game's car and its player's name and avatar.
static func joining_on(l: NetLink, car: String, player := "", pic := "") -> OnlineSession:
	return hosting_on(l, car, player, pic)


func hosting() -> bool:
	return link.hosting


## Players in the room, by slot.
func slots() -> Array:
	var out := players.keys()
	out.sort()
	return out


## "P1" to "P4".
static func player_name(s: int) -> String:
	return "P%d" % (s + 1)


## A name off the wire (ON-8), which anyone could have sent: capitals, digits, spaces and
## - . only, spaces run together, at most NAME_MAX long; "" for anything else.
static func clean_name(v: Variant) -> String:
	if not v is String and not v is StringName:
		return ""
	var out := ""
	for c in String(v).to_upper():
		if NAME_CHARS.contains(c) and not (c == " " and (out == "" or out.ends_with(" "))):
			out += c
	return out.left(NAME_MAX).strip_edges()


## An avatar off the wire: a car id in Cars.LIST, else "".
static func clean_avatar(v: Variant) -> String:
	if not v is String and not v is StringName:
		return ""
	for car: Dictionary in Cars.LIST:
		if car["id"] == String(v):
			return car["id"]
	return ""


## What slot `s` shows as: its profile's name (ON-8), or P1 to P4 for a game that didn't say
## one. A name an earlier slot has too gets its slot's number ("ACE 2").
func name_of(s: int) -> String:
	var n := String(who.get(s, ["", ""])[0])
	if n == "":
		return player_name(s)
	for other: int in who:
		if other < s and String(who[other][0]) == n:
			return "%s %d" % [n, s + 1]
	return n


## Slot `s`'s avatar (a car id), "" for none.
func avatar_of(s: int) -> String:
	return String(who.get(s, ["", ""])[1])


## A `who` off the wire, cleaned: only int slots in range with a [name, avatar].
static func clean_who(v: Variant) -> Dictionary:
	var out := {}
	if not v is Dictionary:
		return out
	for k: Variant in v:
		if not (k is int) or k < 0 or k >= MAX_PLAYERS or not v[k] is Array or v[k].size() < 2:
			continue
		out[k] = [clean_name(v[k][0]), clean_avatar(v[k][1])]
	return out


## Where a slot starts across the road.
static func grid_x(s: int) -> float:
	return GRID_X[clampi(s, 0, GRID_X.size() - 1)]


func poll(dt: float) -> void:
	if phase == Phase.CLOSED:
		return
	link.poll()
	for s in cars:
		cars[s][1] += dt
	if phase == Phase.DIALING and link.ready() and not _hello:
		_in_room()
	for got: Array in link.receive():
		if hosting():
			_host_got(int(got[0]), got[1])
		else:
			_guest_got(got[1])
		if error != "":
			break
	if error == "" and link.error != "":
		error = link.error
		needs_update = error.begins_with(UPDATE_TO_PLAY)
	if error != "":
		phase = Phase.CLOSED
		link.close()
		return
	if phase != Phase.DIALING and clock.call() - _ping_at >= PING_EVERY:
		_ping_at = clock.call()
		link.send_to(NetLink.ALL if hosting() else NetLink.HOST, [PING, clock.call()])
	if hosting() and phase == Phase.LOADING:
		_wait += dt
		if _wait >= READY_WAIT or racers.all(func(s: int) -> bool: return _loaded.has(s) or not players.has(s)):
			_go()


## Why a game on version `mine` can't join a host on `host` ("" when either is unknown), or
## a relay whose oldest accepted version is `oldest` ("" when it names none): "" when it can.
## Older than either: UPDATE TO PLAY ONLINE (the guest updates, ON-14). Newer than the host:
## OLD VERSION (the host's to update). Said from the guest's side, so the host sends it too.
static func version_refusal(mine: String, host: String, oldest := "") -> String:
	if oldest != "" and BootTree.compare(mine, oldest) < 0:
		return "%s: THE SERVER TAKES %s OR LATER, YOU HAVE %s" % [UPDATE_TO_PLAY, oldest, mine]
	if host == "" or host == mine:
		return ""
	if BootTree.compare(host, mine) > 0:
		return "%s: THE HOST HAS %s, YOU HAVE %s" % [UPDATE_TO_PLAY, host, mine]
	return "OLD VERSION: THE HOST HAS %s, YOU HAVE %s" % [host, mine]


## The line is up: the host's lobby opens; a guest checks the host's version and says hello.
func _in_room() -> void:
	if hosting() and version_refusal(Updater.version(), "", link.oldest_version) != "":
		error = version_refusal(Updater.version(), "", link.oldest_version)
		needs_update = true
	elif hosting():
		slot = 0
		players = {0: car_id}
		who = {0: [profile_name, avatar]}
		phase = Phase.LOBBY
	elif version_refusal(Updater.version(), link.host_version, link.oldest_version) != "":
		error = version_refusal(Updater.version(), link.host_version, link.oldest_version)
		needs_update = error.begins_with(UPDATE_TO_PLAY)
	else:
		slot = link.you + 1
		_hello = true
		link.send_to(NetLink.HOST, [HELLO, car_id, profile_name, avatar])


# --- The host ------------------------------------------------------------------------

## The host's pick of stage and mirror, sent to the lobby.
func choose(stage_index: int, mirrored: bool) -> void:
	stage = stage_index
	mirror = mirrored
	_send_lobby()


## The host starts a race on the stage picked, with everyone in the room: from the lobby, or
## after a race (everyone ready, or the host not waiting for the rest).
func start() -> void:
	if not hosting() or not (phase == Phase.LOBBY or phase == Phase.RACING):
		return
	_new_race()
	phase = Phase.LOADING
	_wait = 0.0
	_loaded.clear()
	link.send_to(NetLink.ALL, [START, stage, mirror, players, who])


func _go() -> void:
	phase = Phase.RACING
	go = true
	link.send_to(NetLink.ALL, [GO])


func _send_lobby() -> void:
	if hosting() and phase != Phase.DIALING:
		link.send_to(NetLink.ALL, [LOBBY, stage, mirror, players, who])


func _host_got(guest: int, msg: Array) -> void:
	var s := guest + 1
	match String(msg[0]):
		NetLink.JOINED:
			var refusal := version_refusal(String(msg[1]), Updater.version())
			if refusal != "":
				link.send_to(guest, [NOPE, refusal])
			elif phase == Phase.LOADING or phase == Phase.RACING:
				link.send_to(guest, [NOPE, "A RACE IS UNDER WAY: TRY AGAIN SOON"])
		NetLink.LEFT:
			_rtt.erase(s)
			_heard.erase(s)
			who.erase(s)
			if players.erase(s):
				_dropped(s)
				for other: int in slots():
					if other != 0:
						link.send_to(other - 1, [GONE, s])
				_send_lobby()
				if again.erase(s):
					_send_again()
				_check_again()  # (the one left may have been the last not ready)
		HELLO:
			if phase == Phase.LOBBY and s < MAX_PLAYERS:
				players[s] = String(msg[1])
				who[s] = [clean_name(msg[2] if msg.size() > 2 else ""), clean_avatar(msg[3] if msg.size() > 3 else "")]
				_send_lobby()
		READY:
			_loaded[s] = true
		CAR:
			if not players.has(s) or msg.size() < 1 + CarState.SIZE:
				return
			var state := msg.slice(1)
			cars[s] = [state, 0.0]
			for other: int in slots():
				if other != 0 and other != s:
					link.send_to(other - 1, [CAR, s] + state)
		FIN:
			finishes[s] = float(msg[1])
			link.send_to(NetLink.ALL, [FIN, s, float(msg[1])])
		AGAIN:
			if players.has(s) and phase == Phase.RACING and msg.size() >= 2:
				_set_again(s, bool(msg[1]))
		PING:
			if msg.size() >= 2:
				link.send_to(guest, [PONG, msg[1]])
		PONG:
			if players.has(s) and msg.size() >= 2:
				_answered(s, float(msg[1]))


## Who's ready for the next race, to every guest.
func _send_again() -> void:
	var ready_slots: Array = again.keys()
	ready_slots.sort()
	link.send_to(NetLink.ALL, [AGAIN, ready_slots])


func _set_again(s: int, on: bool) -> void:
	if on:
		again[s] = true
	else:
		again.erase(s)
	_send_again()
	_check_again()


## The host: everyone in the room ready after a race starts the next.
func _check_again() -> void:
	if hosting() and phase == Phase.RACING and not players.is_empty() and players.keys().all(func(s: int) -> bool: return again.has(s)):
		start()


# --- A guest -------------------------------------------------------------------------

func _guest_got(msg: Array) -> void:
	match String(msg[0]):
		LOBBY:
			stage = int(msg[1])
			mirror = bool(msg[2])
			players = msg[3]
			who = clean_who(msg[4] if msg.size() > 4 else null)
			if phase == Phase.DIALING:
				phase = Phase.LOBBY
		START:
			stage = int(msg[1])
			mirror = bool(msg[2])
			players = msg[3]
			who = clean_who(msg[4] if msg.size() > 4 else null)
			_new_race()
			phase = Phase.LOADING
		GO:
			go = true
			phase = Phase.RACING
		CAR:
			if msg.size() >= 2 + CarState.SIZE and int(msg[1]) != slot:
				cars[int(msg[1])] = [msg.slice(2), 0.0]
		FIN:
			if int(msg[1]) != slot:
				finishes[int(msg[1])] = float(msg[2])
		GONE:
			players.erase(int(msg[1]))
			who.erase(int(msg[1]))
			_dropped(int(msg[1]))
		NOPE:
			error = String(msg[1])
			needs_update = error.begins_with(UPDATE_TO_PLAY)
		PING:
			if msg.size() >= 2:
				link.send_to(NetLink.HOST, [PONG, msg[1]])
		PONG:
			if msg.size() >= 2:
				_answered(0, float(msg[1]))
		AGAIN:
			if msg.size() >= 2 and msg[1] is Array:
				again.clear()
				for s: Variant in msg[1]:
					again[int(s)] = true


# --- Both ----------------------------------------------------------------------------

func _new_race() -> void:
	started = true
	go = false
	racers.clear()
	for s: int in slots():
		racers.append(s)
	cars.clear()
	finishes.clear()
	gone.clear()
	again.clear()
	_ticks = 0


func _dropped(s: int) -> void:
	cars.erase(s)
	if racers.has(s) and not gone.has(s):
		gone.append(s)


## The race has its stage loaded and is waiting on the GO.
func loaded() -> void:
	if hosting():
		_loaded[0] = true
	else:
		link.send_to(NetLink.HOST, [READY])


## This game's car, every SEND_EVERY ticks of the race.
func send_car(p: PlayerCar) -> void:
	_ticks += 1
	if _ticks % SEND_EVERY != 0:
		return
	var state := CarState.of(p)
	if hosting():
		link.send_to(NetLink.ALL, [CAR, 0] + state)
	else:
		link.send_to(NetLink.HOST, [CAR] + state)


## This game's car crossed the line in `seconds`.
func finish(seconds: float) -> void:
	finishes[slot] = seconds
	if hosting():
		link.send_to(NetLink.ALL, [FIN, 0, seconds])
	else:
		link.send_to(NetLink.HOST, [FIN, seconds])


## A PONG from `s` for the PING sent at `sent`.
func _answered(s: int, sent: float) -> void:
	_rtt[s] = maxf(0.0, clock.call() - sent)
	_heard[s] = clock.call()


## The room's round trip through the relay (ON-12) in milliseconds: the worst of the host's to
## each guest, or a guest's to the host; one gone quiet for STALE counts as at least that
## long. -1 before any has come back.
func round_trip_ms() -> float:
	var worst := -1.0
	for s: int in _rtt:
		var since: float = clock.call() - float(_heard[s])
		var t: float = _rtt[s] if since <= STALE else maxf(_rtt[s], since)
		worst = maxf(worst, t * 1000.0)
	return worst


## How a round trip of `ms` (round_trip_ms) rates: GOOD, FAIR or POOR, UNKNOWN under 0.
static func quality(ms: float) -> int:
	if ms < 0.0:
		return Quality.UNKNOWN
	if ms < GOOD_MS:
		return Quality.GOOD
	if ms < FAIR_MS:
		return Quality.FAIR
	return Quality.POOR


## After a race (ON-9): this player ready for the next one (`on`), or not after all. Once the
## whole room is, the host starts it.
func ready_again(on := true) -> void:
	if phase != Phase.RACING:
		return
	if hosting():
		_set_again(0, on)
		return
	if on:
		again[slot] = true  # (shown at once; the host's count follows)
	else:
		again.erase(slot)
	link.send_to(NetLink.HOST, [AGAIN, on])


## How many in the room are ready for the next race.
func ready_count() -> int:
	return players.keys().filter(func(s: int) -> bool: return again.has(s)).size()


## Whether this game's player is ready for the next race.
func is_ready_again() -> bool:
	return again.has(slot)


## Back from a race's results to the lobby (the host can start the next).
func to_lobby() -> void:
	if phase == Phase.CLOSED:
		return
	started = false
	go = false
	phase = Phase.LOBBY
	_send_lobby()


## Leaves the room. A host leaving ends it for everyone (the relay closes it).
func leave() -> void:
	if phase != Phase.CLOSED:
		phase = Phase.CLOSED
		link.close()


## Where a remote car is shown this tick: its last message moved on at its speed for the
## time since (at most EXTRAPOLATE_MAX). `shown` (where it was shown last tick) runs on at
## that speed for `dt` and eases toward it, or jumps there from more than SNAP away.
## As (distance, x, steer).
static func shown_at(state: Array, age: float, shown: Vector3, dt: float) -> Vector3:
	var speed := float(state[CarState.SPEED])
	var d := float(state[CarState.DISTANCE]) + speed * minf(age, EXTRAPOLATE_MAX)
	var target := Vector3(d, float(state[CarState.X]), float(state[CarState.STEER]))
	if absf(target.x - shown.x) > SNAP:
		return target
	return (shown + Vector3(speed * dt, 0.0, 0.0)).lerp(target, EASE)
