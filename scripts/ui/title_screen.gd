class_name TitleScreen
extends MenuScreen
## Attract screen: the logo over the Palm Coast sunset, with START (on to mode select),
## OPTIONS, CONTROLS (PR-22: the controls card), STATS (MP-11), PROFILE (MP-10: who is
## driving) and QUIT side by side. A browser tab can't be quit, so the web build has no QUIT.
## The driver's avatar and name show top left.
## After an error (CrashLog, EQ-20) the version line offers COPY REPORT: F4, or a click or tap
## on it, puts the report on the clipboard.
## After an update, what's new in it (WhatsNew, PR-17) is up over the title until Enter or back.
## A new profile (and the first boot) is asked who's driving (WhosDriving, AC-16) before
## anything else. A wheel plugged in with no saved profile is offered calibration once (WH-16).

const LOGO := "res://assets/sprites/ui/logo.png"
const PILL_STEP := 124.0  # the most from one pill to the next; six share the width
const PILL := Vector2(112, 26)  # the widest a pill is, its height
const PILL_GAP := 12.0
const ANSWER_CARD := Vector2(150, 92)  # who's driving: each answer's card
const DRIVER := Rect2(8, 8, 150, 34)  # who is driving (MP-10), top left
const DRIVER_PIC := Vector2(56, 26)
const VERSION_X := 150.0  # the version line, from the right edge
const COPIED_SECONDS := 2.5  # how long REPORT COPIED shows

var _logo: Texture2D
var _avatar: Texture2D
var _avatar_id := ""
## `time` when the report was last copied, or a negative number.
var copied_at := -100.0
## Where the report goes (copy_report): the clipboard, unless a test hands it another.
var set_clipboard := Callable()
## What's new up over the title (WhatsNew.items), and its version; empty when it's not up.
var news: Array = []
var news_version := ""
## Who's driving (AC-16) is up, asking; the cursor on `answer` (WhosDriving.Answer).
var asking := false
var answer: int = WhosDriving.DEFAULT
## Whether the first-run prompts (the wheel's, WH-16) may come up: the game turns them off for
## a staged screenshot, the test runners through WhosDriving.enabled.
var offers := true
## The wheel offered calibration (WH-16): its GUID and name, "" when no offer is up; the
## cursor on `wheel_choice`, into wheel_choices().
var wheel_offer := ""
var wheel_offer_name := ""
var wheel_choice := 0


func _ready() -> void:
	super._ready()
	_logo = load(LOGO)


## What the start prompt says for the device in use.
static func start_prompt() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.WHEEL:
			return "PRESS A"
		DriveInput.Kind.GAMEPAD:
			return "PRESS START"
	return "PRESS ENTER"


## The title's choices: QUIT too, except in a browser.
static func items(web := OS.has_feature("web")) -> Array[String]:
	var out: Array[String] = ["START", "OPTIONS", "CONTROLS", "STATS", "PROFILE"]
	if not web:
		out.append("QUIT")
	return out


## What the version line offers about the crash report: nothing without one.
static func report_offer(has_report: bool, copied: bool) -> String:
	if not has_report:
		return ""
	return "REPORT COPIED" if copied else "F4 COPY REPORT"


func report_text() -> String:
	return report_offer(CrashLog.has_report(), time - copied_at < COPIED_SECONDS)


## Where COPY REPORT is on the screen, for a click or tap.
func report_rect() -> Rect2:
	var wide := UiText.width("F4 COPY REPORT", 8)
	return Rect2(Cfg.SCREEN_W - VERSION_X - wide - 16, Cfg.SCREEN_H - 20, wide + 12, 20)


## COPY REPORT: the crash report on the clipboard. False when there's none to copy.
func copy_report() -> bool:
	if not CrashLog.copy_report("", set_clipboard):
		return false
	copied_at = time
	Audio.play("beep")
	return true


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
		and report_rect().has_point((make_input_local(event) as InputEventMouseButton).position)
	var f4 := InputMap.has_action("copy_report") and event.is_action_pressed("copy_report")
	if (f4 or click) and report_text() != "":
		copy_report()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func choice_count() -> int:
	return items().size()


## Something is up over the title (what's new, who's driving, a wheel's offer): no demo starts.
func busy() -> bool:
	return not news.is_empty() or asking or wheel_offer != ""


## Who's driving answered: `a`'s options set and saved, and the profile asked.
func answer_question(a: int) -> void:
	WhosDriving.apply(a, Settings)
	SaveData.mark_driver_asked()
	asking = false


## Who's driving passed over (back): the options left as they are, the profile asked anyway.
func pass_question() -> void:
	SaveData.mark_driver_asked()
	asking = false


## Looks for a wheel to offer calibration (InputRouter.first_run_wheel) in `plugged` (GUID ->
## name; the joypads plugged in) and, finding one, puts the offer up and remembers it was
## made (Settings.wheels_prompted), so each wheel is offered once. Returns its GUID or "".
func offer_wheel(plugged: Dictionary = InputRouter.plugged_joypads()) -> String:
	if not offers or not WhosDriving.enabled:
		return ""
	var guid := InputRouter.first_run_wheel(plugged, Settings.wheels_prompted)
	if guid == "":
		return ""
	wheel_offer = guid
	wheel_offer_name = str(plugged[guid])
	wheel_choice = 0
	Settings.wheels_prompted.append(guid)
	Settings.save()
	return guid


## The offer's choices. WH-4 (known wheels' ready-made profiles) isn't built: once it is,
## a wheel InputRouter.known_profile_for has a profile for gets USE ITS PROFILE here too,
## taken in take_wheel_offer by saving that profile for it.
static func wheel_choices() -> Array[String]:
	return ["CALIBRATE NOW", "LATER"]


## The offer answered: CALIBRATE NOW opens the calibration on that wheel; LATER (or back)
## leaves it, calibration still a press of F2 or Options > Controls away.
func take_wheel_offer(calibrate: bool) -> void:
	var guid := wheel_offer
	wheel_offer = ""
	if calibrate and game != null:
		game.calibration.open(InputRouter.device_for(guid))


func handle(m: MenuInput) -> void:
	if not news.is_empty():
		if m.confirm_pressed or m.back_pressed:
			Audio.play("beep")
			news = []
		return
	if asking:
		if m.step() != 0:
			answer = posmod(answer + m.step(), WhosDriving.Answer.size())
			Audio.play("tick")
		elif m.confirm_pressed:
			Audio.play("beep")
			answer_question(answer)
		elif m.back_pressed:
			Audio.play("beep")
			pass_question()
		return
	if wheel_offer != "":
		if m.step() != 0:
			wheel_choice = posmod(wheel_choice + m.step(), wheel_choices().size())
			Audio.play("tick")
		elif m.confirm_pressed:
			Audio.play("beep")
			take_wheel_offer(wheel_choices()[wheel_choice] == "CALIBRATE NOW")
		elif m.back_pressed:
			take_wheel_offer(false)
		return
	if offer_wheel() != "":
		Audio.play("beep")
		return
	if m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		Audio.play("beep")
		match items()[index]:
			"START":
				game.show_mode_select()
			"OPTIONS":
				game.show_options()
			"CONTROLS":
				game.show_controls()
			"STATS":
				game.show_stats()
			"PROFILE":
				game.show_profiles()
			"QUIT":
				game.quit()


func _draw() -> void:
	_backdrop(0.15)
	var w := float(Cfg.SCREEN_W)
	if _logo != null:
		var bob := roundf(sin(time * 2.0) * 2.0)
		draw_texture(_logo, Vector2(roundf((w - _logo.get_width()) / 2.0), 22 + bob))
	var names := items()
	var step := pill_step(names.size())
	for i in names.size():
		var pill := Rect2(w / 2.0 - names.size() * step / 2.0 + PILL_GAP / 2.0 + i * step, 270, step - PILL_GAP, PILL.y)
		var on := i == index
		if on:
			draw_rect(pill.grow(4), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
		draw_rect(pill.grow(2), Color("#c9d4ff") if on else Color(1, 1, 1, 0.35))
		draw_rect(pill, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.85))
		_text_centered(Vector2(pill.get_center().x, 288), names[i], 14, Color.WHITE if on else Color(1, 1, 1, 0.55))
	_draw_driver()
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, 314), start_prompt(), 10, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(0, Cfg.SCREEN_H - 20, w, 20), Color(0, 0, 0, 0.6))
	var inp: DriveInput = InputRouter.state
	var dev: String = ["KEYBOARD", "GAMEPAD", "WHEEL"][inp.kind]
	_text(Vector2(10, Cfg.SCREEN_H - 8), dev + "  " + inp.device_name.left(28), 8, Color(1, 1, 1, 0.7))
	_text(Vector2(w - VERSION_X, Cfg.SCREEN_H - 8), "F2 calibrate wheel   v" + str(ProjectSettings.get_setting("application/config/version", "")), 8, Color(1, 1, 1, 0.6))
	var report := report_text()
	if report != "":
		var r := report_rect()
		_text(Vector2(r.end.x - 6 - UiText.width(report, 8), Cfg.SCREEN_H - 8), report, 8, GOLD)
	var hint := InputRouter.wheel_hint()
	if hint != "":
		_text_centered(Vector2(w / 2.0, 330), hint, 10, GOLD)
	if not news.is_empty():
		_draw_news()
	elif asking:
		_draw_question()
	elif wheel_offer != "":
		_draw_wheel_offer()


## From one pill to the next for `n` of them: PILL_STEP, or less so they fit across.
static func pill_step(n: int) -> float:
	return minf(PILL_STEP, (Cfg.SCREEN_W - 16.0) / maxi(1, n))


## Who's driving (AC-16): a card per answer, the cursor's lit, what it sets under each.
func _draw_question() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.72))
	var panel := Rect2(40, 60, w - 80, 226)
	_panel(panel, 0.95)
	_text_centered(Vector2(w / 2.0, panel.position.y + 30), WhosDriving.QUESTION, 22, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 40, panel.size.x - 40, 2), GOLD)
	var n := WhosDriving.Answer.size()
	var gap := 14.0
	var x0 := w / 2.0 - (n * ANSWER_CARD.x + (n - 1) * gap) / 2.0
	for i in n:
		var r := Rect2(x0 + i * (ANSWER_CARD.x + gap), panel.position.y + 56, ANSWER_CARD.x, ANSWER_CARD.y)
		var on := i == answer
		_frame(r, Color(GOLD, 0.35 + 0.15 * sin(time * 5.0)) if on else Color.TRANSPARENT)
		draw_rect(r, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.9))
		_text_centered(Vector2(r.get_center().x, r.position.y + 34), WhosDriving.NAMES[i], 22, Color.WHITE if on else Color(1, 1, 1, 0.6))
		var words: PackedStringArray = WhosDriving.LINES[i].split(" ")
		var lines := _wrap(words, ANSWER_CARD.x - 16, 9)
		for k in lines.size():
			_text_centered(Vector2(r.get_center().x, r.position.y + 56 + k * 12), lines[k], 9, GOLD if on else Color(1, 1, 1, 0.55))
	_text_centered(Vector2(w / 2.0, panel.end.y - 34), "It sets the assists and difficulty. Change them any time in Options.", 9, Color(1, 1, 1, 0.75))
	_text_centered(Vector2(w / 2.0, panel.end.y - 14), MenuScreen.hints(true), 9, Color(1, 1, 1, 0.7))


## The wheel's first run (WH-16): which wheel, and CALIBRATE NOW or LATER.
func _draw_wheel_offer() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.65))
	var panel := Rect2(w / 2.0 - 200, 92, 400, 150)
	_panel(panel, 0.95)
	_text_centered(Vector2(w / 2.0, panel.position.y + 26), "NEW WHEEL", 20, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 36, panel.size.x - 40, 2), GOLD)
	_text_centered(Vector2(w / 2.0, panel.position.y + 56), wheel_offer_name.left(44), 11, Color.WHITE)
	_text_centered(Vector2(w / 2.0, panel.position.y + 74), "Calibrate its steering and pedals now? It takes a minute.", 9, Color(1, 1, 1, 0.8))
	var choices := wheel_choices()
	var bw := 150.0
	var x0 := w / 2.0 - (choices.size() * bw + (choices.size() - 1) * 16.0) / 2.0
	for i in choices.size():
		var r := Rect2(x0 + i * (bw + 16.0), panel.position.y + 90, bw, 24)
		var on := i == wheel_choice
		if on:
			draw_rect(r.grow(3), Color(GOLD, 0.45 + 0.2 * sin(time * 5.0)))
		draw_rect(r.grow(1), Color("#c9d4ff") if on else Color(1, 1, 1, 0.35))
		draw_rect(r, Color("#1d3fa8") if on else Color(0.07, 0.07, 0.2, 0.9))
		_text_centered(Vector2(r.get_center().x, r.position.y + 17), choices[i], 12, Color.WHITE if on else Color(1, 1, 1, 0.6))
	_text_centered(Vector2(w / 2.0, panel.end.y - 12), "Later: F2, or Options > Controls > Calibrate", 9, Color(1, 1, 1, 0.6))


## `words` in lines no wider than `width` at `size`.
static func _wrap(words: PackedStringArray, width: float, size: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in words:
		var next := word if line == "" else line + " " + word
		if line != "" and UiText.width(next, size) > width:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## What's new: a panel over the title listing the update's additions, changes and fixes.
func _draw_news() -> void:
	var w := float(Cfg.SCREEN_W)
	draw_rect(Rect2(0, 0, w, Cfg.SCREEN_H), Color(NIGHT, 0.7))
	var panel := Rect2(30, 22, w - 60, Cfg.SCREEN_H - 44)
	_panel(panel, 0.95)
	_text_centered(Vector2(w / 2.0, panel.position.y + 24), "WHAT'S NEW IN v" + news_version, 18, GOLD)
	draw_rect(Rect2(panel.position.x + 20, panel.position.y + 32, panel.size.x - 40, 2), GOLD)
	var col_w := (panel.size.x - 40) / WhatsNew.COLUMNS
	for slot: Array in WhatsNew.layout(news):
		var item: Array = slot[2]
		var at := Vector2(panel.position.x + 20 + slot[0] * col_w, panel.position.y + 52 + slot[1] * 15)
		if item[0]:
			_text(at, item[1], 10, SKY)
		else:
			draw_rect(Rect2(at + Vector2(2, -5), Vector2(3, 3)), GOLD)
			_text(at + Vector2(10, 0), item[1], 9, Color(1, 1, 1, 0.9))
	if fmod(time, 1.0) < 0.65:
		_text_centered(Vector2(w / 2.0, panel.end.y - 10), "Enter: carry on", 9, Color(1, 1, 1, 0.75))


## The words in the driver badge: who is driving and which profile slot (P1 to P4).
static func driver_text() -> Array[String]:
	return ["DRIVER  P%d" % (SaveData.slot + 1), SaveData.profile_name]


## Who is driving (MP-10): the profile's avatar and name, top left.
func _draw_driver() -> void:
	if _avatar_id != SaveData.avatar:
		_avatar_id = SaveData.avatar
		_avatar = load(Cars.picture(Cars.find(_avatar_id)))
	draw_rect(DRIVER, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(DRIVER.position.x, DRIVER.end.y, DRIVER.size.x, 2), GOLD)
	var pic := Rect2(DRIVER.position + Vector2(4, 4), DRIVER_PIC)
	draw_rect(pic, Color(0.1, 0.12, 0.3, 0.9))
	if _avatar != null:
		var k := minf(pic.size.x / _avatar.get_width(), pic.size.y / _avatar.get_height())
		var size := Vector2(_avatar.get_width(), _avatar.get_height()) * k
		draw_texture_rect(_avatar, Rect2(pic.get_center() - size / 2.0, size), false)
	draw_rect(pic, Color("#c9d4ff", 0.6), false, 1.0)
	var words := driver_text()
	_text(Vector2(pic.end.x + 8, DRIVER.position.y + 14), words[0], 8, Color(1, 1, 1, 0.65))
	_text(Vector2(pic.end.x + 8, DRIVER.position.y + 30), words[1], 14, GOLD)
