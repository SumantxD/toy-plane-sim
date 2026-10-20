class_name Rooms
extends Node

# Internet play with no server of our own: peers connect directly with WebRTC (P2P, NAT punching via
# free public STUN); the offer/answer/ICE handshake travels over free public MQTT brokers, keyed by a
# 5-letter room code. Game RPCs are unchanged: this only provides the WebRTCMultiplayerPeer.
# The host always makes the offer (star topology), so there is no glare. Very strict NAT pairs need a
# TURN relay: the player adds their own credentials (settings.cfg turn_* or TPS_TURN_* env, see NOTES.md).
# Once connected the broker is only needed for new joiners: a broker outage never stops a running game.
const MQTT := preload("res://addons/mqtt/mqtt.gd")
const BROKERS := ["wss://broker.hivemq.com:8884/mqtt", "wss://broker.emqx.io:8084/mqtt", "wss://test.mosquitto.org:8081"]
const PREFIX := "toyplanesim/v1/"
const STUN := ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"] # two operators; more only slows gathering
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const PEER_TIMEOUT := 20000 # ms from offer to open data channels
const KNOCK_MS := 2000
const MAX_PENDING := 8 # peers mid-handshake; caps spam on a public topic
const NAT_TIP := "This usually means a strict NAT or firewall on one side. Try another network (e.g. a phone hotspot) or add a TURN server: see How to play > Internet tips."

signal status(text: String)
signal failed(text: String) # client only: this join attempt is over

var mqtt: Node
var code := ""
var hosting := false
var my_id := 0
var session := "" # host: random per room; client: the host session it locked onto
var rtc := WebRTCMultiplayerPeer.new()
var conns := {} # peer id -> WebRTCPeerConnection
var sent := {} # peer id -> our signaling messages, repeated when the other side knocks again
var queued := {} # peer id -> ICE candidates that arrived before the remote description
var remote := {} # peer id -> true once the remote description is set
var started := {} # peer id -> ticks when negotiation began; erased once connected
var seen := {} # exact duplicate messages (brokers and our own repeats)
var broker_i := 0
var broker_fails := 0
var broker_up := false
var broker_retry := 0 # ticks of the next reconnect attempt, 0 = none pending
var knock_at := 0
var knocks := 0
var phase := ""
var done := false


func host() -> WebRTCMultiplayerPeer:
	hosting = true
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	session = "%x" % randi()
	rtc.create_server()
	_connect_broker()
	return rtc


func join(room: String) -> WebRTCMultiplayerPeer:
	code = room.strip_edges().to_upper()
	my_id = randi_range(2, 2147483646) # fresh per attempt: a rejoin never sees the last attempt's messages
	rtc.create_client(my_id)
	_connect_broker()
	return rtc


# TURN relays the pairs STUN can't punch through. Credentials are the player's own, never shipped.
static func ice() -> Dictionary:
	var urls := OS.get_environment("TPS_TURN_URLS")
	var user := OS.get_environment("TPS_TURN_USERNAME")
	var cred := OS.get_environment("TPS_TURN_CREDENTIAL")
	if urls == "":
		urls = str(Settings.values.get("turn_urls", ""))
		user = str(Settings.values.get("turn_username", ""))
		cred = str(Settings.values.get("turn_credential", ""))
	var servers: Array = [{urls = STUN}]
	var list := Array(urls.replace(" ", "").split(",", false))
	if list:
		servers.append({urls = list, username = user, credential = cred})
	return {iceServers = servers}


func _connect_broker() -> void:
	if mqtt:
		mqtt.queue_free()
	broker_up = false
	mqtt = MQTT.new()
	mqtt.client_id = "tps%d" % randi()
	mqtt.verbose_level = 0
	add_child(mqtt)
	mqtt.broker_connected.connect(_on_broker)
	mqtt.broker_connection_failed.connect(_on_broker_lost) # also fires when a live connection drops
	mqtt.received_message.connect(_on_message)
	if not _joined():
		status.emit("Contacting matchmaking (%d/%d)..." % [broker_i + 1, BROKERS.size()])
	mqtt.connect_to_broker(BROKERS[broker_i])


# Try each broker once, then back off (2..30 s, jittered so many players don't retry in lockstep).
func _on_broker_lost() -> void:
	broker_up = false
	if done or (not hosting and _joined()):
		return
	broker_i = (broker_i + 1) % BROKERS.size()
	broker_fails += 1
	if broker_fails < BROKERS.size():
		_connect_broker()
		return
	var wait := minf(30.0, pow(2.0, broker_fails - BROKERS.size() + 1)) * randf_range(0.5, 1.0)
	broker_retry = Time.get_ticks_msec() + int(wait * 1000.0)
	if hosting:
		status.emit("Matchmaking service unreachable, retrying in %d s. Games in progress keep running; new players can join once it's back." % ceili(wait))
	else:
		status.emit("Can't reach the matchmaking service, retrying in %d s. Check your internet connection." % ceili(wait))


func _on_broker() -> void:
	broker_up = true
	broker_fails = 0
	if hosting:
		mqtt.subscribe(_topic("host"))
		status.emit("Room ready")
	else:
		mqtt.subscribe(_topic("p/%d" % my_id))
		status.emit("Looking for room %s..." % code)
		knock_at = 0


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if broker_retry and now >= broker_retry:
		broker_retry = 0
		_connect_broker()
	if not hosting and not done and broker_up and now >= knock_at:
		_knock(now)
	for id in conns.keys():
		if started.has(id):
			_check_peer(id, now)


# Public brokers are fire-and-forget: keep knocking until the host answers, then keep repeating our
# answer + candidates until the channels open. Rotating brokers finds a host that fell back to another.
func _knock(now: int) -> void:
	knock_at = now + KNOCK_MS
	if conns.has(1):
		for m in sent.get(1, []):
			_send("host", m)
		return
	knocks += 1
	if knocks > 15:
		_fail("Room %s not found. Check the code and that the host is waiting in the lobby." % code)
		return
	if knocks % 5 == 0:
		broker_i = (broker_i + 1) % BROKERS.size()
		_connect_broker()
		return
	_send("host", {t = "hello", id = my_id})


func _check_peer(id: int, now: int) -> void:
	var c: WebRTCPeerConnection = conns[id]
	var st := c.get_connection_state()
	if rtc.has_peer(id) and rtc.get_peer(id).connected:
		started.erase(id)
		if not hosting:
			mqtt.queue_free() # done with signaling; the game no longer depends on the broker
			mqtt = null
			broker_up = false
		return
	# WebRTCMultiplayerPeer drops a peer on its own once it fails/closes; disconnected is retried by
	# the game's rejoin path (60 s), so here we only time out and clean up.
	var gone := not rtc.has_peer(id) or st in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED]
	if not gone and now - started[id] < PEER_TIMEOUT:
		if not hosting:
			var p: String = ["negotiating", "checking network routes", "opening game channels"][clampi(st, 0, 2)]
			if p != phase:
				phase = p
				status.emit("Room found, connecting: %s..." % p)
		return
	var why := "connection failed" if gone else "timed out while %s" % ["negotiating", "checking network routes", "opening game channels"][clampi(st, 0, 2)]
	print("rooms: peer %d %s (state %d, gathering %d)" % [id, why, st, c.get_gathering_state()])
	forget(id)
	if hosting:
		status.emit("A player couldn't connect (%s). %s" % [why, NAT_TIP])
	else:
		_fail("Couldn't open a direct connection to the host (%s). %s" % [why, NAT_TIP])


func _fail(text: String) -> void:
	if done:
		return
	done = true
	status.emit(text)
	failed.emit(text)


func _on_message(_topic_name: String, message) -> void:
	var raw := str(message)
	if raw.length() > 20000:
		return
	var m = JSON.parse_string(raw)
	if not m is Dictionary or not m.get("t") is String:
		return
	if m.t != "hello":
		if seen.has(raw):
			return
		if seen.size() > 1000:
			seen.clear()
		seen[raw] = true
	if hosting:
		var id := int(m.get("id", 0)) if m.get("id") is float else 0
		if id < 2:
			return
		if m.t != "hello" and m.get("s") != session:
			return # answer/candidate meant for an earlier room or another host with the same code
		match m.t:
			"hello":
				if conns.has(id):
					for s in sent.get(id, []):
						_send("p/%d" % id, s)
				elif started.size() < MAX_PENDING and not rtc.has_peer(id):
					var c := _new_conn(id)
					if c:
						rtc.add_peer(c, id)
						c.create_offer()
			"answer":
				if conns.has(id) and not remote.has(id) and m.get("sdp") is String:
					_set_remote(id, "answer", m.sdp)
			"ice":
				_on_ice(id, m)
	else:
		if session != "" and m.get("s") != session:
			return
		match m.t:
			"offer":
				if conns.has(1) or done or not m.get("sdp") is String or not m.get("s") is String:
					return
				session = m.s
				var c := _new_conn(1)
				if not c:
					return
				rtc.add_peer(c, 1)
				_set_remote(1, "offer", m.sdp)
			"ice":
				_on_ice(1, m)


# Candidates can outrun the description they belong to (separate messages, any broker): hold them.
func _on_ice(id: int, m: Dictionary) -> void:
	if not (m.get("mid") is String and m.get("idx") is float and m.get("name") is String):
		return
	if remote.has(id):
		conns[id].add_ice_candidate(m.mid, int(m.idx), m.name)
	elif (conns.has(id) or not hosting) and queued.get(id, []).size() < 64:
		if not queued.has(id):
			queued[id] = []
		queued[id].append(m)


func _set_remote(id: int, type: String, sdp: String) -> void:
	if conns[id].set_remote_description(type, sdp) != OK:
		return
	remote[id] = true
	for m in queued.get(id, []):
		if m.get("s") == session:
			conns[id].add_ice_candidate(m.mid, int(m.idx), m.name)
	queued.erase(id)


func _new_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	if c.initialize(ice()) != OK:
		push_warning("rooms: ICE config rejected (check turn_urls), using STUN only")
		c = WebRTCPeerConnection.new()
		if c.initialize({iceServers = [{urls = STUN}]}) != OK:
			_fail("Online rooms aren't available in this build (WebRTC library missing). Use Host on LAN.")
			return null
	c.session_description_created.connect(func(type: String, sdp: String):
		if conns.has(id): # not `c`: capturing it would keep the connection alive forever
			conns[id].set_local_description(type, sdp)
			_signal(id, {t = type, sdp = sdp}))
	c.ice_candidate_created.connect(func(mid: String, idx: int, name: String):
		_signal(id, {t = "ice", mid = mid, idx = idx, name = name}))
	conns[id] = c
	sent[id] = []
	started[id] = Time.get_ticks_msec()
	return c


func _signal(id: int, msg: Dictionary) -> void:
	msg.s = session
	if not hosting:
		msg.id = my_id
	if sent.has(id):
		sent[id].append(msg)
	_send("p/%d" % id if hosting else "host", msg)


func forget(id: int) -> void:
	if conns.has(id):
		conns[id].close()
	if rtc.has_peer(id):
		rtc.remove_peer(id)
	for d in [conns, sent, queued, remote, started]:
		d.erase(id)


func _joined() -> bool:
	return not hosting and rtc.has_peer(1) and rtc.get_peer(1).connected


func _send(sub: String, msg: Dictionary) -> void:
	if mqtt and broker_up:
		mqtt.publish(_topic(sub), JSON.stringify(msg))


func _topic(sub: String) -> String:
	return PREFIX + code + "/" + sub
