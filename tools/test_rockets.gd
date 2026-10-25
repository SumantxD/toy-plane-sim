extends SceneTree
# Rocket guidance vs a turning target: hit rate for AI (grip 1) and players' rockets (PLAYER_GRIP).
#   godot --headless --path . -s tools/test_rockets.gd
const Rockets := preload("res://rockets.gd")


class Dummy extends Node3D:
	var v := Vector3.ZERO
	func vel_estimate() -> Vector3:
		return v


func _rate(grip: float) -> float:
	var hits := 0
	var n := 0
	for ang in [-60, -30, 0, 30, 60]:
		for turn in [-0.6, -0.3, 0.3, 0.6]: # rad/s: a dodging plane
			n += 1
			var t := Dummy.new()
			t.position = Vector3(0, 0, -500).rotated(Vector3.UP, deg_to_rad(ang * 0.3))
			t.v = Vector3(70, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
			var p := Vector3.ZERO
			var v := Vector3(0, 0, -90)
			for i in 7.0 * 60:
				var dt := 1.0 / 60.0
				t.v = t.v.rotated(Vector3.UP, turn * dt)
				t.position += t.v * dt
				var tgt: Node = t if v.angle_to(t.position - p) <= Rockets.SEEKER_FOV * grip else null
				var s: Array = Rockets.step(p, v, i * dt, tgt, dt, grip)
				p = s[0]
				v = s[1]
				if p.distance_to(t.position) < Rockets.FUSE * grip + 6.0:
					hits += 1
					break
				if not tgt:
					break
			t.free()
	return float(hits) / n


func _initialize() -> void:
	var ai := _rate(1.0)
	var player := _rate(Rockets.PLAYER_GRIP)
	print("hit rate  AI rockets %d%%  player rockets %d%%" % [ai * 100, player * 100])
	assert(player >= 0.8 and player > ai)
	quit()
