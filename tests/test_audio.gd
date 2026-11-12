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


## How many times a song or sting started.
func music_starts() -> int:
	var n := 0
	for cue in Radio.all_cues():
		n += count(cue)
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
	eq(audio_node().music_cue, Radio.song_cue(r.audio.station, r.audio.song), "the radio starts with the race")
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
	var p: AudioStreamPlayer = audio_node().player_of("thunder")
	check(p != null and p.bus == "SFX", "out in the open, as it is")
	var palm := fresh_race()
	step(palm, 600)
	eq(count("thunder"), 0, "none on a clear stage")


func test_thunder_is_muffled_under_cover() -> void:
	# WS-12: the same strike heard from under a Thunderhead overpass
	var r := race(false, false, 6, false)
	var cover := Weather.shelters(r.track)
	r.player.move_to((cover[0].x + cover[0].y) * 0.5, r.track)
	audio_node().history.clear()
	r.fx.set_weather(r.track.theme, 1.0)
	step(r, 60 + int(Weather.THUNDER_NEAR * 60.0) + 2)
	eq(count("thunder"), 1, "thunder still rolls under the overpass")
	var p: AudioStreamPlayer = audio_node().player_of("thunder")
	check(p != null, "on a pool player")
	if p != null:
		eq(p.bus, audio_node().MUFFLED_BUS, "through the low-pass")
		eq(p.volume_db, SoundBank.volume_db("thunder") + audio_node().MUFFLE_DB, "and quieter")
	var bus := AudioServer.get_bus_index(audio_node().MUFFLED_BUS)
	check(bus >= 0, "the muffled bus exists")
	if bus >= 0:
		check(AudioServer.get_bus_effect(bus, 0) is AudioEffectLowPassFilter, "with a low-pass on it")
		eq(AudioServer.get_bus_send(bus), "SFX", "under the effects volume")


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
	step(r, 185)
	var car = r.traffic.cars[0]
	r.traffic.cars.resize(1)  # just the one car: another may have rolled by the grid already
	audio_node().history.clear()
	var right := func() -> int: return audio_node()._pool.filter(func(p): return p.bus == "SFX Right").size()
	var right_before: int = right.call()
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
	eq(right.call() - right_before, 1, "on the right")


func test_each_pickup_has_its_own_sound() -> void:
	var r := fresh_race()
	step(r, 185)
	for kind: int in RaceAudio.PICKUP_CUES:
		r.picked_up = true
		r.pickup_gave = kind
		r.audio.update(DT)
		eq(count(RaceAudio.PICKUP_CUES[kind]), 1, RaceAudio.PICKUP_CUES[kind])
	r.picked_up = false
	r.player.draft_time = Tuning.v("draft/boost_time")
	r.audio.update(DT)
	eq(count("draft_boost"), 1, "the slipstream boost")


func test_engine_revs_in_a_manual_gear() -> void:
	for pct in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0, 1.15]:
		near(RaceAudio.engine_rpm(pct, PlayerCar.auto_gear(pct)), RaceAudio.engine_rpm(pct), 0.0001,
			"in the automatic's gear: the same revs (%.2f)" % pct)
	near(RaceAudio.engine_rpm(0.3, 1), 1.0, 0.0001, "past 1st's band: on the limiter")
	check(RaceAudio.engine_rpm(0.2, 4) < RaceAudio.engine_rpm(0.2), "too tall a gear: low revs")
	near(RaceAudio.engine_rpm(0.0, 3), 0.0, 0.0001, "and none at rest")
	check(RaceAudio.engine_rpm(1.1, 5) > 1.0, "the top gear still over-revs on nitro")


func test_the_engine_follows_the_manual_gear() -> void:
	var saved: bool = Settings.manual_gears
	Settings.manual_gears = true
	var r := fresh_race()
	check(r.player.manual, "the option reaches the race")
	step(r, 185 + 240, input(1.0))
	eq(r.player.gear, 1, "never shifted")
	near(r.audio.pitches["engine_low"], 1.8, 0.001, "screaming on 1st's limiter")
	var n := input(1.0)
	n.shift_up_pressed = true
	step(r, 1, n)
	eq(r.player.gear, 2, "the shift button")
	check(r.audio.pitches["engine_low"] < 1.6, "the revs drop with the shift (%.2f)" % r.audio.pitches["engine_low"])
	Settings.manual_gears = saved
	r = fresh_race()
	check(not r.player.manual, "automatic by default")


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
		eq(Radio.song_count(i), 5, Radio.genre(i) + ": five songs (PR-24)")
		eq(Radio.song_cue(i, 0), Radio.cue(i), "the first is the station's own loop")
		eq(Radio.song_cue(i, Radio.song_count(i)), Radio.cue(i), "round the list")
		eq(Radio.next_song(i, Radio.song_count(i) - 1), 0, "and back to the first")
	var titles := {}
	for cue in Radio.all_cues():
		check(not SoundBank.loops(cue), cue + " plays once")
		check(SoundBank.CUES.get(cue, [""])[0] in ["music", "radio"], cue + " a music cue")
	for i in Radio.count():
		for k in Radio.song_count(i):
			titles[Radio.song_title(i, k)] = true
	eq(titles.size(), Radio.count() * 5, "every song has its own title")


func test_race_starts_on_the_chosen_station() -> void:
	var saved: int = Settings.radio
	Settings.radio = 3
	var r := fresh_race()
	step(r, 1)
	eq(r.audio.station, 3, "the setting's station")
	eq(audio_node().music_cue, Radio.song_cue(3, r.audio.song), "playing one of its songs")
	Settings.radio = saved


## A station per stage (PR-19): SHUFFLE starts each stage on its own station, a picked
## station still wins, and the radio button still switches.
func test_a_station_per_stage() -> void:
	var saved: int = Settings.radio
	for i in Stages.count():
		var own := Radio.for_theme(Stages.theme(i))
		check(own >= 0, Stages.stage_name(i) + " names a station")
	eq(Radio.genre(Radio.for_theme(Stages.theme(2))), "SYNTHWAVE", "Neon Strip on synthwave")
	eq(Radio.genre(Radio.for_theme(Stages.theme(1))), "ROCK", "Redrock on rock")
	eq(Radio.for_theme({}), -1, "a theme without one")
	check(Radio.start_station(Radio.SHUFFLE, 7, -1) >= 0, "none named: shuffle still picks one")
	# SHUFFLE follows the stage
	Settings.radio = Radio.SHUFFLE
	for stage in [1, 2]:
		var r := race(false, false, stage)
		audio_node().history.clear()
		step(r, 1)
		eq(r.audio.station, Radio.for_theme(Stages.theme(stage)), Stages.stage_name(stage) + ": its own station")
		eq(audio_node().music_cue, Radio.song_cue(r.audio.station, r.audio.song), "playing it")
		# the radio button still switches
		var n := input(1.0)
		n.radio_pressed = true
		step(r, 1, n)
		eq(r.audio.station, Radio.next(Radio.for_theme(Stages.theme(stage))), "the button: the next station up the dial")
		r.start_race()  # again: back on the stage's own
		step(r, 1)
		eq(r.audio.station, Radio.for_theme(Stages.theme(stage)), "a restart starts on the stage's own again")
	# A picked station wins over the stage's
	var picked := Radio.next(Radio.for_theme(Stages.theme(2)))
	Settings.radio = picked
	var neon := race(false, false, 2)
	step(neon, 1)
	eq(neon.audio.station, picked, "the picked station, not Neon's")
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
	eq(audio_node().music_cue, Radio.song_cue(Radio.next(was), r.audio.song), "playing at once")
	eq(count("radio_tune"), 1, "a burst of tuning")
	var shown: Array = [r.callouts.current.get("text", "")]
	for c: Dictionary in r.callouts.waiting:
		shown.append(c["text"])
	check(Radio.station_name(r.audio.station) in shown, "its name comes up")
	r.player.distance = r.finish_distance + 1.0
	step(r, 3)
	r.audio.next_station()
	eq(audio_node().music_cue, "", "no music back after the finish")


## The Web build has no radio/ folder: no sting, so a song over goes straight to the next
## (there the only one: the station's first song loops, as before PR-24).
func test_no_sting_goes_straight_to_the_next_song() -> void:
	var r := fresh_race()
	step(r, 1)
	var a: RaceAudio = r.audio
	check(Radio.has_sting(a.station), "this build has the sting")
	check(SoundBank.path_for(Radio.sting(a.station)).begins_with(SoundBank.ROOT + "radio/"), "the stings go with the newer songs")
	var first := a.song
	Radio._stings[a.station] = false
	a.cue_left = DT * 0.5
	step(r, 1, input(1.0))
	check(not a.in_sting, "no sting")
	eq(a.song, Radio.next_song(a.station, first), "the next song")
	eq(audio_node().music_cue, Radio.song_cue(a.station, a.song), "playing")
	Radio._stings.clear()


## Radio v2 (PR-24): a song plays out, the station's sting, then its next song, round the
## list; the radio button carries on at the same point.
func test_the_sting_plays_between_songs() -> void:
	var r := fresh_race()
	step(r, 1)
	var a: RaceAudio = r.audio
	var first := a.song
	eq(audio_node().music_cue, Radio.song_cue(a.station, first), "a song first")
	check(not a.in_sting, "not the sting")
	near(a.cue_left, RaceAudio.cue_length(Radio.song_cue(a.station, first)) - DT, 0.02, "the whole song to go")
	check(RaceAudio.cue_length(Radio.song_cue(a.station, first)) > 20.0, "a song lasts")
	a.cue_left = DT * 2.5  # near its end
	audio_node().history.clear()
	step(r, 3, input(1.0))
	check(a.in_sting, "the song over: the sting")
	eq(audio_node().music_cue, Radio.sting(a.station), "the station's sting playing")
	var sting_len := RaceAudio.cue_length(Radio.sting(a.station))
	check(sting_len > 1.0 and sting_len < 4.0, "a short one (%.2f s)" % sting_len)
	step(r, int(sting_len / DT) + 2, input(1.0))
	check(not a.in_sting, "then a song again")
	eq(a.song, Radio.next_song(a.station, first), "the next one")
	eq(audio_node().music_cue, Radio.song_cue(a.station, a.song), "playing")
	var seen: Array = audio_node().history.filter(func(c: String) -> bool: return c in Radio.all_cues())
	eq(seen, [Radio.sting(a.station), Radio.song_cue(a.station, a.song)], "song, sting, song")
	# Every song and sting, round a whole station
	for k in Radio.song_count(a.station) * 2:
		a.cue_left = DT * 0.5
		step(r, 1, input(1.0))
	eq(a.song, Radio.next_song(a.station, first), "round the whole list and back")
	# Switching station mid-sting: the new station's sting, at the same point
	a.cue_left = DT * 0.5
	step(r, 1, input(1.0))
	check(a.in_sting, "in a sting")
	var left := a.cue_left
	a.next_station()
	eq(audio_node().music_cue, Radio.sting(a.station), "the new station's sting")
	near(a.cue_left, RaceAudio.cue_length(Radio.sting(a.station)) - (sting_len - left), 0.05, "carrying on where it was")
	# The finish: no more songs or stings
	run_until(r, func() -> bool:
		r.audio.update(DT)
		return r.state == r.State.RACING, 2000, input(1.0))
	r.next_checkpoint = r.checkpoint_distances.size()
	r.player.distance = r.finish_distance + 1.0
	step(r, 3)
	check(not a.radio_on, "the radio off at the finish")
	a.cue_left = 0.0
	step(r, 2)
	eq(audio_node().music_cue, "", "and nothing starts after it")


## The now-playing tag (PR-24): up as a song starts, held back until past GO, then gone.
func test_the_now_playing_tag_shows_as_a_song_starts() -> void:
	var r := fresh_race()
	step(r, 1)
	var a: RaceAudio = r.audio
	check(a.tag_pending and a.tag_age < 0.0, "the first song waits for its tag through the countdown")
	run_until(r, func() -> bool:
		r.audio.update(DT)
		return r.state == r.State.RACING and r.race_time >= RaceAudio.TAG_AFTER_GO, 2000, input(1.0))
	step(r, 1, input(1.0))
	check(a.tag_age >= 0.0, "up once the race is under way")
	var words := Radio.now_playing(a.station, a.song)
	eq(words, [Radio.song_title(a.station, a.song), Radio.station_name(a.station)], "the song's title and its station")
	step(r, int(RaceAudio.TAG_TIME / DT) + 2, input(1.0))
	eq(a.tag_age, -1.0, "gone after TAG_TIME")
	# The next song tags at once
	a.cue_left = DT * 0.5
	step(r, 1, input(1.0))
	check(a.in_sting and a.tag_age < 0.0, "not for the sting")
	a.cue_left = DT * 0.5
	step(r, 2, input(1.0))
	check(a.tag_age >= 0.0, "the next song's tag")
	# The tag slides in and out
	eq(Hud.tag_slide(0.0, 4.0), 0.0, "off the edge as it starts")
	eq(Hud.tag_slide(2.0, 4.0), 1.0, "in, held")
	eq(Hud.tag_slide(4.0, 4.0), 0.0, "out again at the end")
	eq(Hud.tag_slide(-1.0, 4.0), 0.0, "not up")
	var lay := Hud.layout()
	check(lay["now_playing"].size.x >= UiText.width("SOUL STOP STRUT", 11) + 30, "room for the longest title")


## make_audio.py writes the radio's new files reproducibly: a station's sting rendered again
## (on its own random stream, so it renders alone) comes out as the repository's.
func test_make_audio_writes_the_new_songs_reproducibly() -> void:
	var out := ProjectSettings.globalize_path(TestSuite.scratch("audio"))
	var project := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var code := OS.execute("python3", [project.path_join("tools/make_audio.py"), project, "--only=sting_techno", "--out=" + out], output, true)
	if code != 0:
		print("    (no python3 here: skipped) ", output)
		return
	var fresh := FileAccess.get_file_as_bytes(out.path_join("radio/sting_techno.wav"))
	var repo := FileAccess.get_file_as_bytes("res://assets/audio/radio/sting_techno.wav")
	check(repo.size() > 44 and fresh.size() > 44, "the sting written and read (%d, %d bytes)" % [fresh.size(), repo.size()])
	eq(fresh.size(), repo.size(), "the same length")
	var worst := 0
	for i in range(44, mini(fresh.size(), repo.size()) - 1, 2):
		worst = maxi(worst, absi(fresh.decode_s16(i) - repo.decode_s16(i)))
	check(worst <= 2, "the same samples (off by at most %d)" % worst)
	var src := FileAccess.get_file_as_string("res://tools/make_audio.py")
	for cue in Radio.all_cues():
		if cue.begins_with("station_"):
			continue
		check(src.contains('"%s/%s.wav"' % [SoundBank.CUES[cue][0], cue]), "make_audio.py writes " + cue)
	# The Web build leaves radio/ out: a station plays what it has, its first song always
	var all: Array = Radio.STATIONS[0]["songs"]
	eq(Radio.songs_with(all, func(_c: String) -> bool: return true).size(), 5, "every song there")
	eq(Radio.songs_with(all, func(_c: String) -> bool: return false), [all[0]], "none of radio/: the first song alone")


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


## A race just over its finish line, autodriven with rivals, its sound stepped along.
func _finished(traffic := false) -> Node:
	var r := race(true, traffic, 0, true)
	audio_node().history.clear()
	step(r, 200)
	r.player.distance = r.finish_distance - 60000.0
	r.player.position = fposmod(r.player.distance, r.track.length)
	for i in 3000:
		if r.state != r.State.RACING:
			break
		step(r, 1)
	r.set("_autodrive", false)
	return r


func _car_loops(r: Node) -> float:
	var most := 0.0
	for cue in ["engine_low", "engine_high", "turbo_whine", "skid", "offroad", "wind", "draft", "rival", "horn"]:
		most = maxf(most, r.audio.levels[cue])
	return most


func test_the_car_goes_quiet_for_the_replay_and_the_results() -> void:
	var r := _finished()
	eq(r.state, r.State.FINISHED, "over the line")
	check(_car_loops(r) > 0.1, "the car still heard as it slows")
	for i in 900:
		if r.replaying:
			break
		step(r, 1)
	check(r.replaying, "the instant replay")
	step(r, 90)
	near(_car_loops(r), 0.0, 0.01, "the engine, tires and wind fade out under the replay, not held where it froze")
	for i in 2000:
		if not r.replaying:
			break
		step(r, 1)
	check(r.results.visible, "the results")
	step(r, 60)
	near(_car_loops(r), 0.0, 0.01, "and no engine idling under the results")
	r.start_race()
	step(r, 200, input(1.0))
	check(r.audio.levels["engine_low"] > 0.1 or r.audio.levels["engine_high"] > 0.1, "the next race heard again")


func test_the_engine_stops_idling_once_time_is_up_and_the_car_stops() -> void:
	var r := fresh_race()
	step(r, 300, input(1.0))
	r.time_left = 0.05
	step(r, 10, input(1.0))
	eq(r.state, r.State.TIME_UP, "out of time")
	check(r.audio.levels["engine_low"] + r.audio.levels["engine_high"] > 0.1, "heard while it coasts")
	for i in 3000:
		if r.player.speed <= 0.0:
			break
		step(r, 1, input(1.0))
	step(r, 60, input(1.0))
	near(_car_loops(r), 0.0, 0.01, "then quiet, not idling on under TIME UP")


# --- Engine note per car (PR-18) ---------------------------------------------------------

func test_every_car_has_an_engine_note() -> void:
	var used := {}
	for car: Dictionary in Cars.LIST:
		var model := Cars.engine_model(car)
		check(car.has("engine"), car["id"] + " picks its engine note in Cars.LIST")
		check(EngineModels.MODELS.has(model), car["id"] + " maps to a model: " + model)
		used[model] = true
		for layer in ["low", "high"]:
			var cue := EngineModels.cue(model, layer)
			check(SoundBank.loops(cue), "%s's %s layer, %s, is a loop" % [model, layer, cue])
	eq(used.size(), EngineModels.MODELS.size(), "every model is some car's")
	eq(Cars.engine_model(Cars.find("car_hauler")), "v8", "the Hauler: a V8")
	eq(Cars.engine_model(Cars.find("car_halo")), "small", "the Halo: the small, high-revving note")
	eq(Cars.engine_model({}), EngineModels.DEFAULT, "a car with none: the turbo")


func test_the_engine_models_pitch_curves_differ() -> void:
	var names: Array = EngineModels.MODELS.keys()
	for name: String in names:
		for layer in ["low", "high"]:
			var last := 0.0
			for rpm in [0.0, 0.25, 0.5, 0.75, 1.0, 1.2]:
				var p := EngineModels.pitch(name, layer, rpm)
				check(p > last, "%s %s pitch rises with the revs (%.2f at %.2f)" % [name, layer, p, rpm])
				last = p
		near(EngineModels.low_mix(name, 0.0), 1.0, 0.001, name + " idles on its low layer")
		near(EngineModels.high_mix(name, 0.0), 0.0, 0.001, name + " no high layer at idle")
		check(EngineModels.high_mix(name, 1.0) > 0.5, name + " the high layer in at the top")
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			check(EngineModels.cue(a, "low") != EngineModels.cue(b, "low"), "%s and %s idle on different loops" % [a, b])
			for rpm in [0.0, 1.0]:
				check(absf(EngineModels.pitch(a, "low", rpm) - EngineModels.pitch(b, "low", rpm)) > 0.05,
					"%s and %s at different pitches at %.1f revs" % [a, b, rpm])
	# The small engine revs highest (its loop also fires fastest), the V8 lowest.
	check(EngineModels.pitch("small", "low", 1.0) > EngineModels.pitch("turbo", "low", 1.0), "small over turbo at the top")
	check(EngineModels.pitch("turbo", "low", 1.0) > EngineModels.pitch("v8", "low", 1.0), "turbo over V8 at the top")
	check(EngineModels.high_mix("small", 0.5) > EngineModels.high_mix("turbo", 0.5), "the small one gets buzzy sooner")
	check(EngineModels.high_mix("v8", 1.0) < 1.0 and EngineModels.low_mix("v8", 1.0) >= 0.5, "the V8 keeps its burble")


func test_only_the_turbo_whines_and_pops() -> void:
	for name: String in EngineModels.MODELS:
		var turbo := name == "turbo"
		eq(EngineModels.pops(name), turbo, name + " pops on a shift")
		check((EngineModels.whine_level(name, 1.0, true) > 0.5) == turbo, name + " whines at full revs")
	near(EngineModels.whine_level("turbo", 0.1, true), 0.0, 0.001, "no whine at low revs")
	check(EngineModels.whine_level("turbo", 0.9, false) < EngineModels.whine_level("turbo", 0.9, true), "louder spooling")


func test_the_race_plays_the_cars_engine_note() -> void:
	var r := fresh_race()
	eq(r.audio.engine_model, "turbo", "the Vega: turbo")
	eq(r.audio.loop_cue("engine_low"), "engine_low", "its low layer")
	step(r, 185 + 240, input(1.0))
	check(r.audio.levels["turbo_whine"] > 0.1, "the whine spools under full throttle (%.2f)" % r.audio.levels["turbo_whine"])
	check(count("turbo_pop") > 0, "a pop on an upshift")
	near(r.audio.pitches["engine_low"], EngineModels.pitch("turbo", "low", RaceAudio.engine_rpm(r.player.speed_percent())),
		0.001, "pitch from the model")
	for id in ["car_hauler", "car_halo"]:
		r.car_id = id
		r.start_race()
		audio_node().history.clear()
		step(r, 185 + 240, input(1.0))
		var model := Cars.engine_model(Cars.find(id))
		eq(r.audio.engine_model, model, id + "'s note")
		eq(r.audio.loop_cue("engine_low"), EngineModels.cue(model, "low"), id + " plays its model's low loop")
		var p: AudioStreamPlayer = r.audio._loops.get("engine_low")
		if p != null:
			check(p.stream == SoundBank.stream(EngineModels.cue(model, "low")), id + "'s loop on the player")
		near(r.audio.levels["turbo_whine"], 0.0, 0.001, id + " no whine")
		eq(count("turbo_pop"), 0, id + " no pop")
		near(r.audio.pitches["engine_low"], EngineModels.pitch(model, "low", RaceAudio.engine_rpm(r.player.speed_percent())),
			0.001, id + " pitch from its model")


func test_the_sweep_tool_renders_each_note_differently() -> void:
	var sweep: GDScript = load("res://tools/engine_sweep.gd")
	var crossings := {}
	for name: String in EngineModels.MODELS:
		var s: PackedFloat32Array = sweep.render(name, 1.0)
		eq(s.size(), sweep.RATE, name + ": a second of sweep")
		var peak := 0.0
		var n := 0
		for i in range(1, s.size()):
			peak = maxf(peak, absf(s[i]))
			if (s[i] >= 0.0) != (s[i - 1] >= 0.0):
				n += 1
		check(peak > 0.05 and peak < 1.0, "%s heard, unclipped (peak %.2f)" % [name, peak])
		crossings[name] = n
	check(crossings["small"] > crossings["v8"], "the small one buzzes, the V8 rumbles (%s)" % str(crossings))
	var path := scratch("engine_v8.wav")
	eq(sweep.write_wav(path, sweep.render("v8", 0.2)), OK, "writes a WAV")
	check(FileAccess.get_file_as_bytes(path).size() > 44, "with samples")
