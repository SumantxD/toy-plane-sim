class_name Terrain
extends RefCounted

# Shared world contract. Every peer builds the same world from these, nothing is synced.
# height(x, z) is the ONE source of truth for ground: mesh, crashes, prop placement, AI.
static var SEED := 1337 # per world (Worlds.configure)
const WATER_Y := 6.0
const ROUTE := [Vector3(0, 220, 1800), Vector3(1200, 220, 600), Vector3(-1200, 220, -600), Vector3(0, 220, -1800)]
const CORRIDOR_CAP := 90.0 # ground under the bomber route never exceeds this
const LAKE_CENTER := Vector2(-900, 900)
const LAKE_RADIUS := 300.0
const RUNWAY := Rect2(-25, 1650, 50, 650) # x, z, width, length (along +z)
const RUNWAY_Y := 14.0
# River centreline: lake -> (800,-1200) -> gorge through the mountain ring. Bed below WATER_Y.
static var RIVER := PackedVector2Array([
	Vector2(-850, 850), Vector2(-640, 640), Vector2(-500, 560), Vector2(-330, 470), Vector2(-200, 330),
	Vector2(-170, 140), Vector2(-230, -40), Vector2(-180, -220), Vector2(-20, -340), Vector2(180, -420),
	Vector2(330, -560), Vector2(380, -760), Vector2(500, -930), Vector2(660, -1040), Vector2(800, -1200),
	Vector2(900, -1400), Vector2(1100, -1530), Vector2(1350, -1580), Vector2(1600, -1720),
	Vector2(1800, -1950), Vector2(2100, -2150), Vector2(2500, -2300), Vector2(3000, -2600),
	Vector2(3700, -2900), Vector2(4500, -3400), Vector2(6500, -4200)])
const RIVER_HALF_WIDTH := 24.0
const RIVER_BED_Y := WATER_Y - 5.0
const RIVER_REACH := 450.0
const CELL := 500.0
static var _river_cells := {}

static var _noise: FastNoiseLite
static var _ridge: FastNoiseLite
static var _tint: FastNoiseLite
# Current world's terrain knobs, copied out of Worlds.cur for speed (height() is hot).
static var _base := 18.0
static var _amp := 220.0
static var _pow := 1.6
static var _freq := 0.0011
static var _mount := 1.0
static var _lake := true
static var _river := true
static var _floating := false
static var _pal: Dictionary = {}
static var _shape := Callable()
static var _recolor := Callable()
static var _bottom := Callable()


static func configure() -> void:
	var c: Dictionary = Worlds.cur.terrain
	SEED = c.seed
	_base = c.base
	_amp = c.amp
	_pow = c.power
	_freq = c.freq
	_mount = c.mountain
	_lake = c.lake
	_river = c.river
	_floating = c.floating
	_pal = Worlds.cur.palette
	_shape = Callable(Worlds.mod, "shape") if Worlds.has("shape") else Callable()
	_recolor = Callable(Worlds.mod, "color") if Worlds.has("color") else Callable()
	_bottom = Callable(Worlds.mod, "bottom") if Worlds.has("bottom") else Callable()
	_noise = null
	_river_cells = {}


static func _n() -> FastNoiseLite:
	if not _noise:
		_noise = FastNoiseLite.new()
		_noise.seed = SEED
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = _freq
		_noise.fractal_octaves = 4
		_ridge = FastNoiseLite.new()
		_ridge.seed = SEED + 1
		_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ridge.frequency = 0.0007
		_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_ridge.fractal_octaves = 4
		_tint = FastNoiseLite.new()
		_tint.seed = SEED + 2
		_tint.frequency = 0.004
		_tint.fractal_octaves = 2
	return _noise


static func height(x: float, z: float) -> float:
	if _pal.is_empty():
		Worlds.select(Worlds.index)
	var n := _n().get_noise_2d(x, z) * 0.5 + 0.5
	var h := _base + pow(n, _pow) * _amp
	var rwd := _rect_dist(RUNWAY, Vector2(x, z))
	var edge := maxf(absf(x), absf(z)) + _noise.get_noise_2d(z + 7000.0, x - 3000.0) * 250.0
	var m := smoothstep(1500.0, 2700.0, edge) * smoothstep(250.0, 900.0, rwd) # runway keeps an open valley
	if m > 0.0 and _mount > 0.0: # ring of mountains = soft world edge
		h += m * _mount * (180.0 + (_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 560.0)
	if _shape.is_valid():
		h = _shape.call(x, z, h)
	h = lerpf(minf(h, CORRIDOR_CAP), h, smoothstep(180.0, 450.0, _route_dist(x, z)))
	var ld := Vector2(x, z).distance_to(LAKE_CENTER) + _noise.get_noise_2d(x * 3.0, z * 3.0) * 70.0
	if _lake and ld < LAKE_RADIUS * 2.4: # shallow basin, then the lake bowl
		h = minf(h, lerpf(WATER_Y + 5.0, h, smoothstep(LAKE_RADIUS, LAKE_RADIUS * 2.4, ld)))
		h = lerpf(-12.0, h, smoothstep(LAKE_RADIUS * 0.6, LAKE_RADIUS * 1.05, ld))
	var rd := _river_dist(x, z) if _river else INF
	if rd < RIVER_REACH: # valley floor just above water, then the channel
		var valley := minf(60.0 + maxf(h - WATER_Y, 0.0) * 2.0, RIVER_REACH - RIVER_HALF_WIDTH)
		h = minf(h, lerpf(WATER_Y + 5.0, h, smoothstep(RIVER_HALF_WIDTH, RIVER_HALF_WIDTH + valley, rd)))
		h = minf(h, lerpf(RIVER_BED_Y, h, smoothstep(RIVER_HALF_WIDTH * 0.5, RIVER_HALF_WIDTH + 12.0, rd)))
	h = lerpf(RUNWAY_Y, h, smoothstep(10.0, 220.0, rwd))
	return h


# Underside of floating ground at (x, z); -INF when the ground is solid all the way down.
static func bottom(x: float, z: float) -> float:
	return _bottom.call(x, z) if _bottom.is_valid() else -INF


# True when p is inside ground (or below a floating world's kill floor).
static func solid(p: Vector3) -> bool:
	var top := height(p.x, p.z)
	return p.y < top + 1.0 and p.y > bottom(p.x, p.z)


# Height of the first surface below p (for floating worlds, flying under an island is fine).
static func floor_below(p: Vector3) -> float:
	var top := height(p.x, p.z)
	if not _floating:
		return top
	var kill: float = Worlds.cur.env.kill_y
	return maxf(top, kill) if p.y >= top else maxf(kill, -50.0)


static func normal(x: float, z: float) -> Vector3:
	const E := 2.0
	return Vector3(height(x - E, z) - height(x + E, z), 2.0 * E, height(x, z - E) - height(x, z + E)).normalized()


static func _route_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in ROUTE.size() - 1:
		var a := Vector2(ROUTE[i].x, ROUTE[i].z)
		var b := Vector2(ROUTE[i + 1].x, ROUTE[i + 1].z)
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


static func _river_dist(x: float, z: float) -> float:
	if _river_cells.is_empty():
		for i in RIVER.size() - 1: # bucket segments into cells so a lookup only tests nearby ones
			var r := Rect2(RIVER[i], Vector2.ZERO).expand(RIVER[i + 1]).grow(RIVER_REACH)
			for cx in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
				for cz in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
					var k := Vector2i(cx, cz)
					if not _river_cells.has(k):
						_river_cells[k] = PackedInt32Array()
					_river_cells[k].append(i)
	var segs: PackedInt32Array = _river_cells.get(Vector2i(floori(x / CELL), floori(z / CELL)), PackedInt32Array())
	var best := INF
	for i in segs:
		var a := RIVER[i]
		var ab := RIVER[i + 1] - a
		var ax := x - a.x
		var az := z - a.y
		var t := clampf((ax * ab.x + az * ab.y) / ab.length_squared(), 0.0, 1.0)
		var dx := ax - ab.x * t
		var dz := az - ab.y * t
		best = minf(best, dx * dx + dz * dz)
	return sqrt(best)


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var d := (p - r.get_center()).abs() - r.size / 2.0
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


# ---------- visible ground ----------
const FINE := 25.0
const FINE_EXTENT := 2500.0
const COARSE := 100.0
const COARSE_EXTENT := 6000.0


static func build() -> Node3D:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var n := int(FINE_EXTENT * 2.0 / FINE) + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for i in n:
		for j in n:
			hs[i * n + j] = height(-FINE_EXTENT + j * FINE, -FINE_EXTENT + i * FINE)
	for i in n - 1:
		var z0 := -FINE_EXTENT + i * FINE
		for j in n - 1:
			var x0 := -FINE_EXTENT + j * FINE
			var a := Vector3(x0, hs[i * n + j], z0)
			var b := Vector3(x0 + FINE, hs[i * n + j + 1], z0)
			var c := Vector3(x0, hs[(i + 1) * n + j], z0 + FINE)
			var d := Vector3(x0 + FINE, hs[(i + 1) * n + j + 1], z0 + FINE)
			if _floating and maxf(maxf(a.y, b.y), maxf(c.y, d.y)) < WATER_Y - 2.0:
				continue # open sky between islands
			if (i + j) & 1: # alternate diagonals: less grid-like facets
				_tri(pos, col, a, b, c)
				_tri(pos, col, b, d, c)
			else:
				_tri(pos, col, a, b, d)
				_tri(pos, col, a, d, c)
			if _floating: # rocky underside, wound to face down
				var ua := Vector3(a.x, minf(bottom(a.x, a.z), a.y), a.z)
				var ub := Vector3(b.x, minf(bottom(b.x, b.z), b.y), b.z)
				var uc := Vector3(c.x, minf(bottom(c.x, c.z), c.y), c.z)
				var ud := Vector3(d.x, minf(bottom(d.x, d.z), d.y), d.z)
				_under(pos, col, ua, ub, ud)
				_under(pos, col, ua, ud, uc)

	var cn := int(COARSE_EXTENT * 2.0 / COARSE)
	var sub := int(COARSE / FINE)
	for i in cn:
		var z0 := -COARSE_EXTENT + i * COARSE
		for j in cn:
			var x0 := -COARSE_EXTENT + j * COARSE
			var inside_x := x0 >= -FINE_EXTENT and x0 + COARSE <= FINE_EXTENT
			var inside_z := z0 >= -FINE_EXTENT and z0 + COARSE <= FINE_EXTENT
			if inside_x and inside_z:
				continue
			# Edges touching the fine grid get its vertices too, so there are no T-junction cracks.
			var w := sub if inside_z and x0 + COARSE == -FINE_EXTENT else 1
			var e := sub if inside_z and x0 == FINE_EXTENT else 1
			var s := sub if inside_x and z0 + COARSE == -FINE_EXTENT else 1
			var nn := sub if inside_x and z0 == FINE_EXTENT else 1
			if _floating and height(x0 + COARSE / 2.0, z0 + COARSE / 2.0) < WATER_Y - 2.0:
				continue
			if w + e + s + nn == 4:
				var a := _v(x0, z0)
				var b := _v(x0 + COARSE, z0)
				var c := _v(x0, z0 + COARSE)
				var d := _v(x0 + COARSE, z0 + COARSE)
				_tri(pos, col, a, b, d)
				_tri(pos, col, a, d, c)
				continue
			var ring: Array[Vector3] = []
			for k in nn: ring.append(_v(x0 + COARSE * k / nn, z0)) # z0 edge (north side of the fine grid)
			for k in w: ring.append(_v(x0 + COARSE, z0 + COARSE * k / w))
			for k in s: ring.append(_v(x0 + COARSE - COARSE * k / s, z0 + COARSE))
			for k in e: ring.append(_v(x0, z0 + COARSE - COARSE * k / e))
			var ctr := _v(x0 + COARSE / 2.0, z0 + COARSE / 2.0)
			for k in ring.size():
				_tri(pos, col, ctr, ring[k], ring[(k + 1) % ring.size()])

	_runway_marks(pos, col)

	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for k in range(0, pos.size(), 3):
		var fn := (pos[k + 2] - pos[k]).cross(pos[k + 1] - pos[k]).normalized()
		nrm[k] = fn
		nrm[k + 1] = fn
		nrm[k + 2] = fn
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://terrain_ground.gdshader")
	var shown := DisplayServer.get_name() != "headless" # servers and tests never draw it
	light_map = _bake_light(hs, n) if shown else null
	RenderingServer.global_shader_parameter_set("baked_light", light_map) # ground, props, water, Sky Kingdom's cloud sea
	_mat = mat
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	return mi


# ---------- baked light ----------
# Sun shadows + ambient occlusion baked once per world from the same heights, so phones can skip the
# real-time shadow pass. light_map: one texel per fine-grid vertex, R = sun visibility, G = AO.
# blob_map: soft prop shadows (trees, houses, rocks) cast away from the sun. Shaders hardcode this area
# (+-FINE_EXTENT, 201 texels: baked_uv) and read light_map as the global uniform baked_light.
const BLOB_PX := 2048
static var light_map: ImageTexture
static var _mat: ShaderMaterial
static var _brushes := {}


static func _bake_light(hs: PackedFloat32Array, n: int) -> ImageTexture:
	var sun := Atmos.sun_dir()
	var s2 := Vector2(sun.x, sun.z).normalized()
	var drop := 2.0 * FINE * sun.y / Vector2(sun.x, sun.z).length() # shadow surface sinks this much per 2-cell step
	# One sweep from the sun's side: S = max(own height, S two cells sunward - drop). Below S = in shadow.
	var sh := PackedFloat32Array()
	sh.resize(n * n)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var i_rng := range(n - 1, -1, -1) if s2.y > 0.0 else range(n)
	var j_rng := range(n - 1, -1, -1) if s2.x > 0.0 else range(n)
	for i: int in i_rng:
		for j: int in j_rng:
			var h := maxf(hs[i * n + j], WATER_Y) # under water (and Sky Kingdom's cloud sea): shade the surface
			var gx := j + s2.x * 2.0
			var gz := i + s2.y * 2.0
			var vis := 1.0
			var top := h
			if gx >= 0.0 and gz >= 0.0 and gx <= n - 1 and gz <= n - 1:
				var x0 := mini(int(gx), n - 2)
				var z0 := mini(int(gz), n - 2)
				var fx := gx - x0
				var fz := gz - z0
				var k := z0 * n + x0
				var up := lerpf(lerpf(sh[k], sh[k + 1], fx), lerpf(sh[k + n], sh[k + n + 1], fx), fz) - drop
				vis = 1.0 - smoothstep(1.0, 10.0, up - h)
				top = maxf(h, up)
			sh[i * n + j] = top
			# AO: how far the ground sits below its surroundings ~75 m out (valleys, gullies, lake bowls).
			var a := 0.0
			for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]:
				a += hs[clampi(i + d.y, 0, n - 1) * n + clampi(j + d.x, 0, n - 1)]
			var ao := 1.0 - 0.45 * smoothstep(2.0, 40.0, a / 8.0 - h)
			img.set_pixel(j, i, Color(vis, ao, 1.0))
	return ImageTexture.create_from_image(img)


# Prop shadows on the ground: every prop instance (transform + local AABB) stamps soft discs over its
# footprint and out along the sun's shadow direction for its height. Called by Props.build.
static func bake_blobs(casters: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sun := Atmos.sun_dir()
	var away := -Vector2(sun.x, sun.z) / maxf(sun.y, 0.1) # ground offset per metre of height
	var px := FINE_EXTENT * 2.0 / BLOB_PX
	var img := Image.create(BLOB_PX, BLOB_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for i in range(0, casters.size(), 2):
		var t: Transform3D = casters[i]
		var box: AABB = t * (casters[i + 1] as AABB)
		var c3 := box.get_center()
		var ground := height(c3.x, c3.z)
		var lo := maxf(box.position.y - ground, 0.0) + box.size.y * 0.15 # trunks / bases cast little
		var hi := minf(box.end.y - ground, 300.0 * sun.y)
		if hi - lo < 1.0 or absf(c3.x) > FINE_EXTENT or absf(c3.z) > FINE_EXTENT:
			continue
		# Footprint = the two most horizontal box axes; stamps run along the longer one.
		var ax: Array[Vector3] = []
		var loc: AABB = casters[i + 1]
		for k in 3:
			ax.append(t.basis[k] * loc.size[k])
		ax.sort_custom(func(p: Vector3, q: Vector3) -> bool: return absf(p.y) / maxf(p.length(), 0.001) < absf(q.y) / maxf(q.length(), 0.001))
		var u := Vector2(ax[0].x, ax[0].z)
		var v := Vector2(ax[1].x, ax[1].z)
		if u.length() < v.length():
			var w := u
			u = v
			v = w
		var r := maxf(v.length() * 0.45, px)
		var rp := clampi(roundi(r / px), 1, 40)
		var brush := _brush(rp)
		var along := maxf(u.length() - 2.0 * r, 0.0)
		var nu := clampi(ceili(along / r), 0, 64)
		var ns := clampi(ceili(away.length() * (hi - lo) / maxf(r * 0.8, px)), 1, 64)
		var c := Vector2(c3.x, c3.z)
		for a in nu + 1:
			var base := c + u.normalized() * along * (float(a) / maxi(nu, 1) - 0.5) if nu > 0 else c
			for k in ns + 1:
				var q := base + away * lerpf(lo, hi, float(k) / ns)
				img.blend_rect(brush, Rect2i(0, 0, rp * 2 + 1, rp * 2 + 1), Vector2i(roundi((q.x + FINE_EXTENT) / px) - rp, roundi((q.y + FINE_EXTENT) / px) - rp))
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	if _mat:
		_mat.set_shader_parameter("blob_map", ImageTexture.create_from_image(img))


# Soft black disc, alpha strongest in the middle. Stamps along one caster overlap, so keep it light.
static func _brush(rp: int) -> Image:
	if not _brushes.has(rp):
		var w := rp * 2 + 1
		var b := Image.create(w, w, false, Image.FORMAT_RGBA8)
		for y in w:
			for x in w:
				var d := Vector2(x - rp, y - rp).length() / (rp + 0.5)
				b.set_pixel(x, y, Color(0, 0, 0, 0.5 * (1.0 - smoothstep(0.55, 1.0, d))))
		_brushes[rp] = b
	return _brushes[rp]


# Phones (or shadows off): the baked sun shadow stands in for the real-time one.
static func use_baked_sun(on: bool) -> void:
	RenderingServer.global_shader_parameter_set("baked_sun", 1.0 if on else 0.0)


static func _under(pos: PackedVector3Array, col: PackedColorArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (c - a).cross(b - a).y > 0.0:
		var t := b
		b = c
		c = t
	pos.append(a)
	pos.append(b)
	pos.append(c)
	var k: Color = (_pal.cliff as Color).darkened(0.25 + fmod(absf(a.x * 0.013 + a.z * 0.007), 0.15))
	col.append(k)
	col.append(k)
	col.append(k)


static func _v(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


# Appends one flat-coloured triangle, wound so it faces up (Godot front faces are clockwise).
static func _tri(pos: PackedVector3Array, col: PackedColorArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	var fn := (c - a).cross(b - a)
	if fn.y < 0.0:
		var t := b
		b = c
		c = t
		fn = -fn
	pos.append(a)
	pos.append(b)
	pos.append(c)
	var k := _face_color((a + b + c) / 3.0, fn.normalized().y)
	col.append(k)
	col.append(k)
	col.append(k)


static func _face_color(p: Vector3, up: float) -> Color:
	var P := _pal
	var t := _tint.get_noise_2d(p.x, p.z) # -1..1 patches
	var jit := (float(hash(Vector2i(int(p.x * 7.0), int(p.z * 7.0))) % 1000) / 1000.0 - 0.5) * 0.06
	var h := p.y
	var k: Color
	if RUNWAY.grow(0.5).has_point(Vector2(p.x, p.z)):
		return P.runway
	if h < WATER_Y - 1.5:
		k = P.bed
	elif h < WATER_Y + 3.5:
		k = P.sand
	elif up < 0.72:
		k = (P.cliff as Color).lerp(P.cliff2, t * 0.5 + 0.5)
	elif h > P.snow_h + t * 60.0 and up > 0.6:
		k = P.snow
	elif h > P.alpine_h + t * 40.0:
		k = P.alpine_rock if up < 0.85 else P.alpine
	elif h > P.forest_h + t * 30.0:
		k = (P.forest as Color).lerp(P.forest2, t * 0.5 + 0.5)
	else:
		var lush: Color = (P.lush as Color).lerp(P.lush2, smoothstep(-0.3, 0.3, t))
		k = lush.lerp(P.field, smoothstep(0.35, 0.6, t)) # occasional fields
		k = k.lerp(P.wood, smoothstep(-0.35, -0.6, t)) # and darker woodland
		if up < 0.88:
			k = k.lerp(P.slope, 0.5)
	if _recolor.is_valid():
		k = _recolor.call(p, up, k)
	return Color(k.r + jit, k.g + jit, k.b + jit)


# Top-down minimap picture of the current world: same face colours as the 3D terrain, hill-shaded,
# with water / cloud sea. Painted a few rows at a time (map_rows) so the bake never stalls a frame.
const MAP_PX := 256


static func map_rows(img: Image, i0: int, i1: int) -> void:
	var px := img.get_width()
	var cell := FINE_EXTENT * 2.0 / px
	var cfg: Dictionary = Worlds.cur
	var wat: Dictionary = cfg.water
	var light := Vector3(-0.6, 0.7, -0.4).normalized() # from the north-west, like a printed map
	var w := px + 2 # one sample of border so every pixel has neighbours for its normal
	var rows := i1 - i0 + 2
	var hs := PackedFloat32Array()
	hs.resize(w * (rows + 1))
	for r in rows + 1:
		for j in w:
			hs[r * w + j] = height(-FINE_EXTENT + (j - 0.5) * cell, -FINE_EXTENT + (i0 + r - 0.5) * cell)
	for i in range(i0, i1 + 1):
		for j in px:
			var c := (i - i0 + 1) * w + j + 1
			var h := hs[c]
			var n := Vector3(hs[c - 1] - hs[c + 1], 2.0 * cell, hs[c - w] - hs[c + w]).normalized()
			var k := _face_color(Vector3(-FINE_EXTENT + (j + 0.5) * cell, h, -FINE_EXTENT + (i + 0.5) * cell), n.y)
			if _floating and h < cfg.env.kill_y + 2.0:
				k = cfg.clouds.mid
			elif wat.get("visible", true) and h < wat.get("y", WATER_Y):
				k = (wat.shallow as Color).lerp(wat.deep, clampf((wat.get("y", WATER_Y) - h) / 12.0, 0.0, 1.0))
			else:
				k = k * (0.75 + 0.4 * clampf(n.dot(light), 0.0, 1.0))
			img.set_pixel(j, i, Color(k.r, k.g, k.b))


# Prop footprints (Metro's towers, bases, bridges) darkened onto the finished map.
static func map_stamp(img: Image, obstacles: Array) -> void:
	var px := img.get_width()
	var cell := FINE_EXTENT * 2.0 / px
	for a in obstacles:
		var b: AABB = a
		var p0 := Vector2i(floori((b.position.x + FINE_EXTENT) / cell), floori((b.position.z + FINE_EXTENT) / cell))
		var p1 := Vector2i(floori((b.end.x + FINE_EXTENT) / cell), floori((b.end.z + FINE_EXTENT) / cell))
		for i in range(maxi(p0.y, 0), mini(p1.y, px - 1) + 1):
			for j in range(maxi(p0.x, 0), mini(p1.x, px - 1) + 1):
				img.set_pixel(j, i, img.get_pixel(j, i).darkened(0.45))


static func _runway_marks(pos: PackedVector3Array, col: PackedColorArray) -> void:
	var y := RUNWAY_Y + 0.3
	var cx := RUNWAY.get_center().x
	var white := Color(0.95, 0.95, 0.95)
	var quads: Array[Rect2] = []
	var z := RUNWAY.position.y + 60.0
	while z < RUNWAY.end.y - 70.0: # centreline dashes
		quads.append(Rect2(cx - 0.75, z, 1.5, 18.0))
		z += 36.0
	for k in 8: # threshold piano keys at both ends
		var x := RUNWAY.position.x + 4.0 + k * 5.5 + (2.0 if k >= 4 else 0.0)
		quads.append(Rect2(x, RUNWAY.position.y + 6.0, 2.5, 26.0))
		quads.append(Rect2(x, RUNWAY.end.y - 32.0, 2.5, 26.0))
	quads.append(Rect2(RUNWAY.position.x + 1.0, RUNWAY.position.y + 2.0, 1.0, RUNWAY.size.y - 4.0)) # edge lines
	quads.append(Rect2(RUNWAY.end.x - 2.0, RUNWAY.position.y + 2.0, 1.0, RUNWAY.size.y - 4.0))
	for r in quads:
		var a := Vector3(r.position.x, y, r.position.y)
		var b := Vector3(r.end.x, y, r.position.y)
		var c := Vector3(r.position.x, y, r.end.y)
		var d := Vector3(r.end.x, y, r.end.y)
		for v in [a, b, d, a, d, c]:
			pos.append(v)
			col.append(white)
