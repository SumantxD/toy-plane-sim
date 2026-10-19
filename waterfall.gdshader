shader_type spatial;
// Cartoon falling water: bright streaks scrolling down a sheet. Shared by any world's waterfalls.
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 water : source_color = vec3(0.62, 0.86, 1.0);
uniform vec3 streak : source_color = vec3(1.0, 1.0, 1.0);
uniform float speed = 1.6;

void fragment() {
	// Long soft streaks: each column drifts at its own phase so it reads as flowing water, not tiles.
	float col = sin(UV.x * 61.0) * 0.07 + sin(UV.x * 13.0 + 1.7) * 0.18;
	float s = fract(UV.y * 3.0 - TIME * speed + col);
	float band = smoothstep(0.05, 0.3, s) * (1.0 - smoothstep(0.45, 0.75, s));
	ALBEDO = mix(water, streak, band) * 1.25;
	ALPHA = 0.92 - 0.25 * smoothstep(0.85, 1.0, UV.y);
}
