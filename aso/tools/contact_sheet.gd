extends SceneTree
# Usage: godot --headless -s aso/tools/contact_sheet.gd -- OUT.png CELL COLS img1 img2 ...

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var cell := int(a[1])
	var cols := int(a[2])
	var paths := a.slice(3)
	var rows := ceili(paths.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for i in paths.size():
		var img := Image.load_from_file(paths[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		var s := minf(cell / float(img.get_width()), cell / float(img.get_height()))
		img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell, (i / cols) * cell))
	sheet.save_png(out)
	quit()
