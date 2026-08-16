shader_type canvas_item;
// Pulsing hexagon energy-shield for the player's grenade. Drawn on a Polygon2D
// hexagon mesh. Uses VERTEX (local coords) as UV so the pattern tracks the hexagon.

uniform vec4 color : source_color = vec4(0.40, 0.92, 1.0, 0.35);
uniform float radius : hint_range(1.0, 400.0) = 121.24; // hexagon apothem (matches mesh)
uniform float edge_width : hint_range(0.5, 12.0) = 3.5;
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.2;

void vertex() {
	UV = VERTEX; // local-space position -> UV
}

// Signed distance to a pointy-top hexagon (negative inside).
float sdHexagon(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

void fragment() {
	vec2 p = UV;
	float d = sdHexagon(p, radius);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);

	// Interior fill, stronger near the boundary for an "energy field" look.
	float fill = 1.0 - smoothstep(0.0, radius * 0.5, -d);

	// Bright rim that pulses.
	float rim = 1.0 - smoothstep(0.0, edge_width, abs(d));
	float rim_g = rim * (0.65 + 0.35 * pulse);

	// Faint honeycomb cell grid across the face.
	vec2 hp = p * 0.055;
	float g = sdHexagon(vec2(fract(hp.x + 0.5) - 0.5, fract(hp.y + 0.5) - 0.5), 0.5);
	float cell = 1.0 - smoothstep(0.0, 0.06, abs(g));

	vec3 col = color.rgb * (0.55 + 0.45 * pulse) * fill;
	col += vec3(0.55, 0.95, 1.0) * rim_g;
	col += vec3(0.4, 0.85, 1.0) * cell * 0.12 * (0.5 + 0.5 * pulse);

	float aa = clamp((radius + d) / 2.0, 0.0, 1.0); // inside mask (polygon already clips)
	COLOR = vec4(col, color.a * (0.6 + 0.4 * pulse) * aa);
}
