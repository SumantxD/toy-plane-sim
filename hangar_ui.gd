class_name HangarUI
extends Control

# Phone Hangar: your plane and every look as picture cards. Tap one you own to wear it (saved at once,
# flown next match); a paid one opens the shop on it, an earned one says the pilot level that unlocks it.
# PILOT: your level, title, next reward and the badge wall. The turntable shows what you'll fly.
const TABS := [["PLANE", "plane"], ["PAINT", "paint"], ["TRAIL", "trail"], ["STICKER", "sticker"], ["EFFECT", "burst"], ["PILOT", "medal"]]
const FX_COLORS := [Color(0.6, 0.6, 0.65), Color(1.0, 0.45, 0.8), Color(0.55, 0.85, 1.0), Color(1.0, 0.5, 0.12)]
var main: Node
var shop: Shop
var tab := "PLANE"
var tabs := {} # name -> tile
var grid := GridContainer.new()
var cards: Array = []
var note := Label.new()
var fly_btn: Button
var pilot := HBoxContainer.new()
var pilot_title := Label.new()
var pilot_bar := ProgressBar.new()
var pilot_next := Label.new()


func _init(m: Node, s: Shop) -> void:
	main = m
	shop = s
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	Menus.icon_tile(top, "BACK", "back", close, main, 16, Vector2(132, 68), true)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	top.add_child(head)
	Menus.big_title(head, "HANGAR", 28).add_theme_constant_override("outline_size", 10)
	var sub := Label.new()
	sub.text = "Tap a look you own to wear it."
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.75)
	head.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for t in TABS:
		var b := Menus.icon_tile(row, t[0], t[1], pick_tab.bind(t[0]), main, 12, Vector2(0, 80))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs[t[0]] = b
	pilot.add_theme_constant_override("separation", 10)
	box.add_child(pilot)
	var lvb := Control.new()
	lvb.custom_minimum_size = Vector2(48, 48)
	lvb.draw.connect(func(): ResultsUI.draw_level(lvb, Progress.level()))
	pilot.add_child(lvb)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 2)
	pilot.add_child(pv)
	pilot_title.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	pilot_title.add_theme_font_size_override("font_size", 16)
	pv.add_child(pilot_title)
	pilot_bar.show_percentage = false
	pilot_bar.custom_minimum_size.y = 10
	pv.add_child(pilot_bar)
	pilot_next.add_theme_font_size_override("font_size", 13)
	pilot_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pilot_next.custom_minimum_size.x = 200
	pv.add_child(pilot_next)
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Menus.AMBER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 40
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(note)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	box.add_child(foot)
	var sb := Menus.icon_tile(foot, "SHOP", "shop", func(): main.shop_ui.open(), main, 17, Vector2(0, 76), true)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fly_btn = Menus.icon_tile(foot, "FLY!", "play", func(): close(); main.quick_battle(), main, 26, Vector2(0, 76), true)
	fly_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Menus.lit(fly_btn, true)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Menus.side_panel(self, box, 560)
	box.add_theme_constant_override("separation", 8)
	shop.changed.connect(func(): if visible: _states())
	visibility_changed.connect(func(): if visible and cards: _states()) # back from the shop: what you bought is worn
	hide()


func open(t := "") -> void:
	main.hangar_open = true
	main._refresh_ui()
	pick_tab(t if t != "" else tab)


func close() -> void:
	main.hangar_open = false
	main._refresh_ui()


func pick_tab(t: String) -> void:
	tab = t
	note.text = ""
	_fill()
	if tab == "PLANE":
		var v := Planes.variant(main.plane_choice)
		note.text = "%s: %s" % [v.name, v.desc]
	elif tab == "PILOT":
		note.text = "Badges: %d of %d earned. Tap one to see how." % [Settings.values.badges.size(), Progress.BADGES.size()]
	pilot.visible = tab == "PILOT"
	if pilot.visible:
		var lv := Progress.level()
		var xp := int(Settings.values.xp)
		pilot_title.text = "LEVEL %d  ·  %s" % [lv, Progress.title(lv).to_upper()]
		pilot_bar.value = 100.0 * Progress.level_frac(xp)
		var nx := Progress.next_reward(lv)
		pilot_next.text = "Every reward unlocked. Sky Legend!" if nx.is_empty() else "Next: level %d unlocks the %s (%d XP to go)" % [nx.lv, Progress.reward_name(nx.item), Progress.floor_xp(nx.lv) - xp]
		pilot.get_child(0).queue_redraw()


# [title, item key ("livery:1"), swatch painter] for the open tab.
func _entries() -> Array:
	match tab:
		"PLANE":
			return Planes.ORDER.map(func(k): return [Planes.variant(k).name, "plane:" + k, func(b: Control, r: Rect2): Menus.icon(b, "plane", r.get_center(), minf(r.size.x, r.size.y) * 0.45, Color(0.35, 0.6, 1.0))])
		"PAINT":
			return range(Planes.LIVERIES.size()).map(func(i): return [Planes.LIVERIES[i].name, "livery:%d" % i, _paint_swatch.bind(i)])
		"TRAIL":
			return range(Planes.trail_names().size()).map(func(i): return [Planes.trail_names()[i], "trail:%d" % i, _trail_swatch.bind(i)])
		"STICKER":
			return range(Planes.STICKERS.size()).map(func(i): return [Planes.STICKERS[i], "sticker:%d" % i, func(b: Control, r: Rect2):
				if i == 0:
					_none(b, r)
				else:
					Menus.icon(b, "sticker", r.get_center(), minf(r.size.x, r.size.y) * 0.42, Color.from_hsv(i / 7.0, 0.6, 1.0))])
		"PILOT":
			return Progress.BADGES.map(func(bd): return [bd.name, "badge:" + bd.id, func(b: Control, r: Rect2):
				Menus.icon(b, "medal", r.get_center(), minf(r.size.x, r.size.y) * 0.45, Menus.AMBER if Settings.values.badges.has(bd.id) else Color(1, 1, 1, 0.3))])
	return range(Planes.KILL_FX.size()).map(func(i): return [Planes.KILL_FX[i], "killfx:%d" % i, func(b: Control, r: Rect2):
		if i == 0:
			_none(b, r)
		else:
			Menus.icon(b, "burst", r.get_center(), minf(r.size.x, r.size.y) * 0.45, FX_COLORS[i])])


func _worn(item: String) -> bool:
	var slot := item.get_slice(":", 0)
	if slot == "plane":
		return main.plane_choice == item.get_slice(":", 1)
	return int(Settings.values.get("banner" if slot == "trail" else slot, 0)) == int(item.get_slice(":", 1))


func _fill() -> void:
	for t in tabs:
		Menus.lit(tabs[t], t == tab)
	for c in cards:
		grid.remove_child(c)
		c.queue_free()
	cards.clear()
	var list := _entries()
	var tall := 84.0 if tab == "PILOT" else (96.0 if list.size() <= 2 * grid.columns else 76.0) # three rows still fit a phone
	for e in list:
		var c := Menus.card(grid, e[0].to_upper(), e[2], _tap.bind(e[1]), main, Vector2(76, tall))
		c.name = "Card_" + e[1].replace(":", "_")
		c.set_meta("item", e[1])
		cards.append(c)
	_states()


func _states() -> void:
	for c: Button in cards:
		var item: String = c.get_meta("item")
		if item.begins_with("badge:"):
			var got: bool = Settings.values.badges.has(item.get_slice(":", 1))
			Menus.card_state(c, "", got, not got)
			continue
		var lv := Progress.reward_level(item)
		var free: bool = item.begins_with("plane:") or (item.begins_with("sticker:") and lv == 0) or Shop._free(item) or (lv > 0 and Progress.has(item))
		var own: bool = free or shop.owns(item)
		var on := own and _worn(item)
		var badge := "EQUIPPED" if on else ("" if free else ("OWNED" if own else ("LV %d" % lv if lv > 0 else shop.price(shop.product_for(item)))))
		Menus.card_state(c, badge if own or badge != "" else "SHOP", on, not own)
	main.preview_key = ""
	main._refresh_preview()


func _tap(item: String) -> void:
	var slot := item.get_slice(":", 0)
	var val := item.get_slice(":", 1)
	if slot == "plane":
		main.plane_choice = val
		Settings.values.last_plane = val
		Settings.save()
		note.text = "%s: %s" % [Planes.variant(val).name, Planes.variant(val).desc]
		_states()
		return
	if slot == "badge":
		var bd := Progress.badge(val)
		var at: int = Settings.values.badges.get(val, 0)
		note.text = "%s: %s.%s" % [bd.name, bd.desc, ("  Earned %s." % Time.get_date_string_from_unix_time(at)) if at else "  Not earned yet."]
		return
	var lv := Progress.reward_level(item)
	if lv > 0 and not Progress.has(item):
		note.text = "Reach pilot level %d to unlock the %s. You're level %d." % [lv, Progress.reward_name(item), Progress.level()]
		TouchControls.buzz(15)
		return
	if lv == 0 and not (slot == "sticker" or shop.owns(item)):
		main.shop_ui.open(shop.product_for(item))
		return
	Settings.values["banner" if slot == "trail" else slot] = int(val)
	Settings.save()
	main.send_look()
	note.text = "Equipped! You'll fly it next match."
	TouchControls.buzz(15)
	_states()
	if slot == "killfx" and int(val) > 0:
		Fx.kill_effect(main, main.preview.global_position + main.lobby_cam.global_basis.x * 9.0 + Vector3.UP * 2.0, int(val))


static func _none(b: Control, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.35
	b.draw_arc(c, s, 0, TAU, 24, Color(1, 1, 1, 0.5), 3.0)
	b.draw_line(c + Vector2(-s, s) * 0.7, c + Vector2(s, -s) * 0.7, Color(1, 1, 1, 0.5), 3.0)


static func _paint_swatch(b: Control, r: Rect2, i: int) -> void:
	var lv: Dictionary = Planes.LIVERIES[i]
	var cols: Array = [lv.wing, lv.trim, lv.accent] if lv.has("wing") else [Color(0.2, 0.4, 0.9), Color(0.95, 0.93, 0.85), Color(0.2, 0.4, 0.9)]
	var h := r.size.y / 3.0
	for k in 3:
		b.draw_rect(Rect2(r.position + Vector2(0, h * k), Vector2(r.size.x, h)), cols[k])


static func _trail_swatch(b: Control, r: Rect2, i: int) -> void:
	if i == 0:
		_none(b, r)
		return
	var cols: Array = [Planes.BANNER_COLORS[i]] if i < Planes.BANNERS.size() else Planes.trail_colors(i)
	var w := r.size.x / cols.size()
	for k in cols.size():
		var c: Color = cols[k]
		b.draw_rect(Rect2(r.position + Vector2(w * k, r.size.y * 0.3), Vector2(w + 0.5, r.size.y * 0.4)), Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0)))
