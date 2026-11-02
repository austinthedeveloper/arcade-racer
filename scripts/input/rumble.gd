class_name Rumble
extends RefCounted
## Gamepad rumble (WH-13): crashes, bumps, landings, nitro and off-road shake the pad driving
## the race, through Input.start_joy_vibration, scaled by the rumble option (Settings.rumble,
## 0 off .. 10 as designed). The race calls tick once a physics tick; events and command are
## plain functions, so tests see what would be sent without a pad.

## event -> [weak motor 0..1, strong motor 0..1, seconds], as designed (the option at 10).
const EVENTS := {
	"crash": [0.6, 1.0, 0.45],
	"bump": [0.5, 0.25, 0.12],
	"landing": [0.25, 0.6, 0.18],
	"nitro": [0.7, 0.15, 0.35],
	"offroad": [0.35, 0.0, 0.12],  # at top speed; slower is gentler (command's `pct`)
}
## Off the road the rumble is renewed this often (seconds) while it lasts.
const OFFROAD_EVERY := 0.1

var _last_nitro := 0.0
var _offroad_wait := 0.0
var _busy := 0.0  # seconds left on the last command sent
var _busy_strength := 0.0  # its stronger motor: a weaker event doesn't cut it short


## The rumble events of this tick: "crash" (a crash starts), "bump" (a nudge, a ram, a side
## swipe), "landing", "nitro" (lit this tick) and "offroad" (on the ground off the road at speed).
static func events(p: PlayerCar, last_nitro: float) -> PackedStringArray:
	var out := PackedStringArray()
	if p.crashed:
		out.append("crash")
	elif p.bumped or p.rammed or (p.hit_traffic and p.crash_time <= 0.0):
		out.append("bump")
	if p.landed:
		out.append("landing")
	if p.nitro_time > last_nitro:
		out.append("nitro")
	if p.offroad and not p.airborne and p.crash_time <= 0.0 and p.speed_percent() > 0.05:
		out.append("offroad")
	return out


## What `event` sends at rumble `level` (0..Settings.EFFECT_STEPS), the car at `pct` of top
## speed (only off-road reads it): weak motor, strong motor, seconds. ZERO at level 0.
static func command(event: String, level: int, pct := 1.0) -> Vector3:
	if level <= 0 or not EVENTS.has(event):
		return Vector3.ZERO
	var e: Array = EVENTS[event]
	var scale := clampi(level, 0, Settings.EFFECT_STEPS) / float(Settings.EFFECT_STEPS)
	if event == "offroad":
		scale *= clampf(pct, 0.0, 1.0)
	return Vector3(e[0] * scale, e[1] * scale, e[2])


## One tick: the command to send now for `p`'s events at `level`, or ZERO for none (nothing
## new, everything at 0, or a stronger rumble still running).
func tick(dt: float, p: PlayerCar, level: int) -> Vector3:
	_busy = maxf(0.0, _busy - dt)
	_offroad_wait = maxf(0.0, _offroad_wait - dt)
	var evs := events(p, _last_nitro)
	_last_nitro = p.nitro_time
	var out := Vector3.ZERO
	for e in evs:
		if e == "offroad":
			if _offroad_wait > 0.0:
				continue
			_offroad_wait = OFFROAD_EVERY
		var c := command(e, level, p.speed_percent())
		out = Vector3(maxf(out.x, c.x), maxf(out.y, c.y), maxf(out.z, c.z))
	var strength := maxf(out.x, out.y)
	if strength <= 0.0 or (_busy > 0.0 and strength < _busy_strength):
		return Vector3.ZERO
	_busy = out.z
	_busy_strength = strength
	return out


## Stops what's running (a pause, the race over) and forgets it.
func stop(device: int) -> void:
	_busy = 0.0
	_busy_strength = 0.0
	if device >= 0:
		Input.stop_joy_vibration(device)


## Sends `c` (tick) to joypad `device`; nothing for the keyboard (-1) or a ZERO command.
## Returns whether it sent.
static func send(device: int, c: Vector3) -> bool:
	if device < 0 or maxf(c.x, c.y) <= 0.0:
		return false
	Input.start_joy_vibration(device, c.x, c.y, c.z)
	return true
