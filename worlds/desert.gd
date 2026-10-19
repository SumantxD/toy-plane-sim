extends RefCounted

# Desert Wasteland: gold flats, terraced red mesas cut by winding canyons, cellular buttes, a dry
# riverbed. Steady crosswind, thermals over the flats, periodic sandstorm.
const STRATA := [Color(0.78, 0.36, 0.22), Color(0.88, 0.52, 0.3), Color(0.68, 0.28, 0.18), Color(0.92, 0.72, 0.5)]
const DES := "res://assets/desert/"
const STONE := {"dirt": Color(0.86, 0.5, 0.3), "_default": Color(0.9, 0.62, 0.4), "grass": Color(0.8, 0.55, 0.3)}
# Plateaus [centre, radius]; canyons [axis ("x" = runs along z), offset, amp, k, phase, from, to].
const PLATEAUS := [[Vector2(1150, -650), 620.0], [Vector2(-1150, 650), 620.0]]
const CANYONS := [
	["x", 1150.0, 90.0, 0.005, 0.0, -1450.0, 150.0], ["z", -650.0, 80.0, 0.006, 1.0, 400.0, 1800.0],
	["x", -1150.0, 90.0, 0.005, 2.0, -150.0, 1450.0], ["z", 650.0, 80.0, 0.006, 3.0, -1800.0, -400.0]]
const FLOOR_HALF := 55.0 # flat canyon floor = 110 m wide
const WALL := 50.0 # horizontal run of the canyon wall
const ARCH := Vector2(-300, 1000)
const FORT := Vector2(650, -1350)
const RUINS := Vector2(-450, 250)
const PADS := [[Vector2(-300, -1500), 260.0, 52.0], [FORT, 110.0, 24.0], [RUINS, 90.0, 40.0]] # [centre, radius, y]; first = Props.RED_RUNWAY

static var _cell: FastNoiseLite
static var _cellv: FastNoiseLite
static var _wob: FastNoiseLite


static func def() -> Dictionary:
	return {
		terrain = {seed = 913, base = 22.0, amp = 95.0, power = 1.8, freq = 0.0013, mountain = 0.8, lake = false, river = true},
		palette = {bed = Color(0.84, 0.72, 0.56), sand = Color(0.92, 0.78, 0.5), runway = Color(0.42, 0.38, 0.36)},
		features = [],
		scatter = {density = 0.12, tree_line = 400.0, pine_line = 9999.0, rocks = 0.0, accent = [], pines = [],
			broad = [[DES + "cactus_tall.glb", Color(0.36, 0.62, 0.3)], [DES + "cactus_short.glb", Color(0.42, 0.66, 0.32)]],
			rock_tint = Color(1.0, 0.72, 0.55)},
		sky = {zenith = Color(0.32, 0.55, 0.86), horizon = Color(1.0, 0.86, 0.64), sun_rot = Vector3(-40.0, -120.0, 0.0),
			sun_color = Color(1.0, 0.9, 0.74), sun_energy = 1.25, sun_disc = Color(1.0, 0.95, 0.75), ambient = Color(0.85, 0.7, 0.58),
			ambient_energy = 0.55, fog_begin = 1100.0, fog_end = 4800.0, fog_color = Color(0.96, 0.8, 0.6), saturation = 1.1},
		clouds = {count = 22, base_min = 420.0, base_max = 600.0, top = Color(1, 0.97, 0.92), mid = Color(0.98, 0.88, 0.76), bottom = Color(0.9, 0.74, 0.6)},
		water = {visible = false},
		env = {wind = Vector3(9.0, 0.0, 3.5), gust = 3.0,
			updrafts = [{pos = Vector3(450, 0, 1050), radius = 160.0, strength = 14.0, top = 520.0},
				{pos = Vector3(-650, 0, -1100), radius = 160.0, strength = 14.0, top = 520.0},
				{pos = Vector3(250, 0, -650), radius = 140.0, strength = 12.0, top = 480.0}],
			storm = {period = 150.0, length = 40.0, fog = 0.8, wind_mul = 1.4, warn = "SANDSTORM incoming! Visibility dropping."},
			weather = "sand"},
		ambience = [],
		shots = [
			[Vector3(1089, 70, -120), Vector3(1080, 60, -450)], # inside the east canyon
			[Vector3(-300, 90, 1350), Vector3(-300, 80, 1000)], # stone arch
			[Vector3(2100, 650, -200), Vector3(1100, 120, -700)], # east mesas
			[Vector3(FORT.x + 220, 120, FORT.y + 220), Vector3(FORT.x, 20, FORT.y)], # fort
			[Vector3(RUINS.x + 160, 70, RUINS.y + 160), Vector3(RUINS.x, 20, RUINS.y)], # ruins
		],
	}


static func _noises() -> void:
	_cell = FastNoiseLite.new()
	_cell.seed = 77
	_cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	_cell.frequency = 0.0022
	_cell.fractal_type = FastNoiseLite.FRACTAL_NONE
	_cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_cellv = _cell.duplicate()
	_cellv.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_wob = FastNoiseLite.new()
	_wob.seed = 78
	_wob.frequency = 0.004
	_wob.fractal_octaves = 2


static func _terrace(e: float, step: float) -> float:
	var f := e / step
	return (floorf(f) + smoothstep(0.7, 1.0, f - floorf(f))) * step


static func canyon_dist(x: float, z: float) -> float:
	var best := INF
	for c in CANYONS:
		var u: float = z if c[0] == "x" else x # along
		var v: float = x if c[0] == "x" else z # across
		if absf(v - c[1]) > c[2] + FLOOR_HALF + WALL:
			continue
		var o := maxf(maxf(c[5] - u, u - c[6]), 0.0) # past an end: rounded box-canyon head
		var a: float = c[3] * clampf(u, c[5], c[6]) + c[4]
		var d := absf(v - c[1] - c[2] * sin(a)) / sqrt(1.0 + pow(c[2] * c[3] * cos(a), 2))
		best = minf(best, sqrt(d * d + o * o))
	return best


static func shape(x: float, z: float, h: float) -> float:
	if not _cell:
		_noises()
	var q := Vector2(x, z)
	var w := 0.0
	for p in PLATEAUS:
		var r: float = q.distance_to(p[0]) / p[1]
		if r < 1.15:
			w = _wob.get_noise_2d(x, z)
			r += w * 0.12
			if r < 1.0:
				var e := _terrace(lerpf(150.0, 270.0, smoothstep(0.9, 0.2, r)) + w * 40.0, 48.0)
				h = maxf(h, lerpf(h, e, smoothstep(1.0, 0.93, r)))
	if h < 200.0 and q.distance_to(Terrain.RUNWAY.get_center()) > 700.0 and q.distance_to(Props.RED_RUNWAY) > 420.0 \
		and q.distance_to(Props.FACTORY) > 320.0 and q.distance_to(ARCH) > 260.0 and q.distance_to(FORT) > 220.0 and q.distance_to(RUINS) > 200.0:
		var v := _cellv.get_noise_2d(x, z) * 0.5 + 0.5
		var d := _cell.get_noise_2d(x, z) + 1.0 if v > 0.45 else 1.0 # 0..~1 inside a cell
		if d < 0.42: # roughly every other cell grows a butte
			var top := 80.0 + (v - 0.45) * 220.0 + (40.0 if d < 0.22 else 0.0)
			h = maxf(h, lerpf(h, top, smoothstep(0.42, 0.36, d)))
	if h > 38.0:
		var cd := canyon_dist(x, z)
		if cd < FLOOR_HALF + WALL:
			h = minf(h, lerpf(32.0 + w * 6.0, h, smoothstep(FLOOR_HALF, FLOOR_HALF + WALL, cd)))
	for pad in PADS: # level ground for bases
		var pd := q.distance_to(pad[0])
		if pd < pad[1] + 140.0:
			h = lerpf(pad[2], h, smoothstep(pad[1], pad[1] + 140.0, pd))
	return h


static func color(p: Vector3, up: float, k: Color) -> Color:
	if p.y < Terrain.WATER_Y - 1.5:
		return Color(0.84, 0.72, 0.56) # dry riverbed
	if Terrain.RUNWAY.grow(0.5).has_point(Vector2(p.x, p.z)):
		return k
	if up < 0.75: # cliff strata
		return STRATA[posmod(int(floorf((p.y + sin(p.x * 0.01) * 4.0) / 13.0)), 4)]
	if p.y > 380.0:
		return Color(0.64, 0.38, 0.26)
	if p.y > 105.0: # mesa tops
		return Color(0.86, 0.56, 0.32).lerp(Color(0.8, 0.46, 0.28), clampf(sin(p.x * 0.003 + p.z * 0.004) * 0.5 + 0.5, 0.0, 1.0))
	var t := clampf(sin(p.x * 0.004) * sin(p.z * 0.005) + 0.5, 0.0, 1.0)
	return Color(0.95, 0.8, 0.5).lerp(Color(0.9, 0.7, 0.42), t) if up > 0.9 else Color(0.88, 0.64, 0.4)


static func layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9130
	_arch(rng)
	_fort(rng)
	_ruins(rng)
	_rocks(rng)


# Giant sandstone arch north-west of home: two thick pillars and a rock lintel, ~120 m wide gap.
static func _arch(rng: RandomNumberGenerator) -> void:
	const GAP := 120.0
	var c := Vector3(ARCH.x, 0, ARCH.y)
	var top := INF
	for s in [-1.0, 1.0]:
		var p := c + Vector3(s * (GAP / 2.0 + 26.0), 0, 0)
		p.y = Props._ground(p.x, p.z, 26.0) - 4.0
		var pm := Props.model(Props.NAT + ("rock_tallC.glb" if s < 0 else "rock_tallG.glb"), "", STONE)
		var sz := pm.get_aabb().size
		var pt := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(56.0 / sz.x, 180.0 / sz.y, 56.0 / sz.z)), p)
		Props._add(pm, pt)
		Props._solid(pt, AABB(pm.get_aabb().position + sz * Vector3(0.2, 0, 0.2), sz * Vector3(0.6, 0.95, 0.6)))
		top = minf(top, p.y + 180.0)
	Props._keep_out.append(Vector3(c.x, c.z, GAP))
	var m := Props.model(Props.NAT + "rock_largeD.glb", "", STONE)
	var t := Transform3D(Basis.from_scale(Vector3((GAP + 120.0) / 1.07, 44, 52)), c + Vector3(0, top - 22.0, 0))
	Props._add(m, t)
	Props._solid(t, m.get_aabb())
	Props.spots["arch"] = c


# Abandoned adobe fort by the dry riverbed: crumbling walls, corner towers, barracks, a tattered flag.
static func _fort(rng: RandomNumberGenerator) -> void:
	const H := 60.0
	var adobe := Color(0.88, 0.68, 0.46)
	var c := Vector3(FORT.x, Props._ground(FORT.x, FORT.y, 70.0), FORT.y)
	for s in 4:
		var yaw := s * PI / 2.0
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var along := Vector3(dir.z, 0, -dir.x)
		for k in 5:
			if (s == 0 and k == 2) or rng.randf() < 0.15:
				continue # gate / collapsed section
			var tall := rng.randf_range(7.0, 11.0)
			Props._box(c + dir * H + along * (k - 2) * 24.0 + Vector3(0, tall / 2.0 - 2.0, 0), Vector3(25, tall + 4.0, 4), adobe.darkened(rng.randf() * 0.1), yaw, true)
		var q := c + dir * H + along * H
		Props._box(q + Vector3(0, 7, 0), Vector3(14, 18, 14), adobe.darkened(0.12), yaw, true)
		Props._box(q + Vector3(0, 16.5, 0), Vector3(16, 1.5, 16), Color(0.6, 0.4, 0.26), yaw)
	for k in 3:
		var p := c + Vector3(-30 + k * 30, 0, -25)
		Props._box(p + Vector3(0, 3, 0), Vector3(22, 10, 14), adobe.lightened(0.05), 0.0, true)
		Props._box(p + Vector3(0, 8.5, 0), Vector3(23, 1, 15), Color(0.55, 0.36, 0.24))
	Props._part("cyl", c + Vector3(0, 14, 15), Vector3(0.8, 28, 0.8), Color(0.4, 0.3, 0.22))
	Props._box(c + Vector3(4.5, 25, 15), Vector3(8, 5, 0.4), Color(0.85, 0.2, 0.15))
	Props._solid(Transform3D(Basis.from_scale(Vector3(3, 30, 3)), c + Vector3(0, 15, 15)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	Props._keep_out.append(Vector3(c.x, c.z, H + 25.0))
	Props.spots["fort"] = c


# Ruined temple: stepped platform, two colonnades with broken columns, a fallen drum.
static func _ruins(rng: RandomNumberGenerator) -> void:
	var stone := Color(0.93, 0.82, 0.62)
	var c := Vector3(RUINS.x, Props._ground(RUINS.x, RUINS.y, 50.0), RUINS.y)
	var yaw := 0.5
	var b := Basis(Vector3.UP, yaw)
	Props._box(c + Vector3(0, 0.5, 0), Vector3(60, 5, 96), stone.darkened(0.15), yaw, true)
	Props._box(c + Vector3(0, 3.5, 0), Vector3(48, 3, 84), stone.darkened(0.08), yaw, true)
	for row in [-1.0, 1.0]:
		for k in 7:
			var p := c + b * Vector3(row * 18.0, 5.0, (k - 3) * 12.5)
			var tall := 24.0 if rng.randf() > 0.35 else rng.randf_range(6.0, 15.0)
			Props._part("cyl", p + Vector3(0, tall / 2.0, 0), Vector3(4.5, tall, 4.5), stone)
			Props._solid(Transform3D(Basis.from_scale(Vector3(5, tall, 5)), p + Vector3(0, tall / 2.0, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
			if tall == 24.0:
				Props._box(p + Vector3(0, tall + 1.0, 0), Vector3(6.5, 2, 6.5), stone.lightened(0.05), yaw)
		Props._box(c + b * Vector3(row * 18.0, 31.5, -18.75), Vector3(7, 3, 44), stone.lightened(0.05), yaw, true)
	var fall := c + b * Vector3(30.0, 2.0, 20.0)
	Props._add(Props._prim("cyl"), Transform3D(Basis(Vector3.UP, yaw + 0.4) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(4.5, 22, 4.5)), fall), stone.darkened(0.05))
	Props._keep_out.append(Vector3(c.x, c.z, 70.0))
	Props.spots["ruins"] = c


# Sandstone boulders on slopes and flats (the shared rock scatter has green tops).
static func _rocks(rng: RandomNumberGenerator) -> void:
	var ms: Array[Mesh] = []
	for f in ["rock_largeA", "rock_largeD", "rock_largeF", "rock_tallB", "rock_tallH"]:
		ms.append(Props.model(Props.NAT + f + ".glb", "", STONE))
	for i in 700:
		var x := rng.randf_range(-2400, 2400)
		var z := rng.randf_range(-2400, 2400)
		var sc := 6.0 + pow(rng.randf(), 2.0) * 22.0
		if Props._blocked(x, z) or Terrain.RUNWAY.grow(120).has_point(Vector2(x, z)):
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, Terrain.height(x, z) - sc * 0.2, z))
		Props._add(ms[i % ms.size()], t, Color.WHITE.lerp(Color(0.8, 0.75, 0.7), rng.randf()))


# Dust devils mark the thermals.
static func nodes(root: Node3D) -> void:
	for u in Worlds.cur.env.updrafts:
		var p := Fx.smoke(4.0, 7.0, Color(0.9, 0.72, 0.5))
		p.amount = 40
		p.spread = 12.0
		p.gravity = Vector3(0, 16, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 14.0
		p.emission_ring_inner_radius = 6.0
		p.emission_ring_height = 2.0
		p.orbit_velocity_min = 0.3
		p.orbit_velocity_max = 0.5
		p.position = Vector3(u.pos.x, Terrain.height(u.pos.x, u.pos.z), u.pos.z)
		root.add_child(p)
