shader_type canvas_item;
// Combined enemy status shader: white hit-flash (as before) PLUS a cyan "glitch"
// that appears while the enemy is slowed by the player's grenade zone.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_strength : hint_range(1.0, 20.0) = 6.0;
uniform float glitch_rate : hint_range(1.0, 30.0) = 12.0;
uniform vec4 cyan : source_color = vec4(0.5, 0.95, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float split = 0.0;
	if (glitch > 0.001) {
		float rows = 7.0;
		float row = floor(uv.y * rows);
		float t = floor(TIME * glitch_rate) + row;
		float jitter = hash(vec2(row, t)) - 0.5;
		uv.x += jitter * glitch_strength * glitch * TEXTURE_PIXEL_SIZE.x * 3.0;
		split = glitch * (0.5 + 0.5 * hash(vec2(row, t + 5.0))) * TEXTURE_PIXEL_SIZE.x * 1.5;
	}

	// White hit-flash first (preserved existing behaviour).
	vec4 base = texture(TEXTURE, uv);
	base.rgb = mix(base.rgb, vec3(1.0), flash * base.a);

	// Cyan glitch tint plus RGB channel split (chromatic "break").
	vec3 col = base.rgb;
	if (glitch > 0.001) {
		float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
		col = vec3(r, col.g, b);
		col = mix(col, col * cyan.rgb, glitch * 0.5);
	}
	COLOR = vec4(col, base.a);
}
