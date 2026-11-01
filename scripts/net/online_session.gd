class_name OnlineSession
extends RefCounted
## An online room (ON-2, ON-3; docs/roadmap/09-online-and-mobile.md), from the lobby through
## its races. The host keeps the room: who's in it with which car, the stage and mirror, the
## start. Every game drives its own car and sends it 20 times a second; guests send theirs to
## the host, which passes each on to the other guests. The game polls it every tick (poll), in
## the menus and in the race; the online screen and the race read what came in.
##
## Messages (Arrays, the op first):
##   guest to host: [HELLO, car], [CAR, state...], [READY], [FIN, time]
##   host to guests: [LOBBY, stage, mirror, players], [START, stage, mirror, players], [GO],
##     [CAR, slot, state...], [FIN, slot, time], [GONE, slot], [NOPE, reason]
## Slots: the host is 0, guest n is n + 1. A car's state is CarState.

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
## Where each slot starts, across the road (times Track.side): four abreast, clear of contact.
const GRID_X: Array[float] = [-0.25, 0.25, -0.75, 0.75]

var link: NetLink
var phase := Phase.DIALING
var slot := -1  # this game's: 0 hosting, a guest's once in
var car_id := "car_vega"  # this game's car
var players := {}  # slot -> car id: everyone in the room, this game too
var stage := 0  # into Stages, the host's pick
var mirror := false
var error := ""  # why the room is gone, in capitals for the screen
## A START came in (or the host started): the game opens the race and clears it.
var started := false
var go := false  # the GO came in: the race's countdown runs from it
var racers: Array[int] = []  # the slots in this race, from its START
var cars := {}  # slot -> [CarState Array, seconds since it came in]: the others' latest
var finishes := {}  # slot -> race seconds that player finished in
var gone: Array[int] = []  # slots that left during this race (the race drops their cars)

var _ticks := 0
var _loaded := {}  # the host's: slots whose games have the stage loaded
var _wait := 0.0


## A room opened on `l`, with this game's car.
static func hosting_on(l: NetLink, car: String) -> OnlineSession:
	var s := OnlineSession.new()
	s.link = l
	s.car_id = car
	return s


## A room joined on `l`, with this game's car.
static func joining_on(l: NetLink, car: String) -> OnlineSession:
	return hosting_on(l, car)


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


## Where a slot starts across the road.
static func grid_x(s: int) -> float:
	return GRID_X[clampi(s, 0, GRID_X.size() - 1)]


func poll(dt: float) -> void:
	if phase == Phase.CLOSED:
		return
	link.poll()
	for s in cars:
		cars[s][1] += dt
	if phase == Phase.DIALING and link.ready():
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
	if error != "":
		phase = Phase.CLOSED
		link.close()
		return
	if hosting() and phase == Phase.LOADING:
		_wait += dt
		if _wait >= READY_WAIT or racers.all(func(s: int) -> bool: return _loaded.has(s) or not players.has(s)):
			_go()


## The line is up: the host's lobby opens; a guest checks the host's version and says hello.
func _in_room() -> void:
	if hosting():
		slot = 0
		players = {0: car_id}
		phase = Phase.LOBBY
	elif link.host_version != "" and link.host_version != Updater.version():
		error = "OLD VERSION: THE HOST HAS %s, THIS IS %s" % [link.host_version, Updater.version()]
	else:
		slot = link.you + 1
		link.send_to(NetLink.HOST, [HELLO, car_id])


# --- The host ------------------------------------------------------------------------

## The host's pick of stage and mirror, sent to the lobby.
func choose(stage_index: int, mirrored: bool) -> void:
	stage = stage_index
	mirror = mirrored
	_send_lobby()


## The host starts a race on the stage picked, with everyone in the room.
func start() -> void:
	if not hosting() or phase != Phase.LOBBY:
		return
	_new_race()
	phase = Phase.LOADING
	_wait = 0.0
	_loaded.clear()
	link.send_to(NetLink.ALL, [START, stage, mirror, players])


func _go() -> void:
	phase = Phase.RACING
	go = true
	link.send_to(NetLink.ALL, [GO])


func _send_lobby() -> void:
	if hosting() and phase != Phase.DIALING:
		link.send_to(NetLink.ALL, [LOBBY, stage, mirror, players])


func _host_got(guest: int, msg: Array) -> void:
	var s := guest + 1
	match String(msg[0]):
		NetLink.JOINED:
			if String(msg[1]) != Updater.version():
				link.send_to(guest, [NOPE, "OLD VERSION: THE HOST HAS %s, YOU HAVE %s" % [Updater.version(), msg[1]]])
			elif phase == Phase.LOADING or phase == Phase.RACING:
				link.send_to(guest, [NOPE, "A RACE IS UNDER WAY: TRY AGAIN SOON"])
		NetLink.LEFT:
			if players.erase(s):
				_dropped(s)
				for other: int in slots():
					if other != 0:
						link.send_to(other - 1, [GONE, s])
				_send_lobby()
		HELLO:
			if phase == Phase.LOBBY and s < MAX_PLAYERS:
				players[s] = String(msg[1])
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


# --- A guest -------------------------------------------------------------------------

func _guest_got(msg: Array) -> void:
	match String(msg[0]):
		LOBBY:
			stage = int(msg[1])
			mirror = bool(msg[2])
			players = msg[3]
			if phase == Phase.DIALING:
				phase = Phase.LOBBY
		START:
			stage = int(msg[1])
			mirror = bool(msg[2])
			players = msg[3]
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
			_dropped(int(msg[1]))
		NOPE:
			error = String(msg[1])


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
