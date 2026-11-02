class_name Photo
extends Control
## The photo key (PR-21): F12, or a button bound to PHOTO, saves a picture of the race with
## the HUD hidden for that frame to user://screenshots/, with a shutter sound and a white
## flash that the flash option scales (Settings.flash_amount). The race hides its HUD layer
## (Race.begin_photo), grabs the frame and hands it here (Race.finish_photo); this node is
## the flash, drawn over the HUD, the pause menu and the results.

const DIR := "user://screenshots"
const FLASH_TIME := 0.3  # seconds the flash takes to fade
const FLASH_ALPHA := 0.8  # how white it starts, as designed (the flash option at 10)

## Where photos go. Tests point it at their scratch folder.
static var dir := DIR

var flash_left := 0.0  # seconds left on the flash


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Starts the flash.
func flash() -> void:
	flash_left = FLASH_TIME
	queue_redraw()


## The flash one tick on.
func tick(dt: float) -> void:
	if flash_left <= 0.0:
		return
	flash_left = maxf(0.0, flash_left - dt)
	queue_redraw()


func _process(dt: float) -> void:
	tick(dt)


## How white the flash is with `left` seconds of it to go, after the flash option: 0 with
## the option at 0.
static func flash_alpha(left: float) -> float:
	return Settings.flash_amount(FLASH_ALPHA * clampf(left / FLASH_TIME, 0.0, 1.0))


func _draw() -> void:
	var a := flash_alpha(flash_left)
	if a > 0.0:
		draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(1, 1, 1, a))


## A photo's file name for the time `when` (Time.get_datetime_dict_from_system), the `n`th
## taken in that second after the first.
static func file_name(when: Dictionary, n := 0) -> String:
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [when.get("year", 0), when.get("month", 0), when.get("day", 0),
		when.get("hour", 0), when.get("minute", 0), when.get("second", 0)]
	return "photo_%s%s.png" % [stamp, "" if n == 0 else "_%d" % (n + 1)]


## Saves `img` into `folder` (made if it isn't there) under a name no other photo has.
## Returns its path, or "" when there was no picture or it couldn't be written.
static func save(img: Image, folder := dir, when := Time.get_datetime_dict_from_system()) -> String:
	if img == null or img.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	var n := 0
	while FileAccess.file_exists(folder.path_join(file_name(when, n))):
		n += 1
	var path := folder.path_join(file_name(when, n))
	return path if img.save_png(path) == OK else ""
