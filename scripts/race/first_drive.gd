class_name FirstDrive
extends RefCounted
## The first drive (MP-15): a new profile's first race on Palm Coast is a guided run. One
## prompt at a time, each when the road allows it (allowed), each cleared by doing it
## (cleared): hold the gas, steer, nitro on a straight, draft behind a truck, a power slide.
## A step whose moment hasn't come lets a later one go first, so a run with no truck in reach
## still gets its slide. Every prompt cleared, or the race run to the end, and the first
## drive is done; SKIP FIRST DRIVE on the pause menu skips it. Either way it never shows
## again (SaveData.first_drive). Its pacing is Tuning's "first_drive" area.
##
## The race reads the road into a plain dictionary each tick (look), and `tick` works on that,
## so a test can step every prompt from a scripted run. The HUD draws the prompt up
## (Hud._draw_first_drive); a cleared one bursts NICE! through the callouts (PR-5).

enum Step { GAS, STEER, NITRO, DRAFT, SLIDE }

const STAGE := 0  # Palm Coast, into Stages
## What each prompt says, big, and the callout when it's cleared.
const TEXT := ["HOLD THE GAS", "STEER", "NITRO ON THE STRAIGHT", "DRAFT THE TRUCK", "POWER SLIDE"]
const CLEARED := "NICE!"
const DONE_TEXT := "FIRST DRIVE DONE"
const DONE_SUB := "The road is yours"

var left: Array[int] = [Step.GAS, Step.STEER, Step.NITRO, Step.DRAFT, Step.SLIDE]
## The prompt up (a Step), or -1 between prompts.
var current := -1
var cleared: Array[int] = []
var done := false
var held := 0.0  # seconds the current prompt's action has been kept up
var shown_for := 0.0  # seconds the current prompt has been up
var gap := 0.0  # seconds before the next prompt may come up
var off_for := 0.0  # seconds the road hasn't allowed the current prompt


## Whether a race on `stage` starts as the first drive for the profile in `save_data`
## (SaveData): Palm Coast, and its first drive still to come.
static func wanted(stage: int, save_data: Node) -> bool:
	return stage == STAGE and save_data.first_drive_pending()


## How many prompts there are in all.
static func count() -> int:
	return Step.size()


## Which number the current prompt is (1 up).
func number() -> int:
	return cleared.size() + 1


## The road and the car this tick, as `tick` reads it, from `race` (race.gd) and the input
## it drove on (`inp`, after the assists): racing, the input, the car's speed share, nitro
## and slipstream, and what the road ahead holds (a straight, a bend, a big vehicle).
static func look(race: Node, inp: DriveInput) -> Dictionary:
	var p: PlayerCar = race.player
	var track: Track = race.track
	return {
		"racing": race.state == race.State.RACING,
		"throttle": inp.throttle,
		"steer": inp.steer,
		"speed": p.speed_percent(),
		"nitro_charges": p.nitro_charges,
		"nitro": p.nitro_time > 0.0,
		"draft_boost": p.draft_time > 0.0,
		"sliding": p.slide != 0.0,
		"straight": straight_ahead(track, p.position + Cfg.PLAYER_Z),
		"bend": bend_ahead(track, p.position + Cfg.PLAYER_Z),
		"big_ahead": big_ahead(track, p),
	}


## The most curve in the `reach` segments from `z` on.
static func curve_ahead(track: Track, z: float, reach: int) -> float:
	var here := track.find_segment(z).index
	var most := 0.0
	for k in reach:
		most = maxf(most, absf(track.segments[(here + k) % track.segments.size()].curve))
	return most


## The road ahead runs straight long enough for a nitro (first_drive/straight_reach, Tuning).
static func straight_ahead(track: Track, z: float) -> bool:
	return curve_ahead(track, z, Tuning.i("first_drive/straight_reach")) < Tuning.v("first_drive/straight_curve")


## A bend sharp enough to slide through is coming up (first_drive/bend_reach).
static func bend_ahead(track: Track, z: float) -> bool:
	return curve_ahead(track, z, Tuning.i("first_drive/bend_reach")) >= Tuning.v("first_drive/bend_curve")


## A big vehicle (Traffic.BIG) going the player's way within first_drive/truck_reach ahead.
static func big_ahead(track: Track, me: PlayerCar) -> bool:
	var nose := me.position + Cfg.PLAYER_Z
	var reach := Tuning.v("first_drive/truck_reach")
	var here := track.find_segment(nose).index
	for k in ceili(reach / Cfg.SEGMENT_LENGTH) + 1:
		for car: Traffic.TrafficCar in track.segments[(here + k) % track.segments.size()].cars:
			if not Traffic.BIG.has(car.sprite) or car.oncoming or not car.solid():
				continue
			var ahead := wrapf(car.z - nose, -track.length * 0.5, track.length * 0.5)
			if ahead > 0.0 and ahead < reach:
				return true
	return false


## Whether the road (`v`, look) allows `step`'s prompt now.
static func allowed(step: int, v: Dictionary) -> bool:
	if not v["racing"]:
		return false
	match step:
		Step.GAS:
			return true
		Step.STEER:
			return v["speed"] >= Tuning.v("first_drive/steer_speed")
		Step.NITRO:
			return v["straight"] and v["nitro_charges"] > 0 and not v["nitro"] and v["speed"] >= Tuning.v("first_drive/nitro_speed")
		Step.DRAFT:
			return v["big_ahead"] and not v["draft_boost"]
		Step.SLIDE:
			return v["bend"] and v["speed"] >= Tuning.v("slide/speed")
	return false


## Whether `step` has been done this tick (`v`).
static func doing(step: int, v: Dictionary) -> bool:
	match step:
		Step.GAS:
			return v["throttle"] > 0.5
		Step.STEER:
			return absf(v["steer"]) > 0.3
		Step.NITRO:
			return v["nitro"]
		Step.DRAFT:
			return v["draft_boost"]
		Step.SLIDE:
			return v["sliding"]
	return false


## The seconds `step` has to be kept up to clear it: holding the gas and steering take a
## moment; nitro, the slipstream boost and a slide count as they happen.
static func hold_for(step: int) -> float:
	match step:
		Step.GAS:
			return Tuning.v("first_drive/gas_hold")
		Step.STEER:
			return Tuning.v("first_drive/steer_hold")
	return 0.0


## Whether `step` can't come any more: nitro with every charge burned.
static func gone(step: int, v: Dictionary) -> bool:
	return step == Step.NITRO and v["nitro_charges"] <= 0 and not v["nitro"]


## One tick over `dt` seconds of the road as `v` (look) has it. Returns the Step cleared
## this tick, or -1.
func tick(dt: float, v: Dictionary) -> int:
	if done:
		return -1
	for s in left.duplicate():
		if s != current and gone(s, v):
			left.erase(s)
	gap = maxf(0.0, gap - dt)
	if current >= 0:
		shown_for += dt
		if doing(current, v):
			held += dt
			if held >= hold_for(current):
				return _clear()
		else:
			held = 0.0
		# The moment passed (the straight ran out, the truck went by): it waits for the next.
		off_for = 0.0 if allowed(current, v) or current == Step.GAS or current == Step.STEER else off_for + dt
		if gone(current, v) or (shown_for >= Tuning.v("first_drive/min_show") and off_for >= Tuning.v("first_drive/withdraw")):
			if gone(current, v):
				left.erase(current)
			current = -1
			gap = Tuning.v("first_drive/gap")
	if current < 0 and gap <= 0.0:
		for s in left:
			if allowed(s, v):
				current = s
				held = 0.0
				shown_for = 0.0
				off_for = 0.0
				break
	if left.is_empty():
		done = true
	return -1


func _clear() -> int:
	var s := current
	cleared.append(s)
	left.erase(s)
	current = -1
	gap = Tuning.v("first_drive/gap")
	done = left.is_empty()
	return s


## The line under the prompt: how to do it on `dev` (ControlsCard.Device), with `profile`'s
## bindings (ControlsCard.profile_for).
static func how(step: int, dev: int, profile: DeviceProfile) -> String:
	var rows := {}
	for r: Array in ControlsCard.rows(dev, profile):
		rows[r[0]] = r[1]
	var gas: String = rows.get("GAS", "the gas pedal")
	var brake: String = rows.get("BRAKE", "the brake pedal")
	if dev == ControlsCard.Device.WHEEL:
		gas = "the gas pedal"
		brake = "the brake"
	elif dev == ControlsCard.Device.TOUCH:
		gas = "GAS"
		brake = "BRAKE"
		rows["NITRO"] = "NITRO"
	match step:
		Step.GAS:
			return "Hold %s to get going" % gas
		Step.STEER:
			return "%s to steer round the traffic" % (rows.get("STEER", "Turn the wheel") if dev != ControlsCard.Device.WHEEL else "Turn the wheel")
		Step.NITRO:
			return "A straight! %s for a burst of nitro" % rows.get("NITRO", "NITRO")
		Step.DRAFT:
			return "Tuck in right behind the truck to fill the slipstream"
		Step.SLIDE:
			return "Into the bend: %s and steer hard at speed" % brake
	return ""
