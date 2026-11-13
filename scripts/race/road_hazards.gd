class_name RoadHazards
extends RefCounted
## Road hazards (RC-19): debris, a row of cones, an ice patch and puddles, each lying in a
## lane of a stretch of road, placed by the stage's script (Track.add_hazard). Driving over
## one is a bump (debris: speed lost and a hop), a slow (cones knocked flying, a deep puddle
## dragging at the tires) or a slide (ice: the steering mostly gone and the car drifting for
## a moment). Every racer feels them; the rivals and the autodrive pick a lane clear of them
## when there is one (AIDriver.open_lane, hazard_room). Strengths are in Tuning ("hazards/").

enum Kind { DEBRIS, CONES, ICE, PUDDLE }

const IDS := ["debris", "cones", "ice", "puddle"]
## Debris and cones stand on the road, drawn upright WORLD_H high (world units); ice and
## puddles lie flat on it, drawn over every segment they cover.
const SPRITES := "res://assets/sprites/hazards/"  # tools/make_hazard_sprites.py
const WORLD_H := {Kind.DEBRIS: 380.0, Kind.CONES: 360.0}
const FLAT := [Kind.ICE, Kind.PUDDLE]
const CONE_FLY := 0.7  # seconds a knocked cone flies before it's gone

class Hazard:
	var kind := 0
	var segment := 0  # the first segment it lies on
	var length := 1  # how many segments it covers
	var offset := 0.0  # its middle across the road, in Cfg.ROAD_WIDTH (by Track.side once mirrored)
	var half := 0.25  # half its width across, in Cfg.ROAD_WIDTH
	var knocked := -1.0  # cones: seconds since a car knocked them flying (-1 standing)

	## Whether it still does anything: knocked cones are gone.
	func live() -> bool:
		return knocked < 0.0

	## Whether it covers segment `index` of a track `n` segments long.
	func covers(index: int, n: int) -> bool:
		return posmod(index - segment, n) < length

static var _textures: Dictionary = {}


## The half-width (Cfg.ROAD_WIDTH) a hazard of `kind` covers on road with lanes `lane_w` wide
## (Segment.width * 2 / lanes): about a lane, so a car in the next one passes it (reach).
static func half_for(kind: int, lane_w: float) -> float:
	match kind:
		Kind.ICE, Kind.PUDDLE:
			return lane_w * 0.6
		Kind.CONES:
			return lane_w * 0.45
		_:
			return lane_w * 0.35


## How far either side of a hazard's middle a car at it touches it: its half-width and a
## share of the car's (hazards/reach).
static func reach(h: Hazard) -> float:
	return h.half + Cfg.HALF_CAR * Tuning.v("hazards/reach")


## The live hazards a car at `x` is over in `segments` (the ones its nose entered this tick).
static func under(segments: Array[Segment], x: float) -> Array:
	var out := []
	for seg in segments:
		for h: Hazard in seg.hazards:
			if h.live() and not out.has(h) and absf(x - h.offset) < reach(h):
				out.append(h)
	return out


## Drives `car` over whatever hazards it is on this tick (after its update and collide): a
## hazard it wasn't already on hits it (hit), and ice it is on keeps it sliding. In the air it
## passes over everything. Sets car.hazard_hit to the kind that hit it this tick, or -1.
static func drive_over(car: PlayerCar, track: Track) -> void:
	car.hazard_hit = -1
	if car.airborne:
		car.on_hazards.clear()
		return
	var now := under(car.passed_segments(track), car.x)
	for h: Hazard in now:
		if h.kind == Kind.ICE:
			car.skid_time = maxf(car.skid_time, Tuning.v("hazards/ice_time"))
		if not car.on_hazards.has(h):
			hit(car, h, track)
	car.on_hazards = now


## What hazard `h` does to `car` as it drives onto it.
static func hit(car: PlayerCar, h: Hazard, track: Track) -> void:
	car.hazard_hit = h.kind
	match h.kind:
		Kind.DEBRIS:
			car.speed *= 1.0 - Tuning.v("hazards/debris_loss")
			car.hop(Tuning.v("hazards/debris_hop"))
		Kind.CONES:
			car.speed *= 1.0 - Tuning.v("hazards/cones_loss")
			h.knocked = 0.0
		Kind.PUDDLE:
			car.speed *= 1.0 - Tuning.v("hazards/puddle_loss")
		Kind.ICE:
			car.skid_time = Tuning.v("hazards/ice_time")
			car.skid_dir = skid_way(car.steer, track.find_segment(car.position + Cfg.PLAYER_Z).curve, car.x)


## Which way a car slides on ice (-1 left, 1 right): the way it was steering, or else out of
## the bend (curves pull to the outside), or else away from the middle of the road.
static func skid_way(steer: float, curve: float, x: float) -> float:
	if absf(steer) > 0.05:
		return signf(steer)
	if curve != 0.0:
		return -signf(curve)
	return 1.0 if x >= 0.0 else -1.0


## Moves knocked cones along their flight; call each tick with the world's `dt`.
static func age(track: Track, dt: float) -> void:
	for h: Hazard in track.road_hazards:
		if h.knocked >= 0.0:
			h.knocked += dt


## Segments ahead of `z` (up to `lookahead`) before a live hazard covers a car at `x`
## (half-width `half_car`, with `clearance` to spare), or `lookahead` when none does.
static func room(track: Track, z: float, x: float, half_car: float, clearance: float, lookahead: int) -> int:
	if track.road_hazards.is_empty():
		return lookahead
	var here := track.find_segment(z).index
	var n := track.segments.size()
	for k in lookahead:
		for h: Hazard in track.segments[(here + k) % n].hazards:
			if h.live() and absf(h.offset - x) < h.half + half_car + clearance:
				return k
	return lookahead


## The callout for a hazard of `kind` hitting the player.
static func callout(kind: int) -> Callouts.Kind:
	match kind:
		Kind.DEBRIS:
			return Callouts.Kind.DEBRIS
		Kind.CONES:
			return Callouts.Kind.CONES
		Kind.ICE:
			return Callouts.Kind.ICE
		Kind.PUDDLE:
			return Callouts.Kind.SPLASH
	return Callouts.Kind.NONE


## Where cone `i` of a row of `count` stands across its hazard: a diagonal taper across the
## lane, from one side of it at the near end to the other at the far end.
static func cone_offset(h: Hazard, i: int, count: int) -> float:
	var t := float(i) / maxf(count - 1, 1)
	return h.offset - h.half + 2.0 * h.half * t


## A knocked cone's flight `age` seconds in: how high (share of its height) and how far
## sideways (share of the hazard's half-width) it is, and its fade (1 to 0).
static func cone_flight(age: float) -> Vector3:
	var t := clampf(age / CONE_FLY, 0.0, 1.0)
	return Vector3(sin(t * PI) * 1.6, t * 2.5, 1.0 - t)


## A hazard sprite by name (debris, cone, ice, puddle), loaded once. A missing file gives a
## small blank texture and one warning, so drawing it never crashes.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := SPRITES + name + ".png"
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex == null:
			push_warning("Missing hazard sprite: " + path)
			tex = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
		_textures[name] = tex
	return _textures[name]


## The sprite a hazard of `kind` is drawn with.
static func sprite(kind: int) -> String:
	return "cone" if kind == Kind.CONES else IDS[kind]
