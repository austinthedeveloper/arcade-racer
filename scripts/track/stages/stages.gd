class_name Stages
extends RefCounted
## The stages in Grand Tour order. A race runs them one after another.

const NAMES := ["Palm Coast Boulevard", "Redrock Canyon", "Neon Strip", "Timberline Pass",
	"Bayou Causeway", "Harvest Valley", "Thunderhead Highway", "Skyline Finale"]
## Stage select pictures (tools/make_ui_sprites.py), in the same order.
const POSTCARDS := ["palm_coast", "redrock", "neon", "timberline", "bayou", "harvest", "thunder", "skyline"]


static func count() -> int:
	return NAMES.size()


## Stage `index`, built, its end dressed like the next stage's start (StageFlow); flipped
## left for right with `mirror` (WS-6, Track.mirror), dressing and all. `next` dresses the
## end for that stage instead of the one after (StageFlow.dress; Survival).
static func build(index: int, mirror := false, next := -2) -> Track:
	var t := _build(index)
	StageFlow.dress(t, index, next)
	if mirror:
		t.mirror()
	return t


static func _build(index: int) -> Track:
	match index:
		1:
			return Redrock.build()
		2:
			return NeonStrip.build()
		3:
			return Timberline.build()
		4:
			return BayouCauseway.build()
		5:
			return HarvestValley.build()
		6:
			return Thunderhead.build()
		7:
			return SkylineFinale.build()
		_:
			return PalmCoast.build()


## Stage `index`'s theme (colors, background, clock), without building its road.
static func theme(index: int) -> Dictionary:
	match index:
		1:
			return Redrock.theme()
		2:
			return NeonStrip.theme()
		3:
			return Timberline.theme()
		4:
			return BayouCauseway.theme()
		5:
			return HarvestValley.theme()
		6:
			return Thunderhead.theme()
		7:
			return SkylineFinale.theme()
		_:
			return PalmCoast.theme()


## The stage after `index`, or -1 after the last one.
static func next(index: int) -> int:
	return index + 1 if index + 1 < count() else -1


static func stage_name(index: int) -> String:
	return NAMES[index]


static func postcard(index: int) -> String:
	return "res://assets/sprites/ui/postcard_%s.png" % POSTCARDS[index]
