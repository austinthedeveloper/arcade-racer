class_name ProfileScreen
extends MenuScreen
## Who is driving (MP-10), from PROFILE on the title: a card for each of the SaveData.MAX_PROFILES
## slots, the profile's avatar (a car's showroom picture), name and how far it has got, or
## NEW DRIVER for an empty one. Under the cards, NAME and AVATAR pick from the lists (no
## typing; a name another driver has is skipped). Select on the cards drives as that profile
## (making it first for an empty slot) and goes back to the title; BACK goes back as it was.
## Keyboard and pad: up/down picks the row, left/right changes it; a wheel's D-pad works as
## a pad's.

enum Row { CARDS, NAME, AVATAR, BACK }

const LABELS := ["", "NAME", "AVATAR", "BACK"]
const CARD := Vector2(130, 150)
const CARD_GAP := 12.0
const CARDS_Y := 52.0
const PIC := Vector2(116, 54)  # the avatar on a card
const ROWS_Y := 222.0  # the first row under the cards
const ROW_H := 20.0
const HELP := [
	"Pick a driver. Select drives as them; an empty slot makes a new one.",
	"The driver's name, from the list.",
	"The driver's picture.",
	"Back to the title screen.",
]

var card := 0  # the slot under the cursor
## An empty slot's name and avatar as picked, before it's made: slot -> {"name", "avatar"}.
var pending := {}


func _init() -> void:
	card = SaveData.slot


func choice_count() -> int:
	return Row.size()


## The Row under the cursor.
func row() -> int:
	return index


## The name and avatar slot `s` shows: its profile's, or for an empty slot what has been
## picked for it so far (at first a name no one has and the slot's car).
func identity(s: int) -> Dictionary:
	if SaveData.has_profile(s):
		return SaveData.profile_of(s)
	if pending.has(s):
		return pending[s]
	var free := SaveData.names_free_for(s)
	return {"slot": s, "name": free[0] if not free.is_empty() else SaveData.NAMES[0],
		"avatar": SaveData.default_identity(s)["avatar"]}


## How far slot `s`'s profile has got: {"stage": the furthest stage reached (1 up),
## "races": races run}; empty for an empty slot.
static func summary(s: int) -> Dictionary:
	if not SaveData.has_profile(s):
		return {}
	if s == SaveData.slot:
		return {"stage": SaveData.furthest_stage + 1, "races": int(SaveData.stats["races"])}
	var cfg := ConfigFile.new()
	cfg.load(SaveData.slot_path(SaveData.base_path, s))
	return {"stage": clampi(int(cfg.get_value("tour", "furthest_stage", 0)), 0, Stages.count() - 1) + 1,
		"races": maxi(0, int(cfg.get_value("stats", "races", 0)))}


## Moves the card cursor by `dir`, wrapping round; returns the slot.
func pick_card(dir: int) -> int:
	card = posmod(card + dir, SaveData.MAX_PROFILES)
	return card


## The next name (by `dir`) for the card's driver that no other driver has; saved for a
## profile, kept for an empty slot. Returns it.
func cycle_name(dir: int) -> String:
	var id := identity(card)
	var names := SaveData.names_free_for(card)
	var i := names.find(id["name"])
	id["name"] = names[posmod(i + dir, names.size())] if i >= 0 else names[0]
	_keep(id)
	return id["name"]


## The next avatar (by `dir`, through Cars.LIST) for the card's driver. Returns its car id.
func cycle_avatar(dir: int) -> String:
	var id := identity(card)
	var i := Cars.LIST.find(Cars.find(id["avatar"]))
	id["avatar"] = Cars.get_car(posmod(i + dir, Cars.LIST.size()))["id"]
	_keep(id)
	return id["avatar"]


func _keep(id: Dictionary) -> void:
	if SaveData.has_profile(card):
		SaveData.set_identity(card, id["name"], id["avatar"])
	else:
		pending[card] = {"slot": card, "name": id["name"], "avatar": id["avatar"]}


## Drives as the card's profile, making it first for an empty slot. Returns false when it
## couldn't be made.
func drive_as() -> bool:
	if not SaveData.has_profile(card):
		var id := identity(card)
		if SaveData.make_profile(id["name"], id["avatar"], card) < 0:
			return false
		pending.erase(card)
	SaveData.switch_to(card)
	return true


## Changes the row by `dir`; false for rows that hold no value.
func change(r: int, dir: int) -> bool:
	match r:
		Row.CARDS:
			pick_card(dir)
		Row.NAME:
			cycle_name(dir)
		Row.AVATAR:
			cycle_avatar(dir)
		_:
			return false
	return true


func handle(m: MenuInput) -> void:
	if m.step_y() != 0:
		move(m.step_y())
		Audio.play("tick")
	elif m.step() != 0:
		if change(row(), m.step()):
			Audio.play("tick")
	elif m.confirm_pressed:
		match row():
			Row.CARDS:
				if drive_as():
					Audio.play("beep")
					game.show_title(TitleScreen.items().find("PROFILE"))
			Row.BACK:
				Audio.play("beep")
				game.show_title(TitleScreen.items().find("PROFILE"))
			_:
				change(row(), 1)
				Audio.play("beep")
	elif m.back_pressed:
		game.show_title(TitleScreen.items().find("PROFILE"))


## Where card `s` goes.
static func card_rect(s: int) -> Rect2:
	var w := SaveData.MAX_PROFILES * CARD.x + (SaveData.MAX_PROFILES - 1) * CARD_GAP
	return Rect2(Vector2((Cfg.SCREEN_W - w) / 2.0 + s * (CARD.x + CARD_GAP), CARDS_Y), CARD)


func _draw() -> void:
	_backdrop(0.8)
	_header("DRIVERS")
	var on_cards := row() == Row.CARDS
	for s in SaveData.MAX_PROFILES:
		var r := card_rect(s)
		var picked := s == card
		var made := SaveData.has_profile(s)
		_frame(r, Color(GOLD, 0.35 + 0.15 * sin(time * 5.0)) if picked and on_cards else Color.TRANSPARENT)
		draw_rect(r, UiText.ink(0.9) if made else UiText.ink(0.6))
		if picked:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), GOLD)
		var id := identity(s)
		var pic := Rect2(r.position + Vector2((CARD.x - PIC.x) / 2.0, 14), PIC)
		draw_avatar(pic, id["avatar"], not made)
		_text(r.position + Vector2(7, 11), "P%d" % (s + 1), 8, Color(1, 1, 1, 0.6))
		if s == SaveData.slot:
			var tag := "DRIVING"
			_text(Vector2(r.end.x - 7 - _width(tag, 8), r.position.y + 11), tag, 8, Color("#5dff8a"))
		_text_centered(Vector2(r.get_center().x, pic.end.y + 22), id["name"], 16, (GOLD if picked else Color.WHITE) if made else Color(1, 1, 1, 0.5))
		if made:
			var sum := summary(s)
			_text_centered(Vector2(r.get_center().x, pic.end.y + 40), "STAGE %d   %d RACES" % [sum["stage"], sum["races"]], 9, Color(1, 1, 1, 0.7))
		else:
			_text_centered(Vector2(r.get_center().x, pic.end.y + 40), "NEW DRIVER", 9, SKY)
		_text_centered(Vector2(r.get_center().x, r.end.y - 10), _card_action(s), 9, Color(1, 1, 1, 0.55) if not picked else GOLD)

	var panel := Rect2(card_rect(0).position.x, ROWS_Y - 4, card_rect(SaveData.MAX_PROFILES - 1).end.x - card_rect(0).position.x, ROW_H * 3 + 4)
	_panel(panel, 0.85)
	var id := identity(card)
	var shown := {Row.NAME: id["name"], Row.AVATAR: String(Cars.find(id["avatar"])["name"]).to_upper()}
	for r: int in [Row.NAME, Row.AVATAR, Row.BACK]:
		var y := ROWS_Y + (r - 1) * ROW_H
		var on: bool = r == row()
		if on:
			draw_rect(Rect2(panel.position.x, y, panel.size.x, ROW_H - 4), Color(GOLD, 0.18 + 0.06 * sin(time * 5.0)))
			draw_rect(Rect2(panel.position.x, y, 3, ROW_H - 4), GOLD)
		var col := GOLD if on else Color.WHITE
		_text(Vector2(panel.position.x + 16, y + 13), LABELS[r] if r == Row.BACK else "%s  (P%d)" % [LABELS[r], card + 1], 12, col)
		if shown.has(r):
			var t: String = shown[r]
			var right := panel.end.x - 20
			_text(Vector2(right - 90 - _width(t, 12) / 2.0, y + 13), t, 12, col)
			if on:
				_small_arrow(Vector2(right - 180, y + 8), -1)
				_small_arrow(Vector2(right, y + 8), 1)
	_text_centered(Vector2(Cfg.SCREEN_W / 2.0, panel.end.y + 18), HELP[row()], 10, Color(1, 1, 1, 0.85))
	_footer(options_like_hints())


## What selecting card `s` does, under it.
func _card_action(s: int) -> String:
	if s == SaveData.slot:
		return "DRIVING NOW"
	return "SELECT: DRIVE" if SaveData.has_profile(s) else "SELECT: MAKE"


static func options_like_hints() -> String:
	match InputRouter.state.kind:
		DriveInput.Kind.GAMEPAD, DriveInput.Kind.WHEEL:
			return "D-pad Up / Down: choose    Left / Right: change    A: select    B: back"
	return "Up / Down: choose    Left / Right: change    Enter: select    Esc: back"


func _small_arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -6), c + Vector2(-4 * d, 6)]), GOLD)
