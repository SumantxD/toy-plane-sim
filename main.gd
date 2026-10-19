extends Node3D

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
var PORT := DEFAULT_PORT # --port N overrides (tests run beside a real game)
const WORLD_SIZE := 2000.0
const Aircraft := preload("res://plane.gd")
const Bullets := preload("res://bullets.gd")
const Rockets := preload("res://rockets.gd")
const MODES := ["Co-op Escort", "Team Dogfight", "Free Flight", "Team Battle vs AI"]
const SIZES := [2, 4, 6]
const SKILL_NAMES := ["rookie", "pilot", "ace"]
const CALLSIGNS := ["Maverick", "Goose", "Iceman", "Viper", "Jester", "Hollywood", "Wolfman", "Sundown", "Cougar", "Merlin", "Slider", "Stinger"]
const TEAM_NAMES := ["Blue", "Red"]
const DAMAGE := [8, 45] # guns, rocket
const BEACON_TIME := 15.0
const BEACON_RADIUS := 25.0
const RESPAWN_DELAY := 3.0
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
	beacons = [], feed = [], msg = "", match_id = 0, room = "", public_ip = "", popped = 0, size = 1, skill = 1, team_kills = [0, 0], ai_board = {}, world = 0, storm = 0.0,
}
var beacons := {} # server only: victim id -> {pos, t, team}
var respawning := {} # server only: victim id -> team, waiting out RESPAWN_DELAY
var pings: Array = [] # local: [pos, text, time_left]
var push_cd := 0.0
var ai_count := 0
var bot := "--bot" in OS.get_cmdline_user_args()

var menu_root: Control
var lobby_root: Control
var pause_root: Control
var name_edit := LineEdit.new()
var address := LineEdit.new()
var status := Label.new()
var lobby_list := Label.new()
var mode_btn := OptionButton.new()
var plane_btn := OptionButton.new()
var battle_row := HBoxContainer.new()
var world_btn := OptionButton.new()
var size_btn := OptionButton.new()
var skill_btn := OptionButton.new()
var plane_choice := "cub"
var start_btn: Button
var copy_btn: Button
var room_label := Label.new()
var net_label := Label.new()
var leave_btn: Button
var switch_btn: Button
var overlay := Control.new()
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


func _ready() -> void:
	Settings.load_saved()
	_build_world()
	_build_ui()
	Settings.apply(get_tree())
	if Engine.has_meta("leave_msg"):
		status.text = Engine.get_meta("leave_msg")
		Engine.remove_meta("leave_msg")
		print("MENU: ", status.text)
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
	var shot := args.find("--shot")
	if shot >= 0:
		get_tree().create_timer(float(args[shot + 1])).timeout.connect(func():
			print("FPS ", Engine.get_frames_per_second(), "  draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			get_viewport().get_texture().get_image().save_png(args[shot + 2])
			get_tree().quit())
	var qa := args.find("--quit-after-secs")
	if qa >= 0:
		get_tree().create_timer(float(args[qa + 1])).timeout.connect(func():
			print("AIM shots=%d hits=%d (%.1f%%)" % [stat_shots, stat_hits, 100.0 * stat_hits / maxf(stat_shots, 1)])
			print("STATS nodes=%d orphans=%d mem=%.1fMB" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6])
			get_tree().quit())
	if "--free" in args:
		free_flight()
	if "--test-deploy" in args: # test hook: a joined client calls in a SAM site
		get_tree().create_timer(25.0).timeout.connect(func(): request_deploy.rpc_id(1, "sam"))
	if "--solo" in args:
		solo_battle()
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


# ---------- connection ----------
# LAN / IP: plain ENet on PORT. Online: rooms.gd (WebRTC P2P + room code over public MQTT).
const VERSION := "0.5"

var room := "" # online room code we host or joined
var rooms: Rooms
var joining := false
var spectating := "--spectate" in OS.get_cmdline_user_args() # watch AI-only battles
var spec_target: Node
var spec_t := 0.0
var upnp_task := -1


func host(port := -1) -> bool:
	if port < 0:
		port = PORT
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		status.text = "Could not host on port %d (already running?)" % port
		return false
	multiplayer.multiplayer_peer = peer
	room = ""
	_start_hosting()
	if DisplayServer.get_name() != "headless":
		upnp_task = WorkerThreadPool.add_task(_open_router_port.bind(port))
	return true


func _start_hosting() -> void:
	if not multiplayer.peer_disconnected.is_connected(_on_peer_left):
		multiplayer.peer_disconnected.connect(_on_peer_left)
	gs.phase = "lobby"
	gs.room = room
	if DisplayServer.get_name() == "headless" or spectating:
		gs.leader = 0 # first player to join leads
	else:
		_add_player(1, name_edit.text)
	_push()
	print("Hosting")


# Solo battle vs AI: offline lobby where you pick size and difficulty, then fight.
func solo_battle() -> void:
	room = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_start_hosting()
	request_mode(3)


# Solo practice runs offline: no port, no firewall prompt, same game code (offline peer = server).
func free_flight() -> void:
	room = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_start_hosting()
	gs.mode = 2
	_start()


# Plan B with zero servers: ask the router (UPnP) to forward our port, then friends type our public IP.
# Fails on routers with UPnP off or carrier-grade NAT; online rooms cover those.
func _open_router_port(port: int) -> void:
	var upnp := UPNP.new()
	if upnp.discover(1200) != UPNP.UPNP_RESULT_SUCCESS or not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		return
	if upnp.add_port_mapping(port, port, "Toy Plane Sim", "UDP", 4 * 3600) == UPNP.UPNP_RESULT_SUCCESS:
		_set_public_ip.call_deferred(upnp.query_external_address())


func _set_public_ip(ip: String) -> void:
	gs.public_ip = ip
	_push()


func _exit_tree() -> void:
	if upnp_task >= 0:
		WorkerThreadPool.wait_for_task_completion(upnp_task)


func host_online() -> void:
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
		status.text = t
		net_label.text = t if gs.phase == "lobby" else ""
		print("rooms: ", t))
	add_child(rooms)


func join() -> void:
	if joining:
		return
	var target := address.text.strip_edges()
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
	var attempt := room
	get_tree().create_timer(40.0).timeout.connect(func():
		if gs.phase == "menu" and room == attempt and joining:
			joining = false
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			status.text = "Could not connect to room %s. Check the code, make sure everyone clicked Allow on the firewall prompt, or see How to play > Internet tips." % attempt)


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
		multiplayer.server_disconnected.connect(func(): _leave("The host left the game."))


func _on_connect_failed() -> void:
	joining = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status.text = "Could not connect. Is the host's game open in the lobby, and did they allow it through the firewall?"


func _on_connected() -> void:
	joining = false
	print("Connected as %d" % multiplayer.get_unique_id())
	var fv := OS.get_cmdline_user_args().find("--fake-version") # test hook
	register.rpc_id(1, {name = name_edit.text, version = OS.get_cmdline_user_args()[fv + 1] if fv >= 0 else VERSION, plane = Planes.ORDER.pick_random() if bot else plane_choice})


@rpc("authority", "reliable")
func kicked(reason: String) -> void:
	_leave(reason)


# Back to the main menu; `msg` survives the scene reload and shows on the menu.
func _leave(msg := "") -> void:
	if msg:
		Engine.set_meta("leave_msg", msg)
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_peer_left(id: int) -> void:
	if rooms:
		rooms.forget(id)
	gs.players.erase(id)
	beacons.erase(id)
	var p := _plane(id)
	if p:
		p.queue_free()
	respawning.erase(id)
	if gs.leader == id:
		gs.leader = 1 if gs.players.has(1) else (gs.players.keys()[0] if gs.players else 0)
	if gs.players.is_empty() and gs.phase != "lobby":
		for c in players.get_children():
			c.queue_free()
		gs.phase = "lobby"
	_push()


@rpc("any_peer", "reliable")
func register(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	var pilot := str(info.get("name", ""))
	var version := str(info.get("version", "?"))
	var plane := str(info.get("plane", "cub"))
	var reject := ""
	if version != VERSION:
		reject = "Version mismatch: the host has v%s, you have v%s. Everyone needs the same download." % [VERSION, version]
	elif gs.players.size() >= MAX_PLAYERS:
		reject = "That room is full (%d pilots)." % MAX_PLAYERS
	if reject:
		kicked.rpc_id(id, reject)
		get_tree().create_timer(0.5).timeout.connect(func(): multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	_add_player(id, pilot)
	if Planes.TYPES.has(plane):
		gs.players[id].plane = plane
	if gs.leader == 0:
		gs.leader = id
	if gs.phase == "playing":
		_spawn_pilot(id, _base(id))
		for c in players.get_children():
			if c.name != str(id):
				c.set_hp.rpc_id(id, c.hp, c.comps)
				if not c.alive:
					c.die.rpc_id(id, false)
		if battlefield: # replay deployed defenses in order so turret indices match
			for g in battlefield.guns.slice(battlefield.base_count):
				bf_event.rpc_id(id, "deploy", g.team * 10 + Battlefield.KINDS.find(g.kind), g.position, g.position + Vector3.UP * 5.0)
	_push()


func _add_player(id: int, pilot: String) -> void:
	pilot = pilot.strip_edges().left(16)
	var counts := _team_counts()
	gs.players[id] = {name = pilot if pilot else "Pilot%d" % (id % 1000), team = 0 if not gs.mode in [1, 3] or counts[0] <= counts[1] else 1, kills = 0, deaths = 0, revives = 0, plane = "cub", charges = 2}


@rpc("authority", "call_local", "reliable")
func sync(state: Dictionary) -> void:
	var was: String = gs.phase
	gs = state
	if gs.get("world", 0) != Worlds.index:
		_build_world_content(gs.world)
	if gs.phase != was and gs.phase == "playing":
		Sfx.ui(self, Sfx.CONFIRM, -4.0)
		if battlefield:
			battlefield.reset_guns()
			for id in battlefield.crates.keys():
				battlefield.remove_crate(id)
	if gs.phase != was and gs.phase != "playing":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		lobby_cam.make_current()
		pause_root.hide()
	_refresh_ui()


func _push() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		if gs.phase != "menu":
			sync(gs.duplicate(true)) # solo free flight: apply locally
	else:
		sync.rpc(gs)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# ---------- lobby actions (leader only) ----------

@rpc("any_peer", "call_local", "reliable")
func request_start() -> void:
	if _sender() == gs.leader and gs.phase == "lobby":
		if gs.mode == 1 and 0 in _team_counts():
			_feed("Dogfight needs a pilot on each team")
			gs.msg = "Dogfight needs a pilot on each team"
			_push()
			return
		_start()


@rpc("any_peer", "call_local", "reliable")
func request_battle(size_i: int, skill_i: int) -> void:
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.size = clampi(size_i, 0, SIZES.size() - 1)
		gs.skill = clampi(skill_i, 0, SKILL_NAMES.size() - 1)
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_end() -> void:
	if _sender() == gs.leader and gs.phase == "playing":
		_end("Match ended by the leader")


@rpc("any_peer", "call_local", "reliable")
func request_mode(m: int) -> void:
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.mode = clampi(m, 0, MODES.size() - 1)
		gs.msg = ""
		var i := 0
		for id in gs.players:
			gs.players[id].team = 0 if gs.mode != 1 else i % 2 # vs-AI: everyone starts on Blue
			i += 1
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_plane(kind: String) -> void:
	var id := _sender()
	if gs.phase == "lobby" and gs.players.has(id) and Planes.TYPES.has(kind):
		gs.players[id].plane = kind
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_switch_team() -> void:
	var id := _sender()
	if gs.phase == "lobby" and gs.mode in [1, 3] and gs.players.has(id):
		gs.players[id].team = 1 - gs.players[id].team
		_push()


@rpc("any_peer", "call_local", "reliable")
func request_ping(text: String) -> void:
	var p := _plane(_sender())
	if p and p.alive and text in ["Help!", "On me"]:
		show_ping.rpc(p.position, "%s: %s" % [p.pilot, text], p.team)


@rpc("authority", "call_local", "reliable")
func show_ping(pos: Vector3, text: String, team: int) -> void:
	if team == _my_team():
		pings.append([pos, text, 5.0])


# ---------- match flow (server) ----------

func _start() -> void:
	gs.match_id += 1
	gs.phase = "playing"
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
	gs.msg = ""
	gs.popped = 0
	gs.storm = 0.0
	for id in gs.players:
		gs.players[id].kills = 0
		gs.players[id].deaths = 0
		gs.players[id].revives = 0
		gs.players[id].charges = 2
	gs.team_kills = [0, 0]
	gs.ai_board = {}
	if gs.mode == 3:
		var n: int = SIZES[gs.size]
		gs.lives = [n * 2, n * 2]
		gs.time = MATCH_TIME
		var counts := _team_counts()
		var names := CALLSIGNS.duplicate()
		names.shuffle()
		for team in 2:
			for i in range(counts[team], n):
				var b := _base_for(team, i)
				var w := _spawn_ai("wing", team, b[0], b[1], Vector3.ZERO, Planes.ORDER.pick_random(), names.pop_back())
				w.ai = PilotAI.make(SKILL_NAMES[gs.skill])
				w.ai.slot = i - counts[team]
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
	_push()


func _end(text: String) -> void:
	if gs.phase != "playing":
		return
	gs.phase = "ended"
	gs.msg = text
	print("END: ", text, "\n", _scoreboard())
	_push()
	var id: int = gs.match_id
	get_tree().create_timer(8.0).timeout.connect(func():
		if gs.match_id == id and gs.phase == "ended":
			for c in players.get_children():
				c.queue_free()
			gs.phase = "lobby"
			_push()
			if "--start" in OS.get_cmdline_user_args():
				get_tree().create_timer(2.0).timeout.connect(_start))


func _process(dt: float) -> void:
	for p in pings:
		p[2] -= dt
	pings = pings.filter(func(p): return p[2] > 0.0)
	overlay.queue_redraw()
	_refresh_hud()
	if preview.visible:
		preview.rotate_y(0.6 * dt)
	if spectating and gs.phase in ["playing", "ended"]:
		_spectate(dt)
	if not multiplayer.is_server() or gs.phase != "playing":
		return
	_tick_beacons(dt)
	if env:
		env.server_tick(dt)
	if battlefield:
		battlefield.server_tick(dt)
		battlefield.server_guns(dt)
	_tick_charges(dt)
	if gs.mode == 0:
		_tick_escort(dt)
	elif gs.mode == 1:
		_tick_dogfight(dt)
	elif gs.mode == 3:
		_tick_battle(dt)
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
	return players.get_children().filter(func(p): return p.team == team and p.alive and p.role in ["pilot", "wing"]).size()


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
func report_hit(target_name: String, weapon: int, comp: int) -> void:
	var a := _plane(multiplayer.get_remote_sender_id())
	var t := players.get_node_or_null(target_name)
	if a and t and a.position.distance_to(t.position) < 2500.0:
		apply_hit(a, t, clampi(weapon, 0, 1), clampi(comp, -1, 3))


@rpc("any_peer", "call_local", "reliable")
func report_crash() -> void:
	var p := _plane(_sender())
	if p:
		kill(p, null)


func apply_hit(a: Node, t: Node, weapon: int, comp := -1) -> void:
	if a.is_ai and weapon == 0:
		stat_hits += 1
	if t.alive and a.team != t.team and gs.phase == "playing":
		var dmg: int = DAMAGE[weapon]
		if a.role == "fighter":
			dmg = ceili(dmg * (0.4 if t.role == "bomber" else 0.6)) # raiders hit softer (bombers must be escortable)
		elif a.role == "turret":
			dmg = ceili(dmg * (0.15 if t.role == "bomber" else 0.6)) # defenses chip bombers, they don't erase them
		elif a.role == "wing" and t.role == "pilot":
			dmg = ceili(dmg * 0.75) # AI wingmen/enemies go a bit easy on humans
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
	if not quiet:
		_feed("%s shot down %s" % [killer.pilot, victim.pilot] if killer else "%s crashed" % victim.pilot)
	if killer and killer.role == "pilot" and gs.players.has(int(str(killer.name))):
		gs.players[int(str(killer.name))].kills += 1
	if killer and killer.team != victim.team:
		gs.team_kills[killer.team] += 1
	if killer and killer.role == "wing":
		var row: Dictionary = gs.ai_board.get_or_add(killer.pilot, {team = killer.team, style = PilotAI.ARCHETYPES[killer.ai.arch].name, kills = 0})
		row.kills += 1
	PilotAI.on_kill(victim, killer, self)
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
	get_tree().create_timer(delay).timeout.connect(func():
		respawning.erase(key)
		if is_instance_valid(victim) and gs.match_id == id and gs.phase == "playing" and not victim.alive:
			var b := _base(int(key)) if victim.role == "pilot" else _base_for(victim.team, randi() % 6)
			victim.respawn.rpc(b[0], b[1]))


func _feed(text: String) -> void:
	print("[%5.1f] %s" % [Time.get_ticks_msec() / 1000.0, text])
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
var radio_cd := 0.0
var radio_last := {}

func radio(p: Node, text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < radio_cd or now < radio_last.get(p.name, 0.0):
		return
	radio_cd = now + 2.5
	radio_last[p.name] = now + 12.0
	_feed('%s: "%s"' % [p.pilot, text])


func repair(p: Node, amount: int) -> void:
	var c: PackedFloat32Array = p.comps.duplicate()
	for i in 4:
		c[i] = minf(c[i] + 0.04 * amount / 5.0, 1.0)
	p.set_hp.rpc(mini(p.hp + amount, p.max_hp), c)


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
	if p.role == "balloon":
		p.position = p.offset + Vector3(0, sin(Time.get_ticks_msec() / 900.0 + p.offset.x) * 4.0, 0)
		p.rotate_y(0.2 * dt)
		return
	if p.role == "bomber":
		_bomber_move(p, dt)
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
	if Terrain.solid(p) or p.y < Worlds.cur.env.kill_y:
		return true
	return p.y < Terrain.height(p.x, p.z) + obstacle_top and hits_obstacle(p)


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


func boom(pos: Vector3, size := 1.0) -> void:
	Sfx.at(self, pos, Sfx.BOOMS.pick_random(), 4.0, 3000.0)
	var m := MeshInstance3D.new()
	m.mesh = SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(3.0, 1.6, 0.3)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	add_child(m)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * 22.0 * size, 0.7 * size)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(m.queue_free)


# ---------- input & UI ----------

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and (settings_root.visible or howto_root.visible or credits_root.visible):
		Settings.save()
		settings_root.hide()
		howto_root.hide()
		credits_root.hide()
		return
	if gs.phase != "playing":
		return
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
			request_deploy.rpc_id(1, "rapid")
		KEY_4:
			request_deploy.rpc_id(1, "sam")
		KEY_5:
			request_deploy.rpc_id(1, "radar")


func _refresh_ui() -> void:
	menu_root.visible = gs.phase == "menu"
	lobby_root.visible = gs.phase == "lobby"
	var leader: bool = gs.leader == multiplayer.get_unique_id()
	mode_btn.disabled = not leader
	mode_btn.selected = gs.mode
	start_btn.visible = leader
	switch_btn.visible = gs.mode in [1, 3]
	battle_row.visible = gs.mode == 3
	size_btn.disabled = not leader
	world_btn.disabled = not leader
	world_btn.selected = gs.get("world", 0)
	skill_btn.disabled = not leader
	size_btn.selected = gs.size
	skill_btn.selected = gs.skill
	leave_btn.text = "Close room" if multiplayer.is_server() and gs.players.size() > 1 else "Leave"
	if gs.room:
		room_label.text = "ROOM CODE:  %s" % gs.room
	elif multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		room_label.text = "Solo battle vs AI" if gs.mode == 3 else "Solo practice"
	else:
		var lan := Array(IP.get_local_addresses()).filter(func(a): return a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."))
		room_label.text = "LAN game - friends join with: %s%s" % [", ".join(lan.slice(0, 2)) if lan else "your IP", ("\nInternet (router allowed): %s" % gs.public_ip) if gs.public_ip else ""]
	copy_btn.visible = gs.room != ""
	var lines := [gs.msg] if gs.msg else []
	var counts := _team_counts()
	for team in (2 if gs.mode in [1, 3] else 1):
		var fill := maxi(SIZES[gs.size] - counts[team], 0) if gs.mode == 3 else 0
		lines.append("%s team%s" % [TEAM_NAMES[team], ("  + %d AI pilot%s" % [fill, "s" if fill != 1 else ""]) if fill else ""])
		for id in gs.players:
			if gs.players[id].team == team:
				var info: Dictionary = gs.players[id]
				lines.append("   %s  [%s]%s" % [info.name, Planes.TYPES[info.get("plane", "cub")].name, "  (leader)" if id == gs.leader else ""])
	if not leader:
		lines.append("\nWaiting for the leader to start...")
	lobby_list.text = "\n".join(lines)
	_refresh_preview()
	$EscortGoal.visible = gs.mode == 0
	if gs.phase == "ended":
		results_title.text = gs.msg
		for c in results_grid.get_children():
			c.queue_free()
		for h in ["PILOT", "TEAM", "PLANE", "KILLS", "DEATHS", "REVIVES"]:
			_cell(h, Menus.AMBER)
		for id in gs.players:
			var p: Dictionary = gs.players[id]
			for v in [p.name, TEAM_NAMES[p.team], Planes.TYPES[p.get("plane", "cub")].name, p.kills, p.deaths, p.get("revives", 0)]:
				_cell(str(v), Color.WHITE)
		var ai_rows: Array = gs.ai_board.keys()
		ai_rows.sort_custom(func(a, b): return gs.ai_board[a].kills > gs.ai_board[b].kills)
		for n in ai_rows.slice(0, 6):
			var r: Dictionary = gs.ai_board[n]
			for v in ["%s (AI)" % n, TEAM_NAMES[r.team], r.style, r.kills, "", ""]:
				_cell(str(v), Color(0.75, 0.85, 1.0))


func _cell(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.custom_minimum_size.x = 110
	results_grid.add_child(l)


# Spinning model of the chosen plane next to the lobby panel, plus its stat bars.
func _refresh_preview() -> void:
	preview.visible = gs.phase == "lobby"
	var key := "%s/%d" % [plane_choice, _my_team()]
	if not preview.visible or key == preview_key:
		return
	preview_key = key
	for c in preview.get_children():
		c.queue_free()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	Planes.build(plane_choice, preview, toon(Aircraft.TEAM_COLORS[_my_team()]), toon(Color(0.95, 0.93, 0.85)), toon(Color(0.15, 0.2, 0.3)), toon(Color(0.2, 0.2, 0.22)), glow)
	var t: Dictionary = Planes.TYPES[plane_choice]
	stats_label.text = "%s\n%s" % [t.name, t.desc]
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
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer and not multiplayer.is_server() and peer.get_peer(1):
		rtt = "   Ping %dms" % peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	if gs.mode == 3:
		var t := "%d:%02d" % [int(gs.time) / 60, int(gs.time) % 60]
		top.text = "BLUE  %d lives, %d flying   |   %s   |   RED  %d lives, %d flying%s" % [gs.lives[0], _flying(0), t, gs.lives[1], _flying(1), rtt]
	elif gs.mode == 2:
		top.text = "FREE FLIGHT   Balloons popped: %d   (Esc for menu)%s" % [gs.popped, rtt]
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
	feed.text = "\n".join(gs.feed)


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
	for b in gs.beacons:
		if b[1] == team:
			_marker(cam, b[0], Color.ORANGE, "REVIVE %s  %ds" % [b[3], b[2]])
	for p in pings:
		_marker(cam, p[0], Color.CYAN, p[1])
	if battlefield:
		for c in battlefield.crates.values():
			_marker(cam, c.pos, Color(1.0, 0.85, 0.2), "SUPPLY")
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


func _marker(cam: Camera3D, pos: Vector3, color: Color, text: String) -> void:
	if cam.is_position_behind(pos):
		return
	var s := cam.unproject_position(pos)
	if not s.is_finite():
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
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	ui.add_child(overlay)
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
	ui.add_child(feed)

	var box := VBoxContainer.new()
	_title(box, "TOY PLANE SIM")
	var ver := Label.new()
	ver.text = "v" + VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.modulate = Color(1, 1, 1, 0.6)
	box.add_child(ver)
	name_edit.text = Settings.values.name if Settings.values.name else "Pilot%d" % randi_range(10, 99)
	name_edit.max_length = 16
	name_edit.placeholder_text = "Your name"
	name_edit.text_changed.connect(func(t):
		Settings.values.name = t.strip_edges()
		Settings.save())
	box.add_child(name_edit)
	_button(box, "Battle vs AI (solo)", solo_battle)
	_button(box, "Free Flight (solo practice)", free_flight)
	_button(box, "Host online (get a room code)", host_online)
	_button(box, "Host on LAN", host)
	var join_row := HBoxContainer.new()
	address.placeholder_text = "Room code or IP"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(address)
	var jb := Button.new()
	jb.text = "Join"
	jb.pressed.connect(join)
	join_row.add_child(jb)
	box.add_child(join_row)
	_button(box, "Settings", func(): settings_root.show())
	_button(box, "How to play", func(): howto_root.show())
	_button(box, "Credits", func(): credits_root.show())
	_button(box, "Quit", get_tree().quit)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status)
	menu_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "LOBBY")
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(room_label)
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_label.modulate = Menus.AMBER
	net_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(net_label)
	copy_btn = _button(box, "Copy room code", func(): DisplayServer.clipboard_set(gs.room))
	for mo in MODES:
		mode_btn.add_item(mo)
	mode_btn.item_selected.connect(func(i): request_mode.rpc_id(1, i))
	box.add_child(mode_btn)
	for wn in Worlds.NAMES:
		world_btn.add_item(wn)
	world_btn.item_selected.connect(func(i): request_world.rpc_id(1, i))
	box.add_child(world_btn)
	battle_row.add_theme_constant_override("separation", 8)
	for sz in SIZES:
		size_btn.add_item("%dv%d" % [sz, sz])
	for sk in ["Rookie AI", "Pilot AI", "Ace AI"]:
		skill_btn.add_item(sk)
	size_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_btn.item_selected.connect(func(i): request_battle.rpc_id(1, i, gs.skill))
	skill_btn.item_selected.connect(func(i): request_battle.rpc_id(1, gs.size, i))
	battle_row.add_child(size_btn)
	battle_row.add_child(skill_btn)
	box.add_child(battle_row)
	for k in Planes.ORDER:
		plane_btn.add_item(Planes.TYPES[k].name)
	plane_btn.item_selected.connect(func(i):
		plane_choice = Planes.ORDER[i]
		request_plane.rpc_id(1, plane_choice)
		_refresh_preview())
	box.add_child(plane_btn)
	box.add_child(lobby_list)
	switch_btn = _button(box, "Switch team", func(): request_switch_team.rpc_id(1))
	start_btn = _button(box, "Start match", func(): request_start.rpc_id(1))
	_button(box, "How to play", func(): howto_root.show())
	leave_btn = _button(box, "Leave", _leave)
	lobby_root = _panel(ui, box, Control.PRESET_CENTER_LEFT, 50)
	var sbox := VBoxContainer.new()
	stats_label.add_theme_font_size_override("font_size", 22)
	sbox.add_child(stats_label)
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
	var stats_root := _panel(ui, sbox, Control.PRESET_BOTTOM_RIGHT, 40)
	stats_root.reparent(lobby_root)

	box = VBoxContainer.new()
	_title(box, "PAUSED")
	_button(box, "Resume", func():
		pause_root.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_button(box, "Settings", func(): settings_root.show())
	_button(box, "How to play", func(): howto_root.show())
	end_btn = _button(box, "End match (back to lobby)", func():
		pause_root.hide()
		request_end.rpc_id(1))
	_button(box, "Leave game", _leave)
	pause_root = _panel(ui, box)

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.add_theme_font_size_override("font_size", 32)
	results_title.modulate = Menus.AMBER
	box.add_child(results_title)
	results_grid.columns = 6
	box.add_child(results_grid)
	var back := Label.new()
	back.text = "Back to the lobby in a few seconds..."
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(back)
	results_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "SETTINGS")
	box.add_child(Menus.settings_panel(get_tree(), func(): settings_root.hide()))
	settings_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "HOW TO PLAY")
	var how := RichTextLabel.new()
	how.bbcode_enabled = true
	how.fit_content = true
	how.custom_minimum_size.x = 760
	how.text = Menus.howto_text()
	box.add_child(how)
	_button(box, "Got it", func(): howto_root.hide())
	howto_root = _panel(ui, box)

	box = VBoxContainer.new()
	_title(box, "CREDITS")
	var cr := RichTextLabel.new()
	cr.bbcode_enabled = true
	cr.custom_minimum_size = Vector2(760, 420)
	cr.text = Menus.credits_text()
	box.add_child(cr)
	_button(box, "Close", func(): credits_root.hide())
	credits_root = _panel(ui, box)

	for r in [pause_root, results_root, settings_root, howto_root, credits_root, lobby_root]:
		r.hide()


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
	return root


func _title(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	box.add_child(l)


func _button(box: VBoxContainer, text: String, cb: Callable) -> Button:
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
	lobby_cam.look_at_from_position(Vector3(0, 230, 2450), Vector3(0, 60, 0))
	lobby_cam.make_current()
	add_outline(lobby_cam)
	add_child(preview)
	preview.global_transform = Transform3D(Basis(), lobby_cam.global_position - lobby_cam.global_basis.z * 20.0 + lobby_cam.global_basis.x * 5.0 - lobby_cam.global_basis.y * 0.5)


# Everything that differs per world lives under world_root, so a world switch is free-and-rebuild.
var world_root: Node3D
var env: Env
var battlefield: Battlefield
var world_env: WorldEnvironment

func _build_world_content(i: int) -> void:
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
	for a in Props.obstacles():
		_add_obstacle(a)
	Sfx.ambience(world_root)
	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	world_root.add_child(battlefield)
	battlefield.setup(self)
	env = Env.new()
	world_root.add_child(env)
	env.setup(self, world_env.environment)
	Settings.apply(get_tree())


@rpc("any_peer", "call_local", "reliable")
func request_world(i: int) -> void:
	if _sender() == gs.leader and gs.phase == "lobby":
		gs.world = clampi(i, 0, Worlds.LIST.size() - 1)
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


@rpc("authority", "call_local", "reliable")
func env_event(kind: String, at: Vector3, v: Vector3) -> void:
	if env:
		env.show_event(kind, at, v)


# Planes or turrets by node name (rockets from SAM sites need their owner on every peer).
func find_unit(n: String) -> Node:
	var p := players.get_node_or_null(n)
	if not p and battlefield:
		p = battlefield.get_node_or_null(n)
	return p


# ---------- deployable defenses ----------
const DEPLOY_COST := {rapid = 1, sam = 2, radar = 1}
const MAX_CHARGES := 3
var charge_t := 0.0

@rpc("any_peer", "call_local", "reliable")
func request_deploy(kind: String) -> void:
	var p := _plane(_sender())
	var info = gs.players.get(_sender())
	if p and info and DEPLOY_COST.has(kind) and info.get("charges", 0) >= DEPLOY_COST[kind]:
		if deploy(p, kind):
			info.charges -= DEPLOY_COST[kind]
			_push()


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


func _tick_charges(dt: float) -> void:
	charge_t += dt
	if charge_t < 90.0:
		return
	charge_t = 0.0
	for id in gs.players:
		gs.players[id].charges = mini(gs.players[id].get("charges", 0) + 1, MAX_CHARGES)
	for p in players.get_children():
		if p.ai.has("traits"):
			p.ai.charges = mini(p.ai.get("charges", 1) + 1, MAX_CHARGES)


# Damage from the world itself (lava, lightning): server only.
func env_hit(p: Node, dmg: int, cause: String) -> void:
	if not p.alive or gs.phase != "playing":
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
