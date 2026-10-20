class_name Taunts
extends Control

# Quick taunts: hold T for a wheel of preset messages, the mouse picks one, releasing T sends it; the
# scroll wheel flips pages. Only the message number crosses the network (the host checks it and the
# 2 s limit), so there is no free text to moderate. Bubbles are comic clouds over the sender's plane.
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
const RANGE := 1500.0 # no bubbles for planes further than this: no clutter, no long-range spotting

var main: Node
var open := false
var page := 0
var pick := -1
var aim := Vector2.ZERO
static var _tex: ImageTexture


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


# From main._input: true when the wheel used the event (so the plane doesn't also steer with it).
func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode == KEY_T and not event.echo:
		if event.pressed and not open and main.can_taunt():
			open = true
			aim = Vector2.ZERO
			pick = -1
			show()
			queue_redraw()
			return true
		if not event.pressed and open:
			open = false
			hide()
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
		page = posmod(page + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), LIST.size() / PER_PAGE)
		queue_redraw()
		return true
	return false


func _draw() -> void:
	var c := size / 2.0
	var font: Font = preload("res://assets/ui/kenney_future_narrow.ttf")
	draw_circle(c, 70.0, Color(0.03, 0.05, 0.1, 0.6))
	draw_string(font, c + Vector2(-60, 6), "PAGE %d/%d" % [page + 1, LIST.size() / PER_PAGE], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.7))
	draw_string(font, c + Vector2(-90, 30), "scroll: more", HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(1, 1, 1, 0.5))
	for i in PER_PAGE:
		var p := c + Vector2.from_angle(i * TAU / PER_PAGE) * 215.0
		var text: String = LIST[page * PER_PAGE + i]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 28.0
		var r := Rect2(p - Vector2(w / 2.0, 20), Vector2(w, 40))
		var lit := i == pick
		draw_style_box(Menus._box(Color(Menus.AMBER, 0.85) if lit else Color(0.05, 0.08, 0.16, 0.85), Menus.AMBER if lit else Color(1, 1, 1, 0.25), 2, 6), r)
		draw_string(font, r.position + Vector2(14, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.05, 0.08, 0.16) if lit else Color.WHITE)


# Comic speech cloud over `plane` for ~3 s. Screen-facing and fixed-size so it reads while banking.
static func pop(plane: Node3D, text: String) -> void:
	var cam := plane.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(plane.global_position) > RANGE:
		return
	var old := plane.get_node_or_null("Bubble")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "Bubble"
	root.top_level = true # follows the plane's position (plane.gd), not its roll
	plane.add_child(root)
	root.global_position = plane.global_position + Vector3.UP * 9.0
	var cloud := Sprite3D.new()
	cloud.texture = _cloud()
	cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cloud.fixed_size = true
	cloud.no_depth_test = true
	cloud.pixel_size = 0.0011
	cloud.scale.x = clampf(0.4 + text.length() * 0.1, 1.0, 2.8) # stretch to fit the message
	cloud.render_priority = 10
	root.add_child(cloud)
	var label := Label3D.new()
	label.text = text
	label.font = preload("res://assets/ui/kenney_future_narrow.ttf")
	label.font_size = 40
	label.modulate = Color(0.08, 0.08, 0.12)
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.pixel_size = 0.0008
	label.position.y = 0.012 # sits in the round part, above the tail
	label.render_priority = 11
	root.add_child(label)
	root.scale = Vector3.ONE * 0.2
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(root, "scale", Vector3.ONE, 0.08)
	tw.tween_interval(2.6)
	tw.parallel().tween_property(cloud, "modulate:a", 0.0, 0.4).set_delay(2.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(2.6)
	tw.tween_callback(root.queue_free)


# White cloud with a black outline and a little tail, drawn once.
static func _cloud() -> ImageTexture:
	if _tex:
		return _tex
	var w := 256
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(128, 54)
	var tail := [Vector2(96, 90), Vector2(126, 92), Vector2(78, 124)]
	for y in h:
		for x in w:
			var d := Vector2((x - c.x) / 122.0, (y - c.y) / 50.0).length()
			var t := Geometry2D.point_is_inside_triangle(Vector2(x, y), tail[0], tail[1], tail[2])
			if d <= 0.93 or (t and d > 0.9):
				img.set_pixel(x, y, Color.WHITE)
			elif d <= 1.0 or Geometry2D.point_is_inside_triangle(Vector2(x, y), tail[0] + Vector2(-6, -4), tail[1] + Vector2(6, -4), tail[2] + Vector2(-3, 4)):
				img.set_pixel(x, y, Color(0.06, 0.06, 0.1))
	_tex = ImageTexture.create_from_image(img)
	return _tex
