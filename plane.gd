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
const TEAM_COLORS := [Color(0.3, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const ROCKETS := 4
const ROCKET_RELOAD := 6.0
const LOCK_CONE := 0.35 # ~20 deg
const LOCK_RANGE := 1300.0

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
var wants_rocket := false
var rocket_aiming := false
var rockets_left := ROCKETS
var rocket_cd := 0.0
var lock: Node

# AI state (server): PilotAI keeps its memory here
var ai := {}
var wp := 1
var offset := Vector3.ZERO

var snaps: Array = [] # [t, pos, quat], owner's game clock
var sim_clock := 0.0 # owner's game time (same units as dt, so time-scale safe)
var render_t := 0.0

var main: Node
var body := Node3D.new()
var tag := Label3D.new()
var cam: Camera3D
var hud: Control
var hud_text := Label.new()
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
	if role == "striker":
		max_hp = 900
		hit_radius = t.radius * 2.0
		body.scale = Vector3.ONE * 2.0
	elif role == "bomber":
		max_hp = 1000
		hit_radius = t.radius * 2.5
		body.scale = Vector3.ONE * 2.5
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
	tag.modulate = TEAM_COLORS[team]
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
	if not is_multiplayer_authority():
		_interpolate(dt)
		return
	if alive:
		if is_ai:
			main.ai_think(self, dt)
		else:
			_read_input(dt)
		if not role in ["bomber", "balloon", "striker"]:
			_fly(dt)
			_shoot(dt)
		send_cd -= dt
		if send_cd <= 0.0:
			send_cd = SEND_INTERVAL
			st.rpc(sim_clock, position, quaternion)
	if cam:
		var aim := Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0))
		cam.global_position = position + aim * Vector3(0, 5.5, 19)
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
		hud_text.text = "%s   HP %d   Speed %d   Alt %d   Throttle %d%%   Rockets %d%s%s" % [Planes.TYPES[kind].name, hp, velocity.length(), position.y, throttle * 100, rockets_left, deploy, ("\nDAMAGED: " + ", ".join(broken)) if broken else ""]
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
	if main.pause_root.visible:
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
	lock = find_lock()
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
	if not is_ai and manual != Vector3.ZERO:
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
			main.report_crash.rpc_id(1)


func _shoot(dt: float) -> void:
	fire_cd -= dt
	if wants_fire and fire_cd <= 0.0:
		fire_cd = fire_interval * (1.5 if is_ai else 1.0)
		var dir := -basis.z
		if is_ai:
			dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02).normalized()
		main.bullets.fire(position - basis.z * 5.0, velocity + dir * BULLET_SPEED, self, true)
		if is_ai:
			main.stat_shots += 1
		fired.rpc()
		if is_local():
			Sfx.ui(main, Sfx.GUN, -3.0, randf_range(0.93, 1.07)) # your own guns: loud and close
		else:
			Sfx.at(main, position, Sfx.GUN, 2.0, 1000.0)
	rocket_cd -= dt
	if rocket_cd <= -ROCKET_RELOAD and rockets_left < max_rockets:
		rockets_left += 1
		rocket_cd = 0.0
	if wants_rocket and rocket_cd <= 0.0 and rockets_left > 0:
		rockets_left -= 1
		rocket_cd = 1.0 if not is_ai else 8.0
		main.rockets.launch(self, lock)


# Best enemy inside the seeker cone; nil = the rocket flies unguided.
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
		Sfx.ui(main, Sfx.HITS.pick_random(), -10.0) # hit marker
	if multiplayer.is_server():
		main.apply_hit(self, target, weapon, comp)
	else:
		main.report_hit.rpc_id(1, target.name, weapon, comp)


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


@rpc("authority", "unreliable_ordered")
func st(t: float, p: Vector3, q: Quaternion) -> void:
	if not snaps.is_empty() and t <= snaps[-1][0]:
		return
	snaps.append([t, p, q])
	if snaps.size() > 30:
		snaps.pop_front()


@rpc("authority", "unreliable")
func fired() -> void:
	main.bullets.fire(position - basis.z * 5.0, vel_estimate() - basis.z * BULLET_SPEED, self, false)
	Sfx.at(main, position, Sfx.GUN, 2.0, 1000.0)


@rpc("any_peer", "call_local", "reliable")
func set_hp(v: int, c: PackedFloat32Array) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return # only the server may change health / respawn
	if v < hp and is_local():
		Sfx.ui(main, Sfx.HURT, 0.0, randf_range(0.9, 1.15))
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


func _tag_text() -> String:
	return "%s %d%%" % [pilot, 100 * hp / max_hp] if role == "bomber" else pilot


@rpc("any_peer", "call_local", "reliable")
func resupply() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	rockets_left = max_rockets
	boost = 1.0
	if is_local():
		Sfx.ui(main, Sfx.CONFIRM, 0.0)


@rpc("any_peer", "call_local", "reliable")
func die(fx: bool) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	alive = false
	body.hide()
	tag.hide()
	_show_damage()
	if fx:
		main.boom(position, 0.7)
		Fx.shoot_down(main, body, global_transform, velocity if is_multiplayer_authority() else vel_estimate())


@rpc("any_peer", "call_local", "reliable")
func respawn(p: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return # only the server may change health / respawn
	hp = max_hp
	alive = true
	rockets_left = max_rockets
	comps = PackedFloat32Array([1, 1, 1, 1])
	position = p
	rotation = Vector3(0, yaw, 0)
	velocity = -basis.z * 60.0
	throttle = 0.5
	boost = 1.0
	ang = Vector3.ZERO
	snaps.clear()
	body.show()
	if not is_local():
		tag.show()
	_show_damage()
	_reset_aim()


# Remote planes render ~100 ms in the past, between two real snapshots,
# so packet jitter never shows. Small extrapolation covers a late packet.
func _interpolate(dt: float) -> void:
	if snaps.is_empty():
		return
	var target: float = snaps[-1][0] - INTERP_DELAY
	render_t += dt
	render_t = target if absf(render_t - target) > 0.5 else lerpf(render_t, target, 0.05)
	for i in range(snaps.size() - 1, 0, -1):
		var a: Array = snaps[i - 1]
		if a[0] <= render_t:
			var b: Array = snaps[i]
			var span: float = maxf(b[0] - a[0], 0.001)
			var w := clampf((render_t - a[0]) / span, 0.0, 1.0 + 0.25 / span)
			position = a[1].lerp(b[1], w)
			quaternion = a[2].slerp(b[2], minf(w, 1.0))
			return
	position = snaps[0][1]
	quaternion = snaps[0][2]


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
	elif rocket_aiming and rockets_left > 0:
		# Unguided: show where the rocket would actually go (same integrator as the real one).
		for q in main.rockets.predict(position - basis.z * 6.0, velocity - basis.z * 20.0):
			if not cam.is_position_behind(q):
				hud.draw_circle(cam.unproject_position(q), 2.5, Color(1, 1, 1, 0.6))
	if main.rockets.incoming(self):
		hud.draw_string(ThemeDB.fallback_font, Vector2(hud.size.x / 2 - 60, hud.size.y - 120), "MISSILE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.RED)


func _build_mesh() -> void:
	var c: Color = TEAM_COLORS[team]
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
