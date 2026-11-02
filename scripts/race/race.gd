extends Node2D
## Race scene: owns the track, player, traffic, timer and checkpoints, and feeds the renderers.
## The game (game.gd) starts it from the menus; quit_requested asks to go back to them.

signal quit_requested
## A Single Race is over and the player confirmed the finish: back to the menus.
signal race_over
## OPTIONS on the pause menu: the game shows the options, then calls options_closed.
signal options_requested

enum State { COUNTDOWN, RACING, FINISHED, TIME_UP }

## The clock on the ARCADE timer, for a stage whose theme has no "clock" of its own (each
## stage sets one, WS-11); Settings scales it for the others.
const RADIO_SHOW := 1.5  # seconds the new station's name stays up
const START_TIME := 45.0
const COUNTDOWN_TIME := 3.0  # seconds from the grid to GO
const CHECKPOINT_BONUS := 25.0
const BACKGROUND_SCROLL := 0.0006  # per segment travelled, per unit of curve
# After the finish line (finish_time_scale)
const FINISH_SLOWMO := 0.35  # how fast the world runs just past the line
const FINISH_SLOWMO_HOLD := 0.8  # seconds at that speed
const FINISH_SLOWMO_EASE := 1.2  # seconds back up to full speed
const FINISH_BRAKING := Cfg.MAX_SPEED / 3.0  # on top of coasting; stops from top speed in about 2 s
## The results come up once the slow-down is over (Enter brings them sooner).
const RESULTS_AFTER := FINISH_SLOWMO_HOLD + FINISH_SLOWMO_EASE
const TRAFFIC_COUNT := 70  # a stage theme can ask for more ("traffic")

var track: Track
var stage_index := 0  # into Stages
var tour := true  # Grand Tour: a finish goes on to the next stage. false: a Single Race
## An attract-mode demo (Attract): autodriven with traffic, no countdown, the player's
## controls ignored (the game watches them to end it). It ends itself (quit_requested) at
## the finish, at time up or after Attract.DEMO_SECONDS, and it never saves anything
## (_saves).
var demo := false
## Time Attack: solo against the clock and the best run's ghost; no rivals, no time limit.
var time_attack := false
## Free Drive: no clock, no rivals, no finish; the road loops on until you quit (pause menu).
var free_drive := false
## Mirror mode (WS-6): the stage flipped left for right (Stages.build). It shares the stage's
## best times and ghost: the same road, the same distances.
var mirror := false
## An online race (ON-3): the room, or null. The other players are rivals moved by what their
## games send (RivalCar.remote); no AI rivals, no clock, nothing saved. The countdown waits on
## the host's GO, and the pause menu doesn't stop the race.
var online: OnlineSession
var _shown := {}  # online: slot -> where its car was shown last tick (OnlineSession.shown_at)
## Online after the finish (ON-10): the car the camera follows, the leader of the players still
## racing (watch_target); null when not watching. The results wait until the last car is in.
var watching: RivalCar
## Online (ON-11): a short line about the room ("P2 DROPPED OUT"), and its seconds left.
var notice := ""
var notice_time := 0.0
## Online (ON-11): the room went mid-race (the host left, or the line): the race ended there,
## with the results so far.
var cut_short := false
const NOTICE_TIME := 3.0
const FADE_TIME := 1.2  # seconds a player who dropped out takes to fade off the road
const CUT_SHORT_RESULTS := 1.5  # seconds from the room going to the results
var _own_strips: Dictionary = {}  # the player car's strips, for the camera back from watching
var ghost: Ghost  # Time Attack: the best run so far, replayed (null before the first)
var recording: Ghost  # Time Attack: this run, tick by tick
var ghost_now := Vector3.ZERO  # the ghost this tick: distance, x, steer (Ghost.at)
var split := NAN  # Time Attack: seconds against the ghost at the last checkpoint (minus is ahead)
var new_best := false  # Time Attack: this finish beat the ghost and replaced it
## The instant replay (RC-17): after the finish spectacle, the last Replay.SECONDS before the
## line once, from a trace of every car recorded while racing; any button skips it. Not in a
## demo, online or in Free Drive (no finish). Tests that aren't about it turn it off.
var instant_replay := true
var replay_trace := Replay.new()
var replaying := false
var replay_frames: Array[PackedFloat32Array] = []
var replay_index := 0  # the next frame to show
var replay_player: PlayerCar  # stand-ins the road draws while the replay runs
var replay_rivals: Array[RivalCar] = []
var _replay_skip := false  # a key or button went down during the replay (_input)
var _replay_done := false  # this finish's replay has run (or been skipped)
var _traffic_before := PackedFloat32Array()  # the traffic as it was, put back after the replay
## What Enter does after a finish or TIME UP: on, another go, or back to the menus.
enum After { NEXT_STAGE, RETRY, TOUR_OVER, TOUR_DONE, MENU }
var tour_state: Tour  # the Grand Tour's standings and continue, kept stage to stage
var after := After.RETRY
var car_id := "car_vega"  # into Cars
var player: PlayerCar
var power_ups := PowerUps.new()
var pickup := -1  # the last pickup taken (PowerUps.Kind), for the HUD
var pickup_gave := -1  # what it gave (a mystery hubcap opens into another kind)
var pickup_age := 99.0  # seconds since it was taken
var picked_up := false  # true for the tick a pickup is taken
var view: int = CameraView.View.CHASE_NEAR  # the camera view (WS-15, set_view)
var hour := Sundown.DEFAULT_HOUR  # the time of day the stage is shown at (Sundown, WS-16)
var horn := false  # the horn button held this tick (RaceAudio sounds it; traffic ahead gives way, RC-13)
var ram_flash := 0.0  # seconds left on the ram plate's impact flash
## Gamepad rumble (WH-13): what it sent last tick (ZERO for nothing) and how many it has sent.
var rumble := Rumble.new()
var last_rumble := Vector3.ZERO
var rumble_sent := 0
var traffic: Traffic
var rivals := Rivals.new()
var state := State.COUNTDOWN
var countdown := COUNTDOWN_TIME
var time_left := START_TIME
var race_time := 0.0
var finish_age := 0.0  # seconds since the finish line (real time, not slowed)
var _results_shown := false  # the results have come up for this finish (closed again or not)
var results_age := -1.0  # seconds since the results came up, -1 before (StageFlow.crossfade)
var launch: Launch.Grade = Launch.Grade.PENDING  # how the player's start went
var score := Scoring.new()
var place := 1  # the player's place in the field (Rivals.standings)
var difficulty := Difficulty.of(Difficulty.Level.NORMAL)  # this race's (Settings.difficulty)
var player_finish := -1.0  # race time the player finished in, -1 still racing
var touched_traffic := false  # the player has touched a traffic car this stage (Unlocks secret)
var new_unlocks: Array[String] = []  # car ids (and a stage's mirror_id) this finish opened, for the HUD
var finish_distance := 1.0
var checkpoint_bonus := CHECKPOINT_BONUS  # the next checkpoint's, after the timer option
var clock: Array[float] = []  # this stage's ARCADE clock: start, then each checkpoint (stage_clock)
var checkpoint_distances: Array[float] = []
var next_checkpoint := 0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var callouts := Callouts.new()  # what the HUD shows of the banners, and the starbursts (PR-5)
var paused := false
var pause_menu: PauseMenu
## The GUID of the joypad driving while it's unplugged (WH-7), or "". The pause menu says so.
var unplugged := ""
var _unplug_paused := false  # the unplugging paused the race, so plugging back in resumes it
## Seconds left counting 3, 2, 1 after the joypad came back (WH-12), before the race resumes;
## 0 when not counting. The pause menu shows the count (PauseMenu.counting).
var replug_count := 0.0
var results: ResultsScreen  # after the finish (RC-5)
var new_best_time := false  # this finish set the best time for the stage and car
var best_before := {}  # SaveData.best for the stage and car before this finish
var stats_recorded := false  # this run is in the stats page's counters (record_stats)
var _start_distance := 0.0  # where the player started this run, for the miles driven

var background: Background
var road: RoadRenderer
## The layer the HUD, the results, the pause menu and the photo flash are on: hidden for the
## frame a photo is taken (begin_photo).
var ui_layer: CanvasLayer
var photo: Photo  # the photo key's flash (PR-21)
var photo_taking := false  # the HUD is hidden for a photo being taken
var last_photo := ""  # the last photo's path ("" when it couldn't be saved)
var _touch_was_visible := false
var fx: FxLayer  # between the road and the HUD
var hud: Hud
## The F1 input overlay, F2 calibration wizard and F3 tuning panel. The game passes in its
## own, so there is one of each across the menus and the race; a race run on its own (tests,
## race.tscn) makes its own.
var debug_overlay: InputDebugOverlay
var calibration: CalibrationWizard
var debug_panel: DebugPanel
var audio: RaceAudio

var _shake := 0.0  # camera shake as designed, in pixels; the screen shake option scales what shows
var _fov_stretch := 0.0  # 0..camera/nitro_fov_stretch (Tuning), eased while nitro burns
var _was_airborne := false
var _autodrive := false
var _log_banners := false
var _no_traffic := false
var _no_rivals := false
var _start_segment := 0  # --at-segment=N: start the race this far in (screenshots)
var _results_shot := false  # --screen=results: a staged finish, for a screenshot of the results
var _staged := false  # this race was staged for a screenshot: nothing it does is saved
var _drive_x := NAN  # --drive-x=X: start on this line and autodrive holds it (road half-widths; past 1 is off the road)
var _lightning_at := NAN  # --lightning-at=SECONDS: a full lightning strike then, on a stage with lightning (screenshots)
var _screenshot_frames: Array[int] = []
var _photo_frames: Array[int] = []  # --photo-at=N,M: the photo key pressed on those frames (into --shot-dir)
var _screenshot_dir := ""
var _gas_since := NAN  # when the gas went down, in seconds from GO (Launch.grade)
var _frame := 0  # physics ticks since this race (re)started
var _final_stretch := false  # FINAL STRETCH has come up this race
var _led_at := -INF  # race time of the last 1ST PLACE callout
var _callout_shot := Callouts.Kind.NONE  # --callout=ID: that starburst held up after GO (screenshots)
var _callout_shot_count := 0  # --callout=ID:COUNT: with that count (NEAR MISS x3)
var _pickup_shot := -1  # --pickup=ID (PowerUps.IDS): the player takes that pickup at GO (screenshots)
var _time_left_shot := NAN  # --time-left=S: start with this much on the clock (low-time screenshots)
## The dev flags are for the race the game starts with; later races come from the menus.
static var _dev_args_read := false


func _ready() -> void:
	SpriteLibrary.load_all()
	background = Background.new()
	add_child(background)
	road = RoadRenderer.new()
	add_child(road)
	road.background = background
	fx = FxLayer.new()
	add_child(fx)
	var layer := CanvasLayer.new()
	ui_layer = layer
	add_child(layer)
	hud = Hud.new()
	hud.race = self
	layer.add_child(hud)
	results = ResultsScreen.new()
	results.race = self
	layer.add_child(results)
	pause_menu = PauseMenu.new()
	layer.add_child(pause_menu)
	if debug_overlay == null:
		debug_overlay = InputDebugOverlay.new()
		layer.add_child(debug_overlay)
	if calibration == null:
		calibration = CalibrationWizard.new()
		layer.add_child(calibration)
	if debug_panel == null:
		debug_panel = DebugPanel.new()
		layer.add_child(debug_panel)
	debug_panel.race = self
	photo = Photo.new()
	layer.add_child(photo)  # over the rest of the layer
	audio = RaceAudio.new(self)
	add_child(audio)
	if not InputRouter.driver_unplugged.is_connected(driver_unplugged):
		InputRouter.driver_unplugged.connect(driver_unplugged)
		InputRouter.driver_replugged.connect(driver_replugged)
	# (the window's notification may not reach a node under it on every platform: its signal does)
	if is_inside_tree() and not get_window().focus_exited.is_connected(focus_lost):
		get_window().focus_exited.connect(focus_lost)
	if not _dev_args_read:
		_dev_args_read = true
		_parse_dev_args()
	TouchControls.set_race(self)
	start_race()


func start_race() -> void:
	record_stats(false)  # a run restarted partway: its miles, crashes and near misses
	InputRouter.speed_factor = 0.0
	_frame = 0
	track = Stages.build(stage_index, mirror)
	# The sun drops stage by stage in a Grand Tour; a single race keeps the stage's own hour
	hour = Sundown.apply(track, stage_index, Stages.count(), tour)
	CarSprites.shadow_length = Sundown.shadow_length(Sundown.lit_hour(track.theme))
	player = PlayerCar.new()
	var car := Cars.find(car_id)
	player.setup(car)
	player.manual = Settings.manual_gears and not demo  # the attract demo shows the automatic
	CarSprites.load_all()
	player.reset(_start_segment * Cfg.SEGMENT_LENGTH)
	player.distance = _start_segment * Cfg.SEGMENT_LENGTH  # that far along the route, so the finish is where it is drawn
	_start_distance = player.distance
	stats_recorded = false
	if not is_nan(_drive_x):
		player.x = _drive_x  # already on that line, past any roadside railing
	elif online != null:
		player.x = OnlineSession.grid_x(online.slot) * track.side()  # four abreast, by slot
	player.road_y = track.height_at(player.position + Cfg.PLAYER_Z)
	power_ups = PowerUps.new()
	if Settings.power_ups:
		power_ups.place(track)
	pickup = -1
	pickup_gave = -1
	pickup_age = 99.0
	ram_flash = 0.0
	_shake = 0.0
	_fov_stretch = 0.0
	_was_airborne = false
	traffic = Traffic.new()
	var cars := int(track.theme.get("traffic", TRAFFIC_COUNT))
	var traffic_count := cars if demo else Settings.traffic_count(cars)
	if _no_traffic or ((time_attack or free_drive) and not Settings.attack_traffic):
		traffic_count = 0
	traffic.spawn(track, traffic_count, 7, player.position + Cfg.PLAYER_Z)  # none just ahead of the start (RC-14)
	if tour and tour_state == null:
		tour_state = Tour.new()
		tour_state.start_stage = stage_index
	rivals = Rivals.new()
	difficulty = Difficulty.of(Settings.difficulty)
	rivals.spawn(track, player, car_id, 0 if _no_rivals or time_attack or free_drive or online != null else Rivals.COUNT,
		Rivals.SEED + stage_index, difficulty, tour_state.drivers if tour else [])
	_shown.clear()
	if online != null:
		for s: int in online.racers:
			if s != online.slot and online.players.has(s):
				var r := RivalCar.remote_player(Cars.find(String(online.players[s])), s)
				r.reset(player.position)
				r.distance = player.distance
				r.x = OnlineSession.grid_x(s) * track.side()
				r.road_y = player.road_y
				rivals.cars.append(r)
				_shown[s] = Vector3(r.distance, r.x, 0.0)
		online.loaded()
	if tour and tour_state.drivers.is_empty():
		tour_state.drivers = rivals.driver_names()
	state = State.RACING if demo else State.COUNTDOWN
	countdown = 0.0 if demo else COUNTDOWN_TIME
	clock = stage_clock(track.theme, track.checkpoints.size())
	time_left = Settings.race_time(clock[0]) + (tour_state.carried if tour else 0.0)
	if not is_nan(_time_left_shot):
		time_left = _time_left_shot
	after = After.RETRY
	checkpoint_bonus = Settings.race_time(clock[1]) if clock.size() > 1 else 0.0
	race_time = 0.0
	finish_age = 0.0
	_results_shown = false
	results_age = -1.0
	replay_trace = Replay.new()
	replaying = false
	replay_frames.clear()
	replay_index = 0
	_replay_done = false
	player_finish = -1.0
	touched_traffic = false
	new_unlocks.clear()
	new_best_time = false
	best_before = SaveData.best(stage_index, car_id)
	results.close()
	score = Scoring.new()
	launch = Launch.Grade.PENDING
	_gas_since = NAN
	place = rivals.place(player, player_finish)
	ghost = Ghost.load_best(stage_index, car_id) if time_attack else null
	recording = Ghost.make(stage_index, car_id) if time_attack else null
	ghost_now = Vector3.ZERO if ghost == null else Ghost.sided(ghost.at(0), track.side())
	road.ghost = ghost_now
	split = NAN
	new_best = false
	next_checkpoint = 0
	banner = ""
	callouts.clear()
	_final_stretch = false
	_led_at = -INF
	resume()
	finish_distance = track.finish_index * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z
	checkpoint_distances.clear()
	for c in track.checkpoints:
		checkpoint_distances.append(c * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z)
	# Started partway in (--at-segment): past the checkpoints behind it
	while next_checkpoint < checkpoint_distances.size() and player.distance >= checkpoint_distances[next_checkpoint]:
		next_checkpoint += 1
	background.set_theme(track.theme, track.next_theme)
	background.mirrored = track.mirrored
	road.flow = not free_drive  # (its road loops straight back to its own start)
	road.flow_share = 0.0
	road.flow_fade = 0.0
	background.offset = 0.0
	road.track = track
	road.player = player
	road.player_strips = CarSprites.strips(car["strip"])
	_own_strips = road.player_strips
	watching = null
	notice = ""
	notice_time = 0.0
	cut_short = false
	road.rivals = rivals.cars
	road.ghost_strips = road.player_strips if ghost != null else {}
	fx.clear()
	fx.set_weather(track.theme, _lightning_at)
	fx.player = player
	set_view(Settings.camera_view)


## Pad steering's speed sensitivity is the race's to set; the menus get it back at rest.
func _exit_tree() -> void:
	record_stats(false)  # quit partway (or after the results, already counted)
	InputRouter.speed_factor = 0.0
	if debug_panel != null and debug_panel.race == self:
		debug_panel.race = null


## After a finish: on to the next stage, or back to the first after the last.
func continue_tour() -> void:
	stage_index = maxi(0, Stages.next(stage_index))
	start_race()


## R, or RESTART on the pause menu. In a tour, a stage that is over goes the way Enter
## would (after_race), and one still running costs the continue; with none left it can't be
## restarted. Returns false when it wasn't.
func restart() -> bool:
	if online != null:
		resume()
		return false  # an online race goes on for everyone
	if not tour:
		start_race()
		return true
	if state == State.TIME_UP or state == State.FINISHED:
		after_race()
		return true
	if not tour_state.use_continue():
		resume()
		_banner("NO CONTINUE LEFT", "", 1.5)
		return false
	start_race()
	return true


## Enter (or R) after a finish or TIME UP.
func after_race() -> void:
	match after:
		After.NEXT_STAGE:
			continue_tour()
		After.RETRY:
			if tour:
				tour_state.use_continue()
			start_race()
		After.TOUR_OVER, After.TOUR_DONE, After.MENU:
			race_over.emit()


## What a stage that went wrong (TIME UP, or outside the top three) leads to in a tour, and
## the prompt for it.
func _setback_prompt() -> String:
	if tour_state.continues > 0:
		after = After.RETRY
		return "Enter: use your continue"
	after = After.TOUR_OVER
	return "Tour over.   Enter: menu"


func pause() -> void:
	paused = true
	rumble.stop(InputRouter.last_active_device)  # (the keyboard's -1: nothing to stop)
	pause_menu.has_options = not options_requested.get_connections().is_empty()
	pause_menu.open()


func resume() -> void:
	paused = false
	replug_count = 0.0
	pause_menu.counting = 0.0
	pause_menu.close()
	unplugged = ""  # resumed without it (the keyboard, or a restart): no waiting for it
	_unplug_paused = false
	pause_menu.notice = []


## The rumble option while a gamepad drives (WH-13): 0 for the keyboard, a wheel, the attract
## demo, an autodriven run, or under the pause menu (online, the race runs on beneath it).
func rumble_level() -> int:
	if demo or _autodrive or paused or InputRouter.state.kind != DriveInput.Kind.GAMEPAD:
		return 0
	return Settings.rumble


## Auto-pause (AC-15): the window losing focus, the app going to the background (a phone
## browser's tab hidden) or the OS pausing it pauses a race under way (focus_lost).
const FOCUS_LOST := [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]


func _notification(what: int) -> void:
	if what in FOCUS_LOST:
		focus_lost()


## Whether losing focus pauses the race now: a race under way, the player's (not the attract
## demo, an autodriven run or a golden trace), not paused already, and not online, where the
## pause menu doesn't stop the race and opening it on its own would leave the car coasting.
func auto_pauses() -> bool:
	return not demo and not _autodrive and online == null and not paused \
		and (state == State.COUNTDOWN or state == State.RACING)


## The window lost focus: pauses the race if auto_pauses says so. Returns whether it did.
func focus_lost() -> bool:
	if not auto_pauses():
		return false
	pause()
	return true


## The joypad driving was unplugged (InputRouter.driver_unplugged): a race under way pauses,
## saying which to plug back in. Already paused, it only says so.
func driver_unplugged(guid: String, joy_name: String, wheel: bool) -> void:
	if demo or _autodrive or not (state == State.COUNTDOWN or state == State.RACING):
		return
	if not paused:
		pause()
		_unplug_paused = true
	unplugged = guid
	pause_menu.notice = PauseMenu.unplugged_notice(joy_name, wheel)


## A joypad is back (InputRouter.driver_replugged, WH-12): the one that went (`same`), or a
## different one in its place, which the notice says. If the unplugging paused the race and
## the pause menu is still up (not the options over it), it counts 3, 2, 1 and carries on
## (replug_tick); otherwise it stays paused as the player left it, the notice saying only
## that a different device is driving.
func driver_replugged(_guid: String, joy_name := "", wheel := false, same := true) -> void:
	if unplugged == "":
		return
	unplugged = ""
	if _unplug_paused and paused and pause_menu.visible:
		replug_count = PauseMenu.REPLUG_COUNT
		pause_menu.counting = replug_count
		pause_menu.notice = PauseMenu.replugged_notice(joy_name, wheel, same)
		Audio.play("beep")
	else:
		var n: Array[String] = []
		if not same:
			n = PauseMenu.replugged_notice(joy_name, wheel, same)
		pause_menu.notice = n


## One tick of the replug countdown: a beep on each number, the race resumed at 0. Pause
## (or back) stops it, and the pause menu takes over, still paused.
func replug_tick(dt: float, stop: bool) -> void:
	if stop:
		replug_count = 0.0
		pause_menu.counting = 0.0
		pause_menu.open()
		return
	var shown := ceili(replug_count)
	replug_count = maxf(0.0, replug_count - dt)
	pause_menu.counting = replug_count
	if replug_count <= 0.0:
		resume()
	elif ceili(replug_count) != shown:
		Audio.play("beep")


## Back from the options the pause menu opened: the menu again, still paused.
func options_closed() -> void:
	pause_menu.reopen()


## Carries out what the pause menu picked (PauseMenu.Action).
func pause_action(action: int) -> void:
	match action:
		PauseMenu.Action.RESUME:
			resume()
		PauseMenu.Action.RESTART:
			restart()
		PauseMenu.Action.OPTIONS:
			pause_menu.close()
			options_requested.emit()
		PauseMenu.Action.QUIT:
			quit_requested.emit()


## Carries out the tuning panel's action (TuningPanel.Action), with its values in `panel`.
func debug_action(action: int, panel: TuningPanel) -> void:
	match action:
		TuningPanel.Action.JUMP:
			debug_jump(panel.jump_to)
		TuningPanel.Action.GIVE:
			_give(TuningPanel.GIVE_KINDS[panel.give])
		TuningPanel.Action.CLOCK:
			time_left = panel.clock
		TuningPanel.Action.BURST:
			traffic.burst(track, player.position + Cfg.PLAYER_Z + 1000.0, panel.burst)


## Puts the player's car at segment `seg`, that far along the route (as --at-segment does):
## the checkpoints behind it are passed, the ones ahead still to come.
func debug_jump(seg: int) -> void:
	player.position = fposmod(seg * Cfg.SEGMENT_LENGTH, track.length)
	player.last_position = player.position
	player.distance = seg * Cfg.SEGMENT_LENGTH
	player.road_y = track.height_at(player.position + Cfg.PLAYER_Z)
	player.x = clampf(player.x, -1.0, 1.0)
	next_checkpoint = 0
	while next_checkpoint < checkpoint_distances.size() and player.distance >= checkpoint_distances[next_checkpoint]:
		next_checkpoint += 1


## A demo is done: it reached the finish, ran out of time or ran its length.
func demo_over() -> bool:
	return state == State.FINISHED or state == State.TIME_UP or race_time >= Attract.DEMO_SECONDS


func counting_down() -> bool:
	return state == State.COUNTDOWN


## Seconds since the countdown started (the stage intro card, StageIntro, slides by it).
func countdown_elapsed() -> float:
	return COUNTDOWN_TIME - countdown


## Whether the touch controls (TouchControls) show the driving layout: the race is on screen,
## not under the pause menu, the results or the calibration wizard.
func touch_driving() -> bool:
	return not demo and not paused and not results.visible and not calibration.visible


## Any key or button skips the instant replay (RC-17), mapped or not.
func _input(event: InputEvent) -> void:
	if replaying and Attract.is_wake_event(event):
		_replay_skip = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_input"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("calibrate") and not calibration.visible:
		calibration.open()


func _physics_process(dt: float) -> void:
	if InputRouter.state.photo_pressed and not demo:
		take_photo()
	var inp: DriveInput = Settings.drive_input(InputRouter.state)
	if _autodrive or demo:
		inp = _autodrive_input()
	else:
		if Settings.co_pilot:  # (AC-14: in place of the steering assist, and braking for the bends)
			inp = Assists.co_pilot(inp, player, track)
		inp = Assists.apply(inp, player, track, Settings.steer_assist and not Settings.co_pilot,
			Settings.brake_assist or Settings.co_pilot)
	horn = inp.horn
	if calibration.visible or debug_panel.visible:  # (the tuning panel holds the race still)
		_redraw()
		return
	dt *= debug_panel.logic.slow_motion()
	if paused:
		if replug_count > 0.0:  # the joypad back: 3, 2, 1 (WH-12)
			replug_tick(dt, inp.pause_pressed or InputRouter.menu.back_pressed)
		elif pause_menu.visible:  # (hidden while the options are up)
			pause_action(pause_menu.choose(InputRouter.menu, inp.pause_pressed))
		if online == null or not paused:
			_redraw()
			return
		inp = DriveInput.new()  # online the race runs on under the menu, the car coasting
	if replaying:  # (the player's own buttons skip it, not the autodrive's)
		_replay_tick(dt, Settings.drive_input(InputRouter.state))
		return
	if results.visible:
		if inp.restart_pressed and online == null:  # R: in a tour, on as ever; otherwise the stage again
			if tour:
				after_race()
			else:
				start_race()
			return
		if online != null:
			online_results_input(InputRouter.menu)
		match results.choose(InputRouter.menu, inp.confirm_pressed):
			ResultsScreen.Choice.CONTINUE:
				if online != null:
					online_continue()
				else:
					after_race()
				return
			ResultsScreen.Choice.RETRY:
				start_race()
				return
			ResultsScreen.Choice.QUIT:
				quit_requested.emit()
				return
	var over := state == State.TIME_UP or state == State.FINISHED
	if state == State.FINISHED and not _results_shown and (inp.confirm_pressed or (finish_age >= RESULTS_AFTER and watching == null) or _staged):
		if not inp.confirm_pressed and not _staged and replay_offered() and not _replay_done and not replay_trace.frames.is_empty():
			start_replay()  # after the finish spectacle, the replay first (RC-17)
			_redraw()
			return
		_show_results()  # after the finish spectacle, or Enter for them now
		if inp.confirm_pressed:
			return
	if over and not results.visible and inp.confirm_pressed:
		after_race()
		return
	if inp.restart_pressed and online == null:
		restart()
		return
	if inp.pause_pressed and not paused:
		pause()
		_redraw()
		return
	if inp.radio_pressed and not over:
		audio.next_station()
		callouts.push_message(Radio.station_name(audio.station), Radio.genre(audio.station), RADIO_SHOW)
	if inp.view_pressed and not demo:
		Settings.camera_view = CameraView.next(Settings.camera_view)
		Settings.save()  # remembered in Options (WS-15)
		callouts.push_message(CameraView.name_of(Settings.camera_view), "VIEW", RADIO_SHOW)
	if view != Settings.camera_view:  # the VIEW button, or Options from the pause menu
		set_view(Settings.camera_view)

	banner_time = maxf(0.0, banner_time - dt)
	_watch_launch(inp)
	match state:
		State.COUNTDOWN:
			if online == null or online.go:  # online, the countdown runs from the host's GO
				countdown -= dt
			if countdown <= Tuning.v("launch/roll_time"):
				for car: PlayerCar in rivals.everyone(player):
					car.speed = Tuning.v("launch/roll_speed")
			if countdown <= 0.0:
				state = State.RACING
				_banner("GO!", "", 1.0, Callouts.Kind.GO)
				if _callout_shot != Callouts.Kind.NONE:
					callouts.push(_callout_shot, "", Callouts.HOLD, _callout_shot_count)
					if _callout_shot == Callouts.Kind.CHECKPOINT and timed():  # as a checkpoint shows (PR-15)
						callouts.push(Callouts.Kind.TIME_EXTENDED, "+%d SEC" % checkpoint_bonus)
				if _pickup_shot >= 0:
					take_pickup(_pickup_shot)
				race_time += dt  # the cars drive on the GO tick, and the rivals' clock counts it
		State.RACING:
			race_time += dt
			if timed():
				time_left -= dt
			if time_left <= 0.0 and timed():
				time_left = 0.0
				state = State.TIME_UP
				record_stats(true)
				_banner("TIME UP", _setback_prompt() if tour else "Press R or Enter to try again", Callouts.HOLD)

	# Past the line the world drops into slow motion for a moment (sim, the world's tick), and
	# the car brakes itself to a stop
	var sim := dt
	if state == State.FINISHED:
		finish_age += dt
		sim = dt * finish_time_scale(finish_age)

	InputRouter.speed_factor = player.speed_percent()
	var cam: PlayerCar = player if watching == null else watching  # (last tick's)
	var seg_before := track.find_segment(cam.position + Cfg.PLAYER_Z)
	var solid := solid_cars()
	Draft.update(player, sim, state == State.RACING and Draft.in_wake(player, track, solid))
	player.update(sim, inp, track, state == State.RACING)
	if horn and state == State.RACING:
		traffic.honk(track, player.position + Cfg.PLAYER_Z, player.x, player.speed)  # (RC-13)
	traffic.update(sim, track)
	rivals.update(sim, track, player, state != State.COUNTDOWN, finish_distance)
	if online != null:
		_online_tick(sim)
	player.collide(track)
	if state == State.FINISHED:
		player.speed = move_toward(player.speed, 0.0, FINISH_BRAKING * sim)
		player.braking = player.speed > 0.0
	touched_traffic = touched_traffic or player.hit_traffic
	Rivals.resolve_contacts(solid, track)
	place = rivals.place(player, player_finish)
	var place_before := place
	picked_up = false
	pickup_age += sim
	ram_flash = 0.3 if player.rammed else maxf(0.0, ram_flash - sim)
	score.age_feed(dt)
	callouts.update(dt)
	var earned := score.bonuses.size()
	if state == State.RACING:
		score.watch(dt, player, track)
		_check_pickups()
		if recording != null:
			recording.record(player, track.side())
		if replay_offered():
			replay_trace.record([player] + rivals.cars, traffic.cars)
		_check_progress()
		_callouts_after_tick(earned, place_before)
	if demo and demo_over():
		quit_requested.emit()
		return
	if ghost != null:
		ghost_now = Ghost.sided(ghost.at(recording.count() - 1), track.side())
		road.ghost = ghost_now

	background.offset += seg_before.curve * (cam.speed * sim / Cfg.SEGMENT_LENGTH) * BACKGROUND_SCROLL

	# Camera shake: rough ground, crests, landings, crashes. Display only (road.position).
	_shake = shake_after(_shake, player, player.airborne and not _was_airborne, dt)
	_was_airborne = player.airborne
	var shown := Settings.shake_amount(_shake)
	road.position = Vector2(roundf(randf_range(-1, 1) * shown), roundf(randf_range(-1, 1) * shown))
	# Nitro widens the view a little (display only: the renderer's camera depth)
	var stretch_to := Tuning.v("camera/nitro_fov_stretch") if player.nitro_time > 0.0 else 0.0
	_fov_stretch = move_toward(_fov_stretch, stretch_to, dt * Tuning.v("camera/nitro_fov_rate"))
	road.camera_depth = camera_depth(_fov_stretch)
	road.flash = Settings.flash_amount(1.0)
	road.time += sim
	fx.flash_share = road.flash
	fx.update(sim, cam, track)  # (watching online: the car on screen, ON-10)
	last_rumble = rumble.tick(sim, player, rumble_level())
	if last_rumble != Vector3.ZERO:
		rumble_sent += 1
		Rumble.send(InputRouter.last_active_device, last_rumble)
	fx.position = road.position
	cam = follow(watch_target(rivals.cars) if online != null and state == State.FINISHED and player_finish >= 0.0
		and online.phase != OnlineSession.Phase.CLOSED else null)
	road.camera_z = CameraView.camera_z(view, cam.position, track.length)
	var rise := track.height_at(cam.position + Background.HILL_AHEAD) - cam.road_y
	background.hill = Background.shown_hill(rise, road.camera_depth)
	_flow(dt)
	if _results_shot and state == State.RACING and race_time > 1.0:
		_stage_results_shot()
	_redraw()
	_frame += 1
	if _screenshot_frames.has(_frame):
		_save_screenshot(_frame)
	if _photo_frames.has(_frame):
		take_photo()


## The photo key (PR-21): hides the HUD for this frame, grabs the frame once it is drawn and
## saves it (finish_photo). Not while one is being taken already.
func take_photo() -> void:
	if not begin_photo():
		return
	if not is_inside_tree():
		finish_photo(null)
		return
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	finish_photo(tex.get_image() if tex != null else null)


## Hides the HUD layer (the HUD, the pause menu, the results) and the touch controls for the
## photo's frame. Returns false when a photo is already being taken.
func begin_photo() -> bool:
	if photo_taking:
		return false
	photo_taking = true
	ui_layer.visible = false
	_touch_was_visible = TouchControls.current != null and TouchControls.current.visible
	if _touch_was_visible:
		TouchControls.current.visible = false
	return true


## The photo's frame, `img`, grabbed: saves it (Photo.save), puts the HUD back, sounds the
## shutter and flashes. Returns the photo's path, "" when there was nothing to save.
func finish_photo(img: Image) -> String:
	photo_taking = false
	ui_layer.visible = true
	if _touch_was_visible and TouchControls.current != null:
		TouchControls.current.visible = true
	last_photo = Photo.save(img)
	Audio.play("shutter")
	photo.flash()
	return last_photo


## The camera view (WS-15, CameraView) the road and the FX layer draw from. Display only.
func set_view(v: int) -> void:
	view = clampi(v, 0, CameraView.View.size() - 1)
	road.view = view
	fx.view = view


## Camera shake (pixels, as designed) after a tick: a crash sets it, a landing, a takeoff
## over a crest and rough ground at speed kick it up, and it settles back to still.
static func shake_after(shake: float, p: PlayerCar, took_off: bool, dt: float) -> float:
	if p.crashed:
		shake = Tuning.v("camera/shake_crash")
	elif p.landed:
		shake = maxf(shake, Tuning.v("camera/shake_landing"))
	elif took_off:
		shake = maxf(shake, Tuning.v("camera/shake_takeoff"))
	elif p.offroad and p.speed > 100.0:
		shake = maxf(shake, Tuning.v("camera/shake_offroad") * p.speed_percent())
	return move_toward(shake, 0.0, dt * Tuning.v("camera/shake_settle"))


## The renderer's camera depth for a nitro stretch (0..camera/nitro_fov_stretch), after the
## screen shake option: the tuned camera/depth with no stretch or with the option at 0.
static func camera_depth(stretch: float) -> float:
	return Tuning.v("camera/depth") * (1.0 - Settings.shake_amount(stretch))


## Grades the start once it's known: the gas down in the window around GO, or too early.
func _watch_launch(inp: DriveInput) -> void:
	if launch != Launch.Grade.PENDING:
		return
	var now := -countdown if state == State.COUNTDOWN else race_time
	if inp.throttle >= Launch.GAS_DOWN:
		if is_nan(_gas_since):
			_gas_since = now
	else:
		_gas_since = NAN
	if state == State.COUNTDOWN:
		return
	# Auto gas holds the gas for the player all through the countdown: a plain start, no bog
	launch = Launch.Grade.NONE if Settings.auto_gas and not _autodrive else Launch.grade(_gas_since, now)
	Launch.apply(player, launch)
	if launch == Launch.Grade.LAUNCH:
		_banner("LAUNCH!", "", 1.0, Callouts.Kind.LAUNCH)
	elif launch == Launch.Grade.BOG:
		_banner("GO!", "Too early!", 1.0, Callouts.Kind.GO)


func _check_pickups() -> void:
	var p := power_ups.take(player.passed_segments(track), player.x)
	if p == null:
		return
	take_pickup(p.kind)


## The player takes a pickup of `kind` (a PowerUps.Kind): a mystery hubcap opens into another
## kind, the HUD's slot shows it (Hud.slot_icon) and it takes effect.
func take_pickup(kind: int) -> void:
	picked_up = true
	pickup = kind
	pickup_gave = power_ups.open(kind, time_left)
	pickup_age = 0.0
	_give(pickup_gave)


## Catch-up nitro at a checkpoint (RC-16): a charge back in the last places, on a difficulty
## that gives it (Difficulty.catch_up_nitro). Not online, where each racer has their own.
func _catch_up() -> void:
	if online != null:
		return
	var back := mini(difficulty.catch_up_nitro(place, rivals.cars.size() + 1), player.nitro_max - player.nitro_charges)
	if back > 0:
		player.nitro_charges += back
		callouts.push_message("NITRO +%d" % back, "Catch-up")


## What a pickup (or the debug panel) gives: a PowerUps.Kind other than MYSTERY.
func _give(kind: int) -> void:
	match kind:
		PowerUps.Kind.NITRO:
			player.nitro_charges = mini(player.nitro_max, player.nitro_charges + 1)
			_banner("NITRO +1", "", 1.2)
		PowerUps.Kind.CLOCK:
			time_left += Tuning.v("power_ups/clock_bonus")
			_banner("+%d SEC" % Tuning.v("power_ups/clock_bonus"), "", 1.2)
		PowerUps.Kind.RAM:
			player.ram_time = Tuning.v("power_ups/ram_time")
			_banner("RAM PLATE", "Traffic goes flying", 1.2)
		PowerUps.Kind.GHOST:
			player.ghost_time = Tuning.v("power_ups/ghost_time")
			_banner("GHOST", "Drive right through", 1.2)


func _check_progress() -> void:
	if free_drive:
		return
	if next_checkpoint < checkpoint_distances.size() and player.distance >= checkpoint_distances[next_checkpoint]:
		next_checkpoint += 1
		score.checkpoint()
		if time_attack:
			split = race_time - ghost.time_at(player.distance, 1.0 / Engine.physics_ticks_per_second) if ghost != null else NAN
			_banner("CHECKPOINT", "" if is_nan(split) else split_text(split) + " vs best", 2.0, Callouts.Kind.CHECKPOINT)
		else:
			time_left += checkpoint_bonus
			_banner("CHECKPOINT!", "TIME EXTENDED +%d" % checkpoint_bonus, 2.0, Callouts.Kind.NONE)
			callouts.push(Callouts.Kind.CHECKPOINT)
			callouts.push(Callouts.Kind.TIME_EXTENDED, "+%d SEC" % checkpoint_bonus)
			checkpoint_bonus = Settings.race_time(clock[next_checkpoint + 1]) if next_checkpoint + 1 < clock.size() else 0.0
			_catch_up()
	if player.distance >= finish_distance:
		state = State.FINISHED
		finish_age = 0.0
		if online != null:
			online.finish(race_time)
		player.nitro_time = 0.0  # it brakes from here (see FINISH_BRAKING)
		fx.celebrate(FxLayer.fireworks_for(track.theme))
		player_finish = race_time
		place = rivals.place(player, player_finish)
		score.finish(place, not rivals.cars.is_empty())
		var before_furthest := SaveData.furthest_stage
		var before_unlocks: Array = SaveData.unlocks.duplicate()
		new_best_time = record_finish()
		record_stats(true)
		if time_attack:
			_save_ghost()
		var mins := int(race_time) / 60
		var secs := fmod(race_time, 60.0)
		var prompt := "Enter: menu   R: race again"
		after = After.MENU
		if online != null:
			prompt = "Enter: results"
		elif tour:
			prompt = _tour_finish()
		elif time_attack:
			var against := "" if ghost == null else split_text(race_time - ghost.time) + " vs best   "
			prompt = ("NEW BEST!   " if new_best else "") + against + prompt
		if _saves() and Unlocks.earns_secret(stage_index, touched_traffic, not traffic.cars.is_empty()):
			SaveData.unlock(Unlocks.SECRET_CAR)
		if _saves() and Unlocks.earns_mirror(place, not rivals.cars.is_empty()):
			SaveData.unlock(Unlocks.mirror_id(stage_index))
		new_unlocks = Unlocks.newly_open(before_furthest, before_unlocks, SaveData.furthest_stage, SaveData.unlocks)
		if SaveData.is_unlocked(Unlocks.mirror_id(stage_index)) and not before_unlocks.has(Unlocks.mirror_id(stage_index)):
			new_unlocks.append(Unlocks.mirror_id(stage_index))
		var placed := "%s of %d   " % [Rivals.ordinal(place), rivals.cars.size() + 1] if not rivals.cars.is_empty() else ""
		_banner("FINISH!", "%sTime %d:%05.2f   %s" % [placed, mins, secs, prompt], Callouts.HOLD, Callouts.Kind.NONE)
		callouts.finish(banner, banner_sub, place == 1 and not rivals.cars.is_empty())


## A tour stage finished: points, then on, another go, or the end of the tour. Returns the
## banner's prompt.
func _tour_finish() -> String:
	var with_rivals := not rivals.cars.is_empty()
	if with_rivals and not Tour.advances(place):
		return "Top %d go through.   %s" % [Tour.ADVANCE, _setback_prompt()]
	var order: Array = []
	for car: PlayerCar in rivals.standings(player, player_finish):
		order.append(Tour.YOU if car == player else (car as RivalCar).profile.driver)
	tour_state.award(order, score.total() - (Scoring.place_points(place) if with_rivals else 0))
	tour_state.stages_won += 1
	var next := Stages.next(stage_index)
	if next >= 0:
		tour_state.carried = Tour.carry(time_left, Settings.carry_time)
		after = After.NEXT_STAGE
		return "Enter: on to %s" % Stages.stage_name(next)
	tour_state.complete = true
	after = After.TOUR_DONE
	if not tour_state.full():
		return "Tour complete! Start from stage 1 for the Zenith.   Enter: menu"
	if _saves():
		SaveData.unlock(Tour.FINISH_UNLOCK)
		SaveData.total_points += int(tour_state.points.get(Tour.YOU, 0))
		SaveData.save()
	return "Tour complete!   Enter: menu"


## Saves the finish (SaveData): best time for this stage and car, and the tour's progress
## when the tour goes on from it.
## Autodriven runs and partway starts (dev flags) aren't the player's, so they aren't saved.
## Returns true for a new best time.
func record_finish() -> bool:
	if not _saves():
		return false
	var placed := not rivals.cars.is_empty()
	var goes_on := tour and (not placed or Tour.advances(place))
	return SaveData.record_finish(stage_index, car_id, race_time, place if placed else 0, goes_on)


## Adds this run to the stats page's counters (SaveData.record_run, MP-11), once: `counted`
## at a finish or TIME UP; a run left partway (restarted, quit, Free Drive) adds only its
## miles, crashes and near misses. Not for runs that aren't the player's (_saves).
func record_stats(counted: bool) -> void:
	if stats_recorded or player == null or not _saves():
		return
	var driven := maxf(0.0, player.distance - _start_distance)
	if not counted and driven <= 0.0:
		return  # never left the grid
	stats_recorded = true
	var won := counted and state == State.FINISHED and place == 1 and not rivals.cars.is_empty()
	SaveData.record_run(stage_index, car_id, counted, won, score.crashes, near_misses(score), Settings.miles(driven))


## The near misses in a stage's bonuses.
static func near_misses(s: Scoring) -> int:
	var n := 0
	for b in s.bonuses:
		n += int(b["name"] == "NEAR MISS")
	return n


## Time Attack: this run becomes the ghost when it beats the saved one.
func _save_ghost() -> void:
	if not _saves() or not Ghost.beats(race_time, ghost):
		return
	recording.time = race_time
	new_best = recording.save()


## Seconds against a best: "-1.23" ahead, "+0.50" behind.
static func split_text(seconds: float) -> String:
	return ("-" if seconds < 0.0 else "+") + "%.2f" % absf(seconds)


## A stage's clock on ARCADE: seconds to start with, then the bonus at each of its
## `checkpoints`. From the theme's "clock", filled out with the defaults.
static func stage_clock(theme: Dictionary, checkpoints: int) -> Array[float]:
	var out: Array[float] = []
	var given: Array = theme.get("clock", [])
	for i in checkpoints + 1:
		out.append(float(given[i]) if i < given.size() else (START_TIME if i == 0 else CHECKPOINT_BONUS))
	return out


## Whether the clock runs down to TIME UP (not in Time Attack, Free Drive or online).
func timed() -> bool:
	return not time_attack and not free_drive and online == null


## Online after the finish (ON-10): who to watch among `cars` (the rivals), the player out in
## front of those still racing; null with none left.
static func watch_target(cars: Array) -> RivalCar:
	var best: RivalCar = null
	for r: RivalCar in cars:
		if r.remote and not r.finished and r.fade >= 1.0 and (best == null or r.distance > best.distance):
			best = r
	return best


## Points the camera at `target` (null: the player's own car) and returns the car it follows:
## the renderer draws it where the player's car goes, and the rest as rivals.
func follow(target: RivalCar) -> PlayerCar:
	watching = target
	if target == null:
		if road.player != player:
			road.player = player
			road.player_strips = _own_strips
			road.rivals = rivals.cars
		return player
	road.player = target
	road.player_strips = target.strips
	var others: Array[RivalCar] = []
	for r: RivalCar in rivals.cars:
		if r != target:
			others.append(r)
	road.rivals = others
	return target


## The results online (ON-9): the host picks the next stage with up and down.
func online_results_input(m: MenuInput) -> void:
	if not online.hosting() or online.phase != OnlineSession.Phase.RACING or m.step_y() == 0:
		return
	var next := OnlineScreen.next_stage(online.stage, m.step_y())
	online.choose(next, online.mirror and Unlocks.mirror_unlocked(next))
	Audio.play("tick")


## The results' first button online (ON-9): READY for the next race (again to take it back);
## the host, once ready, starts it without waiting for the rest. With the room gone, back to
## the online screen, which says why.
func online_continue() -> void:
	if online.phase == OnlineSession.Phase.CLOSED:
		after_race()
	elif online.hosting() and online.is_ready_again():
		online.start()
	else:
		online.ready_again(not online.is_ready_again())


## Everyone on the road who can be touched or drafted: the player and the rivals, less a player
## fading out (ON-11).
func solid_cars() -> Array:
	return rivals.everyone(player).filter(func(c: PlayerCar) -> bool: return not (c is RivalCar and (c as RivalCar).fade < 1.0))


## Online (ON-3): the other players where their games last said, moved on since; their
## finishes; those who dropped out faded off the road (ON-11); this car sent on. The room
## going (the host left, or the line) ends the race with the results so far.
func _online_tick(dt: float) -> void:
	notice_time = maxf(0.0, notice_time - dt)
	var closed := online.phase == OnlineSession.Phase.CLOSED
	if closed:
		if not cut_short:
			end_cut_short()
		return
	for r: RivalCar in rivals.cars.duplicate():
		if not r.remote:
			continue
		if online.gone.has(r.slot):
			_fade_out(r, dt)
			continue
		if online.cars.has(r.slot):
			var got: Array = online.cars[r.slot]
			_shown[r.slot] = OnlineSession.shown_at(got[0], got[1], _shown[r.slot], dt)
			CarState.apply(r, got[0], _shown[r.slot], track)
		if not r.finished and online.finishes.has(r.slot):
			r.finished = true
			r.finish_time = online.finishes[r.slot]
	if state != State.COUNTDOWN:
		online.send_car(player)


## Autodrives from here on, as --autodrive does (a rematch online, whose race didn't read the
## dev flags: game.start_online_race).
func drive_itself() -> void:
	_autodrive = true
	_log_banners = true


## A player who dropped out (ON-11): a notice, then their car runs on at its last speed as it
## fades, and goes (one already over the line stays in the standings, unseen).
func _fade_out(r: RivalCar, dt: float) -> void:
	if r.fade >= 1.0:
		show_notice("%s DROPPED OUT" % OnlineSession.player_name(r.slot))
	r.fade = maxf(0.0, r.fade - dt / FADE_TIME)
	r.distance += r.speed * dt
	r.position = fposmod(r.distance, track.length)
	if r.fade <= 0.0 and not r.finished:
		rivals.cars.erase(r)
		_shown.erase(r.slot)


## Online (ON-11): a line about the room for NOTICE_TIME (the HUD's, under the route bar).
func show_notice(text: String) -> void:
	notice = text
	notice_time = NOTICE_TIME


## The room went mid-race (ON-11): the race ends where everyone is, the others held where they
## were last seen, and the results so far come up (BACK leads to the online screen, which
## says why). Over the line already, the results come now rather than after the others.
func end_cut_short() -> void:
	cut_short = true
	show_notice(online.error)
	for r: RivalCar in rivals.cars:
		if r.remote:
			r.speed = 0.0
	if state == State.COUNTDOWN or state == State.RACING:
		_banner(online.error, "The results so far", CUT_SHORT_RESULTS)
		state = State.FINISHED
		finish_age = maxf(0.0, RESULTS_AFTER - CUT_SHORT_RESULTS)
		player.nitro_time = 0.0
		after = After.MENU
		place = rivals.place(player, player_finish)


## Whether this race is the player's own, to save from: not autodriven, not started partway
## or with a made-up clock, not staged for a screenshot.
func _saves() -> bool:
	return not _autodrive and not demo and _start_segment == 0 and not _staged and is_nan(_time_left_shot) and online == null


## Whether this race shows the instant replay at its finish (RC-17).
func replay_offered() -> bool:
	return instant_replay and not demo and online == null and not free_drive


## The instant replay starts (RC-17): stand-in cars for the field, put where the trace's frames
## say tick by tick; the real ones and the traffic wait where the finish left them.
func start_replay() -> void:
	replay_frames = Replay.build(replay_trace.frames)
	replay_index = 0
	replaying = true
	_replay_skip = false
	replay_player = PlayerCar.new()
	replay_rivals.clear()
	for i in rivals.cars.size():
		var r := RivalCar.remote_player(Cars.find(rivals.cars[i].car_id), i + 1)
		r.profile = rivals.cars[i].profile
		replay_rivals.append(r)
	var keep := Replay.new()
	keep.record([], traffic.cars)
	_traffic_before = keep.frames[0]
	road.player = replay_player
	road.rivals = replay_rivals
	road.ghost_strips = {}
	fx.clear()
	_show_replay_frame()


## Puts the next frame of the replay on the road.
func _show_replay_frame() -> void:
	var cars: Array = [replay_player]
	cars.append_array(replay_rivals)
	Replay.apply(replay_frames[replay_index], cars, traffic.cars, track)
	replay_index += 1
	road.camera_z = replay_player.position


## A tick of the replay: the next frame, until the finish frame has shown or a button skips it.
func _replay_tick(dt: float, inp: DriveInput) -> void:
	if _replay_skip or Replay.skips(inp, InputRouter.menu) or replay_index >= replay_frames.size():
		end_replay()
	else:
		_show_replay_frame()
		road.time += dt
	_redraw()
	_frame += 1
	if _screenshot_frames.has(_frame):
		_save_screenshot(_frame)


## The replay is over (or skipped): the field back as the finish left it, then the results.
func end_replay() -> void:
	replaying = false
	_replay_done = true
	Replay.apply(_traffic_before, [], traffic.cars, track)
	road.player = player
	road.rivals = rivals.cars
	road.ghost_strips = road.player_strips if ghost != null else {}
	road.camera_z = player.position
	_show_results()


func _show_results() -> void:
	_results_shown = true
	results_age = 0.0
	results.open()


## Stage flow (StageFlow), display only: the sky and fog turn to the next stage's as the car
## runs into its end, and the results fade the rest of the way when the tour goes on to it.
func _flow(dt: float) -> void:
	if results_age >= 0.0:
		results_age += dt
	var age := results_age if after == After.NEXT_STAGE else -1.0
	var here := track.find_segment(player.position + Cfg.PLAYER_Z)
	var k := StageFlow.share(here.handover, age) if road.flow else 0.0
	road.flow_share = k
	road.flow_fade = StageFlow.crossfade(age) if road.flow else 0.0
	background.share = k
	results.flow_share = k


## How fast the world runs `age` seconds after the finish line: FINISH_SLOWMO for a moment,
## then easing back to full speed.
static func finish_time_scale(age: float) -> float:
	if age < FINISH_SLOWMO_HOLD:
		return FINISH_SLOWMO
	return lerpf(FINISH_SLOWMO, 1.0, clampf((age - FINISH_SLOWMO_HOLD) / FINISH_SLOWMO_EASE, 0.0, 1.0))


## The race's last banner (banner, banner_sub: what the tests and golden traces read), and
## the callout it shows as: a starburst `kind`, a plain message, or NONE when the caller
## pushes its own.
func _banner(text: String, sub: String, seconds: float, kind := Callouts.Kind.MESSAGE) -> void:
	banner = text
	banner_sub = sub
	banner_time = seconds
	if kind == Callouts.Kind.MESSAGE:
		callouts.push_message(text, sub, seconds)
	else:
		callouts.push(kind, sub, seconds)
	if _log_banners:
		print("[autodrive] %.1fs  %s  %s" % [race_time, text, sub])


## The callouts that come from a racing tick rather than a banner: NEAR MISS and BIG AIR
## as they're scored (the bonuses past `earned`), FINAL STRETCH once, and 1ST PLACE on
## taking the lead (not more often than Callouts.LEAD_GAP).
func _callouts_after_tick(earned: int, place_before: int) -> void:
	for i in range(earned, score.bonuses.size()):
		var b: Dictionary = score.bonuses[i]
		callouts.push(Callouts.for_bonus(b["name"]), "", Callouts.SHOW_TIME, b.get("chain", 0))
	if state != State.RACING:
		return  # (the finish has its own)
	if not _final_stretch and not free_drive and Callouts.in_final_stretch(player.distance, finish_distance):
		_final_stretch = true
		callouts.push(Callouts.Kind.FINAL_STRETCH)
	if place == 1 and place_before > 1 and not rivals.cars.is_empty() and race_time - _led_at >= Callouts.LEAD_GAP:
		_led_at = race_time
		callouts.push(Callouts.Kind.FIRST_PLACE)


func _redraw() -> void:
	road.queue_redraw()
	fx.queue_redraw()
	background.queue_redraw()
	hud.queue_redraw()


# --- Dev helpers: `godot -- --autodrive --screenshots=60,300 --shot-dir=/tmp/shots` -------

func _parse_dev_args() -> void:
	Tuning.boot(DevArgs.value("--tuning-file", Tuning.PATH))  # (the game has, unless this is race.tscn on its own)
	for arg in OS.get_cmdline_user_args():
		if arg == "--autodrive":
			_autodrive = true
			_log_banners = true
		elif arg.begins_with("--stage="):
			stage_index = clampi(int(arg.get_slice("=", 1)) - 1, 0, Stages.count() - 1)
		elif arg == "--mirror":
			mirror = true
		elif arg.begins_with("--car="):
			car_id = Cars.find(arg.get_slice("=", 1))["id"]
		elif arg.begins_with("--at-segment="):
			_start_segment = int(arg.get_slice("=", 1))
		elif arg.begins_with("--drive-x="):
			_drive_x = float(arg.get_slice("=", 1))
		elif arg.begins_with("--lightning-at="):
			_lightning_at = float(arg.get_slice("=", 1))
		elif arg == "--no-traffic":
			_no_traffic = true
		elif arg == "--screen=results":
			_results_shot = true
		elif arg == "--no-rivals":
			_no_rivals = true
		elif arg.begins_with("--screenshots="):
			for f in arg.get_slice("=", 1).split(","):
				_screenshot_frames.append(int(f))
		elif arg.begins_with("--callout="):  # ID, or ID:COUNT for a count (near_miss:3)
			var spec := arg.get_slice("=", 1)
			_callout_shot = Callouts.IDS.get(spec.get_slice(":", 0), Callouts.Kind.NONE)
			_callout_shot_count = int(spec.get_slice(":", 1)) if spec.contains(":") else 0
		elif arg.begins_with("--pickup="):
			_pickup_shot = PowerUps.IDS.find(arg.get_slice("=", 1))
		elif arg.begins_with("--time-left="):
			_time_left_shot = float(arg.get_slice("=", 1))
		elif arg.begins_with("--photo-at="):
			for f in arg.get_slice("=", 1).split(","):
				_photo_frames.append(int(f))
		elif arg.begins_with("--shot-dir="):
			_screenshot_dir = arg.get_slice("=", 1)
			Photo.dir = _screenshot_dir


func _autodrive_input() -> DriveInput:
	var inp := DriveInput.new()
	var seg := track.find_segment(player.position + Cfg.PLAYER_Z + 3000.0)
	inp.throttle = 0.0 if state == State.COUNTDOWN and countdown > 0.1 else 1.0
	var lane := _drive_x if not is_nan(_drive_x) else _autodrive_lane()
	inp.steer = clampf((seg.curve * 0.25) + (lane - player.x) * 1.5, -1.0, 1.0)
	# A dab of brake with the lock on throws it into a power slide through a hard bend (RC-8)
	if autodrive_slides(seg.curve, inp.steer, player):
		inp.brake = 1.0
	inp.nitro_pressed = _frame % 600 == 300
	inp.shift_up_pressed = player.on_limiter()
	inp.shift_down_pressed = player.manual and player.gear > 1 and player.speed < PlayerCar.gear_limit(player.gear - 1) * 0.8
	return inp


## Whether the autodrive brakes into a power slide: a hard bend ahead (Track.CURVE_HARD), the
## lock on for it and the speed for a slide, on the road and not sliding already (the brake
## would only brake).
static func autodrive_slides(curve_ahead: float, steer: float, car: PlayerCar) -> bool:
	return car.slide == 0.0 and not car.airborne and not car.offroad and absf(curve_ahead) >= Track.CURVE_HARD \
		and absf(steer) >= Tuning.v("slide/steer") and car.speed >= Cfg.MAX_SPEED * Tuning.v("slide/speed")


## The lane with the most open road ahead, keeping the current one on a tie. Anything slower
## than cruising speed blocks a lane, so a slowed car doesn't sit behind a tractor.
func _autodrive_lane() -> float:
	const LOOKAHEAD := 40  # segments
	var want := maxf(player.speed, Cfg.MAX_SPEED * 0.8)
	var here := track.find_segment(player.position + Cfg.PLAYER_Z).index
	var lanes: Array = Traffic.lanes(track, track.narrowest_ahead(player.position + Cfg.PLAYER_Z))
	var best: float = lanes[0]
	var best_gap := -1
	lanes.sort_custom(func(a: float, b: float) -> bool: return absf(a - player.x) < absf(b - player.x))
	for lane: float in lanes:
		var gap := LOOKAHEAD
		for r in rivals.cars:
			var ahead := wrapf(r.position - player.position, -track.length * 0.5, track.length * 0.5)
			if ahead > 0.0 and absf(r.x - lane) < 0.3 and r.speed < want:
				gap = mini(gap, int(ahead / Cfg.SEGMENT_LENGTH))
		for n in gap:
			var ahead := track.segments[(here + n) % track.segments.size()]
			var blocked := false
			for car in ahead.cars:
				if absf(car.offset - lane) < 0.3 and car.speed < want:
					blocked = true
			if blocked:
				gap = n
				break
		if gap > best_gap:
			best_gap = gap
			best = lane
	return best


## --screen=results: a rival over the line ahead, the player second, the rest still out.
func _stage_results_shot() -> void:
	_results_shot = false
	_staged = true
	race_time = 62.48
	rivals.clock = race_time
	for i in rivals.cars.size():
		var r: RivalCar = rivals.cars[i]
		if i < 1:
			r.distance = finish_distance + 900.0
			r.finished = true
			r.finish_time = 61.12
		else:
			r.distance = finish_distance - 2500.0 * i
	player.distance = finish_distance + 1.0
	_check_progress()


func _save_screenshot(frame: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if DevArgs.has("--shot-as-window"):
		img = DevArgs.as_window(img, get_window())
	var dir := _screenshot_dir if _screenshot_dir != "" else "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/frame_%05d.png" % [dir, frame])
