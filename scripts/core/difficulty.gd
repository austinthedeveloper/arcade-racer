class_name Difficulty
extends Resource
## A difficulty level: how fast the rivals are, how hard the rubber band pulls (Rivals.band),
## and the timer option it starts you on.

enum Level { EASY, NORMAL, HARD }

const NAMES := ["EASY", "NORMAL", "HARD"]
## The timer option (Settings.Clock) each level puts it on: relaxed, arcade, arcade. Hard's
## clock is tight through its checkpoint bonuses instead (clock_bonus, RC-23).
const TIMERS := [0, 1, 1]

@export var rival_pace := 1.0  ## on every rival's own pace
@export var band_ease := 0.05  ## most a rival ahead of you gives up
@export var band_boost := 0.04  ## most a rival behind you gains
@export var timer := 1  ## the Settings.Clock it sets the timer option to
@export var catch_up := true  ## a nitro charge back at each checkpoint in the last places (RC-16)
@export var clock_bonus := 1.0  ## on each checkpoint's time bonus, after the timer option (RC-23)
@export var crash_ease := 0.0  ## how much the player's crashes are spared (PlayerCar.crash_ease)


static func make(pace: float, ease: float, boost: float, clock: int, nitro := true, bonus := 1.0, crash := 0.0) -> Difficulty:
	var d := Difficulty.new()
	d.crash_ease = crash
	d.rival_pace = pace
	d.band_ease = ease
	d.band_boost = boost
	d.timer = clock
	d.catch_up = nitro
	d.clock_bonus = bonus
	return d


## Catch-up nitro (RC-16): the nitro charges a racer in `place` (1 is first) of a field of
## `field` gets back at a checkpoint. One in the last power_ups/catch_up_places places
## (Tuning) when the level allows it, none otherwise or racing alone.
func catch_up_nitro(place: int, field: int) -> int:
	if not catch_up or field < 2:
		return 0
	return 1 if place > field - Tuning.i("power_ups/catch_up_places") else 0


## The resource for a Level, its rival numbers and checkpoint bonuses from Tuning
## (difficulty/*, RC-21, RC-23). Easy: slower rivals that wait for you, a relaxed timer and
## bigger checkpoint bonuses. Hard: quicker rivals that hardly wait, smaller checkpoint bonuses
## (the arcade timer's start: on the tight one the autodrive can't reach Thunderhead's first
## checkpoint) and no catch-up nitro.
static func of(level: int) -> Difficulty:
	var l := clampi(level, 0, Level.size() - 1)
	var name: String = ["easy", "normal", "hard"][l]
	return make(Tuning.v("difficulty/%s_pace" % name), Tuning.v("difficulty/%s_ease" % name),
		Tuning.v("difficulty/%s_boost" % name), TIMERS[l], l != Level.HARD, Tuning.v("difficulty/%s_clock" % name),
		Tuning.v("difficulty/%s_crash_ease" % name))
