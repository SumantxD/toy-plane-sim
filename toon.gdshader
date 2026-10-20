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

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	// Band only the sun angle (the cartoon look); shadows multiply in smoothly afterwards. Banding
	// ATTENUATION too turned the filtered shadow edge into texel-sized stair steps.
	float d = (dot(NORMAL, LIGHT) + wrap) * steepness;
	float inv = 1.0 / float(cuts);
	float stepped = clamp(d + mod(1.0 - d, inv), 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped * ATTENUATION;
	float spec = step(0.5, pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), specular_shininess * specular_shininess));
	SPECULAR_LIGHT += specular_strength * spec * ATTENUATION * LIGHT_COLOR;
	SPECULAR_LIGHT += pow(1.0 - dot(NORMAL, VIEW), rim_width) * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
}
