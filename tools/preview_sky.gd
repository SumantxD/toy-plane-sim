extends SceneTree
# godot --path . -s tools/preview_sky.gd  -> /tmp/sky_*.png

var cam := Camera3D.new()


func _initialize() -> void:
	var we := WorldEnvironment.new()
	we.environment = Atmos.build_environment()
	root.add_child(we)
	root.add_child(Atmos.build_sun())
	root.add_child(Atmos.build_clouds())
	root.add_child(Atmos.build_water())
	var ts: GDScript = load("res://terrain.gd")
	var has_build := ts.get_script_method_list().any(func(m): return m.name == "build")
	root.add_child(ts.call("build") if has_build else _quick_terrain())
	root.add_child(_test_plane())
	cam.far = 6000.0
	root.add_child(cam)
	var q := MeshInstance3D.new()
	q.mesh = QuadMesh.new()
	q.mesh.size = Vector2(2, 2)
	q.mesh.flip_faces = true
	q.extra_cull_margin = 16384.0
	q.material_override = ShaderMaterial.new()
	q.material_override.shader = load("res://outline.gdshader")
	cam.add_child(q)
	_shots.call_deferred()


func _shots() -> void:
	var lake := Vector3(Terrain.LAKE_CENTER.x, 0, Terrain.LAKE_CENTER.y)
	var sd := Atmos.sun_dir()
	var flat_sd := Vector3(sd.x, 0, sd.z).normalized()
	var views := {
		"lake": [lake + Vector3(330, 30 + Terrain.height(lake.x + 330, lake.z + 330), 330), lake + Vector3(-100, 0, -100)],
		"lake_high": [lake + Vector3(500, 400, 500), lake],
		"plane_sky": [Vector3(0, 100, 1260), Vector3(0, 125, 1200)],
		"plane": [Vector3(0, 130, 1240), Vector3(0, 120, 1200)],
		"to_sun": [Vector3(0, 400, 0), Vector3(0, 400, 0) + flat_sd * 1000 + Vector3(0, 300, 0)],
		"away_sun": [Vector3(0, 350, 0), Vector3(0, 250, 0) - flat_sd * 1000],
		"lobby": [Vector3(0, 500, 2300), Vector3.ZERO],
	}
	for k in views:
		cam.look_at_from_position(views[k][0], views[k][1])
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/sky_%s.png" % k)
	# among clouds: fly toward the nearest big puff cluster
	var mm: MultiMesh = (root.get_node("Clouds") as MultiMeshInstance3D).multimesh
	var p := Vector3.ZERO
	var best := 0.0
	for i in mm.instance_count:
		var t := mm.get_instance_transform(i)
		if Vector2(t.origin.x, t.origin.z).length() < 2500 and t.basis.x.x > best:
			best = t.basis.x.x
			p = t.origin
	cam.look_at_from_position(p + Vector3(400, 30, 400), p)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/sky_clouds.png")
	cam.look_at_from_position(p + Vector3(110, 10, 110), p)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/sky_inside.png")
	quit()


func _test_plane() -> Node3D:
	var n := Node3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://toon.gdshader")
	mat.set_shader_parameter("albedo", Color(0.9, 0.2, 0.15))
	for b in [[Vector3(1.5, 1.5, 9), Vector3.ZERO], [Vector3(11, 0.3, 2), Vector3(0, 0, -0.5)], [Vector3(4, 0.3, 1.2), Vector3(0, 0, 4)]]:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		m.mesh.size = b[0]
		m.position = b[1]
		m.material_override = mat
		n.add_child(m)
	var tracer := MeshInstance3D.new()
	tracer.mesh = BoxMesh.new()
	tracer.mesh.size = Vector3(0.3, 0.3, 30)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(3.0, 2.2, 0.6)
	tracer.material_override = tm
	tracer.position = Vector3(3, 0, -40)
	n.add_child(tracer)
	n.position = Vector3(0, 120, 1200)
	n.rotation_degrees = Vector3(0, 20, 10)
	return n


func _quick_terrain() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, 2400.0, 40.0, 0.0)
	_grid(st, 6400.0, 200.0, 2400.0)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://toon.gdshader")
	m.material_override = mat
	return m


func _grid(st: SurfaceTool, ext: float, step: float, hole: float) -> void:
	var x := -ext
	while x < ext:
		var z := -ext
		while z < ext:
			if maxf(absf(x + step / 2), absf(z + step / 2)) >= hole:
				var c := [Vector3(x, 0, z), Vector3(x + step, 0, z), Vector3(x + step, 0, z + step), Vector3(x, 0, z + step)]
				for i in 4:
					c[i].y = Terrain.height(c[i].x, c[i].z)
				for i in [0, 1, 2, 0, 2, 3]:
					var v: Vector3 = c[i]
					st.set_color(_col(v.y))
					st.add_vertex(v)
			z += step
		x += step


func _col(h: float) -> Color:
	if h < Terrain.WATER_Y + 3: return Color(0.93, 0.85, 0.6)
	if h < 120: return Color(0.42, 0.75, 0.3)
	if h < 260: return Color(0.3, 0.6, 0.28)
	if h < 420: return Color(0.55, 0.5, 0.45)
	return Color(0.97, 0.97, 1.0)
