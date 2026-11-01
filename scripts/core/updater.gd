class_name Updater
extends Node
## Autoload ("Updates", EQ-14): download the game once, and it keeps itself up to date from
## GitHub Releases.
##
## A release's game is its .pck (scripts, art, sound); the app around it is Godot's engine,
## which only changes with Godot's version. So each release also publishes
## SundownRun-X.Y.Z.pck and SundownRun-X.Y.Z.json (version, engine, size, SHA-256;
## tools/export.sh). On start this asks GitHub for the latest release; when it's newer and
## for this engine, the UpdateScreen downloads its pack into user://updates/, checks the
## SHA-256, records it in current.json and restarts the game, and BootTree loads it over the
## built-in game at every start until a newer full download replaces it. A release for
## another engine needs a full download: the screen links to the releases page.
##
## Only exported desktop builds check (`supported`); a checkout and the Web build never
## touch the network. Nothing is sent but the requests.

enum State { OFF, IDLE, CHECKING, LATEST, AVAILABLE, FULL, DOWNLOADING, READY, FAILED }

const API := "https://api.github.com/repos/%s/releases/latest"
const PAGE := "https://github.com/%s/releases/latest"
const REPO := "austinthedeveloper/arcade-racer"  # must be public: the API is asked without signing in
const NAME := "SundownRun-%s"  # a release's update files: NAME.pck and NAME.json
const HEADERS := ["User-Agent: SundownRun", "Accept: application/vnd.github+json"]
const ASK_TIMEOUT := 30.0  # seconds for an answer about the release
## Seconds a download may go without a byte before it's given up. Not a limit on the whole
## download: 18 MB on a slow line takes minutes.
const STALL_TIMEOUT := 30.0

## Where updates go. BootTree reads BootTree.CURRENT, so only tests change this.
var dir := "user://updates/"
## The latest-release URL. --update-api=URL asks another server (a local stand-in for GitHub,
## to try an exported build's update end to end).
var api := API % REPO
var state := State.OFF
var latest := ""  # the newest release's version
var error := ""  # why it FAILED, for the screen
var manifest := {}  # the newest release's manifest
var last_url := ""  # the last request, for tests
var staged_progress := 0.0  # progress() without a download, for tests and screenshots

var _http: HTTPRequest
var _pck_url := ""
var _job := ""  # "release", "manifest" or "pck"
var _bytes := 0  # downloaded at the last new byte
var _stalled := 0.0  # seconds since then


func _ready() -> void:
	if not supported():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--update-api="):
			api = arg.trim_prefix("--update-api=")
	state = State.IDLE
	_http = HTTPRequest.new()
	_http.request_completed.connect(_on_done)
	add_child(_http)
	check.call_deferred()


## Exported desktop builds only.
static func supported() -> bool:
	return OS.has_feature("template") and not OS.has_feature("web")


## The version running: the update's when BootTree loaded one.
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## From GitHub's latest-release JSON: {version, manifest_url, pck_url}, or {} when it has no
## update files (v0.1.0, before the updater).
static func parse_release(r: Dictionary) -> Dictionary:
	var v := str(r.get("tag_name", "")).trim_prefix("v")
	var out := {"version": v, "manifest_url": "", "pck_url": ""}
	for a in r.get("assets", []):
		var n := str(a.get("name", ""))
		if n == (NAME % v) + ".json":
			out["manifest_url"] = a.get("browser_download_url", "")
		elif n == (NAME % v) + ".pck":
			out["pck_url"] = a.get("browser_download_url", "")
	if v == "" or out["manifest_url"] == "" or out["pck_url"] == "":
		return {}
	return out


func current_path() -> String:
	return dir + "current.json"


## The title was reached: a start on an update works, so BootTree won't skip it next time.
func mark_good() -> void:
	var c := BootTree.read_current(current_path())
	if bool(c.get("booting", false)) and str(c.get("version", "")) == version():
		c["booting"] = false
		BootTree.write_current(current_path(), c)


## Asks GitHub for the latest release.
func check() -> void:
	if state in [State.OFF, State.CHECKING, State.DOWNLOADING]:
		return
	error = ""
	manifest = {}
	state = State.CHECKING
	_job = "release"
	if not _request(api, ""):
		_fail("Couldn't reach GitHub.")


## Downloads the newest pack (when AVAILABLE).
func download() -> void:
	if state != State.AVAILABLE:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	state = State.DOWNLOADING
	_job = "pck"
	if not _request(_pck_url, dir + "download.part"):
		_fail("Couldn't start the download.")


func _process(dt: float) -> void:
	if _http != null and state == State.DOWNLOADING and watch(_http.get_downloaded_bytes(), dt):
		_http.cancel_request()


## One frame of the download with `bytes` down so far: FAILED (true) once no new byte has
## come for STALL_TIMEOUT seconds.
func watch(bytes: int, dt: float) -> bool:
	if bytes != _bytes:
		_bytes = bytes
		_stalled = 0.0
		return false
	_stalled += dt
	if _stalled < STALL_TIMEOUT:
		return false
	_fail("The download stopped.")
	return true


## 0..1 while DOWNLOADING.
func progress() -> float:
	if _http == null or state != State.DOWNLOADING:
		return staged_progress
	var total := maxi(_http.get_body_size(), int(manifest.get("size", 0)))
	return clampf(float(_http.get_downloaded_bytes()) / maxf(total, 1.0), 0.0, 1.0)


## READY: starts the game again (BootTree loads the update) and quits this one. False when
## the new process didn't start (or this isn't an exported build): the update is installed
## all the same, and opening the game again starts it.
func restart() -> bool:
	if state != State.READY or not supported():
		return false
	if OS.create_process(OS.get_executable_path(), []) <= 0:
		return false
	get_tree().quit()
	return true


## FULL: the releases page, for the full download.
func open_page() -> void:
	OS.shell_open(PAGE % REPO)


## GitHub's answer about the latest release.
func on_release(r: Dictionary) -> void:
	var rel := parse_release(r)
	latest = rel.get("version", str(r.get("tag_name", "")).trim_prefix("v"))
	if BootTree.compare(latest, version()) <= 0:
		state = State.LATEST
	elif rel.is_empty():
		state = State.FULL  # newer, but without update files
	else:
		_pck_url = rel["pck_url"]
		_job = "manifest"
		if not _request(rel["manifest_url"], ""):
			_fail("Couldn't reach GitHub.")


## The newest release's manifest: the pack is for this engine, or it needs a full download.
func on_manifest(m: Dictionary) -> void:
	manifest = m
	state = State.AVAILABLE if str(m.get("engine", "")) == BootTree.engine() else State.FULL


## The download finished into `part`: checked, kept as the update, older packs removed.
func on_pck(part: String) -> void:
	if FileAccess.get_sha256(part) != str(manifest.get("sha256", "")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		_fail("The download was damaged.")
		return
	var file := dir + (NAME % latest) + ".pck"
	DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(file))
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".pck") and dir + f != file:
				d.remove(f)
	BootTree.write_current(current_path(), {"version": latest, "engine": BootTree.engine(), "file": file, "booting": false})
	state = State.READY


func _request(url: String, to_file: String) -> bool:
	last_url = url
	if _http == null:
		return true  # tests answer with on_release / on_manifest / on_pck
	_http.download_file = to_file
	_http.timeout = 0.0 if to_file != "" else ASK_TIMEOUT  # a download is watched for stalls instead
	_bytes = 0
	_stalled = 0.0
	return _http.request(url, HEADERS) == OK


func _fail(why: String) -> void:
	error = why
	state = State.FAILED


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("No connection." if _job != "pck" else "The download stopped.")
		return
	if code != 200:
		_fail("GitHub said %d." % code)
		return
	match _job:
		"release", "manifest":
			var v = JSON.parse_string(body.get_string_from_utf8())
			var d: Dictionary = v if v is Dictionary else {}
			if _job == "release":
				on_release(d)
			else:
				on_manifest(d)
		"pck":
			on_pck(dir + "download.part")
