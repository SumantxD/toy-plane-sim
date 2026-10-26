class_name Settings
extends RefCounted

# Player preferences, saved to user://settings.cfg. Bad or missing values fall back to defaults.
const PATH := "user://settings.cfg"
const DEFAULTS := {volume = 0.8, sensitivity = 1.0, invert_y = false, fullscreen = false, quality = 1, name = "", cam = 1, matches = 0, player_id = "", turn_urls = "", turn_username = "", turn_credential = "", sticker = 0, banner = 0, taunts = true, trails = true, last_world = 0, last_mode = 3, last_size = 1, last_skill = 0, last_plane = "cub",
	touch_layout = {}, touch_opacity = 0.8, touch_lefty = false, touch_fixed = false, tilt = false, autofire = false, vibrate = true,
	livery = 0, killfx = 0, offer_dismiss = {}, review_at = 0, show_fps = false,
	xp = 0, best = {}, last = {}, badges = {}, daily = {}, onboarded = false} # progression: progress.gd, this device only

static var values := DEFAULTS.duplicate(true)


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	var old := OS.get_user_data_dir().get_base_dir().path_join("Toy Plane Sim/settings.cfg") # the game's old name: keep players' settings
	if not FileAccess.file_exists(PATH) and FileAccess.file_exists(old):
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(PATH))
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			var v = cfg.get_value("prefs", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
				values[k] = v
	values.volume = clampf(values.volume, 0.0, 1.0)
	values.sensitivity = clampf(values.sensitivity, 0.2, 3.0)
	values.quality = clampi(values.quality, 0, 1)
	values.banner = clampi(values.banner, 0, Planes.trail_names().size() - 1)
	values.livery = clampi(values.livery, 0, Planes.LIVERIES.size() - 1)
	values.killfx = clampi(values.killfx, 0, Planes.KILL_FX.size() - 1)
	values.name = str(values.name).strip_edges().left(16)


static func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("prefs", k, values[k])
	cfg.save(PATH)


# quality 1 = shadows (desktop) + anti-aliasing, 0 = off (older laptops / phones).
static func apply(tree: SceneTree) -> void:
	AudioServer.set_bus_volume_linear(0, values.volume)
	if DisplayServer.get_name() == "headless":
		return
	var win := tree.root
	win.mode = Window.MODE_FULLSCREEN if values.fullscreen else Window.MODE_WINDOWED
	win.msaa_3d = Viewport.MSAA_2X if values.quality == 1 and not TouchControls.phone() else Viewport.MSAA_DISABLED # phones: FXAA only
	win.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if values.quality == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	if TouchControls.phone(): # 3D at 80% (UI stays sharp): fill rate is what phones run out of
		win.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		win.scaling_3d_scale = res_scale
	for light in tree.get_nodes_in_group("sun"):
		light.shadow_enabled = values.quality == 1 and not TouchControls.phone() # phones: no shadow pass, the baked ground shadows (Terrain) stand in
		Terrain.use_baked_sun(not light.shadow_enabled)


# Phones: 3D at 0.8, stepped down (to 0.6 at worst) only under sustained slowness, see adapt_res.
# ponytail: frame time can't tell GPU- from CPU-bound (Metal has no GPU timer here), so a CPU hitch
# storm can also cost a step; a per-device starting scale would be the upgrade.
const RES_MAX := 0.8
const RES_MIN := 0.6
static var res_scale := RES_MAX
static var _late := 0.0
static var _smooth := 0.0


# Only ever steps DOWN, and rarely: each change rebuilds the 3D buffers (a hitch of its own), so a
# boost or a big fight must not set off a chain of them. Sustained slowness (3 s of late frames) ->
# -0.1, then at least 30 s before another step; it never climbs back mid-session.
static func adapt_res(win: Viewport, dt: float) -> void:
	_smooth += dt # time since the last change
	if dt > 1.0 / 50.0:
		_late = minf(_late + minf(dt, 0.05), 4.0) # one long hitch (a world load) is not a trend; capped so smooth play clears it
	else:
		_late = maxf(_late - dt * 0.25, 0.0)
	if _late > 3.0 and _smooth > 30.0 and res_scale > RES_MIN:
		res_scale = maxf(res_scale - 0.1, RES_MIN)
		win.scaling_3d_scale = res_scale
		_late = 0.0
		_smooth = 0.0
