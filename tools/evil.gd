extends Node

# TEST HOOK (--evil, client only): a cheating client. Every 6 s it fires a battery of forged,
# malformed, replayed and spammy RPCs at the host and the other peers. Each should show up as a
# refusal in the host's TALLY line (--netstats / --quit-after-secs), and nobody should crash.
# Round 4 floods the host until it kicks us.
var main: Node
var round_n := 0


func _ready() -> void:
	main = get_parent()
	var t := Timer.new()
	t.wait_time = 6.0
	t.autostart = true
	t.timeout.connect(_attack)
	add_child(t)


func _attack() -> void:
	var me: Node = main._plane(multiplayer.get_unique_id())
	if not me or not me.alive or main.gs.phase != "playing" or main.gs.get("countdown", 0.0) > 0.0:
		return
	round_n += 1
	var foes: Array = get_tree().get_nodes_in_group("targets").filter(func(t): return t.team != me.team and t.alive)
	foes.sort_custom(func(a, b): return a.position.distance_to(me.position) < b.position.distance_to(me.position))
	var sent := {}
	# Fake damage: from 2.5 km+, through a mountain, rockets never launched, 200 gun hits in one burst.
	for t in foes:
		var d: float = t.position.distance_to(me.position)
		if d > 2500.0:
			main.report_hit.rpc_id(1, t.name, 0, 0)
			sent.far = sent.get("far", 0) + 1
		elif d < 1000.0 and not main._clear_line(me.position, t.position):
			main.report_hit.rpc_id(1, t.name, 0, 0)
			sent.hidden = sent.get("hidden", 0) + 1
	for t in foes.slice(0, 3):
		main.report_hit.rpc_id(1, t.name, 2, -1)
		sent.nolaunch = sent.get("nolaunch", 0) + 1
	if foes and round_n == 1:
		for i in 200:
			main.report_hit.rpc_id(1, foes[0].name, 0, 2)
		sent.burst = 200
	# Malformed: unknown names, out-of-range indices, a 100 KB name, wrong types and arg counts.
	main.report_hit.rpc_id(1, "nobody", -5, 99)
	main.report_hit.rpc_id(1, "x".repeat(100000), 99999, -99999)
	main.rpc_id(1, "report_hit", 5, "x", null)
	main.rpc_id(1, "report_hit")
	main.rpc_id(1, "register", "not a dict")
	main.rpc_id(1, "request_deploy", [1, 2, 3])
	main.rpc_id(1, "pong", "soon")
	main.pong.rpc_id(1, -999999999)
	me.rpc("st", "t", null, 7)
	me.st.rpc(NAN, me.position, me.quaternion)
	me.st.rpc(me.sim_clock, Vector3(INF, 0, 0), me.quaternion)
	# Replayed identity: register again with a giant name and a different plane.
	main.register.rpc_id(1, {name = "Z".repeat(200000), version = main.VERSION, plane = "fighter", token = "t".repeat(5000)})
	# Teleport, speed hack, fast clock.
	me.st.rpc(me.sim_clock + 0.03, me.position + Vector3(1500, 0, 0), me.quaternion)
	me.st.rpc(me.sim_clock + 0.03, me.position + me.basis.z * -40.0, me.quaternion) # 1300 m/s
	me.st.rpc(me.sim_clock + 60.0, me.position, me.quaternion)
	# Ordnance: in someone else's name, someone else's id, 1 km from us, too fast, beyond what we carry.
	var other: Node = null
	for p in main.players.get_children():
		if p != me:
			other = p
			break
	if other:
		main.rockets.spawn_remote.rpc("%s_900" % other.name, other.position, Vector3.ZERO, str(other.name), str(me.name), false)
		main.rockets.spawn_remote.rpc("%s_901" % other.name, me.position, Vector3.ZERO, str(me.name), "", false)
		main.rockets.detonate_remote.rpc("%s_1" % other.name, other.position)
		other.set_hp.rpc(0, other.comps)
		other.die.rpc(true)
	main.rockets.spawn_remote.rpc("%s_far%d" % [me.name, round_n], me.position + Vector3(0, 0, 1000), me.velocity, str(me.name), "", false)
	main.rockets.spawn_remote.rpc("%s_fast%d" % [me.name, round_n], me.position, Vector3(5000, 0, 0), str(me.name), "", false)
	for i in 15:
		main.rockets.spawn_remote.rpc("%s_e%d_%d" % [me.name, round_n, i], me.position, me.velocity, str(me.name), "", true)
	main.rockets.spawn_remote.rpc("%s_e%d_0" % [me.name, round_n], me.position, me.velocity, str(me.name), "", true) # replay
	# One real-looking bomb, then its hit replayed on the same target and claimed on far targets.
	if foes:
		for i in 3:
			main.report_hit.rpc_id(1, foes[0].name, 2, -1)
		main.report_hit.rpc_id(1, foes[-1].name, 2, -1)
		get_tree().create_timer(8.0).timeout.connect(_late_bomb_hits.bind(str(foes[0].name)))
	# Unlimited flares, guns, explosions; spammed requests (round 1 only: the strikes add up to a kick).
	for i in 20:
		me.flare.rpc()
	if round_n == 1:
		for i in 60:
			main.rockets.detonate_remote.rpc("%s_e%d_%d" % [me.name, round_n, i % 15], me.position)
		for i in 100:
			me.fired.rpc()
		for i in 25:
			main.request_deploy.rpc_id(1, "rapid")
			main.request_ping.rpc_id(1, "Help!")
			main.request_repair.rpc_id(1)
			main.request_plane.rpc_id(1, "racer")
	# Host-only requests sent to the other clients through the relay.
	for id in main.gs.players:
		if id != 1 and id != multiplayer.get_unique_id():
			main.request_start.rpc_id(id)
			main.request_end.rpc_id(id)
			main.register.rpc_id(id, {name = "evil", version = main.VERSION})
			main.report_hit.rpc_id(id, me.name, 0, 0)
	print("EVIL round %d sent %s" % [round_n, sent])
	if round_n == 3: # a dead plane's guns: crash, then claim hits after the grace period
		get_tree().create_timer(1.5).timeout.connect(_crash.bind(foes.slice(0, 1).map(func(t): return str(t.name))))
	if round_n >= 4: # flood: the host must stay responsive and kick us
		for i in 3000:
			main.request_ping.rpc_id(1, "Help!")
		print("EVIL flooded")


func _crash(names: Array) -> void: # after the round's spam has drained from the reliable channel
	main.report_crash.rpc_id(1)
	get_tree().create_timer(2.6).timeout.connect(_dead_hits.bind(names))


func _dead_hits(names: Array) -> void:
	for n in names:
		for i in 5:
			main.report_hit.rpc_id(1, n, 0, 0)
	print("EVIL dead hits sent (we are %s)" % ("alive" if main._plane(multiplayer.get_unique_id()).alive else "dead"))


# 8 s after our two bombs: far enough for a plausible reach. Two may land (two bombs), the third is a replay.
func _late_bomb_hits(target: String) -> void:
	for i in 3:
		main.report_hit.rpc_id(1, target, 2, -1)
