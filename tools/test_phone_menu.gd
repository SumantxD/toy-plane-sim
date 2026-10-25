extends SceneTree
# Phone home + Mission Select without a window: layout by numbers (on screen, inside a faked notch / home-bar
# safe area, no overlaps, 44 pt targets, no scrolling) at three phone sizes, then the flows by simulated taps.
#   godot --headless -s tools/test_phone_menu.gd -- --phone --local-player
const SCREENS := [Vector2i(2622, 1206), Vector2i(2868, 1320), Vector2i(1427, 1004)]
const INSETS := Vector4(95, 0, 95, 32) # 62 pt left/right, 21 pt home bar
const MIN_TAP := 68.0 # 44 pt
var main: Node
var rows: Array = []


func _ok(what: String, ok: bool, detail := "") -> void:
	rows.append([what, ok, detail])


func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * at
	e.pressed = down
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * at
	e.relative = rel
	Input.parse_input_event(e)


func _tap(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	_touch(at, true)
	_drag(at, Vector2.ZERO)
	await process_frame
	_touch(at, false)
	for i in 10:
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


func _layout(screen: String, under: Control) -> void:
	var vis := root.get_visible_rect()
	var safe := Rect2(vis.position + Vector2(INSETS.x, INSETS.y), vis.size - Vector2(INSETS.x + INSETS.z, INSETS.y + INSETS.w))
	var font: Font = load("res://assets/ui/kenney_future.ttf")
	var taps: Array = []
	var bad: Array = []
	for b: Button in under.find_children("*", "Button", true, false):
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		var label: String = b.text if b.text else str(b.name)
		for clip in [b.get_parent().get_parent()]: # world cards: only the part the scroller shows counts
			if clip is ScrollContainer:
				r = r.intersection((clip as Control).get_global_rect())
		if r.size.x <= 0.0:
			continue
		taps.append([label, r])
		if r.size.x < MIN_TAP - 0.5 or r.size.y < MIN_TAP - 0.5:
			bad.append("%s small %s" % [label, r.size])
		if not safe.grow(0.5).encloses(r):
			bad.append("%s outside safe %s" % [label, r])
		for ch in b.text:
			if not font.has_char(ch.unicode_at(0)):
				bad.append("%s glyph '%s'" % [label, ch])
	for i in taps.size():
		for j in range(i + 1, taps.size()):
			if taps[i][1].grow(-0.5).intersects(taps[j][1].grow(-0.5)):
				bad.append("%s overlaps %s" % [taps[i][0], taps[j][0]])
	for c: Control in under.find_children("*", "Control", true, false): # everything fits the height: no vertical scroll needed
		if c.is_visible_in_tree() and c.get_global_rect().end.y > vis.end.y + 0.5:
			bad.append("%s below the screen" % c.name)
			break
	_ok("%s %d buttons" % [screen, taps.size()], bad.is_empty() and taps.size() > 0, ", ".join(bad))


func _initialize() -> void:
	Engine.set_meta("test_insets", INSETS)
	Settings.load_saved()
	var keep := Settings.values.duplicate(true)
	Settings.values.merge({last_world = 2, last_mode = 4, last_size = 0, last_skill = 2}, true)
	Settings.save()
	for scr in SCREENS:
		for i in 2: # headless ignores --resolution; the first resize after start doesn't stick
			root.size = scr
			await process_frame
		await _fresh()
		var tag := "%dx%d -> %s" % [scr.x, scr.y, root.get_visible_rect().size]
		_layout("home " + tag, main.menu_root)
		main.status.text = main.PHONE_NET_TIP # the longest note the home screen shows
		await process_frame
		var sr: Rect2 = main.status.get_global_rect()
		_ok("home status note clear of buttons " + tag, not sr.intersects(main.menu_root.get_node("HangarShop").get_global_rect()) and sr.position.y >= 0.0, str(sr))
		main.status.text = ""
		await _tap(main.find_child("MissionCard", true, false))
		_layout("mission " + tag, main.mission_root)
		await _tap(_button(main.mission_root, "<  BACK"))
	# PLAY: one tap, the remembered mission
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
	var sc: ScrollContainer = main.world_cards[0].get_parent().get_parent()
	var at: Vector2 = main.world_cards[1].get_global_rect().get_center()
	_touch(at, true)
	for k in 10:
		_drag(at - Vector2(30 * (k + 1), 0), Vector2(-30, 0))
		await process_frame
	_touch(at - Vector2(300, 0), false)
	for i in 10:
		await process_frame
	_ok("drag scrolls the worlds, picks nothing", sc.scroll_horizontal > 0 and main.gs.world == 3, "scroll %d world %d" % [sc.scroll_horizontal, main.gs.world])
	sc.scroll_horizontal = 0
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
	for i in 10:
		await process_frame
	_ok("HOST ON LAN -> lobby (old lobby panel)", main.gs.phase == "lobby" and main.lobby_root.visible and not main.mission_root.visible and not main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	await _fresh()
	await _tap(_button(main.menu_root, "MULTIPLAYER"))
	await _tap(_button(main.mp_root, "BACK"))
	_ok("MULTIPLAYER BACK -> home", main.menu_root.visible)
	await _tap(_button(main.menu_root, "FREE FLIGHT"))
	_ok("FREE FLIGHT -> flying", main.gs.phase == "playing" and main.gs.mode == 2)
	await _fresh()
	await _tap(_button(main.menu_root, "HANGAR SHOP"))
	_ok("HANGAR SHOP -> shop", main.shop_ui.visible and not main.menu_root.visible)
	main.shop_ui.close()
	for it in [["SETTINGS", "settings_root"], ["HOW TO PLAY", "howto_root"], ["CREDITS", "credits_root"]]:
		await _tap(_button(main.menu_root, it[0]))
		_ok(it[0] + " -> panel", main.get(it[1]).visible)
		main.get(it[1]).hide()
	await _tap(main.find_child("MissionCard", true, false))
	await _tap(_button(main.mission_root, "PLANE + LOOKS"))
	_ok("PLANE + LOOKS -> lobby with plane + hangar", main.gs.phase == "lobby" and main.lobby_root.visible and main.plane_sel.is_visible_in_tree() and main.gs.world == 3)
	var fails := rows.filter(func(r): return not r[1]).size()
	print("\n%-58s %s" % ["CHECK", "RESULT"])
	for r in rows:
		print("%-58s %s  %s" % [r[0], "PASS" if r[1] else "FAIL", r[2]])
	print("%d checks, %d failed" % [rows.size(), fails])
	Settings.values = keep
	Settings.save()
	quit(1 if fails else 0)
