shader_type spatial;
// Toon cumulus puffs (MultiMesh). Stepped sun lighting, flat cut bottoms, slow wrap-around drift, fade near camera.
// INSTANCE_CUSTOM: xz = cluster centre (puffs of a cluster wrap together), y = cloud base altitude.
// Alpha-blended so the outline pass ignores them (dissolving puffs would otherwise draw ink rings).
render_mode unshaded, blend_mix, cull_back, depth_draw_always, shadows_disabled;
uniform vec3 top : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 mid : source_color = vec3(0.87, 0.92, 1.0);
uniform vec3 bottom : source_color = vec3(0.70, 0.78, 0.94);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec2 wind = vec2(4.0, 1.5);
uniform float extent = 4500.0;
uniform float near_fade = 160.0;

varying vec3 wpos;
varying vec3 wnorm;
varying float edge_fade;

void vertex() {
	vec2 c = INSTANCE_CUSTOM.xz;
	vec2 moved = mod(c + wind * TIME + extent, 2.0 * extent) - extent;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	if (wpos.y < INSTANCE_CUSTOM.y) {
		wpos.y = INSTANCE_CUSTOM.y;
		wnorm = vec3(0.0, -1.0, 0.0);
	}
	wpos.xz += moved - c;
	edge_fade = 1.0 - smoothstep(extent * 0.85, extent, max(abs(moved.x), abs(moved.y)));
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpos, 1.0);
}

void fragment() {
	vec3 n = normalize(wnorm);
	float l = dot(n, sun_dir) * 0.5 + n.y * 0.5;
	ALBEDO = l > 0.05 ? top : (l > -0.45 ? mid : bottom);
	ALPHA = smoothstep(near_fade * 0.25, near_fade, distance(wpos, CAMERA_POSITION_WORLD)) * edge_fade;
}
