extends Node
## Main scene: the front end (title, options, stage select, car select) and the race it starts.
## Race dev flags (--autodrive, --stage=N, --race) skip the menus and go straight to a race.

enum Screen { TITLE, OPTIONS, STAGES, CARS, RACE }

const RACE_SCENE := preload("res://scenes/race.tscn")
const RACE_FLAGS := ["--autodrive", "--race", "--stage="]

var screen := Screen.TITLE
var stage_index := 0  # into Stages
var car_index := 0  # into Cars
var menu: MenuScreen
var race: Node  # race.gd, while racing
var wheel_hint := ""

var calibration: CalibrationWizard
var debug_overlay: InputDebugOverlay
var _layer: CanvasLayer
var _menu_shot := ""


func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	debug_overlay = InputDebugOverlay.new()
	calibration = CalibrationWizard.new()
	var top := CanvasLayer.new()
	top.layer = 2
	add_child(top)
	top.add_child(debug_overlay)
	top.add_child(calibration)
	InputRouter.devices_changed.connect(_update_wheel_hint)
	_update_wheel_hint()
	var quick := false
	for arg in OS.get_cmdline_user_args():
		for flag: String in RACE_FLAGS:
			quick = quick or arg.begins_with(flag)
		if arg.begins_with("--screen="):
			_open(arg.get_slice("=", 1))
		elif arg.begins_with("--menu-shot="):
			_menu_shot = arg.get_slice("=", 1)
	if quick:
		start_race()
	elif menu == null:
		show_title()
	if _menu_shot != "":
		_save_menu_shot()


func _physics_process(_dt: float) -> void:
	if screen == Screen.RACE or menu == null or calibration.visible:
		return
	menu.handle(InputRouter.menu)


func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.RACE:
		return
	if event.is_action_pressed("debug_input"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("calibrate") and not calibration.visible:
		calibration.open()


## The title, with START (0) or OPTIONS (1) picked.
func show_title(item := 0) -> void:
	var t := TitleScreen.new()
	t.index = item
	_set_menu(t, Screen.TITLE)


func show_options() -> void:
	_set_menu(OptionsScreen.new(), Screen.OPTIONS)


func show_stage_select() -> void:
	var s := StageSelect.new()
	s.index = stage_index
	_set_menu(s, Screen.STAGES)


func show_car_select() -> void:
	var c := CarSelect.new()
	c.index = car_index
	_set_menu(c, Screen.CARS)


## Leaves the menus for a race on the chosen stage and car.
func start_race() -> void:
	_set_menu(null, Screen.RACE)
	race = RACE_SCENE.instantiate()
	race.stage_index = stage_index
	race.car_id = Cars.get_car(car_index)["id"]
	race.debug_overlay = debug_overlay
	race.calibration = calibration
	race.quit_requested.connect(_on_race_quit)
	add_child(race)


func _on_race_quit() -> void:
	stage_index = race.stage_index  # stage select opens on the stage the tour reached
	race.queue_free()
	race = null
	Audio.stop_music()
	Audio.set_paused(false)
	show_title()


func _set_menu(next: MenuScreen, to: Screen) -> void:
	if menu != null:
		menu.queue_free()
	menu = next
	screen = to
	if menu != null:
		menu.game = self
		_layer.add_child(menu)


func _update_wheel_hint() -> void:
	wheel_hint = ""
	for d in Input.get_connected_joypads():
		if InputRouter.needs_calibration(d):
			wheel_hint = "Wheel detected: press F2 to calibrate steering and pedals"


# --- Dev helpers: `godot -- --screen=stages --menu-shot=/tmp/stages.png` -------------

func _open(which: String) -> void:
	match which:
		"stages":
			show_stage_select()
		"cars":
			show_car_select()
		"options":
			show_options()
		_:
			show_title()


func _save_menu_shot() -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_menu_shot.get_base_dir())
	img.save_png(_menu_shot)
	get_tree().quit()
