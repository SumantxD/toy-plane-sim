extends SceneTree
# In-app purchase promotional images (1024x1024, RGB, no text): each item on planes flying a gentle turn over a world.
#   godot --path . --resolution 640x360 -s tools/iap_promo.gd [-- <product> ...]
# Writes ../builds/appstore/iap_promo/<product>.png
const OUT := "res://../builds/appstore/iap_promo/"
const SIZE := 1024
const SPEED := 45.0 # slower than play (60-95) so the whole one-second trail fits the frame
const BLUE := Color(0.3, 0.55, 1.0) # plane.gd TEAM_COLORS[0]
# w = world, planes = [kind, livery, trail, offset] in the leader's frame (-z ahead, +x right), cam / look = camera
# and its target in that frame, fx = kill effect at fx_at, bank = roll in degrees.
const SHOTS := {
	"bundle.all": {planes = [["cub", 1, 7, Vector3.ZERO], ["racer", 3, 8, Vector3(-11, 0, 11)], ["fighter", 4, 9, Vector3(11, 0, 11)], ["twin", 2, 6, Vector3(0, 0, 22)]],
		cam = Vector3(-11, 7, -18), look = Vector3(4, -2, 12)},
	"bundle.golden": {planes = [["cub", 1, 7, Vector3.ZERO]], fx = 1, fx_at = Vector3(12, -3, 40), cam = Vector3(-14, 6, -18), look = Vector3(2, 3, 16)},
	"bundle.neon": {planes = [["cub", 3, 8, Vector3.ZERO]], fx = 2, fx_at = Vector3(14, 0, 55), cam = Vector3(-14, 6, -18), look = Vector3(2, 3, 16)},
	"bundle.inferno": {planes = [["cub", 4, 9, Vector3.ZERO]], fx = 3, fx_at = Vector3(14, 2, 55), cam = Vector3(-14, 6, -18), look = Vector3(2, 3, 16)},
	"livery.golden": {planes = [["cub", 1, 0, Vector3.ZERO]], cam = Vector3(-9, 3.5, -10), look = Vector3(0, 0.3, 0.5)},
	"livery.phantom": {planes = [["cub", 2, 0, Vector3.ZERO]], cam = Vector3(-9, 3.5, -10), look = Vector3(0, 0.3, 0.5)},
	"livery.neon": {planes = [["cub", 3, 0, Vector3.ZERO]], cam = Vector3(-9, 3.5, -10), look = Vector3(0, 0.3, 0.5)},
	"livery.inferno": {planes = [["cub", 4, 0, Vector3.ZERO]], cam = Vector3(-9, 3.5, -10), look = Vector3(0, 0.3, 0.5)},
	"trail.rainbow": {planes = [["cub", 0, 6, Vector3.ZERO]], cam = Vector3(-12, 5, -15), look = Vector3(7, 0, 12)},
	"trail.gold": {planes = [["cub", 0, 7, Vector3.ZERO]], cam = Vector3(-12, 5, -15), look = Vector3(7, 0, 12)},
	"trail.neon": {planes = [["cub", 0, 8, Vector3.ZERO]], cam = Vector3(-12, 5, -15), look = Vector3(7, 0, 12)},
	"trail.fire": {planes = [["cub", 0, 9, Vector3.ZERO]], cam = Vector3(-12, 5, -15), look = Vector3(7, 0, 12)},
	"kill.fireworks": {w = 4, planes = [["cub", 0, 0, Vector3.ZERO]], fx = 1, fx_at = Vector3(-3, -4, -26), cam = Vector3(3, 4, 16), look = Vector3(-2, 6, -30)},
	"kill.lightning": {w = 4, planes = [["cub", 0, 0, Vector3.ZERO]], fx = 2, fx_at = Vector3(-6, -4, -55), cam = Vector3(3, 5, 16), look = Vector3(-3, 5, -30)},
	"kill.blaze": {planes = [["cub", 0, 0, Vector3.ZERO]], fx = 3, fx_at = Vector3(-2, -10, -36), cam = Vector3(3, 18, 16), look = Vector3(-2, -6, -30)},
}
const FX_WAIT := [0.0, 0.7, 0.07, 0.35] # kill effect -> capture: fireworks all open, bolt at full, ring mid-burst
const CENTRE := Vector3(0, 0, 900) # the turn circles here (Green Valley: lake, river and hills below)
const R := 520.0
const ALT := 480.0

var main: Node
var vp := SubViewport.new()
var cam := Camera3D.new()


# The leader's transform t seconds into a right turn, banked into it (a camera on its left looks into the valley).
func _leader(t: float, bank: float) -> Transform3D:
	var a := 2.2 - t * SPEED / R
	var fwd := Vector3(-cos(a), 0, sin(a))
	return Transform3D(Basis.looking_at(fwd, Vector3.UP).rotated(fwd, deg_to_rad(bank)), CENTRE + Vector3(sin(a) * R, ALT, cos(a) * R))


func _plane(kind: String, livery: int, trail: int) -> Node3D:
	var n := Node3D.new()
	main.add_child(n)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(3.0, 1.4, 0.4)
	var parts := Planes.build(kind, n, main.toon(BLUE), main.toon(Color(0.95, 0.93, 0.85)), main.toon(Color(0.15, 0.2, 0.3)), main.toon(Color(0.2, 0.2, 0.22)), glow, livery)
	var t: Dictionary = Planes.TYPES[kind]
	Planes.dress(kind, n, parts, t.rockets, t.bombs, 0, trail, main.toon(Color(0.2, 0.2, 0.22)), Callable(main, "toon"))
	if parts.trails: # plane.gd draws the first 0.3 s as a ribbon; here dense puffs from the wing make the line
		var swell := Curve.new()
		swell.add_point(Vector2(0, 1.0))
		swell.add_point(Vector2(1, 3.0))
		for s: CPUParticles3D in parts.trails:
			s.scale_amount_curve = swell
			s.amount = 400
	n.set_meta("props", parts.props)
	return n


func _render(p: String, f: Dictionary) -> void:
	if f.get("w", 0) != Worlds.index:
		main._build_world_content(f.get("w", 0))
		await create_timer(1.0).timeout
	seed(7)
	for b in main.battlefield.get_children(): # drifting balloons: one wanders into some frames
		b.visible = not b.has_meta("orbit")
	var bank: float = f.get("bank", 18.0)
	var planes: Array[Node3D] = []
	for d: Array in f.planes:
		planes.append(_plane(d[0], d[1], d[2]))
	var fx: int = f.get("fx", 0)
	var shot_t := 1.6 # trails are a second long: let them grow
	var fired := false
	var t := 0.0
	while true:
		var lead := _leader(t, bank)
		for i in planes.size():
			planes[i].global_transform = lead.translated_local(f.planes[i][3])
			for prop: Node3D in planes[i].get_meta("props"):
				prop.rotate_z(0.7)
		cam.global_transform = Transform3D(Basis(), lead * f.cam).looking_at(lead * f.look, lead.basis.y)
		if fx and not fired and t >= shot_t - FX_WAIT[fx]:
			fired = true
			var at: Vector3 = _leader(shot_t, bank) * f.fx_at
			Fx.kill_effect(main, at, fx)
		if t >= shot_t:
			break
		await process_frame
		t += root.get_process_delta_time()
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + p + ".png"))
	print("saved %s %dx%d" % [p, img.get_width(), img.get_height()])
	for n in planes:
		n.queue_free()
	await create_timer(3.0).timeout # let the last effects die out


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(1.0).timeout
	main.menu_root.hide()
	vp.size = Vector2i(SIZE, SIZE)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	cam.fov = 55.0
	cam.far = 6000.0
	vp.add_child(cam)
	main.add_outline(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	for p in Shop.PRODUCTS:
		if only.is_empty() or p in only:
			await _render(p, SHOTS[p])
	quit()
