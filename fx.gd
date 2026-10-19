class_name Fx
extends RefCounted

# Fire, smoke and the shot-down sequence: burning plane -> flaming spinning fall with a smoke
# trail -> fireball, debris and a burning crash site that smoulders for a while.

static var _fire_mat: StandardMaterial3D
static var _smoke_mat: ShaderMaterial


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


static func smoke(scale := 1.0, life := 2.5, color := Color(0.1, 0.09, 0.09)) -> CPUParticles3D:
	if not _smoke_mat:
		_smoke_mat = ShaderMaterial.new()
		_smoke_mat.shader = preload("res://toon.gdshader")
		_smoke_mat.set_shader_parameter("specular_strength", 0.0)
		_smoke_mat.set_shader_parameter("rim_color", Color(1, 1, 1, 0))
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
	grow.add_point(Vector2(1, 3.5))
	p.scale_amount_curve = grow
	p.color = color
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
		var ground := Terrain.height(position.x, position.z)
		if position.y <= ground + 1.0 or main.hits_obstacle(position) or t > 12.0:
			Fx.crash(main, Vector3(position.x, maxf(position.y, ground), position.z), vel)
			queue_free()


static func shoot_down(main: Node, body: Node3D, at: Transform3D, vel: Vector3) -> void:
	var w := Wreck.new()
	w.main = main
	w.vel = vel * 0.9 + Vector3(randf_range(-6, 6), randf_range(0, 8), randf_range(-6, 6))
	w.spin = Vector3(0, 0, randf_range(2.0, 6.0) * (1.0 if randf() < 0.5 else -1.0))
	main.add_child(w)
	w.global_transform = at
	var shell: Node3D = body.duplicate()
	shell.show()
	w.add_child(shell)
	var s: float = body.scale.x
	var f := fire(1.3 * s)
	f.position = Vector3(0, 0.5, -1.0) * s
	w.add_child(f)
	var trail := smoke(1.8 * s, 4.5)
	trail.position = Vector3(0, 0.5, 0.5) * s
	w.add_child(trail)
	# Sometimes a wing comes off and tumbles away on its own.
	var parts := shell.get_children().filter(func(c): return c is MeshInstance3D and absf(c.position.x) > 2.0)
	if parts and randf() < 0.5:
		var wing: MeshInstance3D = parts.pick_random()
		var g := wing.global_transform
		shell.remove_child(wing)
		_debris(main, wing, g, w.vel + wing.global_basis.x * 12.0 + Vector3.UP * 6.0, 4.0)


static func crash(main: Node, pos: Vector3, vel: Vector3) -> void:
	main.boom(pos, 2.6)
	var debris_mat: Material = main.toon(Color(0.18, 0.16, 0.15))
	for i in 6:
		var d := MeshInstance3D.new()
		d.mesh = BoxMesh.new()
		d.mesh.size = Vector3(randf_range(0.5, 1.6), randf_range(0.2, 0.6), randf_range(0.5, 1.8))
		d.material_override = debris_mat
		_debris(main, d, Transform3D(Basis(), pos + Vector3.UP), Vector3(randf_range(-25, 25), randf_range(15, 35), randf_range(-25, 25)) + vel * 0.2, 2.5)
	# The crash site keeps burning and smoking for a while.
	var site := Node3D.new()
	main.add_child(site)
	site.global_position = pos
	var f := fire(5.0)
	f.lifetime = 1.1
	f.amount = 70
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 7.0
	site.add_child(f)
	var sm := smoke(4.5, 10.0)
	sm.position.y = 6.0
	sm.spread = 12.0
	sm.initial_velocity_min = 6.0
	sm.initial_velocity_max = 10.0 # rises as a column you can spot from across the map
	site.add_child(sm)
	var tw := site.create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(func(): f.emitting = false)
	tw.tween_interval(4.0)
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
