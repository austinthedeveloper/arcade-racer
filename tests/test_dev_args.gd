## The command line's dev flags (DevArgs): --settings-file=, --car=, --shot-as-window ...
extends TestSuite


static func _args(list: Array) -> PackedStringArray:
	return PackedStringArray(list)


func test_value_reads_the_flag() -> void:
	var a := _args(["--autodrive", "--settings-file=/tmp/opts.cfg", "--car=car_mesa"])
	eq(DevArgs.value_in(a, "--settings-file"), "/tmp/opts.cfg", "a path")
	eq(DevArgs.value_in(a, "--car", "car_vega"), "car_mesa", "given: not the default")


func test_value_falls_back_to_the_default() -> void:
	var a := _args(["--autodrive"])
	eq(DevArgs.value_in(a, "--out", "user://track_preview"), "user://track_preview", "missing: the default")
	eq(DevArgs.value_in(a, "--out"), "", "no default: empty")
	eq(DevArgs.value_in(_args([]), "--stage", "0"), "0", "no arguments at all")


func test_value_matches_the_whole_flag() -> void:
	var a := _args(["--car-colour=red", "--carx=1", "--car"])
	eq(DevArgs.value_in(a, "--car", "none"), "none", "a longer flag or a bare one isn't --car=")


func test_the_last_one_wins_and_keeps_its_equals_signs() -> void:
	var a := _args(["--stage=2", "--stage=5"])
	eq(DevArgs.value_in(a, "--stage"), "5", "the last")
	var url := _args(["--update-api=http://127.0.0.1:8000/latest?x=1"])
	eq(DevArgs.value_in(url, "--update-api"), "http://127.0.0.1:8000/latest?x=1", "everything after the first =")
	eq(DevArgs.value_in(_args(["--out="]), "--out", "dflt"), "", "an empty value is a value")


func test_has_is_a_bare_flag() -> void:
	var a := _args(["--shot-as-window", "--screen=pause"])
	check(DevArgs.has_in(a, "--shot-as-window"), "given")
	check(not DevArgs.has_in(a, "--no-traffic"), "not given")
	check(not DevArgs.has_in(a, "--screen"), "a flag with a value isn't a bare flag")


func test_the_test_run_passes_no_dev_flags() -> void:
	# The runner's only user argument is an optional suite filter, never a --flag=.
	eq(DevArgs.value("--settings-file", "unset"), "unset", "settings file")
	check(not DevArgs.has("--shot-as-window"), "shot as window")
