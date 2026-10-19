extends SceneTree
# godot --path . --script tools/preview_terrain.gd  -> /tmp/terrain_*.png, then quits.

const SHOTS := {
	"route_low": [Vector3(600, 160, 1300), Vector3(1200, 100, 600)],
	"route_low2": [Vector3(-200, 200, -300), Vector3(-1200, 80, -700)],
	"overview": [Vector3(0, 1700, 2900), Vector3(0, 0, -200)],
	"lake": [Vector3(-500, 180, 500), Vector3(-900, 0, 900)],
	"river": [Vector3(200, 220, -500), Vector3(800, 0, -1200)],
	"runway": [Vector3(80, 70, 1500), Vector3(0, 14, 2000)],
	"edge": [Vector3(1200, 260, -1200), Vector3(2600, 300, -2600)],
}


func _init() -> void:
	var t := Time.get_ticks_usec()
	var ground := Terrain.build()
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("Terrain.build: %.0f ms, %d tris" % [ms, ground.mesh.get_faces().size() / 3])
	t = Time.get_ticks_usec()
	for i in 10000:
		Terrain.height(i * 0.37 - 1800.0, 1800.0 - i * 0.29)
	print("height(): %.2f us/call" % ((Time.get_ticks_usec() - t) / 10000.0))
	root.add_child(ground)
	for i in 200: # contract checks
		var f := i / 199.0
		var seg := mini(int(f * 3.0), 2)
		var p: Vector3 = Terrain.ROUTE[seg].lerp(Terrain.ROUTE[seg + 1], f * 3.0 - seg)
		assert(Terrain.height(p.x, p.z) <= Terrain.CORRIDOR_CAP + 0.01, "route corridor")
	for p in Terrain.RIVER:
		assert(Terrain.height(p.x, p.y) < Terrain.WATER_Y, "river bed %s" % p)
	assert(Terrain.height(Terrain.LAKE_CENTER.x, Terrain.LAKE_CENTER.y) < Terrain.WATER_Y, "lake")
	var rw := Terrain.RUNWAY
	for p in [rw.position, rw.end, rw.get_center(), Vector2(rw.end.x, rw.position.y)]:
		assert(is_equal_approx(Terrain.height(p.x, p.y), Terrain.RUNWAY_Y), "runway")

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.88)
	sky_mat.ground_horizon_color = Color(0.68, 0.78, 0.88)
	sky_mat.ground_bottom_color = Color(0.68, 0.78, 0.88)
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
	cam.fov = 75.0
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
	for key in SHOTS:
		cam.look_at_from_position(SHOTS[key][0], SHOTS[key][1])
		for f in 8:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/terrain_%s.png" % key)
		print("saved /tmp/terrain_%s.png" % key)
	quit()
