class_name RivalProfile
extends Resource
## Who a rival is: driver, car, driving style and pace. One per car (roster); a race picks
## seven of the drivers whose car isn't the player's.

enum Style {
	CLEAN,  ## holds its line and passes with room
	AGGRESSIVE,  ## moves across to block a faster car coming up behind
	ERRATIC,  ## reacts late and swerves its line now and then
}

@export var driver := ""
@export var car_id := ""
@export var style: Style = Style.CLEAN
@export var pace := 0.94  ## top speed, as a share of its car's
@export var lane_bias := 0.0  ## its own spot across the road, added to the racing line


static func make(driver_name: String, car: String, s: Style, p: float, bias: float) -> RivalProfile:
	var r := RivalProfile.new()
	r.driver = driver_name
	r.car_id = car
	r.style = s
	r.pace = p
	r.lane_bias = bias
	return r


## Every driver, one per car in Cars.LIST.
static func roster() -> Array[RivalProfile]:
	return [
		make("Dani Vance", "car_vega", Style.CLEAN, 0.95, 0.1),
		make("Rook Maddox", "car_bruiser", Style.AGGRESSIVE, 0.93, -0.2),
		make("Ilse Brandt", "car_kestrel", Style.CLEAN, 0.96, 0.25),
		make("Tomas Reyes", "car_sol", Style.ERRATIC, 0.92, -0.3),
		make("Big Jo Harlan", "car_mesa", Style.AGGRESSIVE, 0.94, 0.3),
		make("Wren Okafor", "car_phantom", Style.CLEAN, 0.95, -0.1),
		make("Sasha Lind", "car_tempest", Style.AGGRESSIVE, 0.97, 0.0),
		make("Kip Delgado", "car_skipper", Style.ERRATIC, 0.93, 0.2),
		make("Nova Ash", "car_halo", Style.CLEAN, 0.94, -0.25),
		make("Mags Tully", "car_cyclone", Style.ERRATIC, 0.95, 0.1),
		make("Gus Pruitt", "car_hauler", Style.CLEAN, 0.92, -0.15),
		make("Yuki Sato", "car_zenith", Style.AGGRESSIVE, 0.97, 0.15),
	]
