class_name Atmos
extends RefCounted

# Sky, sun, clouds, water. Named Atmos because `Sky` is a built-in Godot class.
# Deterministic: clouds are seeded and drift by TIME in the shader only.
const SUN_ROT := Vector3(-38.0, -145.0, 0.0) # degrees: warm afternoon, ~38 deg elevation
const HORIZON := Color(0.70, 0.88, 1.0)
const ZENITH := Color(0.16, 0.42, 0.92)
const CLOUD_SEED := 777


static func sun_dir() -> Vector3:
	return Basis.from_euler(SUN_ROT * PI / 180.0).z # towards the sun


static func build_environment() -> Environment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://sky.gdshader")
	sky_mat.set_shader_parameter("zenith", ZENITH)
	sky_mat.set_shader_parameter("horizon", HORIZON)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.9)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HORIZON
	env.fog_density = 1.0
	env.fog_depth_begin = 1500.0
	env.fog_depth_end = 5800.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	return env


static func build_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROT
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 1200.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_fade_start = 0.8
	return sun


static func build_clouds() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = CLOUD_SEED
	var puffs: Array[Transform3D] = []
	var customs: Array[Color] = []
	for i in 100:
		var big := i < 18
		var c := Vector2(rng.randf_range(-4000, 4000), rng.randf_range(-4000, 4000))
		var base := rng.randf_range(320.0, 560.0) # flat bottoms >= 320 m, clear of the 220 m bomber route
		var r := rng.randf_range(120.0, 180.0) if big else rng.randf_range(50.0, 110.0)
		var yaw := rng.randf() * TAU
		var n := rng.randi_range(10, 16) if big else rng.randi_range(4, 9)
		for k in n:
			var u := rng.randf_range(-1.0, 1.0)
			var off := Vector3(u * r * 1.5, 0.0, rng.randf_range(-0.5, 0.5) * r).rotated(Vector3.UP, yaw)
			var s := r * rng.randf_range(0.6, 1.0) * (1.0 - absf(u) * 0.5)
			var pos := Vector3(c.x + off.x, base + s * rng.randf_range(0.05, 0.45), c.y + off.z)
			puffs.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.85, s)), pos))
			customs.append(Color(c.x, base, c.y, 0.0))
	var sphere := SphereMesh.new()
	sphere.radial_segments = 14
	sphere.rings = 7
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://clouds.gdshader")
	mat.set_shader_parameter("sun_dir", sun_dir())
	mat.render_priority = 1 # after the outline quad, so terrain ink behind clouds is covered
	sphere.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = sphere
	mm.instance_count = puffs.size()
	for i in puffs.size():
		mm.set_instance_transform(i, puffs[i])
		mm.set_instance_custom_data(i, customs[i])
	var node := MultiMeshInstance3D.new()
	node.name = "Clouds"
	node.multimesh = mm
	node.custom_aabb = AABB(Vector3(-5000, 250, -5000), Vector3(10000, 700, 10000)) # shader moves puffs
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func build_water() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 12000.0
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://water.gdshader")
	mat.set_shader_parameter("sun_dir", sun_dir())
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.position.y = Terrain.WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return water
