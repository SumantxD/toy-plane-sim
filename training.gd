class_name Training
extends Control

# First flight: a free flight with three one-line steps (steer, guns on balloons, a rocket on a target),
# then "Great flying!" and straight into a Very Easy battle. SKIP (top-left) or finishing marks it done
# (Settings.onboarded), so it shows once; HOW TO PLAY > TRAINING flies it again.
const FONT := preload("res://assets/ui/kenney_future.ttf")
const STEPS := ["steer", "guns", "rocket", "done"]
var main: Node
var active := false
var step := 0
var turned := 0.0
var aim := Vector2.INF
var base := 0
var t := 0.0
var targets: Array = []
var prompt := Label.new()
var count := Label.new()
var skip_btn: Button


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := Menus.insets(self)
	for l: Label in [prompt, count]:
		l.set_anchors_preset(Control.PRESET_TOP_WIDE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", FONT)
		l.add_theme_constant_override("outline_size", 12)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	prompt.add_theme_font_size_override("font_size", 34)
	prompt.offset_top = 172 # under the HUD readout and the top touch row
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Menus.AMBER)
	count.offset_top = 150
	skip_btn = Menus.tile(self, "SKIP" if TouchControls.on() else "SKIP  (ENTER)", skip, main, 18, Vector2(120, 68))
	skip_btn.name = "Skip"
	skip_btn.position = Vector2(maxf(ins.x, 20.0), maxf(ins.y, 12.0))
	hide()


func begin() -> void:
	active = true
	step = 0
	turned = 0.0
	aim = Vector2.INF
	targets.clear()
	_show()
	show()


func _show() -> void:
	var touch := TouchControls.on()
	prompt.text = [("DRAG TO STEER" if touch else "MOVE THE MOUSE TO STEER"), ("HOLD FIRE: POP 3 BALLOONS" if touch else "CLICK OR SPACE: POP 3 BALLOONS"),
		("HOLD ROCKET ON THE TARGET, LET GO" if touch else "HOLD RIGHT CLICK ON THE TARGET, LET GO"), "GREAT FLYING! NOW A REAL BATTLE"][step]
	count.text = "TRAINING  %d / 3" % (step + 1) if step < 3 else ""
	prompt.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if step == 3 else Color.WHITE)
	t = 0.0
	Sfx.ui(main, Sfx.CONFIRM, -4.0, 1.0 + 0.1 * step)


func skip() -> void:
	if not active:
		return
	_done()
	main.quick_battle()


func _done() -> void:
	active = false
	hide()
	for n in targets:
		if is_instance_valid(n):
			n.queue_free()
	targets.clear()
	Settings.values.onboarded = true
	Settings.save()


func _process(dt: float) -> void:
	if not active:
		return
	if main.gs.phase != "playing" or main.gs.mode != 2:
		_done() # left the flight some other way (pause > leave)
		return
	t += dt
	queue_redraw()
	var p: Node = main._plane(main.multiplayer.get_unique_id())
	if not p:
		return
	var c: Dictionary = Progress.cur
	match STEPS[step]:
		"steer":
			var a := Vector2(p.aim_yaw, p.aim_pitch)
			if aim != Vector2.INF and p.steer_t < 0.3:
				turned += absf(wrapf(a.x - aim.x, -PI, PI)) + absf(a.y - aim.y)
			aim = a
			if turned > 1.6:
				_next(p)
		"guns":
			if c.get("balloons", 0) - base >= 3:
				_next(p)
		"rocket":
			if c.get("rhits", 0) > base:
				_next(p)
		"done":
			if t > 2.5:
				_done()
				main.training_battle()


func _next(p: Node) -> void:
	step += 1
	_show()
	var fwd: Vector3 = -p.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP)
	if STEPS[step] == "guns": # three balloons just ahead, in a gentle spread
		base = Progress.cur.get("balloons", 0)
		for i in 3:
			_target(p.position + fwd * (260.0 + 60.0 * i) + side * (i - 1) * 45.0 + Vector3.UP * 10.0 * i)
	elif STEPS[step] == "rocket":
		base = Progress.cur.get("rhits", 0)
		_target(p.position + fwd * 420.0 + Vector3.UP * 20.0)


func _target(at: Vector3) -> void:
	at.y = maxf(at.y, Terrain.floor_below(Vector3(at.x, 3000.0, at.z)) + 60.0)
	targets.append(main._spawn_ai("balloon", 1, at, 0.0, at))


# Where to look: a pulsing ring on each training target (an arrow at the edge when it's off screen),
# and on phones a ring around the button this step needs.
func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or step == 0 or step == 3:
		return
	var k := 0.5 + 0.5 * sin(t * 6.0)
	for n in targets:
		if not is_instance_valid(n) or not n.alive:
			continue
		var at: Vector3 = n.position
		var q := cam.unproject_position(at)
		if not cam.is_position_behind(at) and get_rect().grow(-40.0).has_point(q):
			draw_arc(q, 26.0 + 8.0 * k, 0, TAU, 32, Color(Menus.AMBER, 0.9), 3.0)
		else:
			var local := cam.global_transform.basis.inverse() * (at - cam.global_position)
			var dir := Vector2(local.x, -local.y).normalized()
			if local.z > 0.0:
				dir = (dir * 0.5 + Vector2.DOWN).normalized()
			var tip := size / 2.0 + dir * minf(size.x, size.y) * 0.36
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip + dir * 20.0, tip - dir * 10.0 + side * 16.0, tip - dir * 10.0 - side * 16.0]), Menus.AMBER)
	if main.touch:
		var id := "fire" if step == 1 else "rocket"
		draw_arc(main.touch._center(id), main.touch._radius(id) + 10.0 + 10.0 * k, 0, TAU, 40, Color(Menus.AMBER, 1.0 - 0.6 * k), 4.0)


# The phone's steering layer takes every touch first: SKIP must win the ones on it.
func covers(at: Vector2) -> bool:
	return active and visible and skip_btn.get_global_rect().has_point(at)


func _unhandled_input(e: InputEvent) -> void:
	if active and e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		skip()
		get_viewport().set_input_as_handled()
