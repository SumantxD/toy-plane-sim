extends SceneTree
# Finds z-fighting on the planes: faces of DIFFERENT materials that face the same way, lie within
# EPS of the same plane and overlap. Every kind x world, with each livery and each sticker.
#   godot --headless --path . -s tools/audit_zfight.gd   (add -- --verbose for every pair)
const EPS := 0.02


func _tris(root: Node3D) -> Array: # [a, b, c, normal, material id]
	var out := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.mesh:
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat = mi.material_override if mi.material_override else mi.mesh.surface_get_material(s)
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var ids: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			for i in range(0, ids.size() - 2, 3):
				var a: Vector3 = xf * v[ids[i]]
				var b: Vector3 = xf * v[ids[i + 1]]
				var c: Vector3 = xf * v[ids[i + 2]]
				var n := (b - a).cross(c - a)
				if n.length() < 1e-6:
					continue
				out.append([a, b, c, n.normalized(), mat.get_instance_id() if mat else 0, mi.name])
	return out


static func _overlap2d(p: Array, q: Array) -> bool: # separating axis test on two 2D triangles
	for tri in [p, q]:
		for i in 3:
			var e: Vector2 = tri[(i + 1) % 3] - tri[i]
			var ax := Vector2(-e.y, e.x)
			var pmin := INF
			var pmax := -INF
			var qmin := INF
			var qmax := -INF
			for v in p:
				pmin = minf(pmin, ax.dot(v))
				pmax = maxf(pmax, ax.dot(v))
			for v in q:
				qmin = minf(qmin, ax.dot(v))
				qmax = maxf(qmax, ax.dot(v))
			if pmax <= qmin + 1e-4 or qmax <= pmin + 1e-4:
				return false
	return true


func _scan(root: Node3D) -> Array:
	var tris := _tris(root)
	var buckets := {} # same facing and plane offset (in EPS steps) -> triangle indices
	for i in tris.size():
		var n: Vector3 = tris[i][3]
		var key := "%d,%d,%d,%d" % [roundi(n.x * 50), roundi(n.y * 50), roundi(n.z * 50), floori(n.dot(tris[i][0]) / EPS)]
		buckets.get_or_add(key, []).append(i)
	var hits := []
	for i in tris.size():
		var t: Array = tris[i]
		var n: Vector3 = t[3]
		var d := floori(n.dot(t[0]) / EPS)
		for dd in [d - 1, d, d + 1]:
			for j in buckets.get("%d,%d,%d,%d" % [roundi(n.x * 50), roundi(n.y * 50), roundi(n.z * 50), dd], []):
				if j <= i:
					continue
				var u: Array = tris[j]
				if t[4] == u[4] or n.dot(u[3]) < 0.995 or absf(n.dot(u[0] - t[0])) > EPS:
					continue
				var ax := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
				var ay := n.cross(ax)
				var p := [Vector2(ax.dot(t[0]), ay.dot(t[0])), Vector2(ax.dot(t[1]), ay.dot(t[1])), Vector2(ax.dot(t[2]), ay.dot(t[2]))]
				var q := [Vector2(ax.dot(u[0]), ay.dot(u[0])), Vector2(ax.dot(u[1]), ay.dot(u[1])), Vector2(ax.dot(u[2]), ay.dot(u[2]))]
				if _overlap2d(p, q):
					hits.append("%s / %s at %s (gap %.3f)" % [t[5], u[5], Vector3i((t[0] + u[0]) * 5.0) / 5.0, absf(n.dot(u[0] - t[0]))])
	return hits


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	var total := 0
	for w in Worlds.LIST.size():
		Worlds.index = w
		for kind in Planes.TYPES.keys():
			var looks := []
			for l in Planes.LIVERIES.size():
				looks.append([l, 0])
			for s in range(1, Planes.STICKERS.size()):
				looks.append([0, s])
			for look in looks:
				var n := Node3D.new()
				root.add_child(n)
				var t: Dictionary = Planes.TYPES[kind]
				var parts := Planes.build(kind, n, main.toon(Color(0.3, 0.55, 1.0)), main.toon(Color(0.95, 0.93, 0.85)), main.toon(Color(0.15, 0.2, 0.3)), main.toon(Color(0.2, 0.2, 0.22)), StandardMaterial3D.new(), look[0])
				Planes.dress(kind, n, parts, t.rockets, t.bombs, look[1], 0, main.toon(Color(0.2, 0.2, 0.22)), Callable(main, "toon"))
				var hits := _scan(n)
				if hits.size() > 0:
					total += hits.size()
					print("%-14s %-7s livery %d sticker %d: %d overlapping face pairs  e.g. %s" % [Worlds.LIST[w], kind, look[0], look[1], hits.size(), hits[0]])
					if verbose:
						for h in hits:
							print("    ", h)
				n.free()
	print("TOTAL overlapping face pairs: ", total)
	quit()
