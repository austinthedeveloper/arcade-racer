class_name Survival
extends RefCounted
## Survival (MP-13): one endless road, the stages chained end to end. Each stage is a leg:
## crossing its finish line goes straight on into the next stage's start (StageFlow dresses
## the end like it), round the open stages in tour order and back to Palm Coast. The score
## is the distance driven.
##
## The clock: the run starts with the first stage's start time; every checkpoint, and every
## leg's end, adds the stage's own allowance for the stretch ahead (its ARCADE clock, the same
## numbers a race uses), cut by survival/bonus_shrink for each checkpoint passed before it.
## The bonuses only ever shrink, to nothing after 1 / bonus_shrink checkpoints, so every run
## ends at TIME UP. The traffic ramps: each leg has survival/traffic_ramp more of the stage's
## own traffic than the last (up to survival/traffic_cap times it), and each checkpoint adds
## survival/checkpoint_cars more up the road.
##
## The numbers are in Tuning (the SURVIVAL page). The race (race.gd) keeps one of these for a
## run; the rules are plain functions here.

## The stages a run goes round, in order (the open stages: loop).
var stages: Array[int] = [0]
## The leg being driven (0 is the first).
var leg := 0
## Checkpoints passed this run, the legs' finish lines among them.
var passed := 0
## The distance of the legs already driven, world units.
var banked := 0.0


## A run round `open_stages` (stage indexes; the open ones, loop).
static func make(open_stages: Array[int]) -> Survival:
	var s := Survival.new()
	if not open_stages.is_empty():
		s.stages = open_stages.duplicate()
	return s


## The stages a run goes round: Palm Coast and every other stage that `is_open` (a stage
## index -> bool; Unlocks.stage_unlocked in the game) lets in, in tour order. A run never
## takes a driver onto a stage the tour hasn't reached.
static func loop(is_open: Callable) -> Array[int]:
	var out: Array[int] = [0]
	for i in range(1, Stages.count()):
		if is_open.call(i):
			out.append(i)
	return out


## The stage leg `n` is on, going round `stages`.
static func stage_for(n: int, stages_in_loop: Array[int]) -> int:
	return stages_in_loop[posmod(n, stages_in_loop.size())]


## The stage being driven, and the one after it (whose start this leg's end looks like).
func stage() -> int:
	return stage_for(leg, stages)


func next_stage() -> int:
	return stage_for(leg + 1, stages)


## What's left of a bonus after `checkpoints` passed: 1 at the start, shrinking by
## survival/bonus_shrink each, never below 0.
static func shrink(checkpoints: int) -> float:
	return maxf(0.0, 1.0 - checkpoints * Tuning.v("survival/bonus_shrink"))


## The clock at the start of a run whose first stage gives `base` seconds (its clock[0]).
static func start_time(base: float) -> float:
	return base * Tuning.v("survival/clock_scale")


## The bonus for the next checkpoint, `base` seconds being the stage's allowance for the
## stretch after it, with `checkpoints` already passed.
static func bonus(base: float, checkpoints: int) -> float:
	return base * Tuning.v("survival/clock_scale") * shrink(checkpoints)


## The checkpoint after which nothing more is given: the run is on its last stretch of clock.
static func last_bonus() -> int:
	var step := Tuning.v("survival/bonus_shrink")
	return ceili(1.0 / step) if step > 0.0 else -1


## The traffic on leg `n` for a stage whose own is `base` cars (after the traffic option).
static func traffic_for(n: int, base: int) -> int:
	var ramp := 1.0 + maxi(0, n) * Tuning.v("survival/traffic_ramp")
	return roundi(base * minf(ramp, Tuning.v("survival/traffic_cap")))


## Cars added up the road at a checkpoint.
static func checkpoint_cars() -> int:
	return Tuning.i("survival/checkpoint_cars")


## The run's distance with `leg_distance` driven on this leg.
func distance(leg_distance: float) -> float:
	return banked + maxf(0.0, leg_distance)


## A checkpoint passed: returns the bonus for it, `base` seconds being the stage's allowance
## for the stretch after it.
func checkpoint(base: float) -> float:
	var out := bonus(base, passed)
	passed += 1
	return out


## The leg's finish line crossed, `length` world units into it: banked, on to the next leg.
## Returns the bonus, `base` being the next stage's start time. It counts as a checkpoint.
func finish_leg(length: float, base: float) -> float:
	banked += maxf(0.0, length)
	leg += 1
	return checkpoint(base)
