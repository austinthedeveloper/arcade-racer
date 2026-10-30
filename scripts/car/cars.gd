class_name Cars
extends RefCounted
## The cars on the select screen. Only the Vega is drivable so far; the rest of the
## line-up (docs/01-game-design.md) joins as its sprites are made.

## id, name, archetype, select-screen stats (1..5) and showroom picture
const LIST := [
	{
		"id": "car_vega", "name": "Vega GT", "archetype": "Low wedge supercar",
		"accel": 4, "top_speed": 5, "handling": 3,
		"picture": "res://assets/sprites/ui/car_vega.png",
	},
]


static func count() -> int:
	return LIST.size()


static func get_car(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
