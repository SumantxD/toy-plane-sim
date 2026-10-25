extends SceneTree
# Plays the phone build with simulated fingers: menu taps, launch, fire, steer, pause, resume.
# godot --path . --resolution 1340x618 -s tools/test_touch.gd -- --touch   (needs a window)
var main: Node


func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * at # viewport -> window pixels
	e.pressed = down
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2, finger := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.relative = rel
	Input.parse_input_event(e)


func _tap(at: Vector2) -> void:
	_touch(at, true)
	await process_frame
	_touch(at, false)
	for i in 10:
		await process_frame


func _button(parent: Node, text: String) -> Control:
	for c in parent.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and "text" in c and str(c.text).strip_edges() == text:
			return c
	return null


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await process_frame
	var tc: Control = main.find_children("*", "TouchControls", true, false)[0]
	print("touch layer: ", tc != null, "   quit button shown: ", _button(main, "QUIT") != null)
	var b := _button(main, "BATTLE VS AI")
	await _tap(b.get_global_rect().get_center())
	for i in 30:
		await process_frame
	print("tap BATTLE VS AI -> phase ", main.gs.phase)
	b = _button(main, "LAUNCH")
	await _tap(b.get_global_rect().get_center())
	while main.gs.get("countdown", 1.0) > 0.0 or main._plane(1) == null:
		await process_frame
	for i in 20:
		await process_frame
	var p: Node = main._plane(1)
	print("tap LAUNCH -> phase ", main.gs.phase, "   controls visible: ", tc.visible)
	var fire: Vector2 = tc._center(0)
	var most := 0
	_touch(fire, true, 1)
	for i in 60:
		await process_frame
		most = maxi(most, main.bullets.shots.filter(func(s): return s.owner == p).size())
	_touch(fire, false, 1)
	print("hold FIRE 1 s -> your rounds in the air: ", most)
	var yaw0: float = p.rotation.y
	var at := Vector2(200, tc.size.y - 140)
	_touch(at, true, 2)
	await process_frame
	_drag(at + Vector2(80, 0), Vector2(80, 0), 2)
	for i in 90:
		await process_frame
	_touch(at + Vector2(80, 0), false, 2)
	print("stick right 1.5 s -> heading changed %.0f deg" % rad_to_deg(absf(angle_difference(yaw0, p.rotation.y))))
	await _tap(tc._center(7))
	print("tap II -> pause menu: ", main.pause_root.visible)
	b = _button(main.pause_root, "RESUME")
	await _tap(b.get_global_rect().get_center())
	print("tap RESUME -> pause menu: ", main.pause_root.visible, "   controls visible: ", tc.visible)
	quit()
