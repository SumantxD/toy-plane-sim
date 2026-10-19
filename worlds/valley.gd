extends RefCounted

# Green Valley: the starter world. Rolling green countryside, river, lake, windmill, open sky.
# Uses Worlds.DEFAULT; shared landmarks live in props.gd. Adds the Giant's Tooth and a lake waterfall.
const TOOTH := Vector3(1650, 0, -1150) # off the bomber route, visible from anywhere
const FALLS := Vector2(-900, 570) # cliff on the lake's north shore, water pours south into the lake


static func def() -> Dictionary:
	return {shots = [[Vector3(1100, 280, -650), Vector3(1650, 220, -1150)], [Vector3(-760, 140, 950), Vector3(-900, 70, 590)]]}


static func layout() -> void:
	var rng := Props._rng(91)
	# Giant's Tooth: three stacked rock spires.
	var m := Props.model(Props.NAT + "rock_tallG.glb", "", Props.SANDSTONE)
	var s := m.get_aabb().size
	var y := Terrain.height(TOOTH.x, TOOTH.z) - 6.0
	for part in [[95.0, 170.0], [68.0, 140.0], [42.0, 110.0]]:
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(part[0] / s.x, part[1] / s.y, part[0] / s.z)), Vector3(TOOTH.x, y, TOOTH.z))
		Props._add(m, t, Color(0.93, 0.87, 0.8))
		Props._solid(t, AABB(m.get_aabb().position + Vector3(s.x * 0.2, 0, s.z * 0.2), Vector3(s.x * 0.6, s.y * 0.95, s.z * 0.6)))
		y += part[1] * 0.85
	Props.spots["giants_tooth"] = Vector3(TOOTH.x, y, TOOTH.z)
	# Waterfall cliff: a wall of rock spires the falls pour over.
	for i in 11:
		var h := 150.0 - absf(i - 5) * 9.0 + rng.randf_range(-8, 8) # tallest in the middle
		Props._spire(Vector3(FALLS.x + (i - 5) * 21.0, 0, FALLS.y - rng.randf_range(0, 14)), h, rng, 44.0)
	Props.spots["waterfall"] = Vector3(FALLS.x, Terrain.height(FALLS.x, FALLS.y) + 40.0, FALLS.y + 40.0)


static func nodes(root: Node3D) -> void:
	var ground := Terrain.height(FALLS.x, FALLS.y + 40.0)
	var top := Terrain.height(FALLS.x, FALLS.y) + 112.0
	var sheet := MeshInstance3D.new()
	sheet.mesh = QuadMesh.new()
	sheet.mesh.size = Vector2(46.0, top - ground)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://waterfall.gdshader")
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sheet)
	sheet.position = Vector3(FALLS.x, (top + ground) / 2.0, FALLS.y + 30.0)
	var mist := Fx.smoke(3.6, 3.5, Color(0.92, 0.96, 1.0))
	mist.initial_velocity_max = 8.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(22, 2, 6)
	root.add_child(mist)
	mist.position = Vector3(FALLS.x, ground + 4.0, FALLS.y + 42.0)
