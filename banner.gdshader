shader_type spatial;
// Team banner waving in the wind: a sine ripple that grows toward the free end.
render_mode cull_disabled;
uniform vec3 color : source_color = vec3(0.3, 0.55, 1.0);

void vertex() {
	float free_end = UV.x;
	VERTEX.z += sin(TIME * 4.0 + UV.x * 7.0) * 0.45 * free_end;
	VERTEX.y += sin(TIME * 3.1 + UV.x * 5.0) * 0.15 * free_end;
}

void fragment() {
	float stripe = step(0.5, fract(UV.x * 3.0));
	ALBEDO = mix(color, vec3(1.0), stripe * 0.35);
	ROUGHNESS = 1.0;
}
