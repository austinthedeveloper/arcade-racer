class_name Cars
extends RefCounted
## The garage: every car on the select screen, its stats and its sprites. The stats (1..5,
## docs/01-game-design.md and docs/07) shown on the select screen also tune the driving
## model (tuning), relative to the Vega, which drives on the base Cfg values.

## id, name, archetype, select-screen stats, sprite strip (CarSprites), showroom picture.
## "engine" is its engine note (EngineModels: small, v8 or turbo, PR-18).
## Optional: "offroad" scales the off-road slowdown (0 none), "nitros" and "nitro_time"
## change the nitro charges and how long each lasts.
const LIST := [
	{
		"id": "car_vega", "name": "Vega GT", "archetype": "Low wedge supercar",
		"accel": 4, "top_speed": 5, "handling": 3, "strip": "vega", "engine": "turbo",
	},
	{
		"id": "car_bruiser", "name": "Bruiser 440", "archetype": "Muscle coupe",
		"accel": 5, "top_speed": 4, "handling": 2, "strip": "bruiser", "engine": "v8",
	},
	{
		"id": "car_kestrel", "name": "Kestrel R", "archetype": "Rally-bred hatch",
		"accel": 4, "top_speed": 3, "handling": 5, "strip": "kestrel", "engine": "turbo",
	},
	{
		"id": "car_sol", "name": "Solano Spyder", "archetype": "Open-top roadster",
		"accel": 3, "top_speed": 4, "handling": 4, "strip": "sol", "engine": "small",
	},
	{
		"id": "car_mesa", "name": "Mesa Rumbler", "archetype": "Lifted 4x4: no off-road slowdown",
		"accel": 3, "top_speed": 3, "handling": 3, "strip": "mesa", "engine": "v8", "offroad": 0.0,
	},
	{
		"id": "car_phantom", "name": "Phantom", "archetype": "Pursuit sedan",
		"accel": 4, "top_speed": 5, "handling": 3, "strip": "phantom", "engine": "v8",
	},
	{
		"id": "car_tempest", "name": "Tempest LM", "archetype": "Endurance prototype",
		"accel": 3, "top_speed": 5, "handling": 4, "strip": "tempest", "engine": "turbo",
	},
	{
		"id": "car_skipper", "name": "Dune Skipper", "archetype": "Sand-rail buggy: half off-road slowdown",
		"accel": 5, "top_speed": 2, "handling": 4, "strip": "skipper", "engine": "small", "offroad": 0.5,
	},
	{
		"id": "car_halo", "name": "Halo EV", "archetype": "Electric: four shorter nitros",
		"accel": 5, "top_speed": 4, "handling": 3, "strip": "halo", "engine": "small", "nitros": 4, "nitro_time": 0.75,
	},
	{
		"id": "car_cyclone", "name": "Cyclone", "archetype": "Reverse trike",
		"accel": 4, "top_speed": 3, "handling": 5, "strip": "cyclone", "engine": "small",
	},
	{
		"id": "car_hauler", "name": "Hauler", "archetype": "Delivery van (surprisingly fast)",
		"accel": 3, "top_speed": 4, "handling": 2, "strip": "hauler", "engine": "v8",
	},
	{
		"id": "car_zenith", "name": "Zenith X", "archetype": "Concept hypercar",
		"accel": 5, "top_speed": 5, "handling": 4, "strip": "zenith", "engine": "turbo",
	},
]


static func count() -> int:
	return LIST.size()


static func get_car(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]


## The car with this id; the Vega when there is none.
static func find(id: String) -> Dictionary:
	for car: Dictionary in LIST:
		if car["id"] == id:
			return car
	return LIST[0]


## The car's engine note (EngineModels.MODELS), the turbo when it has none.
static func engine_model(car: Dictionary) -> String:
	return String(car.get("engine", EngineModels.DEFAULT))


static func picture(car: Dictionary) -> String:
	return "res://assets/sprites/ui/car_%s.png" % car["strip"]


## Driving multipliers from a car's stats, 1.0 for the Vega's: top speed, acceleration,
## steering rate, curve pull (lower grips better), off-road slowdown, nitro charges and
## nitro length.
static func tuning(car: Dictionary) -> Dictionary:
	return {
		"top": 1.0 - (5 - int(car["top_speed"])) * 0.04,
		"accel": 1.0 + (int(car["accel"]) - 4) * 0.1,
		"steer": 1.0 + (int(car["handling"]) - 3) * 0.08,
		"pull": 1.0 - (int(car["handling"]) - 3) * 0.1,
		"offroad": float(car.get("offroad", 1.0)),
		"nitros": int(car.get("nitros", Cfg.NITRO_CHARGES)),
		"nitro_time": float(car.get("nitro_time", 1.0)),
	}
