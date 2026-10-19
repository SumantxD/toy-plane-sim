extends RefCounted

# Frozen Frontier: snowfields, blue-grey cliffs, a glacier tongue, frozen lake and river, giant ice
# crystals, a frozen waterfall and an abandoned radar station. Strong gusty wind, periodic snowstorms,
# updrafts along the ridges.
const FZ := "res://assets/frozen/"
const WF := Vector2(-1800, 1080) # waterfall mesa centre; the fall faces the lake
const WF_R := 200.0
const WF_TOP := 230.0
const POOL_Y := 20.0
const STATION := Vector2(1600, 1500)
const STATION_Y := 120.0
const G0 := Vector2(2900, -100) # glacier head (beyond the map edge) -> snout
const G1 := Vector2(1300, -520)
const GW := 160.0 # glacier half width
const ICE := {"dirt": Color(0.8, 0.92, 1.0), "_default": Color(0.92, 0.97, 1.0), "grass": Color(0.97, 0.99, 1.0)}
const STONE := {"dirt": Color(0.48, 0.53, 0.62), "_default": Color(0.6, 0.65, 0.74), "grass": Color(0.96, 0.97, 1.0)}
const SNOW := Color(0.95, 0.97, 1.0)
const ROCK_A := Color(0.5, 0.56, 0.66)
const ROCK_B := Color(0.58, 0.63, 0.72)
const GLACIER := Color(0.72, 0.88, 0.98)

static var _hex: Mesh
static var _hex_tip: Mesh


static func def() -> Dictionary:
	var trees := [[FZ + "tree-snow-a.glb", Color.WHITE], [FZ + "tree-snow-b.glb", Color.WHITE], [FZ + "tree-snow-c.glb", Color.WHITE]]
	return {
		terrain = {seed = 1337, amp = 240.0, power = 1.7, mountain = 1.25},
		palette = {bed = Color(0.7, 0.8, 0.9), sand = SNOW, runway = Color(0.34, 0.36, 0.42)},
		features = ["bridge"],
		scatter = {density = 0.75, tree_line = 300.0, pine_line = 0.0, rocks = 0.0, broad = trees, pines = trees, accent = null},
		sky = {zenith = Color(0.26, 0.48, 0.84), horizon = Color(0.84, 0.92, 1.0), sun_rot = Vector3(-17.0, -140.0, 0.0),
			sun_color = Color(1.0, 0.88, 0.74), sun_energy = 1.2, sun_disc = Color(1.0, 0.9, 0.75), ambient = Color(0.68, 0.78, 0.95),
			ambient_energy = 0.62, fog_begin = 1300.0, fog_end = 5200.0, fog_color = Color(0.84, 0.9, 0.98), saturation = 1.05},
		clouds = {count = 120, base_min = 340.0, base_max = 600.0, top = Color(1, 1, 1), mid = Color(0.88, 0.92, 0.98), bottom = Color(0.66, 0.73, 0.86)},
		water = {visible = false}, # frozen: an ice sheet replaces the water plane (nodes())
		env = {
			wind = Vector3(7.0, 0.0, -3.0), gust = 6.0, weather = "snow",
			storm = {period = 150.0, length = 40.0, fog = 0.8, wind_mul = 1.2, warn = "Snowstorm incoming! Visibility dropping."},
			updrafts = [
				{pos = Vector3(WF.x + 300, 0, WF.y - 60), radius = 150.0, strength = 14.0, top = 520.0}, # waterfall cliff
				{pos = Vector3(-1500, 0, 150), radius = 170.0, strength = 12.0, top = 450.0}, # ice spire canyon
				{pos = Vector3(1900, 0, -560), radius = 200.0, strength = 15.0, top = 650.0}, # glacier ridge
				{pos = Vector3(1850, 0, 1500), radius = 160.0, strength = 12.0, top = 480.0}, # ridge behind the station
				{pos = Vector3(-2050, 0, -950), radius = 180.0, strength = 14.0, top = 600.0}, # crystal ridge
			],
		},
		ambience = [],
		shots = [
			[Vector3(-1200, 160, 1250), Vector3(WF.x + WF_R, 120, WF.y)], # frozen waterfall
			[Vector3(1440, 200, 1400), Vector3(STATION.x, STATION_Y + 15, STATION.y)], # research station
			[Vector3(950, 230, -760), Vector3(2000, 170, -330)], # glacier + arches
			[Vector3(-1500, 180, -350), Vector3(-1500, 80, 300)], # ice spire canyon
			[Vector3(-500, 120, 700), Vector3(-1000, 6, 950)], # frozen lake
		],
	}


# ---------- terrain ----------

# (distance from the glacier centreline, 0..1 along it)
static func _glacier(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var ab := G1 - G0
	var t := clampf((p - G0).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(G0 + ab * t), t)


static func shape(x: float, z: float, h: float) -> float:
	if x > 1000.0 and z < 200.0 and z > -900.0: # glacier: smooth ice valley falling to the snout
		var g := _glacier(x, z)
		if g.x < GW:
			var q := g.x / GW
			var gh := 40.0 + 430.0 * pow(1.0 - g.y, 1.4) + 12.0 * (1.0 - q * q)
			h = lerpf(gh, h, smoothstep(0.6, 1.0, q))
	var dw := Vector2(x, z).distance_to(WF)
	if dw < WF_R + 420.0: # plunge pool, then the cliff-sided mesa the waterfall drops off
		var pool := WF + (Terrain.LAKE_CENTER - WF).normalized() * (WF_R + 90.0)
		h = minf(h, lerpf(POOL_Y, h, smoothstep(70.0, 150.0, Vector2(x, z).distance_to(pool))))
		var a := atan2(z - WF.y, x - WF.x)
		var rim := WF_R + sin(a * 3.0) * 18.0 + sin(a * 7.0 + 1.0) * 9.0
		h = maxf(h, lerpf(h, WF_TOP + sin(x * 0.02) * 4.0, 1.0 - smoothstep(rim, rim + 45.0, dw)))
	var ds := Vector2(x, z).distance_to(STATION)
	if ds < 230.0: # flat shelf for the station
		h = lerpf(STATION_Y, h, smoothstep(120.0, 230.0, ds))
	return h


static func color(p: Vector3, up: float, _k: Color) -> Color:
	var t := Terrain._tint.get_noise_2d(p.x, p.z)
	var k: Color
	if up < 0.72:
		k = ROCK_A.lerp(ROCK_B, t * 0.5 + 0.5)
	elif up < 0.86:
		k = SNOW.lerp(Color(0.78, 0.85, 0.95), 0.55 + t * 0.3) # wind-scoured slopes
	else:
		k = SNOW.lerp(Color(0.86, 0.91, 0.99), smoothstep(-0.1, 0.6, t) * 0.6)
	if p.x > 1000.0 and p.z < 200.0 and p.z > -900.0:
		var g := _glacier(p.x, p.z)
		if g.x < GW * 0.82 and up > 0.6:
			var crev := absf(sin(g.y * 140.0 + sin(g.x * 0.05) * 1.5)) > 0.93
			k = Color(0.5, 0.68, 0.86) if crev else GLACIER.lerp(Color(0.9, 0.96, 1.0), smoothstep(0.2, 0.7, t))
	return k


# ---------- props ----------

static func layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	_waterfall(rng)
	_station(rng)
	_glacier_arches(rng)
	for row in [-1.0, 1.0]: # ice spire canyon (replaces the valley's rock canyon)
		var z := -170.0
		while z < 470.0:
			_ice_spire(Vector3(-1500.0 + row * rng.randf_range(44, 56), 0, z), rng.randf_range(70, 140), rng)
			z += rng.randf_range(48, 70)
	for c in [Vector2(-2050, -950), Vector2(1950, 950), Vector2(-750, 2380), Vector2(2150, -650), Vector2(-2200, 300)]:
		_crystals(c, rng)
	_lake_ice(rng)
	_rocks(rng)


static func _ground(x: float, z: float, r: float) -> float:
	return Props._ground(x, z, r)


static func _hexes() -> void:
	if _hex:
		return
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	m.material = Props.toon()
	_hex = m
	var c := m.duplicate()
	c.top_radius = 0.0
	_hex_tip = c


# One hexagonal ice crystal: prism + pointed tip, tilted. Solid when `solid`.
static func _crystal(base: Vector3, b: Basis, tall: float, w: float, col: Color, solid := true) -> void:
	_hexes()
	var body := tall * 0.8
	var t := Transform3D(b * Basis.from_scale(Vector3(w, body, w)), base + b.y * body * 0.5)
	Props._add(_hex, t, col)
	Props._add(_hex_tip, Transform3D(b * Basis.from_scale(Vector3(w, tall * 0.2, w)), base + b.y * (body + tall * 0.1)), col.lightened(0.15))
	if solid:
		Props._solid(t, AABB(Vector3(-0.35, -0.5, -0.35), Vector3(0.7, 1.0, 0.7)))


static func _crystals(c: Vector2, rng: RandomNumberGenerator) -> void:
	var g := _ground(c.x, c.y, 30)
	var tones := [Color(0.72, 0.88, 1.0), Color(0.86, 0.95, 1.0), Color(0.6, 0.8, 0.98)]
	_crystal(Vector3(c.x, g - 10, c.y), Basis(), rng.randf_range(190, 250), 46.0, tones[1])
	for k in 7:
		var a := k * TAU / 7.0 + rng.randf() * 0.5
		var off := Vector3(sin(a), 0, cos(a)) * rng.randf_range(30, 55)
		var p := Vector3(c.x + off.x, 0, c.y + off.z)
		p.y = _ground(p.x, p.z, 10) - 6.0
		var tilt := Basis(Vector3(cos(a), 0, -sin(a)), rng.randf_range(0.25, 0.55)) # lean outwards
		_crystal(p, tilt, rng.randf_range(60, 140), rng.randf_range(16, 28), tones[k % 3])
	Props._keep_out.append(Vector3(c.x, c.y, 90))
	Props.spots["crystals_%d" % int(c.x)] = Vector3(c.x, g, c.y)


static func _ice_spire(p: Vector3, tall: float, rng: RandomNumberGenerator) -> float:
	var w := rng.randf_range(22, 34)
	p.y = _ground(p.x, p.z, w * 0.4) - 4.0
	var m := Props.model(Props.NAT + ["rock_tallC.glb", "rock_tallG.glb", "rock_tallI.glb", "rock_tallD.glb"][rng.randi() % 4], "", ICE)
	var s := m.get_aabb().size
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w / s.x, tall / s.y, w / s.z)), p)
	Props._add(m, t, Color.WHITE.lerp(Color(0.85, 0.92, 1.0), rng.randf()))
	Props._solid(t, AABB(m.get_aabb().position + Vector3(s.x * 0.2, 0, s.z * 0.2), Vector3(s.x * 0.6, s.y * 0.95, s.z * 0.6)))
	Props._keep_out.append(Vector3(p.x, p.z, w * 0.6))
	if rng.randf() < 0.6: # shards at the foot
		var a := rng.randf() * TAU
		_crystal(p + Vector3(sin(a), 0, cos(a)) * w * 0.6, Basis(Vector3(cos(a), 0, -sin(a)), 0.5), tall * 0.35, w * 0.4, Color(0.75, 0.9, 1.0), false)
	return p.y + tall


static func _waterfall(rng: RandomNumberGenerator) -> void:
	var dir := (Terrain.LAKE_CENTER - WF).normalized()
	var d3 := Vector3(dir.x, 0, dir.y)
	var side := Vector3(-dir.y, 0, dir.x)
	var lip := Vector3(WF.x, WF_TOP, WF.y) + d3 * (WF_R - 6.0)
	var foot := Vector3(WF.x, 0, WF.y) + d3 * (WF_R + 55.0)
	foot.y = Terrain.height(foot.x, foot.z)
	var drop := lip.y - foot.y
	var yaw := atan2(dir.x, dir.y)
	# frozen stream across the mesa top feeding the lip
	Props._box(Vector3(WF.x, WF_TOP + 0.6, WF.y) + d3 * (WF_R * 0.5 - 6.0), Vector3(26, 1.2, WF_R), Color(0.68, 0.86, 0.98), yaw)
	# the fall: overlapping columns of ice bulging out over the cliff
	for k in 9:
		var s := (k - 4) / 4.0
		var w := 22.0 - absf(s) * 9.0 + rng.randf_range(-3, 3)
		var h := drop * (1.0 - absf(s) * 0.35) + rng.randf_range(-8, 8)
		var c := lip + side * s * 34.0 + d3 * (10.0 + rng.randf_range(0, 6)) + Vector3.DOWN * h * 0.5 + Vector3.UP * 4.0
		Props._part("taper", c, Vector3(w, h, w * 0.8), Color(0.78, 0.92, 1.0).lerp(Color(0.6, 0.8, 0.97), rng.randf()))
		for i in 3: # icicles hanging off the lip
			var ip := lip + side * (s * 34.0 + rng.randf_range(-5, 5)) + d3 * (4.0 + i * 3.0) + Vector3.DOWN * rng.randf_range(4, 14)
			var il := rng.randf_range(10, 26)
			Props._add(Props._prim("cone"), Transform3D(Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(4, il, 4)), ip), Color(0.88, 0.96, 1.0))
	# frozen cascade bulge and plunge pool
	Props._part("sphere", foot + Vector3.UP * 6.0 + d3 * -8.0, Vector3(80, 26, 46), Color(0.82, 0.94, 1.0))
	Props._part("cyl", foot + d3 * 40.0 + Vector3.UP * 0.4, Vector3(130, 1.0, 130), Color(0.62, 0.82, 0.98))
	for k in 5:
		var a := rng.randf() * TAU
		_crystal(foot + d3 * 40.0 + Vector3(sin(a), 0, cos(a)) * rng.randf_range(50, 70), Basis(Vector3(cos(a), 0, -sin(a)), 0.4), rng.randf_range(18, 34), rng.randf_range(6, 10), Color(0.8, 0.93, 1.0), false)
	Props._solid(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(76, drop, 26)), lip + d3 * 12.0 + Vector3.DOWN * drop * 0.5), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	Props._keep_out.append(Vector3(foot.x, foot.z, 120))
	Props.spots["frozen_waterfall"] = foot


static func _station(rng: RandomNumberGenerator) -> void:
	var c := Vector3(STATION.x, STATION_Y, STATION.y)
	var orange := Color(0.92, 0.42, 0.18)
	var white := Color(0.93, 0.94, 0.96)
	var steel := Color(0.4, 0.43, 0.5)
	var rust := Color(0.6, 0.32, 0.2)
	# two long modules on stilts
	for m in [[Vector3(-20, 0, 0), 0.0, Vector3(16, 9, 46)], [Vector3(14, 0, 20), PI / 2, Vector3(14, 8, 36)]]:
		var p: Vector3 = c + m[0]
		var yaw: float = m[1]
		var s: Vector3 = m[2]
		Props._box(p + Vector3(0, 4 + s.y / 2, 0), s, orange, yaw, true)
		Props._box(p + Vector3(0, 4 + s.y * 0.62, 0), Vector3(s.x + 0.4, 1.4, s.z + 0.4), white, yaw)
		Props._box(p + Vector3(0, 4 + s.y + 0.6, 0), Vector3(s.x + 1.0, 1.2, s.z + 1.0), SNOW, yaw) # snow on the roof
		for i in 4:
			var b := Basis(Vector3.UP, yaw)
			for sx in [-1.0, 1.0]:
				Props._part("cyl", p + b * Vector3(sx * (s.x / 2 - 1.5), 2, (i / 3.0 - 0.5) * (s.z - 4)), Vector3(1.2, 5, 1.2), steel)
	# radar tower + dome, and a big ground radome
	var tw := c + Vector3(30, 0, -28)
	Props._box(tw + Vector3(0, 15, 0), Vector3(11, 30, 11), steel, 0.0, true)
	Props._box(tw + Vector3(0, 30.5, 0), Vector3(14, 1.5, 14), white)
	Props._part("sphere", tw + Vector3(0, 39, 0), Vector3(20, 20, 20), white)
	var rd := c + Vector3(-45, 0, -55)
	Props._part("cyl", rd + Vector3(0, 4, 0), Vector3(42, 8, 42), white.darkened(0.1))
	Props._part("sphere", rd + Vector3(0, 9, 0), Vector3(44, 44, 44), white)
	Props._part("sphere", rd + Vector3(0, 14, 0), Vector3(45, 24, 45), Color(0.85, 0.3, 0.2)) # faded red band
	Props._part("sphere", rd + Vector3(0, 17, 0), Vector3(45.5, 24, 45.5), white)
	Props._solid(Transform3D(Basis.from_scale(Vector3(42, 38, 42)), rd + Vector3(0, 15, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	# antenna mast with red/white bands, leaning a little (abandoned)
	var mast := c + Vector3(45, 0, 30)
	var lean := Basis(Vector3(0, 0, 1), 0.08)
	for k in 6:
		Props._add(Props._prim("cyl"), Transform3D(lean * Basis.from_scale(Vector3(1.6, 9, 1.6)), mast + lean.y * (4.5 + k * 9.0)), Color(0.9, 0.2, 0.15) if k % 2 == 0 else white)
	Props._solid(Transform3D(Basis.from_scale(Vector3(6, 54, 6)), mast + Vector3(-2, 27, 0)), AABB(Vector3.ONE * -0.5, Vector3.ONE))
	# tilted dish, fuel tanks, collapsed shed, drifts
	var dish := c + Vector3(-5, 0, 45)
	Props._part("cyl", dish + Vector3(0, 4, 0), Vector3(1.6, 8, 1.6), steel)
	Props._add(Props._prim("cyl"), Transform3D(Basis(Vector3.RIGHT, 1.0) * Basis.from_scale(Vector3(16, 1.2, 16)), dish + Vector3(0, 10, 0)), white)
	for k in 3:
		Props._add(Props._prim("cyl"), Transform3D(Basis(Vector3.BACK, PI / 2) * Basis.from_scale(Vector3(6, 14, 6)), c + Vector3(-52, 3.2, 10 + k * 8)), rust if k == 1 else Color(0.78, 0.8, 0.82))
	Props._box(c + Vector3(20, 3, 52), Vector3(12, 6, 10), rust, 0.3)
	Props._add(Props._prim("prism"), Transform3D(Basis(Vector3.BACK, 0.35) * Basis(Vector3.UP, 0.3) * Basis.from_scale(Vector3(13, 4, 11)), c + Vector3(21, 7, 52)), steel)
	for k in 8:
		var a := rng.randf() * TAU
		Props._part("sphere", c + Vector3(sin(a), 0, cos(a)) * rng.randf_range(40, 85) + Vector3(0, -1, 0), Vector3(rng.randf_range(14, 26), rng.randf_range(4, 7), rng.randf_range(10, 18)), SNOW)
	Props._kit(FZ + "snowman.glb", "", c + Vector3(-2, 0, 22), 2.6, 4.0, false)
	Props._keep_out.append(Vector3(c.x, c.z, 110))
	Props.spots["station"] = c


static func _glacier_arches(rng: RandomNumberGenerator) -> void:
	var ab := (G1 - G0).normalized()
	var across := Vector3(-ab.y, 0, ab.x)
	var m := Props.model(Props.NAT + "rock_largeD.glb", "", ICE)
	for t in [0.62, 0.8]:
		var q := G0.lerp(G1, t)
		var c := Vector3(q.x, 0, q.y)
		var gap := 80.0
		var tops := []
		for s in [-1.0, 1.0]:
			tops.append(_ice_spire(c + across * s * (gap / 2.0 + 14.0), rng.randf_range(85, 105), rng))
		var y: float = minf(tops[0], tops[1]) - 8.0
		var tr := Transform3D(Basis(Vector3.UP, atan2(across.x, across.z) - PI / 2) * Basis.from_scale(Vector3((gap + 56.0) / 1.07, 26, 28)), c + Vector3(0, y - 6, 0))
		Props._add(m, tr)
		Props._solid(tr, m.get_aabb())
	for k in 10: # ice pinnacles along the glacier's flanks
		var t := 0.35 + k * 0.065
		var q := G0.lerp(G1, t)
		var s := -1.0 if k % 2 == 0 else 1.0
		_ice_spire(Vector3(q.x, 0, q.y) + across * s * GW * rng.randf_range(0.75, 0.95), rng.randf_range(50, 110), rng)
	for k in 14: # no trees on the ice
		var q := G0.lerp(G1, 0.3 + k * 0.055)
		Props._keep_out.append(Vector3(q.x, q.y, GW))
	Props.spots["glacier"] = Vector3(G1.x, Terrain.height(G1.x, G1.y), G1.y)


static func _lake_ice(rng: RandomNumberGenerator) -> void:
	var lc := Terrain.LAKE_CENTER
	for k in 14: # snow drifts on the ice
		var a := rng.randf() * TAU
		var p := lc + Vector2(sin(a), cos(a)) * rng.randf_range(0, 240)
		Props._part("sphere", Vector3(p.x, Terrain.WATER_Y, p.y), Vector3(rng.randf_range(20, 45), 2.2, rng.randf_range(12, 28)), SNOW)
	for k in 3: # ice-fishing huts
		var p := lc + Vector2(-60 + k * 55, 40 - k * 30)
		var hc := Vector3(p.x, Terrain.WATER_Y + 2.0, p.y)
		Props._box(hc, Vector3(5, 4, 6), [Color(0.85, 0.25, 0.2), Color(0.25, 0.45, 0.8), Color(0.95, 0.75, 0.2)][k], k * 0.7)
		Props._add(Props._prim("prism"), Transform3D(Basis(Vector3.UP, k * 0.7) * Basis.from_scale(Vector3(6, 2.2, 7)), hc + Vector3(0, 3.1, 0)), SNOW)


static func _rocks(rng: RandomNumberGenerator) -> void:
	var rocks: Array[Mesh] = []
	for f in ["rock_largeA", "rock_largeD", "rock_largeF", "rock_tallB", "rock_tallH"]:
		rocks.append(Props.model(Props.NAT + f + ".glb", "", STONE))
	var x := -2450.0
	while x <= 2450.0:
		var z := -2450.0
		while z <= 2450.0:
			var px := x + rng.randf_range(-20, 20)
			var pz := z + rng.randf_range(-20, 20)
			z += 55.0
			if rng.randf() > 0.35 or Props._blocked(px, pz):
				continue
			var h := Terrain.height(px, pz)
			var steep := Vector2(Terrain.height(px + 5.0, pz) - h, Terrain.height(px, pz + 5.0) - h).length() / 5.0
			if h < Terrain.WATER_Y + 4.0 or steep < 0.35:
				continue
			var sc := 8.0 + pow(rng.randf(), 2.0) * 24.0
			Props._add(rocks[rng.randi() % rocks.size()], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, h - sc * 0.15 - steep * 2.0, pz)), Color.WHITE * rng.randf_range(0.85, 1.0))
		x += 55.0


# ---------- nodes ----------

static func nodes(root: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 12000.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://frozen_ice.gdshader")
	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	ice.mesh = plane
	ice.material_override = mat
	ice.position.y = Terrain.WATER_Y
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ice)
