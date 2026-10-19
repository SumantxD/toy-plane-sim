class_name Terrain
extends RefCounted

# Shared world contract. Every peer builds the same world from these, nothing is synced.
# height(x, z) is the ONE source of truth for ground: mesh, crashes, prop placement, AI.
const SEED := 1337
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


static func _n() -> FastNoiseLite:
	if not _noise:
		_noise = FastNoiseLite.new()
		_noise.seed = SEED
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.0011
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
	var n := _n().get_noise_2d(x, z) * 0.5 + 0.5
	var h := 18.0 + pow(n, 1.6) * 220.0
	var rwd := _rect_dist(RUNWAY, Vector2(x, z))
	var edge := maxf(absf(x), absf(z)) + _noise.get_noise_2d(z + 7000.0, x - 3000.0) * 250.0
	var m := smoothstep(1500.0, 2700.0, edge) * smoothstep(250.0, 900.0, rwd) # runway keeps an open valley
	if m > 0.0: # ring of mountains = soft world edge
		h += m * (180.0 + (_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 560.0)
	h = lerpf(minf(h, CORRIDOR_CAP), h, smoothstep(180.0, 450.0, _route_dist(x, z)))
	var ld := Vector2(x, z).distance_to(LAKE_CENTER) + _noise.get_noise_2d(x * 3.0, z * 3.0) * 70.0
	if ld < LAKE_RADIUS * 2.4: # shallow basin, then the lake bowl
		h = minf(h, lerpf(WATER_Y + 5.0, h, smoothstep(LAKE_RADIUS, LAKE_RADIUS * 2.4, ld)))
		h = lerpf(-12.0, h, smoothstep(LAKE_RADIUS * 0.6, LAKE_RADIUS * 1.05, ld))
	var rd := _river_dist(x, z)
	if rd < RIVER_REACH: # valley floor just above water, then the channel
		var valley := minf(60.0 + maxf(h - WATER_Y, 0.0) * 2.0, RIVER_REACH - RIVER_HALF_WIDTH)
		h = minf(h, lerpf(WATER_Y + 5.0, h, smoothstep(RIVER_HALF_WIDTH, RIVER_HALF_WIDTH + valley, rd)))
		h = minf(h, lerpf(RIVER_BED_Y, h, smoothstep(RIVER_HALF_WIDTH * 0.5, RIVER_HALF_WIDTH + 12.0, rd)))
	h = lerpf(RUNWAY_Y, h, smoothstep(10.0, 220.0, rwd))
	return h


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
			if (i + j) & 1: # alternate diagonals: less grid-like facets
				_tri(pos, col, a, b, c)
				_tri(pos, col, b, d, c)
			else:
				_tri(pos, col, a, b, d)
				_tri(pos, col, a, d, c)

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
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	return mi


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
	var t := _tint.get_noise_2d(p.x, p.z) # -1..1 patches
	var jit := (float(hash(Vector2i(int(p.x * 7.0), int(p.z * 7.0))) % 1000) / 1000.0 - 0.5) * 0.06
	var h := p.y
	var k: Color
	if RUNWAY.grow(0.5).has_point(Vector2(p.x, p.z)):
		return Color(0.36, 0.37, 0.4)
	if h < WATER_Y - 1.5:
		k = Color(0.62, 0.6, 0.45)
	elif h < WATER_Y + 3.5:
		k = Color(0.95, 0.86, 0.6)
	elif up < 0.72:
		k = Color(0.56, 0.53, 0.5).lerp(Color(0.62, 0.5, 0.4), t * 0.5 + 0.5)
	elif h > 470.0 + t * 60.0 and up > 0.6:
		k = Color(0.97, 0.98, 1.0)
	elif h > 320.0 + t * 40.0:
		k = Color(0.6, 0.6, 0.55) if up < 0.85 else Color(0.33, 0.5, 0.3)
	elif h > 160.0 + t * 30.0:
		k = Color(0.27, 0.55, 0.27).lerp(Color(0.2, 0.45, 0.25), t * 0.5 + 0.5)
	else:
		var lush := Color(0.42, 0.72, 0.3).lerp(Color(0.32, 0.62, 0.28), smoothstep(-0.3, 0.3, t))
		k = lush.lerp(Color(0.72, 0.78, 0.36), smoothstep(0.35, 0.6, t)) # occasional golden fields
		k = k.lerp(Color(0.22, 0.48, 0.24), smoothstep(-0.35, -0.6, t)) # and darker woodland
		if up < 0.88:
			k = k.lerp(Color(0.5, 0.55, 0.32), 0.5)
	return Color(k.r + jit, k.g + jit, k.b + jit)


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
