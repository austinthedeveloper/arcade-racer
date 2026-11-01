class_name SoundBank
extends RefCounted
## Every sound the game plays, by cue name. A cue plays the first of
## res://assets/audio/<folder>/<cue>.ogg, .wav or .mp3 that exists, so a sound pack
## replaces a generated placeholder by dropping in a file with the cue's name.
## Looping is set here, not in the import settings, so swapped files loop too.

const ROOT := "res://assets/audio/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

## cue: [folder, loops, volume in dB]. Level a new pack here. The levels put each cue's
## loudness (RMS) where the mix wants it; `make_audio.py` prints every file's.
const CUES := {
	"engine_low": ["sfx", true, -9.5],
	"engine_high": ["sfx", true, -13.5],
	"rival": ["sfx", true, -16.0],  # the nearest rival's engine, under the player's own
	"skid": ["sfx", true, -10.0],
	"offroad": ["sfx", true, -15.0],
	"wind": ["sfx", true, -15.0],  # rises with speed
	"draft": ["sfx", true, -12.0],  # in a slipstream
	"horn": ["sfx", true, -11.0],  # while the horn button is held
	"nitro": ["sfx", false, -5.0],
	"crash": ["sfx", false, -5.0],
	"bump": ["sfx", false, -6.0],
	"land": ["sfx", false, -5.0],
	"whoosh": ["sfx", false, -7.0],  # passing traffic or a rival, panned to its side
	"draft_boost": ["sfx", false, -4.0],
	"pickup_nitro": ["sfx", false, -4.0],
	"pickup_clock": ["sfx", false, -5.0],
	"pickup_ram": ["sfx", false, -6.0],
	"pickup_ghost": ["sfx", false, -5.0],
	"beep": ["sfx", false, -6.0],
	"go": ["sfx", false, -6.0],
	"tick": ["sfx", false, -9.0],
	"checkpoint": ["sfx", false, -6.0],
	"finish": ["sfx", false, -6.0],
	"crowd": ["sfx", false, -1.0],  # the finish-line roar: the loudest cue on purpose
	"time_up": ["sfx", false, -3.0],
	"thunder": ["sfx", false, -9.0],  # a beat after a lightning flash (Weather)
	"music_race": ["music", true, -12.0],
}

static var _streams: Dictionary = {}


## The file a cue plays, or "" if none of its files exist.
static func path_for(cue: String) -> String:
	if not CUES.has(cue):
		return ""
	for ext in EXTENSIONS:
		var path := "%s%s/%s.%s" % [ROOT, CUES[cue][0], cue, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


static func loops(cue: String) -> bool:
	return CUES.has(cue) and CUES[cue][1]


static func volume_db(cue: String) -> float:
	return CUES[cue][2] if CUES.has(cue) else 0.0


## The cue's stream, loaded once, with looping set; null (and a warning) if it has no file.
static func stream(cue: String) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var path := path_for(cue)
	var s: AudioStream = load(path) if path != "" else null
	if s == null:
		push_warning("No sound for cue: " + cue)
	else:
		set_loop(s, loops(cue))
	_streams[cue] = s
	return s


static func set_loop(s: AudioStream, on: bool) -> void:
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED
		wav.loop_begin = 0
		wav.loop_end = int(roundf(wav.get_length() * wav.mix_rate))
	elif "loop" in s:  # AudioStreamOggVorbis, AudioStreamMP3
		s.set("loop", on)


## Forgets loaded streams (after files change on disk).
static func clear() -> void:
	_streams.clear()
