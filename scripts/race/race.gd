extends Node2D
## Race scene: owns the track, player, traffic, timer and checkpoints, and feeds the renderers.
## The game (game.gd) starts it from the menus; quit_requested asks to go back to them.

signal quit_requested
## A Single Race is over and the player confirmed the finish: back to the menus.
signal race_over
## OPTIONS on the pause menu: the game shows the options, then calls options_closed.
signal options_requested

enum State { COUNTDOWN, RACING, FINISHED, TIME_UP }

const START_TIME := 45.0  # on the ARCADE timer; Settings scales both for the others
const CHECKPOINT_BONUS := 25.0
const BACKGROUND_SCROLL := 0.0006  # per segment travelled, per unit of curve
const TRAFFIC_COUNT := 70  # a stage theme can ask for more ("traffic")
# Camera shake, in screen pixels, and how fast it settles (pixels per second)
const SHAKE_CRASH := 5.0
const SHAKE_LANDING := 3.0
const SHAKE_OFFROAD := 1.5  # at top speed
const SHAKE_SETTLE := 12.0

var track: Track
var stage_index := 0  # into Stages
var tour := true  # Grand Tour: a finish goes on to the next stage. false: a Single Race
## Time Attack: solo against the clock and the best run's ghost; no rivals, no time limit.
var time_attack := false
## Free Drive: no clock, no rivals, no finish; the road loops on until you quit (pause menu).
var free_drive := false
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
var ram_flash := 0.0  # seconds left on the ram plate's impact flash
var traffic: Traffic
var rivals := Rivals.new()
var state := State.COUNTDOWN
var countdown := 3.0
var time_left := START_TIME
var race_time := 0.0
var launch: Launch.Grade = Launch.Grade.PENDING  # how the player's start went
var score := Scoring.new()
var place := 1  # the player's place in the field (Rivals.standings)
var player_finish := -1.0  # race time the player finished in, -1 still racing
var touched_traffic := false  # the player has touched a traffic car this stage (Unlocks secret)
var new_unlocks: Array[String] = []  # car ids this finish opened, for the HUD
var finish_distance := 1.0
var checkpoint_bonus := CHECKPOINT_BONUS  # after the timer option
var checkpoint_distances: Array[float] = []
var next_checkpoint := 0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var paused := false
var pause_menu: PauseMenu

var background: Background
var road: RoadRenderer
var hud: Hud
## The F1 input overlay and F2 calibration wizard. The game passes in its own, so there is one
## pair across the menus and the race; a race run on its own (tests, race.tscn) makes a pair.
var debug_overlay: InputDebugOverlay
var calibration: CalibrationWizard
var audio: RaceAudio

var _shake := 0.0
var _autodrive := false
var _log_banners := false
var _no_traffic := false
var _no_rivals := false
var _start_segment := 0  # --at-segment=N: start the race this far in (screenshots)
var _screenshot_frames: Array[int] = []
var _screenshot_dir := ""
var _gas_since := NAN  # when the gas went down, in seconds from GO (Launch.grade)
var _frame := 0  # physics ticks since this race (re)started
## The dev flags are for the race the game starts with; later races come from the menus.
static var _dev_args_read := false


func _ready() -> void:
	SpriteLibrary.load_all()
	background = Background.new()
	add_child(background)
	road = RoadRenderer.new()
	add_child(road)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.race = self
	layer.add_child(hud)
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
	if not _dev_args_read:
		_dev_args_read = true
		_parse_dev_args()
	start_race()


func start_race() -> void:
	InputRouter.speed_factor = 0.0
	_frame = 0
	track = Stages.build(stage_index)
	player = PlayerCar.new()
	var car := Cars.find(car_id)
	player.setup(car)
	CarSprites.load_all()
	player.reset(_start_segment * Cfg.SEGMENT_LENGTH)
	player.road_y = track.height_at(player.position + Cfg.PLAYER_Z)
	power_ups = PowerUps.new()
	if Settings.power_ups:
		power_ups.place(track)
	pickup = -1
	pickup_gave = -1
	pickup_age = 99.0
	ram_flash = 0.0
	traffic = Traffic.new()
	var traffic_count := Settings.traffic_count(int(track.theme.get("traffic", TRAFFIC_COUNT)))
	if _no_traffic or ((time_attack or free_drive) and not Settings.attack_traffic):
		traffic_count = 0
	traffic.spawn(track, traffic_count)
	if tour and tour_state == null:
		tour_state = Tour.new()
	rivals = Rivals.new()
	rivals.spawn(track, player, car_id, 0 if _no_rivals or time_attack or free_drive else Rivals.COUNT, Rivals.SEED + stage_index,
		Difficulty.of(Settings.difficulty), tour_state.drivers if tour else [])
	if tour and tour_state.drivers.is_empty():
		tour_state.drivers = rivals.driver_names()
	state = State.COUNTDOWN
	countdown = 3.0
	time_left = Settings.race_time(START_TIME) + (tour_state.carried if tour else 0.0)
	after = After.RETRY
	checkpoint_bonus = Settings.race_time(CHECKPOINT_BONUS)
	race_time = 0.0
	player_finish = -1.0
	touched_traffic = false
	new_unlocks.clear()
	score = Scoring.new()
	launch = Launch.Grade.PENDING
	_gas_since = NAN
	place = rivals.place(player, player_finish)
	ghost = Ghost.load_best(stage_index, car_id) if time_attack else null
	recording = Ghost.make(stage_index, car_id) if time_attack else null
	ghost_now = Vector3.ZERO if ghost == null else ghost.at(0)
	road.ghost = ghost_now
	split = NAN
	new_best = false
	next_checkpoint = 0
	banner = ""
	resume()
	finish_distance = track.finish_index * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z
	checkpoint_distances.clear()
	for c in track.checkpoints:
		checkpoint_distances.append(c * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z)
	background.set_theme(track.theme)
	background.offset = 0.0
	road.track = track
	road.player = player
	road.player_strips = CarSprites.strips(car["strip"])
	road.rivals = rivals.cars
	road.ghost_strips = road.player_strips if ghost != null else {}


## Pad steering's speed sensitivity is the race's to set; the menus get it back at rest.
func _exit_tree() -> void:
	InputRouter.speed_factor = 0.0


## After a finish: on to the next stage, or back to the first after the last.
func continue_tour() -> void:
	stage_index = maxi(0, Stages.next(stage_index))
	start_race()


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


## Back from the options the pause menu opened: the menu again, still paused.
func options_closed() -> void:
	pause_menu.reopen()


## Carries out what the pause menu picked (PauseMenu.Action).
func pause_action(action: int) -> void:
	match action:
		PauseMenu.Action.RESUME:
			resume()
		PauseMenu.Action.RESTART:
			start_race()
		PauseMenu.Action.OPTIONS:
			pause_menu.close()
			options_requested.emit()
		PauseMenu.Action.QUIT:
			quit_requested.emit()


func counting_down() -> bool:
	return state == State.COUNTDOWN


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_input"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("calibrate") and not calibration.visible:
		calibration.open()


func _physics_process(dt: float) -> void:
	var inp: DriveInput = Settings.drive_input(InputRouter.state)
	if _autodrive:
		inp = _autodrive_input()
	if calibration.visible:
		_redraw()
		return
	if paused:
		if pause_menu.visible:  # (hidden while the options are up)
			pause_action(pause_menu.choose(InputRouter.menu, inp.pause_pressed))
		_redraw()
		return
	var over := state == State.TIME_UP or state == State.FINISHED
	if over and (inp.confirm_pressed or (inp.restart_pressed and tour)):
		after_race()
		return
	if inp.restart_pressed:
		start_race()
		return
	if inp.pause_pressed:
		pause()
		_redraw()
		return

	banner_time = maxf(0.0, banner_time - dt)
	_watch_launch(inp)
	match state:
		State.COUNTDOWN:
			countdown -= dt
			if countdown <= Launch.ROLL_TIME:
				for car: PlayerCar in rivals.everyone(player):
					car.speed = Launch.ROLL_SPEED
			if countdown <= 0.0:
				state = State.RACING
				_banner("GO!", "", 1.0)
		State.RACING:
			race_time += dt
			if timed():
				time_left -= dt
			if time_left <= 0.0 and timed():
				time_left = 0.0
				state = State.TIME_UP
				_banner("TIME UP", _setback_prompt() if tour else "Press R or Enter to try again", 999.0)

	InputRouter.speed_factor = player.speed_percent()
	var seg_before := track.find_segment(player.position + Cfg.PLAYER_Z)
	Draft.update(player, dt, state == State.RACING and Draft.in_wake(player, track, rivals.everyone(player)))
	player.update(dt, inp, track, state == State.RACING)
	traffic.update(dt, track)
	rivals.update(dt, track, player, state != State.COUNTDOWN, finish_distance)
	player.collide(track)
	touched_traffic = touched_traffic or player.hit_traffic
	Rivals.resolve_contacts(rivals.everyone(player), track)
	place = rivals.place(player, player_finish)
	picked_up = false
	pickup_age += dt
	ram_flash = 0.3 if player.rammed else maxf(0.0, ram_flash - dt)
	if state == State.RACING:
		score.watch(dt, player, track)
		_check_pickups()
		if recording != null:
			recording.record(player)
		_check_progress()
	if ghost != null:
		ghost_now = ghost.at(recording.count() - 1)
		road.ghost = ghost_now

	background.offset += seg_before.curve * (player.speed * dt / Cfg.SEGMENT_LENGTH) * BACKGROUND_SCROLL

	# Camera shake: rough ground, landings, crashes
	if player.crashed:
		_shake = SHAKE_CRASH
	elif player.landed:
		_shake = maxf(_shake, SHAKE_LANDING)
	elif player.offroad and player.speed > 100.0:
		_shake = maxf(_shake, SHAKE_OFFROAD * player.speed_percent())
	_shake = move_toward(_shake, 0.0, dt * SHAKE_SETTLE)
	road.position = Vector2(roundf(randf_range(-1, 1) * _shake), roundf(randf_range(-1, 1) * _shake))
	road.time += dt
	road.camera_z = player.position
	_redraw()
	_frame += 1
	if _screenshot_frames.has(_frame):
		_save_screenshot(_frame)


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
		_banner("LAUNCH!", "", 1.0)
	elif launch == Launch.Grade.BOG:
		_banner("GO!", "Too early!", 1.0)


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
			_banner("CHECKPOINT", "" if is_nan(split) else split_text(split) + " vs best", 2.0)
		else:
			time_left += checkpoint_bonus
			_banner("CHECKPOINT!", "TIME EXTENDED +%d" % checkpoint_bonus, 2.0)
	if player.distance >= finish_distance:
		state = State.FINISHED
		player_finish = race_time
		place = rivals.place(player, player_finish)
		score.finish(place, not rivals.cars.is_empty())
		var before_furthest := SaveData.furthest_stage
		var before_unlocks: Array = SaveData.unlocks.duplicate()
		record_finish()
		if time_attack:
			_save_ghost()
		var mins := int(race_time) / 60
		var secs := fmod(race_time, 60.0)
		var prompt := "Enter: menu   R: race again"
		after = After.MENU
		if tour:
			prompt = _tour_finish()
		elif time_attack:
			var against := "" if ghost == null else split_text(race_time - ghost.time) + " vs best   "
			prompt = ("NEW BEST!   " if new_best else "") + against + prompt
		if _saves() and Unlocks.earns_secret(stage_index, touched_traffic, not traffic.cars.is_empty()):
			SaveData.unlock(Unlocks.SECRET_CAR)
		new_unlocks = Unlocks.newly_open(before_furthest, before_unlocks, SaveData.furthest_stage, SaveData.unlocks)
		var placed := "%s of %d   " % [Rivals.ordinal(place), rivals.cars.size() + 1] if not rivals.cars.is_empty() else ""
		_banner("FINISH!", "%sTime %d:%05.2f   %s" % [placed, mins, secs, prompt], 999.0)


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
	if _saves():
		SaveData.unlock(Tour.FINISH_UNLOCK)
		SaveData.total_points += int(tour_state.points.get(Tour.YOU, 0))
		SaveData.save()
	return "Tour complete!   Enter: menu"


## Saves the finish (SaveData): best time for this stage and car, and the tour's progress.
## Autodriven runs and partway starts (dev flags) aren't the player's, so they aren't saved.
## Returns true for a new best time.
func record_finish() -> bool:
	if not _saves():
		return false
	return SaveData.record_finish(stage_index, car_id, race_time, place if not rivals.cars.is_empty() else 0, not time_attack)


## Time Attack: this run becomes the ghost when it beats the saved one.
func _save_ghost() -> void:
	if not _saves() or not Ghost.beats(race_time, ghost):
		return
	recording.time = race_time
	new_best = recording.save()


## Seconds against a best: "-1.23" ahead, "+0.50" behind.
static func split_text(seconds: float) -> String:
	return ("-" if seconds < 0.0 else "+") + "%.2f" % absf(seconds)


## Whether the clock runs down to TIME UP (not in Time Attack or Free Drive).
func timed() -> bool:
	return not time_attack and not free_drive


## Whether this race is the player's own, to save from: not autodriven, not started partway.
func _saves() -> bool:
	return not _autodrive and _start_segment == 0


func _banner(text: String, sub: String, seconds: float) -> void:
	banner = text
	banner_sub = sub
	banner_time = seconds
	if _log_banners:
		print("[autodrive] %.1fs  %s  %s" % [race_time, text, sub])


func _redraw() -> void:
	road.queue_redraw()
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
		elif arg.begins_with("--car="):
			car_id = Cars.find(arg.get_slice("=", 1))["id"]
		elif arg.begins_with("--at-segment="):
			_start_segment = int(arg.get_slice("=", 1))
		elif arg == "--no-traffic":
			_no_traffic = true
		elif arg == "--no-rivals":
			_no_rivals = true
		elif arg.begins_with("--screenshots="):
			for f in arg.get_slice("=", 1).split(","):
				_screenshot_frames.append(int(f))
		elif arg.begins_with("--shot-dir="):
			_screenshot_dir = arg.get_slice("=", 1)


func _autodrive_input() -> DriveInput:
	var inp := DriveInput.new()
	var seg := track.find_segment(player.position + Cfg.PLAYER_Z + 3000.0)
	inp.throttle = 0.0 if state == State.COUNTDOWN and countdown > 0.1 else 1.0
	inp.steer = clampf((seg.curve * 0.25) + (_autodrive_lane() - player.x) * 1.5, -1.0, 1.0)
	inp.nitro_pressed = _frame % 600 == 300
	return inp


## The lane with the most open road ahead, keeping the current one on a tie.
func _autodrive_lane() -> float:
	const LOOKAHEAD := 40  # segments
	var here := track.find_segment(player.position + Cfg.PLAYER_Z).index
	var best: float = Traffic.LANE_OFFSETS[0]
	var best_gap := -1
	var lanes: Array = Traffic.LANE_OFFSETS.duplicate()
	lanes.sort_custom(func(a: float, b: float) -> bool: return absf(a - player.x) < absf(b - player.x))
	for lane: float in lanes:
		var gap := LOOKAHEAD
		for r in rivals.cars:
			var ahead := wrapf(r.position - player.position, -track.length * 0.5, track.length * 0.5)
			if ahead > 0.0 and absf(r.x - lane) < 0.3 and r.speed < player.speed:
				gap = mini(gap, int(ahead / Cfg.SEGMENT_LENGTH))
		for n in gap:
			var ahead := track.segments[(here + n) % track.segments.size()]
			var blocked := false
			for car in ahead.cars:
				if absf(car.offset - lane) < 0.3 and car.speed < player.speed:
					blocked = true
			if blocked:
				gap = n
				break
		if gap > best_gap:
			best_gap = gap
			best = lane
	return best


func _save_screenshot(frame: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := _screenshot_dir if _screenshot_dir != "" else "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/frame_%05d.png" % [dir, frame])
