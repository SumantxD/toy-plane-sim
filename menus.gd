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


static func _box(bg: Color, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(pad)
	return sb


static func settings_panel(tree: SceneTree, on_close: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var v := Settings.values
	_slider(box, "Volume", 0.0, 1.0, v.volume, func(x): v.volume = x; Settings.apply(tree))
	_slider(box, "Mouse sensitivity", 0.2, 3.0, v.sensitivity, func(x): v.sensitivity = x)
	_check(box, "Invert mouse Y", v.invert_y, func(on): v.invert_y = on)
	_check(box, "Fullscreen", v.fullscreen, func(on): v.fullscreen = on; Settings.apply(tree))
	_check(box, "High graphics (shadows, anti-aliasing)", v.quality == 1, func(on): v.quality = int(on); Settings.apply(tree))
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(func():
		Settings.save()
		on_close.call())
	box.add_child(done)
	return box


static func howto_text() -> String:
	return """[b]FLYING[/b]
  Mouse aims, the plane follows.  W / S throttle,  Shift boost.
  Arrows + Q / E fly manually.  Too slow = stall, nose drops.

[b]FIGHTING[/b]
  Left click / Space: guns. Red circles show where to lead your shots.
  Hold right click / F to aim a rocket (lock box, or a dotted path), release to fire.
  MISSILE! means one is chasing you: turn hard or boost.

[b]DAMAGE[/b]
  A hit wing pulls you to that side, a hit engine sputters (dead = glide),
  a hit tail makes turns sluggish. Crashing into ground or buildings kills you.

[b]TEAMWORK[/b]
  Shot down? Teammates fly through your orange beacon within 15 s to revive you.
  1 = "Help!",  2 = "On me".  Lives are shared by the team.  M = minimap on/off.

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
  and join with the host's Tailscale address (100.x.x.x)."""


static func credits_text() -> String:
	return """[b]Toy Plane Sim[/b]  v%s
Made with Claude Code and the Godot Engine.

[b]Engine[/b]  Godot Engine (MIT license), godotengine.org
[b]Networking[/b]  webrtc-native (MIT) with libdatachannel and libjuice (MPL-2.0),
  usrsctp and libsrtp (BSD-3), mbedTLS (Apache-2.0), plog (MIT);
  godot-mqtt by goatchurchprime (MIT); public MQTT brokers HiveMQ, EMQX, Mosquitto;
  STUN by Google and Cloudflare.
[b]3D models, sounds, font[/b]  Kenney (kenney.nl), CC0: Nature Kit, Holiday Kit, City Kit Industrial,
  City Kit Suburban, Sci-Fi Sounds, Impact Sounds, Interface Sounds, UI Pack.
[b]Nature ambience[/b]  "Park Ambiences" (OpenGameArt), CC0.
[b]Toon shading[/b]  based on Flexible Toon Shader by atzuk4451 (MIT).
[b]Engine, wind, gun and beep sounds[/b]  synthesized for this game.

Full license texts: THIRD_PARTY_LICENSES.txt next to the game.""" % Engine.get_main_loop().current_scene.VERSION


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


static func _check(box: VBoxContainer, label: String, on: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = on
	c.toggled.connect(cb)
	box.add_child(c)
