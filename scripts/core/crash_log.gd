class_name CrashLog
extends Logger
## Crash log (EQ-20): every error the engine reports (a GDScript runtime error, push_error,
## an engine error) writes a report to user://logs/crash_report.txt: the game's version,
## the engine and OS, the errors with their GDScript backtraces, and the last LINES lines
## the game printed. The title's version line offers COPY REPORT while a report is there
## (TitleScreen), so a player can paste it into a bug report.
##
## A Logger the game adds with `install` (game.gd, at the main scene's start: no autoload,
## see BootTree). Godot calls it from any thread, so it holds a mutex, and it never prints
## (that would come straight back here).

const DIR := "user://logs/"
const REPORT := "crash_report.txt"
const LINES := 200  # log lines a report keeps
const MAX_ERRORS := 20  # errors a report lists (the first ones, which usually cause the rest)
## Reports written straight away; after that, at most one every THROTTLE_MSEC (an error
## in _process repeats every frame).
const FREE_WRITES := 5
const THROTTLE_MSEC := 2000

## The logger the game installed (install), or null.
static var installed: CrashLog

var dir := DIR
var lines: PackedStringArray = []  # the last LINES log lines, oldest first
var errors: PackedStringArray = []  # this run's first MAX_ERRORS errors
var error_count := 0
var writes := 0  # reports written
var dirty := false  # an error not yet in the written report
var _last_write := -THROTTLE_MSEC
var _mutex := Mutex.new()
var _busy := false  # inside write: an error there mustn't come back in


func _init(log_dir := DIR) -> void:
	dir = log_dir


## Adds the game's crash log, writing to `log_dir`, once a run: a later call (a second
## main scene in tests) keeps the first, so the test runners install theirs into scratch.
static func install(log_dir := DIR) -> CrashLog:
	if installed == null:
		installed = CrashLog.new(log_dir)
		OS.add_logger(installed)
	return installed


static func uninstall() -> void:
	if installed != null:
		OS.remove_logger(installed)
		installed = null


## Where the report goes in `log_dir`.
static func report_path(log_dir := DIR) -> String:
	return log_dir.path_join(REPORT)


## The report to copy: the installed log's own when it has errors not yet written, else
## the one on disk ("" when there's none).
static func current_report(log_dir := "") -> String:
	if installed != null and log_dir in ["", installed.dir]:
		installed.flush()
		log_dir = installed.dir
	if log_dir == "":
		log_dir = DIR
	var path := report_path(log_dir)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Whether there's a report to copy.
static func has_report(log_dir := "") -> bool:
	if installed != null and log_dir in ["", installed.dir]:
		return installed.error_count > 0 or FileAccess.file_exists(report_path(installed.dir))
	return FileAccess.file_exists(report_path(DIR if log_dir == "" else log_dir))


## Puts the report on the clipboard through `set_clipboard` (a Callable taking the text;
## DisplayServer's clipboard by default, which a headless run doesn't have). False when
## there's no report or no clipboard.
static func copy_report(log_dir := "", set_clipboard := Callable()) -> bool:
	var text := current_report(log_dir)
	if text == "":
		return false
	if not set_clipboard.is_valid():
		if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			return false
		set_clipboard = DisplayServer.clipboard_set
	set_clipboard.call(text)
	return true


func _log_message(message: String, _error: bool) -> void:
	add_lines(message)


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var traces: PackedStringArray = []
	for bt in script_backtraces:
		if bt != null and not bt.is_empty():
			traces.append(bt.format())
	var text := describe(function, file, line, code, rationale, error_type, traces)
	if error_type == ERROR_TYPE_WARNING:
		add_lines(text)
	else:
		record_error(text)


## An error as Godot prints it: the kind and message, where, and the backtraces.
static func describe(function: String, file: String, line: int, code: String, rationale: String,
		error_type: int, traces: PackedStringArray = []) -> String:
	var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
	var out := "%s: %s\n   at: %s (%s:%d)" % [kind, rationale if rationale != "" else code, function, file, line]
	for t in traces:
		out += "\n   " + t.strip_edges().replace("\n", "\n   ")
	return out


## Keeps `text`'s lines, the last LINES of them.
func add_lines(text: String) -> void:
	_mutex.lock()
	for l in text.trim_suffix("\n").split("\n"):
		lines.append(l)
	if lines.size() > LINES:
		lines = lines.slice(lines.size() - LINES)
	_mutex.unlock()


## An error: into the log lines and the report's error list, and the report written
## (straight away for the first FREE_WRITES, then at most every THROTTLE_MSEC).
func record_error(text: String, now_msec := -1) -> void:
	add_lines(text)
	_mutex.lock()
	error_count += 1
	if errors.size() < MAX_ERRORS:
		errors.append(text)
	dirty = true
	_mutex.unlock()
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if writes < FREE_WRITES or now - _last_write >= THROTTLE_MSEC:
		write(now)


## Writes the report when an error isn't in it yet.
func flush() -> void:
	if dirty:
		write()


## The report's text: what ran, the errors, then the last log lines.
func report() -> String:
	_mutex.lock()
	var out := PackedStringArray([
		"Sundown Run %s crash report" % ProjectSettings.get_setting("application/config/version", "?"),
		"%s, Godot %s, %s %s" % [Time.get_datetime_string_from_system(true, true) + " UTC",
			Engine.get_version_info()["string"], OS.get_name(), OS.get_version()],
		"%s, %s" % [RenderingServer.get_current_rendering_method(), OS.get_processor_name()],
		"",
		"--- errors (%d; the first %d) ---" % [error_count, errors.size()] if error_count > errors.size()
			else "--- errors (%d) ---" % error_count,
	])
	out.append_array(errors)
	out.append("")
	out.append("--- the last %d log lines ---" % lines.size())
	out.append_array(lines)
	_mutex.unlock()
	return "\n".join(out) + "\n"


## Writes the report to `dir`; false when it can't.
func write(now_msec := -1) -> bool:
	if _busy:
		return false
	_busy = true
	var text := report()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("user://") else dir)
	var f := FileAccess.open(report_path(dir), FileAccess.WRITE)
	var ok := f != null
	if ok:
		f.store_string(text)
		f.close()
		writes += 1
		dirty = false
		_last_write = Time.get_ticks_msec() if now_msec < 0 else now_msec
	_busy = false
	return ok
