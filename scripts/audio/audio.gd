extends Node
## Audio autoload: the Music and SFX buses, the music player and a pool of one-shot
## players. Sounds are named by cue (see SoundBank); race sounds are driven by RaceAudio.

const POOL_SIZE := 10
## Buses a one-shot can play on: side -1 left, 0 center, 1 right (traffic whooshes).
const SIDE_BUSES := {-1: "SFX Left", 0: "SFX", 1: "SFX Right"}
const SIDE_PAN := 0.7
const DUCK_DB := -9.0  # the music under the announcer
const DUCK_SPEED := 30.0  # dB per second, down and back up
const HISTORY_SIZE := 64

var music: AudioStreamPlayer
var music_cue := ""
var paused := false
## Recent cues started, oldest first (for tests and debugging).
var history: Array[String] = []
var duck_db := 0.0  # how far the music is ducked now

var _duck_left := 0.0

var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	if music != null:
		return
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for side: int in [-1, 1]:
		var bus: String = SIDE_BUSES[side]
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "SFX")  # so the effects volume covers them
			var pan := AudioEffectPanner.new()
			pan.pan = side * SIDE_PAN
			AudioServer.add_bus_effect(i, pan)
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())  # crashes over music never clip
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


## Plays a one-shot cue on the next free pool player (or the oldest), panned to `side`
## (-1 left, 0 center, 1 right).
func play(cue: String, pitch := 1.0, side := 0) -> void:
	_log(cue)
	var s := SoundBank.stream(cue)
	if s == null or _pool.is_empty():
		return
	var p := _pool[_next]
	for i in POOL_SIZE:
		var q := _pool[(_next + i) % POOL_SIZE]
		if not q.playing:
			p = q
			break
	_next = (_pool.find(p) + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = SoundBank.volume_db(cue)
	p.pitch_scale = pitch
	p.bus = SIDE_BUSES.get(signi(side), "SFX")
	p.stream_paused = false
	if p.is_inside_tree():
		p.play()


## Starts a music cue, `from` seconds in (wrapped to its length).
func play_music(cue: String, from := 0.0) -> void:
	_log(cue)
	music_cue = cue
	if music == null:
		return
	music.stream = SoundBank.stream(cue)
	music.volume_db = SoundBank.volume_db(cue) + duck_db
	music.stream_paused = false
	if music.stream != null and music.is_inside_tree():
		music.play(fposmod(from, maxf(music.stream.get_length(), 0.001)))


## How far into the music it is, in seconds (0 when none plays).
func music_position() -> float:
	return music.get_playback_position() if music != null and music.playing else 0.0


## Ducks the music for `seconds` (the announcer speaking), then brings it back.
func duck(seconds: float) -> void:
	_duck_left = maxf(_duck_left, seconds)


func _process(dt: float) -> void:
	step_duck(dt)


func step_duck(dt: float) -> void:
	if paused:
		return
	_duck_left = maxf(0.0, _duck_left - dt)
	duck_db = move_toward(duck_db, DUCK_DB if _duck_left > 0.0 else 0.0, DUCK_SPEED * dt)
	if music != null and music_cue != "":
		music.volume_db = SoundBank.volume_db(music_cue) + duck_db


func stop_music() -> void:
	music_cue = ""
	if music != null:
		music.stop()


## Holds music and one-shots where they are (pause menu, calibration).
func set_paused(on: bool) -> void:
	paused = on
	if music != null:
		music.stream_paused = on
	for p in _pool:
		p.stream_paused = on


## A player for a looping cue, not yet in the tree or playing; the caller owns it.
static func loop_player(cue: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = SoundBank.stream(cue)
	p.volume_db = SoundBank.volume_db(cue)
	return p


func _log(cue: String) -> void:
	history.append(cue)
	if history.size() > HISTORY_SIZE:
		history.pop_front()
