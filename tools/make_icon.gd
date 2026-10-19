extends SceneTree
# Renders icon.png (Toy Cub on a sky disc). Run windowed: godot --path . -s tools/make_icon.gd
func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.7, 0.9)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	var disc := MeshInstance3D.new()
	disc.mesh = CylinderMesh.new()
	disc.mesh.top_radius = 6.4
	disc.mesh.bottom_radius = 6.4
	disc.mesh.height = 0.1
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.35, 0.62, 1.0)
	disc.material_override = dm
	disc.rotation_degrees.x = 90
	disc.position.z = -8
	vp.add_child(disc)
	var plane := Node3D.new()
	vp.add_child(plane)
	Planes.build("cub", plane, _toon(Color(1.0, 0.75, 0.2)), _toon(Color(0.95, 0.93, 0.85)), _toon(Color(0.15, 0.2, 0.3)), _toon(Color(0.2, 0.2, 0.22)), _toon(Color.WHITE))
	plane.rotation_degrees = Vector3(22, 145, -18)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 13.0
	cam.position = Vector3(0, 0, 20)
	vp.add_child(cam)
	for i in 10:
		await process_frame
	vp.get_texture().get_image().save_png("res://icon.png")
	print("icon saved")
	quit()

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://toon.gdshader")
	m.set_shader_parameter("albedo", c)
	return m
