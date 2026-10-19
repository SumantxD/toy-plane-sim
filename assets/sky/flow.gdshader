shader_type spatial;
// Scrolling streak bands: waterfalls (quads) and air-current columns (open cylinders).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 a : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform vec4 b : source_color = vec4(0.62, 0.82, 1.0, 0.85);
uniform float speed = 1.2; // bands per second along UV.y (negative = upward)
uniform float bands = 10.0;
uniform float cols = 7.0;
uniform float edge_x = 0.15; // soft side edges (0 for wrapped cylinders)
uniform float fade_top = 0.0;
uniform float fade_bottom = 0.15;

float hash(float x) {
	return fract(sin(x * 91.3) * 43758.5453);
}

void fragment() {
	float c = floor(UV.x * cols);
	float v = UV.y * bands * (0.8 + 0.4 * hash(c)) - TIME * speed + hash(c + 3.0) * 5.0;
	float k = smoothstep(0.55, 0.68, fract(v));
	vec4 col = mix(b, a, k);
	ALBEDO = col.rgb;
	float e = edge_x > 0.0 ? smoothstep(0.0, edge_x, UV.x) * smoothstep(1.0, 1.0 - edge_x, UV.x) : 1.0;
	float f = (fade_top > 0.0 ? smoothstep(0.0, fade_top, UV.y) : 1.0) * (fade_bottom > 0.0 ? smoothstep(1.0, 1.0 - fade_bottom, UV.y) : 1.0);
	ALPHA = col.a * e * f;
}
