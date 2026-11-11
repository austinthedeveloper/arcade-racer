class_name Medals
extends RefCounted
## Medals (MP-9): bronze, silver and gold times per stage and difficulty. A stage's medal is
## the best one its best time (any car, SaveData.stage_best) earns against the table for the
## difficulty picked now, so a harder difficulty asks for a quicker time.
##
## The Normal times sit around the autodrive's finish with traffic and rivals (its golden
## trace, tests/golden/): gold is quicker than the autodrive, silver just slower, bronze about
## an eighth slower. So the autodrive earns silver on Normal and Easy and bronze on Hard; gold
## needs a driver who beats it. test_medals checks that against the traces.

enum Medal { NONE, BRONZE, SILVER, GOLD }

const NAMES := ["", "BRONZE", "SILVER", "GOLD"]
## Drawn after the results' place badges (ResultsScreen.PLACE_COLORS).
const COLORS := [Color(0.5, 0.5, 0.58), Color("#e08a3a"), Color("#c9d4ff"), Color("#ffc21a")]

## Seconds for gold, silver and bronze on Normal, by stage id (Stages.POSTCARDS).
const TIMES := {
	"palm_coast": [101.0, 115.0, 126.0],
	"redrock": [91.0, 103.0, 113.0],
	"neon": [68.0, 77.0, 84.0],
	"timberline": [84.0, 95.0, 104.0],
	"bayou": [78.0, 89.0, 97.0],
	"harvest": [78.0, 88.0, 97.0],
	"thunder": [65.0, 74.0, 81.0],
	"skyline": [95.0, 107.0, 118.0],
}
## Each difficulty's times are Normal's times this much (Difficulty.Level order): Easy gives
## a little more time, Hard a little less.
const SCALE := [1.06, 1.0, 0.95]


## Gold, silver and bronze times for `stage` on `level` (Difficulty.Level), whole seconds.
static func times(stage: int, level: int) -> Array[float]:
	var normal: Array = TIMES[Stages.POSTCARDS[stage]]
	var k: float = SCALE[clampi(level, 0, SCALE.size() - 1)]
	var out: Array[float] = []
	for t: float in normal:
		out.append(roundf(t * k))
	return out


## The time for `medal` (BRONZE..GOLD) on a stage and difficulty.
static func time_for(stage: int, level: int, medal: int) -> float:
	return times(stage, level)[Medal.GOLD - medal]


## The medal a finish in `seconds` earns (NONE for none, or no time: INF or below zero).
static func earned(stage: int, level: int, seconds: float) -> int:
	if seconds < 0.0 or is_inf(seconds) or is_nan(seconds):
		return Medal.NONE
	var t := times(stage, level)
	for i in t.size():
		if seconds <= t[i]:
			return Medal.GOLD - i
	return Medal.NONE


## The medal the player holds on `stage`: their best time there against the difficulty
## picked (Settings.difficulty).
static func held(stage: int) -> int:
	return earned(stage, Settings.difficulty, SaveData.stage_best(stage))


static func medal_name(medal: int) -> String:
	return NAMES[clampi(medal, 0, NAMES.size() - 1)]


static func color(medal: int) -> Color:
	return COLORS[clampi(medal, 0, COLORS.size() - 1)]


## A medal on `ci` centred on `c`: a ribbon, then the disc. NONE draws an empty ring.
static func draw(ci: CanvasItem, c: Vector2, medal: int, radius: float) -> void:
	var col := color(medal)
	if medal == Medal.NONE:
		ci.draw_arc(c, radius - 1.0, 0.0, TAU, 16, Color(col, 0.8), 1.5)
		return
	var r := radius
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 1.6), c + Vector2(-r * 0.05, -r * 1.6),
		c + Vector2(r * 0.35, -r * 0.4), c + Vector2(-r * 0.35, -r * 0.2)]), Color("#d92e4a"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, -r * 1.6), c + Vector2(r * 0.75, -r * 1.6),
		c + Vector2(r * 0.35, -r * 0.2), c + Vector2(-r * 0.35, -r * 0.4)]), Color("#3a6fe0"))
	ci.draw_circle(c, r + 1.0, Color(0, 0, 0, 0.75))
	ci.draw_circle(c, r, col)
	ci.draw_circle(c, r * 0.68, col.darkened(0.22))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.7))
