class_name LoopLink
extends NetLink
## A NetLink through an in-memory relay (LoopLink.Relay), for tests: the relay's rooms, guest
## numbers, versions and refusals, with nothing on the wire. Messages go through
## var_to_bytes as on a real line, so only what survives it gets through.


## The relay, in memory: rooms by code, each a host and up to `guests` guests.
class Relay:
	extends RefCounted
	var guests := 3
	var oldest := ""  # the oldest version it takes, named to every game (NetLink.oldest_version)
	var rooms := {}  # code -> {"host": LoopLink, "guests": [LoopLink or null]}
	var _next := 61873  # the first room is BXKM-like rather than BBBB

	func open(h: LoopLink, version: String) -> void:
		var code := ""
		var n := _next
		_next += 1
		for i in RelayLink.ROOM_LEN:
			code += RelayLink.ALPHABET[n % RelayLink.ALPHABET.length()]
			n /= RelayLink.ALPHABET.length()
		var seats: Array = []
		seats.resize(guests)
		rooms[code] = {"host": h, "guests": seats, "version": version}
		h.oldest_version = oldest
		h.room = code

	func enter(g: LoopLink, code: String, version: String) -> void:
		if not rooms.has(code):
			g.error = "NO SUCH ROOM"
			return
		var r: Dictionary = rooms[code]
		var seat: int = (r["guests"] as Array).find(null)
		if seat < 0:
			g.error = "THAT ROOM IS FULL"
			return
		r["guests"][seat] = g
		g.room = code
		g.you = seat
		g.host_version = r["version"]
		g.oldest_version = oldest
		(r["host"] as LoopLink)._inbox.append([seat, [NetLink.JOINED, version]])

	func leave(l: LoopLink) -> void:
		if not rooms.has(l.room):
			return
		var r: Dictionary = rooms[l.room]
		if r["host"] == l:
			rooms.erase(l.room)
			for g: LoopLink in r["guests"]:
				if g != null:
					g.error = "THE HOST LEFT"
		elif l.you >= 0 and r["guests"][l.you] == l:
			r["guests"][l.you] = null
			(r["host"] as LoopLink)._inbox.append([l.you, [NetLink.LEFT]])


var relay: Relay
var _inbox: Array = []
## Milliseconds every message to this game takes to arrive (--bot-lag, screenshots); 0 at once.
var lag_ms := 0
var _held: Array = []  # with lag: [due msec, message] not handed over yet


func _init(on: Relay) -> void:
	relay = on


func host(version := Updater.version()) -> bool:
	hosting = true
	relay.open(self, version)
	return true


func join(code: String, version := Updater.version()) -> bool:
	relay.enter(self, RelayLink.clean_room(code), version)
	return error == ""


func send_to(to: int, msg: Array) -> void:
	if not ready() or not relay.rooms.has(room):
		return
	var r: Dictionary = relay.rooms[room]
	var bytes := var_to_bytes(msg)
	if not hosting:
		(r["host"] as LoopLink)._inbox.append([you, bytes_to_var(bytes)])
		return
	for i in (r["guests"] as Array).size():
		var g: LoopLink = r["guests"][i]
		if g != null and (to == ALL or to == i):
			g._inbox.append([HOST, bytes_to_var(bytes)])


func receive() -> Array:
	var out := _inbox
	_inbox = []
	if lag_ms <= 0:
		return out
	var now := Time.get_ticks_msec()
	for m: Array in out:
		_held.append([now + lag_ms, m])
	var due: Array = []
	while not _held.is_empty() and int(_held[0][0]) <= now:
		due.append(_held.pop_front()[1])
	return due


func close() -> void:
	relay.leave(self)
	if error == "":
		error = "CLOSED"
