extends SceneTree
# Plays the phone build with simulated fingers: menu taps, launch, fire, steer, pause, resume.
# godot --path . --resolution 1340x618 -s tools/test_touch.gd -- --touch   (needs a window)
var main: Node


func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * at # viewport -> window pixels
	e.pressed = down
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2, finger := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.relative = rel
	Input.parse_input_event(e)


func _shot(name: String) -> void: # with --shots: save what the screen shows
	if "--shots" in OS.get_cmdline_user_args():
		await process_frame
		root.get_texture().get_image().save_png("/tmp/touch_%s.png" % name)


func _tap(at: Vector2) -> void:
	_touch(at, true)
	_drag(at, Vector2.ZERO) # a still finger (the desktop's real cursor must not drag it off the button)
	await process_frame
	_drag(at, Vector2.ZERO)
	_touch(at, false)
	for i in 10:
		await process_frame


func _button(parent: Node, text: String) -> Control:
	for c in parent.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and "text" in c and str(c.text).strip_edges() == text:
			return c
	return null


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await process_frame
	var tc: Control = main.find_children("*", "TouchControls", true, false)[0]
	print("touch layer: ", tc != null, "   quit button shown: ", _button(main, "QUIT") != null)
	var b := _button(main, "BATTLE VS AI")
	await _tap(b.get_global_rect().get_center())
	for i in 30:
		await process_frame
	print("tap BATTLE VS AI -> phase ", main.gs.phase)
	b = _button(main, "LAUNCH")
	await _tap(b.get_global_rect().get_center())
	while main.gs.get("countdown", 1.0) > 0.0 or main._plane(1) == null:
		await process_frame
	for i in 20:
		await process_frame
	var p: Node = main._plane(1)
	print("tap LAUNCH -> phase ", main.gs.phase, "   controls visible: ", tc.visible)
	var fire: Vector2 = tc._center("fire")
	var most := 0
	_touch(fire, true, 1)
	for i in 60:
		await process_frame
		most = maxi(most, main.bullets.shots.filter(func(s): return s.owner == p).size())
	_touch(fire, false, 1)
	print("hold FIRE 1 s -> your rounds in the air: ", most)
	var yaw0: float = p.rotation.y
	var at := Vector2(200, tc.size.y - 140)
	_touch(at, true, 2)
	await process_frame
	_drag(at + Vector2(80, 0), Vector2(80, 0), 2)
	for i in 90:
		await process_frame
	_touch(at + Vector2(80, 0), false, 2)
	print("stick right 1.5 s -> heading changed %.0f deg" % rad_to_deg(absf(angle_difference(yaw0, p.rotation.y))))
	await _tap(tc._center("pause"))
	print("tap II -> pause menu: ", main.pause_root.visible)
	b = _button(main.pause_root, "RESUME")
	await _tap(b.get_global_rect().get_center())
	print("tap RESUME -> pause menu: ", main.pause_root.visible, "   controls visible: ", tc.visible)
	var thr: Rect2 = tc._throttle_rect()
	await _tap(thr.position + Vector2(thr.size.x / 2, thr.size.y * 0.1))
	print("tap top of throttle -> throttle %.0f%%" % (p.throttle * 100))
	var bank: int = main.gs.bank[p.team]
	p.position.y = Terrain.floor_below(p.position) + 150.0
	await _tap(tc._center("supply"))
	await _shot("buy")
	print("tap BUY -> menu open: ", tc.fan == "supply", " (", tc._fan_items("supply").size(), " choices)")
	await _tap(tc._fan_spots("supply")[0])
	for i in 10:
		await process_frame
	print("tap AA GUN -> supplies %d -> %d" % [bank, main.gs.bank[p.team]])
	await _tap(tc._center("team"))
	var pings: int = main.pings.size()
	await _tap(tc._fan_spots("team")[0])
	for i in 5:
		await process_frame
	print("tap TEAM, HELP! -> team pings %d -> %d" % [pings, main.pings.size()])
	var states := []
	for i in 3:
		await _tap(tc._center("map"))
		states.append("%s/%.1f" % [main.show_map, main.map_zoom])
	print("tap MAP x3 -> ", states)
	Settings.values.autofire = true
	var foe: Node = null
	for q in main.players.get_children():
		if q.team != p.team and q.alive and q.role == "wing":
			foe = q
			break
	most = 0
	for i in 40:
		foe.position = p.position - p.basis.z * 150.0
		foe.velocity = p.velocity
		await process_frame
		most = maxi(most, main.bullets.shots.filter(func(s): return s.owner == p).size())
	Settings.values.autofire = false
	print("auto-fire, enemy dead ahead (no finger on FIRE) -> rounds in the air: ", most)
	# layout editor, from Settings
	await _tap(tc._center("pause"))
	await _tap(_button(main.pause_root, "SETTINGS").get_global_rect().get_center())
	await _tap(_button(main.settings_root, "Touch controls...").get_global_rect().get_center())
	print("Settings > Touch controls -> screen open: ", main.touch_root.visible)
	await _shot("settings")
	var cl := _button(main.touch_root, "Customize layout")
	await _tap(cl.get_global_rect().get_center())
	print("Customize layout -> editor: ", tc.editing)
	var f0: Vector2 = tc._center("fire")
	_touch(f0, true)
	await process_frame
	for k in 10:
		_drag(f0 + Vector2(-20 * (k + 1), -10 * (k + 1)), Vector2(-20, -10))
		await process_frame
	_touch(f0 + Vector2(-200, -100), false)
	await process_frame
	await _tap(tc._tool_rect(1).get_center()) # BIGGER
	await _shot("editor")
	print("drag FIRE + BIGGER -> moved %s, size x%.2f" % [tc._center("fire") - f0, tc._scale("fire")])
	await _tap(tc._tool_rect(3).get_center()) # DONE
	var saved := ConfigFile.new()
	saved.load(Settings.PATH)
	print("DONE -> editor: ", tc.editing, "   saved layout: ", saved.get_value("prefs", "touch_layout", {}).has("fire"))
	var x0: float = tc._center("fire").x
	Settings.values.touch_lefty = true
	print("left-handed -> FIRE x %.0f -> %.0f (screen %.0f wide)" % [x0, tc._center("fire").x, tc.size.x])
	Settings.values.touch_lefty = false
	Settings.values.touch_layout = {}
	Settings.save()
	quit()
