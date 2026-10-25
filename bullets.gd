extends MultiMeshInstance3D

# Every peer draws every tracer; only the shooter's own copy tests for hits
# against what that shooter sees (favor-the-shooter, no server rewind).
# ponytail: trusts the shooter's hit claims; fine among friends, add server validation for public servers.
const LIFE := 1.2 # ~780 m at 650 m/s
const MAX := 1024

var shots: Array = [] # {p, v, t, owner, local}


func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.25, 6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(3, 2.2, 0.6)
	mesh.material = mat
	multimesh.mesh = mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func fire(p: Vector3, v: Vector3, owner: Node, local: bool) -> void:
	if shots.size() < MAX:
		shots.append({p = p, v = v, t = LIFE, owner = owner, local = local})


var whiz_cd := 0.0


func _process(dt: float) -> void:
	var targets := get_tree().get_nodes_in_group("targets")
	# Enemy rounds passing close to *you* snap past your ears.
	var me: Node = get_tree().current_scene.players.get_node_or_null(str(multiplayer.get_unique_id()))
	whiz_cd -= dt
	for s in shots:
		var a: Vector3 = s.p
		s.p += s.v * dt
		s.t -= dt
		if me and me.alive and whiz_cd <= 0.0 and not s.get("whizzed", false) and is_instance_valid(s.owner) and s.owner.team != me.team:
			if _closest(a, s.p, me.position).distance_to(me.position) < 22.0:
				s.whizzed = true
				whiz_cd = 0.12
				Sfx.ui(self, Sfx.WHIZ, -1.0, randf_range(0.85, 1.2))
		if get_tree().current_scene.hits_ground(s.p):
			s.t = 0.0
		elif s.local and is_instance_valid(s.owner):
			for t in targets:
				if t != s.owner and t.alive and t.team != s.owner.team and _seg_hits(a, s.p, t.position, t.hit_radius + (0.0 if s.owner.get("is_ai") else 4.0)): # players' rounds forgive a near miss
					s.owner.report_hit(t, 0, t.component_at(_closest(a, s.p, t.position)))
					s.t = 0.0
					break
	shots = shots.filter(func(s): return s.t > 0.0)
	multimesh.visible_instance_count = shots.size()
	for i in shots.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(shots[i].v), shots[i].p))


static func _seg_hits(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	return _closest(a, b, c).distance_squared_to(c) < r * r


static func _closest(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var d := b - a
	return a + d * clampf((c - a).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
