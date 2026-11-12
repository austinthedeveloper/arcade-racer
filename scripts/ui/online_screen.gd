class_name OnlineScreen
extends MenuScreen
## ONLINE (ON-2), after car select: HOST opens a room on the relay and shows its four letters;
## JOIN picks them on a letter grid (keyboard, pad, wheel or touch; typing works too). Then
## the lobby: everyone in the room with their car, the stage and mirror the host picks, and
## the host's START. The room itself is the game's (game.online); this screen shows it.

enum View { CHOOSE, CODE, WAIT, LOBBY, ERROR }
enum Row { STAGE, MIRROR, START }  # the host's lobby rows

const CHOICES := ["HOST", "JOIN"]
const COLS := 5
const ROWS := 4  # of letters; a fifth row holds DEL and JOIN
const DEL := 20  # cells after the 20 letters
const GO := 21
const CELL := Vector2(34, 26)
## The grid's top left: centred, clear of the touch controls' D-pad and OK (TouchControls).
const GRID_AT := Vector2(223, 108)

var view := View.CHOOSE  # CHOOSE or CODE before a room; the room's phase picks the rest (current)
var code := ""  # JOIN: the letters picked so far
var cell := 0  # JOIN: the letter grid's cursor (0..19 letters, DEL, GO)
var row: int = Row.START  # the host's lobby cursor
var notice := ""  # a short line under the grid ("A ROOM IS 4 LETTERS")
var _held_letters := {}  # keyboard letters held down: typing D or S doesn't also move the cursor
var _staged: Array = []  # stage_shot's guests, kept alive
## The relay's regions (ON-12), [{name, url}] from its /v1/regions; the picker shows under HOST
## and JOIN only when it lists two or more. Today's relay lists none.
var regions: Array[Dictionary] = []
var region := 0  # into regions: the one HOST and JOIN go through
var on_region := false  # the cursor on the region row rather than HOST / JOIN
var _fetch: HTTPRequest
## The updater UPDATE uses (ON-14): the Updates autoload unless a test or screenshot gives its own.
var updater: Updater


## Asks the relay for its regions, in a window (not in the headless tests).
func _ready() -> void:
	super._ready()
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		_fetch = HTTPRequest.new()
		_fetch.timeout = 10.0
		add_child(_fetch)
		_fetch.request_completed.connect(_regions_came)
		_fetch.request(RelayLink.regions_url(RelayLink.home()))


func _regions_came(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var none: Array[Dictionary] = []
	set_regions(RelayLink.parse_regions(body.get_string_from_utf8()) if code == 200 else none)


## The relay's regions came (or none): the picker on the one already picked, else the first.
func set_regions(list: Array[Dictionary]) -> void:
	regions = list
	region = 0
	for i in regions.size():
		if regions[i]["url"] == RelayLink.chosen:
			region = i
	if not shows_regions():
		on_region = false


## Whether the region picker is up: the relay lists more than one.
func shows_regions() -> bool:
	return regions.size() >= 2


## Picks region `i` (wrapping): HOST and JOIN go through its relay from now on.
func pick_region(i: int) -> void:
	region = posmod(i, regions.size())
	RelayLink.chosen = String(regions[region]["url"])


## What shows now: before a room, CHOOSE or CODE; in one, from its phase.
func current() -> View:
	var room: OnlineSession = game.online if game != null else null
	if room == null:
		return view
	match room.phase:
		OnlineSession.Phase.DIALING:
			return View.WAIT
		OnlineSession.Phase.CLOSED:
			return View.ERROR
	return View.LOBBY


func choice_count() -> int:
	return CHOICES.size()


## The letter in grid cell `i`, or "" for DEL and GO.
static func letter(i: int) -> String:
	return RelayLink.ALPHABET[i] if i >= 0 and i < DEL else ""


## The grid cursor after a step of (`dx`, `dy`), wrapping. The bottom row has two wide cells:
## DEL under the first three columns, JOIN under the last two.
static func grid_move(at: int, dx: int, dy: int) -> int:
	var cx := at % COLS if at < DEL else (0 if at == DEL else COLS - 1)
	var cy := at / COLS if at < DEL else ROWS
	if dy != 0:
		cy = posmod(cy + dy, ROWS + 1)
	elif cy == ROWS:
		return GO if at == DEL else DEL
	else:
		cx = posmod(cx + dx, COLS)
	if cy == ROWS:
		return DEL if cx < 3 else GO
	return cy * COLS + cx


## A letter typed or picked: added while there's room for it.
func type_letter(c: String) -> void:
	notice = ""
	var room := RelayLink.clean_room(code + c)
	if room.length() > code.length():
		code = room
		Audio.play("tick")
	if code.length() == RelayLink.ROOM_LEN:
		cell = GO  # all four: the cursor jumps to JOIN


func delete_letter() -> void:
	notice = ""
	code = code.substr(0, maxi(0, code.length() - 1))


func handle(m: MenuInput) -> void:
	match current():
		View.CHOOSE:
			_handle_choose(m)
		View.CODE:
			_handle_code(m)
		View.WAIT:
			if m.back_pressed:
				game.leave_room()
				view = View.CHOOSE
		View.LOBBY:
			_handle_lobby(m)
		View.ERROR:
			if m.confirm_pressed and game.online.needs_update:
				Audio.play("beep")
				update_game()
			elif m.confirm_pressed or m.back_pressed:
				game.leave_room()
				view = View.CHOOSE
				Audio.play("beep")


func _handle_choose(m: MenuInput) -> void:
	if shows_regions() and m.step_y() != 0:
		on_region = not on_region
		Audio.play("tick")
	elif on_region and (m.step() != 0 or m.confirm_pressed):
		pick_region(region + (m.step() if m.step() != 0 else 1))
		Audio.play("tick")
	elif m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		if index == 0:
			host()
		else:
			view = View.CODE
			code = ""
			cell = 0
	elif m.back_pressed:
		game.show_car_select()


func _handle_code(m: MenuInput) -> void:
	var dx := m.step()
	var dy := m.step_y()
	if _held_letters.is_empty() and (dx != 0 or dy != 0):
		cell = grid_move(cell, dx, dy)
		Audio.play("tick")
	elif m.confirm_pressed:
		if cell == DEL:
			delete_letter()
		elif cell == GO:
			join()
		else:
			type_letter(letter(cell))
	elif m.back_pressed:
		if code.is_empty():
			view = View.CHOOSE
		else:
			delete_letter()


func _handle_lobby(m: MenuInput) -> void:
	var room: OnlineSession = game.online
	if m.back_pressed:
		game.leave_room()
		view = View.CHOOSE
		Audio.play("beep")
		return
	if not room.hosting() or room.phase != OnlineSession.Phase.LOBBY:
		return
	if m.step_y() != 0:
		row = posmod(row + m.step_y(), Row.size())
		Audio.play("tick")
	elif m.step() != 0 and row == Row.STAGE:
		room.choose(next_stage(room.stage, m.step()), room.mirror and Unlocks.mirror_unlocked(next_stage(room.stage, m.step())))
		Audio.play("tick")
	elif (m.step() != 0 or m.confirm_pressed) and row == Row.MIRROR:
		if Unlocks.mirror_unlocked(room.stage):
			room.choose(room.stage, not room.mirror)
			Audio.play("tick")
		else:
			Audio.play("bump")
	elif m.confirm_pressed and row == Row.START:
		Audio.play("go")
		room.start()


## The host's next open stage from `from` in `dir`, wrapping (stage 1 is always open).
static func next_stage(from: int, dir: int) -> int:
	var i := from
	for n in Stages.count():
		i = posmod(i + dir, Stages.count())
		if Unlocks.stage_unlocked(i):
			return i
	return from


func host() -> void:
	var link: NetLink = game.make_link.call()
	game.open_room(link)
	link.call("host")


func join() -> void:
	if code.length() != RelayLink.ROOM_LEN:
		notice = "A ROOM IS %d LETTERS" % RelayLink.ROOM_LEN
		Audio.play("bump")
		return
	Audio.play("beep")
	var link: NetLink = game.make_link.call()
	game.open_room(link)
	link.call("join", code)


## Where a tap or a click lands (a touch's emulated mouse click is left to the touch), or
## null for anything else.
static func tap_at(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and event.pressed:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		return (event as InputEventMouseButton).position
	return null


## A tap (or click) on something on screen picks it: HOST or JOIN, a letter, DEL, JOIN, or a
## row of the host's lobby.
func tap(pos: Vector2) -> void:
	match current():
		View.CHOOSE:
			if shows_regions() and region_rect().has_point(pos):
				on_region = true
				handle(_confirm())
				return
			for i in CHOICES.size():
				if choice_rect(i).has_point(pos):
					on_region = false
					index = i
					handle(_confirm())
		View.CODE:
			for i in GO + 1:
				if grid_rect(i).has_point(pos):
					cell = i
					handle(_confirm())
		View.LOBBY:
			for i in Row.size():
				if lobby_row_rect(i).has_point(pos) and game.online.hosting():
					row = i
					handle(_confirm())
		View.ERROR:
			if game.online.needs_update and update_rect().has_point(pos):
				handle(_confirm())


## A tick of menu input with only a confirm in it, for a tap.
static func _confirm() -> MenuInput:
	var m := MenuInput.new()
	m.confirm_pressed = true
	return m


## Typing a room on a keyboard (its letters), and taps.
func _input(event: InputEvent) -> void:
	var at: Variant = tap_at(event)
	if at != null:
		tap(at)
		return
	if current() != View.CODE or not event is InputEventKey:
		return
	var k := event as InputEventKey
	var c := char(k.unicode).to_upper() if k.unicode > 0 else ""
	if c != "" and c in RelayLink.ALPHABET:
		if k.pressed:
			_held_letters[k.keycode] = true
			if not k.echo:
				type_letter(c)
		else:
			_held_letters.erase(k.keycode)
	elif not k.pressed:
		_held_letters.erase(k.keycode)  # (Backspace is BACK, which deletes)


func _draw() -> void:
	_backdrop(0.78)
	_header("ONLINE")
	match current():
		View.CHOOSE:
			_draw_choose()
		View.CODE:
			_draw_code()
		View.WAIT:
			var room: OnlineSession = game.online
			_message("JOINING ROOM %s..." % room.link.room if not room.hosting() else "OPENING A ROOM ON THE SERVER...",
				"The server can take 20 seconds to wake up.")
			_footer("Esc / B: cancel")
		View.LOBBY:
			_draw_lobby()
		View.ERROR:
			if game.online.needs_update:
				_draw_update()
			else:
				_message(game.online.error, "")
				_footer("Enter / A: back")


func _message(line: String, sub: String) -> void:
	var w := float(Cfg.SCREEN_W)
	var r := Rect2(w / 2.0 - 230, 140, 460, 60)
	_panel(r, 0.85)
	_text_centered(Vector2(w / 2.0, r.position.y + 27), line, 13, GOLD)
	if sub != "":
		_text_centered(Vector2(w / 2.0, r.position.y + 46), sub, 10, Color(1, 1, 1, 0.8))


func _draw_choose() -> void:
	var w := float(Cfg.SCREEN_W)
	var help := ["Open a room and share its four letters.", "Type the four letters a friend's room shows."]
	for i in CHOICES.size():
		var on := i == index and not on_region
		var r := choice_rect(i)
		_frame(r, Color(GOLD, 0.4 + 0.15 * sin(time * 4.0)) if on else Color.TRANSPARENT)
		draw_rect(r, Color("#1d3fa8") if on else Color(0.04, 0.03, 0.1, 0.9))
		_text_centered(Vector2(r.get_center().x, r.get_center().y + 8), CHOICES[i], 22, GOLD if on else Color(1, 1, 1, 0.6))
	_text_centered(Vector2(w / 2.0, 236), help[index], 11, Color(1, 1, 1, 0.85))
	_text_centered(Vector2(w / 2.0, 262), "Racing in the %s" % Cars.get_car(game.car_index)["name"], 10, Color(SKY, 0.9))
	if shows_regions():
		var r := region_rect()
		_frame(r, Color(GOLD, 0.4 + 0.15 * sin(time * 4.0)) if on_region else Color.TRANSPARENT)
		draw_rect(r, Color("#1d3fa8") if on_region else Color(0.04, 0.03, 0.1, 0.9))
		_text(r.position + Vector2(10, 14), "SERVER", 10, Color(1, 1, 1, 0.7))
		_text_centered(Vector2(r.get_center().x + 24, r.position.y + 14), String(regions[region]["name"]), 11, GOLD if on_region else Color.WHITE)
		if on_region:
			_arrow(Vector2(r.position.x + 78, r.get_center().y), -1, GOLD)
			_arrow(Vector2(r.end.x - 12, r.get_center().y), 1, GOLD)
	_footer(hints(true) + ("    Up / Down: server" if shows_regions() else ""))


# --- Online across versions (ON-14) -----------------------------------------------------

## What UPDATE does with the updater in `state` on this build: "screen", the update screen
## (an exported desktop game, which downloads the new version or links to it); "reload" on the
## Web build (a reload gets the version online); "page", the releases page (a checkout).
static func update_route(state: int, web := OS.has_feature("web")) -> String:
	if state != Updater.State.OFF:
		return "screen"
	return "reload" if web else "page"


## UPDATE TO PLAY ONLINE's button: out of the room, to the updater (update_route). A check
## that said up to date (or failed) asks again, as the host's newer version may be new.
func update_game() -> void:
	var u: Updater = updater if updater != null else get_node_or_null("/root/Updates")
	game.leave_room()
	view = View.CHOOSE
	match update_route(u.state if u != null else Updater.State.OFF):
		"screen":
			if u.state in [Updater.State.IDLE, Updater.State.LATEST, Updater.State.FAILED]:
				u.check()
			game.show_update(updater)
		"reload":
			JavaScriptBridge.eval("location.reload()")
		"page":
			if u != null:
				u.open_page()


## The UPDATE button under the message.
static func update_rect() -> Rect2:
	return Rect2(Cfg.SCREEN_W / 2.0 - 75, 218, 150, 30)


## UPDATE TO PLAY ONLINE: the versions under it, and the updater's button.
func _draw_update() -> void:
	var why := String(game.online.error)
	var versions := why.get_slice(": ", 1) if why.contains(": ") else ""
	_message(OnlineSession.UPDATE_TO_PLAY, versions)
	var r := update_rect()
	_frame(r, Color(GOLD, 0.4 + 0.15 * sin(time * 4.0)))
	draw_rect(r, Color("#1d3fa8"))
	_text_centered(Vector2(r.get_center().x, r.get_center().y + 6), "UPDATE", 16, GOLD)
	_footer("Enter / A: update    Esc / B: back")


## HOST (0) or JOIN (1) on screen.
static func choice_rect(i: int) -> Rect2:
	return Rect2(Cfg.SCREEN_W / 2.0 - 170 + i * 190, 110, 150, 90)


## The region picker's row (ON-12), under HOST and JOIN.
static func region_rect() -> Rect2:
	return Rect2(Cfg.SCREEN_W / 2.0 - 120, 280, 240, 20)


## The host's lobby row `i` (Row) on screen.
static func lobby_row_rect(i: int) -> Rect2:
	return Rect2(22, 130 + i * 28, 238, 24)


func _draw_code() -> void:
	var w := float(Cfg.SCREEN_W)
	# The four boxes
	for i in RelayLink.ROOM_LEN:
		var b := Rect2(w / 2.0 + (i - 2) * 44 + 4, 50, 36, 44)
		_panel(b, 0.9)
		if i < code.length():
			_text_centered(Vector2(b.get_center().x, b.end.y - 11), code[i], 26, GOLD)
		elif i == code.length() and int(time * 2.0) % 2 == 0:
			draw_rect(Rect2(b.position.x + 8, b.end.y - 9, b.size.x - 16, 3), GOLD)
	for i in GO + 1:
		var r := grid_rect(i)
		var on := i == cell
		_frame(r, Color(GOLD, 0.5) if on else Color.TRANSPARENT)
		draw_rect(r, Color("#1d3fa8") if on else Color(0.04, 0.03, 0.1, 0.9))
		var label := letter(i) if i < DEL else ("DEL" if i == DEL else "JOIN")
		_text_centered(Vector2(r.get_center().x, r.end.y - 8), label, 14 if i < DEL else 12,
			GOLD if on else Color(1, 1, 1, 0.8))
	var under := grid_rect(GO).end.y
	if notice != "":
		_text_centered(Vector2(w / 2.0, under + 22), notice, 11, Color("#ff8a5a"))
	else:
		_text_centered(Vector2(w / 2.0, under + 22), "The four letters on the host's screen (no vowels, so no I or O).", 10, Color(1, 1, 1, 0.8))
	_footer("Arrows / D-pad: letter    Enter / A: pick    Esc / B: delete    or type it")


## "BXKM" as "B X K M".
static func spaced(s: String) -> String:
	var out := PackedStringArray()
	for c in s:
		out.append(c)
	return " ".join(out)


## Cell `i` of the letter grid, on screen.
static func grid_rect(i: int) -> Rect2:
	var pitch := CELL + Vector2(6, 6)
	if i < DEL:
		return Rect2(GRID_AT + Vector2(i % COLS, i / COLS) * pitch, CELL)
	var y := GRID_AT.y + ROWS * pitch.y
	if i == DEL:
		return Rect2(GRID_AT.x, y, pitch.x * 3 - 6, CELL.y)
	return Rect2(GRID_AT.x + pitch.x * 3, y, pitch.x * 2 - 6, CELL.y)


func _draw_lobby() -> void:
	var room: OnlineSession = game.online
	var w := float(Cfg.SCREEN_W)
	# The room's letters, big, for the host to share
	var tag := Rect2(16, 50, 250, 60)
	_panel(tag, 0.85)
	_text(tag.position + Vector2(12, 18), "ROOM", 11, Color(1, 1, 1, 0.7))
	_text(tag.position + Vector2(12, 50), spaced(room.link.room), 30, GOLD)
	# The players
	var list := Rect2(w - 16 - 300, 50, 300, 4 * 28 + 30)
	_panel(list, 0.85)
	_text(list.position + Vector2(12, 18), "PLAYERS  %d / %d" % [room.players.size(), OnlineSession.MAX_PLAYERS], 11, GOLD)
	for s in OnlineSession.MAX_PLAYERS:
		var y := list.position.y + 30 + s * 28
		var here: bool = room.players.has(s)
		var you := s == room.slot
		draw_rect(Rect2(list.position.x + 8, y, list.size.x - 16, 24), Color("#1d3fa8", 0.8) if you else Color(1, 1, 1, 0.06))
		# Their avatar and profile name (ON-8; P2 etc. from a game that didn't say), their car
		var pic := Rect2(list.position.x + 12, y + 2, 40, 20)
		if here and room.avatar_of(s) != "":
			draw_avatar(pic, room.avatar_of(s))
		else:
			draw_rect(pic, Color(1, 1, 1, 0.05))
			_text_centered(Vector2(pic.get_center().x, y + 16), OnlineSession.player_name(s), 9, Color(1, 1, 1, 0.3 if not here else 0.6))
		var who := room.name_of(s) if here else "waiting..."
		_text(Vector2(list.position.x + 60, y + 17), who, fit_size(who, 12, 110) if here else 11, GOLD if here else Color(1, 1, 1, 0.3))
		if here:
			var what := String(Cars.find(String(room.players[s]))["name"])
			if s == 0:
				what += "  (host)"
			if you:
				what += "  YOU"
			var size := fit_size(what, 10, 120)
			_text(Vector2(list.end.x - 14 - _width(what, size), y + 16), what, size, Color.WHITE)
	# The race: stage and mirror, the host's to pick
	var race := Rect2(16, 122, 250, 92)
	_panel(race, 0.85)
	var rows_text := ["STAGE   %s" % Stages.stage_name(room.stage),
		"MIRROR  %s" % ("ON" if room.mirror else ("OFF" if Unlocks.mirror_unlocked(room.stage) else "LOCKED")), "START"]
	for i in Row.size():
		var on := room.hosting() and i == row
		var y := lobby_row_rect(i).position.y
		if on:
			draw_rect(lobby_row_rect(i), Color("#1d3fa8"))
		var col := GOLD if on else (Color.WHITE if room.hosting() else Color(1, 1, 1, 0.7))
		if i == Row.START and not room.hosting():
			_text(Vector2(race.position.x + 14, y + 17), "THE HOST STARTS THE RACE", 11, Color(1, 1, 1, 0.6))
		else:
			_text(Vector2(race.position.x + 14, y + 17), rows_text[i], 12, col)
		if on and i == Row.STAGE:
			_arrow(Vector2(race.end.x - 34, y + 12), -1, GOLD)
			_arrow(Vector2(race.end.x - 16, y + 12), 1, GOLD)
	var line := "Share the room's letters: friends pick ONLINE, then JOIN." if room.hosting() else "Waiting for the host to start..."
	if room.phase == OnlineSession.Phase.LOADING:
		line = "Starting..."
	_text_centered(Vector2(w / 2.0, 252), line, 11, Color(1, 1, 1, 0.85))
	_text_centered(Vector2(w / 2.0, 270), "No clock and no AI rivals online: first over the line wins.", 10, Color(SKY, 0.85))
	_footer("Up / Down: choose    Left / Right: stage    Enter / A: select    Esc / B: leave" if room.hosting()
		else "Esc / B: leave the room")


# --- Dev helper: --screen=online:<view> --menu-shot=... ------------------------------
# (online:menu, online:regions the region picker on two made-up regions, online:code with two letters in, online:lobby hosting with two guests in,
# online:guest the lobby as a guest sees it, online:error a refusal, online:update a guest on an
# older build than the host's (ON-14); all on an in-memory relay.)

func stage_shot(which: String) -> void:
	var relay := LoopLink.Relay.new()
	game.make_link = func() -> NetLink: return LoopLink.new(relay)
	match which:
		"code":
			view = View.CODE
			code = "BX"
			cell = 7
		"lobby", "guest":
			var h := LoopLink.new(relay)
			h.host()
			var host_room := OnlineSession.hosting_on(h, "car_vega" if which == "guest" else Cars.get_car(game.car_index)["id"],
				SaveData.profile_name, SaveData.avatar)
			var rooms: Array = [host_room]
			for i in 2:  # two made-up guests with names and avatars (ON-8)
				var car: String = ["car_mesa", "car_kestrel"][i]
				var g := LoopLink.new(relay)
				g.join(h.room)
				rooms.append(OnlineSession.joining_on(g, car, OnlineBot.made_up_name(i, SaveData.profile_name), car))
			for i in 3:
				for r: OnlineSession in rooms:
					r.poll(0.0)
			game.online = host_room if which == "lobby" else rooms[1]
			rooms.erase(game.online)
			_staged = rooms
			row = Row.STAGE
		"regions":  # a relay that lists regions, as today's doesn't
			var two: Array[Dictionary] = [{"name": "US EAST", "url": "wss://us-east.invalid"},
				{"name": "EUROPE WEST", "url": "wss://eu-west.invalid"}]
			if _fetch != null:
				_fetch.cancel_request()  # (the real relay's answer, none, would clear them)
			set_regions(two)
			region = 1  # (shown picked, without changing the relay this run would use)
			on_region = true
		"error":
			var g := LoopLink.new(relay)
			g.join("ZZZZ")
			game.online = OnlineSession.joining_on(g, "car_vega")
			game.online.poll(0.0)
		"update":  # a guest on an older build than the host's (ON-14)
			var h := LoopLink.new(relay)
			h.host(_newer(Updater.version()))
			var host_room := OnlineSession.hosting_on(h, "car_vega")
			var g := LoopLink.new(relay)
			g.join(h.room)
			game.online = OnlineSession.joining_on(g, "car_vega")
			for i in 3:
				host_room.poll(0.0)
				game.online.poll(0.0)
			_staged = [host_room]


## The version after `v` (its minor up one), for the update screenshot's host.
static func _newer(v: String) -> String:
	var parts := v.split(".")
	return "%s.%d.0" % [parts[0], int(parts[1]) + 1] if parts.size() >= 2 else v + ".1"
