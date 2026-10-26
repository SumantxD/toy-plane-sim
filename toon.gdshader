shader_type spatial;
// Trimmed from Flexible Toon Shader (MIT, github.com/atzuk4451/FlexibleToonShaderGD-4.0).
// Added: multiplies vertex/instance COLOR so one material serves the MultiMesh towers.
uniform vec4 albedo : source_color = vec4(1.0);
uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.3;
uniform float steepness : hint_range(1.0, 8.0) = 1.5;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.4;
uniform float specular_shininess : hint_range(0.0, 32.0) = 8.0;
uniform float rim_width : hint_range(0.0, 16.0) = 6.0;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
// Baked by terrain.gd (Terrain.light_map): R = sun visibility, G = AO, one texel per 25 m fine-grid vertex over
// +-2500 m. baked_sun = 1 when there is no real-time shadow pass (phones), so the bake shades the sun instead.
global uniform sampler2D baked_light : filter_linear, repeat_disable;
global uniform float baked_sun;
uniform bool baked = false; // props only (Props.toon): they sit on the ground the bake describes; planes fly above it

varying float sun_vis;

vec2 baked_uv(vec3 w) { // world xz -> light map texel centres
	return ((w.xz + 2500.0) / 5000.0) * (200.0 / 201.0) + 0.5 / 201.0;
}
float baked_inside(vec3 w) {
	return step(max(abs(w.x), abs(w.z)), 2500.0);
}

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	sun_vis = 1.0;
	if (baked && baked_sun > 0.0) {
		vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		sun_vis = mix(1.0, texture(baked_light, baked_uv(w)).r, baked_inside(w));
	}
}

void light() {
	// Band only the sun angle (the cartoon look); shadows multiply in smoothly afterwards. Banding
	// ATTENUATION too turned the filtered shadow edge into texel-sized stair steps.
	float d = (dot(NORMAL, LIGHT) + wrap) * steepness;
	float inv = 1.0 / float(cuts);
	float stepped = clamp(d + mod(1.0 - d, inv), 0.0, 1.0);
	float sv = LIGHT_IS_DIRECTIONAL ? sun_vis : 1.0; // the bake shades the sun only, not flashes
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped * ATTENUATION * sv;
	float spec = step(0.5, pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), specular_shininess * specular_shininess));
	SPECULAR_LIGHT += specular_strength * spec * ATTENUATION * sv * LIGHT_COLOR;
	SPECULAR_LIGHT += pow(1.0 - dot(NORMAL, VIEW), rim_width) * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
}
