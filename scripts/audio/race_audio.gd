class_name RaceAudio
extends Node
## Race sounds. Watches the race each tick (after it updates) and turns what changed
## into cues: engine, tire, wind and slipstream loops follow the player's car, the nearest
## rival's engine follows its gap, the horn follows its button, one-shots mark events.
## Reads the race and never writes to it, so play is the same with or without sound.

const GEARS: Array[float] = PlayerCar.GEARS  # speed fraction where each gear ends
const FADE := 6.0  # loop level change per second
const HORN_FADE := 30.0  # the horn is on or off at once
const RIVAL_HEAR := 2500.0  # world units along the road a rival's engine carries
const WHOOSH_REACH := 1.0  # road half-widths to the side a passed car whooshes within
const PASS_WINDOW := 1000.0  # world units: a gap jump bigger than this is a wrap, not a pass
const SLIDE_SQUEAL := 0.6  # a power slide's squeal at a standstill, up to full at top speed
## The radio (PR-24): the now-playing tag stays up this long once it shows, and the race's
## first song waits for it until this far past GO (the countdown has the stage card).
const TAG_TIME := 4.0
const TAG_AFTER_GO := 5.0
const SONG_FALLBACK := 30.0  # seconds a song with no file counts as
## The announcer's line for each callout kind (Callouts.Kind).
const CALLOUT_LINES := {
	Callouts.Kind.GO: "go", Callouts.Kind.LAUNCH: "launch", Callouts.Kind.CHECKPOINT: "checkpoint",
	Callouts.Kind.TIME_EXTENDED: "time_extended", Callouts.Kind.NEAR_MISS: "near_miss",
	Callouts.Kind.BIG_AIR: "big_air", Callouts.Kind.FINAL_STRETCH: "final_stretch",
	Callouts.Kind.FIRST_PLACE: "first_place",
}
const PICKUP_CUES := {
	PowerUps.Kind.NITRO: "pickup_nitro", PowerUps.Kind.CLOCK: "pickup_clock",
	PowerUps.Kind.RAM: "pickup_ram", PowerUps.Kind.GHOST: "pickup_ghost",
}

var race: Node
var levels := {"engine_low": 0.0, "engine_high": 0.0, "skid": 0.0, "offroad": 0.0, "wind": 0.0, "draft": 0.0,
	"rival": 0.0, "horn": 0.0}
var pitches := {"engine_low": 1.0, "engine_high": 1.0, "skid": 1.0, "offroad": 1.0, "wind": 1.0, "draft": 1.0,
	"rival": 1.0, "horn": 1.0}

var _loops := {}
var _player: PlayerCar
var _state := -1
var _count := 0
var _checkpoint := 0
var _nitro := 0
var _tick := 0
var _paused := false
var _draft_time := 0.0
var station := 0  # the radio station playing (Radio)
var song := 0  # its song playing, or the one the sting leads into (Radio.song_cue)
var in_sting := false  # the station's sting is playing, between songs
var cue_left := 0.0  # seconds left of the song or sting playing
var radio_on := false  # music is playing (it stops at the finish and at TIME UP)
## The now-playing tag: seconds it has been up (-1 when it's not), and a song that started
## and is still to be tagged (it waits for TAG_AFTER_GO).
var tag_age := -1.0
var tag_pending := false
var announcer := Announcer.new()
var _callout := {}  # the callout up last tick, to notice a new one
var _hurried := false
var _rng := RandomNumberGenerator.new()  # SHUFFLE's own: play never sees it
var _gaps := {}  # traffic car or rival -> its gap ahead of the player last tick (whooshes)


func _init(r: Node = null) -> void:
	race = r
	process_physics_priority = 100  # after the race's own tick


func _ready() -> void:
	if not _loops.is_empty():
		return
	for cue in levels:
		var p := Audio.loop_player(cue)
		add_child(p)
		_loops[cue] = p


func _physics_process(dt: float) -> void:
	update(dt)


func update(dt: float) -> void:
	if race == null or race.player == null:
		return
	var paused: bool = race.paused or race.calibration.visible
	if paused != _paused:
		_paused = paused
		Audio.set_paused(paused)
		for p: AudioStreamPlayer in _loops.values():
			p.stream_paused = paused
	if paused:
		return
	if race.player != _player:
		_new_race()
	_events()
	radio_tick(dt)
	_announce(dt)
	_set_loops(dt)


## start_race() makes a new PlayerCar: reset everything and start the music.
func _new_race() -> void:
	_player = race.player
	_state = race.state
	_count = 0
	_checkpoint = race.next_checkpoint
	_nitro = _player.nitro_charges
	_tick = 0
	_draft_time = 0.0
	_gaps.clear()
	station = Radio.start_station(Settings.radio, _rng.randi(), Radio.for_theme(race.track.theme))
	song = posmod(_rng.randi(), Radio.song_count(station))
	radio_on = true
	tag_age = -1.0
	_start_cue(false)
	announcer.reset()
	announcer.say("ready")
	_callout = {}
	_hurried = false


## The radio button: the next station, its song (or sting) carrying on at the same point,
## so the music never drops out.
func next_station() -> void:
	var at := cue_length(current_cue()) - cue_left
	station = Radio.next(station)
	Audio.play("radio_tune")
	if radio_on and race != null and race.state != race.State.FINISHED and race.state != race.State.TIME_UP:
		_start_cue(in_sting, at)


## What the radio is playing: the station's song, or its sting between songs.
func current_cue() -> String:
	return Radio.sting(station) if in_sting else Radio.song_cue(station, song)


## A cue's length in seconds (SONG_FALLBACK without a file).
static func cue_length(cue: String) -> float:
	var s := SoundBank.stream(cue)
	var n := s.get_length() if s != null else 0.0
	return n if n > 0.0 else SONG_FALLBACK


## The radio's clock (PR-24): a song plays once, then the station's sting, then its next
## song, round the list. A new song is tagged on the HUD (tag_age) once the race is
## TAG_AFTER_GO past GO.
func radio_tick(dt: float) -> void:
	if not radio_on:
		return
	cue_left -= dt
	if cue_left <= 0.0:
		if in_sting or not Radio.has_sting(station):
			song = Radio.next_song(station, song)
			_start_cue(false)
		else:
			_start_cue(true)
	if tag_pending and race.state == race.State.RACING and race.race_time >= TAG_AFTER_GO:
		tag_pending = false
		tag_age = 0.0
	elif tag_age >= 0.0:
		tag_age += dt
		if tag_age > TAG_TIME:
			tag_age = -1.0


## Starts the song (or, `sting`, the sting) `from` seconds in.
func _start_cue(sting: bool, from := 0.0) -> void:
	in_sting = sting
	var cue := current_cue()
	var length := cue_length(cue)
	from = fposmod(from, length)
	Audio.play_music(cue, from)
	cue_left = length - from
	if not sting:
		tag_pending = true
		tag_age = -1.0


func _radio_off() -> void:
	radio_on = false
	tag_pending = false
	tag_age = -1.0
	Audio.stop_music()


func _events() -> void:
	var state: int = race.state
	if state == race.State.COUNTDOWN:
		var n := ceili(race.countdown)
		if n != _count and n > 0:
			_count = n
			Audio.play("beep")
	if state != _state:
		match state:
			race.State.RACING:
				Audio.play("go")
			race.State.FINISHED:
				_radio_off()
				Audio.play("finish")
				Audio.play("crowd")
				announcer.say(Announcer.finish_line(race.place, not race.rivals.cars.is_empty()))
			race.State.TIME_UP:
				_radio_off()
				Audio.play("time_up")
				announcer.say("time_up")
		_state = state
	if race.next_checkpoint > _checkpoint:
		Audio.play("checkpoint")
	_checkpoint = race.next_checkpoint
	if _player.nitro_charges < _nitro:
		Audio.play("nitro")
	_nitro = _player.nitro_charges
	if race.picked_up:
		Audio.play(PICKUP_CUES.get(race.pickup_gave, "pickup_nitro"))
	if _player.draft_time > _draft_time:
		Audio.play("draft_boost")
	_draft_time = _player.draft_time
	_whooshes()
	if _player.rammed:
		Audio.play("bump", 0.7)
	if _player.crashed:
		Audio.play("crash")
	elif _player.bumped:
		Audio.play("bump")
	if _player.landed:
		Audio.play("land")
	if race.fx.thunder:
		Audio.play("thunder", 1.0, 0, Weather.thunder_muffled(race.fx.shelter))  # under cover: muffled (WS-12)
	if state == race.State.RACING and race.time_left < Cfg.LOW_TIME:
		var s := ceili(race.time_left)
		if s != _tick:
			_tick = s
			Audio.play("tick")
		if not _hurried:
			_hurried = true
			announcer.say("hurry")


func _set_loops(dt: float) -> void:
	var pct := _player.speed_percent()
	var rpm := engine_rpm(pct, _player.gear if _player.manual else 0)
	var high := smoothstep(0.35, 0.85, rpm)
	var target := {
		"engine_low": 1.0 - 0.7 * high,
		"engine_high": high,
		"skid": skid_level(_player),
		"offroad": offroad_level(_player),
	}
	pitches["engine_low"] = 0.8 + rpm
	pitches["engine_high"] = 0.6 + 0.9 * rpm
	pitches["skid"] = 0.9 + 0.2 * pct
	pitches["offroad"] = 0.7 + 0.6 * pct
	target["wind"] = wind_level(_player)
	pitches["wind"] = 0.8 + 0.4 * clampf(pct, 0.0, 1.2)
	target["draft"] = draft_level(_player)
	var rival := _nearest_rival()
	target["rival"] = 0.0 if rival == null else rival_level(rival.distance - _player.distance)
	if rival != null:
		pitches["rival"] = 0.8 + engine_rpm(rival.speed_percent())
	target["horn"] = 1.0 if race.horn and race.state != race.State.FINISHED else 0.0
	if car_quiet(race):
		for cue in target:
			target[cue] = 0.0
	for cue in levels:
		levels[cue] = move_toward(levels[cue], target[cue], dt * (HORN_FADE if cue == "horn" else FADE))
		var p: AudioStreamPlayer = _loops.get(cue)
		if p == null:
			continue
		p.volume_db = SoundBank.volume_db(cue) + linear_to_db(maxf(levels[cue], 0.0001))
		p.pitch_scale = pitches[cue]
		var on: bool = levels[cue] > 0.01
		if on != p.playing and p.is_inside_tree():
			if on:
				p.play()
			else:
				p.stop()


## Whether the car's loops (engine, tires, wind, the rival, the horn) fade out: under the
## instant replay, which holds the car still where the finish left it, and under the results
## or once the clock ran out, where the car has stopped and would only idle on.
static func car_quiet(r: Node) -> bool:
	if r.replaying or r.results.visible:
		return true
	return r.state == r.State.TIME_UP and r.player.speed <= 0.0


## Engine revs, 0..1 in each gear (a shift drops them back), up to 1.2 on nitro. `gear` 0
## is automatic: the gear the speed is in. A manual gear (1..5, PlayerCar.gear) revs through
## the same band; below it (too tall a gear) the revs sag toward 0, and above it they sit at
## 1, on the limiter (PlayerCar.gear_limit), except in the top gear.
static func engine_rpm(pct: float, gear := 0) -> float:
	pct = maxf(pct, 0.0)
	var g := (PlayerCar.auto_gear(pct) if gear <= 0 else mini(gear, GEARS.size() - 1)) - 1
	var floor_rpm := 0.0 if g == 0 else 0.35 + 0.05 * g
	if pct < GEARS[g]:
		return floor_rpm * pct / GEARS[g]
	var t := (pct - GEARS[g]) / (GEARS[g + 1] - GEARS[g])
	if g < GEARS.size() - 2 and gear > 0:
		t = minf(t, 1.0)
	return minf(lerpf(floor_rpm, 1.0, t), 1.2)


## Tire squeal: braking hard, cornering at full lock at speed, a power slide, or sliding
## after a crash.
static func skid_level(p: PlayerCar) -> float:
	if p.airborne or p.offroad:
		return 0.0
	var pct := p.speed_percent()
	if p.crash_time > 0.0:
		return clampf(pct * 2.0, 0.0, 1.0)
	var level := 0.0
	if p.braking and pct > 0.25:
		level = pct
	if absf(p.steer) > 0.75 and pct > 0.6:
		level = maxf(level, (absf(p.steer) - 0.75) * 4.0 * pct)
	if p.slide != 0.0:
		level = maxf(level, SLIDE_SQUEAL + (1.0 - SLIDE_SQUEAL) * pct)
	return clampf(level, 0.0, 1.0)


## Gravel rumble off the road.
static func offroad_level(p: PlayerCar) -> float:
	if not p.offroad or p.airborne:
		return 0.0
	return clampf(p.speed_percent() * 3.0, 0.0, 1.0)


## A whoosh for each traffic car or rival the player passes (or that passes the player)
## close alongside, panned to its side.
func _whooshes() -> void:
	var length: float = race.track.length
	var seen := {}
	var cars: Array = race.traffic.cars if race.traffic != null else []
	for car in cars:
		_whoosh_check(car, wrapf(car.z - (_player.position + Cfg.PLAYER_Z), -length * 0.5, length * 0.5), car.offset, seen)
	for r: RivalCar in race.rivals.cars:
		_whoosh_check(r, wrapf(r.position - _player.position, -length * 0.5, length * 0.5), r.x, seen)
	_gaps = seen


func _whoosh_check(car, gap: float, x: float, seen: Dictionary) -> void:
	seen[car] = gap
	if _gaps.has(car) and passed(_gaps[car], gap) and absf(x - _player.x) < WHOOSH_REACH:
		Audio.play("whoosh", 0.9 + 0.2 * clampf(_player.speed_percent(), 0.0, 1.0), pan_side(x, _player.x))


func _nearest_rival() -> RivalCar:
	var best: RivalCar = null
	for r: RivalCar in race.rivals.cars:
		if best == null or absf(r.distance - _player.distance) < absf(best.distance - _player.distance):
			best = r
	return best


## Whether a car's gap ahead of the player went through zero this tick (a pass, either
## way), and not by wrapping around the track.
static func passed(gap_before: float, gap: float) -> bool:
	if absf(gap - gap_before) > PASS_WINDOW:
		return false
	return (gap_before > 0.0 and gap <= 0.0) or (gap_before < 0.0 and gap >= 0.0)


## Which side a car at road x sounds on, seen from the player at player_x: -1 left, 1 right.
static func pan_side(x: float, player_x: float) -> int:
	return -1 if x < player_x else 1


## Wind over the car: silent at a crawl, full at top speed; quieter in the air.
static func wind_level(p: PlayerCar) -> float:
	var level := smoothstep(0.15, 1.0, p.speed_percent())
	return level * (0.6 if p.airborne else 1.0)


## The slipstream buffet, with the draft meter (Draft).
static func draft_level(p: PlayerCar) -> float:
	return clampf(p.draft * 1.2, 0.0, 1.0) if p.speed_percent() > Tuning.v("draft/min_speed") else 0.0


## The nearest rival's engine, by its gap along the road (either way).
static func rival_level(gap: float) -> float:
	var t := 1.0 - absf(gap) / RIVAL_HEAR
	return t * t if t > 0.0 else 0.0


## The announcer: a line for each new callout (GO, CHECKPOINT, NEAR MISS and the rest) on
## top of the finish and the low clock, then whichever line starts now, with the music
## ducked under it.
func _announce(dt: float) -> void:
	var c: Dictionary = race.callouts.current
	if not c.is_empty() and not is_same(c, _callout):
		announcer.say(CALLOUT_LINES.get(c["kind"], ""))
		if c.get("line2", "") == Callouts.TEXT[Callouts.Kind.TIME_EXTENDED]:  # one burst, both lines (PR-15)
			announcer.say(CALLOUT_LINES[Callouts.Kind.TIME_EXTENDED])
	_callout = c
	var line := announcer.update(dt)
	if line != "":
		Audio.play(Announcer.cue(line))
		Audio.duck(Announcer.duration(line))
