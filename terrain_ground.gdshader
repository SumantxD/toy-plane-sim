shader_type spatial;
// toon.gdshader's stepped light() for the ground: no specular, faint rim, colour from vertex COLOR.
uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.3;
uniform float steepness : hint_range(1.0, 8.0) = 1.5;
uniform float rim_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)); // vertex colours are authored in sRGB
	ROUGHNESS = 1.0;
}

void light() {
	// Band only the sun angle (the cartoon look); shadows multiply in smoothly afterwards. Banding
	// ATTENUATION too turned the filtered shadow edge into texel-sized stair steps.
	float d = (dot(NORMAL, LIGHT) + wrap) * steepness;
	float inv = 1.0 / float(cuts);
	float stepped = clamp(d + mod(1.0 - d, inv), 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped * ATTENUATION;
	SPECULAR_LIGHT += pow(1.0 - dot(NORMAL, VIEW), rim_width) * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
}
