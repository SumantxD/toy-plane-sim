extends Node3D

# Gamified rocket ballistics, one integrator for flight and for the HUD preview:
#   burn: thrust along velocity for BURN s, then coast; quadratic drag and gravity throughout.
#   guidance: proportional navigation (a = N * LOS-rate x velocity), so it leads the target.
#   Turn authority scales with speed^2, so a coasting rocket gets lazy: hard turns or boost dodge it.
# Same rules as bullets: every peer simulates, only the shooter's copy detonates and reports.
const BURN := 1.6
const THRUST := 170.0
const DRAG := 0.0005
const GRAVITY := 15.0
const NAV := 3.5
const MAX_LATERAL := 160.0 # m/s^2 at REF_SPEED
const REF_SPEED := 300.0
const SEEKER_FOV := 1.05 # ~60 deg
const FUSE := 8.0
const SPLASH := 18.0
const LIFE := 7.0

var rockets := {} # id -> {p, v, t, owner, target, local, mesh, trail}
var count := 0
var trails := ImmediateMesh.new()
var trail_mat := StandardMaterial3D.new()
var rocket_mesh := BoxMesh.new()


func _ready() -> void:
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.vertex_color_use_as_albedo = true
	var trail_node := MeshInstance3D.new()
	trail_node.mesh = trails
	trail_node.material_override = trail_mat
	add_child(trail_node)
	rocket_mesh.size = Vector3(0.5, 0.5, 2.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.95)
	m.emission_enabled = true
	m.emission = Color(1, 0.5, 0.1)
	rocket_mesh.material = m


func launch(owner: Node, target: Node) -> void:
	count += 1
	var id := "%s_%d" % [owner.name, count]
	var p: Vector3 = owner.position - owner.basis.z * 6.0 - owner.basis.y * 1.0
	var v: Vector3 = owner.velocity - owner.basis.z * 20.0
	var tname: String = target.name if target else ""
	_add(id, p, v, owner, tname, true)
	spawn_remote.rpc(id, p, v, owner.name, tname)


# Launch from an arbitrary point/velocity (SAM sites on the ground).
func fire_from(owner: Node, p: Vector3, v: Vector3, target: Node) -> void:
	count += 1
	var id := "%s_%d" % [owner.name, count]
	var tname: String = target.name if target else ""
	_add(id, p, v, owner, tname, true)
	spawn_remote.rpc(id, p, v, owner.name, tname)


@rpc("any_peer", "call_remote", "reliable")
func spawn_remote(id: String, p: Vector3, v: Vector3, owner_name: String, target_name: String) -> void:
	_add(id, p, v, main().find_unit(owner_name), target_name, false)


@rpc("any_peer", "call_remote", "reliable")
func detonate_remote(id: String, p: Vector3) -> void:
	_remove(id)
	main().boom(p)


func _add(id: String, p: Vector3, v: Vector3, owner: Node, target_name: String, local: bool) -> void:
	if not owner:
		return
	Sfx.at(main(), p, Sfx.LAUNCH, -6.0)
	var m := MeshInstance3D.new()
	m.mesh = rocket_mesh
	add_child(m)
	rockets[id] = {p = p, v = v, t = 0.0, owner = owner, team = owner.team, local = local, mesh = m, trail = [],
		target = main().players.get_node_or_null(target_name) if target_name else null}


func _remove(id: String) -> void:
	if rockets.has(id):
		rockets[id].mesh.queue_free()
		rockets.erase(id)


# One physics step. Shared by real rockets and the preview, so the preview never lies.
static func step(p: Vector3, v: Vector3, t: float, target: Node, dt: float) -> Array:
	var speed := maxf(v.length(), 1.0)
	var a := Vector3.DOWN * GRAVITY - v * speed * DRAG
	if t < BURN:
		a += v / speed * THRUST
	if target:
		var r: Vector3 = target.position - p
		var rv: Vector3 = target.vel_estimate() - v
		var los_rate := r.cross(rv) / maxf(r.length_squared(), 1.0)
		var lateral := NAV * los_rate.cross(v) + Vector3.UP * GRAVITY
		lateral -= v / speed * lateral.dot(v / speed) # steering only, no free thrust
		a += lateral.limit_length(MAX_LATERAL * pow(speed / REF_SPEED, 2.0))
	v += a * dt
	return [p + v * dt, v]


func predict(p: Vector3, v: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var t := 0.0
	while t < 4.0:
		for i in 5:
			var s := step(p, v, t, null, 0.02)
			p = s[0]
			v = s[1]
			t += 0.02
		pts.append(p)
		if p.y < Terrain.height(p.x, p.z):
			break
	return pts


func incoming(plane: Node) -> bool:
	return rockets.values().any(func(r): return is_instance_valid(r.target) and r.target == plane)


func _process(dt: float) -> void:
	for id in rockets.keys():
		var r: Dictionary = rockets[id]
		if not is_instance_valid(r.target) or not r.target.is_inside_tree() or not r.target.alive or r.v.angle_to(r.target.position - r.p) > SEEKER_FOV:
			r.target = null # lost lock
		var a: Vector3 = r.p
		var s := step(r.p, r.v, r.t, r.target, dt)
		r.p = s[0]
		r.v = s[1]
		r.t += dt
		r.mesh.global_transform = Transform3D(Basis.looking_at(r.v), r.p)
		r.trail.append(r.p)
		if r.trail.size() > 40:
			r.trail.pop_front()
		var hit: bool = main().hits_ground(r.p)
		if not hit:
			for t in get_tree().get_nodes_in_group("targets"):
				if t.alive and t.team != r.team and _seg_dist(a, r.p, t.position) < FUSE + t.hit_radius:
					hit = true
					break
		if hit and r.local:
			_explode(id, r)
		elif hit or r.t > LIFE:
			_remove(id) # remote copies wait for the shooter's verdict; this one is just visual
	_draw_trails()


func _explode(id: String, r: Dictionary) -> void:
	for t in get_tree().get_nodes_in_group("targets"):
		if t.alive and t.team != r.team and t.position.distance_to(r.p) < SPLASH + t.hit_radius and is_instance_valid(r.owner):
			r.owner.report_hit(t, 1, t.component_at(r.p))
	main().boom(r.p)
	detonate_remote.rpc(id, r.p)
	_remove(id)


func _draw_trails() -> void:
	trails.clear_surfaces()
	for r in rockets.values():
		if r.trail.size() < 2:
			continue
		trails.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in r.trail.size():
			trails.surface_set_color(Color(1, 1, 1, float(i) / r.trail.size() * 0.8))
			trails.surface_add_vertex(r.trail[i])
		trails.surface_end()


func main() -> Node:
	return get_tree().current_scene


static func _seg_dist(a: Vector3, b: Vector3, c: Vector3) -> float:
	var d := b - a
	var k := clampf((c - a).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
	return (a + d * k).distance_to(c)
