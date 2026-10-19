extends SceneTree
# godot --path . --script tools/preview_props.gd  -> /tmp/props_*.png, then quits.

# name: [landmark spot, camera offset, look offset]
const SHOTS := {
	"airfield": ["airfield", Vector3(230, 150, -330), Vector3(50, 0, -40)],
	"overview": ["airfield", Vector3(0, 1400, 900), Vector3(0, 0, -2000)],
	"village": ["village", Vector3(-150, 120, -200), Vector3.ZERO],
	"factory": ["factory", Vector3(-260, 150, 260), Vector3.ZERO],
	"forest": ["windmill", Vector3(-500, 160, -500), Vector3(-200, 0, -200)],
	"windmill": ["windmill", Vector3(-70, 40, 110), Vector3(0, 30, 0)],
	"lighthouse": ["lighthouse", Vector3(120, 50, 90), Vector3(0, 25, 0)],
	"bridge": ["bridge", Vector3(180, 40, 120), Vector3.ZERO],
	"red_airfield": ["red_airfield", Vector3(250, 140, 250), Vector3.ZERO],
	"canyon": ["canyon", Vector3(0, 90, 520), Vector3(0, 40, 0)],
	"arches": ["arches", Vector3(160, 70, 420), Vector3(0, 50, 0)],
}


func _init() -> void:
	var t := Time.get_ticks_usec()
	var ground := Terrain.build()
	print("Terrain.build: %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	var props := Props.build()
	print("Props.build: %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	var obs := Props.obstacles()
	print("Props.obstacles: %d AABBs, %.0f ms" % [obs.size(), (Time.get_ticks_usec() - t) / 1000.0])
	var inst := 0
	var tris := 0
	for mmi: MultiMeshInstance3D in props.find_children("*", "MultiMeshInstance3D", true, false):
		var n := mmi.multimesh.instance_count
		inst += n
		tris += n * mmi.multimesh.mesh.get_faces().size() / 3
	print("MultiMeshes: %d, instances: %d, tris: %d" % [props.find_children("*", "MultiMeshInstance3D", true, false).size(), inst, tris])
	print("spots: ", Props.spots)
	root.add_child(ground)
	root.add_child(props)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.88)
	sky_mat.ground_horizon_color = Color(0.68, 0.78, 0.88)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.78, 0.88)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 800.0
	root.add_child(sun)
	var water := MeshInstance3D.new() # stand-in for sky.gd's water
	water.mesh = PlaneMesh.new()
	water.mesh.size = Vector2.ONE * 14000.0
	water.position.y = Terrain.WATER_Y
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.55, 0.85)
	water.material_override = wm
	root.add_child(water)

	var cam := Camera3D.new()
	cam.far = 6000.0
	cam.fov = 70.0
	root.add_child(cam)
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.mesh.size = Vector2(2, 2)
	quad.mesh.flip_faces = true
	quad.extra_cull_margin = 16384.0
	quad.material_override = ShaderMaterial.new()
	quad.material_override.shader = load("res://outline.gdshader")
	cam.add_child(quad)
	cam.make_current()
	_shoot(cam)


func _shoot(cam: Camera3D) -> void:
	var only := OS.get_cmdline_user_args()
	for key in SHOTS:
		if only.size() and not key in only:
			continue
		var s: Array = SHOTS[key]
		var at: Vector3 = Props.spots[s[0]]
		cam.look_at_from_position(at + s[1], at + s[2])
		for f in 8:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/props_%s.png" % key)
		print("saved /tmp/props_%s.png  draw calls %d" % [key, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
