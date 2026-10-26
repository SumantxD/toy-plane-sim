class_name Fx
extends RefCounted

# Fire, smoke and the shot-down sequence: burning plane -> flaming spinning fall with a smoke
# trail -> fireball, debris and a burning crash site that smoulders for a while.

static var _fire_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _smoke_fade: Gradient
const FAR := 800.0 # effects further than this from the camera skip their particles
const MAX_SITES := 4 # burning crash sites / falling wrecks at once; the oldest give way
static var _sites: Array = []
static var _wrecks: Array = []
static var _puffs: Array = [] # idle flak puffs for reuse


static func far(main: Node, at: Vector3) -> bool:
	var cam := main.get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_squared_to(at) > FAR * FAR


# Keeps the newest few of `list` (instance ids); `drop` handles the oldest live one past the cap.
static func _cap(list: Array, n: Node, drop: Callable) -> void:
	list.assign(list.filter(func(id): return is_instance_valid(instance_from_id(id))))
	while list.size() >= MAX_SITES:
		drop.call(instance_from_id(list.pop_front()))
	list.append(n.get_instance_id())


static func fire(scale := 1.0) -> CPUParticles3D:
	if not _fire_mat:
		_fire_mat = StandardMaterial3D.new()
		_fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fire_mat.vertex_color_use_as_albedo = true
		_fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fire_mat.albedo_color = Color(3.0, 2.2, 1.2) # HDR so the glow picks it up
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.55
	p.local_coords = false
	var m := SphereMesh.new()
	m.radius = 0.8 * scale
	m.height = 1.6 * scale
	m.radial_segments = 6
	m.rings = 3
	m.material = _fire_mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.0 * scale
	p.initial_velocity_max = 4.0 * scale
	p.gravity = Vector3(0, 3, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	g.add_point(0.35, Color(1.0, 0.5, 0.1, 0.95))
	g.set_color(g.get_point_count() - 1, Color(0.35, 0.05, 0.0, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func smoke(scale := 1.0, life := 2.5, color := Color(0.22, 0.21, 0.21)) -> CPUParticles3D:
	if not _smoke_mat:
		_smoke_mat = StandardMaterial3D.new() # soft see-through puffs, not shiny solid balls
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_fade = Gradient.new() # multiplies p.color: thickest early, gone well before the puffs get big
		_smoke_fade.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 0.7])
		_smoke_fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0)]) # never above 1: glow would make old puffs shine
	var p := CPUParticles3D.new()
	p.amount = 64
	p.lifetime = life
	p.local_coords = false
	var m := SphereMesh.new()
	m.radius = 1.5 * scale
	m.height = 3.0 * scale
	m.radial_segments = 6
	m.rings = 3
	m.material = _smoke_mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 45.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0 * scale
	p.gravity = Vector3(0, 2.5, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = grow
	p.color = color
	p.color_ramp = _smoke_fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# The doomed plane keeps its momentum, noses into a dive and spins, burning all the way down.
class Wreck extends Node3D:
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var main: Node
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		vel += Vector3.DOWN * 16.0 * dt
		vel *= 1.0 - 0.15 * dt # drag
		position += vel * dt
		# Nose follows the falling path, plus a tumbling roll.
		if vel.length() > 1.0:
			var dir := vel.normalized()
			var want := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
			basis = basis.slerp(want, minf(1.0, dt * 1.2)).orthonormalized()
		rotate_object_local(Vector3.FORWARD, spin.z * dt)
		var ground := Terrain.ground(position.x, position.z)
		if position.y <= ground + 1.0 or main.hits_obstacle(position) or t > 12.0:
			Fx.crash(main, Vector3(position.x, maxf(position.y, ground), position.z), vel)
			queue_free()


# A balloon bursts: confetti and rubber scraps fly out and flutter down; no fire, no falling wreck.
static func pop(main: Node, at: Vector3, big: bool) -> void:
	Sfx.at(main, at, Sfx.POP, 8.0 if big else 4.0, 1600.0)
	if far(main, at):
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 70 if big else 36
	p.lifetime = 2.4
	p.local_coords = false
	var bit := BoxMesh.new()
	bit.size = Vector3(0.9, 0.06, 0.6) * (1.4 if big else 1.0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bit.material = mat
	p.mesh = bit
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 24.0 if big else 16.0
	p.gravity = Vector3(0, -9, 0)
	p.damping_min = 3.0
	p.damping_max = 6.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.particle_flag_rotate_y = true
	var colors := Gradient.new() # each scrap gets a colour from this
	colors.colors = PackedColorArray([Color(1, 0.8, 0.2), Color(1, 0.3, 0.3), Color(0.3, 0.6, 1), Color(0.5, 1, 0.4), Color(1, 1, 1)]) if big \
		else PackedColorArray([Color(0.95, 0.35, 0.3), Color(1, 0.6, 0.4), Color(1, 1, 1)])
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0]) if big else PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_initial_ramp = colors
	p.finished.connect(p.queue_free)
	main.add_child(p)
	p.global_position = at
	p.restart() # a one-shot emitter only bursts on restart once it's in the tree


static func shoot_down(main: Node, body: Node3D, at: Transform3D, vel: Vector3) -> void:
	var w := Wreck.new()
	w.main = main
	w.vel = vel * 0.9 + Vector3(randf_range(-6, 6), randf_range(0, 8), randf_range(-6, 6))
	w.spin = Vector3(0, 0, randf_range(2.0, 6.0) * (1.0 if randf() < 0.5 else -1.0))
	main.add_child(w)
	w.global_transform = at
	var shell := _shell(body)
	w.add_child(shell)
	if far(main, at.origin):
		return
	_cap(_wrecks, w, func(old: Node) -> void:
		for c in old.get_children():
			if c is CPUParticles3D:
				c.emitting = false)
	var s: float = body.scale.x
	var f := fire(1.3 * s)
	f.position = Vector3(0, 0.5, -1.0) * s
	w.add_child(f)
	var trail := smoke(1.8 * s, 4.5)
	trail.position = Vector3(0, 0.5, 0.5) * s
	w.add_child(trail)
	# Sometimes a wing comes off and tumbles away on its own.
	var parts := shell.get_children().filter(func(c): return c.has_meta("top") and c is MeshInstance3D and absf(c.position.x) > 2.0)
	if parts and randf() < 0.5:
		var wing: MeshInstance3D = parts.pick_random()
		var g := wing.global_transform
		shell.remove_child(wing)
		_debris(main, wing, g, w.vel + g.basis.x.normalized() * 12.0 + Vector3.UP * 6.0, 4.0)


# The wreck's look without duplicate()-ing the plane's node tree (that cost a few ms per kill on phones):
# its visible meshes flattened under one node, sharing meshes and materials, plus any smoke trails.
static func _shell(body: Node3D) -> Node3D:
	var shell := Node3D.new()
	shell.transform = body.transform
	var inv := body.global_transform.affine_inverse()
	for n in body.find_children("*", "GeometryInstance3D", true, false):
		var shown := true
		var up: Node = n
		while up != body and shown:
			shown = up.visible
			up = up.get_parent()
		if not shown:
			continue
		var c: GeometryInstance3D
		if n is MeshInstance3D:
			c = MeshInstance3D.new()
			c.mesh = n.mesh
			c.material_override = n.material_override
			c.cast_shadow = n.cast_shadow
		elif n is CPUParticles3D:
			c = n.duplicate()
		else:
			continue
		c.transform = inv * n.global_transform
		if n.get_parent() == body:
			c.set_meta("top", true) # (a wing that may come off)
		shell.add_child(c)
	return shell


static func crash(main: Node, pos: Vector3, vel: Vector3) -> void:
	main.boom(pos, 2.6)
	var near := not far(main, pos)
	var debris_mat: Material = main.toon(Color(0.18, 0.16, 0.15))
	for i in 6 if near else 0:
		var d := MeshInstance3D.new()
		d.mesh = BoxMesh.new()
		d.mesh.size = Vector3(randf_range(0.5, 1.6), randf_range(0.2, 0.6), randf_range(0.5, 1.8))
		d.material_override = debris_mat
		_debris(main, d, Transform3D(Basis(), pos + Vector3.UP), Vector3(randf_range(-25, 25), randf_range(15, 35), randf_range(-25, 25)) + vel * 0.2, 2.5)
	# The crash site keeps burning and smoking for a while (it stands still: particles step at 30 Hz).
	var site := Node3D.new()
	main.add_child(site)
	site.global_position = pos
	_cap(_sites, site, func(old: Node) -> void: old.queue_free())
	var f := fire(5.0)
	f.lifetime = 1.1
	f.amount = 70
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 7.0
	f.fixed_fps = 30
	f.emitting = near
	site.add_child(f)
	var sm := smoke(4.5, 6.0)
	sm.amount = 40
	sm.position.y = 6.0
	sm.spread = 12.0
	sm.initial_velocity_min = 6.0
	sm.initial_velocity_max = 10.0 # rises as a column you can spot from across the map
	sm.fixed_fps = 30
	site.add_child(sm)
	var tw := site.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func(): f.emitting = false)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): sm.emitting = false)
	tw.tween_interval(6.0)
	tw.tween_callback(site.queue_free)


static func _debris(main: Node, piece: Node3D, at: Transform3D, v: Vector3, life: float) -> void:
	main.add_child(piece)
	piece.global_transform = at
	var start := at.origin
	var spin := Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var b0 := at.basis
	var tw := piece.create_tween()
	tw.tween_method(func(t: float):
		piece.position = start + v * t + Vector3.DOWN * 9.0 * t * t
		piece.basis = b0 * Basis.from_euler(spin * t), 0.0, life, life)
	tw.tween_callback(piece.queue_free)


# Cartoon flak: a black puff with an orange core, a small bang. Puffs are reused.
static func flak(main: Node, at: Vector3) -> void:
	main.boom(at, 0.45)
	Sfx.at(main, at, Sfx.BOOMS[0], -2.0, 1500.0)
	if far(main, at):
		return
	var pick = null # untyped: the static pool can hold puffs freed by a scene reload, and a typed var rejects those
	while _puffs and not is_instance_valid(pick):
		pick = _puffs.pop_back()
	var puff: MeshInstance3D = pick if is_instance_valid(pick) else null
	if not puff:
		puff = MeshInstance3D.new()
		puff.mesh = SphereMesh.new()
		puff.mesh.radial_segments = 8
		puff.mesh.rings = 4
		var m := StandardMaterial3D.new() # a soft, see-through puff that thins away (not a solid shiny ball)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = m
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(puff)
	var soot: StandardMaterial3D = puff.material_override
	soot.albedo_color = Color(0.2, 0.19, 0.19, 0.7)
	puff.global_position = at
	puff.scale = Vector3.ONE * 4.0
	puff.show()
	var tw := puff.create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * 14.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(soot, "albedo_color:a", 0.0, 1.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		puff.hide()
		_puffs.append(puff))


# Movie-style flare dump: two streams kicked out left and right behind the plane, each flare a hot
# white-orange ball dragging smoke, drooping as it slows: the "angel wings" V. Lives in world space.
static func flare_burst(plane: Node3D) -> void:
	if far(plane, plane.global_position):
		return
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(5.0, 3.6, 1.6)
	var ball := SphereMesh.new()
	ball.radius = 0.7
	ball.height = 1.4
	ball.radial_segments = 8
	ball.rings = 4
	ball.material = glow
	for side in [-1.0, 1.0]:
		var dir := Vector3(side, -0.45, 0.25).normalized() # sideways, down, a little back (plane-local)
		var hot := CPUParticles3D.new()
		hot.mesh = ball
		hot.amount = 32
		hot.lifetime = 2.0
		hot.local_coords = false
		hot.direction = dir
		hot.spread = 6.0
		hot.initial_velocity_min = 50.0
		hot.initial_velocity_max = 64.0
		hot.damping_min = 14.0
		hot.damping_max = 18.0
		hot.gravity = Vector3(0, -9, 0)
		hot.scale_amount_curve = Curve.new()
		hot.scale_amount_curve.add_point(Vector2(0, 1.3))
		hot.scale_amount_curve.add_point(Vector2(0.7, 0.8))
		hot.scale_amount_curve.add_point(Vector2(1, 0.0))
		var trail := smoke(0.75, 2.6, Color(0.92, 0.92, 0.9))
		trail.amount = 90
		trail.direction = dir
		trail.spread = 8.0
		trail.initial_velocity_min = 46.0
		trail.initial_velocity_max = 60.0
		trail.damping_min = 14.0
		trail.damping_max = 18.0
		trail.gravity = Vector3(0, -6, 0)
		for e in [trail, hot]:
			plane.add_child(e)
			e.position = Vector3(side * 1.5, -0.8, 2.0)
			e.emitting = true
			# Dump for 0.6 s (about 10 flares a side), then let them burn out where they fell.
			var eid: int = e.get_instance_id() # never capture the node: the plane may be freed first
			plane.get_tree().create_timer(0.6).timeout.connect(func():
				var n = instance_from_id(eid)
				if is_instance_valid(n):
					n.emitting = false)
			plane.get_tree().create_timer(3.4).timeout.connect(func():
				var n = instance_from_id(eid)
				if is_instance_valid(n):
					n.queue_free())
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 6.0
	flash.omni_range = 80.0
	plane.add_child(flash)
	flash.position = Vector3(0, -2, 6)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 1.2).finished.connect(flash.queue_free)


# Paid kill effects (Planes.KILL_FX), played where the victim was hit, for everyone to see.
static func kill_effect(main: Node, at: Vector3, kind: int) -> void:
	var near := not far(main, at) # far away: just the sound
	match kind:
		1:
			for i in 3 if near else 0: # fireworks: three staggered gold/red/blue starbursts
				main.create_tween().tween_callback(func(): # dies with main (a menu reload mid-show)
					_burst(main, at + Vector3(randf_range(-12, 12), 8.0 + i * 6.0, randf_range(-12, 12)), [Color(1.8, 1.4, 0.4), Color(1.7, 0.4, 0.35), Color(0.5, 0.9, 1.8)][i])).set_delay(i * 0.25)
			Sfx.at(main, at, Sfx.POP, 6.0, 2400.0)
		2:
			if near:
				_lightning(main, at)
			else:
				Sfx.at(main, at, Sfx.THUNDER, 4.0, 3000.0)
		3:
			if near:
				_blaze(main, at)


static func _burst(main: Node, at: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 90
	p.lifetime = 1.6
	p.local_coords = false
	var spark := SphereMesh.new()
	spark.radius = 0.35
	spark.height = 0.7
	spark.radial_segments = 4
	spark.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material = mat
	p.mesh = spark
	p.spread = 180.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 8.0
	p.damping_max = 12.0
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(col, 1.0), Color(col, 0.0)])
	p.color_ramp = fade
	p.finished.connect(p.queue_free)
	main.add_child(p)
	p.global_position = at
	p.restart()


static func _lightning(main: Node, at: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.6, 1.8, 2.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt.mesh = im
	bolt.material_override = mat
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := at + Vector3(0, 90, 0)
	while p.y > at.y: # jagged zig-zag down to the hit
		var q := Vector3(at.x + randf_range(-6, 6), p.y - randf_range(8, 16), at.z + randf_range(-6, 6))
		q.y = maxf(q.y, at.y)
		var w := Vector3(0.6, 0, 0)
		for v in [p - w, p + w, q + w, p - w, q + w, q - w]:
			im.surface_add_vertex(v)
		p = q
	im.surface_end()
	main.add_child(bolt)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.7, 0.8, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 120.0
	main.add_child(flash)
	flash.global_position = at
	Sfx.at(main, at, Sfx.THUNDER, 4.0, 3000.0)
	var tw := bolt.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.parallel().tween_property(flash, "light_energy", 0.0, 0.45)
	tw.tween_callback(bolt.queue_free)
	tw.tween_callback(flash.queue_free)


static func _blaze(main: Node, at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.8, 0.7, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	main.add_child(ring)
	ring.global_position = at
	var f := fire(2.5)
	f.fixed_fps = 30
	main.add_child(f)
	f.global_position = at
	var fid := f.get_instance_id() # never capture the node: a scene change may free it first
	main.get_tree().create_timer(1.0).timeout.connect(func():
		var n = instance_from_id(fid)
		if is_instance_valid(n):
			n.emitting = false)
	main.get_tree().create_timer(3.5).timeout.connect(func():
		var n = instance_from_id(fid)
		if is_instance_valid(n):
			n.queue_free())
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 30.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(ring.queue_free)
