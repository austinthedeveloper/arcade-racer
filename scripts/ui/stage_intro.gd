class_name StageIntro
extends RefCounted
## The stage intro card (PR-16): during the countdown, a card slides in from the right with the
## stage's name, its weather, its length, and your best time and medal there, then slides back
## out before GO. The Hud draws it; where it is and what it says are plain functions here.

const CARD := Vector2(232, 70)
const SLIDE_IN := 0.35  # seconds from the countdown's start to fully in
const OUT_AT := 2.3  # seconds from the start when it starts back out
const SLIDE_OUT := 0.35


## Where the card is `elapsed` seconds into the countdown, slid in to `home` (Hud.layout's
## "intro", top right: the rival cards have the left): off the right edge before and after,
## eased in and out. An empty Rect2 when it isn't on screen.
static func rect(elapsed: float, home: Rect2) -> Rect2:
	var k := 0.0
	if elapsed >= 0.0 and elapsed < OUT_AT:
		k = ease_out(clampf(elapsed / SLIDE_IN, 0.0, 1.0))
	elif elapsed >= OUT_AT:
		k = 1.0 - ease_in(clampf((elapsed - OUT_AT) / SLIDE_OUT, 0.0, 1.0))
	if k <= 0.0:
		return Rect2()
	var hidden_x := float(Cfg.SCREEN_W) + 8.0
	return Rect2(Vector2(roundf(lerpf(hidden_x, home.position.x, k)), home.position.y), CARD)


static func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func ease_in(t: float) -> float:
	return t * t


## What the weather line says for a stage theme (Weather.of): STORM with lightning, RAIN with
## rain alone, else CLEAR.
static func weather_label(theme: Dictionary) -> String:
	var w := Weather.of(theme)
	if w.get("lightning", false):
		return "STORM"
	if float(w.get("rain", 0.0)) > 0.0:
		return "RAIN"
	return "CLEAR"


## The card's text: {"stage": "STAGE 2", "name", "info": weather and length, "best": the best
## time line ("" without one, or when `with_best` is off: Free Drive has no finish), "medal":
## the medal it holds (Medals.Medal)}. `length` is the stage in world units.
static func lines(stage: int, mirror: bool, theme: Dictionary, length: float, units: int,
		best: float, level: int, with_best := true) -> Dictionary:
	var stage_line := "STAGE %d" % (stage + 1) + ("   MIRRORED" if mirror else "")
	var info := "%s    %s" % [weather_label(theme), Settings.distance_text(length, units)]
	var best_line := ""
	var medal := Medals.Medal.NONE
	if with_best:
		if is_inf(best):
			best_line = "NO BEST TIME YET"
		else:
			best_line = "BEST  " + Hud.clock_text(best)
			medal = Medals.earned(stage, level, best)
	return {"stage": stage_line, "name": Stages.stage_name(stage).to_upper(), "info": info, "best": best_line, "medal": medal}


## Draws the card `elapsed` seconds into the countdown on `ci` (the Hud).
static func draw(ci: CanvasItem, elapsed: float, home: Rect2, text: Dictionary) -> void:
	var r := rect(elapsed, home)
	if not r.has_area():
		return
	ci.draw_rect(r.grow(2), Color("#1b2a6b"))
	ci.draw_rect(r.grow(1), Color("#c9d4ff"))
	ci.draw_rect(r, Color(0.04, 0.03, 0.1, 0.88))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Hud.GOLD)
	var x := r.position.x + 12
	UiText.draw(ci, Vector2(x, r.position.y + 13), text["stage"], 9, Hud.GOLD)
	UiText.draw(ci, Vector2(x, r.position.y + 31), text["name"], 15, Color.WHITE)
	UiText.draw(ci, Vector2(x, r.position.y + 46), text["info"], 9, Color(1, 1, 1, 0.8))
	var best: String = text["best"]
	if best == "":
		return
	var medal: int = text["medal"]
	UiText.draw(ci, Vector2(x, r.position.y + 61), best, 9, Color.WHITE if medal != Medals.Medal.NONE else Color(1, 1, 1, 0.6))
	if medal != Medals.Medal.NONE:
		var mx := x + UiText.width(best, 9) + 12
		Medals.draw(ci, Vector2(mx, r.position.y + 57), medal, 5.0)
		UiText.draw(ci, Vector2(mx + 9, r.position.y + 61), Medals.medal_name(medal), 9, Medals.color(medal))
