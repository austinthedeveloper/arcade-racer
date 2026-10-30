class_name RaceAudio
extends Node
## Race sounds. Watches the race each tick (after it updates) and turns what changed
## into cues: engine and tire loops follow the player's car, one-shots mark events.
## Reads the race and never writes to it, so play is the same with or without sound.

const GEARS: Array[float] = [0.0, 0.16, 0.34, 0.54, 0.76, 1.0]  # speed fraction where each gear ends
const LOW_TIME := 10.0  # seconds left when the clock starts ticking
const FADE := 6.0  # loop level change per second

var race: Node
var levels := {"engine_low": 0.0, "engine_high": 0.0, "skid": 0.0, "offroad": 0.0}
var pitches := {"engine_low": 1.0, "engine_high": 1.0, "skid": 1.0, "offroad": 1.0}

var _loops := {}
var _player: PlayerCar
var _state := -1
var _count := 0
var _checkpoint := 0
var _nitro := 0
var _tick := 0
var _paused := false


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
	_set_loops(dt)


## start_race() makes a new PlayerCar: reset everything and start the music.
func _new_race() -> void:
	_player = race.player
	_state = race.state
	_count = 0
	_checkpoint = race.next_checkpoint
	_nitro = _player.nitro_charges
	_tick = 0
	Audio.play_music("music_race")


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
			race.State.TIME_UP:
				Audio.stop_music()
				Audio.play("time_up")
		_state = state
	if race.next_checkpoint > _checkpoint:
		Audio.play("checkpoint")
	_checkpoint = race.next_checkpoint
	if _player.nitro_charges < _nitro:
		Audio.play("nitro")
	_nitro = _player.nitro_charges
	if _player.crashed:
		Audio.play("crash")
	elif _player.bumped:
		Audio.play("bump")
	if _player.landed:
		Audio.play("land")
	if state == race.State.RACING and race.time_left < LOW_TIME:
		var s := ceili(race.time_left)
		if s != _tick:
			_tick = s
			Audio.play("tick")


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
	for cue in levels:
		levels[cue] = move_toward(levels[cue], target[cue], dt * FADE)
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


## Tire squeal: braking hard, cornering at full lock at speed, or sliding after a crash.
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
	return clampf(level, 0.0, 1.0)


## Gravel rumble off the road.
static func offroad_level(p: PlayerCar) -> float:
	if not p.offroad or p.airborne:
		return 0.0
	return clampf(p.speed_percent() * 3.0, 0.0, 1.0)
