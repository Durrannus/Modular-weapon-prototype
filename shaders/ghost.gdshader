// Ghostwield's sword: whatever is drawn inside the CanvasGroup becomes a
// see-through copy in the ghost's colours, with a bright edge, never dimmed by
// the dark. (Same trick as outline.gdshader: the group is drawn once, then
// recoloured.) The colours are the art's Ghostwield ramp, dark to light.
shader_type canvas_item;
render_mode unshaded;

// Screen pixels per game pixel (2 in a 1280x720 window). Set by the game.
uniform float px = 1.0;
// 0 to 1: how solid it is right now (it shimmers, and blinks before it goes).
uniform float strength = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

vec3 ramp(float l) {
	vec3 c0 = vec3(0.102, 0.141, 0.314);
	vec3 c1 = vec3(0.227, 0.235, 0.549);
	vec3 c2 = vec3(0.416, 0.439, 0.816);
	vec3 c3 = vec3(0.659, 0.706, 1.0);
	if (l < 0.3) {
		return mix(c0, c1, l / 0.3);
	}
	if (l < 0.6) {
		return mix(c1, c2, (l - 0.3) / 0.3);
	}
	return mix(c2, c3, clamp((l - 0.6) / 0.4, 0.0, 1.0));
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a < 0.5) {
		vec2 p = SCREEN_PIXEL_SIZE * px;
		float n = textureLod(screen_texture, SCREEN_UV + vec2(p.x, 0.0), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV - vec2(p.x, 0.0), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV + vec2(0.0, p.y), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV - vec2(0.0, p.y), 0.0).a;
		// The edge: the ramp's lightest colour, nearly solid.
		COLOR = n > 0.5 ? vec4(0.82, 0.86, 1.0, 0.95 * strength) : vec4(0.0);
	} else {
		// The sword's own light and dark, a step down the ramp so the edge stands out.
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(ramp(l * 0.8), 0.62 * strength);
	}
}
