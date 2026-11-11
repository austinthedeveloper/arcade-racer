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


## The resource for a Level, its rival numbers from Tuning (difficulty/*, RC-21). Easy:
## slower rivals that wait for you, and a relaxed clock. Hard: quicker rivals that hardly
## wait, a tight clock and no catch-up nitro.
static func of(level: int) -> Difficulty:
	var name: String = ["easy", "normal", "hard"][clampi(level, 0, Level.size() - 1)]
	var d := make(Tuning.v("difficulty/%s_pace" % name), Tuning.v("difficulty/%s_ease" % name),
		Tuning.v("difficulty/%s_boost" % name), clampi(level, 0, Level.size() - 1), level != Level.HARD)
	return d
