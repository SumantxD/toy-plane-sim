class_name Objectives
extends Node3D

# Objective play on top of the dogfight:
#  - Supply economy (every mode but Free Flight): grabbing a crate makes you a cargo carrier; get it
#    to your airfield for +1 team supply, get shot down and it drops for anyone to steal. Supplies
#    buy turret deployments and HQ repairs.
#  - Capture the Flag (mode 4): fly through the enemy flag, bring it to yours while yours is home.
#  - Base Assault (mode 5): each team's HQ has health; AI bomber raids and players wear it down.
# The server decides everything and mirrors it through main.gs; peers render from gs.
const FLAG_R := 45.0
const FLAG_TOP := 160.0 # pickup is a column up the beam, not a ball you must skim the grass for
const HOME_R := 260.0
const CAPS_TO_WIN := 3
const FLAG_RETURN := 30.0
const HQ_HP := 6000
const RAID_EVERY := 70.0
const RAID_DAMAGE := 600
const BANK_TRICKLE := 90.0

var main: Node
var flags: Array = [null, null] # visual flag nodes per team
var hqs: Array = [null, null]
var cargo_nodes := {} # carrier name -> crate node hanging under the plane
var bases: Array = [Vector3.ZERO, Vector3.ZERO] # flag stands, on clear ground
var raid_t := [40.0, 55.0]
var trickle_t := 0.0


func setup(m: Node) -> void:
	main = m
	for team in 2:
		flags[team] = _make_flag(team)
		add_child(flags[team])
		bases[team] = _clear_spot(flag_spot(team), 10.0)
		var h := HQ.new()
		h.name = "HQ%d" % team
		h.team = team
		h.main = main
		h.position = _clear_spot(hq_spot(team), 30.0) + Vector3.UP * HQ.MID # hit sphere centred on the building
		add_child(h)
		hqs[team] = h
	# The final spots can move (water, buildings), so clear small decor there rather than trusting keep-out.
	for team in 2:
		_clear_decor(hqs[team].position, 34.0)
		_clear_decor(bases[team], 16.0)


static func flag_spot(team: int) -> Vector2:
	return Vector2(70, 1500) if team == 0 else Props.RED_RUNWAY + Vector2(70, 40) # same distance from centre for both


static func hq_spot(team: int) -> Vector2:
	return Vector2(250, 1500) if team == 0 else Props.RED_RUNWAY + Vector2(250, 0) # mirrors blue: open ground beside the runway


# Hide scattered trees / rocks (small, non-solid MultiMesh instances) standing on an objective.
func _clear_decor(at: Vector3, r: float) -> void:
	var props: Node = main.world_root.get_node_or_null("Props")
	if not props:
		return
	for mmi: MultiMeshInstance3D in props.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := mmi.multimesh
		var size := mm.mesh.get_aabb().size
		for i in mm.instance_count:
			var t := mmi.global_transform * mm.get_instance_transform(i)
			if Vector2(t.origin.x - at.x, t.origin.z - at.z).length() < r and (t.basis * size).length() < 45.0:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))


func flag_base(team: int) -> Vector3:
	return bases[team]


# Nearest ground near `at` with no props in the way (worlds differ: Metro is all towers). Bullets
# stop at obstacles, so an HQ inside a building's box would be unhittable.
func _clear_spot(at: Vector2, half: float) -> Vector3:
	for r in range(0, 600, 40):
		for k in (1 if r == 0 else 12):
			var p := at + Vector2.from_angle(k * TAU / 12.0) * r
			var g := Vector3(p.x, Terrain.floor_below(Vector3(p.x, 2000.0, p.y)), p.y)
			if not _blocked(g, half):
				return g
	return Vector3(at.x, Terrain.floor_below(Vector3(at.x, 2000.0, at.y)), at.y)


func _blocked(g: Vector3, half: float) -> bool:
	for dx in [-half, 0.0, half]:
		for dz in [-half, 0.0, half]:
			for h in [4.0, 20.0, 40.0]:
				var q := g + Vector3(dx, h, dz)
				if main.hits_obstacle(q) or Terrain.solid(q):
					return true
	var cfg: Dictionary = Worlds.cur
	if cfg.water.get("visible", true) and g.y < cfg.water.get("y", Terrain.WATER_Y) + 1.0:
		return true # no HQ in the sea
	return g.y < cfg.env.kill_y + 2.0 # or on Sky Kingdom's cloud sea


func home(team: int) -> Vector3:
	return flag_base(team)


# ---------- match start (server sets gs, everyone resets visuals) ----------

func reset(gs: Dictionary) -> void:
	gs.flags = [{state = "home", pos = flag_base(0), carrier = "", t = 0.0}, {state = "home", pos = flag_base(1), carrier = "", t = 0.0}]
	gs.score = [0, 0]
	gs.bank = [2, 2]
	gs.cargo = []
	gs.hq = [HQ_HP, HQ_HP]
	raid_t = [40.0, 55.0]
	trickle_t = 0.0


func on_match_start() -> void:
	for team in 2:
		hqs[team].revive(main.gs.mode == 5)


# ---------- server ticks ----------

func tick(dt: float) -> void:
	var gs: Dictionary = main.gs
	if gs.mode == 2:
		return
	_tick_cargo(gs)
	trickle_t += dt
	if trickle_t >= BANK_TRICKLE:
		trickle_t = 0.0
		for team in 2:
			gs.bank[team] = mini(gs.bank[team] + 1, 9)
	if gs.mode == 4:
		_tick_ctf(gs, dt)
	elif gs.mode == 5:
		_tick_assault(gs, dt)


func _tick_cargo(gs: Dictionary) -> void:
	for n in gs.cargo.duplicate():
		var p: Node = main.players.get_node_or_null(n)
		if not p:
			gs.cargo.erase(n)
			continue
		var h := home(p.team)
		if Vector2(p.position.x - h.x, p.position.z - h.z).length() < HOME_R:
			gs.cargo.erase(n)
			gs.bank[p.team] = mini(gs.bank[p.team] + 1, 9)
			main.feed_msg("%s delivered supplies (+1 %s)" % [p.pilot, Main_TEAM[p.team]])
			main.sfx_event.rpc("deliver", p.team, p.position, str(p.name))


const Main_TEAM := ["Blue", "Red"]


func pick_cargo(p: Node) -> void:
	if not p.name in main.gs.cargo:
		main.gs.cargo.append(str(p.name))


func _tick_ctf(gs: Dictionary, dt: float) -> void:
	for team in 2:
		var f: Dictionary = gs.flags[team]
		match f.state:
			"home", "dropped":
				if f.state == "dropped":
					f.t += dt
					if f.t > FLAG_RETURN:
						_flag_home(team, "The %s flag returned home" % Main_TEAM[team])
						continue
				for p in main.players.get_children():
					if not (p.alive and p.role in ["pilot", "wing"]) or not _in_column(p.position, f.pos, FLAG_R + p.hit_radius):
						continue
					if p.team != team:
						f.state = "carried"
						f.carrier = str(p.name)
						main.feed_msg("%s grabbed the %s flag!" % [p.pilot, Main_TEAM[team]])
						main.sfx_event.rpc("grab", team, f.pos, str(p.name))
						break
					elif f.state == "dropped":
						_flag_home(team, "%s returned the %s flag" % [p.pilot, Main_TEAM[team]])
						main.sfx_event.rpc("return", team, f.pos, str(p.name))
						break
			"carried":
				var c: Node = main.players.get_node_or_null(f.carrier)
				if not c or not c.alive:
					drop_flag_of(f.carrier, f.pos)
					continue
				f.pos = c.position
				var own: Dictionary = gs.flags[c.team]
				if own.state == "home" and _in_column(c.position, flag_base(c.team), 150.0):
					gs.score[c.team] += 1
					_flag_home(team, "%s CAPTURED the %s flag! (%d-%d)" % [c.pilot, Main_TEAM[team], gs.score[0], gs.score[1]])
					main.sfx_event.rpc("capture", c.team, c.position, str(c.name))
	if gs.score[0] >= CAPS_TO_WIN or gs.score[1] >= CAPS_TO_WIN:
		main._end("%s team wins %d-%d!" % [Main_TEAM[0 if gs.score[0] > gs.score[1] else 1], gs.score[0], gs.score[1]])


func _in_column(at: Vector3, base: Vector3, r: float) -> bool:
	return Vector2(at.x - base.x, at.z - base.z).length() < r and at.y - base.y < FLAG_TOP


func _flag_home(team: int, msg: String) -> void:
	var f: Dictionary = main.gs.flags[team]
	f.state = "home"
	f.pos = flag_base(team)
	f.carrier = ""
	f.t = 0.0
	main.feed_msg(msg)


# Carrier died: whatever it held drops where it fell (flag) or as a crate (cargo).
func on_down(p: Node) -> void:
	var gs: Dictionary = main.gs
	if gs.get("flags") and gs.mode == 4:
		drop_flag_of(str(p.name), p.position)
	if gs.get("cargo") and str(p.name) in gs.cargo:
		gs.cargo.erase(str(p.name))
		main.battlefield.drop_cargo(p.position)


func drop_flag_of(carrier: String, at: Vector3) -> void:
	for team in 2:
		var f: Dictionary = main.gs.flags[team]
		if f.state == "carried" and f.carrier == carrier:
			f.state = "dropped"
			f.carrier = ""
			f.t = 0.0
			f.pos = Vector3(at.x, maxf(at.y, Terrain.floor_below(at) + 12.0), at.z)
			main.feed_msg("The %s flag was dropped!" % Main_TEAM[team])
			main.sfx_event.rpc("drop", team, f.pos, "")


func _tick_assault(gs: Dictionary, dt: float) -> void:
	for team in 2:
		gs.hq[team] = hqs[team].hp
		raid_t[team] -= dt
		if raid_t[team] <= 0.0:
			raid_t[team] = RAID_EVERY
			var from := home(team) + Vector3.UP * 260.0
			var to: Vector3 = hqs[1 - team].position
			main._spawn_ai("striker", team, from, main._yaw_to(to - from), Vector3.ZERO, "twin", "%s bomber" % Main_TEAM[team])
			main.feed_msg("%s bomber raid launched!" % Main_TEAM[team])
			main.sfx_event.rpc("raid", team, from, "")
		# AI teams patch their HQ when it's hurting and they can afford it.
		if hqs[team].hp < HQ_HP * 0.6 and gs.bank[team] >= 2 and _team_has_ai(team) and randf() < dt * 0.05:
			repair_hq(team)


func _team_has_ai(team: int) -> bool:
	return main.players.get_children().any(func(p): return p.role == "wing" and p.team == team)


func repair_hq(team: int) -> bool:
	var gs: Dictionary = main.gs
	if gs.mode != 5 or gs.bank[team] < 2 or not hqs[team].alive:
		return false
	gs.bank[team] -= 2
	hqs[team].set_hp.rpc(mini(hqs[team].hp + 1000, HQ_HP), hqs[team].comps)
	main.feed_msg("%s team repaired its HQ" % Main_TEAM[team])
	main.sfx_event.rpc("repair", team, hqs[team].position, "")
	return true


# Server: a raid bomber flies straight to the enemy HQ, bombs it once, heads home.
func strike_move(p: Node, dt: float) -> void:
	var target: Node = hqs[1 - p.team]
	var goal: Vector3 = (target.position if not p.ai.get("bombed", false) else home(p.team)) + Vector3.UP * 260.0
	var to: Vector3 = goal - p.position
	if not p.ai.get("bombed", false) and Vector2(to.x, to.z).length() < 90.0:
		p.ai.bombed = true
		main.obj_event.rpc("bombs", p.position, target.position)
		if target.alive:
			target.set_hp.rpc(target.hp - RAID_DAMAGE, target.comps)
			main.feed_msg("%s hit the %s HQ!" % [p.pilot, Main_TEAM[1 - p.team]])
			main.sfx_event.rpc("hq_hit", 1 - p.team, target.position, "")
			if target.hp <= 0:
				main.kill(target, p)
	elif p.ai.get("bombed", false) and Vector2(to.x, to.z).length() < 200.0:
		p.queue_free()
		return
	var v := Vector3(to.x, 0, to.z).normalized() * 32.0
	v.y = clampf(to.y, -10.0, 10.0)
	p.velocity = v
	p.position += v * dt
	if v.length() > 0.1:
		p.basis = p.basis.slerp(Basis.looking_at(v.normalized()), minf(1.0, dt)).orthonormalized()


# ---------- AI objectives: what a pilot with a job should be doing right now ----------
# Returns {} (fight freely), {goto = Vector3} or {target = Node}.
func objective_for(p: Node) -> Dictionary:
	var gs: Dictionary = main.gs
	if gs.mode == 2 or gs.phase != "playing":
		return {}
	var me := str(p.name)
	if gs.mode == 4:
		for team in 2:
			if gs.flags[team].state == "carried" and gs.flags[team].carrier == me:
				return {goto = flag_base(p.team) + Vector3.UP * 70.0, urgent = true}
	if me in gs.cargo:
		return {goto = home(p.team) + Vector3.UP * 120.0, urgent = true}
	var job: String = p.ai.get("job", "hunt")
	if gs.mode == 4:
		var mine: Dictionary = gs.flags[p.team]
		var theirs: Dictionary = gs.flags[1 - p.team]
		if mine.state == "carried" and job != "attack":
			var thief: Node = main.players.get_node_or_null(mine.carrier)
			if thief and thief.alive:
				return {target = thief}
		match job:
			"attack":
				return {goto = theirs.pos + Vector3.UP * 70.0, urgent = theirs.state != "carried"}
			"hunt": # second attacker, but happy to dogfight on the way
				if theirs.state != "carried":
					return {goto = theirs.pos + Vector3.UP * 70.0}
			"escort":
				var ours: Node = main.players.get_node_or_null(theirs.carrier) if theirs.state == "carried" else null
				if ours and ours.alive:
					return {goto = ours.position + ours.basis * Vector3(40, 15, 60)}
				return {goto = theirs.pos + Vector3.UP * 80.0}
			"defend":
				if mine.state == "dropped":
					return {goto = mine.pos, urgent = true}
				var e := _enemy_near(p, flag_base(p.team), 700.0)
				return {target = e} if e else {goto = flag_base(p.team) + Vector3.UP * 180.0}
	elif gs.mode == 5:
		var enemy_hq: Node = hqs[1 - p.team]
		match job:
			"attack":
				if enemy_hq.alive:
					return {target = enemy_hq}
			"escort":
				for s in main.players.get_children():
					if s.role == "striker" and s.team == p.team and s.alive:
						return {goto = s.position + Vector3(50, 30, 50)}
				if enemy_hq.alive:
					return {target = enemy_hq}
			"defend":
				for s in main.players.get_children():
					if s.role == "striker" and s.team != p.team and s.alive:
						return {target = s}
				var e := _enemy_near(p, hqs[p.team].position, 900.0)
				return {target = e} if e else {goto = hqs[p.team].position + Vector3.UP * 220.0}
	return {}


func _enemy_near(p: Node, at: Vector3, r: float) -> Node:
	var best: Node = null
	var bd := r
	for e in main.players.get_children():
		if e.alive and e.team != p.team and e.role in ["pilot", "wing", "striker"]:
			var d: float = e.position.distance_to(at)
			if d < bd:
				bd = d
				best = e
	return best


# ---------- everyone: render flags, cargo crates, bombs ----------

func _process(_dt: float) -> void:
	var gs: Dictionary = main.gs
	var ctf: bool = gs.get("mode", 0) == 4 and gs.get("flags") != null and gs.phase in ["playing", "ended"]
	for team in 2:
		var fl: Node3D = flags[team]
		fl.visible = ctf
		if not ctf:
			continue
		var f: Dictionary = gs.flags[team]
		var c: Node = main.players.get_node_or_null(f.carrier) if f.state == "carried" else null
		fl.global_position = (c.position + Vector3.UP * 3.0) if c else f.pos
		fl.scale = Vector3.ONE * (0.45 if c else 1.0)
	var carrying: Array = gs.get("cargo", []) if gs.phase in ["playing", "ended"] else []
	for n in cargo_nodes.keys():
		if not n in carrying or not main.players.get_node_or_null(n):
			cargo_nodes[n].queue_free()
			cargo_nodes.erase(n)
	for n in carrying:
		var p: Node = main.players.get_node_or_null(n)
		if p and not cargo_nodes.has(n):
			var box := MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			box.mesh.size = Vector3(2.4, 2.4, 2.4)
			box.material_override = main.toon(Color(0.75, 0.52, 0.28))
			add_child(box)
			cargo_nodes[n] = box
		if p:
			cargo_nodes[n].global_position = p.position + Vector3.DOWN * 3.5


func show_bombs(from: Vector3, at: Vector3) -> void:
	for i in 5:
		var at_i := at + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		get_tree().create_timer(0.25 * i + 0.6).timeout.connect(func():
			if is_instance_valid(main):
				main.boom(at_i + Vector3.UP * 4.0, 1.3))
	Sfx.at(main, from, Sfx.BOMB_WHISTLE, 0.0, 2000.0)


func _make_flag(team: int) -> Node3D:
	var n := Node3D.new()
	var pole := MeshInstance3D.new()
	pole.mesh = CylinderMesh.new()
	pole.mesh.top_radius = 0.4
	pole.mesh.bottom_radius = 0.5
	pole.mesh.height = 22.0
	pole.position.y = 11.0
	pole.material_override = main.toon(Color(0.9, 0.9, 0.88))
	n.add_child(pole)
	var cloth := MeshInstance3D.new()
	cloth.mesh = QuadMesh.new()
	cloth.mesh.size = Vector2(12.0, 7.0)
	cloth.mesh.subdivide_width = 10
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://banner.gdshader")
	mat.set_shader_parameter("color", Battlefield.Aircraft_TEAM[team])
	cloth.material_override = mat
	cloth.position = Vector3(6.2, 18.0, 0)
	n.add_child(cloth)
	var beam := MeshInstance3D.new() # tall soft light column: spot the flag from across the map
	beam.mesh = CylinderMesh.new()
	beam.mesh.top_radius = 3.0
	beam.mesh.bottom_radius = 3.0
	beam.mesh.height = 400.0
	beam.position.y = 200.0
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c: Color = Battlefield.Aircraft_TEAM[team]
	bm.albedo_color = Color(c.r, c.g, c.b, 0.18)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	n.visible = false
	return n


# A team headquarters: a big bunker that only takes damage in Base Assault.
class HQ extends Node3D:
	const MID := 16.0
	var team := 0
	var alive := true
	var hp := HQ_HP
	var max_hp := HQ_HP
	var hit_radius := 32.0
	var pilot := "HQ"
	var role := "hq"
	var is_ai := true
	var velocity := Vector3.ZERO
	var comps := PackedFloat32Array([1, 1, 1, 1])
	var ai := {}
	var main: Node
	var body := Node3D.new()

	func _ready() -> void:
		pilot = ["Blue HQ", "Red HQ"][team]
		add_child(body)
		body.position.y = -MID
		var c: Color = Battlefield.Aircraft_TEAM[team]
		_box(Vector3(40, 14, 30), Vector3(0, 7, 0), main.toon(Color(0.6, 0.6, 0.57)))
		_box(Vector3(42, 2.5, 32), Vector3(0, 15, 0), main.toon(c))
		_box(Vector3(12, 18, 12), Vector3(-10, 25, 0), main.toon(Color(0.7, 0.7, 0.66)))
		_box(Vector3(14, 3, 14), Vector3(-10, 35, 0), main.toon(c))
		_box(Vector3(0.6, 20, 0.6), Vector3(8, 26, 6), main.toon(Color(0.2, 0.2, 0.22)))

	func _box(size: Vector3, at: Vector3, mat: Material) -> void:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		m.mesh.size = size
		m.position = at
		m.material_override = mat
		body.add_child(m)

	func vel_estimate() -> Vector3:
		return Vector3.ZERO

	func component_at(_p: Vector3) -> int:
		return -1

	func report_hit(_t: Node, _w := 0, _c := -1) -> void:
		pass

	# Only a target in Base Assault; otherwise just a building.
	func revive(targetable: bool) -> void:
		alive = true
		hp = max_hp
		body.show()
		for ch in get_children():
			if ch is CPUParticles3D:
				ch.queue_free()
		if targetable and not is_in_group("targets"):
			add_to_group("targets")
		elif not targetable and is_in_group("targets"):
			remove_from_group("targets")

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
		main.boom(global_position + Vector3.UP * 15.0, 3.0)
		var f := Fx.fire(6.0)
		f.position.y = -6.0
		add_child(f)
		add_child(Fx.smoke(5.0, 9.0))
