class_name Attract
extends RefCounted
## Attract mode: left on the title, the game plays an autodriven demo race with the logo
## over it. Each demo takes the next stage and car in turn; any input goes back to the
## title. A demo race never saves anything (see race.gd `demo`).

const IDLE_SECONDS := 20.0  # on the title before a demo starts (game.attract_delay)
const DEMO_SECONDS := 60.0  # longest a demo runs before going back to the title
const AXIS_WAKE := 0.3  # a steer, gas or brake axis past this counts as input


## The stage (index into Stages) and car (index into Cars) for the `n`th demo: the stages
## in order, and the cars in order alongside them, so demos rotate through both.
static func pick(n: int) -> Dictionary:
	return {"stage": posmod(n, Stages.count()), "car": posmod(n, Cars.count())}


## True when this tick's controls show a player is there: a press, or an axis held over.
static func is_input(inp: DriveInput, m: MenuInput) -> bool:
	if inp.nitro_pressed or inp.pause_pressed or inp.restart_pressed or inp.confirm_pressed:
		return true
	if absf(inp.steer) > AXIS_WAKE or inp.throttle > AXIS_WAKE or inp.brake > AXIS_WAKE:
		return true
	return m.confirm_pressed or m.back_pressed or m.step() != 0 or m.step_y() != 0


## Any key, joypad button or mouse button press (keys the input map doesn't use too).
## Joypad axes aren't counted here: an uncalibrated wheel's pedals can rest at full
## travel. They come through is_input once the InputRouter has made sense of them.
static func is_wake_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.pressed
	return false
