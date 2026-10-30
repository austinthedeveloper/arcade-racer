class_name Stages
extends RefCounted
## The stages in Grand Tour order. A race runs them one after another.

const NAMES := ["Palm Coast Boulevard", "Redrock Canyon"]


static func count() -> int:
	return NAMES.size()


static func build(index: int) -> Track:
	match index:
		1:
			return Redrock.build()
		_:
			return PalmCoast.build()


## The stage after `index`, or -1 after the last one.
static func next(index: int) -> int:
	return index + 1 if index + 1 < count() else -1


static func stage_name(index: int) -> String:
	return NAMES[index]
