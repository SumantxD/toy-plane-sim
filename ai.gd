class_name PilotAI
extends RefCounted

# Server-side brain for AI pilots. It only produces what a human would (aim direction, throttle,
# boost, guns, rockets); plane.gd flies it with the shared flight model, damage and weapons.
#
# Each pilot = difficulty skill (reflexes, aim) + an archetype personality (with random per-pilot
# variation) + moods that change during the fight (confidence, fear, grudges) + signature moves.
# Decisions refresh every `react` seconds; steering, moves and safety run every frame.
enum { PATROL, PURSUE, ATTACK, EVADE, RETREAT }
const BULLET_SPEED := 450.0 # plane.gd BULLET_SPEED

# Difficulty: reflexes and hands. Never extra health.
const SKILLS := {
	rookie = {react = 0.9, aim_err = 0.03, lead = 0.75, slop = 14.0, evade = 0.35, mistakes = 0.25, rocket_cd = 14.0},
	pilot = {react = 0.45, aim_err = 0.015, lead = 0.92, slop = 8.0, evade = 0.65, mistakes = 0.1, rocket_cd = 9.0},
	ace = {react = 0.2, aim_err = 0.006, lead = 1.0, slop = 4.0, evade = 0.9, mistakes = 0.03, rocket_cd = 6.0},
}

# Personality: aggr (chase / head-ons), caution (break off, retreat), patience (wait for a clean
# shot), flair (stunts), loyalty (protect teammates, revenge), range (favourite gun distance).
const ARCHETYPES := {
	hothead = {name = "Hothead", aggr = 0.95, caution = 0.1, patience = 0.15, flair = 0.5, loyalty = 0.4, range = 250.0, moves = ["headon", "jink", "roll"]},
	sniper = {name = "Sniper", aggr = 0.5, caution = 0.5, patience = 0.9, flair = 0.15, loyalty = 0.4, range = 550.0, moves = ["boomzoom", "zoom", "yoyo"]},
	guardian = {name = "Guardian", aggr = 0.6, caution = 0.45, patience = 0.6, flair = 0.2, loyalty = 0.95, range = 350.0, moves = ["scissors", "yoyo", "jink"]},
	showoff = {name = "Show-off", aggr = 0.7, caution = 0.3, patience = 0.4, flair = 0.95, loyalty = 0.5, range = 320.0, moves = ["roll", "loop", "yoyo"]},
	survivor = {name = "Survivor", aggr = 0.35, caution = 0.9, patience = 0.7, flair = 0.25, loyalty = 0.6, range = 450.0, moves = ["splits", "zoom", "scissors"]},
	hunter = {name = "Hunter", aggr = 0.8, caution = 0.5, patience = 0.7, flair = 0.35, loyalty = 0.5, range = 380.0, moves = ["yoyo", "splits", "roll"]},
}

const RADIO := {
	kill = ["Splash one!", "Scratch one bandit!", "Got 'em!", "That's a kill!"],
	kill_hothead = ["Who's next?!", "Too easy!", "Come on, come ON!"],
	kill_showoff = ["Did everyone see that?", "Style points!", "Victory roll!"],
	kill_sniper = ["One shot.", "Clean hit.", "Target down."],
	hurt = ["I'm hit!", "Taking fire!", "They got my wing!", "Get him off me!"],
	missile = ["Missile! Missile!", "Rocket on my six!", "Breaking!"],
	retreat = ["Bugging out, patching up.", "Heading home, I'm leaking.", "Too hot, falling back!"],
	back = ["Patched up, coming back in!", "Miss me?", "Round two."],
	revenge = ["You'll pay for that!", "That was my wingman!", "Payback time."],
	down = ["I'm going down!", "Mayday, mayday!", "Ejecting!"],
	help = ["On your six, hold on!", "I've got you covered!", "Moving to assist."],
}

const SLOTS := [Vector3(-45, 0, 35), Vector3(45, 0, 35), Vector3(-90, 0, 70), Vector3(90, 0, 70), Vector3(-135, 0, 105), Vector3(135, 0, 105)]


# Fresh brain: skill + archetype with per-pilot variation, so no two pilots fly alike.
static func make(skill: String, archetype := "") -> Dictionary:
	if archetype == "":
		archetype = ARCHETYPES.keys().pick_random()
	var a: Dictionary = ARCHETYPES[archetype]
	var t := {}
	for k in ["aggr", "caution", "patience", "flair", "loyalty"]:
		t[k] = clampf(a[k] + randf_range(-0.15, 0.15), 0.0, 1.0)
	t.range = a.range * randf_range(0.85, 1.2)
	return {skill = skill, arch = archetype, traits = t, conf = 0.5, fear = 0.0, grudge = null, kills = 0}


# After a respawn: forget the fight, keep the personality (a bit shaken).
static func reset(p: Node) -> void:
	for k in ["state", "move", "target", "heal", "retreated"]:
		p.ai.erase(k)
	p.ai.conf = clampf(p.ai.get("conf", 0.5) - 0.15, 0.2, 1.0)
	p.ai.fear = 0.0


static func think(p: Node, dt: float, main: Node) -> void:
	var s: Dictionary = p.ai
	if not s.has("traits"):
		s.merge(make(s.get("skill", "rookie")))
	if not s.has("state"):
		s.merge({state = PATROL, target = null, clock = 0.0, t_think = randf() * 0.5, until = 0.0, break_dir = Vector3.UP,
			jitter = Vector3.ZERO, rocket_t = randf_range(3.0, 8.0), move = {}, blind = 0.0, hold = 0.0, heal = 0.0, back_at = 0.0})
	var sk: Dictionary = SKILLS[s.skill]
	var tr: Dictionary = s.traits
	s.clock += dt
	s.rocket_t -= dt
	s.blind -= dt
	s.fear = maxf(s.fear - 0.12 * dt, 0.0)
	s.t_think -= dt
	if s.t_think <= 0.0:
		# Reflexes wobble, and a shaken pilot is slower: nobody reacts on a metronome.
		s.t_think = sk.react * randf_range(0.6, 1.5) * (1.3 - 0.5 * s.conf)
		s.jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * sk.aim_err * (1.0 + s.fear)
		_decide(p, s, sk, tr, main)
	p.wants_fire = false
	p.wants_rocket = false
	p.wants_boost = false
	var aim: Vector3
	if not s.move.is_empty():
		aim = _run_move(p, s, dt)
	else:
		aim = _steer(p, s, sk, tr, dt, main)
	p.aim_dir = _avoid(p, aim, tr, main)


static func _decide(p: Node, s: Dictionary, sk: Dictionary, tr: Dictionary, main: Node) -> void:
	if not s.move.is_empty():
		return
	if s.state in [EVADE, RETREAT] and s.clock < s.until:
		return
	var threat: Node = _threat(p, main)
	var hurt: float = 1.0 - float(p.hp) / p.max_hp
	# A flag/cargo run is committed: no breaking off for every tracer.
	var obj: Dictionary = main.objectives.objective_for(p) if main.objectives else {}
	if obj.get("urgent", false):
		s.erase("supply")
		s.state = PATROL
		s.goal = obj.goto
		return
	# Hotheads never run; careful pilots break off sooner, more so when shaken.
	# Retreat at most once per life, and only when really hurt (survivors earlier, hotheads never).
	if p.role != "fighter" and tr.aggr < 0.9 and not s.get("retreated", false) and hurt > 0.8 - 0.3 * tr.caution and randf() < 0.6:
		s.retreated = true
		s.state = RETREAT
		s.until = s.clock + randf_range(6.0, 10.0)
		_say(p, main, "retreat", 0.7)
		return
	var evade_chance: float = sk.evade * (0.25 + 0.45 * tr.caution) * (1.0 + 0.5 * s.fear)
	if threat and randf() < evade_chance:
		s.state = EVADE
		s.until = s.clock + randf_range(1.0, 2.2)
		var away: Vector3 = (p.position - threat.position).normalized()
		var side: Vector3 = away.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		s.break_dir = (side + Vector3.UP * randf_range(-0.6, 0.8) + (-p.basis.z) * 0.3).normalized()
		# Sometimes the break is a signature move instead of a plain turn.
		if randf() < 0.35 + 0.3 * tr.flair:
			_start_move(p, s, _pick_move(p, ["splits", "zoom", "scissors", "roll", "jink"]), threat)
		return
	# Careful or loyal pilots dig in: drop a defense near home or near the bombers.
	var bank: Array = main.gs.get("bank", [0, 0])
	if p.role == "wing" and bank[p.team] > 0 and randf() < 0.015 * (tr.caution + tr.loyalty):
		var home: Vector3 = main.home_for(p.team)
		if Vector2(p.position.x - home.x, p.position.z - home.z).length() < 900.0 and p.position.y - Terrain.floor_below(p.position) < 400.0:
			var k: String = ["rapid", "rapid", "radar", "sam"].pick_random()
			var cost: int = 2 if k == "sam" else 1
			if bank[p.team] >= cost and main.deploy(p, k):
				bank[p.team] -= cost
	# Hurt or out of rockets: a supply crate nearby is worth the detour.
	if (hurt > 0.45 or p.rockets_left == 0) and main.battlefield and randf() < 0.6:
		var crate = main.battlefield.nearest_crate(p.position, 1600.0)
		if crate != null:
			s.state = PATROL
			s.supply = crate
			return
	s.erase("supply")
	# Mode objectives (flags, cargo, HQs): a job beats free-for-all dogfighting.
	s.erase("goal")
	if main.objectives:
		if obj.has("target") and is_instance_valid(obj.target) and obj.target.alive:
			s.target = obj.target
			s.state = ATTACK if p.position.distance_to(obj.target.position) < 650.0 else PURSUE
			return
		if obj.has("goto"):
			if not threat:
				s.state = PATROL
				s.goal = obj.goto
				return
	# Mistakes: target fixation for a moment (more for rookies).
	if randf() < sk.mistakes and s.blind <= 0.0:
		s.blind = randf_range(0.8, 2.0)
	var t: Node = _pick_target(p, s, tr, main)
	if t != null and s.target != t and p.role == "wing" and _helping(p, t, main) and randf() < tr.loyalty:
		_say(p, main, "help", 0.3)
	s.target = t
	if not t:
		s.state = PATROL
		# Bored show-offs fill the quiet with stunts.
		if randf() < 0.08 * tr.flair and p.position.y - Terrain.height(p.position.x, p.position.z) > 250.0:
			_start_move(p, s, ["roll", "loop"].pick_random(), null)
		return
	var d: float = p.position.distance_to(t.position)
	s.state = ATTACK if d < 650.0 else PURSUE
	# Openers depend on character.
	if randf() < 0.2:
		var head_on: bool = (-t.basis.z).angle_to(p.position - t.position) < 0.5 and (-p.basis.z).angle_to(t.position - p.position) < 0.6
		if head_on and d < 900.0 and randf() < tr.aggr:
			_start_move(p, s, "headon", t)
		elif s.state == ATTACK and randf() < 0.5:
			_start_move(p, s, _pick_move(p, ARCHETYPES[s.arch].moves), t)


# An enemy close behind with its nose on us, or a rocket homing on us.
static func _threat(p: Node, main: Node) -> Node:
	for r in main.rockets.rockets.values():
		if is_instance_valid(r.target) and r.target == p and is_instance_valid(r.owner):
			p.ai.fear = minf(p.ai.fear + 0.3, 1.0)
			_say(p, main, "missile", 0.3)
			return r.owner
	for e in _enemies(p, main):
		var to_me: Vector3 = p.position - e.position
		if to_me.length() < 420.0 and (-e.basis.z).angle_to(to_me) < 0.25 and (-p.basis.z).dot(to_me) > 0.0:
			return e
	return null


# Cheapest score wins: near and ahead, not swarmed, threatening friends, grudges, wounded prey.
static func _pick_target(p: Node, s: Dictionary, tr: Dictionary, main: Node) -> Node:
	if not is_instance_valid(s.target):
		s.target = null
	if not is_instance_valid(s.grudge):
		s.grudge = null
	if s.blind > 0.0 and s.target and s.target.alive:
		return s.target # target fixation: ignores better options for a bit
	var friends: Array = main.players.get_children().filter(func(f): return f != p and f.alive and f.team == p.team)
	var leader_lock: Node = null
	for f in friends:
		if f.role == "pilot" and is_instance_valid(f.lock):
			leader_lock = f.lock
	var best: Node = null
	var best_score := INF
	for e in _enemies(p, main):
		var d: float = p.position.distance_to(e.position)
		var score: float = d + (-p.basis.z).angle_to(e.position - p.position) * 300.0
		for f in friends:
			if f.ai.get("target") == e:
				score += 450.0
			elif f.position.distance_to(e.position) < 500.0 and (-e.basis.z).angle_to(f.position - e.position) < 0.4:
				score -= 600.0 * tr.loyalty # it's on a teammate's tail
		if e == leader_lock:
			score -= 700.0 * tr.loyalty
		if is_instance_valid(s.grudge) and e == s.grudge:
			score -= 900.0
		if s.arch == "hunter":
			score -= (1.0 - float(e.hp) / e.max_hp) * 600.0 # finish the wounded
		if p.role == "fighter" and e.role == "bomber":
			score -= 500.0
		if e.role == "turret":
			score += 700.0 # ground targets only when nothing better is close
		if e == s.target:
			score *= 0.85
		score += randf_range(0.0, 150.0) # a little indecision
		if score < best_score:
			best_score = score
			best = e
	return best


static func _helping(p: Node, e: Node, main: Node) -> bool:
	for f in main.players.get_children():
		if f.alive and f.team == p.team and f != p and f.position.distance_to(e.position) < 500.0:
			return true
	return false


static func _steer(p: Node, s: Dictionary, sk: Dictionary, tr: Dictionary, dt: float, main: Node) -> Vector3:
	var fwd: Vector3 = -p.basis.z
	p.throttle = 0.8
	match s.state:
		EVADE:
			p.throttle = 1.0
			p.wants_boost = p.boost > 0.3
			return s.break_dir
		RETREAT:
			p.throttle = 1.0
			p.wants_boost = p.boost > 0.5
			var safe: bool = _enemies(p, main).all(func(e): return e.position.distance_to(p.position) > 900.0)
			if safe:
				s.heal += dt * 5.0 # patch up away from the fight
				if s.heal >= 5.0:
					main.repair(p, int(s.heal))
					s.heal = 0.0
				if p.hp >= p.max_hp * 0.7:
					s.state = PATROL
					s.until = 0.0
					s.back_at = s.clock + 20.0
					_say(p, main, "back", 0.8)
			return (main.home_for(p.team) + Vector3.UP * 300.0 - p.position).normalized()
		PURSUE, ATTACK:
			if not is_instance_valid(s.target) or not s.target.alive:
				s.target = null
				s.t_think = 0.0
				return fwd
			var t: Node = s.target
			var d: float = p.position.distance_to(t.position)
			var tv: Vector3 = t.vel_estimate()
			if d < 140.0 and fwd.dot(tv) > 0.0:
				# Too close behind: lag pursuit (aim at its tail), ease off, maybe a high yo-yo.
				p.throttle = 0.35
				if randf() < 0.02 * (1.0 + tr.flair):
					_start_move(p, s, "yoyo", t)
				return (t.position - tv.normalized() * 60.0 - p.position).normalized()
			if tr.patience > 0.75 and d < tr.range * 0.5 and randf() < 0.01:
				_start_move(p, s, "zoom", t) # snipers hate knife fights: extend and come back
			var lead: Vector3 = t.position + (tv - p.velocity) * (d / BULLET_SPEED) * sk.lead
			var aim: Vector3 = (lead - p.position).normalized() + s.jitter
			p.throttle = 1.0 if d > tr.range else 0.6 + 0.3 * tr.aggr
			p.wants_boost = d > 1200.0 and p.boost > 0.6
			# Shoot when the guns are actually on the lead point: the window is the target's size at
			# this range plus skill slop (patient pilots wait for cleaner shots, hotheads spray).
			var cone: float = atan((t.hit_radius * 1.2 + sk.slop * (1.3 - 0.6 * tr.patience)) / maxf(d, 1.0))
			var reach: float = tr.range + 150.0 * tr.aggr
			s.hold -= dt
			if d < reach and fwd.angle_to(aim) < cone and s.hold <= 0.0:
				p.wants_fire = true
				if randf() < 0.015 * (0.5 + tr.patience):
					s.hold = randf_range(0.3, 0.8)
			p.lock = p.find_lock()
			if p.lock == t and d > 350.0 and d < 1100.0 and s.rocket_t <= 0.0 and p.rockets_left > 0 and randf() < 0.3 + tr.patience * 0.5:
				p.wants_rocket = true
				s.rocket_t = sk.rocket_cd * randf_range(0.7, 1.4)
			return aim.normalized()
	if s.has("supply"):
		p.throttle = 1.0
		return (s.supply + Vector3.UP * 4.0 - p.position).normalized()
	if s.has("goal"):
		var gd: float = p.position.distance_to(s.goal)
		p.throttle = clampf(gd / 700.0, 0.35, 1.0) # slow down to thread the pickup
		p.wants_boost = gd > 900.0 and p.boost > 0.5
		return (s.goal - p.position).normalized()
	# PATROL: loyal wingmen hold formation on a human; free spirits head for the action.
	var leader: Node = null
	for f in main.players.get_children():
		if f.role == "pilot" and f.alive and f.team == p.team:
			leader = f
			break
	if leader and p.role == "wing" and tr.loyalty > 0.45:
		var slot: Vector3 = SLOTS[s.get("slot", 0) % SLOTS.size()]
		var spot: Vector3 = leader.position + leader.basis * slot + leader.velocity * 1.0
		var gap: float = p.position.distance_to(spot)
		p.throttle = clampf(gap / 150.0, 0.3, 1.0)
		return (spot - p.position).normalized()
	var enemies: Array = _enemies(p, main)
	if not enemies.is_empty() and tr.aggr > 0.5:
		var mid := Vector3.ZERO
		for e in enemies:
			mid += e.position
		return (mid / enemies.size() - p.position).normalized()
	var c: Vector3 = main.home_for(p.team) * 0.5
	c.y = Terrain.height(c.x, c.z) + 280.0
	var r: Vector3 = p.position - c
	r.y = 0.0
	return (r.normalized().cross(Vector3.UP) + (c - p.position).normalized() * 0.4).normalized()


# ---------- signature moves: short scripted manoeuvres flown through the normal controls ----------

static func _pick_move(p: Node, options: Array) -> String:
	var alt: float = p.position.y - Terrain.floor_below(p.position)
	var ok: Array = options.filter(func(m): return not (m in ["splits", "loop"] and alt < 280.0))
	return ok.pick_random() if ok else "jink"


static func _start_move(p: Node, s: Dictionary, name: String, other: Node) -> void:
	var dur: float = {roll = 1.6, loop = 4.0, yoyo = 1.3, splits = 2.6, zoom = 2.4, scissors = 2.6, jink = 2.0, headon = 4.0, boomzoom = 6.0, victory = 1.6}.get(name, 1.5)
	s.move = {name = name, t = 0.0, dur = dur, basis = p.basis, other = other, side = 1.0 if randf() < 0.5 else -1.0, phase = 0}


static func _run_move(p: Node, s: Dictionary, dt: float) -> Vector3:
	var m: Dictionary = s.move
	m.t += dt
	var b: Basis = m.basis
	var fwd: Vector3 = -b.z
	var k: float = m.t / m.dur
	if k >= 1.0:
		var next: String = "zoom" if m.name == "boomzoom" and m.phase == 1 else ""
		s.move = {}
		if next:
			_start_move(p, s, next, m.other)
		return -p.basis.z
	p.throttle = 1.0
	match m.name:
		"roll", "victory":
			var a := TAU * k
			return (fwd + (b.x * cos(a) + b.y * sin(a)) * 0.7 * m.side).normalized()
		"loop":
			p.wants_boost = p.boost > 0.2
			var a := TAU * k
			return (fwd * cos(a) + b.y * sin(a)).normalized()
		"yoyo":
			if k < 0.55 or not is_instance_valid(m.other):
				return (fwd + b.y * 1.3).normalized()
			return (m.other.position - p.position).normalized()
		"splits":
			# Half roll, then pull through the bottom: ends up diving the other way.
			if k < 0.25:
				return (fwd + b.x * 0.8 * m.side).normalized()
			return (Vector3.DOWN * 1.2 - fwd * minf(k * 1.5, 1.0)).normalized()
		"zoom":
			p.wants_boost = p.boost > 0.2
			return (fwd * 0.6 + Vector3.UP * 1.4).normalized()
		"scissors":
			var flip: float = 1.0 if int(m.t / 0.65) % 2 == 0 else -1.0
			return (fwd + b.x * 1.6 * flip * m.side).normalized()
		"jink":
			if not m.has("dir") or int(m.t / 0.4) != int((m.t - dt) / 0.4):
				m.dir = (fwd + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1))).normalized()
			return m.dir
		"headon":
			# Play chicken: guns blazing nose to nose, break at the last moment.
			var o: Node = m.other
			if not is_instance_valid(o) or not o.alive:
				s.move = {}
				return fwd
			var d: float = p.position.distance_to(o.position)
			if d < m.get("nerve", 140.0):
				_start_move(p, s, ["roll", "jink"].pick_random(), o)
				return -p.basis.z
			m.nerve = m.get("nerve", randf_range(100.0, 180.0))
			p.wants_fire = d < 500.0
			return (o.position + o.vel_estimate() * (d / BULLET_SPEED) - p.position).normalized()
		"boomzoom":
			var o: Node = m.other
			if not is_instance_valid(o) or not o.alive:
				s.move = {}
				return fwd
			if m.phase == 0:
				# Climb for an altitude advantage first.
				if p.position.y > o.position.y + 150.0 or k > 0.5:
					m.phase = 1
				return (o.position + Vector3.UP * 220.0 - p.position).normalized()
			var d: float = p.position.distance_to(o.position)
			p.wants_fire = d < 500.0 and (-p.basis.z).angle_to(o.position - p.position) < 0.15
			if d < 120.0:
				m.t = m.dur # dive done: zoom out
			return (o.position + o.vel_estimate() * (d / BULLET_SPEED) - p.position).normalized()
	return -p.basis.z


# ---------- events from main.gd ----------

static func on_hit(victim: Node, attacker: Node, main: Node) -> void:
	if not victim.ai.has("traits"):
		return
	var s: Dictionary = victim.ai
	s.fear = minf(s.fear + 0.15, 1.0)
	s.conf = maxf(s.conf - 0.03, 0.1)
	if s.traits.aggr > 0.85 and attacker:
		s.grudge = attacker # hotheads take it personally
	if victim.hp < victim.max_hp * 0.5:
		_say(victim, main, "hurt", 0.2)


static func on_kill(victim: Node, killer: Node, main: Node) -> void:
	if killer and killer.ai.has("traits"):
		var s: Dictionary = killer.ai
		s.kills += 1
		s.conf = minf(s.conf + 0.2, 1.0)
		if is_instance_valid(s.grudge) and s.grudge == victim:
			s.grudge = null
		var flavour: String = "kill_" + str(s.arch)
		_say(killer, main, flavour if RADIO.has(flavour) and randf() < 0.6 else "kill", 0.7)
		if s.traits.flair > 0.6 and randf() < s.traits.flair:
			_start_move(killer, s, "victory", null) # victory roll
	if victim.ai.has("traits"):
		_say(victim, main, "down", 0.3)
	# Teammates of the fallen remember who did it.
	if killer:
		for f in main.players.get_children():
			if f.alive and f.team == victim.team and f.ai.has("traits") and f.position.distance_to(victim.position) < 1500.0 and randf() < f.ai.traits.loyalty * 0.6:
				f.ai.grudge = killer
				_say(f, main, "revenge", 0.4)


static func _say(p: Node, main: Node, kind: String, chance: float) -> void:
	if randf() < chance:
		main.radio(p, RADIO[kind].pick_random())


# ---------- safety layer over any intent: ground, buildings, other planes, map edge, ceiling ----------

static func _avoid(p: Node, aim: Vector3, tr: Dictionary, main: Node) -> Vector3:
	var t = p.ai.get("target")
	# Strafing an HQ means committing to a dive: short look-ahead, low floor.
	var strafe: bool = is_instance_valid(t) and t.role == "hq" and p.position.distance_to(t.position) < 700.0
	var margin: float = 25.0 if strafe else 50.0 + 40.0 * tr.get("caution", 0.5) # hotheads cut it closer
	for k in ([1.0] if strafe else [1.0, 2.5]):
		var probe: Vector3 = p.position + p.velocity * k
		if Terrain.solid(probe):
			# Heading into ground: climb, unless we're under a floating island (then dive under it).
			var under: bool = p.position.y < Terrain.bottom(probe.x, probe.z)
			return (aim + (Vector3.DOWN if under else Vector3.UP) * 3.0).normalized()
		if Terrain.solid(probe + Vector3.DOWN * margin * 0.5) and probe.y < Terrain.bottom(probe.x, probe.z) + 30.0:
			return (aim + Vector3.DOWN * 2.0).normalized() # about to hit a floating island's underside
		if probe.y < Terrain.floor_below(probe) + margin * (1.0 if k < 2.0 else 1.5) or main.hits_obstacle(probe):
			if not p.ai.get("move", {}).is_empty() and p.ai.move.name in ["splits", "loop", "boomzoom"]:
				p.ai.move = {} # abort a dive that would end in the ground
			return (aim + Vector3.UP * (3.0 if k < 2.0 else 1.5)).normalized()
	for f in main.players.get_children():
		if f != p and f.alive and p.position.distance_to(f.position) < 45.0:
			aim += (p.position - f.position).normalized() * 0.8
	if Vector2(p.position.x, p.position.z).length() > 2350.0 and not strafe: # outside both bases (blue runway ends at z 2300)
		aim += Vector3(-p.position.x, 0, -p.position.z).normalized() * 1.5
	if p.position.y > 700.0:
		aim += Vector3.DOWN
	return aim.normalized()


static func _enemies(p: Node, main: Node) -> Array:
	var list: Array = main.players.get_children().filter(func(e): return e.alive and e.team != p.team and e.role != "balloon")
	if main.battlefield and main.gs.mode != 2:
		for g in main.battlefield.guns:
			if g.alive and g.active and g.team != p.team and g.position.distance_to(p.position) < 900.0:
				list.append(g)
	return list
