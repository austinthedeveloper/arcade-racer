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


## How many times a station started.
func music_starts() -> int:
	var n := 0
	for i in Radio.count():
		n += count(Radio.cue(i))
	return n


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
	eq(audio_node().music_cue, Radio.cue(r.audio.station), "the radio starts with the race")
	eq(music_starts(), 1, "once")
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
	eq(count("crowd"), 1, "the crowd roars at the finish")
	eq(audio_node().music_cue, "", "music stops at the finish")
	for cue: String in SoundBank.CUES:
		check(cue == "crowd" or SoundBank.volume_db(cue) < SoundBank.volume_db("crowd"), "the crowd is louder than %s" % cue)


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
	eq(music_starts(), 2, "music restarts")
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


func test_thunder_after_lightning() -> void:
	var r := race(false, false, 6, false)  # Thunderhead
	audio_node().history.clear()
	r.fx.set_weather(r.track.theme, 1.0)
	step(r, 60 + int(Weather.THUNDER_NEAR * 60.0) + 2)
	eq(count("thunder"), 1, "thunder a beat after the flash")
	var palm := fresh_race()
	step(palm, 600)
	eq(count("thunder"), 0, "none on a clear stage")


func test_whooshes_pan_to_the_passed_cars_side() -> void:
	eq(RaceAudio.pan_side(-0.5, 0.0), -1, "a car on the left sounds left")
	eq(RaceAudio.pan_side(0.75, 0.25), 1, "a car on the right sounds right")
	eq(RaceAudio.pan_side(-0.25, 0.25), -1, "left of the player, though right of center")
	check(RaceAudio.passed(120.0, -40.0), "overtaking: the gap goes through zero")
	check(RaceAudio.passed(-30.0, 10.0), "being overtaken counts too")
	check(not RaceAudio.passed(300.0, 200.0), "still ahead")
	check(not RaceAudio.passed(-200.0, 50000.0), "a wrap round the track is no pass")


func test_wind_rises_with_speed() -> void:
	var p := PlayerCar.new()
	eq(RaceAudio.wind_level(p), 0.0, "no wind parked")
	p.speed = Cfg.MAX_SPEED * 0.1
	eq(RaceAudio.wind_level(p), 0.0, "none at a crawl")
	var last := 0.0
	for pct in [0.3, 0.5, 0.7, 0.9]:
		p.speed = Cfg.MAX_SPEED * pct
		var w := RaceAudio.wind_level(p)
		check(w > last, "louder at %d%%" % int(pct * 100))
		last = w
	p.speed = Cfg.MAX_SPEED
	near(RaceAudio.wind_level(p), 1.0, 0.001, "full at top speed")
	p.airborne = true
	check(RaceAudio.wind_level(p) < 1.0, "quieter in the air")


func test_rival_engine_and_slipstream_levels() -> void:
	near(RaceAudio.rival_level(0.0), 1.0, 0.001, "alongside: full")
	check(RaceAudio.rival_level(-800.0) > RaceAudio.rival_level(1600.0), "nearer is louder, either side")
	eq(RaceAudio.rival_level(RaceAudio.RIVAL_HEAR + 1.0), 0.0, "out of earshot")
	var p := PlayerCar.new()
	p.speed = Cfg.MAX_SPEED * 0.8
	p.draft = 0.5
	check(RaceAudio.draft_level(p) > 0.5, "the buffet follows the draft meter")
	p.speed = Cfg.MAX_SPEED * 0.3
	eq(RaceAudio.draft_level(p), 0.0, "no slipstream at low speed")


func test_passing_traffic_whooshes_once() -> void:
	var r := race(false, true)  # traffic, no rivals
	audio_node().history.clear()
	step(r, 185)
	var car = r.traffic.cars[0]
	car.offset = r.player.x + 0.4
	car.speed = 0.0
	car.z = fposmod(r.player.position + Cfg.PLAYER_Z + 60.0, r.track.length)
	car.last_z = car.z
	r.audio.update(DT)  # remember the gap
	car.z = fposmod(r.player.position + Cfg.PLAYER_Z - 60.0, r.track.length)  # now behind
	r.audio.update(DT)
	eq(count("whoosh"), 1, "a whoosh as it goes by")
	r.audio.update(DT)
	eq(count("whoosh"), 1, "just the one")
	eq(audio_node()._pool.filter(func(p): return p.bus == "SFX Right").size(), 1, "on the right")


func test_each_pickup_has_its_own_sound() -> void:
	var r := fresh_race()
	step(r, 185)
	for kind: int in RaceAudio.PICKUP_CUES:
		r.picked_up = true
		r.pickup_gave = kind
		r.audio.update(DT)
		eq(count(RaceAudio.PICKUP_CUES[kind]), 1, RaceAudio.PICKUP_CUES[kind])
	r.picked_up = false
	r.player.draft_time = Draft.BOOST_TIME
	r.audio.update(DT)
	eq(count("draft_boost"), 1, "the slipstream boost")


func test_horn_sounds_while_held() -> void:
	var r := fresh_race()
	step(r, 185)
	var n := input(1.0)
	n.horn = true
	step(r, 2, n)
	near(r.audio.levels["horn"], 1.0, 0.001, "horn on at once")
	step(r, 2, input(1.0))
	eq(r.audio.levels["horn"], 0.0, "and off on release")


func test_every_cue_level_is_set() -> void:
	for cue: String in SoundBank.CUES:
		check(SoundBank.volume_db(cue) < 0.0, cue + " sits under full scale")
	for cue: String in ["rival", "wind", "draft", "horn"]:
		check(SoundBank.loops(cue), cue + " loops")


func test_radio_dial() -> void:
	eq(Radio.count(), 4, "rock, synthwave, funk, techno")
	eq(Radio.next(Radio.count() - 1), 0, "round the dial")
	eq(Radio.next_setting(Radio.SHUFFLE), 0, "shuffle, then each station")
	eq(Radio.next_setting(Radio.count() - 1), Radio.SHUFFLE, "and back to shuffle")
	eq(Radio.start_station(2, 999), 2, "a chosen station")
	for roll in [0, 1, 7, -3, 123456789]:
		var s := Radio.start_station(Radio.SHUFFLE, roll)
		check(s >= 0 and s < Radio.count(), "shuffle lands on a station (%d)" % roll)
	for i in Radio.count():
		check(SoundBank.loops(Radio.cue(i)), Radio.genre(i) + " loops")
		eq(SoundBank.CUES[Radio.cue(i)][0], "music", Radio.genre(i) + " on the music bus")


func test_race_starts_on_the_chosen_station() -> void:
	var saved: int = Settings.radio
	Settings.radio = 3
	var r := fresh_race()
	step(r, 1)
	eq(r.audio.station, 3, "the setting's station")
	eq(audio_node().music_cue, Radio.cue(3), "playing it")
	Settings.radio = saved


func test_radio_button_switches_without_a_gap() -> void:
	var r := fresh_race()
	step(r, 200, input(1.0))
	var was: int = r.audio.station
	var n := input(1.0)
	n.radio_pressed = true
	r.callouts.clear()
	step(r, 1, n)
	eq(r.audio.station, Radio.next(was), "the next station")
	eq(audio_node().music_cue, Radio.cue(Radio.next(was)), "playing at once")
	eq(count("radio_tune"), 1, "a burst of tuning")
	var shown: Array = [r.callouts.current.get("text", "")]
	for c: Dictionary in r.callouts.waiting:
		shown.append(c["text"])
	check(Radio.station_name(r.audio.station) in shown, "its name comes up")
	r.player.distance = r.finish_distance + 1.0
	step(r, 3)
	r.audio.next_station()
	eq(audio_node().music_cue, "", "no music back after the finish")


func test_a_power_slide_squeals() -> void:
	# RC-8: the skid loop follows the slide, braked into or not
	var p := PlayerCar.new()
	p.speed = Cfg.MAX_SPEED * 0.6
	eq(RaceAudio.skid_level(p), 0.0, "quiet cruising")
	p.slide = -1.0
	check(RaceAudio.skid_level(p) >= RaceAudio.SLIDE_SQUEAL, "sliding, off the brake, gentle lock: squeals")
	var faster := PlayerCar.new()
	faster.speed = Cfg.MAX_SPEED
	faster.slide = 1.0
	check(RaceAudio.skid_level(faster) > RaceAudio.skid_level(p), "louder faster")
	p.airborne = true
	eq(RaceAudio.skid_level(p), 0.0, "not in the air")
