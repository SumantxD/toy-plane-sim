class_name TouchControls
extends Control

# Phone controls: a stick on the left steers (it moves your aim like the mouse does), thumb buttons press
# the same keys a keyboard would, so the game code doesn't know the difference. Settings > Touch controls
# has tilt steering, auto-fire, vibration, left-handed, a fixed stick, opacity and a layout editor
# (drag to move, BIGGER/SMALLER) saved as screen fractions so it fits any phone.
const FONT := preload("res://assets/ui/kenney_future_narrow.ttf")
const ELEMS := [ # id, label, key (or kind), default offset from the anchor corner, radius
	{id = "fire", label = "FIRE", key = KEY_SPACE, at = Vector2(-130, -130), corner = "br", r = 66.0},
	{id = "rocket", label = "ROCKET", key = KEY_F, at = Vector2(-280, -92), corner = "br", r = 46.0},
	{id = "flare", label = "FLARE", key = KEY_X, at = Vector2(-262, -232), corner = "br", r = 40.0},
	{id = "bomb", label = "BOMB", key = KEY_B, at = Vector2(-130, -272), corner = "br", r = 40.0},
	{id = "boost", label = "BOOST", key = KEY_SHIFT, at = Vector2(-404, -70), corner = "br", r = 40.0},
	{id = "supply", label = "BUY", fan = [["AA GUN", KEY_3], ["SAM", KEY_4], ["RADAR", KEY_5], ["FIX HQ", KEY_6]], at = Vector2(-400, -196), corner = "br", r = 32.0},
	{id = "pause", label = "II", key = KEY_ESCAPE, at = Vector2(34, 132), corner = "tl", r = 26.0},
	{id = "cam", label = "CAM", key = KEY_C, at = Vector2(100, 132), corner = "tl", r = 26.0},
	{id = "taunt", label = "TAUNT", key = KEY_T, at = Vector2(166, 132), corner = "tl", r = 26.0},
	{id = "team", label = "TEAM", fan = [["HELP!", KEY_1], ["ON ME", KEY_2]], at = Vector2(232, 132), corner = "tl", r = 26.0},
	{id = "map", label = "MAP", at = Vector2(298, 132), corner = "tl", r = 26.0},
	{id = "throttle", label = "THR", slider = true, at = Vector2(46, -300), corner = "bl", r = 24.0},
	{id = "stick", label = "STEER", stick = true, at = Vector2(170, -130), corner = "bl", r = 80.0},
]
const THROTTLE_LEN := 190.0

var main: Node
var held := {} # finger -> element id ("stick", "throttle", a button, "fan")
var stick_at := Vector2.ZERO
var stick := Vector2.ZERO
var fan := "" # element whose radial menu is open
var fire_held := false
var space_down := false
var tilt_base := Vector3.ZERO
var editing := false
var sel := ""
var drag_off := Vector2.ZERO
var grab := {} # editor: finger -> element being dragged


static func on() -> bool:
	return phone() or "--touch" in OS.get_cmdline_user_args()


# Running as the phone build (--phone tests the phone-only paths on a desktop).
static func phone() -> bool:
	return OS.has_feature("mobile") or "--phone" in OS.get_cmdline_user_args()


# A short buzz (hits, getting hit, missile warning) when the player wants it.
static func buzz(ms: int) -> void:
	if phone() and Settings.values.get("vibrate", true):
		Input.vibrate_handheld(ms)


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("touch_controls")


func _live() -> bool:
	return main.gs.phase == "playing" and not main.menu_open() and main._plane(multiplayer.get_unique_id()) != null


func _elem(id: String) -> Dictionary:
	for e in ELEMS:
		if e.id == id:
			return e
	return {}


# Keep thumbs clear of the rounded corners and the camera cut-out.
func _pad() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	var k := size.x / maxf(scr.x, 1.0)
	return maxf(maxf(safe.position.x, scr.x - safe.end.x) * k, 12.0)


func _scale(id: String) -> float:
	var saved: Array = Settings.values.touch_layout.get(id, [])
	return saved[2] if saved.size() == 3 else 1.0


func _radius(id: String) -> float:
	return _elem(id).r * _scale(id)


# Where an element sits: its saved spot (screen fractions), else its default corner offset; mirrored
# for left-handed play.
func _center(id: String) -> Vector2:
	var e := _elem(id)
	var saved: Array = Settings.values.touch_layout.get(id, [])
	var c: Vector2
	if saved.size() == 3:
		c = Vector2(saved[0] * size.x, saved[1] * size.y)
	else:
		var pad := _pad()
		match e.corner:
			"bl":
				c = Vector2(pad, size.y) + e.at
			"tl":
				c = Vector2(pad, 0) + e.at
			_:
				c = size - Vector2(pad, 0) + e.at
	if Settings.values.touch_lefty:
		c.x = size.x - c.x
	return c


func _throttle_rect() -> Rect2:
	var c := _center("throttle")
	var w := _radius("throttle")
	var h := THROTTLE_LEN * _scale("throttle")
	return Rect2(c - Vector2(w, h / 2.0), Vector2(w * 2.0, h))


func _hit(id: String, p: Vector2) -> bool:
	if id == "throttle":
		return _throttle_rect().grow(10.0).has_point(p)
	return p.distance_to(_center(id)) < _radius(id) + 10.0


func _shown(id: String) -> bool:
	return main.gs.mode != 2 or id not in ["supply", "team"] # free flight: nothing to buy, no team


func _fan_items(id: String) -> Array:
	return _elem(id).fan.filter(func(it): return it[1] != KEY_6 or main.gs.mode == 5) # HQ repair: Base Assault only


func _fan_spots(id: String) -> Array:
	var n := _fan_items(id).size()
	var c := _center(id)
	var dir := (size / 2.0 - c).normalized()
	var out := []
	for i in n:
		out.append(c + dir.rotated((i - (n - 1) / 2.0) * 0.75) * (_radius(id) + 62.0))
	return out


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _set_throttle(y: float) -> void:
	var p: Node = main._plane(multiplayer.get_unique_id())
	var r := _throttle_rect()
	if p:
		p.throttle = clampf(1.0 - (y - r.position.y) / r.size.y, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if editing:
		_edit_input(event)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _live():
				return
			if main.taunts and main.taunts.open: # a second finger flips the taunt wheel's page
				main.taunts.flip()
				held[event.index] = "flip"
				get_viewport().set_input_as_handled()
				return
			_press(event.index, event.position)
			if held.has(event.index):
				get_viewport().set_input_as_handled()
				queue_redraw()
		elif held.has(event.index):
			var id: String = held[event.index]
			held.erase(event.index)
			if id == "stick":
				stick = Vector2.ZERO
			elif id == "fire":
				fire_held = false
			elif _elem(id).has("key"):
				_key(_elem(id).key, false)
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventScreenDrag and held.has(event.index):
		var id: String = held[event.index]
		if id == "stick":
			stick = ((event.position - stick_at) / _radius("stick")).limit_length(1.0)
		elif id == "throttle":
			_set_throttle(event.position.y)
		elif id == "taunt": # slide from TAUNT to pick on the wheel
			var m := InputEventMouseMotion.new()
			m.relative = event.relative * 2.0
			Input.parse_input_event(m)
		get_viewport().set_input_as_handled()
		queue_redraw()


func _press(finger: int, at: Vector2) -> void:
	var was := fan
	if fan != "":
		var spots := _fan_spots(fan)
		var items := _fan_items(fan)
		fan = ""
		for i in spots.size():
			if at.distance_to(spots[i]) < 34.0:
				_key(items[i][1], true)
				_key(items[i][1], false)
				held[finger] = "fan"
				return
	for e in ELEMS:
		if e.has("stick") or not _shown(e.id) or not _hit(e.id, at):
			continue
		held[finger] = e.id
		if e.has("fan"):
			fan = "" if was == e.id else e.id
		elif e.id == "map":
			_cycle_map()
		elif e.id == "throttle":
			_set_throttle(at.y)
		elif e.id == "fire":
			fire_held = true
		else:
			_key(e.key, true)
		return
	if at.x > size.x * 0.55 if Settings.values.touch_lefty else at.x < size.x * 0.45:
		held[finger] = "stick"
		stick_at = _center("stick") if Settings.values.touch_fixed else at
		stick = ((at - stick_at) / _radius("stick")).limit_length(1.0)


# MAP: shown -> zoomed in -> hidden -> shown.
func _cycle_map() -> void:
	if not main.show_map:
		main.show_map = true
		main.map_zoom = 1.0
	elif main.map_zoom == 1.0:
		main.map_zoom = 2.5
	else:
		main.map_zoom = 1.0
		main.show_map = false


func _process(dt: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # no cursor to capture on a phone (and captured = touch fires guns)
	visible = editing or _live()
	if visible:
		queue_redraw()
	if not visible or editing:
		for f in held:
			var e := _elem(held[f])
			if e.has("key") and e.id != "fire":
				_key(e.key, false)
		held.clear()
		stick = Vector2.ZERO
		fire_held = false
		fan = ""
		tilt_base = Vector3.ZERO # recalibrate tilt next time you fly
	var p: Node = main._plane(multiplayer.get_unique_id()) if visible and not editing else null
	var want_fire: bool = fire_held or (p != null and Settings.values.autofire and p._assist(-p.basis.z) != -p.basis.z)
	if want_fire != space_down:
		space_down = want_fire
		_key(KEY_SPACE, want_fire)
	if not p:
		return
	var steer := stick
	if Settings.values.tilt and steer == Vector2.ZERO:
		steer = _tilt()
	if steer == Vector2.ZERO:
		return
	# The stick moves the aim point; it never runs more than ~55 degrees ahead of the nose.
	var curve := steer * steer.length() # fine control near the middle
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


# Tilt like a steering wheel (roll = turn), top away = nose down. Gravity arrives screen-aligned
# (x right, y up, z toward you); however you hold the phone when you start flying is "level".
func _tilt() -> Vector2:
	var g := Input.get_gravity()
	if g.length() < 1.0:
		return Vector2.ZERO
	g = g.normalized()
	if tilt_base == Vector3.ZERO:
		tilt_base = g
	var lean := atan2(-g.z, -g.y) - atan2(-tilt_base.z, -tilt_base.y)
	var t := Vector2(g.x - tilt_base.x, lean) / 0.35 # ~20 degrees = full stick
	t = Vector2(signf(t.x) * maxf(absf(t.x) - 0.1, 0.0), signf(t.y) * maxf(absf(t.y) - 0.1, 0.0)) # dead zone
	return t.limit_length(1.0)


# ---------- layout editor ----------

const TOOLS := ["SMALLER", "BIGGER", "RESET", "DONE"]


var on_done := Callable()


func edit(done := Callable()) -> void:
	on_done = done
	editing = true
	sel = ""
	visible = true


func _tool_rect(i: int) -> Rect2:
	var w := 130.0
	var x0 := size.x / 2.0 - TOOLS.size() * (w + 12.0) / 2.0
	return Rect2(Vector2(x0 + i * (w + 12.0), size.y * 0.42), Vector2(w, 44))


func _edit_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled() # the finger's emulated mouse must not click the menu underneath
		return
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		for i in TOOLS.size():
			if _tool_rect(i).has_point(event.position):
				_tool(TOOLS[i])
				return
		sel = ""
		for e in ELEMS:
			if _hit(e.id, event.position):
				sel = e.id
				drag_off = _center(e.id) - event.position
				grab[event.index] = e.id
				return
	elif event is InputEventScreenTouch:
		grab.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and grab.has(event.index):
		_store(grab[event.index], (event.position + drag_off).clamp(Vector2.ZERO, size), _scale(grab[event.index]))
		get_viewport().set_input_as_handled()


func _store(id: String, c: Vector2, s: float) -> void:
	if Settings.values.touch_lefty:
		c.x = size.x - c.x
	var layout: Dictionary = Settings.values.touch_layout.duplicate()
	layout[id] = [c.x / size.x, c.y / size.y, s]
	Settings.values.touch_layout = layout


func _tool(name: String) -> void:
	match name:
		"SMALLER", "BIGGER":
			if sel != "":
				_store(sel, _center(sel), clampf(_scale(sel) * (0.85 if name == "SMALLER" else 1.18), 0.5, 2.0))
		"RESET":
			Settings.values.touch_layout = {}
			sel = ""
		"DONE":
			editing = false
			grab.clear()
			Settings.save()
			if on_done.is_valid():
				on_done.call()


func _draw() -> void:
	var alpha: float = 1.0 if editing else Settings.values.touch_opacity
	if editing:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.1, 0.8))
		draw_string(FONT, Vector2(0, size.y * 0.42 - 18), "Drag a control to move it. Tap one, then BIGGER / SMALLER.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
		for i in TOOLS.size():
			var r := _tool_rect(i)
			draw_rect(r, Menus.AMBER if TOOLS[i] == "DONE" else Color(1, 1, 1, 0.25))
			draw_string(FONT, r.position + Vector2(0, 29), TOOLS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color.BLACK if TOOLS[i] == "DONE" else Color.WHITE)
	var pressed := held.values()
	for e in ELEMS:
		if not editing and not _shown(e.id):
			continue
		var c := _center(e.id)
		var r := _radius(e.id)
		var lit: bool = e.id in pressed or (e.id == "fire" and space_down) or e.id == fan or e.id == sel
		var ring := Color(1, 0.83, 0.3, alpha) if e.id == sel else Color(1, 1, 1, 0.55 * alpha)
		if e.has("slider"):
			var tr := _throttle_rect()
			var p: Node = main._plane(multiplayer.get_unique_id())
			var k: float = p.throttle if p else 0.5
			draw_rect(tr, Color(0.04, 0.06, 0.12, 0.32 * alpha))
			draw_rect(Rect2(tr.position + Vector2(0, tr.size.y * (1.0 - k)), Vector2(tr.size.x, tr.size.y * k)), Color(1, 1, 1, 0.22 * alpha))
			draw_rect(tr, ring, false, 2.0)
			draw_string(FONT, Vector2(tr.position.x - 20, tr.position.y - 8), "%d%%" % roundi(k * 100), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x + 40, 12, Color(1, 1, 1, 0.85 * alpha))
		elif e.has("stick"):
			if "stick" in pressed and not editing:
				draw_circle(stick_at, r, Color(1, 1, 1, 0.1 * alpha))
				draw_arc(stick_at, r, 0, TAU, 48, Color(1, 1, 1, 0.4 * alpha), 2.0, true)
				draw_circle(stick_at + stick * r, 30.0, Color(1, 1, 1, 0.45 * alpha))
			else:
				draw_arc(c, r, 0, TAU, 48, Color(ring, ring.a * (1.0 if editing else 0.35)), 2.0, true)
				draw_string(FONT, c + Vector2(-r, 5), e.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 13, Color(1, 1, 1, 0.4 * alpha))
		else:
			draw_circle(c, r, Color(1, 1, 1, 0.35 * alpha) if lit else Color(0.04, 0.06, 0.12, 0.32 * alpha)) # dark glass: readable on cloud and sky
			draw_arc(c, r, 0, TAU, 40, ring, 2.0, true)
			var fs := 15 if r > 35.0 else 11
			draw_string_outline(FONT, c + Vector2(-r, fs * 0.35), e.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, Color(0, 0, 0, 0.5 * alpha))
			draw_string(FONT, c + Vector2(-r, fs * 0.35), e.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.9 * alpha))
	if fan != "":
		var items := _fan_items(fan)
		var spots := _fan_spots(fan)
		for i in spots.size():
			draw_circle(spots[i], 32.0, Color(0.1, 0.12, 0.2, 0.75))
			draw_arc(spots[i], 32.0, 0, TAU, 32, Menus.AMBER, 2.0, true)
			draw_string(FONT, spots[i] + Vector2(-32, 4), items[i][0], HORIZONTAL_ALIGNMENT_CENTER, 64, 11, Color.WHITE)
