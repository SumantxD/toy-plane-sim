extends SceneTree
# App Store screenshots (6.9" iPhone, landscape 2868x1320) from real gameplay with the phone HUD:
#   godot --path . --resolution 2868x1320 -s tools/appstore_shots.gd -- --phone --fake-store
# Writes ../builds/appstore/1-battle.png ... 5-shop.png
const OUT := "res://../builds/appstore/"
var main: Node


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved %s %dx%d" % [name, img.get_width(), img.get_height()])


func _fresh() -> void:
	if main:
		main.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(0.6)


func _fly(world: int, mode: int) -> void:
	main.solo_battle()
	await _wait(0.3)
	main.request_world(world)
	await _wait(1.5)
	main.request_mode(mode)
	await _wait(0.3)
	main.request_start()
	while main.gs.get("countdown", 1.0) > 0.0 or main._plane(1) == null:
		await process_frame


func _initialize() -> void:
	Settings.load_saved()
	var keep := Settings.values.duplicate(true)
	Settings.values.matches = 20 # past the first-match tutorial cards
	Settings.values.name = "Ace"
	Settings.values.livery = 1
	Settings.values.banner = 7
	Settings.values.killfx = 1
	Settings.save()
	var cfg := ConfigFile.new() # the test store owns the Golden Ace set, so the hangar can wear it
	cfg.set_value("store", "owned", {"bundle.golden": true})
	cfg.save("user://fake_store.cfg")
	# 1: a dogfight in Green Valley, guns firing
	await _fresh()
	await _fly(0, 3)
	await _wait(9.0)
	var tc: Control = main.find_children("*", "TouchControls", true, false)[0]
	var e := InputEventScreenTouch.new()
	e.index = 1
	e.position = root.get_final_transform() * tc._center("fire")
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.6)
	await _shot("1-battle")
	e.pressed = false
	Input.parse_input_event(e)
	# 2: skywriting a taunt
	main.taunt_cd = 0
	main.send_taunt(12)
	await _wait(2.4)
	await _shot("2-taunt")
	# 3: Sky Kingdom
	await _fresh()
	await _fly(5, 2)
	await _wait(6.0)
	await _shot("3-sky-kingdom")
	# 4: mission setup
	await _fresh()
	main.solo_battle()
	await _wait(2.0)
	await _shot("4-mission-setup")
	# 5: the Hangar Shop
	await _fresh()
	main.shop_ui.open("bundle.golden")
	await _wait(1.5)
	await _shot("5-shop")
	Settings.values = keep
	Settings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg"))
	quit()
