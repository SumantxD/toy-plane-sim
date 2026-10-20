class_name Sfx
extends RefCounted

# Sound bank + one-shot helpers. Kenney sounds are CC0 (assets/sfx/Kenney-License.txt);
# engine/wind/gun/beeps are synthesized by tools/make_sounds.py.
const PROP := preload("res://assets/sfx/prop_loop.wav")
const JET := preload("res://assets/sfx/jet_loop.wav")
const WIND := preload("res://assets/sfx/wind_loop.wav")
const GUN := preload("res://assets/sfx/gun.wav")
# Each plane sounds like itself: toy rattle, snappy crack, heavy cannon, autocannon.
const GUNS := {cub = preload("res://assets/sfx/gun_cub.wav"), racer = preload("res://assets/sfx/gun_racer.wav"),
	twin = preload("res://assets/sfx/gun_twin.wav"), fighter = preload("res://assets/sfx/gun_fighter.wav")}
const AA_GUN := preload("res://assets/sfx/aa_gun.wav")
const FLAK := preload("res://assets/sfx/flak.wav")
const BOMB_WHISTLE := preload("res://assets/sfx/bomb_whistle.wav")
const FLARE := preload("res://assets/sfx/flare.wav")
const SIREN := preload("res://assets/sfx/siren.wav")
const FANFARE := preload("res://assets/sfx/fanfare.wav")
const LAUNCHES := [preload("res://assets/sfx/thrusterFire_000.ogg"), preload("res://assets/sfx/thrusterFire_001.ogg"),
	preload("res://assets/sfx/thrusterFire_002.ogg"), preload("res://assets/sfx/thrusterFire_003.ogg")]
const HEAVY_HITS := [preload("res://assets/sfx/impactMetal_heavy_000.ogg"), preload("res://assets/sfx/impactMetal_heavy_001.ogg")]
const BELL := preload("res://assets/sfx/impactBell_heavy_000.ogg")
const GRAB := preload("res://assets/sfx/maximize_006.ogg")
const DROP := preload("res://assets/sfx/minimize_006.ogg")
const RETURN := preload("res://assets/sfx/toggle_002.ogg")
const ALARM := preload("res://assets/sfx/error_004.ogg")
const PLUCK := preload("res://assets/sfx/pluck_001.ogg")
const KILL := preload("res://assets/sfx/confirmation_002.ogg")
const CLUNK := preload("res://assets/sfx/doorClose_001.ogg")
# Quiet per-world music bed (Worlds.LIST order), like IGI's background: there, never in the way.
const BEDS := [preload("res://assets/sfx/bed_valley.wav"), preload("res://assets/sfx/bed_volcano.wav"), preload("res://assets/sfx/bed_frozen.wav"),
	preload("res://assets/sfx/bed_desert.wav"), preload("res://assets/sfx/bed_metro.wav"), preload("res://assets/sfx/bed_sky.wav")]
const BED_DB := -17.0
const WHIZ := preload("res://assets/sfx/whiz.wav")
const THUNDER := preload("res://assets/sfx/thunder.wav")
const LOCK := preload("res://assets/sfx/lock.wav")
const WARN := preload("res://assets/sfx/warn.wav")
const LAUNCH := preload("res://assets/sfx/thrusterFire_000.ogg")
const BOOMS := [preload("res://assets/sfx/lowFrequency_explosion_000.ogg"), preload("res://assets/sfx/lowFrequency_explosion_001.ogg"), preload("res://assets/sfx/explosionCrunch_000.ogg")]
const HITS := [preload("res://assets/sfx/impactMetal_light_000.ogg"), preload("res://assets/sfx/impactMetal_light_001.ogg"),
	preload("res://assets/sfx/impactMetal_light_002.ogg"), preload("res://assets/sfx/impactMetal_light_003.ogg")]
const HURTS := [preload("res://assets/sfx/impactPlate_heavy_000.ogg"), preload("res://assets/sfx/impactPlate_heavy_001.ogg"), preload("res://assets/sfx/impactPlate_heavy_002.ogg")]
const CLICK := preload("res://assets/sfx/click_002.ogg")
const CONFIRM := preload("res://assets/sfx/confirmation_001.ogg")

static var enabled := DisplayServer.get_name() != "headless"


# Positional one-shot; skipped when too far from the listener to matter.
static func at(host: Node, pos: Vector3, stream: AudioStream, db := 0.0, max_dist := 1200.0, pitch := 1.0) -> void:
	if not enabled or not pos.is_finite(): # a NaN position makes the engine compute a NaN volume
		return
	var cam := host.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > max_dist:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.unit_size = 60.0
	p.max_distance = max_dist
	p.position = pos
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func ui(host: Node, stream: AudioStream, db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------- world ambience: 3D emitters at water and landmarks, heard as you fly close ----------
const RIVER := preload("res://assets/sfx/river_loop.wav") # CC0, "Park Ambiences" (OpenGameArt)
const BIRDS := preload("res://assets/sfx/birds_loop.wav") # CC0, "Park Ambiences" (OpenGameArt)
const WATERFALL := preload("res://assets/sfx/waterfall_loop.wav")
const CREAK := preload("res://assets/sfx/creak_loop.wav")
const RUMBLE := preload("res://assets/sfx/rumble_loop.wav")
# Props.spots keys that get a sound: [stream, volume dB, audible range m]
const SPOT_SOUNDS := {
	waterfall = [WATERFALL, 6.0, 900.0], windmill = [CREAK, 0.0, 350.0], village = [BIRDS, -2.0, 500.0],
	volcano = [RUMBLE, 10.0, 2500.0], lighthouse = [RIVER, -6.0, 400.0],
}


static func ambience(root: Node3D) -> void:
	if not enabled:
		return
	var emit := func(stream: AudioStream, at: Vector3, db: float, reach: float) -> void:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.volume_db = db
		p.unit_size = reach / 12.0
		p.max_distance = reach
		p.autoplay = true
		root.add_child(p)
		p.global_position = at
		p.play(randf() * 3.0)
	var bed := AudioStreamPlayer.new()
	bed.stream = BEDS[Worlds.index]
	bed.volume_db = BED_DB
	bed.autoplay = true
	root.add_child(bed)
	var water: Dictionary = Worlds.cur.water
	if Worlds.cur.terrain.river and water.visible:
		var pts := Terrain.RIVER
		var gap := 0.0
		for i in pts.size() - 1:
			gap += pts[i].distance_to(pts[i + 1])
			if gap > 380.0 and absf(pts[i].x) < 2600.0 and absf(pts[i].y) < 2600.0:
				gap = 0.0
				emit.call(RIVER, Vector3(pts[i].x, Terrain.WATER_Y + 2.0, pts[i].y), 0.0, 420.0)
	if Worlds.cur.terrain.lake and water.visible:
		emit.call(RIVER, Vector3(Terrain.LAKE_CENTER.x, Terrain.WATER_Y, Terrain.LAKE_CENTER.y), -3.0, 700.0)
	for key in Props.spots:
		if SPOT_SOUNDS.has(key):
			var s: Array = SPOT_SOUNDS[key]
			emit.call(s[0], Props.spots[key], s[1], s[2])
