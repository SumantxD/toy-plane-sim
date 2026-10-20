extends SceneTree
# Close-range quality pass (shadows, z-fighting, floating props): godot --path . -s tools/audit_world.gd -- <world> <out_dir>
# Saves <out_dir>/audit_<world>_<n>_<label>.png from gameplay-height viewpoints.
const Aircraft := preload("res://plane.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := int(args[0]) if args.size() > 0 else 0
	var out: String = args[1] if args.size() > 1 else "/tmp"
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._build_world_content(i)
	main.gs.mode = 4
	main.objectives.reset(main.gs)
	main.menu_root.hide()
	var ground := func(x: float, z: float) -> float: return Terrain.floor_below(Vector3(x, 3000, z))
	var hq0: Vector3 = main.objectives.hqs[0].position
	var hq1: Vector3 = main.objectives.hqs[1].position
	var rr := Vector3(Props.RED_RUNWAY.x, 0, Props.RED_RUNWAY.y)
	rr.y = ground.call(rr.x, rr.z)
	var shots := {
		"blue_runway": [Vector3(-90, ground.call(-90, 1700) + 35, 1700), Vector3(40, ground.call(40, 1850), 1850)],
		"flight_120": [Vector3(300, ground.call(300, 900) + 120, 900), Vector3(0, ground.call(0, 300), 300)],
		"flight_300": [Vector3(-200, ground.call(-200, 1300) + 300, 1300), Vector3(0, ground.call(0, 200), 200)],
		"red_runway": [rr + Vector3(160, 60, 160), rr],
		"blue_hq_flag": [hq0 + Vector3(90, 45, -90), hq0],
		"red_hq_flag": [hq1 + Vector3(-90, 45, 90), hq1],
		"factory": [Vector3(Props.FACTORY.x + 180, ground.call(Props.FACTORY.x, Props.FACTORY.y) + 70, Props.FACTORY.y + 180), Vector3(Props.FACTORY.x, ground.call(Props.FACTORY.x, Props.FACTORY.y), Props.FACTORY.y)],
		"hillside": [Vector3(700, ground.call(700, 300) + 70, 300), Vector3(400, ground.call(400, 0), 0)],
	}
	var k := 0
	for key in Props.spots:
		if k >= 3:
			break
		var at: Vector3 = Props.spots[key]
		shots["spot_" + key] = [at + Vector3(110, 55, 110), at]
		k += 1
	# A plane low over the runway: does it cast a shadow, does the shadow sit right?
	var p := Aircraft.new()
	p.kind = "twin"
	p.is_ai = true
	p.role = "showcase"
	p.pilot = "Shadow test"
	p.position = Vector3(0, ground.call(0, 1900) + 18, 1900)
	main.players.add_child(p)
	await process_frame
	p.set_process(false)
	shots["plane_shadow"] = [p.position + Vector3(25, 14, 30), p.position + Vector3(0, -8, 0)]
	var n := 0
	for label in shots:
		var s: Array = shots[label]
		main.lobby_cam.fov = 70
		main.lobby_cam.look_at_from_position(s[0], s[1])
		for f in 25:
			await process_frame
		root.get_texture().get_image().save_png("%s/audit_%d_%02d_%s.png" % [out, i, n, label])
		n += 1
	print("audit %s: %d shots" % [Worlds.LIST[i], n])
	quit()
