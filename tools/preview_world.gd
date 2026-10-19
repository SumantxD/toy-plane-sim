extends SceneTree
# Renders a world from several viewpoints: godot --path . -s tools/preview_world.gd -- <index> [extra shots...]
# Saves /tmp/world_<name>_<n>.png. A world's def() may list extra cameras in "shots": [[eye, target], ...].
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := int(args[0]) if args.size() > 0 else 0
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var t0 := Time.get_ticks_msec()
	main._build_world_content(i)
	print("world %s built in %d ms, %d obstacles" % [Worlds.LIST[i], Time.get_ticks_msec() - t0, main.obstacles.size()])
	main.menu_root.hide()
	var shots := [
		[Vector3(0, 900, 2700), Vector3(0, 0, 0)],          # overview
		[Vector3(1300, 200, 1100), Vector3(-200, 120, -500)], # low along the bomber route
		[Vector3(-120, 110, 2550), Vector3(0, 14, 1900)],    # home airfield
		[Vector3(250, 260, -1150), Vector3(0, 60, -1800)],   # enemy factory
	]
	shots.append_array(Worlds.cur.get("shots", []))
	var n := 0
	for s in shots:
		main.lobby_cam.look_at_from_position(s[0], s[1])
		for k in 30:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/world_%s_%d.png" % [Worlds.LIST[i], n])
		n += 1
	print("saved %d shots" % n)
	quit()
