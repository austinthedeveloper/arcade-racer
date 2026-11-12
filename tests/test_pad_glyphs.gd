## Button glyphs (WH-14, PadGlyphs): the family a device's name gives, what each family draws
## for each button, and how hints and bindings are cut into text and glyphs.
extends TestSuite

const F := PadGlyphs.Family


func test_the_family_comes_from_the_device_name() -> void:
	for n in ["Xbox Wireless Controller", "Xbox 360 Controller", "XInput Controller", "Microsoft X-Box One pad"]:
		eq(PadGlyphs.family_for(n, false), F.XBOX, n)
	for n in ["PS5 Controller", "DualSense Wireless Controller", "Sony DualShock 4", "PS4 Controller", "PLAYSTATION(R)3 Controller"]:
		eq(PadGlyphs.family_for(n, false), F.PLAYSTATION, n)
	for n in ["8BitDo SN30 Pro", "USB Gamepad", "Nintendo Switch Pro Controller", ""]:
		eq(PadGlyphs.family_for(n, false), F.GENERIC, n + ": a generic pad")
	eq(PadGlyphs.family_for("Thrustmaster TMX Racing Wheel", true), F.WHEEL, "a wheel")
	eq(PadGlyphs.family_for("Xbox Wireless Controller", true), F.WHEEL, "read as a wheel: wheel glyphs")


func test_a_profile_gives_its_family_and_the_keyboard_none() -> void:
	eq(PadGlyphs.family_of(DeviceProfile.keyboard()), F.NONE, "the keyboard stays text")
	eq(PadGlyphs.family_of(null), F.NONE, "no profile")
	var p := DeviceProfile.new()
	p.name = "DualSense Wireless Controller"
	eq(PadGlyphs.family_of(p), F.PLAYSTATION, "a PlayStation pad")
	p.kind = DeviceProfile.Kind.WHEEL
	eq(PadGlyphs.family_of(p), F.WHEEL, "a wheel profile")


func test_the_dev_flag_forces_a_family() -> void:
	eq(PadGlyphs.forced_in(PackedStringArray(["--pad-family=playstation"])), F.PLAYSTATION, "playstation")
	eq(PadGlyphs.forced_in(PackedStringArray(["--pad-family=Xbox"])), F.XBOX, "any case")
	eq(PadGlyphs.forced_in(PackedStringArray(["--pad-family=wheel"])), F.WHEEL, "wheel")
	eq(PadGlyphs.forced_in(PackedStringArray(["--pad-family=nonsense"])), F.NONE, "unknown: none")
	eq(PadGlyphs.forced_in(PackedStringArray()), F.NONE, "no flag")


func test_xbox_glyphs() -> void:
	var a := PadGlyphs.glyph(F.XBOX, JOY_BUTTON_A)
	eq([a["shape"], a["label"]], [PadGlyphs.Shape.FACE, "A"], "A is a lettered face button")
	eq(a["color"], Color("#5fd35a"), "green")
	eq(PadGlyphs.glyph(F.XBOX, JOY_BUTTON_Y)["label"], "Y", "Y")
	eq(PadGlyphs.glyph(F.XBOX, JOY_BUTTON_RIGHT_SHOULDER), {"shape": PadGlyphs.Shape.SHOULDER, "label": "RB"}, "RB tab")
	eq(PadGlyphs.glyph(F.XBOX, PadGlyphs.TRIGGER_RIGHT)["label"], "RT", "RT")
	eq(PadGlyphs.glyph(F.XBOX, JOY_BUTTON_START)["label"], "MENU", "Start is Menu")


func test_playstation_glyphs() -> void:
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_A)["mark"], "cross", "A is the cross")
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_B)["mark"], "circle", "B the circle")
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_X)["mark"], "square", "X the square")
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_Y)["mark"], "triangle", "Y the triangle")
	check(not PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_A).has("label"), "no letter on it")
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_LEFT_SHOULDER)["label"], "L1", "L1")
	eq(PadGlyphs.glyph(F.PLAYSTATION, PadGlyphs.TRIGGER_LEFT), {"shape": PadGlyphs.Shape.TRIGGER, "label": "L2"}, "L2")
	eq(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_START)["label"], "OPTIONS", "Start is Options")


func test_generic_pad_glyphs() -> void:
	var a := PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_A)
	eq([a["shape"], a["dir"]], [PadGlyphs.Shape.FACE, Vector2(0, 1)], "A: the bottom of the diamond")
	eq(PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_Y)["dir"], Vector2(0, -1), "Y: the top")
	eq(PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_RIGHT_SHOULDER)["label"], "R1", "R1")
	eq(PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_BACK)["label"], "SELECT", "Back is Select")
	eq(PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_DPAD_LEFT), {"shape": PadGlyphs.Shape.DPAD, "dir": Vector2(-1, 0)}, "D-pad left")
	eq(PadGlyphs.glyph(F.GENERIC, JOY_BUTTON_LEFT_STICK)["shape"], PadGlyphs.Shape.STICK, "L3 a stick")


func test_wheel_glyphs_are_labelled_tabs() -> void:
	eq(PadGlyphs.glyph(F.WHEEL, 5), {"shape": PadGlyphs.Shape.TAB, "label": "5"}, "a numbered button")
	eq(PadGlyphs.glyph(F.WHEEL, JOY_BUTTON_A)["label"], "A", "A")
	eq(PadGlyphs.glyph(F.WHEEL, JOY_BUTTON_DPAD_UP)["shape"], PadGlyphs.Shape.DPAD, "its hat is a D-pad")
	eq(PadGlyphs.glyph(F.WHEEL, 99), {}, "past the buttons: text")


func test_the_keyboard_has_no_glyphs() -> void:
	eq(PadGlyphs.glyph(F.NONE, JOY_BUTTON_A), {}, "nothing")
	eq(PadGlyphs.pieces("Enter: select    Esc: back", F.NONE), ["Enter: select    Esc: back"], "text stays")


func test_words_name_codes() -> void:
	eq(PadGlyphs.code_for("A"), JOY_BUTTON_A, "A")
	eq(PadGlyphs.code_for("d-pad up"), JOY_BUTTON_DPAD_UP, "any case")
	eq(PadGlyphs.code_for("BUTTON 7"), 7, "a wheel's button by number")
	eq(PadGlyphs.code_for("SPACE"), -1, "a key: none")
	# Every pad button the remap screen names has a glyph in every pad family.
	for code: int in DeviceProfile.PAD_BUTTON_NAMES:
		var word: String = DeviceProfile.PAD_BUTTON_NAMES[code]
		for family in [F.XBOX, F.PLAYSTATION, F.GENERIC]:
			check(not PadGlyphs.glyph(family, PadGlyphs.code_for(word)).is_empty(), "%s in family %d" % [word, family])


func test_hints_become_glyphs_and_their_words() -> void:
	eq(PadGlyphs.pieces("D-pad: choose    A: select    B: back", F.XBOX),
		[PadGlyphs.DPAD, ": choose    ", JOY_BUTTON_A, ": select    ", JOY_BUTTON_B, ": back"], "the menu hints")
	eq(PadGlyphs.pieces("D-pad Up / Down: choose    Left / Right: device", F.PLAYSTATION),
		[PadGlyphs.DPAD_UP_DOWN, ": choose    ", PadGlyphs.DPAD_LEFT_RIGHT, ": device"], "up and down make one D-pad")
	eq(PadGlyphs.pieces("B / Start: resume", F.GENERIC), [JOY_BUTTON_B, " / ", JOY_BUTTON_START, ": resume"], "two buttons")
	eq(PadGlyphs.pieces("Hold any button: faster   B: back", F.XBOX), ["Hold any button: faster   B: back"],
		"a part with a word that isn't a button stays text")


func test_bindings_become_glyphs_or_stay_text() -> void:
	eq(PadGlyphs.pieces("RB", F.XBOX, true), [JOY_BUTTON_RIGHT_SHOULDER], "a binding")
	eq(PadGlyphs.pieces("RT / A", F.XBOX, true), [PadGlyphs.TRIGGER_RIGHT, " / ", JOY_BUTTON_A], "the card's gas")
	eq(PadGlyphs.pieces("LEFT STICK / D-PAD", F.PLAYSTATION, true), [PadGlyphs.STICK_LEFT, " / ", PadGlyphs.DPAD], "steering")
	eq(PadGlyphs.pieces("---", F.XBOX, true), ["---"], "unbound stays text")
	eq(PadGlyphs.pieces("BUTTON 5", F.WHEEL, true), [5], "a wheel's button")
	eq(PadGlyphs.pieces("D-PAD, A SELECT, B BACK", F.XBOX, true), ["D-PAD, A SELECT, B BACK"], "a sentence stays text")


func test_glyph_widths() -> void:
	var h := PadGlyphs.glyph_height(9)
	eq(int(h) % 2, 1, "odd, so it has a middle pixel")
	eq(PadGlyphs.width(PadGlyphs.glyph(F.XBOX, JOY_BUTTON_A), h, 6), h, "a face button is round")
	check(PadGlyphs.width(PadGlyphs.glyph(F.PLAYSTATION, JOY_BUTTON_START), h, 6) > h, "OPTIONS is wider")
	var list := PadGlyphs.pieces("A: select", F.XBOX)
	check(absf(PadGlyphs.pieces_width(list, 9, F.XBOX) - (h + UiText.width(": select", 9))) < 0.01, "glyph plus text")


func test_the_card_and_the_remap_screen_pick_families() -> void:
	eq(ControlsCard.card_family(ControlsCard.Device.KEYBOARD), F.NONE, "keyboard tab: text")
	eq(ControlsCard.card_family(ControlsCard.Device.WHEEL), F.WHEEL, "wheel tab")
	check(ControlsCard.card_family(ControlsCard.Device.GAMEPAD) != F.NONE, "gamepad tab: a pad family")
	var r := RemapScreen.new()
	eq(r.devices().size(), InputRouter.binding_devices().size(), "nothing staged")
	r.stage(F.PLAYSTATION)
	eq([r.device(), r.device_name()], [RemapScreen.STAGED, "DUALSENSE WIRELESS CONTROLLER"], "opens on the staged pad")
	eq(PadGlyphs.family_of(r.profile()), F.PLAYSTATION, "drawn in its family")
	r.flip_device(-1)
	eq(r.device(), -1, "the keyboard is still first")
	r.free()
