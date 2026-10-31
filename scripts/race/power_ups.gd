class_name PowerUps
extends RefCounted
## Pickups on the road (docs/07, section 3): a few per stage, in a lane, never a weapon.
## Driving over one takes it. Nitro cans and clocks apply at once; the ram plate and the
## ghost run for a few seconds; the mystery hubcap turns into one of the others.

enum Kind { NITRO, CLOCK, RAM, GHOST, MYSTERY }

const IDS := ["nitro", "clock", "ram", "ghost", "mystery"]
## Where along the stage the pickups go, as fractions of its length
const SPOTS := [0.12, 0.3, 0.47, 0.64, 0.81]
## Chance of each kind on the road (mystery most often), and out of a mystery hubcap
const ROAD_WEIGHTS := [0.15, 0.15, 0.15, 0.15, 0.4]
const MYSTERY_WEIGHTS := [0.3, 0.25, 0.25, 0.2, 0.0]
## Below this much time left, a mystery hubcap is much more likely to be a clock: a little
## earlier than the clock flashes (Cfg.LOW_TIME), so the help comes before the panic
const LOW_TIME := 12.0
const CLOCK_BONUS := 3.0
const RAM_TIME := 5.0
const GHOST_TIME := 4.0
const REACH := 0.3  # road half-widths between the car's center and a pickup's that take it
const WORLD_H := 560.0  # world height of a pickup sprite

class Pickup:
	var segment := 0
	var offset := 0.0
	var kind := 0
	var taken := false


const SPRITES := "res://assets/sprites/powerups/"  # tools/make_powerup_sprites.py
const MYSTERY_SPIN := 8.0  # hubcap frames per second

var pickups: Array[Pickup] = []
var _rng := RandomNumberGenerator.new()
static var _textures: Dictionary = {}


## Lays out a stage's pickups, the same every time for a stage, and lists each in its segment.
func place(track: Track, seed_value: int = 11) -> void:
	for p in pickups:
		track.segments[p.segment].pickups.erase(p)
	pickups = layout(track, seed_value)
	for p in pickups:
		track.segments[p.segment].pickups.append(p)
	_rng.seed = seed_value


static func layout(track: Track, seed_value: int) -> Array[Pickup]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Pickup] = []
	for f: float in SPOTS:
		var i := track.free_spot(int(track.segments.size() * f), 6)
		if i < 0:
			continue
		var p := Pickup.new()
		p.segment = i
		p.offset = Traffic.LANE_OFFSETS[rng.randi() % Traffic.LANE_OFFSETS.size()]
		p.kind = pick(ROAD_WEIGHTS, rng.randf())
		out.append(p)
	return out


## The kind a weighted roll `r` (0..1) lands on.
static func pick(weights: Array, r: float) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var acc := 0.0
	for k in weights.size():
		acc += weights[k] / total
		if r < acc:
			return k
	return weights.size() - 1


## What a mystery hubcap gives: mostly a clock when time is running out.
static func mystery(r: float, time_left: float) -> int:
	var w := MYSTERY_WEIGHTS.duplicate()
	if time_left < LOW_TIME:
		w[Kind.CLOCK] *= 4.0
	return pick(w, r)


## The pickup a car at `x` drives over in `segments` (the ones it entered this tick), or
## null. Marks it taken.
func take(segments: Array[Segment], x: float) -> Pickup:
	for seg in segments:
		for p in seg.pickups:
			if not p.taken and absf(x - p.offset) < REACH:
				p.taken = true
				return p
	return null


## Resolves a mystery hubcap to what it gives.
func open(kind: int, time_left: float) -> int:
	return mystery(_rng.randf(), time_left) if kind == Kind.MYSTERY else kind


## A power-up sprite by name (pickup_nitro, icon_ram, fx_sparkle, reveal_2, ...), loaded once.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(SPRITES + name + ".png")
	return _textures[name]


## The road sprite for a pickup at time `t`: the mystery hubcap spins through its frames
## (face, three-quarter, edge, three-quarter).
static func road_sprite(kind: int, t: float) -> String:
	if kind != Kind.MYSTERY:
		return "pickup_" + IDS[kind]
	return "pickup_mystery_%d" % [1, 2, 3, 2][int(t * MYSTERY_SPIN) % 4]
