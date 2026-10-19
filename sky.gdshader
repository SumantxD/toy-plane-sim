shader_type sky;
// Cartoon sky: zenith -> horizon gradient, flat sun disc with a stepped halo.
uniform vec3 zenith : source_color = vec3(0.16, 0.42, 0.92);
uniform vec3 horizon : source_color = vec3(0.70, 0.88, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.82);
uniform float sun_size = 0.99975;

void sky() {
	float y = max(EYEDIR.y, 0.0);
	vec3 col = mix(horizon, zenith, pow(y, 0.55));
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		col = mix(col, mix(col, sun_color, 0.35), step(0.9984, d));
		col = mix(col, mix(col, sun_color, 0.6), step(0.9993, d));
		col = mix(col, sun_color * 1.6, smoothstep(sun_size - 0.0002, sun_size, d));
	}
	COLOR = col;
}
