extends Node3D

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
static var PORT := DEFAULT_PORT # --port N overrides (tests run beside a real game); static: survives the reload before a rejoin
const WORLD_SIZE := 2000.0
const Aircraft := preload("res://plane.gd")
const Bullets := preload("res://bullets.gd")
const Rockets := preload("res://rockets.gd")
const MODES := ["Co-op Escort", "Team Dogfight", "Free Flight", "Team Battle vs AI", "Capture the Flag", "Base Assault"]
const TEAM_MODES := [1, 3, 4, 5]
const AI_MODES := [3, 4, 5]
const JOBS := ["attack", "defend", "escort", "hunt"]
const SIZES := [2, 4, 6]
const SKILL_NAMES := ["cadet", "rookie", "pilot", "ace"]
const SKILLS := [{title = "VERY EASY", sub = "Relaxed: they barely fight back"}, {title = "ROOKIE", sub = "Easy kills: slow, clumsy, fragile"},
	{title = "PILOT", sub = "A fair fight"}, {title = "ACE", sub = "Sharp, fast and merciless"}]
# ponytail: substring blocklist on pilot names (the only typed text others see); a real moderation service if public matchmaking ever exists.
const BLOCKED_NAMES := ["fuck", "fuk", "shit", "bitch", "cunt", "dick", "cock", "pussy", "whore", "slut", "nigg", "fag", "rape",
	"porn", "penis", "vagina", "bastard", "asshole", "nazi", "hitler", "chut", "madarchod", "behenchod", "bhenchod", "bsdk", "bhosd",
	"gaand", "gandu", "lund", "randi", "harami", "kutt", "kamina", "retard", "kike", "chink", "spic", "tranny", "kkk", "pedo", "phuck",
	"fvck", "fck", "molest", "boob", "tits", "sex", "cum"]
const ALLOWED_NAMES := ["cockpit", "peacock", "hancock", "hitchcock", "dickens", "scunthorpe", "grape", "therapist", "shitake",
	"torpedo", "spice", "essex", "sussex", "cumulus", "cucumber"] # cut out before the blocklist check
const CALLSIGNS := ["Biscuit", "Comet", "Pebble", "Rusty", "Noodle", "Zippy", "Sprocket", "Maple", "Doodle", "Ziggy", "Pipkin", "Bolt"] # original names (no film characters)
const TEAM_NAMES := ["Blue", "Red"]
const DAMAGE := [8, 45, 150] # guns, rocket, bomb
const BEACON_TIME := 15.0
const BEACON_RADIUS := 25.0
const RESPAWN_DELAY := 3.0
const COUNTDOWN := 3.0 # 3-2-1-GO at match start, decided by the server
const LOAD_WAIT := 15.0 # longest the countdown holds for a peer still building the world
const ESCORT_LIVES := 6
const WAVES := 8
const WAVE_INTERVAL := 30.0
const FIGHTER_CAP := 12
const BOMBER_SPEED := 25.0
const ROUTE := Terrain.ROUTE
const MATCH_TIME := 480.0
const CLUTCH_TIME := 45.0

var players := Node3D.new()
var spawner := MultiplayerSpawner.new()
var bullets := Bullets.new()
var rockets := Rockets.new()
var obstacles: Array[AABB] = []
var lobby_cam := Camera3D.new()

# Server-owned match state, mirrored to every peer by _push().
var gs := {
	phase = "menu", mode = 0, leader = 1, players = {}, lives = [0, 0], clutch = [-1.0, -1.0],
	time = 0.0, wave = 0, next_wave = 0.0, arrived = 0, lost = 0, sudden = false,
	beacons = [], feed = [], msg = "", match_id = 0, room = "", public_ip = "", popped = 0, size = 1, skill = 0, team_kills = [0, 0], ai_board = {}, world = 0, storm = 0.0,
}
var beacons := {} # server only: victim id -> {pos, t, team}
var respawning := {} # server only: victim id -> team, waiting out RESPAWN_DELAY
var pings: Array = [] # local: [pos, text, time_left]
var push_cd := 0.0
var gs_sent := {} # server: gs as last pushed, so a push only carries the keys that changed
var synced := false # client: got a full gs, deltas apply from here on
var ai_count := 0
var bot := "--bot" in OS.get_cmdline_user_args()

var menu_root: Control
var lobby_root: Control
var pause_root: Control
var name_edit := LineEdit.new()
var address := LineEdit.new()
var status := Label.new()
var lobby_list := Label.new()
var mode_sel: Menus.Selector
var world_sel: Menus.Selector
var size_sel: Menus.Selector
var skill_sel: Menus.Selector
var plane_sel: Menus.Selector
var sticker_sel: Menus.Selector
var banner_sel: Menus.Selector
var prize: Node # the current prize balloon (server)
var prize_t := 35.0
var battle_row: BoxContainer = HBoxContainer.new() if TouchControls.phone() else VBoxContainer.new() # phones: size and skill side by side
var mp_root: Control # Multiplayer screen (host / join), part of the main menu
var mp_open := false
var mission_root: Control # phone: solo mission setup over the home screen
var mission_open := false
var play_sub := Label.new()
var home_pic := TextureRect.new()
var home_world := Label.new()
var home_mode := Label.new()
var objective := Label.new()
var world_cards: Array = []
var mode_chips := {} # mode -> Button
var size_segs: Array = []
var skill_segs: Array = []
var battle_segs: Control # size + skill: vs-AI modes only
var plane_choice := "cub"
var start_btn: Button
var copy_btn: Button
var room_label := Label.new()
var net_label := Label.new()
var leave_btn: Button
var kick_box: Container = HFlowContainer.new() if TouchControls.phone() else VBoxContainer.new() # host: a KICK per joined pilot
var switch_btn: Button
var overlay := Control.new()
var minimap := Control.new() # its own canvas item: redrawn less often than the overlay
var top := Label.new()
var feed := Label.new()
var settings_root: Control
var howto_root: Control
var credits_root: Control
var results_root: Control
var results_title := Label.new()
var results_grid := GridContainer.new()
var end_btn: Button
var stats_label := Label.new()
var stat_bars: Array = []
var ui_theme := Menus.theme()
var preview := Node3D.new()
var preview_key := ""


# Launch: a loading screen draws at once, then the heavy steps run one per frame so its bar moves.
var boot: CanvasLayer


func _boot(frac: float, text: String) -> void:
	if not boot:
		boot = CanvasLayer.new()
		boot.layer = 100
		var bg := ColorRect.new()
		bg.color = Color(0.07, 0.11, 0.2)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		boot.add_child(bg)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_CENTER)
		col.grow_horizontal = Control.GROW_DIRECTION_BOTH
		col.grow_vertical = Control.GROW_DIRECTION_BOTH
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 14)
		bg.add_child(col)
		Menus.big_title(col, "TOY PLANE ARCADE", 40).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bar := ProgressBar.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(420, 18)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Menus.AMBER
		fill.set_corner_radius_all(9)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.15)
		back.set_corner_radius_all(9)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		col.add_child(bar)
		var l := Label.new()
		l.name = "Step"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = Color(1, 1, 1, 0.7)
		col.add_child(l)
		add_child(boot)
	boot.find_child("Bar", true, false).value = frac * 100.0
	boot.find_child("Step", true, false).text = text
	await get_tree().process_frame # let it draw before the next blocking step


# Draw every effect once behind the loading screen (muted) so a phone compiles their shaders now,
# not mid-fight: the first confetti, kill effect or shield used to hitch.
func _warm_effects() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	AudioServer.set_bus_mute(0, true)
	var before := get_children()
	var at := cam.global_position - cam.global_basis.z * 40.0
	Fx.pop(self, at, true)
	Fx.pop(self, at, false)
	Fx.flak(self, at)
	for k in [1, 2, 3]:
		Fx.kill_effect(self, at, k)
	Fx.crash(self, at, Vector3.ZERO)
	var temp: Array[Node3D] = [Fx.fire(), Fx.smoke()]
	var shield := MeshInstance3D.new() # same material as plane.gd's prize shield
	shield.mesh = SphereMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.4, 0.85, 1.0, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield.material_override = m
	temp.append(shield)
	var b := Bullets.new() # tracers (instanced: their own shader variant)
	temp.append(b)
	var sky := Taunts.SkyText.new() # skywritten taunts and AI radio lines
	sky.material_override = Taunts.SkyText.cloud(Color.WHITE)
	temp.append(sky)
	temp.append(rockets._missile())
	for n in temp:
		add_child(n)
		n.global_position = at
	b.set_process(false)
	b.multimesh.visible_instance_count = 1
	b.multimesh.set_instance_transform(0, Transform3D(Basis(), at))
	sky.write("GG", at, cam.global_basis.x, sky.material_override)
	for i in 3:
		await get_tree().process_frame
	for n in get_children():
		if not n in before: # the warm-up's own bits, so none drift past the menu
			n.queue_free()
	AudioServer.set_bus_mute(0, false)


func _ready() -> void:
	for f in [set_process, set_physics_process, set_process_input, set_process_unhandled_input]:
		f.call(false) # nothing ticks until the world and UI exist
	await _boot(0.05, "Starting...")
	Settings.load_saved()
	plane_choice = Settings.values.last_plane if Settings.values.last_plane in Planes.ORDER else "cub"
	shop.name = "Shop"
	add_child(shop)
	if TouchControls.on():
		get_tree().root.content_scale_size = Vector2i(1100, 620) # phone: everything bigger, readable at arm's length
		if not OS.has_feature("mobile"):
			Input.emulate_touch_from_mouse = true # --touch on a desktop: the mouse is a finger
	await _boot(0.2, "Building the world...")
	_build_world()
	await _boot(0.6, "Warming up effects...")
	await _warm_effects()
	await _boot(0.8, "Getting the hangar ready...")
	_build_ui()
	Settings.apply(get_tree())
	if Engine.has_meta("leave_msg"):
		status.text = Engine.get_meta("leave_msg")
		Engine.remove_meta("leave_msg")
		print("MENU: ", status.text)
	Menus.bind_wasd()
	if Engine.has_meta("shop_try"): # back from a free test flight: the shop opens on what you tried
		var tried: String = Engine.get_meta("shop_try")
		Engine.remove_meta("shop_try")
		shop_ui.open.call_deferred(tried, "How did it fly? Buy it to keep it, or carry on with the free looks.")
	get_tree().set_auto_accept_quit(false) # closing the window says goodbye to clients first
	if Engine.has_meta("rejoin"):
		call_deferred("_try_rejoin")
	players.name = "Players"
	add_child(players)
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_function = _spawn_plane
	add_child(spawner)
	add_child(bullets)
	rockets.name = "Rockets"
	add_child(rockets)

	var args := OS.get_cmdline_user_args() if not Engine.has_meta("args_done") else PackedStringArray()
	Engine.set_meta("args_done", true) # scene reloads (Leave) must not re-run launch flags
	var pi := args.find("--port")
	if pi >= 0 and pi + 1 < args.size():
		PORT = int(args[pi + 1])
	var si := args.find("--speed")
	if si >= 0 and si + 1 < args.size():
		Engine.time_scale = float(args[si + 1]) # test only: fast-forward matches
	if "--shot" in args: # test hook: render stats + screenshot, then quit (tools/perf_shot.gd)
		add_child(load("res://tools/perf_shot.gd").new())
	var qa := args.find("--quit-after-secs")
	if qa >= 0:
		get_tree().create_timer(float(args[qa + 1])).timeout.connect(func():
			print("AIM shots=%d hits=%d (%.1f%%)" % [stat_shots, stat_hits, 100.0 * stat_hits / maxf(stat_shots, 1)])
			print("TALLY ", tallies)
			print("STATS nodes=%d orphans=%d mem=%.1fMB" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6])
			_quit())
		# Test hook backstop: bound to the SceneTree, so it still fires after a reconnect reloaded the scene.
		get_tree().create_timer(float(args[qa + 1]) + 10.0).timeout.connect(get_tree().quit)
	if "--netstats" in args:
		netstats = {frames = 0, extrap = 0, stall = 0, jumps = 0, snaps = 0, gap_max = 0, gaps150 = 0, sync_bytes = 0, syncs = 0, dev_max = 0.0, rdev_max = 0.0, rdev_sum = 0.0, stale = 0, corr_n = 0, corr_sum = 0.0}
		var nt := Timer.new()
		nt.wait_time = 10.0
		nt.autostart = true
		nt.timeout.connect(_print_netstats)
		add_child(nt)
	if "--free" in args:
		free_flight()
	if "--evil" in args: # test hook: abusive client, see tools/evil.gd
		add_child(load("res://tools/evil.gd").new())
	if "--test-deploy" in args: # test hook: a joined client calls in a SAM site
		get_tree().create_timer(25.0).timeout.connect(func(): request_deploy.rpc_id(1, "sam", gs.match_id))
	if "--solo" in args:
		solo_battle()
		if args.find("--mode") >= 0:
			request_mode(clampi(int(args[args.find("--mode") + 1]), 0, MODES.size() - 1))
		if args.find("--world") >= 0:
			request_world(int(args[args.find("--world") + 1]))
		if "--start" in args:
			get_tree().create_timer(1.0).timeout.connect(_start)
	var ea := args.find("--end-after")
	if ea >= 0:
		get_tree().create_timer(float(args[ea + 1])).timeout.connect(func(): _end("Practice over"))
	var ji := args.find("--join-room")
	if "--server" in args or "--host-online" in args:
		if "--host-online" in args:
			host_online()
		else:
			host()
		var szi := args.find("--size")
		if szi >= 0:
			gs.size = int(args[szi + 1])
		var ski := args.find("--skill")
		if ski >= 0:
			gs.skill = int(args[ski + 1])
		if "--debug-ai" in args:
			var t := Timer.new()
			t.wait_time = 5.0
			t.autostart = true
			t.timeout.connect(func():
				var rows := []
				for p in players.get_children():
					rows.append("%s:%s%s/%d" % [p.pilot.left(4), ["P", "U", "A", "E", "R"][p.ai.get("state", 0)] if p.ai else "-", "" if p.alive else "x", p.position.y])
				print("DBG phase=%s t=%d lives=%s  %s" % [gs.phase, gs.time, gs.lives, " ".join(rows)]))
			add_child(t)
		var wi := args.find("--world")
		if wi >= 0:
			gs.world = int(args[wi + 1])
			_build_world_content(gs.world)
		var mi := args.find("--mode")
		if mi >= 0 and mi + 1 < args.size():
			gs.mode = clampi(int(args[mi + 1]), 0, MODES.size() - 1)
		if "--start" in args and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			get_tree().create_timer(1.0).timeout.connect(_start)
	elif ji >= 0:
		address.text = args[ji + 1]
		join()
	elif "--join" in args:
		join()
	boot.queue_free()
	boot = null
	for f in [set_process, set_physics_process, set_process_input, set_process_unhandled_input]:
		f.call(true)


# ---------- connection ----------
# LAN / IP: plain ENet on PORT. Online: rooms.gd (WebRTC P2P + room code over public MQTT).
const VERSION := "1.0"

var room := "" # online room code we host or joined
var rooms: Rooms
var joining := false
var quitting := false # _leave under way
var spectating := "--spectate" in OS.get_cmdline_user_args() # watch AI-only battles
var spec_target: Node
var spec_t := 0.0
var upnp_task := -1


func host(port := -1) -> bool:
	if port < 0:
		port = PORT
	_drop_join()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		status.text = "Could not host on port %d (already running?)" % port
		return false
	multiplayer.multiplayer_peer = peer
	room = ""
	_start_hosting()
	if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"): # phones sit behind carrier NAT / Wi-Fi: no router to ask
		upnp_task = WorkerThreadPool.add_task(_open_router_port.bind(port))
	return true


func _start_hosting() -> void:
	if not multiplayer.peer_disconnected.is_connected(_on_peer_left):
		multiplayer.peer_disconnected.connect(_on_peer_left)
	gs.phase = "lobby"
	gs.room = room
	if DisplayServer.get_name() == "headless" and not "--local-player" in OS.get_cmdline_user_args() or spectating: # tests can keep a pilot headless
		gs.leader = 0 # first player to join leads
	else:
		_add_player(1, name_edit.text)
		var look := my_look()
		gs.players[1].sticker = look[0]
		gs.players[1].banner = look[1]
		gs.players[1].livery = look[2]
		gs.players[1].killfx = look[3]
		gs.players[1].plane = plane_choice
	_push()
	print("Hosting")
	net_who = "host"
	netlog("hosting %s v%s" % ["room " + room if room else "port %d" % PORT, VERSION])


# Solo battle vs AI: offline lobby where you pick size and difficulty, then fight.
func solo_battle() -> void:
	room = ""
	_drop_join()
	_start_hosting()
	var v := Settings.values # the last mission this player set up
	gs.world = clampi(v.last_world, 0, Worlds.LIST.size() - 1)
	gs.size = clampi(v.last_size, 0, SIZES.size() - 1)
	gs.skill = clampi(v.last_skill, 0, SKILL_NAMES.size() - 1)
	request_mode(v.last_mode if v.last_mode in [0, 3, 4, 5] else 3)


# Solo practice runs offline: no port, no firewall prompt, same game code (offline peer = server).
func free_flight() -> void:
	room = ""
	_drop_join()
	_start_hosting()
	gs.mode = 2
	_start()


# Plan B with zero servers: ask the router (UPnP) to forward our port, then friends type our public IP.
# Fails on routers with UPnP off or carrier-grade NAT; online rooms cover those.
func _open_router_port(port: int) -> void:
	var upnp := UPNP.new()
	if upnp.discover(1200) != UPNP.UPNP_RESULT_SUCCESS or not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		return
	if upnp.add_port_mapping(port, port, "Toy Plane Arcade", "UDP", 4 * 3600) == UPNP.UPNP_RESULT_SUCCESS:
		_set_public_ip.call_deferred(upnp.query_external_address())


func _set_public_ip(ip: String) -> void:
	gs.public_ip = ip
	_push()


func _exit_tree() -> void:
	if upnp_task >= 0:
		WorkerThreadPool.wait_for_task_completion(upnp_task)


func host_online() -> void:
	_drop_join()
	_new_rooms()
	multiplayer.multiplayer_peer = rooms.host()
	room = rooms.code
	print("ROOM ", room)
	var rf := OS.get_cmdline_user_args().find("--room-file")
	if rf >= 0:
		FileAccess.open(OS.get_cmdline_user_args()[rf + 1], FileAccess.WRITE).store_string(room)
	_start_hosting()


func _new_rooms() -> void:
	if rooms:
		rooms.queue_free()
	rooms = Rooms.new()
	rooms.status.connect(func(t):
		t = _net_tip(t)
		status.text = t
		net_label.text = t if gs.phase == "lobby" else ""
		print("rooms: ", t))
	rooms.failed.connect(_room_failed)
	add_child(rooms)


func join() -> void:
	if joining:
		return
	var target := address.text.strip_edges()
	last_target = target
	room = ""
	var host_port := target.rsplit(":", true, 1)
	if target == "" or target == "localhost" or target.is_valid_ip_address() or (host_port.size() == 2 and host_port[0].is_valid_ip_address() and host_port[1].is_valid_int()):
		var ip := "127.0.0.1" if target in ["", "localhost"] else (host_port[0] if host_port.size() == 2 and not target.is_valid_ip_address() else target)
		var port := int(host_port[1]) if host_port.size() == 2 and not target.is_valid_ip_address() else PORT
		_connect_client(ip, port, 0)
		return
	target = target.to_upper().replace(" ", "")
	if target.length() != 5 or not Array(target.split("")).all(func(ch): return Rooms.CODE_CHARS.contains(ch)):
		status.text = "Room codes are 5 letters/numbers (like KNHXC). For LAN, type the host's IP address."
		print("MENU: ", status.text)
		return
	room = target
	joining = true
	_new_rooms()
	multiplayer.multiplayer_peer = rooms.join(room)
	_watch_connection()
	var attempt := rooms.get_instance_id() # a rejoin into the same room must not be cut short by this timer
	get_tree().create_timer(40.0).timeout.connect(func():
		if gs.phase == "menu" and rooms and rooms.get_instance_id() == attempt:
			_room_failed(("Could not connect to room %s. Check the code. " + PHONE_NET_TIP if TouchControls.on() else
				"Could not connect to room %s. Check the code, make sure everyone clicked Allow on the firewall prompt, or see How to play > Internet tips.") % room))


func _room_failed(msg: String) -> void:
	if not joining:
		return
	joining = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if Engine.has_meta("rejoin"):
		get_tree().create_timer(3.0).timeout.connect(_try_rejoin)
		return
	status.text = _net_tip(msg)
	print("MENU: ", status.text)


const PHONE_NET_TIP := "Make sure both devices are online. For LAN, allow Local Network in Settings > Privacy & Security > Local Network."

# Phones have no firewall prompt, TURN settings or How to play > Internet tips: give phone advice instead.
func _net_tip(text: String) -> String:
	return text.replace(Rooms.NAT_TIP, "Try another network, or the same Wi-Fi. " + PHONE_NET_TIP) if TouchControls.on() else text


# Stop a join / reconnect in flight (BACK, or a solo game or host started meanwhile).
func _drop_join() -> void:
	Engine.remove_meta("rejoin")
	joining = false
	if rooms:
		rooms.queue_free()
		rooms = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# Multiplayer screen BACK also calls off a join still trying, so JOIN works again right away.
func _close_mp() -> void:
	if joining or Engine.has_meta("rejoin"):
		_drop_join()
		status.text = "Join cancelled."
	mp_open = false
	_refresh_ui()


func _open_mp() -> void:
	mp_open = true
	_refresh_ui()


# PLAY / QUICK BATTLE / LAUNCH: straight into the last mission set up (solo_battle applies it).
func quick_battle() -> void:
	mission_open = false
	solo_battle()
	_start()


func _open_mission() -> void:
	mission_open = true
	_refresh_ui()


func _close_mission() -> void:
	mission_open = false
	_refresh_ui()


# Mission Select picks are remembered at once; the world builds at launch (Worlds.shown only restyles).
func _pick_mission(key: String, i: int) -> void:
	gs[key] = i
	Settings.values["last_" + key] = i
	Settings.save()
	Worlds.shown = clampi(Settings.values.last_world, 0, Worlds.LIST.size() - 1)
	_refresh_mission()


func _connect_client(addr: String, port: int, local_port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(addr, port, 0, 0, 0, local_port) != OK:
		status.text = "Bad address"
		return
	multiplayer.multiplayer_peer = peer
	joining = true
	_watch_connection()
	status.text = "Connecting..."


func _watch_connection() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connect_failed)
		multiplayer.server_disconnected.connect(_lost_host)


func _on_connect_failed() -> void:
	joining = false
	netlog("connect failed: " + last_target)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if Engine.has_meta("rejoin"):
		get_tree().create_timer(3.0).timeout.connect(_try_rejoin)
		return
	status.text = "Could not connect. Is the host's game open in the lobby? " + PHONE_NET_TIP if TouchControls.on() else "Could not connect. Is the host's game open in the lobby, and did they allow it through the firewall?"


# ENet's throttle throws away unreliable packets whenever ping wobbles (half our snapshots at 40 ms).
# Snapshots are tiny and we never saturate a link, so let them all through.
func _no_throttle(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet and enet.get_peer(id):
		enet.get_peer(id).throttle_configure(5000, 2, 0)


func _on_connected() -> void:
	joining = false
	_no_throttle(1)
	if Engine.has_meta("rejoin"):
		Engine.remove_meta("rejoin")
	print("Connected as %d" % multiplayer.get_unique_id())
	net_who = "c%d" % multiplayer.get_unique_id()
	netlog("connected to %s v%s" % [last_target if last_target else "localhost:%d" % PORT, VERSION])
	var fv := OS.get_cmdline_user_args().find("--fake-version") # test hook
	register.rpc_id(1, {name = name_edit.text, token = _player_token(), version = OS.get_cmdline_user_args()[fv + 1] if fv >= 0 else VERSION, plane = Planes.ORDER.pick_random() if bot else plane_choice,
		sticker = randi() % Planes.STICKERS.size() if bot else Settings.values.get("sticker", 0), banner = randi() % Planes.BANNERS.size() if bot else my_look()[1],
		livery = 0 if bot else my_look()[2], killfx = 0 if bot else my_look()[3]})


@rpc("authority", "reliable")
func kicked(reason: String) -> void:
	netlog("kicked: " + reason)
	_leave(reason)


# Host's lobby KICK: same path as a rejected join.
func _kick(id: int) -> void:
	if not multiplayer.is_server() or not id in multiplayer.get_peers():
		return
	netlog("host kicked %d %s" % [id, gs.players.get(id, {}).get("name", "?")])
	kicked.rpc_id(id, "The host removed you from the room.")
	get_tree().create_timer(5.0).timeout.connect(func():
		if id in multiplayer.get_peers():
			multiplayer.multiplayer_peer.disconnect_peer(id))


# Back to the main menu; `msg` survives the scene reload and shows on the menu.
func _leave(msg := "") -> void:
	quitting = true
	if msg:
		Engine.set_meta("leave_msg", msg)
	await _goodbye()
	if not is_inside_tree():
		return # a second _leave (kicked, then disconnected) already reloaded the scene
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_peer_left(id: int) -> void:
	if rooms:
		rooms.forget(id)
	var token: String = tokens.get(id, "")
	tokens.erase(id)
	loaded.erase(id)
	load_wait.erase(id)
	netlog("left %d %s phase=%s" % [id, gs.players.get(id, {}).get("name", "?"), gs.phase])
	var p := _plane(id)
	if token and gs.players.has(id) and gs.phase in ["playing", "ended"]:
		# Kept as they left: a pilot who was down comes back down (no free respawn by reconnecting).
		away[token] = {info = gs.players[id].duplicate(), until = Time.get_ticks_msec() + 60000, match = gs.match_id,
			down = p != null and not p.alive, respawn = respawning.has(str(id)), beacon = beacons.get(id, {})}
		_feed("%s lost connection (60 s to rejoin)" % gs.players[id].name)
	elif gs.players.has(id) and gs.phase != "lobby":
		_feed("%s left the game" % gs.players[id].name)
	gs.players.erase(id)
	beacons.erase(id)
	if p:
		p.queue_free()
	respawning.erase(str(id))
	if gs.leader == id:
		gs.leader = 1 if gs.players.has(1) else (gs.players.keys()[0] if gs.players else 0)
	_back_to_lobby_if_empty()
	_push()


# Nobody left (and nobody about to rejoin): stop the match.
func _back_to_lobby_if_empty() -> void:
	if gs.players.is_empty() and away.is_empty() and gs.phase != "lobby":
		for c in players.get_children():
			c.queue_free()
		gs.phase = "lobby"


# Client: leaving on purpose (Leave / Quit), so the host doesn't hold a rejoin slot or say "lost connection".
@rpc("any_peer", "reliable")
func leaving() -> void:
	if not multiplayer.is_server() or not _allow(_sender(), "leaving", 0.5, 2.0): # each one writes the netlog
		return
	tokens.erase(_sender())
	netlog("leaving %d (on purpose)" % _sender())


@rpc("any_peer", "reliable")
func register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return # relayed from another client: only the host handles requests
	var id := multiplayer.get_remote_sender_id()
	if gs.players.has(id):
		return # repeated / replayed registration
	_no_throttle(id)
	var pilot := str(info.get("name", ""))
	var version := str(info.get("version", "?"))
	var plane := str(info.get("plane", "cub"))
	var token := str(info.get("token", "")).left(40)
	var ghost = tokens.find_key(token) if token else null
	if ghost != null and ghost != id:
		# Same pilot on a new connection (network switch, or back before we noticed the old one drop):
		# retire the old peer now so it frees its slot and its state goes to `away` for this one.
		netlog("retiring %d: same pilot reconnected as %d" % [ghost, id])
		_on_peer_left(ghost)
		multiplayer.disconnect_peer(ghost) # SceneMultiplayer's: also stops sending to it right away
	var reject := ""
	if version != VERSION:
		reject = "Version mismatch: the host has v%s, you have v%s. Everyone needs the same download." % [VERSION, version]
	elif gs.players.size() >= MAX_PLAYERS:
		reject = "That room is full (%d pilots)." % MAX_PLAYERS
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var addr := enet.get_peer(id).get_remote_address() if enet and enet.get_peer(id) else "-"
	if reject:
		netlog("rejected %d %s v%s from %s: %s" % [id, pilot, version, addr, reject])
		kicked.rpc_id(id, reject)
		# The client leaves on its own; this is the backstop. Short delays cut the reason off on lossy links.
		get_tree().create_timer(5.0).timeout.connect(func():
			if id in multiplayer.get_peers():
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	_add_player(id, pilot)
	if Planes.TYPES.has(plane):
		gs.players[id].plane = plane
	gs.players[id].sticker = clampi(int(info.get("sticker", 0)), 0, Planes.STICKERS.size() - 1)
	gs.players[id].banner = clampi(int(info.get("banner", 0)), 0, Planes.trail_names().size() - 1)
	gs.players[id].livery = clampi(int(info.get("livery", 0)), 0, Planes.LIVERIES.size() - 1)
	gs.players[id].killfx = clampi(int(info.get("killfx", 0)), 0, Planes.KILL_FX.size() - 1)
	var back: Dictionary = {}
	if token and not token in tokens.values():
		tokens[id] = token
		back = away.get(token, {})
		away.erase(token)
		if back and back.match == gs.match_id and Time.get_ticks_msec() < back.until:
			gs.players[id] = back.info # same team, score and plane as before the drop
			_feed("%s reconnected" % back.info.name)
			netlog("rejoined %d %s" % [id, back.info.name])
		else:
			back = {}
	if gs.leader == 0:
		gs.leader = id
	netlog("joined %d %s v%s from %s phase=%s" % [id, gs.players[id].name, version, addr, gs.phase])
	if gs.phase == "playing":
		_spawn_pilot(id, _base(id))
		if back.get("down", false):
			_down_again(id, back)
		sync.rpc_id(id, gs, true) # world + match reset land first, or they would wipe the replays below
		for c in players.get_children():
			if c.name != str(id):
				c.set_hp.rpc_id(id, c.hp, c.comps)
				if not c.alive:
					c.die.rpc_id(id, false)
		if battlefield: # replay deployed defenses in order so turret indices match, then what's destroyed
			for g in battlefield.guns.slice(battlefield.base_count):
				bf_event.rpc_id(id, "deploy", g.team * 10 + Battlefield.KINDS.find(g.kind), g.position, g.position + Vector3.UP * 5.0)
			for g in battlefield.guns:
				if g.hp < g.max_hp:
					g.set_hp.rpc_id(id, g.hp, g.comps)
				if not g.alive and g.visible:
					g.die.rpc_id(id, false)
			for k in battlefield.crates:
				bf_event.rpc_id(id, "drop", k, battlefield.crates[k].pos, Vector3.ZERO)
		if objectives:
			for h in objectives.hqs:
				h.set_hp.rpc_id(id, h.hp, h.comps)
	_push(true)


# A pilot who dropped while shot down: down again once their new plane exists on every peer,
# then back on the respawn timer / revive beacon they had.
func _down_again(id: int, back: Dictionary) -> void:
	var pid := _plane(id).get_instance_id()
	var mid: int = gs.match_id
	get_tree().create_timer(0.5).timeout.connect(func():
		var v = instance_from_id(pid)
		if not is_instance_valid(v) or gs.match_id != mid or gs.phase != "playing":
			return
		v.die.rpc(false)
		if back.respawn:
			_respawn_later(v, RESPAWN_DELAY)
		if back.beacon:
			beacons[id] = back.beacon
		_push())


static func clean_name(pilot: String) -> bool:
	var s := pilot.to_lower()
	for pair in [["0", "o"], ["1", "i"], ["3", "e"], ["4", "a"], ["5", "s"], ["@", "a"], ["$", "s"], ["!", "i"]]:
		s = s.replace(pair[0], pair[1])
	var letters := ""
	for c in s:
		if c >= "a" and c <= "z":
			letters += c
	for w in ALLOWED_NAMES:
		letters = letters.replace(w, "")
	return not BLOCKED_NAMES.any(func(w): return w in letters)


func _add_player(id: int, pilot: String) -> void:
	pilot = pilot.strip_edges().left(16)
	if not clean_name(pilot):
		pilot = ""
	var counts := _team_counts()
	gs.players[id] = {name = pilot if pilot else "Pilot%d" % (id % 1000), team = 0 if not gs.mode in TEAM_MODES or counts[0] <= counts[1] else 1, kills = 0, deaths = 0, revives = 0, plane = "cub"}


# ---------- connection health: pings, stalls, reconnects, goodbyes ----------
func _tick_network(dt: float) -> void:
	if Engine.has_meta("rejoin") and Time.get_ticks_msec() > Engine.get_meta("rejoin").until:
		_try_rejoin() # gives up on time, even mid-attempt
	var online := not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if multiplayer.is_server():
		ping_t -= dt / maxf(Engine.time_scale, 0.01)
		if online and ping_t <= 0.0:
			ping_t = 2.0
			for id in multiplayer.get_peers():
				probe.rpc_id(id, Time.get_ticks_msec())
		var now := Time.get_ticks_msec()
		for token in away.keys():
			if now > away[token].until:
				away.erase(token)
				_back_to_lobby_if_empty()
	elif online and gs.phase == "playing":
		var quiet := Time.get_ticks_msec() - last_sync_ms
		var stalled := last_sync_ms > 0 and quiet > 3000
		if stalled != (stall_from > 0):
			netlog("stall: no word from the host for 3 s" if stalled else "stall over after %d ms" % (Time.get_ticks_msec() - stall_from))
			stall_from = last_sync_ms if stalled else 0
		stall_label.visible = stalled or gs.get("loading", false)
		stall_label.text = "Connection to the host interrupted - waiting (%d s)" % (quiet / 1000) if stalled else "Waiting for every pilot to finish loading..."
		if last_sync_ms > 0 and quiet > 15000: # any transport: a host this silent is gone (or frozen)
			last_sync_ms = 0
			stall_from = 0
			_lost_host()
	else:
		stall_label.hide()
	# Tell the host once our world is built and has drawn a couple of frames; the countdown waits for it.
	if online and not multiplayer.is_server() and acked_world != Worlds.index and Engine.get_process_frames() > world_frame + 2 \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		acked_world = Worlds.index
		world_ready.rpc_id(1, acked_world)
	var t_ms := Time.get_ticks_msec()
	if online and frame_ms > 0 and t_ms - frame_ms > 500 and t_ms > hitch_quiet_ms:
		netlog("hitch %d ms" % (t_ms - frame_ms))
		hitch_quiet_ms = t_ms + 10000 # a throttled background window must not flood the log
	frame_ms = t_ms


@rpc("any_peer", "reliable")
func world_ready(world: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	loaded[id] = world
	if world == gs.world:
		load_wait.erase(id)


# Plain-text session log (user://netlog.txt, one line per event, rotated at 512 KB) so a friend's
# bad session can be looked into afterwards. Only rare events go here, never per-frame data.
const NETLOG := "user://netlog.txt"

func netlog(text: String) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var f := FileAccess.open(NETLOG, FileAccess.READ_WRITE if FileAccess.file_exists(NETLOG) else FileAccess.WRITE)
	if f and f.get_length() > 512 * 1024:
		f.close()
		DirAccess.rename_absolute(NETLOG, "user://netlog.old.txt")
		f = FileAccess.open(NETLOG, FileAccess.WRITE)
	if not f:
		return
	f.seek_end()
	f.store_line("%s %d pid%d %s m%d %s" % [Time.get_datetime_string_from_system(), Time.get_ticks_msec(), OS.get_process_id(), net_who, gs.get("match_id", 0), text])


# Gameplay requests carry the match they were made in; one from an earlier match (late reliable
# packet across a rematch) must not hit, kill or spend anything in the new one.
func stale(mid: int) -> bool:
	if mid == gs.match_id:
		return false
	stale_drops += 1
	tally("stale")
	if stale_drops <= 20:
		netlog("dropped stale rpc from %d (match %d)" % [_sender(), mid])
	return true


@rpc("authority", "unreliable")
func probe(t: int) -> void:
	pong.rpc_id(1, t)


@rpc("any_peer", "unreliable")
func pong(t: int) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var ms := Time.get_ticks_msec() - t
	if not gs.players.has(id) or ms < 0 or ms > 20000:
		return
	var info: Dictionary = gs.players[id]
	info.ping = int(lerpf(info.get("ping", ms), ms, 0.5))
	var now := Time.get_ticks_msec()
	if info.ping > 300 and now > lag_warned.get(id, 0):
		lag_warned[id] = now + 60000
		_feed("%s has a laggy connection (%d ms)" % [info.name, info.ping])
		netlog("high ping %d %s %d ms" % [id, info.name, info.ping])


func _player_token() -> String:
	if bot: # test bots on one machine must not share an identity, but keep theirs across a rejoin
		if not Engine.has_meta("bot_token"):
			Engine.set_meta("bot_token", "bot%d" % randi())
		return Engine.get_meta("bot_token")
	if Settings.values.get("player_id", "") == "":
		Settings.values.player_id = "%08x%08x" % [randi(), randi()]
		Settings.save()
	return Settings.values.player_id


# Lost the host without a goodbye (Wi-Fi blip, network switch): reconnect to the same room / address
# for up to 60 s. The host keeps our team, score and plane for that long.
func _lost_host() -> void:
	if quitting:
		return # already on the way out (the host ended the game, kicked us, or we left): no reconnect
	netlog("lost the host")
	multiplayer.multiplayer_peer.close() # no "leaving" goodbye: the host must keep our slot
	Engine.set_meta("rejoin", {target = last_target, until = Time.get_ticks_msec() + 60000, name = name_edit.text})
	_leave("Connection lost - reconnecting...")


func _try_rejoin() -> void:
	if not Engine.has_meta("rejoin") or gs.phase != "menu":
		return # a solo game or a hosted room started meanwhile: never pull the player out of it
	var r: Dictionary = Engine.get_meta("rejoin")
	if Time.get_ticks_msec() > r.until:
		Engine.remove_meta("rejoin")
		joining = false
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new() # drop an attempt still in flight
		status.text = "Could not reconnect - the host may have closed the game."
		print("MENU: ", status.text)
		return
	if joining:
		return
	address.text = r.target
	name_edit.text = r.name
	status.text = "Connection lost - reconnecting... (%d s left)" % ((r.until - Time.get_ticks_msec()) / 1000)
	print("MENU: ", status.text)
	join()


# Leaving on purpose: the host tells everyone (so they don't sit trying to reconnect), a client tells the host.
func _goodbye() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer is OfflineMultiplayerPeer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or multiplayer.get_peers().is_empty():
		return false
	if multiplayer.is_server():
		kicked.rpc("The host ended the game.")
	else:
		leaving.rpc_id(1)
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet:
		enet.host.flush()
	await get_tree().create_timer(0.25).timeout
	return true


func _notification(what: int) -> void:
	# Phone sent to the background (a call, the home swipe) or covered (Control Center): come back to the pause menu.
	if (what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and TouchControls.phone())) and gs.phase == "playing" and not menu_open():
		pause_root.show()
		end_btn.visible = gs.leader == multiplayer.get_unique_id()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	await _goodbye()
	get_tree().quit()


func _print_netstats() -> void:
	if multiplayer.is_server():
		print("TALLY ", tallies)
	var ns := netstats
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var rtt := -1.0
	var lossp := -1.0
	var kb := 0.0
	if peer and not multiplayer.is_server() and peer.get_peer(1):
		rtt = peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		lossp = peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0
		kb = peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0 / 10.0
	if multiplayer.is_server() and peer:
		var up := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0 / 10.0
		var down := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0 / 10.0
		var pk := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS) / 10.0
		print("HOST up %.1f KB/s (%d pkt/s) down %.1f KB/s  peers %d  fps %d  proc avg %.2f max %.1f ms  nodes %d orphans %d  mem %.1f MB  objs %d  gs %d B  planes %d bullets %d rockets %d" % [
			up, pk, down, multiplayer.get_peers().size(), Engine.get_frames_per_second(), 1000.0 * ns.get("proc", 0.0) / maxf(ns.get("pframes", 0), 1), 1000.0 * ns.get("proc_max", 0.0),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6,
			Performance.get_monitor(Performance.OBJECT_COUNT), var_to_bytes(gs).size(), players.get_child_count(), bullets.shots.size(), rockets.rockets.size()])
	var f := maxf(ns.frames, 1)
	print("NET rtt %dms loss %.1f%%  down %.1f KB/s  snaps %d  gap_max %dms  gaps>150ms %d  extrap %.1f%%  frozen %.2f%%  jumps %d  kink %.1fm  rkink %.1fdeg  wobble %.3fdeg  stale %d  corr %d avg %.1fm  fps %d  sync %d B" % [
		rtt, lossp, kb, ns.snaps, ns.gap_max, ns.gaps150, 100.0 * ns.extrap / f, 100.0 * ns.stall / f, ns.jumps, ns.dev_max, ns.rdev_max, ns.rdev_sum / f, ns.stale, ns.corr_n, ns.corr_sum / maxi(ns.corr_n, 1), Engine.get_frames_per_second(), ns.sync_bytes / maxi(ns.syncs, 1)])
	for k in ns:
		ns[k] = 0 if ns[k] is int else 0.0


@rpc("authority", "call_local", "reliable")
func sync(state: Dictionary, full: bool) -> void:
	last_sync_ms = Time.get_ticks_msec()
	if not (full or synced):
		return # a delta that beat our first full state (we connected but aren't registered yet)
	synced = true
	if netstats:
		netstats.sync_bytes += var_to_bytes(state).size()
		netstats.syncs += 1
	var was := seen_phase # not gs.phase: the server already changed that before pushing
	gs.merge(state, true) # only the keys that changed since the last push (all of them for a full push)
	seen_phase = gs.phase
	# Countdown: lead the server's value by our one-way lag so every peer hits GO together (capped:
	# a long local hitch, like building a world, inflates the measured ping for a few seconds).
	var lag: float = 0.0 if gs.get("loading", false) else minf(gs.players.get(multiplayer.get_unique_id(), {}).get("ping", 0) / 2000.0, 0.25)
	count_local = maxf(gs.get("countdown", 0.0) - lag, 0.0)
	if gs.phase == "lobby": # lobby picks show a picture; the world builds at LAUNCH
		Worlds.shown = gs.get("world", 0)
	elif gs.get("world", 0) != Worlds.index:
		_build_world_content(gs.world)
	if gs.phase != was and gs.phase == "playing":
		Sfx.ui(self, Sfx.CONFIRM, -4.0)
		if objectives:
			objectives.on_match_start()
		_show_intro()
		if battlefield:
			battlefield.reset_guns()
			for id in battlefield.crates.keys():
				battlefield.remove_crate(id)
	if gs.phase != was and gs.phase != "playing":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		lobby_cam.make_current()
		pause_root.hide()
	_refresh_ui()


# Reliable+ordered, so peers can't miss a delta; `full` is for a peer that just joined. gs keys are never erased.
# Sent every time even when empty: it doubles as the host's heartbeat (no-sync watchdog).
func _push(full := false) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		if gs.phase != "menu":
			sync({}, true) # solo: gs already is the state, just apply it locally
	else:
		full = full or gs_sent.is_empty()
		var d := {}
		for k in gs:
			if full or not gs_sent.has(k) or gs_sent[k] != gs[k]:
				d[k] = gs[k]
		gs_sent = gs.duplicate(true)
		sync.rpc(d, full)


# Snapshots ride in one packed batch per host frame, not one RPC (= one UDP datagram) per plane per peer.
# Entry: id s32 (peer id, or -n for "ai<n>"), t f32, pos 3 x f32, quat 4 x s16, shots u8.
const SNAP := 30 # + 1 byte: rockets (low 4 bits) / bombs (high 4) so everyone sees the hardpoints
var snap_out := PackedByteArray() # server: entries waiting for the end-of-frame flush


func send_snap(p: Node) -> void:
	var b := PackedByteArray()
	b.resize(SNAP)
	var n := str(p.name)
	b.encode_s32(0, -int(n.substr(2)) if n.begins_with("ai") else int(n))
	b.encode_float(4, p.sim_clock)
	for i in 3:
		b.encode_float(8 + i * 4, p.position[i])
	for i in 4:
		b.encode_s16(20 + i * 2, roundi(p.quaternion[i] * 32767.0))
	b[28] = mini(p.shots_out, 255)
	b[29] = mini(p.rockets_left, 15) | mini(p.bombs_left, 15) << 4
	p.shots_out = 0
	if multiplayer.is_server():
		_queue_snap(b)
	else:
		snap_up.rpc_id(1, b)


func _queue_snap(b: PackedByteArray) -> void:
	if snap_out.is_empty():
		_flush_snaps.call_deferred() # end of this frame, after every plane has queued
	snap_out.append_array(b)
	if snap_out.size() > 1100: # stay under one MTU: a fragmented unreliable packet dies with any fragment
		_flush_snaps()


func _flush_snaps() -> void:
	if snap_out and multiplayer.get_peers():
		snaps.rpc(snap_out)
	snap_out.clear()


@rpc("any_peer", "unreliable")
func snap_up(b: PackedByteArray) -> void:
	if b.size() == SNAP and b.decode_s32(0) == multiplayer.get_remote_sender_id(): # only your own plane
		_apply_snaps(b)
		_queue_snap(b)


@rpc("authority", "unreliable")
func snaps(b: PackedByteArray) -> void:
	_apply_snaps(b)


func _apply_snaps(b: PackedByteArray) -> void:
	for o in range(0, b.size() - SNAP + 1, SNAP):
		var id := b.decode_s32(o)
		var p := players.get_node_or_null(str(id) if id > 0 else "ai%d" % -id)
		if not p or p.is_multiplayer_authority():
			continue
		var q := Quaternion(b.decode_s16(o + 20), b.decode_s16(o + 22), b.decode_s16(o + 24), b.decode_s16(o + 26)).normalized()
		p.st(b.decode_float(o + 4), Vector3(b.decode_float(o + 8), b.decode_float(o + 12), b.decode_float(o + 16)), q)
		for i in mini(b[o + 28], 4):
			p.fired()
		p.show_ammo(b[o + 29] & 15, b[o + 29] >> 4)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# ---------- lobby actions (leader only) ----------

@rpc("any_peer", "call_local", "reliable")
func request_start() -> void:
	if not multiplayer.is_server():
		return
	if _sender() == gs.leader and gs.phase == "lobby":
		if gs.mode == 1 and 0 in _team_counts():
			_feed("Dogfight needs a pilot on each team")
			gs.msg = "Dogfight needs a pilot on each team"
			_push()
			return
		_start()


# Lobby choices made on this device are kept for next time (hosts only; a guest's taps go to the host).
func _remember(d: Dictionary) -> void:
	if _sender() == multiplayer.get_unique_id():
		Settings.values.merge(d, true)
		Settings.save()


@rpc("any_peer", "call_local", "reliable")
func request_battle(size_i: int, skill_i: int) -> void:
	if not multiplayer.is_server():
		return
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.size = clampi(size_i, 0, SIZES.size() - 1)
		gs.skill = clampi(skill_i, 0, SKILL_NAMES.size() - 1)
		_remember({last_size = gs.size, last_skill = gs.skill})
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_end() -> void:
	if not multiplayer.is_server():
		return
	if _sender() == gs.leader and gs.phase == "playing":
		_end("Match ended by the leader")


@rpc("any_peer", "call_local", "reliable")
func request_mode(m: int) -> void:
	if not multiplayer.is_server():
		return
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.mode = clampi(m, 0, MODES.size() - 1)
		gs.msg = ""
		var i := 0
		for id in gs.players:
			gs.players[id].team = 0 if gs.mode != 1 else i % 2 # vs-AI: everyone starts on Blue
			i += 1
		if gs.mode in [0, 3, 4, 5]:
			_remember({last_mode = gs.mode})
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_look(sticker: int, banner: int, livery: int, killfx: int) -> void:
	if not multiplayer.is_server() or not _allow(_sender(), "look", 2.0, 4.0):
		return
	var id := _sender()
	if gs.phase == "lobby" and gs.players.has(id):
		gs.players[id].sticker = clampi(sticker, 0, Planes.STICKERS.size() - 1)
		gs.players[id].banner = clampi(banner, 0, Planes.trail_names().size() - 1)
		gs.players[id].livery = clampi(livery, 0, Planes.LIVERIES.size() - 1)
		gs.players[id].killfx = clampi(killfx, 0, Planes.KILL_FX.size() - 1)
		_push()


# What you fly with: [sticker, trail, livery, kill effect]; paid looks only if you own them (or are
# trying them on a solo flight). Peers can't check a purchase, so this is the honest client's word.
func my_look() -> Array:
	var solo := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	return [int(Settings.values.get("sticker", 0)), shop.wear("banner", solo), shop.wear("livery", solo), shop.wear("killfx", solo)]


func send_look() -> void:
	if gs.phase == "lobby" and gs.players.has(multiplayer.get_unique_id()):
		var look := my_look()
		request_look.rpc_id(1, look[0], look[1], look[2], look[3])
	preview_key = ""
	_refresh_preview()


@rpc("any_peer", "call_local", "reliable")
func request_plane(kind: String) -> void:
	if not multiplayer.is_server():
		return
	if not _allow(_sender(), "plane", 2.0, 4.0):
		return
	var id := _sender()
	if gs.phase == "lobby" and gs.players.has(id) and Planes.TYPES.has(kind):
		gs.players[id].plane = kind
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_switch_team() -> void:
	if not multiplayer.is_server():
		return
	if not _allow(_sender(), "team", 1.0, 2.0):
		return
	var id := _sender()
	if gs.phase == "lobby" and gs.mode in TEAM_MODES and gs.players.has(id):
		gs.players[id].team = 1 - gs.players[id].team
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_ping(text: String) -> void:
	if not multiplayer.is_server():
		return
	if not _allow(_sender(), "ping", 1.0, 2.0):
		return
	var p := _plane(_sender())
	if p and p.alive and text in ["Help!", "On me"]:
		show_ping.rpc(p.position, "%s: %s" % [p.pilot, text], p.team)


@rpc("authority", "call_local", "reliable")
func show_ping(pos: Vector3, text: String, team: int) -> void:
	if team == _my_team():
		pings.append([pos, text, 5.0])


# ---------- match flow (server) ----------

func _start() -> void:
	seen.clear()
	ambushes.clear()
	if gs.world != Worlds.index:
		_build_world_content(gs.world)
	gs.match_id += 1
	gs.phase = "playing"
	gs.countdown = 0.0 if gs.mode == 2 else COUNTDOWN
	gs.feed = []
	gs.msg = ""
	gs.arrived = 0
	gs.lost = 0
	gs.wave = 0
	gs.next_wave = 10.0
	gs.sudden = false
	gs.clutch = [-1.0, -1.0]
	beacons.clear()
	respawning.clear()
	launches.clear() # plane names repeat across matches
	stale_drops = 0
	load_wait = gs.players.keys().filter(func(id): return id != 1 and loaded.get(id, -1) != gs.world)
	load_hold = 0.0
	gs.loading = gs.countdown > 0.0 and not load_wait.is_empty()
	gs.msg = ""
	gs.popped = 0
	gs.storm = 0.0
	for id in gs.players:
		gs.players[id].kills = 0
		gs.players[id].deaths = 0
		gs.players[id].revives = 0
	gs.team_kills = [0, 0]
	gs.ai_board = {}
	if objectives:
		objectives.reset(gs)
	if gs.mode in AI_MODES:
		var n: int = SIZES[gs.size]
		gs.lives = [n * 2, n * 2] if gs.mode == 3 else [-1, -1]
		gs.time = MATCH_TIME if gs.mode != 5 else 600.0
		var counts := _team_counts()
		var names := CALLSIGNS.duplicate()
		names.shuffle()
		for team in 2:
			for i in range(counts[team], n):
				var b := _base_for(team, i)
				var w := _spawn_ai("wing", team, b[0], b[1], Vector3.ZERO, Planes.ORDER.pick_random(), names.pop_back())
				# the difficulty is the enemy's: wingmen of an all-human-vs-AI side fly as "pilot"
				w.ai = PilotAI.make("pilot" if counts[team] > 0 and counts[1 - team] == 0 else SKILL_NAMES[gs.skill])
				w.ai.slot = i - counts[team]
				w.ai.job = JOBS[(i + team) % JOBS.size()]
	elif gs.mode == 2:
		gs.lives = [-1, -1]
		for i in 20:
			_spawn_balloon()
	elif gs.mode == 0:
		gs.lives = [ESCORT_LIVES, 0]
		gs.time = 0.0
		for i in 3:
			var off := Vector3((i - 1) * 45.0, (i % 2) * 15.0, absf(i - 1) * 40.0)
			_spawn_ai("bomber", 0, ROUTE[0] + off, _yaw_to(ROUTE[1] - ROUTE[0]), off)
	else:
		var counts := _team_counts()
		gs.lives = [5 if counts[0] == 1 else 10, 5 if counts[1] == 1 else 10]
		gs.time = MATCH_TIME
	for id in gs.players:
		_spawn_pilot(id, _base(id))
	netlog("start mode=%d world=%d pilots=%d loading=%s" % [gs.mode, gs.world, gs.players.size(), load_wait])
	_push()


func _end(text: String) -> void:
	if gs.phase != "playing":
		return
	gs.phase = "ended"
	gs.msg = text
	print("END: ", text, "\n", _scoreboard())
	netlog("end: " + text)
	_push()
	var id: int = gs.match_id
	get_tree().create_timer(8.0).timeout.connect(func():
		if gs.match_id == id and gs.phase == "ended":
			for c in players.get_children():
				c.queue_free()
			if TouchControls.phone() and multiplayer.multiplayer_peer is OfflineMultiplayerPeer: # phone solo: home, where PLAY goes again
				gs.phase = "menu"
				sync(gs.duplicate(true), true)
				return
			gs.phase = "lobby"
			_push()
			if "--start" in OS.get_cmdline_user_args():
				get_tree().create_timer(2.0).timeout.connect(func():
					if gs.phase == "lobby" and gs.match_id == id: # nobody started one by hand meanwhile
						_start()))


# Keyboard menus: whenever a panel is up and nothing has focus, focus its first control, so
# arrows/Tab move, Enter/Space press, Left/Right adjust sliders, Esc backs out of overlays.
func _keep_menu_focus() -> void:
	if TouchControls.on():
		return # no keyboard on a phone, and a held focus scrolls panels and swallows taps
	var top_panel: Control = null
	for r in [credits_root, howto_root, touch_root, settings_root, shop_ui, pause_root, results_root, lobby_root, mp_root, menu_root]:
		if r and r.visible:
			top_panel = r
			break
	if not top_panel:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner and owner.is_visible_in_tree() and top_panel.is_ancestor_of(owner):
		return
	var first := _first_focusable(top_panel)
	if first:
		first.grab_focus()


func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and c.is_visible_in_tree():
			if (c is BaseButton or c is Slider or c is Menus.Selector) and c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and c.disabled):
				return c
			var deeper := _first_focusable(c)
			if deeper:
				return deeper
	return null


# Home screen: a slow cinematic orbit around the whole map, always looking in at its heart (think the
# Prince of Persia: The Two Thrones title screen). The lobby gets its fixed pose back for the plane preview.
const LOBBY_EYE := Vector3(0, 230, 2450)
const LOBBY_LOOK := Vector3(0, 60, 0)
const ORBIT_LAP := 180.0 # seconds per lap
const ORBIT_R := 1900.0
var orbit := 0.0
var orbit_y := 400.0
var orbiting := false


func _orbit_menu(dt: float) -> void:
	if gs.phase == "menu" and not spectating and not (shop_ui and shop_ui.visible):
		orbit += dt * TAU / ORBIT_LAP
		var at := func(a: float) -> Vector3: return Vector3(sin(a) * ORBIT_R, 0.0, cos(a) * ORBIT_R)
		var eye: Vector3 = at.call(orbit)
		var ahead: Vector3 = at.call(orbit + 0.12)
		var ground := maxf(Terrain.floor_below(Vector3(eye.x, 3000.0, eye.z)), Terrain.floor_below(Vector3(ahead.x, 3000.0, ahead.z)))
		var want := maxf(ground + 160.0, 420.0) + sin(orbit * 3.0) * 40.0
		orbit_y = want if not orbiting else lerpf(orbit_y, want, 1.0 - exp(-0.8 * dt)) # glide over ridges, no jerks
		orbit_y = maxf(orbit_y, ground + 60.0)
		var look := Vector3(sin(orbit * 2.0) * 250.0, 80.0, cos(orbit * 1.3) * 250.0)
		lobby_cam.look_at_from_position(Vector3(eye.x, orbit_y, eye.z), look)
		orbiting = true
	elif orbiting:
		orbiting = false
		lobby_cam.look_at_from_position(LOBBY_EYE, LOBBY_LOOK)


func _process(dt: float) -> void:
	if Sfx.enabled:
		_keep_menu_focus()
		_orbit_menu(dt)
		if TouchControls.phone():
			Settings.adapt_res(get_viewport(), dt)
	fps_label.visible = Settings.values.show_fps
	if fps_label.visible:
		fps_ms = lerpf(fps_ms, dt * 1000.0, 0.1)
		if Engine.get_process_frames() % 15 == 0:
			fps_label.text = "%d FPS  %.1f ms" % [Engine.get_frames_per_second(), fps_ms]
	if pings:
		for p in pings:
			p[2] -= dt
		pings = pings.filter(func(p): return p[2] > 0.0)
	overlay.queue_redraw()
	map_t -= dt
	if map_t <= 0.0: # the minimap redraws at 20 Hz, the markers every frame
		map_t = 0.05
		minimap.queue_redraw()
	_track_seen(dt)
	_tick_intro(dt)
	if netstats:
		var pt := Performance.get_monitor(Performance.TIME_PROCESS)
		netstats.proc = netstats.get("proc", 0.0) + pt
		netstats.proc_max = maxf(netstats.get("proc_max", 0.0), pt)
		netstats.pframes = netstats.get("pframes", 0) + 1
	if map_img:
		_bake_map()
	_refresh_hud()
	if preview.visible:
		_turntable(dt)
	if spectating and gs.phase in ["playing", "ended"]:
		_spectate(dt)
	_tick_network(dt)
	if not multiplayer.is_server() or gs.phase != "playing":
		return
	if gs.get("countdown", 0.0) > 0.0: # clock, raids, hazards and guns wait for GO
		if gs.get("loading", false): # ...and GO waits for everyone's world, but not forever
			load_hold += dt
			if load_wait.is_empty() or load_hold > LOAD_WAIT:
				gs.loading = false
				netlog("countdown after %.1f s loading wait%s" % [load_hold, " (gave up on %s)" % [load_wait] if load_wait else ""])
				push_cd = 0.0
			push_cd -= dt
			if push_cd <= 0.0: # keep the waiting peers' stall detector quiet
				push_cd = 0.5
				_push()
			return
		var before := ceili(gs.countdown)
		gs.countdown = maxf(gs.countdown - dt, 0.0)
		if ceili(gs.countdown) != before:
			_push()
		return
	_tick_beacons(dt)
	_tick_prize(dt)
	if env:
		env.server_tick(dt)
	if battlefield:
		battlefield.server_tick(dt)
		battlefield.server_guns(dt)

	if gs.mode == 0:
		_tick_escort(dt)
	elif gs.mode == 1:
		_tick_dogfight(dt)
	elif gs.mode == 3:
		_tick_battle(dt)
	elif gs.mode in [4, 5]:
		gs.time -= dt
		if gs.time <= 0.0:
			var a: float = gs.score[0] if gs.mode == 4 else objectives.hqs[0].hp
			var b: float = gs.score[1] if gs.mode == 4 else objectives.hqs[1].hp
			var how := "%d-%d" % [a, b] if gs.mode == 4 else "HQ %d%% vs %d%%" % [100 * a / Objectives.HQ_HP, 100 * b / Objectives.HQ_HP]
			_end(("Draw! (%s)" if a == b else "%s team wins on time! (%s)" % [TEAM_NAMES[0 if a > b else 1], "%s"]) % how)
	if objectives:
		objectives.tick(dt)
	push_cd -= dt
	if push_cd <= 0.0:
		push_cd = 0.5
		_push()


func _tick_escort(dt: float) -> void:
	gs.time += dt
	gs.next_wave -= dt
	if gs.next_wave <= 0.0 and gs.wave < WAVES:
		gs.wave += 1
		gs.next_wave = WAVE_INTERVAL
		_spawn_wave()
	if gs.arrived >= 2:
		_end("Bombers delivered. Mission complete!")
	elif gs.lost >= 2:
		_end("Bombers lost. Mission failed.")
	elif gs.lives[0] == 0 and _pilots(0, true).is_empty() and beacons.is_empty() and respawning.is_empty():
		_end("Squadron wiped out. Mission failed.")


func _tick_dogfight(dt: float) -> void:
	for team in 2:
		if gs.lives[team] == 0 and gs.clutch[team] < 0.0:
			gs.clutch[team] = CLUTCH_TIME
			_feed("%s is out of lives! %ds to turn it around" % [TEAM_NAMES[team], CLUTCH_TIME])
		if gs.clutch[team] >= 0.0:
			gs.clutch[team] -= dt
			var wiped := _pilots(team, true).is_empty() and not beacons.values().any(func(b): return b.team == team) and not team in respawning.values()
			if gs.clutch[team] <= 0.0 or wiped:
				_end("%s wins!" % TEAM_NAMES[1 - team])
				return
	if gs.sudden:
		return
	gs.time -= dt
	if gs.time <= 0.0:
		var a: Array = [gs.lives[0], _pilots(0, true).size()]
		var b: Array = [gs.lives[1], _pilots(1, true).size()]
		if a == b:
			gs.sudden = true
			_feed("Sudden death: next kill wins")
		else:
			_end("%s wins on time!" % TEAM_NAMES[0 if a > b else 1])


# Team Battle: shared lives per team; a team loses when out of lives with nobody flying.
func _tick_battle(dt: float) -> void:
	gs.time -= dt
	for team in 2:
		var flying := players.get_children().filter(func(p): return p.team == team and p.alive and p.role in ["pilot", "wing"]).size()
		if gs.lives[team] <= 0 and flying == 0 and not team in respawning.values():
			_end("%s team wins!" % TEAM_NAMES[1 - team])
			return
	if gs.time <= 0.0:
		var a: int = gs.lives[0] + _flying(0)
		var b: int = gs.lives[1] + _flying(1)
		_end("Draw!" if a == b else "%s team wins on time!" % TEAM_NAMES[0 if a > b else 1])


func _flying(team: int) -> int:
	var n := 0
	for p in players.get_children():
		if p.team == team and p.alive and p.role in ["pilot", "wing"]:
			n += 1
	return n


func _tick_beacons(dt: float) -> void:
	for id in beacons.keys():
		var b: Dictionary = beacons[id]
		var victim := _plane(id)
		b.t -= dt
		if not victim:
			beacons.erase(id)
			continue
		for p in _pilots(b.team, true):
			if p.position.distance_to(b.pos) < BEACON_RADIUS:
				beacons.erase(id)
				victim.respawn.rpc(b.pos + Vector3.UP * 20.0, _yaw_to(-p.basis.z))
				_feed("%s revived %s" % [p.pilot, victim.pilot])
				if gs.players.has(int(str(p.name))):
					gs.players[int(str(p.name))].revives += 1
				break
		if beacons.has(id) and (b.t <= 0.0 or _pilots(b.team, true).is_empty()):
			beacons.erase(id)
			_spend_life(victim)
	gs.beacons = beacons.keys().map(func(id): return [beacons[id].pos, beacons[id].team, ceili(beacons[id].t), _plane(id).pilot])


@rpc("authority", "unreliable")
func gunner_fired(bomber: String, dir: Vector3) -> void:
	var p := players.get_node_or_null(bomber)
	if p:
		bullets.fire(p.position + dir * 12.0, p.vel_estimate() + dir * Aircraft.BULLET_SPEED, p, false)


func _spawn_wave() -> void:
	var lead := _lead_bomber()
	if not lead:
		return
	var alive := players.get_children().filter(func(p): return p.role == "fighter" and p.alive).size()
	var n := mini(1 + gs.players.size(), FIGHTER_CAP - alive)
	var fwd: Vector3 = -lead.basis.z
	for i in n:
		var pos: Vector3 = lead.position + fwd * 1300.0 + fwd.cross(Vector3.UP) * randf_range(-600, 600)
		pos.y = randf_range(250, 400)
		_spawn_ai("fighter", 1, pos, _yaw_to(lead.position - pos), Vector3.ZERO)
	_feed("Wave %d incoming: %d raiders" % [gs.wave, n])


# ---------- damage, death, revive (server) ----------

@rpc("any_peer", "reliable")
func report_hit(target_name: String, weapon: int, comp: int, mid: int) -> void:
	if not multiplayer.is_server() or stale(mid):
		return
	var a := _plane(multiplayer.get_remote_sender_id())
	var t := find_unit(target_name) # planes, turrets, HQs
	weapon = clampi(weapon, 0, 2)
	var why := _hit_check(a, t, weapon) if a and t else "unknown"
	tally("hit_" + (why if why else "ok"))
	if why == "":
		apply_hit(a, t, weapon, clampi(comp, -1, 3))


# Favour the shooter, within limits: rewind the target at most 0.3 s to where a lagging shooter saw
# it, require range and (for guns) a line of sight past terrain at that moment; rockets and bombs
# must match a launch the host saw that could have reached the target by now. "" = accept.
func _hit_check(a: Node, t: Node, weapon: int) -> String:
	var id := int(str(a.name))
	var ago := clampf(gs.players.get(id, {}).get("ping", 100) / 2000.0 + 0.1, 0.0, 0.3)
	var tp: Vector3 = t.position_at(ago) if t.has_method("position_at") else t.position
	if t == a:
		return "self"
	if weapon > 0:
		return _launch_used(a, t, tp, weapon == 2)
	if not a.alive and Time.get_ticks_msec() - a.died_ms > 2200: # rounds already in the air when you died still count
		return "dead"
	if a.position.distance_to(tp) > 1100.0:
		return "range"
	if not _allow(id, "gun", 1.25 / (a.fire_interval * (0.5 if a.buffs.has("twin") else 1.0)), 8.0):
		return "rate"
	return "" if _clear_line(a.position, tp) else "los"


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var len := from.distance_to(to)
	var k := 10.0
	while k < len - 20.0:
		if Terrain.solid(from.lerp(to, k / len)):
			return false
		k += 30.0
	return true


# Every peer: a client's rocket or bomb launch, checked against what that plane can carry and where
# it is. Shooters name their ordnance "<plane>_<n>", so ids can't collide with anyone else's.
func note_launch(p: Node, id: String, at: Vector3, v: Vector3, bomb: bool) -> bool:
	var peer := p.get_multiplayer_authority()
	var why := ""
	if not id.begins_with(str(p.name) + "_") or id.length() > 40:
		why = "id"
	elif not p.alive and Time.get_ticks_msec() - p.died_ms > 1500:
		why = "dead"
	elif at.distance_to(p.position) > 400.0 or v.length() > 400.0:
		why = "where"
	elif not (bomb and _allow(peer, "bomb", 1.0 / 20.0, p.max_bombs) or not bomb and _allow(peer, "rocket", 1.0 / (1.0 if p.buffs.has("swarm") else Aircraft.ROCKET_RELOAD), p.max_rockets)):
		why = "ammo"
	tally("launch_" + (why if why else "ok"))
	if why:
		return false
	var list: Array = launches.get(str(p.name), [])
	list.append({t = Time.get_ticks_msec(), p = at, v = v.length(), bomb = bomb, first = 0, hit = []})
	launches[str(p.name)] = list.slice(-12)
	return true


# A launch that could have reached `tp` by now (rockets top out near 520 m/s, bombs fall), hitting
# each target once; one explosion may splash several targets within 400 ms.
func _launch_used(p: Node, t: Node, tp: Vector3, bomb: bool) -> String:
	var now := Time.get_ticks_msec()
	var why := "launch"
	for l in launches.get(str(p.name), []):
		var e: float = (now - l.t) / 1000.0
		if l.bomb != bomb or e > (25.0 if bomb else 9.0) or l.first > 0 and now - l.first > 400:
			continue
		var reach: float = ((l.v + 15.0 * e) if bomb else 520.0) * (e + 0.3) + 100.0 + t.hit_radius
		if tp.distance_to(l.p) > reach:
			why = "reach"
		elif t in l.hit:
			why = "dup"
		else:
			l.first = now if l.first == 0 else l.first
			l.hit.append(t)
			return ""
	return why


# Token-bucket rate limit per peer and request kind. A peer that keeps hammering gets kicked.
func _allow(id: int, key: String, rate: float, burst: float) -> bool:
	var k := "%d:%s" % [id, key]
	var now := Time.get_ticks_msec() / 1000.0
	var b: Array = buckets.get(k, [burst, now])
	b[0] = minf(burst, b[0] + (now - b[1]) * rate)
	b[1] = now
	buckets[k] = b
	if b[0] >= 1.0:
		b[0] -= 1.0
		return true
	tally("rate_" + key)
	if key != "strikes" and id > 1 and multiplayer.is_server() and not _allow(id, "strikes", 5.0, 300.0):
		buckets.erase("%d:strikes" % id)
		kicked.rpc_id(id, "Disconnected: too many invalid requests.")
		get_tree().create_timer(2.0).timeout.connect(func(): if id in multiplayer.get_peers(): multiplayer.multiplayer_peer.disconnect_peer(id))
	return false


# Respawn / resupply: the host's ammo count for this plane starts full again.
func refill(p: Node) -> void:
	for key in ["rocket", "bomb"]:
		buckets.erase("%d:%s" % [p.get_multiplayer_authority(), key])


func tally(why: String) -> void:
	tallies[why] = tallies.get(why, 0) + 1


@rpc("any_peer", "call_local", "reliable")
func report_crash(mid: int) -> void:
	if not multiplayer.is_server() or stale(mid):
		return
	var p := _plane(_sender())
	if p:
		kill(p, null)


func apply_hit(a: Node, t: Node, weapon: int, comp := -1) -> void:
	if a.is_ai and weapon == 0:
		stat_hits += 1
	if t.alive and t.is_in_group("targets") and a.team != t.team and gs.phase == "playing" and gs.get("countdown", 0.0) <= 0.0:
		var dmg: int = DAMAGE[weapon]
		if weapon == 2:
			dmg = dmg * 3 if t.role in ["hq", "turret"] else dmg / 2 # bombs are for the ground
		if a.role == "fighter":
			dmg = ceili(dmg * (0.4 if t.role == "bomber" else 0.6)) # raiders hit softer (bombers must be escortable)
		elif a.role == "turret":
			dmg = ceili(dmg * (0.15 if t.role == "bomber" else 0.6)) # defenses chip bombers, they don't erase them
			if t.role == "pilot" and gs.mode in AI_MODES:
				dmg = ceili(dmg * PilotAI.SKILLS[SKILL_NAMES[gs.skill]].hurt)
		elif a.role == "wing" and t.role == "pilot":
			dmg = ceili(dmg * PilotAI.SKILLS[a.ai.get("skill", "pilot")].hurt)
		elif a.role == "pilot" and t.role == "wing":
			dmg = ceili(dmg * PilotAI.SKILLS[t.ai.get("skill", "pilot")].frail)
		if weapon < 2 and t.has_method("off_guard") and a.has_method("off_guard"):
			dmg = _off_guard(a, t, dmg)
		if t.get("buffs") and t.buffs.has("shield"):
			dmg = ceili(dmg * 0.5)
		var c: PackedFloat32Array = t.comps.duplicate()
		if comp >= 0:
			c[comp] = maxf(c[comp] - dmg / (t.max_hp * 0.45), 0.0) # a part dies after ~45% of hp worth of hits
		t.set_hp.rpc(t.hp - dmg, c)
		PilotAI.on_hit(t, a, self)
		if t.hp <= 0:
			kill(t, a)


func kill(victim: Node, killer: Node, quiet := false) -> void:
	if not victim.alive:
		return
	victim.die.rpc(true)
	if gs.phase != "playing":
		return
	if victim.role == "prize":
		_award_prize(killer)
		var vid := victim.get_instance_id()
		get_tree().create_timer(1.0).timeout.connect(func():
			var v = instance_from_id(vid)
			if is_instance_valid(v):
				v.queue_free())
		_push()
		return
	if not quiet:
		_feed("%s shot down %s" % [killer.pilot, victim.pilot] if killer else "%s crashed" % victim.pilot)
	if killer and killer.role == "pilot" and gs.players.has(int(str(killer.name))):
		gs.players[int(str(killer.name))].kills += 1
		sfx_event.rpc("kill", killer.team, victim.position, str(killer.name))
	if killer and killer.team != victim.team:
		gs.team_kills[killer.team] += 1
	if killer and killer.role == "wing":
		var row: Dictionary = gs.ai_board.get_or_add(killer.pilot, {team = killer.team, style = PilotAI.ARCHETYPES[killer.ai.arch].name, kills = 0})
		row.kills += 1
	PilotAI.on_kill(victim, killer, self)
	if objectives and victim.role in ["pilot", "wing"]:
		objectives.on_down(victim)
	if victim.role == "hq":
		_end("%s team destroyed the %s!" % [TEAM_NAMES[1 - victim.team], victim.pilot])
		return
	if victim.role == "striker":
		get_tree().create_timer(1.0).timeout.connect(victim.queue_free)
		_push()
		return
	if gs.mode in [4, 5] and victim.role in ["pilot", "wing"]:
		if victim.role == "pilot" and gs.players.has(int(str(victim.name))):
			gs.players[int(str(victim.name))].deaths += 1
		if victim.role == "wing":
			PilotAI.reset(victim)
		_respawn_later(victim, RESPAWN_DELAY)
		_push()
		return
	if spectating and killer and killer.alive:
		cut_to.rpc(killer.name)
	if gs.mode == 3 and victim.role in ["pilot", "wing"]:
		if victim.role == "pilot" and gs.players.has(int(str(victim.name))):
			gs.players[int(str(victim.name))].deaths += 1
		if victim.role == "wing":
			PilotAI.reset(victim)
		_spend_life(victim)
		_push()
		return
	if victim.role == "pilot" and gs.mode == 2:
		if gs.players.has(int(str(victim.name))):
			gs.players[int(str(victim.name))].deaths += 1
		_respawn_later(victim, 2.0)
		_push()
		return
	match victim.role:
		"balloon":
			gs.popped += 1
			get_tree().create_timer(1.0).timeout.connect(victim.queue_free)
			var mid: int = gs.match_id
			get_tree().create_timer(4.0).timeout.connect(func():
				if gs.match_id == mid and gs.phase == "playing":
					_spawn_balloon())
		"fighter", "bomber":
			if victim.role == "bomber":
				gs.lost += 1
			get_tree().create_timer(1.0).timeout.connect(victim.queue_free)
		"pilot":
			var id := int(str(victim.name))
			if gs.players.has(id):
				gs.players[id].deaths += 1
			if gs.sudden:
				_end("%s wins!" % TEAM_NAMES[1 - victim.team])
			elif _pilots(victim.team, true).is_empty():
				_spend_life(victim) # nobody left to revive you
			else:
				var at: Vector3 = victim.position
				at.y = maxf(at.y, Terrain.height(at.x, at.z) + 80.0)
				beacons[id] = {pos = at, t = BEACON_TIME, team = victim.team}
	_push()


func _spend_life(victim: Node) -> void:
	if gs.lives[victim.team] <= 0:
		_feed("%s is out" % victim.pilot)
		return
	gs.lives[victim.team] -= 1
	_respawn_later(victim, RESPAWN_DELAY)


func _respawn_later(victim: Node, delay: float) -> void:
	var key := str(victim.name)
	respawning[key] = victim.team
	var id: int = gs.match_id
	var vid := victim.get_instance_id() # never capture the node: it may be freed before the timer
	get_tree().create_timer(delay).timeout.connect(func():
		respawning.erase(key)
		var v = instance_from_id(vid)
		if is_instance_valid(v) and gs.match_id == id and gs.phase == "playing" and not v.alive:
			var b := _base(int(key)) if v.role == "pilot" else _base_for(v.team, randi() % 6)
			v.respawn.rpc(b[0], b[1]))


func _feed(text: String) -> void:
	print("[%5.1f] %s" % [Time.get_ticks_msec() / 1000.0, text])
	if not multiplayer.is_server():
		return # gs is the host's (a --bot client's own radio chatter used to flicker in until the next sync)
	gs.feed.append(text)
	gs.feed = gs.feed.slice(-5)


# ---------- spawning ----------

func _spawn_plane(d: Dictionary) -> Node:
	var p := Aircraft.new()
	p.name = d.name
	p.pilot = d.pilot
	p.team = d.team
	p.role = d.role
	p.kind = d.kind
	p.is_ai = d.role != "pilot"
	p.offset = d.offset
	p.set_multiplayer_authority(d.id)
	p.position = d.pos
	p.rotation.y = d.yaw
	return p


# Offline (solo) the spawner builds nodes but doesn't add them; do it ourselves.
func _spawn(data: Dictionary) -> Node:
	var n := spawner.spawn(data)
	if n and not n.is_inside_tree():
		players.add_child(n, true)
	return n


func _spawn_pilot(id: int, at: Array) -> void:
	var info: Dictionary = gs.players[id]
	_spawn({name = str(id), id = id, pilot = info.name, team = info.team, role = "pilot", kind = info.get("plane", "cub"), pos = at[0], yaw = at[1], offset = Vector3.ZERO})


func _spawn_ai(role: String, team: int, pos: Vector3, yaw: float, offset: Vector3, kind := "", pilot := "") -> Node:
	ai_count += 1
	if kind == "":
		kind = {bomber = "twin", balloon = "balloon"}.get(role, "racer")
	if pilot == "":
		pilot = {bomber = "Bomber", balloon = "Balloon"}.get(role, "Raider")
	var n := _spawn({name = "ai%d" % ai_count, id = 1, pilot = pilot, team = team, role = role, kind = kind, pos = pos, yaw = yaw, offset = offset})
	if role == "fighter":
		n.ai = PilotAI.make("rookie")
	return n


# AI radio chatter in the feed, rate-limited so it reads like comms, not spam.
var stat_shots := 0 # test stats: AI gun accuracy
var stat_hits := 0
var seen := {} # victim id -> {attacker id: msec the victim last had that enemy in view} (host)
var ambushes := {} # "attacker>victim" -> msec an ambush started (its 0.6 s window, then a 10 s cooldown)
var seen_t := 0.0


# Host, 10 Hz: who has whom in view. Being out of sight is what makes an ambush.
func _track_seen(dt: float) -> void:
	seen_t -= dt
	if seen_t > 0.0 or not multiplayer.is_server() or gs.phase != "playing":
		return
	seen_t = 0.1
	var now := Time.get_ticks_msec()
	var planes := get_tree().get_nodes_in_group("targets").filter(func(p): return p.alive and p.has_method("off_guard"))
	for v in planes:
		var row: Dictionary = seen.get_or_add(v.get_instance_id(), {})
		for a in planes:
			if a.team != v.team and v.position.distance_squared_to(a.position) < 1440000.0 and v.sees(a):
				row[a.get_instance_id()] = now


# Catching someone off guard (research: reward getting there unseen; tail position alone already wins).
# AMBUSH: the victim hasn't had you in view for 2.5 s -> x1.75 for 0.6 s, once per 10 s per pair.
# TAIL: you're in its rear cone -> x1.25. AI attackers only get x1.1 from behind, so the game stays easy.
# No bonus in the first 3 s after a respawn; an ambush can't take a healthy player plane straight to 0.
func _off_guard(a: Node, t: Node, dmg: int) -> int:
	var now := Time.get_ticks_msec()
	if now - t.born_ms < 3000:
		return dmg
	if a.is_ai:
		return ceili(dmg * 1.1) if t.off_guard(a) else dmg
	var k := "%d>%d" % [a.get_instance_id(), t.get_instance_id()]
	var start: int = ambushes.get(k, -100000)
	var tag := ""
	if now - start < 600:
		tag = "AMBUSH!"
	elif now - start > 10000 and now - seen.get(t.get_instance_id(), {}).get(a.get_instance_id(), -100000) > 2500:
		ambushes[k] = now
		tag = "AMBUSH!"
	elif t.off_guard(a):
		tag = "TAIL SHOT"
	seen.get_or_add(t.get_instance_id(), {})[a.get_instance_id()] = now # it knows you're there now
	if tag == "":
		return dmg
	var out := ceili(dmg * (1.75 if tag == "AMBUSH!" else 1.25))
	if tag == "AMBUSH!" and t.role == "pilot" and t.hp > t.max_hp / 2 and out >= t.hp:
		out = t.hp - 1
	if a.role == "pilot" and gs.players.has(int(str(a.name))):
		a.hit_tag.rpc_id(int(str(a.name)), tag)
	return out
var radio_cd := 0.0
var radio_last := {}

func radio(p: Node, text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < radio_cd or now < radio_last.get(p.name, 0.0):
		return
	radio_cd = now + 2.5
	radio_last[p.name] = now + 12.0
	_feed('%s: "%s"' % [p.pilot, text])
	if multiplayer.is_server(): # test bots run the same AI code on clients; only the host may broadcast
		say_bubble.rpc(str(p.name), text)


func repair(p: Node, amount: int) -> void:
	var c: PackedFloat32Array = p.comps.duplicate()
	for i in 4:
		c[i] = minf(c[i] + 0.04 * amount / 5.0, 1.0)
	p.set_hp.rpc(mini(p.hp + amount, p.max_hp), c)


# Prize balloons: every ~55 s one appears mid-way between the two bases (same distance for both teams),
# drifts for 60 s, and whoever lands the popping hit gets a random reward. Server decides everything.
const PRIZES := [{id = "repair", name = "FULL REPAIR"}, {id = "refill", name = "AMMO REFILL"},
	{id = "twin", name = "TWIN GUNS (20 s)", secs = 20.0}, {id = "shield", name = "SHIELD (15 s)", secs = 15.0},
	{id = "swarm", name = "ROCKET SWARM (20 s)", secs = 20.0}]


func _tick_prize(dt: float) -> void:
	if is_instance_valid(prize) and prize.alive:
		return
	prize_t -= dt
	if prize_t > 0.0:
		return
	prize_t = 55.0
	var a := home_for(0)
	var b := home_for(1)
	var side := (b - a).cross(Vector3.UP).normalized()
	var at := (a + b) / 2.0 + side * randf_range(-450.0, 450.0)
	at.y = Terrain.floor_below(Vector3(at.x, 3000.0, at.z)) + randf_range(160.0, 260.0)
	prize = _spawn_ai("prize", 2, at, 0.0, at, "balloon", "PRIZE")
	_feed("A PRIZE BALLOON appeared mid-map: pop it for a reward!")
	sfx_event.rpc("prize_up", 2, at, "")
	var pid := prize.get_instance_id()
	var mid: int = gs.match_id
	get_tree().create_timer(60.0).timeout.connect(func():
		var p = instance_from_id(pid)
		if is_instance_valid(p) and p.alive and gs.match_id == mid:
			_feed("The prize balloon floated away.")
			p.queue_free())


func _award_prize(killer: Node) -> void:
	if not killer or not killer.alive or not killer.role in ["pilot", "wing"]:
		_feed("The prize balloon popped - nobody claimed it.")
		return
	var pr: Dictionary = PRIZES.pick_random()
	match pr.id:
		"repair":
			repair(killer, killer.max_hp)
		"refill":
			killer.resupply.rpc()
		_:
			killer.buff.rpc(pr.id, pr.secs)
	_feed("%s popped the prize balloon: %s!" % [killer.pilot, pr.name])
	sfx_event.rpc("prize", killer.team, killer.position, str(killer.name))


func _spawn_balloon() -> void:
	var x := randf_range(-1500, 1500)
	var z := randf_range(-1500, 1500)
	var pos := Vector3(x, Terrain.height(x, z) + randf_range(60, 260), z)
	_spawn_ai("balloon", 1, pos, randf() * TAU, pos)


# Returns [position, yaw] for a pilot (re)spawn.
func _base(id: int) -> Array:
	var team: int = gs.players[id].team if gs.players.has(id) else 0
	var i: int = gs.players.keys().find(id)
	if gs.mode == 0:
		var lead := _lead_bomber()
		if lead:
			var f: Vector3 = -lead.basis.z
			return [lead.position - f * 200.0 + f.cross(Vector3.UP) * (i * 30.0 - 45.0) + Vector3.UP * 40.0, _yaw_to(f)]
		return [ROUTE[0] + Vector3(i * 30.0, 60, 200), _yaw_to(ROUTE[1] - ROUTE[0])]
	return _base_for(team, i)


func _base_for(team: int, i: int) -> Array:
	if team == 0:
		return [Vector3(i * 30.0 - 75.0, 160 + (i % 2) * 15, 2150 + i * 20), 0.0] # over the home runway (LEVEL.md)
	return [Vector3(-375.0 + i * 30.0, 200 + (i % 2) * 15, -1450 - i * 20), PI] # over the Red airfield


# ---------- AI (server) ----------

func ai_think(p: Node, dt: float) -> void:
	if p.role in ["balloon", "prize"]:
		p.position = p.offset + Vector3(0, sin(Time.get_ticks_msec() / 900.0 + p.offset.x) * 4.0, 0)
		p.rotation.y += 0.2 * dt # set the angle: repeated rotate_y drifts the basis off unit length
		return
	if p.role == "bomber":
		_bomber_move(p, dt)
		return
	if p.role == "striker":
		objectives.strike_move(p, dt)
		return
	PilotAI.think(p, dt, self)


# Chase camera on an AI pilot; switches to whoever is in the thick of it every few seconds.
func _spectate(dt: float) -> void:
	spec_t -= dt
	var alive := players.get_children().filter(func(p): return p.alive and p.role in ["wing", "fighter", "pilot"])
	if alive.is_empty():
		return
	if spec_t <= 0.0 or not is_instance_valid(spec_target) or not spec_target.alive:
		spec_t = 10.0
		# Prefer someone in a close fight right now.
		var fighting := alive.filter(func(p): return p.ai.get("state", 0) == PilotAI.ATTACK and is_instance_valid(p.ai.get("target")) and p.position.distance_to(p.ai.target.position) < 500.0)
		spec_target = (fighting if fighting else alive).pick_random()
	lobby_cam.make_current()
	var want: Vector3 = spec_target.position + spec_target.basis * Vector3(0, 6, 26)
	lobby_cam.global_position = lobby_cam.global_position.lerp(want, 1.0 - exp(-4.0 * dt))
	var look: Vector3 = spec_target.position - spec_target.basis.z * 30.0
	lobby_cam.look_at(look)
	var s: Dictionary = spec_target.ai
	top.text = "WATCHING %s  (%s, %s)   %s   [Tab: next pilot]" % [spec_target.pilot, PilotAI.ARCHETYPES[s.arch].name if s.has("arch") else "?", s.get("skill", ""),
		["patrolling", "pursuing", "attacking", "evading", "retreating"][s.get("state", 0)] + ("  > " + s.move.name if not s.get("move", {}).is_empty() else "")]


@rpc("authority", "call_local", "reliable")
func cut_to(who: String) -> void:
	var n := players.get_node_or_null(who)
	if n and spectating:
		spec_target = n
		spec_t = 7.0


func home_for(team: int) -> Vector3:
	return Vector3(0, 0, 2000) if team == 0 else Vector3(-300, 0, -1500)


func _bomber_move(p: Node, dt: float) -> void:
	var to: Vector3 = ROUTE[p.wp] + p.offset - p.position
	if to.length() < 15.0:
		p.wp += 1
		if p.wp >= ROUTE.size():
			gs.arrived += 1
			_feed("A bomber reached the target!")
			p.queue_free()
			return
	p.velocity = to.normalized() * BOMBER_SPEED
	p.position += p.velocity * dt
	# Tail gunner: sprays the nearest raider in range.
	p.fire_cd -= dt
	if p.fire_cd <= 0.0:
		for t in players.get_children():
			if t.role == "fighter" and t.alive and t.position.distance_to(p.position) < 450.0:
				var dir: Vector3 = (t.position + t.velocity * 0.4 - p.position).normalized()
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.06).normalized()
				bullets.fire(p.position + dir * 12.0, p.velocity + dir * Aircraft.BULLET_SPEED, p, true)
				gunner_fired.rpc(p.name, dir)
				p.fire_cd = 0.25
				break
	p.basis = p.basis.slerp(Basis.looking_at(to.normalized()), minf(1.0, dt)).orthonormalized()


# ---------- helpers ----------

func _plane(id: int) -> Node:
	return players.get_node_or_null(str(id))


func _pilots(team: int, alive_only: bool) -> Array:
	return players.get_children().filter(func(p): return p.role == "pilot" and p.team == team and (p.alive or not alive_only))


func _lead_bomber() -> Node:
	var b := players.get_children().filter(func(p): return p.role == "bomber" and p.alive)
	return b[0] if b else null


func _team_counts() -> Array:
	var c := [0, 0]
	for id in gs.players:
		c[gs.players[id].team] += 1
	return c


func _my_team() -> int:
	var me = gs.players.get(multiplayer.get_unique_id())
	return me.team if me else 0


func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func hits_ground(p: Vector3) -> bool:
	if p.y > Terrain.max_h + obstacle_top and absf(p.x) < Terrain.FINE_EXTENT and absf(p.z) < Terrain.FINE_EXTENT:
		return false # above every hill and building
	var g := Terrain.span(p.x, p.z)
	if p.y < g.x + 1.0 and p.y > g.y or p.y < Worlds.cur.env.kill_y:
		return true
	return p.y < g.x + obstacle_top and hits_obstacle(p)


# Obstacles bucketed into 100 m cells so a point test only scans its own cell.
const CELL := 100.0
var obstacle_grid := {}
var obstacle_top := 0.0 # tallest obstacle above its ground; points higher than this skip the grid

func _add_obstacle(a: AABB) -> void:
	obstacles.append(a)
	var c := a.get_center()
	obstacle_top = maxf(obstacle_top, a.end.y - Terrain.height(c.x, c.z) + 20.0)
	for cx in range(floori(a.position.x / CELL), floori(a.end.x / CELL) + 1):
		for cz in range(floori(a.position.z / CELL), floori(a.end.z / CELL) + 1):
			obstacle_grid.get_or_add(Vector2i(cx, cz), []).append(a)


func hits_obstacle(p: Vector3) -> bool:
	for a in obstacle_grid.get(Vector2i(floori(p.x / CELL), floori(p.z / CELL)), []):
		if a.has_point(p):
			return true
	return false


var boom_mesh: SphereMesh
var boom_pool: Array[MeshInstance3D] = []


func boom(pos: Vector3, size := 1.0) -> void:
	if size < 0.6:
		Sfx.at(self, pos, Sfx.FLAK, 0.0, 2500.0) # flak bursts, sparks: a dull whump
	elif size >= 2.0:
		Sfx.at(self, pos, Sfx.BOOMS[0], 9.0, 4000.0, 0.7) # bombs: deeper and louder
	else:
		Sfx.at(self, pos, Sfx.BOOMS.pick_random(), 4.0, 3000.0)
	if Fx.far(self, pos):
		return
	if not boom_mesh: # one shared, lighter ball: the default sphere is 4k triangles and was rebuilt per bang
		boom_mesh = SphereMesh.new()
		boom_mesh.radial_segments = 24
		boom_mesh.rings = 12
	var m: MeshInstance3D = boom_pool.pop_back() if boom_pool else null # fireballs are reused
	if not m:
		m = MeshInstance3D.new()
		m.mesh = boom_mesh
		var fresh := StandardMaterial3D.new()
		fresh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fresh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = fresh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	var mat: StandardMaterial3D = m.material_override
	mat.albedo_color = Color(3.0, 1.6, 0.3)
	m.position = pos
	m.scale = Vector3.ONE
	m.show()
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * 22.0 * size, 0.7 * size)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(func():
		m.hide()
		boom_pool.append(m))


# ---------- input & UI ----------

func _input(event: InputEvent) -> void:
	if taunts and taunts.handle(event):
		get_viewport().set_input_as_handled() # the wheel has the mouse: the plane flies straight meanwhile


func can_taunt() -> bool:
	return gs.phase == "playing" and not menu_open() and _plane(multiplayer.get_unique_id()) != null


func send_taunt(i: int) -> void:
	var p := _plane(multiplayer.get_unique_id())
	if not p or Time.get_ticks_msec() < taunt_cd:
		return
	taunt_cd = Time.get_ticks_msec() + 2000
	taunts.say(p, Taunts.LIST[i]) # instantly on your own screen
	request_taunt.rpc_id(1, i)


# Host: a valid message number, at most one per 2 s, then everyone else sees it.
@rpc("any_peer", "call_local", "reliable")
func request_taunt(i: int) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p := _plane(id)
	if not p or i < 0 or i >= Taunts.LIST.size() or not _allow(id, "taunt", 0.5, 1.0):
		return
	for peer in multiplayer.get_peers():
		if peer != id:
			show_taunt.rpc_id(peer, str(p.name), i)
	if id != multiplayer.get_unique_id():
		show_taunt(str(p.name), i)


@rpc("authority", "reliable")
func show_taunt(plane_name: String, i: int) -> void:
	var p := players.get_node_or_null(plane_name)
	if p and p.alive and i >= 0 and i < Taunts.LIST.size() and Settings.values.get("taunts", true):
		taunts.say(p, Taunts.LIST[i])


# AI radio lines are skywritten over the speaker too (host-written text, not player input) (same range as taunts).
@rpc("authority", "call_local", "reliable")
func say_bubble(plane_name: String, text: String) -> void:
	var p := players.get_node_or_null(plane_name)
	if p and p.alive and Settings.values.get("taunts", true) and not TouchControls.phone(): # phones: the kill feed carries AI chatter (skywriting costs a frame)
		taunts.say(p, text.left(28))


func _unhandled_input(event: InputEvent) -> void:
	if preview.visible and _spin_input(event):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and (settings_root.visible or touch_root.visible or howto_root.visible or credits_root.visible):
		Settings.save()
		settings_root.hide()
		touch_root.hide()
		howto_root.hide()
		credits_root.hide()
		return
	if event.keycode == KEY_ESCAPE and shop_ui.visible:
		shop_ui.close()
		return
	if event.keycode == KEY_ESCAPE and mp_open and gs.phase == "menu":
		_close_mp()
		return
	if event.keycode == KEY_ESCAPE and mission_open and gs.phase == "menu":
		_close_mission()
		return
	if gs.phase != "playing":
		return
	if menu_open() and event.keycode != KEY_ESCAPE:
		return # menu keys (W/A/S/D, arrows, numbers) belong to the menu, not the plane
	if spectating and event.keycode == KEY_TAB:
		spec_t = 0.0
		return
	match event.keycode:
		KEY_ESCAPE:
			var paused := not pause_root.visible
			pause_root.visible = paused
			end_btn.visible = gs.leader == multiplayer.get_unique_id()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		KEY_1:
			request_ping.rpc_id(1, "Help!")
		KEY_2:
			request_ping.rpc_id(1, "On me")
		KEY_3:
			request_deploy.rpc_id(1, "rapid", gs.match_id)
		KEY_4:
			request_deploy.rpc_id(1, "sam", gs.match_id)
		KEY_5:
			request_deploy.rpc_id(1, "radar", gs.match_id)
		KEY_6:
			request_repair.rpc_id(1, gs.match_id)
		KEY_M:
			show_map = not show_map
		KEY_N:
			map_zoom = 2.5 if map_zoom == 1.0 else 1.0
		KEY_H:
			keys_t = 0.0 if keys_root.visible else 1e9
		KEY_C:
			Settings.values.cam = (Settings.values.get("cam", 1) + 1) % 3
			Settings.save()


# A menu is over the game: the plane ignores the keyboard (W/A/S/D and arrows drive the menu).
func menu_open() -> bool:
	return pause_root.visible or settings_root.visible or touch_root.visible or shop_ui.visible or howto_root.visible or credits_root.visible or (touch != null and touch.editing)


func _refresh_ui() -> void:
	var shopping := shop_ui != null and shop_ui.visible # the shop takes the left side on its own
	menu_root.visible = gs.phase == "menu" and not mp_open and not shopping and not mission_open
	if mission_root:
		mission_root.visible = gs.phase == "menu" and mission_open and not shopping
	mp_root.visible = gs.phase == "menu" and mp_open and not shopping
	status.visible = gs.phase == "menu"
	if TouchControls.phone(): # the note sits beside the Multiplayer strip, else above HANGAR SHOP
		var x: float = mp_root.custom_minimum_size.x + 20.0 if mp_open else menu_root.get_node("HangarShop").offset_left
		status.custom_minimum_size.x = minf(470.0, get_viewport().get_visible_rect().size.x - Menus.insets(status).z - x)
		status.offset_left = x
		status.offset_right = x + status.custom_minimum_size.x
	lobby_root.visible = gs.phase == "lobby" and not shopping
	if gs.phase == "playing": # lobby widgets are hidden mid-match: they refresh once it's back
		_refresh_preview()
		$EscortGoal.visible = gs.mode == 0 and gs.phase != "menu"
		return
	var leader: bool = gs.leader == multiplayer.get_unique_id()
	for sel: Menus.Selector in [mode_sel, world_sel, size_sel, skill_sel]:
		sel.set_locked(not leader)
	var solo := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if (mode_sel.items.size() < MODES.size()) != solo: # Team Dogfight needs a human on each team: not offered solo
		mode_sel.set_items(range(MODES.size()).filter(func(m): return m != 1 or not solo).map(func(m): return {title = MODES[m].to_upper(), sub = OBJECTIVES[m], mode = m}))
	mode_sel.set_index(mode_sel.items.map(func(it): return it.mode).find(gs.mode))
	world_sel.set_index(gs.get("world", 0))
	size_sel.set_index(gs.size)
	skill_sel.set_index(gs.skill)
	plane_sel.set_items(Planes.ORDER.map(func(k): return {title = Planes.variant(k).name.to_upper(), sub = Planes.variant(k).desc})) # this world's lineup
	plane_sel.set_index(Planes.ORDER.find(plane_choice))
	start_btn.visible = leader
	switch_btn.visible = gs.mode in TEAM_MODES
	battle_row.visible = gs.mode in AI_MODES
	leave_btn.text = "Close room" if multiplayer.is_server() and gs.players.size() > 1 else "Leave"
	if gs.room:
		room_label.text = "ROOM CODE:  %s" % gs.room
	elif multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		room_label.text = "Solo battle vs AI" if gs.mode in AI_MODES else "Solo practice"
	else:
		var lan := Array(IP.get_local_addresses()).filter(func(a): return a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."))
		room_label.text = "LAN game - friends join with: %s%s" % [", ".join(lan.slice(0, 2)) if lan else "your IP", ("\nInternet (router allowed): %s" % gs.public_ip) if gs.public_ip else ""]
	copy_btn.visible = gs.room != ""
	var lines := [gs.msg] if gs.msg else []
	var counts := _team_counts()
	for team in (2 if gs.mode in TEAM_MODES else 1):
		var fill := maxi(SIZES[gs.size] - counts[team], 0) if gs.mode in AI_MODES else 0
		lines.append("%s team%s" % [TEAM_NAMES[team], ("  + %d AI pilot%s" % [fill, "s" if fill != 1 else ""]) if fill else ""])
		for id in gs.players:
			if gs.players[id].team == team:
				var info: Dictionary = gs.players[id]
				var ping := "  host" if id == 1 else ("  %d ms" % info.ping if info.has("ping") else "")
				lines.append("   %s  [%s]%s%s" % [info.name, Planes.variant(info.get("plane", "cub")).name, "  (leader)" if id == gs.leader else "", ping])
	if not leader:
		lines.append("\nWaiting for the leader to start...")
	lobby_list.text = "\n".join(lines)
	var kick: Array = gs.players.keys().filter(func(id): return id != multiplayer.get_unique_id()) if multiplayer.is_server() else []
	if str(kick) != kick_box.get_meta("ids", "[]"):
		kick_box.set_meta("ids", str(kick))
		for c in kick_box.get_children():
			c.queue_free()
		for id in kick:
			var kb := Menus.menu_item(kick_box, "KICK %s" % gs.players[id].name, _kick.bind(id), self, 16)
			if lobby_pages: # phones: two to a row
				kb.custom_minimum_size.x = 248
				kb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Menus.thumbs(kick_box)
	if lobby_pages:
		lobby_pages.KICK[0].visible = not kick.is_empty()
		if kick.is_empty() and kick_box.visible:
			_lobby_tab("PILOTS")
	_refresh_preview()
	$EscortGoal.visible = gs.mode == 0 and gs.phase != "menu" # not hanging over the home-screen flyby
	if gs.phase == "ended":
		results_title.text = gs.msg
		if offer_match != gs.match_id:
			offer_match = gs.match_id
			_fill_offer()
		for c in results_grid.get_children():
			c.queue_free()
		for h in ["PILOT", "TEAM", "PLANE", "KILLS", "DEATHS", "REVIVES"]:
			_cell(h, Menus.AMBER)
		for id in gs.players:
			var p: Dictionary = gs.players[id]
			for v in [p.name, TEAM_NAMES[p.team], Planes.variant(p.get("plane", "cub")).name, p.kills, p.deaths, p.get("revives", 0)]:
				_cell(str(v), Color.WHITE)
		var ai_rows: Array = gs.ai_board.keys()
		ai_rows.sort_custom(func(a, b): return gs.ai_board[a].kills > gs.ai_board[b].kills)
		for n in ai_rows.slice(0, maxi(8 - gs.players.size(), 0) if TouchControls.phone() else 6): # phones: the table fits the screen
			var r: Dictionary = gs.ai_board[n]
			for v in ["%s (AI)" % n, TEAM_NAMES[r.team], r.style, r.kills, "", ""]:
				_cell(str(v), Color(0.75, 0.85, 1.0))


func _carrying_flag(n: String) -> bool:
	if gs.get("flags") == null or gs.mode != 4:
		return false
	return gs.flags.any(func(f): return f.state == "carried" and f.carrier == n)


# Hangar rows: every look, paid ones tagged with what they take ("try it" in solo games).
func _fill_looks() -> void:
	var solo := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	var tag := func(item: String) -> String:
		if shop.owns(item):
			return ""
		return "Locked: in the Hangar Shop" + ("  (try it free in Free Flight)" if solo else "")
	livery_sel.set_items(range(Planes.LIVERIES.size()).map(func(i): return {title = Planes.LIVERIES[i].name.to_upper(), sub = tag.call("livery:%d" % i)}))
	banner_sel.set_items(range(Planes.trail_names().size()).map(func(i): return {title = Planes.trail_names()[i].to_upper(), sub = tag.call("trail:%d" % i)}))
	killfx_sel.set_items(range(Planes.KILL_FX.size()).map(func(i): return {title = Planes.KILL_FX[i].to_upper(), sub = tag.call("killfx:%d" % i)}))
	livery_sel.set_index(Settings.values.livery)
	banner_sel.set_index(Settings.values.banner)
	killfx_sel.set_index(Settings.values.killfx)


# Under the scoreboard: paid looks other pilots flew this match (seeing them is the honest advert),
# and after a win at most one set offer you can wave away.
func _fill_offer() -> void:
	for c in offer_box.get_children():
		c.queue_free()
	var me := multiplayer.get_unique_id()
	for id in gs.players:
		var p: Dictionary = gs.players[id]
		var items := ["livery:%d" % p.get("livery", 0), "trail:%d" % p.get("banner", 0), "killfx:%d" % p.get("killfx", 0)].filter(func(it): return not Shop._free(it))
		if id == me or items.is_empty() or not shop.sells():
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "Spotted: %s flew %s" % [p.name, ", ".join(items.map(func(it): return Shop.PRODUCTS[shop.product_for(it)].title))]
		l.modulate = Color(1, 1, 1, 0.8)
		row.add_child(l)
		var it0: String = items[0]
		_button_in(row, "SEE IT", func(): shop_ui.open(shop.product_for(it0)))
		offer_box.add_child(row)
		Menus.thumbs(row)
		break
	var won: bool = gs.msg.begins_with(TEAM_NAMES[_my_team()]) or gs.msg.ends_with("Mission complete!")
	if not won:
		return
	shop.maybe_review()
	var p := shop.offer_after_win()
	if p == "":
		return
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Win in style: %s (%s)" % [Shop.PRODUCTS[p].title, shop.price(p)]
	l.modulate = Menus.AMBER
	row.add_child(l)
	_button_in(row, "PREVIEW", func(): shop_ui.open(p))
	_button_in(row, "NOT NOW", func():
		shop.dismiss(p)
		row.queue_free())
	offer_box.add_child(row)
	Menus.thumbs(row)


func _button_in(row: Container, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	row.add_child(b)


func _cell(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.custom_minimum_size.x = 110
	results_grid.add_child(l)


# Turntable: drag the open space around the plane to turn it any way (top and bottom too), double-tap
# levels it; after a drag it holds still for a moment, then slowly turns on its own again.
var spin := Vector2.ZERO # yaw, pitch
var spin_drag := false
var spin_hold := 0.0

func _spin_input(e: InputEvent) -> bool:
	var touch := TouchControls.on() # a finger also sends an emulated mouse: only one of the two counts
	if (e is InputEventScreenTouch and touch) or (e is InputEventMouseButton and not touch and e.button_index == MOUSE_BUTTON_LEFT):
		spin_drag = e.pressed
		if e.pressed and (e.double_tap if e is InputEventScreenTouch else e.double_click):
			spin = Vector2.ZERO
		return true
	if spin_drag and ((e is InputEventScreenDrag and touch) or (e is InputEventMouseMotion and not touch and e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		spin += e.relative * 0.01
		spin.y = clampf(spin.y, -1.5, 1.5)
		spin_hold = 3.0
		return true
	return false


func _turntable(dt: float) -> void:
	spin_hold -= dt
	if spin_hold <= 0.0 and not spin_drag:
		spin.x += 0.6 * dt
		spin.y = lerpf(spin.y, 0.0, 1.0 - exp(-1.5 * dt))
	preview.basis = Basis(lobby_cam.global_basis.x, spin.y) * Basis(Vector3.UP, spin.x)
	if TouchControls.phone(): # in the middle of the open space beside the panel, whatever the screen's shape
		var panel: Control = (shop_ui if shop_ui.visible else lobby_root).get_child(0)
		var vis := get_viewport().get_visible_rect().size
		var x := (panel.get_global_rect().end.x + vis.x - Menus.insets(panel).z) / 2.0
		preview.global_position = lobby_cam.project_position(Vector2(x, vis.y * 0.45), 20.0)


# Spinning model of the chosen plane next to the lobby panel, plus its stat bars.
func _refresh_preview() -> void:
	var in_shop := shop_ui != null and shop_ui.visible
	preview.visible = gs.phase == "lobby" or in_shop
	var look: Array = shop_ui.preview_look() if in_shop else [my_look()[0], 0, my_look()[2]] # lobby turntable: no trail
	var key := "%s/%d/%d/%s" % [plane_choice, _my_team(), Worlds.shown, look]
	if not preview.visible or key == preview_key:
		return
	preview_key = key
	for c in preview.get_children():
		c.queue_free()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var parts := Planes.build(plane_choice, preview, toon(Aircraft.TEAM_COLORS[_my_team()]), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), toon(Color(0.2, 0.2, 0.22)), glow, look[2])
	var pt: Dictionary = Planes.TYPES[plane_choice]
	Planes.dress(plane_choice, preview, parts, pt.rockets, pt.bombs, look[0], look[1], toon(Color(0.2, 0.2, 0.22)), toon)
	var t: Dictionary = Planes.TYPES[plane_choice]
	var v := Planes.variant(plane_choice)
	stats_label.text = "%s\n%s" % [v.name, v.desc]
	var vals := [inverse_lerp(85.0, 140.0, t.max), inverse_lerp(3.0, 6.5, t.turn.x + t.turn.z), inverse_lerp(50.0, 200.0, t.hp), inverse_lerp(0.0, 6.0, t.rockets)]
	for i in 4:
		stat_bars[i].value = vals[i] * 100.0


func _refresh_hud() -> void:
	var playing: bool = gs.phase in ["playing", "ended"]
	top.visible = playing
	feed.visible = playing
	results_root.visible = gs.phase == "ended"
	if not playing:
		return
	var rtt := ""
	var my_ping: int = gs.players.get(multiplayer.get_unique_id(), {}).get("ping", -1)
	if not multiplayer.is_server() and my_ping >= 0:
		rtt = "   Ping %dms%s" % [my_ping, " (laggy connection)" if my_ping > 200 else ""]
	var bank := ""
	if gs.mode != 2 and gs.get("bank") != null:
		bank = "      Supplies  Blue %d  Red %d" % [gs.bank[0], gs.bank[1]]
	if gs.mode == 4 and gs.get("flags") != null:
		var t4 := "%d:%02d" % [int(gs.time) / 60, int(gs.time) % 60]
		var st := func(team: int) -> String:
			var f: Dictionary = gs.flags[team]
			return "flag " + ({home = "safe", dropped = "DROPPED", carried = "TAKEN"}[f.state])
		top.text = "BLUE %d  (%s)   |   %s   |   (%s)  %d RED%s%s" % [gs.score[0], st.call(0), t4, st.call(1), gs.score[1], bank, rtt]
	elif gs.mode == 5 and gs.get("hq") != null:
		var t5 := "%d:%02d" % [int(gs.time) / 60, int(gs.time) % 60]
		top.text = "BLUE HQ %d%%   |   %s   |   RED HQ %d%%%s%s" % [100 * gs.hq[0] / Objectives.HQ_HP, t5, 100 * gs.hq[1] / Objectives.HQ_HP, bank, rtt]
	elif gs.mode == 3:
		var t := "%d:%02d" % [int(gs.time) / 60, int(gs.time) % 60]
		top.text = "BLUE  %d lives, %d flying   |   %s   |   RED  %d lives, %d flying%s" % [gs.lives[0], _flying(0), t, gs.lives[1], _flying(1), rtt]
	elif gs.mode == 2:
		top.text = "FREE FLIGHT   Balloons popped: %d   (%s for menu)%s" % [gs.popped, "II" if TouchControls.on() else "Esc", rtt]
	elif gs.mode == 0:
		var flying := players.get_children().filter(func(p): return p.role == "bomber" and p.alive).size()
		top.text = "Wave %d/%d  (next %ds)   Bombers: %d flying, %d delivered, %d lost   Lives %d%s" % [gs.wave, WAVES, maxf(gs.next_wave, 0), flying, gs.arrived, gs.lost, gs.lives[0], rtt]
	else:
		var t := "SUDDEN DEATH" if gs.sudden else "%d:%02d" % [int(gs.time) / 60, int(gs.time) % 60]
		var c := ["", ""]
		for team in 2:
			if gs.clutch[team] >= 0.0:
				c[team] = " (CLUTCH %ds)" % gs.clutch[team]
		top.text = "Blue %d lives%s   |   %s   |   Red %d lives%s%s" % [gs.lives[0], c[0], t, gs.lives[1], c[1], rtt]
	feed.text = "\n".join(gs.feed.slice(-3 if get_viewport().get_visible_rect().size.aspect() > 1.8 else -2) if TouchControls.phone() else gs.feed) # phone: clear of the minimap
	if touch: # and of the notch / Dynamic Island
		feed.position.x = overlay.size.x - feed.size.x - maxf(touch._pad(), 20.0)


func _scoreboard() -> String:
	var rows := []
	for id in gs.players:
		var p: Dictionary = gs.players[id]
		rows.append("%s (%s)   %d kills   %d deaths   %d revives" % [p.name, TEAM_NAMES[p.team], p.kills, p.deaths, p.get("revives", 0)])
	return "\n".join(rows)


func _draw_overlay() -> void:
	if not Sfx.enabled:
		return # headless: nothing to draw on
	var cam := get_viewport().get_camera_3d()
	if gs.phase != "playing" or not cam or cam == lobby_cam:
		return
	var team := _my_team()
	if is_instance_valid(prize) and prize.alive:
		_marker(cam, prize.position + Vector3.UP * 22.0, Color(1.0, 0.8, 0.2), "PRIZE BALLOON")
	for b in gs.beacons:
		if b[1] == team:
			_marker(cam, b[0], Color.ORANGE, "REVIVE %s  %ds" % [b[3], b[2]])
	for p in pings:
		_marker(cam, p[0], Color.CYAN, p[1])
	if battlefield:
		for c in battlefield.crates.values():
			_marker(cam, c.pos, Color(1.0, 0.85, 0.2), "SUPPLY")
		if objectives and gs.get("flags") != null and gs.mode == 4:
			for ft in 2:
				var f: Dictionary = gs.flags[ft]
				if f.state != "carried":
					_marker(cam, f.pos + Vector3.UP * 25.0, Battlefield.Aircraft_TEAM[ft], "%s FLAG%s" % [TEAM_NAMES[ft].to_upper(), " (dropped)" if f.state == "dropped" else ""])
		if objectives and gs.mode == 5:
			for ht in 2:
				var h: Node3D = objectives.hqs[ht]
				_marker(cam, h.global_position + Vector3.UP * 45.0, Battlefield.Aircraft_TEAM[ht], "%s %d%%" % [h.pilot.to_upper(), 100 * h.hp / h.max_hp])
		var me_p := _plane(multiplayer.get_unique_id())
		if objectives and me_p and (str(me_p.name) in gs.get("cargo", []) or _carrying_flag(str(me_p.name))):
			_marker(cam, objectives.home(me_p.team) + Vector3.UP * 30.0, Color(0.4, 1.0, 0.5), "HOME - deliver here")
		for g in battlefield.guns:
			if g.alive and g.visible and g.team != team and cam.global_position.distance_to(g.global_position) < 1300.0:
				_marker(cam, g.global_position + Vector3.UP * 8.0, Color(1.0, 0.3, 0.25), Battlefield.Turret.SPEC[g.kind].tag)
	var me := _plane(multiplayer.get_unique_id())
	if not me or not me.alive:
		return
	# Lead markers: where to shoot so bullets meet the target.
	for t in get_tree().get_nodes_in_group("targets"):
		if t.team != me.team and t.alive:
			var d: float = me.position.distance_to(t.position)
			var lead: Vector3 = t.position + (t.vel_estimate() - me.velocity) * (d / Aircraft.BULLET_SPEED)
			if d < 900.0 and not cam.is_position_behind(lead):
				overlay.draw_arc(cam.unproject_position(lead), 7, 0, TAU, 16, Color(1, 0.3, 0.3), 2)


# North-up map, bottom-right: baked terrain (Terrain.map_rows) under live icons. M hides it,
# N zooms in around you. Enemies only show when a friendly plane or defense can see them.
const MAP_WORLD := 5000.0 # metres across the full map (terrain detail is +-2500)
const SPOT_RANGE := 1300.0
var show_map := true
var map_zoom := 1.0
var map_tex: ImageTexture
var map_img: Image # being baked
var map_row := 0
var map_obs: Array


# Minimap bake, a few rows per frame (~0.4 s total) so picking a world never hitches.
func _bake_map() -> void:
	var t := Time.get_ticks_usec()
	while map_row < Terrain.MAP_PX and Time.get_ticks_usec() - t < 6000:
		var last := mini(map_row + 7, Terrain.MAP_PX - 1)
		Terrain.map_rows(map_img, map_row, last)
		map_row = last + 1
	if map_row >= Terrain.MAP_PX:
		Terrain.map_stamp(map_img, map_obs)
		map_tex = ImageTexture.create_from_image(map_img)
		map_img = null


var map_t := 0.0
var spotted := {} # enemies a friendly plane or defense can see, refreshed at 5 Hz
var spot_ms := 0


func _draw_map_layer() -> void:
	if not Sfx.enabled:
		return # headless: nothing to draw on
	var cam := get_viewport().get_camera_3d()
	if not show_map or gs.phase != "playing" or not cam or cam == lobby_cam:
		return
	var team := _my_team()
	if Time.get_ticks_msec() >= spot_ms:
		spot_ms = Time.get_ticks_msec() + 200
		spotted.clear()
		for e in players.get_children():
			if e.team != team and _spotted(e, team):
				spotted[e] = true
		for g in battlefield.guns if battlefield else []:
			if g.team != team and _spotted(g, team):
				spotted[g] = true
	_draw_minimap(team)


func _spotted(e: Node, team: int) -> bool:
	if e.role == "striker" or _carrying_flag(str(e.name)):
		return true # raids are announced, flag carriers glow
	for f in players.get_children():
		if f.alive and f.team == team and f.position.distance_to(e.position) < SPOT_RANGE:
			return true
	for g in battlefield.guns if battlefield else []:
		if g.alive and g.visible and g.team == team and g.position.distance_to(e.position) < (2200.0 if g.kind == "radar" else 1000.0):
			return true
	return false


func _draw_minimap(team: int) -> void:
	var size := clampf(overlay.size.y * 0.27, 170.0, 300.0)
	var r := Rect2(overlay.size - Vector2(size + 16, size + 36), Vector2(size, size))
	if TouchControls.on(): # the thumb buttons own the bottom-right
		size = overlay.size.y * 0.22
		r = Rect2(Vector2(overlay.size.x - size - maxf(touch._pad(), 16.0), 150), Vector2(size, size)) # clear of the notch / Dynamic Island
	var me := _plane(multiplayer.get_unique_id())
	var span := MAP_WORLD / map_zoom
	var centre := Vector2.ZERO
	if map_zoom > 1.0 and me:
		centre = Vector2(me.position.x, me.position.z).clamp(Vector2.ONE * (span - MAP_WORLD) / 2.0, Vector2.ONE * (MAP_WORLD - span) / 2.0)
	minimap.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.6))
	if map_tex:
		var px := map_tex.get_width() / MAP_WORLD
		var src := Rect2((centre - Vector2.ONE * span / 2.0 + Vector2.ONE * MAP_WORLD / 2.0) * px, Vector2.ONE * span * px)
		minimap.draw_texture_rect_region(map_tex, r, src, Color(1, 1, 1, 0.92))
	else:
		minimap.draw_rect(r, Color(0.04, 0.06, 0.1, 0.82))
	minimap.draw_rect(r, Color(1, 1, 1, 0.6), false, 1.5)
	var font := ThemeDB.fallback_font
	minimap.draw_string(font, r.position + Vector2(size / 2.0 - 5, 15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	minimap.draw_rect(Rect2(r.position + Vector2(-2, size + 2), Vector2(size + 4, 22)), Color(0, 0, 0, 0.6))
	minimap.draw_string(font, r.position + Vector2(4, size + 18), Worlds.NAMES[Worlds.index] if TouchControls.on() else "%s    M hide   N zoom" % Worlds.NAMES[Worlds.index], HORIZONTAL_ALIGNMENT_LEFT, size - 8, 13, Color(1, 1, 1, 0.9)) # phones: the MAP button does it
	var ppm := size / span # pixels per metre
	var inner := r.grow(-4.0)
	var at := func(p: Vector3) -> Vector2:
		return r.get_center() + (Vector2(p.x, p.z) - centre) * ppm
	var dot := func(p: Vector3, c: Color, sz: float, pin := false) -> void:
		var q: Vector2 = at.call(p)
		if not inner.has_point(q):
			if not pin:
				return
			q = q.clamp(inner.position, inner.end) # objectives stay on the rim, pointing the way
		minimap.draw_rect(Rect2(q - Vector2.ONE * (sz / 2.0 + 1.0), Vector2.ONE * (sz + 2.0)), Color(0, 0, 0, 0.85))
		minimap.draw_rect(Rect2(q - Vector2.ONE * sz / 2.0, Vector2.ONE * sz), c)
	for c in battlefield.crates.values() if battlefield else []:
		dot.call(c.pos, Color(1.0, 0.85, 0.2), 6.0)
	for g in battlefield.guns if battlefield else []:
		if g.alive and g.visible and (g.team == team or spotted.has(g)):
			dot.call(g.global_position, Battlefield.Aircraft_TEAM[g.team].darkened(0.35), 5.0)
	for b in gs.beacons:
		if b[1] == team:
			dot.call(b[0], Color.ORANGE, 7.0, true)
	for p in pings:
		dot.call(p[0], Color.CYAN, 7.0, true)
	if objectives and gs.mode == 4 and gs.get("flags") != null:
		for ft in 2:
			if gs.flags[ft].state == "carried":
				continue
			var fp: Vector2 = (at.call(gs.flags[ft].pos) as Vector2).clamp(inner.position + Vector2(0, 12), inner.end - Vector2(9, 0))
			minimap.draw_line(fp, fp + Vector2(0, -13), Color.WHITE, 2.0)
			minimap.draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -13), fp + Vector2(10, -10), fp + Vector2(0, -6)]), Battlefield.Aircraft_TEAM[ft])
	if objectives and gs.mode == 5:
		for h in objectives.hqs:
			if h.alive:
				dot.call(h.position, Battlefield.Aircraft_TEAM[h.team], 12.0, true)
	if objectives and me and (str(me.name) in gs.get("cargo", []) or _carrying_flag(str(me.name))):
		var hq: Vector2 = (at.call(objectives.home(me.team)) as Vector2).clamp(inner.position, inner.end)
		minimap.draw_arc(hq, 9.0 + 3.0 * sin(Time.get_ticks_msec() / 150.0), 0, TAU, 20, Color(0.4, 1.0, 0.5), 2.5)
	var spectator: bool = spectating or not gs.players.has(multiplayer.get_unique_id())
	for p in players.get_children():
		if not p.alive or p == me:
			continue
		if p.team != team and not p.role in ["balloon", "prize"] and not spectator and not spotted.has(p):
			continue
		var c: Color = Color(0.85, 0.85, 0.9) if p.role == "balloon" else (Color(1.0, 0.8, 0.2) if p.role == "prize" else Battlefield.Aircraft_TEAM[p.team])
		dot.call(p.position, c, 9.0 if p.role in ["bomber", "striker"] else (4.0 if p.role == "balloon" else 6.0))
		if _carrying_flag(str(p.name)):
			minimap.draw_arc(at.call(p.position), 9.0, 0, TAU, 16, Battlefield.Aircraft_TEAM[1 - p.team], 2.0)
	if me and me.alive:
		var fwd := Vector2(-me.basis.z.x, -me.basis.z.z).normalized()
		var m: Vector2 = at.call(me.position)
		var side := fwd.orthogonal()
		var arrow := PackedVector2Array([m + fwd * 11.0, m - fwd * 7.0 + side * 7.0, m - fwd * 3.0, m - fwd * 7.0 - side * 7.0])
		minimap.draw_colored_polygon(arrow, Color.WHITE)
		arrow.append(arrow[0])
		minimap.draw_polyline(arrow, Color.BLACK, 1.5)


func _marker(cam: Camera3D, pos: Vector3, color: Color, text: String) -> void:
	if cam.is_position_behind(pos):
		return
	var s := cam.unproject_position(pos)
	if not s.is_finite() or not overlay.get_rect().grow(400.0).has_point(s):
		return
	overlay.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -9), s + Vector2(9, 0), s + Vector2(0, 9), s + Vector2(-9, 0)]), color)
	var dist := cam.global_position.distance_to(pos)
	overlay.draw_string(ThemeDB.fallback_font, s + Vector2(14, 5), "%s  %dm" % [text, dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = ui_theme
	layer.add_child(ui)
	var fps_layer := CanvasLayer.new() # Settings "Show FPS": bottom centre, over menus and touch buttons
	fps_layer.layer = 10
	add_child(fps_layer)
	fps_label.theme = ui_theme
	fps_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fps_label.offset_bottom = -4.0 - Menus.insets(ui).w
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_constant_override("outline_size", 4)
	fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_layer.add_child(fps_label)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	ui.add_child(overlay)
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_map_layer)
	overlay.add_child(minimap)
	if TouchControls.on():
		var touch_layer := CanvasLayer.new()
		touch_layer.layer = 2
		add_child(touch_layer)
		touch = TouchControls.new(self)
		touch_layer.add_child(touch)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 12
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_font_size_override("font_size", 20)
	ui.add_child(top)
	feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	feed.position += Vector2(-20, 50)
	feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # long lines wrap instead of running into the stats line on narrow screens
	feed.custom_minimum_size.x = 330
	ui.add_child(feed)
	_build_intro(ui)
	taunts = Taunts.new(self)
	ui.add_child(taunts)

	var box := VBoxContainer.new()
	if TouchControls.phone():
		_build_home(ui)
	else:
		Menus.big_title(box, "TOY PLANE", 60)
		Menus.big_title(box, "ARCADE", 60).add_theme_color_override("font_color", Menus.AMBER)
		var gap := Control.new()
		gap.custom_minimum_size.y = 16
		box.add_child(gap)
		Menus.menu_item(box, "QUICK BATTLE", quick_battle, self)
		Menus.menu_item(box, "BATTLE VS AI", solo_battle, self)
		Menus.menu_item(box, "FREE FLIGHT", free_flight, self)
		Menus.menu_item(box, "MULTIPLAYER", _open_mp, self)
		Menus.menu_item(box, "HANGAR SHOP", func(): shop_ui.open(), self)
		Menus.menu_item(box, "SETTINGS", func(): settings_root.show(), self)
		Menus.menu_item(box, "HOW TO PLAY", func(): howto_root.show(), self)
		Menus.menu_item(box, "CREDITS", func(): credits_root.show(), self)
		Menus.menu_item(box, "QUIT", _quit, self) # not on phones: iOS apps never quit themselves
		menu_root = Menus.side_panel(ui, box)

	box = VBoxContainer.new()
	Menus.big_title(box, "MULTIPLAYER", 44)
	var hint := Label.new()
	hint.text = "Play with friends anywhere: host a room and send them the code."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)
	var cl := Label.new()
	cl.text = "CALLSIGN"
	cl.modulate = Color(1, 1, 1, 0.55)
	box.add_child(cl)
	name_edit.text = Settings.values.name if Settings.values.name else "Pilot%d" % randi_range(10, 99)
	name_edit.max_length = 16
	name_edit.placeholder_text = "Your name"
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_changed.connect(func(t):
		Settings.values.name = t.strip_edges()
		status.text = "" if clean_name(t) else "That callsign isn't allowed: others will see you as Pilot plus a number."
		Settings.save())
	box.add_child(name_edit)
	Menus.menu_item(box, "HOST ONLINE", host_online, self)
	Menus.menu_item(box, "HOST ON LAN", host, self)
	var jl := Label.new()
	jl.text = "JOIN A FRIEND - room code or LAN address"
	jl.modulate = Color(1, 1, 1, 0.55)
	box.add_child(jl)
	var join_row := HBoxContainer.new()
	address.placeholder_text = "e.g. KNHXC"
	address.add_theme_font_size_override("font_size", 22)
	address.text_submitted.connect(func(_t): join()) # Enter joins
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(address)
	Menus.menu_item(join_row, "JOIN", join, self, 26)
	box.add_child(join_row)
	Menus.menu_item(box, "BACK", _close_mp, self)
	if TouchControls.phone(): # the iOS keyboard covers the lower half: both text fields sit high, the hint goes last
		var crow := HBoxContainer.new()
		box.add_child(crow)
		cl.reparent(crow)
		name_edit.reparent(crow)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.move_child(jl, 1)
		box.move_child(join_row, 2)
		box.move_child(crow, 3)
		box.move_child(hint, -1)
	mp_root = Menus.side_panel(ui, box)
	mp_root.hide()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status.custom_minimum_size.x = 470
	status.position = Vector2(48, -110)
	status.add_theme_color_override("font_color", Menus.AMBER)
	if TouchControls.phone(): # grows upward from just above HANGAR SHOP
		var hs: Control = menu_root.get_node("HangarShop")
		status.grow_vertical = Control.GROW_DIRECTION_BEGIN
		status.offset_left = hs.offset_left
		status.offset_bottom = hs.offset_top - 10.0
		status.offset_top = status.offset_bottom - 26.0
	ui.add_child(status)

	box = VBoxContainer.new()
	Menus.big_title(box, "MISSION SETUP", 30)
	room_label.add_theme_color_override("font_color", Menus.AMBER)
	box.add_child(room_label)
	net_label.modulate = Menus.AMBER
	net_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(net_label)
	var worlds: Array = []
	for i in Worlds.LIST.size():
		worlds.append({title = Worlds.NAMES[i].to_upper(), sub = Worlds.TAGLINES[i], pic = load("res://assets/ui/worlds/%s.png" % Worlds.LIST[i])})
	world_sel = Menus.Selector.new("WORLD", worlds, Vector2(384, 96 if TouchControls.on() else 164)) # phones: LAUNCH stays on screen
	world_sel.changed.connect(func(i): request_world.rpc_id(1, i))
	box.add_child(world_sel)
	var modes: Array = []
	for i in MODES.size():
		modes.append({title = MODES[i].to_upper(), sub = OBJECTIVES[i], mode = i})
	mode_sel = Menus.Selector.new("MODE", modes)
	mode_sel.changed.connect(func(i): request_mode.rpc_id(1, mode_sel.items[i].mode))
	box.add_child(mode_sel)
	var sizes: Array = SIZES.map(func(sz): return {title = "%d  VS  %d" % [sz, sz]})
	size_sel = Menus.Selector.new("SQUADRON SIZE", sizes)
	size_sel.changed.connect(func(i): request_battle.rpc_id(1, i, gs.skill))
	battle_row.add_child(size_sel)
	skill_sel = Menus.Selector.new("ENEMY PILOTS", SKILLS)
	skill_sel.changed.connect(func(i): request_battle.rpc_id(1, gs.size, i))
	battle_row.add_child(skill_sel)
	battle_row.add_theme_constant_override("separation", 10)
	box.add_child(battle_row)
	plane_sel = Menus.Selector.new("YOUR PLANE", Planes.ORDER.map(func(k): return {title = Planes.variant(k).name.to_upper(), sub = Planes.variant(k).desc}))
	plane_sel.changed.connect(func(i):
		plane_choice = Planes.ORDER[i]
		Settings.values.last_plane = plane_choice # remembered for next time
		Settings.save()
		request_plane.rpc_id(1, plane_choice)
		_refresh_preview())
	start_btn = Menus.menu_item(box, "LAUNCH", func(): request_start.rpc_id(1), self, 36)
	start_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_btn.add_theme_stylebox_override("normal", Menus._box(Color(Menus.AMBER, 0.22), Menus.AMBER, 2, 8))
	lobby_root = Control.new() # full-screen layer: setup strip left, roster top-right, plane stats bottom-right
	lobby_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lobby_root)
	box.remove_child(start_btn)
	var rbox := VBoxContainer.new()
	var sq := Label.new()
	sq.text = "SQUADRONS"
	sq.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	sq.add_theme_font_size_override("font_size", 22)
	rbox.add_child(sq)
	rbox.add_child(lobby_list)
	rbox.add_child(kick_box)
	copy_btn = Menus.menu_item(rbox, "COPY ROOM CODE", func(): DisplayServer.clipboard_set(gs.room), self, 18)
	switch_btn = Menus.menu_item(rbox, "SWITCH TEAM", func(): request_switch_team.rpc_id(1), self, 18)
	Menus.menu_item(rbox, "HOW TO PLAY", func(): howto_root.show(), self, 18)
	leave_btn = Menus.menu_item(rbox, "LEAVE", _leave, self, 18)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 6)
	var hangar := Label.new()
	hangar.text = "HANGAR"
	hangar.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	hangar.add_theme_font_size_override("font_size", 22)
	sbox.add_child(hangar)
	plane_sel.custom_minimum_size.x = 340
	sbox.add_child(plane_sel)
	sticker_sel = Menus.Selector.new("STICKER  (just for looks)", Array(Planes.STICKERS).map(func(n): return {title = n.to_upper()}))
	banner_sel = Menus.Selector.new("SMOKE TRAIL  (just for looks)", [{title = ""}])
	livery_sel = Menus.Selector.new("PAINT JOB  (just for looks)", [{title = ""}])
	killfx_sel = Menus.Selector.new("KILL EFFECT  (just for looks)", [{title = ""}])
	for sel: Menus.Selector in [sticker_sel, livery_sel, banner_sel, killfx_sel]:
		sel.changed.connect(func(_i):
			Settings.values.sticker = sticker_sel.index
			Settings.values.banner = banner_sel.index
			Settings.values.livery = livery_sel.index
			Settings.values.killfx = killfx_sel.index
			Settings.save()
			_fill_looks()
			send_look())
		sbox.add_child(sel)
	_fill_looks()
	shop.changed.connect(_fill_looks)
	Menus.menu_item(sbox, "HANGAR SHOP", func(): shop_ui.open(), self, 18)
	sbox.add_child(stats_label)
	stats_label.hide() # the plane row already names and describes it
	for s in ["Speed", "Agility", "Armor", "Rockets"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = s
		l.custom_minimum_size.x = 110
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		stat_bars.append(bar)
		sbox.add_child(row)
	# One right-hand column (squadrons above the hangar), mirroring the setup column: they can't overlap.
	var right := VBoxContainer.new()
	right.add_child(rbox)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	right.add_child(spacer)
	right.add_child(sbox)
	if TouchControls.phone():
		_lobby_tabs(box, rbox, sbox)
		right.free()
	else:
		Menus.side_panel(lobby_root, box, 520, false, start_btn).get_theme_stylebox("panel").content_margin_top = 30
		box.add_theme_constant_override("separation", 7)
		Menus.side_panel(lobby_root, right, 420, true).get_theme_stylebox("panel").content_margin_top = 30

	box = VBoxContainer.new()
	Menus.big_title(box, "PAUSED", 48)
	var note := Label.new()
	note.text = "The battle goes on while you're in here."
	note.modulate = Color(1, 1, 1, 0.6)
	box.add_child(note)
	Menus.menu_item(box, "RESUME", func():
		pause_root.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED, self)
	Menus.menu_item(box, "SETTINGS", func(): settings_root.show(), self)
	Menus.menu_item(box, "HOW TO PLAY", func(): howto_root.show(), self)
	end_btn = Menus.menu_item(box, "END MATCH", func():
		pause_root.hide()
		request_end.rpc_id(1), self)
	Menus.menu_item(box, "LEAVE GAME", _leave, self)
	pause_root = Menus.side_panel(ui, box, 480)

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.add_theme_font_size_override("font_size", 32)
	results_title.modulate = Menus.AMBER
	box.add_child(results_title)
	results_grid.columns = 6
	box.add_child(results_grid)
	offer_box.add_theme_constant_override("separation", 4)
	box.add_child(offer_box)
	var back := Label.new()
	back.text = "Back in a few seconds..." if TouchControls.phone() else "Back to the lobby in a few seconds..."
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(back)
	results_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "SETTINGS")
	var to_touch := Callable()
	if TouchControls.on():
		to_touch = func(): settings_root.hide(); touch_root.show()
	box.add_child(Menus.settings_panel(get_tree(), func(): settings_root.hide(), to_touch))
	settings_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "TOUCH CONTROLS")
	var v := Settings.values
	var grid := Menus.columns(box)
	Menus._check(grid, "Tilt to steer (hold the phone how you like, it's level)", v.tilt, func(on): v.tilt = on)
	Menus._check(grid, "Auto-fire when the lead ring is in your sights", v.autofire, func(on): v.autofire = on)
	Menus._check(grid, "Vibration", v.vibrate, func(on): v.vibrate = on)
	Menus._check(grid, "Left-handed (mirror the layout)", v.touch_lefty, func(on): v.touch_lefty = on)
	Menus._check(grid, "Fixed stick (it stays put instead of following your thumb)", v.touch_fixed, func(on): v.touch_fixed = on)
	Menus._slider(box, "Button opacity", 0.25, 1.0, v.touch_opacity, func(x): v.touch_opacity = x)
	_button(grid, "Customize layout", func():
		touch_root.hide()
		touch.edit(touch_root.show))
	_button(grid, "Done", func():
		Settings.save()
		touch_root.hide()
		settings_root.show())
	touch_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "HOW TO PLAY")
	if TouchControls.phone(): # a topic per page
		var pg := Menus.Pager.new(PAGE_TEXT, self)
		pg.set_pages(Array(Menus.howto_text().split("\n\n")))
		box.add_child(pg)
		Menus.tile(pg.row, "GOT IT", func(): howto_root.hide(), self)
	else:
		var how := RichTextLabel.new()
		how.bbcode_enabled = true
		how.custom_minimum_size = Vector2(760, 420 if TouchControls.on() else 620) # scrolls, so "Got it" stays on screen
		how.text = Menus.howto_text()
		box.add_child(how)
		_button(box, "Got it", func(): howto_root.hide())
	howto_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "CREDITS")
	if TouchControls.phone():
		_phone_credits(box)
	else:
		var cr := RichTextLabel.new()
		cr.bbcode_enabled = true
		cr.custom_minimum_size = Vector2(760, 420)
		cr.text = Menus.credits_text()
		box.add_child(cr)
		var lic := Button.new()
		lic.text = "Licenses"
		lic.pressed.connect(func(): # the credits box doubles as the license viewer
			cr.bbcode_enabled = not cr.bbcode_enabled
			cr.text = Menus.credits_text() if cr.bbcode_enabled else FileAccess.get_file_as_string("res://THIRD_PARTY_LICENSES.txt")
			lic.text = "Licenses" if cr.bbcode_enabled else "Back to credits")
		box.add_child(lic)
		_button(box, "Close", func(): credits_root.hide())
	credits_root = _panel(ui, box)

	shop_ui = ShopUI.new(self, shop)
	ui.add_child(shop_ui)
	for r in [pause_root, results_root, settings_root, touch_root, howto_root, credits_root, lobby_root]:
		r.hide()
	for r in [settings_root, touch_root, howto_root, credits_root]:
		r.mouse_filter = Control.MOUSE_FILTER_STOP # the menu underneath can't be tapped through these


# Phone credits, doubling as the license viewer: fixed lines per page, so every page fits.
const PAGE_TEXT := Vector2(860, 400)

func _phone_credits(box: VBoxContainer) -> void:
	var pg := Menus.Pager.new(PAGE_TEXT, self)
	for f in ["normal_font_size", "bold_font_size"]:
		pg.label.add_theme_font_size_override(f, 16)
	pg.set_pages([Menus.credits_text()])
	box.add_child(pg)
	var lic := Menus.tile(pg.row, "LICENSES", func(): pass, self)
	lic.pressed.connect(func():
		var on := lic.text == "LICENSES"
		lic.text = "CREDITS" if on else "LICENSES"
		if not on:
			pg.set_pages([Menus.credits_text()])
			return
		var font := pg.label.get_theme_font("normal_font")
		var fs := pg.label.get_theme_font_size("normal_font_size")
		var lines := int(PAGE_TEXT.y / (font.get_height(fs) + pg.label.get_theme_constant("line_separation")))
		pg.set_pages(Menus.text_pages(FileAccess.get_file_as_string("res://THIRD_PARTY_LICENSES.txt"), font, fs, PAGE_TEXT.x - 16.0, lines), false))
	Menus.tile(pg.row, "CLOSE", func(): credits_root.hide(), self)


# Phone home: title and small buttons up top, the big PLAY under the right thumb with the mission it
# plays just above it (tap to change), hangar bottom-left. Nothing scrolls; the live world shows through.
func _build_home(ui: Control) -> void:
	var inset := Menus.insets(ui)
	var l := maxf(inset.x, 20.0)
	var r := maxf(inset.z, 20.0)
	var b := maxf(inset.w + 8.0, 16.0)
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu_root)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = l
	bar.offset_right = -r
	bar.offset_top = maxf(inset.y, 12.0)
	bar.add_theme_constant_override("separation", 10)
	menu_root.add_child(bar)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Menus.big_title(title, "TOY PLANE", 34).add_theme_constant_override("outline_size", 10)
	var arcade := Menus.big_title(title, "ARCADE", 34)
	arcade.add_theme_color_override("font_color", Menus.AMBER)
	arcade.add_theme_constant_override("outline_size", 10)
	bar.add_child(title)
	for it in [["SETTINGS", "settings_root"], ["HOW TO PLAY", "howto_root"], ["CREDITS", "credits_root"]]: # built after this
		var small := Menus.tile(bar, it[0], func(): get(it[1]).show(), self, 16, Vector2(96, 68))
		small.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_corner(col, Vector2(-r - 340, -b - 100), Vector2(340, 100), true)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN # PLAY sits on the corner, the rest stacks up from it
	menu_root.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for it in [["MULTIPLAYER", _open_mp], ["FREE FLIGHT", free_flight]]:
		var half := Menus.tile(row, it[0], it[1], self, 17, Vector2(0, 72))
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card := Menus.tile(col, "", _open_mission, self, 18, Vector2(340, 86))
	card.name = "MissionCard"
	card.add_theme_stylebox_override("normal", Menus._box(Color(0.03, 0.05, 0.1, 0.72), Color(1, 1, 1, 0.25), 2, 8))
	card.add_theme_stylebox_override("hover", card.get_theme_stylebox("normal"))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	home_pic.custom_minimum_size = Vector2(112, 0)
	home_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	h.add_child(home_pic)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	for lab: Label in [home_world, home_mode]:
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.custom_minimum_size.x = 110
		v.add_child(lab)
	home_world.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	home_world.add_theme_font_size_override("font_size", 17)
	home_mode.add_theme_font_size_override("font_size", 14)
	home_mode.add_theme_color_override("font_color", Menus.AMBER)
	var change := Label.new()
	change.text = "CHANGE"
	change.add_theme_font_size_override("font_size", 14)
	change.modulate = Color(1, 1, 1, 0.75)
	h.add_child(change)
	var play := _big_button(col, "PLAY", quick_battle)
	play.name = "Play"
	var pv := VBoxContainer.new()
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	play.add_child(pv)
	var word := Label.new()
	word.text = play.text
	play.text = ""
	word.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	word.add_theme_font_size_override("font_size", 34)
	play_sub.add_theme_font_size_override("font_size", 13)
	play_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for lab: Label in [word, play_sub]:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", Menus.NAVY)
		lab.add_theme_constant_override("outline_size", 0)
		pv.add_child(lab)
	var shop_btn := Menus.tile(menu_root, "HANGAR SHOP", func(): shop_ui.open(), self, 17, Vector2(200, 72))
	shop_btn.name = "HangarShop"
	_corner(shop_btn, Vector2(l, -b - 72), Vector2(200, 72), false)
	for c in [menu_root] + menu_root.find_children("*", "Control", true, false): # taps land on the buttons, not their insides
		if not c is BaseButton:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_mission(ui, inset, l, r, b)


# Phone Mission Select: all six worlds as picture cards (3 x 2), mode chips, size and skill segments;
# LAUNCH is where PLAY was. Nothing scrolls on a 620-unit screen.
func _build_mission(ui: Control, inset: Vector4, l: float, r: float, b: float) -> void:
	mission_root = Control.new()
	mission_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_root.hide()
	ui.add_child(mission_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_root.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = l
	v.offset_right = -r
	v.offset_top = maxf(inset.y, 12.0)
	v.offset_bottom = -b
	v.add_theme_constant_override("separation", 10)
	mission_root.add_child(v)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	v.add_child(bar)
	Menus.tile(bar, "<  BACK", _close_mission, self, 18, Vector2(120, 68))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Menus.big_title(tv, "MISSION", 34).add_theme_constant_override("outline_size", 10)
	bar.add_child(tv)
	Menus.tile(bar, "PLANE + LOOKS", func():
		mission_open = false
		solo_battle()
		_lobby_tab("PLANE"), self, 16, Vector2(0, 68)) # the full lobby: plane picker with stats, stickers, paint
	var cards := GridContainer.new()
	cards.columns = 3
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	v.add_child(cards)
	for i in Worlds.LIST.size():
		var c := Menus.tile(cards, "", _pick_mission.bind("world", i), self, 18, Vector2(0, 84))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := HBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		cv.add_theme_constant_override("separation", 8)
		c.add_child(cv)
		var pic := TextureRect.new()
		pic.texture = load("res://assets/ui/worlds/%s.png" % Worlds.LIST[i])
		pic.custom_minimum_size.x = 100
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cv.add_child(pic)
		var txt := VBoxContainer.new()
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_constant_override("separation", 2)
		cv.add_child(txt)
		var n := Label.new()
		n.text = Worlds.NAMES[i].to_upper()
		n.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
		n.add_theme_font_size_override("font_size", 14)
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		txt.add_child(n)
		var tag := Label.new()
		tag.text = Worlds.TAGLINES[i]
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.add_theme_font_size_override("font_size", 12)
		tag.modulate = Color(1, 1, 1, 0.75)
		txt.add_child(tag)
		world_cards.append(c)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	v.add_child(chips)
	for m in [3, 0, 4, 5]: # Team Dogfight needs humans; Free Flight has its own button
		mode_chips[m] = Menus.tile(chips, MODES[m].to_upper(), _pick_mission.bind("mode", m), self, 16, Vector2(96, 68))
	objective.add_theme_font_size_override("font_size", 15)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(objective)
	var low := HBoxContainer.new() # keeps the segments clear of LAUNCH's corner
	v.add_child(low)
	battle_segs = HFlowContainer.new()
	battle_segs.add_theme_constant_override("h_separation", 24)
	battle_segs.add_theme_constant_override("v_separation", 8)
	battle_segs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(battle_segs)
	var room := Control.new()
	room.custom_minimum_size.x = 352
	low.add_child(room)
	for g in [["SQUADRON SIZE", SIZES.map(func(sz): return "%dV%d" % [sz, sz]), "size", size_segs], ["ENEMY PILOTS", SKILLS.map(func(s): return s.title), "skill", skill_segs]]:
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 2)
		battle_segs.add_child(gv)
		var head := Label.new()
		head.text = g[0]
		head.add_theme_font_size_override("font_size", 13)
		head.modulate = Color(1, 1, 1, 0.6)
		gv.add_child(head)
		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 4)
		gv.add_child(seg)
		for i in g[1].size():
			g[3].append(Menus.tile(seg, g[1][i], _pick_mission.bind(g[2], i), self, 15, Vector2(76, 68)))
	var launch := _big_button(mission_root, "LAUNCH", quick_battle)
	launch.name = "Launch"
	_corner(launch, Vector2(-r - 340, -b - 100), Vector2(340, 100), true)
	for c in [mission_root] + mission_root.find_children("*", "Control", true, false):
		if not c is BaseButton:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # nothing behind it takes a stray tap
	_refresh_mission()


func _big_button(parent: Control, text: String, cb: Callable) -> Button:
	var btn := Menus.tile(parent, text, cb, self, 34, Vector2(340, 100))
	Menus.lit(btn, true)
	return btn


# Phone lobby: one strip with tabs on top (nothing scrolls on a 620-unit screen), LEAVE and LAUNCH at its foot.
var lobby_pages := {} # tab name -> [tab, page]

func _lobby_tabs(box: VBoxContainer, rbox: VBoxContainer, sbox: VBoxContainer) -> void:
	box.get_child(0).free() # MISSION SETUP / HANGAR: the tabs name them
	sbox.get_child(0).free()
	world_sel.pic.custom_minimum_size = Vector2(300, 56)
	for sel: Control in [size_sel, skill_sel]:
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var looks := VBoxContainer.new()
	for sel: Control in [sticker_sel, livery_sel, banner_sel, killfx_sel]:
		sel.reparent(looks)
	lobby_list.add_theme_font_size_override("font_size", 15)
	var acts := HFlowContainer.new()
	rbox.add_child(acts)
	copy_btn.text = "COPY CODE"
	for b: Control in [copy_btn, switch_btn, rbox.get_child(5)]: # ..., HOW TO PLAY: one row
		b.reparent(acts)
		b.add_theme_font_size_override("font_size", 16)
	var col := VBoxContainer.new()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for it in [["MISSION", box], ["PLANE", sbox], ["LOOKS", looks], ["PILOTS", rbox], ["KICK", kick_box]]:
		var page: Control = it[1]
		if page.get_parent():
			page.reparent(col)
		else:
			col.add_child(page)
		var t := Menus.tile(tabs, it[0], _lobby_tab.bind(it[0]), self, 15)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lobby_pages[it[0]] = [t, page]
	var foot := HBoxContainer.new()
	leave_btn.reparent(foot)
	foot.add_child(start_btn)
	for b: Control in [leave_btn, start_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Menus.side_panel(lobby_root, col, 560, false, foot)
	_lobby_tab("MISSION")


func _lobby_tab(k: String) -> void:
	for n in lobby_pages:
		lobby_pages[n][1].visible = n == k
		Menus.lit(lobby_pages[n][0], n == k)


# Pin a control to the bottom-right (right = true) or bottom-left corner: at = offset from that corner's anchor.
func _corner(c: Control, at: Vector2, sz: Vector2, right: bool) -> void:
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = at.x
	c.offset_top = at.y
	c.offset_right = at.x + sz.x
	c.offset_bottom = at.y + sz.y


func _refresh_mission() -> void:
	if not mission_root:
		return
	var v := Settings.values
	var w := clampi(v.last_world, 0, Worlds.LIST.size() - 1)
	var m: int = v.last_mode if v.last_mode in [0, 3, 4, 5] else 3
	var sz := clampi(v.last_size, 0, SIZES.size() - 1)
	var sk := clampi(v.last_skill, 0, SKILLS.size() - 1)
	for i in world_cards.size():
		var on: bool = i == w
		world_cards[i].add_theme_stylebox_override("normal", Menus._box(Color(0.05, 0.08, 0.16, 0.8), Menus.AMBER if on else Color(1, 1, 1, 0.15), 4 if on else 1, 6))
		world_cards[i].add_theme_stylebox_override("hover", world_cards[i].get_theme_stylebox("normal"))
	for k in mode_chips:
		Menus.lit(mode_chips[k], k == m)
	for i in size_segs.size():
		Menus.lit(size_segs[i], i == sz)
	for i in skill_segs.size():
		Menus.lit(skill_segs[i], i == sk)
	objective.text = OBJECTIVES[m]
	battle_segs.visible = m in AI_MODES
	home_pic.texture = load("res://assets/ui/worlds/%s.png" % Worlds.LIST[w])
	home_world.text = Worlds.NAMES[w].to_upper()
	home_mode.text = MODES[m].trim_suffix(" vs AI").to_upper()
	var parts := [Worlds.NAMES[w], MODES[m].trim_suffix(" vs AI")]
	if m in AI_MODES:
		parts += ["%dv%d" % [SIZES[sz], SIZES[sz]], SKILLS[sk].title]
	play_sub.text = "  ·  ".join(parts).to_upper()


# ---------- match start: who/what/where card, controls card, 3-2-1-GO ----------
var OBJECTIVES := ["Escort the bombers to the factory - 2 of 3 must arrive.", "Run the enemy team out of lives.",
	"No rules: pop balloons, explore, practise.", "Shoot down the red squadron before your lives run out.",
	"Steal the enemy flag and fly it home while yours is safe. First to 3.", "Destroy the enemy HQ and defend yours. Bombs (%s) hit hardest." % ("BOMB" if TouchControls.on() else "B")]
var intro_root: Control
var intro_label := RichTextLabel.new()
var keys_root: Control
var keys_label := RichTextLabel.new()
var count_label := Label.new()
var intro_t := 0.0
var keys_t := 0.0
var count_local := 0.0
var count_shown := -1


func _build_intro(ui: Control) -> void:
	for l: RichTextLabel in [intro_label, keys_label]:
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_label.custom_minimum_size.x = 640
	keys_label.custom_minimum_size.x = 440
	var ib := VBoxContainer.new()
	ib.add_child(intro_label)
	intro_root = _panel(ui, ib, Control.PRESET_CENTER_TOP, 120)
	var kb := VBoxContainer.new()
	kb.add_child(keys_label)
	keys_root = _panel(ui, kb, Control.PRESET_CENTER_LEFT, 110 if TouchControls.on() else 20) # phones: clear of the throttle slider
	for r in [intro_root, keys_root]:
		r.hide()
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.offset_top = 200 # centred below the match card, not on it
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	count_label.add_theme_font_size_override("font_size", 180)
	count_label.add_theme_constant_override("outline_size", 18)
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.hide()
	ui.add_child(count_label)
	stall_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stall_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stall_label.position.y -= 170
	stall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stall_label.add_theme_font_size_override("font_size", 22)
	stall_label.add_theme_color_override("font_color", Color(1, 0.75, 0.3))
	stall_label.add_theme_constant_override("outline_size", 8)
	stall_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stall_label.hide()
	ui.add_child(stall_label)


func _show_intro() -> void:
	if not Sfx.enabled:
		return
	var me: Dictionary = gs.players.get(multiplayer.get_unique_id(), {})
	var team: int = me.get("team", 0)
	var t: Dictionary = Planes.TYPES.get(me.get("plane", "cub"), Planes.TYPES.cub)
	var lines := ["[center][font_size=30][b]%s[/b][/font_size]" % Worlds.NAMES[Worlds.index].to_upper(),
		"[font_size=22][color=#ffd34d]%s[/color][/font_size]" % MODES[gs.mode].to_upper(),
		"[font_size=18]%s[/font_size]" % OBJECTIVES[gs.mode]]
	if gs.mode in TEAM_MODES:
		var size := [0, 0]
		for id in gs.players:
			size[gs.players[id].team] += 1
		if gs.mode in AI_MODES:
			size = [maxi(size[0], SIZES[gs.size]), maxi(size[1], SIZES[gs.size])]
		var col := ["#5c9bff", "#ff6b5c"]
		lines.append("[font_size=18][color=%s]%s SQUADRON (%d)%s[/color]   vs   [color=%s]%s SQUADRON (%d)%s[/color][/font_size]" % [
			col[0], TEAM_NAMES[0].to_upper(), size[0], "  <- you" if team == 0 else "", col[1], TEAM_NAMES[1].to_upper(), size[1], "  <- you" if team == 1 else ""])
	lines.append("[font_size=16]Your plane: [b]%s[/b]  -  guns, %d rockets, %d bombs, %d flares[/font_size][/center]" % [Planes.variant(me.get("plane", "cub")).name, t.rockets, t.bombs, t.flares])
	intro_label.text = "\n".join(lines)
	var keys: Array
	if TouchControls.on():
		keys = ["[font_size=20][b]CONTROLS[/b][/font_size]",
			"[color=#9fd3ff]FLY[/color]   Drag anywhere: steer  |  FAST / SLOW throttle  |  BOOST",
			"[color=#ff9f80]FIGHT[/color]  Hold FIRE: guns  |  hold ROCKET: follow + LOCK, let go to fire",
			"         Hold BOMB for the sight, let go to drop  |  FLARE when you hear MISSILE",
			"[color=#e0c8ff]VIEW[/color]   II menu  |  CAM camera",
			"[color=#ffd34d]FUN[/color]    Hold TAUNT and slide to pick (2nd finger: more)"]
	else:
		keys = ["[font_size=20][b]CONTROLS[/b][/font_size]  [font_size=13](H hides)[/font_size]",
			"[color=#9fd3ff]FLY[/color]   Mouse aims  |  W / S throttle  |  Shift boost",
			"         Q / E + arrows: manual stick",
			"[color=#ff9f80]FIGHT[/color]  Left click / Space: guns",
			"         Hold right click / F: rocket (wait for LOCK)",
			"         Hold B: bomb sight, release to drop",
			"         X: flares when you hear MISSILE"]
		keys.append("[color=#a8f0a0]TEAM[/color]   1 Help!  |  2 On me")
		if gs.mode != 2:
			keys.append("         Supplies buy: 3 AA  4 SAM  5 Radar" + ("  6 Repair HQ" if gs.mode == 5 else ""))
		keys.append("[color=#e0c8ff]VIEW[/color]   C camera  |  M map  N zoom  |  Esc menu")
		keys.append("[color=#ffd34d]FUN[/color]    Hold T: taunt wheel, release to send")
	keys_label.text = "\n".join(keys)
	var runs: int = Settings.values.get("matches", 0)
	Settings.values.matches = runs + 1
	Settings.save()
	intro_t = 5.0
	keys_t = 0.0 # no instruction card over the fight; HOW TO PLAY has the controls
	count_shown = -1


func _tick_intro(dt: float) -> void:
	if not intro_root:
		return
	intro_t -= dt
	if intro_t <= 0.0: # one card at a time: the controls follow the match card (they overlapped on phones)
		keys_t -= dt
	var playing: bool = gs.phase == "playing" and not menu_root.visible
	intro_root.visible = playing and intro_t > 0.0
	intro_root.modulate.a = clampf(intro_t / 0.6, 0.0, 1.0)
	keys_root.visible = playing and keys_t > 0.0 and intro_t <= 0.0
	keys_root.modulate.a = clampf(keys_t / 0.6, 0.0, 1.0)
	if not gs.get("loading", false): # set by sync(), ticked here in between
		count_local = maxf(count_local - dt, 0.0)
	var n := ceili(count_local) if count_local > 0.0 else 0
	if playing and n != count_shown and count_shown != -1:
		if n > 0:
			Sfx.ui(self, Sfx.LOCK, -2.0, 0.6)
		else:
			Sfx.ui(self, Sfx.KILL, 0.0)
			Sfx.ui(self, Sfx.LAUNCHES.pick_random(), -6.0)
	if playing and count_shown == -1 and n > 0:
		Sfx.ui(self, Sfx.LOCK, -2.0, 0.6)
	if n != count_shown and n == 0 and count_shown > 0:
		count_label.text = "GO!"
		count_label.modulate = Color(0.5, 1.0, 0.55)
		get_tree().create_timer(0.9).timeout.connect(count_label.hide)
	elif n > 0:
		count_label.text = str(n)
		count_label.modulate = Color(1, 0.9, 0.4)
		count_label.visible = playing
	count_shown = n


func _panel(ui: Control, box: VBoxContainer, at := Control.PRESET_CENTER, margin := 0) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	box.custom_minimum_size.x = 400
	box.add_theme_constant_override("separation", 10)
	pc.add_child(box)
	root.add_child(pc)
	pc.resized.connect(func(): pc.set_anchors_and_offsets_preset(at, Control.PRESET_MODE_MINSIZE, margin))
	ui.add_child(root)
	Menus.thumbs(box)
	return root


func _title(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	box.add_child(l)


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): Sfx.ui(self, Sfx.CLICK, -6.0))
	b.pressed.connect(cb)
	box.add_child(b)
	return b


# ---------- world ----------

func _build_world() -> void:
	_build_world_content(Worlds.index)

	var goal := MeshInstance3D.new()
	goal.mesh = CylinderMesh.new()
	goal.mesh.top_radius = 60.0
	goal.mesh.bottom_radius = 60.0
	goal.mesh.height = 600.0
	var goal_mat := StandardMaterial3D.new()
	goal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	goal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	goal_mat.albedo_color = Color(0.3, 1, 0.4, 0.15)
	goal.material_override = goal_mat
	goal.position = ROUTE[-1] + Vector3(0, 80, 0)
	goal.name = "EscortGoal"
	add_child(goal)
	_build_static()


func _build_static() -> void:
	lobby_cam.far = 6000.0
	add_child(lobby_cam)
	lobby_cam.look_at_from_position(LOBBY_EYE, LOBBY_LOOK)
	lobby_cam.make_current()
	add_outline(lobby_cam)
	add_child(preview)
	preview.global_transform = Transform3D(Basis(), lobby_cam.global_position - lobby_cam.global_basis.z * 20.0 + lobby_cam.global_basis.x * 5.0 - lobby_cam.global_basis.y * 0.5)


# Everything that differs per world lives under world_root, so a world switch is free-and-rebuild.
var world_root: Node3D
var env: Env
var battlefield: Battlefield
var objectives: Objectives
var away := {} # server: token -> {info, until, match}: dropped pilots who may rejoin within 60 s
var tokens := {} # server: peer id -> player token (stable across reconnects)
var buckets := {} # server: rate limits per peer and request
var launches := {} # plane name -> [{t, p, v, bomb, first, hit}], client rockets/bombs seen launched
var tallies := {} # client input accepted / refused, by reason (printed with --netstats / at quit)
var last_target := "" # the room code / address we joined (for auto-reconnect)
var last_sync_ms := 0
var ping_t := 0.0
var lag_warned := {}
var stall_label := Label.new()
var fps_label := Label.new()
var fps_ms := 16.7
var stall_from := 0
var frame_ms := 0
var hitch_quiet_ms := 0
var net_who := "menu" # netlog: who wrote the line
var loaded := {} # server: peer id -> world index that peer has finished building
var load_wait: Array = [] # server: peers the countdown is holding for
var load_hold := 0.0
var stale_drops := 0
var acked_world := -1
var world_frame := 0
var taunts: Taunts
var touch: TouchControls
var shop := Shop.new()
var shop_ui: ShopUI
var offer_match := -1 # results offer worked out once per match
var offer_box := VBoxContainer.new()
var livery_sel: Menus.Selector
var killfx_sel: Menus.Selector
var touch_root: Control
var taunt_cd := 0
var netstats := {} # --netstats: what lag does to remote planes, printed every 10 s
var seen_phase := "lobby"
var world_env: WorldEnvironment

func _build_world_content(i: int) -> void:
	var t0 := Time.get_ticks_msec()
	if world_root:
		world_root.free()
	obstacles.clear()
	obstacle_grid.clear()
	obstacle_top = 0.0
	Worlds.select(i)
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	move_child(world_root, 0)
	world_env = WorldEnvironment.new()
	world_env.environment = Atmos.build_environment()
	world_root.add_child(world_env)
	var sun := Atmos.build_sun()
	sun.add_to_group("sun")
	world_root.add_child(sun)
	world_root.add_child(Atmos.build_clouds())
	world_root.add_child(Atmos.build_water())
	world_root.add_child(Terrain.build())
	world_root.add_child(Props.build())
	var obs := Props.obstacles()
	for a in obs:
		_add_obstacle(a)
	map_tex = null
	map_img = Image.create(Terrain.MAP_PX, Terrain.MAP_PX, false, Image.FORMAT_RGB8) if Sfx.enabled else null # headless never draws it
	map_row = 0
	map_obs = obs
	Sfx.ambience(world_root)
	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	world_root.add_child(battlefield)
	battlefield.setup(self)
	objectives = Objectives.new()
	objectives.name = "Objectives"
	world_root.add_child(objectives)
	objectives.setup(self)
	env = Env.new()
	world_root.add_child(env)
	env.setup(self, world_env.environment)
	Settings.apply(get_tree())
	world_frame = Engine.get_process_frames()
	if not multiplayer.is_server():
		netlog("built world %d in %d ms" % [i, Time.get_ticks_msec() - t0])


@rpc("any_peer", "call_local", "reliable")
func request_world(i: int) -> void:
	if not multiplayer.is_server():
		return
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.world = clampi(i, 0, Worlds.LIST.size() - 1)
		_remember({last_world = gs.world})
		_push()


@rpc("authority", "call_local", "reliable")
func bf_event(kind: String, id: int, at: Vector3, v: Vector3) -> void:
	if not battlefield:
		return
	match kind:
		"drop":
			battlefield.spawn_crate(id, at)
		"gone":
			battlefield.remove_crate(id)
		"flak", "rapid":
			battlefield.shot(id, kind, at, v.x)
		"deploy":
			battlefield.deploy(Battlefield.KINDS[id % 10], id / 10, v, at)
			Sfx.at(self, at, Sfx.CLUNK, 4.0, 1200.0)


# Objective sounds, heard from your own side: your flag taken is an alarm, theirs is a win.
@rpc("authority", "call_local", "reliable")
func sfx_event(kind: String, team: int, at: Vector3, who: String) -> void:
	var mine := team == _my_team()
	var me := str(multiplayer.get_unique_id()) == who
	match kind:
		"grab":
			Sfx.ui(self, Sfx.ALARM if mine else Sfx.GRAB, -4.0)
		"drop":
			Sfx.ui(self, Sfx.DROP, -6.0)
		"return":
			Sfx.ui(self, Sfx.RETURN, -6.0)
		"capture":
			Sfx.ui(self, Sfx.FANFARE, -4.0 if mine else -10.0, 1.0 if mine else 0.7)
		"deliver":
			if mine:
				Sfx.ui(self, Sfx.BELL, -6.0 if not me else -2.0)
		"crate":
			if me:
				Sfx.ui(self, Sfx.PLUCK, -2.0)
		"raid":
			if not mine:
				Sfx.ui(self, Sfx.SIREN, -16.0) # far-off warning: a raid is coming for your HQ
		"hq_hit":
			Sfx.at(self, at, Sfx.HEAVY_HITS.pick_random(), 8.0, 2500.0, 0.6)
			if mine:
				Sfx.ui(self, Sfx.ALARM, -8.0, 0.8)
		"repair":
			Sfx.at(self, at, Sfx.CLUNK, 6.0, 2000.0)
		"kill":
			if me:
				Sfx.ui(self, Sfx.KILL, -4.0)
			var fx: int = gs.players.get(int(who), {}).get("killfx", 0)
			if fx > 0 and Sfx.enabled:
				Fx.kill_effect(self, at, fx)
		"prize_up":
			Sfx.ui(self, Sfx.GRAB, -6.0, 1.3)
		"prize":
			if not me:
				Sfx.ui(self, Sfx.BELL, -10.0)


@rpc("authority", "call_local", "reliable")
func env_event(kind: String, at: Vector3, v: Vector3) -> void:
	if env:
		env.show_event(kind, at, v)


# Planes or turrets by node name (rockets from SAM sites need their owner on every peer).
func find_unit(n: String) -> Node:
	var p := players.get_node_or_null(n)
	if not p and battlefield:
		p = battlefield.get_node_or_null(n)
	if not p and objectives:
		p = objectives.get_node_or_null(n)
	return p


# ---------- deployable defenses ----------
const DEPLOY_COST := {rapid = 1, sam = 2, radar = 1}

@rpc("any_peer", "call_local", "reliable")
func request_deploy(kind: String, mid: int) -> void:
	if not multiplayer.is_server() or stale(mid) or not _allow(_sender(), "deploy", 1.0, 2.0):
		return
	var p := _plane(_sender())
	if p and DEPLOY_COST.has(kind) and gs.get("bank", [0, 0])[p.team] >= DEPLOY_COST[kind]:
		if deploy(p, kind):
			gs.bank[p.team] -= DEPLOY_COST[kind]
			_push()


@rpc("any_peer", "call_local", "reliable")
func request_repair(mid: int) -> void:
	if not multiplayer.is_server() or stale(mid) or not _allow(_sender(), "repair", 1.0, 2.0):
		return
	var p := _plane(_sender())
	if p and objectives and objectives.repair_hq(p.team):
		_push()


@rpc("authority", "call_local", "reliable")
func obj_event(kind: String, a: Vector3, b: Vector3) -> void:
	if objectives and kind == "bombs":
		objectives.show_bombs(a, b)


# Server: drop a turret for `p`'s team onto the ground below it. Returns false if there's no spot.
func deploy(p: Node, kind: String) -> bool:
	if gs.phase != "playing" or gs.mode == 2 or not battlefield or battlefield.deployed_alive(p.team) >= Battlefield.MAX_DEPLOYED:
		return false
	var at := Vector3(p.position.x, Terrain.floor_below(p.position), p.position.z)
	if p.position.y - at.y > 700.0 or at.y < Terrain.WATER_Y + 1.0 or hits_obstacle(at + Vector3.UP * 3.0) or absf(at.x) > 1900.0 or absf(at.z) > 1900.0:
		return false
	bf_event.rpc("deploy", p.team * 10 + Battlefield.KINDS.find(kind), at, p.position)
	var what: String = Battlefield.Turret.SPEC[kind].name
	_feed("%s deployed %s %s" % [p.pilot, "an" if what[0] in "AEIOU" else "a", what])
	return true


# Damage from the world itself (lava, lightning): server only.
func env_hit(p: Node, dmg: int, cause: String) -> void:
	if not p.alive or not p.is_in_group("targets") or gs.phase != "playing":
		return
	p.set_hp.rpc(p.hp - dmg, p.comps)
	if p.hp <= 0:
		_feed("%s was downed by %s" % [p.pilot, cause])
		kill(p, null, true)


func feed_msg(text: String) -> void:
	_feed(text)
	_push()


var toon_cache := {}

func toon(c: Color) -> ShaderMaterial:
	if not toon_cache.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://toon.gdshader")
		mat.set_shader_parameter("albedo", c)
		toon_cache[c] = mat
	return toon_cache[c]


func add_outline(cam: Camera3D) -> void:
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.mesh.size = Vector2(2, 2)
	quad.mesh.flip_faces = true
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.material_override = ShaderMaterial.new()
	quad.material_override.shader = preload("res://outline.gdshader")
	cam.add_child(quad)
