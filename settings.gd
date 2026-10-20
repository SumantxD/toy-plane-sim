class_name Settings
extends RefCounted

# Player preferences, saved to user://settings.cfg. Bad or missing values fall back to defaults.
const PATH := "user://settings.cfg"
const DEFAULTS := {volume = 0.8, sensitivity = 1.0, invert_y = false, fullscreen = false, quality = 1, name = "", cam = 1}

static var values := DEFAULTS.duplicate()


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			var v = cfg.get_value("prefs", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
				values[k] = v
	values.volume = clampf(values.volume, 0.0, 1.0)
	values.sensitivity = clampf(values.sensitivity, 0.2, 3.0)
	values.quality = clampi(values.quality, 0, 1)
	values.name = str(values.name).strip_edges().left(16)


static func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("prefs", k, values[k])
	cfg.save(PATH)


# quality 1 = shadows + MSAA, 0 = off (for older laptops).
static func apply(tree: SceneTree) -> void:
	AudioServer.set_bus_volume_linear(0, values.volume)
	if DisplayServer.get_name() == "headless":
		return
	var win := tree.root
	win.mode = Window.MODE_FULLSCREEN if values.fullscreen else Window.MODE_WINDOWED
	win.msaa_3d = Viewport.MSAA_2X if values.quality == 1 else Viewport.MSAA_DISABLED
	for light in tree.get_nodes_in_group("sun"):
		light.shadow_enabled = values.quality == 1
