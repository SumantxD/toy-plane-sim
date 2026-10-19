class_name Worlds
extends RefCounted

# Six worlds on one shared layout (runways, bomber route, factory, spawns stay put) so every
# mode works everywhere. Each world is a script in res://worlds/ with:
#   static func def() -> Dictionary      settings merged over DEFAULT below (all optional)
#   static func shape(x, z, h) -> float  reshape the base terrain height (optional)
#   static func color(p, up, k) -> Color recolour a terrain face (optional)
#   static func bottom(x, z) -> float    underside of floating ground; -INF = solid to the core (optional)
#   static func layout()                 add solid/visual props via Props helpers (optional)
#   static func nodes(root: Node3D)      add animated / effect / audio nodes (optional)
const LIST := ["valley", "volcano", "frozen", "desert", "metro", "sky"]
const NAMES := ["Green Valley", "Volcanic Islands", "Frozen Frontier", "Desert Wasteland", "Neon Metropolis", "Sky Kingdom"]

const DEFAULT := {
	terrain = {seed = 1337, base = 18.0, amp = 220.0, power = 1.6, freq = 0.0011, mountain = 1.0, lake = true, river = true, floating = false},
	palette = {bed = Color(0.62, 0.6, 0.45), sand = Color(0.95, 0.86, 0.6), cliff = Color(0.56, 0.53, 0.5), cliff2 = Color(0.62, 0.5, 0.4),
		snow = Color(0.97, 0.98, 1.0), alpine_rock = Color(0.6, 0.6, 0.55), alpine = Color(0.33, 0.5, 0.3), forest = Color(0.27, 0.55, 0.27),
		forest2 = Color(0.2, 0.45, 0.25), lush = Color(0.42, 0.72, 0.3), lush2 = Color(0.32, 0.62, 0.28), field = Color(0.72, 0.78, 0.36),
		wood = Color(0.22, 0.48, 0.24), slope = Color(0.5, 0.55, 0.32), runway = Color(0.36, 0.37, 0.4), snow_h = 470.0, alpine_h = 320.0, forest_h = 160.0},
	features = ["village", "windmill", "lighthouse", "bridge", "canyon", "arches"],
	scatter = {density = 1.0, tree_line = 330.0, pine_line = 160.0, rocks = 1.0,
		broad = [["tree_default.glb", Color(0.42, 0.7, 0.26)], ["tree_fat.glb", Color(0.28, 0.58, 0.27)], ["tree_simple.glb", Color(0.42, 0.7, 0.26)],
			["tree_default.glb", Color(0.28, 0.58, 0.27)], ["tree_fat.glb", Color(0.55, 0.75, 0.28)]],
		pines = [["tree_pineTallA.glb", Color(0.2, 0.48, 0.3)], ["tree_pineTallC.glb", Color(0.2, 0.48, 0.3)], ["tree_cone.glb", Color(0.28, 0.58, 0.27)]],
		accent = ["tree_oak.glb", Color(0.95, 0.6, 0.2)], bark = Color(0.55, 0.36, 0.24), rock_tint = Color.WHITE},
	sky = {zenith = Color(0.16, 0.42, 0.92), horizon = Color(0.70, 0.88, 1.0), sun_rot = Vector3(-38.0, -145.0, 0.0), sun_color = Color(1.0, 0.95, 0.84),
		sun_energy = 1.1, sun_disc = Color(1.0, 0.97, 0.82), ambient = Color(0.62, 0.72, 0.9), ambient_energy = 0.5, fog_begin = 1500.0, fog_end = 5800.0,
		fog_color = null, saturation = 1.15},
	clouds = {count = 100, base_min = 320.0, base_max = 560.0, top = Color(1, 1, 1), mid = Color(0.87, 0.92, 1.0), bottom = Color(0.70, 0.78, 0.94)},
	water = {visible = true, y = 6.0, shallow = Color(0.30, 0.90, 0.86), deep = Color(0.10, 0.50, 0.86), foam = Color(0.95, 1.0, 1.0), glow = Color(0, 0, 0)},
	# Flight-changing mechanics (env.gd): wind drifts every plane, updrafts lift, storms cut visibility, hazards hurt.
	env = {wind = Vector3.ZERO, gust = 0.0, updrafts = [], storm = {}, weather = "", hazards = {}, kill_y = -INF},
	ambience = ["birds"],
}

static var index := 0
static var cur: Dictionary = {}
static var mod: Script


static func select(i: int) -> void:
	index = clampi(i, 0, LIST.size() - 1)
	mod = load("res://worlds/%s.gd" % LIST[index])
	cur = DEFAULT.duplicate(true)
	var d: Dictionary = mod.def() if mod.has_method("def") else {}
	for k in d:
		if cur.get(k) is Dictionary and d[k] is Dictionary:
			cur[k].merge(d[k], true)
		else:
			cur[k] = d[k]
	Terrain.configure()


static func has(hook: String) -> bool:
	return mod != null and mod.has_method(hook)


static func get_cfg(section: String) -> Dictionary:
	if cur.is_empty():
		select(0)
	return cur[section]
