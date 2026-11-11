class_name Radio
extends RefCounted
## The race radio: four stations of original music (tools/make_audio.py). The player
## picks one before the race (car select, or Options > Audio) or leaves it on SHUFFLE,
## and the radio button changes station mid-race. On SHUFFLE each stage starts on its own
## station, its theme's "station" (PR-19: Neon Strip on synthwave, Redrock on rock).
## Radio v2 (PR-24): each station plays its five songs in turn, once each, with the
## station's sting between them (RaceAudio.radio_tick), and the HUD tags each song as it
## starts. A station's first song is its `cue`, the loop it had before.

const STATIONS := [
	{"cue": "station_rock", "name": "98.3 THE CANYON", "genre": "ROCK", "sting": "sting_rock",
		"songs": [["station_rock", "SUNDOWN HIGHWAY"], ["rock_dust_devil", "DUST DEVIL"], ["rock_mesa_run", "MESA RUN"],
			["rock_high_noon", "HIGH NOON"], ["rock_salt_flats", "SALT FLATS"]]},
	{"cue": "station_synthwave", "name": "104.7 NEON FM", "genre": "SYNTHWAVE", "sting": "sting_synthwave",
		"songs": [["station_synthwave", "NEON MILES"], ["synthwave_afterglow", "AFTERGLOW"],
			["synthwave_chrome_heart", "CHROME HEART"], ["synthwave_night_drive", "NIGHT DRIVE"],
			["synthwave_palm_static", "PALM STATIC"]]},
	{"cue": "station_funk", "name": "92.1 SOUL STOP", "genre": "FUNK", "sting": "sting_funk",
		"songs": [["station_funk", "SOUL STOP STRUT"], ["funk_slick_back", "SLICK BACK"], ["funk_double_parked", "DOUBLE PARKED"],
			["funk_velvet_turn", "VELVET TURN"], ["funk_tailwind", "TAILWIND"]]},
	{"cue": "station_techno", "name": "107.9 PULSE", "genre": "TECHNO", "sting": "sting_techno",
		"songs": [["station_techno", "PULSE WIDTH"], ["techno_redline", "REDLINE"], ["techno_overpass", "OVERPASS"],
			["techno_grid_lock", "GRID LOCK"], ["techno_static_bloom", "STATIC BLOOM"]]},
]
## The setting's value for each stage's own station (Radio.for_theme; any one where it names none).
const SHUFFLE := -1


static func count() -> int:
	return STATIONS.size()


static var _lists := {}  # station -> its songs that have files (songs_with)
static var _stings := {}  # station -> its sting has a file (has_sting)


## The station's first song.
static func cue(station: int) -> String:
	return STATIONS[station]["cue"]


## The [cue, title] songs in `songs` that `has` (cue -> bool) says are there; the first
## always, so a station never goes quiet. The Web build has no radio/ folder (its download
## budget), so it loops each station's first song with no sting between (has_sting).
static func songs_with(songs: Array, has: Callable) -> Array:
	var out := []
	for i in songs.size():
		if i == 0 or has.call(songs[i][0]):
			out.append(songs[i])
	return out


## A station's songs this build has.
static func songs(station: int) -> Array:
	if not _lists.has(station):
		_lists[station] = songs_with(STATIONS[station]["songs"], func(c: String) -> bool: return SoundBank.path_for(c) != "")
	return _lists[station]


## How many songs a station plays.
static func song_count(station: int) -> int:
	return songs(station).size()


## Song `song` of a station (wrapped round its list): its cue.
static func song_cue(station: int, song: int) -> String:
	return songs(station)[posmod(song, song_count(station))][0]


## Song `song` of a station: its title, for the now-playing tag.
static func song_title(station: int, song: int) -> String:
	return songs(station)[posmod(song, song_count(station))][1]


## The short ident a station plays between songs.
static func sting(station: int) -> String:
	return STATIONS[station]["sting"]


## Whether this build has the station's sting (the Web build has no radio/ folder): without
## it the radio goes straight on to the next song (RaceAudio.radio_tick).
static func has_sting(station: int) -> bool:
	if not _stings.has(station):
		_stings[station] = SoundBank.path_for(sting(station)) != ""
	return _stings[station]


## Every song and sting cue, every station.
static func all_cues() -> Array[String]:
	var out: Array[String] = []
	for i in count():
		for k in song_count(i):
			out.append(song_cue(i, k))
		out.append(sting(i))
	return out


## The song after `song`, round to the first.
static func next_song(station: int, song: int) -> int:
	return posmod(song + 1, song_count(station))


## The now-playing tag's words: the song's title, and the station it's on.
static func now_playing(station: int, song: int) -> Array[String]:
	return [song_title(station, song), station_name(station)]


static func station_name(station: int) -> String:
	return STATIONS[station]["name"]


static func genre(station: int) -> String:
	return STATIONS[station]["genre"]


## The next station up the dial, round to the first.
static func next(station: int) -> int:
	return (station + 1) % count()


## The setting after this one: SHUFFLE, then each station, then SHUFFLE again.
static func next_setting(setting: int) -> int:
	return SHUFFLE if setting >= count() - 1 else setting + 1


## What the setting shows: SHUFFLE or the station's genre.
static func setting_name(setting: int) -> String:
	return "SHUFFLE" if setting == SHUFFLE else genre(setting)


## The station a stage's `theme` names (its "station" cue), or -1 when it names none.
static func for_theme(theme: Dictionary) -> int:
	var want := str(theme.get("station", ""))
	for i in count():
		if cue(i) == want:
			return i
	return -1


## The station a race starts on: the chosen one; on SHUFFLE the stage's own (`stage`, from
## for_theme), or with none `roll` (any whole number) picks one.
static func start_station(setting: int, roll: int, stage := -1) -> int:
	if setting >= 0 and setting < count():
		return setting
	return stage if stage >= 0 and stage < count() else posmod(roll, count())
