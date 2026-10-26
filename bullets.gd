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
		shots.append({p = p, v = v, t = LIFE, owner = owner, local = local, b = Basis.looking_at(v)})


var whiz_cd := 0.0


func _process(dt: float) -> void:
	var main := get_tree().current_scene
	# Live targets once per frame (not per round): position, reach and team in packed arrays.
	var tn: Array[Node] = []
	var tp := PackedVector3Array()
	var tr := PackedFloat32Array()
	var tt := PackedInt32Array()
	for t in get_tree().get_nodes_in_group("targets"):
		if t.alive:
			tn.append(t)
			tp.append(t.position)
			tr.append(t.hit_radius)
			tt.append(t.team)
	# Enemy rounds passing close to *you* snap past your ears.
	var me: Node = main.players.get_node_or_null(str(multiplayer.get_unique_id()))
	whiz_cd -= dt
	var n := 0
	for s in shots:
		var a: Vector3 = s.p
		s.p += s.v * dt
		s.t -= dt
		if me and me.alive and whiz_cd <= 0.0 and not s.get("whizzed", false) and is_instance_valid(s.owner) and s.owner.team != me.team:
			if _closest(a, s.p, me.position).distance_to(me.position) < 22.0:
				s.whizzed = true
				whiz_cd = 0.12
				Sfx.ui(self, Sfx.WHIZ, -1.0, randf_range(0.85, 1.2))
		if main.hits_ground(s.p):
			s.t = 0.0
		elif s.local and is_instance_valid(s.owner):
			var team: int = s.owner.team
			var slack := 0.0 if s.owner.get("is_ai") else 4.0 # players' rounds forgive a near miss
			var mid: Vector3 = (a + s.p) * 0.5
			var half := a.distance_to(s.p) * 0.5
			for i in tn.size():
				var r := tr[i] + slack
				if tt[i] != team and mid.distance_squared_to(tp[i]) < (half + r) * (half + r) and tn[i] != s.owner and tn[i].alive and _seg_hits(a, s.p, tp[i], r):
					s.owner.report_hit(tn[i], 0, tn[i].component_at(_closest(a, s.p, tp[i])))
					s.t = 0.0
					break
		if s.t > 0.0:
			shots[n] = s
			multimesh.set_instance_transform(n, Transform3D(s.b, s.p))
			n += 1
	shots.resize(n)
	multimesh.visible_instance_count = n


static func _seg_hits(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	return _closest(a, b, c).distance_squared_to(c) < r * r


static func _closest(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var d := b - a
	return a + d * clampf((c - a).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
