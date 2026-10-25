extends SceneTree
# Toy-World icon: a Golden Ace cub banking past a tiny floating Volcanic Islands volcano, both from the game's real
# geometry (Planes.build/dress, worlds/volcano.gd shape()/color()/flows, the volcano world's palm GLBs).
# godot --path . --resolution 1024x1024 -s aso/tools/icon_toyworld.gd -- [key=value ...]   (see args below)
# Size strip: sips the PNG to DIR/<out>_{180,120,87,60}.png, then run again with -- out=<out> dir=DIR strip=OUT.png
# Out: aso/creative/icons/v3/<out>.png (1024 RGB, square, no alpha), raw render in v3/src/.

const OUT := "res://aso/creative/icons/v3/"
const S := 1024
const INK := Color(0.08, 0.06, 0.12)
const V := preload("res://worlds/volcano.gd")
const ISLE_K := 0.0095 # world metres -> icon-scene metres for the volcano (a 1.5 km island becomes a 14 m toy)

var _cache := {}
# Defaults = the shipped toyworld.png (iteration 9a); any key can be overridden on the command line as key=value.
var args := {bg = "teal", out = "toyworld", body = "red", livery = "1", palm = "300", palms = "6", ix = "5.5", iy = "-8", iz = "-6",
	px = "-1.5", py = "3.5", pz = "8", roll = "-30", dx = "-1.0", dy = "0.05", dz = "0.6", frac = "0.96", isk = "0.0072", exag = "1.85", fy = "0.52"}


func toon(c: Color) -> ShaderMaterial: # same as main.toon()
	if not _cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_cache[c] = mat
	return _cache[c]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "src"))
	if args.has("strip"):
		_strip.call_deferred()
	else:
		_run.call_deferred()


# Size check: strip=OUT.png dir=DIR (holding <out>_<px>.png made by sips). Rows: iOS light grey, dark; each cell masked to
# a rounded square (22.37% radius, a close stand-in for Apple's squircle), then the 60 px cell again at 3x nearest.
func _strip() -> void:
	var sizes := [180, 120, 87, 60]
	var pad := 24
	var w := pad
	for z in sizes:
		w += z + pad
	w += 180 + pad
	var sheet := Image.create(w, 2 * (180 + 2 * pad), false, Image.FORMAT_RGBA8)
	for row in 2:
		var bgc := Color(0.95, 0.95, 0.97) if row == 0 else Color(0.0, 0.0, 0.0)
		sheet.fill_rect(Rect2i(0, row * (180 + 2 * pad), w, 180 + 2 * pad), bgc)
		var x := pad
		for z in sizes + [-60]:
			var img := Image.load_from_file("%s/%s_%d.png" % [args.dir, args.out, absi(z)])
			img.convert(Image.FORMAT_RGBA8)
			if z < 0:
				img.resize(180, 180, Image.INTERPOLATE_NEAREST)
			var n := img.get_width()
			var rad := 0.2237 * n
			for yy in n:
				for xx in n:
					var q := Vector2(clampf(xx + 0.5, rad, n - rad), clampf(yy + 0.5, rad, n - rad))
					var cov := clampf(rad - Vector2(xx + 0.5, yy + 0.5).distance_to(q) + 0.5, 0.0, 1.0)
					var c := img.get_pixel(xx, yy)
					img.set_pixel(xx, yy, Color(c.r, c.g, c.b, cov))
			var y0 := row * (180 + 2 * pad) + pad + (180 - n) / 2
			sheet.blend_rect(img, Rect2i(0, 0, n, n), Vector2i(x, y0))
			x += n + pad
	sheet.convert(Image.FORMAT_RGB8)
	sheet.save_png(args.strip)
	print("wrote ", args.strip)
	quit()


# --- plane --------------------------------------------------------------------------------

func plane(color: Color, livery: int, sticker: int) -> Node3D:
	Worlds.index = 0
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var dark := toon(Color(0.2, 0.2, 0.22))
	var parts := Planes.build("cub", root, toon(color), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), dark, glow, livery)
	Planes.dress("cub", root, parts, 0, 0, sticker, 0, dark, toon)
	for p: Node3D in parts.props:
		p.rotation.z = deg_to_rad(20.0)
	_strip_gear(root, dark)
	return root


# Wheels, gear legs and wing struts ink into black debris at icon sizes: cut every triangle below the belly
# and the thin strut rods outboard of the fuselage (round-1 critique).
func _strip_gear(root: Node3D, dark: Material) -> void:
	for mi in root.get_children():
		if mi is MeshInstance3D and mi.mesh is BoxMesh and mi.mesh.size == Vector3(0.09, 0.09, 1.0): # Planes.dress gun barrels
			mi.free()
			continue
		if not (mi is MeshInstance3D and mi.mesh is ArrayMesh) or mi.mesh.get_surface_count() != 1:
			continue
		var a: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null or idx.is_empty():
			continue
		var strut: bool = mi.material_override == Planes._toon(Planes.STYLE[0].strut)
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var c: Vector3 = mi.transform * ((v[idx[i]] + v[idx[i + 1]] + v[idx[i + 2]]) / 3.0)
			var gear := c.y < -0.68 and c.z > -2.6
			var rod := strut and ((c.y > -0.3 and c.y < 1.0 and c.z < 0.5 and absf(c.x) > 0.7) or c.y < -0.4)
			if not (gear or rod):
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		if keep.size() == idx.size():
			continue
		a[Mesh.ARRAY_INDEX] = keep
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mi.mesh = m


func aim(p: Node3D, at: Vector3, dir: Vector3, roll_deg: float) -> void: # nose (-Z) along dir, then bank
	p.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, deg_to_rad(roll_deg)), at)


# --- floating volcano -----------------------------------------------------------------------
# Top: V.shape() sampled on a polar grid round the vent, coloured by V.color() (basalt, scorch, green foot),
# sitting on a grassy shelf with a sand lip. Underside: a Sky Kingdom style rock root in volcano cliff strata.
# Lava: the four V flows as unshaded strips + the crater pool. All in world metres, scaled by ISLE_K.

const SHELF := 30.0
const NA := 120
const NR := 44


func _rim(a: float) -> float:
	return (V.CONE_R + 70.0) * (1.0 + 0.06 * sin(a * 3.0 + 1.0) + 0.04 * sin(a * 5.0 + 2.0))


func _top_h(x: float, z: float) -> float: # cone stretched up EXAG x: toy proportions
	return SHELF + maxf(V.shape(x, z, V.SEA_BED) - SHELF, 0.0) * float(args.get("exag", "1.5"))


func island() -> Node3D:
	var root := Node3D.new()
	var lush := Color(0.3, 0.76, 0.33)
	var sand := Color(0.99, 0.89, 0.62)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := func(k: int, j: int) -> int: return 1 + k * NA + (j % NA)
	# top: centre + NR rings
	st.set_color(Color(0.4, 0.14, 0.08))
	st.add_vertex(Vector3(0, _top_h(V.VENT.x, V.VENT.y), 0))
	for k in NR:
		var f := float(k + 1) / NR
		for j in NA:
			var a := j * TAU / NA
			var r := _rim(a) * pow(f, 0.9)
			var x := V.VENT.x + cos(a) * r
			var z := V.VENT.y + sin(a) * r
			var h := _top_h(x, z)
			var c: Color = V.color(Vector3(x, maxf(V.shape(x, z, V.SEA_BED), SHELF), z), 1.0, lush) # game colours from the real height
			if h <= SHELF + 0.5:
				c = lush.lerp(Color(0.2, 0.66, 0.36), 0.5 + 0.5 * sin(a * 7.0 + r * 0.01))
			if f > 0.93:
				c = sand
			st.set_color(c)
			st.add_vertex(Vector3(cos(a) * r, h, sin(a) * r))
	for j in NA:
		st.add_index(0); st.add_index(ring.call(0, j)); st.add_index(ring.call(0, j + 1))
	for k in NR - 1:
		for j in NA:
			var a0: int = ring.call(k, j)
			var a1: int = ring.call(k, j + 1)
			var b0: int = ring.call(k + 1, j)
			var b1: int = ring.call(k + 1, j + 1)
			st.add_index(a0); st.add_index(b0); st.add_index(a1)
			st.add_index(a1); st.add_index(b0); st.add_index(b1)
	st.generate_normals()
	var top := MeshInstance3D.new()
	top.mesh = st.commit()
	top.material_override = Props.toon()
	root.add_child(top)
	# underside: rings from the rim inward and down to a point, banded like the volcano's cliffs
	var ub := SurfaceTool.new()
	ub.begin(Mesh.PRIMITIVE_TRIANGLES)
	const UR := 10
	const DEPTH := 620.0
	var strata := [Color(0.58, 0.38, 0.27), Color(0.45, 0.38, 0.34), Color(0.52, 0.34, 0.26), V.BASALT2]
	for k in UR:
		var f := float(k) / UR # 0 at the rim
		for j in NA:
			var a := j * TAU / NA
			var r := _rim(a) * (1.0 - pow(f, 1.6)) * (1.0 + 0.05 * sin(a * 9.0 + k))
			var y := SHELF - 40.0 - DEPTH * pow(f, 0.8) + 25.0 * sin(a * 4.0 + k * 1.3)
			ub.set_color(sand if k == 0 else strata[k % strata.size()])
			ub.add_vertex(Vector3(cos(a) * r, SHELF - 2.0 if k == 0 else y, sin(a) * r))
	ub.set_color(strata[0])
	ub.add_vertex(Vector3(0, SHELF - 40.0 - DEPTH * 1.05, 0))
	var tip := UR * NA
	for k in UR - 1:
		for j in NA:
			var a0 := k * NA + j
			var a1 := k * NA + (j + 1) % NA
			var b0 := (k + 1) * NA + j
			var b1 := (k + 1) * NA + (j + 1) % NA
			ub.add_index(a0); ub.add_index(b0); ub.add_index(a1)
			ub.add_index(a1); ub.add_index(b0); ub.add_index(b1)
	for j in NA:
		ub.add_index((UR - 1) * NA + j); ub.add_index(tip); ub.add_index((UR - 1) * NA + (j + 1) % NA)
	ub.generate_normals()
	var under := MeshInstance3D.new()
	under.mesh = ub.commit()
	under.material_override = Props.toon()
	root.add_child(under)
	# lava: crater pool + flows (V.nodes builds these with Terrain.height; same paths, our heights, wider for icon read)
	var lava := StandardMaterial3D.new()
	lava.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lava.albedo_color = Color(1.0, 0.45, 0.08)
	var pool := MeshInstance3D.new()
	pool.mesh = CylinderMesh.new()
	pool.mesh.top_radius = V.CRATER_R * 0.75
	pool.mesh.bottom_radius = V.CRATER_R * 0.55
	pool.mesh.height = 10.0
	pool.material_override = lava
	pool.position = Vector3(0, _top_h(V.VENT.x, V.VENT.y) + 22.0, 0)
	root.add_child(pool)
	var ls := SurfaceTool.new()
	ls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lv := 0
	for i in V.FLOWS.size():
		var d := V.CRATER_R - 10.0
		var n := 0
		while d < V.CONE_R * 0.97:
			var c: Vector2 = V._flow_at(i, d)
			var a: float = V._flow_angle(i, d)
			var side := Vector2(-sin(a), cos(a)) * lerpf(52.0, 30.0, d / V.CONE_R)
			for s in [-1.0, 1.0]:
				var q: Vector2 = c + side * s
				ls.add_vertex(Vector3(q.x - V.VENT.x, _top_h(q.x, q.y) + 6.0, q.y - V.VENT.y))
			lv += 2
			if n > 0:
				ls.add_index(lv - 4); ls.add_index(lv - 2); ls.add_index(lv - 3)
				ls.add_index(lv - 3); ls.add_index(lv - 2); ls.add_index(lv - 1)
			n += 1
			d += 20.0
	var lm := MeshInstance3D.new()
	lm.mesh = ls.commit()
	lm.material_override = lava
	root.add_child(lm)
	# puffs: the crater's ash plume (V.nodes) as three flat toon clouds leaning with the trade wind
	var crater := _top_h(V.VENT.x, V.VENT.y)
	for q in [[Vector3(10, 110, 0), 75.0], [Vector3(60, 230, -30), 100.0], [Vector3(140, 370, -60), 130.0]]:
		if args.get("puffs", "0") == "0":
			break
		var b := MeshInstance3D.new()
		b.mesh = SphereMesh.new()
		b.mesh.radius = q[1]
		b.mesh.height = q[1] * 1.7
		b.material_override = toon(Color(0.96, 0.94, 0.9))
		b.position = q[0] + Vector3(0, crater, 0)
		root.add_child(b)
	# palms on the shelf (the volcano world's own scatter.broad models + bark)
	var A := V.A
	var kinds := [[A + "tree_palm.glb", Color(0.2, 0.75, 0.45)], [A + "tree_palmBend.glb", Color(0.3, 0.8, 0.35)], [A + "tree_palmTall.glb", Color(0.16, 0.7, 0.5)],
		[A + "tree_palmShort.glb", Color(0.35, 0.82, 0.3)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var np := int(args.get("palms", "9"))
	for i in np:
		var a := 0.6 + i * TAU / np + rng.randf_range(-0.15, 0.15)
		var r := _rim(a) * rng.randf_range(0.78, 0.86)
		var e: Array = kinds[i % kinds.size()]
		var m: ArrayMesh = Props.model(e[0], "", {"leaf": e[1], "wood": Color(0.78, 0.52, 0.34)})
		var mi := MeshInstance3D.new()
		mi.mesh = m
		var k := float(args.get("palm", "170")) / maxf(m.get_aabb().size.y, 0.01)
		var x := V.VENT.x + cos(a) * r
		var z := V.VENT.y + sin(a) * r
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * k), Vector3(cos(a) * r, _top_h(x, z) - 2.0, sin(a) * r))
		root.add_child(mi)
	root.scale = Vector3.ONE * float(args.get("isk", str(ISLE_K)))
	return root


# --- scene ----------------------------------------------------------------------------------

func bg(u: float, v: float) -> Color:
	match args.bg:
		"plum": # deep plum top to warm coral glow behind the volcano
			return radial(u, v, Vector2(0.72, 0.72), [[0.0, Color(1.0, 0.62, 0.45)], [0.5, Color(0.72, 0.28, 0.5)], [1.1, Color(0.24, 0.1, 0.3)]])
		"mint":
			return radial(u, v, Vector2(0.35, 0.3), [[0.0, Color(0.88, 1.0, 0.86)], [0.6, Color(0.45, 0.88, 0.72)], [1.2, Color(0.1, 0.5, 0.5)]])
		_: # teal: deep sea-glass teal, a pale glow in the empty upper-right (off the gold wing)
			return radial(u, v, Vector2(float(args.get("gx", "0.78")), float(args.get("gy", "0.18"))), [[0.0, Color(0.8, 0.97, 0.78)], [0.45, Color(0.18, 0.68, 0.64)], [1.15, Color(0.03, 0.28, 0.36)]])


func radial(u: float, v: float, c: Vector2, stops: Array) -> Color:
	var d := Vector2(u, v).distance_to(c)
	var col: Color = stops[0][1]
	for i in range(1, stops.size()):
		col = col.lerp(stops[i][1], clampf(inverse_lerp(stops[i - 1][0], stops[i][0], d), 0, 1))
	return col


func _run() -> void:
	var body: Color = {red = Color(1.0, 0.35, 0.3), blue = Color(0.3, 0.55, 1.0), cream = Color(0.98, 0.92, 0.8)}[args.body]
	var sc := Node3D.new()
	var p := plane(body, int(args.livery), int(args.get("sticker", "1")))
	aim(p, Vector3(float(args.get("px", "-1.5")), float(args.get("py", "2.2")), float(args.get("pz", "4.0"))), Vector3(float(args.get("dx", "-1.0")), float(args.get("dy", "0.18")), float(args.get("dz", "0.7"))), float(args.get("roll", "-32")))
	sc.add_child(p)
	var isl := island()
	isl.position = Vector3(float(args.get("ix", "4.0")), float(args.get("iy", "-4.0")), float(args.get("iz", "-8.0")))
	isl.rotation.y = deg_to_rad(float(args.get("iyaw", "40")))
	sc.add_child(isl)
	var vp := SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.68, 0.66) # volcano world ambient
	env.ambient_light_energy = 0.55
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2 # volcano sky.saturation
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(0.4, -0.8, -0.45), Vector3.UP)
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	vp.add_child(sun)
	vp.add_child(sc)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(float(args.get("cx", "0")), float(args.get("cy", "8")), 26.0), Vector3(0, 0, 0))
	await process_frame
	_fit(cam, _points([p, isl]), float(args.get("frac", "1.0")), Vector2(float(args.get("fx", "0.5")), float(args.get("fy", "0.5"))))
	var ol := MeshInstance3D.new() # main.add_outline(): the game's ink lines
	ol.mesh = QuadMesh.new()
	ol.mesh.size = Vector2(2, 2)
	ol.mesh.flip_faces = true
	ol.extra_cull_margin = 16384.0
	ol.material_override = ShaderMaterial.new()
	ol.material_override.shader = preload("res://outline.gdshader")
	cam.add_child(ol)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var fg := vp.get_texture().get_image()
	vp.queue_free()
	fg.convert(Image.FORMAT_RGBA8)
	fg.save_png(OUT + "src/%s_render.png" % args.out)
	var out := _background()
	out.blend_rect(_halo(fg, int(args.get("stroke", "12")), INK), Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.blend_rect(fg, Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	out.save_png(OUT + args.out + ".png")
	print("wrote ", args.out)
	quit()


func _points(nodes: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n: Node in nodes:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var xf := mi.global_transform
			var f := mi.mesh.get_faces()
			for i in range(0, f.size(), 7): # sparse sample: the island has ~40k faces
				pts.append(xf * f[i])
	return pts


func _fit(cam: Camera3D, pts: PackedVector3Array, frac: float, centre: Vector2) -> void: # dolly + lens shift until the bounds fit
	for it in 6:
		var lo := Vector2(INF, INF)
		var hi := -lo
		var depth := 0.0
		for p in pts:
			var s := cam.unproject_position(p)
			lo = lo.min(s)
			hi = hi.max(s)
			depth += -(cam.global_transform.affine_inverse() * p).z
		depth /= pts.size()
		var ext := maxf(hi.x - lo.x, hi.y - lo.y) / S
		var fwd := -cam.global_transform.basis.z
		var move := depth * (1.0 - ext / frac)
		cam.global_position += fwd * move
		var upp := 2.0 * (depth - move) * tan(deg_to_rad(cam.fov) / 2.0) / S
		var off := ((lo + hi) / 2.0 - centre * S) * (frac / ext)
		cam.h_offset += off.x * upp
		cam.v_offset -= off.y * upp


func _background() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, bg((x + 0.5) / n, (y + 0.5) / n))
	img.resize(S, S, Image.INTERPOLATE_CUBIC)
	return img


func _halo(fg: Image, px: int, col: Color) -> Image: # sticker outline: alpha mask grown by px (at 1/2 scale)
	var n := S / 2
	var r := maxi(1, px / 2)
	var m := fg.duplicate() as Image
	m.resize(n, n, Image.INTERPOLATE_BILINEAR)
	var a := PackedFloat32Array()
	a.resize(n * n)
	for y in n:
		for x in n:
			a[y * n + x] = m.get_pixel(x, y).a
	var offs := []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				offs.append(Vector2i(dx, dy))
	var g := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var best := 0.0
			for o: Vector2i in offs:
				var xx := x + o.x
				var yy := y + o.y
				if xx >= 0 and yy >= 0 and xx < n and yy < n and a[yy * n + xx] > best:
					best = a[yy * n + xx]
					if best >= 0.99:
						break
			g.set_pixel(x, y, Color(col, best))
	g.resize(S, S, Image.INTERPOLATE_CUBIC)
	for y in S:
		for x in S:
			g.set_pixel(x, y, Color(col, smoothstep(0.3, 0.7, g.get_pixel(x, y).a)))
	return g
