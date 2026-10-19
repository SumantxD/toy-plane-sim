shader_type spatial;
// Frozen Frontier lake/river ice: static sheet at WATER_Y, blue/white patches, cracks, snow dusting, toon light.
uniform vec3 ice : source_color = vec3(0.72, 0.86, 0.96);
uniform vec3 deep : source_color = vec3(0.52, 0.72, 0.9);
uniform vec3 crack : source_color = vec3(0.95, 0.98, 1.0);
uniform vec3 snow : source_color = vec3(0.96, 0.97, 1.0);

varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

vec2 h2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }

float cells(vec2 p) { // F2 - F1: ~0 on cell borders
	vec2 i = floor(p), f = fract(p);
	float a = 8.0, b = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		float d = length(g + h2(i + g) - f);
		if (d < a) { b = a; a = d; } else if (d < b) { b = d; }
	}
	return b - a;
}

void fragment() {
	vec2 p = wpos.xz;
	float patch = sin(p.x * 0.011 + sin(p.y * 0.007) * 2.0) * sin(p.y * 0.013 + sin(p.x * 0.009) * 1.5);
	vec3 col = mix(ice, deep, smoothstep(-0.2, 0.6, patch));
	col = mix(col, snow, smoothstep(0.55, 0.8, -patch)); // drifted snow
	float c = 1.0 - smoothstep(0.0, 0.05, cells(p / 45.0)) * (1.0 - smoothstep(0.0, 0.035, cells(p / 13.0 + 3.7)) * 0.6);
	col = mix(col, crack, c * 0.75);
	ALBEDO = col;
	ROUGHNESS = 0.3;
}

void light() {
	float d = (dot(NORMAL, LIGHT) + (ATTENUATION - 1.0) + 0.3) * 1.5;
	float stepped = clamp(d + mod(1.0 - d, 1.0 / 3.0), 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped;
	float spec = step(0.5, pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 300.0));
	SPECULAR_LIGHT += 0.35 * spec * LIGHT_COLOR;
}
