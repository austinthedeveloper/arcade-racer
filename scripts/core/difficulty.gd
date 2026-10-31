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


static func make(pace: float, ease: float, boost: float, clock: int) -> Difficulty:
	var d := Difficulty.new()
	d.rival_pace = pace
	d.band_ease = ease
	d.band_boost = boost
	d.timer = clock
	return d


## The resource for a Level. Easy: slower rivals that wait for you, and a relaxed clock. Hard:
## quicker rivals that hardly wait, and a tight clock.
static func of(level: int) -> Difficulty:
	match level:
		Level.EASY:
			return make(0.94, 0.07, 0.02, 0)
		Level.HARD:
			return make(1.03, 0.02, 0.06, 2)
	return make(1.0, Rivals.BAND_EASE, Rivals.BAND_BOOST, 1)
