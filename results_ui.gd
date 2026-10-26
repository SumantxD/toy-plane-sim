class_name ResultsUI
extends Control

# After a match: the outcome, your numbers against last match and your bests with one true observation,
# the XP it earned filling the level bar (a level-up shows what it unlocked), today's challenges, then
# PLAY AGAIN / HANGAR / HOME. Solo waits for your pick; online the host's REMATCH restarts the room,
# guests can ask for one, anyone can leave, and the room drops back to its lobby on its own.
const FONT := preload("res://assets/ui/kenney_future.ttf")
const ROWS := [["kills", "KILLS"], ["acc", "ACCURACY"], ["dmg", "DAMAGE"], ["life", "LONGEST FLIGHT"], ["ambush", "AMBUSHES"]]
var main: Node
var outcome := Label.new()
var sub := Label.new()
var tabs := {}
var you := HBoxContainer.new()
var scores := VBoxContainer.new()
var cells := {} # stat -> [now, last, best]
var observation := Label.new()
var badge := Control.new()
var lv_label := Label.new()
var title_label := Label.new()
var gain_label := Label.new()
var parts_label := Label.new()
var bar := ProgressBar.new()
var next_label := Label.new()
var up_label := Label.new()
var daily_rows: Array = []
var badges_label := Label.new()
var home_btn: Button
var hangar_btn: Button
var again_btn: Button
var again_word := Label.new()
var again_sub := Label.new()
var wait_label := Label.new()
var report := {}
var shown_lv := 1
var until_ms := 0
var voted := -1 # match id this guest asked for a rematch in


func _init(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var phone := TouchControls.phone()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var ins := Menus.insets(self)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = maxf(ins.x, 20.0) if phone else 48.0
	col.offset_right = -(maxf(ins.z, 20.0) if phone else 48.0)
	col.offset_top = maxf(ins.y, 12.0) if phone else 32.0
	col.offset_bottom = -(maxf(ins.w + 8.0, 16.0) if phone else 32.0)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", -2)
	head.add_child(hv)
	outcome.add_theme_font_override("font", FONT)
	outcome.add_theme_font_size_override("font_size", 44)
	outcome.add_theme_constant_override("outline_size", 12)
	hv.add_child(outcome)
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.8)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = 200
	hv.add_child(sub)
	for t in ["YOU", "SCORES"]:
		tabs[t] = Menus.tile(head, t, show_tab.bind(t), main, 16, Vector2(124, 68))
		tabs[t].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	you.size_flags_vertical = Control.SIZE_EXPAND_FILL
	you.add_theme_constant_override("separation", 12)
	col.add_child(you)
	scores.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scores.add_theme_constant_override("separation", 8)
	col.add_child(scores)
	_match_card(_card(you, "THIS MATCH"))
	_pilot_card(_card(you, "PILOT"))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	home_btn = Menus.icon_tile(foot, "HOME", "home", func(): main.results_home(), main, 16, Vector2(150, 76), true)
	hangar_btn = Menus.icon_tile(foot, "HANGAR", "plane", func(): main.results_hangar(), main, 16, Vector2(176, 76), true)
	for b: Button in [home_btn, hangar_btn]:
		b.size_flags_vertical = Control.SIZE_SHRINK_END
	wait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wait_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wait_label.custom_minimum_size.x = 120
	wait_label.add_theme_font_size_override("font_size", 14)
	wait_label.modulate = Color(1, 1, 1, 0.7)
	foot.add_child(wait_label)
	again_btn = Menus.tile(foot, "", func(): main.play_again(), main, 30, Vector2(340, 100))
	again_btn.name = "PlayAgain"
	Menus.lit(again_btn, true)
	if not phone:
		again_btn.focus_mode = Control.FOCUS_ALL # Enter plays again
	var pv := VBoxContainer.new()
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	pv.offset_left = 52
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	again_btn.add_child(pv)
	again_btn.draw.connect(func(): Menus.icon(again_btn, "play", Vector2(44, 50), 20, Menus.NAVY))
	again_word.add_theme_font_override("font", FONT)
	again_word.add_theme_font_size_override("font_size", 30)
	again_sub.add_theme_font_size_override("font_size", 13)
	again_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for lab: Label in [again_word, again_sub]:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", Menus.NAVY)
		lab.add_theme_constant_override("outline_size", 0)
		pv.add_child(lab)
	for c in find_children("*", "Control", true, false):
		if not c is BaseButton and c != dim:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_tab("YOU")
	hide()


func _card(parent: Control, title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Menus._box(Color(0.05, 0.08, 0.16, 0.85), Color(1, 1, 1, 0.16), 1, 14))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var h := Label.new()
	h.text = title
	h.add_theme_font_override("font", FONT)
	h.add_theme_font_size_override("font_size", 14)
	h.modulate = Color(1, 1, 1, 0.6)
	v.add_child(h)
	return v


func _match_card(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 2)
	v.add_child(g)
	for t in ["", "NOW", "LAST", "BEST"]:
		_cell(g, t, 13, Color(1, 1, 1, 0.5))
	for r in ROWS:
		_cell(g, r[1], 14, Color(1, 1, 1, 0.75)).custom_minimum_size.x = 150
		cells[r[0]] = [_cell(g, "", 20, Color.WHITE), _cell(g, "", 15, Color(1, 1, 1, 0.6)), _cell(g, "", 15, Color(1, 1, 1, 0.8))]
	observation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	observation.custom_minimum_size.x = 300
	observation.add_theme_font_size_override("font_size", 17)
	observation.add_theme_color_override("font_color", Menus.AMBER)
	v.add_child(observation)


func _cell(g: Control, text: String, size: int, col: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 70
	if display:
		l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.modulate = col
	g.add_child(l)
	return l


func _pilot_card(v: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	badge.custom_minimum_size = Vector2(56, 56)
	badge.pivot_offset = Vector2(28, 28)
	badge.draw.connect(func(): draw_level(badge, shown_lv))
	top.add_child(badge)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	lv_label.add_theme_font_override("font", FONT)
	lv_label.add_theme_font_size_override("font_size", 20)
	tv.add_child(lv_label)
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Menus.AMBER)
	tv.add_child(title_label)
	gain_label.add_theme_font_size_override("font_size", 26) # body font: the display font's X reads as H
	gain_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	gain_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(gain_label)
	parts_label.add_theme_font_size_override("font_size", 13)
	parts_label.modulate = Color(1, 1, 1, 0.7)
	v.add_child(parts_label)
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	v.add_child(bar)
	next_label.add_theme_font_size_override("font_size", 14)
	next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_label.custom_minimum_size.x = 200
	v.add_child(next_label)
	up_label.add_theme_font_override("font", FONT)
	up_label.add_theme_font_size_override("font_size", 16)
	up_label.add_theme_color_override("font_color", Menus.AMBER)
	up_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	up_label.custom_minimum_size.x = 300
	v.add_child(up_label)
	var dh := Label.new()
	dh.text = "TODAY'S CHALLENGES"
	dh.add_theme_font_override("font", FONT)
	dh.add_theme_font_size_override("font_size", 12)
	dh.modulate = Color(1, 1, 1, 0.55)
	v.add_child(dh)
	for i in 3:
		var row := HBoxContainer.new()
		v.add_child(row)
		var t := Label.new()
		t.add_theme_font_size_override("font_size", 14)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size.x = 160
		row.add_child(t)
		var p := Label.new()
		p.add_theme_font_override("font", FONT)
		p.add_theme_font_size_override("font_size", 14)
		row.add_child(p)
		daily_rows.append([t, p])
	badges_label.add_theme_font_size_override("font_size", 14)
	badges_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	badges_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badges_label.custom_minimum_size.x = 300
	v.add_child(badges_label)


# Round level badge: the number on amber.
static func draw_level(ci: Control, lv: int) -> void:
	var c := ci.size / 2.0
	var r := minf(c.x, c.y)
	ci.draw_circle(c, r, Menus.AMBER)
	ci.draw_arc(c, r - 4.0, 0, TAU, 32, Menus.NAVY, 2.0)
	var s := str(lv)
	var fs := 26 if lv < 10 else 22
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(FONT, c + Vector2(-w / 2.0, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Menus.NAVY)


func show_tab(t: String) -> void:
	you.visible = t == "YOU"
	scores.visible = t == "SCORES"
	for k in tabs:
		Menus.lit(tabs[k], k == t)


# A match just ended: `rep` is Progress.finish()'s report ({} for a spectator or a pilot who joined late).
func open(title: String, msg: String, rep: Dictionary) -> void:
	report = rep
	outcome.text = title
	outcome.add_theme_color_override("font_color", {"VICTORY": Color(0.55, 1.0, 0.6), "DEFEAT": Color(1.0, 0.45, 0.4)}.get(title, Color.WHITE))
	sub.text = msg
	until_ms = Time.get_ticks_msec() + int(main.RESULTS_WAIT * 1000.0)
	tabs.YOU.visible = not rep.is_empty()
	show_tab("YOU" if not rep.is_empty() else "SCORES")
	if rep.is_empty():
		return
	var st: Dictionary = rep.stats
	for k in cells:
		cells[k][0].text = _fmt(k, st[k])
		cells[k][1].text = _fmt(k, rep.last[k]) if rep.last.has(k) else "-"
		var nb: bool = k in rep.new_best
		cells[k][2].text = "NEW!" if nb else (_fmt(k, rep.best[k]) if rep.best.has(k) else "-")
		cells[k][2].add_theme_color_override("font_color", Menus.AMBER if nb else Color.WHITE)
	observation.text = rep.observation
	var gain: int = rep.xp1 - rep.xp0
	gain_label.text = "+%d XP" % gain
	parts_label.text = "  ·  ".join(rep.parts.map(func(p): return "%s %d" % p)) if rep.parts else "No XP: the match ended before a minute was up."
	badges_label.text = ("NEW BADGE: " + ", ".join(rep.badges.map(func(id): return Progress.badge(id).name.to_upper()))) if rep.badges else ""
	badges_label.visible = badges_label.text != ""
	up_label.hide()
	shown_lv = Progress.level_of(rep.xp0)
	_show_level(shown_lv, rep.xp1)
	bar.value = 100.0 * Progress.level_frac(rep.xp0)
	_fill_daily()
	var tw := create_tween()
	tw.tween_interval(0.5)
	var lv1 := Progress.level_of(rep.xp1)
	for lv in range(shown_lv + 1, lv1 + 1):
		tw.tween_property(bar, "value", 100.0, 0.5)
		tw.tween_callback(_level_up.bind(lv))
		tw.tween_property(bar, "value", 0.0, 0.0)
	tw.tween_property(bar, "value", 100.0 * Progress.level_frac(rep.xp1), 0.7)


func _show_level(lv: int, xp: int) -> void:
	shown_lv = lv
	lv_label.text = "LEVEL %d" % lv
	title_label.text = Progress.title(lv).to_upper()
	var nx := Progress.next_reward(lv)
	if lv >= Progress.MAX_LEVEL:
		next_label.text = "Top level: every reward unlocked."
	elif nx.is_empty():
		next_label.text = "%d XP to level %d" % [Progress.floor_xp(lv + 1) - xp, lv + 1]
	else:
		next_label.text = "Next: level %d unlocks the %s  (%d XP to go)" % [nx.lv, Progress.reward_name(nx.item), maxi(Progress.floor_xp(nx.lv) - xp, 0)]
	badge.queue_redraw()


# The level-up beat: the badge pops, a fanfare, and what it unlocked (waiting in the Hangar).
func _level_up(lv: int) -> void:
	_show_level(lv, report.xp1)
	var got := Progress.REWARDS.filter(func(r): return r.lv == lv).map(func(r): return Progress.reward_name(r.item))
	up_label.text = "LEVEL UP! %s" % ("Unlocked: %s. Wear it in the Hangar." % got[0] if got and not got[0].ends_with("title") else ("New title: %s." % Progress.title(lv).to_upper()))
	up_label.show()
	Sfx.ui(main, Sfx.FANFARE, -2.0)
	TouchControls.buzz(80)
	badge.scale = Vector2.ONE * 1.4
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_daily() -> void:
	var d := Progress.daily()
	for i in 3:
		var ch := Progress.challenge(d.ids[i])
		var done: bool = d.done.has(ch.id)
		daily_rows[i][0].text = ch.text
		daily_rows[i][1].text = "DONE" if done else "%d/%d" % [d.prog.get(ch.id, 0), ch.goal]
		daily_rows[i][1].add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if done else Color.WHITE)


static func _fmt(k: String, v: int) -> String:
	match k:
		"acc":
			return "-" if v < 0 else "%d%%" % v
		"life":
			return "%d:%02d" % [v / 60, v % 60]
	return str(v)


# Buttons for who you are: solo, the host of a room, or a guest in one.
func refresh() -> void:
	var solo: bool = main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	var host: bool = main.multiplayer.is_server()
	again_word.text = "PLAY AGAIN" if solo or not host else "REMATCH"
	var asked: int = main.gs.get("rematch", []).size()
	if solo:
		again_sub.text = "SAME MISSION"
	elif host:
		again_sub.text = "%d PILOT%s ASKED" % [asked, "" if asked == 1 else "S"] if asked else "EVERYONE FLIES AGAIN"
	else:
		again_word.text = "ASKED!" if voted == main.gs.match_id else "PLAY AGAIN"
		again_sub.text = "WAITING FOR THE HOST" if voted == main.gs.match_id else "ASK THE HOST FOR A REMATCH"
	hangar_btn.text = "HANGAR" if solo else "LOBBY"
	hangar_btn.visible = solo or host
	home_btn.text = "HOME" if solo else "LEAVE"


func _process(_dt: float) -> void:
	if not visible or main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		wait_label.text = ""
		return
	if Engine.get_process_frames() % 15 == 0:
		wait_label.text = "Back to the lobby in %d s" % maxi(ceili((until_ms - Time.get_ticks_msec()) / 1000.0), 0)
