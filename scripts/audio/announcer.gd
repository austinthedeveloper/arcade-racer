class_name Announcer
extends RefCounted
## The race announcer: a short line for each big moment, one at a time. Each line is a
## voice cue (vo_<id>: synthesized patter in the line's rhythm, tools/make_audio.py, which
## reads LINES from this file) and its words as a subtitle (AC-5). The music ducks under
## it (Audio.duck). RaceAudio tells it what happened; update() says which line starts.

## id: the words. tools/make_audio.py speaks each one (so keep them to letters and . , ! ?).
const LINES := {
	"ready": "Engines ready. Here we go!",
	"go": "Go, go, go!",
	"launch": "What a launch!",
	"checkpoint": "Checkpoint!",
	"time_extended": "Time extended!",
	"hurry": "Hurry up!",
	"final_stretch": "Final stretch! Bring it home!",
	"near_miss": "Whoa, close one!",
	"big_air": "Big air!",
	"first_place": "You have the lead!",
	"finish_1": "You win! What a drive!",
	"finish_2": "Second place! So close!",
	"finish_3": "Third! You made the podium!",
	"finish": "Finished! Go again for the podium.",
	"time_up": "Out of time!",
}
## Lines that matter more go first and never go stale; the rest wait their turn.
const PRIORITY := {
	"finish_1": 3, "finish_2": 3, "finish_3": 3, "finish": 3, "time_up": 3,
	"ready": 2, "go": 2, "final_stretch": 2, "hurry": 2,
	"checkpoint": 1, "time_extended": 1, "first_place": 1, "launch": 1,
	"near_miss": 0, "big_air": 0,
}
const GAP := 0.15  # seconds of quiet between two lines
const STALE := 2.0  # seconds a waiting line keeps (under priority 3) before the moment has passed
const MAX_WAITING := 2
const HOLD_TEXT := 0.6  # seconds a subtitle stays up after its line ends
const SECONDS_PER_SYLLABLE := 0.16  # a line's length when its voice file isn't there

var current := ""  # the line speaking, or ""
var shown := ""  # the line the subtitle shows (stays a moment after the voice ends)
var _left := 0.0  # seconds left in the current line
var _quiet := 0.0  # seconds since the last line ended
var _show_left := 0.0
var _waiting: Array[Dictionary] = []  # {"id", "age"}


func reset() -> void:
	current = ""
	shown = ""
	_left = 0.0
	_quiet = GAP
	_show_left = 0.0
	_waiting.clear()


## Something happened: queue its line. One already waiting is not queued twice.
func say(id: String) -> void:
	if not LINES.has(id):
		return
	for w in _waiting:
		if w["id"] == id:
			return
	_waiting.append({"id": id, "age": 0.0})
	_waiting.sort_custom(func(a, b): return PRIORITY.get(a["id"], 0) > PRIORITY.get(b["id"], 0))
	while _waiting.size() > MAX_WAITING:
		_waiting.pop_back()  # the least important


## Advances `dt` seconds; returns the line that starts now, or "".
func update(dt: float) -> String:
	_show_left = maxf(0.0, _show_left - dt)
	if _show_left <= 0.0 and current == "":
		shown = ""
	for w in _waiting:
		w["age"] += dt
	_waiting = _waiting.filter(func(w): return w["age"] <= STALE or PRIORITY.get(w["id"], 0) >= 3)
	if current != "":
		_left -= dt
		if _left > 0.0:
			return ""
		current = ""
		_quiet = 0.0
	_quiet += dt
	if _waiting.is_empty() or _quiet < GAP:
		return ""
	current = _waiting.pop_front()["id"]
	shown = current
	_left = duration(current)
	_show_left = _left + HOLD_TEXT
	return current


## The subtitle up now, or "".
func subtitle() -> String:
	return LINES.get(shown, "")


static func cue(id: String) -> String:
	return "vo_" + id


## How long a line speaks: its voice file's length, or a guess from its syllables.
static func duration(id: String) -> float:
	var s := SoundBank.stream(cue(id)) if SoundBank.path_for(cue(id)) != "" else null
	if s != null:
		return s.get_length()
	return maxf(0.5, syllables(LINES.get(id, "")) * SECONDS_PER_SYLLABLE)


## A rough syllable count: groups of vowels.
static func syllables(text: String) -> int:
	var n := 0
	var in_vowel := false
	for ch in text.to_lower():
		var v := "aeiouy".contains(ch)
		if v and not in_vowel:
			n += 1
		in_vowel = v
	return n


## The finish line for a place (no rivals: just finished).
static func finish_line(place: int, racing_rivals: bool) -> String:
	if racing_rivals and place >= 1 and place <= 3:
		return "finish_%d" % place
	return "finish"
