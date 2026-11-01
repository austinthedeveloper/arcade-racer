## The colorblind-safe HUD (AC-4): the simulation (ColorVision), the palette's states
## apart in brightness for each deficiency, and the power-up icons apart in silhouette.
extends TestSuite

const ALL := [ColorVision.Deficiency.PROTANOPIA, ColorVision.Deficiency.DEUTERANOPIA, ColorVision.Deficiency.TRITANOPIA]
const NAMES := ["protanopia", "deuteranopia", "tritanopia"]
## What the HUD's power-up slot can show once a pickup opens (Hud.slot_icon; a mystery
## hubcap always opens into one of these, so its own icon never shows there).
const ICONS := ["icon_nitro", "icon_clock", "icon_ram", "icon_ghost"]
const MAX_SILHOUETTE_OVERLAP := 0.75  # intersection over union of two icons' shapes, at most (today 0.69 at worst)


func test_simulation_keeps_greys() -> void:
	for d in ALL:
		for g in [0.0, 0.2, 0.5, 1.0]:
			var c := ColorVision.simulate(Color(g, g, g), d)
			check(absf(c.r - g) < 0.01 and absf(c.g - g) < 0.01 and absf(c.b - g) < 0.01,
				"%s keeps grey %.1f: %s" % [NAMES[d], g, c])


func test_simulation_confuses_what_it_should() -> void:
	var red := Color("#d03030")
	var green := Color("#6a8a20")
	var hue_gap := func(a: Color, b: Color) -> float: return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
	var seen: float = hue_gap.call(red, green)
	var deutan: float = hue_gap.call(ColorVision.simulate(red, ColorVision.Deficiency.DEUTERANOPIA),
		ColorVision.simulate(green, ColorVision.Deficiency.DEUTERANOPIA))
	check(deutan < seen * 0.5, "red and olive green run together for deuteranopia: %.2f vs %.2f" % [deutan, seen])
	check(ColorVision.luminance(ColorVision.simulate(Color.RED, ColorVision.Deficiency.PROTANOPIA)) < ColorVision.luminance(Color.RED),
		"red looks darker with protanopia")
	near(ColorVision.contrast(Color.BLACK, Color.WHITE), 21.0, 0.01, "black on white")
	near(ColorVision.contrast(Color.RED, Color.RED), 1.0, 0.0001, "a color on itself")


func test_hud_states_differ_in_brightness() -> void:
	for pair: Array in Hud.MUST_DIFFER:
		var a: Color = Hud.PALETTE[pair[0]]
		var b: Color = Hud.PALETTE[pair[1]]
		var plain := ColorVision.contrast(a, b)
		check(plain >= Hud.MIN_STATE_CONTRAST, "%s / %s: %.2f" % [pair[0], pair[1], plain])
		for d in ALL:
			var c := ColorVision.contrast_with(a, b, d)
			check(c >= Hud.MIN_STATE_CONTRAST, "%s / %s with %s: %.2f" % [pair[0], pair[1], NAMES[d], c])


func test_every_must_differ_color_is_in_the_palette() -> void:
	for pair: Array in Hud.MUST_DIFFER:
		check(Hud.PALETTE.has(pair[0]) and Hud.PALETTE.has(pair[1]), str(pair))


## An icon's shape: its alpha, cropped to what's drawn, centered on a square (keeping its
## proportions, as the slot draws it) and scaled to `size`.
func _silhouette(icon: String, size: int) -> PackedByteArray:
	var src := PowerUps.texture(icon).get_image()
	src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	var side := maxi(used.size.x, used.size.y)
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, used, (Vector2i(side, side) - used.size) / 2)
	img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	var out := PackedByteArray()
	for y in size:
		for x in size:
			out.append(1 if img.get_pixel(x, y).a > 0.5 else 0)
	return out


func test_power_up_icons_differ_in_silhouette() -> void:
	var shapes := {}
	for icon in ICONS:
		shapes[icon] = _silhouette(icon, 24)
	for i in ICONS.size():
		for j in range(i + 1, ICONS.size()):
			var a: PackedByteArray = shapes[ICONS[i]]
			var b: PackedByteArray = shapes[ICONS[j]]
			var both := 0
			var either := 0
			for k in a.size():
				both += a[k] & b[k]
				either += a[k] | b[k]
			var iou := float(both) / maxf(1.0, either)
			check(iou < MAX_SILHOUETTE_OVERLAP, "%s and %s overlap %.2f" % [ICONS[i], ICONS[j], iou])


func test_state_shapes() -> void:
	var sign := Hud.warning_sign(Vector2(50, 50), 14.0)
	eq(sign.size(), 3, "the low-time sign is a triangle")
	check(sign[0].y < sign[1].y, "point up")
	var crown := Hud.crown(Vector2(50, 50), 18.0, 11.0)
	check(Geometry2D.triangulate_polygon(crown).size() > 0, "the leader's crown is a simple polygon")
	var box := Rect2(crown[0], Vector2.ZERO)
	for p in crown:
		box = box.expand(p)
	eq(box, Rect2(41, 39, 18, 11), "standing on its base")
