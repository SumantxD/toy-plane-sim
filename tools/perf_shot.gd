extends Node

# Test hook (main.gd adds it for --shot <secs> <png>): prints render stats averaged over the last 3 s,
# saves a screenshot, quits. Extras:
#   --perf-off a,b,..  hide a subsystem to price it: shadows clouds water terrain props particles outline
#                      glow fog aa scale75 scale50 scale200 fsr bicubic planes
#   --perf-ab a,b,..   price each subsystem in one run, A/B against base windows (see _ab_tick)
#   --freeze           stop the scene for the last 4 s: the same still frame, for comparing builds
#   --stress           everything at once in front of the camera (booms, crashes, flak, confetti, kill
#                      effects, flares, skywriting, rockets, tracers) for the last 6 s
var secs := 10.0
var png := ""
var off: PackedStringArray = []
var stress := false
var freeze := false
var freeze_us := 0
var t := 0.0
var times: Array[float] = []
var last_us := 0
var main: Node
const AB_START := 8.0


func _ready() -> void:
	main = get_parent()
	var a := OS.get_cmdline_user_args()
	var i := a.find("--shot")
	secs = float(a[i + 1])
	png = a[i + 2]
	if a.find("--perf-off") >= 0:
		off = a[a.find("--perf-off") + 1].split(",")
	stress = "--stress" in a
	freeze = "--freeze" in a
	if a.find("--perf-ab") >= 0:
		ab = a[a.find("--perf-ab") + 1].split(",")
		secs = AB_START + AB_WIN * (ab.size() * 2 + 1) + 5.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(dt: float) -> void:
	t += dt
	Settings._late = 0.0 # keep the phone's dynamic resolution still: measure one fixed scale
	var now := Time.get_ticks_usec()
	if (t > secs - 3.0 or freeze_us > 0 and now - freeze_us > 1e6) and last_us > 0:
		times.append((now - last_us) / 1000.0)
	last_us = now
	if fmod(t, 0.25) < dt:
		_apply_off()
		if main.get("pause_root") and main.pause_root.visible: # --phone pauses when the off-screen window loses focus
			main.pause_root.hide()
	if not ab.is_empty() and t >= AB_START:
		_ab_tick()
	if stress and t > secs - 6.0 and fmod(t, 0.5) < dt:
		_stress()
	if freeze and t >= secs - 4.0 and freeze_us == 0: # --freeze: a still frame for the last 4 s (wall clock)
		freeze_us = now
		times.clear()
		Engine.time_scale = 0.0
	if freeze_us > 0 and now - freeze_us > 4e6 or freeze_us == 0 and t >= secs and ab.is_empty():
		Engine.time_scale = 1.0
		_report()


func _apply_off() -> void:
	for k in off:
		_hide(k, true)


# Hides (on) or restores (off) one subsystem.
func _hide(k: String, on: bool) -> void:
	var root := get_tree().root
	var vp := get_viewport()
	match k:
		"shadows":
			for l in get_tree().get_nodes_in_group("sun"):
				if on and l.shadow_enabled:
					l.set_meta("had_shadow", true)
				l.shadow_enabled = not on and l.get_meta("had_shadow", false)
		"clouds", "water", "terrain", "props":
			for n in root.find_children(k.capitalize(), "Node3D", true, false):
				n.visible = not on
		"particles":
			for n in root.find_children("*", "CPUParticles3D", true, false):
				n.visible = not on
		"outline":
			for n in root.find_children("*", "MeshInstance3D", true, false):
				if n.material_override is ShaderMaterial and n.material_override.shader and n.material_override.shader.resource_path.ends_with("outline.gdshader"):
					n.visible = not on
		"glow", "fog":
			for we in root.find_children("*", "WorldEnvironment", true, false):
				we.environment.set(k + "_enabled", not on)
		"aa":
			if on:
				set_meta("aa", [vp.msaa_3d, vp.screen_space_aa])
			var was: Array = get_meta("aa", [vp.msaa_3d, vp.screen_space_aa])
			vp.msaa_3d = Viewport.MSAA_DISABLED if on else was[0]
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if on else was[1]
		"scale75", "scale50", "scale200": # scale200 = 4x the pixels: makes a fast desktop GPU-bound like a phone
			vp.scaling_3d_scale = {"scale75": 0.75, "scale50": 0.5, "scale200": 2.0}[k] if on else 1.0
		"fsr": # with scale75: FSR 1 upscale instead of bilinear
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if on else Viewport.SCALING_3D_MODE_BILINEAR
		"bicubic": # glow upscale as iPhones do it (linear; desktop default is bicubic)
			RenderingServer.environment_glow_set_use_bicubic_upscale(not on)
		"planes":
			for p in main.players.get_children():
				p.visible = not on


# --perf-ab a,b,..: one run alternates base / a-off / base / b-off ... windows of AB_WIN s each and
# prints each subsystem's saving against the mean of its two neighbouring base windows (same clocks).
const AB_WIN := 4.0
var ab: PackedStringArray = []
var ab_ms: Array[float] = []
var ab_acc := [0.0, 0]
var ab_t0 := 0
var ab_w := 0
var ab_last := 0


func _ab_tick() -> void:
	if ab_t0 == 0:
		ab_t0 = Time.get_ticks_usec()
		Engine.time_scale = 0.0 # a frozen scene: windows differ only by the toggle
	var now := Time.get_ticks_usec()
	if (now - ab_t0) / 1e6 >= AB_WIN: # window ended: store, switch to the next
		ab_t0 = now
		var w := ab_w + 1
		ab_ms.append(ab_acc[0] / maxi(ab_acc[1], 1))
		ab_acc = [0.0, 0]
		if ab_w % 2 == 1:
			_hide(ab[ab_w / 2], false)
		ab_w = w
		if ab_ms.size() >= ab.size() * 2 + 1:
			for i in ab.size():
				var base := (ab_ms[i * 2] + ab_ms[i * 2 + 2]) / 2.0
				print("AB %-10s base %.2f ms  off %.2f ms  saves %.2f ms (%.0f%%)" % [ab[i], base, ab_ms[i * 2 + 1], base - ab_ms[i * 2 + 1], 100.0 * (base - ab_ms[i * 2 + 1]) / base])
			Engine.time_scale = 1.0
			_report()
			return
		if w % 2 == 1:
			_hide(ab[w / 2], true)
		ab_last = now
		return
	if (now - ab_t0) / 1e6 > 0.6 and ab_last > 0: # let the toggle settle
		ab_acc[0] += (now - ab_last) / 1000.0
		ab_acc[1] += 1
	ab_last = now


func _stress() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var at := cam.global_position + fwd * 160.0
	var me: Node = main.players.get_child(0) if main.players.get_child_count() > 0 else null
	for k in 3:
		main.boom(at + right * (k - 1) * 40.0, 1.0 + k * 0.6)
	for k in 4:
		Fx.flak(main, at + right * randf_range(-60, 60) + Vector3.UP * randf_range(-20, 30))
	Fx.pop(main, at + right * 30.0, true)
	Fx.kill_effect(main, at - right * 30.0, 1 + int(t * 2.0) % 3)
	if int(t * 2.0) % 4 == 0:
		Fx.crash(main, at + right * randf_range(-50, 50), Vector3.ZERO)
		var dummy := Node3D.new()
		main.add_child(dummy)
		dummy.global_transform = Transform3D(cam.global_basis, at + Vector3.UP * 20.0)
		Fx.flare_burst(dummy)
		get_tree().create_timer(4.0).timeout.connect(dummy.queue_free)
	if t < secs - 5.5:
		for k in 3:
			var sky := Taunts.SkyText.new()
			main.add_child(sky)
			sky.write(["GG", "NICE TRY", "TOO SLOW"][k], at + right * (k - 1) * 90.0 + Vector3.UP * 40.0, right, Taunts.SkyText.cloud(Color.WHITE))
	if me:
		for k in 3:
			main.rockets.fire_from(me, cam.global_position + right * randf_range(-30, 30) + fwd * 20.0, (fwd + right * randf_range(-0.3, 0.3)) * 160.0, null)
		for k in 60:
			main.bullets.fire(cam.global_position + fwd * 10.0 + right * randf_range(-8, 8), (fwd + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0)) * 650.0, me, false)


func _report() -> void:
	set_process(false)
	times.sort()
	var n := maxi(times.size(), 1)
	var sum := 0.0
	for x in times:
		sum += x
	var ri := func(k: int) -> int: return get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, k)
	print("3D scale %.2f" % get_viewport().scaling_3d_scale)
	print("FPS %.0f  avg_ms %.2f  p95_ms %.2f  max_ms %.2f  draws %d  prims %d  objects %d  shadow draws/prims/objs %d/%d/%d" % [1000.0 * n / maxf(sum, 0.001),
		sum / n, times[int(n * 0.95)] if times else 0.0, times[-1] if times else 0.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		ri.call(Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), ri.call(Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), ri.call(Viewport.RENDER_INFO_OBJECTS_IN_FRAME)])
	get_viewport().get_texture().get_image().save_png(png)
	get_tree().quit()
