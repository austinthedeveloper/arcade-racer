## Base for test suites: assertions report to the runner and keep going.
class_name TestSuite
extends RefCounted

const SCRATCH_PROFILES := "user://test_input_profiles.cfg"
const SCRATCH_SETTINGS := "user://test_settings.cfg"
const SCRATCH_SAVE := "user://test_save.cfg"
const SCRATCH_GHOSTS := "user://test_ghosts"
const DT := 1.0 / 60.0

var runner
var asserts := 0
var _nodes: Array[Node] = []


## Points the InputRouter at an empty profile file of the tests' own.
static func use_scratch_profiles(router: Node) -> void:
	router.profile_path = SCRATCH_PROFILES
	if FileAccess.file_exists(SCRATCH_PROFILES):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PROFILES))
	router.load_profiles()


## Points the Settings autoload at an empty options file of the tests' own (all defaults).
static func use_scratch_settings(settings: Node) -> void:
	settings.path = SCRATCH_SETTINGS
	if FileAccess.file_exists(SCRATCH_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SETTINGS))
	settings.load_settings()


## Points the SaveData autoload at an empty save file of the tests' own (a fresh save).
static func use_scratch_save(save_data: Node) -> void:
	save_data.path = SCRATCH_SAVE
	for f in [SCRATCH_SAVE, SCRATCH_SAVE + ".bad", SCRATCH_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	save_data.load_save()


## Points Time Attack ghosts (Ghost.dir) at an empty folder of the tests' own.
static func use_scratch_ghosts() -> void:
	Ghost.dir = SCRATCH_GHOSTS
	var d := DirAccess.open(SCRATCH_GHOSTS)
	if d != null:
		for f in d.get_files():
			d.remove(f)


## A straight, flat track `segments` long, for driving tests.
static func flat_track(segments: int = 600) -> Track:
	var t := Track.new()
	for i in segments:
		t.add_segment(0.0, 0.0)
	t.finish_building(segments - 10)
	return t


## The race scene, ready, outside the tree (nothing draws or ticks on its own; tests
## call _physics_process). Autodrive, traffic, rivals and stage (index into Stages) as asked.
static func new_race(autodrive := false, traffic := true, stage := 0, rivals := true) -> Node:
	var r: Node = load("res://scenes/race.tscn").instantiate()
	r.set("stage_index", stage)
	r.set("_autodrive", autodrive)
	r.set("_no_traffic", not traffic)
	r.set("_no_rivals", not rivals)
	ready_all(r)
	return r


## Runs _ready on a node built outside the tree, and on everything under it.
static func ready_all(node: Node) -> void:
	node._ready()
	for n in node.find_children("*", "", true, false):
		if n.has_method("_ready"):
			n._ready()


## A race for this suite, freed after it.
func race(autodrive := false, traffic := true, stage := 0, rivals := true) -> Node:
	var r := new_race(autodrive, traffic, stage, rivals)
	_nodes.append(r)
	return r


## Steps the race `frames` physics ticks with the given input (autodrive overrides it).
func drive(r: Node, frames: int, inp: DriveInput = null) -> void:
	var router: Node = runner.root.get_node("InputRouter")
	var keep: DriveInput = router.state
	if inp != null:
		router.state = inp
	for i in frames:
		r._physics_process(DT)
	router.state = keep


## Runs the race until `cond` is true or `limit` ticks pass; returns ticks, or -1.
func run_until(r: Node, cond: Callable, limit: int = 20000, inp: DriveInput = null) -> int:
	for i in limit:
		if cond.call():
			return i
		drive(r, 1, inp)
	return -1


static func input(throttle := 0.0, steer := 0.0, brake := 0.0) -> DriveInput:
	var inp := DriveInput.new()
	inp.throttle = throttle
	inp.steer = steer
	inp.brake = brake
	return inp


func free_nodes() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func check(cond: bool, msg: String = "check failed") -> bool:
	asserts += 1
	if not cond:
		runner.fail(msg)
	return cond


func eq(actual, expected, msg: String = "") -> bool:
	asserts += 1
	if actual != expected:
		runner.fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])
		return false
	return true


func near(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> bool:
	asserts += 1
	if absf(actual - expected) > tolerance:
		runner.fail("%s expected %s (+-%s), got %s" % [msg, str(expected), str(tolerance), str(actual)])
		return false
	return true
