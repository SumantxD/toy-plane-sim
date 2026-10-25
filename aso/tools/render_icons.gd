extends SceneTree
# Renders App Store icon concepts from the game's own plane models (Planes.build / Planes.dress).
# godot --path . --resolution 1024x1024 -s aso/tools/render_icons.gd [-- A B C]
# Out: aso/creative/icons/{A_hero,B_duel,C_face}.png (RGB, 1024, square), raw transparent renders in icons/src/.
# The CHOSEN concept also gets <name>_dark.png (navy bg, light rim) and <name>_tinted.png (grayscale of dark).
# Size test + contact sheet: aso/tools/icon_sheet.sh

const OUT := "res://aso/creative/icons/"
const S := 1024
const BLUE := Color(0.3, 0.55, 1.0) # Aircraft.TEAM_COLORS
const GOLD := 1 # Planes.LIVERIES "Golden Ace": the look in builds/appstore/1-battle.png (tools/appstore_shots.gd:49)
const SMOKE := Color(0.55, 0.55, 0.58) # plane.gd _show_damage(): smoke from a hurt part
const RED := Color(1.0, 0.35, 0.3)
const INK := Color(0.08, 0.06, 0.12)
const CHOSEN := "B_duel" # the recommended launch icon (icon-concepts.md)

var _cache := {}


func toon(c: Color) -> ShaderMaterial: # same as main.toon()
	if not _cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		_cache[c] = mat
	return _cache[c]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "src"))
	_run.call_deferred()


func _run() -> void:
	var want := OS.get_cmdline_user_args()
	for c in [["A", "A_hero"], ["B", "B_duel"], ["C", "C_face"]]:
		if want.is_empty() or c[0] in want:
			await _render(c[1])
	quit()


# --- scene helpers -------------------------------------------------------------------------

func plane(kind: String, world: int, color: Color, livery := 0, sticker := 0, rockets := 0, bombs := 0, prop_deg := 30.0, glass := Color(0.15, 0.2, 0.3)) -> Node3D:
	Worlds.index = world # Planes.build reads only the index and STYLE[index]
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var dark := toon(Color(0.2, 0.2, 0.22))
	var parts := Planes.build(kind, root, toon(color), toon(Color(0.95, 0.93, 0.85)), toon(glass), dark, glow, livery)
	Planes.dress(kind, root, parts, rockets, bombs, sticker, 0, dark, toon)
	for p: Node3D in parts.props:
		p.rotation.z = deg_to_rad(prop_deg)
	_drop_struts(root, world)
	Worlds.index = 0
	return root


# Wing struts are 0.05-radius rods that ink into loose black scratches at icon sizes. Planes._merge folds
# them into one mesh per material (with the gear legs), so cut the triangles in the strut zone:
# above the gear, ahead of the tail wheel, outboard of the fuselage stripe.
func _drop_struts(root: Node3D, world: int) -> void:
	var mat := Planes._toon(Planes.STYLE[world].strut)
	for mi in root.get_children():
		if not (mi is MeshInstance3D and mi.material_override == mat):
			continue
		var a: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var c := (v[idx[i]] + v[idx[i + 1]] + v[idx[i + 2]]) / 3.0
			if not (c.y > -0.3 and c.y < 1.0 and c.z < 0.5 and absf(c.x) > 0.7):
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		a[Mesh.ARRAY_INDEX] = keep
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mi.mesh = m


func aim(p: Node3D, at: Vector3, dir: Vector3, roll_deg: float) -> void: # nose (-Z) along dir, then bank
	p.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, deg_to_rad(roll_deg)), at)


# The Shark Mouth is a 1.1 x 0.6 m decal per nose side: a 2 px dot at 60 px. Grow it along the fuselage side.
func grow_mouth(p: Node3D, k: float) -> void:
	for mi in p.get_children():
		if mi is MeshInstance3D and mi.material_override in [toon(Color(0.8, 0.12, 0.12)), toon(Color.WHITE)] and absf(mi.position.x) > 0.5:
			var c := Vector3(mi.position.x, -0.1, Planes.HULL.cub[2] + 1.7)
			mi.transform = Transform3D(Basis.from_scale(Vector3(1, k, k)), c - Basis.from_scale(Vector3(1, k, k)) * c) * mi.transform


func radial(u: float, v: float, c: Vector2, stops: Array) -> Color: # stops: [[dist, Color], ...] ascending
	var d := Vector2(u, v).distance_to(c)
	var col: Color = stops[0][1]
	for i in range(1, stops.size()):
		col = col.lerp(stops[i][1], clampf(inverse_lerp(stops[i - 1][0], stops[i][0], d), 0, 1))
	return col


# --- concepts ------------------------------------------------------------------------------
# Each returns {scene, cam: [pos, look_at, fov], fit: [nodes, fraction, centre], light: travel direction,
# bg: Callable(u, v) -> Color, stroke: [px, Color], shots?: [[from, to, width px], ...] (world points, drawn in 2D with no stroke),
# hit?: [point, radius px] (spark), smoke?: [from, to, radius px start, end] (puffs under the planes)}.
# fit moves the camera so the nodes' projected bounds fill `fraction` of the square around `centre` (0..1).

func concept(name: String) -> Dictionary:
	var sc := Node3D.new()
	match name:
		"A_hero": # Green Valley: one Golden Ace cub, low three-quarter, nose and prop toward the viewer
			var p := plane("cub", 0, BLUE, GOLD, 6, 0, 0, 25.0)
			grow_mouth(p, 1.8)
			aim(p, Vector3.ZERO, Vector3(-1.0, 0.3, -0.5), 24.0) # banked, tips clear of the masked corners
			sc.add_child(p)
			return {scene = sc, cam = [Vector3(-9.0, 2.5, -13.0), Vector3(0, 0, 0), 45.0], fit = [[p], 0.92, Vector2(0.5, 0.5)], light = Vector3(0.6, -0.8, 0.5),
				bg = func(u: float, v: float) -> Color: # cream sky to valley green (1-battle.png), light kept off the cowling
					return radial(u, v, Vector2(0.1, 0.05), [[0.0, Color(0.98, 0.95, 0.78)], [0.55, Color(0.55, 0.8, 0.5)], [1.15, Color(0.1, 0.45, 0.38)]]),
				stroke = [16, INK]}
		"B_duel":
			var hero := plane("cub", 0, BLUE, GOLD, 0, 0, 0, 25.0)
			var hero_at := Vector3(-4.5, -3.5, 0)
			var dir := Vector3(1.0, 0.55, -0.3).normalized()
			aim(hero, hero_at, dir, 15.0)
			sc.add_child(hero)
			var foe := plane("cub", 0, RED, 0, 0, 0, 0, 70.0)
			var foe_at := hero_at + dir * 9.0 + Vector3(0, 0.5, -1.0)
			var foe_dir := Vector3(1.0, 0.25, -0.6).normalized()
			aim(foe, foe_at, foe_dir, 55.0)
			sc.add_child(foe)
			var t := foe_at + Vector3(0, 0.3, 0)
			var shots := []
			for side in [-1.0, 1.0]: # gun muzzles at the wing roots (Planes.dress), converging on the foe
				var g := hero.transform * Vector3(side * 0.93, 0.9, -2.5)
				shots.append([g.lerp(t, 0.02), g.lerp(t, 0.4), 30.0])
				shots.append([g.lerp(t, 0.48), g.lerp(t, 0.95), 40.0])
			var engine := foe.transform * Vector3(0, 0, -3.2)
			return {scene = sc, cam = [Vector3(-2.0, 7.0, 34.0), Vector3(0, 0, 0), 34.0], fit = [[hero, foe], 0.95, Vector2(0.5, 0.5)], light = Vector3(0.35, -0.7, -0.6),
				bg = func(u: float, v: float) -> Color: # pale spot behind the red plane, deep coral behind the gold-winged one
					return radial(u, v, Vector2(0.7, 0.25), [[0.0, Color(1.0, 0.78, 0.4)], [0.45, Color(0.97, 0.55, 0.3)], [0.95, Color(0.85, 0.3, 0.25)]]),
				shots = shots, hit = [t, 70.0], smoke = [engine, engine - foe_dir * 9.0 + Vector3(0, 1.0, 0), 22.0, 70.0],
				stroke = [14, INK]}
		_: # C_face: head-on red cub, wide lens so prop, cowling and windshield are the face and the wings stay in frame
			var p := plane("cub", 0, RED, 0, 0, 0, 0, -45.0, Color(0.55, 0.78, 0.95)) # blades along the wing, off the face
			aim(p, Vector3.ZERO, Vector3(0.05, -0.12, 1.0), 30.0) # banked: the wing runs corner to corner
			sc.add_child(p)
			return {scene = sc, cam = [Vector3(0.0, 0.8, 8.0), Vector3(0, 0, 0), 85.0], fit = [[p], 0.9, Vector2(0.5, 0.5)], light = Vector3(0.45, -0.6, -0.7),
				bg = func(u: float, v: float) -> Color: # Sky Kingdom: deep violet top to lavender-pink haze (3-sky-kingdom.png)
					return Color(0.36, 0.3, 0.72).lerp(Color(0.95, 0.8, 0.95), clampf(v * 1.1, 0, 1)),
				stroke = [16, INK]}


func _points(nodes: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n: Node in nodes:
		var all: Array = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			all.append(n)
		for mi: MeshInstance3D in all:
			if mi.mesh == null:
				continue
			var xf := mi.global_transform
			for v in mi.mesh.get_faces():
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
		var off := ((lo + hi) / 2.0 - centre * S) * (frac / ext) # pixel offset after the dolly
		cam.h_offset += off.x * upp
		cam.v_offset -= off.y * upp


# --- render + composite --------------------------------------------------------------------

func _render(name: String) -> void:
	var c := concept(name)
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
	env.adjustment_saturation = 1.15 # Worlds DEFAULT sky.saturation
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(c.light, Vector3.UP)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	vp.add_child(sun)
	vp.add_child(c.scene)
	var cam := Camera3D.new()
	cam.fov = c.cam[2]
	vp.add_child(cam)
	cam.look_at_from_position(c.cam[0], c.cam[1])
	await process_frame
	_fit(cam, _points(c.fit[0]), c.fit[1], c.fit[2])
	var shots := []
	for s in c.get("shots", []):
		shots.append([cam.unproject_position(s[0]), cam.unproject_position(s[1]), s[2]])
	var fx := {}
	if c.has("hit"):
		fx.hit = [cam.unproject_position(c.hit[0]), c.hit[1]]
	if c.has("smoke"):
		fx.smoke = [cam.unproject_position(c.smoke[0]), cam.unproject_position(c.smoke[1]), c.smoke[2], c.smoke[3]]
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
	fg.save_png(OUT + "src/%s_render.png" % name)
	var halo: Image = _halo(fg, c.stroke[0], c.stroke[1]) if c.stroke[0] > 0 else null
	_compose(fg, [halo], c.bg, shots, fx).save_png(OUT + name + ".png")
	print("wrote ", name)
	if name == CHOSEN: # Apple's dark and tinted appearances (icons/icon_1024x1024_dark, _tinted in the iOS export preset)
		var rim := _halo(fg, c.stroke[0] + 8, Color(1, 1, 1, 0.85)) # the ink halo vanishes on black: a light rim outside it keeps the edge
		var dark := _compose(fg, [rim, halo], func(u: float, v: float) -> Color: return Color(0.12, 0.12, 0.22).lerp(Color(0.04, 0.04, 0.08), v), shots, fx)
		dark.save_png(OUT + name + "_dark.png")
		for y in S:
			for x in S:
				var p := dark.get_pixel(x, y)
				var l := maxf(p.r, maxf(p.g, p.b)) # HSV value, not luma: luma puts the blue plane at mid-grey
				dark.set_pixel(x, y, Color(l, l, l))
		dark.save_png(OUT + name + "_tinted.png")
		print("wrote ", name, "_dark, _tinted")


func _compose(fg: Image, halos: Array, bg: Callable, shots: Array, fx := {}) -> Image:
	var out := _background(bg)
	if fx.has("smoke"): # puffs growing and fading away from the engine, under the planes
		var sm: Array = fx.smoke
		for i in range(7, -1, -1):
			var k := i / 7.0
			_blob(out, sm[0].lerp(sm[1], k), lerpf(sm[2], sm[3], k), SMOKE, 0.95 - 0.6 * k)
	for h in halos:
		if h:
			out.blend_rect(h, Rect2i(0, 0, S, S), Vector2i.ZERO)
	out.blend_rect(fg, Rect2i(0, 0, S, S), Vector2i.ZERO)
	for s in shots:
		_tracer(out, s[0], s[1], s[2])
	if fx.has("hit"): # spark where the fire lands
		_blob(out, fx.hit[0], fx.hit[1], Color(1.0, 0.62, 0.12), 0.9)
		_blob(out, fx.hit[0], fx.hit[1] * 0.45, Color(1.0, 0.98, 0.82), 1.0)
	out.convert(Image.FORMAT_RGB8)
	return out


# Tapered glowing streak from a (thin tail) to b (fat head), like the in-game tracer, no ink stroke.
func _tracer(img: Image, a: Vector2, b: Vector2, w: float) -> void:
	var d := b - a
	var len2 := d.length_squared()
	var lo := (a.min(b) - Vector2.ONE * w * 2.0).floor().max(Vector2.ZERO)
	var hi := (a.max(b) + Vector2.ONE * w * 2.0).ceil().min(Vector2.ONE * (S - 1))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(d) / len2, 0.0, 1.0)
			var r := w * 0.5 * (0.2 + 0.8 * t)
			var dist := p.distance_to(a + d * t)
			var fade := smoothstep(0.0, 0.35, t)
			var glow := (1.0 - smoothstep(r * 0.5, r * 2.2, dist)) * 0.75 * fade
			var core := (1.0 - smoothstep(r * 0.45, r * 0.7, dist)) * fade
			if glow <= 0.0 and core <= 0.0:
				continue
			var c := img.get_pixel(x, y).lerp(Color(1.0, 0.62, 0.12), glow)
			img.set_pixel(x, y, c.lerp(Color(1.0, 0.98, 0.82), core))


func _blob(img: Image, at: Vector2, r: float, col: Color, a: float) -> void: # soft-edged disc
	for y in range(maxi(0, int(at.y - r)), mini(S, int(at.y + r) + 1)):
		for x in range(maxi(0, int(at.x - r)), mini(S, int(at.x + r) + 1)):
			var w := (1.0 - smoothstep(r * 0.6, r, Vector2(x + 0.5, y + 0.5).distance_to(at))) * a
			if w > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, w))


func _background(f: Callable) -> Image:
	var n := 256 # gradient at 256, smooth upscale: cheap and banding-free enough at icon sizes
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, f.call((x + 0.5) / n, (y + 0.5) / n))
	img.resize(S, S, Image.INTERPOLATE_CUBIC)
	return img


# Sticker-style outline: the plane's alpha mask grown by `px` (done at 1/2 scale), filled with `col`.
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
			g.set_pixel(x, y, Color(col, best * col.a))
	g.resize(S, S, Image.INTERPOLATE_CUBIC)
	for y in S: # re-sharpen the upscaled edge: smooth curve, no 2x stair steps
		for x in S:
			g.set_pixel(x, y, Color(col, smoothstep(0.3, 0.7, g.get_pixel(x, y).a / col.a) * col.a))
	return g
