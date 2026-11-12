class_name Attract
extends RefCounted
## Attract mode: left on the title, the game plays an autodriven demo race with the logo
## over it; any input goes back to the title. A demo race never saves anything (see race.gd
## `demo`).
## The attract tour (PR-20): the demos run on one after another, a loop of every stage in
## order, each with the next car in turn and a title card (the stage and the car) as it
## starts, and the controls card (PR-22) once a loop, after the first race. At the end of a
## loop the title comes back; idle there, the next loop starts with the cars carrying on.
## Every stage is in the loop, locked or not (the stage select shows them all as postcards,
## and the tour is the game's shop window), and every car but the secret one (Unlocks
## SECRET_CAR) until it's found: a demo shouldn't give a secret away. `step` is the loop in
## a plain function; the game (game.gd) walks it.

enum Step { RACE, CONTROLS }

const IDLE_SECONDS := 20.0  # on the title before a demo starts (game.attract_delay)
const DEMO_SECONDS := 60.0  # longest a demo runs before the next step
const CONTROLS_SECONDS := 8.0  # the controls card's turn in the loop
const CONTROLS_AT := 1  # the controls card's place in a loop: after the first race
const AXIS_WAKE := 0.3  # a steer, gas or brake axis past this counts as input
## The title card at a demo's start: where it sits (bottom left, clear of the car and of
## PRESS START), and its timing: in from the left, held, back out.
const CARD := Rect2(14, 212, 252, 68)
const CARD_IN := 0.4
const CARD_OUT_AT := 4.0
const CARD_OUT := 0.4


## The cars the tour shows (indices into Cars): all of them, but the secret car only once
## `secret_open`.
static func tour_cars(secret_open: bool) -> Array[int]:
	var out: Array[int] = []
	for i in Cars.count():
		if Cars.get_car(i)["id"] != Unlocks.SECRET_CAR or secret_open:
			out.append(i)
	return out


## The cars for the save as it is (Unlocks.car_unlocked).
static func tour_cars_now() -> Array[int]:
	return tour_cars(Unlocks.car_unlocked(Unlocks.SECRET_CAR))


## Steps in a loop of `stages` stages: a race on each and the controls card.
static func loop_length(stages: int) -> int:
	return stages + 1


## The tour's `n`th step since the game started (loops run on, one after another):
## {"kind": Step.RACE, "stage", "car"} (indices into Stages and Cars) or {"kind": Step.CONTROLS}.
## The stages go in order each loop; the cars (`cars`, tour_cars) run on in turn across loops,
## so every car comes round however many stages there are.
static func step(n: int, stages: int, cars: Array[int]) -> Dictionary:
	var length := loop_length(stages)
	var loop := n / length
	var k := posmod(n, length)
	if k == CONTROLS_AT:
		return {"kind": Step.CONTROLS}
	var race := k if k < CONTROLS_AT else k - 1
	return {"kind": Step.RACE, "stage": race, "car": cars[posmod(loop * stages + race, cars.size())]}


## Loop number `loop` whole, step by step.
static func loop_steps(loop: int, stages: int, cars: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in loop_length(stages):
		out.append(step(loop * loop_length(stages) + k, stages, cars))
	return out


## Whether step `n` is the last of its loop (the title comes next).
static func ends_loop(n: int, stages: int) -> bool:
	return posmod(n + 1, loop_length(stages)) == 0


## The title card's words for a demo on `stage` (into Stages) in the car `car_id`.
static func card_text(stage: int, car_id: String) -> Dictionary:
	var car: Dictionary = Cars.find(car_id)
	return {"tag": "STAGE %d OF %d" % [stage + 1, Stages.count()], "stage": Stages.stage_name(stage).to_upper(),
		"car": String(car.get("name", "")).to_upper(), "kind": String(car.get("archetype", "")).to_upper()}


## How far the title card is in, 0 (off the left edge) to 1, `t` seconds into the demo.
static func card_in(t: float) -> float:
	if t < 0.0 or t >= CARD_OUT_AT + CARD_OUT:
		return 0.0
	if t < CARD_IN:
		return StageIntro.ease_out(t / CARD_IN)
	if t < CARD_OUT_AT:
		return 1.0
	return 1.0 - StageIntro.ease_in((t - CARD_OUT_AT) / CARD_OUT)


## Where the title card is `t` seconds into the demo: slid in from the left to CARD.
static func card_rect(t: float) -> Rect2:
	var k := card_in(t)
	if k <= 0.0:
		return Rect2()
	return Rect2(Vector2(roundf(lerpf(-CARD.size.x - 8.0, CARD.position.x, k)), CARD.position.y), CARD.size)


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
