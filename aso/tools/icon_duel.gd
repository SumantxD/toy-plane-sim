extends SceneTree
# DUEL icon (v3): blue Golden Ace Toy Cub chasing a red Speedster, both from Planes.build/dress.
# godot --path . --resolution 1024x1024 -s aso/tools/icon_duel.gd [-- bg=teal|orange]
# Out: aso/creative/icons/v3/final_duel[_orange].png (1024 RGB), _sizes.png (180/120/87/60/40 on light + dark),
# teal also _dark.png (transparent bg) and _tinted.png (grayscale); src/final_duel_render.png (raw 3D pass).

const OUT := "res://aso/creative/icons/v3/"
const S := 1024
const BLUE := Color(0.3, 0.55, 1.0) # Aircraft.TEAM_COLORS
const RED := Color(1.0, 0.35, 0.3)
const INK := Color(0.08, 0.06, 0.12)
const SPARK := Color(1.0, 0.95, 0.55)
const HOT := Color(1.0, 1.0, 0.92)
# layout (iterated by eye against final_duel_sizes.png)
const CAM_AT := Vector3(-4.0, 22.0, 24.0)
const HERO_AT := Vector3(-2.5, 0.5, 11.0)
const HERO_ROLL := -15.0
const FOE_AT := Vector3(6.0, 2.5, -3.5)
const FOE_DIR := Vector3(1.0, 0.1, -0.4)
const FOE_ROLL := 20.0
const FIT := 0.85
const FIT_C := Vector2(0.5, 0.52)
const STAR_R := 84.0
const STAR_TILT := 0.26

var _cache := {}
var bg_name := "teal"


func toon(c: Color) -> ShaderMaterial: # same as main.toon()
	if not _cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_cache[c] = mat
	return _cache[c]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bg="):
			bg_name = a.substr(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "src"))
	_render.call_deferred()


func plane(kind: String, color: Color, livery: int, prop_deg: float) -> Node3D:
	Worlds.index = 0
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var dark := toon(Color(0.2, 0.2, 0.22))
	var parts := Planes.build(kind, root, toon(color), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), dark, glow, livery)
	Planes.dress(kind, root, parts, 0, 0, 0, 0, dark, toon)
	for p: Node3D in parts.props:
		p.rotation.z = deg_to_rad(prop_deg)
	_cut(root, kind)
	return root


# Gear, wing struts and gun barrels ink into loose black scratches at icon size. Planes._merge folds them
# into shared meshes, so drop their triangles by zone: below the belly, and the cub's strut band.
func _cut(root: Node3D, kind: String) -> void:
	var belly := -0.78 if kind == "cub" else -0.62
	for mi in root.get_children():
		if not (mi is MeshInstance3D and mi.mesh is ArrayMesh):
			continue
		var a: Array = mi.mesh.surface_get_arrays(0)
		if a[Mesh.ARRAY_INDEX] == null:
			continue
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var strut: bool = mi.material_override == Planes._toon(Planes.STYLE[0].strut)
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var c := (v[idx[i]] + v[idx[i + 1]] + v[idx[i + 2]]) / 3.0
			var drop := c.y < belly or (c.z > 3.0 and c.y < -0.25) # main gear, tail wheel
			if strut: # gear legs (inboard, under the belly line) and the cub's wing struts
				drop = drop or c.y < -0.3 or (kind == "cub" and c.y < 1.0 and c.z < 0.5 and absf(c.x) > 0.7)
			if not drop:
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		a[Mesh.ARRAY_INDEX] = keep
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mi.mesh = m


func aim(p: Node3D, at: Vector3, dir: Vector3, roll_deg: float) -> void: # nose (-Z) along dir, then bank
	p.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, deg_to_rad(roll_deg)), at)


var glow := Vector2(0.55, 0.45)


func _ramp(d: float, stops: Array) -> Color:
	for i in range(1, stops.size()):
		if d <= stops[i][0]:
			return stops[i - 1][1].lerp(stops[i][1], (d - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]))
	return stops[-1][1]


func bg(u: float, v: float) -> Color:
	var d := Vector2(u, v).distance_to(glow)
	if bg_name == "orange": # round-1 B_duel sky, for a one-variable PPO test against teal
		return _ramp(d, [[0.0, Color(1.0, 0.78, 0.4)], [0.45, Color(0.97, 0.55, 0.3)], [0.95, Color(0.85, 0.3, 0.25)], [9.0, Color(0.85, 0.3, 0.25)]])
	# mid teal with a light centre glow: away from the category's sky blue, and the edge still shows on a dark home screen
	return _ramp(d, [[0.0, Color(0.42, 0.8, 0.76)], [0.35, Color(0.2, 0.62, 0.62)], [0.85, Color(0.1, 0.42, 0.46)], [9.0, Color(0.1, 0.42, 0.46)]])


# --- render ------------------------------------------------------------------------------------

func _render() -> void:
	var sc := Node3D.new()
	var hero := plane("cub", BLUE, 1, 25.0)
	aim(hero, HERO_AT, (FOE_AT - HERO_AT).normalized(), HERO_ROLL) # nose on the foe, so the shot line runs off the prop
	sc.add_child(hero)
	var foe := plane("racer", RED, 0, 70.0)
	aim(foe, FOE_AT, FOE_DIR.normalized(), FOE_ROLL)
	sc.add_child(foe)

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
	env.ambient_light_energy = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(0.3, -0.8, -0.5), Vector3.UP)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.25
	vp.add_child(sun)
	vp.add_child(sc)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(CAM_AT, Vector3(0, 0, 0))
	await process_frame
	_fit(cam, _points([hero, foe]), FIT, FIT_C)
	for n in [["hero", hero], ["foe", foe]]: # MEASURED: projected width share of each plane
		var b := _bounds(cam, _points([n[1]]))
		print("%s width %.0f%%  x %.0f..%.0f  y %.0f..%.0f" % [n[0], (b.size.x) / S * 100.0, b.position.x, b.end.x, b.position.y, b.end.y])

	var hit := cam.unproject_position(foe.transform * Vector3(0, 0.45, 2.2)) # rear fuselage, behind the cockpit and clear of the wing
	var nose := cam.unproject_position(hero.transform * Vector3(0, 0.0, -5.6)) # just ahead of the prop disc
	glow = hit / S
	var shots := [] # three separate tapered dashes: gap off the nose, gaps between, gap before the burst
	var u := (hit - nose).normalized()
	var run := nose.distance_to(hit) - STAR_R * 0.45
	for r in [[0.0, 0.22, 22.0], [0.36, 0.6, 28.0], [0.74, 1.0, 34.0]]:
		shots.append([nose + u * run * r[0], nose + u * run * r[1], r[2]])
	print("nose->hit %.0f px" % nose.distance_to(hit))

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
	fg.save_png(OUT + "src/final_duel_render.png")

	var ink := _halo(fg, 14, INK)
	var name := "final_duel" + ("" if bg_name == "teal" else "_" + bg_name)
	var out := _layers(_background(), [ink], fg, shots, hit)
	out.convert(Image.FORMAT_RGB8)
	out.save_png(OUT + name + ".png")
	print("wrote %s.png" % name)
	_sizes(out, name)
	if bg_name == "teal": # Apple dark (transparent bg, system supplies it) and tinted (grayscale) appearances
		var clear := Image.create(S, S, false, Image.FORMAT_RGBA8)
		var dark := _layers(clear, [_halo(fg, 22, Color(1, 1, 1, 0.85)), ink], fg, shots, hit)
		dark.save_png(OUT + name + "_dark.png")
		var tint := Image.create(S, S, false, Image.FORMAT_RGB8)
		var on_black := Image.create(S, S, false, Image.FORMAT_RGBA8)
		on_black.fill(Color.BLACK)
		on_black.blend_rect(dark, Rect2i(0, 0, S, S), Vector2i.ZERO)
		for y in S:
			for x in S:
				var p := on_black.get_pixel(x, y)
				var l := maxf(p.r, maxf(p.g, p.b)) * 0.6 + p.get_luminance() * 0.4 # red foe lands mid-grey, hero stays light
				tint.set_pixel(x, y, Color(l, l, l))
		tint.save_png(OUT + name + "_tinted.png")
		print("wrote %s_dark, _tinted" % name)
	quit()


func _layers(base: Image, halos: Array, fg: Image, shots: Array, hit: Vector2) -> Image:
	var out := base
	for h: Image in halos:
		out.blend_rect(h, Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.blend_rect(fg, Rect2i(0, 0, S, S), Vector2i.ZERO)
	for s in shots:
		_tracer(out, s[0], s[1], s[2], 6.0, INK)
		_tracer(out, s[0], s[1], s[2], 0.0, SPARK)
		_tracer(out, s[0].lerp(s[1], 0.25), s[1], s[2] * 0.4, 0.0, HOT)
	_star4(out, hit, STAR_R, 10.0)
	return out


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


func _bounds(cam: Camera3D, pts: PackedVector3Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in pts:
		var s := cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2(lo, hi - lo)


func _fit(cam: Camera3D, pts: PackedVector3Array, frac: float, centre: Vector2) -> void: # dolly + lens shift (render_icons.gd)
	for it in 6:
		var b := _bounds(cam, pts)
		var depth := 0.0
		for p in pts:
			depth += -(cam.global_transform.affine_inverse() * p).z
		depth /= pts.size()
		var ext := maxf(b.size.x, b.size.y) / S
		var move := depth * (1.0 - ext / frac)
		cam.global_position += -cam.global_transform.basis.z * move
		var upp := 2.0 * (depth - move) * tan(deg_to_rad(cam.fov) / 2.0) / S
		var off := (b.get_center() - centre * S) * (frac / ext)
		cam.h_offset += off.x * upp
		cam.v_offset -= off.y * upp


# --- 2D layers ---------------------------------------------------------------------------------

func _background() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, bg((x + 0.5) / n, (y + 0.5) / n))
	img.resize(S, S, Image.INTERPOLATE_CUBIC)
	return img


func _cover(img: Image, x: int, y: int, d: float, col: Color) -> void: # d = signed distance, <0 inside; 1px AA edge
	var a := clampf(0.5 - d, 0.0, 1.0)
	if a > 0.0:
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a))


# Tapered streak from a (thin tail) to b (fat head). grow > 0 draws the ink edge pass.
func _tracer(img: Image, a: Vector2, b: Vector2, w: float, grow: float, col: Color) -> void:
	var d := b - a
	var len2 := d.length_squared()
	var lo := (a.min(b) - Vector2.ONE * (w + grow)).floor().max(Vector2.ZERO)
	var hi := (a.max(b) + Vector2.ONE * (w + grow)).ceil().min(Vector2.ONE * (S - 1))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(d) / len2, 0.0, 1.0)
			var r := w * 0.5 * (0.5 + 0.5 * t) + grow
			_cover(img, x, y, p.distance_to(a + d * t) - r, col)



# Bold 4-point toon star: inked, pale yellow, white-hot core.
func _star4(img: Image, c: Vector2, ro: float, ink: float) -> void:
	var poly := PackedVector2Array()
	for i in 8:
		var ang := PI * i / 4.0 + STAR_TILT
		poly.append(c + Vector2.from_angle(ang) * (ro if i % 2 == 0 else ro * 0.3))
	var lo := (c - Vector2.ONE * (ro + ink + 2)).max(Vector2.ZERO)
	var hi := (c + Vector2.ONE * (ro + ink + 2)).min(Vector2.ONE * (S - 1))
	var core := PackedVector2Array()
	for q in poly:
		core.append(c + (q - c) * 0.5)
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var p := Vector2(x + 0.5, y + 0.5)
			_cover(img, x, y, _sd(p, poly) - ink, INK)
			_cover(img, x, y, _sd(p, poly), SPARK)
			_cover(img, x, y, _sd(p, core), HOT)


func _sd(p: Vector2, poly: PackedVector2Array) -> float:
	var dist := INF
	for i in poly.size():
		dist = minf(dist, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return -dist if Geometry2D.is_point_in_polygon(p, poly) else dist


# Sticker-style outline: alpha mask grown by `px` at 1/2 scale (render_icons.gd).
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


# Small-size check strip: 180/120/87/60/40 with the iOS-ish rounded mask, on a light row and a dark row.
func _sizes(icon: Image, name: String) -> void:
	var sizes := [180, 120, 87, 60, 40]
	var pad := 24
	var w := pad
	for s in sizes:
		w += s + pad
	var row := 180 + pad * 2
	var strip := Image.create(w, row * 2, false, Image.FORMAT_RGB8)
	strip.fill_rect(Rect2i(0, 0, w, row), Color(0.95, 0.95, 0.97))
	strip.fill_rect(Rect2i(0, row, w, row), Color(0.07, 0.07, 0.09))
	for r in 2:
		var x := pad
		for s: int in sizes:
			var im := icon.duplicate() as Image
			im.resize(s, s, Image.INTERPOLATE_LANCZOS)
			var y0 := r * row + pad + (180 - s) / 2
			var rad := s * 0.225
			for yy in s:
				for xx in s:
					var q := Vector2(xx + 0.5, yy + 0.5)
					var k := Vector2(clampf(q.x, rad, s - rad), clampf(q.y, rad, s - rad))
					var a := clampf(rad - q.distance_to(k) + 0.5, 0.0, 1.0)
					if a > 0.0:
						strip.set_pixel(x + xx, y0 + yy, strip.get_pixel(x + xx, y0 + yy).lerp(im.get_pixel(xx, yy), a))
			x += s + pad
	strip.save_png(OUT + name + "_sizes.png")
	print("wrote %s_sizes.png" % name)
