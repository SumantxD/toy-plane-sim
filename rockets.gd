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
const PLAYER_GRIP := 1.6 # players' rockets (not AI ones) turn harder, see wider and fuse further: easy to land
const FUSE := 8.0
const SPLASH := 18.0
const LIFE := 7.0
const BOMB_SPLASH := 35.0
const BOMB_DRAG := 0.0002

var rockets := {} # id -> {p, v, t, owner, target, local, mesh, trail}
var count := 0
var trails := ImmediateMesh.new()
var trail_mat := StandardMaterial3D.new()
var rocket_mesh := CylinderMesh.new()
var nose_mesh := CylinderMesh.new()
var fin_mesh := BoxMesh.new()
var glow_mesh := SphereMesh.new()
var bomb_mesh := CapsuleMesh.new()


func _ready() -> void:
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.vertex_color_use_as_albedo = true
	var trail_node := MeshInstance3D.new()
	trail_node.mesh = trails
	trail_node.material_override = trail_mat
	add_child(trail_node)
	rocket_mesh.top_radius = 0.28
	rocket_mesh.bottom_radius = 0.28
	rocket_mesh.height = 2.6
	rocket_mesh.radial_segments = 8
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.28
	nose_mesh.height = 0.8
	nose_mesh.radial_segments = 8
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.2, 0.15)
	nose_mesh.material = red
	fin_mesh.size = Vector3(1.1, 0.06, 0.6)
	var fin := StandardMaterial3D.new()
	fin.albedo_color = Color(0.25, 0.25, 0.28)
	fin_mesh.material = fin
	glow_mesh.radius = 0.55
	glow_mesh.height = 1.1
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(4.0, 2.2, 0.6) # over-bright: blooms into a flame you can spot
	glow_mesh.material = hot
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.95)
	m.emission_enabled = true
	m.emission = Color(1, 0.5, 0.1)
	rocket_mesh.material = m
	bomb_mesh.radius = 0.55
	bomb_mesh.height = 2.6
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.22, 0.2)
	bomb_mesh.material = bm


func launch(owner: Node, target: Node) -> void:
	count += 1
	var id := "%s_%d" % [owner.name, count]
	var p: Vector3 = owner.position - owner.basis.z * 6.0 - owner.basis.y * 1.0
	var v: Vector3 = owner.velocity - owner.basis.z * 20.0
	var tname: String = target.name if target else ""
	_add(id, p, v, owner, tname, true)
	spawn_remote.rpc(id, p, v, owner.name, tname, false, main().gs.match_id)


# Bombs: inherit the plane's velocity and fall; same shooter-decides rule as rockets.
func drop_bomb(owner: Node) -> void:
	count += 1
	var id := "%s_%d" % [owner.name, count]
	var p: Vector3 = owner.position + Vector3.DOWN * 2.0
	_add(id, p, owner.velocity, owner, "", true, true)
	spawn_remote.rpc(id, p, owner.velocity, owner.name, "", true, main().gs.match_id)


static func bomb_step(p: Vector3, v: Vector3, dt: float) -> Array:
	v += (Vector3.DOWN * GRAVITY - v * v.length() * BOMB_DRAG) * dt
	return [p + v * dt, v]


# Where a bomb dropped now would hit the ground (HUD marker, AI release timing). Coarse 0.1 s steps
# (velocity offset half a step: tracks the true arc), then the crossing step is bisected.
func bomb_impact(p: Vector3, v: Vector3) -> Vector3:
	const DT := 0.1
	var m := main()
	v += (Vector3.DOWN * GRAVITY - v * v.length() * BOMB_DRAG) * (DT / 2.0)
	for i in 300:
		var a := p
		p += v * DT
		v += (Vector3.DOWN * GRAVITY - v * v.length() * BOMB_DRAG) * DT
		if m.hits_ground(p):
			for k in 4:
				var mid := (a + p) / 2.0
				if m.hits_ground(mid):
					p = mid
				else:
					a = mid
			break
	return p


# Flares: rockets chasing `plane` lose it and fly on dumb.
func decoy(plane: Node) -> void:
	for r in rockets.values():
		if r.target == plane:
			r.target = null


# Launch from an arbitrary point/velocity (SAM sites on the ground).
func fire_from(owner: Node, p: Vector3, v: Vector3, target: Node) -> void:
	count += 1
	var id := "%s_%d" % [owner.name, count]
	var tname: String = target.name if target else ""
	_add(id, p, v, owner, tname, true)
	spawn_remote.rpc(id, p, v, owner.name, tname, false, main().gs.match_id)


@rpc("any_peer", "call_remote", "reliable")
func spawn_remote(id: String, p: Vector3, v: Vector3, owner_name: String, target_name: String, bomb: bool, mid: int) -> void:
	if main().stale(mid):
		return
	var owner: Node = main().find_unit(owner_name)
	var from := multiplayer.get_remote_sender_id()
	# Only a plane's own peer may launch its ordnance (no rockets in someone else's name), and only what it carries.
	if not owner or owner.get_multiplayer_authority() != from or not (p.is_finite() and v.is_finite()) or rockets.has(id):
		main().tally("launch_forged" if owner else "launch_owner")
		return
	if from != 1 and not main().note_launch(owner, id, p, v, bomb):
		return
	_add(id, p, v, owner, target_name, false, bomb)


@rpc("any_peer", "call_remote", "reliable")
func detonate_remote(id: String, p: Vector3) -> void:
	var owner: Node = main().find_unit(id.rsplit("_", true, 1)[0])
	var from := multiplayer.get_remote_sender_id()
	if not p.is_finite() or not owner or owner.get_multiplayer_authority() != from or from != 1 and not main()._allow(from, "boom", 2.0, 12.0):
		main().tally("boom_forged")
		return # only the shooter decides where its own rocket went off
	_remove(id)
	main().boom(p)


func _add(id: String, p: Vector3, v: Vector3, owner: Node, target_name: String, local: bool, bomb := false) -> void:
	if not owner:
		return
	if not bomb:
		Sfx.at(main(), p, Sfx.LAUNCHES.pick_random(), -6.0)
	else:
		Sfx.at(main(), p, Sfx.BOMB_WHISTLE, 0.0, 1500.0)
	var m: Node3D = _missile() if not bomb else MeshInstance3D.new()
	if bomb:
		m.mesh = bomb_mesh
	add_child(m)
	rockets[id] = {p = p, v = v, t = 0.0, owner = owner, team = owner.team, local = local, mesh = m, trail = [], bomb = bomb,
		target = main().find_unit(target_name) if target_name else null, # planes, turrets or HQs
		grip = PLAYER_GRIP if not bomb and owner.get("is_ai") == false else 1.0}


func _remove(id: String) -> void:
	if rockets.has(id):
		var smoke := rockets[id].mesh.get_node_or_null("Smoke") as CPUParticles3D
		if smoke: # the trail hangs in the air and fades instead of vanishing with the missile
			smoke.reparent(self)
			smoke.emitting = false
			var sid := smoke.get_instance_id()
			get_tree().create_timer(smoke.lifetime + 0.2).timeout.connect(func():
				var s = instance_from_id(sid)
				if is_instance_valid(s):
					s.queue_free())
		rockets[id].mesh.queue_free()
		rockets.erase(id)


# White body, red nose, four fins, an over-bright exhaust flame and a thick smoke trail behind it.
func _missile() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = rocket_mesh
	body.rotation_degrees.x = 90
	root.add_child(body)
	var nose := MeshInstance3D.new()
	nose.mesh = nose_mesh
	nose.rotation_degrees.x = -90
	nose.position.z = -1.7
	root.add_child(nose)
	for k in 2:
		var f := MeshInstance3D.new()
		f.mesh = fin_mesh
		f.position.z = 1.0
		f.rotation_degrees.z = 90.0 * k
		root.add_child(f)
	var flame := MeshInstance3D.new()
	flame.mesh = glow_mesh
	flame.position.z = 1.6
	flame.scale = Vector3(1, 1, 1.8)
	root.add_child(flame)
	var smoke := Fx.smoke(0.7, 1.8, Color(0.93, 0.93, 0.9))
	smoke.name = "Smoke"
	smoke.amount = 70
	smoke.direction = Vector3(0, 0, 1)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 5.0
	smoke.gravity = Vector3(0, 1.5, 0)
	smoke.position.z = 1.8
	root.add_child(smoke)
	return root


# One physics step. Shared by real rockets and the preview, so the preview never lies.
static func step(p: Vector3, v: Vector3, t: float, target: Node, dt: float, grip := 1.0) -> Array:
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
		a += lateral.limit_length(MAX_LATERAL * grip * pow(speed / REF_SPEED, 2.0))
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
		if p.y < Terrain.ground(p.x, p.z):
			break
	return pts


func incoming(plane: Node) -> bool:
	for r in rockets.values():
		if is_instance_valid(r.target) and r.target == plane:
			return true
	return false


var live: Array[Node] = [] # this frame's live targets (fuse checks)

func _process(dt: float) -> void:
	live.clear()
	if not rockets.is_empty():
		for t in get_tree().get_nodes_in_group("targets"):
			if t.alive:
				live.append(t)
	for id in rockets.keys():
		var r: Dictionary = rockets[id]
		if r.bomb:
			_bomb_tick(id, r, dt)
			continue
		if not is_instance_valid(r.target) or not r.target.is_inside_tree() or not r.target.alive or r.v.angle_to(r.target.position - r.p) > SEEKER_FOV * r.grip:
			r.target = null # lost lock
		var a: Vector3 = r.p
		var s := step(r.p, r.v, r.t, r.target, dt, r.grip)
		r.p = s[0]
		r.v = s[1]
		r.t += dt
		r.mesh.global_transform = Transform3D(Basis.looking_at(r.v), r.p)
		if r.t >= r.get("trail_t", 0.0): # trail points at 30 Hz; the drawn line still ends at the rocket
			r.trail_t = r.t + 1.0 / 30.0
			r.trail.append(r.p)
			if r.trail.size() > 20:
				r.trail.pop_front()
		var hit: bool = main().hits_ground(r.p)
		if not hit:
			for t in live:
				if t.team != r.team and t.alive and _seg_dist(a, r.p, t.position) < FUSE * r.grip + t.hit_radius:
					hit = true
					break
		if hit and r.local:
			_explode(id, r)
		elif hit or r.t > LIFE:
			_remove(id) # remote copies wait for the shooter's verdict; this one is just visual
	_draw_trails()


func _bomb_tick(id: String, r: Dictionary, dt: float) -> void:
	var a: Vector3 = r.p
	var s := bomb_step(r.p, r.v, dt)
	r.p = s[0]
	r.v = s[1]
	r.t += dt
	r.mesh.global_transform = Transform3D(Basis.looking_at(r.v) * Basis(Vector3.RIGHT, PI / 2.0), r.p)
	var hit: bool = main().hits_ground(r.p)
	if not hit:
		for t in live:
			if t.team != r.team and t.alive and _seg_dist(a, r.p, t.position) < 4.0 + t.hit_radius:
				hit = true
				break
	if hit and r.local:
		for t in get_tree().get_nodes_in_group("targets"):
			if t.alive and t.team != r.team and t.position.distance_to(r.p) < BOMB_SPLASH + t.hit_radius and is_instance_valid(r.owner):
				r.owner.report_hit(t, 2, -1)
		main().boom(r.p, 2.2)
		detonate_remote.rpc(id, r.p)
		_remove(id)
	elif hit or r.t > 30.0:
		_remove(id)


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
		trails.surface_set_color(Color(1, 1, 1, 0.8))
		trails.surface_add_vertex(r.p)
		trails.surface_end()


func main() -> Node:
	return get_tree().current_scene


static func _seg_dist(a: Vector3, b: Vector3, c: Vector3) -> float:
	var d := b - a
	var k := clampf((c - a).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
	return (a + d * k).distance_to(c)
