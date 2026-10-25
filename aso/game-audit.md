# Toy Plane Sim: game audit for the App Store listing

Audited 25 Oct 2026 against the working tree at `/Users/sumant.tirkey/Desktop/steam-start/plane-sim`. The first pass ran at commit `d195875` with uncommitted edits to `main.gd` and `planes.gd`; those were committed as `ed9bebf` (18:24 IST), and the round-2 pass re-checked the cited lines against HEAD `bcd5e34` (clean working tree outside `aso/`; version 0.9). Paths are relative to that folder. Labels:

- **VERIFIED**: read in code or config, with file:line.
- **MEASURED**: computed or observed from files in this audit (screenshots, icon, arithmetic).
- **ESTIMATE / HYPOTHESIS**: my judgement. Not a fact about the game.

No store metrics (downloads, search volume, conversion) are used in this file. None exist yet for this app: unknown.

---

## Decisions this supports (summary added 2026-10-25 ~18:30 IST; same block in game-audit.md, competitor-research.md and keyword-research.md)

| Decision | Recommendation | Evidence |
|---|---|---|
| Name | `Toy Plane Arcade` (C) at launch; `Toy Plane Dogfight` (A) after the 3 network checks pass | positioning.md Decision 1 and Recommendation |
| Keep "Sim"? | Drop it. **Blocker:** the game itself is still "Toy Plane Sim" (`project.godot:13`, `export_presets.cfg:41`, main menu `main.gd:2426-2427`, `PRIVACY.md`, `SUPPORT.md`). Rename those first, or keep the store name close to "Toy Plane Sim" | "sim" terms score relevance 1-2 (keyword-research.md); no P1/P2 term contains "sim" (MEASURED) |
| Subtitle word | IN (en-GB): "Aeroplane". US (en-US): "Airplane" | IN `aer` → "aeroplane games" hint #1 (MEASURED); the US hint list for `aeroplane` is weaker |
| en-GB keywords (name Toy Plane Arcade) | `airplane,fighter,war,air,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,combat,fighting` (100 bytes) | `data/listing_C.json`; P1 17/20, P2 13/26 (MEASURED, `tools/coverage.py`) |
| en-US keywords (name Toy Plane Arcade) | `aeroplane,fighter,war,air,dogfight,fight,flying,flight,offline,shooter,bomber,jet,combat,fighting` (97 bytes) | `data/listing_C_en-US.json`; P1 17/20, P2 11/26 |
| Keywords if the name is Toy Plane Dogfight | en-GB `airplane,war,fighter,air,combat,co-op,fighting,sky,flying,battle,jet,flight,offline,bomber,shooter` (98); en-US `aeroplane,war,fighter,air,combat,multiplayer,co-op,fighting,flying,battle,shooting,flight,offline` (97) | `data/listing_A*.json`; P1 18/20 both, P2 15/26 IN, 10/26 US |
| Primary category | **Games > Action** primary, **Simulation** secondary (HYPOTHESIS). IN Simulation is easier to chart (rank #50-#100 median 3,780 lifetime ratings vs 7,046 for IN Action; 15 vs 11 apps under 1,000), but all 5 plane titles in IN Simulation's top 100 are flight sims or hypercasual, the audience the "not a sim" rename steers away from. Apple indexes both primary and secondary category (apple-requirements.md §1.2), so Simulation still counts as secondary | competitor-research.md §2d (MEASURED) |
| ₹79 Hangar Shop price | Open item: check the India price list in App Store Connect when creating the first IAP. If ₹79 is missing, use ₹89 or ₹49 and recompute the set saving | apple-requirements.md §11.6: ₹79 seen in 1 of 214 IN apps; ₹99/₹199/₹499 in 92-112 each (MEASURED) |
| Top 3 screenshot claims (C) | 1. No ads, just dogfights (`PRIVACY.md:5`). 2. Fight AI, Rookie to Ace, solo with no internet (`main.gd:15`, `main.gd:264-279`). 3. Lock on, fire, flare (`planes.gd:9-12`, `plane.gd:443-461`) | All VERIFIED in code; order is HYPOTHESIS until PPO |
| Claims to keep out | "up to 8" (untested), "online" as a keyword, "free" on images, any film or game names | positioning.md check 3; `data/banned_terms.txt` |


## 1. Feature inventory (VERIFIED)

### Platform and build

| Fact | Evidence |
|---|---|
| Version 0.9 | `project.godot:17`, `main.gd:218` |
| iOS bundle `com.toyplanesim.game`, min iOS 15.0 | `export_presets.cfg:59-61` |
| iPhone only for the first release (`targeted_device_family=0`, Godot's iPhone-only value; commit `d195875` says "iPhone-only first release") | `export_presets.cfg` (iOS preset), git log |
| Landscape (sensor landscape) | `project.godot` `window/handheld/orientation=4` |
| Free desktop builds exist for macOS and Windows. In those builds every cosmetic is unlocked. | `README.md`, `shop.gd:7-8`, `shop.gd:65-79` |
| Phone and desktop can share a room only on the same version (host rejects a version mismatch). Cross-play iPhone vs desktop is not blocked in code, but I did not test it. | `main.gd:497-498` |

### Worlds: 6

`worlds.gd:12-16`. All six share one map layout (runways, bomber route, factory, spawns), so every mode works in every world (`worlds.gd:4-5`).

| # | World | Tagline in game | Flight effects (env) | Evidence |
|---|---|---|---|---|
| 1 | Green Valley | Open skies over rolling hills, a river and a lake. | none (defaults: no wind, no storm) | `worlds.gd:13-14,35-36`, `worlds/valley.gd:3` |
| 2 | Volcanic Islands | Thermals lift you, lava bombs rain from the volcano. | wind, updrafts, ash, periodic eruption with lava bombs that damage planes | `worlds/volcano.gd:48-50` |
| 3 | Frozen Frontier | Gusting wind and blinding snowstorms. | strong gusts, snowstorm cuts visibility, ridge updrafts | `worlds/frozen.gd:39-42` |
| 4 | Desert Wasteland | Canyon runs, crosswinds and sandstorms. | crosswind, thermals, sandstorm | `worlds/desert.gd:38-43` |
| 5 | Neon Metropolis | Skyscraper corridors and lightning storms. | rain, wind, lightning strikes that do 34 damage | `worlds/metro.gd:31-33` |
| 6 | Sky Kingdom | Floating islands over a deadly sea of clouds. | gusts, updrafts, falling into the cloud sea kills you | `worlds/sky.gd:66-71` |

Lava and lightning damage goes through `main.gd` `env_hit` ("downed by ..."), `main.gd:3091-3098`.

### Planes: 4 flight classes, each with a themed look per world (24 named variants)

Stats live in one table (`planes.gd:8-13`). Per-world variants change "looks, name and blurb only: stats stay in TYPES" (`planes.gd:14-27`).

| Class | Valley name | HP | Max / boost speed | Rockets | Bombs | Flares | Blurb |
|---|---|---|---|---|---|---|---|
| cub | Toy Cub | 130 | 95 / 130 | 2 | 2 | 3 | Slow and steady, tight turns, tough |
| racer | Speedster | 75 | 135 / 175 | 2 | 1 | 3 | Fastest, rolls like crazy, fragile |
| twin | Heavy Twin | 190 | 100 / 135 | 6 | 4 | 2 | Big and slow, 6 rockets, 4 bombs |
| fighter | Jet Fighter | 100 | 125 / 165 | 4 | 2 | 4 | Fast all-rounder, 4 homing rockets |

Themed names per world (`planes.gd:16-27`): Volcanic (Puddle Jumper, Wave Racer, Lava Clipper, Ash Skimmer), Frozen (Snow Bug, Icicle, Polar Hauler, Frost Fang), Desert (Dune Hopper, Mirage, Sand Camel, Scorpion), Metro (Neon Pup, Volt, Night Freighter, Laser Hawk), Sky (Cloud Kite, Zephyr, Sky Galleon, Brass Hawk). Landing gear also changes by world: wheels, floats, skis, fat tyres, none, spats (`planes.gd:29-36`).

You choose the plane in the lobby; it is not tied to the world. There is nothing to unlock: all 4 classes are available from the start (`main.gd:2519`, lobby selector over `Planes.ORDER`).

### Flight and damage

- Arcade mouse-aim flight: you point the camera and the plane steers toward it; throttle, boost, stall below a speed (`plane.gd:3-10`, `plane.gd:365`).
- Damage hits a part: left wing, right wing, engine, tail (`planes.gd:4-6,37`). README: a hit wing pulls the plane to that side, a hit engine sputters, a hit tail makes turning sluggish (`README.md`; sputter at `plane.gd:280-294`).
- Damage values: guns 8, rocket 45, bomb 150 (`main.gd:18`).
- Three camera distances (`plane.gd:26`).

### Weapons and gear

| Item | What the code does | Evidence |
|---|---|---|
| Guns | Rapid fire, bullets at 450 m/s | `plane.gd:11-12` |
| Lock-on rockets | Hold the target in a ~20 degree cone within 1300 m for 0.6 s, then the rocket guides. Reload 6 s. The target hears a lock warning. | `plane.gd:20-24`, `plane.gd:311-314`, `plane.gd:450-461` |
| Bombs | Hold B to see the impact point, release to drop | `plane.gd:336` |
| Flares | 2-4 per plane, 3 s cooldown, shake off rockets already chasing you | `plane.gd:25`, `plane.gd:429-433`, `README.md` |
| Boost | Higher top speed while held | `planes.gd:9-12` (`boost`) |

### Modes: 6

`main.gd:10`, objective text at `main.gd:2682-2684`.

| Mode | Rules in code | Solo? | Evidence |
|---|---|---|---|
| Co-op Escort | 3 AI bombers fly a route to the factory; 2 of 3 must arrive; 8 waves of AI raiders every 30 s, max 12 fighters at once; team has 6 lives | Yes (all humans on Blue) | `main.gd:24-28`, `main.gd:1069-1074`, `main.gd:1333`, `main.gd:944` |
| Team Dogfight | Blue vs Red humans; shared team lives (5 for a one-pilot team, else 10); 8-minute timer; revive a downed teammate by flying through their beacon within 15 s | No: needs at least one human on each team, and adds no AI | `main.gd:909-911`, `main.gd:1075-1078`, `main.gd:19-20`, `main.gd:1293-1307` |
| Free Flight | No rules; 20 practice balloons to pop; offline, no firewall prompt | Yes | `main.gd:272-279`, `main.gd:1066-1068` |
| Team Battle vs AI | You (and friends) plus AI wingmen vs an AI squadron; 2v2, 4v4 or 6v6; lives = 2 x squad size per side; 8 minutes | Yes (main menu "BATTLE VS AI") | `main.gd:14`, `main.gd:1049-1064`, `main.gd:264-270` |
| Capture the Flag | Fly through the enemy flag, bring it home while yours is home; first to 3; dropped flag returns after 30 s; 8 minutes | Yes, AI fills both teams | `objectives.gd:8,11-15`, `main.gd:12,1053` |
| Base Assault | Each team has an HQ (6000 HP); AI bomber raids every 70 s for both sides (600 damage each); players strafe and bomb; repair your HQ for 2 supplies (+1000 HP); 10 minutes | Yes, AI fills both teams | `objectives.gd:9,16-18`, `objectives.gd:254-262`, `main.gd:1053` |

AI fills empty seats only in Team Battle vs AI, Capture the Flag and Base Assault (`main.gd:12`, `main.gd:1055-1064`).

### AI pilots

`ai.gd`.

- Three difficulties, picked in the lobby as "ENEMY PILOTS": Rookie ("Easy kills: slow, clumsy, fragile"), Pilot ("A fair fight"), Ace ("Sharp, fast and merciless") (`main.gd:15`, `main.gd:2513-2514`).
- Difficulty sets reaction time, aim error, lead, evasion, mistakes, rocket cooldown, turn rate, plus how hard they hit humans and how easily they break (`ai.gd:13-21`). AI is "never tougher than a human" (`ai.gd:13-14`). Your AI wingmen always fly at Pilot level (`ai.gd:15`, `main.gd:1061-1062`).
- Six personalities with random per-pilot variation: Hothead, Sniper, Guardian, Show-off, Survivor, Hunter, each with signature moves (head-on, boom-and-zoom, yo-yo, scissors, loop, split-S, etc.) (`ai.gd:23-31`, `ai.gd:51-60`).
- Moods change mid-fight: confidence, fear, grudges/revenge (`ai.gd:7-9`).
- Radio lines in the kill feed ("Splash one!", "Missile! Missile!", "That was my wingman!") (`ai.gd:33-45`, `main.gd:1647`).
- Team jobs: attack, defend, escort, hunt (`main.gd:13`, `main.gd:1064`).
- Callsigns: Biscuit, Comet, Pebble, Rusty, Noodle, ... (`main.gd:16`, commit `ed9bebf`, commented "original names (no film characters)"). Commit `d195875` and earlier had Top Gun names (Maverick, Goose, Iceman, Viper).

### Battlefield systems

| System | What exists | Evidence |
|---|---|---|
| Supply crates | Parachute in every 45-75 s near the action. Flying through one gives a full repair and a resupply. In every mode except Free Flight you then carry it home for +1 team supply; get shot down and it drops for anyone to grab. Crates vanish 90 s after landing. | `battlefield.gd:4-8`, `battlefield.gd:80-110`, `objectives.gd:5-7`, `objectives.gd:139-148`, `battlefield.gd:146-149` |
| Team supplies (bank) | Each team starts with 2, gains +1 every 90 s automatically, +1 per crate delivered, max 9 | `objectives.gd:19`, `objectives.gd:109`, `objectives.gd:128-132`, `objectives.gd:148` |
| Buy defenses | Spend supplies to drop an AA gun (1), SAM site (2) or radar (1) under your plane; max 4 deployed per team at once; not in Free Flight | `main.gd:3049`, `main.gd:3077-3090`, `battlefield.gd:165-166` |
| HQ repair | 2 supplies, Base Assault only | `objectives.gd:254-262` |
| Fixed AA defenses | Flak, rapid AA, SAM and radar around both airfields and the factory; terrain blocks line of sight; destructible | `battlefield.gd:4-7`, `battlefield.gd:169-180` |
| Prize balloons | Every ~55 s one appears mid-way between the bases, drifts 60 s; whoever pops it gets one of: Full Repair, Ammo Refill, Twin Guns (20 s), Shield (15 s), Rocket Swarm (20 s). No mode check, so it runs in every mode. | `main.gd:1671-1700`, `main.gd:1208` |
| Decorative balloons | 8 hot-air balloons with team banners, decoration only | `battlefield.gd:27-49` |
| Minimap | North-up; enemies show only when a friendly plane or defense can see them | `main.gd:2266-2269` |

### Multiplayer

| Fact | Evidence |
|---|---|
| Max 8 human pilots per room ("That room is full (8 pilots)") | `main.gd:4`, `main.gd:499-500` |
| Online: host gets a 5-character room code (letters and digits, no look-alikes such as O/0, I/1) | `rooms.gd:14`, `rooms.gd:45-49`, `main.gd:338` |
| Peer-to-peer WebRTC; handshake over 3 free public MQTT brokers; STUN from Google and Cloudflare; no game server of our own | `rooms.gd:4-13` |
| Star topology: the host's device runs the match. If the host leaves, the match ends for everyone (HYPOTHESIS from the architecture; no host migration found). | `NOTES.md` "Network architecture", `rooms.gd:7` |
| Very strict NATs (some mobile carriers / CGNAT) may fail to connect; no TURN relay ships; players can add their own TURN credentials | `rooms.gd:7-8,18`, `NOTES.md` "Open 1", `SUPPORT.md` |
| LAN: "HOST ON LAN", join by IP address | `main.gd:2465-2467`, `main.gd:2033` |
| 60 s rejoin grace after a dropped connection, auto-reconnect | `NOTES.md` "Connections", `settings.gd:6` (`player_id`) |
| Lag tolerance tested with a lag proxy up to ~470 ms ping and 8% loss (developer's own test, not field data) | `NOTES.md` table |
| No public lobby list, no random matchmaking: you must share the code. The UI calls the broker step "matchmaking" (`rooms.gd:92`), but it is only a code handshake. | `rooms.gd:4-6`, `main.gd:2464-2476` |

### Communication: preset taunts only

- 24 preset messages on 3 pages of 8, picked from a wheel ("Skill issue!", "GG!", "Need backup!") (`taunts.gd:8-18`).
- Skywritten in puffy smoke letters in the sky (`taunts.gd:4-7`, `taunts.gd:21-37`).
- Only the message number is sent; 2 s cooldown; "no free text to moderate" (`taunts.gd:5-6`, `main.gd:1914`).
- Team pings: HELP! and ON ME (`touch.gd:19`).
- No text chat, no voice chat (`taunts.gd:6`, `PRIVACY.md`). Can be turned off in Settings (`settings.gd:6`, `taunts`).

### Touch controls (iPhone)

`touch.gd:4-23`, settings at `main.gd:2639-2644`.

- Left: floating steer stick (or fixed), throttle slider.
- Right: FIRE, ROCKET, FLARE, BOMB, BOOST, BUY radial menu (AA GUN, SAM, RADAR, FIX HQ).
- Top: pause, CAM, TAUNT, TEAM (HELP!/ON ME), MAP.
- Options: tilt to steer, auto-fire when the lead ring is on target, vibration, left-handed mirror, fixed stick, button opacity, drag-and-resize layout editor.
- Game controller support: **VERIFIED absent** (grep of every `*.gd` in the project root for `joypad`, `joy_` and `controller`, case-insensitive: 0 hits; `project.godot` has no joypad input events either). Do not claim it.

### Hangar Shop (cosmetic one-time IAPs)

`shop.gd:4-6, 17-35`. "Looks only: nothing here changes speed, damage or armour." (`shop_ui.gd:28`). No coins, no gems, no timers, no loot boxes (`shop.gd:5-6`). Prices shown are Apple's localized price; the INR values below are what the code says will be set in App Store Connect (`shop.gd:15-16`).

| Product ID suffix | Title | Contents | INR set in code |
|---|---|---|---|
| bundle.all | Collector's Hangar | all 4 paints, 4 trails, 3 kill effects | 499 |
| bundle.golden | Golden Ace Set | Golden Ace paint, Gold Sparkle trail, Fireworks | 199 |
| bundle.neon | Neon Night Set | Neon Night paint, Neon trail, Lightning | 199 |
| bundle.inferno | Inferno Set | Inferno paint, Fire trail, Blaze | 199 |
| livery.golden / .phantom / .neon / .inferno | Paint jobs: Golden Ace, Black Phantom, Neon Night, Inferno | 1 paint | 99 each |
| trail.rainbow / .gold / .neon / .fire | Smoke trails: Rainbow, Gold Sparkle, Neon, Fire | 1 trail | 79 each |
| kill.fireworks / .lightning / .blaze | Kill effects, "Everyone sees it." | 1 effect | 79 each |

**Are these valid Apple India price points? Not verified from Apple.** Apple's pricing help says you choose from "up to 800 price points" per storefront, but the list itself is only visible inside App Store Connect (`apple-requirements.md` §11.6). MEASURED on 214 live IN product pages: ₹99, ₹199 and ₹499 are among the most common IAP prices (92–112 apps each), but ₹79 shows up in only 1 app (`apple-requirements.md` §11.6). So ₹99/₹199/₹499 are valid in practice; ₹79 is unconfirmed until someone opens the India price list in App Store Connect.

15 products. Free cosmetics: 7 stickers (None, Star, Lightning, Flame, Roundel, Checkers, Shark Mouth) and 5 free trail colours (`planes.gd:39-40`, `shop.gd:36`). A paint job keeps the team colour on the fuselage so friend and foe stay readable (`planes.gd:41-43`).

MEASURED (arithmetic on `shop.gd` INR values): each 199 set replaces 99 + 79 + 79 = 257, so about 23% less (matches screenshot 5). Collector's Hangar replaces 4x99 + 4x79 + 3x79 = 949, so about 47% less.

Other shop behaviour: "Try it free in Free Flight" for unowned items (`shop_ui.gd:44`, `shop_ui.gd:143-146`); one set offer after a win, at most once a session, never in the first 3 matches, dropped after 2 dismissals (`shop.gd:209-219`); Restore Purchases (`shop.gd:130-135`); Ask to Buy handled (`shop.gd:160-161`); Apple's rating prompt after a win, 5+ matches in, at most every 60 days (`shop.gd:229-238`).

### Music and sound

- 6 music tracks, one per world (`sfx.gd:31-33`, `assets/music/*.ogg`).
- Written for this game: "six hand-written folk-style tunes rendered with small synths" by `tools/make_music.py:1`, which marks them "ours, CC0". So "original music" is VERIFIED.
- Sound effects: Kenney CC0 packs plus generated sounds (`assets/sfx/Kenney-License.txt`, `tools/make_sounds.py`, `THIRD_PARTY_LICENSES.txt:3`).
- 3D models (trees, buildings, props) and UI font are Kenney CC0 (`THIRD_PARTY_LICENSES.txt:3`). Planes are built in code (`planes.gd`).

### Privacy facts relevant to the listing

From `PRIVACY.md` and `settings.gd:6`: no accounts, no ads, no analytics, no tracking. Stored on device only: pilot name, settings, equipped looks, a random player ID, a network log. Other players in your room see your IP address (P2P). This supports a "Data Not Collected" privacy label (HYPOTHESIS: confirm against Apple's definitions when filling in the label, since the developer collects nothing but third-party brokers/STUN see IPs). Apple's definitions and how they apply to the brokers and STUN servers are in `apple-requirements.md` §11.3.

---

## 2. What is NOT in the game (VERIFIED by search)

I searched every `*.gd` file in the project root for xp, experience, achievement, gamecenter, leaderboard, ranked, matchmak, login, account, voice, chat, unlock and progress. Hits were only UI progress bars, AI radio "chatter", the rooms "matchmaking" status text and shop "unlock" strings.

| Not there | Evidence |
|---|---|
| Persistent progression: no XP, levels, ranks, plane upgrades or unlock tree | `settings.gd:6-8` is everything that persists. The only counter is `matches`, used just to time the shop offer and rating prompt (`shop.gd:212,233`). All planes are available from the start. |
| Stat upgrades of any kind | Shop is cosmetic only (`shop.gd:4-6`, `shop_ui.gd:28`). Only in-match boosts exist: prize-balloon power-ups and crate repairs. |
| Accounts / login / cloud save | `PRIVACY.md`; no auth code |
| Game Center, leaderboards, achievements | grep: none |
| Ranked play or random matchmaking | Rooms are by code only (`rooms.gd:4-6`) |
| Text or voice chat | `taunts.gd:5-6`, `PRIVACY.md` |
| Single-player campaign or story | Modes list `main.gd:10` |
| Daily rewards, energy, timers, ads, loot boxes, currency | `shop.gd:5-6`, `PRIVACY.md` |
| Takeoff and landing | Parked (`NOTES.md` "Open 4") |
| Persistent stats across matches | Kills, deaths, revives reset each match (`main.gd:1042-1045`); scoreboard is per match (`main.gd:2057`) |
| iPad build | iPhone only (`export_presets.cfg` `targeted_device_family=0`) |
| Spectator mode for players | `--spectate` is a developer command-line flag (`main.gd:223`) |

---

## 3. Claims we can and cannot make on the App Store

| Possible claim | Verdict | What exactly exists |
|---|---|---|
| "6 worlds" | **Can** | Green Valley, Volcanic Islands, Frozen Frontier, Desert Wasteland, Neon Metropolis, Sky Kingdom (`worlds.gd:13`) |
| "Weather and hazards change how you fly" | **Can**, for 5 of 6 worlds | Wind, updrafts, storms that cut visibility; lava bombs (Volcanic) and lightning (Metro) do damage; cloud sea kills (Sky). Green Valley has none. |
| "24 planes" | **Cannot** as stated | 4 flight classes; each world gives them a themed model and name (24 named looks, same 4 stat sets). Safe: "4 plane types, restyled for every world". |
| "6 game modes" | **Can**, with a solo caveat | `main.gd:10`. Team Dogfight is the one mode a solo player cannot start: the host's start request is refused with "Dogfight needs a pilot on each team" when a team has no human (`main.gd:909-911`), and it adds no AI. A solo player who wants a dogfight gets Team Battle vs AI. Copy must not promise a solo "Dogfight" mode. |
| "Play solo or with friends" | **Can** | 5 of 6 modes run offline solo; Team Dogfight needs 2+ humans |
| "Online multiplayer with friends, up to 8 players" | **Can**, with care | 8 humans per room by 5-character code, P2P. Some strict mobile networks cannot connect (no relay ships). Do not imply guaranteed connection. |
| "Real-time multiplayer battles" / "PvP" | **Can** | Team Dogfight and any team mode with humans on both sides |
| "Matchmaking" / "play with players worldwide" / "ranked" | **Cannot** | No random matchmaking, no public lobbies, no ranks. Only friends with your code, or LAN. |
| "Local / LAN multiplayer" | **Can** | Host on LAN, join by IP (`main.gd:2465`) |
| "Cross-platform with PC/Mac" | **Do not claim yet** | Not blocked in code (same version required), not tested in this audit |
| "Smart AI with 3 difficulties" | **Can** | Rookie, Pilot, Ace (`main.gd:2513`) |
| "AI pilots with personalities" | **Can** | 6 archetypes, moods, signature moves, radio lines (`ai.gd:23-45`) |
| "Guns, lock-on rockets, bombs and flares" | **Can** | `plane.gd:20-25`, `plane.gd:336` |
| "Realistic flight sim" / "simulator" | **Cannot** | Arcade mouse-aim flight with toy planes (`plane.gd:3`). The name says "Sim"; copy should say "arcade". HYPOTHESIS: "simulator" in copy may attract players expecting realism and hurt ratings. |
| "Part-by-part damage" | **Can** | Wings, engine, tail each damageable with effects (`planes.gd:4-6`) |
| "Resource gathering" / "supply economy" | **Narrow claim only** | One resource: team supplies. Grab parachuted crates and fly them home (+1), plus +1 every 90 s, max 9. Spent on AA guns, SAM sites, radar, HQ repair. No mining, crafting or inventory. Safe: "grab supply crates and spend them on AA guns, SAMs and radar". |
| "Build defenses" / "base building" | **Narrow claim only** | Drop up to 4 turrets per team (AA gun, SAM, radar) under your plane. No building or base layout. Safe: "deploy AA guns, SAM sites and radar". "Base building": cannot. |
| "Upgrades" / "upgrade your plane" | **Cannot** | Nothing persists. Only in-match prize-balloon power-ups (Twin Guns 20 s, Shield 15 s, Rocket Swarm 20 s, Full Repair, Ammo Refill). Safe: "pop prize balloons for power-ups". |
| "Progression", "level up", "unlock planes", "career" | **Cannot** | None exist |
| "Capture the Flag" / "Base Assault" / "Co-op Escort" | **Can** | `main.gd:10`, `objectives.gd` |
| "Taunt your friends with skywriting" | **Can** | 24 preset taunts written in smoke letters (`taunts.gd`) |
| "Chat with friends" | **Cannot** | No text or voice chat; presets only |
| "No ads" | **Can** | `PRIVACY.md`; no ad SDK |
| "No pay-to-win" / "cosmetics only" | **Can** | `shop.gd:4-6`, `shop_ui.gd:28` |
| "No loot boxes, no energy timers" | **Can** | `shop.gd:5-6` |
| "Free" | **Unknown** | Code implies free download with IAPs (`shop.gd`), but the price tier is set in App Store Connect, not in the repo |
| "Original soundtrack" | **Can** | 6 tunes made for the game (`tools/make_music.py:1`) |
| "Touch controls you can customise" | **Can** | Layout editor, tilt, auto-fire, left-handed, opacity (`touch.gd:4-7`) |
| "Controller support" | **Cannot** | VERIFIED absent (grep of `*.gd` for joypad/joy_/controller: 0 hits) |
| "iPad" | **Cannot** | iPhone-only build |
| "Works offline" | **Can**, for solo | Free Flight and Battle vs AI use an offline peer (`main.gd:264-279`). IAP purchase needs a connection. |
| "No account needed" | **Can** | `PRIVACY.md`, `README.md` |
| "Leaderboards" / "achievements" | **Cannot** | None |
| "Up to 12 v 12" or similar big numbers | **Cannot** | Squadron sizes are 2v2, 4v4, 6v6 (`main.gd:14`); humans max 8 per room; Escort up to 12 AI raiders at once (`main.gd:27`) |

---

## 4. Current screenshots (MEASURED: viewed in this audit)

All five are 2868 x 1320, landscape. That is the iPhone 6.9-inch size in Apple's screenshot specifications (from Apple's published spec, not re-fetched here). They are raw gameplay with no captions. They were made by `tools/appstore_shots.gd` with `--phone --fake-store` (`tools/appstore_shots.gd:3`).

| File | What it shows | Notes for the listing (ESTIMATE / HYPOTHESIS) |
|---|---|---|
| `1-battle.png` | Team Battle vs AI in Green Valley. Chase view behind a blue-and-yellow Toy Cub over low-poly hills, snowy peaks, orange-leaf trees. Top bar: "BLUE 8 lives, 4 flying / 7:50 / RED 8 lives, 4 flying". HUD line: Toy Cub, HP 130, Speed, Alt, Throttle, Rockets 2, Bombs 2, Flares 3, Supplies 2 (BUY). Full touch overlay (STEER, FIRE, ROCKET, FLARE, BOMB, BOOST, BUY, top buttons). Minimap with "Green Valley M hid…". Enemy name tags (Maverick, Merlin, Viper) are tiny in the distance. | Pretty world, but no visible combat: no tracers, hits, explosions or nearby enemy. The plane is small and the HUD text is dense. The minimap caption shows a keyboard hint ("M hide N zoom", cut off) on the phone build. Fixed in commit `bcd5e34`: on touch the caption is the world name only (`main.gd:2325`, VERIFIED); this old PNG still shows it. |
| `2-taunt.png` | Same scene seconds later, with "LET'S GO!" skywritten in big puffy cloud letters across the sky. Radio line top right: Jester: "Moving to assist." | Strongest unique visual of the set: shows the skywriting taunt clearly. Same weak points as shot 1 (no combat, same keyboard hint). |
| `3-sky-kingdom.png` | Free Flight in Sky Kingdom: lavender sky, floating purple islands, white cloud sea, the Cloud Kite variant (with gas-bag wing pods). Top bar: "FREE FLIGHT Balloons popped: 0 (II for menu)". Many red "Balloon" name tags over the islands. | Shows world variety well. The "Balloon" tags clutter the centre, and Free Flight is the least exciting mode to sell. Throttle slider and STEER ring are faint against the bright sky. |
| `4-mission-setup.png` | Lobby "MISSION SETUP / Solo battle vs AI": World Green Valley (1/6) with a thumbnail, Mode Team Battle vs AI (4/6), Squadron size 4 VS 4, big LAUNCH button. Right: Squadrons "Blue team + 3 AI pilots", "Ace [Toy Cub] (leader) host", "Red team + 4 AI pilots"; Hangar: Your plane Toy Cub, Sticker None, Paint job Golden Ace. Centre: plane on the runway with AA guns beside it. | Communicates choice (6 worlds, 6 modes, squad size). Menus are weak as a store screenshot. The pilot is named "Ace", which reads like the difficulty name. The Rookie/Pilot/Ace selector is not visible in this crop. |
| `5-shop.png` | Hangar Shop: "Looks only: nothing here changes speed, damage or armour." Sets > Golden Ace Set (EQUIPPED). "About 23% less than buying these one by one." "One-time purchase. Yours on every device with your Apple ID; Restore Purchases brings it back." Right: gold-trimmed plane on the runway with a gold trail and floating confetti hexagons. | Honest and clear about cosmetics-only, a trust point. HYPOTHESIS: a shop screen is usually low-value in the first 3 store slots; better late in the set. No price is visible because the item shows as equipped (fake store). |

**Blocker (VERIFIED by viewing):** `1-battle.png` shows the name tags Maverick, Merlin and Viper, and `2-taunt.png` shows Jester on the radio line. These are from the old callsign list. Do not upload any of `builds/appstore/*.png`; use the regenerated set in `aso/creative/screens/` (captured after the rename) and re-check every frame for film character names before upload (Guideline 2.3.9 and trademark risk, apple-requirements.md §5).

General (HYPOTHESIS): none of the five shows a dogfight up close, a rocket lock, a bomb run, an explosion, a kill effect, or two human players together, which are the core promises of the subtitle "Dogfight friends in toy planes". Five of six worlds' looks are missing except Valley and Sky (no Volcanic, Frozen, Desert or Neon).

## 5. Current icon (MEASURED: viewed in this audit)

`assets/ui/icon_ios.png`: 1024 x 1024, no alpha (as Apple requires), set as the iOS 1024 icon in `export_presets.cfg:72`.

What it shows: a flat mid-blue square with a slightly different blue circle (faint edge visible), and a yellow, boxy high-wing plane seen from below at an angle, with a white engine block, a black two-blade propeller and two black wheels. No text.

Observations:
- At 120 px (home-screen scale) the plane still reads as a plane and the yellow on blue is high contrast.
- The faint circle edge looks like an artefact rather than a design choice.
- The icon plane is a boxier, all-yellow model than the in-game Toy Cub, which has a rounded blue (team colour) fuselage with yellow wings (compare screenshots 1 and 4). VERIFIED: `tools/make_icon.gd` renders the cub on a sky disc and the 512 px `icon.png` dates from the v0.5 commit (19 Oct); HYPOTHESIS: `icon_ios.png` is that older render placed on a blue square, so it predates the current plane models.
- Nothing in the icon says "combat" or "multiplayer" (no second plane, tracer or smoke trail). HYPOTHESIS: worth testing a version with two planes or a smoke trail once there is store data.

---

## 6. Small findings for the developer (not listing copy)

These are in game code, which this audit does not change:

1. **Resolved in `bcd5e34`.** The minimap caption "M hide N zoom" showed on the phone build (screenshots 1-3). `main.gd:2325` now draws only the world name when `TouchControls.on()` (VERIFIED).
2. The Free Flight top bar switches its hint between "II" and "Esc" on touch (`main.gd:2198`); the minimap caption now matches it (item 1).
3. AI callsigns are original names since commit `ed9bebf` (`main.gd:16`). Build the release from `ed9bebf` or later. The old names still appear in `builds/appstore/1-battle.png` and `2-taunt.png` (see §4 blocker).
4. **Smoke and flak (commit `ed9bebf`, VERIFIED in code; look not re-checked here).** Wreck smoke is now unshaded and see-through, and its alpha fades to 0 at 70% of each puff's life, before the puffs reach full size (`fx.gd:46-55`). Flak is a see-through puff that fades out in 1.4 s (`fx.gd:219-237`). The user reported large, shiny dark balls left at the end of a destruction; whether this commit fully removes them has to be checked in the running game before new store captures. Plane z-fighting (overlapping faces) is also addressed in `ed9bebf` by the commit message; not re-audited here.

## Round 2 changes

Against the latest research critique (r3 in `data/critiques_round1.json`):
- r3 #1 (stale callsigns): §1 "AI pilots" cites the original names at `main.gd:16`; §4 has the `builds/appstore/*.png` blocker; §6 item 3 says to build from `ed9bebf` or later. The header now names the commits checked (`d195875` → `ed9bebf` → HEAD `bcd5e34`) instead of "uncommitted changes", which no longer exist. apple-requirements.md §5 row 2.3.9 carries the matching note.
- r3 #4 (decision summary): the "Decisions this supports" block above §1 is the combined one.
- New since round 1: the minimap keyboard hint is fixed in `bcd5e34` (§4 row 1, §6 items 1-2), and the smoke/flak change is noted in §6 item 4.

