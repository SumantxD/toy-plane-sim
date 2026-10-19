shader_type spatial;
// Neon Metropolis tower on a unit box: dark body, procedural lit windows, glowing edge trim.
// Instance COLOR = neon tint. Emission > 1 so the glow post-effect catches it.
uniform vec3 body : source_color = vec3(0.13, 0.11, 0.2);
uniform float glow = 2.6;
varying vec3 lp;
varying vec3 sz;
varying vec3 ln;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lp = VERTEX + 0.5;
	ln = NORMAL;
	sz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	seed = hash(MODEL_MATRIX[3].xz + MODEL_MATRIX[3].y);
}

void fragment() {
	vec3 m = lp * sz;
	vec3 neon = COLOR.rgb;
	vec3 em;
	vec3 tint = mix(body, neon * 0.25, 0.18) * (0.75 + 0.5 * seed);
	if (abs(ln.y) > 0.5) {
		float edge = min(min(m.x, sz.x - m.x), min(m.z, sz.z - m.z));
		em = neon * step(edge, max(1.4, fwidth(m.x) * 1.5));
		ALBEDO = tint * 0.7;
	} else {
		bool xface = abs(ln.x) > 0.5;
		float u = xface ? m.z : m.x;
		float w = xface ? sz.z : sz.x;
		float trim = max(1.2, fwidth(u) * 1.5);
		float edge = min(u, w - u);
		float tm = max(step(edge, trim), step(sz.y - m.y, max(1.8, fwidth(m.y) * 2.0)));
		tm = max(tm, step(0.62, seed) * step(abs(u - w * 0.5), trim * 0.8)); // centre stripe on some towers
		vec2 cell = vec2(u / 4.0, m.y / 5.0);
		vec2 f = fract(cell);
		float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.78);
		float lit = step(0.5 - 0.15 * seed, hash(floor(cell) + seed * 91.0 + (xface ? 17.0 : 0.0)));
		vec2 fw = fwidth(cell);
		float far = smoothstep(0.1, 0.4, max(fw.x, fw.y));
		win = mix(win * lit, 0.07, far) * step(5.0, m.y);
		vec3 wc = mix(vec3(1.0, 0.72, 0.42), mix(neon, vec3(0.7, 0.9, 1.0), 0.4), step(0.55, hash(floor(cell) + 3.7)));
		em = neon * tm + wc * win * 0.45 * (1.0 - tm);
		ALBEDO = tint;
	}
	EMISSION = em * glow;
	ROUGHNESS = 1.0;
}

void light() {
	float d = (dot(NORMAL, LIGHT) + (ATTENUATION - 1.0) + 0.3) * 1.5;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * clamp(d + mod(1.0 - d, 0.3333), 0.0, 1.0);
}
