extends SceneTree
# Renders the lobby's world picker pictures: godot --path . -s tools/make_thumbs.gd -> assets/ui/worlds/<name>.png
const EYE := Vector3(700, 330, 1650)
const LOOK := Vector3(-150, 60, -200)


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.menu_root.hide()
	main.set_process(false)
	for i in Worlds.LIST.size():
		main._build_world_content(i)
		var ground := Terrain.floor_below(Vector3(EYE.x, 3000, EYE.z))
		main.lobby_cam.fov = 60
		main.lobby_cam.look_at_from_position(EYE + Vector3.UP * ground, LOOK + Vector3.UP * Terrain.floor_below(Vector3(LOOK.x, 3000, LOOK.z)))
		for f in 40:
			await process_frame
		var img := root.get_texture().get_image()
		img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/ui/worlds/%s.png" % Worlds.LIST[i])
	print("thumbs done")
	quit()
