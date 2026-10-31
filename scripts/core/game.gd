extends Node
## Main scene: the front end (title, mode select, options, stage select, car select) and the
## race it starts.
## Race dev flags (--autodrive, --stage=N, --race) skip the menus and go straight to a race.

enum Screen { TITLE, MODES, OPTIONS, STAGES, CARS, RACE, REMAP }

const RACE_SCENE := preload("res://scenes/race.tscn")
const RACE_FLAGS := ["--autodrive", "--race", "--stage="]

var screen := Screen.TITLE
var mode_index := 0  # into ModeSelect.Item, the last mode picked
var stage_index := 0  # into Stages
var car_index := 0  # into Cars
var menu: MenuScreen
var race: Node  # race.gd, while racing

var calibration: CalibrationWizard
var debug_overlay: InputDebugOverlay
var _layer: CanvasLayer
var _menu_shot := ""
## Where the options screen goes back to (close_options): the title unless whoever opened
## it says otherwise.
var _options_back := Callable()
var _options_back_name := "the title screen"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2  # over the race, for options from its pause menu
	add_child(_layer)
	debug_overlay = InputDebugOverlay.new()
	calibration = CalibrationWizard.new()
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	top.add_child(debug_overlay)
	top.add_child(calibration)
	var quick := false
	var pause_shot := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--car="):
			car_index = maxi(0, Cars.LIST.find(Cars.find(arg.get_slice("=", 1))))
	for arg in OS.get_cmdline_user_args():
		for flag: String in RACE_FLAGS:
			quick = quick or arg.begins_with(flag)
		if arg == "--screen=pause":
			pause_shot = true
		elif arg.begins_with("--screen="):
			_open(arg.get_slice("=", 1))
		elif arg.begins_with("--menu-shot="):
			_menu_shot = arg.get_slice("=", 1)
	if quick or pause_shot:
		start_race()
	elif menu == null:
		show_title()
	if pause_shot:
		race.pause()
	if _menu_shot != "":
		_save_menu_shot()


func _physics_process(_dt: float) -> void:
	if screen == Screen.RACE or menu == null or calibration.visible:
		return
	menu.handle(InputRouter.menu)


func _unhandled_input(event: InputEvent) -> void:
	if race != null:  # the race has its own F1 / F2
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


## Mode select, on the last mode picked (or `item`).
func show_mode_select(item := -1) -> void:
	var m := ModeSelect.new()
	m.index = mode_index if item < 0 else item
	_set_menu(m, Screen.MODES)


## The options, from the title unless `back` (with its name for the BACK row's help) says
## where they go back to; on `page` (an OptionsScreen.Page) when given, with the cursor on
## `row` (an OptionsScreen.Row) when given.
func show_options(back := Callable(), back_name := "the title screen", page := -1, row := -1) -> void:
	var o := OptionsScreen.new()
	o.back_name = back_name
	if page >= 0:
		o.page = page
		o.index = 0  # on the page bar, so the page shows which it is
	if row >= 0:
		o.go_to(row)
	_options_back = back
	_options_back_name = back_name
	_set_menu(o, Screen.OPTIONS)


## Controls > REMAP BUTTONS.
func show_remap() -> void:
	_set_menu(RemapScreen.new(), Screen.REMAP)


## Back from remapping: the options again, on REMAP BUTTONS, still going back where they did.
func close_remap() -> void:
	show_options(_options_back, _options_back_name, OptionsScreen.Page.CONTROLS, OptionsScreen.Row.REMAP)
	menu.in_race = race != null


## Options opened from mode select come back to it.
func show_options_from_modes() -> void:
	show_options(show_mode_select.bind(ModeSelect.Item.OPTIONS), "mode select")


## Leaves the options for wherever they were opened from.
func close_options() -> void:
	var back := _options_back
	_options_back = Callable()
	if back.is_valid():
		back.call()
	else:
		show_title(1)


## A playable mode picked on mode select.
func choose_mode(item: int) -> void:
	mode_index = item
	show_stage_select()


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
	race.tour = mode_index == ModeSelect.Item.GRAND_TOUR
	race.debug_overlay = debug_overlay
	race.calibration = calibration
	race.quit_requested.connect(_on_race_quit)
	race.race_over.connect(_on_race_over)
	race.options_requested.connect(_on_race_options)
	add_child(race)


func _on_race_quit() -> void:
	_drop_race()
	show_title()


## A Single Race finished: back to stage select for the next one.
func _on_race_over() -> void:
	_drop_race()
	show_stage_select()


## OPTIONS on the pause menu: the options over the paused race, then back to its menu.
func _on_race_options() -> void:
	show_options(_close_race_options, "the race")
	menu.in_race = true


func _close_race_options() -> void:
	_set_menu(null, Screen.RACE)
	race.options_closed()


func _drop_race() -> void:
	stage_index = race.stage_index  # stage select opens on the stage the tour reached
	race.queue_free()
	race = null
	Audio.stop_music()
	Audio.set_paused(false)


func _set_menu(next: MenuScreen, to: Screen) -> void:
	if menu != null:
		menu.queue_free()
	menu = next
	screen = to
	if menu != null:
		menu.game = self
		_layer.add_child(menu)


# --- Dev helpers: `godot -- --screen=stages --menu-shot=/tmp/stages.png` -------------
# (--screen=pause starts a race and pauses it; add --at-segment=N to pause further in.
# --car=car_mesa opens car select on that car.)

func _open(which: String) -> void:
	match which:
		"stages":
			show_stage_select()
		"cars":
			show_car_select()
		"options":
			show_options()
		"remap":
			show_remap()
		"modes":
			show_mode_select()
		_ when which.begins_with("options:"):
			show_options(Callable(), "the title screen", OptionsScreen.page_named(which.get_slice(":", 1)))
		_:
			show_title()


func _save_menu_shot() -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if OS.get_cmdline_user_args().has("--shot-as-window"):
		img = _as_window(img)
	DirAccess.make_dir_recursive_absolute(_menu_shot.get_base_dir())
	img.save_png(_menu_shot)
	get_tree().quit()


## The 640x360 shot laid out as the window shows it (`--shot-as-window`): scaled and
## bordered by the window's own size and stretch, for checking the display options.
func _as_window(view: Image) -> Image:
	var win := get_window()
	var integer := win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER
	var r := Settings.view_rect(win.size, view.get_size(), integer)
	print("window %s, %s stretch, picture at %s" % [win.size, "integer" if integer else "fractional", r])
	var out := Image.create(win.size.x, win.size.y, false, view.get_format())
	out.fill(Color.BLACK)
	view.resize(r.size.x, r.size.y, Image.INTERPOLATE_NEAREST)
	out.blit_rect(view, Rect2i(Vector2i.ZERO, r.size), r.position)
	return out
