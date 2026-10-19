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
				main.feed_msg("%s grabbed a supply crate" % p.pilot)
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


# Nearest crate position (for AI pilots who need patching up), or null.
func nearest_crate(from: Vector3, reach: float):
	var best = null
	for c in crates.values():
		if from.distance_to(c.pos) < reach and (best == null or from.distance_to(c.pos) < from.distance_to(best)):
			best = c.pos
	return best


# ---------- AA guns ----------

func _guns() -> void:
	var spots: Array = []
	var r: Rect2 = Terrain.RUNWAY
	for dz in [0.15, 0.85]:
		for dx in [-90.0, 90.0]:
			spots.append([Vector2(r.position.x + dx, r.position.y + r.size.y * dz), 0])
	for k in 4:
		var a: float = k * TAU / 4.0 + 0.4
		spots.append([Props.RED_RUNWAY + Vector2(cos(a), sin(a)) * 200.0, 1])
		spots.append([Props.FACTORY + Vector2(cos(a + 0.8), sin(a + 0.8)) * 170.0, 1])
	for i in spots.size():
		var g := AAGun.new()
		g.name = "AA%d" % i
		g.team = spots[i][1]
		var p: Vector2 = spots[i][0]
		g.position = Vector3(p.x, Terrain.height(p.x, p.y), p.y)
		g.main = main
		g.idx = guns.size()
		add_child(g)
		guns.append(g)


func server_guns(dt: float) -> void:
	if main.gs.mode == 2:
		return # free flight stays peaceful
	for g in guns:
		if g.alive:
			g.think(dt)


# New match: every gun back in action.
func reset_guns() -> void:
	for g in guns:
		g.revive()


# Peers: show a gun firing and its shell bursting after `tof` seconds.
func flak(i: int, at: Vector3, tof: float) -> void:
	if i < 0 or i >= guns.size():
		return
	var g: AAGun = guns[i]
	g.aim_at(at)
	Sfx.at(main, g.global_position, Sfx.GUN, 4.0, 1500.0)
	get_tree().create_timer(tof).timeout.connect(func():
		if is_instance_valid(main):
			Fx.flak(main, at))


class AAGun extends Node3D:
	var team := 1
	var alive := true
	var hp := 140
	var max_hp := 140
	var hit_radius := 7.0
	var pilot := "AA gun"
	var role := "turret"
	var comps := PackedFloat32Array([1, 1, 1, 1])
	var ai := {}
	var main: Node
	var idx := 0
	var head := Node3D.new()
	var cd := 0.0
	var target: Node

	func _ready() -> void:
		add_to_group("targets")
		var base := MeshInstance3D.new()
		base.mesh = CylinderMesh.new()
		base.mesh.top_radius = 3.0
		base.mesh.bottom_radius = 4.0
		base.mesh.height = 3.0
		base.position.y = 1.5
		base.material_override = main.toon(Color(0.35, 0.38, 0.33))
		add_child(base)
		head.position.y = 4.0
		add_child(head)
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		body.mesh.size = Vector3(3.2, 2.2, 3.2)
		body.material_override = main.toon(Color(0.55, 0.6, 0.45) if team == 0 else Color(0.6, 0.35, 0.3))
		head.add_child(body)
		for s in [-0.7, 0.7]:
			var barrel := MeshInstance3D.new()
			barrel.mesh = BoxMesh.new()
			barrel.mesh.size = Vector3(0.35, 0.35, 5.5)
			barrel.position = Vector3(s, 0.4, -3.2)
			barrel.material_override = main.toon(Color(0.15, 0.15, 0.17))
			head.add_child(barrel)

	func vel_estimate() -> Vector3:
		return Vector3.ZERO

	func component_at(_p: Vector3) -> int:
		return -1

	func think(dt: float) -> void:
		cd -= dt
		if cd > 0.0:
			return
		cd = randf_range(1.0, 1.6)
		target = _pick()
		if not target:
			return
		var d: float = global_position.distance_to(target.position)
		var tof := d / FLAK_SPEED
		var lead: Vector3 = target.position + target.vel_estimate() * tof
		lead += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * randf_range(10.0, 34.0) # flak is scary, not a laser
		main.bf_event.rpc("flak", idx, lead, Vector3(tof, 0, 0))
		var t := get_tree().create_timer(tof)
		t.timeout.connect(func():
			if not is_instance_valid(main) or main.gs.phase != "playing":
				return
			for p in main.players.get_children():
				if p.alive and p.team != team and p.position.distance_to(lead) < FLAK_RADIUS:
					var dmg := int(26.0 * (1.0 - p.position.distance_to(lead) / FLAK_RADIUS)) + 6
					main.env_hit(p, dmg / 4 if p.role == "bomber" else dmg, "flak"))

	func _pick() -> Node:
		var best: Node = null
		var bd := FLAK_RANGE
		for p in main.players.get_children():
			if p.alive and p.team != team and p.role != "balloon":
				var d: float = global_position.distance_to(p.position)
				if p.role == "bomber":
					d += 600.0 # fighters first: bombers are the escort's job to protect, not a flak free-for-all
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

	func aim_at(at: Vector3) -> void:
		var dir := at - head.global_position
		head.rotation.y = atan2(-dir.x, -dir.z)
		head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())

	@rpc("any_peer", "call_local", "reliable")
	func set_hp(v: int, _c: PackedFloat32Array) -> void:
		if multiplayer.get_remote_sender_id() > 1:
			return
		hp = v

	func revive() -> void:
		alive = true
		hp = max_hp
		head.show()
		for c in get_children():
			if c is CPUParticles3D:
				c.queue_free()

	@rpc("any_peer", "call_local", "reliable")
	func die(_fx: bool) -> void:
		if multiplayer.get_remote_sender_id() > 1:
			return
		alive = false
		head.hide()
		main.boom(global_position + Vector3.UP * 4.0, 1.2)
		var f := Fx.fire(1.5)
		f.position.y = 3.0
		add_child(f)
		add_child(Fx.smoke(1.6, 4.0))
