extends SceneTree
# SKYWRITE icon (round 2): a big game cub climbing out of one closed loop of the game's cel cloud puffs.
# godot --path . --resolution 1024x1024 -s aso/tools/icon_skywrite.gd
# Out: aso/creative/icons/v3/final_skywrite.png (1024 RGB) + _dark (RGBA, transparent bg) + _tinted (grayscale).
# Three passes with one camera: puffs, plane, prop-blur disc.

const OUT := "res://aso/creative/icons/v3/"
const S := 1024
const INK := Color(0.08, 0.06, 0.12)
const RED := Color(1.0, 0.35, 0.3) # Aircraft.TEAM_COLORS red
const GOLD := 1 # Planes.LIVERIES "Golden Ace"
const STAR := 0 # Planes.STICKERS: none (the small stars mushed at 60 px)
const UP := 50.0
const NAME := "final_skywrite"
const FIT := 0.6 # plane share of the frame
const CENTRE := Vector2(0.64, 0.5) 
const HEAD := 0.85 # nose climbs toward the upper right
const STEM := 70.0 # px of straight trail before the loop
const LOOP := 155.0 # loop radius px
const SLIDE := 0.12 # loop drift per radian: lower = rounder, more overlap
const EXIT := 0.15 # radians of run-out after the loop closes
const SIDE := 1.0 
const R0 := 46.0 # puff radius px at the tail
const R1 := 32.0 # at the oldest end
const PLANE_INK := 21 # 1.5x round 1's 14
const RIM := 8
const SMOKE_INK := 9
const FOE_AT := Vector2(0.27, 0.22) 
const FOE_HEAD := 0.5
const FOE_SCALE := 0.34 

var _cache := {}
var plane_props := []


func toon(c: Color) -> ShaderMaterial: # main.toon()
	if not _cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_cache[c] = mat
	return _cache[c]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(_strip if "sizes" in OS.get_cmdline_user_args() else _run).call_deferred()


# Size check: sips -z N N final_skywrite.png --out /tmp/skywrite_N.png for N in 180 120 87 60 first, then `-- sizes`.
# Each size sits on a light and a dark panel with the iOS rounded mask (radius 22.37%) for judging.
func _strip() -> void:
	var sizes := [180, 120, 87, 60]
	var pad := 30
	var w := pad
	for n in sizes:
		w += n + pad
	var h := 2 * (180 + 2 * pad)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill_rect(Rect2i(0, 0, w, h / 2), Color(0.95, 0.95, 0.97))
	out.fill_rect(Rect2i(0, h / 2, w, h / 2), Color(0.07, 0.07, 0.09))
	var x := pad
	for n: int in sizes:
		var img := Image.load_from_file("/tmp/skywrite_%d.png" % n)
		img.convert(Image.FORMAT_RGBA8)
		var r := n * 0.2237
		for yy in n:
			for xx in n:
				var q := Vector2(clampf(xx + 0.5, r, n - r), clampf(yy + 0.5, r, n - r))
				var a := clampf(r - Vector2(xx + 0.5, yy + 0.5).distance_to(q) + 0.5, 0, 1)
				var c := img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(c, a))
		for row in 2:
			out.blend_rect(img, Rect2i(0, 0, n, n), Vector2i(x, row * h / 2 + pad + (180 - n) / 2))
		x += n + pad
	out.convert(Image.FORMAT_RGB8)
	out.save_png(OUT + NAME + "_sizes.png")
	print("wrote sizes")
	quit()


func plane(paint := RED, livery := GOLD) -> Node3D:
	Worlds.index = 0
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark := toon(Color(0.2, 0.2, 0.22))
	var parts := Planes.build("cub", root, toon(paint), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), dark, glow, livery)
	Planes.dress("cub", root, parts, 0, 0, STAR, 0, dark, toon)
	if plane_props.is_empty():
		plane_props = parts.props
	for p: Node3D in parts.props:
		p.rotation.z = deg_to_rad(20.0)
	_cut(root)
	return root


# Gear legs, wheels and wing struts ink into black scratches at icon sizes: drop the merged triangles there.
func _cut(root: Node3D) -> void:
	for mi in root.get_children():
		if not (mi is MeshInstance3D and mi.mesh is ArrayMesh):
			continue
		var a: Array = mi.mesh.surface_get_arrays(0)
		if a[Mesh.ARRAY_INDEX] == null:
			continue
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var c := (v[idx[i]] + v[idx[i + 1]] + v[idx[i + 2]]) / 3.0
			var gear := c.y < -0.66 or (c.z > 3.2 and c.y < -0.12)
			var strut := c.y > -0.3 and c.y < 0.88 and c.z < 0.5 and c.z > -1.2 and absf(c.x) > 0.7
			if not (gear or strut):
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		if keep.size() == idx.size():
			continue
		if keep.is_empty():
			mi.visible = false
			continue
		a[Mesh.ARRAY_INDEX] = keep
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var mat: Material = mi.mesh.surface_get_material(0)
		if mat:
			m.surface_set_material(0, mat)
		mi.mesh = m


# Trail in screen px (y down): a short stem straight back from the tail, then one side-on loop
# (prolate cycloid: rises on the `n` side, crosses itself, runs out). Fat at the tail, thin at the start.
func trail(tail: Vector2, back: Vector2) -> Array:
	var n := Vector2(-back.y, back.x) * SIDE
	var stem := tail + back * STEM
	var pts := []
	for i in 20:
		pts.append(tail.lerp(stem, i / 20.0))
	for i in 241:
		var t := (TAU + EXIT) * i / 240.0
		var q := Vector2(SLIDE * t + sin(t), 1.0 - cos(t)) * LOOP
		pts.append(stem + back * q.x + n * q.y)
	return pts


func puffs(cam: Camera3D, depth: float, tail: Vector2, back: Vector2) -> MultiMeshInstance3D:
	var raw := trail(tail, back)
	var upp := 2.0 * depth * tan(deg_to_rad(cam.fov) / 2.0) / S
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	mm.mesh = sphere
	var list := []
	var acc := 0.0
	var next := 0.0
	for i in raw.size(): # fewer, larger puffs: one every ~1 radius along the path
		var k := float(i) / (raw.size() - 1) # 0 = at the tail, 1 = oldest
		var r := lerpf(R0, R1, k)
		if i > 0:
			acc += (raw[i] as Vector2).distance_to(raw[i - 1])
		if acc < next:
			continue
		next = acc + r * 1.25
		var w := cam.project_position(raw[i], depth - 6.0 + k * 4.0) # newest nearest: the stem covers the tucked end
		list.append([w, r * upp])
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * list[i][1]), list[i][0]))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://clouds.gdshader")
	m.set_shader_parameter("sun_dir", Vector3(-0.4, 0.75, 0.55).normalized())
	m.set_shader_parameter("top", Color(1, 1, 1))
	m.set_shader_parameter("mid", Color(1, 1, 1))
	m.set_shader_parameter("bottom", Color(0.8, 0.84, 0.98))
	m.set_shader_parameter("wind", Vector2.ZERO)
	m.set_shader_parameter("near_fade", 0.01)
	mmi.material_override = m
	return mmi


func blur_disc(p: Node3D) -> MeshInstance3D: # prop blur: a flat disc over the blades, own pass
	var hub: Node3D = plane_props[0]
	var r := 0.0
	for mi: MeshInstance3D in hub.find_children("*", "MeshInstance3D", true, false):
		for v in mi.mesh.get_faces():
			r = maxf(r, Vector2(v.x, v.y).length())
	var d := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 1.05
	cyl.bottom_radius = r * 1.05
	cyl.height = 0.02
	cyl.radial_segments = 48
	d.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d.material_override = mat
	d.rotation.x = PI / 2
	d.position = Vector3(0, 0, -0.08)
	hub.add_child(d)
	return d


func _run() -> void:
	var sc := Node3D.new()
	var p := plane()
	var heading := Vector3(1.0, HEAD, 0.0).normalized()
	var up := (Vector3(-heading.y, heading.x, 0.0) * 0.55 + Vector3(0, 0, 1) * 0.8).normalized() # three-quarter top: wing planform shows
	var at := Vector3(0.0, UP, 0.0)
	p.transform = Transform3D(Basis.looking_at(heading + Vector3(0, 0, 0.35), up), at)
	sc.add_child(p)

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
	env.ambient_light_color = Color(0.62, 0.72, 0.9)
	env.ambient_light_energy = 0.55
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(0.4, -0.6, -0.7), Vector3.UP)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.2
	vp.add_child(sun)
	vp.add_child(sc)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, UP, 60), Vector3(0, UP, 0))
	await process_frame
	_fit(cam, _points([p]), FIT, CENTRE)
	var disc := blur_disc(p)
	var depth := -(cam.global_transform.affine_inverse() * at).z
	var tail := cam.unproject_position(p.transform * Vector3(0, 0.1, 3.4))
	var nose := cam.unproject_position(p.transform * Vector3(0, 0, -3.0))
	var pf := puffs(cam, depth, tail, (tail - nose).normalized())
	sc.add_child(pf)
	var foe: Node3D = null
	if "foe" in OS.get_cmdline_user_args(): # PPO 'combat' arm: a small red foe fleeing ahead
		foe = plane(Color(0.85, 0.12, 0.12), 0)
		var fh := Vector3(1.0, FOE_HEAD, 0.0).normalized()
		var fu := (Vector3(-fh.y, fh.x, 0.0) * 0.5 + Vector3(0, 0, 1) * 0.8).normalized()
		foe.transform = Transform3D(Basis.looking_at(fh + Vector3(0, 0, 0.35), fu).scaled(Vector3.ONE * FOE_SCALE), cam.project_position(FOE_AT * S, depth))
		sc.add_child(foe)
	var ol := MeshInstance3D.new() # main.add_outline()
	ol.mesh = QuadMesh.new()
	ol.mesh.size = Vector2(2, 2)
	ol.mesh.flip_faces = true
	ol.extra_cull_margin = 16384.0
	ol.material_override = ShaderMaterial.new()
	ol.material_override.shader = preload("res://outline.gdshader")
	cam.add_child(ol)

	p.visible = false
	if foe:
		foe.visible = false
	var smoke := await _grab(vp)
	if foe:
		foe.visible = true
	p.visible = true
	pf.visible = false
	disc.visible = false
	var fg := await _grab(vp)
	ol.visible = false
	disc.visible = true
	for mi: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
		if mi != disc:
			mi.visible = false
	var blur := await _grab(vp)
	vp.queue_free()
	fg.blend_rect(_tint(blur, Color(1, 1, 1, 0.55)), Rect2i(0, 0, S, S), Vector2i.ZERO)
	fg.save_png(OUT + "src/skywrite_plane_src.png")
	smoke.save_png(OUT + "src/skywrite_smoke_src.png")

	var layers := [
		_halo(smoke, SMOKE_INK, INK), smoke,
		_halo(fg, PLANE_INK + RIM, Color(1, 1, 1)), _halo(fg, PLANE_INK, INK), fg]
	var out := _background()
	for l: Image in layers:
		out.blend_rect(l, Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	var name := NAME + ("_foe" if foe else "")
	out.save_png(OUT + name + ".png")
	if foe:
		print("wrote ", name)
		quit()
		return
	# Apple appearances: dark = transparent bg (system supplies it), tinted = grayscale, opaque on black.
	var dark := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for l: Image in layers:
		dark.blend_rect(l, Rect2i(0, 0, S, S), Vector2i.ZERO)
	dark.save_png(OUT + NAME + "_dark.png")
	var tint := Image.create(S, S, false, Image.FORMAT_RGBA8)
	tint.fill(Color(0, 0, 0))
	tint.blend_rect(dark, Rect2i(0, 0, S, S), Vector2i.ZERO)
	for y in S:
		for x in S:
			var l := tint.get_pixel(x, y).get_luminance()
			tint.set_pixel(x, y, Color(l, l, l))
	tint.convert(Image.FORMAT_RGB8)
	tint.save_png(OUT + NAME + "_tinted.png")
	print("wrote ", NAME, ", _dark, _tinted")
	quit()


func _tint(mask: Image, col: Color) -> Image:
	var g := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			g.set_pixel(x, y, Color(col, mask.get_pixel(x, y).a * col.a))
	return g


func _grab(vp: SubViewport) -> Image:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _background() -> Image: # rich dusk: deep violet top to warm coral glow behind the plane
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var c := Color(0.22, 0.16, 0.55).lerp(Color(0.45, 0.25, 0.7), clampf(v * 1.2, 0, 1))
			var g := 1.0 - smoothstep(0.0, 0.75, Vector2(u, v).distance_to(Vector2(0.8, 0.85)))
			img.set_pixel(x, y, c.lerp(Color(1.0, 0.55, 0.45), g * 0.85))
	img.resize(S, S, Image.INTERPOLATE_CUBIC)
	return img


func _points(nodes: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n: Node in nodes:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var xf := mi.global_transform
			for v in mi.mesh.get_faces():
				pts.append(xf * v)
	return pts


func _fit(cam: Camera3D, pts: PackedVector3Array, frac: float, centre: Vector2) -> void: # render_icons.gd _fit
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


func _halo(fg: Image, px: int, col: Color) -> Image: # render_icons.gd _halo: alpha mask grown by px, filled with col
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
			g.set_pixel(x, y, Color(col, best * col.a))
	g.resize(S, S, Image.INTERPOLATE_CUBIC)
	for y in S:
		for x in S:
			g.set_pixel(x, y, Color(col, smoothstep(0.3, 0.7, g.get_pixel(x, y).a / col.a) * col.a))
	return g
