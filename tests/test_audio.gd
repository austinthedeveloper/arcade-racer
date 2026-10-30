## Sound: the cue bank (SoundBank), the Audio autoload, and the race cues (RaceAudio).
extends TestSuite


## Steps the race and its audio together, as the tree does.
func step(r: Node, frames: int, inp: DriveInput = null) -> void:
	for i in frames:
		drive(r, 1, inp)
		r.audio.update(DT)


## The Audio autoload, set up (a -s run initializes before autoloads are ready).
func audio_node() -> Node:
	var a: Node = runner.root.get_node("Audio")
	a._ready()
	return a


func count(cue: String) -> int:
	return audio_node().history.count(cue)


func fresh_race() -> Node:
	var r := race(false, false)
	audio_node().history.clear()
	return r


func test_every_cue_has_a_sound() -> void:
	for cue: String in SoundBank.CUES:
		check(SoundBank.path_for(cue) != "", "file for " + cue)
		check(SoundBank.stream(cue) != null, "stream loads for " + cue)


func test_loops_are_set_in_code() -> void:
	for cue: String in SoundBank.CUES:
		var s := SoundBank.stream(cue) as AudioStreamWAV
		if s == null:
			continue  # a pack's ogg/mp3; set_loop covers those through `loop`
		if SoundBank.loops(cue):
			eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, cue + " loops")
			check(s.loop_end > s.loop_begin, cue + " loops the whole file")
		else:
			eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, cue + " plays once")


func test_pack_files_win_over_placeholders() -> void:
	eq(SoundBank.EXTENSIONS[0], "ogg", "a pack's .ogg is looked for first")
	eq(SoundBank.path_for("no_such_cue"), "", "unknown cue")
	check(SoundBank.path_for("engine_low").ends_with("sfx/engine_low.wav"), "placeholder path")


func test_engine_revs_through_the_gears() -> void:
	near(RaceAudio.engine_rpm(0.0), 0.0, 0.001, "idle")
	check(RaceAudio.engine_rpm(0.15) > RaceAudio.engine_rpm(0.05), "revs rise in a gear")
	check(RaceAudio.engine_rpm(0.17) < RaceAudio.engine_rpm(0.15), "a shift drops the revs")
	near(RaceAudio.engine_rpm(1.0), 1.0, 0.001, "top speed, top revs")
	check(RaceAudio.engine_rpm(1.25) <= 1.2, "nitro over-revs, capped")


func test_tires_squeal_braking_and_cornering_only() -> void:
	var p := PlayerCar.new()
	p.speed = Cfg.MAX_SPEED * 0.8
	eq(RaceAudio.skid_level(p), 0.0, "quiet cruising")
	p.braking = true
	check(RaceAudio.skid_level(p) > 0.5, "hard braking squeals")
	p.braking = false
	p.steer = 1.0
	check(RaceAudio.skid_level(p) > 0.5, "full lock at speed squeals")
	p.offroad = true
	eq(RaceAudio.skid_level(p), 0.0, "no squeal on dirt")
	check(RaceAudio.offroad_level(p) > 0.5, "gravel rumble instead")
	p.speed = 0.0
	eq(RaceAudio.offroad_level(p), 0.0, "parked on dirt is quiet")


func test_countdown_beeps_then_go_and_music() -> void:
	var r := fresh_race()
	step(r, 1)
	eq(count("music_race"), 1, "music starts with the race")
	eq(audio_node().music_cue, "music_race", "music playing")
	step(r, 185)
	eq(count("beep"), 3, "three, two, one")
	eq(count("go"), 1, "GO")


func test_engine_follows_speed() -> void:
	var r := fresh_race()
	step(r, 185)
	var idle: float = r.audio.pitches["engine_low"]
	step(r, 120, input(1.0))
	check(r.player.speed > 0.0, "moving")
	check(r.audio.pitches["engine_low"] != idle, "pitch changes with speed")
	check(r.audio.levels["engine_low"] > 0.0, "engine audible")


func test_race_events_play_once_each() -> void:
	var r := fresh_race()
	step(r, 185)
	r.player.distance = r.checkpoint_distances[0] + 1.0
	step(r, 3)
	eq(count("checkpoint"), 1, "checkpoint chime")
	var n := input(1.0)
	n.nitro_pressed = true
	step(r, 1, n)
	step(r, 3)
	eq(count("nitro"), 1, "nitro once per charge")
	r.player.crash()
	r.audio.update(DT)
	eq(count("crash"), 1, "crash")
	r.player.distance = r.finish_distance + 1.0
	step(r, 3)
	eq(count("finish"), 1, "finish fanfare")
	eq(audio_node().music_cue, "", "music stops at the finish")


func test_clock_ticks_when_time_runs_low() -> void:
	var r := fresh_race()
	step(r, 185)
	r.time_left = 3.5
	step(r, 60)
	eq(count("tick"), 2, "a tick per second under ten (4, then 3)")
	r.time_left = 0.05
	step(r, 5)
	eq(count("time_up"), 1, "time up")
	eq(audio_node().music_cue, "", "music stops")


func test_restart_starts_over() -> void:
	var r := fresh_race()
	step(r, 300)
	r.start_race()
	step(r, 185)
	eq(count("music_race"), 2, "music restarts")
	eq(count("beep"), 6, "a fresh countdown")


func test_pause_holds_sound() -> void:
	var r := fresh_race()
	step(r, 200, input(1.0))
	r.paused = true
	audio_node().history.clear()
	step(r, 30)
	eq(audio_node().history.size(), 0, "no cues while paused")
	check(audio_node().paused, "music and effects held")
	r.paused = false
	r.audio.update(DT)
	check(not audio_node().paused, "and resumed")
