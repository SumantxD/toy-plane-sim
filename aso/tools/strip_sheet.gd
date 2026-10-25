extends SceneTree
# Review sheet for wide takes (no square cells): godot --headless -s aso/tools/strip_sheet.gd -- OUT.png TILE_W COLS img1 img2 ...

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var tw := int(a[1])
	var cols := int(a[2])
	var imgs: Array[Image] = []
	for p in a.slice(3):
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, tw * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
		imgs.append(img)
	var th := imgs[0].get_height()
	var rows := ceili(imgs.size() / float(cols))
	var sheet := Image.create(cols * (tw + 8), rows * (th + 8), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (tw + 8), (i / cols) * (th + 8)))
	sheet.save_png(a[0])
	quit()
