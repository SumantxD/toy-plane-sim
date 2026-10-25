extends SceneTree
# Pilot-name filter: godot --headless --path . -s tools/test_names.gd
const Main := preload("res://main.gd")


func _initialize() -> void:
	for ok in ["Ace", "Pilot42", "Maverick_99", "Sumant", "Rohit", "Skyler", "Arjun", "Biscuit", "Cockpit", "Peacock", "Dickens", "Hancock", "Scunthorpe", "Torpedo", "Cumulus"]:
		assert(Main.clean_name(ok), ok)
	for bad in ["fuck", "F.U.C.K", "sh1t", "b!tch", "BSDK", "MadarChod", "n1gga", "xxPORNxx", "retard", "Ph.U.C.K", "FvCk", "pedo", "CockpitFuck", "sexy"]:
		assert(not Main.clean_name(bad), bad)
	print("names ok")
	quit()
