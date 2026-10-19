class_name Sfx
extends RefCounted

# Sound bank + one-shot helpers. Kenney sounds are CC0 (assets/sfx/Kenney-License.txt);
# engine/wind/gun/beeps are synthesized by tools/make_sounds.py.
const PROP := preload("res://assets/sfx/prop_loop.wav")
const JET := preload("res://assets/sfx/jet_loop.wav")
const WIND := preload("res://assets/sfx/wind_loop.wav")
const GUN := preload("res://assets/sfx/gun.wav")
const LOCK := preload("res://assets/sfx/lock.wav")
const WARN := preload("res://assets/sfx/warn.wav")
const LAUNCH := preload("res://assets/sfx/thrusterFire_000.ogg")
const BOOMS := [preload("res://assets/sfx/lowFrequency_explosion_000.ogg"), preload("res://assets/sfx/lowFrequency_explosion_001.ogg"), preload("res://assets/sfx/explosionCrunch_000.ogg")]
const HITS := [preload("res://assets/sfx/impactMetal_light_000.ogg"), preload("res://assets/sfx/impactMetal_light_001.ogg")]
const HURT := preload("res://assets/sfx/impactPlate_heavy_000.ogg")
const CLICK := preload("res://assets/sfx/click_002.ogg")
const CONFIRM := preload("res://assets/sfx/confirmation_001.ogg")

static var enabled := DisplayServer.get_name() != "headless"


# Positional one-shot; skipped when too far from the listener to matter.
static func at(host: Node, pos: Vector3, stream: AudioStream, db := 0.0, max_dist := 1200.0) -> void:
	if not enabled:
		return
	var cam := host.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > max_dist:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.unit_size = 30.0
	p.max_distance = max_dist
	p.position = pos
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func ui(host: Node, stream: AudioStream, db := 0.0) -> void:
	if not enabled:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
