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
const VERSION := 3

## Where options are saved. Tests point this at a scratch file.
var path := "user://settings.cfg"
var auto_gas := false  # hold the gas for the player; steering and brake still theirs
var traffic: int = Traffic.NORMAL
var timer: int = Clock.ARCADE  # a Clock
var power_ups := true  # pickups on the road (PowerUps)
var difficulty: int = Difficulty.Level.NORMAL
var carry_time := false  # Grand Tour: clock left at a finish carries into the next stage
var music_volume := 10  # 0..VOLUME_STEPS; 10 is the mix as authored
var sfx_volume := 10
var screen_shake := 10  # 0..EFFECT_STEPS; scales camera shake and the nitro FOV stretch
var flash := 10  # 0..EFFECT_STEPS; scales flashes and blinking warnings
var units: int = Units.MPH  # the speedometer's
## The version of the file last loaded (VERSION when there was no file).
var loaded_version := VERSION


func _ready() -> void:
	load_settings()


## Back to the defaults (not saved).
func reset() -> void:
	auto_gas = false
	traffic = Traffic.NORMAL
	timer = Clock.ARCADE
	power_ups = true
	difficulty = Difficulty.Level.NORMAL
	carry_time = false
	music_volume = 10
	sfx_volume = 10
	screen_shake = EFFECT_STEPS
	flash = EFFECT_STEPS
	units = Units.MPH
	apply_volumes()


func load_settings() -> void:
	reset()
	loaded_version = VERSION
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		loaded_version = migrate(cfg)
		auto_gas = bool(cfg.get_value("play", "auto_gas", auto_gas))
		traffic = clampi(int(cfg.get_value("play", "traffic", traffic)), 0, Traffic.size() - 1)
		timer = clampi(int(cfg.get_value("play", "timer", timer)), 0, Clock.size() - 1)
		power_ups = bool(cfg.get_value("play", "power_ups", power_ups))
		difficulty = clampi(int(cfg.get_value("play", "difficulty", difficulty)), 0, Difficulty.Level.size() - 1)
		carry_time = bool(cfg.get_value("play", "carry_time", carry_time))
		music_volume = clampi(int(cfg.get_value("audio", "music", music_volume)), 0, VOLUME_STEPS)
		sfx_volume = clampi(int(cfg.get_value("audio", "sfx", sfx_volume)), 0, VOLUME_STEPS)
		screen_shake = clampi(int(cfg.get_value("accessibility", "screen_shake", screen_shake)), 0, EFFECT_STEPS)
		flash = clampi(int(cfg.get_value("accessibility", "flash", flash)), 0, EFFECT_STEPS)
		units = clampi(int(cfg.get_value("display", "units", units)), 0, Units.size() - 1)
	apply_volumes()


## Brings a loaded settings.cfg up to VERSION; returns the version it had.
static func migrate(cfg: ConfigFile) -> int:
	return CfgVersion.migrate(cfg, VERSION, [_v0_to_v1, _v1_to_v2, _v2_to_v3])


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
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "flash", flash)
	cfg.set_value("display", "units", units)
	cfg.save(path)
	apply_volumes()
	changed.emit()


## The race's input after the options: with auto gas, full throttle unless braking.
## Returns a copy; `inp` is left alone.
func drive_input(inp: DriveInput) -> DriveInput:
	if not auto_gas:
		return inp
	var out := inp.copy()
	out.throttle = 0.0 if inp.brake > 0.05 else 1.0
	return out


## A camera effect (shake in pixels, the nitro FOV stretch) after the screen shake option:
## the designed amount at 10, none at 0, never more than designed.
func shake_amount(designed: float) -> float:
	return designed * clampi(screen_shake, 0, EFFECT_STEPS) / float(EFFECT_STEPS)


## A flash's strength (alpha, or how far a blink goes) after the flash option, as above.
func flash_amount(designed: float) -> float:
	return designed * clampi(flash, 0, EFFECT_STEPS) / float(EFFECT_STEPS)


## A car's speed (world units per second) as the speedometer shows it in `in_units`:
## Cfg.DISPLAY_TOP_SPEED mph at Cfg.MAX_SPEED, rounded.
static func speed_in(speed: float, in_units: int) -> int:
	var mph := speed / Cfg.MAX_SPEED * Cfg.DISPLAY_TOP_SPEED
	return roundi(mph * KPH_PER_MPH if in_units == Units.KPH else mph)


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
