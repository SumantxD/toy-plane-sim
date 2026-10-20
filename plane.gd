extends Node3D

# Mouse-aim arcade flight: the pilot points the camera, the plane steers toward it.
# Keys: W/S throttle, Shift boost, LMB/Space guns, RMB/F rocket, arrows + Q/E manual override.
const MIN_SPEED := 35.0
const MAX_SPEED := 110.0
const BOOST_SPEED := 150.0
const STALL := 32.0
const GRAVITY := 18.0
const TURN := Vector3(1.6, 0.6, 3.2) # pitch, yaw, roll rad/s
const FIRE_INTERVAL := 0.08
const BULLET_SPEED := 450.0
const HIT_RADIUS := 4.5
const MAX_HP := 100
const SEND_INTERVAL := 1.0 / 30.0
const INTERP_DELAY := 0.1
const STALL_MS := 1500 # no snapshots this long: a remote pilot counts as stalled
const EXTRAP_MAX := 1.0 # dead-reckon this long past the newest snapshot (covers ~1 s outages), then hold
const TEAM_COLORS := [Color(0.3, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const ROCKETS := 4
const ROCKET_RELOAD := 6.0
const LOCK_CONE := 0.35 # ~20 deg
const LOCK_RANGE := 1300.0
const LOCK_TIME := 0.6 # hold the target in the cone this long before a rocket will guide
const FLARE_CD := 3.0
const CAM_DIST := [0.7, 1.0, 1.5] # C cycles near / normal / far

var team := 0
var pilot := ""
var kind := "cub"
var min_speed := MIN_SPEED
var max_speed := MAX_SPEED
var boost_speed := BOOST_SPEED
var turn := TURN
var fire_interval := FIRE_INTERVAL
var max_rockets := ROCKETS
var comps := PackedFloat32Array([1, 1, 1, 1]) # left wing, right wing, engine, tail; 0..1
var parts := {}
var smoke: Array = [null, null, null, null]
var engine_snd: AudioStreamPlayer3D
var wind_snd: AudioStreamPlayer
var sputter_t := 0.0
var warn_cd := 0.0
var had_lock := false
var shake := 0.0 # camera shake when you take hits
var flames: CPUParticles3D
var is_ai := false
var role := "pilot" # pilot | fighter | bomber
var max_hp := MAX_HP
var hit_radius := HIT_RADIUS
var hp := MAX_HP
var alive := true

var velocity := Vector3.ZERO
var throttle := 0.5
var boost := 1.0
var ang := Vector3.ZERO
var aim_dir := Vector3.FORWARD
var wants_fire := false
var wants_boost := false
var fire_cd := 0.0
var send_cd := 0.0
var shots_out := 0 # guns fired since the last snapshot; remote tracers ride along with it
var wants_rocket := false
var rocket_aiming := false
var rockets_left := ROCKETS
var rocket_cd := 0.0
var lock: Node # completed lock (rockets guide onto it)
var lock_on: Node # being acquired
var lock_t := 0.0
var locking_name := "" # who this plane is locking, as every peer sees it
var locked_warn_cd := 0.0
var max_flares := 3
var flares_left := 3
var flare_cd := 0.0
var wants_flare := false
var max_bombs := 2
var bombs_left := 2
var bomb_cd := 0.0
var bomb_aiming := false
var wants_bomb := false
var flare_key := false

# AI state (server): PilotAI keeps its memory here
var ai := {}
var wp := 1
var offset := Vector3.ZERO

var snaps: Array = [] # [t, pos, quat], owner's game clock
var sim_clock := 0.0 # owner's game time (same units as dt, so time-scale safe)
var render_t := 0.0
var buffs := {} # prize-balloon rewards still running: "twin" | "shield" | "swarm" -> seconds left
var ammo_shown := -1
var shield_fx: MeshInstance3D
var hist: Array = [] # server: [msec, position], last ~0.6 s
var jitter := 0.0 # smoothed irregularity of snapshot arrival (s): sizes the interpolation buffer
var last_arrival := 0
var clock_off := 0.0 # owner's clock minus ours (smoothed), so render time keeps running through gaps
var floor_t := -1.0 # snapshots at or before this are from a previous life
var err_p := Vector3.ZERO # visual offset left by a correction, fades out instead of snapping
var err_q := Quaternion.IDENTITY
var clock0 := Vector2(-1, 0) # first snapshot: [owner clock, our clock], catches a sped-up sender
var died_ms := 0

var main: Node
var body := Node3D.new()
var tag := Label3D.new()
var cam: Camera3D
var hud: Control
var hud_text: Label # local plane only: a never-parented Label leaked once per freed plane
var aim_yaw := 0.0
var aim_pitch := 0.0


func _ready() -> void:
	main = get_tree().current_scene
	add_to_group("targets")
	var t: Dictionary = Planes.TYPES.get(kind, Planes.TYPES.cub)
	max_hp = t.hp
	hit_radius = t.radius
	min_speed = t.min
	max_speed = t.max
	boost_speed = t.boost
	turn = t.turn
	fire_interval = t.fire
	max_rockets = t.rockets
	rockets_left = max_rockets
	max_flares = t.flares
	flares_left = max_flares
	max_bombs = t.bombs
	bombs_left = max_bombs
	if role == "striker":
		max_hp = 900
		hit_radius = t.radius * 2.0
		body.scale = Vector3.ONE * 2.0
	elif role == "bomber":
		max_hp = 1000
		hit_radius = t.radius * 2.5
		body.scale = Vector3.ONE * 2.5
	elif role == "prize": # a big gold balloon worth a reward: ~8 gun hits or a rocket and a few
		max_hp = 60
		hit_radius = 10.0
		body.scale = Vector3.ONE * 1.6
	elif role == "balloon":
		max_hp = 16
		hit_radius = 7.0
	elif role == "fighter":
		max_hp = 60
		rockets_left = 2
	hp = max_hp
	add_child(body)
	_build_mesh()
	velocity = -basis.z * 60.0
	_reset_aim()

	tag.text = _tag_text()
	tag.modulate = Color(1.0, 0.8, 0.2) if role == "prize" else TEAM_COLORS[team]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0012
	tag.font_size = 16 if is_ai else 24
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.position.y = 10.0 if role == "bomber" else 4.0
	add_child(tag)

	if Sfx.enabled:
		engine_snd = AudioStreamPlayer3D.new()
		engine_snd.stream = Sfx.JET if kind == "fighter" else Sfx.PROP
		engine_snd.unit_size = 60.0 if role == "bomber" else 30.0
		engine_snd.max_distance = 1600.0
		engine_snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		engine_snd.volume_db = -8.0 if is_local() else -2.0
		add_child(engine_snd)
		engine_snd.play(randf() * 0.9)

	if not is_multiplayer_authority():
		hide() # until its first snapshot: by then the spawn position is stale
	if is_local():
		tag.hide()
		cam = Camera3D.new()
		cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
		if Sfx.enabled:
			wind_snd = AudioStreamPlayer.new()
			wind_snd.stream = Sfx.WIND
			wind_snd.volume_db = -30.0
			add_child(wind_snd)
			wind_snd.play()
		cam.top_level = true
		cam.far = 6000
		cam.fov = 75
		add_child(cam)
		cam.make_current()
		main.add_outline(cam)
		hud = Control.new()
		hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.draw.connect(_draw_hud)
		hud.theme = main.ui_theme
		hud_text = Label.new()
		hud_text.position = Vector2(20, 60)
		hud.add_child(hud_text)
		var ui := CanvasLayer.new()
		ui.add_child(hud)
		add_child(ui)
		if not main.bot:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_local() -> bool:
	return is_multiplayer_authority() and not is_ai


func _unhandled_input(event: InputEvent) -> void:
	if is_local() and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.003 * Settings.values.sensitivity
		aim_yaw -= event.relative.x * s
		aim_pitch = clampf(aim_pitch - event.relative.y * s * (-1.0 if Settings.values.invert_y else 1.0), -1.45, 1.45)


func _process(dt: float) -> void:
	var spin := 0.0 if comps[2] <= 0.0 or not alive else 40.0
	for prop in parts.get("props", []):
		prop.rotate_z(spin * dt)
	_audio(dt)
	sim_clock += dt
	if parts.get("trails"):
		_trail_look()
	if parts.has("rockets"):
		_update_hardpoints()
	if parts.get("trails"):
		_update_ribbons()
	if not buffs.is_empty() or shield_fx:
		_tick_buffs(dt)
	if multiplayer.is_server(): # short position history: hit checks rewind to what a lagging shooter saw
		hist.append([Time.get_ticks_msec(), position])
		while hist.size() > 2 and hist[1][0] < hist[-1][0] - 600:
			hist.pop_front()
	if not is_multiplayer_authority():
		_check_stall()
		_interpolate(dt)
		return
	if alive:
		if is_ai:
			main.ai_think(self, dt)
		else:
			_read_input(dt)
		if not role in ["bomber", "balloon", "striker", "prize"]:
			_fly(dt)
			_shoot(dt)
		send_cd -= dt
		# After the match: quiet, so no late snapshot lands after the planes are cleared for the lobby.
		if send_cd <= 0.0 and main.gs.phase == "playing":
			send_cd = SEND_INTERVAL if not is_ai else 0.05 # AI at 20 Hz: a third less host upload, same smoothness
			main.send_snap(self)
	if cam:
		var aim := Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0))
		cam.global_position = position + aim * Vector3(0, 5.5, 19) * CAM_DIST[Settings.values.get("cam", 1)]
		cam.global_basis = aim
		if shake > 0.0:
			shake = maxf(shake - dt * 2.5, 0.0)
			cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 1.2
		cam.fov = lerpf(cam.fov, lerpf(70.0, 90.0, clampf((velocity.length() - 40.0) / 110.0, 0.0, 1.0)), 1.0 - exp(-3.0 * dt))
		var broken := []
		for i in 4:
			if comps[i] < 0.6:
				broken.append("%s %d%%" % [Planes.COMPONENT_NAMES[i], comps[i] * 100])
		var bank: Array = main.gs.get("bank", [0, 0])
		var deploy := "   Supplies %d  [3 AA  4 SAM(2)  5 Radar%s]" % [bank[team], "  6 Repair HQ(2)" if main.gs.mode == 5 else ""] if main.gs.mode != 2 else ""
		if str(name) in main.gs.get("cargo", []) or main._carrying_flag(str(name)):
			deploy += "\n>>> CARRYING %s - FLY HOME <<<" % ("THE FLAG" if main._carrying_flag(str(name)) else "SUPPLIES")
		var bonus := ""
		for id in buffs:
			bonus += "   %s %ds" % [{twin = "TWIN GUNS", shield = "SHIELD", swarm = "ROCKET SWARM"}[id], ceili(buffs[id])]
		hud_text.text = "%s   HP %d   Speed %d   Alt %d   Throttle %d%%   Rockets %d   Bombs %d   Flares %d%s%s%s" % [Planes.variant(kind).name, hp, velocity.length(), position.y, throttle * 100, rockets_left, bombs_left, flares_left, bonus, deploy, ("\nDAMAGED: " + ", ".join(broken)) if broken else ""]
		hud.queue_redraw()


# Engine pitch follows speed; a hurt engine sputters, a dead one winds down; wind rises with speed.
func _audio(dt: float) -> void:
	if not engine_snd:
		return
	var spd := (velocity if is_multiplayer_authority() else vel_estimate()).length()
	var f := clampf((spd - min_speed) / (boost_speed - min_speed), 0.0, 1.0)
	var pitch := (0.75 + 0.6 * f) * (0.6 if role == "bomber" else 1.0) * (1.15 if kind == "racer" else 1.0)
	var gain := 1.0 if alive else 0.0
	if comps[2] <= 0.0:
		pitch = 0.35
		gain *= 0.25
	elif comps[2] < 0.6:
		sputter_t -= dt
		if sputter_t <= 0.0:
			sputter_t = randf_range(0.06, 0.2)
			engine_snd.set_meta("gate", 0.15 if randf() > comps[2] + 0.2 else 1.0)
		gain *= engine_snd.get_meta("gate", 1.0)
	var k := 1.0 - exp(-6.0 * dt)
	engine_snd.pitch_scale = lerpf(engine_snd.pitch_scale, pitch, k)
	engine_snd.volume_linear = lerpf(engine_snd.volume_linear, gain * (0.12 if is_local() else 0.45), k * 2.0)
	if wind_snd:
		wind_snd.volume_linear = lerpf(wind_snd.volume_linear, clampf((spd - 30.0) / 130.0, 0.0, 1.0) * 0.3 * gain, k)
		wind_snd.pitch_scale = 0.8 + 0.4 * f
		warn_cd -= dt
		if alive and warn_cd <= 0.0 and main.rockets.incoming(self):
			warn_cd = 0.3
			Sfx.ui(self, Sfx.WARN, -6.0)
		locked_warn_cd -= dt
		if alive and locked_warn_cd <= 0.0 and not main.rockets.incoming(self) and locked_by():
			locked_warn_cd = 0.5
			Sfx.ui(self, Sfx.LOCK, -14.0, 0.7) # someone is locking you: low beeps
		var locked := lock != null and rocket_aiming
		if locked and not had_lock:
			Sfx.ui(self, Sfx.LOCK, -8.0)
		had_lock = locked


func _read_input(dt: float) -> void:
	if main.bot:
		if ai.is_empty():
			ai = PilotAI.make("pilot", "hunter")
		PilotAI.think(self, dt, main) # test bots fly with the real AI brain
		return
	if main.menu_open():
		wants_fire = false
		wants_rocket = false
		return
	throttle = clampf(throttle + _axis(KEY_S, KEY_W) * 0.7 * dt, 0.0, 1.0)
	wants_boost = Input.is_key_pressed(KEY_SHIFT)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	wants_fire = Input.is_key_pressed(KEY_SPACE) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and captured)
	# Hold RMB/F to aim (shows lock or predicted path), release to fire.
	var held := Input.is_key_pressed(KEY_F) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and captured)
	wants_rocket = rocket_aiming and not held
	rocket_aiming = held
	# Hold B to see where a bomb lands, release to drop. X pops flares.
	var b_held := Input.is_key_pressed(KEY_B)
	wants_bomb = bomb_aiming and not b_held
	bomb_aiming = b_held
	var x := Input.is_key_pressed(KEY_X)
	wants_flare = x and not flare_key
	flare_key = x
	aim_dir = -Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0)).z


func _fly(dt: float) -> void:
	var fwd := -basis.z
	var local := basis.transposed() * aim_dir
	var off := fwd.angle_to(aim_dir)
	var pitch := clampf(local.y * 5.0, -1, 1)
	var yaw := clampf(-local.x * 5.0, -1, 1)
	var roll := lerpf(basis.x.y, clampf(local.x * 5.0, -1, 1), clampf(off / deg_to_rad(10), 0, 1))
	if local.z > 0.0 and absf(local.y) < 0.3:
		pitch = 1.0 # target straight behind: pull up instead of dithering

	var manual := Vector3(_axis(KEY_DOWN, KEY_UP), _axis(KEY_E, KEY_Q), _axis(KEY_LEFT, KEY_RIGHT))
	if not is_ai and manual != Vector3.ZERO and not main.menu_open():
		pitch = manual.x
		yaw = manual.y
		roll = manual.z
		_reset_aim()

	var speed := velocity.length()
	if speed < STALL:
		pitch -= 1.0 - speed / STALL # nose drops in a stall
	roll += (comps[0] - comps[1]) * 0.6 # weaker wing drops: plane pulls toward it
	var tail := 0.45 + 0.55 * comps[3]

	ang = ang.lerp(Vector3(pitch, yaw, clampf(roll, -1, 1)), 1.0 - exp(-8.0 * dt))
	rotate_object_local(Vector3.RIGHT, ang.x * turn.x * tail * dt)
	rotate_object_local(Vector3.UP, ang.y * turn.y * tail * dt)
	rotate_object_local(Vector3.FORWARD, ang.z * turn.z * dt)
	basis = basis.orthonormalized()
	fwd = -basis.z

	var engine := comps[2]
	var boosting := wants_boost and boost > 0.0 and engine > 0.0
	boost = clampf(boost + (-0.35 if boosting else 0.1) * dt, 0.0, 1.0)
	var target := boost_speed if boosting else lerpf(min_speed, max_speed, throttle)
	target = lerpf(min_speed * 0.6, target, 0.35 + 0.65 * engine) if engine > 0.0 else min_speed * 0.55 # dead engine = glide
	speed += (target - speed) * 0.6 * dt - fwd.y * GRAVITY * dt
	speed = clampf(speed, 8.0, 200.0)

	var grip := clampf(speed / STALL, 0.2, 1.0) * 5.0
	velocity = velocity.normalized().slerp(fwd, minf(1.0, grip * dt)) * speed
	if speed < STALL:
		velocity.y -= GRAVITY * (1.0 - speed / STALL) * dt
	velocity.y -= (2.0 - comps[0] - comps[1]) * 3.0 * dt # lost lift from wing damage
	position += velocity * dt
	if main.env:
		position += main.env.air_at(position) * dt # wind, gusts, updrafts carry the plane
	position.x = clampf(position.x, -main.WORLD_SIZE, main.WORLD_SIZE)
	position.z = clampf(position.z, -main.WORLD_SIZE, main.WORLD_SIZE)
	position.y = minf(position.y, 800.0)

	if main.hits_ground(position):
		if multiplayer.is_server():
			main.kill(self, null)
		else:
			alive = false
			main.report_crash.rpc_id(1, main.gs.match_id)


func _shoot(dt: float) -> void:
	fire_cd -= dt
	if wants_fire and fire_cd <= 0.0:
		fire_cd = fire_interval * (1.5 if is_ai else 1.0) * (0.5 if buffs.has("twin") else 1.0)
		var dir := -basis.z
		if is_ai:
			dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02).normalized()
		main.bullets.fire(position - basis.z * 5.0, velocity + dir * BULLET_SPEED, self, true)
		if is_ai:
			main.stat_shots += 1
		shots_out += 1
		if is_local():
			Sfx.ui(main, Sfx.GUNS.get(kind, Sfx.GUN), -3.0, randf_range(0.93, 1.07)) # your own guns: loud and close
		else:
			Sfx.at(main, position, Sfx.GUNS.get(kind, Sfx.GUN), 2.0, 1000.0)
	_track_lock(dt)
	if main.count_local > 0.0: # weapons go live on GO (aiming and locks can be practised)
		wants_fire = false
		wants_rocket = false
		wants_bomb = false
		wants_flare = false
	flare_cd -= dt
	if wants_flare and flare_cd <= 0.0 and flares_left > 0:
		flares_left -= 1
		flare_cd = FLARE_CD
		flare.rpc()
	bomb_cd -= dt
	if wants_bomb and bomb_cd <= 0.0 and bombs_left > 0:
		bombs_left -= 1
		bomb_cd = 0.6
		main.rockets.drop_bomb(self)
	rocket_cd -= dt
	if rocket_cd <= -(1.0 if buffs.has("swarm") else ROCKET_RELOAD) and rockets_left < max_rockets:
		rockets_left += 1
		rocket_cd = 0.0
	if wants_rocket and rocket_cd <= 0.0 and rockets_left > 0:
		rockets_left -= 1
		rocket_cd = 1.0 if not is_ai else 8.0
		main.rockets.launch(self, lock)


# Lock builds while the same target stays in the cone; switching targets starts over.
# Everyone hears who is being locked (locking rpc), so the target gets a LOCKED ON warning.
func _track_lock(dt: float) -> void:
	if lock_on and not is_instance_valid(lock_on):
		lock_on = null
	var cand: Node = find_lock() if rocket_aiming and rockets_left > 0 else null
	if cand != lock_on:
		lock_on = cand
		lock_t = 0.0
		locking.rpc(str(cand.name) if cand else "")
	elif cand:
		lock_t += dt
	lock = lock_on if lock_on and lock_t >= LOCK_TIME else null


@rpc("authority", "call_local", "reliable")
func locking(target_name: String) -> void:
	if target_name.length() > 32:
		return
	locking_name = target_name


# Flares: every rocket already chasing this plane loses it (same on all peers: deterministic).
@rpc("authority", "call_local", "reliable")
func flare() -> void:
	if not is_multiplayer_authority(): # count them here too: no endless flares
		if flares_left <= 0:
			main.tally("flare_empty")
			return
		flares_left -= 1
	main.rockets.decoy(self)
	Sfx.at(main, position, Sfx.FLARE, 2.0, 1500.0)
	Fx.flare_burst(self)


# Who is locking me right now (an enemy plane announcing my name), or null.
func locked_by() -> Node:
	for p in main.players.get_children():
		if p.locking_name == str(name) and p.alive and p.team != team:
			return p
	return null


# Best enemy inside the seeker cone; nil = the rocket flies unguided.
# Server: where this plane was `ago` seconds ago (bounded by the history kept).
func position_at(ago: float) -> Vector3:
	var at := Time.get_ticks_msec() - int(ago * 1000.0)
	for i in range(hist.size() - 1, -1, -1):
		if hist[i][0] <= at:
			return hist[i][1]
	return hist[0][1] if not hist.is_empty() else position


func find_lock() -> Node:
	var best: Node = null
	var best_angle := LOCK_CONE
	for t in get_tree().get_nodes_in_group("targets"):
		if t.team != team and t.alive and position.distance_to(t.position) < LOCK_RANGE:
			var a := (-basis.z).angle_to(t.position - position)
			if a < best_angle:
				best_angle = a
				best = t
	return best


func report_hit(target: Node, weapon := 0, comp := -1) -> void:
	if is_local():
		Sfx.ui(main, (Sfx.HEAVY_HITS if weapon > 0 else Sfx.HITS).pick_random(), -10.0 if weapon == 0 else -4.0) # hit marker
	if multiplayer.is_server():
		main.apply_hit(self, target, weapon, comp)
	else:
		main.report_hit.rpc_id(1, target.name, weapon, comp, main.gs.match_id)


# Damaged component for a world-space hit point on this plane.
func component_at(world: Vector3) -> int:
	var local := global_transform.affine_inverse() * world / body.scale.x
	var best := -1
	var best_d := 3.0
	for i in 4:
		var d: float = local.distance_to(parts.anchors[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func vel_estimate() -> Vector3:
	if is_multiplayer_authority() or snaps.size() < 2:
		return velocity
	var a: Array = snaps[-2]
	var b: Array = snaps[-1]
	return (b[1] - a[1]) / maxf(b[0] - a[0], 0.001)


func _net_jump(before: Vector3, dt: float) -> void:
	var moved := position.distance_to(before)
	if moved > maxf(vel_estimate().length() * dt * 3.0, 6.0):
		main.netstats.jumps += 1 # visible teleport
	# kinks: change of per-frame step (m) and of per-frame rotation (deg) vs the previous frame
	var step := position - before
	var dq: Quaternion = quaternion * get_meta("nq", quaternion).inverse()
	dq = -dq if dq.w < 0.0 else dq
	var turn_v: Vector3 = dq.get_axis() * rad_to_deg(dq.get_angle()) if dq.get_angle() > 1e-6 else Vector3.ZERO
	if has_meta("ns"):
		var ns: Dictionary = main.netstats
		ns.dev_max = maxf(ns.dev_max, (step - get_meta("ns")).length())
		var rd: float = (turn_v - get_meta("nr")).length()
		ns.rdev_max = maxf(ns.rdev_max, rd)
		ns.rdev_sum += rd
	set_meta("ns", step)
	set_meta("nr", turn_v)
	set_meta("nq", quaternion)


# Fed by main._apply_snaps. Unordered on purpose: "ordered" made ENet throw away every snapshot that a
# reordering route delivered late (~40% on a jittery link). Late ones are still useful, so they get slotted in.
func st(t: float, p: Vector3, q: Quaternion) -> void:
	# Owner-sent data: never trust it to be sane (a NaN here poisons rendering, audio and hit tests).
	if t <= floor_t: # from a previous life
		if main.netstats:
			main.netstats.stale += 1
		return
	if not (is_finite(t) and p.is_finite() and q.is_finite()) or absf(p.x) > 9000.0 or absf(p.z) > 9000.0 \
			or p.y < -2000.0 or p.y > 8000.0 or absf(q.length_squared() - 1.0) > 0.01:
		main.tally("snap_bad")
		return
	if get_multiplayer_authority() != 1 and alive and not _snap_ok(t, p): # dead: a respawn we haven't heard of yet may jump
		last_arrival = Time.get_ticks_msec() # still talking: stays visible and targetable where it was
		return
	q = q.normalized()
	var o := t - sim_clock
	clock_off = o if snaps.is_empty() else lerpf(clock_off, o, 0.05)
	var now_ms := Time.get_ticks_msec()
	if last_arrival > 0 and not snaps.is_empty() and t > snaps[-1][0]:
		# Jitter = how far arrival spacing strays from send spacing (works for 20 Hz AI and 30 Hz pilots).
		jitter = lerpf(jitter, absf((now_ms - last_arrival) / 1000.0 * Engine.time_scale - (t - snaps[-1][0])), 0.08)
	if snaps.is_empty() or t > snaps[-1][0]:
		last_arrival = now_ms
	if main.netstats:
		var now := Time.get_ticks_msec()
		var gap: int = now - get_meta("last_snap", now)
		set_meta("last_snap", now)
		main.netstats.snaps += 1
		main.netstats.gap_max = maxi(main.netstats.gap_max, gap)
		if gap > 150:
			main.netstats.gaps150 += 1
	if snaps.is_empty():
		snaps.append([t, p, q])
		position = p
		quaternion = q
		show()
		return
	var i := snaps.size()
	while i > 0 and snaps[i - 1][0] > t: # arrived late: slot in by time
		i -= 1
	if i == 0 or snaps[i - 1][0] == t:
		return # older than the buffer, or a duplicate
	# The new snapshot may move where render_t lands (it ends a guess past the newest); keep the
	# drawn pose where it was and fade the difference out in _interpolate.
	var before := _sample(render_t)
	snaps.insert(i, [t, p, q])
	if snaps.size() > 30:
		snaps.pop_front()
	var after := _sample(render_t)
	var fix: Vector3 = before[0] - after[0]
	err_p += fix
	err_q = before[1] * after[1].inverse() * err_q
	if main.netstats and fix.length() > 1.0:
		main.netstats.corr_n += 1 # a guess past the newest snapshot was off by > 1 m
		main.netstats.corr_sum += fix.length()


# Client-owned planes: no teleports, no speed hacks, no clock running fast. Respawn clears snaps,
# so its legit jump passes; a refused jump fades in once the real elapsed time could cover it.
const SNAP_MAX_SPEED := 320.0 # 200 m/s cap + strongest wind and updraft

func _snap_ok(t: float, p: Vector3) -> bool:
	var now := Time.get_ticks_msec() / 1000.0 * Engine.time_scale
	if clock0.x < 0.0:
		clock0 = Vector2(t, now)
	if t - clock0.x > (now - clock0.y) * 1.02 + 1.0:
		main.tally("snap_clock")
		return false
	if not snaps.is_empty() and p.distance_to(snaps[-1][1]) > SNAP_MAX_SPEED * absf(t - snaps[-1][0]) + 25.0:
		main.tally("snap_jump")
		return false
	return true


func fired() -> void:
	if get_multiplayer_authority() != 1 and not main._allow(get_multiplayer_authority(), "fired", 1.3 / (fire_interval * (0.5 if buffs.has("twin") else 1.0)), 10.0):
		return
	main.bullets.fire(position - basis.z * 5.0, vel_estimate() - basis.z * BULLET_SPEED, self, false)
	Sfx.at(main, position, Sfx.GUNS.get(kind, Sfx.GUN), 2.0, 1000.0)


@rpc("any_peer", "call_local", "reliable")
func set_hp(v: int, c: PackedFloat32Array) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return # only the server may change health / respawn
	if v < hp and is_local():
		Sfx.ui(main, Sfx.HURTS.pick_random(), 0.0, randf_range(0.9, 1.15))
		shake = minf(shake + 0.35, 1.0)
	hp = v
	comps = c
	tag.text = _tag_text()
	_show_damage()


# Smoke from hurt parts, black smoke + stopped prop for a dead engine, wing tip snaps off at 0.
func _show_damage() -> void:
	for i in 4:
		var hurt := comps[i] < 0.6 and alive
		if hurt and not smoke[i]:
			smoke[i] = _make_smoke(parts.anchors[i])
		if smoke[i]:
			smoke[i].emitting = hurt
			smoke[i].color = Color(0.12, 0.1, 0.1) if comps[i] <= 0.0 else Color(0.45, 0.45, 0.48)
	# Badly hurt or engine dead: the plane catches fire.
	var burning := alive and (hp < max_hp * 0.25 or comps[2] <= 0.0)
	if burning and not flames:
		flames = Fx.fire(body.scale.x)
		flames.position = parts.anchors[2] * body.scale.x
		add_child(flames)
	if flames:
		flames.emitting = burning
	if parts.get("ltip"):
		parts.ltip.visible = comps[0] > 0.0
		parts.rtip.visible = comps[1] > 0.0


func _make_smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = 1.4
	p.local_coords = false
	p.position = at * body.scale.x
	var m := SphereMesh.new()
	m.radius = 0.7
	m.height = 1.4
	m.radial_segments = 6
	m.rings = 3
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://toon.gdshader")
	mat.set_shader_parameter("specular_strength", 0.0)
	mat.set_shader_parameter("rim_color", Color(1, 1, 1, 0))
	m.material = mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	add_child(p)
	return p


# Sticker and banner: a pilot's own choice (from the lobby); AI pilots get a stable one from their name.
func _look() -> Array:
	if role == "pilot":
		var info: Dictionary = main.gs.players.get(str(name).to_int(), {})
		return [clampi(int(info.get("sticker", 0)), 0, Planes.STICKERS.size() - 1), clampi(int(info.get("banner", 0)), 0, Planes.BANNERS.size() - 1)]
	var h := absi(hash(pilot))
	return [h % Planes.STICKERS.size(), 0 if h % 3 else (h / 7) % Planes.BANNERS.size()]


# Smoke trails on this screen: off when the setting says so. Your own trail fades with how straight
# behind you the camera looks: faint and thin from the chase view, normal when you look around at it.
var trail_view := 1.0 # 1 = full look, 0 = faint chase-view wisp

func _trail_look() -> void:
	var on: bool = Settings.values.get("trails", true) and alive
	for t: CPUParticles3D in parts.trails:
		t.emitting = on
		t.visible = on
	if not on or not is_local():
		trail_view = 1.0
		return
	if not has_meta("own_trail"): # (known only once spawned) give your own trail its own material
		set_meta("own_trail", true)
		var puff: Mesh = parts.trails[0].mesh.duplicate()
		var mat: StandardMaterial3D = puff.material.duplicate()
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA # melts away right at the lens
		mat.distance_fade_min_distance = 3.0
		mat.distance_fade_max_distance = 10.0
		puff.material = mat
		for t: CPUParticles3D in parts.trails:
			t.mesh = puff
	var cam := get_viewport().get_camera_3d()
	var along := (-cam.global_basis.z).dot(-basis.z) if cam else 1.0 # 1 = camera looks where you fly
	trail_view = lerpf(trail_view, 1.0 - clampf((along - 0.35) / 0.5, 0.0, 1.0), 1.0 - exp(-12.0 * get_process_delta_time()))
	var mat: StandardMaterial3D = parts.trails[0].mesh.material
	mat.albedo_color.a = lerpf(0.28, 1.0, trail_view)
	for t: CPUParticles3D in parts.trails:
		t.scale_amount_min = lerpf(0.3, 1.0, trail_view)
		t.scale_amount_max = t.scale_amount_min


# The first stretch of each smoke trail is a smooth line (the puffs bloom after it): a ribbon through the
# wingtip's last 0.3 s of path, facing the camera, white at the wing and widening into the trail colour.
const RIBBON_MS := 300
var ribbon: MeshInstance3D
var ribbon_pts := [[], []]

func _update_ribbons() -> void:
	var cam := get_viewport().get_camera_3d()
	if not alive or not visible or not cam or not Settings.values.get("trails", true):
		if ribbon:
			ribbon.hide()
		ribbon_pts = [[], []]
		return
	if not ribbon:
		ribbon = MeshInstance3D.new()
		ribbon.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ribbon.material_override = mat
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.top_level = true
		add_child(ribbon)
	ribbon.show()
	ribbon.global_transform = Transform3D.IDENTITY
	var im: ImmediateMesh = ribbon.mesh
	im.clear_surfaces()
	var now := Time.get_ticks_msec()
	var col: Color = parts.get("trail_col", Color.WHITE).lightened(0.35)
	var faint := lerpf(0.3, 1.0, trail_view)
	var thin := lerpf(0.5, 1.0, trail_view)
	for k in 2:
		var pts: Array = ribbon_pts[k]
		pts.append([parts.trails[k].global_position, now])
		while pts.size() > 2 and now - pts[0][1] > RIBBON_MS:
			pts.pop_front()
		if pts.size() < 2:
			continue
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var p: Vector3 = pts[i][0]
			var age := clampf((now - pts[i][1]) / float(RIBBON_MS), 0.0, 1.0)
			var dir: Vector3 = pts[mini(i + 1, pts.size() - 1)][0] - pts[maxi(i - 1, 0)][0]
			var side := dir.cross(cam.global_position - p).normalized()
			var w := lerpf(0.1, 0.7, age) * thin
			var c := Color.WHITE.lerp(col, age)
			c.a = lerpf(0.95, 0.75, age) * faint
			im.surface_set_color(c)
			im.surface_add_vertex(p + side * w)
			im.surface_set_color(c)
			im.surface_add_vertex(p - side * w)
		im.surface_end()


# Remote copies: the owner's ammo counts arrive with its snapshots, so everyone sees the same hardpoints.
func show_ammo(rockets: int, bombs: int) -> void:
	rockets_left = rockets
	bombs_left = bombs


# Rockets / bombs hanging under the plane vanish as they're fired and come back on refill.
func _update_hardpoints() -> void:
	var key := rockets_left * 16 + bombs_left
	if key == ammo_shown:
		return
	ammo_shown = key
	var rs: Array = parts.get("rockets", [])
	for i in rs.size():
		rs[i].visible = i < rockets_left
	var bs: Array = parts.get("bombs", [])
	for i in bs.size():
		bs[i].visible = i < bombs_left


# Prize-balloon reward on this plane (server decides; everyone runs the timer and the visuals).
@rpc("any_peer", "call_local", "reliable")
func buff(id: String, secs: float) -> void:
	if multiplayer.get_remote_sender_id() > 1 or not id in ["twin", "shield", "swarm"]:
		return
	buffs[id] = clampf(secs, 0.0, 30.0)
	if id == "swarm":
		rockets_left = max_rockets
		main.refill(self)
	if is_local():
		Sfx.ui(main, Sfx.FANFARE, -4.0)


func _tick_buffs(dt: float) -> void:
	for id in buffs.keys():
		buffs[id] -= dt
		if buffs[id] <= 0.0 or not alive:
			buffs.erase(id)
	var shielded := buffs.has("shield")
	if shielded and not shield_fx:
		shield_fx = MeshInstance3D.new()
		shield_fx.mesh = SphereMesh.new()
		shield_fx.mesh.radius = hit_radius * 1.6
		shield_fx.mesh.height = hit_radius * 3.2
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.4, 0.85, 1.0, 0.18)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		shield_fx.material_override = m
		shield_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shield_fx)
	elif not shielded and shield_fx:
		shield_fx.queue_free()
		shield_fx = null


func _tag_text() -> String:
	return "%s %d%%" % [pilot, 100 * hp / max_hp] if role == "bomber" else pilot


@rpc("any_peer", "call_local", "reliable")
func resupply() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	rockets_left = max_rockets
	flares_left = max_flares
	bombs_left = max_bombs
	boost = 1.0
	main.refill(self)
	if is_local():
		Sfx.ui(main, Sfx.CONFIRM, 0.0)


@rpc("any_peer", "call_local", "reliable")
func die(fx: bool) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	alive = false
	died_ms = Time.get_ticks_msec()
	body.hide()
	tag.hide()
	_show_damage()
	if fx and role in ["balloon", "prize"]:
		Fx.pop(main, position, role == "prize") # balloons burst, they don't crash like planes
	elif fx:
		main.boom(position, 0.7)
		Fx.shoot_down(main, body, global_transform, velocity if is_multiplayer_authority() else vel_estimate())


@rpc("any_peer", "call_local", "reliable")
func respawn(p: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return # only the server may change health / respawn
	hp = max_hp
	alive = true
	rockets_left = max_rockets
	flares_left = max_flares
	bombs_left = max_bombs
	lock_on = null
	lock = null
	buffs.clear()
	main.refill(self)
	comps = PackedFloat32Array([1, 1, 1, 1])
	position = p
	rotation = Vector3(0, yaw, 0)
	velocity = -basis.z * 60.0
	throttle = 0.5
	boost = 1.0
	ang = Vector3.ZERO
	if not snaps.is_empty():
		floor_t = snaps[-1][0]
	snaps.clear()
	shots_out = 0
	last_arrival = Time.get_ticks_msec() # the owner's snapshots resume after this reaches them
	err_p = Vector3.ZERO
	err_q = Quaternion.IDENTITY
	if not is_multiplayer_authority():
		hide() # until a new-life snapshot: one that beat this RPC here was just cleared
	body.show()
	if not is_local():
		tag.show()
	_show_damage()
	_reset_aim()


# A remote pilot whose snapshots stopped (connection stall) would hang in the air as a free kill:
# hidden and untargetable (out of "targets") until they resume. The host enforces it in apply_hit.
func _check_stall() -> void:
	if snaps.is_empty():
		return # hidden on purpose until the first snapshot of this life arrives
	# Not after the match: owners go quiet on purpose then.
	var stalled: bool = alive and not is_ai and main.gs.phase == "playing" and get_multiplayer_authority() != 1 and last_arrival > 0 and Time.get_ticks_msec() - last_arrival > STALL_MS
	if stalled != visible:
		return
	visible = not stalled
	main.netlog("%s %s" % [pilot, "stalled: hidden, no hits" if stalled else "snapshots resumed"])
	if stalled:
		remove_from_group("targets")
	else:
		add_to_group("targets")


# Remote planes render ~100 ms in the past, between two real snapshots, so packet jitter never
# shows. Past the newest one they dead-reckon (velocity + turn rate) for up to EXTRAP_MAX.
func _interpolate(dt: float) -> void:
	if snaps.is_empty():
		return
	# Steady links: 100 ms behind. Jittery or lossy ones: wait longer so there is always a next snapshot.
	# Render time follows the owner's clock (not the newest arrival), so it keeps running through
	# an outage; it only speeds up or slows down to re-centre, never runs backwards.
	var target := sim_clock + clock_off - clampf(INTERP_DELAY + 2.5 * jitter, INTERP_DELAY, 0.35)
	var behind := target - render_t
	render_t = target if absf(behind) > 1.0 else render_t + dt * clampf(1.0 + 2.0 * behind, 0.75, 1.25)
	if main.netstats and alive and visible:
		var ns: Dictionary = main.netstats
		ns.frames += 1
		if render_t > snaps[-1][0]:
			ns.extrap += 1 # guessing past the newest snapshot
		if render_t > snaps[-1][0] + EXTRAP_MAX:
			ns.stall += 1 # out of guesses: frozen
		var before := position
		call_deferred("_net_jump", before, dt)
	elif has_meta("ns"):
		remove_meta("ns")
		remove_meta("nq")
	var k := 1.0 - exp(-3.0 * dt)
	err_p = Vector3.ZERO if err_p.length() > 100.0 else err_p.lerp(Vector3.ZERO, k) # way off: snap
	err_q = err_q.slerp(Quaternion.IDENTITY, k)
	var pose := _sample(render_t)
	position = pose[0] + err_p
	quaternion = (err_q * pose[1]).normalized()


# Pose at owner time `at`: between two snapshots, or dead-reckoned (constant turn) past the newest.
func _sample(at: float) -> Array:
	var n := snaps.size()
	if n == 1 or at <= snaps[0][0]:
		return [snaps[0][1], snaps[0][2]]
	var i := n - 1
	while i > 1 and snaps[i - 1][0] > at:
		i -= 1
	var a: Array = snaps[i - 1]
	var b: Array = snaps[i]
	var span: float = maxf(b[0] - a[0], 0.001)
	if at <= b[0]:
		var w: float = (at - a[0]) / span
		return [a[1].lerp(b[1], w), a[2].slerp(b[2], w)]
	var turn_q: Quaternion = b[2] * a[2].inverse()
	turn_q = -turn_q if turn_q.w < 0.0 else turn_q
	var s := minf(at - b[0], EXTRAP_MAX)
	# 16-bit packed rotations can give an angle with a zero axis: that's "not turning", not an error.
	var axis := Vector3(turn_q.x, turn_q.y, turn_q.z)
	var rate := turn_q.get_angle() / span if axis.length_squared() > 1e-12 else 0.0
	axis = axis.normalized() if rate > 1e-4 else Vector3.UP
	var v: Vector3 = (b[1] - a[1]) / span # average over a..b: the heading half a step back
	return [b[1] + Quaternion(axis, rate * (span + s) * 0.5) * v * s, Quaternion(axis, rate * s) * b[2]]


func _reset_aim() -> void:
	var fwd := -basis.z
	aim_yaw = atan2(-fwd.x, -fwd.z)
	aim_pitch = asin(clampf(fwd.y, -1, 1))
	aim_dir = fwd


func _axis(neg: Key, pos: Key) -> float:
	return float(Input.is_key_pressed(pos)) - float(Input.is_key_pressed(neg))


func _draw_hud() -> void:
	var c := hud.size / 2
	hud.draw_arc(c, 14, 0, TAU, 32, Color(1, 1, 1, 0.8), 2) # where you're aiming
	var nose := position - basis.z * 400.0
	if alive and not cam.is_position_behind(nose):
		var p := cam.unproject_position(nose) # where your guns point
		hud.draw_line(p - Vector2(10, 0), p + Vector2(10, 0), Color.YELLOW, 2)
		hud.draw_line(p - Vector2(0, 10), p + Vector2(0, 10), Color.YELLOW, 2)
	hud.draw_rect(Rect2(20, 40, 200, 10), Color(0, 0, 0, 0.5))
	hud.draw_rect(Rect2(20, 40, 200.0 * hp / max_hp, 10), Color(0.3, 1, 0.4))
	hud.draw_rect(Rect2(20, 90, 200.0 * boost, 4), Color(0.4, 0.8, 1))
	if not alive:
		return
	if lock and lock.alive and not cam.is_position_behind(lock.position):
		var p := cam.unproject_position(lock.position)
		hud.draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), Color.RED, false, 2)
		hud.draw_string(ThemeDB.fallback_font, p + Vector2(-16, -24), "LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.RED)
	elif lock_on and is_instance_valid(lock_on) and lock_on.alive and not cam.is_position_behind(lock_on.position):
		# Acquiring: the box closes in as the lock builds.
		var p := cam.unproject_position(lock_on.position)
		var k := clampf(lock_t / LOCK_TIME, 0.0, 1.0)
		var half := lerpf(46.0, 18.0, k)
		hud.draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(1, 0.85, 0.2), false, 2)
		hud.draw_string(ThemeDB.fallback_font, p + Vector2(-30, -half - 6), "LOCKING %d%%" % (k * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.2))
	elif rocket_aiming and rockets_left > 0:
		# Unguided: show where the rocket would actually go (same integrator as the real one).
		for q in main.rockets.predict(position - basis.z * 6.0, velocity - basis.z * 20.0):
			if not cam.is_position_behind(q):
				hud.draw_circle(cam.unproject_position(q), 2.5, Color(1, 1, 1, 0.6))
	if bomb_aiming and bombs_left > 0:
		var at: Vector3 = main.rockets.bomb_impact(position + Vector3.DOWN * 2.0, velocity)
		if not cam.is_position_behind(at):
			var q := cam.unproject_position(at)
			hud.draw_arc(q, 16, 0, TAU, 24, Color(1, 0.6, 0.2), 2.5)
			hud.draw_line(q - Vector2(24, 0), q + Vector2(24, 0), Color(1, 0.6, 0.2), 1.5)
			hud.draw_line(q - Vector2(0, 24), q + Vector2(0, 24), Color(1, 0.6, 0.2), 1.5)
			hud.draw_string(ThemeDB.fallback_font, q + Vector2(20, -10), "BOMB  %dm" % position.distance_to(at), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.6, 0.2))
	if main.rockets.incoming(self):
		hud.draw_string(ThemeDB.fallback_font, Vector2(hud.size.x / 2 - 110, hud.size.y - 120), "MISSILE!  [X] FLARES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.RED)
		_draw_threats()
	elif locked_by():
		hud.draw_string(ThemeDB.fallback_font, Vector2(hud.size.x / 2 - 70, hud.size.y - 120), "LOCKED ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.6, 0.2))


# Missiles chasing you: a red diamond on each with its distance, or a red arrow on the screen edge
# pointing at it when it's off-screen / behind, so you know which way to break.
func _draw_threats() -> void:
	var red := Color(1.0, 0.22, 0.18)
	var font := ThemeDB.fallback_font
	var c := hud.size / 2.0
	for r in main.rockets.rockets.values():
		if r.target != self or r.bomb:
			continue
		var dist := position.distance_to(r.p)
		if not cam.is_position_behind(r.p):
			var q := cam.unproject_position(r.p)
			if Rect2(Vector2.ZERO, hud.size).grow(-30.0).has_point(q):
				var d := PackedVector2Array([q + Vector2(0, -16), q + Vector2(16, 0), q + Vector2(0, 16), q + Vector2(-16, 0), q + Vector2(0, -16)])
				hud.draw_polyline(d, red, 3.0)
				hud.draw_string(font, q + Vector2(20, 6), "%dm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, red)
				continue
		var local: Vector3 = cam.global_transform.basis.inverse() * (r.p - cam.global_position)
		var behind := local.z > 0.0
		var dir := Vector2(local.x, -local.y).normalized()
		if behind: # bottom of the screen = behind you, nudged toward its side
			dir = (dir * 0.5 + Vector2.DOWN).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		var tip := c + dir * (minf(hud.size.x, hud.size.y) / 2.0 - 50.0)
		var side := dir.orthogonal()
		hud.draw_colored_polygon(PackedVector2Array([tip + dir * 22.0, tip - dir * 10.0 + side * 16.0, tip - dir * 10.0 - side * 16.0]), red)
		hud.draw_string(font, tip - dir * 44.0 + Vector2(-36, 6), ("BEHIND %dm" if behind else "%dm") % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, red)


func _build_mesh() -> void:
	var c: Color = Color(1.0, 0.78, 0.2) if role == "prize" else TEAM_COLORS[team]
	if role == "bomber":
		c = Color(0.62, 0.6, 0.38)
	elif role == "striker":
		c = TEAM_COLORS[team].lerp(Color(0.62, 0.6, 0.38), 0.5)
	elif is_ai:
		c = c.darkened(0.3)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	parts = Planes.build(kind, body, main.toon(c), main.toon(Color(0.95, 0.93, 0.85)), main.toon(Color(0.15, 0.2, 0.3)), main.toon(Color(0.2, 0.2, 0.22)), glow)
	if role in ["pilot", "wing", "fighter", "showcase"]:
		var look := _look()
		Planes.dress(kind, body, parts, max_rockets, max_bombs, look[0], look[1], main.toon(Color(0.2, 0.2, 0.22)), Callable(main, "toon"))

	elif role == "prize":
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.3)
		light.light_energy = 3.0
		light.omni_range = 40.0
		body.add_child(light)
