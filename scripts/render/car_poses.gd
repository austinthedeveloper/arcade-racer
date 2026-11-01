class_name CarPoses
extends RefCounted
## Where and how to pose the player's car for the car-angle review sheet (tools/car_angles.gd):
## every car in every steering frame on a level straight and on hills up and down.

## Road the car is posed on: [name, the pitch wanted] (PlayerCar.pitch: -1 full nose-up,
## 1 full nose-down). The gentle slopes sit past PITCH_SWITCH, where a pitched strip takes over.
const SLOPES := [["level", 0.0], ["gentle_up", -0.5], ["steep_up", -1.0], ["gentle_down", 0.5], ["steep_down", 1.0]]
# Segments of road ahead of the car kept clear of bends, so the hill shots show the slope
const STRAIGHT_AHEAD := 20
# Segments skipped at the start: the grid and the start gate
const SKIP_START := 80


## The steering value that shows each strip frame, hard left to hard right.
static func steer_values() -> Array[float]:
	var out: Array[float] = []
	var half := CarSprites.PLAYER_FRAMES / 2
	for f in CarSprites.PLAYER_FRAMES:
		out.append(float(f - half) / half)
	return out


## The pitch the car settles at with its nose at road distance z (PlayerCar._update_pitch).
static func pitch_at(track: Track, z: float) -> float:
	var span := PlayerCar.PITCH_SPAN
	return PlayerCar.pitch_for_slope((track.height_at(z + span * 0.5) - track.height_at(z - span * 0.5)) / span)


## How well segment i suits a pose wanting `pitch`: higher is better. Closeness to the pitch
## counts most, then how straight the road ahead is.
static func spot_score(track: Track, i: int, pitch: float) -> float:
	var bend := 0.0
	for k in range(-2, STRAIGHT_AHEAD):
		bend += absf(track.segments[(i + k) % track.segments.size()].curve)
	return -absf(pitch_at(track, (i + 0.5) * Cfg.SEGMENT_LENGTH) - pitch) * 10.0 - bend * 0.05


## The segment that best suits a pose wanting `pitch` (spot_score), past the start.
static func find_spot(track: Track, pitch: float) -> int:
	var best := -1
	var best_score := -INF
	for i in range(SKIP_START, track.segments.size() - STRAIGHT_AHEAD):
		var score := spot_score(track, i, pitch)
		if score > best_score:
			best_score = score
			best = i
	return best
