extends RefCounted

# Neon Metropolis: a flat dusk city on a 125 m road grid. Low towers (top <= 117 m) along the bomber
# route, 150-350 m skyscraper districts away from it, one 600 m mega-spire, skyways between towers,
# holo billboards, rooftop pads and slow advertising blimps. Electrical storm: rain, wind, lightning.
const PITCH := 125.0 # block pitch; the first 25 m of every block is road (terrain grid = 25 m)
const ROAD := 25.0
const CITY := 1560.0 # towers inside |x|,|z| < CITY
const SPIRE := Vector2(-925, 200)
const NEON := [Color(1.0, 0.15, 0.85), Color(0.1, 0.95, 1.0), Color(0.62, 0.3, 1.0), Color(1.0, 0.4, 0.65), Color(0.25, 1.0, 0.75)]
const BLIMPS := [[Vector3(450, 430, -250), 520.0, 140.0], [Vector3(-250, 470, 950), 380.0, 120.0],
	[Vector3(1000, 450, 1050), 330.0, 110.0], [Vector3(-700, 440, -1050), 430.0, 130.0]]

static var _mesh := {}


static func def() -> Dictionary:
	return {
		terrain = {seed = 2077, base = 16.0, amp = 40.0, mountain = 0.9},
		palette = {bed = Color(0.08, 0.08, 0.16), sand = Color(0.22, 0.2, 0.3), cliff = Color(0.27, 0.21, 0.38), cliff2 = Color(0.34, 0.24, 0.42),
			snow = Color(0.82, 0.78, 1.0), alpine_rock = Color(0.3, 0.25, 0.42), alpine = Color(0.26, 0.22, 0.4), forest = Color(0.2, 0.18, 0.33),
			forest2 = Color(0.18, 0.16, 0.3), lush = Color(0.22, 0.2, 0.32), lush2 = Color(0.2, 0.18, 0.3), field = Color(0.24, 0.21, 0.34),
			wood = Color(0.18, 0.16, 0.28), slope = Color(0.26, 0.22, 0.36), runway = Color(0.2, 0.2, 0.26)},
		features = [],
		scatter = {density = 0.0, broad = [], pines = [], accent = [], rocks = 0.0},
		sky = {zenith = Color(0.07, 0.02, 0.18), horizon = Color(0.66, 0.24, 0.55), sun_rot = Vector3(-14.0, 70.0, 0.0), sun_color = Color(1.0, 0.6, 0.78),
			sun_energy = 0.75, sun_disc = Color(1.0, 0.62, 0.8), ambient = Color(0.6, 0.5, 0.9), ambient_energy = 0.8, fog_begin = 1000.0, fog_end = 5000.0,
			fog_color = Color(0.34, 0.16, 0.44), saturation = 1.2},
		clouds = {count = 45, base_min = 650.0, base_max = 850.0, top = Color(0.62, 0.42, 0.72), mid = Color(0.38, 0.26, 0.52), bottom = Color(0.2, 0.14, 0.32)},
		water = {shallow = Color(0.1, 0.28, 0.45), deep = Color(0.04, 0.06, 0.2), foam = Color(0.5, 0.9, 1.0), glow = Color(0.04, 0.18, 0.32)},
		env = {wind = Vector3(4, 0, -3), gust = 5.0, weather = "rain",
			storm = {period = 110.0, length = 40.0, fog = 0.55, wind_mul = 2.0, warn = "Electrical storm incoming - watch for lightning!"},
			hazards = {lightning = {rate = 9.0, radius = 55.0, damage = 34}}},
		ambience = ["rain"],
		shots = [
			[Vector3(-560, 160, 650), Vector3(-925, 330, 200)], # mega-spire from the lakefront
			[Vector3(1137, 70, -250), Vector3(1137, 110, -1150)], # street corridor, SE skyscraper district
			[Vector3(400, 420, 700), Vector3(-300, 40, -300)], # dusk over the low core and the route
			[Vector3(-1300, 260, -500), Vector3(-700, 120, 200)], # west districts and skyways
		],
	}


static func shape(x: float, z: float, h: float) -> float:
	return lerpf(16.0, h, smoothstep(1600.0, 2150.0, maxf(absf(x), absf(z))))


static func color(p: Vector3, _up: float, k: Color) -> Color:
	if maxf(absf(p.x), absf(p.z)) > CITY + 60.0 or p.y < Terrain.WATER_Y + 3.5:
		return k
	if posmod(floori(p.x / ROAD), 5) == 0 or posmod(floori(p.z / ROAD), 5) == 0:
		return Color(0.08, 0.07, 0.12)
	return Color(0.19, 0.17, 0.27)


static func layout() -> void:
	var rng := Props._rng(400)
	var noise := FastNoiseLite.new()
	noise.seed = 4400
	noise.frequency = 0.0018
	_spire()
	var towers := {} # block -> [centre (ground y), size, tall?]
	var n := int(CITY / PITCH)
	for i in range(-n - 1, n + 1):
		for j in range(-n - 1, n + 1):
			var c := Vector3(i * PITCH + ROAD + 50.0, 0, j * PITCH + ROAD + 50.0)
			if maxf(absf(c.x), absf(c.z)) > CITY or _clear(c.x, c.z) or rng.randf() < 0.1:
				continue
			var tall_zone := rng.randf() < 0.85
			var w := rng.randf_range(42, 82)
			var d := rng.randf_range(42, 82)
			var g := INF
			for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
				g = minf(g, Terrain.height(c.x + k.x * w / 2.0, c.z + k.y * d / 2.0))
			if g < Terrain.WATER_Y + 3.0:
				continue
			c.y = g
			var rd := Terrain._route_dist(c.x, c.z) - maxf(w, d) * 0.7
			var h: float
			var tall := rd > Props.ROUTE_CLEAR and tall_zone and absf(c.x) > 480.0 # centre column = open dogfight arena
			if tall:
				var t := smoothstep(Props.ROUTE_CLEAR, 850.0, rd) * smoothstep(480.0, 800.0, absf(c.x)) * (0.45 + 0.55 * (noise.get_noise_2d(c.x, c.z) * 0.5 + 0.5))
				h = lerpf(120.0, 350.0, t) * rng.randf_range(0.6, 1.0)
				w = minf(w, 72.0)
				d = minf(d, 72.0)
			else:
				h = lerpf(22.0, Props.CLEAR_Y - 3.0 - g, pow(rng.randf(), 0.8))
			_tower(c, w, d, h, NEON[rng.randi() % NEON.size()], rng, tall)
			towers[Vector2i(i, j)] = [c, Vector3(w, h, d), tall]
	_skyways(towers, rng)
	_roads()


# Spawn/airfield approaches and the spire plaza stay open.
static func _clear(x: float, z: float) -> bool:
	return Rect2(-190, 1050, 380, 1400).has_point(Vector2(x, z)) or Vector2(x, z).distance_to(SPIRE) < 150.0 or Props._blocked(x, z)


static func _tower(c: Vector3, w: float, d: float, h: float, neon: Color, rng: RandomNumberGenerator, tall: bool) -> void:
	var low := h
	if h > 140.0 and rng.randf() < 0.55: # setback: narrower upper tier
		low = h * rng.randf_range(0.55, 0.75)
		_block(c + Vector3(0, low, 0), Vector3(w * 0.68, h - low, d * 0.68), neon)
	_block(c + Vector3(0, -2, 0), Vector3(w, low + 2, d), neon)
	var top := c.y + h
	if tall and h > 170.0 and rng.randf() < 0.5:
		Props._add(_m("neon_cyl"), Transform3D(Basis.from_scale(Vector3(1.6, 30, 1.6)), Vector3(c.x, top + 15, c.z)), neon)
	elif h < 200.0 and w > 50.0 and rng.randf() < 0.2: # rooftop landing pad
		Props._add(_m("neon_cyl"), Transform3D(Basis.from_scale(Vector3(w * 0.62, 0.6, w * 0.62)), Vector3(c.x, top + 0.3, c.z)), NEON[1])
		Props._part("cyl", Vector3(c.x, top + 0.5, c.z), Vector3(w * 0.56, 0.6, w * 0.56), Color(0.16, 0.15, 0.22))
		Props._box(Vector3(c.x, top + 0.9, c.z), Vector3(3, 0.3, w * 0.22), Color(0.95, 0.95, 1.0))
	if h > 45.0 and rng.randf() < 0.45: # holo billboard on one face
		var k := rng.randi() % 4
		var yaw := k * PI / 2.0
		var nrm := Vector3(sin(yaw), 0, cos(yaw))
		var face := w if k % 2 == 0 else d
		var bw := face * 0.72
		var bh := minf(bw * 0.55, low * 0.35)
		var at := c + Vector3(0, low * rng.randf_range(0.45, 0.8), 0) + nrm * ((d if k % 2 == 0 else w) / 2.0 + 1.0)
		Props._add(_m("holo"), Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(bw, bh, 1)), at), neon)


# One solid tower box from its base centre.
static func _block(base: Vector3, size: Vector3, neon: Color) -> void:
	var t := Transform3D(Basis.from_scale(size), base + Vector3(0, size.y / 2.0, 0))
	Props._add(_m("tower"), t, neon)
	Props._solid(t, AABB(Vector3.ONE * -0.5, Vector3.ONE))


# Glass skyways across the street between neighbouring skyscrapers.
static func _skyways(towers: Dictionary, rng: RandomNumberGenerator) -> void:
	for key: Vector2i in towers:
		var a: Array = towers[key]
		if not a[2]:
			continue
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var b: Array = towers.get(key + dir, [])
			if b.is_empty() or not b[2] or rng.randf() > 0.3:
				continue
			var ax := 0 if dir.x == 1 else 2
			var pa: Vector3 = a[0]
			var pb: Vector3 = b[0]
			var y := maxf(pa.y, pb.y) + minf(a[1].y, b[1].y) * rng.randf_range(0.25, 0.5)
			var s0: float = pa[ax] + a[1][ax] / 2.0
			var s1: float = pb[ax] - b[1][ax] / 2.0
			var c := (pa + pb) / 2.0
			c[ax] = (s0 + s1) / 2.0
			c.y = y - 4.0
			var size := Vector3(14, 8, 14)
			size[ax] = s1 - s0 + 4.0
			_block(c, size, NEON[rng.randi() % NEON.size()])


# Neon lane line down the middle of every road, one strip per block.
static func _roads() -> void:
	var n := int(CITY / PITCH) + 1
	for i in range(-n, n + 1):
		for j in range(-n, n):
			for ax in 2:
				var line := i * PITCH + ROAD / 2.0
				var mid := j * PITCH + PITCH / 2.0
				var p := Vector3(line, 0, mid) if ax == 0 else Vector3(mid, 0, line)
				var e := Vector3(0, 0, PITCH / 2.0) if ax == 0 else Vector3(PITCH / 2.0, 0, 0)
				if maxf(absf(p.x), absf(p.z)) > CITY + 50.0 or Rect2(-120, 1500, 240, 900).has_point(Vector2(p.x, p.z)) \
						or Vector2(p.x, p.z).distance_to(Props.RED_RUNWAY) < 240.0:
					continue
				var y := Terrain.height(p.x, p.z)
				var y0 := Terrain.height(p.x - e.x, p.z - e.z)
				var y1 := Terrain.height(p.x + e.x, p.z + e.z)
				if minf(y, minf(y0, y1)) < Terrain.WATER_Y + 3.0 or maxf(absf(y - y0), absf(y - y1)) > 1.0:
					continue
				var sz := Vector3(1.2, 0.3, PITCH - 30.0) if ax == 0 else Vector3(PITCH - 30.0, 0.3, 1.2)
				Props._add(_m("neon"), Transform3D(Basis.from_scale(sz), Vector3(p.x, y + 0.4, p.z)), NEON[1] if (i + j) % 2 == 0 else NEON[0])


# The signature mega-spire: stacked setback tiers, neon halo rings and a 600 m needle.
static func _spire() -> void:
	var g := Props._ground(SPIRE.x, SPIRE.y, 60.0)
	var c := Vector3(SPIRE.x, g, SPIRE.y)
	var tiers := [[110.0, 40.0], [78.0, 220.0], [60.0, 360.0], [44.0, 470.0], [26.0, 530.0]]
	var y := g - 2.0
	for k in tiers.size():
		var t: Array = tiers[k]
		_block(Vector3(c.x, y, c.z), Vector3(t[0], g + t[1] - y, t[0]), NEON[0] if k % 2 == 0 else NEON[1])
		y = g + t[1]
	Props._add(_m("neon_cyl"), Transform3D(Basis.from_scale(Vector3(5, 80, 5)), c + Vector3(0, 570, 0)), NEON[0])
	Props._add(_m("neon_sphere"), Transform3D(Basis.from_scale(Vector3.ONE * 9.0), c + Vector3(0, 612, 0)), Color(1.0, 0.95, 1.0))
	for r in [[230.0, 115.0, 1], [400.0, 84.0, 0], [505.0, 58.0, 2]]:
		Props._add(_m("ring"), Transform3D(Basis.from_scale(Vector3.ONE * r[1]), c + Vector3(0, r[0], 0)), NEON[r[2]])
	for k in 4: # giant holo screens on the podium crown
		var yaw := k * PI / 2.0
		Props._add(_m("holo"), Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(60, 34, 1)), c + Vector3(0, 150, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 40.0), NEON[2])
	Props._keep_out.append(Vector3(c.x, c.z, 80))
	Props.spots["spire"] = c


static func nodes(root: Node3D) -> void:
	for k in BLIMPS.size():
		var b: Array = BLIMPS[k]
		var pivot := Node3D.new()
		pivot.name = "Blimp%d" % k
		pivot.position = b[0]
		root.add_child(pivot)
		var ship := _blimp(NEON[k % NEON.size()])
		ship.position = Vector3(b[1], 0, 0)
		pivot.add_child(ship)
		var start := k * 1.7
		pivot.rotation.y = start
		pivot.tree_entered.connect(func() -> void:
			pivot.create_tween().set_loops().tween_property(pivot, "rotation:y", start + TAU, b[2]).from(start))


# Blimp along local z with holo ad screens on both flanks (visual only, flies above every tower).
static func _blimp(neon: Color) -> Node3D:
	var n := Node3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://toon.gdshader")
	mat.set_shader_parameter("albedo", Color(0.72, 0.7, 0.82))
	var parts := [["sphere", Vector3(0, 0, 0), Vector3(17, 17, 66), mat], ["box", Vector3(0, -9.5, 2), Vector3(5, 4, 16), mat],
		["box", Vector3(0, 0, 29), Vector3(1, 15, 10), mat], ["box", Vector3(0, 0, 29), Vector3(15, 1, 10), mat]]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = Props._prim(p[0])
		mi.material_override = p[3]
		mi.transform = Transform3D(Basis.from_scale(p[2]), p[1])
		n.add_child(mi)
	for s in [-1.0, 1.0]:
		var ad := MeshInstance3D.new()
		ad.mesh = _m("holo")
		ad.transform = Transform3D(Basis(Vector3.UP, s * PI / 2.0) * Basis.from_scale(Vector3(38, 8, 1)), Vector3(s * 8.7, 0, 0))
		n.add_child(ad)
	var light := MeshInstance3D.new()
	light.mesh = _m("neon_sphere")
	light.transform = Transform3D(Basis.from_scale(Vector3.ONE * 2.5), Vector3(0, -12, 2))
	n.add_child(light)
	var band := MeshInstance3D.new()
	band.mesh = _m("ring")
	band.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(18, 2, 18)), Vector3(0, 0, -18))
	n.add_child(band)
	for mi: MeshInstance3D in n.get_children():
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


static func _m(kind: String) -> Mesh:
	if _mesh.has(kind):
		return _mesh[kind]
	var m: PrimitiveMesh
	match kind:
		"tower":
			m = BoxMesh.new()
			m.material = ShaderMaterial.new()
			m.material.shader = preload("res://assets/metro/metro_tower.gdshader")
		"holo":
			m = QuadMesh.new()
			m.material = ShaderMaterial.new()
			m.material.shader = preload("res://assets/metro/metro_holo.gdshader")
		_:
			match kind:
				"neon":
					m = BoxMesh.new()
				"neon_cyl":
					m = CylinderMesh.new()
					m.top_radius = 0.5
					m.bottom_radius = 0.5
					m.height = 1.0
					m.radial_segments = 16
					m.rings = 1
				"neon_sphere":
					m = SphereMesh.new()
					m.radius = 0.5
					m.height = 1.0
					m.radial_segments = 10
					m.rings = 5
				"ring":
					m = TorusMesh.new()
					m.inner_radius = 0.45
					m.outer_radius = 0.5
					m.rings = 48
					m.ring_segments = 6
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color(2.6, 2.6, 2.6)
			m.material = mat
	_mesh[kind] = m
	return m

