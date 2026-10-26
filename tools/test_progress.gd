extends SceneTree
# Pilot progression logic without a window: XP and levels, rewards never touching the shop, badge
# conditions, bests + the observation line, daily challenge rotation, and nothing lost on missed days.
#   godot --headless -s tools/test_progress.gd
var fails := 0


func _ok(what: String, ok: bool, detail := "") -> void:
	print("%-72s %s  %s" % [what, "PASS" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _fresh(xp := 0) -> void:
	Settings.values.merge({xp = xp, best = {}, last = {}, badges = {}, daily = {}}, true)
	Progress.day_override = "2026-10-26"
	Progress.on = true


func _initialize() -> void:
	Settings.load_saved()
	var keep := Settings.values.duplicate(true)
	# levels
	_ok("floor_xp: L1 0, L2 100, L3 225", Progress.floor_xp(1) == 0 and Progress.floor_xp(2) == 100 and Progress.floor_xp(3) == 225)
	_ok("level_of at the edges", Progress.level_of(99) == 1 and Progress.level_of(100) == 2 and Progress.level_of(224) == 2 and Progress.level_of(225) == 3)
	_ok("level 30 is the cap", Progress.level_of(10000000) == 30 and Progress.level_frac(10000000) == 1.0)
	var ok := true
	for l in range(1, 30):
		ok = ok and Progress.floor_xp(l + 1) - Progress.floor_xp(l) == Progress.need(l) and Progress.level_of(Progress.floor_xp(l + 1) - 1) == l
	_ok("every level step = need(l), monotonic", ok, "total to 30: %d XP" % Progress.floor_xp(30))
	_ok("titles Rookie -> Pilot -> Ace -> Sky Legend", Progress.title(1) == "Rookie" and Progress.title(8) == "Pilot" and Progress.title(18) == "Ace" and Progress.title(30) == "Sky Legend")
	# match XP
	var a := Progress.match_xp({time = 300.0, won = true, kills = 3, assists = 2, objectives = 1})
	_ok("match XP: match + win + combat", a == [["Match", 40], ["Win", 25], ["Combat", 55]], str(a))
	a = Progress.match_xp({time = 30.0, won = true, kills = 1})
	_ok("match ended under a minute: no match / win XP", a == [["Combat", 10]], str(a))
	a = Progress.match_xp({time = 600.0, won = false, kills = 40, assists = 20})
	_ok("combat XP capped (grinding Very Easy doesn't pay)", a == [["Match", 40], ["Combat", Progress.ACTION_CAP]], str(a))
	# rewards are earn-only and exist
	var paid := []
	for p in Shop.PRODUCTS:
		paid.append_array(Shop.PRODUCTS[p].items)
	var bad := []
	var last_lv := 1
	for r in Progress.REWARDS:
		var n := int(r.item.get_slice(":", 1))
		var kind: String = r.item.get_slice(":", 0)
		if r.item in paid or (kind != "title" and Shop._free(r.item)) or r.lv <= last_lv or r.lv > Progress.MAX_LEVEL:
			bad.append(r.item)
		if kind == "sticker" and (n < Planes.FREE_STICKERS or n >= Planes.STICKERS.size()):
			bad.append(r.item)
		if kind == "trail" and (n < Planes.BANNERS.size() + Planes.PREMIUM_TRAILS.size() or n >= Planes.trail_names().size()):
			bad.append(r.item)
		last_lv = r.lv
	_ok("%d rewards: none sold in the shop, all exist, levels rising" % Progress.REWARDS.size(), bad.is_empty(), str(bad))
	var shop := Shop.new() # desktop backend: every paid look unlocked, earned ones still need the level
	_fresh(0)
	var locked: bool = not shop.owns("sticker:7") and not shop.owns("trail:10") and shop.owns("trail:6") and shop.owns("sticker:3")
	Settings.values.xp = Progress.floor_xp(3)
	_ok("earned looks unlock at their level (shop.owns), paid ones untouched", locked and shop.owns("sticker:7") and shop.owns("trail:10") and not shop.owns("sticker:8"))
	shop.free()
	# badges
	_fresh()
	Progress.begin(3, 0)
	for i in 9:
		Progress.note("hits")
	Progress.note("miss")
	Progress.note("hits")
	var miss_ok: bool = not Settings.values.badges.has("sharpshooter") and Progress.cur.combo == 1
	for i in 9:
		Progress.note("hits")
	_ok("Sharpshooter: 10 hits in a row (a miss resets)", miss_ok and Settings.values.badges.has("sharpshooter"), "combo %d best %d" % [Progress.cur.combo, Progress.cur.combo_best])
	for i in 4:
		Progress.note("kills")
	Progress.on_death()
	Progress.note("kills")
	var ace_early: bool = Settings.values.badges.has("ace")
	for i in 4:
		Progress.note("kills")
	_ok("Ace: 5 kills without going down (dying resets)", not ace_early and Settings.values.badges.has("ace"))
	_ok("First Takedown on the first kill", Settings.values.badges.has("first_kill"))
	Progress.note("dodges", 2)
	var ev: bool = Settings.values.badges.has("evasive")
	Progress.note("dodges")
	_ok("Evasive: 3 missiles shaken off", not ev and Settings.values.badges.has("evasive"))
	for i in 3:
		Progress.note("ambushes")
	Progress.note("assists", 3)
	Progress.note("prizes")
	Progress.note("captures")
	Progress.note("multi", 2)
	_ok("Ambusher / Team Player / Prize Hunter / Flag Runner / Double Trouble", ["ambusher", "team", "prize", "flag", "double"].all(func(b): return Settings.values.badges.has(b)))
	for i in 91:
		Progress.tick(1.0, i != 50) # went down once at 50 s: 41 s since
	var surv_early: bool = Settings.values.badges.has("survivor")
	for i in 60:
		Progress.tick(1.0, true)
	_ok("Survivor: 90 s in one life (not total)", not surv_early and Settings.values.badges.has("survivor"), "best %.0f" % Progress.cur.life_best)
	_fresh()
	Progress.begin(2, 0)
	for i in 120:
		Progress.tick(1.0, true)
	for i in 10:
		Progress.note("balloons")
	_ok("Balloon Popper in a flight; Survivor not from free flight", Settings.values.badges.has("popper") and not Settings.values.badges.has("survivor"))
	_fresh()
	Progress.begin(3, 3)
	Progress.tick(120.0, true)
	Progress.finish(true, 0)
	_ok("Giant Slayer: win vs ACE", Settings.values.badges.has("giant"))
	_fresh()
	Progress.on = false
	Progress.begin(3, 3)
	Progress.note("kills")
	_ok("test bots / spectators earn nothing", not Settings.values.badges.has("first_kill") and int(Settings.values.xp) == 0)
	# finish: bests, observation, XP, level-up rewards
	_fresh(Progress.floor_xp(2) - 30)
	Progress.begin(3, 0)
	Progress.tick(200.0, true)
	for i in 40:
		Progress.note("shots")
	for i in 10:
		Progress.note("hits")
	Progress.note("kills", 2)
	var r := Progress.finish(true, 120)
	var gain: int = r.xp1 - r.xp0
	var sum := 0
	for p in r.parts:
		sum += p[1]
	_ok("first match: XP = sum of parts, level-up reward listed", gain == sum and r.unlocked == ["sticker:7"] and Progress.level() == 2, "%s gain %d unlocked %s" % [r.parts, gain, r.unlocked])
	_ok("first match: honest 'first on record' line, no fake bests", r.observation.begins_with("First match on record") and r.new_best.is_empty(), r.observation)
	Progress.begin(3, 0)
	Progress.tick(100.0, true)
	for i in 40:
		Progress.note("shots")
	for i in 16:
		Progress.note("hits")
	Progress.note("kills", 2)
	r = Progress.finish(false, 100)
	_ok("accuracy best -> 'New personal best' (only what's true)", r.new_best == ["acc"] and r.observation == "New personal best: 40% accuracy!", "%s / %s" % [r.new_best, r.observation])
	Progress.begin(3, 0)
	Progress.tick(100.0, true)
	for i in 40:
		Progress.note("shots")
	for i in 12:
		Progress.note("hits")
	Progress.note("kills", 2)
	r = Progress.finish(false, 90)
	_ok("worse match: no best claimed, a plain true line", r.new_best.is_empty() and r.observation == "30% of your shots hit. Your best is 40%.", r.observation)
	var lst: Dictionary = Settings.values.last
	_ok("last match + bests stored", lst.acc == 30 and Settings.values.best.acc == 40 and Settings.values.best.kills == 2 and Settings.values.best.dmg == 120)
	_ok("observation: accuracy up on last match", Progress.observe({kills = 1, acc = 39, dmg = 10, life = 30, ambush = 0}, {kills = 1, acc = 30, dmg = 10, life = 30, ambush = 0}, {kills = 5, acc = 50, dmg = 900, life = 300, ambush = 3}) == "Accuracy up 9% on last match.")
	# daily challenges
	var d1 := Progress.daily_ids("2026-10-26")
	var same := Progress.daily_ids("2026-10-26") == d1
	var distinct := true
	var differ := false
	for k in 30:
		var ids := Progress.daily_ids("2026-11-%02d" % (k + 1))
		distinct = distinct and ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]
		differ = differ or ids != d1
	_ok("daily: same date -> same 3 (seeded), always 3 different, days rotate", same and distinct and differ, str(d1))
	_fresh(500)
	Progress.begin(3, 0)
	var d := Progress.daily()
	var first: Dictionary = Progress.challenge(d.ids[0])
	Progress.note(first.stat, first.goal - 1)
	_ok("daily: progress counts, not done one short", not d.done.has(first.id) and int(Settings.values.xp) == 500)
	Progress.day_override = "2026-10-28" # a missed day in between
	var d2 := Progress.daily()
	_ok("missed a day: new set, no XP lost, no streak to break", d2.day == "2026-10-28" and d2.prog.is_empty() and int(Settings.values.xp) == 500 and not d2.has("streak"))
	Progress.begin(3, 0)
	for id in d2.ids:
		var ch := Progress.challenge(id)
		Progress.note(ch.stat, ch.goal)
	_ok("all 3 done: 3 x %d + %d bonus, once" % [Progress.DAILY_XP, Progress.DAILY_BONUS], int(Settings.values.xp) == 500 + 3 * Progress.DAILY_XP + Progress.DAILY_BONUS and d2.bonus, str(Settings.values.xp))
	Progress.note(Progress.challenge(d2.ids[0]).stat, 100)
	_ok("a finished challenge pays only once", int(Settings.values.xp) == 500 + 3 * Progress.DAILY_XP + Progress.DAILY_BONUS)
	print("%d failed" % fails)
	Progress.day_override = ""
	Settings.values = keep
	Settings.save()
	quit(1 if fails else 0)
