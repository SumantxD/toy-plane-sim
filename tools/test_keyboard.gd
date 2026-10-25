extends SceneTree
# Drives the menus with simulated keys (W/A/S/D and arrows), then checks the paused plane ignores the
# keyboard: godot --path . -s tools/test_keyboard.gd   (needs a window: menu focus is off when headless)
func _key(k: Key, frames := 1) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		for f in (frames if pressed else 1):
			await process_frame
	await process_frame


func _focus() -> String:
	var f := root.gui_get_focus_owner()
	if f is Menus.Selector:
		return "selector " + f.title.text
	return f.text if f and "text" in f else str(f)


func _turn(p: Node3D, k: Key) -> float:
	var before := p.quaternion
	await _key(k, 40)
	return rad_to_deg(before.angle_to(p.quaternion))


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 8:
		await process_frame
	print("main menu focus: ", _focus())
	await _key(KEY_S)
	await _key(KEY_S)
	await _key(KEY_S) # past QUICK BATTLE
	print("after S S S: ", _focus())
	await _key(KEY_ENTER)
	print("multiplayer screen: ", main.mp_root.visible, "  focus: ", _focus())
	await _key(KEY_ESCAPE)
	await process_frame
	print("after Esc -> main menu: ", main.menu_root.visible)
	for i in 3:
		await _key(KEY_W)
	await _key(KEY_S) # QUICK BATTLE -> BATTLE VS AI
	print("after W W W S: ", _focus())
	await _key(KEY_ENTER)
	for i in 20:
		await process_frame
	print("lobby: ", main.gs.phase, "  focus: ", _focus(), "  world ", main.gs.world)
	await _key(KEY_D)
	for i in 30:
		await process_frame
	print("after D -> world ", main.gs.world, "  focus: ", _focus())
	await _key(KEY_S)
	print("after S: ", _focus())
	for i in 8: # down to LAUNCH (the hangar column sits further down on the right)
		if _focus() == "LAUNCH":
			break
		await _key(KEY_S)
	print("after S to LAUNCH: ", _focus())
	await _key(KEY_ENTER)
	for i in 240:
		await process_frame
	print("after Enter -> phase: ", main.gs.phase)
	var p: Node3D = main._plane(main.multiplayer.get_unique_id())
	print("unpaused, Down held: plane turned %.1f deg" % await _turn(p, KEY_DOWN))
	await _key(KEY_ESCAPE)
	print("paused: ", main.pause_root.visible, "  focus: ", _focus())
	print("paused, Down held:   plane turned %.1f deg  (menu focus now: %s)" % [await _turn(p, KEY_DOWN), _focus()])
	print("paused, S held:      plane turned %.1f deg" % await _turn(p, KEY_S))
	quit()
