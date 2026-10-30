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
var kind := Kind.KEYBOARD
var device_name := "Keyboard"
