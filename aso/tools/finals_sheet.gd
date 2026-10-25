extends SceneTree
# Finals contact sheet: godot --path . --resolution 1280x800 -s aso/tools/finals_sheet.gd
# Writes aso/creative/finals_contact_sheet.png (icons at 1024 and 60 px, then the screenshot set in order).

const C := "res://aso/creative/"
const W := 3240
const ICONS := [["icons/v3/final_duel.png", "CONTROL  final_duel.png (teal)"],
	["icons/v3/final_duel_orange.png", "PPO 1  final_duel_orange.png"],
	["icons/v3/final_skywrite.png", "PPO 2 (charm)  final_skywrite.png"]]
const SHOTS := [["screens/c01_no_ads.png", "1  c01_no_ads (C launch frame 1)"],
	["screens/02_room_code.png", "2  02_room_code"], ["screens/03_skywriting.png", "3  03_skywriting"],
	["screens/04_vs_ai.png", "4  04_vs_ai"], ["screens/06_worlds.png", "5  06_worlds"],
	["screens/07_no_pay_to_win.png", "6  07_no_pay_to_win"]]
const ALTS := [["screens/01_dogfight_friends.png", "01_dogfight_friends (A / CPP)"],
	["screens/ppo_in_aeroplane.png", "ppo_in_aeroplane (IN)"], ["screens/first_alt_1.png", "first_alt_1"],
	["screens/first_alt_2.png", "first_alt_2"], ["screens/first_alt_3.png", "first_alt_3"]]

var vp: SubViewport
var root_c: Control
var y := 0

func _init() -> void:
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	root_c = Control.new()
	vp.add_child(root_c)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.14, 0.16)
	root_c.add_child(bg)
	y = 30
	_label("Toy Plane Arcade: ASO finals (round 2, 25 Oct 2026)", 40, 64)
	y += 110
	_label("App icon: 1024 px master (actual size)", 40, 40)
	y += 60
	for i in ICONS.size():
		_tex(ICONS[i][0], Vector2(40 + i * 1064, y), Vector2(1024, 1024))
		_label(ICONS[i][1], 40 + i * 1064, 32, y + 1034)
	y += 1100
	_label("Same icons at 60 px (actual size), on light and dark", 40, 40)
	y += 60
	for i in ICONS.size():
		for d in 2:
			var sw := ColorRect.new()
			sw.color = Color(0.95, 0.95, 0.95) if d == 0 else Color(0.02, 0.02, 0.03)
			sw.position = Vector2(40 + i * 1064 + d * 110, y)
			sw.size = Vector2(100, 100)
			root_c.add_child(sw)
			_tex(ICONS[i][0], sw.position + Vector2(20, 20), Vector2(60, 60))
	y += 150
	_label("Screenshots, upload order for the Strategy C launch (2868x1320; C headlines on 2-6 still to do)", 40, 40)
	y += 60
	_grid(SHOTS, 3, 1020)
	_label("First-frame alternatives for PPO (never upload two frames built from the same capture: 01, c01, ppo_in_aeroplane)", 40, 40)
	y += 60
	_grid(ALTS, 5, 600)
	bg.size = Vector2(W, y)
	vp.size = Vector2i(W, y)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(C.path_join("finals_contact_sheet.png"))
	quit()

func _grid(items: Array, cols: int, tw: int) -> void:
	var th := int(tw * 1320.0 / 2868.0)
	for i in items.size():
		var p := Vector2(40 + (i % cols) * (tw + 40), y + (i / cols) * (th + 70))
		_tex(items[i][0], p, Vector2(tw, th))
		_label(items[i][1], int(p.x), 28, int(p.y) + th + 8)
	y += ceili(items.size() / float(cols)) * (th + 70) + 30

func _tex(path: String, pos: Vector2, sz: Vector2) -> void:
	var img := Image.load_from_file(C.path_join(path))
	if img.get_width() > sz.x:
		img.resize(int(sz.x), int(sz.y), Image.INTERPOLATE_LANCZOS)
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = pos
	t.size = sz
	root_c.add_child(t)

func _label(text: String, x: int, fs: int, at_y := -1) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	l.position = Vector2(x, y if at_y < 0 else at_y)
	root_c.add_child(l)
