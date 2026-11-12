class_name EngineModels
extends RefCounted
## The engine note per car (PR-18): three models the gear-and-rev synth (RaceAudio) plays the
## player's engine through, picked per car in Cars.LIST ("engine"). Each is two loops cross-faded
## by the revs (RaceAudio.engine_rpm, 0..1 in a gear, up to 1.2 on nitro), each with its own
## pitch curve, and the turbo has a whine that spools up on the throttle and a pop on each
## upshift. The rivals keep the one shared engine (the rival cue).
##
## small: a high-revving twin (engine_small, 120 firings a second, buzzy), into the bright
##   engine_high early; the pitch climbs the most.
## v8: a cross-plane V8 (engine_v8, 48 firings a second, uneven: the burble), low and lumpy,
##   only part-way into the smoother engine_low at the top.
## turbo: the original engine_low into engine_high, mid-pitched, with turbo_whine and turbo_pop.

const DEFAULT := "turbo"
## model: low and high loop cues, each layer's pitch at 0 revs and its rise to 1 rev, the revs
## the high layer fades in over and how far, and the turbo extras.
const MODELS := {
	"small": {
		"low": "engine_small", "high": "engine_high",
		"low_pitch": [0.9, 1.3], "high_pitch": [0.96, 1.39],
		"cross": [0.25, 0.7], "high_max": 1.0, "low_floor": 0.2,
		"whine": false, "pop": false,
	},
	"v8": {
		"low": "engine_v8", "high": "engine_low",
		"low_pitch": [0.7, 0.8], "high_pitch": [0.6, 0.69],
		"cross": [0.55, 1.0], "high_max": 0.6, "low_floor": 0.5,
		"whine": false, "pop": false,
	},
	"turbo": {
		"low": "engine_low", "high": "engine_high",
		"low_pitch": [0.8, 1.0], "high_pitch": [0.6, 0.9],
		"cross": [0.35, 0.85], "high_max": 1.0, "low_floor": 0.3,
		"whine": true, "pop": true,
	},
}
const WHINE_FROM := 0.3  # revs the whine starts to spool at
const WHINE_OFF_THROTTLE := 0.3  # its level off the throttle, of what it is on it
const WHINE_PITCH := [0.6, 0.9]


static func model(name: String) -> Dictionary:
	return MODELS.get(name, MODELS[DEFAULT])


## The loop cue a model plays for a layer ("low" or "high").
static func cue(name: String, layer: String) -> String:
	return model(name)[layer]


## A layer's pitch scale at these revs.
static func pitch(name: String, layer: String, rpm: float) -> float:
	var curve: Array = model(name)[layer + "_pitch"]
	return curve[0] + curve[1] * rpm


## How far the high layer has faded in at these revs, 0..its high_max.
static func high_mix(name: String, rpm: float) -> float:
	var m := model(name)
	return smoothstep(m["cross"][0], m["cross"][1], rpm) * m["high_max"]


## The low layer's level as the high one comes in (it never quite goes: low_floor).
static func low_mix(name: String, rpm: float) -> float:
	var m := model(name)
	return 1.0 - (1.0 - m["low_floor"]) * smoothstep(m["cross"][0], m["cross"][1], rpm)


## The turbo's whine at these revs, full on the throttle (spooling), 0 for the others.
static func whine_level(name: String, rpm: float, spooling: bool) -> float:
	if not model(name)["whine"]:
		return 0.0
	return smoothstep(WHINE_FROM, 1.0, rpm) * (1.0 if spooling else WHINE_OFF_THROTTLE)


static func whine_pitch(rpm: float) -> float:
	return WHINE_PITCH[0] + WHINE_PITCH[1] * rpm


## Whether the model pops on an upshift.
static func pops(name: String) -> bool:
	return model(name)["pop"]
