class_name CarState
extends RefCounted
## A car as an online race sends it (ON-3): what another game needs to draw it and place it.
## A plain Array so it goes over the line as it is.

enum { DISTANCE, X, STEER, SPEED, AIR, NITRO, BRAKING }
const SIZE := 7


static func of(p: PlayerCar) -> Array:
	return [p.distance, p.x, p.steer, p.speed, p.air_height, p.nitro_time > 0.0, p.braking]


## Puts a remote car where `shown` (OnlineSession.shown_at) says, with the rest of `state`.
static func apply(r: PlayerCar, state: Array, shown: Vector3, track: Track) -> void:
	r.last_position = r.position
	r.last_x = r.x
	r.distance = shown.x
	r.position = fposmod(shown.x, track.length)
	r.x = shown.y
	r.steer = shown.z
	r.speed = float(state[SPEED])
	r.air_height = float(state[AIR])
	r.airborne = r.air_height > 0.0
	r.nitro_time = 1.0 if bool(state[NITRO]) else 0.0
	r.braking = bool(state[BRAKING])
	r.road_y = track.height_at(r.position + Cfg.PLAYER_Z)
