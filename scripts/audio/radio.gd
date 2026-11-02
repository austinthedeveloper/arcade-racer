class_name Radio
extends RefCounted
## The race radio: four stations of original music (tools/make_audio.py). The player
## picks one before the race (car select, or Options > Audio) or leaves it on SHUFFLE,
## and the radio button changes station mid-race. On SHUFFLE each stage starts on its own
## station, its theme's "station" (PR-19: Neon Strip on synthwave, Redrock on rock).

const STATIONS := [
	{"cue": "station_rock", "name": "98.3 THE CANYON", "genre": "ROCK"},
	{"cue": "station_synthwave", "name": "104.7 NEON FM", "genre": "SYNTHWAVE"},
	{"cue": "station_funk", "name": "92.1 SOUL STOP", "genre": "FUNK"},
	{"cue": "station_techno", "name": "107.9 PULSE", "genre": "TECHNO"},
]
## The setting's value for each stage's own station (Radio.for_theme; any one where it names none).
const SHUFFLE := -1


static func count() -> int:
	return STATIONS.size()


static func cue(station: int) -> String:
	return STATIONS[station]["cue"]


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
