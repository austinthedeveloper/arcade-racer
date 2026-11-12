class_name Stickers
extends RefCounted
## The sticker book (MP-12): twenty-four stickers, each awarded once (SaveData.stickers) with a
## chime, shown on the stickers page (StickerScreen) beside the stats. Each sticker's condition
## is a plain function of a run's facts (`run`, the race builds them: race.gd sticker_run) and
## the save (`save`: the SaveData autoload, or a SaveData loaded from a fixture), so a test can
## ask any of them directly. A run that isn't the player's (an autodrive, a demo, a partway
## start, online) earns nothing, as it saves nothing.
##
## The run's facts (every key optional; a missing one counts as nothing happening):
##   finished, time_up: the run crossed the line, or ran out of time
##   stage (index into Stages), car (a car id), mode ("tour", "single", "time_attack",
##   "free_drive"), difficulty (Difficulty.Level), mirror
##   rivals, place (1 = first), traffic, touched_traffic, crashes
##   time (race seconds), timed (a clock ran), time_left
##   near_misses, best_chain, big_airs, slipstreams, launch (a LAUNCH! start), pickups
##   ghost_beaten (Time Attack: a saved ghost beaten), miles (this run's), tour_champion
##
## The list, its order on the page and the art (a shape, a color and a glyph or icon) are
## ALL; docs/roadmap/06-modes-and-progression.md has it in words.

enum Shape { CIRCLE, STAR, SHIELD, HEX, BADGE }

const FIVE_CHAIN := 5  # near misses in a chain (Scoring.chain)
const NEAR_MISSES := 10  # in one race
const SLIPSTREAMS := 3  # in one race
const PICKUPS := 5  # in one race
const LAST_GASP := 3.0  # seconds or less left on the clock at the line
const FREE_MILES := 5.0  # in one Free Drive
const LONG_HAUL := 100.0  # miles in all (SaveData.stats)

## Every sticker, in the page's order: id, name, how it's earned, shape, color, and a glyph
## (text) or an icon ("@flag", "@mirror", "@medal", "@ghost", "@crown", "@wind").
const ALL := [
	{"id": "first_finish", "name": "FIRST FINISH", "how": "Run a race to the line", "shape": Shape.CIRCLE, "color": "#3ad0ff", "glyph": "@flag"},
	{"id": "first_win", "name": "FIRST WIN", "how": "Win a race against rivals", "shape": Shape.STAR, "color": "#ffd23a", "glyph": "1ST"},
	{"id": "no_crash", "name": "NO CRASHES", "how": "Finish a race without a crash", "shape": Shape.SHIELD, "color": "#5dff8a", "glyph": "SAFE"},
	{"id": "untouched", "name": "UNTOUCHED", "how": "Finish without touching traffic", "shape": Shape.HEX, "color": "#9be8ff", "glyph": "CLEAN"},
	{"id": "chain_5", "name": "CHAIN OF FIVE", "how": "Chain five near misses", "shape": Shape.STAR, "color": "#ff5fa2", "glyph": "x5"},
	{"id": "near_miss_10", "name": "THREAD THE NEEDLE", "how": "Ten near misses in one race", "shape": Shape.BADGE, "color": "#ff8a3a", "glyph": "10"},
	{"id": "big_air", "name": "BIG AIR", "how": "Catch big air off a crest", "shape": Shape.CIRCLE, "color": "#7a8cff", "glyph": "AIR"},
	{"id": "drafter", "name": "SLIPSTREAMER", "how": "Slipstream three times in one race", "shape": Shape.HEX, "color": "#3affd2", "glyph": "@wind"},
	{"id": "launch", "name": "PERFECT LAUNCH", "how": "Get a LAUNCH! off the line", "shape": Shape.STAR, "color": "#ff4a4a", "glyph": "GO!"},
	{"id": "scavenger", "name": "SCAVENGER", "how": "Take five power-ups in one race", "shape": Shape.BADGE, "color": "#c97aff", "glyph": "+5"},
	{"id": "last_gasp", "name": "LAST GASP", "how": "Finish with 3 seconds or less left", "shape": Shape.SHIELD, "color": "#ffb13a", "glyph": "0:03"},
	{"id": "out_of_time", "name": "OUT OF TIME", "how": "Run the clock down to nothing", "shape": Shape.CIRCLE, "color": "#a0a6c0", "glyph": "0:00"},
	{"id": "mirror_win", "name": "LOOKING GLASS", "how": "Win a stage mirrored", "shape": Shape.HEX, "color": "#c9d4ff", "glyph": "@mirror"},
	{"id": "hard_win", "name": "HARD CHARGER", "how": "Win a race on Hard", "shape": Shape.SHIELD, "color": "#d92e4a", "glyph": "HARD"},
	{"id": "gold", "name": "GOLD RUSH", "how": "Earn a gold medal", "shape": Shape.CIRCLE, "color": "#ffe27a", "glyph": "@medal"},
	{"id": "ghost", "name": "GHOST BUSTER", "how": "Beat your ghost in Time Attack", "shape": Shape.BADGE, "color": "#7affc9", "glyph": "@ghost"},
	{"id": "free_roam", "name": "SUNDAY DRIVE", "how": "Drive 5 miles in one Free Drive", "shape": Shape.HEX, "color": "#ffd9a0", "glyph": "5MI"},
	{"id": "globetrotter", "name": "GLOBETROTTER", "how": "Finish every stage", "shape": Shape.CIRCLE, "color": "#3a9bff", "glyph": "8/8"},
	{"id": "clean_sweep", "name": "CLEAN SWEEP", "how": "Win on every stage", "shape": Shape.STAR, "color": "#ff7ad9", "glyph": "SWEEP"},
	{"id": "all_gold", "name": "ALL GOLD", "how": "Gold on every stage", "shape": Shape.BADGE, "color": "#ffc21a", "glyph": "ALL"},
	{"id": "tourist", "name": "GRAND TOURIST", "how": "Finish the Grand Tour", "shape": Shape.SHIELD, "color": "#5ac8ff", "glyph": "TOUR"},
	{"id": "champion", "name": "CHAMPION", "how": "Win the Grand Tour from stage 1", "shape": Shape.STAR, "color": "#ffd23a", "glyph": "@crown"},
	{"id": "showroom", "name": "SHOWROOM", "how": "Race every car in the garage", "shape": Shape.HEX, "color": "#ff9f6a", "glyph": "CARS"},
	{"id": "long_haul", "name": "LONG HAUL", "how": "Drive 100 miles in all", "shape": Shape.CIRCLE, "color": "#8aff5d", "glyph": "100"},
]


## Every sticker id, in order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in ALL:
		out.append(s["id"])
	return out


static func count() -> int:
	return ALL.size()


## A sticker's row in ALL (empty for an unknown id).
static func info(id: String) -> Dictionary:
	for s: Dictionary in ALL:
		if s["id"] == id:
			return s
	return {}


# --- The conditions: one plain function a sticker -----------------------------------------

static func _won(run: Dictionary) -> bool:
	return bool(run.get("finished", false)) and bool(run.get("rivals", false)) and int(run.get("place", 0)) == 1


static func first_finish(run: Dictionary, _save) -> bool:
	return bool(run.get("finished", false))


static func first_win(run: Dictionary, _save) -> bool:
	return _won(run)


static func no_crash(run: Dictionary, _save) -> bool:
	return bool(run.get("finished", false)) and int(run.get("crashes", 0)) == 0


## Traffic has to be on the road for keeping clear of it to count.
static func untouched(run: Dictionary, _save) -> bool:
	return bool(run.get("finished", false)) and bool(run.get("traffic", false)) and not bool(run.get("touched_traffic", false))


static func chain_5(run: Dictionary, _save) -> bool:
	return int(run.get("best_chain", 0)) >= FIVE_CHAIN


static func near_miss_10(run: Dictionary, _save) -> bool:
	return int(run.get("near_misses", 0)) >= NEAR_MISSES


static func big_air(run: Dictionary, _save) -> bool:
	return int(run.get("big_airs", 0)) > 0


static func drafter(run: Dictionary, _save) -> bool:
	return int(run.get("slipstreams", 0)) >= SLIPSTREAMS


static func launch(run: Dictionary, _save) -> bool:
	return bool(run.get("launch", false))


static func scavenger(run: Dictionary, _save) -> bool:
	return int(run.get("pickups", 0)) >= PICKUPS


static func last_gasp(run: Dictionary, _save) -> bool:
	return bool(run.get("finished", false)) and bool(run.get("timed", false)) and float(run.get("time_left", INF)) <= LAST_GASP


static func out_of_time(run: Dictionary, _save) -> bool:
	return bool(run.get("time_up", false))


static func mirror_win(run: Dictionary, _save) -> bool:
	return _won(run) and bool(run.get("mirror", false))


static func hard_win(run: Dictionary, _save) -> bool:
	return _won(run) and int(run.get("difficulty", Difficulty.Level.NORMAL)) == Difficulty.Level.HARD


## This run's time earns gold on its stage, at the difficulty it ran on.
static func gold(run: Dictionary, _save) -> bool:
	return bool(run.get("finished", false)) and Medals.earned(int(run.get("stage", 0)),
		int(run.get("difficulty", Difficulty.Level.NORMAL)), float(run.get("time", INF))) == Medals.Medal.GOLD


static func ghost(run: Dictionary, _save) -> bool:
	return bool(run.get("ghost_beaten", false))


static func free_roam(run: Dictionary, _save) -> bool:
	return str(run.get("mode", "")) == "free_drive" and float(run.get("miles", 0.0)) >= FREE_MILES


## A best time on file for every stage (any car).
static func globetrotter(_run: Dictionary, save) -> bool:
	for i in Stages.count():
		if is_inf(save.stage_best(i)):
			return false
	return true


## Every stage won: each one's mirror opened by a win (Unlocks.mirror_id; not the
## unlock-everything option).
static func clean_sweep(_run: Dictionary, save) -> bool:
	for i in Stages.count():
		if not save.unlocks.has(Unlocks.mirror_id(i)):
			return false
	return true


## Every stage's best time earns gold, at the difficulty of the run that asks.
static func all_gold(run: Dictionary, save) -> bool:
	var level := int(run.get("difficulty", Difficulty.Level.NORMAL))
	for i in Stages.count():
		if Medals.earned(i, level, save.stage_best(i)) != Medals.Medal.GOLD:
			return false
	return true


static func tourist(_run: Dictionary, save) -> bool:
	return save.unlocks.has(Tour.FINISH_UNLOCK)


static func champion(run: Dictionary, _save) -> bool:
	return bool(run.get("tour_champion", false))


## A race run to the end in every car in the garage (SaveData.stats "cars").
static func showroom(_run: Dictionary, save) -> bool:
	for car: Dictionary in Cars.LIST:
		if int(save.stats["cars"].get(car["id"], 0)) <= 0:
			return false
	return true


static func long_haul(_run: Dictionary, save) -> bool:
	return float(save.stats.get("miles", 0.0)) >= LONG_HAUL


## Whether sticker `id`'s condition holds for `run` and `save`.
static func met(id: String, run: Dictionary, save) -> bool:
	match id:
		"first_finish": return first_finish(run, save)
		"first_win": return first_win(run, save)
		"no_crash": return no_crash(run, save)
		"untouched": return untouched(run, save)
		"chain_5": return chain_5(run, save)
		"near_miss_10": return near_miss_10(run, save)
		"big_air": return big_air(run, save)
		"drafter": return drafter(run, save)
		"launch": return launch(run, save)
		"scavenger": return scavenger(run, save)
		"last_gasp": return last_gasp(run, save)
		"out_of_time": return out_of_time(run, save)
		"mirror_win": return mirror_win(run, save)
		"hard_win": return hard_win(run, save)
		"gold": return gold(run, save)
		"ghost": return ghost(run, save)
		"free_roam": return free_roam(run, save)
		"globetrotter": return globetrotter(run, save)
		"clean_sweep": return clean_sweep(run, save)
		"all_gold": return all_gold(run, save)
		"tourist": return tourist(run, save)
		"champion": return champion(run, save)
		"showroom": return showroom(run, save)
		"long_haul": return long_haul(run, save)
	return false


## The stickers `run` and `save` earn that `have` (ids already earned) hasn't got, in order.
static func earned(run: Dictionary, save, have: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if not have.has(id) and met(id, run, save):
			out.append(id)
	return out


## The longest near-miss chain in a stage's bonuses (Scoring.near_miss_scored's "chain").
static func best_chain(s: Scoring) -> int:
	var n := 0
	for b in s.bonuses:
		if b["name"] == "NEAR MISS":
			n = maxi(n, int(b.get("chain", 1)))
	return n


## How many of a stage's bonuses are called `bonus_name` (BIG AIR, SLIPSTREAM).
static func bonus_count(s: Scoring, bonus_name: String) -> int:
	var n := 0
	for b in s.bonuses:
		n += int(b["name"] == bonus_name)
	return n


# --- The art ------------------------------------------------------------------------------

## A sticker's tilt in radians, a few degrees either way, the same every time for its slot.
static func tilt(i: int) -> float:
	return deg_to_rad([-6.0, 4.0, -2.0, 7.0, -5.0, 3.0, -8.0, 5.0][posmod(i * 5 + 3, 8)])


## The outline of `shape` around the origin, `r` across (a die-cut sticker's edge).
static func outline(shape: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		Shape.STAR:
			for k in 20:
				var a := -PI / 2.0 + k * TAU / 20.0
				pts.append(Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.78))
		Shape.SHIELD:
			pts.append_array([Vector2(-r * 0.86, -r * 0.82), Vector2(0, -r), Vector2(r * 0.86, -r * 0.82),
				Vector2(r * 0.82, r * 0.1), Vector2(r * 0.45, r * 0.7), Vector2(0, r), Vector2(-r * 0.45, r * 0.7),
				Vector2(-r * 0.82, r * 0.1)])
		Shape.HEX:
			for k in 6:
				pts.append(Vector2.from_angle(k * TAU / 6.0) * r)
		Shape.BADGE:
			var c := r * 0.3
			var h := r * 0.86
			pts.append_array([Vector2(-h + c, -h), Vector2(h - c, -h), Vector2(h, -h + c), Vector2(h, h - c),
				Vector2(h - c, h), Vector2(-h + c, h), Vector2(-h, h - c), Vector2(-h, -h + c)])
		_:
			for k in 24:
				pts.append(Vector2.from_angle(k * TAU / 24.0) * r * 0.94)
	return pts


## Sticker `id` on `ci` centred on `c`, `r` across, tilted `angle`: `have` in its colors with
## a white die-cut edge and a shine, else a dim outline with a "?".
static func draw(ci: CanvasItem, c: Vector2, id: String, r: float, have: bool, angle := 0.0) -> void:
	var s := info(id)
	if s.is_empty():
		return
	var shape: int = s["shape"]
	var col := Color(s["color"])
	ci.draw_set_transform(c, angle if have else 0.0, Vector2.ONE)
	var edge := outline(shape, r + 2.5)
	var face := outline(shape, r)
	if not have:
		ci.draw_colored_polygon(face, Color(0.1, 0.09, 0.2, 0.9))
		var ring := face.duplicate()
		ring.append(face[0])
		ci.draw_polyline(ring, Color(1, 1, 1, 0.22), 1.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		UiText.draw_centered(ci, c + Vector2(0, r * 0.32), "?", int(r * 0.9), Color(1, 1, 1, 0.3))
		return
	ci.draw_colored_polygon(_shifted(edge, Vector2(1.5, 2.0)), Color(0, 0, 0, 0.45))  # its shadow
	ci.draw_colored_polygon(edge, Color(0.97, 0.96, 1.0))  # the white die-cut edge
	ci.draw_colored_polygon(face, col)
	ci.draw_colored_polygon(outline(shape, r * 0.78), col.darkened(0.18))
	# A shine across the top left
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.62, -r * 0.2), Vector2(-r * 0.2, -r * 0.66),
		Vector2(-r * 0.05, -r * 0.58), Vector2(-r * 0.54, -r * 0.08)]), Color(1, 1, 1, 0.45))
	var glyph: String = s["glyph"]
	if glyph.begins_with("@"):
		_icon(ci, glyph.substr(1), r)
	else:
		var size := int(r * (0.62 if glyph.length() <= 3 else 0.5 if glyph.length() == 4 else 0.42))
		var ink := Color(0.08, 0.06, 0.18)
		var w := UiText.width(glyph, size)
		var at := Vector2(-w / 2.0, size * 0.36)
		ci.draw_string_outline(ThemeDB.fallback_font, at, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(1, 1, 1, 0.75))
		ci.draw_string(ThemeDB.fallback_font, at, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## A sticker's picture, drawn at the origin (the transform puts it in place), `r` across.
static func _icon(ci: CanvasItem, icon: String, r: float) -> void:
	var ink := Color(0.08, 0.06, 0.18)
	match icon:
		"flag":
			ci.draw_line(Vector2(-r * 0.42, -r * 0.5), Vector2(-r * 0.42, r * 0.55), ink, 2.0)
			var cell := r * 0.2
			for row in 3:
				for k in 4:
					var on := (row + k) % 2 == 0
					ci.draw_rect(Rect2(Vector2(-r * 0.4 + k * cell, -r * 0.5 + row * cell), Vector2(cell, cell)), ink if on else Color.WHITE)
		"mirror":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.1, -r * 0.45), Vector2(-r * 0.1, r * 0.45), Vector2(-r * 0.55, r * 0.45)]), ink)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.1, -r * 0.45), Vector2(r * 0.1, r * 0.45), Vector2(r * 0.55, r * 0.45)]), Color(1, 1, 1, 0.85))
			ci.draw_line(Vector2(0, -r * 0.6), Vector2(0, r * 0.6), Color.WHITE, 1.0)
		"medal":
			Medals.draw(ci, Vector2(0, r * 0.18), Medals.Medal.GOLD, r * 0.38)
		"ghost":
			var g := PackedVector2Array()
			for k in 9:
				g.append(Vector2.from_angle(PI + k * PI / 8.0) * r * 0.42 + Vector2(0, -r * 0.05))
			g.append_array([Vector2(r * 0.42, r * 0.5), Vector2(r * 0.21, r * 0.36), Vector2(0, r * 0.5),
				Vector2(-r * 0.21, r * 0.36), Vector2(-r * 0.42, r * 0.5)])
			ci.draw_colored_polygon(g, Color(1, 1, 1, 0.92))
			ci.draw_circle(Vector2(-r * 0.15, -r * 0.08), r * 0.08, ink)
			ci.draw_circle(Vector2(r * 0.15, -r * 0.08), r * 0.08, ink)
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, r * 0.32), Vector2(-r * 0.55, -r * 0.3),
				Vector2(-r * 0.25, 0), Vector2(0, -r * 0.45), Vector2(r * 0.25, 0), Vector2(r * 0.55, -r * 0.3),
				Vector2(r * 0.5, r * 0.32)]), ink)
			ci.draw_rect(Rect2(-r * 0.5, r * 0.36, r, r * 0.12), ink)
		"wind":
			for k in 3:
				var y := (k - 1) * r * 0.28
				ci.draw_line(Vector2(-r * 0.5 + k * r * 0.08, y), Vector2(r * 0.4, y), ink, 2.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.55, y), Vector2(r * 0.36, y - r * 0.1), Vector2(r * 0.36, y + r * 0.1)]), ink)
