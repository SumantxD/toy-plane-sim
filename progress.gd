class_name Progress
extends RefCounted

# Pilot progression, kept on this device only (Settings -> user://settings.cfg): XP and levels from your own
# match stats, badges, personal bests and three daily challenges. Nothing is sent or synced, nothing is ever
# taken away (a missed day only rotates the challenges), and rewards are earn-only looks and titles that the
# shop never sells (earned stickers / trails in Planes), so XP can't unlock or devalue a purchase.
const MAX_LEVEL := 30
const TITLES := [[1, "Rookie"], [4, "Wingman"], [8, "Pilot"], [13, "Flight Lead"], [18, "Ace"], [24, "Top Ace"], [30, "Sky Legend"]]
const REWARDS := [
	{lv = 2, item = "sticker:7"}, {lv = 3, item = "trail:10"}, {lv = 4, item = "title:Wingman"}, {lv = 5, item = "sticker:8"},
	{lv = 6, item = "trail:11"}, {lv = 8, item = "title:Pilot"}, {lv = 10, item = "sticker:9"}, {lv = 11, item = "trail:12"},
	{lv = 13, item = "title:Flight Lead"}, {lv = 15, item = "sticker:10"}, {lv = 16, item = "trail:13"}, {lv = 18, item = "title:Ace"},
	{lv = 21, item = "sticker:11"}, {lv = 24, item = "title:Top Ace"}, {lv = 27, item = "trail:14"}, {lv = 30, item = "title:Sky Legend"},
]
# Per match: a fixed amount for flying it to the end, a win bonus, and combat/objective XP capped so
# farming kills on Very Easy is never the fastest road.
const XP := {match = 40, win = 25, kills = 10, assists = 5, objectives = 15, prizes = 10, balloons = 1}
const ACTION_CAP := 100
const MIN_TIME := 60.0 # a match ended sooner (by its leader) earns no match XP
const BADGES := [
	{id = "first_kill", name = "First Takedown", desc = "Shoot down your first plane"},
	{id = "sharpshooter", name = "Sharp Shooter", desc = "Land 10 hits in a row"},
	{id = "ace", name = "Ace", desc = "Shoot down 5 planes without going down"},
	{id = "evasive", name = "Evasive", desc = "Shake off 3 missiles with flares in one match"},
	{id = "survivor", name = "Survivor", desc = "Stay up 90 s in a battle"},
	{id = "ambusher", name = "Ambusher", desc = "Land 3 ambushes in one match"},
	{id = "popper", name = "Balloon Popper", desc = "Pop 10 balloons in one flight"},
	{id = "prize", name = "Prize Hunter", desc = "Pop a prize balloon"},
	{id = "double", name = "Double Trouble", desc = "Two takedowns within 4 s"},
	{id = "team", name = "Team Player", desc = "Get 3 assists in one match"},
	{id = "flag", name = "Flag Runner", desc = "Capture a flag"},
	{id = "giant", name = "Giant Slayer", desc = "Win a battle against ACE pilots"},
]
const DAILY := [
	{id = "kills", text = "Shoot down 5 planes", stat = "kills", goal = 5},
	{id = "hits", text = "Land 50 hits", stat = "hits", goal = 50},
	{id = "prize", text = "Pop a prize balloon", stat = "prizes", goal = 1},
	{id = "ctf", text = "Win a Capture the Flag", stat = "ctf_wins", goal = 1},
	{id = "wins", text = "Win 2 battles", stat = "wins", goal = 2},
	{id = "ambush", text = "Land 2 ambushes", stat = "ambushes", goal = 2},
	{id = "rockets", text = "Hit 3 rocket shots", stat = "rhits", goal = 3},
	{id = "assists", text = "Get 3 assists", stat = "assists", goal = 3},
	{id = "deliver", text = "Fly supplies home or capture a flag", stat = "objectives", goal = 1},
	{id = "flares", text = "Shake off a missile with flares", stat = "dodges", goal = 1},
	{id = "matches", text = "Finish 3 matches", stat = "matches", goal = 3},
]
const DAILY_XP := 40
const DAILY_BONUS := 60
const BEST_KEYS := ["kills", "acc", "dmg", "life", "ambush"]

static var on := true # off for test bots and spectators: only a real local pilot earns anything
static var cur := {} # this match, live
static var events: Array = [] # [text] waiting for the HUD (badge earned, challenge done)
static var day_override := "" # tests


# ---------- levels ----------
static func need(level: int) -> int:
	return 100 + 25 * (level - 1)


static func floor_xp(level: int) -> int: # total XP at the start of `level`
	return (level - 1) * 100 + 25 * (level - 1) * (level - 2) / 2


static func level_of(xp: int) -> int:
	var l := 1
	while l < MAX_LEVEL and xp >= floor_xp(l + 1):
		l += 1
	return l


static func level() -> int:
	return level_of(int(Settings.values.xp))


static func title(lv: int) -> String:
	var out := ""
	for t in TITLES:
		if lv >= t[0]:
			out = t[1]
	return out


# 0..1 through the current level (1 at the cap).
static func level_frac(xp: int) -> float:
	var l := level_of(xp)
	return 1.0 if l >= MAX_LEVEL else clampf(float(xp - floor_xp(l)) / need(l), 0.0, 1.0)


# ---------- rewards ----------
static func reward_level(item: String) -> int: # 0: not an earned item
	for r in REWARDS:
		if r.item == item:
			return r.lv
	return 0


# Free looks and earned ones you've reached; paid looks are the shop's business (Shop.owns asks here first).
static func has(item: String) -> bool:
	var lv := reward_level(item)
	return lv == 0 or level() >= lv


static func reward_name(item: String) -> String:
	var n := int(item.get_slice(":", 1))
	match item.get_slice(":", 0):
		"sticker":
			return "%s sticker" % Planes.STICKERS[n]
		"trail":
			return "%s trail" % Planes.trail_names()[n]
	return "\"%s\" title" % item.get_slice(":", 1)


static func next_reward(lv: int) -> Dictionary:
	for r in REWARDS:
		if r.lv > lv:
			return r
	return {}


# ---------- one match ----------
static func begin(mode: int, skill: int) -> void:
	cur = {mode = mode, skill = skill, xp0 = int(Settings.values.xp), shots = 0, hits = 0, rhits = 0, combo = 0, combo_best = 0,
		kills = 0, streak = 0, streak_best = 0, multi_best = 0, assists = 0, ambushes = 0, balloons = 0, prizes = 0, dodges = 0,
		objectives = 0, captures = 0, life = 0.0, life_best = 0.0, time = 0.0, badges = [], daily = []}
	events.clear()


static func note(stat: String, n := 1) -> void:
	if not on or cur.is_empty():
		return
	match stat:
		"hits":
			cur.combo += n
			cur.combo_best = maxi(cur.combo_best, cur.combo)
		"miss":
			cur.combo = 0
			return
		"kills":
			cur.streak += n
			cur.streak_best = maxi(cur.streak_best, cur.streak)
		"multi":
			cur.multi_best = maxi(cur.multi_best, n)
			_badges()
			return
	cur[stat] = cur.get(stat, 0) + n
	_daily_add(stat, n)
	_badges()


static func on_death() -> void:
	if not cur.is_empty():
		cur.streak = 0
		cur.combo = 0


# Every frame of a match after GO: time played, and your longest life (survival).
static func tick(dt: float, alive: bool) -> void:
	if cur.is_empty():
		return
	cur.time += dt
	cur.life = cur.life + dt if alive else 0.0
	if cur.life > cur.life_best:
		var was: float = cur.life_best
		cur.life_best = cur.life
		if was < 90.0 and cur.life >= 90.0 and cur.mode != 2:
			_badges()


static func _badges() -> void:
	var c := cur
	var got := {first_kill = c.kills >= 1, sharpshooter = c.combo_best >= 10, ace = c.streak_best >= 5, evasive = c.dodges >= 3,
		survivor = c.life_best >= 90.0 and c.mode != 2, ambusher = c.ambushes >= 3, popper = c.balloons >= 10, prize = c.prizes >= 1,
		double = c.multi_best >= 2, team = c.assists >= 3, flag = c.captures >= 1, giant = c.get("won", false) and c.skill == 3 and c.mode in [3, 4, 5]}
	for id in got:
		if got[id] and not Settings.values.badges.has(id):
			var b: Dictionary = Settings.values.badges.duplicate()
			b[id] = int(Time.get_unix_time_from_system())
			Settings.values.badges = b
			c.badges.append(id)
			events.append("BADGE: " + badge(id).name.to_upper())
			Settings.save()


static func badge(id: String) -> Dictionary:
	for b in BADGES:
		if b.id == id:
			return b
	return {}


# The match is over: XP, bests, the one observation, level-ups. Returns what the results screen shows.
static func finish(won: bool, dmg: int, ended_early := false) -> Dictionary:
	if not on or cur.is_empty():
		return {}
	var c := cur
	c.won = won
	note("matches")
	if won:
		note("wins")
		if c.mode == 4:
			note("ctf_wins")
	_badges()
	var stats := {kills = c.kills, acc = roundi(100.0 * minf(c.hits, c.shots) / c.shots) if c.shots >= 20 else -1, dmg = dmg, life = int(c.life_best), ambush = c.ambushes}
	var last: Dictionary = Settings.values.last
	var best: Dictionary = Settings.values.best
	var parts := match_xp({time = 0.0 if ended_early else c.time, won = won, kills = c.kills, assists = c.assists, objectives = c.objectives, prizes = c.prizes, balloons = c.balloons})
	var gain := 0
	for p in parts:
		gain += p[1]
	var new_best := []
	if not best.is_empty():
		for k in BEST_KEYS:
			if stats[k] > best.get(k, -1) and stats[k] > 0:
				new_best.append(k)
	var obs := observe(stats, last, best)
	var nb := best.duplicate()
	for k in BEST_KEYS:
		nb[k] = maxi(int(nb.get(k, -1)), stats[k])
	var lv0 := level_of(c.xp0)
	Settings.values.xp = int(Settings.values.xp) + gain
	var lv1 := level()
	Settings.values.last = stats
	Settings.values.best = nb
	Settings.save()
	var unlocked := REWARDS.filter(func(r): return r.lv > lv0 and r.lv <= lv1).map(func(r): return r.item)
	var daily_xp: int = int(Settings.values.xp) - gain - int(c.xp0)
	if daily_xp > 0:
		parts.append(["Daily", daily_xp])
	var out := {stats = stats, last = last, best = best, new_best = new_best, observation = obs, parts = parts, xp0 = c.xp0, xp1 = int(Settings.values.xp),
		badges = c.badges.duplicate(), unlocked = unlocked, won = won}
	cur = {}
	return out


static func match_xp(s: Dictionary) -> Array:
	var out := []
	if s.time >= MIN_TIME:
		out.append(["Match", XP.match])
	if s.won and s.time >= MIN_TIME:
		out.append(["Win", XP.win])
	var act := 0
	for k in ["kills", "assists", "objectives", "prizes", "balloons"]:
		act += int(s.get(k, 0)) * XP[k]
	if act > 0:
		out.append(["Combat", mini(act, ACTION_CAP)])
	return out


# One honest, specific line about this match (only things that are true).
static func observe(now: Dictionary, last: Dictionary, best: Dictionary) -> String:
	if best.is_empty():
		return "First match on record: %s and %s. Beat it next time!" % [_fmt("kills", now.kills), _fmt("life", now.life)]
	for k in BEST_KEYS:
		if now[k] > best.get(k, -1) and now[k] > 0:
			return "New personal best: %s!" % _fmt(k, now[k])
	if not last.is_empty():
		if now.acc >= 0 and last.get("acc", -1) >= 0 and now.acc - last.acc >= 5:
			return "Accuracy up %d%% on last match." % (now.acc - last.acc)
		if now.kills > last.get("kills", 0):
			var d: int = now.kills - last.get("kills", 0)
			return "%d more kill%s than last match." % [d, "" if d == 1 else "s"]
		if now.life - last.get("life", 0) >= 20:
			return "You stayed up %d s longer than last match." % (now.life - last.get("life", 0))
		if now.dmg - last.get("dmg", 0) >= 50:
			return "%d more damage than last match." % (now.dmg - last.get("dmg", 0))
	if now.acc >= 0:
		return "%d%% of your shots hit. Your best is %d%%." % [now.acc, maxi(best.get("acc", -1), now.acc)]
	return "Longest flight: %s. Your best is %s." % [_fmt("life", now.life), _fmt("life", maxi(best.get("life", 0), now.life))]


static func _fmt(k: String, v: int) -> String:
	match k:
		"kills":
			return "%d kill%s" % [v, "" if v == 1 else "s"]
		"acc":
			return "%d%% accuracy" % v
		"dmg":
			return "%d damage" % v
		"life":
			return "%d:%02d in the air" % [v / 60, v % 60]
	return "%d ambush%s" % [v, "" if v == 1 else "es"]


# ---------- daily challenges ----------
static func today() -> String:
	return day_override if day_override else Time.get_date_string_from_system()


# Three different challenges, the same for everyone on the same date (seeded by it, no server).
static func daily_ids(day: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day.hash()
	var pool := range(DAILY.size())
	var out := []
	for i in 3:
		out.append(DAILY[pool.pop_at(rng.randi_range(0, pool.size() - 1))].id)
	return out


# Today's set; a new day starts a fresh one (yesterday's unfinished ones just rotate away: no streak, no loss).
static func daily() -> Dictionary:
	var d: Dictionary = Settings.values.daily
	if d.get("day", "") != today():
		d = {day = today(), ids = daily_ids(today()), prog = {}, done = {}, bonus = false}
		Settings.values.daily = d
	return d


static func challenge(id: String) -> Dictionary:
	for c in DAILY:
		if c.id == id:
			return c
	return {}


static func _daily_add(stat: String, n: int) -> void:
	var d := daily()
	for id in d.ids:
		var ch := challenge(id)
		if ch.stat != stat or d.done.has(id):
			continue
		d.prog[id] = mini(int(d.prog.get(id, 0)) + n, ch.goal)
		if d.prog[id] >= ch.goal:
			d.done[id] = true
			Settings.values.xp = int(Settings.values.xp) + DAILY_XP
			events.append("CHALLENGE DONE: %s  +%d XP" % [ch.text.to_upper(), DAILY_XP])
			if d.done.size() >= 3 and not d.bonus:
				d.bonus = true
				Settings.values.xp = int(Settings.values.xp) + DAILY_BONUS
				events.append("ALL 3 CHALLENGES DONE  +%d XP" % DAILY_BONUS)
			Settings.save()
