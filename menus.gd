class_name Menus
extends RefCounted

# Shared UI look (Kenney Future font, CC0) and the settings / how-to panels.
const NAVY := Color(0.07, 0.11, 0.2, 0.94)
const AMBER := Color(1.0, 0.74, 0.22)
const BLUE := Color(0.16, 0.3, 0.52)


static func theme() -> Theme:
	var t := Theme.new()
	var display := preload("res://assets/ui/kenney_future_narrow.ttf")
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_font("font", type, display)
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box(NAVY, AMBER, 2, 18))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg: Color = {normal = BLUE, hover = BLUE.lightened(0.2), pressed = AMBER.darkened(0.2), focus = BLUE.lightened(0.1), disabled = BLUE.darkened(0.4)}[state]
		var sb := _box(bg, AMBER if state == "focus" else bg.lightened(0.15), 2, 8)
		t.set_stylebox(state, "Button", sb)
		t.set_stylebox(state, "OptionButton", sb)
	# Keyboard focus: a thick amber outline over whatever the control normally looks like.
	var ring := _box(Color(0, 0, 0, 0), AMBER, 3, 8)
	ring.draw_center = false
	for type in ["Button", "OptionButton", "CheckButton", "HSlider", "LineEdit"]:
		t.set_stylebox("focus", type, ring)
	t.set_color("font_focus_color", "Button", AMBER)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_stylebox("fill", "ProgressBar", _box(AMBER, AMBER, 0, 0))
	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 0, 0))
	t.set_color("font_pressed_color", "Button", NAVY)
	t.set_stylebox("normal", "LineEdit", _box(Color(0, 0, 0, 0.35), BLUE.lightened(0.3), 1, 8))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0.35), AMBER, 2, 8))
	t.set_color("font_color", "Label", Color(0.92, 0.94, 1.0))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("outline_size", "Label", 4)
	return t


# Menus behave like a game's: W/A/S/D work everywhere the arrow keys do.
static func bind_wasd() -> void:
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
		var e := InputEventKey.new()
		e.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], e):
			InputMap.action_add_event(pair[0], e)


# Dark full-height strip the big menus sit on, so text reads over the live 3D world behind.
static func side_panel(ui: Control, box: VBoxContainer, width := 560.0, right := false, footer: Control = null) -> Control:
	var phone := TouchControls.phone()
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.72)
	sb.set_content_margin_all(28 if phone else 48)
	sb.content_margin_top = 20 if phone else 32
	var ins := insets(ui) # keep text clear of the notch / Dynamic Island (and the home bar)
	var inset := maxf(ins.x, ins.z)
	if phone:
		sb.content_margin_bottom = maxf(28.0, ins.w + 8.0)
	if right:
		sb.content_margin_right += inset
	else:
		sb.content_margin_left += inset
	root.add_theme_stylebox_override("panel", sb)
	root.set_anchors_preset(Control.PRESET_RIGHT_WIDE if right else Control.PRESET_LEFT_WIDE)
	root.custom_minimum_size.x = width + inset
	if right:
		root.offset_left = -width - inset
	box.add_theme_constant_override("separation", 4 if phone else 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Control = box
	if not phone: # scrolls only when it doesn't fit; phone screens are laid out to fit
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		scroll.add_child(box)
		body = scroll
	if footer: # stays put under the scrolling part (the lobby's LAUNCH)
		var col := VBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(body)
		col.add_child(footer)
		root.add_child(col)
	else:
		root.add_child(body)
	ui.add_child(root)
	thumbs(root)
	return root


# Phones: every button and text field at least 44 pt (68 units) square.
static func thumbs(n: Node) -> void:
	if TouchControls.phone():
		for c in n.find_children("*", "", true, false):
			if c is BaseButton or c is LineEdit:
				c.custom_minimum_size = c.custom_minimum_size.max(Vector2(68, 68))


static func big_title(box: VBoxContainer, text: String, size := 64) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.2))
	l.add_theme_constant_override("outline_size", 14)
	box.add_child(l)
	return l


# A menu entry the way games do it: big text, no button box; the selected one glows amber with a bar.
static func menu_item(box: Container, text: String, cb: Callable, host: Node, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	b.add_theme_font_size_override("font_size", size)
	var idle := StyleBoxEmpty.new()
	idle.content_margin_left = 20
	idle.content_margin_top = 6
	idle.content_margin_bottom = 6
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(AMBER, 0.14)
	lit.border_color = AMBER
	lit.border_width_left = 6
	lit.content_margin_left = 20
	lit.content_margin_top = 6
	lit.content_margin_bottom = 6
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, idle)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, lit)
	b.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 0.85))
	for st in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, AMBER)
	b.mouse_entered.connect(b.grab_focus) # mouse and keyboard share one highlight
	b.focus_entered.connect(func(): Sfx.ui(host, Sfx.CLICK, -18.0, 1.4))
	b.pressed.connect(func(): Sfx.ui(host, Sfx.CONFIRM, -8.0))
	b.pressed.connect(cb)
	box.add_child(b)
	return b


# Phone screens: a boxed, thumb-sized button (FOCUS_NONE: a held focus swallows taps).
static func tile(box: Control, text: String, cb: Callable, host: Node, size := 18, min_size := Vector2(68, 68)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func(): Sfx.ui(host, Sfx.CONFIRM, -8.0))
	b.pressed.connect(cb)
	box.add_child(b)
	return b


# The picked tile of a row (and PLAY / LAUNCH) is solid amber; the rest dark glass.
static func lit(b: Button, on: bool) -> void:
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, _box(AMBER if on else Color(0.05, 0.08, 0.16, 0.72), AMBER.lightened(0.3) if on else Color(1, 1, 1, 0.18), 2, 8))
	for st in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(st, NAVY if on else Color(0.92, 0.94, 1.0))


# Notch, rounded corners and home bar in UI units (x left, y top, z right, w bottom). Tests fake it with meta "test_insets".
static func insets(_ui: Control) -> Vector4:
	if Engine.has_meta("test_insets"):
		return Engine.get_meta("test_insets")
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or scr.x <= 0:
		return Vector4.ZERO
	return Vector4(safe.position.x, safe.position.y, scr.x - safe.end.x, scr.y - safe.end.y) * (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size.x / scr.x


# Game-menu row: small header, < value >, optional picture. W/S (or up/down) moves between rows,
# A/D (or left/right) and the arrows change the value. Locked rows only show it (non-leaders).
class Selector extends PanelContainer:
	signal changed(i: int)
	var items: Array = [] # [{title, sub, pic}]
	var index := 0
	var locked := false
	var title := Label.new()
	var sub := Label.new()
	var pic: TextureRect # only rows with pictures get one
	var count := Label.new()
	var prev := Button.new()
	var next := Button.new()

	func _init(header: String, entries: Array, pic_size := Vector2.ZERO) -> void:
		items = entries
		focus_mode = Control.FOCUS_ALL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var head := Label.new()
		head.text = header
		head.add_theme_font_size_override("font_size", 13)
		head.modulate = Color(1, 1, 1, 0.55)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(head)
		count.add_theme_font_size_override("font_size", 13)
		count.modulate = Color(1, 1, 1, 0.55)
		top.add_child(count)
		var row := HBoxContainer.new()
		v.add_child(row)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		for b: Button in [prev, next]:
			b.focus_mode = Control.FOCUS_NONE
			b.flat = true
			b.custom_minimum_size = Vector2(68, 68) if TouchControls.phone() else Vector2(34, 34)
			b.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
			b.add_theme_font_size_override("font_size", 28)
			b.add_theme_color_override("font_color", Menus.AMBER)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
		prev.draw.connect(_arrow.bind(prev, -1.0)) # drawn triangles: the display font has no arrow glyphs
		next.draw.connect(_arrow.bind(next, 1.0))
		prev.pressed.connect(step.bind(-1))
		next.pressed.connect(step.bind(1))
		row.add_child(prev)
		row.add_child(mid)
		row.add_child(next)
		if pic_size != Vector2.ZERO:
			pic = TextureRect.new()
			pic.custom_minimum_size = pic_size
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			mid.add_child(pic)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", preload("res://assets/ui/kenney_future.ttf"))
		title.add_theme_font_size_override("font_size", 18 if TouchControls.phone() else 22)
		mid.add_child(title)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD
		sub.add_theme_font_size_override("font_size", 14)
		sub.modulate = Color(1, 1, 1, 0.75)
		mid.add_child(sub)
		focus_entered.connect(_style.bind(true))
		focus_exited.connect(_style.bind(false))
		mouse_entered.connect(grab_focus)
		_style(false)
		_show()

	func _arrow(b: Button, dir: float) -> void:
		var c := b.size / 2.0
		var col := Color.WHITE if b.is_hovered() else Menus.AMBER
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(9 * dir, 0), c + Vector2(-7 * dir, -11), c + Vector2(-7 * dir, 11)]), col)

	func _style(on: bool) -> void:
		add_theme_stylebox_override("panel", Menus._box(Color(0.12, 0.18, 0.32, 0.92) if on else Color(0.05, 0.08, 0.16, 0.7),
			Menus.AMBER if on else Color(1, 1, 1, 0.1), 3 if on else 1, 4 if TouchControls.phone() else 10))

	func set_index(i: int) -> void:
		if i != index:
			index = clampi(i, 0, items.size() - 1)
			_show()

	func set_items(entries: Array) -> void:
		items = entries
		index = clampi(index, 0, items.size() - 1)
		_show()

	func set_locked(on: bool) -> void:
		locked = on
		for b: Button in [prev, next]:
			b.disabled = on
			b.modulate.a = 0.0 if on else 1.0

	func step(d: int) -> void:
		if locked or items.size() < 2:
			return
		index = wrapi(index + d, 0, items.size())
		_show()
		Sfx.ui(self, Sfx.CLICK, -10.0, 1.2)
		changed.emit(index)

	func _gui_input(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left", true):
			step(-1)
			accept_event()
		elif e.is_action_pressed("ui_right", true):
			step(1)
			accept_event()

	func _show() -> void:
		var it: Dictionary = items[index]
		title.text = it.title
		sub.text = it.get("sub", "")
		sub.visible = sub.text != ""
		if pic:
			pic.texture = it.get("pic")
		count.text = "%d / %d" % [index + 1, items.size()] if items.size() > 2 else ""


static func _box(bg: Color, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(pad)
	return sb


const PRIVACY_URL := "https://github.com/SumantxD/toy-plane-sim/blob/main/PRIVACY.md"


static func settings_panel(tree: SceneTree, on_close: Callable, on_touch := Callable()) -> VBoxContainer:
	var box := VBoxContainer.new()
	var v := Settings.values
	_slider(box, "Volume", 0.0, 1.0, v.volume, func(x): v.volume = x; Settings.apply(tree))
	var touch := TouchControls.on()
	_slider(box, "Steering sensitivity" if touch else "Mouse sensitivity", 0.2, 3.0, v.sensitivity, func(x): v.sensitivity = x)
	var grid := columns(box)
	_check(grid, "Invert steering up/down" if touch else "Invert mouse Y", v.invert_y, func(on): v.invert_y = on)
	if not TouchControls.phone():
		_check(grid, "Fullscreen", v.fullscreen, func(on): v.fullscreen = on; Settings.apply(tree))
	_check(grid, "High graphics (shadows, anti-aliasing)", v.quality == 1, func(on): v.quality = int(on); Settings.apply(tree))
	_check(grid, "Show other players' taunt bubbles", v.get("taunts", true), func(on): v.taunts = on)
	_check(grid, "Show smoke trails", v.get("trails", true), func(on): v.trails = on)
	if on_touch.is_valid():
		var tb := Button.new()
		tb.text = "Touch controls..."
		tb.pressed.connect(on_touch)
		grid.add_child(tb)
	var privacy := Button.new()
	privacy.text = "Privacy policy"
	privacy.pressed.connect(func(): OS.shell_open(PRIVACY_URL))
	grid.add_child(privacy)
	var report := Label.new()
	report.text = "Report a player: st72365@gmail.com"
	report.modulate = Color(1, 1, 1, 0.6)
	box.add_child(report)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(func():
		Settings.save()
		on_close.call())
	grid.add_child(done)
	return box


# Phones: switches and buttons two to a row, so a settings screen fits without scrolling (else the box itself).
static func columns(box: VBoxContainer) -> Container:
	if not TouchControls.phone():
		return box
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	return grid


static func howto_text() -> String:
	if TouchControls.on(): # one line per point: the phone panel wraps them
		return """[b]FLYING[/b]
Drag anywhere away from the buttons to steer; the plane follows.
Slide the throttle bar up / down for fast / slow. Hold BOOST for a burst of speed. Too slow = stall, nose drops.

[b]FIGHTING[/b]
Hold FIRE: guns. Red circles show where to lead your shots.
Hold ROCKET with an enemy ahead: your plane follows it on its own and locks on (LOCKING -> LOCK); let go to fire and the rocket chases it. Steer any time to take over; a sharp dodge shakes the follow off. A quick tap fires at whatever is ahead.
LOCKED ON means someone is locking you. MISSILE! means one is chasing you: tap FLARE (flares break the lock of rockets already fired), or turn hard and BOOST.
Hold BOMB to see where a bomb will land, let go to drop. Bombs wreck HQs and defenses.
II = pause menu.  CAM = camera near / normal / far.  Hold TAUNT and slide to pick a message; tap a second finger for more messages.

[b]DAMAGE[/b]
A hit wing pulls you to that side, a hit engine sputters (dead = glide), a hit tail makes turns sluggish. Crashing into ground or buildings kills you.

[b]TEAMWORK[/b]
Shot down? Teammates fly through your orange beacon within 15 s to revive you. Lives are shared by the team.
TEAM: call "Help!" or "On me".  MAP: minimap on / zoomed / off.

[b]MODES[/b]
Co-op Escort: get 2 of 3 bombers to the factory through 8 raider waves.
Team Dogfight (multiplayer): run the other team out of lives.
Free Flight: practice, pop balloons, no rules.
Team Battle vs AI: your team plus AI wingmen against an AI squadron.
Capture the Flag: fly through the enemy flag's beam, bring it home while yours is safe. First to 3 wins (8 min). Shoot down a carrier to drop it; touch your dropped flag to return it.
Base Assault: wear down the enemy HQ with strafing runs; bomber raids launch for both sides. Destroy it to win (10 min, else the healthier HQ wins). BUY > FIX HQ repairs yours (2 supplies).

[b]SUPPLIES[/b]
Fly through a crate: repair + rockets, and you carry the cargo. Get it home for +1 team supply (shot down = it drops for anyone). BUY spends them on defenses: AA GUN, SAM (2), RADAR.

[b]WORLDS[/b] (leader picks in the lobby)
Green Valley: open skies.  Volcanic Islands: thermals lift you, lava bombs rain down.  Frozen Frontier: gusting wind and blinding snowstorms.  Desert Wasteland: canyon runs, crosswind, sandstorms.  Neon Metropolis: skyscraper corridors, lightning.  Sky Kingdom: floating islands you can fly under, air currents - and don't touch the cloud sea.
Everywhere: supply crates, AA guns at airfields and the factory (CTF / Assault: only bought ones).

[b]PLAYING WITH FRIENDS[/b]
The host taps HOST ONLINE and sends the 5-letter room code; friends type it under JOIN A FRIEND.
On one Wi-Fi, HOST ON LAN works too: join with the address shown in the host's lobby.
If iOS asks for Local Network access, tap Allow (or turn it on in Settings > Privacy & Security > Local Network). If a code won't connect, put both devices on the same Wi-Fi.

[b]TOUCH CONTROLS[/b]
Settings > Touch controls: tilt to steer, auto-fire, vibration, left-handed, fixed stick, button opacity, and Customize layout to move and resize every button."""
	return """[b]FLYING[/b]
  Mouse aims, the plane follows.  W / S throttle,  Shift boost.
  Arrows + Q / E fly manually.  Too slow = stall, nose drops.

[b]FIGHTING[/b]
  Left click / Space: guns. Red circles show where to lead your shots.
  Hold right click / F to aim a rocket (lock box, or a dotted path), release to fire.
  Rockets need a lock: keep the target in the box until it closes (LOCKING -> LOCK).
  LOCKED ON means someone is locking you. MISSILE! means one is chasing you: X pops flares
  (they break the lock of rockets already fired), or turn hard and boost.
  Hold B to see where a bomb will land, release to drop. Bombs wreck HQs and defenses.
  C = camera near / normal / far.  Hold T = taunt wheel (mouse picks, scroll = more, release sends).  H = show / hide the controls card.

[b]DAMAGE[/b]
  A hit wing pulls you to that side, a hit engine sputters (dead = glide),
  a hit tail makes turns sluggish. Crashing into ground or buildings kills you.

[b]TEAMWORK[/b]
  Shot down? Teammates fly through your orange beacon within 15 s to revive you.
  1 = "Help!",  2 = "On me".  Lives are shared by the team.  M = minimap on/off, N = zoom it.

[b]MODES[/b]
  Co-op Escort: get 2 of 3 bombers to the factory through 8 raider waves.
  Team Dogfight: run the other team out of lives.
  Free Flight: practice, pop balloons, no rules.
  Team Battle vs AI: your team plus AI wingmen against an AI squadron.
  Capture the Flag: fly through the enemy flag's beam, bring it home while yours is safe.
    First to 3 wins (8 min). Shoot down a carrier to drop it; touch your dropped flag to return it.
  Base Assault: wear down the enemy HQ with strafing runs; bomber raids launch for both sides.
    Destroy it to win (10 min, else the healthier HQ wins). 6 = repair your HQ (2 supplies).

[b]SUPPLIES[/b]
  Fly through a crate: repair + rockets, and you carry the cargo. Get it home for +1 team
  supply (shot down = it drops for anyone). Supplies buy defenses: 3 AA gun, 4 SAM (2), 5 Radar.

[b]MENUS BY KEYBOARD[/b]
  Arrows / Tab move, Enter or Space press, Left / Right adjust sliders, Esc goes back.

[b]WORLDS[/b] (leader picks in the lobby)
  Green Valley: open skies.  Volcanic Islands: thermals lift you, lava bombs rain down.
  Frozen Frontier: gusting wind and blinding snowstorms.  Desert Wasteland: canyon runs,
  crosswind, sandstorms.  Neon Metropolis: skyscraper corridors, lightning.  Sky Kingdom:
  floating islands you can fly under, air currents - and don't touch the cloud sea.
  Everywhere: supply crates, AA guns at airfields and the factory (CTF / Assault: only bought ones).

[b]INTERNET TIPS[/b]
  Host clicks "Host online" and sends the 5-letter room code. Everyone must click Allow
  on the firewall prompt the first time. If a code still won't connect (very strict mobile
  networks), install Tailscale (free), have the host share their computer, click "Host on LAN",
  and join with the host's Tailscale address (100.x.x.x). Or add a free TURN relay (e.g. metered.ca):
  put turn_urls, turn_username and turn_credential in settings.cfg (Toy Plane Arcade's user folder)."""


static func credits_text() -> String:
	return """[b]Toy Plane Arcade[/b]  v%s
Made with Claude Code and the Godot Engine.

[b]Engine[/b]  Godot Engine (MIT license), godotengine.org
[b]Networking[/b]  webrtc-native (MIT) with libdatachannel and libjuice (MPL-2.0),
  usrsctp and libsrtp (BSD-3), mbedTLS (Apache-2.0), plog (MIT);
  godot-mqtt by goatchurchprime (MIT); godot-storekit by araid80 (MIT, iPhone purchases); public MQTT brokers HiveMQ, EMQX, Mosquitto;
  STUN by Google and Cloudflare.
[b]3D models, sounds, font[/b]  Kenney (kenney.nl), CC0: Nature Kit, Holiday Kit, City Kit Industrial,
  City Kit Suburban, Sci-Fi Sounds, Impact Sounds, Interface Sounds, UI Pack.
[b]Nature ambience[/b]  "Park Ambiences" (OpenGameArt), CC0.
[b]Toon shading[/b]  based on Flexible Toon Shader by John Wigg (CaptainProton42), Godot 4 port by atzuk4451 (MIT).
[b]Engine, wind, gun and beep sounds[/b]  synthesized for this game.

Full license texts: press Licenses below.""" % Engine.get_main_loop().current_scene.VERSION


# Phones: long text a page at a time, every page sized to fit (nothing scrolls); < PAGE x / N > turns them.
class Pager extends VBoxContainer:
	var label := RichTextLabel.new()
	var row := HBoxContainer.new()
	var count := Label.new()
	var nav: Array = [] # << < > >>
	var pages: Array = []
	var page := 0

	func _init(sz: Vector2, host: Node) -> void:
		label.custom_minimum_size = sz
		label.scroll_active = false
		add_child(label)
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		for it in [["<<", -10], ["<", -1], ["", 0], [">", 1], [">>", 10]]:
			if it[1] == 0:
				count.custom_minimum_size.x = 150
				count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(count)
				nav.append(count)
			else:
				nav.append(Menus.tile(row, it[0], turn.bind(it[1]), host, 20))

	func set_pages(list: Array, bbcode := true) -> void:
		pages = list
		label.bbcode_enabled = bbcode
		page = 0
		turn(0)

	func turn(d: int) -> void:
		page = clampi(page + d, 0, pages.size() - 1)
		label.text = pages[page]
		count.text = "PAGE %d / %d" % [page + 1, pages.size()]
		for i in nav.size():
			nav[i].visible = pages.size() > (10 if i in [0, 4] else 1) # << >> only for long texts


# Plain text cut into pages of `lines` lines, wrapped the way `font` at `size` fits `width`.
static func text_pages(text: String, font: Font, size: int, width: float, lines: int) -> Array:
	var out := PackedStringArray()
	var para := TextParagraph.new()
	para.width = width
	for src in text.split("\n"):
		para.clear()
		para.add_string(src, font, size)
		if para.get_line_count() == 0:
			out.append("")
		for i in para.get_line_count():
			var r := para.get_line_range(i)
			out.append(src.substr(r.x, r.y - r.x))
	var pages := []
	for i in range(0, out.size(), lines):
		pages.append("\n".join(out.slice(i, i + lines)))
	return pages


static func _slider(box: VBoxContainer, label: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 220
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	row.add_child(s)
	box.add_child(row)


static func _check(box: Container, label: String, on: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	if box is GridContainer:
		c.custom_minimum_size = Vector2(420, 68)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.button_pressed = on
	c.toggled.connect(cb)
	box.add_child(c)
