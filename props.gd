class_name Props
extends RefCounted

# Props, landmarks and level layout (see LEVEL.md). Deterministic: every peer builds the same world
# from Terrain.height + fixed seeds, nothing is synced. Everything ends up in one MultiMesh per mesh.
const SEED := 4242
const CLEAR_Y := 120.0 # nothing solid pokes above this within ROUTE_CLEAR of the bomber route
const ROUTE_CLEAR := 450.0
const CHUNK := 1700.0 # 3x3 cells over the scatter area
const VILLAGE := Vector2(600, 1300)
const FACTORY := Vector2(0, -1800) # ROUTE[-1] ground = escort target
const RED_RUNWAY := Vector2(-300, -1500) # centre; runs along the last route leg
const RED_RUNWAY_DIR := Vector2(0.70710678, -0.70710678)
const RED_RUNWAY_SIZE := Vector2(40, 420)
const WINDMILL_AREA := Rect2(950, 1300, 350, 350) # highest point (under 190 m) in here
const LIGHTHOUSE_DIR := Vector2(0.35, 1.0) # from Terrain.LAKE_CENTER to the north shore
const BRIDGE_NEAR := Vector2(355, -660) # snapped to Terrain.RIVER
const CANYON := Vector2(-1500, 150) # two rows of spires, slot along z
const ARCHES := Vector2(1450, -250) # three fly-through rock arches

const NAT := "res://assets/nature/"
const IND := "res://assets/industrial/"
const SUB := "res://assets/suburban/"
const GRASS := Color(0.42, 0.7, 0.26)
const BARK := Color(0.55, 0.36, 0.24)
const ROCK := {"dirt": Color(0.64, 0.61, 0.58), "_default": Color(0.78, 0.76, 0.72), "grass": GRASS}
const SANDSTONE := {"dirt": Color(0.78, 0.64, 0.52), "_default": Color(0.84, 0.74, 0.64), "grass": GRASS}

static var _cache := {}
static var _toon: ShaderMaterial
static var _prims := {}
static var _batches := {} # Mesh -> [Transform3D, Color, Transform3D, Color, ...]
static var _obs: Array[AABB] = []
static var _keep_out: Array[Vector3] = [] # x, z, radius: no scatter here
static var _sails := Transform3D()
static var spots := {} # landmark name -> world position (filled by build/obstacles)


static func build() -> Node3D:
	_layout()
	_scatter()
	var root := Node3D.new()
	root.name = "Props"
	for mesh: Mesh in _batches:
		var list: Array = _batches[mesh]
		var cells := {"": list}
		if list.size() > 1000: # big scatter batches: split into CHUNK cells so off-screen ones get culled
			cells = {}
			for i in range(0, list.size(), 2):
				var o: Vector3 = list[i].origin
				var key := Vector2i(floori((o.x + 2550.0) / CHUNK), floori((o.z + 2550.0) / CHUNK))
				if not cells.has(key):
					cells[key] = []
				cells[key].append_array([list[i], list[i + 1]])
		for key in cells:
			var part: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = part.size() / 2
			for i in mm.instance_count:
				mm.set_instance_transform(i, part[i * 2])
				mm.set_instance_color(i, part[i * 2 + 1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			root.add_child(mmi)
	var casters := []
	for mesh: Mesh in _batches:
		var list: Array = _batches[mesh]
		for i in range(0, list.size(), 2):
			casters.append_array([list[i], mesh.get_aabb()])
	Terrain.bake_blobs(casters)
	if "windmill" in Worlds.cur.features:
		root.add_child(_windmill_sails())
	if Worlds.has("nodes"):
		Worlds.mod.nodes(root) # animated / effect / audio nodes
	_batches = {}
	return root


static func obstacles() -> Array[AABB]:
	_layout()
	_batches = {}
	return _obs.duplicate()


# ---------- layout ----------

static func _layout() -> void:
	_batches = {}
	_obs = []
	_keep_out = []
	spots = {}
	_home_airfield()
	_red_airfield()
	_factory()
	var feats: Array = Worlds.cur.features
	if "village" in feats:
		_village()
	if "windmill" in feats:
		_windmill()
	if "lighthouse" in feats:
		_lighthouse()
	if "bridge" in feats:
		_bridge()
	if "canyon" in feats:
		_canyon()
		spots["canyon"] = Vector3(CANYON.x, Terrain.height(CANYON.x, CANYON.y), CANYON.y)
	if "arches" in feats:
		_arches()
		spots["arches"] = Vector3(ARCHES.x, Terrain.height(ARCHES.x, ARCHES.y), ARCHES.y)
	if Worlds.has("layout"):
		Worlds.mod.layout() # world-specific landmarks via the helpers below
	for s in Battlefield.base_spots(): # clear trees around gun emplacements
		_keep_out.append(Vector3(s[0].x, s[0].y, 45.0))
	for t in 2: # and around the CTF flags and Assault HQs
		_keep_out.append(Vector3(Objectives.hq_spot(t).x, Objectives.hq_spot(t).y, 55.0))
		_keep_out.append(Vector3(Objectives.flag_spot(t).x, Objectives.flag_spot(t).y, 30.0))


static func _home_airfield() -> void:
	var r := Terrain.RUNWAY
	var y := Terrain.RUNWAY_Y
	var blue := Color(0.3, 0.55, 0.95)
	var ex := r.end.x # east edge; the flattening blend keeps ~40 m beside the runway nearly level
	for i in 3:
		var p := Vector3(ex + 50, 0, r.position.y + 110 + i * 60)
		p.y = _ground(p.x, p.z, 18)
		_hangar(p, PI / 2, Color(0.82, 0.84, 0.8), blue)
	var tp := Vector3(ex + 32, 0, r.position.y + 330)
	tp.y = _ground(tp.x, tp.z, 6)
	_tower(tp, blue)
	_windsock(Vector3(r.position.x - 30, Terrain.height(r.position.x - 30, r.position.y + 60), r.position.y + 60))
	for i in 3:
		var p := Vector3(ex + 48, 0, r.position.y + 390 + i * 24)
		p.y = _ground(p.x, p.z, 7)
		_kit(IND + "detail-tank-large.glb", IND + "Textures/colormap.png", p, 0.0, 9.0)
	for i in 4:
		var p := Vector3(ex + 28 + i * 6, 0, r.position.y + 60)
		p.y = _ground(p.x, p.z, 4)
		_kit(IND + "shipping-container-%s.glb" % ["a", "b", "c", "a"][i], IND + "Textures/colormap.png", p, 0.0, 12.0)
	_keep_out.append(Vector3(ex + 50, r.get_center().y, 260))
	spots["airfield"] = Vector3(r.get_center().x, y, r.get_center().y)


static func _red_airfield() -> void:
	var d := Vector3(RED_RUNWAY_DIR.x, 0, RED_RUNWAY_DIR.y)
	var side := Vector3(-d.z, 0, d.x) # hangar side
	var c := Vector3(RED_RUNWAY.x, 0, RED_RUNWAY.y)
	var yaw := atan2(d.x, d.z)
	var top := -INF
	for k in 9:
		for s in [-1.0, 1.0]:
			var p: Vector3 = c + d * (k / 8.0 - 0.5) * RED_RUNWAY_SIZE.y + side * s * RED_RUNWAY_SIZE.x / 2.0
			top = maxf(top, Terrain.height(p.x, p.z))
	top += 0.3
	c.y = top
	_box(c + Vector3(0, -7, 0), Vector3(RED_RUNWAY_SIZE.x, 14, RED_RUNWAY_SIZE.y), Color(0.33, 0.33, 0.36), yaw)
	var mark := Color(0.95, 0.95, 0.9)
	for k in 9:
		_box(c + d * (k - 4) * 40.0 + Vector3(0, 0.1, 0), Vector3(1.5, 0.3, 18), mark, yaw)
	for e in [-1.0, 1.0]:
		_box(c + d * e * (RED_RUNWAY_SIZE.y / 2.0 - 14.0) + Vector3(0, 0.1, 0), Vector3(30, 0.3, 4), Color(0.85, 0.2, 0.15), yaw)
	var red := Color(0.85, 0.2, 0.15)
	for i in 3:
		var p := c + side * 68.0 + d * (i - 1) * 62.0
		p.y = _ground(p.x, p.z, 15)
		_hangar(p, yaw - PI / 2, Color(0.45, 0.4, 0.38), red)
	var tp := c + side * 55.0 + d * 140.0
	tp.y = _ground(tp.x, tp.z, 8)
	_tower(tp, red)
	_keep_out.append(Vector3(c.x, c.z, 260))
	spots["red_airfield"] = c


static func _factory() -> void:
	var rng := _rng(11)
	var c := Vector3(FACTORY.x, 0, FACTORY.y)
	var pal := IND + "Textures/colormap.png"
	var big := ["building-a", "building-l", "building-r", "building-q", "building-c", "building-b", "building-f", "building-t", "building-m"]
	for i in 3:
		for j in 3:
			var p := c + Vector3((i - 1) * 72.0 + rng.randf_range(-6, 6), 0, (j - 1) * 66.0 + rng.randf_range(-6, 6))
			p.y = _ground(p.x, p.z, 22)
			_kit(IND + big[i * 3 + j] + ".glb", pal, p, PI / 2 * rng.randi_range(0, 3), _fit(p, 1.95, 17.0))
	for p2 in [Vector2(-112, -95), Vector2(112, 95)]:
		var p := c + Vector3(p2.x, 0, p2.y)
		p.y = _ground(p.x, p.z, 10)
		_kit(IND + "chimney-large.glb", pal, p, 0.0, _fit(p, 1.7, 16.0))
	for k in 4:
		var p := c + Vector3(-110 + k * 26, 0, 112)
		p.y = _ground(p.x, p.z, 8)
		_kit(IND + "detail-tank-large.glb", pal, p, PI / 2, 11.0)
	for k in 10:
		var p := c + Vector3(108 + (k % 2) * 8, 0, -100 + k * 9)
		p.y = _ground(p.x, p.z, 4)
		_kit(IND + "shipping-container-%s.glb" % ["a", "b", "c"][k % 3], pal, p, PI / 2, 13.0)
	var wt := c + Vector3(-112, 0, 30)
	wt.y = _ground(wt.x, wt.z, 6)
	_kit(IND + "water-tower.glb", pal, wt, 0.0, _fit(wt, 2.14, 12.0))
	# perimeter wall with corner flak towers and red banners
	const H := 140.0
	var wall := Color(0.5, 0.47, 0.45)
	var red := Color(0.85, 0.18, 0.15)
	for s in 4:
		var yaw := s * PI / 2
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var along := Vector3(dir.z, 0, -dir.x)
		for k in 7:
			var p := c + dir * H + along * (k - 3) * 40.0
			if k == 3 and s == 2:
				continue # gate
			p.y = _ground(p.x, p.z, 20)
			_box(p + Vector3(0, 3, 0), Vector3(41, 14, 4), wall, yaw, true)
		var q := c + dir * H + along * H
		q.y = _ground(q.x, q.z, 8)
		_box(q + Vector3(0, 9, 0), Vector3(12, 22, 12), wall.darkened(0.15), 0.0, true)
		_part("cone", q + Vector3(0, 22.5, 0), Vector3(15, 7, 15), red)
		var b := c + dir * (H + 2.5) + along * 60.0
		b.y = _ground(b.x, b.z, 4)
		_box(b + Vector3(0, 6, 0), Vector3(8, 9, 0.6), red, yaw)
	_keep_out.append(Vector3(c.x, c.z, 200))
	spots["factory"] = Vector3(c.x, Terrain.height(c.x, c.z), c.z)


static func _village() -> void:
	var rng := _rng(21)
	var houses := [["building-type-a", "variation-b"], ["building-type-c", "colormap"], ["building-type-e", "variation-b"],
		["building-type-h", "variation-a"], ["building-type-j", "variation-b"], ["building-type-m", "colormap"],
		["building-type-o", "variation-a"], ["building-type-s", "variation-b"]]
	var c := Vector3(VILLAGE.x, 0, VILLAGE.y)
	var n := 0
	for ring in [[42.0, 6], [82.0, 11], [122.0, 10]]:
		for k in ring[1]:
			var a: float = TAU * k / ring[1] + ring[0] * 0.01 + rng.randf_range(-0.12, 0.12)
			var p: Vector3 = c + Vector3(sin(a), 0, cos(a)) * (ring[0] + rng.randf_range(-8, 8))
			p.y = _ground(p.x, p.z, 9)
			if p.y < Terrain.WATER_Y + 3.0:
				continue
			var h: Array = houses[n % houses.size()]
			n += 1
			_kit(SUB + h[0] + ".glb", SUB + "Textures/" + h[1] + ".png", p, a + PI, 13.0)
	# church: white nave, red roof, steeple (clamped under the route ceiling)
	var g := _ground(c.x, c.z, 14)
	var white := Color(0.95, 0.93, 0.88)
	var roof := Color(0.82, 0.3, 0.22)
	var cy := Vector3(c.x, g, c.z)
	_box(cy + Vector3(0, 5, 0), Vector3(14, 14, 26), white, 0.0, true)
	_part("prism", cy + Vector3(0, 15.5, 0), Vector3(16, 7, 27), roof)
	var st := minf(30.0, CLEAR_Y - 2.0 - g - 12.0)
	_box(cy + Vector3(0, st / 2.0 - 2.0, 15), Vector3(8, st + 4.0, 8), white, 0.0, true)
	_part("cone", cy + Vector3(0, st + 6.0, 15), Vector3(9.5, 12, 9.5), roof)
	_keep_out.append(Vector3(c.x, c.z, 165))
	spots["village"] = cy


static func _windmill() -> void:
	var best := Vector3(0, -INF, 0)
	var x := WINDMILL_AREA.position.x
	while x <= WINDMILL_AREA.end.x:
		var z := WINDMILL_AREA.position.y
		while z <= WINDMILL_AREA.end.y:
			var h := Terrain.height(x, z)
			if h > best.y and h < 190.0:
				best = Vector3(x, h, z)
			z += 25.0
		x += 25.0
	best.y = _ground(best.x, best.z, 10)
	_part("taper", best + Vector3(0, 13, 0), Vector3(18, 30, 18), Color(0.96, 0.9, 0.78))
	_part("cone", best + Vector3(0, 31, 0), Vector3(15, 9, 15), Color(0.62, 0.3, 0.2))
	_box(best + Vector3(0, 3, 8.6), Vector3(4, 6, 1), Color(0.45, 0.28, 0.18))
	_solid(Transform3D(Basis.from_scale(Vector3(18, 36, 18)), best + Vector3(0, 16, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	_sails = Transform3D(Basis(), best + Vector3(0, 28, 10.5)) # faces +z, towards the village/airfield
	_solid(Transform3D(Basis.from_scale(Vector3(46, 46, 3)), _sails.origin), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	_keep_out.append(Vector3(best.x, best.z, 45))
	spots["windmill"] = best


static func _windmill_sails() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "WindmillSails"
	pivot.transform = _sails
	var spin := Node3D.new()
	pivot.add_child(spin)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _prim("box")
	mm.instance_count = 9
	for k in 4:
		var b := Basis(Vector3.BACK, k * PI / 2)
		mm.set_instance_transform(k * 2, Transform3D(b * Basis.from_scale(Vector3(1.2, 22, 1.2)), b * Vector3(0, 11, 0)))
		mm.set_instance_color(k * 2, Color(0.45, 0.28, 0.18).srgb_to_linear())
		mm.set_instance_transform(k * 2 + 1, Transform3D(b * Basis.from_scale(Vector3(5.5, 17, 0.5)), b * Vector3(3, 13, 0)))
		mm.set_instance_color(k * 2 + 1, Color(0.97, 0.95, 0.9).srgb_to_linear())
	mm.set_instance_transform(8, Transform3D(Basis.from_scale(Vector3(3, 3, 3)), Vector3.ZERO))
	mm.set_instance_color(8, Color(0.3, 0.2, 0.15).srgb_to_linear())
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	spin.add_child(mmi)
	spin.tree_entered.connect(func() -> void:
		spin.create_tween().set_loops().tween_property(spin, "rotation:z", -TAU, 14.0).from(0.0))
	return pivot


static func _lighthouse() -> void:
	var dir := LIGHTHOUSE_DIR.normalized()
	var p := Terrain.LAKE_CENTER + dir * 150.0
	while Terrain.height(p.x, p.y) < Terrain.WATER_Y + 2.0:
		p += dir * 4.0
	p += dir * 14.0
	var b := Vector3(p.x, _ground(p.x, p.y, 8), p.y)
	var rng := _rng(31)
	for k in 5:
		var a := k * TAU / 5.0
		_add(model(NAT + "rock_largeD.glb", "", ROCK), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 14.0), b + Vector3(sin(a) * 11, -2, cos(a) * 11)))
	for k in 5:
		var w := 13.0 - k * 1.2
		_part("taper" if k == 0 else "cyl", b + Vector3(0, 4.5 + k * 8.0, 0), Vector3(w, 8.0, w), Color(0.96, 0.95, 0.92) if k % 2 == 0 else Color(0.85, 0.18, 0.16))
	_part("cyl", b + Vector3(0, 40.5, 0), Vector3(12, 1.2, 12), Color(0.18, 0.18, 0.22))
	_part("cyl", b + Vector3(0, 44, 0), Vector3(7, 6, 7), Color(1.0, 0.9, 0.45))
	_part("cone", b + Vector3(0, 50, 0), Vector3(9, 6, 9), Color(0.85, 0.18, 0.16))
	_box(b + Vector3(13, 3, -4), Vector3(9, 7, 11), Color(0.96, 0.95, 0.92))
	_part("prism", b + Vector3(13, 8, -4), Vector3(10, 4, 12), Color(0.85, 0.18, 0.16))
	_solid(Transform3D(Basis.from_scale(Vector3(13, 54, 13)), b + Vector3(0, 26, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	_keep_out.append(Vector3(b.x, b.z, 35))
	spots["lighthouse"] = b


static func _bridge() -> void:
	var pts = Terrain.RIVER
	var best := INF
	var at := BRIDGE_NEAR
	var tan := Vector2.RIGHT
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(BRIDGE_NEAR, pts[i], pts[i + 1])
		if q.distance_to(BRIDGE_NEAR) < best:
			best = q.distance_to(BRIDGE_NEAR)
			at = q
			tan = (pts[i + 1] - pts[i]).normalized()
	var n := Vector2(-tan.y, tan.x)
	# deck height: the lower of the two bank crests; span ends where each bank reaches it
	var crest := [0.0, 0.0]
	for s in 2:
		for k in 60:
			var q: Vector2 = at + n * (1 - s * 2) * k * 5.0
			crest[s] = maxf(crest[s], Terrain.height(q.x, q.y))
	var deck: float = minf(minf(crest[0], crest[1]), 100.0) - 1.0
	var ends := [0.0, 0.0]
	for s in 2:
		var k := 0.0
		while k < 300.0 and Terrain.height(at.x + n.x * (1 - s * 2) * k, at.y + n.y * (1 - s * 2) * k) < deck:
			k += 3.0
		ends[s] = k + 12.0
	var len: float = ends[0] + ends[1]
	var mid: Vector2 = at + n * (ends[0] - ends[1]) / 2.0
	var c := Vector3(mid.x, deck, mid.y)
	var yaw := atan2(n.x, n.y)
	var d := Vector3(n.x, 0, n.y)
	var red := Color(0.82, 0.22, 0.18)
	_box(c, Vector3(14, 3, len), Color(0.35, 0.35, 0.38), yaw, true)
	for s in [-1.0, 1.0]:
		var side: Vector3 = Vector3(d.z, 0, -d.x) * s * 6.5
		_box(c + side + Vector3(0, 7.5, 0), Vector3(1.2, 1.2, len), red, yaw, true)
		var k := -len / 2.0 + 5.0
		while k <= len / 2.0 - 5.0:
			_box(c + side + d * k + Vector3(0, 4, 0), Vector3(0.9, 7, 0.9), red, yaw)
			k += 10.0
	var k := -len / 2.0 + 40.0
	while k < len / 2.0 - 30.0:
		var p := c + d * k
		var g := Terrain.height(p.x, p.z) - 3.0
		if deck - g > 8.0:
			_box(Vector3(p.x, (g + deck) / 2.0 - 1.5, p.z), Vector3(9, deck - g, 6), Color(0.62, 0.6, 0.56), yaw, true)
		k += 45.0
	_keep_out.append(Vector3(c.x, c.z, len / 2.0 + 20.0))
	spots["bridge"] = c


static func _canyon() -> void:
	var rng := _rng(41)
	for row in [-1.0, 1.0]:
		var z := CANYON.y - 320.0
		while z < CANYON.y + 320.0:
			var x: float = CANYON.x + row * rng.randf_range(42, 55)
			_spire(Vector3(x, 0, z), rng.randf_range(70, 140), rng)
			z += rng.randf_range(48, 70)


static func _arches() -> void:
	var rng := _rng(51)
	for i in 3:
		var c := Vector3(ARCHES.x, 0, ARCHES.y + (i - 1) * 220.0)
		var gap := 70.0
		var tops := []
		for s in [-1.0, 1.0]:
			tops.append(_spire(c + Vector3(s * (gap / 2.0 + 14.0), 0, 0), rng.randf_range(80, 100), rng, 28.0))
		var y: float = minf(tops[0], tops[1]) - 8.0
		var m := model(NAT + "rock_largeD.glb", "", SANDSTONE)
		var t := Transform3D(Basis.from_scale(Vector3((gap + 56.0) / 1.07, 28, 30)), c + Vector3(0, y - 6, 0))
		_add(m, t)
		_solid(t, m.get_aabb())
	for k in 8:
		var a := k * TAU / 8.0 + rng.randf() * 0.4
		_spire(Vector3(ARCHES.x, 0, ARCHES.y) + Vector3(sin(a), 0, cos(a)) * rng.randf_range(160, 320), rng.randf_range(50, 110), rng)


# Stretched rock pillar on the ground. Returns its top y.
static func _spire(p: Vector3, tall: float, rng: RandomNumberGenerator, width := 0.0) -> float:
	var w := width if width > 0.0 else rng.randf_range(22, 34)
	p.y = _ground(p.x, p.z, w * 0.4) - 4.0
	if p.y < Terrain.WATER_Y:
		return p.y
	var m := model(NAT + ["rock_tallC.glb", "rock_tallG.glb", "rock_tallI.glb", "rock_tallD.glb"][rng.randi() % 4], "", SANDSTONE)
	var s := m.get_aabb().size
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w / s.x, tall / s.y, w / s.z)), p)
	_add(m, t, Color.WHITE.lerp(Color(0.85, 0.85, 0.85), rng.randf()))
	_solid(t, AABB(m.get_aabb().position + Vector3(s.x * 0.2, 0, s.z * 0.2), Vector3(s.x * 0.6, s.y * 0.95, s.z * 0.6)))
	_keep_out.append(Vector3(p.x, p.z, w * 0.6))
	return p.y + tall


# ---------- scatter (visual only: not obstacles) ----------

static func _scatter() -> void:
	var rng := _rng(1)
	var forest := FastNoiseLite.new()
	forest.seed = SEED
	forest.frequency = 0.0024
	forest.fractal_octaves = 3
	var sc_cfg: Dictionary = Worlds.cur.scatter
	var bark: Color = sc_cfg.bark
	# Entries are [file, leaf colour]; a file with "/" is a full res:// path (world-specific models).
	var tree := func(e: Array) -> Mesh: return model(e[0] if "/" in e[0] else NAT + e[0], "", {"leaf": e[1], "wood": bark})
	var broad: Array[Mesh] = []
	for e in sc_cfg.broad:
		broad.append(tree.call(e))
	var autumn: Mesh = tree.call(sc_cfg.accent) if sc_cfg.accent else null
	var pines: Array[Mesh] = []
	for e in sc_cfg.pines:
		pines.append(tree.call(e))
	var rocks: Array[Mesh] = []
	# scatter.rock_swap: material-name -> colour overrides for the scattered rocks (e.g. no green tops).
	var rock_pal: Dictionary = ROCK.merged(sc_cfg.get("rock_swap", {}), true)
	for f in ["rock_largeA", "rock_largeD", "rock_largeF", "rock_tallB", "rock_tallH"]:
		rocks.append(model(NAT + f + ".glb", "", rock_pal))
	var density: float = sc_cfg.density
	var rock_rate: float = sc_cfg.rocks
	var tree_line: float = sc_cfg.tree_line
	var pine_line: float = sc_cfg.pine_line
	var rock_tint: Color = sc_cfg.rock_tint
	const STEP := 17.0
	const EXT := 2450.0
	var x := -EXT
	while x <= EXT:
		var z := -EXT
		while z <= EXT:
			var r := rng.randf()
			var px := x + rng.randf_range(-7, 7)
			var pz := z + rng.randf_range(-7, 7)
			var yaw := rng.randf() * TAU
			var size := rng.randf()
			z += STEP
			var f := forest.get_noise_2d(px, pz)
			var is_tree := not broad.is_empty() and r < maxf(clampf((f - 0.04) * 5.0, 0.0, 0.85), 0.012) * density
			var is_rock := r > 1.0 - 0.025 * rock_rate
			if not (is_tree or is_rock) or _blocked(px, pz):
				continue
			var h := Terrain.height(px, pz)
			if h < Terrain.WATER_Y + 4.0:
				continue
			var gx := Terrain.height(px + 5.0, pz) - h
			var gz := Terrain.height(px, pz + 5.0) - h
			var steep := sqrt(gx * gx + gz * gz) / 5.0
			if is_tree and steep < 0.75 and h < tree_line:
				var m: Mesh
				if not pines.is_empty() and (h > pine_line + f * 80.0 or size < 0.12):
					m = pines[int(r * 97.0) % pines.size()]
				elif size > 0.95 and autumn:
					m = autumn
				else:
					m = broad[int(r * 89.0) % broad.size()]
				var sc := (13.0 + size * 10.0) / m.get_aabb().size.y
				var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(px, h - 1.0 - steep * 3.0, pz))
				_add(m, t, Color.WHITE * (0.9 + fmod(r * 37.0, 0.2)))
			elif is_rock and (steep > 0.3 or r > 0.997):
				var m: Mesh = rocks[int(r * 1000.0) % rocks.size()]
				var sc := 8.0 + size * size * 22.0
				var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(px, h - sc * 0.15 - steep * 2.0, pz))
				_add(m, t, rock_tint.lerp(rock_tint * 0.85, size))
		x += STEP


static func _blocked(x: float, z: float) -> bool:
	if Terrain.RUNWAY.grow_individual(70, 150, 70, 150).has_point(Vector2(x, z)):
		return true
	for k in _keep_out:
		if Vector2(x - k.x, z - k.y).length_squared() < k.z * k.z:
			return true
	return false


# ---------- building blocks ----------

static func _hangar(p: Vector3, yaw: float, body: Color, trim: Color) -> void:
	# Quonset hut: a cylinder lying along local z, half buried. Door faces local -z.
	var b := Basis(Vector3.UP, yaw)
	_add(_prim("cyl"), Transform3D(b * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(30, 40, 30)), p), body)
	_box(p + b * Vector3(0, 6, -20.3), Vector3(20, 12, 1), Color(0.25, 0.27, 0.3), yaw)
	_box(p + b * Vector3(0, 13, -20.4), Vector3(22, 2, 1.2), trim, yaw)
	_solid(Transform3D(b * Basis.from_scale(Vector3(30, 15, 40)), p + Vector3(0, 7.5, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))


static func _tower(p: Vector3, trim: Color) -> void:
	_box(p + Vector3(0, 8, 0), Vector3(9, 16, 9), Color(0.93, 0.9, 0.82), 0.0, true)
	_box(p + Vector3(0, 18.5, 0), Vector3(12, 5, 12), Color(0.35, 0.55, 0.8), 0.0, true)
	_box(p + Vector3(0, 21.6, 0), Vector3(13.5, 1.2, 13.5), trim)
	_part("cyl", p + Vector3(0, 25, 0), Vector3(0.6, 6, 0.6), Color(0.9, 0.9, 0.9))
	_part("sphere", p + Vector3(0, 28.3, 0), Vector3(1.6, 1.6, 1.6), Color(1, 0.3, 0.2))


static func _windsock(p: Vector3) -> void:
	_part("cyl", p + Vector3(0, 7, 0), Vector3(0.6, 14, 0.6), Color(0.95, 0.95, 0.95))
	for k in 3:
		var t := Transform3D(Basis(Vector3.BACK, PI / 2) * Basis.from_scale(Vector3(2.6 - k * 0.5, 2.6, 2.6 - k * 0.5)), p + Vector3(1.3 + k * 2.6, 13.2, 0))
		_add(_prim("taper"), t, Color(1, 0.5, 0.1) if k % 2 == 0 else Color(0.97, 0.97, 0.97))


# Box centred at c. solid=true also registers it as an obstacle.
static func _box(c: Vector3, size: Vector3, col: Color, yaw := 0.0, solid := false) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), c)
	_add(_prim("box"), t, col)
	if solid:
		_solid(t, AABB(Vector3.ONE * -0.5, Vector3.ONE))


static func _part(kind: String, c: Vector3, size: Vector3, col: Color) -> void:
	_add(_prim(kind), Transform3D(Basis.from_scale(size), c), col)


static func _kit(path: String, palette: String, p: Vector3, yaw: float, scale: float, solid := true) -> void:
	var m := model(path, palette)
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), p)
	_add(m, t)
	if solid:
		_solid(t, m.get_aabb())


static func _add(mesh: Mesh, t: Transform3D, col := Color.WHITE) -> void:
	if not _batches.has(mesh):
		_batches[mesh] = []
	_batches[mesh].append(t)
	_batches[mesh].append(col.srgb_to_linear())


# Registers world AABBs for a (possibly rotated) local box. Rotated boxes are cut into slices along
# their long axis so a diagonal bridge deck doesn't become one huge box swallowing the gap below.
static func _solid(t: Transform3D, local: AABB) -> void:
	var s := local.size
	var axis := 0 if s.x * t.basis.x.length() >= s.z * t.basis.z.length() else 2
	var long := s[axis] * t.basis[axis].length()
	var thick := s[2 - axis] * t.basis[2 - axis].length()
	var rotated := absf(t.basis.x.normalized().dot(Vector3.RIGHT)) < 0.999 and absf(t.basis.x.normalized().dot(Vector3.BACK)) < 0.999
	var n := maxi(1, ceili(long / maxf(thick, 4.0))) if rotated else 1
	for i in n:
		var piece := local
		piece.position[axis] += s[axis] * i / n
		piece.size[axis] = s[axis] / n
		var box := t * piece
		if box.end.y > CLEAR_Y and Terrain._route_dist(box.get_center().x, box.get_center().z) < ROUTE_CLEAR:
			push_warning("Props: solid at %s pokes above route ceiling (%.0f m)" % [box.get_center(), box.end.y])
		_obs.append(box.grow(1.0))


# Scale for a kit model of unit height `unit_h` so its top stays under CLEAR_Y near the route.
static func _fit(p: Vector3, unit_h: float, want: float) -> float:
	if Terrain._route_dist(p.x, p.z) >= ROUTE_CLEAR:
		return want
	return minf(want, (CLEAR_Y - 3.0 - p.y) / unit_h)


# Lowest ground under a footprint, so things sink into slopes instead of floating.
static func _ground(x: float, z: float, r: float) -> float:
	var h := Terrain.height(x, z)
	for d in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		h = minf(h, Terrain.height(x + d.x, z + d.y))
	return h


static func _max_h(r: Rect2) -> float:
	var h := -INF
	for i in 5:
		for j in 9:
			h = maxf(h, Terrain.height(r.position.x + r.size.x * i / 4.0, r.position.y + r.size.y * j / 8.0))
	return h


static func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 1000 + salt
	return rng


static func _prim(kind: String) -> Mesh:
	if not _prims.has(kind):
		var m: PrimitiveMesh
		match kind:
			"box":
				m = BoxMesh.new()
			"prism":
				m = PrismMesh.new()
			"sphere":
				m = SphereMesh.new()
				m.radius = 0.5
				m.height = 1.0
				m.radial_segments = 12
				m.rings = 6
			_:
				m = CylinderMesh.new()
				m.top_radius = {"cyl": 0.5, "taper": 0.36, "cone": 0.0}[kind]
				m.bottom_radius = 0.5
				m.height = 1.0
				m.radial_segments = 14
				m.rings = 1
		m.material = toon()
		_prims[kind] = m
	return _prims[kind]


# ---------- Kenney models ----------

# GLB -> one merged single-surface ArrayMesh with colours baked into vertices (flat albedo, or the
# palette texture sampled at each UV), drawn with one white toon material. `swap` recolours flat
# materials whose name contains a key, e.g. {"leaf": Color.GREEN}.
static func model(path: String, palette := "", swap := {}) -> ArrayMesh:
	var key := path + palette + str(swap)
	if _cache.has(key):
		return _cache[key]
	var root: Node3D = load(path).instantiate()
	var pal: Image = null
	if palette != "":
		pal = load(palette).get_image()
		if pal.is_compressed():
			pal.decompress()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != root:
			xf = n.transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var flat := mat.albedo_color if mat else Color.WHITE
			for k in swap:
				if mat and k in mat.resource_name:
					flat = swap[k]
			var img := pal
			if not img and mat and mat.albedo_texture:
				img = mat.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv = a[Mesh.ARRAY_TEX_UV]
			var base := pos.size()
			for i in v.size():
				pos.append(xf * v[i])
				nrm.append((xf.basis * nn[i]).normalized())
				var c := flat
				if img and uv:
					var p: Vector2 = uv[i].posmod(1.0) * Vector2(img.get_size())
					c = flat * img.get_pixel(mini(int(p.x), img.get_width() - 1), mini(int(p.y), img.get_height() - 1))
				col.append(c.srgb_to_linear())
			var ix = a[Mesh.ARRAY_INDEX]
			if ix:
				for i in ix:
					idx.append(base + i)
			else:
				for i in v.size():
					idx.append(base + i)
	root.free()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new() # auto LODs: far scatter chunks draw simplified trees/rocks
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, toon())
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	_cache[key] = mesh
	return mesh


static func toon() -> ShaderMaterial:
	if not _toon:
		_toon = ShaderMaterial.new()
		_toon.shader = preload("res://toon.gdshader")
		_toon.set_shader_parameter("specular_strength", 0.12) # big flat faces otherwise flash white
		_toon.set_shader_parameter("baked", true)
	return _toon
