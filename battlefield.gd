class_name Battlefield
extends Node3D

# Living battlefield, shared by every world: drifting hot-air balloons with team banners
# (decoration), parachuted supply crates (fly through one: full repair + rockets), and AA guns
# guarding the airfields and the factory (flak bursts, line of sight blocked by terrain,
# destructible). The server decides drops, flak and damage; peers render what it announces.
const DROP_EVERY := Vector2(45.0, 75.0)
const PICKUP_R := 32.0
const FLAK_RANGE := 950.0
const FLAK_SPEED := 380.0
const FLAK_RADIUS := 24.0

var main: Node
var crates := {} # id -> {node, pos, t, landed, ground}
var drop_t := 30.0
var crate_n := 0
var guns: Array = []


func setup(m: Node) -> void:
	main = m
	_balloons()
	_guns()


# ---------- balloons: deterministic circles, no syncing needed ----------

func _balloons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150 + Worlds.index
	var cols := [Color(1.0, 0.45, 0.3), Color(0.35, 0.6, 1.0), Color(1.0, 0.8, 0.25), Color(0.55, 0.85, 0.4), Color(0.85, 0.45, 0.95)]
	for i in 8:
		var b := Node3D.new()
		var paint: Material = main.toon(cols[i % cols.size()])
		Planes.build("balloon", b, paint, main.toon(Color(0.95, 0.93, 0.85)), main.toon(Color(0.2, 0.2, 0.22)), main.toon(Color(0.2, 0.2, 0.22)), paint)
		b.scale = Vector3.ONE * rng.randf_range(2.2, 3.2)
		var banner := MeshInstance3D.new()
		banner.mesh = QuadMesh.new()
		banner.mesh.size = Vector2(5.0, 1.6)
		banner.mesh.subdivide_width = 8
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://banner.gdshader")
		mat.set_shader_parameter("color", Aircraft_TEAM[i % 2])
		banner.material_override = mat
		banner.position = Vector3(0, -6.5, 0)
		b.add_child(banner)
		add_child(b)
		b.set_meta("orbit", [Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500)), rng.randf_range(250, 700), rng.randf_range(300, 520), rng.randf() * TAU, rng.randf_range(0.004, 0.01)])


const Aircraft_TEAM := [Color(0.3, 0.55, 1.0), Color(1.0, 0.35, 0.3)]


func _process(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for b in get_children():
		if b.has_meta("orbit"):
			var o: Array = b.get_meta("orbit")
			var a: float = o[3] + now * o[4]
			b.position = Vector3(o[0].x + cos(a) * o[1], o[2] + sin(now * 0.5 + o[3]) * 6.0, o[0].y + sin(a) * o[1])
			b.rotation.y = -a
	for id in crates:
		var c: Dictionary = crates[id]
		c.t += dt
		if not c.landed:
			c.pos.y -= 11.0 * dt
			c.pos.x += sin(c.t * 0.7) * 2.0 * dt
			if c.pos.y <= c.ground:
				c.pos.y = c.ground
				c.landed = true
				var mark := Fx.smoke(1.4, 4.0, Color(0.95, 0.85, 0.2))
				mark.initial_velocity_min = 5.0
				mark.initial_velocity_max = 9.0
				mark.fixed_fps = 30 # stands still: 30 Hz steps look the same
				c.node.add_child(mark)
				c.node.get_node("Chute").hide()
		c.node.position = c.pos


# ---------- supply crates ----------

func server_tick(dt: float) -> void:
	if not multiplayer.is_server() or main.gs.phase != "playing":
		return
	drop_t -= dt
	if drop_t <= 0.0:
		drop_t = randf_range(DROP_EVERY.x, DROP_EVERY.y)
		var near: Array = main.players.get_children().filter(func(p): return p.alive and p.role in ["pilot", "wing"])
		var c := Vector3.ZERO
		for p in near:
			c += p.position
		c = c / near.size() if near else Vector3.ZERO
		var at := Vector3(clampf(c.x + randf_range(-500, 500), -1600, 1600), 650.0, clampf(c.z + randf_range(-500, 500), -1600, 1600))
		crate_n += 1
		main.bf_event.rpc("drop", crate_n, at, Vector3.ZERO)
	for id in crates.keys():
		var cr: Dictionary = crates[id]
		if cr.landed and cr.t > 90.0:
			main.bf_event.rpc("gone", id, cr.pos, Vector3.ZERO)
			continue
		for p in main.players.get_children():
			if p.alive and p.role in ["pilot", "wing"] and p.position.distance_to(cr.pos) < PICKUP_R + p.hit_radius:
				main.bf_event.rpc("gone", id, cr.pos, Vector3.ZERO)
				main.repair(p, p.max_hp)
				p.resupply.rpc()
				if main.objectives and main.gs.mode != 2:
					main.objectives.pick_cargo(p) # now carry it home for the team bank
				main.feed_msg("%s grabbed a supply crate" % p.pilot)
				main.sfx_event.rpc("crate", p.team, cr.pos, str(p.name))
				break


func spawn_crate(id: int, at: Vector3) -> void:
	var n := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.mesh.size = Vector3(4, 4, 4)
	box.material_override = main.toon(Color(0.75, 0.52, 0.28))
	n.add_child(box)
	var band := MeshInstance3D.new()
	band.mesh = BoxMesh.new()
	band.mesh.size = Vector3(4.1, 1.0, 4.1)
	band.material_override = main.toon(Color(0.95, 0.8, 0.2))
	n.add_child(band)
	var chute := MeshInstance3D.new()
	chute.name = "Chute"
	chute.mesh = SphereMesh.new()
	chute.mesh.radius = 9.0
	chute.mesh.height = 9.0
	chute.mesh.is_hemisphere = true
	chute.material_override = main.toon(Color(1.0, 0.3, 0.25))
	chute.position.y = 14.0
	n.add_child(chute)
	add_child(n)
	n.add_to_group("supply")
	crates[id] = {node = n, pos = at, t = 0.0, landed = false, ground = Terrain.floor_below(at) + 2.0}
	Sfx.ui(main, Sfx.CONFIRM, -6.0)


func remove_crate(id: int) -> void:
	if crates.has(id):
		crates[id].node.queue_free()
		crates.erase(id)


# Server: a dead carrier's cargo falls as a fresh crate anyone can grab.
func drop_cargo(at: Vector3) -> void:
	crate_n += 1
	main.bf_event.rpc("drop", crate_n, at, Vector3.ZERO)


# Nearest crate position (for AI pilots who need patching up), or null.
func nearest_crate(from: Vector3, reach: float):
	var best = null
	for c in crates.values():
		if from.distance_to(c.pos) < reach and (best == null or from.distance_to(c.pos) < from.distance_to(best)):
			best = c.pos
	return best


# ---------- ground defenses ----------
# Base defenses are built with the world (same order on every peer). Players and AI pilots can
# deploy more for their team during a match; those are appended in announcement order, so the
# index stays identical on every peer.
const KINDS := ["flak", "rapid", "sam", "radar"]
const MAX_DEPLOYED := 4 # per team, standing at once
var base_count := 0


# Fixed emplacements: [pos2, team, kind]. Props keeps trees out of these spots.
static func base_spots() -> Array:
	var r: Rect2 = Terrain.RUNWAY
	var layout := []
	var home := [["flak", -95.0, 0.2], ["rapid", -95.0, 0.47], ["sam", -95.0, 0.75], ["flak", 95.0, 0.85], ["radar", 140.0, 0.55]]
	for h in home:
		layout.append([Vector2(r.position.x + h[1], r.position.y + r.size.y * h[2]), 0, h[0]])
	for k in 5:
		var a: float = k * TAU / 5.0 + 0.4
		layout.append([Props.RED_RUNWAY + Vector2(cos(a), sin(a)) * 210.0, 1, ["flak", "rapid", "sam", "flak", "radar"][k]])
		layout.append([Props.FACTORY + Vector2(cos(a + 0.6), sin(a + 0.6)) * 175.0, 1, ["flak", "rapid", "flak", "sam", "radar"][k]])
	return layout


func _guns() -> void:
	for l in base_spots():
		var p: Vector2 = l[0]
		_add_turret(l[2], l[1], Vector3(p.x, Terrain.floor_below(Vector3(p.x, 2000.0, p.y)), p.y), false)
	base_count = guns.size()


func _add_turret(kind: String, team: int, at: Vector3, deployed: bool) -> Turret:
	var g := Turret.new()
	g.name = "T%d" % guns.size()
	g.kind = kind
	g.team = team
	g.position = at
	g.main = main
	g.bf = self
	g.idx = guns.size()
	g.deployed = deployed
	add_child(g)
	guns.append(g)
	return g


func server_guns(dt: float) -> void:
	if main.gs.mode == 2:
		return # free flight stays peaceful
	for g in guns:
		if g.alive and g.active:
			g.think(dt)


# New match: base defenses back in action, deployed ones cleared (same on every peer).
func reset_guns() -> void:
	for i in range(guns.size() - 1, base_count - 1, -1):
		guns[i].queue_free()
	guns.resize(base_count)
	for g in guns:
		g.revive()
		# Flag/HQ modes are symmetric: the Escort-era base guns (5 blue vs 10 red) stand down and
		# every defense is one a team bought with supplies.
		g.visible = not main.gs.mode in [4, 5]
		g.alive = g.visible


func deployed_alive(team: int) -> int:
	return guns.slice(base_count).filter(func(g): return g.alive and g.team == team).size()


# A working friendly radar within 900 m sharpens a gun's aim.
func radar_near(g: Turret) -> bool:
	for r in guns:
		if r.kind == "radar" and r.alive and r.active and r.team == g.team and r.position.distance_to(g.position) < 900.0:
			return true
	return false


# Peers: a deployment crate drops from `from` and unfolds into a turret at `at`.
func deploy(kind: String, team: int, from: Vector3, at: Vector3) -> void:
	var g := _add_turret(kind, team, at, true)
	g.active = false
	g.visible = false
	var crate := MeshInstance3D.new()
	crate.mesh = BoxMesh.new()
	crate.mesh.size = Vector3(5, 5, 5)
	crate.material_override = main.toon(Aircraft_TEAM[team])
	var chute := MeshInstance3D.new()
	chute.mesh = SphereMesh.new()
	chute.mesh.radius = 10.0
	chute.mesh.height = 10.0
	chute.mesh.is_hemisphere = true
	chute.material_override = main.toon(Color(0.95, 0.93, 0.85))
	chute.position.y = 15.0
	crate.add_child(chute)
	add_child(crate)
	crate.position = from
	var fall := clampf((from.y - at.y) / 45.0, 1.5, 8.0)
	var gid := g.get_instance_id() # the turret may be cleared (new match) before the crate lands
	var tw := crate.create_tween()
	tw.tween_property(crate, "position", at + Vector3.UP * 2.5, fall)
	tw.tween_callback(func():
		crate.queue_free()
		var t = instance_from_id(gid)
		if t:
			t.visible = true
			t.active = true
			t.scale = Vector3.ONE * 0.2
			t.create_tween().tween_property(t, "scale", Vector3.ONE * Turret.SIZE, 0.6).set_trans(Tween.TRANS_BACK)
			main.boom(at, 0.35))


# Peers: show a shot. Flak bursts after `tof`; tracers are drawn locally from the turret.
func shot(i: int, kind: String, at: Vector3, tof: float) -> void:
	if i < 0 or i >= guns.size():
		return
	var g: Turret = guns[i]
	g.aim_point = at
	match kind:
		"flak":
			Sfx.at(main, g.global_position, Sfx.FLAK, 2.0, 1500.0, 0.8)
			get_tree().create_timer(tof).timeout.connect(func():
				if is_instance_valid(main):
					Fx.flak(main, at))
		"rapid":
			if not multiplayer.is_server():
				main.bullets.fire(g.muzzle(), (at - g.muzzle()).normalized() * 450.0, g, false)
			Sfx.at(main, g.global_position, Sfx.AA_GUN, 0.0, 900.0)


class Turret extends Node3D:
	const SIZE := 1.8 # readable from the air
	const SPEC := {
		flak = {hp = 160, range = 950.0, rate = 1.3, name = "Flak cannon", tag = "FLAK"},
		rapid = {hp = 110, range = 700.0, rate = 0.13, name = "AA gun", tag = "AA"},
		sam = {hp = 130, range = 1400.0, rate = 9.0, name = "SAM site", tag = "SAM"},
		radar = {hp = 90, range = 0.0, rate = 0.0, name = "Radar", tag = "RADAR"},
	}
	var kind := "flak"
	var team := 1
	var alive := true
	var active := true
	var deployed := false
	var hp := 100
	var max_hp := 100
	var hit_radius := 9.0
	var pilot := "Flak cannon"
	var role := "turret"
	var is_ai := true
	var velocity := Vector3.ZERO
	var comps := PackedFloat32Array([1, 1, 1, 1])
	var ai := {}
	var main: Node
	var bf: Node
	var idx := 0
	var head := Node3D.new()
	var dish: Node3D
	var cd := 0.0
	var pick_t := 0.0
	var radar := false # a friendly radar nearby (checked with each target pick)
	var target: Node
	var aim_point := Vector3.ZERO

	func _ready() -> void:
		add_to_group("targets")
		scale = Vector3.ONE * SIZE
		hit_radius = 5.0 * SIZE
		var s: Dictionary = SPEC[kind]
		hp = s.hp
		max_hp = s.hp
		pilot = s.name
		aim_point = global_position + Vector3(0, 50, -100)
		var paint: Material = main.toon(Color(0.5, 0.58, 0.45) if team == 0 else Color(0.62, 0.36, 0.3))
		var dark: Material = main.toon(Color(0.16, 0.16, 0.18))
		var stripe: Material = main.toon(Aircraft_TEAM[team])
		_mesh(self, CylinderMesh.new(), Vector3(12.0, 0.8, 12.0), Vector3(0, 0.1, 0), main.toon(Color(0.66, 0.65, 0.62))) # concrete pad
		_mesh(self, CylinderMesh.new(), Vector3(4.5, 3.0, 4.5), Vector3(0, 1.5, 0), main.toon(Color(0.4, 0.4, 0.38)))
		_mesh(self, CylinderMesh.new(), Vector3(4.7, 0.6, 4.7), Vector3(0, 3.2, 0), stripe) # team band, readable from the air
		head.position.y = 5.0
		add_child(head)
		match kind:
			"flak":
				_mesh(head, BoxMesh.new(), Vector3(4.0, 2.6, 4.0), Vector3.ZERO, paint)
				for x in [-0.9, 0.9]:
					_mesh(head, BoxMesh.new(), Vector3(0.5, 0.5, 7.0), Vector3(x, 0.5, -4.0), dark)
			"rapid":
				_mesh(head, BoxMesh.new(), Vector3(3.0, 2.0, 3.0), Vector3.ZERO, paint)
				for x in [-1.1, -0.4, 0.4, 1.1]:
					_mesh(head, BoxMesh.new(), Vector3(0.25, 0.25, 4.5), Vector3(x, 0.3, -2.8), dark)
			"sam":
				_mesh(head, BoxMesh.new(), Vector3(5.0, 1.0, 3.0), Vector3(0, -0.6, 0), paint)
				for x in [-1.6, -0.55, 0.55, 1.6]:
					_mesh(head, CylinderMesh.new(), Vector3(0.9, 5.0, 0.9), Vector3(x, 0.6, -0.5), main.toon(Color(0.92, 0.92, 0.88)), Vector3(70, 0, 0))
			"radar":
				_mesh(head, CylinderMesh.new(), Vector3(0.6, 9.0, 0.6), Vector3(0, 3.5, 0), dark)
				dish = Node3D.new()
				dish.position.y = 8.5
				head.add_child(dish)
				_mesh(dish, BoxMesh.new(), Vector3(7.0, 3.0, 0.4), Vector3.ZERO, main.toon(Color(0.92, 0.92, 0.88)), Vector3(-15, 0, 0))

	func _mesh(parent: Node3D, m: Mesh, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		if m is BoxMesh:
			m.size = size
		elif m is CylinderMesh:
			m.top_radius = size.x / 2.0
			m.bottom_radius = size.x / 2.0
			m.height = size.y
		mi.mesh = m
		mi.position = at
		mi.rotation_degrees = rot
		mi.material_override = mat
		parent.add_child(mi)

	func vel_estimate() -> Vector3:
		return Vector3.ZERO

	func component_at(_p: Vector3) -> int:
		return -1

	func muzzle() -> Vector3:
		return head.global_position - head.global_basis.z.normalized() * 4.0 * SIZE

	# Barrels swing at a limited rate: a fast low pass can outrun the gun.
	func _process(dt: float) -> void:
		if dish:
			dish.rotate_y(dt * 1.5)
			return
		if not alive or not visible:
			return
		var dir := aim_point - head.global_position
		var want_yaw := atan2(-dir.x, -dir.z)
		var want_pitch := clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -0.1, 1.45)
		var step := 1.4 * dt
		head.rotation.y += clampf(angle_difference(head.rotation.y, want_yaw), -step, step)
		head.rotation.x = move_toward(head.rotation.x, want_pitch, step)

	func on_target(at: Vector3) -> bool:
		return (-head.global_basis.z.normalized()).angle_to(at - head.global_position) < 0.12

	func think(dt: float) -> void:
		var spec: Dictionary = SPEC[kind]
		if spec.range <= 0.0:
			return
		cd -= dt
		pick_t -= dt
		if pick_t <= 0.0:
			pick_t = 0.5
			radar = bf.radar_near(self)
			target = _pick(spec.range * (1.25 if radar else 1.0))
		if not is_instance_valid(target) or not target.alive:
			target = null
			return
		var sharp := radar
		var d: float = global_position.distance_to(target.position)
		match kind:
			"flak":
				var tof := d / FLAK_SPEED
				aim_point = target.position + target.vel_estimate() * tof
				if cd <= 0.0 and on_target(aim_point):
					cd = spec.rate * randf_range(0.8, 1.2)
					var at := aim_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * randf_range(8.0, 32.0) * (0.55 if sharp else 1.0)
					main.bf_event.rpc("flak", idx, at, Vector3(tof, 0, 0))
					get_tree().create_timer(tof).timeout.connect(func():
						if not is_instance_valid(main) or main.gs.phase != "playing":
							return
						for p in main.players.get_children():
							if p.alive and p.team != team and p.position.distance_to(at) < FLAK_RADIUS:
								var dmg := int(26.0 * (1.0 - p.position.distance_to(at) / FLAK_RADIUS)) + 6
								main.env_hit(p, dmg / 4 if p.role == "bomber" else dmg, "flak"))
			"rapid":
				var tof := d / 450.0
				aim_point = target.position + target.vel_estimate() * tof
				if cd <= 0.0 and on_target(aim_point):
					cd = spec.rate
					var spread := 0.025 if sharp else 0.045
					var dir := ((aim_point - muzzle()).normalized() + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread).normalized()
					main.bullets.fire(muzzle(), dir * 450.0, self, true)
					main.bf_event.rpc("rapid", idx, muzzle() + dir * 300.0, Vector3.ZERO)
			"sam":
				aim_point = target.position + Vector3.UP * 60.0
				if cd <= 0.0 and on_target(aim_point) and d > 250.0:
					cd = spec.rate * randf_range(0.8, 1.2)
					main.rockets.fire_from(self, head.global_position + Vector3.UP * 3.0, (target.position - global_position).normalized() * 40.0 + Vector3.UP * 30.0, target)

	func _pick(reach: float) -> Node:
		var best: Node = null
		var bd := reach
		for p in main.players.get_children():
			if p.alive and p.team != team and not p.role in ["balloon", "prize"] and p.is_in_group("targets"):
				var d: float = global_position.distance_to(p.position)
				if p.role == "bomber":
					d += 600.0 # fighters first: bombers are the escort's job to protect
				if d < bd and _clear(p.position):
					bd = d
					best = p
		return best

	# Terrain blocks the shot: duck behind a ridge to escape.
	func _clear(to: Vector3) -> bool:
		var from := global_position + Vector3.UP * 6.0
		for k in range(1, 8):
			if Terrain.solid(from.lerp(to, k / 8.0)):
				return false
		return true

	func report_hit(t: Node, weapon := 0, comp := -1) -> void:
		if multiplayer.is_server():
			main.apply_hit(self, t, weapon, comp)

	func revive() -> void:
		alive = true
		hp = max_hp
		head.show()
		for c in get_children():
			if c is CPUParticles3D:
				c.queue_free()

	@rpc("any_peer", "call_local", "reliable")
	func set_hp(v: int, _c: PackedFloat32Array) -> void:
		if multiplayer.get_remote_sender_id() > 1:
			return
		hp = v

	@rpc("any_peer", "call_local", "reliable")
	func die(_fx: bool) -> void:
		if multiplayer.get_remote_sender_id() > 1:
			return
		alive = false
		head.hide()
		main.boom(global_position + Vector3.UP * 4.0, 1.2)
		var f := Fx.fire(1.5)
		f.position.y = 3.0
		f.fixed_fps = 30 # stands still: 30 Hz steps look the same
		add_child(f)
		var sm := Fx.smoke(1.6, 4.0)
		sm.fixed_fps = 30
		add_child(sm)
