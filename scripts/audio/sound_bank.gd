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
	# The engine notes (EngineModels, PR-18): the small engine's and the V8's low layer, and
	# the turbo's whine and shift pop (the turbo's layers are engine_low and engine_high).
	"engine_small": ["sfx", true, -10.0],
	"engine_v8": ["sfx", true, -8.0],
	"turbo_whine": ["sfx", true, -21.0],
	"turbo_pop": ["sfx", false, -6.0],
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
	"radio_tune": ["sfx", false, -10.0],  # changing station
	"shutter": ["sfx", false, -6.0],  # the photo key (Photo)
	# The radio (Radio): each station's songs, played once each in turn (RaceAudio.radio_tick),
	# then its sting between them. Leveled to about -22 dB RMS once turned down. The newer songs
	# and the stings are in radio/, which the Web build leaves out (Radio.songs, Radio.has_sting:
	# there each station loops its first song, as before PR-24).
	"station_rock": ["music", false, -11.0],
	"station_synthwave": ["music", false, -9.5],
	"station_funk": ["music", false, -10.0],
	"station_techno": ["music", false, -10.5],
	"rock_dust_devil": ["radio", false, -12.0],
	"rock_mesa_run": ["radio", false, -12.1],
	"rock_high_noon": ["radio", false, -12.1],
	"rock_salt_flats": ["radio", false, -11.7],
	"synthwave_afterglow": ["radio", false, -9.1],
	"synthwave_chrome_heart": ["radio", false, -9.5],
	"synthwave_night_drive": ["radio", false, -9.1],
	"synthwave_palm_static": ["radio", false, -9.5],
	"funk_slick_back": ["radio", false, -10.3],
	"funk_double_parked": ["radio", false, -10.2],
	"funk_velvet_turn": ["radio", false, -9.6],
	"funk_tailwind": ["radio", false, -10.1],
	"techno_redline": ["radio", false, -10.3],
	"techno_overpass": ["radio", false, -10.4],
	"techno_grid_lock": ["radio", false, -10.9],
	"techno_static_bloom": ["radio", false, -10.5],
	"sting_rock": ["radio", false, -11.8],
	"sting_synthwave": ["radio", false, -8.3],
	"sting_funk": ["radio", false, -9.9],
	"sting_techno": ["radio", false, -4.7],
}

## The announcer's lines (Announcer.LINES) are cues too: vo_<id>, one-shots at this level.
const VOICE_DB := -2.0

static var _streams: Dictionary = {}


## [folder, loops, volume in dB] for a cue, or [] if there is no such cue.
static func entry(cue: String) -> Array:
	if CUES.has(cue):
		return CUES[cue]
	if cue.begins_with("vo_") and Announcer.LINES.has(cue.substr(3)):
		return ["sfx", false, VOICE_DB]
	return []


## The file a cue plays, or "" if none of its files exist.
static func path_for(cue: String) -> String:
	var e := entry(cue)
	if e.is_empty():
		return ""
	for ext in EXTENSIONS:
		var path := "%s%s/%s.%s" % [ROOT, e[0], cue, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


static func loops(cue: String) -> bool:
	var e := entry(cue)
	return not e.is_empty() and e[1]


static func volume_db(cue: String) -> float:
	var e := entry(cue)
	return e[2] if not e.is_empty() else 0.0


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
