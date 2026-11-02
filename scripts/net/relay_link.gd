class_name RelayLink
extends NetLink
## Online by room (ON-1, ON-2): a NetLink through the relay that Pickleball '94 plays through
## (github.com/austinthedeveloper/pickleball-relay), a WebSocket server every game dials out
## to, so nobody forwards a port and the Web build can play. The host opens a room and the
## relay names it, four consonants ("BXKM"); guests join by that name. Messages are binary
## frames of var_to_bytes Arrays: the host's carry the relay's one-byte guest number (ALL for
## every guest), a guest's are bare. The relay's own words are JSON text frames (room,
## welcome, joined, left, error).

const URL := "wss://pb94-relay.wonderfulground-3bc64e4e.eastus.azurecontainerapps.io"
const GAME := "sundown-run"
## The relay's room names: no I or O to misread, no vowels, so no words.
const ALPHABET := "BCDFGHJKLMNPQRSTVWXZ"
const ROOM_LEN := 4
const TIMEOUT_MS := 45000  # the relay asleep takes about 20 s to wake (pickleball, 2026-10-29)
const KEEP_MS := 60000  # a host waiting in its lobby tells the relay it's still there
## The relay's reasons, as the screen says them; others pass as they are.
const REASONS := {"HOST LEFT": "THE HOST LEFT", "IDLE": "THE ROOM CLOSED: IDLE",
	"TIME UP": "THE ROOM CLOSED: TIME UP", "NO SUCH ROOM": "NO SUCH ROOM",
	"ROOM FULL": "THAT ROOM IS FULL", "SERVER FULL": "THE SERVER IS FULL",
	"NO SUCH GAME": "THE SERVER DOESN'T KNOW THIS GAME", "TOO MANY TRIES": "TOO MANY TRIES: WAIT A MINUTE",
	"TOO MANY ROOMS": "TOO MANY ROOMS: WAIT A MINUTE"}

const MAX_REGIONS := 8
## A region's relay picked on the online screen (ON-12), or "" for URL. A relay with regions
## would list them at /v1/regions (regions_url); today's lists none, so no picker shows.
static var chosen := ""

var ws := WebSocketPeer.new()
var _inbox: Array = []
var _started_ms := 0
var _keep_ms := 0


## The relay's address: URL, or --relay=ws://... on the command line (a local relay for testing:
## `npm start` in pickleball-relay, then --relay=ws://127.0.0.1:8080), or the region picked.
static func address() -> String:
	return chosen if chosen != "" else home()


## The relay before any region is picked: URL, or --relay.
static func home() -> String:
	var a := DevArgs.value("--relay")
	return a if a != "" else URL


## Where the relay at `base` (a ws:// or wss:// address) would list its regions: an HTTP GET
## answering {"regions": [{"name": "US EAST", "url": "wss://..."}, ...]}.
static func regions_url(base: String) -> String:
	var http := base.replace("wss://", "https://").replace("ws://", "http://")
	return http.trim_suffix("/") + "/v1/regions"


## The regions in a /v1/regions answer: [{name, url}], names in capitals, only those with a
## name and a ws:// or wss:// address, at most MAX_REGIONS. Anything else is none.
static func parse_regions(body: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var json := JSON.new()
	if json.parse(body) != OK:
		return out
	var got: Variant = json.data
	if not got is Dictionary or not (got as Dictionary).get("regions") is Array:
		return out
	for r: Variant in got["regions"]:
		if not r is Dictionary:
			continue
		var name := String(r.get("name", "")).strip_edges().to_upper()
		var url := String(r.get("url", ""))
		if name != "" and (url.begins_with("wss://") or url.begins_with("ws://")) and out.size() < MAX_REGIONS:
			out.append({"name": name.left(16), "url": url})
	return out


## A room's name as typed, cleaned: capitals from ALPHABET, at most ROOM_LEN.
static func clean_room(s: String) -> String:
	var out := ""
	for c in s.to_upper():
		if c in ALPHABET and out.length() < ROOM_LEN:
			out += c
	return out


func host(url := address()) -> bool:
	hosting = true
	return _dial("%s/v1/host?game=%s&ver=%s" % [url, GAME, Updater.version().uri_encode()])


func join(code: String, url := address()) -> bool:
	var r := clean_room(code)
	if r.length() != ROOM_LEN:
		error = "A ROOM IS %d LETTERS" % ROOM_LEN
		return false
	room = r
	return _dial("%s/v1/join?game=%s&code=%s&ver=%s" % [url, GAME, r, Updater.version().uri_encode()])


func _dial(url: String) -> bool:
	ws.inbound_buffer_size = 1 << 18
	if ws.connect_to_url(url) != OK:
		error = "CAN'T REACH THE SERVER"
		return false
	_started_ms = Time.get_ticks_msec()
	return true


func ready() -> bool:
	return super.ready() and ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func send_to(to: int, msg: Array) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var out := PackedByteArray([to]) if hosting else PackedByteArray()
	out.append_array(var_to_bytes(msg))
	ws.send(out)


func poll() -> void:
	if error != "" or _started_ms == 0:
		return
	ws.poll()
	var now := Time.get_ticks_msec()
	while ws.get_available_packet_count() > 0:
		var bytes := ws.get_packet()
		if ws.was_string_packet():
			_control(JSON.parse_string(bytes.get_string_from_utf8()))
		elif hosting:
			if bytes.size() > 1:
				_message(bytes[0], bytes_to_var(bytes.slice(1)))
		else:
			_message(HOST, bytes_to_var(bytes))
		if error != "":
			return
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		# A refusal's words come as the close's reason too (Godot can drop the text frame
		# right before a close).
		var r := ws.get_close_reason()
		if r != "":
			error = String(REASONS.get(r, r))
		else:
			error = "CONNECTION LOST" if room != "" and (hosting or you >= 0) else "CAN'T REACH THE SERVER"
		return
	if not ready() and now - _started_ms > TIMEOUT_MS:
		error = "NO ANSWER FROM THE SERVER"
		close()
	elif hosting and ready() and now - _keep_ms >= KEEP_MS:
		_keep_ms = now
		ws.send_text(JSON.stringify({"op": "keep"}))


## The relay's words: the room, guests coming and going, a refusal.
func _control(msg: Variant) -> void:
	if not msg is Dictionary:
		return
	match String(msg.get("op", "")):
		"room":
			room = String(msg.get("code", ""))
			_keep_ms = Time.get_ticks_msec()
		"welcome":
			you = int(msg.get("you", 0))
			host_version = String(msg.get("ver", ""))
		"joined":
			_inbox.append([int(msg.get("guest", 0)), [JOINED, String(msg.get("ver", ""))]])
		"left":
			_inbox.append([int(msg.get("guest", 0)), [LEFT]])
		"error":
			var r := String(msg.get("reason", ""))
			error = String(REASONS.get(r, r)) if r != "" else "CONNECTION LOST"


func _message(from: int, v: Variant) -> void:
	if v is Array and not (v as Array).is_empty():
		_inbox.append([from, v])


func receive() -> Array:
	var out := _inbox
	_inbox = []
	return out


## Closes after a last flush, so a BYE just sent goes out.
func close() -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return
	ws.poll()
	ws.close()
	for i in 3:
		ws.poll()
