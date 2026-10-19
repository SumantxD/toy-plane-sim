shader_type spatial;
// Sky Kingdom cloud sea: slow billowing displaced plane, toon-stepped light, receives island shadows.
render_mode cull_back, specular_disabled;
uniform vec3 hi : source_color = vec3(1.0, 0.98, 1.0);
uniform vec3 lo : source_color = vec3(0.86, 0.84, 1.0);
uniform float amp = 7.0;
uniform float scale = 0.0035;

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

// Billowy: puffs are bright round tops (1 - |n|).
float billow(vec2 p) {
	float s = 0.0;
	float a = 0.6;
	for (int i = 0; i < 4; i++) {
		s += a * (1.0 - abs(vnoise(p) * 2.0 - 1.0));
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.45;
	}
	return s;
}

float field(vec2 xz) {
	return billow(xz * scale + vec2(TIME * 0.012, TIME * 0.005));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (field(wp.xz) - 0.6) * amp;
}

void fragment() {
	const float D = 6.0;
	float h = field(wp.xz);
	float hx = field(wp.xz + vec2(D, 0.0));
	float hz = field(wp.xz + vec2(0.0, D));
	vec3 n = normalize(vec3((h - hx) * amp * 4.0, D, (h - hz) * amp * 4.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = mix(lo, hi, smoothstep(0.45, 0.85, h));
	ROUGHNESS = 1.0;
}

void light() {
	float d = (dot(NORMAL, LIGHT) + (ATTENUATION - 1.0) + 0.5) * 1.6;
	float stepped = clamp(d + mod(1.0 - d, 0.34), 0.35, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped;
}
