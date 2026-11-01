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
