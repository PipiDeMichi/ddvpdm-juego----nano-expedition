shader_type canvas_item;
// White hit-flash. Set `flash` (0..1) to 1 for a fully white blink, then tween
// it back to 0. Mixes the sprite toward white so it works on any base color,
// while keeping transparency intact (flash * alpha).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0), flash * c.a);
	COLOR = c;
}
