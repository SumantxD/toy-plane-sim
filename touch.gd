class_name TouchControls
extends Control

# Phone controls: a floating stick on the left steers (it moves your aim like the mouse does) and thumb
# buttons on the right press the same keys a keyboard would, so the game code doesn't know the difference.
# Hold TAUNT and slide to pick a message, like the T wheel.
const STICK_R := 80.0
const BUTTONS := [ # label, key, offset from the bottom-right (or bottom-left / top-left), radius
	["FIRE", KEY_SPACE, Vector2(-130, -130), 66.0],
	["ROCKET", KEY_F, Vector2(-280, -92), 46.0],
	["FLARE", KEY_X, Vector2(-262, -232), 40.0],
	["BOMB", KEY_B, Vector2(-130, -272), 40.0],
	["BOOST", KEY_SHIFT, Vector2(-404, -70), 40.0],
	["FAST", KEY_W, Vector2(56, -330), 30.0, "left"],
	["SLOW", KEY_S, Vector2(56, -256), 30.0, "left"],
	["II", KEY_ESCAPE, Vector2(34, 132), 26.0, "top"],
	["CAM", KEY_C, Vector2(100, 132), 26.0, "top"],
	["TAUNT", KEY_T, Vector2(166, 132), 26.0, "top"],
]
const FONT := preload("res://assets/ui/kenney_future_narrow.ttf")

var main: Node
var held := {} # finger index -> button index (or -1 for the stick)
var stick_at := Vector2.ZERO
var stick := Vector2.ZERO


static func on() -> bool:
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _live() -> bool:
	return main.gs.phase == "playing" and not main.menu_open() and main._plane(multiplayer.get_unique_id()) != null


func _center(i: int) -> Vector2:
	var b: Array = BUTTONS[i]
	var pad := _pad()
	match b[4] if b.size() > 4 else "":
		"left":
			return Vector2(pad, size.y) + b[2]
		"top":
			return Vector2(pad, 0) + b[2]
	return size - Vector2(pad, 0) + b[2]


# Keep thumbs clear of the rounded corners and the camera cut-out.
func _pad() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	var k := size.x / maxf(scr.x, 1.0)
	return maxf(maxf(safe.position.x, scr.x - safe.end.x) * k, 12.0)


func _press(i: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = BUTTONS[i][1]
	e.physical_keycode = BUTTONS[i][1]
	e.pressed = down
	Input.parse_input_event(e)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _live():
				return
			for i in BUTTONS.size():
				if event.position.distance_to(_center(i)) < BUTTONS[i][3] + 12.0:
					held[event.index] = i
					_press(i, true)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if event.position.x < size.x * 0.45:
				held[event.index] = -1
				stick_at = event.position
				stick = Vector2.ZERO
				get_viewport().set_input_as_handled()
				queue_redraw()
		elif held.has(event.index):
			var i: int = held[event.index]
			held.erase(event.index)
			if i >= 0:
				_press(i, false)
			else:
				stick = Vector2.ZERO
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventScreenDrag and held.has(event.index):
		var i: int = held[event.index]
		if i < 0:
			stick = ((event.position - stick_at) / STICK_R).limit_length(1.0)
		elif BUTTONS[i][1] == KEY_T: # slide from TAUNT to pick on the wheel
			var m := InputEventMouseMotion.new()
			m.relative = event.relative * 2.0
			Input.parse_input_event(m)
		get_viewport().set_input_as_handled()
		queue_redraw()


func _process(dt: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # no cursor to capture on a phone (and captured = touch fires guns)
	visible = _live()
	if visible:
		queue_redraw()
	if not visible and not held.is_empty():
		for f in held:
			if held[f] >= 0:
				_press(held[f], false)
		held.clear()
		stick = Vector2.ZERO
	var p: Node = main._plane(multiplayer.get_unique_id())
	if not p or stick == Vector2.ZERO:
		return
	# The stick moves the aim point; it never runs more than ~55 degrees ahead of the nose.
	var curve := stick * stick.length() # fine control near the middle
	var inv: float = -1.0 if Settings.values.invert_y else 1.0
	var s: float = Settings.values.sensitivity
	p.aim_yaw -= curve.x * 2.2 * s * dt
	p.aim_pitch = clampf(p.aim_pitch - curve.y * 1.7 * s * inv * dt, -1.45, 1.45)
	var fwd: Vector3 = -p.basis.z
	var aim := -Basis.from_euler(Vector3(p.aim_pitch, p.aim_yaw, 0)).z
	if fwd.angle_to(aim) > 0.95:
		aim = fwd.slerp(aim, 0.95 / fwd.angle_to(aim))
		p.aim_yaw = atan2(-aim.x, -aim.z)
		p.aim_pitch = asin(clampf(aim.y, -1, 1))


func _draw() -> void:
	var pressed := held.values()
	for i in BUTTONS.size():
		var b: Array = BUTTONS[i]
		var c := _center(i)
		var down := i in pressed
		draw_circle(c, b[3], Color(1, 1, 1, 0.32 if down else 0.14))
		draw_arc(c, b[3], 0, TAU, 40, Color(1, 1, 1, 0.55), 2.0, true)
		var fs := 15 if b[3] > 35.0 else 11
		var w := FONT.get_string_size(b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(FONT, c + Vector2(-w / 2.0, fs * 0.35), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	if -1 in pressed:
		draw_circle(stick_at, STICK_R, Color(1, 1, 1, 0.1))
		draw_arc(stick_at, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0, true)
		draw_circle(stick_at + stick * STICK_R, 30.0, Color(1, 1, 1, 0.45))
	else:
		var hint := Vector2(_pad() + 150, size.y - 130)
		draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0, true)
		draw_string(FONT, hint + Vector2(-34, 5), "STEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.4))
