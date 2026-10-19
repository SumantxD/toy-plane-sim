class_name Planes
extends RefCounted

# Plane types: stats + low-poly models built from boxes, grouped by damageable component.
# Components: 0 left wing, 1 right wing, 2 engine, 3 tail; a hit damages the part whose anchor
# is within 3 m (plane.component_at), otherwise only hp.
const ORDER := ["cub", "racer", "twin", "fighter"]
const TYPES := {
	"cub": {name = "Toy Cub", desc = "Slow and steady, tight turns, tough", hp = 130, min = 30.0, max = 95.0, boost = 130.0, turn = Vector3(1.9, 0.8, 3.4), fire = 0.09, rockets = 2, radius = 4.5},
	"racer": {name = "Speedster", desc = "Fastest, rolls like crazy, fragile", hp = 75, min = 45.0, max = 135.0, boost = 175.0, turn = Vector3(1.6, 0.6, 4.4), fire = 0.08, rockets = 2, radius = 4.0},
	"twin": {name = "Heavy Twin", desc = "Big and slow, two engines, 6 rockets", hp = 190, min = 35.0, max = 100.0, boost = 135.0, turn = Vector3(1.15, 0.45, 2.3), fire = 0.06, rockets = 6, radius = 6.0},
	"fighter": {name = "Jet Fighter", desc = "Fast all-rounder, 4 homing rockets", hp = 100, min = 40.0, max = 125.0, boost = 165.0, turn = Vector3(1.7, 0.6, 3.6), fire = 0.07, rockets = 4, radius = 4.5},
}
const COMPONENT_NAMES := ["left wing", "right wing", "engine", "tail"]


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
