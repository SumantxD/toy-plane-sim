extends SceneTree
# v3 HERO icon: one chunky Toy Cub from the game's own model (Planes.build/dress), low three-quarter front.
# godot --path . --resolution 1024x1024 -s aso/tools/icon_hero.gd
# Out: aso/creative/icons/v3/hero.png (1024 RGB, full square) + hero_sizes.png (180/120/87/60 on light and dark).

const OUT := "res://aso/creative/icons/v3/"
const S := 1024
const BLUE := Color(0.3, 0.55, 1.0) # Aircraft.TEAM_COLORS
const INK := Color(0.08, 0.06, 0.12)
const LIVERY := 0 # Team Colours: the in-game blue cub
const STICKER := 1 # Star
const PROP_DEG := 140.0
const NOSE := Vector3(0.42, 0.1, 1.0) # nose (-Z) points this way: toward the camera, a little up and right
const ROLL := -34.0
const CAM := Vector3(0.0, 3.2, 14.0)
const FOV := 28.0
const FIT := 0.7
const BODY := 1.7
const STROKE := 22
const LIGHT := Vector3(0.5, -0.8, 0.35)

var _cache := {}


func toon(c: Color) -> ShaderMaterial: # main.toon()
	if not _cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_cache[c] = mat
	return _cache[c]


var teal := "teal" in OS.get_cmdline_user_args() # A/B background: writes hero_teal.png instead


func bg(u: float, v: float) -> Color: # two-tone: light glow behind the plane, darker edge
	var d := Vector2(u, v).distance_to(Vector2(0.42, 0.4))
	if teal:
		return Color(0.55, 0.9, 0.82).lerp(Color(0.05, 0.42, 0.45), smoothstep(0.15, 0.75, d))
	return Color(1.0, 0.86, 0.45).lerp(Color(0.95, 0.42, 0.3), smoothstep(0.15, 0.75, d))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	var p := _plane()
	p.transform = Transform3D(Basis.looking_at(NOSE, Vector3.UP) * Basis(Vector3.FORWARD, deg_to_rad(ROLL)), Vector3.ZERO)
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
	sun.basis = Basis.looking_at(LIGHT, Vector3.UP)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	vp.add_child(sun)
	vp.add_child(p)
	var cam := Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.look_at_from_position(CAM, Vector3.ZERO)
	await process_frame
	_fit(cam, _points(p), FIT, Vector2(0.46, 0.53))
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
	var out := _background()
	out.blend_rect(_halo(fg, STROKE, INK), Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.blend_rect(fg, Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	var name := "hero_teal" if teal else "hero"
	out.save_png(OUT + name + ".png")
	_strip(out).save_png(OUT + name + "_sizes.png")
	print("wrote hero.png, hero_sizes.png")
	quit()


func _plane() -> Node3D:
	Worlds.index = 0
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var dark := toon(Color(0.2, 0.2, 0.22))
	var parts := Planes.build("cub", root, toon(BLUE), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), dark, glow, LIVERY)
	Planes.dress("cub", root, parts, 0, 0, STICKER, 0, dark, toon)
	for pr: Node3D in parts.props:
		pr.rotation.z = deg_to_rad(PROP_DEG)
	_strip_gear(root)
	return root


# Struts, gear legs and wheels ink into black scratches at icon size. They share the strut/dark materials with the
# gun barrels (merged by Planes._merge), so cut triangles by zone: strut band beside the cabin, everything under the belly.
func _strip_gear(root: Node3D) -> void:
	var mats := [Planes._toon(Planes.STYLE[0].strut), toon(Color(0.2, 0.2, 0.22))]
	for mi in root.get_children():
		if not mi is MeshInstance3D:
			continue
		var thin: bool = mi.material_override in mats
		var a: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var c := (v[idx[i]] + v[idx[i + 1]] + v[idx[i + 2]]) / 3.0
			var strut := thin and c.y > -0.3 and c.y < 1.0 and c.z < 0.5 and absf(c.x) > 0.7
			var gear := c.z > -3.0 and (c.y < -0.8 or (thin and c.y < -0.3)) # wheels and hub caps too
			if not (strut or gear):
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		a[Mesh.ARRAY_INDEX] = keep
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mi.mesh = m


func _points(n: Node3D) -> PackedVector3Array: # fuselage, tail and prop only: the wingtips may run off the edge
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var xf := mi.global_transform
			for v in mi.mesh.get_faces():
				if absf((n.global_transform.affine_inverse() * xf * v).x) < BODY:
					pts.append(xf * v)
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


# Sticker-style outline: the plane's alpha mask grown by `px` (at 1/2 scale), filled with `col`.
func _halo(fg: Image, px: int, col: Color) -> Image:
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


# 180/120/87/60 px, iOS-style rounded mask, on a light row and a dark row.
func _strip(icon: Image) -> Image:
	var sizes := [180, 120, 87, 60]
	var pad := 24
	var w := pad
	for s: int in sizes:
		w += s + pad
	var h := 2 * (180 + 2 * pad)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill_rect(Rect2i(0, 0, w, h / 2), Color(0.95, 0.95, 0.97))
	img.fill_rect(Rect2i(0, h / 2, w, h / 2), Color(0.07, 0.07, 0.09))
	for row in 2:
		var x := pad
		for s: int in sizes:
			var small := icon.duplicate() as Image
			small.resize(s, s, Image.INTERPOLATE_LANCZOS)
			var y0 := row * h / 2 + pad + (180 - s) / 2
			var rad := s * 0.225
			for yy in s:
				for xx in s:
					var q := Vector2(maxf(absf(xx + 0.5 - s / 2.0) - (s / 2.0 - rad), 0), maxf(absf(yy + 0.5 - s / 2.0) - (s / 2.0 - rad), 0))
					var k := clampf(rad - q.length() + 0.5, 0, 1)
					if k > 0:
						img.set_pixel(x + xx, y0 + yy, img.get_pixel(x + xx, y0 + yy).lerp(small.get_pixel(xx, yy), k))
			x += s + pad
	return img
