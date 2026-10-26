class_name ShopUI
extends Control

# The Hangar Shop: pick a category and an item, see it on your own plane on the turntable (kill
# effects play beside it), then buy it at Apple's price, equip it, or fly it free in Free Flight first.
# Real prices only, a plain "Back", and no timers.
var main: Node
var shop: Shop
var cat_sel: Menus.Selector
var item_sel: Menus.Selector
var detail := RichTextLabel.new()
var buy_btn: Button
var equip_btn: Button
var try_btn: Button
var status := Label.new()
var restore_btn: Button
var fly_btn: Button # after a purchase: straight into a match wearing it
var hangar_btn: Button # phone, the everything bundle: pick looks in the hangar
var tabs: Array = [] # phone: category tiles
var cards: Array = [] # phone: this category's products
var cards_box := HBoxContainer.new()
var fx_t := 0.0


func _init(m: Node, s: Shop) -> void:
	main = m
	shop = s
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var phone := TouchControls.phone()
	var box := VBoxContainer.new()
	var head := box
	if phone: # nothing scrolls: BACK beside the title, picture tabs and cards, the buttons two by two
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		box.add_child(top)
		Menus.icon_tile(top, "BACK", "back", close, main, 16, Vector2(132, 68), true)
		head = VBoxContainer.new()
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_theme_constant_override("separation", 0)
		top.add_child(head)
	Menus.big_title(head, "SHOP" if phone else "HANGAR SHOP", 28 if phone else 36)
	var note := Label.new()
	note.text = "Looks only: nothing here changes speed, damage or armour." if shop.sells() else "Desktop build: every look is unlocked. Equip what you like."
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.add_child(note)
	cat_sel = Menus.Selector.new("SHOP", Shop.CATEGORIES.map(func(c): return {title = c}))
	cat_sel.changed.connect(func(_i): _fill(); _pick())
	box.add_child(cat_sel)
	item_sel = Menus.Selector.new("ITEM", [{title = ""}])
	item_sel.changed.connect(func(_i): _pick())
	box.add_child(item_sel)
	if phone: # the selectors stay as the model; picture tabs and cards drive them
		cat_sel.hide()
		item_sel.hide()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		for i in Shop.CATEGORIES.size():
			var t := Menus.icon_tile(row, ["SETS", "PAINT", "TRAILS", "KILL FX"][i], ["gift", "paint", "trail", "burst"][i], func():
				cat_sel.set_index(i)
				cat_sel.changed.emit(i), main, 13, Vector2(0, 76))
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.append(t)
		cards_box.add_theme_constant_override("separation", 6)
		box.add_child(cards_box)
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.custom_minimum_size = Vector2(440, 64)
	box.add_child(detail)
	var acts := Menus.columns(box)
	buy_btn = Menus.menu_item(acts, "BUY", _buy, main, 22 if phone else 26)
	equip_btn = Menus.menu_item(acts, "EQUIP", _equip, main, 22)
	try_btn = Menus.menu_item(acts, "TRY IT FREE" if phone else "TRY IT FREE IN FREE FLIGHT", _try, main, 18)
	fly_btn = Menus.menu_item(acts, "FLY WITH IT", func(): close(); main.quick_battle(), main, 22)
	if phone:
		hangar_btn = Menus.menu_item(acts, "OPEN HANGAR", func(): close(); main.hangar_ui.open("PAINT"), main, 20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.modulate = Menus.AMBER
	head.add_child(status)
	restore_btn = Menus.menu_item(acts, "RESTORE PURCHASES", shop.restore, main, 16)
	restore_btn.visible = shop.sells()
	if phone:
		for c: Control in [note, status]:
			c.add_theme_font_size_override("font_size", 13)
		for b: Control in acts.get_children():
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for b: Button in [buy_btn, fly_btn]: # the next step is the amber one
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			Menus.lit(b, true)
		for f in ["normal_font_size", "bold_font_size"]:
			detail.add_theme_font_size_override(f, 15)
	else:
		Menus.menu_item(box, "BACK", close, main, 22)
	Menus.side_panel(self, box, 560).get_theme_stylebox("panel").content_margin_top = 24
	box.add_theme_constant_override("separation", 6)
	shop.changed.connect(_refresh)
	shop.notice.connect(func(t): status.text = t)
	shop.bought.connect(_bought)
	hide()


func open(product := "", note := "") -> void:
	if product != "":
		cat_sel.set_index(Shop.PRODUCTS[product].cat)
	_fill()
	if product != "":
		item_sel.set_index(_products().find(product))
	status.text = Shop.NO_STORE if note == "" and shop.store_down else note
	shop.fetch()
	show()
	main._refresh_ui()
	_pick()
	if TouchControls.on(): # no keyboard on a phone: start at the top, title in view
		if cat_sel.get_parent().get_parent() is ScrollContainer:
			cat_sel.get_parent().get_parent().scroll_vertical = 0
	else:
		cat_sel.grab_focus()


func close() -> void:
	hide()
	main._refresh_ui()
	main.preview_key = ""
	main._refresh_preview()


func _products() -> Array:
	return Shop.PRODUCTS.keys().filter(func(p): return Shop.PRODUCTS[p].cat == cat_sel.index)


func _product() -> String:
	return _products()[item_sel.index]


func _fill() -> void:
	item_sel.set_items(_products().map(func(p):
		return {title = Shop.PRODUCTS[p].title.to_upper(), sub = _tag(p)}))
	if not TouchControls.phone():
		return
	if cards.size() != item_sel.items.size() or cards.is_empty() or cards[0].get_meta("cat") != cat_sel.index:
		for c in cards:
			cards_box.remove_child(c)
			c.queue_free()
		cards.clear()
		for i in _products().size():
			var p: String = _products()[i]
			var c := Menus.card(cards_box, Shop.PRODUCTS[p].title.to_upper().trim_suffix(" KILL EFFECT").trim_suffix(" PAINT").trim_suffix(" TRAIL"), _swatch.bind(p), func():
				item_sel.set_index(i)
				_pick(), main, Vector2(0, 100))
			c.set_meta("cat", cat_sel.index)
			c.name = "Card_" + p
			cards.append(c)
	for i in cards.size():
		var p: String = _products()[i]
		Menus.card_state(cards[i], _tag(p), i == item_sel.index, not shop.owns_product(p))
	for i in tabs.size():
		Menus.lit(tabs[i], i == cat_sel.index)


func _tag(p: String) -> String:
	return "EQUIPPED" if _equipped(p) else ("OWNED" if shop.owns_product(p) else shop.price(p))


# A product's picture: its paint, trail colours and kill effect side by side.
static func _swatch(b: Control, r: Rect2, p: String) -> void:
	var items: Array = Shop.PRODUCTS[p].items
	if items.size() > 3:
		Menus.icon(b, "gift", r.get_center(), minf(r.size.x, r.size.y) * 0.45, Menus.AMBER)
		return
	var w := r.size.x / items.size()
	for k in items.size():
		var cell := Rect2(r.position + Vector2(w * k, 0), Vector2(w - (3 if k < items.size() - 1 else 0), r.size.y))
		var n := int(items[k].get_slice(":", 1))
		match items[k].get_slice(":", 0):
			"livery":
				HangarUI._paint_swatch(b, cell, n)
			"trail":
				HangarUI._trail_swatch(b, cell, n)
			"killfx":
				Menus.icon(b, "burst", cell.get_center(), minf(cell.size.x, cell.size.y) * 0.45, HangarUI.FX_COLORS[n])


func _equipped(p: String) -> bool:
	for item in Shop.PRODUCTS[p].items:
		var slot: String = item.get_slice(":", 0)
		if int(Settings.values.get("banner" if slot == "trail" else slot, 0)) != int(item.get_slice(":", 1)):
			return false
	return shop.owns_product(p) and Shop.PRODUCTS[p].items.size() <= 3


func _pick() -> void:
	var p := _product()
	var info: Dictionary = Shop.PRODUCTS[p]
	var text := "[b]%s[/b]\n%s" % [info.title, info.blurb]
	var save := shop.saving(p)
	if save > 0 and shop.sells():
		text += "\n[color=#ffd34d]About %d%% less than buying these one by one.[/color]" % save
	if shop.sells():
		text += "\n[font_size=12]%s[/font_size]" % ("One-time purchase, yours on all your devices." if TouchControls.phone() else "One-time purchase. Yours on every device with your Apple ID; Restore Purchases brings it back.")
	detail.text = text
	_refresh()
	main.preview_key = ""
	main._refresh_preview()
	fx_t = 0.4


func _refresh() -> void:
	if not visible:
		return
	_fill()
	var p := _product()
	var own := shop.owns_product(p)
	buy_btn.visible = shop.sells() and not own
	var cost := shop.price(p)
	buy_btn.disabled = shop.busy != "" or (cost == "" and shop.fetching)
	buy_btn.text = "BUYING..." if shop.busy == p else ("BUY   %s" % cost if cost != "" else ("LOADING PRICE..." if shop.fetching else "TRY AGAIN"))
	equip_btn.visible = own and Shop.PRODUCTS[p].items.size() <= 3
	equip_btn.text = "EQUIPPED" if _equipped(p) else "EQUIP"
	try_btn.visible = shop.sells() and not own and main.gs.phase == "menu"
	fly_btn.visible = own and _equipped(p) and main.gs.phase == "menu" and shop.sells()
	if hangar_btn:
		hangar_btn.visible = own and Shop.PRODUCTS[p].items.size() > 3 and main.gs.phase == "menu"


# Bought it: wear it at once (the everything bundle points to the hangar instead), say so, offer the flight.
func _bought(p: String) -> void:
	if Shop.PRODUCTS[p].items.size() <= 3:
		_equip(p)
		status.text = "Unlocked and equipped! You'll fly it next match."
	else:
		status.text = "Everything unlocked! Pick your looks in the Hangar."
	TouchControls.buzz(30)
	_refresh()


# No price yet means the App Store didn't answer: the button asks again instead.
func _buy() -> void:
	if shop.price(_product()) == "":
		shop.fetch(true)
	else:
		shop.buy(_product())


func _equip(p := "") -> void:
	for item in Shop.PRODUCTS[p if p else _product()].items:
		var slot: String = item.get_slice(":", 0)
		Settings.values["banner" if slot == "trail" else slot] = int(item.get_slice(":", 1))
	Settings.save()
	main.send_look()
	_refresh()


# Fly it before you pay: a Free Flight wearing it, and the shop greets you on that item afterwards.
func _try() -> void:
	var p := _product()
	shop.trying = Shop.PRODUCTS[p].items.duplicate()
	Engine.set_meta("shop_try", p)
	hide()
	main.free_flight()


# The look on the turntable: what you wear, with the selected item on top.
func preview_look() -> Array:
	var look := [int(Settings.values.sticker), 0, int(Settings.values.livery)]
	for item in Shop.PRODUCTS[_product()].items:
		match item.get_slice(":", 0):
			"livery":
				look[2] = int(item.get_slice(":", 1))
			"trail":
				look[1] = int(item.get_slice(":", 1))
	return look


func _process(dt: float) -> void:
	if not visible:
		return
	fx_t -= dt
	if fx_t > 0.0:
		return
	fx_t = 2.6
	for item in Shop.PRODUCTS[_product()].items:
		if item.begins_with("killfx:") and Shop.PRODUCTS[_product()].items.size() <= 3:
			Fx.kill_effect(main, main.preview.global_position + main.lobby_cam.global_basis.x * 9.0 + Vector3.UP * 2.0, int(item.get_slice(":", 1)))
