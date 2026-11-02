extends Node
## Autoload. Player options (the Options screen), saved to user://settings.cfg.
## The race reads them when a stage starts; volumes go straight to the audio buses.

signal changed

enum Traffic { LIGHT, NORMAL, HEAVY }
enum Clock { RELAXED, ARCADE, TIGHT }
enum Units { MPH, KPH }

const TRAFFIC_NAMES := ["LIGHT", "NORMAL", "HEAVY"]
const TRAFFIC_MULT := [0.5, 1.0, 1.4]
const TIMER_NAMES := ["RELAXED", "ARCADE", "TIGHT"]
const TIMER_MULT := [1.35, 1.0, 0.85]  # on the start time and checkpoint bonuses
const UNIT_NAMES := ["MPH", "KPH"]
const KPH_PER_MPH := 1.609344
const VOLUME_STEPS := 10
const EFFECT_STEPS := 10  # screen shake and flash: 0 (off)..10 (as designed, the most)
## The settings.cfg format (CfgVersion). 0: no version field. 1: the same keys, versioned.
## 2: [accessibility] screen_shake and flash (missing: the designed level).
## 3: [display] units (missing: MPH).
## 4: [display] fullscreen, integer_scale, vsync, scanlines (missing: windowed, fractional,
## V-Sync on, no scanlines).
## 5: [play] steer_assist, brake_assist (missing: off).
## 6: [audio] radio (missing: shuffle). 7: [accessibility] subtitles (missing: on).
## 8: [play] manual_gears (missing: automatic).
## 9: [controls] key_steer_in, key_steer_out (missing: STANDARD, as every earlier build).
## 10: [accessibility] reduce_motion (missing: off).
## 11: [controls] rumble (missing: as designed, EFFECT_STEPS).
## 12: [news] seen, the last version whose notes the title showed (WhatsNew; missing: none,
## so an update from an older build shows its notes); [play] co_pilot (missing: off).
## 13: [display] camera_view (missing: CameraView.View.CHASE_NEAR, the only view before).
const VERSION := 13
## Keyboard steering feel (AC-11): how fast a held key turns in and a released one comes back,
## snappy to smooth. Each multiplies its rate (shares of full lock per second); STANDARD is
## the rate every earlier build had.
const KEY_STEER_IN := 5.0
const KEY_STEER_OUT := 9.0
const STEER_FEEL_NAMES := ["SNAPPIEST", "SNAPPIER", "SNAPPY", "STANDARD", "SMOOTH", "SMOOTHER", "SMOOTHEST"]
const STEER_FEEL_MULT := [2.0, 1.6, 1.3, 1.0, 0.8, 0.6, 0.45]
const STEER_FEEL_STANDARD := 3
## The scanline overlay's CanvasLayer: above the race, the menus and the debug overlay.
const SCANLINE_LAYER := 100
const SCANLINE_SHADER := preload("res://scripts/render/scanlines.gdshader")

## Where options are saved. Tests point this at a scratch file.
var path := "user://settings.cfg"
var auto_gas := false  # hold the gas for the player; steering and brake still theirs
var traffic: int = Traffic.NORMAL
var timer: int = Clock.ARCADE  # a Clock
var power_ups := true  # pickups on the road (PowerUps)
var difficulty: int = Difficulty.Level.NORMAL
var carry_time := false  # Grand Tour: clock left at a finish carries into the next stage
var steer_assist := false  # Assists: keyboard and gamepad steering pulls toward the lane
var brake_assist := false  # Assists: brakes into corners taken too fast
var co_pilot := false  # Assists.co_pilot (AC-14): the steering done for you, nudged by the player's
var manual_gears := false  # the player shifts (PlayerCar.shift); automatic by default
var key_steer_in: int = STEER_FEEL_STANDARD  # into STEER_FEEL_NAMES: a held key's turn in
var key_steer_out: int = STEER_FEEL_STANDARD  # and a released key's return to center
var rumble := 10  # 0..EFFECT_STEPS; a gamepad's rumble (Rumble), 0 off
var attack_traffic := false  # Time Attack and Free Drive with traffic (picked on stage select)
var unlock_all := false  # every car and stage open (Unlocks), for testing and accessibility
var music_volume := 10  # 0..VOLUME_STEPS; 10 is the mix as authored
var sfx_volume := 10
var radio: int = Radio.SHUFFLE  # the station races start on (Radio)
var screen_shake := 10  # 0..EFFECT_STEPS; scales camera shake and the nitro FOV stretch
var flash := 10  # 0..EFFECT_STEPS; scales flashes and blinking warnings
var subtitles := true  # the announcer's words on screen (Announcer)
## Reduce motion (AC-13): no camera shake, nitro view stretch, hill shift of the scenery or
## rain streaks, whatever the screen shake option says (shake_amount, motion_reduced).
var reduce_motion := false
var units: int = Units.MPH  # the speedometer's
var camera_view: int = CameraView.View.CHASE_NEAR  # the race's camera (WS-15): the VIEW button steps it
var fullscreen := false  # windowed by default
var integer_scale := false  # whole-number scaling of the 640x360 view (borders round it)
var vsync := true
var scanlines := false  # a CRT-style overlay (SCANLINE_SHADER)
## The last version whose notes the title showed (WhatsNew, PR-17); "" for none yet.
var whats_new_seen := ""
## The overlay apply_display() shows or hides; made on first use.
var scanline_layer: CanvasLayer
## The version of the file last loaded (VERSION when there was no file).
var loaded_version := VERSION
var had_file := false  # the last load found a file (a game that ran before: WhatsNew)


func _ready() -> void:
	# Dev flag: --settings-file=PATH reads (and saves) another options file, for screenshots.
	path = DevArgs.value("--settings-file", path)
	load_settings()


## Back to the defaults (not saved). What's new stays seen (whats_new_seen is not an option).
func reset() -> void:
	auto_gas = false
	traffic = Traffic.NORMAL
	timer = Clock.ARCADE
	power_ups = true
	difficulty = Difficulty.Level.NORMAL
	carry_time = false
	steer_assist = false
	brake_assist = false
	co_pilot = false
	manual_gears = false
	key_steer_in = STEER_FEEL_STANDARD
	key_steer_out = STEER_FEEL_STANDARD
	rumble = EFFECT_STEPS
	unlock_all = false
	attack_traffic = false
	music_volume = 10
	sfx_volume = 10
	radio = Radio.SHUFFLE
	screen_shake = EFFECT_STEPS
	flash = EFFECT_STEPS
	subtitles = true
	reduce_motion = false
	units = Units.MPH
	camera_view = CameraView.View.CHASE_NEAR
	fullscreen = false
	integer_scale = false
	vsync = true
	scanlines = false
	apply_volumes()
	apply_display()


func load_settings() -> void:
	reset()
	whats_new_seen = ""
	loaded_version = VERSION
	var cfg := ConfigFile.new()
	had_file = cfg.load(path) == OK
	if had_file:
		loaded_version = migrate(cfg)
		auto_gas = bool(cfg.get_value("play", "auto_gas", auto_gas))
		traffic = clampi(int(cfg.get_value("play", "traffic", traffic)), 0, Traffic.size() - 1)
		timer = clampi(int(cfg.get_value("play", "timer", timer)), 0, Clock.size() - 1)
		power_ups = bool(cfg.get_value("play", "power_ups", power_ups))
		difficulty = clampi(int(cfg.get_value("play", "difficulty", difficulty)), 0, Difficulty.Level.size() - 1)
		carry_time = bool(cfg.get_value("play", "carry_time", carry_time))
		steer_assist = bool(cfg.get_value("play", "steer_assist", steer_assist))
		brake_assist = bool(cfg.get_value("play", "brake_assist", brake_assist))
		co_pilot = bool(cfg.get_value("play", "co_pilot", co_pilot))
		manual_gears = bool(cfg.get_value("play", "manual_gears", manual_gears))
		key_steer_in = clampi(int(cfg.get_value("controls", "key_steer_in", key_steer_in)), 0, STEER_FEEL_NAMES.size() - 1)
		key_steer_out = clampi(int(cfg.get_value("controls", "key_steer_out", key_steer_out)), 0, STEER_FEEL_NAMES.size() - 1)
		rumble = clampi(int(cfg.get_value("controls", "rumble", rumble)), 0, EFFECT_STEPS)
		unlock_all = bool(cfg.get_value("play", "unlock_all", unlock_all))
		attack_traffic = bool(cfg.get_value("play", "attack_traffic", attack_traffic))
		music_volume = clampi(int(cfg.get_value("audio", "music", music_volume)), 0, VOLUME_STEPS)
		sfx_volume = clampi(int(cfg.get_value("audio", "sfx", sfx_volume)), 0, VOLUME_STEPS)
		radio = clampi(int(cfg.get_value("audio", "radio", radio)), Radio.SHUFFLE, Radio.count() - 1)
		screen_shake = clampi(int(cfg.get_value("accessibility", "screen_shake", screen_shake)), 0, EFFECT_STEPS)
		flash = clampi(int(cfg.get_value("accessibility", "flash", flash)), 0, EFFECT_STEPS)
		subtitles = bool(cfg.get_value("accessibility", "subtitles", subtitles))
		reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", reduce_motion))
		units = clampi(int(cfg.get_value("display", "units", units)), 0, Units.size() - 1)
		camera_view = clampi(int(cfg.get_value("display", "camera_view", camera_view)), 0, CameraView.View.size() - 1)
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		integer_scale = bool(cfg.get_value("display", "integer_scale", integer_scale))
		vsync = bool(cfg.get_value("display", "vsync", vsync))
		scanlines = bool(cfg.get_value("display", "scanlines", scanlines))
		whats_new_seen = str(cfg.get_value("news", "seen", whats_new_seen))
	apply_volumes()
	apply_display()


## Brings a loaded settings.cfg up to VERSION; returns the version it had.
static func migrate(cfg: ConfigFile) -> int:
	return CfgVersion.migrate(cfg, VERSION, [_v0_to_v1, _v1_to_v2, _v2_to_v3, _v3_to_v4, _v4_to_v5, _v5_to_v6, _v6_to_v7, _v7_to_v8, _v8_to_v9, _v9_to_v10, _v10_to_v11, _v11_to_v12, _v12_to_v13])


## Version 1 only added the version field: the keys are as they were.
static func _v0_to_v1(_cfg: ConfigFile) -> void:
	pass


## Version 2 added screen shake and flash, at the designed level until the player turns them down.
static func _v1_to_v2(cfg: ConfigFile) -> void:
	cfg.set_value("accessibility", "screen_shake", EFFECT_STEPS)
	cfg.set_value("accessibility", "flash", EFFECT_STEPS)


## Version 3 added the speedometer units: MPH, as every earlier build showed.
static func _v2_to_v3(cfg: ConfigFile) -> void:
	cfg.set_value("display", "units", Units.MPH)


## Version 4 added the display options, as every earlier build ran: windowed, fractional
## scaling, V-Sync on, no scanlines.
static func _v3_to_v4(cfg: ConfigFile) -> void:
	cfg.set_value("display", "fullscreen", false)
	cfg.set_value("display", "integer_scale", false)
	cfg.set_value("display", "vsync", true)
	cfg.set_value("display", "scanlines", false)


## Version 5 added the driving assists, off as before.
static func _v4_to_v5(cfg: ConfigFile) -> void:
	cfg.set_value("play", "steer_assist", false)
	cfg.set_value("play", "brake_assist", false)


## Version 6 added the radio station, on shuffle (every earlier build had one music loop).
static func _v5_to_v6(cfg: ConfigFile) -> void:
	cfg.set_value("audio", "radio", Radio.SHUFFLE)


## Version 7 added subtitles for the announcer, on (the default).
static func _v6_to_v7(cfg: ConfigFile) -> void:
	cfg.set_value("accessibility", "subtitles", true)


## Version 8 added manual gears, off: every earlier build shifted for you.
static func _v7_to_v8(cfg: ConfigFile) -> void:
	cfg.set_value("play", "manual_gears", false)


## Version 9 added the keyboard steering feel, STANDARD both ways: the rates every earlier
## build steered at.
static func _v8_to_v9(cfg: ConfigFile) -> void:
	cfg.set_value("controls", "key_steer_in", STEER_FEEL_STANDARD)
	cfg.set_value("controls", "key_steer_out", STEER_FEEL_STANDARD)


## Version 10 added reduce motion, off: everything moving as before.
static func _v9_to_v10(cfg: ConfigFile) -> void:
	cfg.set_value("accessibility", "reduce_motion", false)


## Version 11 added gamepad rumble, as designed (no earlier build rumbled; this is the default).
static func _v10_to_v11(cfg: ConfigFile) -> void:
	cfg.set_value("controls", "rumble", EFFECT_STEPS)


## Version 12 added what the title's what's new last showed: nothing, so the first start on
## this build after an older one shows its notes. And the co-pilot, off as before.
static func _v11_to_v12(cfg: ConfigFile) -> void:
	cfg.set_value("news", "seen", "")
	cfg.set_value("play", "co_pilot", false)


## Version 13 added the camera view (WS-15): chase near, the one view every earlier build had.
static func _v12_to_v13(cfg: ConfigFile) -> void:
	cfg.set_value("display", "camera_view", CameraView.View.CHASE_NEAR)


## Writes the options. Over a file from a newer build, its other keys are kept
## (CfgVersion.to_write); `fresh` (resetting the options) writes only this build's keys.
func save(fresh := false) -> void:
	var cfg := CfgVersion.to_write(path, VERSION, fresh)
	cfg.set_value("play", "auto_gas", auto_gas)
	cfg.set_value("play", "traffic", traffic)
	cfg.set_value("play", "timer", timer)
	cfg.set_value("play", "power_ups", power_ups)
	cfg.set_value("play", "difficulty", difficulty)
	cfg.set_value("play", "carry_time", carry_time)
	cfg.set_value("play", "steer_assist", steer_assist)
	cfg.set_value("play", "brake_assist", brake_assist)
	cfg.set_value("play", "co_pilot", co_pilot)
	cfg.set_value("play", "manual_gears", manual_gears)
	cfg.set_value("controls", "key_steer_in", key_steer_in)
	cfg.set_value("controls", "key_steer_out", key_steer_out)
	cfg.set_value("controls", "rumble", rumble)
	cfg.set_value("play", "unlock_all", unlock_all)
	cfg.set_value("play", "attack_traffic", attack_traffic)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "radio", radio)
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "flash", flash)
	cfg.set_value("accessibility", "subtitles", subtitles)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("display", "units", units)
	cfg.set_value("display", "camera_view", camera_view)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "integer_scale", integer_scale)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "scanlines", scanlines)
	cfg.set_value("news", "seen", whats_new_seen)
	cfg.save(path)
	apply_volumes()
	apply_display()
	changed.emit()


## The race's input after the options: with auto gas, full throttle unless braking.
## Returns a copy; `inp` is left alone.
func drive_input(inp: DriveInput) -> DriveInput:
	if not auto_gas:
		return inp
	var out := inp.copy()
	out.throttle = 0.0 if inp.brake > 0.05 else 1.0
	return out


## The keyboard's steering rates after the steering feel options: x turning in (share of
## full lock per second while a key is held), y coming back (released, or reversing).
func key_steer_rates() -> Vector2:
	return Vector2(KEY_STEER_IN * STEER_FEEL_MULT[clampi(key_steer_in, 0, STEER_FEEL_MULT.size() - 1)],
		KEY_STEER_OUT * STEER_FEEL_MULT[clampi(key_steer_out, 0, STEER_FEEL_MULT.size() - 1)])


## A camera effect (shake in pixels, the nitro FOV stretch) after the screen shake option:
## the designed amount at 10, none at 0, never more than designed. None with reduce motion.
func shake_amount(designed: float) -> float:
	if reduce_motion:
		return 0.0
	return designed * clampi(screen_shake, 0, EFFECT_STEPS) / float(EFFECT_STEPS)


## A moving effect after reduce motion: `designed` (pixels, streaks), or none with it on.
## The hill shift (Background.shown_hill) and rain (FxLayer.rain_shown) read it.
func motion_amount(designed: float) -> float:
	return 0.0 if reduce_motion else designed


## A flash's strength (alpha, or how far a blink goes) after the flash option, as above.
func flash_amount(designed: float) -> float:
	return designed * clampi(flash, 0, EFFECT_STEPS) / float(EFFECT_STEPS)


## A car's speed (world units per second) as the speedometer shows it in `in_units`:
## Cfg.DISPLAY_TOP_SPEED mph at Cfg.MAX_SPEED, rounded.
static func speed_in(speed: float, in_units: int) -> int:
	var mph := speed / Cfg.MAX_SPEED * Cfg.DISPLAY_TOP_SPEED
	return roundi(mph * KPH_PER_MPH if in_units == Units.KPH else mph)


## A distance in world units in miles, on the speedometer's scale (speed_in): a second at
## Cfg.MAX_SPEED covers Cfg.DISPLAY_TOP_SPEED / 3600 miles.
static func miles(world: float) -> float:
	return world / Cfg.MAX_SPEED * Cfg.DISPLAY_TOP_SPEED / 3600.0


## A distance in world units as text in `in_units`: "4.6 MI" or "7.4 KM", one decimal.
static func distance_text(world: float, in_units: int) -> String:
	var mi := miles(world)
	return "%.1f KM" % (mi * KPH_PER_MPH) if in_units == Units.KPH else "%.1f MI" % mi


## The speedometer's number and label in the units option.
func speedometer(speed: float) -> Array:
	return [speed_in(speed, units), UNIT_NAMES[units]]


## Picks a difficulty and puts the timer option on its default (it can still be changed after).
func set_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, Difficulty.Level.size() - 1)
	timer = Difficulty.of(difficulty).timer


func traffic_count(base: int) -> int:
	return roundi(base * TRAFFIC_MULT[traffic])


## A stage's clock (start time or checkpoint bonus) for the timer option.
func race_time(base: float) -> float:
	return roundf(base * TIMER_MULT[timer])


func apply_volumes() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


static func volume_db(steps: int) -> float:
	return -80.0 if steps <= 0 else linear_to_db(float(steps) / VOLUME_STEPS)


func _set_bus(bus: String, steps: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, volume_db(steps))
		AudioServer.set_bus_mute(i, steps <= 0)


## What the display options ask of the window: its mode, the stretch, the V-Sync mode and
## whether the scanline overlay shows.
func display_plan() -> Dictionary:
	return {
		"window_mode": DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED,
		"stretch": Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scale else Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		"vsync": DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED,
		"scanlines": scanlines,
	}


## Where the `view`-sized picture sits in a `window`-sized window (aspect kept, centred):
## whole-number steps with `integer`, as large as fits without. Mirrors the engine's stretch.
static func view_rect(window: Vector2i, view: Vector2i, integer: bool) -> Rect2i:
	var fit := minf(float(window.x) / view.x, float(window.y) / view.y)
	var s := maxf(1.0, floorf(fit)) if integer else fit
	var size := Vector2i(roundi(view.x * s), roundi(view.y * s))
	return Rect2i((window - size) / 2, size)


## True where there is no window to change (headless runs: tests, golden traces).
static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Puts the display options on the window and shows or hides the scanlines. Headless, the
## window is left alone; the overlay is only a node there, and is made only once it shows.
func apply_display() -> void:
	var plan := display_plan()
	if plan["scanlines"] or scanline_layer != null:
		_scanline_overlay().visible = plan["scanlines"]
	if headless() or not is_inside_tree():
		return
	get_window().content_scale_stretch = plan["stretch"]
	var mode := DisplayServer.window_get_mode()
	var windowed := mode == DisplayServer.WINDOW_MODE_WINDOWED or mode == DisplayServer.WINDOW_MODE_MAXIMIZED
	if windowed != (plan["window_mode"] == DisplayServer.WINDOW_MODE_WINDOWED):  # maximized counts as windowed
		DisplayServer.window_set_mode(plan["window_mode"])
	if DisplayServer.window_get_vsync_mode() != plan["vsync"]:
		DisplayServer.window_set_vsync_mode(plan["vsync"])


## The scanline overlay: a full-screen ColorRect under SCANLINE_SHADER on its own top layer.
func _scanline_overlay() -> CanvasLayer:
	if scanline_layer == null:
		scanline_layer = CanvasLayer.new()
		scanline_layer.layer = SCANLINE_LAYER
		scanline_layer.name = "Scanlines"
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = SCANLINE_SHADER
		rect.material = mat
		scanline_layer.add_child(rect)
		add_child(scanline_layer)
	return scanline_layer
