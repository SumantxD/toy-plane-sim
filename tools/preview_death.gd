extends SceneTree
# Shoots down one plane and photographs the fall and the crash: godot --path . -s tools/preview_death.gd
const Aircraft := preload("res://plane.gd")

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.menu_root.hide()
	var p := Aircraft.new()
	p.kind = "fighter"
	p.is_ai = true
	p.role = "showcase"
	p.pilot = "Doomed"
	p.team = 1
	p.position = Vector3(300, 420, 900)
	p.rotation_degrees = Vector3(0, 90, 0)
	main.players.add_child(p)
	await process_frame
	p.velocity = -p.basis.z * 90.0
	p.set_process(false)
	p.set_hp(20, PackedFloat32Array([1, 0.4, 0.0, 1]))
	await create_timer(1.0).timeout
	_shot(main, p.position, "/tmp/death_0_burning.png")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/death_0_burning.png")
	p.die(true)
	var w: Node3D = main.get_children().filter(func(c): return c is Fx.Wreck)[0]
	for i in 3:
		await create_timer(1.1).timeout
		if is_instance_valid(w):
			_shot(main, w.global_position, "")
			await process_frame
			root.get_texture().get_image().save_png("/tmp/death_%d_fall.png" % (i + 1))
	var last: Vector3 = w.global_position if is_instance_valid(w) else Vector3.ZERO
	while is_instance_valid(w):
		last = w.global_position
		await process_frame
	var eye := last + Vector3(-110, 0, -80)
	eye.y = maxf(last.y, Terrain.height(eye.x, eye.z)) + 90.0
	main.lobby_cam.look_at_from_position(eye, last + Vector3.UP * 10)
	await create_timer(0.25).timeout
	root.get_texture().get_image().save_png("/tmp/death_4_impact.png")
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png("/tmp/death_5_site.png")
	quit()

func _shot(main: Node, target: Vector3, _path: String) -> void:
	main.lobby_cam.look_at_from_position(target + Vector3(-60, 25, -40), target)
