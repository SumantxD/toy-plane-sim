class_name Planes
extends RefCounted

# Plane types: stats + low-poly toy models, grouped by damageable component.
# Components: 0 left wing, 1 right wing, 2 engine, 3 tail; a hit damages the part whose anchor
# is within 3 m (plane.component_at), otherwise only hp.
const ORDER := ["cub", "racer", "twin", "fighter"]
const TYPES := {
	"cub": {name = "Toy Cub", desc = "Slow and steady, tight turns, tough", hp = 130, min = 30.0, max = 95.0, boost = 130.0, turn = Vector3(1.9, 0.8, 3.4), fire = 0.09, rockets = 2, flares = 3, bombs = 2, radius = 4.5},
	"racer": {name = "Speedster", desc = "Fastest, rolls like crazy, fragile", hp = 75, min = 45.0, max = 135.0, boost = 175.0, turn = Vector3(1.6, 0.6, 4.4), fire = 0.08, rockets = 2, flares = 3, bombs = 1, radius = 4.0},
	"twin": {name = "Heavy Twin", desc = "Big and slow, 6 rockets, 4 bombs", hp = 190, min = 35.0, max = 100.0, boost = 135.0, turn = Vector3(1.15, 0.45, 2.3), fire = 0.06, rockets = 6, flares = 2, bombs = 4, radius = 6.0},
	"fighter": {name = "Jet Fighter", desc = "Fast all-rounder, 4 homing rockets", hp = 100, min = 40.0, max = 125.0, boost = 165.0, turn = Vector3(1.7, 0.6, 3.6), fire = 0.07, rockets = 4, flares = 4, bombs = 2, radius = 4.5},
}
# Each world flies its own themed version of every class (looks, name and blurb only: stats stay in TYPES).
# Valley uses the TYPES names.
const LINEUP := [{},
	{cub = ["Puddle Jumper", "Float plane: slow and steady, tight turns, tough"], racer = ["Wave Racer", "Float racer: fastest, rolls like crazy, fragile"],
		twin = ["Lava Clipper", "Twin-float bomber: big and slow, 6 rockets, 4 bombs"], fighter = ["Ash Skimmer", "Hydro-ski jet: fast all-rounder, 4 homing rockets"]},
	{cub = ["Snow Bug", "Ski plane: slow and steady, tight turns, tough"], racer = ["Icicle", "Ski racer: fastest, rolls like crazy, fragile"],
		twin = ["Polar Hauler", "Arctic freighter: big and slow, 6 rockets, 4 bombs"], fighter = ["Frost Fang", "Arctic jet: fast all-rounder, 4 homing rockets"]},
	{cub = ["Dune Hopper", "Bush plane on fat tyres: slow, steady, tough"], racer = ["Mirage", "Desert racer: fastest, rolls like crazy, fragile"],
		twin = ["Sand Camel", "Camo hauler: big and slow, 6 rockets, 4 bombs"], fighter = ["Scorpion", "Desert jet: fast all-rounder, 4 homing rockets"]},
	{cub = ["Neon Pup", "Ducted-fan hopper: slow and steady, tough"], racer = ["Volt", "Neon dart: fastest, rolls like crazy, fragile"],
		twin = ["Night Freighter", "Glow hauler: big and slow, 6 rockets, 4 bombs"], fighter = ["Laser Hawk", "Neon jet: fast all-rounder, 4 homing rockets"]},
	{cub = ["Cloud Kite", "Long-wing kite plane: slow, steady, tough"], racer = ["Zephyr", "Brass glider racer: fastest, rolls like crazy, fragile"],
		twin = ["Sky Galleon", "Gas-bag freighter: big and slow, 6 rockets, 4 bombs"], fighter = ["Brass Hawk", "Clockwork jet: fast all-rounder, 4 homing rockets"]},
]
# Per world: landing gear, trim (cowls, fin and wing caps), accent (stripes, floats), strut colour.
const STYLE := [
	{gear = "wheels", trim = Color(0.95, 0.93, 0.85), accent = Color(0.95, 0.78, 0.2), strut = Color(0.2, 0.2, 0.22)},
	{gear = "floats", trim = Color(0.2, 0.19, 0.19), accent = Color(1.0, 0.5, 0.12), strut = Color(0.2, 0.19, 0.19)},
	{gear = "skis", trim = Color(0.97, 0.98, 1.0), accent = Color(0.14, 0.15, 0.18), strut = Color(0.14, 0.15, 0.18)},
	{gear = "tyres", trim = Color(0.93, 0.86, 0.68), accent = Color(0.78, 0.64, 0.42), strut = Color(0.45, 0.4, 0.32)},
	{gear = "none", trim = Color(0.13, 0.13, 0.17), accent = Color(0.13, 0.13, 0.17), strut = Color(0.13, 0.13, 0.17)},
	{gear = "spats", trim = Color(0.86, 0.64, 0.25), accent = Color(0.5, 0.32, 0.17), strut = Color(0.5, 0.32, 0.17)},
]
const COMPONENT_NAMES := ["left wing", "right wing", "engine", "tail"]
# Cosmetics only (no stat changes): a sticker on the wings / tail and coloured wingtip smoke trails.
const STICKERS := ["None", "Star", "Lightning", "Flame", "Roundel", "Checkers", "Shark Mouth"]
const BANNERS := ["None", "Gold", "Lime", "Violet", "White", "Black"]
const BANNER_COLORS := [Color(0, 0, 0, 0), Color(1.0, 0.78, 0.2), Color(0.55, 0.95, 0.3), Color(0.7, 0.45, 1.0), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14)]
# Per model: fuselage [half width, half height, nose z], tail fin [x, y, z, height] (x 0 = one centre fin).
const HULL := {cub = [0.58, 0.62, -3.6, 0.0, 0.95, 3.25, 1.4], racer = [0.5, 0.52, -4.6, 0.0, 1.0, 3.4, 1.9],
	twin = [0.85, 0.88, -5.6, 2.45, 1.2, 4.65, 1.8], fighter = [0.55, 0.42, -4.9, -1.0, 0.0, 0.0, 0.0]}
const WING_B := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)) # slab polygon (x, z), thickness on y
const FIN_B := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)) # slab polygon (z, y), thickness on x

static var _mats := {}


static func variant(kind: String) -> Dictionary:
	var v: Array = LINEUP[Worlds.index].get(kind, [])
	var t: Dictionary = TYPES.get(kind, TYPES.cub)
	return {name = v[0], desc = v[1]} if v else {name = t.name, desc = t.desc}


# Builds the current world's model under `root`. Returns {props: [Node3D], ltip, rtip: Node3D, anchors: [Vector3 x4], wing}.
static func build(kind: String, root: Node3D, paint: Material, trim: Material, glass: Material, dark: Material, glow: Material) -> Dictionary:
	var parts := {props = [], ltip = null, rtip = null, anchors = [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, -3), Vector3(0, 0.5, 3)], panels = [], gear = []}
	if kind == "balloon": # practice target: striped envelope, basket
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
		for s: float in [-1.0, 1.0]:
			_box(root, Vector3(0.08, 3.0, 0.08), Vector3(0.9 * s, -1.0, 0), dark)
		parts.anchors = [Vector3(0, 4, 0), Vector3(0, 4, 0), Vector3(0, 4, 0), Vector3(0, -3, 0)]
		return parts
	var first := root.get_child_count() # the lobby preview may still hold the old model (queue_free)
	var wi := Worlds.index
	var st: Dictionary = STYLE[wi]
	var m := {paint = paint, trim = trim if wi == 0 else _toon(st.trim), accent = _toon(st.accent), strut = _toon(st.strut), glass = glass, dark = dark,
		glow = glow, world = wi, span = 1.35 if wi == 5 else 1.0, chord = 0.82 if wi == 5 else 1.0}
	m.neon = _neon((paint as ShaderMaterial).get_shader_parameter("albedo") if paint is ShaderMaterial else Color.WHITE) if wi == 4 else null
	m.cap = [m.trim, m.accent, m.trim, m.trim, m.neon, m.trim][wi]
	m.blade = m.accent if wi == 5 else dark
	match kind:
		"racer": _racer(root, parts, m)
		"twin": _twin(root, parts, m)
		"fighter": _fighter(root, parts, m)
		_: _cub(root, parts, m)
	_gear(root, parts.gear, st.gear, m)
	if wi == 5: # gas-bag pods riding on each outer wing
		for tip: MeshInstance3D in [parts.ltip, parts.rtip]:
			var s := signf(tip.position.x)
			var w: Array = parts.wing
			var at := Vector3(s * (w[5] + 0.9) - tip.position.x, 0.75, w[3] + (w[5] + 0.9) * w[4] - tip.position.z)
			_ball(tip, 1.0, at, _toon(Color(0.93, 0.88, 0.74)), Vector3(0.42, 0.42, 1.25))
			for dz in [-0.55, 0.55]:
				_tube(tip, dz - 0.06, dz + 0.06, 0.39, 0.39, m.trim, at, Vector2.ONE, 10)
				_rod(tip, at + Vector3(0, -0.35, dz * 0.8), at + Vector3(0, -0.75, dz * 0.8), 0.04, m.trim)
	_merge(root, [parts.ltip, parts.rtip] + parts.panels, first)
	parts.erase("panels")
	parts.erase("gear")
	return parts


# High wing on a round cabin, struts, big two-blade prop.
static func _cub(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	_tube(root, -3.5, -2.75, 0.6, 0.74, m.trim, Vector3.ZERO, Vector2(0.9, 1.0), 10)
	_tube(root, -2.75, 0.8, 0.74, 0.64, m.paint, Vector3.ZERO, Vector2(0.88, 1.0))
	_tube(root, 0.8, 3.75, 0.64, 0.16, m.paint, Vector3.ZERO, Vector2(0.88, 1.0))
	_box(root, Vector3(0.9, 0.36, 1.8), Vector3(0, 0.68, -0.6), m.paint) # cabin roof up to the wing
	_box(root, Vector3(0.94, 0.26, 1.1), Vector3(0, 0.66, -0.75), m.glass) # side windows
	_ball(root, 1.0, Vector3(0, 0.56, -1.5), m.glass, Vector3(0.48, 0.4, 0.72))
	_wings(root, parts, 5.5 * m.span, 1.8 * m.chord, 0.95, -0.6, 0.0, 0.8, m)
	for s: float in [-1.0, 1.0]:
		for z in [-1.0, -0.25]:
			_rod(root, Vector3(0.5 * s, -0.2, z), Vector3(2.7 * s, 0.84, z), 0.05, m.strut)
	_stab(root, 1.8, 2.85, 0.9, 0.55, 0.2, 0.12, m.paint)
	_fin(root, [Vector2(2.45, 0.1), Vector2(3.75, 0.1), Vector2(3.85, 1.5), Vector2(3.6, 1.85), Vector2(3.05, 1.85), Vector2(2.9, 1.6)], 0.0, 1.62, m)
	_engine(root, parts, m, Vector3(0, 0, -3.6), 2, 3.0, 0.6)
	parts.gear = [[Vector3(1.05, -1.35, -1.4), Vector3(0.45, -0.45, -1.4), 1.0, 4.4], [Vector3(0, -0.36, 3.5), Vector3(0, -0.08, 3.35), 0.4, 0.0]]
	parts.anchors = [Vector3(-3.5 * m.span, 1, -0.6), Vector3(3.5 * m.span, 1, -0.6), Vector3(0, 0, -3.2), Vector3(0, 0.9, 3.2)]
	_strip(root, m, Vector3(0.61, -0.05, -2.6), Vector3(0.52, -0.05, 1.2))


# Slim racer: long nose, bubble canopy and spine, low elliptical wing, tall fin.
static func _racer(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	_tube(root, -4.75, -3.6, 0.3, 0.54, m.trim, Vector3.ZERO, Vector2(0.95, 1.0), 10)
	_tube(root, -3.6, 0.4, 0.54, 0.56, m.paint, Vector3.ZERO, Vector2(0.95, 1.0))
	_tube(root, 0.4, 4.2, 0.56, 0.14, m.paint, Vector3.ZERO, Vector2(0.95, 1.0))
	_ball(root, 1.0, Vector3(0, 0.42, 0.3), m.glass, Vector3(0.34, 0.36, 0.85))
	_tube(root, 0.9, 3.3, 0.3, 0.1, m.paint, Vector3(0, 0.3, 0))
	_wings(root, parts, 3.8 * m.span, 1.7 * m.chord, -0.3, -0.3, 6.0, 0.5, m)
	_stab(root, 1.6, 3.35, 0.85, 0.45, 0.3, 0.05, m.paint)
	_fin(root, [Vector2(2.4, 0.1), Vector2(4.15, 0.1), Vector2(4.15, 1.7), Vector2(3.85, 2.05), Vector2(3.3, 2.05), Vector2(3.0, 1.9)], 0.0, 1.85, m)
	_engine(root, parts, m, Vector3(0, 0, -4.85), 3, 2.4, 0.3)
	parts.gear = [[Vector3(1.45, -1.25, -0.75), Vector3(1.3, -0.42, -0.6), 0.85, 4.0], [Vector3(0, -0.36, 3.9), Vector3(0, -0.08, 3.75), 0.35, 0.0]]
	parts.anchors = [Vector3(-3 * m.span, -0.3, 0), Vector3(3 * m.span, -0.3, 0), Vector3(0, 0, -4.4), Vector3(0, 1, 3.4)]
	_strip(root, m, Vector3(0.5, 0.0, -3.4), Vector3(0.5, 0.0, 0.6))


# Bomber: glazed nose, two engine nacelles, twin tail.
static func _twin(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	_ball(root, 0.86, Vector3(0, 0, -4.95), m.glass, Vector3(1.0, 1.02, 1.05))
	_tube(root, -5.0, 1.8, 0.92, 0.92, m.paint, Vector3.ZERO, Vector2(1.0, 1.05))
	_tube(root, 1.8, 5.3, 0.92, 0.3, m.paint, Vector3.ZERO, Vector2(1.0, 1.05))
	_ball(root, 1.0, Vector3(0, 0.82, -3.5), m.glass, Vector3(0.62, 0.42, 1.0))
	_wings(root, parts, 7.5 * m.span, 2.3 * m.chord, 0.1, -0.5, 0.0, 0.6, m)
	for s: float in [-1.0, 1.0]:
		_tube(root, -3.25, -2.3, 0.5, 0.6, m.trim, Vector3(3.4 * s, 0, 0), Vector2.ONE, 10)
		_tube(root, -2.3, 1.3, 0.6, 0.2, m.paint, Vector3(3.4 * s, 0, 0))
		_engine(root, parts, m, Vector3(3.4 * s, 0, -3.35), 3, 2.6, 0.5)
		_fin(root, [Vector2(3.95, -0.25), Vector2(5.2, -0.25), Vector2(5.45, 0.6), Vector2(5.4, 1.95), Vector2(4.95, 2.25), Vector2(4.3, 2.1), Vector2(3.95, 0.8)], 2.45 * s, 1.9, m)
	_stab(root, 2.5, 3.95, 1.25, 1.05, 0.15, 0.45, m.paint)
	parts.gear = [[Vector3(3.4, -1.45, -0.9), Vector3(3.4, -0.45, -0.9), 1.25, 5.0], [Vector3(0, -0.6, 4.6), Vector3(0, -0.3, 4.45), 0.45, 0.0]]
	parts.anchors = [Vector3(-5.5 * m.span, 0.1, -0.5), Vector3(5.5 * m.span, 0.1, -0.5), Vector3(-3.4, 0.3, -1.6), Vector3(0, 1.2, 4.6)]
	_strip(root, m, Vector3(0.88, 0.3, -4.8), Vector3(0.88, 0.3, 1.8))


# Jet: radome, side intakes, swept wing, canted twin fins, glowing nozzle.
static func _fighter(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	_tube(root, -5.6, -3.3, 0.04, 0.5, m.trim, Vector3.ZERO, Vector2(1.1, 0.95))
	_tube(root, -3.3, 3.4, 0.5, 0.48, m.paint, Vector3.ZERO, Vector2(1.1, 0.95))
	_tube(root, 3.4, 4.3, 0.48, 0.4, m.dark, Vector3.ZERO, Vector2(1.1, 0.95), 10)
	_tube(root, 4.24, 4.32, 0.34, 0.34, m.glow, Vector3.ZERO, Vector2(1.1, 0.95), 10)
	_ball(root, 1.0, Vector3(0, 0.42, -2.3), m.glass, Vector3(0.34, 0.36, 1.05))
	for s: float in [-1.0, 1.0]:
		_tube(root, -1.6, 1.4, 0.3, 0.28, m.paint, Vector3(0.62 * s, 0.02, 0))
		_tube(root, -1.64, -1.56, 0.25, 0.25, m.dark, Vector3(0.62 * s, 0.02, 0))
		_fin(root, [Vector2(2.3, 0.2), Vector2(4.2, 0.2), Vector2(4.25, 0.5), Vector2(4.0, 1.85), Vector2(3.55, 1.85)], 0.5 * s, 1.62, m, -16.0 * s)
	_wings(root, parts, 4.2 * m.span, 3.2 * m.chord, -0.1, 0.7, 38.0, 0.3, m)
	_stab(root, 2.0, 3.3, 1.3, 0.5, 0.8, -0.05, m.paint)
	parts.gear = [[Vector3(0, -0.95, -3.4), Vector3(0, -0.4, -3.4), 0.6, 0.0], [Vector3(0.6, -0.95, -0.4), Vector3(0.5, -0.3, -0.4), 0.75, -1.0]]
	parts.anchors = [Vector3(-3 * m.span, 0, 1.8), Vector3(3 * m.span, 0, 1.8), Vector3(0, 0, 4.0), Vector3(0, 1.2, 3.3)]
	_strip(root, m, Vector3(0.62, 0.34, -1.5), Vector3(0.62, 0.32, 1.3))


# Tapered wings: inner panel + outer tip (the tip breaks off when the wing component dies). The chord
# centre line runs at z + |x| * tan(sweep): dress() hangs weapons and stickers off parts.wing.
static func _wings(root: Node3D, parts: Dictionary, half_span: float, chord: float, y: float, z: float, sweep: float, taper: float, m: Dictionary) -> void:
	var k := tan(deg_to_rad(sweep))
	var split := half_span * 0.55
	parts.wing = [half_span, chord, y, z, k, split]
	var cz := func(x: float) -> float: return z + x * k
	var cc := func(x: float) -> float: return chord * (1.0 - (1.0 - taper) * x / half_span)
	for s: float in [-1.0, 1.0]:
		for tip in [false, true]:
			var x0 := split if tip else 0.3
			var x1 := half_span if tip else split
			var poly := PackedVector2Array([Vector2(x0, cz.call(x0) - cc.call(x0) / 2.0), Vector2(x1, cz.call(x1) - cc.call(x1) / 2.0)])
			if tip: # rounded tip
				var c: float = cc.call(x1)
				for a in [-50.0, 0.0, 50.0]:
					poly.append(Vector2(x1 + cos(deg_to_rad(a)) * minf(0.5, c * 0.4), cz.call(x1) + sin(deg_to_rad(a)) * c / 2.0))
			poly.append(Vector2(x1, cz.call(x1) + cc.call(x1) / 2.0))
			poly.append(Vector2(x0, cz.call(x0) + cc.call(x0) / 2.0))
			var mid := (x0 + x1) / 2.0
			var at := Vector3(mid * s, y, cz.call(mid))
			var local := PackedVector2Array()
			for p in poly:
				local.append(Vector2(p.x * s - at.x, p.y - at.z))
			var panel := _slab(root, local, 0.2 if tip else 0.22, m.paint, Transform3D(WING_B, at))
			if tip:
				parts["ltip" if s < 0 else "rtip"] = panel
				var cap_x := (half_span - minf(0.9, half_span * 0.15)) * s - at.x
				var band := PackedVector2Array([Vector2(cap_x, -9), Vector2(cap_x + 9 * s, -9), Vector2(cap_x + 9 * s, 9), Vector2(cap_x, 9)])
				if m.world == 3: # desert camo: tan stripes across the outer wing
					for b in 2:
						var bx := (split + (half_span - split) * (0.2 + b * 0.4)) * s - at.x
						band = PackedVector2Array([Vector2(bx - 0.4, -9), Vector2(bx + 0.4, -9), Vector2(bx + 1.2, 9), Vector2(bx + 0.4, 9)])
						for piece in Geometry2D.intersect_polygons(local, band):
							_slab(panel, piece, 0.03, m.accent, Transform3D(WING_B, Vector3(0, 0.11, 0)))
				elif m.cap:
					for piece in Geometry2D.intersect_polygons(local, band):
						_slab(panel, piece, 0.24, m.cap, Transform3D(WING_B, Vector3.ZERO))
			else:
				parts.panels.append(panel)
			if m.neon: # glowing leading edge
				var a := Vector3(x0 * s, y, cz.call(x0) - cc.call(x0) / 2.0)
				var b := Vector3(x1 * s, y, cz.call(x1) - cc.call(x1) / 2.0)
				_rod(panel, a - at, b - at, 0.07, m.neon)


# Horizontal tail: one slab across, leading edge swept back by `sw` at the tips.
static func _stab(root: Node3D, half: float, z0: float, rc: float, tc: float, sw: float, y: float, mat: Material) -> void:
	_slab(root, PackedVector2Array([Vector2(0, z0), Vector2(half, z0 + sw), Vector2(half + 0.15, z0 + sw + tc * 0.5), Vector2(half, z0 + sw + tc),
		Vector2(0, z0 + rc), Vector2(-half, z0 + sw + tc), Vector2(-half - 0.15, z0 + sw + tc * 0.5), Vector2(-half, z0 + sw)]), 0.13, mat, Transform3D(WING_B, Vector3(0, y, 0)))


# Vertical fin from a (z, y) outline, its top above cap_y in the world's trim colour.
static func _fin(root: Node3D, pts: Array, x: float, cap_y: float, m: Dictionary, roll := 0.0) -> void:
	var poly := PackedVector2Array(pts)
	var xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(roll)) * FIN_B, Vector3(x, 0, 0))
	_slab(root, poly, 0.15, m.paint, xf)
	for piece in Geometry2D.intersect_polygons(poly, PackedVector2Array([Vector2(-9, cap_y), Vector2(9, cap_y), Vector2(9, 9), Vector2(-9, 9)])):
		_slab(root, piece, 0.17, m.cap if m.cap else m.trim, xf)


# Propeller with spinner; Metro ducts it in a glowing ring.
static func _engine(root: Node3D, parts: Dictionary, m: Dictionary, at: Vector3, blades: int, length: float, hub_r: float) -> void:
	if m.neon:
		length *= 0.8
		var ring := MeshInstance3D.new()
		ring.mesh = TorusMesh.new()
		ring.mesh.inner_radius = length / 2.0 + 0.08
		ring.mesh.outer_radius = length / 2.0 + 0.3
		ring.mesh.rings = 16
		ring.mesh.ring_segments = 6
		ring.material_override = m.trim
		ring.rotation_degrees.x = 90
		ring.position = at + Vector3(0, 0, 0.15)
		root.add_child(ring)
		var lip := ring.duplicate() as MeshInstance3D
		lip.mesh = TorusMesh.new()
		lip.mesh.inner_radius = length / 2.0 + 0.24
		lip.mesh.outer_radius = length / 2.0 + 0.36
		lip.mesh.rings = 16
		lip.mesh.ring_segments = 4
		lip.material_override = m.neon
		lip.position.z -= 0.08
		root.add_child(lip)
		for s: float in [-1.0, 1.0]:
			_rod(root, at + Vector3(s * hub_r * 0.8, 0, 0.15), at + Vector3(s * (length / 2.0 + 0.1), 0, 0.15), 0.06, m.trim)
	elif m.world == 5: # brass exhaust stacks
		for s: float in [-1.0, 1.0]:
			_rod(root, at + Vector3(s * hub_r * 1.05, 0.15, 0.4), at + Vector3(s * hub_r * 1.05, 0.15, 1.5), 0.06, m.trim)
	var hub := Node3D.new()
	hub.position = at
	root.add_child(hub)
	var blade := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.11, 0.25), Vector2(0.13, length * 0.38), Vector2(0.04, length * 0.5), Vector2(-0.06, length * 0.46), Vector2(-0.1, 0.25)])
	for i in blades:
		_slab(hub, blade, 0.06, m.blade, Transform3D(Basis(Vector3.BACK, TAU * i / blades), Vector3.ZERO))
	_tube(hub, -0.45, 0.1, 0.03, hub_r * 0.55, m.trim if not m.neon else m.neon, Vector3.ZERO, Vector2.ONE, 10)
	_merge(hub, [])
	parts.props.append(hub)


# Side strip along the fuselage: a lava stripe on Volcano, neon tubes on Metro.
static func _strip(root: Node3D, m: Dictionary, a: Vector3, b: Vector3) -> void:
	var mat: Material = m.neon if m.neon else (m.accent if m.world == 1 else null)
	if mat:
		for s: float in [-1.0, 1.0]:
			_rod(root, Vector3(a.x * s, a.y, a.z), Vector3(b.x * s, b.y, b.z), 0.06, mat)


# Gear entries: [contact centre, attach point, size, float length]. x > 0 entries are mirrored.
# Float length 0 = tail/nose wheel (no float), < 0 = hydro-ski instead of a float.
static func _gear(root: Node3D, gear: Array, kind: String, m: Dictionary) -> void:
	if kind == "none":
		return
	for g: Array in gear:
		var c: Vector3 = g[0]
		var top: Vector3 = g[1]
		var sz: float = g[2]
		for s: float in ([1.0] if c.x == 0.0 else [-1.0, 1.0]):
			var p := Vector3(c.x * s, c.y, c.z)
			var t := Vector3(top.x * s, top.y, top.z)
			if kind == "floats" and g[3] == 0.0:
				continue
			if kind == "floats" and g[3] > 0.0:
				var len: float = g[3]
				var fc := p + Vector3(0, 0, len * 0.08)
				_ball(root, 1.0, fc, m.accent, Vector3(0.3 * sz, 0.28 * sz, len / 2.0))
				_tube(root, fc.z - len * 0.2, fc.z + len * 0.2, 0.31 * sz, 0.31 * sz, m.trim, Vector3(fc.x, fc.y, 0), Vector2(1.0, 0.92), 10)
				for dz in [-0.6, 0.7]:
					_rod(root, t + Vector3(0, 0, dz), Vector3(p.x, p.y + 0.2 * sz, p.z + dz), 0.05, m.strut)
				continue
			var r := 0.38 * sz
			if kind == "skis" or kind == "floats":
				_rod(root, t, p, 0.05 * sz + 0.02, m.strut)
				var ski := PackedVector2Array([Vector2(-0.16, -0.9), Vector2(0.16, -0.9), Vector2(0.16, 0.8), Vector2(-0.16, 0.8)])
				for i in ski.size():
					ski[i] *= sz
				_slab(root, ski, 0.08, m.trim if kind == "skis" else m.accent, Transform3D(WING_B, p - Vector3(0, r * 0.6, 0)))
				_slab(root, PackedVector2Array([Vector2(-0.16 * sz, -0.35 * sz), Vector2(0.16 * sz, -0.35 * sz), Vector2(0.16 * sz, 0), Vector2(-0.16 * sz, 0)]), 0.08,
					m.trim if kind == "skis" else m.accent, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35)) * WING_B, p + Vector3(0, -r * 0.6, -0.9 * sz)))
				continue
			if kind == "tyres":
				r = 0.58 * sz
			_rod(root, t, p, 0.05 * sz + 0.02, m.strut)
			var tyre := _cyl(root, r, r, (0.44 if kind == "tyres" else 0.24) * sz, m.dark)
			tyre.mesh.radial_segments = 12
			tyre.rotation_degrees.z = 90
			tyre.position = p
			var hub := _cyl(root, r * 0.45, r * 0.45, (0.48 if kind == "tyres" else 0.28) * sz, m.trim)
			hub.rotation_degrees.z = 90
			hub.position = p
			if kind == "spats":
				_ball(root, 1.0, p + Vector3(0, 0.1 * sz, 0), m.trim, Vector3(0.17, 0.42, 0.62) * sz)


static func _toon(c: Color) -> Material:
	if not _mats.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_mats[c] = mat
	return _mats[c]


static func _neon(c: Color) -> Material:
	var key := "neon%s" % c
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(c.r * 1.6 + 0.35, c.g * 1.6 + 0.35, c.b * 1.6 + 0.35)
		_mats[key] = mat
	return _mats[key]


# Bakes the static parts into one mesh per material (about 20 planes fly at once); `keep` stay separate.
# Not SurfaceTool.append_from: it skews the normals of the squashed spheres.
static func _merge(root: Node3D, keep: Array, first := 0) -> void:
	var groups := {}
	for c in root.get_children().slice(first):
		if not c is MeshInstance3D or c in keep:
			continue
		var g: Array = groups.get_or_add(c.material_override, [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()])
		var arr: Array = c.mesh.surface_get_arrays(0)
		var xf: Transform3D = c.transform
		var nb := xf.basis.inverse().transposed()
		var base: int = g[0].size()
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
			g[0].append(xf * v)
		for n: Vector3 in arr[Mesh.ARRAY_NORMAL]:
			g[1].append((nb * n).normalized())
		for i: int in arr[Mesh.ARRAY_INDEX]:
			g[2].append(base + i)
		root.remove_child(c)
		c.free()
	for mat in groups:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = groups[mat][0]
		arr[Mesh.ARRAY_NORMAL] = groups[mat][1]
		arr[Mesh.ARRAY_INDEX] = groups[mat][2]
		var mi := MeshInstance3D.new()
		mi.mesh = ArrayMesh.new()
		mi.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi.material_override = mat
		root.add_child(mi)


# Round body along Z from z0 (radius r0) to z1 (r1); flat faces on the sides, top and bottom.
static func _tube(parent: Node3D, z0: float, z1: float, r0: float, r1: float, mat: Material, at := Vector3.ZERO, sq := Vector2.ONE, seg := 8) -> MeshInstance3D:
	var m := _cyl(parent, r1, r0, z1 - z0, mat)
	m.mesh.radial_segments = seg
	m.transform = Transform3D(Basis.from_scale(Vector3(sq.x, sq.y, 1.0)) * Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, PI / seg), at + Vector3(0, 0, (z0 + z1) / 2.0))
	return m


static func _ball(parent: Node3D, r: float, at: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = SphereMesh.new()
	m.mesh.radius = r
	m.mesh.height = r * 2.0
	m.mesh.radial_segments = 12
	m.mesh.rings = 6
	m.position = at
	m.scale = sc
	m.material_override = mat
	parent.add_child(m)
	return m


static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := _cyl(parent, r, r, a.distance_to(b), mat)
	m.mesh.radial_segments = 6
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	m.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) / 2.0)
	return m


# Flat polygon extruded `th` thick (local XY outline, thickness on Z), rotated by xf.basis (baked in, so
# children of the slab use plain world-axis offsets) and placed at xf.origin.
static func _slab(parent: Node3D, poly: PackedVector2Array, th: float, mat: Material, xf: Transform3D) -> MeshInstance3D:
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := th / 2.0
	var bs := xf.basis
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var a := poly[idx[i]]
		var b := poly[idx[i + 1]]
		var c := poly[idx[i + 2]]
		_tri(st, bs, Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(c.x, c.y, h), Vector3.BACK)
		_tri(st, bs, Vector3(a.x, a.y, -h), Vector3(b.x, b.y, -h), Vector3(c.x, c.y, -h), Vector3.FORWARD)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var out := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		_tri(st, bs, Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), out)
		_tri(st, bs, Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h), out)
	st.index()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.position = xf.origin
	m.material_override = mat
	parent.add_child(m)
	return m


static func _tri(st: SurfaceTool, bs: Basis, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0: # Godot's front faces wind clockwise
		var t := b
		b = c
		c = t
	st.set_normal(bs * out)
	for v in [a, b, c]:
		st.add_vertex(bs * v)


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
	parts.trails = []
	if banner > 0: # airshow smoke ribbons from both wingtips: true colour, thin, fading out behind
		var puff := SphereMesh.new()
		puff.radius = 0.6
		puff.height = 1.2
		puff.radial_segments = 6
		puff.rings = 3
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material = mat
		var col: Color = BANNER_COLORS[banner]
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(col, 0.85), Color(col.lightened(0.15), 0.0)])
		var swell := Curve.new()
		swell.add_point(Vector2(0, 0.7))
		swell.add_point(Vector2(1, 2.4))
		for side in [-1.0, 1.0]:
			var smoke := CPUParticles3D.new()
			smoke.mesh = puff
			smoke.amount = 130 # dense enough to read as a ribbon at full speed
			smoke.lifetime = 1.0
			smoke.local_coords = false
			smoke.direction = Vector3(0, 0, 1)
			smoke.spread = 3.0
			smoke.initial_velocity_min = 1.0
			smoke.initial_velocity_max = 2.0
			smoke.gravity = Vector3.ZERO
			smoke.color_ramp = ramp
			smoke.scale_amount_curve = swell
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			smoke.position = Vector3(side * (w[0] - 0.2), w[2], w[3] + w[0] * w[4] + w[1] * 0.3)
			root.add_child(smoke)
			parts.trails.append(smoke)


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
