extends SceneTree
# App Review screenshot for each in-app purchase: the Hangar Shop open on it, previewed on the plane.
#   godot --path . --resolution 2868x1320 -s tools/iap_shots.gd -- --phone --fake-store
# Writes ../builds/appstore/iap/<product>.png
const OUT := "res://../builds/appstore/iap/"


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for p in Shop.PRODUCTS:
		main.shop_ui.open(p)
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + p + ".png"))
		print("saved ", p)
	quit()
