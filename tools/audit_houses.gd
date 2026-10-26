extends SceneTree
# Z-fighting in the village houses: triangles of different colour that face the same way, lie in the
# same plane (within EPS) and overlap.   godot --headless --path . -s tools/audit_houses.gd
const EPS := 0.02 # model units (houses are scaled x13 in the world)
const HOUSES := [["building-type-a", "variation-b"], ["building-type-c", "colormap"], ["building-type-e", "variation-b"],
	["building-type-h", "variation-a"], ["building-type-j", "variation-b"], ["building-type-m", "colormap"],
	["building-type-o", "variation-a"], ["building-type-s", "variation-b"]]


static func _overlap(p: Array, q: Array) -> bool:
	for tri in [p, q]:
		for i in 3:
			var e: Vector2 = tri[(i + 1) % 3] - tri[i]
			var ax := Vector2(-e.y, e.x)
			var pa := [INF, -INF]
			var qa := [INF, -INF]
			for v in p:
				pa = [minf(pa[0], ax.dot(v)), maxf(pa[1], ax.dot(v))]
			for v in q:
				qa = [minf(qa[0], ax.dot(v)), maxf(qa[1], ax.dot(v))]
			if pa[1] <= qa[0] + 1e-5 or qa[1] <= pa[0] + 1e-5:
				return false
	return true


func _initialize() -> void:
	var total := 0
	for h in HOUSES:
		var m: ArrayMesh = Props.model(Props.SUB + h[0] + ".glb", Props.SUB + "Textures/" + h[1] + ".png")
		var a := m.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var idx = a[Mesh.ARRAY_INDEX]
		var ids: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
		var tris := []
		for i in range(0, ids.size() - 2, 3):
			var n := (v[ids[i + 1]] - v[ids[i]]).cross(v[ids[i + 2]] - v[ids[i]])
			if n.length() > 1e-9:
				tris.append([v[ids[i]], v[ids[i + 1]], v[ids[i + 2]], n.normalized(), c[ids[i]]])
		var hits := 0
		var example := ""
		for i in tris.size():
			for j in range(i + 1, tris.size()):
				var t: Array = tris[i]
				var u: Array = tris[j]
				if (t[4] as Color).is_equal_approx(u[4]) or t[3].dot(u[3]) < 0.995 or absf(t[3].dot(u[0] - t[0])) > EPS:
					continue
				var ax: Vector3 = t[3].cross(Vector3.UP if absf(t[3].y) < 0.9 else Vector3.RIGHT).normalized()
				var ay: Vector3 = t[3].cross(ax)
				if _overlap([Vector2(ax.dot(t[0]), ay.dot(t[0])), Vector2(ax.dot(t[1]), ay.dot(t[1])), Vector2(ax.dot(t[2]), ay.dot(t[2]))],
						[Vector2(ax.dot(u[0]), ay.dot(u[0])), Vector2(ax.dot(u[1]), ay.dot(u[1])), Vector2(ax.dot(u[2]), ay.dot(u[2]))]):
					hits += 1
					if example == "":
						example = "normal %s at %s" % [t[3].snapped(Vector3.ONE * 0.01), t[0].snapped(Vector3.ONE * 0.01)]
		total += hits
		print("%-18s tris %4d  overlapping pairs %3d  %s" % [h[0], tris.size(), hits, example])
	print("TOTAL ", total)
	quit()
