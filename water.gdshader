shader_type spatial;
// Cartoon water: depth-tinted teal -> deep blue, shoreline foam band, stepped ripples + sun sparkles.
// Transparent, so it never writes the depth/normal buffers the outline pass reads.
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 shallow : source_color = vec3(0.30, 0.90, 0.86);
uniform vec3 deep : source_color = vec3(0.10, 0.50, 0.86);
uniform vec3 foam : source_color = vec3(0.95, 1.0, 1.0);
uniform float deep_at = 14.0;
uniform float foam_width = 2.2;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 glow : source_color = vec3(0.0); // emissive tint (lava worlds)

varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float wave(vec2 p, float t) {
	return sin(p.x * 0.11 + t * 0.9 + sin(p.y * 0.07 + t * 0.6) * 1.8)
		+ sin(p.y * 0.13 - t * 0.7 + sin(p.x * 0.05) * 2.2);
}

void fragment() {
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	vec3 bed = (INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz;
	float depth = max(wpos.y - bed.y, 0.0);
	float w = wave(wpos.xz, TIME);
	vec3 col = mix(shallow, deep, smoothstep(1.0, deep_at, depth));
	col *= 1.0 + 0.07 * step(1.1, w) - 0.05 * step(w, -1.2);
	float fb = foam_width * (1.0 + 0.3 * sin(TIME * 1.5 + wpos.x * 0.2 + wpos.z * 0.15));
	float shore = step(depth, fb);
	col = mix(col, foam, shore);
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n = normalize(vec3(cos(wpos.x * 0.11 + TIME * 0.9) * 0.25, 1.0, cos(wpos.z * 0.13 - TIME * 0.7) * 0.25));
	float glint = pow(max(dot(reflect(-sun_dir, n), vdir), 0.0), 220.0);
	float sparkle = step(0.6, glint) * step(1.5, w);
	ALBEDO = mix(col, foam, sparkle);
	EMISSION = glow * (1.0 + 0.5 * sin(TIME * 1.3 + UV.x * 40.0)) * (1.0 - sparkle);
	ALPHA = mix(0.9, 1.0, max(shore,smoothstep(2.0, deep_at, depth)));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * mix(0.75, 1.0, ATTENUATION);
}
