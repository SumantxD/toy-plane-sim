extends SceneTree
# Counts placement bugs per world: props inside HQs / flags / turret pads, scatter through solid
# buildings, floating or buried small props. godot --headless --path . -s tools/audit_overlap.gd


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	for w in Worlds.LIST.size():
		main._build_world_content(w)
		await process_frame
		var reserved := [] # [centre, radius, label]
		for h in main.objectives.hqs:
			reserved.append([h.position, 30.0, "HQ"])
		for t in 2:
			reserved.append([main.objectives.flag_base(t), 14.0, "flag"])
		for l in Battlefield.base_spots():
			var p: Vector2 = l[0]
			reserved.append([Vector3(p.x, Terrain.floor_below(Vector3(p.x, 3000, p.y)), p.y), 9.0, "turret pad"])
		var counts := {}
		var examples := {}
		var note := func(kind: String, what: String, at: Vector3) -> void:
			counts[kind] = counts.get(kind, 0) + 1
			if not examples.has(kind):
				examples[kind] = "%s at %s" % [what, Vector3i(at)]
		Props._layout() # deterministic: same placements the world was just built from
		Props._scatter()
		for mesh: Mesh in Props._batches:
			var list: Array = Props._batches[mesh]
			var box := mesh.get_aabb()
			var what := mesh.resource_path.get_file() if mesh.resource_path else (mesh.resource_name if mesh.resource_name else mesh.get_class())
			for i in range(0, list.size(), 2):
				var t: Transform3D = list[i]
				var a := t * box
				var c := a.get_center()
				var ground := Terrain.floor_below(Vector3(c.x, a.end.y + 1.0, c.z))
				var small := a.size.x < 25.0 and a.size.z < 25.0
				for r in reserved:
					if Vector2(c.x - r[0].x, c.z - r[0].z).length() < r[1] + minf(a.size.x, a.size.z) * 0.3 and absf(c.y - r[0].y) < 40.0:
						note.call("inside " + r[2], what, c)
				# Free-standing models only (building parts are primitives stacked on purpose).
				if small and a.size.y < 40.0 and mesh is ArrayMesh:
					var base_ground := Terrain.floor_below(Vector3(t.origin.x, a.end.y + 1.0, t.origin.z))
					if t.origin.y > base_ground + 2.5:
						note.call("floating %s" % what, "dy %.1f" % (t.origin.y - base_ground), t.origin)
					elif a.end.y < base_ground - 0.5:
						note.call("buried %s" % what, "dy %.1f" % (a.end.y - base_ground), t.origin)
				var plant := what.contains("tree") or what.contains("palm") or what.contains("cact") or what.contains("pine") or what.contains("plant")
				if plant and main.hits_obstacle(Vector3(c.x, a.position.y + a.size.y * 0.6, c.z)) and not main.hits_obstacle(Vector3(c.x, a.end.y + 3.0, c.z)):
					note.call("scatter through a solid", what, c)
		Props._batches = {}
		# Solid props intersecting other solids (two buildings through each other). Boxes from one
		# prop touch on purpose (fort wall segments), so only count real interpenetration.
		var obs: Array = main.obstacles
		var shown := 0
		for x in obs.size():
			var A: AABB = obs[x]
			for y in range(x + 1, obs.size()):
				var B: AABB = obs[y]
				if not A.intersects(B):
					continue
				var I := A.intersection(B)
				var small := minf(A.get_volume(), B.get_volume())
				if small > 50.0 and I.get_volume() > 0.25 * small and not (A.encloses(B) or B.encloses(A)):
					note.call("solids interpenetrating", "", I.get_center())
					if shown < 4:
						shown += 1
						print("   overlap at %s: %s vs %s" % [Vector3i(I.get_center()), Vector3i(A.size), Vector3i(B.size)])
		print("== %s: %s" % [Worlds.LIST[w], counts])
		for k in examples:
			print("   e.g. %s: %s" % [k, examples[k]])
	quit()
