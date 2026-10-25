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
var fx_t := 0.0


func _init(m: Node, s: Shop) -> void:
	main = m
	shop = s
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	Menus.big_title(box, "HANGAR SHOP", 36)
	var note := Label.new()
	note.text = "Looks only: nothing here changes speed, damage or armour." if shop.sells() else "Desktop build: every look is unlocked. Equip what you like."
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(note)
	cat_sel = Menus.Selector.new("SHOP", Shop.CATEGORIES.map(func(c): return {title = c}))
	cat_sel.changed.connect(func(_i): _fill(); _pick())
	box.add_child(cat_sel)
	item_sel = Menus.Selector.new("ITEM", [{title = ""}])
	item_sel.changed.connect(func(_i): _pick())
	box.add_child(item_sel)
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.custom_minimum_size = Vector2(440, 64)
	box.add_child(detail)
	buy_btn = Menus.menu_item(box, "BUY", func(): shop.buy(_product()), main, 26)
	equip_btn = Menus.menu_item(box, "EQUIP", _equip, main, 22)
	try_btn = Menus.menu_item(box, "TRY IT FREE IN FREE FLIGHT", _try, main, 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.modulate = Menus.AMBER
	box.add_child(status)
	restore_btn = Menus.menu_item(box, "RESTORE PURCHASES", shop.restore, main, 16)
	restore_btn.visible = shop.sells()
	Menus.menu_item(box, "BACK", close, main, 22)
	Menus.side_panel(self, box, 560).get_theme_stylebox("panel").content_margin_top = 24
	box.add_theme_constant_override("separation", 6)
	shop.changed.connect(_refresh)
	shop.notice.connect(func(t): status.text = t)
	hide()


func open(product := "", note := "") -> void:
	if product != "":
		cat_sel.set_index(Shop.PRODUCTS[product].cat)
	_fill()
	if product != "":
		item_sel.set_index(_products().find(product))
	status.text = note
	show()
	main._refresh_ui()
	_pick()
	if TouchControls.on(): # no keyboard on a phone: start at the top, title in view
		(cat_sel.get_parent().get_parent() as ScrollContainer).scroll_vertical = 0
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
		var tag := "EQUIPPED" if _equipped(p) else ("OWNED" if shop.owns_product(p) else shop.price(p))
		return {title = Shop.PRODUCTS[p].title.to_upper(), sub = tag}))


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
		text += "\n[font_size=12]One-time purchase. Yours on every device with your Apple ID; Restore Purchases brings it back.[/font_size]"
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
	buy_btn.disabled = shop.busy != "" or shop.price(p) == ""
	buy_btn.text = "BUYING..." if shop.busy == p else ("BUY   %s" % shop.price(p) if shop.price(p) != "" else "LOADING PRICE...")
	equip_btn.visible = own and Shop.PRODUCTS[p].items.size() <= 3
	equip_btn.text = "EQUIPPED" if _equipped(p) else "EQUIP"
	try_btn.visible = shop.sells() and not own and main.gs.phase == "menu"


func _equip() -> void:
	for item in Shop.PRODUCTS[_product()].items:
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
