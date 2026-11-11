## Writes this build's save compatibility fixture (EQ-27, SaveFixture) when a release is cut
## (docs/10-releases.md):
##
##   godot --headless --path . -s res://tests/write_save_fixture.gd [-- --version=0.7.0 --out=DIR]
##
## A script run with -s is compiled before the autoloads exist, so it can't name them (or a
## class that does, like SaveFixture) as globals; this loads SaveFixture once they're up.
extends SceneTree


func _initialize() -> void:
	_write.call_deferred()


func _write() -> void:
	var args := OS.get_cmdline_user_args()
	var version := _arg(args, "--version", str(ProjectSettings.get_setting("application/config/version")))
	var fixture: GDScript = load("res://tests/save_fixture.gd")
	var out := _arg(args, "--out", fixture.DIR + "v" + version)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	fixture.write_all(out)
	print("wrote ", out)
	quit()


static func _arg(args: PackedStringArray, flag: String, default: String) -> String:
	for a in args:
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return default
