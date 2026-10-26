class_name Env
extends Node3D

# World mechanics that change how you fly: wind + gusts drift every plane (AI included), updraft
# columns lift (negative = downdraft), storms cut visibility and add wind, weather particles follow
# the camera, hazards (lava bombs, lightning) hurt. Config: Worlds.cur.env. Server decides hazards
# and storm timing; clients just render what the server announces.
var cfg: Dictionary
var main: Node
var t := 0.0
var storm := 0.0 # 0 calm .. 1 full storm (eased toward main.gs.storm)
var weather: CPUParticles3D
var env: Environment
var base_fog := Vector2.ZERO
var hazard_t := {}
var bombs: Array = [] # {node, p, v, t}


func setup(m: Node, world_env: Environment) -> void:
	main = m
	env = world_env
	cfg = Worlds.cur.env
	base_fog = Vector2(env.fog_depth_begin, env.fog_depth_end)
	if cfg.weather != "":
		weather = _weather(cfg.weather)
		add_child(weather)


# Velocity of the air at p: planes are carried by it on top of their own flight.
func air_at(p: Vector3) -> Vector3:
	var w: Vector3 = cfg.wind * (1.0 + storm * cfg.storm.get("wind_mul", 0.0))
	var g: float = cfg.gust * (1.0 + storm)
	if g > 0.0:
		w += Vector3(sin(t * 0.37 + p.z * 0.002), sin(t * 0.23) * 0.3, cos(t * 0.29 + p.x * 0.002)) * g
	for u in cfg.updrafts:
		var d: float = Vector2(p.x - u.pos.x, p.z - u.pos.z).length()
		if d < u.radius and p.y < u.get("top", 900.0):
			w.y += u.strength * (1.0 - d / u.radius) * (1.0 - d / u.radius)
	return w


func _process(dt: float) -> void:
	t += dt
	storm = move_toward(storm, main.gs.get("storm", 0.0), dt * 0.15)
	if env and not cfg.storm.is_empty():
		var thick: float = cfg.storm.get("fog", 0.6) * storm
		env.fog_depth_begin = base_fog.x * (1.0 - thick)
		env.fog_depth_end = base_fog.y * (1.0 - thick * 0.85)
	var cam := get_viewport().get_camera_3d()
	if weather and cam:
		weather.global_position = cam.global_position + Vector3.UP * 60.0
		weather.speed_scale = 1.0 + storm * 0.6 # heavier-feeling snow/sand during storms
	for b in bombs:
		b.t += dt
		b.v += Vector3.DOWN * 22.0 * dt
		b.p += b.v * dt
		b.node.global_position = b.p
		if multiplayer.is_server() and main.gs.phase == "playing":
			for pl in main.players.get_children():
				if pl.alive and pl.position.distance_to(b.p) < 14.0 + pl.hit_radius:
					main.env_hit(pl, 40, "a lava bomb")
					b.t = 99.0
		if b.p.y < Terrain.ground(b.p.x, b.p.z) or b.t > 20.0:
			main.boom(b.p, 0.8)
			b.node.queue_free()
	bombs = bombs.filter(func(b): return is_instance_valid(b.node) and not b.node.is_queued_for_deletion())


# Server: storm cycle and hazard timers. Called from main._process while playing.
func server_tick(dt: float) -> void:
	if not cfg.storm.is_empty():
		var period: float = cfg.storm.get("period", 120.0)
		var on: bool = fmod(t, period) > period - cfg.storm.get("length", 35.0)
		if on != (main.gs.storm > 0.5):
			main.gs.storm = 1.0 if on else 0.0
			main.feed_msg(cfg.storm.get("warn", "Storm incoming!") if on else "The storm is passing.")
	for kind in cfg.hazards:
		var h: Dictionary = cfg.hazards[kind]
		hazard_t[kind] = hazard_t.get(kind, randf() * h.rate) - dt * (1.0 + storm)
		if hazard_t[kind] > 0.0:
			continue
		hazard_t[kind] = h.rate * randf_range(0.6, 1.4)
		match kind:
			"lava_bombs":
				for i in h.get("burst", 3):
					var o: Vector3 = h.origin
					var v := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(30, 90) + Vector3.UP * randf_range(80, 140)
					main.env_event.rpc("bomb", o, v)
			"lightning":
				var targets: Array = main.players.get_children().filter(func(p): return p.alive and p.role != "balloon")
				if targets.is_empty():
					continue
				var tp: Node = targets.pick_random()
				var at: Vector3 = tp.position + Vector3(randf_range(-90, 90), randf_range(-30, 30), randf_range(-90, 90))
				main.env_event.rpc("warn", at, Vector3.ZERO)
				get_tree().create_timer(0.9).timeout.connect(func():
					if not is_instance_valid(main) or main.gs.phase != "playing":
						return
					main.env_event.rpc("bolt", at, Vector3.ZERO)
					for p in main.players.get_children():
						if p.alive and p.position.distance_to(at) < h.get("radius", 55.0):
							main.env_hit(p, h.get("damage", 35), "lightning"))


# Everyone: render an announced hazard.
func show_event(kind: String, at: Vector3, v: Vector3) -> void:
	match kind:
		"bomb":
			var n := Node3D.new()
			add_child(n)
			n.add_child(Fx.fire(2.2))
			var trail := Fx.smoke(1.2, 2.0, Color(0.15, 0.12, 0.1))
			n.add_child(trail)
			bombs.append({node = n, p = at, v = v, t = 0.0})
		"warn":
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.7, 0.8, 1.0)
			glow.light_energy = 4.0
			glow.omni_range = 160.0
			add_child(glow)
			glow.global_position = at + Vector3.UP * 120.0
			glow.create_tween().tween_property(glow, "light_energy", 0.0, 0.9).finished.connect(glow.queue_free)
		"bolt":
			_bolt(at)


func _bolt(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(4.0, 4.5, 6.0)
	var root := Node3D.new()
	add_child(root)
	var p := at + Vector3(randf_range(-40, 40), 450.0, randf_range(-40, 40))
	while p.y > at.y:
		var q := p + Vector3(randf_range(-25, 25), -randf_range(35, 70), randf_range(-25, 25))
		if q.y < at.y:
			q = at
		var seg := MeshInstance3D.new()
		seg.mesh = BoxMesh.new()
		seg.mesh.size = Vector3(1.6, 1.6, p.distance_to(q))
		seg.material_override = mat
		root.add_child(seg)
		seg.global_transform = Transform3D(Basis.looking_at(q - p), (p + q) / 2.0)
		p = q
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.8, 0.85, 1.0)
	flash.light_energy = 12.0
	flash.omni_range = 600.0
	root.add_child(flash)
	flash.global_position = at
	main.boom(at, 0.5)
	Sfx.at(main, at, Sfx.THUNDER, 8.0, 4000.0)
	var tw := root.create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(root.queue_free)


func _weather(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 900
	p.lifetime = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(350, 40, 350)
	var m := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	p.direction = Vector3.DOWN
	p.spread = 10.0
	match kind:
		"snow", "ash":
			# Soft round flakes (a tiny low-poly sphere) instead of square quads.
			var ball := SphereMesh.new()
			ball.radius = 0.55 if kind == "snow" else 0.45
			ball.height = ball.radius * 2.0
			ball.radial_segments = 6
			ball.rings = 3
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			mat.albedo_color = Color(1, 1, 1, 0.9) if kind == "snow" else Color(0.68, 0.65, 0.62, 0.75)
			ball.material = mat
			p.mesh = ball
			p.initial_velocity_min = 25.0 if kind == "snow" else 10.0
			p.initial_velocity_max = 40.0 if kind == "snow" else 22.0
		"sand":
			m.size = Vector2(3.0, 0.6)
			mat.albedo_color = Color(0.95, 0.75, 0.45, 0.55)
			p.direction = (Vector3(cfg.wind.x, -0.2, cfg.wind.z) if cfg.wind != Vector3.ZERO else Vector3(1, -0.2, 0)).normalized()
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 90.0
		"rain":
			m.size = Vector2(0.25, 6.0)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			mat.albedo_color = Color(0.7, 0.8, 1.0, 0.5)
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 160.0
	return p
