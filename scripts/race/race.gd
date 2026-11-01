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
var ghost: Ghost  # Time Attack: the best run so far, replayed (null before the first)
var recording: Ghost  # Time Attack: this run, tick by tick
var ghost_now := Vector3.ZERO  # the ghost this tick: distance, x, steer (Ghost.at)
var split := NAN  # Time Attack: seconds against the ghost at the last checkpoint (minus is ahead)
var new_best := false  # Time Attack: this finish beat the ghost and replaced it
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
var horn := false  # the horn button held this tick (RaceAudio sounds it; play ignores it)
var ram_flash := 0.0  # seconds left on the ram plate's impact flash
var traffic: Traffic
var rivals := Rivals.new()
var state := State.COUNTDOWN
var countdown := 3.0
var time_left := START_TIME
var race_time := 0.0
var finish_age := 0.0  # seconds since the finish line (real time, not slowed)
var _results_shown := false  # the results have come up for this finish (closed again or not)
var results_age := -1.0  # seconds since the results came up, -1 before (StageFlow.crossfade)
var launch: Launch.Grade = Launch.Grade.PENDING  # how the player's start went
var score := Scoring.new()
var place := 1  # the player's place in the field (Rivals.standings)
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
var results: ResultsScreen  # after the finish (RC-5)
var new_best_time := false  # this finish set the best time for the stage and car
var best_before := {}  # SaveData.best for the stage and car before this finish

var background: Background
var road: RoadRenderer
var fx: FxLayer  # between the road and the HUD
var hud: Hud
## The F1 input overlay and F2 calibration wizard. The game passes in its own, so there is one
## pair across the menus and the race; a race run on its own (tests, race.tscn) makes a pair.
var debug_overlay: InputDebugOverlay
var calibration: CalibrationWizard
var audio: RaceAudio

var _shake := 0.0  # camera shake as designed, in pixels; the screen shake option scales what shows
var _fov_stretch := 0.0  # 0..Cfg.NITRO_FOV_STRETCH, eased while nitro burns
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
var _screenshot_dir := ""
var _gas_since := NAN  # when the gas went down, in seconds from GO (Launch.grade)
var _frame := 0  # physics ticks since this race (re)started
var _final_stretch := false  # FINAL STRETCH has come up this race
var _led_at := -INF  # race time of the last 1ST PLACE callout
var _callout_shot := Callouts.Kind.NONE  # --callout=ID: that starburst held up after GO (screenshots)
var _time_left_shot := NAN  # --time-left=S: start with this much on the clock (low-time screenshots)
## The dev flags are for the race the game starts with; later races come from the menus.
static var _dev_args_read := false


func _ready() -> void:
	SpriteLibrary.load_all()
	background = Background.new()
	add_child(background)
	road = RoadRenderer.new()
	add_child(road)
	fx = FxLayer.new()
	add_child(fx)
	var layer := CanvasLayer.new()
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
	audio = RaceAudio.new(self)
	add_child(audio)
	if not InputRouter.driver_unplugged.is_connected(driver_unplugged):
		InputRouter.driver_unplugged.connect(driver_unplugged)
		InputRouter.driver_replugged.connect(driver_replugged)
	if not _dev_args_read:
		_dev_args_read = true
		_parse_dev_args()
	Touch.race = self
	start_race()


func start_race() -> void:
	InputRouter.speed_factor = 0.0
	_frame = 0
	track = Stages.build(stage_index, mirror)
	player = PlayerCar.new()
	var car := Cars.find(car_id)
	player.setup(car)
	player.manual = Settings.manual_gears and not demo  # the attract demo shows the automatic
	CarSprites.load_all()
	player.reset(_start_segment * Cfg.SEGMENT_LENGTH)
	player.distance = _start_segment * Cfg.SEGMENT_LENGTH  # that far along the route, so the finish is where it is drawn
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
	traffic.spawn(track, traffic_count)
	if tour and tour_state == null:
		tour_state = Tour.new()
		tour_state.start_stage = stage_index
	rivals = Rivals.new()
	rivals.spawn(track, player, car_id, 0 if _no_rivals or time_attack or free_drive or online != null else Rivals.COUNT,
		Rivals.SEED + stage_index, Difficulty.of(Settings.difficulty), tour_state.drivers if tour else [])
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
	countdown = 0.0 if demo else 3.0
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
	road.rivals = rivals.cars
	road.ghost_strips = road.player_strips if ghost != null else {}
	fx.clear()
	fx.set_weather(track.theme, _lightning_at)
	fx.player = player


## Pad steering's speed sensitivity is the race's to set; the menus get it back at rest.
func _exit_tree() -> void:
	InputRouter.speed_factor = 0.0


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
	pause_menu.has_options = not options_requested.get_connections().is_empty()
	pause_menu.open()


func resume() -> void:
	paused = false
	pause_menu.close()
	unplugged = ""  # resumed without it (the keyboard, or a restart): no waiting for it
	_unplug_paused = false
	pause_menu.notice = []


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


## It's back (InputRouter.driver_replugged), with the same profile: the race carries on if
## the unplugging paused it and the pause menu is still up (not the options over it).
func driver_replugged(guid: String) -> void:
	if guid != unplugged:
		return
	if _unplug_paused and paused and pause_menu.visible:
		resume()
	else:
		unplugged = ""
		pause_menu.notice = []


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


## A demo is done: it reached the finish, ran out of time or ran its length.
func demo_over() -> bool:
	return state == State.FINISHED or state == State.TIME_UP or race_time >= Attract.DEMO_SECONDS


func counting_down() -> bool:
	return state == State.COUNTDOWN


## Whether the touch controls (TouchControls) show the driving layout: the race is on screen,
## not under the pause menu, the results or the calibration wizard.
func touch_driving() -> bool:
	return not demo and not paused and not results.visible and not calibration.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_input"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("calibrate") and not calibration.visible:
		calibration.open()


func _physics_process(dt: float) -> void:
	var inp: DriveInput = Settings.drive_input(InputRouter.state)
	if _autodrive or demo:
		inp = _autodrive_input()
	else:
		inp = Assists.apply(inp, player, track, Settings.steer_assist, Settings.brake_assist)
	horn = inp.horn
	if calibration.visible:
		_redraw()
		return
	if paused:
		if pause_menu.visible:  # (hidden while the options are up)
			pause_action(pause_menu.choose(InputRouter.menu, inp.pause_pressed))
		if online == null or not paused:
			_redraw()
			return
		inp = DriveInput.new()  # online the race runs on under the menu, the car coasting
	if results.visible:
		if inp.restart_pressed and online == null:  # R: in a tour, on as ever; otherwise the stage again
			if tour:
				after_race()
			else:
				start_race()
			return
		match results.choose(InputRouter.menu, inp.confirm_pressed):
			ResultsScreen.Choice.CONTINUE:
				after_race()
				return
			ResultsScreen.Choice.RETRY:
				start_race()
				return
			ResultsScreen.Choice.QUIT:
				quit_requested.emit()
				return
	var over := state == State.TIME_UP or state == State.FINISHED
	if state == State.FINISHED and not _results_shown and (inp.confirm_pressed or finish_age >= RESULTS_AFTER or _staged):
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

	banner_time = maxf(0.0, banner_time - dt)
	_watch_launch(inp)
	match state:
		State.COUNTDOWN:
			if online == null or online.go:  # online, the countdown runs from the host's GO
				countdown -= dt
			if countdown <= Launch.ROLL_TIME:
				for car: PlayerCar in rivals.everyone(player):
					car.speed = Launch.ROLL_SPEED
			if countdown <= 0.0:
				state = State.RACING
				_banner("GO!", "", 1.0, Callouts.Kind.GO)
				if _callout_shot != Callouts.Kind.NONE:
					callouts.push(_callout_shot, "", Callouts.HOLD)
				race_time += dt  # the cars drive on the GO tick, and the rivals' clock counts it
		State.RACING:
			race_time += dt
			if timed():
				time_left -= dt
			if time_left <= 0.0 and timed():
				time_left = 0.0
				state = State.TIME_UP
				_banner("TIME UP", _setback_prompt() if tour else "Press R or Enter to try again", Callouts.HOLD)

	# Past the line the world drops into slow motion for a moment (sim, the world's tick), and
	# the car brakes itself to a stop
	var sim := dt
	if state == State.FINISHED:
		finish_age += dt
		sim = dt * finish_time_scale(finish_age)

	InputRouter.speed_factor = player.speed_percent()
	var seg_before := track.find_segment(player.position + Cfg.PLAYER_Z)
	Draft.update(player, sim, state == State.RACING and Draft.in_wake(player, track, rivals.everyone(player)))
	player.update(sim, inp, track, state == State.RACING)
	traffic.update(sim, track)
	rivals.update(sim, track, player, state != State.COUNTDOWN, finish_distance)
	if online != null:
		_online_tick(sim)
	player.collide(track)
	if state == State.FINISHED:
		player.speed = move_toward(player.speed, 0.0, FINISH_BRAKING * sim)
		player.braking = player.speed > 0.0
	touched_traffic = touched_traffic or player.hit_traffic
	Rivals.resolve_contacts(rivals.everyone(player), track)
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
		_check_progress()
		_callouts_after_tick(earned, place_before)
	if demo and demo_over():
		quit_requested.emit()
		return
	if ghost != null:
		ghost_now = Ghost.sided(ghost.at(recording.count() - 1), track.side())
		road.ghost = ghost_now

	background.offset += seg_before.curve * (player.speed * sim / Cfg.SEGMENT_LENGTH) * BACKGROUND_SCROLL

	# Camera shake: rough ground, crests, landings, crashes. Display only (road.position).
	_shake = shake_after(_shake, player, player.airborne and not _was_airborne, dt)
	_was_airborne = player.airborne
	var shown := Settings.shake_amount(_shake)
	road.position = Vector2(roundf(randf_range(-1, 1) * shown), roundf(randf_range(-1, 1) * shown))
	# Nitro widens the view a little (display only: the renderer's camera depth)
	var stretch_to := Cfg.NITRO_FOV_STRETCH if player.nitro_time > 0.0 else 0.0
	_fov_stretch = move_toward(_fov_stretch, stretch_to, dt * Cfg.NITRO_FOV_RATE)
	road.camera_depth = camera_depth(_fov_stretch)
	road.flash = Settings.flash_amount(1.0)
	road.time += sim
	fx.flash_share = road.flash
	fx.update(sim, player, track)
	fx.position = road.position
	road.camera_z = player.position
	var rise := track.height_at(player.position + Background.HILL_AHEAD) - player.road_y
	background.hill = Background.hill_shift(rise, road.camera_depth)
	_flow(dt)
	if _results_shot and state == State.RACING and race_time > 1.0:
		_stage_results_shot()
	_redraw()
	_frame += 1
	if _screenshot_frames.has(_frame):
		_save_screenshot(_frame)


## Camera shake (pixels, as designed) after a tick: a crash sets it, a landing, a takeoff
## over a crest and rough ground at speed kick it up, and it settles back to still.
static func shake_after(shake: float, p: PlayerCar, took_off: bool, dt: float) -> float:
	if p.crashed:
		shake = Cfg.SHAKE_CRASH
	elif p.landed:
		shake = maxf(shake, Cfg.SHAKE_LANDING)
	elif took_off:
		shake = maxf(shake, Cfg.SHAKE_TAKEOFF)
	elif p.offroad and p.speed > 100.0:
		shake = maxf(shake, Cfg.SHAKE_OFFROAD * p.speed_percent())
	return move_toward(shake, 0.0, dt * Cfg.SHAKE_SETTLE)


## The renderer's camera depth for a nitro stretch (0..Cfg.NITRO_FOV_STRETCH), after the
## screen shake option: Cfg.CAMERA_DEPTH with no stretch or with the option at 0.
static func camera_depth(stretch: float) -> float:
	return Cfg.CAMERA_DEPTH * (1.0 - Settings.shake_amount(stretch))


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
	picked_up = true
	pickup = p.kind
	pickup_gave = power_ups.open(p.kind, time_left)
	pickup_age = 0.0
	match pickup_gave:
		PowerUps.Kind.NITRO:
			player.nitro_charges = mini(player.nitro_max, player.nitro_charges + 1)
			_banner("NITRO +1", "", 1.2)
		PowerUps.Kind.CLOCK:
			time_left += PowerUps.CLOCK_BONUS
			_banner("+%d SEC" % PowerUps.CLOCK_BONUS, "", 1.2)
		PowerUps.Kind.RAM:
			player.ram_time = PowerUps.RAM_TIME
			_banner("RAM PLATE", "Traffic goes flying", 1.2)
		PowerUps.Kind.GHOST:
			player.ghost_time = PowerUps.GHOST_TIME
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
		if time_attack:
			_save_ghost()
		var mins := int(race_time) / 60
		var secs := fmod(race_time, 60.0)
		var prompt := "Enter: menu   R: race again"
		after = After.MENU
		if online != null:
			prompt = "Enter: back to the lobby"
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
		if place == 1 and not rivals.cars.is_empty():
			callouts.push(Callouts.Kind.FIRST_PLACE)
		_banner("FINISH!", "%sTime %d:%05.2f   %s" % [placed, mins, secs, prompt], Callouts.HOLD)


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


## Online (ON-3): the other players where their games last said, moved on since; their
## finishes; those who left taken off the road; this car sent on.
func _online_tick(dt: float) -> void:
	var closed := online.phase == OnlineSession.Phase.CLOSED  # the host left, or the line went
	if closed and not _shown.is_empty():
		_banner(online.error, "Racing on alone", 2.0)
	for r: RivalCar in rivals.cars.duplicate():
		if not r.remote:
			continue
		if closed:
			rivals.cars.erase(r)
			_shown.erase(r.slot)
			continue
		if online.gone.has(r.slot):
			rivals.cars.erase(r)
			_shown.erase(r.slot)
			if state == State.RACING:
				_banner("%s LEFT" % OnlineSession.player_name(r.slot), "", 1.5)
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


## Whether this race is the player's own, to save from: not autodriven, not started partway
## or with a made-up clock, not staged for a screenshot.
func _saves() -> bool:
	return not _autodrive and not demo and _start_segment == 0 and not _staged and is_nan(_time_left_shot) and online == null


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
		callouts.push(Callouts.for_bonus(score.bonuses[i]["name"]))
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
		elif arg.begins_with("--callout="):
			_callout_shot = Callouts.IDS.get(arg.get_slice("=", 1), Callouts.Kind.NONE)
		elif arg.begins_with("--time-left="):
			_time_left_shot = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-dir="):
			_screenshot_dir = arg.get_slice("=", 1)


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
		and absf(steer) >= Cfg.SLIDE_STEER and car.speed >= Cfg.SLIDE_SPEED


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
