extends Node2D
## Race scene: owns the track, player, traffic, timer and checkpoints, and feeds the renderers.

enum State { COUNTDOWN, RACING, FINISHED, TIME_UP }

const START_TIME := 45.0
const CHECKPOINT_BONUS := 25.0
const BACKGROUND_SCROLL := 0.0006  # per segment travelled, per unit of curve
const TRAFFIC_COUNT := 70

var track: Track
var stage_index := 0  # into Stages
var player: PlayerCar
var traffic: Traffic
var state := State.COUNTDOWN
var countdown := 3.0
var time_left := START_TIME
var race_time := 0.0
var finish_distance := 1.0
var checkpoint_distances: Array[float] = []
var next_checkpoint := 0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var wheel_hint := ""
var paused := false

var background: Background
var road: RoadRenderer
var hud: Hud
var debug_overlay: InputDebugOverlay
var calibration: CalibrationWizard

var _shake := 0.0
var _autodrive := false
var _log_banners := false
var _no_traffic := false
var _screenshot_frames: Array[int] = []
var _screenshot_dir := ""
var _frame := 0


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
	debug_overlay = InputDebugOverlay.new()
	layer.add_child(debug_overlay)
	calibration = CalibrationWizard.new()
	layer.add_child(calibration)
	InputRouter.devices_changed.connect(_update_wheel_hint)
	_parse_dev_args()
	start_race()


func start_race() -> void:
	track = Stages.build(stage_index)
	player = PlayerCar.new()
	player.reset()
	player.road_y = track.height_at(Cfg.PLAYER_Z)
	traffic = Traffic.new()
	traffic.spawn(track, 0 if _no_traffic else TRAFFIC_COUNT)
	state = State.COUNTDOWN
	countdown = 3.0
	time_left = START_TIME
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
	_update_wheel_hint()


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
	var inp: DriveInput = InputRouter.state
	if _autodrive:
		inp = _autodrive_input()
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
	if state == State.RACING:
		_check_progress()

	background.offset += seg_before.curve * (player.speed * dt / Cfg.SEGMENT_LENGTH) * BACKGROUND_SCROLL

	# Camera shake: rough ground, landings, crashes
	if player.crashed:
		_shake = 5.0
	elif player.landed:
		_shake = maxf(_shake, 3.0)
	elif player.offroad and player.speed > 100.0:
		_shake = maxf(_shake, 1.5 * player.speed_percent())
	_shake = move_toward(_shake, 0.0, dt * 12.0)
	road.position = Vector2(roundf(randf_range(-1, 1) * _shake), roundf(randf_range(-1, 1) * _shake))
	road.time += dt
	road.camera_z = player.position
	_redraw()
	_frame += 1
	if _screenshot_frames.has(_frame):
		_save_screenshot()


func _check_progress() -> void:
	if next_checkpoint < checkpoint_distances.size() and player.distance >= checkpoint_distances[next_checkpoint]:
		next_checkpoint += 1
		time_left += CHECKPOINT_BONUS
		_banner("CHECKPOINT!", "TIME EXTENDED +%d" % CHECKPOINT_BONUS, 2.0)
	if player.distance >= finish_distance:
		state = State.FINISHED
		var mins := int(race_time) / 60
		var secs := fmod(race_time, 60.0)
		var next := Stages.next(stage_index)
		var prompt := "Enter: on to %s" % Stages.stage_name(next) if next >= 0 else "Tour complete!   Enter: race again"
		_banner("FINISH!", "Time %d:%05.2f   %s" % [mins, secs, prompt], 999.0)


func _banner(text: String, sub: String, seconds: float) -> void:
	banner = text
	banner_sub = sub
	banner_time = seconds
	if _log_banners:
		print("[autodrive] %.1fs  %s  %s" % [race_time, text, sub])


func _update_wheel_hint() -> void:
	wheel_hint = ""
	for d in Input.get_connected_joypads():
		if InputRouter.needs_calibration(d):
			wheel_hint = "Wheel detected: press F2 to calibrate steering and pedals"


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


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := _screenshot_dir if _screenshot_dir != "" else "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/frame_%05d.png" % [dir, _frame])
