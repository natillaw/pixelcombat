// D-113 (pista C): reusable wind for trees, grass and bushes. Pixel art: every shift is whole pixels.
// sprite_mode (separate sprites: town trees, bushes): the top of the sprite sways, the base stays put,
//   the phase comes from the sprite's world position so neighbours never move in step.
// baked mode (a whole baked map texture): canopy pixels (green, dark) shift by one texel in gusts that
//   travel across the map; ground, paths, rocks and units are never touched.
shader_type canvas_item;

uniform bool sprite_mode = true;
uniform float strength = 1.5;         // px at the top of a sprite (sprite mode)
uniform float speed = 1.4;
uniform float gust_speed = 0.35;
uniform float phase_scale = 0.045;    // phase change per world px
uniform float canopy_max_luma = 0.42; // baked mode: only darker greens count as foliage

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (sprite_mode) {
		vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
		float phase = TIME * speed + origin.x * phase_scale + origin.y * phase_scale * 0.6;
		float gust = 0.6 + 0.4 * sin(TIME * gust_speed + origin.x * 0.004);
		float top = 1.0 - UV.y;                     // 1 at the top of the sprite, 0 at its feet
		VERTEX.x += floor(sin(phase) * strength * gust * top + 0.5);
	}
}

bool is_canopy(vec4 c) {
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	return c.a > 0.5 && c.g > c.r * 1.05 && c.g > c.b * 1.05 && luma < canopy_max_luma;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (!sprite_mode && is_canopy(c)) {
		vec2 texel = UV / TEXTURE_PIXEL_SIZE;
		float phase = TIME * speed + texel.x * phase_scale * 0.5 + texel.y * phase_scale * 0.3;
		float gust = 0.5 + 0.5 * sin(TIME * gust_speed - texel.x * 0.006 + texel.y * 0.002);
		float shift = step(0.55, sin(phase) * gust);   // 0 or 1 texel
		vec4 n = texture(TEXTURE, UV + vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0));
		if (is_canopy(n)) {
			c = n;
		}
	}
	COLOR = c * COLOR;
}
