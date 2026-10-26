shader_type spatial;
// Screen-space ink lines from depth + normal discontinuities. Lives on a quad parented to the camera.
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.08, 0.06, 0.12, 1.0);
uniform float depth_threshold = 0.04;
uniform float normal_threshold = 0.6;
uniform float fade_start = 600.0;
uniform float fade_end = 2200.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Perspective: view z/w depend on depth only, so two terms of the inverse projection do (same result, less math).
float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	return -(inv_proj[2][2] * d + inv_proj[3][2]) / (inv_proj[2][3] * d + inv_proj[3][3]);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float c = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float edge = 0.0;
	if (c < fade_end) { // sky and far ground never get ink: skip the neighbour reads
		vec3 nc = texture(normal_tex, SCREEN_UV).xyz * 2.0 - 1.0;
		vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
		for (int i = 0; i < 4; i++) {
			vec2 uv = SCREEN_UV + offs[i];
			float n = lin_depth(uv, INV_PROJECTION_MATRIX);
			// Only the nearer side draws the line, so it hugs the silhouette.
			if (n - c > depth_threshold * c) edge = 1.0;
			vec3 nn = texture(normal_tex, uv).xyz * 2.0 - 1.0;
			if (dot(nc, nn) < normal_threshold) edge = 1.0;
		}
	}
	ALBEDO = ink.rgb;
	ALPHA = edge * (1.0 - smoothstep(fade_start, fade_end, c)) * ink.a;
}
