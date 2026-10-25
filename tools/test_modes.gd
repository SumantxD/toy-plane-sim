extends SceneTree
# Every vs-AI / solo mode with simulated fingers: godot --path . --resolution 1311x603 -s tools/test_modes.gd -- --touch <mode>
# Launches the mode, then fires every weapon from its thumb button and flies 20 s; prints one line per check.
var main: Node
var tc: Control


func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.pressed = down
	Input.parse_input_event(e)


func _hold(id: String, frames: int) -> void:
	var at: Vector2 = tc._center(id)
	_touch(at, true, 1)
	for i in frames:
		await process_frame
	_touch(at, false, 1)
	for i in 5:
		await process_frame


func _initialize() -> void:
	var mode := int(OS.get_cmdline_user_args()[-1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20:
		await process_frame
	tc = main.find_children("*", "TouchControls", true, false)[0]
	if mode == 2:
		main.free_flight()
	else:
		main.solo_battle()
		await create_timer(0.3).timeout
		main.request_mode(mode)
		await create_timer(0.3).timeout
		main.request_start()
	var t0 := Time.get_ticks_msec()
	while (main.gs.get("countdown", 1.0) > 0.0 or main._plane(1) == null) and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	for i in 30:
		await process_frame
	var p: Node = main._plane(1)
	print("MODE %d %s: phase=%s plane=%s touch=%s phone_card=%s" % [mode, main.MODES[mode], main.gs.phase, p != null, tc.visible, "Drag on the left" in main.keys_label.text])
	if not p:
		quit(1)
		return
	var shown: Array = tc.ELEMS.filter(func(e): return tc._shown(e.id)).map(func(e): return e.id)
	print("  buttons: ", " ".join(shown), "   BUY offers: ", tc._fan_items("supply").map(func(it): return it[0]) if "supply" in shown else "-")
	var most := 0
	_touch(tc._center("fire"), true, 1)
	for i in 50:
		await process_frame
		most = maxi(most, main.bullets.shots.filter(func(s): return s.owner == p).size())
	_touch(tc._center("fire"), false, 1)
	var r0: int = p.rockets_left
	await _hold("rocket", 150) # hold for a lock (or an unguided shot), release fires
	var b0: int = p.bombs_left
	await _hold("bomb", 20)
	var f0: int = p.flares_left
	await _hold("flare", 3)
	var boost0: float = p.boost
	await _hold("boost", 40)
	print("  FIRE rounds=%d  ROCKET %d->%d  BOMB %d->%d  FLARE %d->%d  BOOST %.2f->%.2f" % [most, r0, p.rockets_left, b0, p.bombs_left, f0, p.flares_left, boost0, p.boost])
	var deaths: int = main.gs.players[1].deaths
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and main.gs.phase == "playing":
		await process_frame
	print("  20 s later: phase=%s  you: %d kills %d deaths   feed: %s" % [main.gs.phase, main.gs.players[1].kills, main.gs.players[1].deaths - deaths, main.gs.feed.slice(-2)])
	quit()
