## Soak test (EQ-22): races every stage, car and difficulty headless with random inputs and
## checks each race for what should never happen (a NaN, a car off the edge of the world, a
## race that never ends, a rival that never finishes). tools/soak.sh runs it and also fails on
## any SCRIPT ERROR or engine error printed on the way; CI runs it nightly (.github/workflows/soak.yml).
##
##   godot --headless --path . -s res://tests/soak.gd -- [--stages=1,3] [--cars=car_vega,car_mesa]
##       [--difficulties=easy,hard] [--seed=N] [--quick]
##   godot --headless --path . -s res://tests/soak.gd -- --report [--detail] [--draws=N] [--stages=...]
##       [--difficulties=...] [--tuning-file=PATH] [--driver=casual]
##
## --quick: one car per stage and difficulty (the cars taken in turn), for a local run. --report
## drives each stage and difficulty with the autodrive instead (traffic and rivals, the
## Vega, the difficulty's own timer) and prints the field's finishing gaps (RC-21); --detail
## adds each racer's crashes and finish; --draws=N races N fields per stage (the game's own, then
## N-1 other draws of the drivers) and adds their means. --tuning-file runs on that file's
## tuning, not the defaults. --driver=casual drives as a casual player (CasualDriver) instead
## of the autodrive, and checks no band: Easy is judged by it.
class_name Soak
extends SceneTree

const LEVELS := ["easy", "normal", "hard"]  # Difficulty.Level order, for --difficulties
## Seconds of race (the field's clock, Rivals.clock) by which every rival is home, or it
## counts as stuck: about twice the slowest stage's race.
const RIVALS_HOME_BY := 200.0
## RC-21: per difficulty (Difficulty.Level order), the field's finishing spread (first to
## last across the line, the autodrive among them, seconds) at most, and the places the
## autodrive may finish in (best, worst). Every stage's autodriven race stays in its band:
## test_golden checks Normal on the golden traces and Easy and Hard in a test of their own.
## From the balance pass's report (docs/roadmap/01-racing-core.md, RC-21) and what the crash
## feel (RC-22) then moved: a play change reshuffles a close field by a place or two and a
## straggler by a few seconds, so the bands hold what several draws of the field showed.
const BANDS := [
	{"spread": 50.0, "places": [1, 4]},  # easy: slower rivals the autodrive runs away from
	{"spread": 38.0, "places": [1, 6]},  # normal
	{"spread": 38.0, "places": [1, 7]},  # hard: quicker rivals that hardly wait; not last
]
## A stage whose field spreads further by design, by stage id (Stages.POSTCARDS): the spread
## it may have on every difficulty. Skyline's downtown jam (RC-20) holds whoever reaches it
## among the traffic for half a minute; the rest of the field is home by then.
const STAGE_SPREAD := {"skyline": 46.0}
## RC-23: seconds the autodrive has left at least, arriving at every checkpoint and the line,
## on every difficulty (its own timer and checkpoint bonuses).
const CLOCK_MARGIN := 2.0

var failures := 0


## A race scene ready to run, outside the tree, in `car_id`; difficulty and every other
## option come from Settings, as in a race picked from the menus.
static func new_race(stage: int, car_id: String, autodrive: bool, mirror := false) -> Node:
	var r: Node = load("res://scenes/race.tscn").instantiate()
	r.set("stage_index", stage)
	r.set("mirror", mirror)
	r.set("car_id", car_id)
	r.set("_autodrive", autodrive)
	TestSuite.ready_all(r)
	r.instant_replay = false
	return r


## Runs the race on until every rival is home or the field's clock (Rivals.clock) reaches
## `by` seconds; ticks run.
static func run_rivals_home(r: Node, by: float = RIVALS_HOME_BY) -> int:
	var ticks := 0
	while r.rivals.finished_count() < r.rivals.cars.size() and r.rivals.clock < by and ticks < int(by * 60.0) + 600:
		r._physics_process(TestSuite.DT)
		ticks += 1
	return ticks


## The field's finish, the autodrive (or player) among them: {"times": every finish time,
## sorted, "player": its time (-1 if it didn't finish), "place", "spread": first to last,
## "winner_gap": the player's time behind the winner}. Rivals still out are left out.
static func field(r: Node) -> Dictionary:
	var times: Array[float] = []
	for rv: RivalCar in r.rivals.cars:
		if rv.finished:
			times.append(rv.finish_time)
	var mine: float = r.player_finish
	if mine >= 0.0:
		times.append(mine)
	times.sort()
	var spread := times[-1] - times[0] if times.size() > 1 else 0.0
	return {"times": times, "player": mine, "place": r.place, "spread": spread,
		"winner_gap": mine - times[0] if mine >= 0.0 and not times.is_empty() else NAN}


## Drives `stage` on `level` with the autodrive (traffic, rivals, the Vega, the level's own
## timer) until the field is home, and returns field() of it, with "clock": the least time
## left on the clock arriving at a checkpoint or the line (seconds; below zero, the clock ran
## out first), and "crashes": each racer's crashes, the player's first. The clock is kept
## from running out, so the field is measured whatever it says. Leaves Settings as it found them.
static func autodrive_field(settings: Node, stage: int, level: int, draw := 0, casual := false) -> Dictionary:
	var keep_level: int = settings.difficulty
	var keep_timer: int = settings.timer
	settings.set_difficulty(level)
	var r := new_race(stage, "car_vega", true)
	r.casual = casual
	if draw != 0:  # another field than the game's own (Rivals.SEED + stage)
		r.rivals.spawn(r.track, r.player, "car_vega", Rivals.COUNT, Rivals.SEED + stage + 1000 * draw, r.difficulty,
			[], Rivals.stage_pace_of(stage))
	var lent := 0.0  # seconds put on the clock to keep it from running out
	var least := INF
	var arrivals: Array[float] = []  # race time at each checkpoint, then the line
	var cp: int = r.next_checkpoint
	var crashes := {}
	var limit := 20000
	while r.state != r.State.FINISHED and r.state != r.State.TIME_UP and limit > 0:
		if r.state == r.State.RACING and r.time_left < 1.0:
			r.time_left += 1000.0
			lent += 1000.0
		var left: float = r.time_left - lent
		r._physics_process(TestSuite.DT)
		if r.next_checkpoint != cp or r.state == r.State.FINISHED:
			cp = r.next_checkpoint
			least = minf(least, left)
			arrivals.append(r.race_time)
		_count_crashes(r, crashes)
		limit -= 1
	while r.rivals.finished_count() < r.rivals.cars.size() and r.rivals.clock < RIVALS_HOME_BY:
		r._physics_process(TestSuite.DT)
		_count_crashes(r, crashes)
	var out := field(r)
	out["clock"] = least
	out["arrivals"] = arrivals
	out["timed_out"] = r.state != r.State.FINISHED or least < 0.0
	out["rivals_home"] = r.rivals.finished_count()
	var counts: Array[int] = []
	for c in r.rivals.everyone(r.player):
		counts.append(crashes.get(c, 0))
	out["crashes"] = counts
	var who := PackedStringArray()
	for rv: RivalCar in r.rivals.cars:
		who.append("%s %s" % [rv.profile.driver, "%.1f" % rv.finish_time if rv.finished else "out"])
	out["rivals"] = who
	r.free()
	settings.difficulty = keep_level
	settings.timer = keep_timer
	return out


static func _count_crashes(r: Node, into: Dictionary) -> void:
	for c: PlayerCar in r.rivals.everyone(r.player):
		if c.crashed:
			into[c] = into.get(c, 0) + 1


## The spread a field on `stage` may have on `level` (BANDS, STAGE_SPREAD).
static func spread_for(stage: int, level: int) -> float:
	return STAGE_SPREAD.get(Stages.POSTCARDS[stage], BANDS[level]["spread"])


## Whether a field (field()) on `stage` is in its difficulty's band (BANDS); "" if so, or
## what's out. `clock`: a clock that ran out (autodrive_field) counts too.
static func out_of_band(f: Dictionary, level: int, stage: int, clock := true) -> String:
	var band: Dictionary = BANDS[level]
	var why := PackedStringArray()
	if clock and (f.get("timed_out", false) or f.get("clock", INF) < CLOCK_MARGIN):
		why.append("the clock ran out (%.1f s)" % f.get("clock", NAN) if f.get("timed_out", false)
			else "only %.1f s on the clock at a checkpoint" % f.get("clock", NAN))
	if f["spread"] > spread_for(stage, level):
		why.append("spread %.1f s over %.1f" % [f["spread"], spread_for(stage, level)])
	if f["place"] < band["places"][0] or f["place"] > band["places"][1]:
		why.append("placed %d, not %d-%d" % [f["place"], band["places"][0], band["places"][1]])
	return ", ".join(why)


## A random driver: holds a random input for a random while, mostly flat out and mostly
## steering for the road, with now and then a brake, a swerve, nitro, the horn or a shift.
class RandomDriver:
	var rng := RandomNumberGenerator.new()
	var hold := 0.0
	var inp := DriveInput.new()
	var wild := false  # this while, steering anywhere rather than for the road

	func _init(seed_value: int) -> void:
		rng.seed = seed_value

	func next(r: Node, dt: float) -> DriveInput:
		hold -= dt
		if hold <= 0.0:
			hold = rng.randf_range(0.15, 1.5)
			inp = DriveInput.new()
			inp.throttle = 1.0 if rng.randf() < 0.85 else rng.randf()
			inp.brake = rng.randf() if rng.randf() < 0.12 else 0.0
			wild = rng.randf() < 0.3
			inp.steer = rng.randf_range(-1.0, 1.0)
			inp.horn = rng.randf() < 0.1
		var out := inp.copy()
		if not wild:  # toward a spot near the middle, so most races get somewhere
			var p: PlayerCar = r.player
			var seg: Segment = r.track.find_segment(p.position + Cfg.PLAYER_Z + 3000.0)
			out.steer = clampf(seg.curve * 0.25 + (inp.steer * 0.5 - p.x) * 1.5, -1.0, 1.0)
		out.nitro_pressed = rng.randf() < 0.005
		out.shift_up_pressed = r.player.manual and (r.player.on_limiter() or rng.randf() < 0.01)
		out.shift_down_pressed = r.player.manual and rng.randf() < 0.01
		return out


## One random race: `stage` in `car_id` on `level`, options shuffled by `seed_value`. Returns
## what went wrong ("" for nothing).
static func soak_race(settings: Node, router: Node, stage: int, car_id: String, level: int, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	settings.set_difficulty(level)
	settings.timer = rng.randi() % settings.Clock.size()
	settings.traffic = rng.randi() % settings.TRAFFIC_MULT.size()
	settings.power_ups = rng.randf() < 0.8
	settings.manual_gears = rng.randf() < 0.3
	settings.reduce_motion = rng.randf() < 0.2
	var mirror := rng.randf() < 0.3
	var r := new_race(stage, car_id, false, mirror)
	var driver := RandomDriver.new(seed_value)
	var keep: DriveInput = router.state
	var why := ""
	var ticks := 0
	var limit := 60 * 400  # longer than the most any clock allows (RELAXED, every bonus)
	while r.state != r.State.FINISHED and r.state != r.State.TIME_UP and ticks < limit:
		router.state = driver.next(r, TestSuite.DT)
		r._physics_process(TestSuite.DT)
		ticks += 1
		why = broken(r)
		if why != "":
			why = "at %.1f s: %s" % [r.race_time, why]
			break
	router.state = DriveInput.new()
	if why == "" and ticks >= limit:
		why = "the race never ended (%d ticks)" % ticks
	if why == "":
		run_rivals_home(r)
		if r.rivals.finished_count() < r.rivals.cars.size():
			var out := PackedStringArray()
			for rv: RivalCar in r.rivals.cars:
				if not rv.finished:
					out.append("%s %.0f short at %.0f" % [rv.profile.driver, r.finish_distance - rv.distance, rv.speed])
			why = "%d of %d rivals never finished (%s)" % [out.size(), r.rivals.cars.size(), ", ".join(out)]
		else:
			why = broken(r)
	var ended := "FINISHED" if r.state == r.State.FINISHED else "TIME UP"
	print("  %s  %-10s %-12s %-6s %s%s  %.1f s  %s" % ["ok  " if why == "" else "FAIL",
		r.track.name.left(10), car_id, LEVELS[level], "mirrored " if mirror else "", ended, r.race_time, why])
	router.state = keep
	r.free()
	return why


## Whatever's impossible about the race right now, "" for nothing.
static func broken(r: Node) -> String:
	var cars: Array = r.rivals.everyone(r.player)
	for c: PlayerCar in cars:
		for v: float in [c.distance, c.position, c.x, c.speed, c.air_height, c.crash_time]:
			if is_nan(v) or is_inf(v):
				return "a car's state is not a number"
		if absf(c.x) > Cfg.MAX_X + 0.001:
			return "a car is past the edge of the world (x %.2f)" % c.x
		if c.speed < 0.0 or c.speed > Cfg.MAX_SPEED * 3.0:
			return "a car's speed is %.0f" % c.speed
		if c.position < 0.0 or c.position > r.track.length:
			return "a car is off the track (%.0f)" % c.position
	for t in r.traffic.cars:
		if is_nan(t.z) or is_nan(t.offset):
			return "a traffic car's state is not a number"
	if is_nan(r.time_left) or r.time_left < 0.0:
		return "the clock is %.2f" % r.time_left
	if r.place < 1 or r.place > cars.size():
		return "placed %d" % r.place
	return ""


## What `--flag=...` says on the command line, or `default`. (Not DevArgs: a script run with
## -s compiles before the autoloads exist, and DevArgs reaches Settings.)
static func arg_value(flag: String, default := "") -> String:
	var out := default
	for a in OS.get_cmdline_user_args():
		if a.begins_with(flag + "="):
			out = a.trim_prefix(flag + "=")
	return out


static func _list(arg: String, all: Array) -> Array:
	var v := arg_value(arg)
	if v == "":
		return all
	return Array(v.split(","))


func _initialize() -> void:
	TestSuite.begin_run()
	TestSuite.use_scratch_profiles(root.get_node("InputRouter"))
	TestSuite.use_scratch_settings(root.get_node("Settings"))
	TestSuite.use_scratch_save(root.get_node("SaveData"))
	TestSuite.use_scratch_ghosts()
	TestSuite.use_scratch_logs()
	Tuning.use_defaults()
	if arg_value("--tuning-file") != "":  # trying out tuning before it's adopted (EQ-17)
		Tuning.load_file(arg_value("--tuning-file"))
		print("tuning: ", Tuning.overrides())
	SpriteLibrary.load_all()
	CarSprites.load_all()
	var stages: Array[int] = []
	for s in _list("--stages", range(1, Stages.count() + 1)):
		stages.append(clampi(int(s) - 1, 0, Stages.count() - 1))
	var levels: Array[int] = []
	for l in _list("--difficulties", LEVELS):
		var i := LEVELS.find(String(l).to_lower())
		if i < 0:
			printerr("unknown difficulty: ", l)
			quit(2)
			return
		levels.append(i)
	var t0 := Time.get_ticks_msec()
	if OS.get_cmdline_user_args().has("--report"):
		report(stages, levels)
	else:
		var cars: Array = []
		for c: Dictionary in Cars.LIST:
			cars.append(c["id"])
		cars = _list("--cars", cars)
		var seed_value := int(arg_value("--seed", "2201"))
		var quick := OS.get_cmdline_user_args().has("--quick")
		var n := 0
		var races := 0
		for s in stages:
			for l in levels:
				var picked: Array = [cars[n % cars.size()]] if quick else cars
				n += 1
				for c: String in picked:
					races += 1
					if soak_race(root.get_node("Settings"), root.get_node("InputRouter"), s, c, l, seed_value + races * 7919) != "":
						failures += 1
		print("\nsoak: %d races, %d failed (%d s)" % [races, failures, (Time.get_ticks_msec() - t0) / 1000])
	quit(1 if failures > 0 else 0)


## --report: the field's finishing gaps per stage and difficulty, as a table for
## docs/roadmap/01-racing-core.md (RC-21), each against its band.
func report(stages: Array[int], levels: Array[int]) -> void:
	var detail := OS.get_cmdline_user_args().has("--detail")
	var draws := maxi(1, int(arg_value("--draws", "1")))
	var casual := arg_value("--driver") == "casual"
	if casual:
		print("driver: casual (CasualDriver), no band check")
	print("| Stage | Difficulty | Autodrive | Place | Winner | Last | Spread | Clock | Band |")
	print("|---|---|---|---|---|---|---|---|---|")
	for s in stages:
		for l in levels:
			var spreads := 0.0
			var places := 0.0
			for d in draws:
				var f := autodrive_field(root.get_node("Settings"), s, l, d, casual)
				var times: Array = f["times"]
				var why := "" if casual else out_of_band(f, l, s)
				if why != "" and d == 0:
					failures += 1  # (only the game's own field: the other draws are for the means)
				spreads += f["spread"]
				places += f["place"]
				print("| %s%s | %s | %.1f | %s | %.1f | %.1f | %.1f | %.1f | %s |" % [Stages.build(s).name,
					" (draw %d)" % d if d > 0 else "", LEVELS[l].capitalize(), f["player"], Rivals.ordinal(f["place"]),
					times[0] if not times.is_empty() else NAN, times[-1] if not times.is_empty() else NAN, f["spread"],
					f["clock"], "ok" if why == "" else why])
				if detail:
					print("    crashes (player first) %s; %s" % [str(f["crashes"]), ", ".join(f["rivals"])])
					print("    at the checkpoints and the line %s" % str(f["arrivals"]))
			if draws > 1:
				print("|   mean of %d | %s | | %.1f | | | %.1f | | |" % [draws, LEVELS[l].capitalize(), places / draws, spreads / draws])


func _finalize() -> void:
	TestSuite.end_run()
