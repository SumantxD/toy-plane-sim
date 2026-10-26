class_name Taunts
extends Control

# Quick taunts: hold T for a wheel of preset messages, the mouse picks one, releasing T sends it; the
# scroll wheel (on touch, a second finger) flips pages. Only the message number crosses the network (the host checks it and the
# 2 s limit), so there is no free text to moderate. The message is skywritten: puffy smoke letters
# that pop in one after another, wobble, then drift off and dissolve.
const LIST := [
	"Can't catch me!", "Too easy!", "Skill issue!", # cocky
	"Nice aim, buddy!", "You missed!", "Are you even trying?", # teasing
	"Catch me if you can!", "Gone with the wind!", "See you below!", # flying
	"Incoming!", "Surprise!", "That had to hurt!", # combat
	"Let's go!", "What a shot!", "GG!", # celebrate
	"I meant to do that!", "Totally calculated!", "Oops!", # oops
	"Nice flying!", "Well played!", "Good one!", # friendly
	"Need backup!", "Follow me!", "Defend our base!", # team
]
const PER_PAGE := 8
const RANGE := 1600.0 # skip skywriting this far away: no clutter, no long-range spotting
const FONT := preload("res://assets/ui/kenney_future_narrow.ttf")
# 5x7 block letters (one int per row, 5 bits, left = 16): the skywriting "font".
const GLYPHS := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "!": [4, 4, 4, 4, 4, 0, 4], "?": [14, 17, 1, 2, 4, 0, 4],
	".": [0, 0, 0, 0, 0, 12, 12], ",": [0, 0, 0, 0, 12, 4, 8], "'": [4, 4, 8, 0, 0, 0, 0], "-": [0, 0, 0, 31, 0, 0, 0],
}

var main: Node
var open := false
var page := 0
var pick := -1
var aim := Vector2.ZERO


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# From main._input: true when the wheel used the event (so the plane doesn't also steer with it).
func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode == KEY_T and not event.echo:
		if event.pressed and not open and main.can_taunt():
			open = true
			aim = Vector2.ZERO
			pick = -1
			queue_redraw()
			return true
		if not event.pressed and open:
			open = false
			queue_redraw()
			if pick >= 0:
				main.send_taunt(page * PER_PAGE + pick)
			return true
	if not open:
		return false
	if event is InputEventMouseMotion:
		aim = (aim + event.relative).limit_length(120.0)
		pick = -1 if aim.length() < 30.0 else posmod(roundi(aim.angle() / (TAU / PER_PAGE)), PER_PAGE)
		queue_redraw()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		flip(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return true
	return false


func flip(by := 1) -> void:
	page = posmod(page + by, LIST.size() / PER_PAGE)
	queue_redraw()


# Skywrite `text` for `plane`: above other planes, facing this screen's camera so it reads; yours goes
# up ahead of you so you can read it without it covering the crosshair.
func say(plane: Node3D, text: String) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or cam.global_position.distance_to(plane.global_position) > RANGE:
		return
	var right := cam.global_basis.x
	right = Vector3(right.x, 0.0, right.z).normalized()
	var at: Vector3
	if plane.is_local():
		var fwd := -cam.global_basis.z
		at = plane.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 230.0 + Vector3.UP * 42.0
	else:
		at = plane.global_position + Vector3.UP * 32.0
	var tint: Color = Color(1.0, 0.85, 0.4) if plane.team > 1 else plane.TEAM_COLORS[plane.team]
	var sky := SkyText.new()
	main.add_child(sky)
	sky.write(text.to_upper(), at, right, SkyText.cloud(tint))


func _draw() -> void:
	if not open:
		return
	var c := size / 2.0
	var pages := LIST.size() / PER_PAGE
	for k in pages: # page dots in a little cloud
		draw_circle(c + Vector2((k - (pages - 1) / 2.0) * 14.0, 0), 5.0, Color(1, 1, 1, 0.95 if k == page else 0.35))
	draw_string(FONT, c + Vector2(-60, 26), "tap 2nd finger: more" if TouchControls.on() else "scroll", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 1, 1, 0.7))
	for i in PER_PAGE:
		var text: String = LIST[page * PER_PAGE + i]
		var lit := i == pick
		var p := c + Vector2.from_angle(i * TAU / PER_PAGE) * 150.0
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 30.0
		var r := Rect2(p - Vector2(w / 2.0, 16), Vector2(w, 32))
		var box := StyleBoxFlat.new() # a white puff of cloud, amber when picked
		box.bg_color = Menus.AMBER if lit else Color(1, 1, 1, 0.82)
		box.set_corner_radius_all(16)
		box.shadow_color = Color(0, 0, 0, 0.18)
		box.shadow_size = 6
		draw_style_box(box, r)
		draw_string(FONT, r.position + Vector2(15, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.08, 0.1, 0.18))


# Smoke letters in the sky: one MultiMesh of cloud puffs in the same cel-shaded white as the game's
# clouds. Columns appear left to right as if written, each puff pops with a bounce and wobbles, then the
# words break up: puffs drift up and apart and shrink away, like real skywriting in the wind.
class SkyText extends MultiMeshInstance3D:
	const SPACING := 2.6
	const WRITE := 1.3 # seconds to write the whole line
	const HOLD := 3.2
	const FADE := 1.6
	var puffs: Array = [] # [base position, appear time, size, wobble phase], sorted by appear time
	var t := 0.0
	var lo := 0 # puffs before this have finished popping in
	var wob_t := 0.0

	# The game's own cloud shader (white tops, blue-grey undersides, no ink outline), held still: no
	# drift, no flat cut base, and only fading right at the camera. Tinted a little toward the team.
	static func cloud(tint: Color) -> ShaderMaterial:
		var cc: Dictionary = Worlds.get_cfg("clouds")
		var m := ShaderMaterial.new()
		m.shader = preload("res://clouds.gdshader")
		m.set_shader_parameter("sun_dir", Atmos.sun_dir())
		m.set_shader_parameter("top", (cc.top as Color).lerp(tint, 0.1))
		m.set_shader_parameter("mid", (cc.mid as Color).lerp(tint, 0.18))
		m.set_shader_parameter("bottom", (cc.bottom as Color).lerp(tint, 0.25))
		m.set_shader_parameter("wind", Vector2.ZERO)
		m.set_shader_parameter("near_fade", 25.0)
		m.render_priority = 1
		return m

	func write(text: String, center: Vector3, right: Vector3, cloud: Material) -> void:
		var cols := 0
		for ch in text:
			cols += 6 if GLYPHS.has(ch) or ch == " " else 0
		var origin := center - right * (cols * SPACING / 2.0) + Vector3.UP * (3.5 * SPACING)
		var x := 0
		for ch in text:
			var rows: Array = GLYPHS.get(ch, [])
			if ch == " ":
				x += 6
				continue
			if rows.is_empty():
				continue
			for row in 7:
				for col in 5:
					if rows[row] & (16 >> col):
						var p := origin + right * ((x + col) * SPACING) + Vector3.DOWN * (row * SPACING)
						var when := float(x + col) / maxf(cols, 1.0) * WRITE
						puffs.append([p + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5)), when, randf_range(1.7, 2.2), randf() * TAU])
						if randf() < 0.45: # a smaller puff beside it: fluffy, not dotted
							puffs.append([p + Vector3(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2), randf_range(-0.8, 0.8)), when + 0.05, randf_range(0.9, 1.3), randf() * TAU])
			x += 6
		puffs.sort_custom(func(a, b): return a[1] < b[1])
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 10
		ball.rings = 5
		ball.material = cloud
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = ball
		multimesh.instance_count = puffs.size()
		for i in puffs.size():
			multimesh.set_instance_custom_data(i, Color(0.0, -1e6, 0.0, 0.0)) # cloud shader: no base cut
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_place()

	# Phones can't move ~500 puffs every frame: while writing only the ones popping in move each frame;
	# the gentle wobble runs at 10 Hz; only the fade at the end moves everything every frame.
	func _process(dt: float) -> void:
		t += dt
		wob_t -= dt
		if t > WRITE + HOLD or wob_t <= 0.0:
			wob_t = 0.1
			_place(0, puffs.size())
		else:
			while lo < puffs.size() and t - puffs[lo][1] > 0.35:
				lo += 1
			var hi := lo
			while hi < puffs.size() and puffs[hi][1] <= t:
				hi += 1
			_place(lo, hi)
		if t > WRITE + HOLD + FADE:
			queue_free()

	func _place(from := 0, to := -1) -> void:
		var gone := clampf((t - WRITE - HOLD) / FADE, 0.0, 1.0) # 0 while readable, 1 when blown away
		for i in range(from, puffs.size() if to < 0 else to):
			var p: Array = puffs[i]
			var age: float = t - p[1]
			var s := 0.0
			if age > 0.0:
				var pop := clampf(age / 0.3, 0.0, 1.0)
				s = p[2] * (1.0 + 0.25 * sin(pop * PI)) * pop * (1.0 - gone * gone) # bouncy pop in, shrink away at the end
			var wob := Vector3(sin(t * 1.6 + p[3]), cos(t * 1.3 + p[3]), 0.0) * 0.3
			var drift := Vector3(sin(p[3]) * 6.0, 4.0 + cos(p[3]) * 3.0, cos(p[3] * 1.7) * 4.0) * gone # break up in the wind
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * maxf(s, 0.001)), p[0] + wob + drift))
