extends SceneTree
# Close-up of the four turret types at the home airfield: godot --path . -s tools/preview_turrets.gd
func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.menu_root.hide()
	var shots := 0
	for i in [0, 1, 2, 4]: # flak, rapid, sam, radar
		var t: Node3D = main.battlefield.guns[i]
		main.lobby_cam.look_at_from_position(t.global_position + Vector3(-40, 22, 32), t.global_position + Vector3(0, 6, 0))
		for k in 25:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/turret_%s.png" % t.kind)
		print(t.kind, " at ", t.global_position, " visible ", t.visible)
	quit()
