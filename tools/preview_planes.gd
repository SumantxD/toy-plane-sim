extends SceneTree
# Lineup of all plane types (+ a damaged one) for visual checks: godot --path . -s tools/preview_planes.gd
const Aircraft := preload("res://plane.gd")

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var x := -36.0
	for k in Planes.ORDER + ["cub"]:
		var p := Aircraft.new()
		p.kind = k
		p.is_ai = true
		p.role = "showcase"
		p.pilot = Planes.TYPES[k].name
		p.position = Vector3(x, 400, 0)
		p.rotation_degrees = Vector3(0, 150, 0)
		main.players.add_child(p)
		x += 18.0
	await process_frame
	var hurt: Node = main.players.get_child(main.players.get_child_count() - 1)
	hurt.alive = true
	hurt.set_hp(40, PackedFloat32Array([0.0, 1.0, 0.0, 0.5]))
	main.set_process(false)
	for p in main.players.get_children():
		p.set_process(false)
	main.lobby_cam.look_at_from_position(Vector3(10, 412, -38), Vector3(0, 400, 0))
	main.lobby_cam.fov = 50
	main.menu_root.hide()
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/planes.png")
	quit()
