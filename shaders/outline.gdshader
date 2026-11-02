// 1px dark outline around everything drawn inside a CanvasGroup.
// Put the sword's part sprites (and the hand) under one CanvasGroup and give the group this material,
// so the assembled sword gets one clean outline instead of one per part.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.024, 0.027, 0.039, 1.0);
// Screen pixels per game pixel (2 in a 1280x720 window). Set by the game.
uniform float px = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a < 0.5) {
		vec2 p = SCREEN_PIXEL_SIZE * px;
		float n = textureLod(screen_texture, SCREEN_UV + vec2(p.x, 0.0), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV - vec2(p.x, 0.0), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV + vec2(0.0, p.y), 0.0).a
			+ textureLod(screen_texture, SCREEN_UV - vec2(0.0, p.y), 0.0).a;
		COLOR = n > 0.5 ? outline_color : vec4(0.0);
	} else {
		COLOR = c;
	}
}
