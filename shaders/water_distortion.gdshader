shader_type canvas_item;
// "Water drop" screen distortion. Samples the screen behind this node and bends
// it with a radial ripple that expands outward from `center_uv` as `progress`
// goes 0 -> 1. Designed to run on a fullscreen ColorRect so the whole view ripples
// like a water drop while the HUD (drawn above) stays crisp.
//
// NOTE (Godot 4.7): the built-in SCREEN_TEXTURE was removed, so it must be
// declared explicitly as a screen-texture sampler. Use plain LINEAR filtering —
// requesting mipmaps on a screen texture has been known to intermittently yield
// black/garbage frames (the effect visibly covers the whole screen, so a bad
// read blanks everything for an instant then recovers = "disappear + reappear").
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 at start, 1 at the end
uniform float max_radius : hint_range(0.0, 1.0) = 0.8;  // how far the wave travels (in aspect-normalized UV)
uniform float strength : hint_range(0.0, 2.0) = 0.28;   // amount of bending
uniform float aspect : hint_range(0.1, 4.0) = 1.7778;   // viewport width / height
uniform float speed : hint_range(1.0, 40.0) = 18.0;     // ripple frequency (waves per unit radius)

void fragment() {
	vec2 d = SCREEN_UV - center_uv;
	d.x *= aspect; // aspect-correct so the drop is round on screen
	float dist = length(d);
	float r = max_radius * progress; // expanding wave-front radius

	// A travelling sine ripple; env keeps the warp localised near the wave front.
	float wave = sin((dist - r) * speed);
	float env = exp(-abs(dist - r) * 55.0);

	vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
	vec2 shift = dir * strength * wave * env;
	shift.x /= aspect; // back to UV space

	vec2 uv2 = clamp(SCREEN_UV + shift, 0.001, 0.999);
	vec4 col = texture(SCREEN_TEXTURE, uv2);
	vec4 orig = texture(SCREEN_TEXTURE, SCREEN_UV);

	float amt = clamp(env * 6.0, 0.0, 1.0);
	vec3 c3 = mix(orig.rgb, col.rgb, amt);

	// Faint cyan glint riding the leading edge of the wave (watery highlight).
	float hl = env * (0.5 + 0.5 * cos((dist - r) * 4.0));
	c3 += vec3(0.35, 0.55, 1.0) * hl * 0.30;

	COLOR = vec4(c3, 1.0);
}
