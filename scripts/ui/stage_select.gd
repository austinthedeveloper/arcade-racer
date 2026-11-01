class_name StageSelect
extends MenuScreen
## Stage select: the chosen stage's postcard big, every stage as a thumbnail along the
## bottom. A Grand Tour runs on from the chosen stage; a Single Race is just that stage.
## Stages the tour hasn't reached yet (Unlocks) show dimmed with a lock and can't be picked.
## Outside the Grand Tour a MIRROR toggle (WS-6, Up; game.mirror) races the stage flipped,
## once it's won; Time Attack and Free Drive also switch traffic (Down).

const THUMB := Vector2(72, 40)
const THUMB_GAP := 80.0
const THUMB_Y := 284.0

var _cards: Array[Texture2D] = []


func _ready() -> void:
	super._ready()
	for i in Stages.count():
		_cards.append(load(Stages.postcard(i)))


func choice_count() -> int:
	return Stages.count()


func handle(m: MenuInput) -> void:
	var y := m.step_y()
	if y > 0 and solo():
		Settings.attack_traffic = not Settings.attack_traffic
		Settings.save()
		Audio.play("tick")
	elif y != 0 and mirror_offered():
		toggle_mirror()
	elif m.step() != 0:
		move(m.step())
		Audio.play("tick")
	elif m.confirm_pressed:
		if not Unlocks.stage_unlocked(index):
			Audio.play("bump")
			return
		Audio.play("beep")
		game.stage_index = index
		game.show_car_select()
	elif m.back_pressed:
		game.show_mode_select()


func _draw() -> void:
	_backdrop(0.72)
	_header("SELECT STAGE")
	var w := float(Cfg.SCREEN_W)

	var big := Rect2(w / 2.0 - 168, 52, 336, 189)
	var open := Unlocks.stage_unlocked(index)
	_frame(big, Color(GOLD, 0.35 + 0.15 * sin(time * 4.0)) if open else Color.TRANSPARENT)
	if index < _cards.size() and _cards[index] != null:
		# Mirrored, flipped: a negative width mirrors the picture within the same rect
		var card := Rect2(big.position, Vector2(-big.size.x, big.size.y)) if mirrored() else big
		draw_texture_rect(_cards[index], card, false, Color.WHITE if open else LOCKED_TINT)
	if not open:
		_lock(big.get_center() + Vector2(0, -14), 1.6)
		_text_centered(big.get_center() + Vector2(0, 30), "LOCKED", 16, GOLD)
	var pulse := 3.0 * sin(time * 5.0)
	_arrow(Vector2(big.position.x - 22 - pulse, big.get_center().y), -1, GOLD)
	_arrow(Vector2(big.end.x + 22 + pulse, big.get_center().y), 1, GOLD)
	draw_rect(Rect2(big.position.x, big.end.y - 22, big.size.x, 22), Color(0, 0, 0, 0.6))
	_text(Vector2(big.position.x + 8, big.end.y - 7), "STAGE %d" % (index + 1), 12, GOLD)
	_text(Vector2(big.position.x + 66, big.end.y - 7), Stages.stage_name(index).to_upper(), 12, Color.WHITE)
	if open and mirror_offered():
		_mirror_badge(big.end.x, big.end.y - 4)
	var line := _tour_line() if open else Unlocks.stage_condition(index)
	_text_centered(Vector2(w / 2.0, big.end.y + 22), line, 9, Color(1, 1, 1, 0.75))

	var x0 := (w - THUMB_GAP * (Stages.count() - 1) - THUMB.x) / 2.0
	for i in Stages.count():
		var r := Rect2(Vector2(x0 + i * THUMB_GAP, THUMB_Y - (4.0 if i == index else 0.0)), THUMB)
		_frame(r, GOLD if i == index else Color.TRANSPARENT)
		var tint := Color.WHITE if i == index else Color(0.55, 0.55, 0.65)
		if not Unlocks.stage_unlocked(i):
			tint = LOCKED_TINT
		if _cards[i] != null:
			draw_texture_rect(_cards[i], r, false, tint)
		if not Unlocks.stage_unlocked(i):
			_lock(r.get_center(), 0.7)
		_text_centered(Vector2(r.get_center().x, r.end.y + 12), str(i + 1), 9, GOLD if i == index else Color(1, 1, 1, 0.6))
	_footer(hints(true))


## Up (or Down, with no traffic to switch): MIRROR on or off. Off always goes; on only where
## the stage's mirror is open, or the stage itself is locked.
func toggle_mirror() -> void:
	if not game.mirror and not (Unlocks.stage_unlocked(index) and Unlocks.mirror_unlocked(index)):
		Audio.play("bump")
		return
	game.mirror = not game.mirror
	Audio.play("tick")


func mirror_offered() -> bool:
	return game != null and game.mirror_offered()


## Whether the stage shown would be raced mirrored (the postcard is drawn flipped).
func mirrored() -> bool:
	return game != null and game.mirror_for(index)


## The MIRROR badge on the postcard's caption bar, right-aligned to `right` on `baseline`:
## ON or OFF, or a lock while the stage's mirror isn't won.
func _mirror_badge(right: float, baseline: float) -> void:
	var open := Unlocks.mirror_unlocked(index)
	var on: bool = open and game.mirror
	var label := ("MIRROR " + ("ON" if on else "OFF")) if open else "MIRROR"
	var w := UiText.width(label, 10) + (0.0 if open else 14.0)
	var box := Rect2(right - w - 10, baseline - 11, w + 8, 14)
	draw_rect(box, Color(GOLD, 0.9) if on else Color(1, 1, 1, 0.12))
	var col := NIGHT if on else (Color.WHITE if open else Color(1, 1, 1, 0.5))
	if not open:
		_lock(Vector2(box.position.x + 8, box.get_center().y - 1), 0.45)
	_text(Vector2(box.position.x + 4 + (0.0 if open else 12.0), baseline - 1), label, 10, col)


func time_attack() -> bool:
	return game != null and game.mode_index == ModeSelect.Item.TIME_ATTACK


## Time Attack and Free Drive pick traffic on or off here (Settings.attack_traffic).
func solo() -> bool:
	return game != null and (game.mode_index == ModeSelect.Item.TIME_ATTACK or game.mode_index == ModeSelect.Item.FREE_DRIVE)


func _tour_line() -> String:
	var mirror := "   " + mirror_line()
	if game != null and game.mode_index == ModeSelect.Item.SINGLE_RACE:
		return "Single Race: one run on this stage." + mirror
	var traffic := "Traffic %s (Down)%s" % ["ON" if Settings.attack_traffic else "OFF", mirror]
	if time_attack():
		return "Time Attack: you and your best run.   " + traffic
	if solo():
		return "Free Drive: no clock, no finish.   " + traffic
	var last := Stages.count() - 1
	if index == last:
		return "The final stage"
	return "Tour from here on to %s  (%d stages)" % [Stages.stage_name(last), Stages.count() - index]


## What the MIRROR toggle says under the postcard: how to switch it, or how to open it.
func mirror_line() -> String:
	if not Unlocks.mirror_unlocked(index):
		return Unlocks.mirror_condition(index)
	return "Mirror %s (Up)" % ("ON" if game.mirror else "OFF")
