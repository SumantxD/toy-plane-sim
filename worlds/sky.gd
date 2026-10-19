extends RefCounted

# Sky Kingdom: floating islands over a deadly sea of clouds. Fly between and under the islands,
# ride the rising air columns, dodge the downdrafts that pour off the waterfalls.
const OPEN := 3.0 # shape() value for open sky (Terrain skips faces below WATER_Y - 2)
const NAT := "res://assets/nature/"
# [cx, cz, along radius, across radius, axis angle (deg, from +x), top H, underside depth, hills]
const ISL := [
	[0, 1975, 660, 400, 90, 22, 150, 30], # home runway
	[0, -1830, 330, 330, 0, 70, 200, 8], # factory
	[-300, -1500, 420, 240, -45, 70, 170, 6], # red airfield
	[-1350, 850, 290, 290, 0, 360, 280, 18], # sky temple
	[1500, -1050, 270, 200, 30, 250, 230, 45],
	[-1000, 1750, 230, 170, 20, 170, 150, 35],
	[1250, 1550, 210, 160, -30, 300, 210, 40],
	[-1750, -150, 260, 200, 80, 140, 140, 30],
	[-650, 350, 180, 150, 0, 220, 170, 30],
	[1050, -450, 190, 160, 0, 170, 150, 30],
	[550, -1150, 170, 150, 0, 150, 130, 25],
	[1750, 500, 200, 160, 0, 200, 160, 30],
	[-1450, -1250, 180, 150, 0, 190, 150, 30],
	[650, 1150, 150, 110, -45, 84, 30, 4], # thin stepping stones under the bomber route
	[0, 0, 160, 120, 25, 84, 30, 4],
	[-700, -350, 140, 110, 25, 84, 30, 4],
]
# Waterfalls: [island, direction (deg)]. The first is the big one.
const FALLS := [[3, 60.0], [3, 200.0], [4, 120.0], [6, 20.0], [5, 250.0], [9, 300.0], [11, 0.0]]
const KILL_Y := 9.0

static var _wn: FastNoiseLite
static var _hn: FastNoiseLite


static func def() -> Dictionary:
	var drafts := [
		{pos = Vector3(-250, 0, 900), radius = 130.0, strength = 24.0, top = 650.0},
		{pos = Vector3(800, 0, -850), radius = 130.0, strength = 24.0, top = 650.0},
		{pos = Vector3(-1100, 0, -300), radius = 120.0, strength = 22.0, top = 650.0},
		{pos = Vector3(1550, 0, 950), radius = 120.0, strength = 22.0, top = 650.0},
		{pos = Vector3(-600, 0, -1000), radius = 110.0, strength = 20.0, top = 650.0},
		{pos = Vector3(350, 0, 550), radius = 110.0, strength = 22.0, top = 650.0},
	]
	for f in FALLS: # falling water drags the air down with it
		var i: Array = ISL[f[0]]
		var d := Vector2.from_angle(deg_to_rad(f[1]))
		var p := Vector2(i[0], i[1]) + d * (_reach(i, d) + 55.0)
		drafts.append({pos = Vector3(p.x, 0, p.y), radius = 85.0, strength = -12.0, top = float(i[5])})
	return {
		terrain = {seed = 2718, mountain = 0.0, lake = false, river = false, floating = true},
		palette = {bed = Color(0.66, 0.6, 0.82), sand = Color(0.7, 0.64, 0.86), cliff = Color(0.6, 0.52, 0.78), cliff2 = Color(0.5, 0.56, 0.84),
			snow = Color(0.98, 0.95, 1.0), alpine_rock = Color(0.7, 0.66, 0.84), alpine = Color(0.5, 0.8, 0.68),
			forest = Color(0.42, 0.68, 0.64), forest2 = Color(0.48, 0.62, 0.78), lush = Color(0.52, 0.82, 0.62), lush2 = Color(0.44, 0.76, 0.7),
			field = Color(0.78, 0.68, 0.94), wood = Color(0.4, 0.62, 0.66), slope = Color(0.62, 0.62, 0.8), runway = Color(0.42, 0.4, 0.52),
			snow_h = 900.0, alpine_h = 330.0, forest_h = 230.0},
		features = [],
		scatter = {density = 0.75, tree_line = 600.0, pine_line = 420.0, rocks = 0.6,
			broad = [["tree_default.glb", Color(0.98, 0.62, 0.84)], ["tree_fat.glb", Color(0.74, 0.6, 0.96)], ["tree_simple.glb", Color(0.98, 0.74, 0.9)],
				["tree_default.glb", Color(0.56, 0.84, 0.94)], ["tree_fat.glb", Color(0.9, 0.56, 0.86)]],
			pines = [["tree_pineTallA.glb", Color(0.48, 0.44, 0.84)], ["tree_pineTallC.glb", Color(0.42, 0.56, 0.9)], ["tree_cone.glb", Color(0.62, 0.5, 0.9)]],
			accent = ["tree_oak.glb", Color(1.0, 0.84, 0.4)], bark = Color(0.5, 0.4, 0.58), rock_tint = Color(0.86, 0.8, 1.0)},
		sky = {zenith = Color(0.26, 0.52, 1.0), horizon = Color(0.94, 0.82, 0.98), sun_rot = Vector3(-30.0, -140.0, 0.0), sun_color = Color(1.0, 0.92, 0.9),
			sun_energy = 1.15, sun_disc = Color(1.0, 0.94, 0.86), ambient = Color(0.72, 0.74, 1.0), ambient_energy = 0.55,
			fog_begin = 1300.0, fog_end = 6000.0, fog_color = Color(0.86, 0.82, 1.0), saturation = 1.15},
		clouds = {count = 40, base_min = 620.0, base_max = 880.0, top = Color(1, 1, 1), mid = Color(0.93, 0.87, 1.0), bottom = Color(0.8, 0.74, 0.96)},
		water = {visible = false},
		env = {wind = Vector3(2.5, 0, -1.5), gust = 9.0, updrafts = drafts, kill_y = KILL_Y},
		shots = [
			[Vector3(-1050, 470, 1250), Vector3(-1350, 380, 850)], # sky temple
			[Vector3(-1200, 50, 1150), Vector3(-1380, 230, 800)], # under the temple island
			[Vector3(1050, 200, -650), Vector3(1550, 140, -1100)], # east falls + downdraft
			[Vector3(-200, 60, 1250), Vector3(-250, 200, 900)], # updraft from the cloud sea
			[Vector3(-1500, 300, -2100), Vector3(-150, 60, -1600)], # red airfield + factory island
		],
	}


# ---------- islands ----------

static func _noise() -> void:
	if _wn:
		return
	_wn = FastNoiseLite.new()
	_wn.seed = 2718
	_wn.frequency = 0.004
	_wn.fractal_octaves = 3
	_hn = FastNoiseLite.new()
	_hn.seed = 2719
	_hn.frequency = 0.009
	_hn.fractal_octaves = 2


# 1 at an island's centre, 0 at its rim, negative outside.
static func _mask(i: Array, x: float, z: float, warp: float) -> float:
	var a := deg_to_rad(i[4])
	var dx: float = x - i[0]
	var dz: float = z - i[1]
	var u: float = (dx * cos(a) + dz * sin(a)) / i[2]
	var v: float = (-dx * sin(a) + dz * cos(a)) / i[3]
	return 1.0 - sqrt(u * u + v * v) - warp


# Distance from an island centre to its (unwarped) rim along direction d.
static func _reach(i: Array, d: Vector2) -> float:
	var a := deg_to_rad(i[4])
	var u := (d.x * cos(a) + d.y * sin(a)) / float(i[2])
	var v := (-d.x * sin(a) + d.y * cos(a)) / float(i[3])
	return 1.0 / sqrt(u * u + v * v)


# [island index, mask] of the island this point belongs to most.
static func _best(x: float, z: float) -> Array:
	_noise()
	var w := _wn.get_noise_2d(x, z) * 0.16
	var bi := 0
	var bm := -INF
	for k in ISL.size():
		var m := _mask(ISL[k], x, z, w)
		if m > bm:
			bm = m
			bi = k
	return [bi, bm]


static func _top(i: Array, m: float, x: float, z: float) -> float:
	var hill: float = i[7] * (_hn.get_noise_2d(x, z) * 0.5 + 0.5) * smoothstep(0.1, 0.7, m)
	return i[5] - 7.0 * (1.0 - smoothstep(0.0, 0.18, m)) + hill


static func shape(x: float, z: float, _h: float) -> float:
	var b := _best(x, z)
	if b[1] <= 0.0:
		return OPEN
	var top := _top(ISL[b[0]], b[1], x, z)
	if b[0] == 1 or b[0] == 2: # factory and red airfield share one plateau
		var o: Array = ISL[3 - b[0]]
		var m2 := _mask(o, x, z, _wn.get_noise_2d(x, z) * 0.16)
		if m2 > 0.0:
			top = maxf(top, _top(o, m2, x, z))
	return top


static func bottom(x: float, z: float) -> float:
	var b := _best(x, z)
	if b[1] <= 0.0:
		return INF
	var i: Array = ISL[b[0]]
	var rock := 0.8 + 0.4 * (_hn.get_noise_2d(x * 2.7 + 500.0, z * 2.7) * 0.5 + 0.5)
	return Terrain.height(x, z) - 2.0 - float(i[6]) * pow(b[1], 0.9) * rock


# Open-sky vertex snapped onto the nearest island's rim, where its top and underside meet
# (capped like the ground under the bomber route).
static func _rim(x: float, z: float) -> Vector3:
	var b := _best(x, z)
	var i: Array = ISL[b[0]]
	var w := _wn.get_noise_2d(x, z) * 0.16
	var c := Vector2(i[0], i[1])
	var p := c + (Vector2(x, z) - c) * clampf((1.0 - w) / (1.0 - w - b[1]), 0.6, 1.0)
	var r: float = i[5] - 7.0
	return Vector3(p.x, lerpf(minf(r, Terrain.CORRIDOR_CAP), r, smoothstep(180.0, 450.0, Terrain._route_dist(p.x, p.y))), p.y)


static func color(p: Vector3, up: float, k: Color) -> Color:
	if up > 0.8 and p.y > 300.0: # the temple heights: pale lavender meadows
		return k.lerp(Color(0.86, 0.76, 0.98), 0.25)
	return k


# Terrain links every rim cell to the open-sky value, hanging a curtain down to the clouds. Pull those
# vertices up to the rim instead so top and underside close into a floating lip.
# ponytail: post-processes the built mesh; a Terrain.build rim hook would make this unnecessary.
static func _seal(mi: MeshInstance3D) -> void:
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var lip: Color = Worlds.cur.palette.cliff
	var rim := {}
	for k in range(0, pos.size(), 3):
		var was := (pos[k + 2] - pos[k]).cross(pos[k + 1] - pos[k]).y
		var hit := false
		for j in 3:
			var v := pos[k + j]
			if absf(v.y - OPEN) < 0.001:
				var key := Vector2i(int(v.x), int(v.z))
				if not rim.has(key):
					rim[key] = _rim(v.x, v.z)
				pos[k + j] = rim[key]
				hit = true
		if not hit:
			continue
		var fn := (pos[k + 2] - pos[k]).cross(pos[k + 1] - pos[k])
		if fn.y * was < 0.0: # snapping flipped it: restore the facing
			var t := pos[k + 1]
			pos[k + 1] = pos[k + 2]
			pos[k + 2] = t
			fn = -fn
		fn = fn.normalized()
		for j in 3:
			nrm[k + j] = fn
			if fn.y > 0.0:
				col[k + j] = lip
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	var mat := mi.mesh.surface_get_material(0)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	mi.mesh = mesh


# ---------- landmarks ----------

static func _ground_at(i: Array, d: Vector2, inset: float) -> Vector3:
	var c := Vector2(i[0], i[1])
	var r := 0.0
	while Terrain.height(c.x + d.x * r, c.y + d.y * r) > OPEN + 0.5 and r < 900.0:
		r += 4.0
	var p := c + d * (r - inset)
	return Vector3(p.x, Terrain.height(p.x, p.y), p.y)


static func _falls() -> Array:
	var out := []
	for f in FALLS:
		var d := Vector2.from_angle(deg_to_rad(f[1]))
		var p := _ground_at(ISL[f[0]], d, 6.0)
		out.append([p + Vector3(d.x, 0, d.y) * 8.0, d])
	return out


static func layout() -> void:
	_temple()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var stone := {"dirt": Color(0.66, 0.58, 0.84), "_default": Color(0.78, 0.74, 0.92), "grass": Color(0.56, 0.84, 0.66)}
	# floating rock chunks drifting around the high islands
	for c in [[3, 9], [4, 6], [6, 5], [7, 4]]:
		var i: Array = ISL[c[0]]
		for k in c[1]:
			var a := rng.randf() * TAU
			var r: float = maxf(i[2], i[3]) + rng.randf_range(60, 200)
			var p := Vector3(i[0] + cos(a) * r, i[5] + rng.randf_range(-170, 60), i[1] + sin(a) * r)
			var m := Props.model(NAT + ["rock_largeA.glb", "rock_largeD.glb", "rock_largeF.glb"][k % 3], "", stone)
			var s := rng.randf_range(14, 34)
			if Terrain._route_dist(p.x, p.z) < Props.ROUTE_CLEAR + 40.0:
				continue
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI if k % 2 else 0.0) * Basis.from_scale(Vector3.ONE * s), p)
			Props._add(m, t)
			Props._solid(t, m.get_aabb())
	# magic crystal clusters
	for c in [[4, 0.3], [5, 2.0], [6, 4.0], [7, 1.0], [8, 3.0], [9, 5.0], [10, 2.5], [11, 0.8], [12, 3.6], [0, 3.4]]:
		var i: Array = ISL[c[0]]
		var d := Vector2.from_angle(c[1])
		var p := _ground_at(i, d, 55.0)
		for k in 5:
			var off := Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
			var h := rng.randf_range(10, 26) * (1.6 if k == 0 else 1.0)
			var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.35))
			var col: Color = [Color(0.72, 0.5, 1.0), Color(0.5, 0.82, 1.0), Color(0.9, 0.6, 1.0)][k % 3]
			Props._add(Props._prim("cone"), Transform3D(tilt * Basis.from_scale(Vector3(h * 0.35, h, h * 0.35)), p + off + Vector3(0, h * 0.35, 0)), col)
	var falls := _falls()
	Props.spots["waterfall"] = falls[0][0] + Vector3.DOWN * 120.0


static func _temple() -> void:
	var i: Array = ISL[3]
	var c := Vector3(i[0], 0, i[1])
	c.y = Props._ground(c.x, c.z, 60.0) - 3.0
	var marble := Color(0.97, 0.95, 1.0)
	var lilac := Color(0.74, 0.66, 0.96)
	var gold := Color(1.0, 0.8, 0.35)
	var blue := Color(0.5, 0.68, 1.0)
	Props._box(c + Vector3(0, 4, 0), Vector3(120, 14, 120), lilac, 0.0, true)
	Props._box(c + Vector3(0, 12, 0), Vector3(100, 4, 100), marble, 0.0, true)
	Props._box(c + Vector3(0, 6, 66), Vector3(36, 6, 16), marble) # front steps
	var f := c + Vector3(0, 14, 0)
	for k in 16:
		var a := k * TAU / 16.0
		var p := f + Vector3(sin(a), 0, cos(a)) * 38.0
		Props._part("cyl", p + Vector3(0, 13, 0), Vector3(5, 26, 5), marble)
		Props._box(p + Vector3(0, 26.5, 0), Vector3(7, 2, 7), gold)
		Props._box(p + Vector3(0, 0.5, 0), Vector3(7, 1.5, 7), marble)
	Props._part("cyl", f + Vector3(0, 12, 0), Vector3(40, 24, 40), lilac) # inner sanctum
	Props._part("cyl", f + Vector3(0, 29.5, 0), Vector3(88, 5, 88), marble)
	Props._part("cyl", f + Vector3(0, 32.5, 0), Vector3(80, 1.5, 80), gold)
	Props._part("sphere", f + Vector3(0, 33, 0), Vector3(62, 56, 62), blue)
	Props._part("cyl", f + Vector3(0, 61, 0), Vector3(6, 6, 6), gold)
	Props._part("cone", f + Vector3(0, 70, 0), Vector3(7, 14, 7), gold)
	Props._part("sphere", f + Vector3(0, 78, 0), Vector3(5, 5, 5), Color(1.0, 0.95, 0.7))
	Props._solid(Transform3D(Basis.from_scale(Vector3(88, 62, 88)), f + Vector3(0, 31, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var p := c + Vector3(s.x, 0, s.y) * 54.0
		p.y = c.y
		Props._part("taper", p + Vector3(0, 25, 0), Vector3(14, 46, 14), marble)
		Props._box(p + Vector3(0, 40, 0), Vector3(12, 3, 12), lilac)
		Props._part("sphere", p + Vector3(0, 48, 0), Vector3(13, 14, 13), blue)
		Props._part("cone", p + Vector3(0, 59, 0), Vector3(4, 12, 4), gold)
		Props._solid(Transform3D(Basis.from_scale(Vector3(14, 62, 14)), p + Vector3(0, 30, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	Props.spots["temple"] = f


# ---------- effects ----------

static func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://toon.gdshader")
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("specular_strength", 0.1)
	return m


static func _flow(a: Color, b: Color, speed: float, bands: float, edge: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/sky/flow.gdshader")
	m.set_shader_parameter("a", a)
	m.set_shader_parameter("b", b)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("bands", bands)
	m.set_shader_parameter("edge_x", edge)
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, t: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _puffs(amount: int, life: float, size: float, col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.25, col)
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func nodes(root: Node3D) -> void:
	root.tree_entered.connect(func() -> void:
		var t := root.get_parent().get_node_or_null("Terrain")
		if t:
			_seal(t), CONNECT_ONE_SHOT)
	_cloud_sea(root)
	for u in Worlds.cur.env.updrafts:
		_draft(root, u)
	for f in _falls():
		_waterfall(root, f[0], f[1])
	_airship(root, Vector3(250, 430, 450), 650.0, 210.0, Color(0.72, 0.56, 0.98))
	_airship(root, Vector3(-700, 500, -1150), 420.0, -160.0, Color(0.5, 0.76, 1.0))
	_airship(root, Vector3(900, 560, 1250), 500.0, 240.0, Color(0.96, 0.64, 0.86))


static func _cloud_sea(root: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 12000.0
	plane.subdivide_width = 199
	plane.subdivide_depth = 199
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/sky/cloudsea.gdshader")
	var sea := _mesh(root, plane, mat, Transform3D(Basis(), Vector3(0, 4.0, 0)))
	sea.name = "CloudSea"
	sea.extra_cull_margin = 20.0
	# soft humps on top of the sea
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://clouds.gdshader")
	cm.set_shader_parameter("sun_dir", Atmos.sun_dir())
	cm.set_shader_parameter("top", Color(1, 1, 1))
	cm.set_shader_parameter("mid", Color(0.9, 0.86, 1.0))
	cm.set_shader_parameter("bottom", Color(0.8, 0.74, 0.98))
	cm.set_shader_parameter("wind", Vector2(3.0, -1.5))
	cm.render_priority = 1
	sphere.material = cm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = sphere
	mm.instance_count = 600
	var c := Vector3.ZERO
	for k in mm.instance_count:
		if k % 5 == 0: # clusters of five humps
			c = Vector3(rng.randf_range(-4400, 4400), 2.0, rng.randf_range(-4400, 4400))
		var s := rng.randf_range(40, 110)
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 90.0
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(s, s * rng.randf_range(0.45, 0.7), s)), c + off))
		mm.set_instance_custom_data(k, Color(c.x, 2.0, c.z, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "CloudSeaPuffs"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-5000, -10, -5000), Vector3(10000, 60, 10000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


# Rising (or sinking) air column: a faint scrolling sleeve plus streaks moving with the air.
static func _draft(root: Node3D, u: Dictionary) -> void:
	var up: bool = u.strength > 0.0
	var top: float = u.top
	var r: float = u.radius
	var tube := CylinderMesh.new()
	tube.top_radius = r * 0.55
	tube.bottom_radius = r * 0.7
	tube.height = top - 10.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 20
	var tint := Color(0.75, 0.92, 1.0) if up else Color(0.78, 0.6, 1.0)
	var m := _flow(Color(tint, 0.09), Color(tint, 0.0), -1.0 if up else 1.4, 26.0, 0.0)
	m.set_shader_parameter("cols", 28.0)
	m.set_shader_parameter("fade_top", 0.25)
	m.set_shader_parameter("fade_bottom", 0.1)
	_mesh(root, tube, m, Transform3D(Basis(), Vector3(u.pos.x, 10.0 + tube.height / 2.0, u.pos.z)))
	var p := CPUParticles3D.new()
	p.amount = 140
	p.lifetime = 7.0
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 18.0)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = r * 0.6
	p.emission_ring_inner_radius = r * 0.1
	p.emission_ring_height = 20.0
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP if up else Vector3.DOWN
	p.spread = 3.0
	var sp := (top - 30.0) / p.lifetime
	p.initial_velocity_min = sp * 0.85
	p.initial_velocity_max = sp * 1.15
	var g := Gradient.new()
	g.set_color(0, Color(tint, 0.0))
	g.add_point(0.2, Color(tint, 0.7))
	g.add_point(0.8, Color(tint, 0.6))
	g.set_color(g.get_point_count() - 1, Color(tint, 0.0))
	p.color_ramp = g
	p.visibility_aabb = AABB(Vector3(-r, -top, -r), Vector3(r * 2.0, top * 2.0, r * 2.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = p.lifetime
	p.position = Vector3(u.pos.x, 20.0 if up else top - 10.0, u.pos.z)
	root.add_child(p)


static func _waterfall(root: Node3D, at: Vector3, d: Vector2) -> void:
	var h := at.y - 2.0
	var q := QuadMesh.new()
	q.size = Vector2(minf(24.0, 10.0 + h * 0.05), h)
	var m := _flow(Color(1, 1, 1, 0.95), Color(0.66, 0.84, 1.0, 0.85), 2.2, h / 9.0, 0.18)
	m.set_shader_parameter("cols", 11.0)
	var face := Basis(Vector3.UP, atan2(d.x, d.y))
	_mesh(root, q, m, Transform3D(face, Vector3(at.x, 2.0 + h / 2.0, at.z)))
	var lip := _puffs(14, 1.6, 4.0, Color(1, 1, 1, 0.8))
	lip.position = at + Vector3(d.x, 0, d.y) * 2.0
	lip.direction = Vector3(d.x, 0.4, d.y)
	lip.initial_velocity_min = 4.0
	lip.initial_velocity_max = 8.0
	lip.gravity = Vector3(0, -6, 0)
	root.add_child(lip)
	var mist := _puffs(30, 4.0, 9.0, Color(0.95, 0.95, 1.0, 0.75))
	mist.position = Vector3(at.x, 12.0, at.z)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 14.0
	mist.direction = Vector3.UP
	mist.spread = 60.0
	mist.initial_velocity_min = 4.0
	mist.initial_velocity_max = 10.0
	mist.gravity = Vector3(0, 1, 0)
	mist.scale_amount_min = 0.8
	mist.scale_amount_max = 2.0
	root.add_child(mist)


static func _airship(root: Node3D, c: Vector3, r: float, period: float, body: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	root.add_child(pivot)
	var ship := Node3D.new()
	ship.position = Vector3(r, 0, 0)
	ship.rotation.y = 0.0 if period > 0.0 else PI # nose (-z) along the orbit
	pivot.add_child(ship)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	var box := BoxMesh.new()
	var gold := _mat(Color(1.0, 0.8, 0.35))
	_mesh(ship, sphere, _mat(body), Transform3D(Basis.from_scale(Vector3(18, 17, 52)), Vector3.ZERO))
	_mesh(ship, sphere, gold, Transform3D(Basis.from_scale(Vector3(18.6, 2.2, 40)), Vector3(0, 0, 0)))
	_mesh(ship, box, _mat(Color(0.56, 0.4, 0.34)), Transform3D(Basis.from_scale(Vector3(6, 4, 16)), Vector3(0, -11, 0)))
	_mesh(ship, box, _mat(Color(0.95, 0.92, 1.0)), Transform3D(Basis.from_scale(Vector3(6.4, 1.2, 16.6)), Vector3(0, -8.6, 0)))
	for k in 4:
		var b := Basis(Vector3.BACK, k * PI / 2.0)
		_mesh(ship, box, gold, Transform3D(b * Basis.from_scale(Vector3(0.8, 9, 10)), b * Vector3(0, 9, 22)))
	for s in [-1.0, 1.0]:
		_mesh(ship, box, _mat(Color(0.3, 0.28, 0.36)), Transform3D(Basis.from_scale(Vector3(0.6, 7, 1)), Vector3(s * 5, -11, 9)))
	pivot.tree_entered.connect(func() -> void:
		pivot.create_tween().set_loops().tween_property(pivot, "rotation:y", TAU * signf(period), absf(period)).from(0.0)
		var bob := ship.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		bob.tween_property(ship, "position:y", 8.0, 6.0).from(-8.0)
		bob.tween_property(ship, "position:y", -8.0, 6.0), CONNECT_ONE_SHOT)
