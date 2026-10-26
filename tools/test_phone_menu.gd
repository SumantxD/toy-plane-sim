extends SceneTree
# Every phone menu screen without a window: layout by numbers (on screen, inside a faked notch / home-bar
# safe area, no overlaps, 44 pt targets, nothing that scrolls, every text page fits) at three phone sizes,
# then the flows by simulated taps and the turntable by a simulated drag.
#   godot --headless -s tools/test_phone_menu.gd -- --phone --fake-store --local-player
const SCREENS := [Vector2i(2622, 1206), Vector2i(1334, 750), Vector2i(1427, 1004)] # 1347x620, 1100x620, 1100x773
const INSETS := Vector4(95, 0, 95, 32) # 62 pt left/right, 21 pt home bar
const MIN_TAP := 68.0 # 44 pt
var main: Node
var rows: Array = []


func _ok(what: String, ok: bool, detail := "") -> void:
	rows.append([what, ok, detail])


func _touch(at: Vector2, down: bool, double := false) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * at
	e.pressed = down
	e.double_tap = double
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * at
	e.relative = root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


func _tap(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	_touch(at, true)
	_drag(at, Vector2.ZERO)
	await process_frame
	_touch(at, false)
	for i in 10:
		await process_frame


func _frames(n := 4) -> void:
	for i in n:
		await process_frame


func _button(under: Node, text: String) -> Button:
	for c in under.find_children("*", "Button", true, false):
		if c.is_visible_in_tree() and c.text.strip_edges() == text:
			return c
	return null


func _fresh() -> void:
	if main:
		main._leave()
		for i in 60:
			await process_frame
		main = current_scene
	else:
		change_scene_to_packed(load("res://main.tscn"))
		await process_frame
		main = current_scene
	for i in 10:
		await process_frame


func _safe() -> Rect2:
	var vis := root.get_visible_rect()
	return Rect2(vis.position + Vector2(INSETS.x, INSETS.y), vis.size - Vector2(INSETS.x + INSETS.z, INSETS.y + INSETS.w))


# Taps on screen, in the safe area, >= 44 pt, apart; every control on screen; nothing that would scroll.
func _layout(screen: String, under: Control) -> void:
	await _frames()
	var vis := root.get_visible_rect()
	var font: Font = load("res://assets/ui/kenney_future.ttf")
	var taps: Array = []
	var bad: Array = []
	for b: Control in under.find_children("*", "Control", true, false):
		if not b.is_visible_in_tree() or not (b is BaseButton or b is LineEdit):
			continue
		var r := b.get_global_rect()
		var label: String = b.text if b.text else str(b.name)
		taps.append([label, r])
		if r.size.x < MIN_TAP - 0.5 or r.size.y < MIN_TAP - 0.5:
			bad.append("%s small %s" % [label, r.size])
		if not _safe().grow(0.5).encloses(r):
			bad.append("%s outside safe %s" % [label, r])
		if b is Button:
			for ch in b.text:
				if not font.has_char(ch.unicode_at(0)) and not ch in "₹$€£¥": # prices: the system font fills in
					bad.append("%s glyph '%s'" % [label, ch])
	for i in taps.size():
		for j in range(i + 1, taps.size()):
			if taps[i][1].grow(-0.5).intersects(taps[j][1].grow(-0.5)):
				bad.append("%s overlaps %s" % [taps[i][0], taps[j][0]])
	for c: Control in [under] + under.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree():
			continue
		if c.size.x > 0.0 and not vis.grow(0.5).encloses(c.get_global_rect()):
			bad.append("%s off screen %s" % [c.name, c.get_global_rect()])
		var need := c.get_combined_minimum_size()
		if need.x > c.size.x + 0.5 or need.y > c.size.y + 0.5: # squeezed: its contents spill over
			bad.append("%s squeezed %s < %s" % [c.name, c.size, need])
		if c is ScrollContainer:
			for sb: ScrollBar in [c.get_v_scroll_bar(), c.get_h_scroll_bar()]:
				if sb.max_value > sb.page + 0.5:
					bad.append("%s scrolls %d > %d" % [c.name, sb.max_value, sb.page])
		if c is RichTextLabel:
			var sb: ScrollBar = c.get_v_scroll_bar()
			if c.get_content_height() > c.size.y + 0.5 or (c.scroll_active and sb.max_value > sb.page + 0.5):
				bad.append("%s text %d > %d" % [c.name, c.get_content_height(), c.size.y])
	_ok("%s %d taps" % [screen, taps.size()], bad.is_empty() and taps.size() > 0, ", ".join(bad.slice(0, 6)))


# Every page of a pager fits its box.
func _pages(screen: String, pg: Menus.Pager) -> void:
	var bad: Array = []
	for i in pg.pages.size():
		pg.page = i
		pg.turn(0)
		await process_frame
		if pg.label.get_content_height() > pg.label.size.y + 0.5 or pg.label.get_v_scroll_bar().max_value > pg.label.get_v_scroll_bar().page + 0.5:
			bad.append("page %d: %d > %d" % [i + 1, pg.label.get_content_height(), pg.label.size.y])
	_ok("%s: all %d pages fit" % [screen, pg.pages.size()], bad.is_empty() and pg.pages.size() > 0, ", ".join(bad.slice(0, 6)))
	pg.page = 0
	pg.turn(0)


func _pager(under: Node) -> Menus.Pager:
	for c in under.find_children("*", "", true, false):
		if c is Menus.Pager:
			return c
	return null


# Turntable: a vertical drag on the open space tips the plane over (top / bottom), no button fires.
func _spin(screen: String) -> void:
	await _frames()
	var cam: Camera3D = main.lobby_cam
	var at := cam.unproject_position(main.preview.global_position)
	var shown := root.get_visible_rect().has_point(at)
	var beside: Control = (main.shop_ui if main.shop_ui.visible else main.lobby_root).get_child(0)
	var clear := at.x > beside.get_global_rect().end.x + 40.0 and at.x < root.get_visible_rect().end.x - INSETS.z
	var phase: String = main.gs.phase
	var shop_was: Array = [main.shop_ui.visible, main.shop_ui.cat_sel.index, main.shop_ui.item_sel.index]
	_touch(at, true)
	for k in 12:
		_drag(at + Vector2(0, 12 * (k + 1)), Vector2(0, 12))
		await process_frame
	_touch(at + Vector2(0, 144), false)
	await process_frame
	var tip := rad_to_deg(main.preview.global_basis.y.angle_to(Vector3.UP))
	var same: bool = phase == main.gs.phase and shop_was == [main.shop_ui.visible, main.shop_ui.cat_sel.index, main.shop_ui.item_sel.index]
	_ok("%s turntable: drag tips it %d deg (> 60), plane at %s beside the panel" % [screen, tip, at.round()], tip > 60.0 and shown and clear and same,
		"shown %s clear %s nothing pressed %s" % [shown, clear, same])
	_touch(at, true, true) # double-tap levels it
	await process_frame
	_touch(at, false)
	await _frames()
	_ok("%s turntable: double-tap levels it" % screen, main.preview.global_basis.y.angle_to(Vector3.UP) < 0.05)


func _initialize() -> void:
	Engine.set_meta("test_insets", INSETS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg"))
	Settings.load_saved()
	var keep := Settings.values.duplicate(true)
	Settings.values.merge({last_world = 2, last_mode = 4, last_size = 0, last_skill = 2, matches = 5, offer_dismiss = {}}, true)
	Settings.save()
	for scr in SCREENS:
		for i in 2: # headless ignores --resolution; the first resize after start doesn't stick
			root.size = scr
			await process_frame
		await _fresh()
		var tag := "%dx%d" % [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
		await _layout("home " + tag, main.menu_root)
		main.status.text = main.PHONE_NET_TIP # the longest note the home screen shows
		await process_frame
		var sr: Rect2 = main.status.get_global_rect()
		_ok("home status note clear of buttons " + tag, not sr.intersects(main.menu_root.get_node("HangarShop").get_global_rect()) and sr.position.y >= 0.0, str(sr))
		await _tap(main.find_child("MissionCard", true, false))
		await _layout("mission select " + tag, main.mission_root)
		var cards_in: bool = main.world_cards.all(func(c): return c.is_visible_in_tree() and _safe().encloses(c.get_global_rect()))
		_ok("mission select: all 6 worlds on screen, no scroller " + tag, cards_in and main.mission_root.find_children("*", "ScrollContainer", true, false).is_empty())
		await _tap(_button(main.mission_root, "<  BACK"))
		await _tap(_button(main.menu_root, "MULTIPLAYER"))
		await _layout("multiplayer " + tag, main.mp_root)
		var high: bool = main.address.get_global_rect().end.y < root.get_visible_rect().size.y * 0.48 and main.name_edit.get_global_rect().end.y < root.get_visible_rect().size.y * 0.48
		await _frames()
		sr = main.status.get_global_rect()
		var hit: Array = main.mp_root.find_children("*", "Control", true, false).filter(func(c): return c.is_visible_in_tree() and (c is BaseButton or c is LineEdit) and c.get_global_rect().intersects(sr))
		_ok("multiplayer: code + callsign fields above the keyboard, note clear " + tag, high and hit.is_empty() and _safe().encloses(sr),
			"address %s name %s note %s over %s" % [main.address.get_global_rect(), main.name_edit.get_global_rect(), sr, hit])
		main.status.text = ""
		await _tap(_button(main.mp_root, "BACK"))
		await _tap(_button(main.menu_root, "SETTINGS"))
		await _layout("settings " + tag, main.settings_root)
		await _tap(_button(main.settings_root, "Touch controls..."))
		await _layout("touch controls " + tag, main.touch_root)
		await _tap(_button(main.touch_root, "Customize layout"))
		var tc: TouchControls = main.touch
		var tools_ok: bool = tc.editing and range(tc.TOOLS.size()).all(func(i): return tc._tool_rect(i).size.y >= MIN_TAP and _safe().encloses(tc._tool_rect(i)))
		tc._tool("DONE")
		await _frames()
		_ok("touch layout editor: tools >= 44 pt, on screen " + tag, tools_ok and main.touch_root.visible)
		main.touch_root.hide()
		await _tap(_button(main.menu_root, "HOW TO PLAY"))
		await _layout("how to play " + tag, main.howto_root)
		await _pages("how to play " + tag, _pager(main.howto_root))
		main.howto_root.hide()
		await _tap(_button(main.menu_root, "CREDITS"))
		await _layout("credits " + tag, main.credits_root)
		await _pages("credits " + tag, _pager(main.credits_root))
		await _tap(_button(main.credits_root, "LICENSES"))
		await _layout("licenses " + tag, main.credits_root)
		await _pages("licenses " + tag, _pager(main.credits_root))
		await _tap(_button(main.credits_root, "CREDITS"))
		main.credits_root.hide()
		await _tap(_button(main.menu_root, "HANGAR SHOP"))
		await _layout("hangar shop " + tag, main.shop_ui)
		main.shop_ui.status.text = "The App Store couldn't verify this purchase. Tap Restore Purchases to try again." # the longest notice
		await _layout("hangar shop + notice " + tag, main.shop_ui)
		main.shop_ui.cat_sel.set_index(0)
		main.shop_ui.cat_sel.changed.emit(0) # SETS: the longest detail text
		await _layout("hangar shop sets " + tag, main.shop_ui)
		await _spin("hangar shop " + tag)
		main.shop_ui.close()
		await _tap(main.find_child("MissionCard", true, false))
		await _tap(_button(main.mission_root, "PLANE + LOOKS"))
		for k in main.lobby_pages:
			if main.lobby_pages[k][0].visible:
				main._lobby_tab(k)
				await _layout("solo lobby %s %s" % [k, tag], main.lobby_root)
		await _spin("lobby " + tag)
		await _tap(main.start_btn)
		main.pause_root.show()
		await _layout("pause " + tag, main.pause_root)
		main.pause_root.hide()
		main._end("%s team wins!" % main.TEAM_NAMES[main._my_team()])
		for i in 7: # a full room: 8 pilots on the board
			main.gs.players[100 + i] = {name = "WWWWWWWWWWWWWWWW", team = i % 2, kills = 99, deaths = 99, revives = 9, plane = "cub"}
		main._refresh_ui()
		await _layout("results (8 pilots + offer) " + tag, main.results_root)
		for i in 7:
			main.gs.players.erase(100 + i)
		await create_timer(8.5).timeout
		_ok("solo match over -> home screen, not the lobby " + tag, main.gs.phase == "menu" and main.menu_root.visible and not main.lobby_root.visible and not main.results_root.visible,
			"phase %s home %s" % [main.gs.phase, main.menu_root.visible])
		await _tap(_button(main.menu_root, "MULTIPLAYER"))
		await _tap(_button(main.mp_root, "HOST ON LAN"))
		main.gs.mode = 1 # team mode: SWITCH TEAM shows
		main.gs.room = "KNHXC" # COPY ROOM CODE shows
		main.gs.msg = "Kicked: someone"
		for i in 7: # a full room: roster, KICK buttons
			main.gs.players[100 + i] = {name = "WWWWWWWWWWWWWWWW", team = i % 2, kills = 0, deaths = 0, plane = "cub", ping = 999}
		main.net_label.text = "Room open. Friends join with the code; it stays open while you're in the lobby."
		main._refresh_ui()
		for k in main.lobby_pages:
			if main.lobby_pages[k][0].visible:
				main._lobby_tab(k)
				await _layout("LAN lobby (8 pilots) %s %s" % [k, tag], main.lobby_root)
		for i in 7:
			main.gs.players.erase(100 + i)
		main._refresh_ui()
	# flows: PLAY one tap, the remembered mission
	await _fresh()
	await _tap(main.find_child("Play", true, false))
	_ok("PLAY one tap -> match with last_*", main.gs.phase == "playing" and main.gs.world == 2 and main.gs.mode == 4 and main.gs.size == 0 and main.gs.skill == 2,
		"phase %s world %d mode %d size %d skill %d" % [main.gs.phase, main.gs.world, main.gs.mode, main.gs.size, main.gs.skill])
	await _fresh()
	_ok("PLAY line names it", "FROZEN FRONTIER" in main.play_sub.text and "CAPTURE THE FLAG" in main.play_sub.text, main.play_sub.text)
	await _tap(main.find_child("MissionCard", true, false))
	_ok("mission card -> Mission Select", main.mission_root.visible and not main.menu_root.visible)
	var built: int = Worlds.index
	await _tap(main.world_cards[3])
	var saved := ConfigFile.new()
	saved.load(Settings.PATH)
	_ok("pick world", main.gs.world == 3 and Settings.values.last_world == 3 and saved.get_value("prefs", "last_world") == 3 and Worlds.shown == 3 and Worlds.index == built,
		"gs %d saved %s shown %d built %d" % [main.gs.world, saved.get_value("prefs", "last_world"), Worlds.shown, Worlds.index])
	await _tap(main.world_cards[5])
	await _tap(main.world_cards[3])
	_ok("every world card one tap away (no scrolling)", main.gs.world == 3 and Settings.values.last_world == 3)
	await _tap(main.mode_chips[0])
	_ok("pick Co-op Escort hides size/skill", main.gs.mode == 0 and not main.battle_segs.visible)
	await _tap(main.mode_chips[5])
	await _tap(main.size_segs[2])
	await _tap(main.skill_segs[3])
	var v := Settings.values
	_ok("pick mode / size / skill", main.gs.mode == 5 and main.gs.size == 2 and main.gs.skill == 3 and v.last_mode == 5 and v.last_size == 2 and v.last_skill == 3,
		"gs %d/%d/%d last %d/%d/%d" % [main.gs.mode, main.gs.size, main.gs.skill, v.last_mode, v.last_size, v.last_skill])
	await _tap(_button(main.mission_root, "<  BACK"))
	_ok("BACK -> home", main.menu_root.visible and not main.mission_root.visible and "DESERT WASTELAND" in main.play_sub.text, main.play_sub.text)
	await _tap(main.find_child("MissionCard", true, false))
	await _tap(main.find_child("Launch", true, false))
	_ok("LAUNCH -> match", main.gs.phase == "playing" and main.gs.world == 3 and main.gs.mode == 5 and main.gs.size == 2 and main.gs.skill == 3 and Worlds.index == 3,
		"phase %s world %d built %d mode %d" % [main.gs.phase, main.gs.world, Worlds.index, main.gs.mode])
	await _fresh()
	await _tap(_button(main.menu_root, "MULTIPLAYER"))
	_ok("MULTIPLAYER -> host/join screen", main.mp_root.visible and not main.menu_root.visible)
	await _tap(_button(main.mp_root, "HOST ON LAN"))
	await _frames(10)
	_ok("HOST ON LAN -> lobby, MISSION tab", main.gs.phase == "lobby" and main.lobby_root.visible and main.world_sel.is_visible_in_tree() and not main.mission_root.visible and not main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	await _fresh()
	await _tap(_button(main.menu_root, "MULTIPLAYER"))
	await _tap(_button(main.mp_root, "BACK"))
	_ok("MULTIPLAYER BACK -> home", main.menu_root.visible)
	await _tap(_button(main.menu_root, "FREE FLIGHT"))
	_ok("FREE FLIGHT -> flying", main.gs.phase == "playing" and main.gs.mode == 2)
	await _fresh()
	await _tap(_button(main.menu_root, "HANGAR SHOP"))
	_ok("HANGAR SHOP -> shop", main.shop_ui.visible and not main.menu_root.visible)
	await _tap(_button(main.shop_ui, "<  BACK"))
	_ok("shop <  BACK -> home", not main.shop_ui.visible and main.menu_root.visible)
	for it in [["SETTINGS", "settings_root"], ["HOW TO PLAY", "howto_root"], ["CREDITS", "credits_root"]]:
		await _tap(_button(main.menu_root, it[0]))
		_ok(it[0] + " -> panel", main.get(it[1]).visible)
		main.get(it[1]).hide()
	await _tap(_button(main.menu_root, "HOW TO PLAY"))
	var pg := _pager(main.howto_root)
	await _tap(_button(main.howto_root, ">"))
	await _tap(_button(main.howto_root, ">"))
	var turned: int = pg.page
	await _tap(_button(main.howto_root, "<"))
	_ok("HOW TO PLAY > > < turns pages", turned == 2 and pg.page == 1 and pg.count.text == "PAGE 2 / %d" % pg.pages.size(), pg.count.text)
	await _tap(_button(main.howto_root, "GOT IT"))
	_ok("GOT IT closes", not main.howto_root.visible)
	await _tap(main.find_child("MissionCard", true, false))
	await _tap(_button(main.mission_root, "PLANE + LOOKS"))
	_ok("PLANE + LOOKS -> lobby on the PLANE tab", main.gs.phase == "lobby" and main.lobby_root.visible and main.plane_sel.is_visible_in_tree() and main.gs.world == 3)
	await _tap(main.lobby_pages.LOOKS[0])
	_ok("LOOKS tab -> paint, trail, sticker, kill effect", main.livery_sel.is_visible_in_tree() and main.sticker_sel.is_visible_in_tree() and not main.plane_sel.is_visible_in_tree())
	var fails := rows.filter(func(r): return not r[1]).size()
	print("\n%-78s %s" % ["CHECK", "RESULT"])
	for r in rows:
		print("%-78s %s  %s" % [r[0], "PASS" if r[1] else "FAIL", r[2]])
	print("%d checks, %d failed" % [rows.size(), fails])
	Settings.values = keep
	Settings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg"))
	quit(1 if fails else 0)
