shader_type canvas_item;
// The Display page's scanline filter: every other row of the 640x360 view darkened a little,
// with a soft vignette, drawn over the whole screen (Settings.apply_display).

uniform float darkness : hint_range(0.0, 1.0) = 0.28;
uniform float vignette : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float row = mod(floor(FRAGCOORD.y), 2.0);
	vec2 c = SCREEN_UV - 0.5;
	float edge = smoothstep(0.35, 0.75, length(c)) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(row * darkness + edge, 0.0, 1.0));
}
