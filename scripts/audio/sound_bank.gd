class_name SoundBank
extends RefCounted
## Every sound the game plays, by cue name. A cue plays the first of
## res://assets/audio/<folder>/<cue>.ogg, .wav or .mp3 that exists, so a sound pack
## replaces a generated placeholder by dropping in a file with the cue's name.
## Looping is set here, not in the import settings, so swapped files loop too.

const ROOT := "res://assets/audio/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

## cue: [folder, loops, volume in dB]. Level a new pack here.
const CUES := {
	"engine_low": ["sfx", true, -8.0],
	"engine_high": ["sfx", true, -10.0],
	"skid": ["sfx", true, -12.0],
	"offroad": ["sfx", true, -10.0],
	"nitro": ["sfx", false, -6.0],
	"crash": ["sfx", false, -6.0],
	"bump": ["sfx", false, -6.0],
	"land": ["sfx", false, -6.0],
	"beep": ["sfx", false, -10.0],
	"go": ["sfx", false, -10.0],
	"tick": ["sfx", false, -14.0],
	"checkpoint": ["sfx", false, -8.0],
	"finish": ["sfx", false, -8.0],
	"time_up": ["sfx", false, -8.0],
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
