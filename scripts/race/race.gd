extends Node2D
## Race scene: owns the track, player, traffic, timer and checkpoints, and feeds the renderers.
## The game (game.gd) starts it from the menus; quit_requested asks to go back to them.

signal quit_requested

enum State { COUNTDOWN, RACING, FINISHED, TIME_UP }

const START_TIME := 45.0  # on the ARCADE timer; Settings scales both for the others
const CHECKPOINT_BONUS := 25.0
const BACKGROUND_SCROLL := 0.0006  # per segment travelled, per unit of curve
const TRAFFIC_COUNT := 70  # a stage theme can ask for more ("traffic")

var track: Track
var stage_index := 0  # into Stages
var car_id := "car_vega"  # into Cars
var player: PlayerCar
var power_ups := PowerUps.new()
var pickup := -1  # the last pickup taken (PowerUps.Kind), for the HUD
var pickup_gave := -1  # what it gave (a mystery hubcap opens into another kind)
var pickup_age := 99.0  # seconds since it was taken
var picked_up := false  # true for the tick a pickup is taken
var ram_flash := 0.0  # seconds left on the ram plate's impact flash
var traffic: Traffic
var state := State.COUNTDOWN
var countdown := 3.0
var time_left := START_TIME
var race_time := 0.0
var finish_distance := 1.0
var checkpoint_bonus := CHECKPOINT_BONUS  # after the timer option
var checkpoint_distances: Array[float] = []
var next_checkpoint := 0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var paused := false

var background: Background
var road: RoadRenderer
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
var _start_segment := 0  # --at-segment=N: start the race this far in (screenshots)
var _screenshot_frames: Array[int] = []
var _screenshot_dir := ""
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
	_shake = 0.0
	_fov_stretch = 0.0
	_was_airborne = false
	traffic = Traffic.new()
	traffic.spawn(track, 0 if _no_traffic else Settings.traffic_count(int(track.theme.get("traffic", TRAFFIC_COUNT))))
	state = State.COUNTDOWN
	countdown = 3.0
	time_left = Settings.race_time(START_TIME)
	checkpoint_bonus = Settings.race_time(CHECKPOINT_BONUS)
	race_time = 0.0
	next_checkpoint = 0
	banner = ""
	paused = false
	finish_distance = track.finish_index * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z
	checkpoint_distances.clear()
	for c in track.checkpoints:
		checkpoint_distances.append(c * Cfg.SEGMENT_LENGTH - Cfg.PLAYER_Z)
	background.set_theme(track.theme)
	background.offset = 0.0
	road.track = track
	road.player = player
	road.player_strips = CarSprites.strips(car["strip"])


## Pad steering's speed sensitivity is the race's to set; the menus get it back at rest.
func _exit_tree() -> void:
	InputRouter.speed_factor = 0.0


## After a finish: on to the next stage, or back to the first after the last.
func continue_tour() -> void:
	stage_index = maxi(0, Stages.next(stage_index))
	start_race()


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
	else:
		inp = Assists.apply(inp, player, track, Settings.steer_assist, Settings.brake_assist)
	if calibration.visible:
		_redraw()
		return
	if inp.restart_pressed or (inp.confirm_pressed and state == State.TIME_UP):
		start_race()
		return
	if inp.confirm_pressed and state == State.FINISHED:
		continue_tour()
		return
	if inp.pause_pressed:
		paused = not paused
	elif paused and InputRouter.menu.back_pressed:
		quit_requested.emit()
		return
	if paused:
		_redraw()
		return

	banner_time = maxf(0.0, banner_time - dt)
	match state:
		State.COUNTDOWN:
			countdown -= dt
			if countdown <= 0.0:
				state = State.RACING
				_banner("GO!", "", 1.0)
		State.RACING:
			race_time += dt
			time_left -= dt
			if time_left <= 0.0:
				time_left = 0.0
				state = State.TIME_UP
				_banner("TIME UP", "Press R or Enter to try again", 999.0)

	InputRouter.speed_factor = player.speed_percent()
	var seg_before := track.find_segment(player.position + Cfg.PLAYER_Z)
	player.update(dt, inp, track, state == State.RACING)
	traffic.update(dt, track)
	player.collide(track)
	picked_up = false
	pickup_age += dt
	ram_flash = 0.3 if player.rammed else maxf(0.0, ram_flash - dt)
	if state == State.RACING:
		_check_pickups()
		_check_progress()

	background.offset += seg_before.curve * (player.speed * dt / Cfg.SEGMENT_LENGTH) * BACKGROUND_SCROLL

	# Camera shake: rough ground, crests, landings, crashes. Display only (road.position).
	_shake = shake_after(_shake, player, player.airborne and not _was_airborne, dt)
	_was_airborne = player.airborne
	var shown := Settings.shake_amount(_shake)
	road.position = Vector2(roundf(randf_range(-1, 1) * shown), roundf(randf_range(-1, 1) * shown))
	# Nitro widens the view a little (display only: the renderer's camera depth)
	var stretch_to := Cfg.NITRO_FOV_STRETCH if player.nitro_time > 0.0 else 0.0
	_fov_stretch = move_toward(_fov_stretch, stretch_to, dt * Cfg.NITRO_FOV_RATE)
	road.camera_depth = camera_depth(_fov_stretch)
	road.time += dt
	road.camera_z = player.position
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
	if next_checkpoint < checkpoint_distances.size() and player.distance >= checkpoint_distances[next_checkpoint]:
		next_checkpoint += 1
		time_left += checkpoint_bonus
		_banner("CHECKPOINT!", "TIME EXTENDED +%d" % checkpoint_bonus, 2.0)
	if player.distance >= finish_distance:
		state = State.FINISHED
		record_finish()
		var mins := int(race_time) / 60
		var secs := fmod(race_time, 60.0)
		var next := Stages.next(stage_index)
		var prompt := "Enter: on to %s" % Stages.stage_name(next) if next >= 0 else "Tour complete!   Enter: race again"
		_banner("FINISH!", "Time %d:%05.2f   %s" % [mins, secs, prompt], 999.0)


## Saves the finish (SaveData): best time for this stage and car, and the tour's progress.
## Autodriven runs and partway starts (dev flags) aren't the player's, so they aren't saved.
## Returns true for a new best time.
func record_finish() -> bool:
	if _autodrive or _start_segment != 0:
		return false
	return SaveData.record_finish(stage_index, car_id, race_time)


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
		elif arg.begins_with("--screenshots="):
			for f in arg.get_slice("=", 1).split(","):
				_screenshot_frames.append(int(f))
		elif arg.begins_with("--shot-dir="):
			_screenshot_dir = arg.get_slice("=", 1)


func _autodrive_input() -> DriveInput:
	var inp := DriveInput.new()
	var seg := track.find_segment(player.position + Cfg.PLAYER_Z + 3000.0)
	inp.throttle = 1.0
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
		for n in LOOKAHEAD:
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
