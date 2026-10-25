extends SceneTree
# Icon size test (pre-scaled by sips into icons/src/sizes/ by icon_sheet.sh):
# 1. each concept at 180/120/87/60/40/29 px with an iOS-style rounded mask, on a light and a dark wallpaper;
# 2. each concept at 60 px in front of the 20 competitor icons (data/competitors.json);
# 3. each concept at 60 px as result 2 in a mock App Store search list (results 1, 3, 4: iTunes Search API, "dogfight", country=in);
# 4. each concept and the 3 search results at the iPhone search-result icon size (~64 pt: 192 px @3x, 128 px @2x);
# 5. a dark home-screen row at 60 px (B_dark, the light concepts, current icon, 5 competitors as shipped);
# plus masked_1024.png: A, B, C and B_dark at full size with the rounded mask.
# godot --path . --resolution 1760x1400 -s aso/tools/icon_sheet.gd

const DIR := "res://aso/creative/icons/"
const ROWS := [["A_hero", "A  hero"], ["B_duel", "B  duel"], ["C_face", "C  face"], ["B_duel_dark", "B  dark"], ["B_duel_tinted", "B  tinted"], ["current", "current icon_ios"]]
const VS := [["A_hero", "A"], ["B_duel", "B"], ["C_face", "C"], ["current", "current"]] # concepts compared against competitors
const SIZES := [180, 120, 87, 60, 40, 29]
const ROW_H := 200
const W := 1760
const MASK := "shader_type canvas_item;
uniform float r = 0.2237; // iOS corner radius / side (ponytail: rounded rect, not Apple's true squircle)
void fragment() {
	vec2 q = abs(UV - 0.5) - (0.5 - r);
	float d = length(max(q, 0.0)) - r;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= clamp(0.5 - d / fwidth(d), 0.0, 1.0);
}"

var mask := ShaderMaterial.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	mask.shader = Shader.new()
	mask.shader.code = MASK
	var y1 := 40 + ROW_H * ROWS.size() + 20 # competitor strips
	var y2 := y1 + 50 + 80 * VS.size() + 20 # search mock
	var y3 := y2 + 50 + 4 * 78 + 30 # 64 pt search size
	var y4 := y3 + 50 + 2 * 232 + 10 # dark home screen
	var vp := SubViewport.new()
	vp.size = Vector2i(W, y4 + 50 + 120 + 20)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	_rect(vp, Vector2.ZERO, Vector2(vp.size), Color(0.18, 0.18, 0.2))

	# 1. sizes
	for i in ROWS.size():
		var y := 40 + i * ROW_H
		_rect(vp, Vector2(190, y), Vector2(690, ROW_H), Color(0.86, 0.9, 0.96))
		_rect(vp, Vector2(890, y), Vector2(400, ROW_H), Color(0.07, 0.08, 0.12))
		_text(vp, ROWS[i][1], Vector2(10, y + ROW_H / 2 - 12), Color.WHITE)
		var x := 205
		for s: int in SIZES:
			_icon(vp, ROWS[i][0], s, Vector2(x, y + (ROW_H - s) / 2), true)
			x += s + 22
		x = 910
		for s: int in [120, 60, 40]:
			_icon(vp, ROWS[i][0], s, Vector2(x, y + (ROW_H - s) / 2), true)
			x += s + 35
		_icon(vp, ROWS[i][0], 60, Vector2(x, y + (ROW_H - 60) / 2), false) # unmasked 60 for edge check
	var x := 205
	for s: int in SIZES:
		_text(vp, "%d" % s, Vector2(x, 10), Color.WHITE)
		x += s + 22
	_text(vp, "dark wallpaper: 120, 60, 40, 60 unmasked", Vector2(910, 10), Color.WHITE)

	# 2. versus the 20 competitor icons
	_text(vp, "60 px, concept first, then the 20 competitors from competitor-research.md (same order as data/competitors.json)", Vector2(10, y1 + 10), Color.WHITE)
	for i in VS.size():
		var y := y1 + 50 + i * 80
		_rect(vp, Vector2(190, y), Vector2(W - 200, 80), Color(0.95, 0.95, 0.97))
		_text(vp, VS[i][1], Vector2(10, y + 28), Color.WHITE)
		_icon(vp, VS[i][0], 60, Vector2(205, y + 10), true)
		for k in 20:
			_icon(vp, "c_%02d" % k, 60, Vector2(300 + k * 72, y + 10), true)

	# 3. mock search results
	_text(vp, "mock App Store search for \"dogfight\" (iTunes Search API, country=in, top 3; concept placed second)", Vector2(10, y2 + 10), Color.WHITE)
	var res: Array = JSON.parse_string(FileAccess.get_file_as_string("res://aso/data/search/dogfight_in.json")).results
	for i in VS.size():
		var cx := 10 + i * 437
		var y := y2 + 50
		_rect(vp, Vector2(cx, y), Vector2(427, 4 * 78 + 10), Color.WHITE)
		var rows := [["c_search0", res[0].trackName, res[0].artistName], [VS[i][0], "Toy Plane Sim", "Dogfight friends in toy planes"],
			["c_search1", res[1].trackName, res[1].artistName], ["c_search2", res[2].trackName, res[2].artistName]]
		for r in rows.size():
			var ry := y + 10 + r * 78
			_icon(vp, rows[r][0], 60, Vector2(cx + 12, ry), true)
			_text(vp, str(rows[r][1]).left(28), Vector2(cx + 86, ry + 6), Color(0.05, 0.05, 0.07), 17)
			_text(vp, str(rows[r][2]).left(34), Vector2(cx + 86, ry + 32), Color(0.45, 0.45, 0.5), 14)
			_rect(vp, Vector2(cx + 350, ry + 16), Vector2(64, 28), Color(0.93, 0.94, 0.96))
			_text(vp, "GET", Vector2(cx + 366, ry + 19), Color(0.0, 0.48, 1.0), 15)

	# 4. real search-result size
	_text(vp, "search-result size, ~64 pt: 192 px (@3x) and 128 px (@2x), masked, on white", Vector2(10, y3 + 10), Color.WHITE)
	var big: Array = [VS, [["c_search0", "search 1"], ["c_search1", "search 3"], ["c_search2", "search 4"]]]
	for r in 2:
		var y := y3 + 50 + r * 232
		_rect(vp, Vector2(10, y), Vector2(W - 20, 222), Color.WHITE)
		for i in big[r].size():
			var bx: int = 20 + i * 430
			_icon(vp, big[r][i][0], 192, Vector2(bx, y + 15), true)
			_icon(vp, big[r][i][0], 128, Vector2(bx + 210, y + 15), true)
			_text(vp, big[r][i][1], Vector2(bx + 210, y + 160), Color(0.05, 0.05, 0.07), 17)

	# 5. dark home screen
	_text(vp, "iOS dark home screen, 60 px: B dark variant first; competitors as shipped (their own dark variants unknown)", Vector2(10, y4 + 10), Color.WHITE)
	_rect(vp, Vector2(10, y4 + 50), Vector2(W - 20, 120), Color(0.05, 0.06, 0.1))
	var home := [["B_duel_dark", "B dark"], ["A_hero", "A"], ["B_duel", "B"], ["C_face", "C"], ["current", "current"]]
	for k in 5:
		home.append(["c_%02d" % k, "comp %d" % (k + 1)])
	for i in home.size():
		var hx: int = 40 + i * 110
		_icon(vp, home[i][0], 60, Vector2(hx, y4 + 68), true)
		_text(vp, home[i][1], Vector2(hx, y4 + 134), Color(0.92, 0.92, 0.95), 13)

	await _save(vp, "contact_sheet.png")

	var m := SubViewport.new() # masked full-size preview, 2 x 2
	m.size = Vector2i(2 * 1024 + 3 * 40, 2 * 1024 + 3 * 40)
	m.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(m)
	_rect(m, Vector2.ZERO, Vector2(m.size), Color(0.86, 0.9, 0.96))
	for i in 4:
		_icon(m, ["A_hero", "B_duel", "C_face", "B_duel_dark"][i], 1024, Vector2(40 + (i % 2) * 1064, 40 + (i / 2) * 1064), true)
	await _save(m, "masked_1024.png")
	quit()


func _save(vp: SubViewport, file: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(DIR + file)
	print("wrote ", file)


func _icon(vp: Node, name: String, s: int, at: Vector2, masked: bool) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "src/sizes/%s_%d.png" % [name, s]))
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = at
	tr.size = Vector2(s, s)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # show the sips pixels 1:1
	tr.material = mask if masked else null
	vp.add_child(tr)


func _rect(vp: Node, at: Vector2, size: Vector2, c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = at
	r.size = size
	vp.add_child(r)


func _text(vp: Node, t: String, at: Vector2, c: Color, size := 20) -> void:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	vp.add_child(l)
