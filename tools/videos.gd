extends SceneTree
# Drives the game for the App Review demo and the App Store previews, recorded by Movie Maker.
# Run it through tools/make_videos.sh (window size, user-data backup, captions, encoding):
#   godot --path . --write-movie x.avi --fixed-fps 30 --max-fps 30 -s tools/videos.gd -- --phone --fake-store <review|host|join|preview1|preview2>
# Prints "CAP <frame> <text>" (caption strip) and "MARK <frame> <name>" (cut points); frame = movie frame.
var main: Node
var tc: Control
var dots := {} # finger -> where it touches, drawn on top so the taps show
var dots_ui := Control.new()
var kills := 0


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _cap(text: String) -> void:
	print("CAP %d %s" % [Engine.get_process_frames(), text])


func _mark(what: String) -> void:
	print("MARK %d %s" % [Engine.get_process_frames(), what])


func _fresh() -> void:
	if main:
		main.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(0.6)
	tc = main.find_children("*", "TouchControls", true, false)[0]


# After Leave reloads the scene.
func _reloaded() -> void:
	var old := main
	while current_scene == old or current_scene == null or not current_scene.is_node_ready():
		await process_frame
	main = current_scene
	await _wait(0.6)
	tc = main.find_children("*", "TouchControls", true, false)[0]


# Wait for `ok`, but never record forever: a stuck run quits instead of filling the disk.
func _until(ok: Callable, secs := 60.0) -> void:
	var t := 0.0
	while not ok.call():
		await process_frame
		t += 1.0 / 30.0
		if t > secs:
			push_error("timed out")
			quit(1)
			return


func _btn(text: String) -> Button:
	for b: Button in main.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	push_error("no button " + text)
	return null


func _show(finger: int, at: Vector2, on: bool) -> void:
	if on:
		dots[finger] = at
	else:
		dots.erase(finger)
	dots_ui.queue_redraw()


# A finger tap on a menu control: the dot shows where, then the button does what a tap does.
func _tap(c: Control) -> void:
	var sc := c.get_parent()
	while sc and not sc is ScrollContainer:
		sc = sc.get_parent()
	if sc:
		(sc as ScrollContainer).ensure_control_visible(c)
		await _wait(0.2)
	_show(9, c.get_global_rect().get_center(), true)
	await _wait(0.35)
	_show(9, Vector2.ZERO, false)
	if c is BaseButton:
		c.pressed.emit()
	else:
		c.grab_focus()
	await _wait(0.15)


func _touch(at: Vector2, down: bool, finger: int) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.pressed = down
	Input.parse_input_event(e)
	_show(finger, at, down)


func _drag(at: Vector2, rel: Vector2, finger: int) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = root.get_final_transform() * at
	e.relative = rel
	Input.parse_input_event(e)
	_show(finger, at, true)


func _press(id: String, hold := 0.15) -> void:
	_touch(tc._center(id), true, 5)
	await _wait(hold)
	_touch(tc._center(id), false, 5)


func _me() -> int:
	return main.multiplayer.get_unique_id()


func _enemy(p: Node) -> Node:
	var best: Node = null
	var bd := INF
	for e: Node in main.players.get_children():
		if e == p or not e.alive or e.team == p.team or e.role not in ["pilot", "wing", "fighter"]:
			continue
		var d: float = e.position.distance_to(p.position)
		if d < bd:
			bd = d
			best = e
	return best


# Fly by touch only: left thumb steers toward the nearest enemy (or weaves), FIRE when it's ahead,
# ROCKET held until LOCK, then released. Returns early `after` s past the first kill when `after` >= 0.
func _fly(secs: float, hunt := true, after := -1.0) -> void:
	var base := Vector2(210, tc.size.y - 150)
	var last := base
	var t := 0.0
	var kill_t := -1.0
	var rocket_t := -1.0
	var rocket_next := 3.0
	var fire := false
	var boost := false
	var stick := false
	var near := INF # distance to the plane we're chasing: a kill only "counts" for `after` when it's in view
	while t < secs and (after < 0.0 or kill_t < 0.0 or t - kill_t < after):
		await process_frame
		t += 1.0 / 30.0
		if not is_instance_valid(main) or not main.is_inside_tree():
			_mark("lost") # dropped back to the menu (the other copy closed first)
			return
		var p: Node = main._plane(_me())
		if not p or not p.alive or not tc.visible:
			for f in [1, 2, 3, 6]:
				_show(f, Vector2.ZERO, false)
			stick = false
			fire = false
			boost = false
			rocket_t = -1.0
			continue
		if not stick:
			_touch(base, true, 2)
			last = base
			stick = true
		var want := Vector2(sin(t * 0.8) * 0.4, (p.aim_pitch - 0.05) * 2.2) # level weave
		var aimed := false
		var e: Node = _enemy(p) if hunt else null
		var prev := near # the victim drops out of _enemy() the frame it dies
		near = p.position.distance_to(e.position) if e else INF
		if e:
			var to: Vector3 = e.position + (e.velocity - p.velocity) * (p.position.distance_to(e.position) / p.BULLET_SPEED) - p.position
			var dir := to.normalized()
			want = Vector2(-wrapf(atan2(-dir.x, -dir.z) - p.aim_yaw, -PI, PI), -(asin(clampf(dir.y, -1.0, 1.0)) - p.aim_pitch)) * 2.2
			aimed = (-p.basis.z).angle_to(dir) < 0.3 and to.length() < 750.0
			if rocket_t < 0.0 and t > rocket_next and p.rockets_left > 0 and (-p.basis.z).angle_to(dir) < 0.4 and to.length() < 900.0:
				_touch(tc._center("rocket"), true, 3)
				rocket_t = 0.0
		if p.position.y - Terrain.height(p.position.x, p.position.z) < 110.0:
			want.y = -1.0
		want = want.limit_length(1.0)
		var at := base + want * 70.0
		_drag(at, at - last, 2)
		last = at
		var far: bool = e != null and p.position.distance_to(e.position) > 550.0 and p.boost > 0.3
		if far != boost:
			boost = far
			_touch(tc._center("boost"), boost, 6)
		if aimed != fire:
			fire = aimed
			_touch(tc._center("fire"), fire, 1)
		if rocket_t >= 0.0:
			rocket_t += 1.0 / 30.0
			if p.lock or rocket_t > 2.5:
				_touch(tc._center("rocket"), false, 3)
				rocket_t = -1.0
				rocket_next = t + 2.5
		var k: int = main.gs.players.get(_me(), {}).get("kills", 0)
		if k > kills:
			kills = k
			_mark("kill %d" % minf(prev, 99999.0))
			if kill_t < 0.0 and prev < 450.0:
				kill_t = t
	for f in [1, 2, 3, 6]:
		if dots.has(f):
			_touch(dots[f], false, f)


# Hold TAUNT and slide up: the wheel picks "Catch me if you can!", letting go skywrites it.
func _taunt() -> void:
	var at: Vector2 = tc._center("taunt")
	_touch(at, true, 4)
	await _wait(0.5)
	for i in 6:
		_drag(at + Vector2(0, -12 * (i + 1)), Vector2(0, -10), 4)
		await _wait(0.05)
	await _wait(0.6)
	_touch(at + Vector2(0, -72), false, 4)


func _battle(world: int, mode: int, size: int, skill: int, plane := "") -> void:
	main.solo_battle()
	await _wait(0.3)
	if plane:
		main.plane_choice = plane
		main.request_plane(plane)
	main.request_world(world)
	main.request_battle(size, skill)
	await _wait(1.5)
	main.request_mode(mode)
	await _wait(0.3)
	main.request_start()
	while main._plane(1) == null:
		await process_frame


func _settings(name: String, livery: int, banner: int, killfx: int) -> void:
	Settings.values = Settings.DEFAULTS.duplicate(true)
	Settings.values.matches = 20 # past the first-match tutorial cards
	Settings.values.name = name
	Settings.values.livery = livery
	Settings.values.banner = banner
	Settings.values.killfx = killfx
	Settings.save()


func _initialize() -> void:
	Engine.max_fps = 30 # real time, so two networked recordings keep pace with each other
	var dl := CanvasLayer.new()
	dl.layer = 100
	root.add_child(dl)
	dots_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	dots_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots_ui.draw.connect(func():
		for f in dots:
			dots_ui.draw_circle(dots[f], 24.0, Color(1, 1, 1, 0.35))
			dots_ui.draw_arc(dots[f], 24.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0, true))
	dl.add_child(dots_ui)
	_mark("begin")
	match OS.get_cmdline_user_args()[-1]:
		"review": await review()
		"host": await host()
		"join": await join()
		"preview1": await preview1()
		"preview2": await preview2()
	_mark("end")
	await _wait(0.2)
	quit()


func review() -> void:
	_settings("Ace", 0, 0, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fake_store.cfg")) # nothing bought yet
	await _fresh()
	_cap("1. Launch: the main menu")
	await _wait(3.0)
	_cap("2. BATTLE VS AI: an offline match against computer pilots")
	await _tap(_btn("BATTLE VS AI"))
	await _wait(1.5)
	_cap("Mission setup: pick the world, mode, squadron size, enemy skill and plane")
	await _tap(main.world_sel.next)
	await _wait(1.0)
	await _tap(main.size_sel.next)
	await _wait(0.6)
	while main.skill_sel.index > 0:
		await _tap(main.skill_sel.prev)
	await _wait(1.2)
	_cap("Tap LAUNCH")
	await _tap(main.start_btn)
	_cap("Each match opens with a mission card, then the touch controls card")
	await _wait(6.0)
	_cap("Left thumb: drag anywhere on the left half to steer")
	await _fly(6.0, false)
	_cap("Hold FIRE for the guns, hold ROCKET until LOCK and let go to fire")
	await _fly(30.0, true, 2.5)
	if kills > 0:
		_cap("Enemy plane shot down")
		await _fly(3.0)
	_cap("3. Pause: the II button, top left")
	await _press("pause")
	await _wait(2.0)
	_cap("LEAVE GAME goes back to the main menu")
	await _tap(_btn("LEAVE GAME"))
	await _reloaded()
	await _wait(1.0)
	_cap("4. HANGAR SHOP: cosmetic looks only, each a one-time purchase")
	await _tap(_btn("HANGAR SHOP"))
	await _wait(2.0)
	var sh: Control = main.shop_ui
	_cap("SETS, with the price on each (a test store here; on iPhone, Apple's local prices)")
	for i in 3:
		await _tap(sh.item_sel.next)
		await _wait(1.1)
	_cap("PAINT JOBS")
	await _tap(sh.cat_sel.next)
	await _wait(1.3)
	await _tap(sh.item_sel.next)
	await _wait(1.3)
	_cap("SMOKE TRAILS")
	await _tap(sh.cat_sel.next)
	await _wait(1.3)
	await _tap(sh.item_sel.next)
	await _wait(1.3)
	_cap("KILL EFFECTS: they play beside the plane")
	await _tap(sh.cat_sel.next)
	await _wait(3.0)
	_cap("Back to SETS: the Neon Night Set")
	await _tap(sh.cat_sel.next)
	while sh.item_sel.index != 2:
		await _tap(sh.item_sel.next)
	await _wait(1.5)
	_cap("TRY IT FREE IN FREE FLIGHT: fly the look before buying")
	await _tap(sh.try_btn)
	while main._plane(1) == null:
		await process_frame
	await _wait(1.0)
	_cap("Free Flight wearing the Neon Night paint and trail, for free")
	await _fly(9.0, false)
	_cap("Pause > LEAVE GAME: the shop reopens on the item you tried")
	await _press("pause")
	await _wait(1.2)
	await _tap(_btn("LEAVE GAME"))
	await _reloaded()
	sh = main.shop_ui
	await _wait(2.0)
	_cap("BUY: on iPhone Apple's purchase sheet confirms it (test store in this recording)")
	await _tap(sh.buy_btn)
	await _wait(2.5)
	_cap("Bought: the set shows OWNED and can be equipped")
	await _wait(1.0)
	await _tap(sh.equip_btn)
	await _wait(2.0)
	_cap("RESTORE PURCHASES brings back everything bought with your Apple ID")
	await _tap(sh.restore_btn)
	await _wait(3.0)
	_cap("5. Multiplayer: two devices")
	await _tap(_btn("BACK"))
	await _wait(1.5)


func host() -> void:
	await _fresh()
	Settings.values.matches = 20
	main.name_edit.text = "Ava"
	_cap("Device A: MULTIPLAYER > HOST ON LAN opens a lobby")
	await _wait(1.5)
	await _tap(_btn("MULTIPLAYER"))
	await _wait(2.0)
	await _tap(_btn("HOST ON LAN"))
	print("HOSTING")
	await _until(func(): return main.gs.players.size() >= 2)
	_mark("joined")
	_cap("Both pilots are in the same lobby (SQUADRONS, top right)")
	await _wait(2.5)
	_cap("The host picks the mode (Team Dogfight) and taps LAUNCH")
	while main.mode_sel.index != 1:
		await _tap(main.mode_sel.next)
	await _wait(2.0)
	await _tap(main.start_btn)
	_mark("sync")
	_cap("Same match on both devices: A flies Blue, B flies Red")
	await _wait(8.0)
	_cap("They fight each other live; each screen shows the other's plane")
	await _fly(10.0)


func join() -> void:
	await _fresh()
	Settings.values.matches = 20
	Settings.values.player_id = "videoclient" # its own identity (both share one settings file)
	main.name_edit.text = "Ben"
	await _wait(2.5)
	await _tap(_btn("MULTIPLAYER"))
	await _wait(1.5)
	_cap("Device B: MULTIPLAYER > JOIN A FRIEND with the host's LAN address (same Wi-Fi)")
	await _tap(main.address)
	for ch in "127.0.0.1":
		main.address.text += ch
		await _wait(0.12)
	await _wait(0.5)
	_cap("Online rooms work the same way: HOST ONLINE shows a 5-character code to type here")
	await _tap(_btn("JOIN"))
	await _until(func(): return main.gs.phase == "playing")
	_mark("sync")
	await _wait(8.0)
	await _fly(11.0)


func preview1() -> void:
	_settings("Ace", 1, 7, 1)
	Settings.values.autofire = true # Settings > Touch controls: fires when the lead ring is on target
	Settings.save()
	var cfg := ConfigFile.new() # the test store owns the Golden Ace set: gold paint, gold trail, fireworks
	cfg.set_value("store", "owned", {"bundle.golden": true})
	cfg.save("user://fake_store.cfg")
	await _fresh()
	await _battle(1, 3, 1, 0, "fighter")
	await _wait(12.0) # mission + controls cards
	_mark("in")
	await _fly(12.0)
	await _fly(90.0, true, 2.0) # until a kill close enough to see
	await _fly(1.5, false)
	await _taunt()
	await _fly(4.0, false) # level, so the skywriting stays in view
	_mark("out")


func preview2() -> void:
	_settings("", 1, 7, 1) # bots read the same file: no name, so they pick their own
	var cfg := ConfigFile.new()
	cfg.set_value("store", "owned", {"bundle.golden": true})
	cfg.save("user://fake_store.cfg")
	await _fresh()
	for w in [2, 4, 5]:
		main.name_edit.text = "Ace"
		await _battle(w, 3, 1, 0)
		await _wait(12.0)
		_mark("in")
		await _fly(4.5)
		_mark("out")
		main._leave()
		await _reloaded()
	main.name_edit.text = "Ace"
	await _tap(_btn("MULTIPLAYER"))
	await _tap(_btn("HOST ON LAN"))
	print("HOSTING")
	await _until(func(): return main.gs.players.size() >= 3)
	main.request_mode(1)
	await _wait(1.0)
	_mark("in")
	await _wait(2.5)
	await _tap(main.start_btn)
	_mark("out")
	await _wait(12.0)
	_mark("in")
	await _fly(6.0)
	_mark("out")
	main._leave()
	await _reloaded()
	main.shop_ui.open("bundle.golden")
	await _wait(1.0)
	_mark("in")
	for i in 2:
		await _wait(1.8)
		await _tap(main.shop_ui.item_sel.next)
	await _wait(1.8)
	_mark("out")
