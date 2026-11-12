## Renders each engine note (EngineModels, PR-18) through a rev sweep to a WAV, to hear or
## inspect the three side by side without driving: full throttle from a standstill up through
## the five gears to top speed, mixed the way RaceAudio mixes the loops (the same revs, layer
## levels, pitch curves, whine and shift pops), from the source WAVs in assets/audio/sfx.
##
##   godot --headless --path . -s res://tools/engine_sweep.gd -- --out=/tmp/engines [--seconds=8]
##
## Writes <out>/engine_<model>.wav (mono 16-bit 22.05 kHz) for each model.
extends SceneTree

const RATE := 22050


## In _initialize, with the autoloads up; the game's classes load at run time (_game), since a
## -s script compiles before the autoloads the audio scripts name exist.
func _initialize() -> void:
	var out := "user://engine_sweep"
	var seconds := 8.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out)
	var status := 0
	for model: String in EngineModels.MODELS:
		var path := "%s/engine_%s.wav" % [out, model]
		var err := write_wav(path, render(model, seconds))
		print(("wrote " if err == OK else "FAILED ") + path)
		if err != OK:
			status = 1
	quit(status)


## The speed fraction `t` (0..1) of the way through the sweep: a car's pull, quick off the
## line and slower near the top.
static func sweep_pct(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.2)


## One of the game's scripts by class file (RaceAudio, SoundBank, PlayerCar).
static func _game(path: String) -> GDScript:
	return load(path)


## The sweep for one model, as samples at RATE.
static func render(model: String, seconds: float) -> PackedFloat32Array:
	var race_audio := _game("res://scripts/audio/race_audio.gd")
	var bank := _game("res://scripts/audio/sound_bank.gd")
	var car := _game("res://scripts/car/player_car.gd")
	var m := EngineModels.model(model)
	var layers := {
		"low": _load(m["low"]), "high": _load(m["high"]), "whine": _load("turbo_whine"),
	}
	var pop := _load("turbo_pop")
	var gain := {
		"low": db_to_linear(bank.volume_db(m["low"])), "high": db_to_linear(bank.volume_db(m["high"])),
		"whine": db_to_linear(bank.volume_db("turbo_whine")),
	}
	var pop_gain := db_to_linear(bank.volume_db("turbo_pop"))
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := {"low": 0.0, "high": 0.0, "whine": 0.0}
	var level := {"low": 0.0, "high": 0.0, "whine": 0.0}
	var gear := 1
	var pop_at := -1
	var tick := RATE / 60  # levels and pitches change at the physics rate, as in the game
	var target := {}
	var pitch := {}
	for i in n:
		if i % tick == 0:
			var pct := sweep_pct(float(i) / n)
			var rpm: float = race_audio.engine_rpm(pct)
			target = {
				"low": EngineModels.low_mix(model, rpm), "high": EngineModels.high_mix(model, rpm),
				"whine": EngineModels.whine_level(model, rpm, true),
			}
			pitch = {"low": EngineModels.pitch(model, "low", rpm), "high": EngineModels.pitch(model, "high", rpm),
				"whine": EngineModels.whine_pitch(rpm)}
			var g: int = car.auto_gear(pct)
			if g > gear and EngineModels.pops(model):
				pop_at = i
			gear = g
			for k in level:
				level[k] = move_toward(level[k], target[k], race_audio.FADE / 60.0)
		var s := 0.0
		for k: String in layers:
			var src: Dictionary = layers[k]
			var data: PackedFloat32Array = src["data"]
			if data.is_empty() or level[k] <= 0.0:
				continue
			s += _sample(data, phase[k]) * level[k] * gain[k]
			phase[k] = fposmod(phase[k] + pitch[k] * src["rate"] / RATE, data.size())
		if pop_at >= 0:
			var j := i - pop_at
			var pd: PackedFloat32Array = pop["data"]
			var at := j * float(pop["rate"]) / RATE
			if at < pd.size() - 1:
				s += _sample(pd, at) * pop_gain
		out[i] = s
	return out


## A looped source sample at a fractional position, linearly between its neighbors.
static func _sample(data: PackedFloat32Array, at: float) -> float:
	var i := int(at)
	var f := at - i
	return lerpf(data[i % data.size()], data[(i + 1) % data.size()], f)


## A cue's source WAV (mono 16-bit PCM, as make_audio.py writes it): {data, rate}.
static func _load(cue: String) -> Dictionary:
	var path := "res://assets/audio/sfx/%s.wav" % cue
	var bytes := FileAccess.get_file_as_bytes(path)
	var data := PackedFloat32Array()
	var rate := RATE
	var at := 12
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "fmt ":
			rate = bytes.decode_u32(at + 12)
		elif id == "data":
			data.resize(size / 2)
			for k in size / 2:
				data[k] = bytes.decode_s16(at + 8 + 2 * k) / 32768.0
		at += 8 + size + (size & 1)
	return {"data": data, "rate": rate}


## Mono 16-bit PCM at RATE, clipped.
static func write_wav(path: String, samples: PackedFloat32Array) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var size := samples.size() * 2
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + size)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(size)
	var pcm := PackedByteArray()
	pcm.resize(size)
	for i in samples.size():
		pcm.encode_s16(2 * i, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	f.store_buffer(pcm)
	f.close()
	return OK
