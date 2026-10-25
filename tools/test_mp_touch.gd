extends SceneTree
# Phone-mode host plays Team Dogfight against joined players, all by touch:
#   godot --path . --resolution 1311x603 -s tools/test_mp_touch.gd -- --touch lan|online <players>
# then join bots: lan -> godot --headless -- --join --port 7810 --bot ; online -> --join-room $(cat /tmp/room.txt) --bot
var main: Node
var tc: Control


func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.pressed = down
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2, finger := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.relative = rel
	Input.parse_input_event(e)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var online := args[-2] == "online"
	var want := int(args[-1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20:
		await process_frame
	tc = main.find_children("*", "TouchControls", true, false)[0]
	if online:
		main.host_online()
		FileAccess.open("/tmp/room.txt", FileAccess.WRITE).store_string(main.room)
	else:
		main.host(7810)
	print("HOST %s up, room=%s" % ["online" if online else "LAN", main.room])
	var t0 := Time.get_ticks_msec()
	while main.gs.players.size() < want + 1 and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	print("joined: %d players after %.1f s" % [main.gs.players.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	main.request_mode(1)
	await create_timer(0.5).timeout
	main.request_start()
	t0 = Time.get_ticks_msec()
	while (main.gs.get("countdown", 1.0) > 0.0 or main._plane(1) == null) and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	var p: Node = main._plane(1)
	print("match: phase=%s mode=%s  planes in the sky: %d  touch=%s" % [main.gs.phase, main.MODES[main.gs.mode], main.players.get_child_count(), tc.visible])
	# fly for 45 s by touch: hold FIRE, weave with the stick, fire a rocket every so often
	var fire_at: Vector2 = tc._center("fire")
	var stick_at := Vector2(200, tc.size.y - 140)
	_touch(fire_at, true, 1)
	_touch(stick_at, true, 2)
	var shots := 0
	t0 = Time.get_ticks_msec()
	var k := 0
	while Time.get_ticks_msec() - t0 < 45000 and main.gs.phase == "playing":
		k += 1
		var off := Vector2(sin(k * 0.02) * 70.0, cos(k * 0.013) * 40.0)
		_drag(stick_at + off, off, 2)
		if k % 300 == 150:
			_touch(tc._center("rocket"), true, 3)
		if k % 300 == 290:
			_touch(tc._center("rocket"), false, 3)
		p = main._plane(1)
		if p:
			shots = maxi(shots, main.bullets.shots.filter(func(s): return s.owner == p).size())
		await process_frame
	_touch(fire_at, false, 1)
	_touch(stick_at, false, 2)
	print("after 45 s: most of your rounds in the air at once: %d" % shots)
	for id in main.gs.players:
		var pl: Dictionary = main.gs.players[id]
		print("  %-10s team %s  %d kills  %d deaths" % [pl.name, ["Blue", "Red"][pl.team], pl.kills, pl.deaths])
	print("  feed: ", main.gs.feed.slice(-3))
	quit()
