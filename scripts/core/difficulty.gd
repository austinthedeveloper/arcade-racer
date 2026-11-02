class_name Difficulty
extends Resource
## A difficulty level: how fast the rivals are, how hard the rubber band pulls (Rivals.band),
## and the timer option it starts you on.

enum Level { EASY, NORMAL, HARD }

const NAMES := ["EASY", "NORMAL", "HARD"]

@export var rival_pace := 1.0  ## on every rival's own pace
@export var band_ease := 0.05  ## most a rival ahead of you gives up
@export var band_boost := 0.04  ## most a rival behind you gains
@export var timer := 1  ## the Settings.Clock it sets the timer option to
@export var catch_up := true  ## a nitro charge back at each checkpoint in the last places (RC-16)


static func make(pace: float, ease: float, boost: float, clock: int, nitro := true) -> Difficulty:
	var d := Difficulty.new()
	d.rival_pace = pace
	d.band_ease = ease
	d.band_boost = boost
	d.timer = clock
	d.catch_up = nitro
	return d


## Catch-up nitro (RC-16): the nitro charges a racer in `place` (1 is first) of a field of
## `field` gets back at a checkpoint. One in the last power_ups/catch_up_places places
## (Tuning) when the level allows it, none otherwise or racing alone.
func catch_up_nitro(place: int, field: int) -> int:
	if not catch_up or field < 2:
		return 0
	return 1 if place > field - Tuning.i("power_ups/catch_up_places") else 0


## The resource for a Level. Easy: slower rivals that wait for you, and a relaxed clock. Hard:
## quicker rivals that hardly wait, a tight clock and no catch-up nitro.
static func of(level: int) -> Difficulty:
	match level:
		Level.EASY:
			return make(0.94, 0.07, 0.02, 0)
		Level.HARD:
			return make(1.03, 0.02, 0.06, 2, false)
	return make(1.0, Rivals.BAND_EASE, Rivals.BAND_BOOST, 1)
