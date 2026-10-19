extends RefCounted

# Volcanic Islands: palm archipelago in a turquoise sea around an erupting volcano.
# Mechanic: hot air lifts hard over the crater and the lava flows, a ring of sinking air circles the
# island, the crater lobs lava bombs, and every couple of minutes it erupts (thicker ash, faster bombs).
const VENT := Vector2(-1000, 950)
const CONE_R := 700.0
const RIM_Y := 470.0
const CRATER_R := 130.0
const CRATER_DEPTH := 80.0
const FLOWS := [0.35, 1.75, 3.3, 4.75] # lava flow angles (radians, atan2(z, x) around VENT)
const SEA_BED := -6.0
const A := "res://assets/volcano/"
# Islands that must be dry: [centre, radius, plateau height]. Home runway, red airfield, factory, village.
const ISLES := [[Vector2(10, 1975), 430.0, 15.0], [Vector2(-300, -1500), 360.0, 24.0], [Vector2(0, -1800), 330.0, 24.0],
	[Vector2(600, 1300), 230.0, 20.0]]
const STACKS := [Vector2(-1550, 120), Vector2(1450, -250)] # basalt sea-stack clusters (dogfight cover)
const BASALT := Color(0.33, 0.29, 0.3)
const BASALT2 := Color(0.42, 0.33, 0.3)
const SCORCH := Color(0.62, 0.3, 0.16)
const CRUST := Color(0.16, 0.1, 0.09)


static func def() -> Dictionary:
	var crater := Vector3(VENT.x, RIM_Y - 20.0, VENT.y)
	var drafts: Array = [{pos = crater, radius = 300.0, strength = 38.0, top = 1100.0}]
	for i in FLOWS.size():
		var e := _flow_at(i, CONE_R * 0.93) # ~where the flow meets the sea (no Terrain calls in def)
		drafts.append({pos = Vector3(e.x, 0, e.y), radius = 150.0, strength = 20.0, top = 700.0})
	for k in 6: # sinking air ring around the island
		var a := k * TAU / 6.0 + 0.5
		drafts.append({pos = Vector3(VENT.x + cos(a) * 900.0, 0, VENT.y + sin(a) * 900.0), radius = 170.0, strength = -9.0, top = 600.0})
	return {
		terrain = {seed = 9091, base = -150.0, amp = 300.0, power = 1.5, freq = 0.0013, mountain = 0.45, lake = false, river = false},
		palette = {bed = Color(0.86, 0.82, 0.62), sand = Color(0.99, 0.89, 0.62), cliff = Color(0.45, 0.38, 0.34), cliff2 = Color(0.58, 0.38, 0.27),
			alpine_rock = Color(0.4, 0.34, 0.32), alpine = Color(0.5, 0.42, 0.36), forest = Color(0.13, 0.55, 0.33), forest2 = Color(0.1, 0.47, 0.33),
			lush = Color(0.3, 0.76, 0.33), lush2 = Color(0.2, 0.66, 0.36), field = Color(0.6, 0.82, 0.3), wood = Color(0.12, 0.52, 0.34),
			slope = Color(0.42, 0.55, 0.3), snow_h = 9999.0, alpine_h = 330.0, forest_h = 150.0},
		features = ["village"],
		scatter = {density = 1.1, tree_line = 170.0, rocks = 0.8, pines = [], accent = null, bark = Color(0.78, 0.52, 0.34), rock_tint = Color(0.6, 0.52, 0.5),
			broad = [[A + "tree_palm.glb", Color(0.2, 0.75, 0.45)], [A + "tree_palmBend.glb", Color(0.3, 0.8, 0.35)], [A + "tree_palmTall.glb", Color(0.16, 0.7, 0.5)],
				[A + "tree_palmDetailedTall.glb", Color(0.25, 0.78, 0.4)], [A + "tree_palmShort.glb", Color(0.35, 0.82, 0.3)]]},
		sky = {zenith = Color(0.1, 0.44, 0.86), horizon = Color(1.0, 0.8, 0.6), sun_rot = Vector3(-34.0, -125.0, 0.0), sun_color = Color(1.0, 0.9, 0.74),
			sun_energy = 1.15, sun_disc = Color(1.0, 0.86, 0.55), ambient = Color(0.78, 0.68, 0.66), ambient_energy = 0.5,
			fog_begin = 1400.0, fog_end = 5400.0, fog_color = Color(0.98, 0.76, 0.58), saturation = 1.2},
		clouds = {count = 70, top = Color(1, 0.98, 0.94), mid = Color(1.0, 0.88, 0.8), bottom = Color(0.95, 0.68, 0.6)},
		water = {shallow = Color(0.16, 0.93, 0.83), deep = Color(0.03, 0.56, 0.8)},
		env = {wind = Vector3(3.0, 0, -2.0), gust = 2.0, updrafts = drafts, weather = "ash",
			storm = {period = 150.0, length = 30.0, fog = 0.45, warn = "The volcano is erupting! Lava bombs incoming!"},
			hazards = {lava_bombs = {origin = crater, rate = 4.5, burst = 4}}},
		ambience = ["birds"],
		shots = [[Vector3(-250, 380, 250), Vector3(-1000, 330, 950)], [Vector3(-1000, 900, 1150), Vector3(-1000, 400, 950)],
			[Vector3(-1150, 140, 650), Vector3(-1550, 60, 120)], [Vector3(-200, 60, 2200), Vector3(-900, 250, 1100)]],
	}


static func shape(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	h = maxf(h, SEA_BED + sin(x * 0.004) * sin(z * 0.005) * 3.0)
	for isle in ISLES:
		var d: float = p.distance_to(isle[0]) / isle[1] + sin(x * 0.013 + z * 0.007) * 0.06 + sin(z * 0.011 - x * 0.005) * 0.06
		if d < 1.0:
			h = lerpf(h, isle[2], smoothstep(1.0, 0.6, d))
	var v := p - VENT
	var d := v.length()
	if d < CONE_R + 60.0:
		var a := atan2(v.y, v.x)
		var d0 := d
		d += (sin(a * 3.0 + 1.0) * 35.0 + sin(a * 5.0) * 20.0) * smoothstep(CRATER_R + 100.0, CONE_R * 0.7, d) # ragged coast
		var cone := RIM_Y * pow(maxf(CONE_R - maxf(d, CRATER_R), 0.0) / (CONE_R - CRATER_R), 1.7)
		cone *= 1.0 + 0.04 * sin(a * 7.0 + d * 0.01) * smoothstep(CRATER_R, CRATER_R + 80.0, d)
		cone -= _channel(a, d0) * 7.0
		cone += 8.0 * smoothstep(CRATER_R - 25.0, CRATER_R, d) * smoothstep(CRATER_R + 40.0, CRATER_R, d) # rim lip
		cone -= CRATER_DEPTH * smoothstep(CRATER_R, CRATER_R * 0.6, d)
		h = maxf(h, cone)
	return h


static func color(p: Vector3, _up: float, k: Color) -> Color:
	var v := Vector2(p.x - VENT.x, p.z - VENT.y)
	var d := v.length()
	if d > CONE_R or p.y < Terrain.WATER_Y + 3.5:
		return k
	var a := atan2(v.y, v.x)
	var rock := BASALT.lerp(BASALT2, 0.5 + 0.5 * sin(p.y * 0.1))
	rock = rock.lerp(SCORCH, smoothstep(RIM_Y - 90.0, RIM_Y, p.y))
	if d < CRATER_R:
		rock = Color(0.4, 0.14, 0.08)
	var ch := _channel(a, d)
	rock = rock.lerp(CRUST, ch)
	var green := smoothstep(150.0, 80.0, p.y + sin(a * 5.0) * 30.0) * (1.0 - ch)
	return rock.lerp(k, green)


# 0..1: how close (x,z) sits to a lava flow's channel. a, d = polar coords around VENT.
static func _channel(a: float, d: float) -> float:
	if d < CRATER_R:
		return 0.0
	var best := 0.0
	for i in FLOWS.size():
		var lateral := absf(wrapf(a - _flow_angle(i, d), -PI, PI)) * d
		best = maxf(best, smoothstep(40.0, 12.0, lateral))
	return best * smoothstep(CRATER_R, CRATER_R + 30.0, d)


static func _flow_angle(i: int, d: float) -> float:
	return FLOWS[i] + 0.18 * sin(d * 0.008 + i * 1.7)


static func _flow_at(i: int, d: float) -> Vector2:
	var a := _flow_angle(i, d)
	return VENT + Vector2(cos(a), sin(a)) * d


# Where flow i meets the sea (or the cone's foot).
static func flow_end(i: int) -> Vector2:
	var d := CRATER_R + 10.0
	while d < CONE_R + 60.0:
		var q := _flow_at(i, d)
		if Terrain.height(q.x, q.y) < Terrain.WATER_Y:
			break
		d += 10.0
	return _flow_at(i, d)


static func layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90901
	var swap := {"dirt": BASALT2, "_default": BASALT, "grass": Color(0.25, 0.7, 0.35)}
	var tall := ["rock_tallC.glb", "rock_tallG.glb", "rock_tallI.glb", "rock_tallD.glb"]
	for c in STACKS:
		for k in 12:
			var a := k * TAU / 12.0 + rng.randf_range(-0.2, 0.2)
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(60, 280)
			var m := Props.model(Props.NAT + tall[rng.randi() % tall.size()], "", swap)
			var s := m.get_aabb().size
			var w := rng.randf_range(24, 40)
			var hgt := rng.randf_range(60, 130)
			var g := Terrain.height(p.x, p.y) - 6.0
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w / s.x, hgt / s.y, w / s.z)), Vector3(p.x, g, p.y))
			Props._add(m, t, Color.WHITE.lerp(Color(0.8, 0.8, 0.8), rng.randf()))
			Props._solid(t, AABB(m.get_aabb().position + Vector3(s.x * 0.2, 0, s.z * 0.2), Vector3(s.x * 0.6, s.y * 0.95, s.z * 0.6)))
			Props._keep_out.append(Vector3(p.x, p.y, w * 0.6))
	Props._keep_out.append(Vector3(VENT.x, VENT.y, CONE_R * 0.5))
	Props.spots["volcano"] = Vector3(VENT.x, RIM_Y, VENT.y)


static func nodes(root: Node3D) -> void:
	var lava := ShaderMaterial.new()
	lava.shader = preload("res://assets/volcano/volcano_lava.gdshader")
	var crater := Vector3(VENT.x, Terrain.height(VENT.x, VENT.y), VENT.y)
	# lava lake + fire + glow in the crater, ash plume above it
	var pool := MeshInstance3D.new()
	pool.mesh = CylinderMesh.new()
	pool.mesh.top_radius = CRATER_R * 0.68
	pool.mesh.bottom_radius = CRATER_R * 0.5
	pool.mesh.height = 10.0
	pool.material_override = lava
	pool.position = crater + Vector3(0, 3, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)
	for k in 3:
		var f := Fx.fire(9.0)
		f.amount = 30
		f.lifetime = 1.4
		f.position = crater + Vector3(cos(k * 2.1) * 30.0, 6, sin(k * 2.1) * 30.0)
		root.add_child(f)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 6.0
	glow.omni_range = 380.0
	glow.position = crater + Vector3(0, 60, 0)
	root.add_child(glow)
	var plume := Fx.smoke(22.0, 18.0, Color(0.38, 0.34, 0.34))
	plume.amount = 110
	plume.spread = 14.0
	plume.initial_velocity_min = 12.0
	plume.initial_velocity_max = 20.0
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	plume.emission_sphere_radius = 40.0
	plume.gravity = Vector3(3.0, 2.0, -2.0) # leans with the trade wind
	plume.preprocess = 15.0
	plume.position = Vector3(VENT.x, RIM_Y + 10.0, VENT.y)
	root.add_child(plume)
	# lava rivers down the channels, steaming where they hit the sea
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in FLOWS.size():
		var d := CRATER_R - 10.0
		var first := true
		while d < CONE_R + 60.0:
			var c := _flow_at(i, d)
			var a := _flow_angle(i, d)
			var side := Vector2(-sin(a), cos(a)) * lerpf(30.0, 16.0, d / CONE_R) * 0.5
			for s in [-1.0, 1.0]:
				var q: Vector2 = c + side * s
				verts.append(Vector3(q.x, Terrain.height(q.x, q.y) + 3.0, q.y))
				uvs.append(Vector2(s * 0.5 + 0.5, d))
			if not first:
				var n := verts.size()
				idx.append_array([n - 4, n - 3, n - 2, n - 3, n - 1, n - 2])
			first = false
			if Terrain.height(c.x, c.y) < Terrain.WATER_Y - 1.0:
				break
			d += 10.0
		var e := flow_end(i)
		var steam := Fx.smoke(4.0, 7.0, Color(0.96, 0.96, 0.96))
		steam.initial_velocity_min = 8.0
		steam.initial_velocity_max = 14.0
		steam.spread = 20.0
		steam.position = Vector3(e.x, Terrain.WATER_Y + 2.0, e.y)
		root.add_child(steam)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rivers := MeshInstance3D.new()
	rivers.mesh = am
	rivers.material_override = lava
	rivers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rivers)
	# cargo ships circling open water
	for s in SHIPS:
		root.add_child(_ship(s[0], s[1], s[2], s[3]))


const SHIPS := [[Vector2(0, -300), 350.0, 150.0, Color(0.95, 0.5, 0.15)], [Vector2(-650, -1050), 240.0, 110.0, Color(0.15, 0.75, 0.75)],
	[Vector2(700, -700), 380.0, -160.0, Color(0.85, 0.25, 0.2)]]


# Ship on a circle (centre, radius) taking `period` s per lap (negative = clockwise). Visual only.
static func _ship(c: Vector2, r: float, period: float, cargo: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(c.x, Terrain.WATER_Y - 1.0, c.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Props._prim("box")
	var parts := [[Vector3(0, 2, 0), Vector3(14, 6, 64), Color(0.2, 0.22, 0.28)], [Vector3(0, 0.5, 0), Vector3(14.4, 2, 64.4), Color(0.8, 0.2, 0.15)],
		[Vector3(0, 9, 24), Vector3(12, 8, 9), Color(0.95, 0.95, 0.92)], [Vector3(0, 14, 25), Vector3(13, 2, 7), Color(0.2, 0.22, 0.28)]]
	for k in 6:
		var col: Color = cargo if k % 2 == 0 else Color(0.95, 0.92, 0.85)
		parts.append([Vector3(-3.2 + (k % 2) * 6.4, 7.5, -22 + (k / 2) * 13.0), Vector3(6, 5, 12), col.darkened((k % 3) * 0.12)])
	parts.append([Vector3(0, 2, -33), Vector3(9, 6, 6), Color(0.2, 0.22, 0.28)])
	mm.instance_count = parts.size()
	for k in parts.size():
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(parts[k][1]), parts[k][0]))
		mm.set_instance_color(k, (parts[k][2] as Color).srgb_to_linear())
	var hull := MultiMeshInstance3D.new()
	hull.multimesh = mm
	var dir := signf(period)
	hull.position = Vector3(r, 0, 0)
	hull.rotation.y = 0.0 if dir > 0 else PI # bow (-z) points along the motion
	pivot.add_child(hull)
	pivot.tree_entered.connect(func() -> void:
		pivot.create_tween().set_loops().tween_property(pivot, "rotation:y", TAU * dir, absf(period)).from(0.0))
	return pivot
