shader_type spatial;
// Flowing lava: UV.y = metres downhill, UV.x = 0..1 across. HDR hot core so the glow pass blooms it.
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 hot : source_color = vec3(1.0, 0.55, 0.1);
uniform vec3 crust : source_color = vec3(0.22, 0.06, 0.03);
uniform float heat = 2.6;
uniform float speed = 6.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float y = UV.y - TIME * speed;
	float plates = sin(y * 0.09 + sin(UV.x * 7.0 + y * 0.03) * 2.0) + sin(y * 0.21 + UV.x * 4.0) * 0.6;
	float core = step(across, 0.55 + 0.25 * sin(y * 0.05));
	float c = clamp(core * step(0.2, plates + 0.9) + step(1.2, plates) * 0.6, 0.0, 1.0);
	c *= 0.7 + 0.3 * sin(TIME * 2.0 + UV.y * 0.02);
	ALBEDO = mix(crust, hot * heat, c);
}
