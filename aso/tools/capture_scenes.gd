extends SceneTree
# Raw App Store scenes for the Strategy A storyboard (aso/screenshot-storyboard.md), real gameplay, phone HUD.
# Based on tools/appstore_shots.gd (copied, not edited).
#   godot --path . --resolution 2868x1320 -s aso/tools/capture_scenes.gd -- --phone --fake-store [--only a,b]
# Scenes: lan (dogfight + taunt, 4 game instances over localhost LAN), lobby (online room, 3 joined instances),
#   ai, rocket, weather, worlds, ctf, shop, assault. Writes takes to OUT; picks are copied to aso/creative/raw/sel_*.png.
# Staging only moves the camera/your plane (position, aim) and fast-forwards the storm clock; everything drawn is the game.
# Store-art cleanup (_clean), every frame: the top HUD row, kill feed, your stats line, the touch controls, the world
# markers (SUPPLY, REVIVE, PRIZE BALLOON, lead rings) and balloon name tags are hidden; the plane HUD (crosshair,
# lock box) shows only where show_hud is set (frame 05).
# settings.cfg is restored byte-for-byte at the end; the user's running game is never touched.
const OUT := "res://aso/creative/takes/v6/" # pick takes from here, copy to raw/sel_*.png
const LAN_PORT := 7853
const FRIENDS := ["Riya", "Kabir", "Dev"]
# Close duel framing for 01 and 04: [distance ahead, side, height, camera drop, camera yaw] (m, rad). Target up-left
# of your plane: revision 2's chosen take (first row), then the same angles closer. The 0.3 drop keeps the camera
# looking down, which separates the two planes; compose_screens.gd zooms the frame in further.
const CLOSE := [[22.0, 14.0, -8.0, 0.3, -0.45], [18.0, 11.5, -6.5, 0.3, -0.45], [16.0, 10.0, -6.0, 0.32, -0.5],
	[20.0, 13.0, -7.0, 0.28, -0.5], [14.0, 9.0, -5.0, 0.32, -0.5], [18.0, 12.0, -6.0, 0.3, -0.55]]
var main: Node
var pids: Array[int] = []
var only: PackedStringArray
var show_hud := false
var lan_world := 1
var lan_plane := "cub"


func _clean() -> void:
	if not is_instance_valid(main):
		return
	main.top.modulate.a = 0.0
	main.feed.modulate.a = 0.0
	main.overlay.modulate.a = 0.0
	if main.touch:
		main.touch.modulate.a = 0.0
	var me := _me()
	for p in main.players.get_children():
		if p.role in ["balloon", "prize"] or show_hud and me and p != me.lock: # 05: only the locked target keeps its tag
			p.tag.visible = false
	if me and me.hud:
		me.hud_text.modulate.a = 0.0
		me.hud.modulate.a = 1.0 if show_hud else 0.0


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, settle := 3) -> void:
	await _frames(settle)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved %s %dx%d" % [name, img.get_width(), img.get_height()])


func _look() -> void:
	Settings.values.matches = 101 # past the tutorial cards
	Settings.values.sticker = 6 # Shark Mouth, a free sticker
	Settings.values.banner = 0
	Settings.values.livery = 0
	Settings.values.killfx = 0
	Settings.values.cam = 1
	Settings.values.autofire = false
	Settings.values.trails = false # wingtip smoke reads as white streaks at thumbnail size


func _fresh() -> void:
	if main:
		main.queue_free()
		await process_frame
	if get_multiplayer().multiplayer_peer:
		get_multiplayer().multiplayer_peer.close()
	get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	for pid in pids:
		OS.kill(pid)
	pids.clear()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_look() # after _ready's load_saved, in memory only
	show_hud = false
	roll = 0.0
	main.name_edit.text = "Arjun"
	await _wait(0.6)


func _until_flying() -> void:
	var t0 := Time.get_ticks_msec()
	while (main.gs.get("countdown", 1.0) > 0.0 or main._plane(get_multiplayer().get_unique_id()) == null) and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	main.intro_t = 0.0
	main.keys_t = 0.0
	main.show_map = false # the MAP button's "hidden" state: hides the desktop "M hide N zoom" caption (main.gd:2325)


func _fly(world: int, mode: int, size := 0, skill := 1, plane := "cub") -> void:
	main.name_edit.text = "Arjun"
	main.plane_choice = plane
	main.solo_battle()
	await _wait(0.3)
	main.request_plane(plane)
	main.request_world(world)
	await _wait(1.5)
	main.request_mode(mode)
	main.request_battle(size, skill)
	await _wait(0.3)
	main.request_start()
	await _until_flying()


func _me() -> Node:
	return main._plane(get_multiplayer().get_unique_id())


func _touch(id: String, down: bool, finger: int) -> void:
	var tc: Control = main.find_children("*", "TouchControls", true, false)[0]
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * tc._center(id)
	e.pressed = down
	Input.parse_input_event(e)


func _vel(t: Node) -> Vector3:
	var v: Vector3 = t.velocity if t.is_multiplayer_authority() else t.vel_estimate()
	return v if v.length() > 5.0 else -t.basis.z * 80.0


# Put your plane `dist` behind `t` (plus up/side offset) at its speed, nose on it (same velocity, so no lead).
# `drop` / `yaw` turn the camera that much below / beside the target, so it sits off your plane's line in frame.
func _pin(t: Node, dist: float, up: float, side := 0.0, drop := 0.0, yaw := 0.0) -> void:
	var me := _me()
	if not me or not is_instance_valid(t):
		return
	var v := _vel(t)
	var d := v.normalized()
	var right := d.cross(Vector3.UP).normalized()
	me.position = t.position - d * dist + Vector3.UP * up + right * side
	me.velocity = v
	_aim(me, t.position - me.position)
	me.aim_pitch -= drop
	me.aim_yaw += yaw


func _aim(me: Node, dir: Vector3) -> void:
	dir = dir.normalized()
	me.basis = Basis.looking_at(dir)
	me.aim_yaw = atan2(-dir.x, -dir.z)
	me.aim_pitch = asin(clampf(dir.y, -1, 1))


func _pin_for(t: Node, secs: float, dist: float, up: float, side := 0.0, drop := 0.0, yaw := 0.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 and is_instance_valid(t) and t.alive:
		_pin(t, dist, up, side, drop, yaw)
		await process_frame


# Hold your plane at a fixed point (the chase camera stays put), looking along `dir`, banked `roll` rad (the camera stays level).
var roll := 0.0

func _hold(at: Vector3, dir: Vector3, secs: float, speed := 90.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		var me := _me()
		if me:
			me.position = at
			me.velocity = dir.normalized() * speed
			_aim(me, dir)
			me.basis = me.basis.rotated(dir.normalized(), roll)
		await process_frame


func _enemies() -> Array:
	var me := _me()
	return main.players.get_children().filter(func(p): return me and p != me and p.alive and p.team != me.team and p.role in ["pilot", "fighter", "wing"] and p.position.y > 90.0)


# Enemy with the most other planes around it (a busy frame), preferring ones flying level.
func _busy_target() -> Node:
	var best: Node = null
	var score := -1.0
	for e in _enemies():
		var n := 0.0
		for p in main.players.get_children():
			if p != e and p.alive and p.position.distance_to(e.position) < 450.0:
				n += 1.0
		n -= absf(_vel(e).normalized().y) * 2.0
		if n > score:
			score = n
			best = e
	return best


func _friend(name: String, addr: String) -> void:
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", ProjectSettings.globalize_path("res://aso/tools/lan_friend.gd"),
		"--", "--bot", "--quit-after-secs", "300", "--name", name, "--addr", addr]
	var pid := OS.create_process(OS.get_executable_path(), args)
	print("friend %s pid %d" % [name, pid])
	pids.append(pid)


func _wait_players(n: int, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while main.gs.players.size() < n and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame
	print("players in room: %d" % main.gs.players.size())


# Frames 1 + 3: (--only lan,fight or lan,taunt runs one half) Team Dogfight, you + 3 more game instances over LAN (localhost). Every pilot is a human slot.
func scene_lan() -> void:
	await _fresh()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1") # LAN host without the UPnP router call main.host() makes
	if peer.create_server(LAN_PORT) != OK:
		print("LAN: port busy")
		return
	get_multiplayer().multiplayer_peer = peer
	main.room = ""
	main.name_edit.text = "Arjun"
	main._start_hosting()
	main.request_plane(lan_plane)
	for f in FRIENDS:
		_friend(f, "127.0.0.1:%d" % LAN_PORT)
	await _wait_players(4, 60.0)
	main.request_world(lan_world) # 1 Volcanic Islands (01); --lan-world for 02's second dogfight
	await _wait(1.0)
	main.request_mode(1)
	await _wait(0.5)
	main.request_start()
	await _until_flying()
	print("LAN dogfight: %s" % ", ".join(main.gs.players.values().map(func(p): return "%s/%s" % [p.name, ["Blue", "Red"][p.team]])))
	await _wait(10.0)
	# [camera (0 near, 1 normal), distance ahead, side offset, height offset, camera drop, camera yaw] (m, rad):
	# target close and off to one side, so it shows side-on and big, above and beside your plane
	# (side > 0, yaw < 0 puts the target left of your plane)
	var setups: Array = CLOSE.map(func(c): return [0] + c)
	var take := 0
	var tries := 0
	while take < setups.size() and tries < 80 and not only.has("taunt"):
		tries += 1
		var t: Node = _busy_target()
		if not t or not _me() or not _me().alive or main.rockets.incoming(_me()):
			await _wait(1.0)
			continue
		var c: Array = setups[take]
		Settings.values.cam = c[0]
		await _pin_for(t, 1.0, c[1], c[3], c[2], c[4], c[5])
		_touch("fire", true, 1)
		for k in 4:
			await _pin_for(t, 0.3, c[1], c[3], c[2], c[4], c[5])
			_pin(t, c[1], c[3], c[2], c[4], c[5])
			if _me() and _me().alive and not main.rockets.incoming(_me()):
				await _shot("lan_dogfight_%d_%d" % [take, k], 1)
		_touch("fire", false, 1)
		take += 1
		await _wait(1.5)
	Settings.values.cam = 1
	# skywriting from mid-map (away from the airfield SAMs), heading for the volcano; the local taunt
	# is written ~230 m ahead, so fly into it until it fills the sky
	var dir := Vector3(-900, 0, 650).normalized()
	dir.y = 0.05
	dir = dir.normalized()
	for i in 9 if not only.has("fight") else 0:
		var at := Vector3(150, 300, 100)
		_touch("flare", true, 2) # shake off any rocket already chasing you, so no MISSILE warning in frame
		await _hold(at, dir, 0.3)
		_touch("flare", false, 2)
		await _hold(at, dir, 1.0)
		var me := _me()
		if not me:
			await _wait(4.0)
			continue
		main.taunt_cd = 0
		main.send_taunt([2, 14, 12][i % 3]) # Skill issue!, GG!, Let's go!
		var t0 := Time.get_ticks_msec()
		var k := 0
		while k < 3:
			var secs: float = (Time.get_ticks_msec() - t0) / 1000.0
			if is_instance_valid(me):
				me.position = at + dir * 100.0 * secs
				me.velocity = dir * 100.0
				_aim(me, dir + Vector3.UP * 0.2) # nose up a little: the letters sit mid-sky, below the headline band
			if secs > [1.35, 1.55, 1.75][k]:
				if not main.rockets.incoming(me): # no MISSILE! warning in frame
					await _shot("lan_taunt_%d_%d" % [i, k], 0)
				k += 1
			await process_frame
		await _wait(2.0)


# Frame 2: online room by code, 3 more game instances join with that code.
func scene_lobby() -> void:
	await _fresh()
	main.name_edit.text = "Arjun"
	main.host_online()
	print("room ", main.room)
	await _wait(3.0)
	for f in FRIENDS:
		_friend(f, main.room)
		await _wait(1.0)
	await _wait_players(4, 90.0)
	main.request_world(1)
	main.request_mode(1)
	await _wait(2.0)
	await _shot("lobby_room")


# Enemy with the most other planes inside a 35-degree cone ahead of where you'd sit `dist` behind it.
func _crowded_target(dist: float) -> Node:
	var best: Node = null
	var score := -1
	for e in _enemies():
		var from: Vector3 = e.position - _vel(e).normalized() * dist
		var ahead: Vector3 = (e.position - from).normalized()
		var n := 0
		for p in main.players.get_children():
			if p != e and p != _me() and p.alive and p.position.distance_to(from) < 450.0 and (p.position - from).normalized().dot(ahead) > 0.82:
				n += 1
		if n > score:
			score = n
			best = e
	return best


# Enemy with the fewest other planes near it, preferring level flight: one clear subject, no half-cut wingman.
func _lone_target() -> Node:
	var best: Node = null
	var score := INF
	for e in _enemies():
		var n := 0.0
		for p in main.players.get_children():
			if p != e and p != _me() and p.alive and p.position.distance_to(e.position) < 250.0:
				n += 1.0
		n += absf(_vel(e).normalized().y) * 2.0
		if n < score:
			score = n
			best = e
	return best


# Frame 4: Team Battle vs AI, 6v6, Desert Wasteland, Pilot difficulty. One red AI plane close ahead, staged like
# frame 01. AI radio is muted (radio_cd), so no skywritten radio line lands in frame (from behind it reads mirrored).
func scene_ai() -> void:
	await _fresh()
	await _fly(3, 3, 2, 1)
	main.radio_cd = 1e12
	await _wait(10.0)
	Settings.values.cam = 0
	var setups := CLOSE
	var n := 0
	for take in 20:
		if n >= 8:
			break
		var c: Array = setups[take % setups.size()]
		var t := _lone_target()
		if not t or not _me() or not _me().alive:
			await _wait(2.0)
			continue
		_touch("flare", true, 2)
		await _pin_for(t, 0.3, c[0], c[2], c[1], c[3], c[4])
		_touch("flare", false, 2)
		await _pin_for(t, 0.5, c[0], c[2], c[1], c[3], c[4])
		_touch("fire", true, 1)
		await _pin_for(t, 0.6, c[0], c[2], c[1], c[3], c[4])
		_pin(t, c[0], c[2], c[1], c[3], c[4])
		if not main.rockets.incoming(_me()) and not _me().locked_by(): # no MISSILE / LOCKED ON warning
			await _shot("ai_battle_%d" % take, 1)
			n += 1
		_touch("fire", false, 1)
		await _wait(0.5)
	Settings.values.cam = 1


# Frame 5: Neon Metropolis vs Ace AI, flying the Jet Fighter: lock on a side-on target 25-35 m ahead, then
# release (fires) and shoot the rocket in flight toward it. HUD at its real size (no zoom: Guideline 2.3).
func scene_rocket() -> void:
	await _fresh()
	Settings.values.cam = 0
	await _fly(4, 3, 1, 2, "fighter")
	main.radio_cd = 1e12 # no skywritten radio line behind the target
	show_hud = true
	await _wait(8.0)
	var take := 0
	var tries := 0
	var setups := [[30.0, 12.0, -5.0, 0.12, -0.45], [25.0, 10.0, -4.0, 0.12, -0.5], [35.0, 14.0, -6.0, 0.1, -0.4]]
	while take < 6 and tries < 40:
		tries += 1
		var t := _lone_target()
		var me := _me()
		if not t or not me or not me.alive or me.rockets_left < 1 or main.rockets.incoming(me):
			await _wait(2.0)
			continue
		var c: Array = setups[take % setups.size()]
		await _pin_for(t, 0.4, c[0], c[2], c[1], c[3], c[4])
		_touch("rocket", true, 3)
		await _pin_for(t, 0.9, c[0], c[2], c[1], c[3], c[4])
		print("rocket take %d: target %s at %d m, lock %s" % [take, t.pilot, me.position.distance_to(t.position), me.lock.pilot if me.lock else "-"])
		if me.lock:
			await _shot("rocket_lock_%d" % take, 1)
			_touch("rocket", false, 3)
			for k in 3:
				await _pin_for(t, [0.05, 0.1, 0.1][k], c[0], c[2], c[1], c[3], c[4])
				await _shot("rocket_fly_%d_%d" % [take, k], 0)
		_touch("rocket", false, 3)
		take += 1
		await _wait(3.0)
	Settings.values.cam = 1


# `shot`: index into the world's own camera list, or [from, to]. `cam` 0 near / 1 normal / 2 far; `bank` in rad.
func _vista(world: int, shot: Variant, name: String, storm: bool, hazard: String, cam_mode := 1, bank := 0.0, plane := "cub") -> void:
	await _fresh()
	await _fly(world, 2, 0, 1, plane) # Free Flight: the only plane in the sky, so hazards come to you
	Settings.values.cam = cam_mode
	roll = bank
	var s: Array = shot if shot is Array else Worlds.cur.shots[shot]
	var dir: Vector3 = s[1] - s[0]
	await _hold(s[0], dir, 0.5)
	if storm:
		main.env.t = Worlds.cur.env.storm.period - Worlds.cur.env.storm.length + 0.5 # fast-forward to the storm
		await _hold(s[0], dir, 0.5)
		main.env.storm = 1.0
	if hazard == "lava_bombs":
		for k in 3:
			main.env.hazard_t[hazard] = 0.0
			await _hold(s[0], dir, 0.6)
		for k in 4: # bombs rise and fall: several moments, pick the fullest sky
			await _hold(s[0], dir, 0.5)
			await _shot("%s_%d" % [name, k], 1)
	elif hazard == "lightning":
		# Keep only bolts that land in front of the camera, 80-400 m out and off to one side of your plane.
		var good := 0
		for tries in 24:
			if good >= 4:
				break
			var before: Array = main.env.get_children()
			main.env.hazard_t[hazard] = 0.0
			var t0 := Time.get_ticks_msec()
			var bolt: Node = null
			while Time.get_ticks_msec() - t0 < 2500 and not bolt:
				var me := _me()
				if me:
					me.hp = me.max_hp
					me.position = s[0]
					me.velocity = dir.normalized()
					_aim(me, dir)
					me.basis = me.basis.rotated(dir.normalized(), roll)
				for c in main.env.get_children():
					if not c in before and c.get_class() == "Node3D" and c.get_child_count() > 2:
						bolt = c
				await process_frame
			if bolt and is_instance_valid(bolt):
				var at: Vector3 = bolt.get_child(bolt.get_child_count() - 1).global_position # the flash light sits at the strike point
				var cam := root.get_camera_3d()
				var x := cam.unproject_position(at).x / root.get_visible_rect().size.x if not cam.is_position_behind(at) else -1.0
				var d := cam.global_position.distance_to(at)
				print("bolt %d: x %.2f, %d m" % [tries, x, d])
				if d > 80.0 and d < 400.0 and ((x > 0.12 and x < 0.4) or (x > 0.6 and x < 0.88)):
					await _shot("%s_%d" % [name, tries], 1)
					good += 1
			await _hold(s[0], dir, 1.0, 1.0)
	else:
		await _hold(s[0], dir, 4.0)
		await _shot(name, 1)
		await _hold(s[0], dir, 1.5)
		await _shot(name + "_b", 1)


# Frame 6 + alt 3: world vistas, a different camera, bank and distance per world so the panels don't repeat.
# Volcano: low pass along the cone toward the crater, banked. Frozen: near camera at the dark waterfall and
# canyon, where the flakes show. Metro: far camera, so the plane is small against the bolt.
func scene_weather() -> void:
	var crater := Vector3(-1000, 470, 950)
	await _vista(1, [Vector3(-420, 170, 430), crater], "world_volcano_low", true, "lava_bombs", 1, 0.45, "twin")
	await _vista(1, [Vector3(-330, 230, 1250), crater + Vector3(0, 60, 0)], "world_volcano_side", true, "lava_bombs", 1, -0.4, "twin")
	for i in [0, 3]:
		await _vista(2, i, "world_frozen_%d" % i, true, "", 0, -0.35, "racer")
	await _vista(4, 0, "world_metro", true, "lightning", 1, 0.3, "fighter") # normal camera: the plane reads next to the bolt
	roll = 0.0


# One plane type per world (each world flies its own themed version), so the strip panels differ.
func scene_worlds() -> void:
	await _vista(0, 1, "world_valley", false, "", 1, -0.5, "cub")
	await _vista(3, 0, "world_desert", false, "", 0, 0.4, "cub")
	await _vista(5, 0, "world_sky", false, "", 2, -0.25, "racer")
	roll = 0.0


# Spare: Capture the Flag moment (enemy flag marker ahead).
func scene_ctf() -> void:
	await _fresh()
	await _fly(0, 4, 1, 1)
	await _wait(8.0)
	var f: Dictionary = main.gs.flags[1]
	var me := _me()
	var from: Vector3 = f.pos + Vector3(0, 140, 0) + (Vector3(0, 0, 0) - f.pos).normalized() * 520.0
	await _hold(from, f.pos + Vector3.UP * 30.0 - from, 1.5)
	await _shot("ctf_flag", 1)


# Frame 7: Hangar Shop, Golden Ace Set (owned in the fake store; the compose crop leaves out the OWNED tag).
# The Golden Ace livery repaints wings, tail and trim gold; the fuselage keeps the team colour (planes.gd:41). So the
# turntable plane is banked toward the camera (wing tops show) and tried on each plane type, trail on and off.
func scene_shop() -> void:
	await _fresh()
	main.request_world(0) # Green Valley: gold reads against green
	await _wait(1.0)
	main.shop_ui.open("bundle.golden")
	await _wait(1.5)
	var cam: Camera3D = main.lobby_cam
	var n := 0
	# Round-2 sweep: twin / fighter / cub x bank 0.5, -0.5, 0.9 x yaw -0.25, 0.2; the cub at bank 0.5, yaw 0.2 showed
	# the most gold (wing tops). Now only that pose, dropped lower so the headline band stays clear of the plane.
	for kind in ["cub"]:
		main.plane_choice = kind
		main.preview_key = ""
		main._refresh_preview()
		for bank in [0.5]:
			for drop in [1.8, 2.6, 3.4]:
				var fwd := cam.global_basis.x.rotated(Vector3.UP, 0.2)
				var at: Vector3 = cam.global_position - cam.global_basis.z * 12.0 + cam.global_basis.x * 7.0 - cam.global_basis.y * drop
				for k in 30:
					main.preview.global_transform = Transform3D(Basis.looking_at(fwd).rotated(fwd, bank), at)
					for c in main.preview.find_children("*", "CPUParticles3D", true, false) + main.preview.find_children("*", "GPUParticles3D", true, false):
						c.visible = false
					await process_frame
				await _shot("shop_%s_low_%d" % [kind, n], 0)
				n += 1


# Frame 8: Base Assault vs AI in Green Valley. You buy a SAM site with the team's 2 starting supplies (the BUY menu's
# request_deploy, as a player would), then hold short of the red HQ while the raids and the SAM fight; then bomb runs.
func scene_assault() -> void:
	await _fresh()
	await _fly(0, 5, 1, 1, "twin")
	main.radio_cd = 1e12
	await _wait(4.0)
	var hq: Vector3 = main.objectives.hqs[1].position
	var blue: Vector3 = main.objectives.hqs[0].position
	var dir := Vector3(hq.x - blue.x, 0, hq.z - blue.z).normalized()
	var spot := hq - dir * 260.0
	await _hold(Vector3(spot.x, Terrain.floor_below(Vector3(spot.x, 2000, spot.z)) + 60.0, spot.z), dir, 0.5, 30.0)
	main.request_deploy("sam", main.gs.match_id)
	await _wait(3.0)
	var k := 0
	for side in [-60.0, 60.0, 0.0]:
		for h in [110.0, 70.0]:
			var at: Vector3 = hq - dir * 520.0 + dir.cross(Vector3.UP) * side + Vector3.UP * h
			await _hold(at, hq - at, 2.0)
			if not main.rockets.incoming(_me()) and not _me().locked_by():
				await _shot("assault_%d" % k, 1)
			k += 1
	# Bomb runs: dive at the HQ, release, follow the bombs down.
	for run in 4:
		var at: Vector3 = hq - dir * 180.0 + Vector3.UP * 120.0 + dir.cross(Vector3.UP) * [-25.0, 25.0, 0.0, -10.0][run]
		var aim: Vector3 = (hq - at).normalized() + Vector3.UP * 0.35
		await _hold(at, aim, 0.6)
		_touch("bomb", true, 3)
		await _hold(at, aim, 0.15)
		_touch("bomb", false, 3)
		for j in 3:
			await _hold(at, aim, [0.35, 0.4, 0.5][j])
			await _shot("bomb_%d_%d" % [run, j], 0)
		await _wait(2.0)


# Frame 8 try: Base Assault, chase camera near and low, flying past the red HQ side-on so the base fills the frame.
func scene_hqside() -> void:
	await _fresh()
	await _fly(0, 5, 1, 1, "twin")
	main.radio_cd = 1e12
	await _wait(6.0)
	Settings.values.cam = 0
	var hq: Vector3 = main.objectives.hqs[1].position
	var k := 0
	for ang: float in [0.0, 1.2, 2.4, 3.6, 4.8]:
		for d: Array in [[170.0, 35.0, 0.3], [120.0, 26.0, 0.4]]:
			var off: Vector3 = Vector3(cos(ang), 0, sin(ang)) * float(d[0])
			var at: Vector3 = hq + off
			at.y = maxf(Terrain.floor_below(Vector3(at.x, 2000, at.z)), hq.y) + d[1]
			var side := Vector3(-off.z, 0, off.x).normalized() # fly tangent, HQ beside and ahead
			var dir: Vector3 = ((hq - at).normalized() + side * float(d[2])).normalized() # HQ ahead, off to the left
			await _hold(at, dir, 1.0, 40.0)
			if _me() and not main.rockets.incoming(_me()):
				await _shot("hqside_%d" % k, 1)
			k += 1
	Settings.values.cam = 1


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	only = a[a.find("--only") + 1].split(",") if a.has("--only") else PackedStringArray(["lan", "lobby", "ai", "rocket", "weather", "worlds", "ctf", "shop"])
	if a.has("--lan-world"):
		lan_world = int(a[a.find("--lan-world") + 1])
	if a.has("--lan-plane"):
		lan_plane = a[a.find("--lan-plane") + 1]
	process_frame.connect(_clean)
	var cfg_path := ProjectSettings.globalize_path(Settings.PATH)
	var saved_cfg := FileAccess.get_file_as_bytes(cfg_path) if FileAccess.file_exists(cfg_path) else PackedByteArray()
	var store_path := ProjectSettings.globalize_path("user://fake_store.cfg")
	var saved_store := FileAccess.get_file_as_bytes(store_path) if FileAccess.file_exists(store_path) else PackedByteArray()
	var store := ConfigFile.new()
	store.set_value("store", "owned", {"bundle.golden": true})
	store.save(store_path)
	for s in only:
		print("=== ", s)
		match s:
			"lan": await scene_lan()
			"lobby": await scene_lobby()
			"ai": await scene_ai()
			"rocket": await scene_rocket()
			"weather": await scene_weather()
			"worlds": await scene_worlds()
			"ctf": await scene_ctf()
			"shop": await scene_shop()
			"assault": await scene_assault()
			"hqside": await scene_hqside()
	for pid in pids:
		OS.kill(pid)
	if saved_cfg.is_empty():
		DirAccess.remove_absolute(cfg_path)
	else:
		FileAccess.open(cfg_path, FileAccess.WRITE).store_buffer(saved_cfg)
	if saved_store.is_empty():
		DirAccess.remove_absolute(store_path)
	else:
		FileAccess.open(store_path, FileAccess.WRITE).store_buffer(saved_store)
	quit()
