class_name Completion
extends RefCounted
## The completion page's sums (MP-17): what's done and what's left, from a save (the SaveData
## autoload, or a SaveData loaded from a fixture). Each stage has STAGE_ITEMS to do: finish it,
## win it (which opens its mirror, WS-6), its bronze, silver and gold medals (MP-9, at the
## difficulty asked about, as stage select shows them) and a win on it mirrored. The whole
## game's percentage adds the stickers (MP-12) and the cars unlocked (Unlocks) to the stages'.
## The unlock-everything option opens things without earning them, so it counts for nothing.

const STAGE_ITEMS: Array[String] = ["FINISH", "WIN", "BRONZE", "SILVER", "GOLD", "MIRROR WIN"]


## Stage `stage`'s items for `save` on `level` (Difficulty.Level): {"label", "done"} each, in
## STAGE_ITEMS order.
static func stage_items(stage: int, save, level: int) -> Array[Dictionary]:
	var best: float = save.stage_best(stage)
	var medal := Medals.earned(stage, level, best)
	var id: String = Stages.POSTCARDS[stage]
	var done := [
		not is_inf(best),
		save.unlocks.has(Unlocks.mirror_id(stage)),
		medal >= Medals.Medal.BRONZE,
		medal >= Medals.Medal.SILVER,
		medal >= Medals.Medal.GOLD,
		save.mirror_wins.has(id),
	]
	var out: Array[Dictionary] = []
	for i in STAGE_ITEMS.size():
		out.append({"label": STAGE_ITEMS[i], "done": done[i]})
	return out


## How many of `items` are done.
static func done_count(items: Array[Dictionary]) -> int:
	var n := 0
	for it in items:
		n += int(it["done"])
	return n


## Stage `stage`'s percentage done, 0 to 100, rounded down (100 only when every item is).
static func stage_percent(stage: int, save, level: int) -> int:
	return percent(done_count(stage_items(stage, save, level)), STAGE_ITEMS.size())


## `done` of `total` as a whole percentage, rounded down so 100 means all of it.
static func percent(done: int, total: int) -> int:
	return 0 if total <= 0 else clampi(floori(100.0 * done / total), 0, 100)


## The stickers earned and the cars unlocked (by play: not the unlock-everything option).
static func sticker_count(save) -> int:
	var n := 0
	for id in Stickers.ids():
		n += int(save.stickers.has(id))
	return n


static func car_count(save) -> int:
	var n := 0
	for car: Dictionary in Cars.LIST:
		n += int(Unlocks.car_open(car["id"], save.furthest_stage, save.unlocks, false))
	return n


## The whole game's parts: {"label", "done", "total"} for the stages' items, the stickers and
## the cars.
static func parts(save, level: int) -> Array[Dictionary]:
	var stage_done := 0
	for i in Stages.count():
		stage_done += done_count(stage_items(i, save, level))
	return [
		{"label": "STAGES", "done": stage_done, "total": Stages.count() * STAGE_ITEMS.size()},
		{"label": "STICKERS", "done": sticker_count(save), "total": Stickers.count()},
		{"label": "CARS", "done": car_count(save), "total": Cars.LIST.size()},
	]


## The whole game's percentage: every part's items counted alike.
static func overall(save, level: int) -> int:
	var done := 0
	var total := 0
	for p in parts(save, level):
		done += int(p["done"])
		total += int(p["total"])
	return percent(done, total)


## What's left on a stage, as the page's line says it: the first item not done, "" when all are.
static func next_item(stage: int, save, level: int) -> String:
	for it in stage_items(stage, save, level):
		if not it["done"]:
			return it["label"]
	return ""
