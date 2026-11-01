class_name ColorVision
extends RefCounted
## How a color looks with the common color vision deficiencies, for checking the HUD's
## palette (Hud.MUST_DIFFER, AC-4): the Machado, Oliveira and Fernandes (2009) simulation at
## full severity, applied in linear RGB. tools/colorblind.py runs the same matrices over a
## screenshot.

enum Deficiency { PROTANOPIA, DEUTERANOPIA, TRITANOPIA }

const MATRICES := {
	Deficiency.PROTANOPIA: [
		[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	Deficiency.DEUTERANOPIA: [
		[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	Deficiency.TRITANOPIA: [
		[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


## `c` as seen with `d` (sRGB in, sRGB out).
static func simulate(c: Color, d: Deficiency) -> Color:
	var lin := c.srgb_to_linear()
	var rgb := [lin.r, lin.g, lin.b]
	var out := [0.0, 0.0, 0.0]
	var m: Array = MATRICES[d]
	for row in 3:
		for k in 3:
			out[row] += m[row][k] * rgb[k]
	return Color(clampf(out[0], 0.0, 1.0), clampf(out[1], 0.0, 1.0), clampf(out[2], 0.0, 1.0), c.a).linear_to_srgb()


## Relative luminance (WCAG), 0 black to 1 white.
static func luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


## The WCAG contrast ratio between two colors: 1 the same brightness, 21 black on white.
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The contrast between `a` and `b` as someone with `d` sees them.
static func contrast_with(a: Color, b: Color, d: Deficiency) -> float:
	return contrast(simulate(a, d), simulate(b, d))
