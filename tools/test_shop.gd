extends SceneTree
# The shop end to end against the test store (no Apple): browse, buy, cancel, equip, try-before-buy,
# lobby locks, the post-win offer, a kill effect.
#   godot --path . --resolution 1311x603 -s tools/test_shop.gd -- --phone --fake-store [--shots]
var main: Node


func _shot(name: String) -> void:
	if "--shots" in OS.get_cmdline_user_args():
		for i in 3:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/shop_%s.png" % name)


func _press(text: String, under: Node = null) -> bool:
	for c in (under if under else main).find_children("*", "BaseButton", true, false):
		if c.is_visible_in_tree() and str(c.text).strip_edges().begins_with(text):
			c.pressed.emit()
			for i in 5:
				await process_frame
			return true
	print("  (no button %s)" % text)
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg"))
	Settings.load_saved()
	var keep := Settings.values.duplicate(true)
	Settings.values.livery = 0
	Settings.values.banner = 0
	Settings.values.killfx = 0
	Settings.values.matches = 5
	Settings.values.offer_dismiss = {}
	Settings.save()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(0.5)
	var shop: Shop = main.shop
	var ui: ShopUI = main.shop_ui
	print("backend: ", shop.backend, "   sells: ", shop.sells(), "   owns golden paint: ", shop.owns("livery:1"))
	await _press("HANGAR SHOP")
	print("main menu -> shop open: ", ui.visible, "   preview shown: ", main.preview.visible)
	await _shot("sets")
	print("  SETS: ", ui.item_sel.items.map(func(i): return "%s %s" % [i.title, i.sub]))
	print("  detail: ", ui.detail.get_parsed_text().replace("\n", " | "))
	ui.cat_sel.set_index(1)
	ui.cat_sel.changed.emit(1)
	await _wait(0.3)
	await _shot("paint")
	ui.cat_sel.set_index(3)
	ui.cat_sel.changed.emit(3)
	await _wait(1.0)
	await _shot("killfx")
	# buy a set
	ui.open("bundle.golden")
	await _press("BUY")
	print("tap BUY -> button: ", ui.buy_btn.text, "  busy: ", shop.busy)
	await _wait(1.0)
	print("after the store answers -> owns set: ", shop.owns_product("bundle.golden"), "  owns its paint/trail/kill: ", shop.owns("livery:1"), shop.owns("trail:7"), shop.owns("killfx:1"), "   notice: ", ui.status.text)
	await _press("EQUIP")
	print("EQUIP -> livery %d trail %d killfx %d   saved: %s" % [Settings.values.livery, Settings.values.banner, Settings.values.killfx, ConfigFile.new().load(Settings.PATH) == OK])
	await _shot("owned")
	# a locked item can't be worn online, only tried solo
	print("Neon paint picked but not owned: online wears -> ", _wear_with(shop, "livery", 3, false), "   solo try -> ", _try_wear(shop, "livery", 3))
	# try before you buy
	ui.open("livery.neon")
	await _press("TRY IT FREE")
	await _wait(2.0)
	var p: Node = main._plane(1)
	print("TRY -> phase %s mode %s  flying with livery %s (trying %s)" % [main.gs.phase, main.MODES[main.gs.mode], main.gs.players[1].get("livery"), shop.trying])
	await _shot("trying")
	main._leave()
	await _wait(1.5)
	main = current_scene
	print("leave -> shop greets: ", main.shop_ui.visible, "  on: ", main.shop_ui._product(), "  note: ", main.shop_ui.status.text)
	await _shot("after_try")
	main.shop_ui.close()
	# lobby: locked tags, look sent
	main.solo_battle()
	await _wait(0.6)
	main._fill_looks()
	print("lobby paint rows: ", main.livery_sel.items.map(func(i): return "%s[%s]" % [i.title, i.sub]))
	print("host look in gs: livery %s trail %s killfx %s" % [main.gs.players[1].get("livery"), main.gs.players[1].get("banner"), main.gs.players[1].get("killfx")])
	await _shot("lobby")
	# post-win offer
	main.gs.phase = "ended"
	main.gs.msg = "%s team wins!" % main.TEAM_NAMES[main._my_team()]
	main.gs.match_id += 1
	main._refresh_ui()
	main.results_root.show()
	await _wait(0.3)
	var lines := []
	for row in main.offer_box.get_children():
		for c in row.get_children():
			lines.append(c.text)
	print("results after a win -> offer: ", lines)
	await _shot("offer")
	# kill effects render without errors
	for k in [1, 2, 3]:
		Fx.kill_effect(main, Vector3(0, 300, 0), k)
	await _wait(1.0)
	print("kill effects played")
	Settings.values = keep
	Settings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg"))
	quit()


func _wear_with(shop: Shop, slot: String, v: int, solo: bool) -> int:
	var old: int = Settings.values[slot]
	Settings.values[slot] = v
	var out := shop.wear(slot, solo)
	Settings.values[slot] = old
	return out


func _try_wear(shop: Shop, slot: String, v: int) -> int:
	shop.trying = ["%s:%d" % [slot, v]]
	var out := shop.wear(slot, true)
	shop.trying = []
	return out
