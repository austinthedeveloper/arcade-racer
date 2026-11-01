class_name RaceAudio
extends Node
## Race sounds. Watches the race each tick (after it updates) and turns what changed
## into cues: engine, tire, wind and slipstream loops follow the player's car, the nearest
## rival's engine follows its gap, the horn follows its button, one-shots mark events.
## Reads the race and never writes to it, so play is the same with or without sound.

const GEARS: Array[float] = [0.0, 0.16, 0.34, 0.54, 0.76, 1.0]  # speed fraction where each gear ends
const FADE := 6.0  # loop level change per second
const HORN_FADE := 30.0  # the horn is on or off at once
const RIVAL_HEAR := 2500.0  # world units along the road a rival's engine carries
const WHOOSH_REACH := 1.0  # road half-widths to the side a passed car whooshes within
const PASS_WINDOW := 1000.0  # world units: a gap jump bigger than this is a wrap, not a pass
const SLIDE_SQUEAL := 0.6  # a power slide's squeal at a standstill, up to full at top speed
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
	station = Radio.start_station(Settings.radio, _rng.randi())
	Audio.play_music(Radio.cue(station))
	announcer.reset()
	announcer.say("ready")
	_callout = {}
	_hurried = false


## The radio button: the next station, carrying on at the same point in the loop, so the
## music never drops out.
func next_station() -> void:
	var at := Audio.music_position()
	station = Radio.next(station)
	Audio.play("radio_tune")
	if race != null and race.state != race.State.FINISHED and race.state != race.State.TIME_UP:
		Audio.play_music(Radio.cue(station), at)


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
				Audio.stop_music()
				Audio.play("finish")
				Audio.play("crowd")
				announcer.say(Announcer.finish_line(race.place, not race.rivals.cars.is_empty()))
			race.State.TIME_UP:
				Audio.stop_music()
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
		Audio.play("thunder")
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
	var rpm := engine_rpm(pct)
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


## Engine revs, 0..1 in each gear (a shift drops them back), up to 1.2 on nitro.
static func engine_rpm(pct: float) -> float:
	pct = maxf(pct, 0.0)
	var last := GEARS.size() - 2
	for g in GEARS.size() - 1:
		if pct < GEARS[g + 1] or g == last:
			var t := (pct - GEARS[g]) / (GEARS[g + 1] - GEARS[g])
			var floor_rpm := 0.0 if g == 0 else 0.35 + 0.05 * g
			return minf(lerpf(floor_rpm, 1.0, t), 1.2)
	return 0.0


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
	return clampf(p.draft * 1.2, 0.0, 1.0) if p.speed_percent() > Draft.MIN_SPEED else 0.0


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
	_callout = c
	var line := announcer.update(dt)
	if line != "":
		Audio.play(Announcer.cue(line))
		Audio.duck(Announcer.duration(line))
