class_name Planes
extends RefCounted

# Plane types: stats + low-poly models built from boxes, grouped by damageable component.
# Components: 0 left wing, 1 right wing, 2 engine, 3 tail; a hit damages the part whose anchor
# is within 3 m (plane.component_at), otherwise only hp.
const ORDER := ["cub", "racer", "twin", "fighter"]
const TYPES := {
	"cub": {name = "Toy Cub", desc = "Slow and steady, tight turns, tough", hp = 130, min = 30.0, max = 95.0, boost = 130.0, turn = Vector3(1.9, 0.8, 3.4), fire = 0.09, rockets = 2, flares = 3, bombs = 2, radius = 4.5},
	"racer": {name = "Speedster", desc = "Fastest, rolls like crazy, fragile", hp = 75, min = 45.0, max = 135.0, boost = 175.0, turn = Vector3(1.6, 0.6, 4.4), fire = 0.08, rockets = 2, flares = 3, bombs = 1, radius = 4.0},
	"twin": {name = "Heavy Twin", desc = "Big and slow, 6 rockets, 4 bombs", hp = 190, min = 35.0, max = 100.0, boost = 135.0, turn = Vector3(1.15, 0.45, 2.3), fire = 0.06, rockets = 6, flares = 2, bombs = 4, radius = 6.0},
	"fighter": {name = "Jet Fighter", desc = "Fast all-rounder, 4 homing rockets", hp = 100, min = 40.0, max = 125.0, boost = 165.0, turn = Vector3(1.7, 0.6, 3.6), fire = 0.07, rockets = 4, flares = 4, bombs = 2, radius = 4.5},
}
const COMPONENT_NAMES := ["left wing", "right wing", "engine", "tail"]
# Cosmetics only (no stat changes): a sticker on the wings / tail and a waving tail banner.
const STICKERS := ["None", "Star", "Lightning", "Flame", "Roundel", "Checkers", "Shark Mouth"]
const BANNERS := ["None", "Gold", "Lime", "Violet", "White", "Black"]
const BANNER_COLORS := [Color(0, 0, 0, 0), Color(1.0, 0.78, 0.2), Color(0.55, 0.95, 0.3), Color(0.7, 0.45, 1.0), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14)]
# Per model: fuselage [half width, half height, nose z], tail fin [x, y, z, height] (x 0 = one centre fin).
const HULL := {cub = [0.65, 0.7, -3.6, 0.0, 0.9, 3.0, 1.4], racer = [0.5, 0.5, -4.6, 0.0, 1.0, 3.4, 1.9],
	twin = [0.85, 0.9, -5.6, 2.4, 1.2, 4.6, 1.8], fighter = [0.55, 0.5, -5.2, -1.0, 0.0, 0.0, 0.0]}


# Builds the model under `root`. Returns {props: [Node3D], ltip, rtip: Node3D, anchors: [Vector3 x4]}.
static func build(kind: String, root: Node3D, paint: Material, trim: Material, glass: Material, dark: Material, glow: Material) -> Dictionary:
	var parts := {props = [], ltip = null, rtip = null, anchors = [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, -3), Vector3(0, 0.5, 3)]}
	match kind:
		"racer":
			_box(root, Vector3(1.0, 1.0, 8), Vector3(0, 0, 0), paint)
			_box(root, Vector3(1.02, 0.25, 8.02), Vector3(0, 0.2, 0), trim) # racing stripe
			_box(root, Vector3(0.7, 0.7, 1.2), Vector3(0, 0, -4.5), trim)
			_wings(root, parts, 3.8, 1.6, -0.3, -0.2, 8.0, paint)
			_box(root, Vector3(3.0, 0.12, 0.8), Vector3(0, 0.1, 3.6), paint)
			_box(root, Vector3(0.15, 1.9, 1.4), Vector3(0, 1.0, 3.4), trim)
			_box(root, Vector3(0.7, 0.6, 1.6), Vector3(0, 0.6, 0.8), glass)
			parts.props.append(_prop(root, Vector3(0, 0, -5.15), 3, 2.4, dark))
			parts.anchors = [Vector3(-3, -0.3, 0), Vector3(3, -0.3, 0), Vector3(0, 0, -4.5), Vector3(0, 1, 3.4)]
		"twin":
			_box(root, Vector3(1.7, 1.8, 10), Vector3(0, 0, 0), paint)
			_box(root, Vector3(1.3, 1.2, 1.2), Vector3(0, -0.1, -5.4), glass) # glazed bomber nose
			_box(root, Vector3(1.2, 0.6, 1.4), Vector3(0, 1.1, -3.5), glass)
			_wings(root, parts, 7.5, 2.2, 0.1, -0.5, 0.0, paint)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(1.1, 1.1, 3.2), Vector3(3.0 * s, 0, -1.2), trim)
				parts.props.append(_prop(root, Vector3(3.0 * s, 0, -2.9), 3, 2.6, dark))
				_box(root, Vector3(0.15, 1.8, 1.2), Vector3(2.4 * s, 1.2, 4.6), trim)
			_box(root, Vector3(5.0, 0.15, 1.2), Vector3(0, 0.5, 4.6), paint)
			parts.anchors = [Vector3(-5.5, 0.1, -0.5), Vector3(5.5, 0.1, -0.5), Vector3(-3, 0.3, -1.6), Vector3(0, 1.2, 4.6)]
		"fighter":
			_box(root, Vector3(1.1, 1.0, 8.5), Vector3(0, 0, 0), paint)
			_box(root, Vector3(0.6, 0.6, 1.6), Vector3(0, -0.05, -5.0), trim)
			_wings(root, parts, 4.2, 3.0, -0.1, 0.6, 35.0, paint)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.12, 1.6, 1.4), Vector3(0.7 * s, 0.9, 3.3), trim, Vector3(0, 0, -18.0 * s))
				_box(root, Vector3(0.5, 0.7, 2.2), Vector3(0.75 * s, -0.1, -1.0), dark)
			_box(root, Vector3(0.6, 0.5, 1.8), Vector3(0, 0.65, -2.4), glass)
			_box(root, Vector3(0.8, 0.8, 0.3), Vector3(0, 0, 4.35), glow) # afterburner
			parts.anchors = [Vector3(-3, 0, 1.5), Vector3(3, 0, 1.5), Vector3(0, 0, 4.5), Vector3(0, 1.2, 3.3)]
		"balloon": # practice target: striped envelope, basket
			var env := MeshInstance3D.new()
			env.mesh = SphereMesh.new()
			env.mesh.radius = 5.0
			env.mesh.height = 11.0
			env.mesh.radial_segments = 10
			env.mesh.rings = 6
			env.material_override = paint
			env.position.y = 4.0
			root.add_child(env)
			_box(root, Vector3(2.0, 1.4, 2.0), Vector3(0, -3.0, 0), trim)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.08, 3.0, 0.08), Vector3(0.9 * s, -1.0, 0), dark)
			parts.anchors = [Vector3(0, 4, 0), Vector3(0, 4, 0), Vector3(0, 4, 0), Vector3(0, -3, 0)]
		_: # cub: high wing, struts, fixed gear, big prop
			_box(root, Vector3(1.3, 1.4, 6), Vector3(0, 0, 0.2), paint)
			_box(root, Vector3(1.4, 1.4, 0.9), Vector3(0, 0, -3.1), trim)
			_wings(root, parts, 5.5, 1.8, 0.95, -0.6, 0.0, paint)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.1, 1.3, 0.1), Vector3(1.6 * s, 0.35, -0.6), trim, Vector3(0, 0, 40.0 * s))
				_box(root, Vector3(0.1, 1.0, 0.1), Vector3(0.7 * s, -0.95, -1.2), trim, Vector3(0, 0, -20.0 * s))
				_box(root, Vector3(0.3, 0.7, 0.7), Vector3(0.9 * s, -1.4, -1.2), dark)
			_box(root, Vector3(3.6, 0.15, 0.9), Vector3(0, 0.2, 3.0), paint)
			_box(root, Vector3(0.15, 1.4, 1.0), Vector3(0, 0.9, 3.0), trim)
			_box(root, Vector3(1.0, 0.6, 1.0), Vector3(0, 0.6, -1.7), glass)
			parts.props.append(_prop(root, Vector3(0, 0, -3.65), 2, 3.0, dark))
			parts.anchors = [Vector3(-3.5, 1, -0.6), Vector3(3.5, 1, -0.6), Vector3(0, 0, -3.2), Vector3(0, 0.9, 3)]
	return parts


# Each wing = inner panel + outer tip; the tip breaks off when the wing component dies.
static func _wings(root: Node3D, parts: Dictionary, half_span: float, chord: float, y: float, z: float, sweep: float, mat: Material) -> void:
	var k := tan(deg_to_rad(sweep))
	var split := half_span * 0.55
	parts.wing = [half_span, chord, y, z, k, split] # dress() hangs weapons and stickers off this
	for s in [-1.0, 1.0]:
		var inner_mid := (0.5 + split) / 2.0
		var tip_mid := (split + half_span) / 2.0
		_box(root, Vector3(split - 0.5, 0.22, chord), Vector3(inner_mid * s, y, z + inner_mid * k), mat, Vector3(0, -sweep * s, 0))
		var tip := _box(root, Vector3(half_span - split, 0.2, chord * 0.8), Vector3(tip_mid * s, y, z + tip_mid * k), mat, Vector3(0, -sweep * s, 0))
		parts["ltip" if s < 0 else "rtip"] = tip


static func _prop(root: Node3D, at: Vector3, blades: int, length: float, mat: Material) -> Node3D:
	var hub := Node3D.new()
	hub.position = at
	root.add_child(hub)
	for i in blades:
		_box(hub, Vector3(0.22, length, 0.08), Vector3.ZERO, mat, Vector3(0, 0, 180.0 * i / blades))
	_box(hub, Vector3(0.4, 0.4, 0.5), Vector3.ZERO, mat)
	return hub


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.mesh.size = size
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	parent.add_child(m)
	return m


# Weapons you can see (they vanish as you fire them), gun barrels, sticker and banner. Rockets hang on
# the inner wing so they stay put if a wingtip is shot off. Returns parts.rockets / parts.bombs (nodes).
static func dress(kind: String, root: Node3D, parts: Dictionary, n_rockets: int, n_bombs: int, sticker: int, banner: int, dark: Material, toon: Callable) -> void:
	var w: Array = parts.get("wing", [4.0, 1.8, 0.0, 0.0, 0.0, 2.2])
	var hull: Array = HULL.get(kind, HULL.cub)
	var under: float = w[2] - 0.11
	var white: Material = toon.call(Color(0.93, 0.93, 0.9))
	var red: Material = toon.call(Color(0.85, 0.2, 0.15))
	parts.rockets = []
	for i in n_rockets:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x: float = side * (0.95 + (i / 2) * minf(0.75, (w[5] - 1.0) / maxf(n_rockets / 2.0, 1.0)))
		var z: float = w[3] + absf(x) * w[4]
		var r := Node3D.new()
		r.position = Vector3(x, under - 0.32, z)
		root.add_child(r)
		_box(r, Vector3(0.08, 0.22, 0.6), Vector3(0, 0.2, 0.1), dark) # pylon
		var body := _cyl(r, 0.13, 0.13, 1.3, white)
		body.rotation_degrees.x = 90
		var tip := _cyl(r, 0.0, 0.13, 0.35, red)
		tip.rotation_degrees.x = -90
		tip.position.z = -0.82
		parts.rockets.append(r)
	parts.bombs = []
	for i in n_bombs:
		var b := Node3D.new()
		var row := (i - (n_bombs - 1) / 2.0) * 1.0
		b.position = Vector3(0.35 * (1 if i % 2 else -1) if n_bombs > 2 else 0.0, -hull[1] - 0.32, row * 0.9)
		root.add_child(b)
		var shell := MeshInstance3D.new()
		shell.mesh = CapsuleMesh.new()
		shell.mesh.radius = 0.26
		shell.mesh.height = 1.3
		shell.rotation_degrees.x = 90
		shell.material_override = toon.call(Color(0.25, 0.28, 0.22))
		b.add_child(shell)
		_box(b, Vector3(0.5, 0.05, 0.25), Vector3(0, 0, 0.6), dark)
		parts.bombs.append(b)
	for side in [-1.0, 1.0]: # gun barrels poking out of the wing roots
		var gx: float = side * (hull[0] + 0.35)
		_box(root, Vector3(0.09, 0.09, 1.0), Vector3(gx, w[2] - 0.05, w[3] - w[1] * 0.5 - 0.4 + absf(gx) * w[4]), dark)
	if sticker > 0:
		_sticker(sticker, root, parts, w, hull, toon)
	if banner > 0:
		var fin := Vector3(0.0, hull[4] + hull[6] * 0.35, hull[5] + 0.5) if hull[6] > 0.0 else Vector3(0, 0.4, 4.6)
		var flag := MeshInstance3D.new()
		flag.mesh = QuadMesh.new()
		flag.mesh.size = Vector2(3.4, 0.6)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://banner.gdshader")
		mat.set_shader_parameter("color", BANNER_COLORS[banner])
		flag.material_override = mat
		flag.rotation_degrees.y = 90 # streams straight back, ripples sideways
		flag.position = fin + Vector3(0, 0, 1.7)
		root.add_child(flag)


static func _sticker(i: int, root: Node3D, parts: Dictionary, w: Array, hull: Array, toon: Callable) -> void:
	var name: String = STICKERS[i]
	var size: float = minf(w[1] * 0.8, 1.6)
	if name == "Shark Mouth": # on both nose sides
		for side in [-1.0, 1.0]:
			var t := Transform3D(Basis(Vector3.UP, side * PI / 2.0), Vector3(side * (hull[0] + 0.03), -0.1, hull[2] + 1.7)) # fully on the fuselage side, not hanging off the nose
			_shape(root, _circle(0.55, 14), Color(0.8, 0.12, 0.12), t, Vector2(1.0, 0.55), toon)
			for k in 5:
				var tx := -0.45 + k * 0.22
				_shape(root, PackedVector2Array([Vector2(tx, 0.0), Vector2(tx + 0.18, 0.0), Vector2(tx + 0.09, -0.22)]), Color.WHITE, t.translated_local(Vector3(0, 0, 0.03)), Vector2.ONE, toon)
		return
	var spots: Array = []
	for side in [-1.0, 1.0]: # top of each inner wing
		var x: float = side * (0.5 + w[5]) * 0.55
		spots.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(x, w[2] + 0.115, w[3] + absf(x) * w[4])))
	if hull[6] > 0.0: # both faces of the tail fin(s)
		for fx in ([hull[3]] if hull[3] == 0.0 else [-hull[3], hull[3]]):
			for side in [-1.0, 1.0]:
				spots.append(Transform3D(Basis(Vector3.UP, side * PI / 2.0), Vector3(fx + side * 0.09, hull[4], hull[5])))
	for t in spots:
		var sz := size if t.basis.y.y < 0.5 else minf(size, hull[6] * 0.55)
		match name:
			"Star":
				var star := PackedVector2Array()
				for k in 10:
					star.append(Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * (0.5 if k % 2 == 0 else 0.2))
				_shape(root, star, Color.WHITE, t, Vector2.ONE * sz, toon)
			"Lightning":
				_shape(root, PackedVector2Array([Vector2(-0.1, -0.5), Vector2(0.3, -0.5), Vector2(0.05, -0.08), Vector2(0.28, -0.08),
					Vector2(-0.22, 0.5), Vector2(-0.02, 0.04), Vector2(-0.28, 0.04)]), Color(1.0, 0.86, 0.15), t, Vector2.ONE * sz, toon)
			"Flame":
				_shape(root, PackedVector2Array([Vector2(0, 0.5), Vector2(0.32, 0.2), Vector2(0.28, -0.15), Vector2(0.12, -0.05), Vector2(0.15, -0.5),
					Vector2(-0.05, -0.2), Vector2(-0.18, -0.42), Vector2(-0.3, 0.05), Vector2(-0.3, 0.25)]), Color(1.0, 0.45, 0.1), t, Vector2.ONE * sz, toon)
				_shape(root, PackedVector2Array([Vector2(0, 0.38), Vector2(0.16, 0.15), Vector2(0.08, -0.15), Vector2(-0.02, 0.0), Vector2(-0.15, 0.15)]),
					Color(1.0, 0.85, 0.2), t.translated_local(Vector3(0, 0, 0.03)), Vector2.ONE * sz, toon)
			"Roundel":
				_shape(root, _circle(0.5, 18), Color.WHITE, t, Vector2.ONE * sz, toon)
				_shape(root, _circle(0.32, 18), Color(0.85, 0.2, 0.15), t.translated_local(Vector3(0, 0, 0.03)), Vector2.ONE * sz, toon)
				_shape(root, _circle(0.14, 14), Color(0.2, 0.3, 0.75), t.translated_local(Vector3(0, 0, 0.06)), Vector2.ONE * sz, toon)
			"Checkers":
				for cx in 4:
					for cy in 4:
						var c := Color.WHITE if (cx + cy) % 2 == 0 else Color(0.1, 0.1, 0.1)
						var o := Vector2(-0.5 + cx * 0.25, -0.5 + cy * 0.25)
						_shape(root, PackedVector2Array([o, o + Vector2(0.25, 0), o + Vector2(0.25, 0.25), o + Vector2(0, 0.25)]), c, t, Vector2.ONE * sz, toon)


static func _circle(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(Vector2.from_angle(TAU * k / n) * r)
	return pts


# Flat coloured polygon (local XY plane, facing +Z) placed by `t`, nudged off the surface it sits on.
static func _shape(root: Node3D, poly: PackedVector2Array, color: Color, t: Transform3D, scale: Vector2, toon: Callable) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var verts := PackedVector3Array()
	for k in idx:
		verts.append(Vector3(poly[k].x * scale.x, -poly[k].y * scale.y, 0.0))
	for k in range(idx.size() - 1, -1, -1): # and the reverse winding: visible from either side
		verts.append(Vector3(poly[idx[k]].x * scale.x, -poly[idx[k]].y * scale.y, 0.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat: Material = toon.call(color)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.transform = t.translated_local(Vector3(0, 0, 0.06)) # layers sit 3 cm apart: closer than that they z-fight at range
	root.add_child(m)


static func _cyl(parent: Node3D, top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = CylinderMesh.new()
	m.mesh.top_radius = top
	m.mesh.bottom_radius = bottom
	m.mesh.height = h
	m.mesh.radial_segments = 8
	m.mesh.rings = 1
	m.material_override = mat
	parent.add_child(m)
	return m
