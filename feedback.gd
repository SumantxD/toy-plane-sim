class_name Feedback
extends RefCounted

# The local pilot's combat feedback, one visual language drawn on the plane HUD: hit marker + combo at the
# crosshair, SHOT DOWN / multi-takedown banners, AMBUSH / TAIL SHOT tags, badge and challenge toasts,
# arrows toward whoever is hurting you, and a low-HP edge glow. Timers only: idle costs nothing.
const FONT := preload("res://assets/ui/kenney_future.ttf")
const MULTI := ["", "", "DOUBLE TAKEDOWN!", "TRIPLE TAKEDOWN!"]
const MULTI_MS := 4000 # kills this close together chain
const LOW := 0.3 # of max hp
const RED := Color(1.0, 0.22, 0.18)

var plane: Node
var hit_t := 0.0
var hit_heavy := false
var combo_t := 0.0
var banner := ""
var banner_col := Color.WHITE
var banner_t := 0.0
var multi := ""
var multi_t := 0.0
var kill_n := 0
var kill_ms := -100000
var tag := ""
var tag_t := 0.0
var ambush_ms := -100000
var toast := ""
var toast_t := 0.0
var flash := Color.TRANSPARENT
var flash_t := 0.0
var hurt: Array = [] # [attacker position, seconds left], newest last, at most 3
var low := false
var edge_pts: Array = [] # 4 edge quads, rebuilt only when the screen size changes
var edge_size := Vector2.ZERO
var edge_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


func _init(p: Node) -> void:
	plane = p


func on_hit(weapon: int) -> void:
	hit_t = 0.18 if weapon == 0 else 0.3
	hit_heavy = weapon > 0
	combo_t = 1.6


func on_tag(t: String) -> void:
	tag = t
	tag_t = 0.9
	if t == "AMBUSH!":
		if Time.get_ticks_msec() - ambush_ms > 1000: # one ambush, however many rounds land in its window
			Progress.note("ambushes")
		ambush_ms = Time.get_ticks_msec()
		Sfx.ui(plane.main, Sfx.HEAVY_HITS.pick_random(), -2.0, 1.3)


func on_credit(kind: String, what: String) -> void:
	match kind:
		"kill":
			_banner("SHOT DOWN  " + what.to_upper(), Color.WHITE)
			hit_t = 0.35
			hit_heavy = true
			var now := Time.get_ticks_msec()
			kill_n = kill_n + 1 if now - kill_ms < MULTI_MS else 1
			kill_ms = now
			if kill_n >= 2:
				_multi()
		"destroy":
			_banner("DESTROYED  " + what.to_upper(), Color.WHITE)
		"assist":
			_banner("ASSIST  " + what.to_upper(), Color(0.75, 0.9, 1.0))
			Sfx.ui(plane.main, Sfx.PLUCK, -8.0, 1.2)
		"prize":
			_banner("PRIZE: " + what.to_upper(), Menus.AMBER)
		"dodge":
			_banner("MISSILE SHAKEN OFF!", Color(0.6, 1.0, 0.7))


# DOUBLE / TRIPLE TAKEDOWN: a beat of its own (edge flash, camera punch; a hint of slow motion when solo only).
func _multi() -> void:
	multi = MULTI[mini(kill_n, MULTI.size() - 1)] if kill_n < MULTI.size() else "%d TAKEDOWNS!" % kill_n
	multi_t = 2.0
	flash = Menus.AMBER
	flash_t = 0.45
	Progress.note("multi", kill_n)
	Sfx.ui(plane.main, Sfx.KILL, -2.0, 1.0 + 0.15 * kill_n)
	Sfx.ui(plane.main, Sfx.BELL, -8.0, 1.2)
	TouchControls.buzz(60)
	if plane.cam:
		plane.cam.fov += 7.0
		plane.shake = minf(plane.shake + 0.25, 1.0)
	var tree: SceneTree = plane.get_tree()
	if plane.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and Engine.time_scale == 1.0 and not plane.main.bot:
		Engine.time_scale = 0.35
		tree.create_timer(0.15, true, false, true).timeout.connect(func(): if Engine.time_scale == 0.35: Engine.time_scale = 1.0)


func on_hurt(from: Vector3) -> void:
	for h in hurt:
		if h[0].distance_squared_to(from) < 900.0: # same attacker: refresh, don't stack
			h[0] = from
			h[1] = 1.2
			return
	hurt.append([from, 1.2])
	if hurt.size() > 3:
		hurt.pop_front()


func _banner(text: String, col: Color) -> void:
	banner = text
	banner_col = col
	banner_t = 1.8
	plane.main.intro_t = minf(plane.main.intro_t, 0.4) # the match card makes way


func draw(hud: Control, cam: Camera3D, dt: float) -> void:
	var c := hud.size / 2.0
	if not Progress.events.is_empty() and toast_t <= 0.0:
		toast = Progress.events.pop_front()
		toast_t = 2.6
		Sfx.ui(plane.main, Sfx.CONFIRM, -6.0, 1.25)
	var was_low := low
	low = plane.alive and plane.hp < plane.max_hp * LOW
	if low and not was_low:
		Sfx.ui(plane.main, Sfx.WARN, -8.0, 0.6)
		TouchControls.buzz(80)
	if low:
		var k := 0.25 + 0.2 * sin(Time.get_ticks_msec() / 160.0)
		_edges(hud, Color(RED, k))
		_text(hud, Vector2(c.x, hud.size.y * 0.66), "LOW HP", 22, Color(RED, 0.6 + k))
	if flash_t > 0.0:
		flash_t -= dt
		_edges(hud, Color(flash, 0.5 * flash_t / 0.45))
	if hit_t > 0.0: # hit marker: four ticks around the crosshair
		hit_t -= dt
		var col := (Menus.AMBER if hit_heavy else Color.WHITE) * Color(1, 1, 1, minf(hit_t / 0.1, 1.0))
		var r0 := 18.0 if not hit_heavy else 20.0
		var r1 := r0 + (10.0 if not hit_heavy else 16.0)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			hud.draw_line(c + d * r0 * 0.7071, c + d * r1 * 0.7071, col, 3.0)
	if combo_t > 0.0:
		combo_t -= dt
		var n: int = Progress.cur.get("combo", 0)
		if n >= 3:
			var s := 18 + mini(n, 20) / 2
			hud.draw_string_outline(FONT, c + Vector2(34, 8), "%d HITS" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 6, Color(0, 0, 0, 0.7 * minf(combo_t, 1.0)))
			hud.draw_string(FONT, c + Vector2(34, 8), "%d HITS" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(Menus.AMBER if n >= 10 else Color.WHITE, minf(combo_t, 1.0)))
	if tag_t > 0.0:
		tag_t -= dt
		_text(hud, c + Vector2(0, -40), tag, 24 if tag == "AMBUSH!" else 18, (Menus.AMBER if tag == "AMBUSH!" else Color.WHITE) * Color(1, 1, 1, minf(tag_t / 0.3, 1.0)))
	if multi_t > 0.0:
		multi_t -= dt
		var pop := 1.0 + 0.25 * clampf((multi_t - 1.8) / 0.2, 0.0, 1.0)
		_text(hud, Vector2(c.x, hud.size.y * 0.2), multi, int(34 * pop), Menus.AMBER * Color(1, 1, 1, minf(multi_t / 0.4, 1.0)))
	if banner_t > 0.0:
		banner_t -= dt
		_text(hud, Vector2(c.x, hud.size.y * 0.27), banner, 26, banner_col * Color(1, 1, 1, minf(banner_t / 0.4, 1.0)))
	if toast_t > 0.0:
		toast_t -= dt
		_text(hud, Vector2(c.x, hud.size.y * 0.34), toast, 20, Color(0.6, 1.0, 0.7, minf(toast_t / 0.4, 1.0)), ThemeDB.fallback_font) # "XP": the display font's X reads as H
	for i in range(hurt.size() - 1, -1, -1):
		hurt[i][1] -= dt
		if hurt[i][1] <= 0.0:
			hurt.remove_at(i)
		elif plane.alive:
			_hurt_arrow(hud, cam, hurt[i][0], hurt[i][1])


# Red chevron on a ring around the crosshair, pointing at whoever hit you (behind = toward the bottom).
func _hurt_arrow(hud: Control, cam: Camera3D, at: Vector3, left: float) -> void:
	var local: Vector3 = cam.global_transform.basis.inverse() * (at - cam.global_position)
	var dir := Vector2(local.x, -local.y).normalized()
	if local.z > 0.0:
		dir = (dir * 0.5 + Vector2.DOWN).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var tip := hud.size / 2.0 + dir * minf(hud.size.x, hud.size.y) * 0.3
	var side := dir.orthogonal()
	var col := Color(RED, minf(left / 0.4, 1.0) * 0.9)
	hud.draw_colored_polygon(PackedVector2Array([tip + dir * 16.0, tip - dir * 10.0 + side * 24.0, tip, tip - dir * 10.0 - side * 24.0]), col)


# Glow along all four screen edges (low HP, multi-kill), fading toward the middle.
func _edges(hud: Control, col: Color) -> void:
	var s := hud.size
	if s != edge_size:
		edge_size = s
		var w := minf(s.x, s.y) * 0.12
		edge_pts = [PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x - w, w), Vector2(w, w)]),
			PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(w, s.y - w)]),
			PackedVector2Array([Vector2.ZERO, Vector2(0, s.y), Vector2(w, s.y - w), Vector2(w, w)]),
			PackedVector2Array([Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(s.x - w, w)])]
	edge_cols[0] = col
	edge_cols[1] = col
	edge_cols[2] = Color(col, 0.0)
	edge_cols[3] = Color(col, 0.0)
	for pts in edge_pts:
		hud.draw_polygon(pts, edge_cols)


# Centred, outlined display text.
func _text(hud: Control, at: Vector2, text: String, size: int, col: Color, font: Font = FONT) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(at.x - w / 2.0, at.y)
	hud.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0, 0, 0, 0.75 * col.a))
	hud.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
