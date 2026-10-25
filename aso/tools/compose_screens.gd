extends SceneTree
# Headline over real captures -> aso/creative/screens/*.png (2868x1320, RGB), aso/creative/contact_sheet.png and
# aso/creative/contact_sheet_350.png (every frame at 350 px wide: about its size on an iPhone product page).
#   godot --path . --resolution 640x300 -s aso/tools/compose_screens.gd
# Other sizes (e.g. iPhone Duo 2853x2007) go to screens/<W>x<H>/, upload frames only, laid out to scale (s):
#   godot --path . --resolution 640x300 -s aso/tools/compose_screens.gd -- --size=2853x2007
# Needs a window (renders in a SubViewport); raws come from aso/tools/capture_scenes.gd.
var W := 2868
var H := 1320
var s := 1.0 # W / 2868: px sizes below are at 2868 wide
var tall := false # ~1.42:1 (iPhone Duo): frames use their `tall` overrides
const RAW := "res://aso/creative/raw/"
const OUT := "res://aso/creative/screens/"
const SKY_FONT := preload("res://assets/ui/kenney_future_narrow.ttf") # the skywriting font (taunts.gd:21), only on sky = true frames
const SAFE := 110 # text stays this far from the side edges
const NAVY := Color(0.03, 0.05, 0.14)
const AMBER := Color(1.0, 0.74, 0.22) # Menus.AMBER: solo, worlds and shop frames
const CYAN := Color(0.45, 0.9, 1.0) # multiplayer frames
const HEAD := 184 # headline px: ~23 pt on a 350 pt-wide product-page shot
const SUB := 100 # sub-line px, sentence case
const TOP := 400 # content of split frames starts below the text

# kind: overlay = full-bleed capture, optionally zoomed (zoom = [centre x, centre y, factor] in raw pixels);
# tri / strip = side-by-side slices [file, centre x, zoom, centre y]; split = rows cropped from a menu capture on
# the left (amber box on hl = [row, rect]), a zoomed capture on the right (right = [file, cx, cy, factor]).
# tall = keys that replace the above at ~1.42:1 (more of the raw's height fits, so less zoom); ts = roster text scale;
# ws = slice width weights.
const SET := [
	{out = "01_dogfight_friends", kind = "overlay", raw = "sel_dogfight_lan", zoom = [1240, 640, 1.7], accent = CYAN,
		head = "DOGFIGHT YOUR FRIENDS", sub = "Online or LAN. Join by room code."},
	# 02: lan_c had a Sky Kingdom cloud slab through the jet (round 3), so it uses lan_b like first_alt_2.
	{out = "02_room_code", kind = "split", src = "sel_lobby_room", rows = "roster", k = 2.8, lw = 1300, right = ["sel_dogfight_lan_b", 1300, 760, 1.3], accent = CYAN,
		head = "SHARE A CODE. JUMP IN.", sub = "No account. No sign-up.",
		tall = {right = ["sel_dogfight_lan_b", 1300, 720, 1.15], ts = 1.3, k = 3.0, lw = 1460}},
	{out = "03_skywriting", kind = "overlay", raw = "sel_taunt_skill_issue", zoom = [1434, 660, 1.1], accent = CYAN, sky = true,
		head = "TAUNT THEM IN THE SKY", sub = "24 skywritten taunts",
		tall = {zoom = [1420, 660, 1.0]}},
	{out = "04_vs_ai", kind = "overlay", raw = "sel_ai_battle", zoom = [1300, 640, 1.35], accent = AMBER,
		head = "FRIENDS BUSY? FIGHT AI", sub = "Rookie, Pilot or Ace",
		tall = {zoom = [1300, 700, 1.25]}},
	# 05_lock_on dropped from the upload set (round 2): no rocket in frame, target too small at phone size.
	{out = "06_worlds", kind = "tri", crops = [["sel_world_volcano", 1434], ["sel_world_frozen", 1420, 1.3, 760], ["sel_world_metro_lightning", 1360, 1.15, 700]], accent = AMBER,
		head = "6 WORLDS, WILD WEATHER", sub = "Lava, snow and lightning",
		tall = {crops = [["sel_world_volcano", 1434], ["sel_world_frozen", 1420], ["sel_world_metro_lightning", 1360]], ws = [1.25, 0.95, 0.8]}},
	# Full-bleed on the Golden Ace plane: the shop's menu text can't be read at phone size, so the zoom keeps it out.
	{out = "07_no_pay_to_win", kind = "overlay", raw = "sel_shop", zoom = [2040, 943, 1.75], accent = AMBER,
		head = "NEVER PAY TO WIN", sub = "Looks only. No ads. No timers.",
		tall = {zoom = [2060, 900, 1.18]}},
	{out = "first_alt_1", kind = "overlay", raw = "sel_taunt_lets_go", accent = CYAN, sky = true,
		head = "TAUNT YOUR FRIENDS IN THE SKY", sub = "24 skywritten taunts"},
	{out = "first_alt_2", kind = "split", src = "sel_lobby_room", rows = "roster", k = 2.8, lw = 1300, right = ["sel_dogfight_lan_b", 1300, 760, 1.3], accent = CYAN,
		head = "ONE CODE. ONE SKY.", sub = "Join by room code. No account."},
	{out = "first_alt_3", kind = "strip", crops = [["sel_world_volcano", 1434], ["sel_world_frozen", 1420, 1.3, 760],
		["sel_world_desert", 1463], ["sel_world_metro_lightning", 1380, 1.1, 720]], accent = AMBER,
		head = "TOY PLANE DOGFIGHTS", sub = "Lava, snow, lightning and more"},
	# Strategy C (launch listing) frame 1.
	{out = "c01_no_ads", kind = "overlay", raw = "sel_dogfight_lan", zoom = [1240, 640, 1.7], accent = AMBER,
		head = "NO ADS. JUST DOGFIGHTS.", sub = "Fight AI with no internet, or friends by code.",
		tall = {zoom = [1150, 760, 1.4]}},
	{out = "ppo_in_aeroplane", kind = "overlay", raw = "sel_dogfight_lan", zoom = [1240, 640, 1.7], accent = CYAN,
		head = "AEROPLANE DOGFIGHTS WITH FRIENDS", sub = "Online or LAN. Join by room code."},
]
# 02 / first_alt_2: the ROOM CODE line cropped from sel_lobby_room, then a roster set in team colours; text instead of
# crops drops the menu's row boxes and ping column. Kabir is on Red: sel_dogfight_lan_b shows a red jet tagged "Kabir".
const CODE := Rect2i(96, 156, 420, 56)
const TEAMS := [["Blue team", "Arjun   Riya", Color(0.45, 0.7, 1.0)], ["Red team", "Kabir   Dev", Color(1.0, 0.45, 0.4)]]

var out_dir := OUT
var vp := SubViewport.new()
var sub_font := FontVariation.new()
var head_font := FontVariation.new()


func _raw(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(RAW + name + ".png"))
	img.convert(Image.FORMAT_RGB8)
	return img


# Region of `src` around (cx, cy) with the given aspect, `z` times closer than fitting the full height, resized to w x h.
func _zoomed(src: Image, cx: float, cy: float, z: float, w: int, h: int) -> Image:
	var sh := int(src.get_height() / z)
	var sw := int(sh * w / float(h))
	var r := Rect2i(clampi(int(cx) - sw / 2, 0, src.get_width() - sw), clampi(int(cy) - sh / 2, 0, src.get_height() - sh), sw, sh)
	var out := src.get_region(r)
	out.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return out


# Side-by-side vertical slices of several captures, dark 6 px dividers from y = TOP down (the headline band is unbroken).
func _slices(crops: Array, ws: Array) -> Image:
	var n := crops.size()
	var gap := int(6 * s)
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var x := 0
	var cuts := []
	for i in n:
		var w := (W - gap * (n - 1)) / n if ws.is_empty() else int((W - gap * (n - 1)) * ws[i] / ws.reduce(func(a, b): return a + b))
		var c: Array = crops[i]
		var src := _raw(c[0])
		var part := _zoomed(src, c[1], c[3] if c.size() > 3 else src.get_height() / 2.0, c[2] if c.size() > 2 else 1.0, w + gap, H)
		img.blit_rect(part, Rect2i(0, 0, w + gap, H), Vector2i(x - gap / 2, 0))
		x += w + gap
		cuts.append(x - gap)
	for i in n - 1:
		img.fill_rect(Rect2i(cuts[i], int(TOP * s), gap, H - int(TOP * s)), NAVY)
	return img


func _tex(parent: Node, tex: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = rect.position
	t.size = rect.size
	parent.add_child(t)
	return t


func _img(parent: Node, img: Image, rect: Rect2) -> void:
	_tex(parent, ImageTexture.create_from_image(img), rect)


# Same soft scrim on every frame: dark at the very top, clear by y = 470, so the sky still shows through.
# Split frames: solid to just under the sub-line, so the text never straddles the panel seam.
func _scrim(parent: Node, solid := false) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72 if solid else 0.5, 1.0])
	var a := 1.0 if solid else 0.72
	g.colors = PackedColorArray([Color(NAVY, a), Color(NAVY, a if solid else 0.45), Color(NAVY, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	_tex(parent, gt, Rect2(0, 0, W, 470 * s))


func _label(parent: Node, text: String, y: float, size: int, font: Font, color: Color, outline: int, max_w: float = W - SAFE * 2 * s) -> void:
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and size > 40:
		size -= 2 # long headlines shrink to fit the safe area
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = NAVY
	ls.shadow_size = outline / 2
	ls.shadow_color = Color(NAVY, 0.55)
	ls.shadow_offset = Vector2(0, outline * 0.45)
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(SAFE * s, y)
	l.size = Vector2(W - SAFE * 2 * s, size * 1.2)
	parent.add_child(l)


func _box(parent: Node, rect: Rect2, color: Color) -> void:
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(roundi(8 * s))
	sb.border_color = color
	sb.set_corner_radius_all(roundi(12 * s))
	box.add_theme_stylebox_override("panel", sb)
	box.position = rect.position
	box.size = rect.size
	parent.add_child(box)


func _split(root_c: Control, f: Dictionary) -> void:
	var lw := int(f.get("lw", 980) * s)
	var top := TOP * s
	var r: Array = f.right
	_img(root_c, _zoomed(_raw(r[0]), r[1], r[2], r[3], W - lw, H), Rect2(lw, 0, W - lw, H))
	var edge := ColorRect.new()
	edge.color = Color(1, 1, 1, 0.85)
	edge.position = Vector2(lw - 4 * s, top)
	edge.size = Vector2(8 * s, H - top)
	root_c.add_child(edge)
	var src := _raw(f.src)
	var rows: Array = []
	var hl: Array = f.get("hl", [0, CODE])
	if f.rows is String:
		rows.append([CODE, 0, 60.0])
	else:
		for row: Array in f.rows:
			rows.append([row[0], row[1], 40.0])
	var k: float = f.get("k", 1.7) * s
	var ts: float = f.get("ts", 1.0) * s # roster text scale
	var total := 0.0
	for row in rows:
		total += row[0].size.y * k + row[2] * s
	if f.rows is String:
		total += TEAMS.size() * ((84 + 96) * 1.25 + 30) * ts
	var y := top + maxf(0.0, (H - top - total) / 2.0 - 30.0 * s)
	for i in rows.size():
		var reg: Rect2i = rows[i][0]
		var at := Rect2(70.0 * s + rows[i][1] * k, y, reg.size.x * k, reg.size.y * k)
		_img(root_c, src.get_region(reg), at)
		if i == hl[0]:
			var h: Rect2i = hl[1]
			_box(root_c, Rect2(at.position + Vector2(h.position - reg.position) * k, Vector2(h.size) * k).grow(14 * s), f.accent)
		y += reg.size.y * k + rows[i][2] * s
	if f.rows is String:
		for t: Array in TEAMS:
			for line in [[t[0], t[2], 84], [t[1], Color.WHITE, 96]]:
				var ls := LabelSettings.new()
				ls.font = sub_font
				ls.font_size = roundi(line[2] * ts)
				ls.font_color = line[1]
				var l := Label.new()
				l.text = line[0]
				l.label_settings = ls
				l.position = Vector2(84 * s, y)
				root_c.add_child(l)
				y += line[2] * 1.25 * ts
			y += 30 * ts


func _compose(f: Dictionary) -> Image:
	if tall:
		f = f.merged(f.tall, true)
	for c in vp.get_children():
		c.queue_free()
	var root_c := Control.new()
	root_c.size = Vector2(W, H)
	vp.add_child(root_c)
	var bg := ColorRect.new()
	bg.color = NAVY
	bg.size = Vector2(W, H)
	root_c.add_child(bg)
	match f.kind:
		"overlay":
			var src := _raw(f.raw)
			if f.has("zoom"):
				src = _zoomed(src, f.zoom[0], f.zoom[1], f.zoom[2], W, H)
			_img(root_c, src, Rect2(0, 0, W, H))
		"tri", "strip":
			_img(root_c, _slices(f.crops, f.get("ws", [])), Rect2(0, 0, W, H))
		"split":
			_split(root_c, f)
	_scrim(root_c, f.kind == "split")
	_label(root_c, f.head, 18 * s, roundi(HEAD * s), SKY_FONT if f.get("sky", false) else head_font, Color.WHITE, roundi(30 * s), W * 0.75) # headline reads as a block
	_label(root_c, f.sub, 222 * s, roundi(SUB * s), sub_font, f.accent, roundi(22 * s))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _sheet(made: Array[Image], tw: int, cols: int, path: String) -> void:
	var th := tw * H / W
	var pad := 20 if tw > 400 else 12
	var rows := ceili(made.size() / float(cols))
	var sheet := Image.create(cols * tw + (cols + 1) * pad, rows * th + (rows + 1) * pad, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.12, 0.12, 0.14))
	for i in made.size():
		var t := made[i].duplicate() as Image
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i(pad + (i % cols) * (tw + pad), pad + (i / cols) * (th + pad)))
	sheet.save_png(ProjectSettings.globalize_path(path)) # outside screens/: never uploaded
	print("saved ", path)


func _initialize() -> void:
	sub_font.base_font = ThemeDB.fallback_font # the game's menu font (has lowercase; Kenney Future is caps only)
	sub_font.variation_embolden = 0.6
	head_font.base_font = ThemeDB.fallback_font # heavy, tight caps: Kenney Future's R/N/M misread at phone size
	head_font.variation_embolden = 1.4
	head_font.spacing_glyph = -2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			W = a.get_slice("=", 1).get_slice("x", 0).to_int()
			H = a.get_slice("=", 1).get_slice("x", 1).to_int()
			s = W / 2868.0
			tall = H > W * 0.6
			out_dir = OUT + "%dx%d/" % [W, H]
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var made: Array[Image] = []
	for f in SET:
		if tall and not f.has("tall"):
			continue
		var img := await _compose(f)
		img.save_png(ProjectSettings.globalize_path(out_dir + f.out + ".png"))
		made.append(img)
		print("saved %s %dx%d" % [f.out, img.get_width(), img.get_height()])
	if out_dir == OUT:
		_sheet(made, 940, 3, "res://aso/creative/contact_sheet.png")
		_sheet(made, 350, 3, "res://aso/creative/contact_sheet_350.png")
	quit()
