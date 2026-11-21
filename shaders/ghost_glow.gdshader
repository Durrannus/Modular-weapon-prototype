// A glowing effect (a swing's smear, a spark, a rune's wave) redrawn in the
// ghost's colours: Ghostwield's copies of your swings and of your passive runes.
// Keeps the picture's light and dark and swaps its colours for the art's
// Ghostwield ramp. It glows like the real effect, but also covers a little of
// what is behind it, so it stays pale green on a bright floor instead of
// washing out to white.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// How much of what is behind it the effect covers (0: purely added light).
uniform float cover = 0.6;

vec3 ramp(float l) {
	// (Verdigris, the game's colour for what is old or asleep: 12383e, 2a7f70,
	// 86d4a4, c8f0c4. It was a blue-violet ramp until 21 November.)
	vec3 c0 = vec3(0.071, 0.220, 0.243);
	vec3 c1 = vec3(0.165, 0.498, 0.439);
	vec3 c2 = vec3(0.525, 0.831, 0.643);
	vec3 c3 = vec3(0.784, 0.941, 0.769);
	if (l < 0.3) {
		return mix(c0, c1, l / 0.3);
	}
	if (l < 0.6) {
		return mix(c1, c2, (l - 0.3) / 0.3);
	}
	if (l < 0.9) {
		return mix(c2, c3, (l - 0.6) / 0.3);
	}
	return mix(c3, vec3(1.0), (l - 0.9) / 0.1);
}

void fragment() {
	vec4 c = COLOR;
	float l = max(c.r, max(c.g, c.b));
	COLOR = vec4(ramp(l) * c.a, cover * c.a * smoothstep(0.0, 0.25, l));
}
