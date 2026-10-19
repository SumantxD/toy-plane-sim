shader_type spatial;
// Animated holographic billboard: hue-cycling stripes / rings / pixel blocks with scanlines.
render_mode unshaded, cull_disabled;
uniform float glow = 2.2;
varying float seed;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = TIME * 0.5 + seed * 10.0;
	vec3 a = mix(hue(fract(t * 0.08 + seed)), COLOR.rgb, 0.4);
	vec3 b = hue(fract(t * 0.08 + seed + 0.5));
	int kind = int(seed * 3.0);
	float p = kind == 0 ? step(0.5, fract(UV.x * 4.0 - t))
		: kind == 1 ? step(0.5, fract(length((UV - 0.5) * vec2(2.0, 1.0)) * 5.0 - t * 1.5))
		: step(0.5, fract(floor(UV.x * 6.0) * 0.37 + floor(UV.y * 3.0) * 0.61 + floor(t * 2.0) * 0.29));
	float frame = step(min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)), 0.05);
	float scan = 0.8 + 0.2 * sin(UV.y * 90.0 - TIME * 6.0);
	ALBEDO = (mix(a * 0.35, b, p) * scan * (1.0 - frame) + vec3(1.0) * frame) * glow;
}
