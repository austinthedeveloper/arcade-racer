extends Node
## Audio autoload: the Music and SFX buses, the music player and a pool of one-shot
## players. Sounds are named by cue (see SoundBank); race sounds are driven by RaceAudio.

const POOL_SIZE := 8
const HISTORY_SIZE := 64

var music: AudioStreamPlayer
var music_cue := ""
var paused := false
## Recent cues started, oldest first (for tests and debugging).
var history: Array[String] = []

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


## Plays a one-shot cue on the next free pool player (or the oldest).
func play(cue: String, pitch := 1.0) -> void:
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
	p.stream_paused = false
	if p.is_inside_tree():
		p.play()


func play_music(cue: String) -> void:
	_log(cue)
	music_cue = cue
	if music == null:
		return
	music.stream = SoundBank.stream(cue)
	music.volume_db = SoundBank.volume_db(cue)
	music.stream_paused = false
	if music.stream != null and music.is_inside_tree():
		music.play()


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
