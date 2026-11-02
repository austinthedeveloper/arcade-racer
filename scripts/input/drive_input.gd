class_name DriveInput
extends RefCounted
## The one normalized control state gameplay reads, whatever device produced it.

enum Kind { KEYBOARD, GAMEPAD, WHEEL }

var steer := 0.0  # -1 full left .. 1 full right
var throttle := 0.0  # 0..1
var brake := 0.0  # 0..1
var nitro_pressed := false  # edge: true only on the tick it was pressed
var pause_pressed := false
var restart_pressed := false
var confirm_pressed := false
var horn := false  # held: RaceAudio sounds it, the car ahead gives way (Traffic.honk, RC-13)
var radio_pressed := false  # edge: the next station (RaceAudio)
var view_pressed := false  # edge: the next camera view (CameraView, WS-15)
var photo_pressed := false  # edge: a picture of the race without the HUD (Photo, PR-21)
var shift_up_pressed := false  # edge: one gear up (manual gears only, PlayerCar.shift)
var shift_down_pressed := false  # edge: one gear down
var kind := Kind.KEYBOARD
var device_name := "Keyboard"
## False for a pad without a standard gamepad layout (most likely a wheel or pedals not
## recognized by name): it has no stick for up and down, so menus let it steer instead.
var mapped := true


## A field-by-field copy, including any field added later.
func copy() -> DriveInput:
	var out := DriveInput.new()
	for prop in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.set(prop["name"], get(prop["name"]))
	return out
