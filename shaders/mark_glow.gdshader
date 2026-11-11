// A sprite's whole body lit up in one colour, with a bright one-pixel rim: an enemy
// carrying a Weak Point mark. Added on top of the sprite and never dimmed.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.72, 0.96, 1.0, 1.0);
// How strongly the inside of the body is lit (the rim is always full).
uniform float fill = 0.4;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 p = TEXTURE_PIXEL_SIZE;
	float a = step(0.5, texture(TEXTURE, UV).a);
	float n = max(max(texture(TEXTURE, UV + vec2(p.x, 0.0)).a, texture(TEXTURE, UV - vec2(p.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, p.y)).a, texture(TEXTURE, UV - vec2(0.0, p.y)).a));
	float inner = max(max(1.0 - step(0.5, texture(TEXTURE, UV + vec2(p.x, 0.0)).a), 1.0 - step(0.5, texture(TEXTURE, UV - vec2(p.x, 0.0)).a)),
		max(1.0 - step(0.5, texture(TEXTURE, UV + vec2(0.0, p.y)).a), 1.0 - step(0.5, texture(TEXTURE, UV - vec2(0.0, p.y)).a)));
	// The rim: the body's own outermost pixels (so it shows even where the picture
	// fills its frame), and the empty pixels just outside it.
	float rim = max(a * inner, (1.0 - a) * step(0.5, n));
	COLOR = vec4(tint.rgb, max(rim, a * fill) * tint.a * modulate.a);
}
