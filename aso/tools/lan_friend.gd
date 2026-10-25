extends SceneTree
# A second game instance that joins a room as a named pilot, flying with the game's own --bot brain.
#   godot --headless --path . -s aso/tools/lan_friend.gd -- --bot --name Riya --addr 127.0.0.1:7853|ROOMCODE
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.name_edit.text = a[a.find("--name") + 1]
	main.address.text = a[a.find("--addr") + 1]
	main.join()
