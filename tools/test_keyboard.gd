extends SceneTree
# Drives the menus with simulated keys: godot --path . -s tools/test_keyboard.gd
func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame

func _focus(main: Node) -> String:
	var f := root.gui_get_focus_owner()
	return f.text if f and "text" in f else str(f)

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	print("menu focus: ", _focus(main))
	await _key(KEY_DOWN)
	print("after Down: ", _focus(main))
	await _key(KEY_ENTER)
	for i in 30:
		await process_frame
	print("after Enter -> phase: ", main.gs.phase, " mode: ", main.gs.mode)
	await _key(KEY_ESCAPE)
	print("after Esc -> paused: ", main.pause_root.visible, " focus: ", _focus(main))
	await _key(KEY_DOWN)
	print("after Down: ", _focus(main))
	await _key(KEY_ENTER)
	await process_frame
	print("after Enter -> settings open: ", main.settings_root.visible, " focus: ", _focus(main))
	await _key(KEY_ESCAPE)
	print("after Esc -> settings open: ", main.settings_root.visible, " paused: ", main.pause_root.visible, " focus: ", _focus(main))
	quit()
