class_name Rooms
extends Node

# Internet play with no server of our own: peers connect directly with WebRTC (P2P, NAT punching via
# free public STUN); the offer/answer/ICE handshake travels over free public MQTT brokers, keyed by a
# 5-letter room code. Game RPCs are unchanged: this only provides the WebRTCMultiplayerPeer.
# ponytail: STUN only, so two very strict NATs (some carrier-grade NAT pairs) can fail; add a free TURN
# entry to ICE (e.g. ExpressTURN credentials) to relay those.
const MQTT := preload("res://addons/mqtt/mqtt.gd")
const BROKERS := ["wss://broker.hivemq.com:8884/mqtt", "wss://broker.emqx.io:8084/mqtt", "wss://test.mosquitto.org:8081"]
const PREFIX := "toyplanesim/v1/"
const ICE := {iceServers = [{urls = ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302", "stun:stun.cloudflare.com:3478"]}]}
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

signal status(text: String)

var mqtt: Node
var code := ""
var hosting := false
var my_id := 0
var rtc := WebRTCMultiplayerPeer.new()
var conns := {} # peer id -> WebRTCPeerConnection
var offers := {} # peer id -> offer sdp (re-sent if the client repeats hello)
var broker_i := 0
var got_offer := false


func host() -> WebRTCMultiplayerPeer:
	hosting = true
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	rtc.create_server()
	_connect_broker()
	return rtc


func join(room: String) -> WebRTCMultiplayerPeer:
	code = room.strip_edges().to_upper()
	my_id = randi_range(2, 2147483646)
	rtc.create_client(my_id)
	_connect_broker()
	return rtc


func _connect_broker() -> void:
	if mqtt:
		mqtt.queue_free()
	mqtt = MQTT.new()
	mqtt.client_id = "tps%d" % randi()
	mqtt.verbose_level = 0
	add_child(mqtt)
	mqtt.broker_connected.connect(_on_broker)
	mqtt.broker_connection_failed.connect(_next_broker)
	mqtt.received_message.connect(_on_message)
	status.emit("Contacting matchmaking (%d/%d)..." % [broker_i + 1, BROKERS.size()])
	mqtt.connect_to_broker(BROKERS[broker_i])


func _next_broker() -> void:
	broker_i += 1
	if broker_i >= BROKERS.size():
		status.emit("No matchmaking service reachable. Check your internet.")
		return
	_connect_broker()


func _on_broker() -> void:
	if hosting:
		mqtt.subscribe(_topic("host"))
		status.emit("Room ready")
	else:
		mqtt.subscribe(_topic("p/%d" % my_id))
		status.emit("Looking for room %s..." % code)
		_say_hello()


# Until the host answers, keep knocking (public brokers are fire-and-forget).
func _say_hello() -> void:
	for i in 15:
		if got_offer or not is_inside_tree():
			return
		_send("host", {t = "hello", id = my_id})
		await get_tree().create_timer(2.0).timeout
	if not got_offer:
		status.emit("Room %s not found. Check the code and that the host is waiting in the lobby." % code)


func _on_message(topic: String, message) -> void:
	var m = JSON.parse_string(str(message))
	if not m is Dictionary:
		return
	if hosting:
		var id := int(m.get("id", 0))
		if id < 2:
			return
		match m.get("t"):
			"hello":
				if offers.has(id):
					_send("p/%d" % id, {t = "offer", sdp = offers[id]})
				elif not conns.has(id):
					var c := _new_conn(id)
					rtc.add_peer(c, id)
					c.create_offer()
			"answer":
				if conns.has(id):
					conns[id].set_remote_description("answer", str(m.sdp))
			"ice":
				if conns.has(id):
					conns[id].add_ice_candidate(str(m.mid), int(m.idx), str(m.name))
	else:
		match m.get("t"):
			"offer":
				if got_offer:
					return
				got_offer = true
				status.emit("Room found, connecting...")
				var c := _new_conn(1)
				rtc.add_peer(c, 1)
				c.set_remote_description("offer", str(m.sdp))
			"ice":
				if conns.has(1):
					conns[1].add_ice_candidate(str(m.mid), int(m.idx), str(m.name))


func _new_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize(ICE)
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		if hosting:
			offers[id] = sdp
			_send("p/%d" % id, {t = type, sdp = sdp})
		else:
			_send("host", {t = type, id = my_id, sdp = sdp}))
	c.ice_candidate_created.connect(func(mid: String, idx: int, name: String):
		if hosting:
			_send("p/%d" % id, {t = "ice", mid = mid, idx = idx, name = name})
		else:
			_send("host", {t = "ice", id = my_id, mid = mid, idx = idx, name = name}))
	conns[id] = c
	return c


func forget(id: int) -> void:
	conns.erase(id)
	offers.erase(id)


func _send(sub: String, msg: Dictionary) -> void:
	if mqtt:
		mqtt.publish(_topic(sub), JSON.stringify(msg))


func _topic(sub: String) -> String:
	return PREFIX + code + "/" + sub
