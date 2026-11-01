class_name DevArgs
extends RefCounted
## The dev flags after `--` on the command line (`godot --path . -- --settings-file=PATH`).
## `value_in` and `has_in` take the arguments, so tests can hand them some.


## What the last `flag=...` says (`flag` with its dashes, e.g. "--out"), or `default`.
static func value(flag: String, default := "") -> String:
	return value_in(OS.get_cmdline_user_args(), flag, default)


## Whether `flag` (e.g. "--shot-as-window") was given on its own.
static func has(flag: String) -> bool:
	return has_in(OS.get_cmdline_user_args(), flag)


static func value_in(args: PackedStringArray, flag: String, default := "") -> String:
	var prefix := flag + "="
	var out := default
	for arg in args:
		if arg.begins_with(prefix):
			out = arg.trim_prefix(prefix)
	return out


static func has_in(args: PackedStringArray, flag: String) -> bool:
	return args.has(flag)


## A 640x360 shot laid out as `win` shows it (`--shot-as-window`): scaled and bordered by
## the window's own size and stretch, for checking the display options and the HUD.
static func as_window(view: Image, win: Window) -> Image:
	var integer := win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER
	var r := Settings.view_rect(win.size, view.get_size(), integer)
	print("window %s, %s stretch, picture at %s" % [win.size, "integer" if integer else "fractional", r])
	var out := Image.create(win.size.x, win.size.y, false, view.get_format())
	out.fill(Color.BLACK)
	view.resize(r.size.x, r.size.y, Image.INTERPOLATE_NEAREST)
	out.blit_rect(view, Rect2i(Vector2i.ZERO, r.size), r.position)
	return out
