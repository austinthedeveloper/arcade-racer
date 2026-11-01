class_name Unlocks
extends RefCounted
## What opens each car and stage (docs/roadmap/06, MP-4). The rules are plain functions of
## the save's progress, so tests can ask them directly; `car_unlocked` and `stage_unlocked`
## read the SaveData and Settings autoloads for the menus. Dev flags (--car, --stage) and
## tests pass straight by them.
##
## A stage's mirror (WS-6) opens when you win it: first past the line against rivals, in the
## Grand Tour or a Single Race (SaveData unlock id mirror_id). Paint colors by placing (CP-4)
## hook in here once they exist.

## Open from the start.
const STARTERS := ["car_vega", "car_bruiser", "car_kestrel", "car_sol"]
## Cars opened by the stage the Grand Tour has reached (stage numbers from 1).
const BY_STAGE := {
	"car_skipper": 2, "car_mesa": 3, "car_cyclone": 4, "car_phantom": 5, "car_halo": 6, "car_tempest": 7,
}
## Opened by finishing the tour (SaveData unlock id, set by the race).
const TOUR_CAR := Tour.FINISH_UNLOCK
## Opened by a secret: Palm Coast finished without touching traffic (SaveData unlock id).
const SECRET_CAR := "car_hauler"
const SECRET_STAGE := 0


## Whether car `id` is open, given the furthest stage reached (index), the save's unlock ids
## and the unlock-everything option.
static func car_open(id: String, furthest_stage: int, unlocked: Array, everything: bool) -> bool:
	if everything or STARTERS.has(id) or unlocked.has(id):
		return true
	if BY_STAGE.has(id):
		return furthest_stage + 1 >= int(BY_STAGE[id])
	return false


## Stages open up as the tour reaches them.
static func stage_open(index: int, furthest_stage: int, everything: bool) -> bool:
	return everything or index <= furthest_stage


## What a locked car's card says opens it.
static func car_condition(id: String) -> String:
	if BY_STAGE.has(id):
		return "Reach stage %d in the Grand Tour" % int(BY_STAGE[id])
	if id == TOUR_CAR:
		return "Finish the Grand Tour"
	if id == SECRET_CAR:
		return "A secret: keep Palm Coast clean"
	return ""


static func stage_condition(index: int) -> String:
	return "Reach stage %d in the Grand Tour" % (index + 1)


## The SaveData unlock id of stage `index`'s mirror: "mirror_" and the stage's id.
static func mirror_id(index: int) -> String:
	return "mirror_" + Stages.POSTCARDS[index]


## Whether stage `index` can be raced mirrored, given the save's unlock ids.
static func mirror_open(index: int, unlocked: Array, everything: bool) -> bool:
	return everything or unlocked.has(mirror_id(index))


static func mirror_condition(_index: int) -> String:
	return "Win this stage to race it mirrored"


## Whether a finish earns the stage's mirror: a win, against rivals.
static func earns_mirror(place: int, had_rivals: bool) -> bool:
	return had_rivals and place == 1


## Whether a finish earns the secret car: Palm Coast, with traffic on the road, without a
## single touch of it.
static func earns_secret(stage: int, touched_traffic: bool, had_traffic: bool) -> bool:
	return stage == SECRET_STAGE and had_traffic and not touched_traffic


## The cars open now that weren't with `before_furthest` and `before_unlocked`: for the
## finish to announce.
static func newly_open(before_furthest: int, before_unlocked: Array, after_furthest: int, after_unlocked: Array) -> Array[String]:
	var out: Array[String] = []
	for car: Dictionary in Cars.LIST:
		var id: String = car["id"]
		if car_open(id, after_furthest, after_unlocked, false) and not car_open(id, before_furthest, before_unlocked, false):
			out.append(id)
	return out


static func car_unlocked(id: String) -> bool:
	return car_open(id, SaveData.furthest_stage, SaveData.unlocks, Settings.unlock_all)


static func stage_unlocked(index: int) -> bool:
	return stage_open(index, SaveData.furthest_stage, Settings.unlock_all)


static func mirror_unlocked(index: int) -> bool:
	return mirror_open(index, SaveData.unlocks, Settings.unlock_all)
