class_name Tour
extends RefCounted
## Grand Tour rules: the same seven drivers stage after stage, points by place (Scoring) added
## up into standings, the top three going through, and one continue for a stage that went
## wrong (time up, or finishing outside the top three). Restarting a stage partway through
## spends the continue too. Finishing the last stage completes the tour; a tour started from
## the first stage unlocks the Zenith and banks its points.

const ADVANCE := 3  # the top this many go on to the next stage
const CONTINUES := 1
const YOU := "YOU"  # the player's name in the standings
const FINISH_UNLOCK := "car_zenith"

var drivers: Array[String] = []  # the rivals' driver names, picked on the first stage
var points := {}  # name -> points
var continues := CONTINUES
var stages_won := 0  # stages finished in the top three
var complete := false
var carried := 0.0  # seconds of clock carried into the next stage (Settings.carry_time)
var start_stage := 0  # where the tour was started (stage select lets it start anywhere)


## Whether this tour runs the whole way, from the first stage: only that one unlocks the
## Zenith and banks its points.
func full() -> bool:
	return start_stage == 0


static func advances(place: int) -> bool:
	return place >= 1 and place <= ADVANCE


## Points for a finished stage: each racer's place points in `order` (names, finish order),
## plus the player's bonuses.
func award(order: Array, player_bonus: int) -> void:
	for i in order.size():
		var who: String = order[i]
		points[who] = int(points.get(who, 0)) + Scoring.place_points(i + 1) + (player_bonus if who == YOU else 0)


## Names and points, most points first (ties: the player, then by name).
func standings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for who: String in points:
		out.append({"name": who, "points": points[who]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["name"] == YOU or b["name"] == YOU:
			return a["name"] == YOU
		return a["name"] < b["name"])
	return out


func standing_of(who: String) -> int:
	var s := standings()
	for i in s.size():
		if s[i]["name"] == who:
			return i + 1
	return 0


## Spends the continue for another go at a stage; false when it's gone.
func use_continue() -> bool:
	if continues <= 0:
		return false
	continues -= 1
	return true


## Clock carried into the next stage: what was left, when the option is on.
static func carry(time_left: float, on: bool) -> float:
	return maxf(0.0, time_left) if on else 0.0
