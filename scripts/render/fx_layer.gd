class_name FxLayer
extends Node2D
## Sprite particles between the road and the HUD (tools/make_fx_sprites.py): tire smoke,
## kick-up off the road by ground type, sparks on hits, nitro flames and speed lines, and a
## puff on landing. Purely visual: it reads the car and never writes it, and its randomness
## is a generator of its own, so play (and the golden traces) can't tell it is there.
##
## Particles live in screen space in a fixed pool; at most SPAWN_CAP start in one tick and
## MAX_PARTICLES are alive at once, so a crash in heavy smoke can't blow the frame budget.

const SPRITES := "res://assets/sprites/fx/"
const MAX_PARTICLES := 160
const SPAWN_CAP := 12  # new particles per tick
const EMIT_EVERY := 2  # ticks between puffs of a steady effect (smoke, kick-up)

## What each particle effect looks like. sprite: file stem (frames are stem_1..stem_n, or
## the stem alone for one frame); life in seconds; scale at birth and how much it grows
## over its life; vel: speed range in screen pixels per second (x is outward from the car's
## middle); gravity: pixels per second squared; origin: where in the sprite its position is
## (x mirrored for a flipped sprite); fade: the last fraction of its life it fades over.
const EFFECTS := {
	"smoke": {"sprite": "smoke", "frames": 8, "life": 0.7, "scale": 1.3, "grow": 1.0,
		"vel": [Vector2(10, 10), Vector2(60, 50)], "gravity": 0.0, "origin": Vector2(0.3, 0.85), "fade": 0.5},
	"dust": {"sprite": "dust", "frames": 5, "life": 0.45, "scale": 1.0, "grow": 0.6,
		"vel": [Vector2(20, 30), Vector2(80, 70)], "gravity": 0.0, "origin": Vector2(0.1, 1.0), "fade": 0.4},
	"sand": {"sprite": "sand", "frames": 5, "life": 0.45, "scale": 1.0, "grow": 0.6,
		"vel": [Vector2(20, 30), Vector2(80, 70)], "gravity": 0.0, "origin": Vector2(0.1, 1.0), "fade": 0.4},
	"snow": {"sprite": "snow", "frames": 5, "life": 0.5, "scale": 1.0, "grow": 0.7,
		"vel": [Vector2(20, 30), Vector2(80, 70)], "gravity": 0.0, "origin": Vector2(0.1, 1.0), "fade": 0.4},
	"water": {"sprite": "water", "frames": 5, "life": 0.4, "scale": 1.1, "grow": 0.6,
		"vel": [Vector2(20, 40), Vector2(90, 80)], "gravity": 0.0, "origin": Vector2(0.1, 1.0), "fade": 0.3},
	"sparks": {"sprite": "sparks", "frames": 6, "life": 0.3, "scale": 1.2, "grow": 0.2,
		"vel": [Vector2(40, -60), Vector2(160, 20)], "gravity": 500.0, "origin": Vector2(0.1, 1.0), "fade": 0.3},
	"impact": {"sprite": "impact", "frames": 1, "life": 0.18, "scale": 1.0, "grow": 1.5,
		"vel": [Vector2.ZERO, Vector2.ZERO], "gravity": 0.0, "origin": Vector2(0.5, 0.5), "fade": 0.5},
	"puff": {"sprite": "smoke", "frames": 8, "life": 0.5, "scale": 1.0, "grow": 0.8,
		"vel": [Vector2(90, -10), Vector2(170, 10)], "gravity": 0.0, "origin": Vector2(0.4, 0.9), "fade": 0.5},
	"nitro_burst": {"sprite": "nitro_burst", "frames": 1, "life": 0.22, "scale": 0.8, "grow": 0.9,
		"vel": [Vector2.ZERO, Vector2.ZERO], "gravity": 0.0, "origin": Vector2(0.5, 0.5), "fade": 0.6},
}
## What comes off the road beside the asphalt, per Track.GROUND_* (grass, sand), unless a
## stage theme says otherwise with its own "kickup". "smoke" is hard ground (paving).
const DEFAULT_KICKUP := ["dust", "sand"]
const NITRO_FRAMES := 6
const NITRO_SCALE := 1.7  # flame size against the 180-pixel-wide car
const SPEED_LINE_FRAMES := 3
const SPEED_LINES_FROM := 0.85  # of top speed, before nitro

## The player car on screen, as RoadRenderer draws it: wheels and exhausts as fractions of
## its width from its middle, the exhausts up from its base.
const WHEEL_X := 0.36
const EXHAUST_X := 0.2
const EXHAUST_Y := 0.2

## One pooled particle.
class Particle:
	var alive := false
	var effect := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var age := 0.0
	var flip := false


var particles: Array[Particle] = []
var spawned := 0  # this tick, against SPAWN_CAP
var dropped := 0  # spawns refused for the cap or a full pool, since the race started
var player: PlayerCar
var time := 0.0
var _free: Array[int] = []
var _tick := 0
var _last_speed := 0.0
var _last_nitro := 0.0
var _rng := RandomNumberGenerator.new()
static var _textures: Dictionary = {}


func _init() -> void:
	for i in MAX_PARTICLES:
		particles.append(Particle.new())
	clear()


## Every particle gone, for a new race. The generator restarts too, so a race's FX are the
## same every time.
func clear() -> void:
	_free.clear()
	for i in range(MAX_PARTICLES - 1, -1, -1):
		particles[i].alive = false
		_free.append(i)
	spawned = 0
	dropped = 0
	_tick = 0
	_last_speed = 0.0
	_last_nitro = 0.0
	time = 0.0
	_rng.seed = 2024


func alive_count() -> int:
	return MAX_PARTICLES - _free.size()


## One tick: ages the particles, then starts what the car calls for (react).
func update(dt: float, p: PlayerCar, track: Track) -> void:
	player = p
	time += dt
	spawned = 0
	_tick += 1
	for i in MAX_PARTICLES:
		var q := particles[i]
		if not q.alive:
			continue
		var e: Dictionary = EFFECTS[q.effect]
		q.age += dt
		if q.age >= e["life"]:
			q.alive = false
			_free.append(i)
			continue
		q.vel.y += e["gravity"] * dt
		q.pos += q.vel * dt
	react(p, track)


## Starts the particles for this tick's triggers (triggers) at the car's wheels and exhausts.
func react(p: PlayerCar, track: Track) -> void:
	var steady := _tick % EMIT_EVERY == 0
	var base := car_base(p)
	var w := car_width()
	for t in triggers(p, _last_speed, _last_nitro):
		match t:
			"smoke":
				if steady:
					_at_wheels("smoke", base, w)
			"kickup":
				if steady:
					var kind := kickup_kind(track.theme, ground_under(p, track))
					_at_wheels(kind, base, w)
			"sparks":
				for side in [-1.0, 1.0]:
					for n in 2:
						spawn("sparks", base + Vector2(side * w * 0.3, -w * 0.05), side < 0.0)
			"impact":
				spawn("impact", base + Vector2(0, -w * 0.2), false)
			"puff":
				for side in [-1.0, 1.0]:
					spawn("puff", base + Vector2(side * w * WHEEL_X, 0), side < 0.0)
			"nitro_burst":
				for side in [-1.0, 1.0]:
					spawn("nitro_burst", exhaust(base, w, side), false)
	_last_speed = p.speed
	_last_nitro = p.nitro_time


func _at_wheels(effect: String, base: Vector2, w: float) -> void:
	for side in [-1.0, 1.0]:
		spawn(effect, base + Vector2(side * w * WHEEL_X, 0), side < 0.0)


## The effects the car calls for this tick, from its state now and last tick's speed and
## nitro time: "smoke" (braking hard, wheelspin off the line, cornering on the limit, a crash
## slide), "kickup" (off the road), "sparks" (any hit), "impact" (a crash), "puff" (landing),
## "nitro_burst" (nitro lit this tick).
static func triggers(p: PlayerCar, last_speed: float, last_nitro: float) -> PackedStringArray:
	var out := PackedStringArray()
	var pct := p.speed_percent()
	var grounded := not p.airborne
	if p.crash_time > 0.0 and p.speed > Cfg.MAX_SPEED * 0.05:
		out.append("smoke")
	elif grounded and not p.offroad and (
			(p.braking and pct > 0.35)
			or (p.speed > last_speed and p.speed > 0.0 and pct < 0.25)
			or (absf(p.steer) > 0.8 and pct > 0.7)):
		out.append("smoke")
	if grounded and p.offroad and pct > 0.05 and p.crash_time <= 0.0:
		out.append("kickup")
	if p.crashed or p.bumped or p.rammed:
		out.append("sparks")
	if p.crashed:
		out.append("impact")
	if p.landed:
		out.append("puff")
	if p.nitro_time > last_nitro:
		out.append("nitro_burst")
	return out


## What the car throws up off the road on `ground` (Track.GROUND_*) on a stage with `theme`.
static func kickup_kind(theme: Dictionary, ground: int) -> String:
	var kinds: Array = theme.get("kickup", DEFAULT_KICKUP)
	return kinds[clampi(ground, 0, kinds.size() - 1)]


## The ground beside the road on the side the car is on.
static func ground_under(p: PlayerCar, track: Track) -> int:
	var seg := track.find_segment(p.position + Cfg.PLAYER_Z)
	return seg.ground_left if p.x < 0.0 else seg.ground_right


## Starts one particle of `effect` at screen point `at`; `flip` mirrors it (the left wheel's
## spray goes left). False when this tick's cap or the pool is used up.
func spawn(effect: String, at: Vector2, flip: bool) -> bool:
	if spawned >= SPAWN_CAP or _free.is_empty():
		dropped += 1
		return false
	var e: Dictionary = EFFECTS[effect]
	var q := particles[_free.pop_back()]
	spawned += 1
	q.alive = true
	q.effect = effect
	q.age = 0.0
	q.flip = flip
	q.pos = at
	var lo: Vector2 = e["vel"][0]
	var hi: Vector2 = e["vel"][1]
	q.vel = Vector2(_rng.randf_range(lo.x, hi.x) * (-1.0 if flip else 1.0), _rng.randf_range(lo.y, hi.y))
	return true


## Live particles of `effect`.
func count(effect: String) -> int:
	var n := 0
	for q in particles:
		if q.alive and q.effect == effect:
			n += 1
	return n


## The player car's base (middle of its bottom edge) on screen, lifted when it's in the air.
static func car_base(p: PlayerCar) -> Vector2:
	var s := Cfg.CAMERA_DEPTH / Cfg.PLAYER_Z
	return Vector2(Cfg.SCREEN_W * 0.5, Cfg.HORIZON_Y + s * (Cfg.CAMERA_HEIGHT - p.air_height) * Cfg.PROJ)


static func car_width() -> float:
	return Cfg.CAR_WIDTH * Cfg.CAMERA_DEPTH / Cfg.PLAYER_Z * Cfg.PROJ


static func exhaust(base: Vector2, w: float, side: float) -> Vector2:
	return base + Vector2(side * w * EXHAUST_X, -w * EXHAUST_Y)


## Which nitro flame frame (1..NITRO_FRAMES) shows with `left` seconds of a `duration` burn
## to go at time `t`: it lights small, flickers through the big middle frames, and dies down.
static func nitro_frame(left: float, duration: float, t: float) -> int:
	if left <= 0.0:
		return 0
	if duration - left < 0.08:
		return 1
	if left < 0.15:
		return NITRO_FRAMES
	return 2 + int(t * 20.0) % (NITRO_FRAMES - 2)


## How strong the speed lines are, 0 (none) to 1: they come in near top speed and are full
## on nitro.
static func speed_lines(p: PlayerCar) -> float:
	if p.nitro_time > 0.0:
		return 1.0
	return clampf((p.speed_percent() - SPEED_LINES_FROM) / (1.0 - SPEED_LINES_FROM), 0.0, 1.0) * 0.6


## The frame (1-based) of `effect` at `age` seconds into its life.
static func frame_at(effect: String, age: float) -> int:
	var e: Dictionary = EFFECTS[effect]
	var n: int = e["frames"]
	return clampi(int(age / e["life"] * n) + 1, 1, n)


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(SPRITES + name + ".png")
	return _textures[name]


static func _frame_name(stem: String, frames: int, frame: int) -> String:
	return stem if frames == 1 else "%s_%d" % [stem, frame]


func _draw() -> void:
	if player == null:
		return
	var lines := speed_lines(player)
	if lines > 0.0:
		_draw_speed_lines(lines)
	for q in particles:
		if q.alive:
			_draw_particle(q)
	var f := nitro_frame(player.nitro_time, player.nitro_duration, time)
	if f > 0:
		var base := car_base(player)
		var w := car_width()
		var tex := texture("nitro_%d" % f)
		var size := Vector2(tex.get_width(), tex.get_height()) * (w / 180.0) * NITRO_SCALE
		for side in [-1.0, 1.0]:
			var at := exhaust(base, w, side)
			# Head (the blue core) at the pipe, the tail streaming back toward the camera
			var rect := Rect2(roundf(at.x - size.x / 2.0), roundf(at.y - size.y * 0.1), size.x, size.y)
			if side > 0.0:
				rect = Rect2(rect.position.x + rect.size.x, rect.position.y, -rect.size.x, rect.size.y)
			draw_texture_rect(tex, rect, false)


func _draw_particle(q: Particle) -> void:
	var e: Dictionary = EFFECTS[q.effect]
	var life: float = e["life"]
	var k := q.age / life
	var tex := texture(_frame_name(e["sprite"], e["frames"], frame_at(q.effect, q.age)))
	var scale_now: float = e["scale"] + e["grow"] * k
	var size := Vector2(tex.get_width(), tex.get_height()) * scale_now
	var o: Vector2 = e["origin"]
	var ox := (1.0 - o.x) if q.flip else o.x
	var pos := Vector2(roundf(q.pos.x - size.x * ox), roundf(q.pos.y - size.y * o.y))
	var fade: float = e["fade"]
	var alpha := clampf((1.0 - k) / fade, 0.0, 1.0) if fade > 0.0 else 1.0
	var rect := Rect2(pos, size)
	if q.flip:
		rect = Rect2(pos.x + size.x, pos.y, -size.x, size.y)
	draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))


func _draw_speed_lines(strength: float) -> void:
	var tex := texture("speed_%d" % speed_line_frame(strength))
	# Zoomed a little more every tick, then back, so the lines rush past. (Not mirrored: a
	# mirrored rect this big doesn't draw in GL Compatibility.)
	var grow := float(int(time * 20.0) % 4) * 8.0
	var rect := Rect2(-grow, -grow * 0.6, Cfg.SCREEN_W + grow * 2.0, Cfg.SCREEN_H + grow * 1.2)
	draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.15 + 0.3 * strength))


## Which speed-line sheet (1..SPEED_LINE_FRAMES, light to heavy) shows at `strength`.
static func speed_line_frame(strength: float) -> int:
	return clampi(int(strength * SPEED_LINE_FRAMES - 0.01) + 1, 1, SPEED_LINE_FRAMES)
