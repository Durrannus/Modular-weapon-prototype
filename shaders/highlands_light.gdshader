// The Highlands' light on the land (version 68: step 3 of the new look, after the Art builder's light concept v2/v4).
// Every chunk of painted land is drawn through this, with what scripts/highlands/land_light.gd worked out for it.
// What lies away from light takes the light of where it is: daylight out in the open, the dark under the hill (three
// hard steps, deeper the further from open ground), night if the lab's day and night is on. Away from daylight its
// colours go part way to their own brightness in a cool hue, so the dark is blue-violet, not muddy. Lamps, fires and
// everybody's small light light pools in three hard steps with a one-pixel checker where two steps meet: no gradient,
// no bloom. A pool takes its colour toward the light's warmth, never past the colour's own top. The undug rock's top
// stops light and takes none; the cut face of a wall catches it. Ore on a lit face shines in its own colour, with a
// two-step halo (copper warm, tin cool), and the old tunnels' fungi glow gold.
shader_type canvas_item;
render_mode unshaded;

// 32 x 32 tiles round the chunk (8 each side): r how dark, g the rock (0 open; 0.5 a rock with open ground south of
// it, whose lower part is its lit face; 1 the rock's top all through), b how deep in the snow.
uniform sampler2D tiles : filter_nearest;
// The chunk's own pixels: r 1 shines in its own colour, 2/3 and 1/3 its halo; g which glow (0 copper, 0.5 tin, 1 fungi).
uniform sampler2D glow : filter_nearest;
uniform bool has_glow = false;
uniform vec2 origin;                    // the chunk's top left, art pixels on the map
uniform int lamp_n = 0;
uniform vec4 lamps[24];                 // x, y (art pixels from the chunk's top left), reach, strength (+2: a fire's light)
uniform int player_n = 0;
uniform vec4 players[4];                // where everybody carries their small light: x, y (art pixels on the map)
uniform float night = 0.0;              // 0 day, 1 night
uniform vec3 deep_col = vec3(0.30, 0.30, 0.44);
uniform vec3 night_col = vec3(0.46, 0.46, 0.72);
uniform vec3 snow_day = vec3(0.90, 0.95, 1.0);
uniform vec3 snow_night = vec3(1.3, 1.43, 1.19);
uniform vec3 lamp_warm = vec3(1.0, 0.96, 0.88);
uniform vec3 fire_warm = vec3(1.10, 0.90, 0.70);
uniform float player_reach = 30.0;
uniform float player_light = 0.5;

const float PADT = 8.0;
const vec3 COOLTINT = vec3(0.62, 0.66, 1.0);
const vec3 COPPER = vec3(1.2, 0.95, 0.75);
const vec3 TIN = vec3(1.0, 1.06, 1.1);
const vec3 FUNGI = vec3(1.3, 1.1, 0.7);

vec4 tile_at(vec2 p) {
	ivec2 t = clamp(ivec2(floor(p / 16.0) + PADT), ivec2(0), ivec2(31));
	return texelFetch(tiles, t, 0);
}

// Is this point (the chunk's own pixels) on the rock's dark top?
bool top_at(vec2 p) {
	float g = tile_at(p).g;
	return g > 0.75 || (g > 0.25 && mod(p.y, 16.0) < 6.0);
}

// Three hard steps, with a one-pixel checker on the rim of each (the concept's bands3).
float steps3(float v, vec2 w) {
	float q = clamp(v, 0.0, 1.0) * 3.0;
	float k = floor(q);
	if (q - k > 0.82 && mod(w.x + w.y, 2.0) < 1.0) {
		k += 1.0;
	}
	return min(k, 3.0) / 3.0;
}

// The ring of a pool a point is in (3 in the middle, 0 outside), with a checker where two rings meet. As the
// painter's lamplight on dug floor (land_painter.gd, _light), so the two pools are one.
int ring_of(float dd, vec2 w) {
	if (dd >= 1.05) {
		return 0;
	}
	int ring = dd < 0.42 ? 3 : (dd < 0.72 ? 2 : (dd < 1.0 ? 1 : 0));
	bool edge = abs(dd - 0.42) < 0.05 || abs(dd - 0.72) < 0.05 || abs(dd - 1.0) < 0.05;
	if (edge && mod(w.x + w.y, 4.0) < 2.0 && ring > 0) {
		ring -= 1;
	}
	return ring;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 B = base.rgb;
	vec2 pix = floor(UV * 256.0);
	vec2 p = pix + 0.5;                 // this pixel's middle, from the chunk's top left
	vec2 w = origin + pix;              // this pixel on the map
	bool top = top_at(p);
	// How dark it is here, and how deep in the snow (both smooth between tiles, then the dark in steps).
	vec2 q = p / 16.0 - 0.5 + PADT;
	vec2 i0 = floor(q);
	vec2 f = q - i0;
	ivec2 a = clamp(ivec2(i0), ivec2(0), ivec2(31));
	ivec2 b = clamp(ivec2(i0) + 1, ivec2(0), ivec2(31));
	vec4 t00 = texelFetch(tiles, a, 0);
	vec4 t10 = texelFetch(tiles, ivec2(b.x, a.y), 0);
	vec4 t01 = texelFetch(tiles, ivec2(a.x, b.y), 0);
	vec4 t11 = texelFetch(tiles, b, 0);
	vec4 tm = mix(mix(t00, t10, f.x), mix(t01, t11, f.x), f.y);
	float dark = top ? 0.0 : steps3(tm.r, w);   // (the rock's top keeps its own dark colour under the hill: it is not lit)
	float snow = smoothstep(0.0, 1.0, tm.b);
	vec3 away = mix(mix(vec3(1.0), night_col, night), deep_col, dark);
	away *= mix(vec3(1.0), mix(snow_day, snow_night, night), snow);
	float dim = clamp((1.0 - (away.r + away.g + away.b) / 3.0) / 0.55, 0.0, 1.0);
	if (top) {
		away *= mix(1.0, 0.75, night);  // the rock's top darker still at night
	}
	float k = 0.45 * dim;
	float lum = dot(B, vec3(0.30, 0.59, 0.11));
	vec3 cool = B * away * (1.0 - k) + lum * away * COOLTINT * k * 1.15;
	// The pools: the brightest light that reaches here, unless the rock's top is in its way.
	float L = 0.0;
	vec3 warm = lamp_warm;
	if (!top) {
		for (int i = 0; i < lamp_n; i++) {
			vec4 l = lamps[i];
			float s = l.w;
			vec3 wc = lamp_warm;
			if (s >= 2.0) {
				s -= 2.0;
				wc = fire_warm;
			}
			vec2 d = p - l.xy;
			d.y *= 1.3;
			int ring = ring_of(length(d) / l.z, w);
			float lv = float(ring) / 3.0 * s;
			if (lv <= L) {
				continue;
			}
			bool blocked = false;
			for (int j = 1; j < 12; j++) {
				if (top_at(mix(l.xy, p, float(j) / 12.0))) {
					blocked = true;
					break;
				}
			}
			if (!blocked) {
				L = lv;
				warm = wc;
			}
		}
		for (int i = 0; i < player_n; i++) {
			vec2 d = w - players[i].xy;
			d.y *= 1.3;
			float dd = length(d) / player_reach;
			if (dd >= 1.05) {
				continue;
			}
			float r = dd < 0.55 ? 2.0 : (dd < 1.0 ? 1.0 : 0.0);
			if ((abs(dd - 0.55) < 0.06 || abs(dd - 1.0) < 0.06) && mod(w.x + w.y, 4.0) < 2.0 && r > 0.0) {
				r -= 1.0;
			}
			float lv = r / 2.0 * player_light;
			if (lv > L) {
				L = lv;
				warm = lamp_warm;
			}
		}
	}
	vec3 col = mix(cool, min(B * warm, vec3(1.0)), L);
	if (has_glow) {
		vec4 g = texelFetch(glow, ivec2(pix), 0);
		if (g.r > 0.9) {
			col = B;                    // ore on a lit face shines in its own colour
		} else if (g.r > 0.1) {
			vec3 hue = g.g < 0.25 ? COPPER : (g.g < 0.75 ? TIN : FUNGI);
			float h = (g.r > 0.5 ? 0.8 : 0.4) * dim;
			col = mix(col, max(col, min(B * hue, vec3(1.0))), h);
		}
	}
	COLOR = vec4(col, base.a);
}
