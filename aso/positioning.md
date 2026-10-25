# Positioning: Toy Plane Sim (iOS)

Written 2026-10-25 from `game-audit.md`, `competitor-research.md`, `keyword-research.md` and `apple-requirements.md` in this folder. Revised several times the same day after review: "Sim" is dropped from every listing, Strategy C is the launch default, `online` is out of the keyword fields, and (round 2) the A and C names carry the search term "Air Combat". See "Round 2 changes" at the end. Labels:

- **VERIFIED**: in the game's code or config (file:line), or on an Apple page.
- **MEASURED**: from data fetched for this project (`aso/data/`) or counted by me.
- **ESTIMATE**: derived by a stated method.
- **HYPOTHESIS**: judgement, untested.

Search volume, downloads and conversion are **unknown** for every term and every strategy. Nothing below predicts installs. "Demand" means App Store autocomplete presence (a proxy), and "competition" means the median rating count of the top 5 search results, both from `keyword-research.md` and `data/keywords.json`.

**Data versions used here.** `data/keywords.json` and `data/review_theme_counts.txt` were regenerated during the day by the research pass. This file uses the versions on disk at 16:55 and 16:51 IST on 2026-10-25:
- `keywords.json`: 21 P1 and 22 P2 terms. The ranked table in `keyword-research.md` may still show the older list of 16 P1 terms.
- `review_theme_counts.txt`: 843 reviews from 19 page-1 feeds (the `TOTAL page-1 feeds` line). This replaces the 500-review sample quoted in the first revision.

Coverage counts come from `tools/coverage.py`, run at 16:54 IST and re-run at 17:00 IST against the 16:55 `keywords.json` with identical results (ESTIMATE, see §0).

## Short version

**Recommendation: ship Strategy C, "No-ads arcade aeroplane game". Switch to Strategy A, "Dogfight your friends", only after it passes three checks: at least 9 of 10 joins succeed on both Jio and Airtel data, a hosted MQTT broker or TURN relay exists, and an 8-phone room holds a full match.** Details in the Recommendation section.

**How to read the three strategies.** There are two keyword strategies, not three: a head-term core shared by A and C (21 of their 24 indexed words are the same after round 2), and B's combat set. A and C are two page-level pitches over that core (friends versus no ads), differing in subtitle, promo text, description order, screenshots and icon.

**Launch blockers for C (all in `launch-action-plan.md` Phase 0):** (1) rename the game to match the store name (`project.godot:13`, `export_presets.cfg:41`, main menu `main.gd:2427-2428`, `PRIVACY.md`, `SUPPORT.md`); until then every listing shows the validator's "device name" WARN. (2) Render C's balloon/power-up frame and put C's headlines on frames 2-7; frame 1 (`creative/screens/c01_no_ads.png`) now exists.

| Field | India (en-GB, default language there) | US (en-US) |
|---|---|---|
| Name | `Toy Plane Arcade: Air Combat` (28/30) | same as India |
| Subtitle | `Aeroplane battles with no ads` | `Airplane battles with no ads` |
| Keywords | `airplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` (98 bytes) | `aeroplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` (99 bytes) |
| Coverage (ESTIMATE, `tools/coverage.py`, 20 P1 / 26 P2) | P1 17/20, P2 14/26 | P1 17/20, P2 14/26 |
| Files | `data/listing_C.json` | `data/listing_C_en-US.json` |

The switch-to listing, Strategy A:

| Field | India (en-GB) | US (en-US) |
|---|---|---|
| Name | `Toy Plane Dogfight: Air Combat` (30/30) | same as India |
| Subtitle | `Aeroplane fights with friends` | `Airplane fights with friends` |
| Keywords | `airplane,war,fighter,co-op,fighting,sky,flying,battle,jet,flight,offline,bomber,shooter,shooting` (96 bytes) | `aeroplane,war,fighter,multiplayer,co-op,fighting,flying,battle,shooting,flight,offline,sky,pvp` (94 bytes) |
| Coverage (ESTIMATE) | P1 18/20, P2 16/26 | P1 18/20, P2 13/26 |
| Files | `data/listing_A.json` | `data/listing_A_en-US.json` |

**Revision 3 (2026-10-25, ~18:30 IST, completeness pass).** (1) C's keywords swap `capture,flag` (P3 only) for `combat,fighting`; en-US also drops `sky`. Coverage against the current `data/keywords.json` (20 P1, 26 P2 after keyword-research round 4): C India P1 17/20, P2 13/26; C US P1 17/20, P2 11/26. Before the swap, against the 23-term P2 list: 16/20 and 10/23 in both stores. Newly covered: "plane fighting game", "air combat", "air combat games" (MEASURED, `tools/coverage.py`, 18:30 IST). (2) "up to 8 pilots" removed from A, B and C; `data/banned_terms.txt` now WARNs on "up to 8" until the 8-phone test passes. (3) C's first line no longer says "with nothing to interrupt you", because the post-win shop prompt (`shop.gd:209-219`) could be read as an interruption. (4) The Comparison table was refreshed in round 2 against the 20/26 `keywords.json`. (5) A's keywords take keyword-research.md's reconciliation swaps (`capture,flag,pvp` out; `fighting,co-op,sky,bomber,shooter` in): A India P1 18/20, P2 15/26; A US P1 18/20, P2 10/26 (MEASURED, `tools/coverage.py`, after round 4 added 3 P2 terms). (6) The name mismatch is a **launch blocker**, not an open item: see `launch-action-plan.md` step 1. The validator now WARNs when a listing name doesn't start with `project.godot` `config/name` ("Toy Plane Sim"), so every listing shows 1 WARN until the game is renamed or the store name is kept close. (7) **Read A and C as two page-level pitches over one keyword core, not two keyword strategies.** After the swaps they share 13 of 15 India keyword words; the real keyword alternative is B. The differences between A and C are the name, subtitle, description order and screenshots. (8) C's hero frame now exists (`creative/screens/c01_no_ads.png`); the balloon frame is not rendered yet: a launch blocker (`launch-action-plan.md`). (9) **Name with a search term, tested (MEASURED, validator + `tools/coverage.py`, 18:35 IST).** `Toy Plane Arcade: Air Combat` (28/30) passes the validator, including the competitor-title check, and frees `air,combat` from the keyword field for `shooting` (en-GB `airplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting`, 98 bytes; en-US adds `aeroplane`, drops nothing else, 99 bytes). Coverage: P1 17/20 and P2 14/26 in both stores (vs 13 and 11 for plain `Toy Plane Arcade`). `Toy Plane: Air War Arcade` is rejected: the validator WARNs that "air war" copies the competitor title "Alliance: Air War". **Adopted in round 2** (see "Round 2 changes"): every non-"Sim" name already needs the in-game rename, so the suffix adds no new gap; the game can be renamed to "Toy Plane Arcade" and the store name then starts with it.

All five listing files pass `tools/validate_metadata.py` with 0 FAIL and 1 WARN each, the intended "device name" WARN that stays until the game is renamed (MEASURED, run 2026-10-25 18:36 IST; output in the appendix).

`developer_name` in every listing is set to `Sumant Tirkey` (ESTIMATE, from the macOS user and git author). App Store Connect makes the seller name searchable on its own, so replace it with the exact seller name ASC shows before trusting the validator's duplicate check.

## Decision 1, made: "Sim" is out of the name

Every listing now drops "Sim": A is `Toy Plane Dogfight: Air Combat` (30/30), B is `Toy Plane: Fighter Battles` (26/30) and C is `Toy Plane Arcade: Air Combat` (28/30). The reasons:

- **"Sim" mislabels the game.** It is an arcade combat game with no realistic flight model, cockpit or progression (VERIFIED, game-audit.md §2). For "plane game" and "aeroplane game", the top-5 results in both stores are flight simulators (Infinite Flight, Airplane Pro, X-Plane), and "plane simulator", "airplane simulator" and "flight simulator" scored relevance 1-2, the Avoid bucket (MEASURED, keyword-research.md). A name that says "Sim" sets an expectation the game doesn't meet, which is a Guideline 2.3 accuracy risk and a likely "not a sim" review theme (HYPOTHESIS).
- **The cost is lowest now.** The app has 0 ratings and no store history. After release, the name changes only with a new app version, and early reviews keep the old expectation attached (VERIFIED, apple-requirements.md §7).
- **The rename loses nothing measured.** No P1 or P2 term contains "sim" (MEASURED, `data/keywords.json`).
- **C's old name doubled down.** `Toy Plane Sim: Flight Arcade` paired "Sim" with "Flight", the two words simulator searchers type. `Toy Plane Arcade` keeps "flight game" covered through the keyword field instead.
- **The name you pick here is the name most of the world sees.** The en-GB localization is the default language for India and for more than 100 other storefronts, including the UK, Ireland, Indonesia, Singapore, Malaysia, the Philippines, Pakistan, Nigeria and South Africa (VERIFIED, Apple localization table, https://developer.apple.com/help/app-store-connect/reference/app-store-localizations/, fetched 2026-10-25). Australia and New Zealand default to English (Australia); the US to English (U.S.).

The game itself, its desktop build and `PRIVACY.md`/`SUPPORT.md` still say "Toy Plane Sim". **This is a launch blocker, not an open item.** App Review compares the store name with the name on the device and in the app (HYPOTHESIS from common rejection reports; Guideline 2.3). Before submitting, rename the game in `project.godot:13` (`config/name`), `export_presets.cfg:41` (`product_name`), the main-menu title (`main.gd:2427-2428`, "TOY PLANE" / "SIM"), `PRIVACY.md` and `SUPPORT.md` to "Toy Plane Arcade" (VERIFIED locations), or keep the store name close to "Toy Plane Sim". These are code and docs changes outside this folder (`launch-action-plan.md` step 1). The validator WARNs ("device name") while the store name does not start with `config/name`.

---

## 0. Two facts that shape all three strategies

1. **India's App Store shows English (U.K.) by default.** Apple's localization table lists India: default language English (U.K.), additional languages Bangla, Gujarati, Hindi, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu, Urdu. The US default is English (U.S.), with additional languages Arabic, Chinese (Simplified), Chinese (Traditional), French, Korean, Portuguese (Brazil), Russian, Spanish (Mexico) and Vietnamese. There is no "English (India)" locale (VERIFIED, same Apple table, fetched 2026-10-25). So the India listing is an **en-GB** localization with India's spelling ("aeroplane"), and en-US carries the US version. Each `listing_X.json` is `en-GB`; A and C also have `listing_X_en-US.json`.
2. **The name and subtitle should carry the terms people actually type.** "aeroplane game(s)" is IN autocomplete #1 after 3 letters (`aer`) (MEASURED, keyword-research.md rows 7-8). "dogfight" has IN top-5 competition of 34 ratings, the lowest of any P1 term, but its autocomplete score is 1 in both stores: it only appears once the whole word is typed (MEASURED, row 9). The exact multiplayer phrases ("plane games with friends", "multiplayer plane game", "online plane game") show no autocomplete in either store (MEASURED). So "friends" is a promise for the people who land on the page, not a search magnet.

Keyword coverage assumes two things Apple does not document (HYPOTHESIS): that words from the name, subtitle and keyword field combine into phrases, and that "game" is covered by the Games category. Apple says only that these fields are indexed (`apple-requirements.md` §1.2). `tools/coverage.py` applies that rule with naive plural folding, so it does not match "coop" to "co-op" or "fighting" to "fight" (ESTIMATE; Apple's own matching is unpublished).

**About "3d".** "plane game 3d" and "aeroplane game 3d" are P1 terms. Covering them needs the keyword `3d`, but ASC's help says each keyword must be "greater than two characters" (VERIFIED, apple-requirements.md §1.1), and the validator fails it. Whether ASC actually rejects `3d` is **unknown**. Test it when entering metadata: A India has room (`…,shooting,3d` is 99 bytes); C India would have to drop `sky` (the only C keyword whose P2 terms have US autocomplete 1 only). B covers "3d" through its subtitle.

**About "offline".** "aeroplane games offline" is an IN autocomplete hint (MEASURED, keyword-research.md line 10), and "offline plane game" hints in the US from `offline plane` (MEASURED, row 46). Solo play really runs with no network: Free Flight and the vs-AI modes use `OfflineMultiplayerPeer` (VERIFIED, `main.gd:264-279`). So both A and C now index `offline`. Multiplayer still needs internet or LAN, and both descriptions say so.

**About "online".** Removed from every keyword field. There is no public lobby or random matchmaking: you join only by room code or LAN (VERIFIED, `rooms.gd:4-6`). "online plane game" draws searchers who expect a player pool (IN top-5 median 99,850 ratings, 0 autocomplete in both stores; MEASURED, keyword-research.md row 41), and they would meet an empty game unless they bring friends. That is the same Guideline 2.3 expectation risk that made screenshot headline 4 drop "online", and a likely "nobody online" review theme (HYPOTHESIS). The validator now WARNs on `online` in the keyword field (`data/banned_terms.txt`).

---

## Strategy A: "Dogfight your friends" (friends multiplayer, toy dogfights)

**Target player (HYPOTHESIS).** Teens and young adults in India who play with a fixed group of friends or cousins, often on the same Wi-Fi, and who are tired of matchmaking queues, bots and fuel timers in the big plane games. Secondary: the same group in the US.

**Promise.** Share a code and you and your friends are in the same sky. Friends busy? Fight AI pilots.

**Proof from the real game (VERIFIED, game-audit.md).**
- Rooms by 5-character code, up to 8 human pilots (`rooms.gd:14,45-49`, `main.gd:4,499-500`). The code is shown as "ROOM CODE" with a COPY button (`main.gd:2028`, `main.gd:2541`). 8 is the code limit; 8 phones in one room has not been tested (see the pre-launch checks).
- LAN host and join by IP (`main.gd:2465-2467`).
- No account (`PRIVACY.md`).
- AI fills seats in 3 of 6 modes (Team Battle vs AI, Capture the Flag, Base Assault), Rookie/Pilot/Ace (`main.gd:12`, `main.gd:2513`); solo play runs on an offline peer (`main.gd:264-279`).
- Teammate revive by beacon (`main.gd:1293-1307`).
- Skywritten preset taunts, no open chat (`taunts.gd:4-18`).
- Six AI personalities with their own moves (`ai.gd:23-60`). Only three of them (hothead, show-off, sniper) have their own kill lines on the radio (`ai.gd:33-37`); the rest share the common lines. So the description says "radio chatter", not "their own radio calls".
- No public lobby or random matchmaking: you join only by code or LAN (`rooms.gd:4-6`). The copy never says or implies "online players".

**Competitor evidence it answers (MEASURED, `data/review_theme_counts.txt`, 843 reviews, regex themes).**
- 11 review matches on friends, private rooms or local play (1.3%).
- 15 on matchmaking waits and bots ("spend 30 mnt just to find a game", "now I've played only with bots").
- Air Wings reviewers: "nobody is online", asked for LAN (competitor-research.md).
- 4 of the 7 competitor first screenshots that have a headline sell friends or multiplayer (competitor-research.md).

**Keyword focus.** Name and subtitle take "dogfight", "air", "combat", "plane", "aeroplane"/"airplane", "fights", "friends". The keyword field adds combat and solo words: airplane, war, fighter, co-op, fighting, sky, flying, battle, jet, flight, offline, bomber, shooter, shooting (India). The US swaps airplane for aeroplane and adds multiplayer and pvp in place of jet, bomber and shooter.

Coverage (ESTIMATE, `tools/coverage.py`, 20 P1 / 26 P2 terms, 2026-10-25 18:36 IST):
- India: P1 18/20, P2 16/26. Missing P1: aeroplane game 3d, plane game 3d.
- US: P1 18/20, P2 13/26. Same P1 gaps.

Keyword history: `online` removed (see §0); `offline` added (IN hint "aeroplane games offline", true for solo play); round 2 moved `air,combat` into the name and spent the bytes on `shooting` (India) and `sky,pvp` (US).

| Field | Text | Length |
|---|---|---|
| Name | `Toy Plane Dogfight: Air Combat` | 30/30 |
| Subtitle (IN, en-GB) | `Aeroplane fights with friends` | 29/30 |
| Subtitle (US, en-US) | `Airplane fights with friends` | 28/30 |
| Keywords (IN) | `airplane,war,fighter,co-op,fighting,sky,flying,battle,jet,flight,offline,bomber,shooter,shooting` | 96/100 bytes |
| Keywords (US) | `aeroplane,war,fighter,multiplayer,co-op,fighting,flying,battle,shooting,flight,offline,sky,pvp` | 94/100 bytes |
| Promotional text | Share a 5-character room code and your friends fly in one sky. Friends busy? Fight AI pilots on Rookie, Pilot or Ace. No ads, no energy timers. | 143/170 |

US keywords swap "airplane" for "aeroplane", because the US subtitle already has "airplane". "aeroplane" still hints #1 in the US once typed in full (MEASURED). The US description uses US spelling ("armor"); the validator now checks this per locale.

**Description** (2445/4000, `data/listing_A.json`; the en-US file differs only in "armor"):

```
Dogfight your friends in tiny cel-shaded toy planes. Host a room, share the code, and fight in the same sky. Friends busy? Take on AI pilots instead.

PLAY WITH FRIENDS
- Host a room and share its 5-character code.
- On the same Wi-Fi? Host on LAN and join by IP address.
- Shoot down the other team, or fly together against an AI squadron.
- Downed teammate? Fly through their beacon within 15 seconds to bring them back.
- Taunt in giant skywritten smoke letters: 24 preset messages like "Skill issue!" and "GG!". There is no open chat.

OR PLAY SOLO, NO INTERNET NEEDED
- AI pilots on Rookie, Pilot or Ace.
- Six AI personalities, from hotheads to snipers, with their own moves and radio chatter.
- AI wingmen fill your team in 2v2, 4v4 or 6v6 battles.

6 MODES
- Team Dogfight: friends against friends.
- Team Battle vs AI: you and your wingmen against an AI squadron.
- Capture the Flag: grab their flag, fly it home, first to 3.
- Base Assault: AI bombers raid both HQs. Strafe and bomb theirs, repair your own.
- Co-op Escort: protect 3 bombers through 8 waves of raiders.
- Free Flight: no rules, 20 balloons to pop.

TOY PLANES, REAL DOGFIGHTS
- 4 plane types: Toy Cub, Speedster, Heavy Twin and Jet Fighter, each restyled for every world.
- Guns, lock-on rockets, bombs and flares.
- Hits damage wings, engine and tail: a shot wing pulls you sideways, a hit engine sputters.

6 WORLDS
Green Valley, Volcanic Islands, Frozen Frontier, Desert Wasteland, Neon Metropolis and Sky Kingdom. Ride updrafts, fight through snowstorms and sandstorms, dodge lava bombs and lightning, and don't fall into the sea of clouds.

THE BATTLEFIELD
- Supply crates parachute in. Grab one to repair, then fly it home for team supplies.
- Spend supplies on AA guns, SAM sites and radar.
- Pop prize balloons for Twin Guns, Shield or a Rocket Swarm.

Original music, one tune per world.

FAIR BY DESIGN
- No ads.
- No energy timers, no coins, no loot boxes.
- Optional one-time purchases in the Hangar Shop: paint jobs, smoke trails and kill effects. They change looks only, never speed, damage or armour. Restore Purchases brings them back on a new device.
- No account and no sign-up.

GOOD TO KNOW
- Played in landscape.
- Online rooms connect phones directly to each other. Some mobile networks block direct connections; if a room won't connect, try Wi-Fi.
- Team Dogfight needs at least one human pilot on each team. The other modes can be played alone.
```

**Screenshot headlines (5-7).** Full storyboard in `screenshot-storyboard.md`; rendered frames in `creative/screens/`.
1. DOGFIGHT YOUR FRIENDS
2. SHARE A CODE. JUMP IN.
3. TAUNT THEM IN THE SKY
4. FRIENDS BUSY? FIGHT AI
5. LOCK ON. FIRE. FLARE.
6. 6 WORLDS, WILD WEATHER
7. LOOKS ONLY. NEVER PAY TO WIN.

Headline 4 used to read "NO ONE ONLINE? FIGHT AI". There is no public player pool (`rooms.gd:4-6`), so "online" suggests one the game doesn't have. `creative/screens/04_vs_ai.png` was re-rendered with the new headline on 2026-10-25 (MEASURED, checked by eye).

**Icon direction.** Concept 2, "Aerial duel" (`icon-concepts.md`): a blue toy plane chasing a red one, with tracers and a smoke trail. Use the Toy Cub rather than jets, so the icon says "toy" and "fight" at once.

**Risks.**
- **Connection failures (VERIFIED, `rooms.gd:7-8`).** No relay server ships; a TURN relay works only if the player enters their own credentials. Some strict mobile networks will fail to join a room. In the competitor reviews, connection/server complaints (27) and crashes (51) each outnumber the friends theme (11) (MEASURED, 843 reviews). A "friends" promise that fails to connect turns into 1-star reviews (HYPOTHESIS).
- **Every new room depends on free public MQTT brokers (VERIFIED, `rooms.gd:4-5,11`).** The offer/answer/ICE handshake for each new room travels over `broker.hivemq.com`, `broker.emqx.io` and `test.mosquitto.org`. None of them offers this game an SLA. Mosquitto's own page says the server "will often be running unreleased or experimental code" and that "websockets and TLS support are the most likely to be unavailable"; the game connects to it over `wss://` (VERIFIED, https://test.mosquitto.org/, fetched 2026-10-25). A running match survives a broker outage (`rooms.gd:9`), but while all three are down or blocked, nobody can start or join a room, and that breaks the headline promise.
- **8 phones in one room is untested.** `MAX_PLAYERS = 8` is the code limit (VERIFIED, `main.gd:4`). The host makes every offer (star topology, `rooms.gd:6`), so one phone carries all 7 peer links. Whether a mid-range phone on mobile data holds that for a full match is **unknown**.
- **Team Dogfight needs a human on each team (VERIFIED, `main.gd:909-911`).** A solo player who picks it gets no match. The description says so, and headline 4 points solo players to the AI modes.
- **Empty-room problem.** No public lobbies or random matchmaking (VERIFIED, `rooms.gd:4-6`). A player with no friends who own the game falls back to AI. The promise has to keep saying "or fight AI", or the page sells something a lone player can't use (HYPOTHESIS).
- **Name changes are slow to test.** The name and subtitle change only with a new app version. PPO tests icon and screenshots only (VERIFIED, apple-requirements.md §7).

**Checks before A's listing ships (all three required).**
1. **Join success on Indian mobile data.** TestFlight round: host on one phone, join from another, 10 attempts each on Jio data and on Airtel data, plus Wi-Fi as a control. Record joins that reach the match. The failure rate is **unknown** today.
2. **Broker reachability on the same networks.** In the same round, record which of the three brokers the handshake used, and repeat with each broker blocked in turn, so you know whether the game still joins with only one broker up. Re-run the reachability part the week of launch.
3. **An 8-phone room.** TestFlight round with 8 phones in one room, mixing Wi-Fi and mobile data, host on a mid-range phone. Pass: all 8 join, and a full Team Dogfight match runs to the end with no peer dropped. Until it passes, no store text or screenshot says "8": A's promo text, the "Up to 8 pilots" lines in A, B and C's descriptions, and screenshot 02's subtitle "UP TO 8 PILOTS. NO ACCOUNT." (all removed in revision 3 of this file and revision 4 of the storyboard). If it fails, use the largest count that passed.

Decision rule (my threshold, HYPOTHESIS): switch from C to A only when check 1 reaches at least 9 of 10 joins on each carrier, a hosted broker (or a bundled TURN relay) replaces sole reliance on the three free brokers, and check 3 passes.

---

## Strategy B: "Arcade air war" (aerial combat action)

**Target player (HYPOTHESIS).** Players who search for fighter plane and war plane games, like Metalstorm and Sky Warriors, but want something lighter, quicker and without grind.

**Promise.** Fast arcade combat: lock on, fire rockets, flare off missiles, bomb their base.

**Proof (VERIFIED).**
- **Weapons:** lock-on rockets, held 0.6 s within a 20° cone, with a lock warning for the target (`plane.gd:20-24`, `plane.gd:450-461`). Flares (`plane.gd:25`, `plane.gd:429-433`). Bombs with an impact preview (`plane.gd:336`).
- **Damage:** part damage to wings, engine and tail (`planes.gd:4-6`).
- **Planes:** 4 classes with distinct stats (`planes.gd:8-13`).
- **Ground war:** Base Assault, plus AA guns, SAM sites and radar bought with team supplies (`objectives.gd`, `main.gd:3049-3058`, `battlefield.gd:165-166`).
- **Fixed base defences:** an uneven set from the Escort layout, 5 around the blue runway and 10 around the red runway and factory (`battlefield.gd:171-181`). They stand down in Capture the Flag and Base Assault, where every defence is one a team bought (`battlefield.gd:220-223`), and stay quiet in Free Flight (`battlefield.gd:207`). The copy therefore limits them to Co-op Escort, Team Dogfight and Team Battle vs AI.
- **AI:** six AI personalities with signature moves (`ai.gd:23-60`).

**Competitor evidence (MEASURED, 843 reviews).**
- Combat terms return combat games, not sims, so the searcher's intent matches the game.
- A Metalstorm reviewer asked for "Air to Ground attack modes. Like destroying a base while fighting enemy aircraft and SAM Missiles". Base Assault does this.
- Pay-to-win and grind: 21 review matches. Fuel and energy timers: 10.

**Keyword focus.** Combat and generic plane terms. The name no longer copies a competitor: "air" and "war" moved into the keyword field.
- Coverage (ESTIMATE, `tools/coverage.py`, 20 P1 / 26 P2): P1 18/20, P2 14/26. Missing P1: plane fighting game, games with friends.

| Field | Text | Length |
|---|---|---|
| Name | `Toy Plane: Fighter Battles` | 26/30 |
| Subtitle | `Arcade jet dogfights in 3D` | 26/30 |
| Keywords | `aeroplane,airplane,air,war,shooting,rocket,bomber,fight,combat,flying,flight,sky,pvp,shooter` | 92/100 bytes |
| Promotional text | Lock on, fire rockets, drop flares, bomb their base. Fast arcade dogfights in toy planes across 6 worlds, against AI aces or your friends. | 138/170 |

**Description** (2256/4000, `data/listing_B.json`):

```
Fast arcade air combat with toy planes. Lock on, fire rockets, pop flares, dive-bomb their base and get back in the fight.

LOCK ON AND FIRE
- Hold a target in your sights to lock on, then fire a homing rocket.
- Rocket on your tail? You hear the lock warning. Drop flares to shake it off.
- Hold to aim bombs at the exact impact point, then release.
- Hits damage wings, engine and tail: a shot wing pulls you sideways, a hit engine sputters, a hit tail turns slowly.

4 PLANES, 4 WAYS TO FIGHT
- Toy Cub: slow, tough, turns tight.
- Speedster: fastest, rolls hard, breaks easily.
- Heavy Twin: 6 rockets, 4 bombs, lots of armour.
- Jet Fighter: fast all-rounder with 4 homing rockets.
Every plane is restyled for each world. All four are ready from the first match.

AI THAT FIGHTS BACK
- Rookie, Pilot or Ace.
- Six AI personalities with signature moves: head-on passes, boom-and-zoom, scissors, split-S.
- AI pilots hold grudges, get nervous and call out on the radio.

TAKE THE GROUND TOO
- Base Assault: bomber raids hit both HQs. Strafe, bomb, and repair your own.
- Fixed AA defences guard the airfields in Co-op Escort, Team Dogfight and Team Battle vs AI.
- Buy AA guns, SAM sites and radar with team supplies.
- Capture the Flag, Co-op Escort, Team Battle vs AI and Team Dogfight.

WEATHER FIGHTS BACK
6 worlds. Thermals, crosswinds, snowstorms, sandstorms, lava bombs from the volcano, lightning over the neon city, and a sea of clouds that swallows planes.

SOLO OR WITH FRIENDS
- Battle AI squadrons alone, 2v2 up to 6v6, with no internet connection.
- Or host a room with a 5-character code, or play on LAN.
- Pop prize balloons for Twin Guns, Shield or a Rocket Swarm.

FAIR BY DESIGN
- No ads.
- No energy timers, no coins, no loot boxes.
- Optional one-time purchases in the Hangar Shop: paint jobs, smoke trails and kill effects. They change looks only, never speed, damage or armour. Restore Purchases brings them back on a new device.
- No account and no sign-up.

GOOD TO KNOW
- Played in landscape.
- Online rooms connect phones directly to each other. Some mobile networks block direct connections; if a room won't connect, try Wi-Fi.
- Team Dogfight needs at least one human pilot on each team. The other modes can be played alone.
```

**Screenshot headlines.**
1. LOCK ON. FIRE.
2. FLARES SHAKE THE ROCKET
3. BOMB THEIR BASE
4. DROP A SAM SITE
5. 4 PLANES, 4 WAYS TO FIGHT
6. THE WEATHER FIGHTS BACK
7. ROOKIE TO ACE AI

**Icon direction.** Concept 2, "Aerial duel", in its most aggressive form: two planes, tracers, a rocket smoke trail and possibly an explosion puff.

**Risks.**
- **Competition is strongest here.** For "air war" and "fighter plane game" the US top-5 median is 42,011 and 67,440 ratings, and India's is 2,086 and 1,940 (MEASURED). Metalstorm is #1 for "dogfight", "air combat" and "fighter plane" in both stores (MEASURED). A new app with 0 ratings starts at the bottom of those lists (HYPOTHESIS; ranking factors include downloads and ratings, VERIFIED apple-requirements.md §1.2).
- **Expectation mismatch.** "Fighter Battles" next to realistic jets may draw players who expect real aircraft, depth and progression. The game has no progression or unlocks (VERIFIED, game-audit.md §2), and the competitor field is 13/16 realistic military icons (MEASURED). The toy look could read as a downgrade to this audience rather than a feature (HYPOTHESIS).
- **The differentiator stays hidden.** Friends-by-code is pushed to the bottom of the description.
- **The earlier name copied a competitor.** The first B name, "Toy Plane Sim: Air War", repeated the title words of "Alliance: Air War" (Art of the State LLC), and the validator flagged it (Guidelines 2.3.7 and 4.1). The new name passes the same check against 48 competitor names and sellers.

---

## Strategy C: "No-ads arcade aeroplane game" (the launch listing)

The first C ("Toy-world flying": cute, calm, offline) was weak by construction: it sold a calm game that is combat in 5 of 6 modes. This C is built on the two biggest review themes instead and targets the head terms honestly.

**Target player (HYPOTHESIS).** Players in India who search the head terms ("aeroplane game", "plane game", "flying game"), mostly play alone, and are worn out by ads in hypercasual plane games. They want something simple that still has real dogfights.

**Promise.** An arcade aeroplane game with no ads. Fight AI with no internet, or friends by room code.

**Evidence it answers (MEASURED, `data/review_theme_counts.txt`, 843 reviews).**
- **Ads: 79 matches (9.4%)**, the biggest complaint theme, mostly in Epic Plane Evolution (35 across IN and US) and Sling Plane 3D (25), both hypercasual plane games. The ads regex was tightened after a hand check (`data/review_handcheck_v1.csv`).
- **"No ads" praise: 16.** Players notice and mention it when a game has none.
- **Fun/simple praise: 195 (23%).** This regex is broad (`fun`, `simple`, `addict`, `enjoy`, `love`), so it is general praise, not a measure of "simple" demand. It shows that players reward fun even in games they criticise, nothing more specific.
- None of the 20 US and 20 IN competitor descriptions says "no ads" or "ad-free" (MEASURED, regex over `lookup_us.json` and `lookup_in.json`). Three call themselves arcade: Bomber Ace, War Plane Strike and 1945 Air Force.
- Demand for "no ads" phrasing itself is **unknown**; it was not in the keyword universe. The subtitle uses it to convert, not to rank.

**Proof (VERIFIED).**
- **No ads** (`PRIVACY.md`); looks-only one-time purchases (`shop.gd`, `SUPPORT.md`).
- **Solo with no internet:** Free Flight and the vs-AI modes run on an offline peer (`main.gd:264-279`).
- **AI on Rookie/Pilot/Ace** fills seats in Team Battle vs AI, Capture the Flag and Base Assault (`main.gd:12`, `AI_MODES = [3, 4, 5]`).
- **Arcade combat:** guns, lock-on rockets, bombs, flares, power-up balloons (`plane.gd`, `battlefield.gd`).
- **Touch controls:** customisable layout (`touch.gd:4-7`).
- **Free Flight** is the mode name (`main.gd:10`); the shop's try button reads "TRY IT FREE IN FREE FLIGHT" (`shop_ui.gd:44`).

**Keyword focus.** Name and subtitle take "arcade", "air", "combat", "aeroplane", "battles", "ads". Keywords: airplane, fighter, war, dogfight, fight, flying, flight, offline, shooter, bomber, sky, jet, fighting, shooting.
- `offline` carries C's "no internet" promise; `friends` stays out (C's player is solo).
- Round 3 swapped `capture,flag` (P3 only) for `combat,fighting`, covering "plane fighting game", "air combat" and "air combat games". Round 2 then moved `air,combat` into the name and spent the bytes on `shooting` (and `sky` back in en-US).
- Coverage (ESTIMATE, `tools/coverage.py`, 20 P1 / 26 P2, 18:36 IST): P1 17/20, P2 14/26 in both stores. Missing P1: aeroplane game 3d, plane game 3d, games with friends.

**How different are A and C, really?** In search, barely: after round 2, 21 of the 24 indexed words in each are shared (MEASURED, word sets after plural folding over name, subtitle and keywords). Only A has co-op and friends; only C has arcade and "no ads". The FAIR BY DESIGN and GOOD TO KNOW blocks are identical on purpose: they are disclosures. So A versus C is a choice of page-level pitch (subtitle, promo text, description lead, screenshots, icon) over one keyword core. B is the only different keyword strategy (19 of its 23 words overlap C, but it trades friends/offline/dogfight for rocket, pvp and 3D).

| Field | Text | Length |
|---|---|---|
| Name | `Toy Plane Arcade: Air Combat` | 28/30 |
| Subtitle (IN, en-GB) | `Aeroplane battles with no ads` | 29/30 |
| Subtitle (US, en-US) | `Airplane battles with no ads` | 28/30 |
| Keywords (IN) | `airplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` | 98/100 bytes |
| Keywords (US) | `aeroplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` | 99/100 bytes |
| Promotional text | Arcade dogfights in toy planes. Fight AI pilots on Rookie, Pilot or Ace with no internet, or share a room code with friends. No ads, no energy timers. | 150/170 |

**Description** (2231/4000, `data/listing_C.json`; the en-US file uses "airplane" and "tires"):

```
An arcade aeroplane game with no ads. Pick a toy plane, take off and start shooting.

PICK UP AND PLAY
- Fight AI pilots on Rookie, Pilot or Ace. Solo modes need no internet connection.
- Free Flight: no rules, 20 balloons to pop. A good place to learn the controls.
- Touch controls you can move and resize, with tilt steering, auto-fire, left-handed layout and vibration options.

ARCADE AIR COMBAT
- Guns, lock-on rockets, bombs and flares.
- Hits damage wings, engine and tail: a shot wing pulls you sideways, a hit engine sputters.
- Pop prize balloons for Twin Guns, Shield or a Rocket Swarm.
- 4 planes: Toy Cub, Speedster, Heavy Twin and Jet Fighter. All four are ready from the first match.

6 MODES
- Team Battle vs AI: you and your wingmen against an AI squadron, 2v2 up to 6v6.
- Capture the Flag: grab their flag, fly it home, first to 3.
- Base Assault: AI bombers raid both HQs. Strafe and bomb theirs, repair your own.
- Co-op Escort: protect 3 bombers through 8 waves of raiders.
- Team Dogfight: friends against friends.
- Free Flight.
AI pilots fill empty seats in Team Battle vs AI, Capture the Flag and Base Assault.

6 TOY WORLDS
Green Valley, Volcanic Islands, Frozen Frontier, Desert Wasteland, Neon Metropolis and Sky Kingdom. Every plane is restyled for each world: floats on the volcanic islands, skis in the snow, fat tyres in the desert.

PLAY WITH FRIENDS WHEN YOU WANT
- Host a room with a 5-character code, or play on LAN.
- Taunt in giant skywritten smoke letters: 24 preset messages like "Nice flying!" and "GG!". There is no open chat.

Original music: one tune for each world.

FAIR BY DESIGN
- No ads.
- No energy timers, no coins, no loot boxes.
- Optional one-time purchases in the Hangar Shop: paint jobs, smoke trails and kill effects. They change looks only, never speed, damage or armour. Try any look in Free Flight before you buy it. Restore Purchases brings them back on a new device.
- No account and no sign-up.

GOOD TO KNOW
- Played in landscape.
- Online rooms connect phones directly to each other. Some mobile networks block direct connections; if a room won't connect, try Wi-Fi.
- Team Dogfight needs at least one human pilot on each team. The other modes can be played alone.
```

**Screenshot headlines.**
1. NO ADS. JUST DOGFIGHTS.
2. FIGHT AI: ROOKIE TO ACE
3. LOCK ON. FIRE. FLARE.
4. POP BALLOONS FOR POWER-UPS
5. 6 TOY WORLDS
6. PLAY SOLO, NO INTERNET
7. FRIENDS? SHARE A CODE

The rendered set in `creative/screens/` is A's. Frames 04 (AI battle), 05 (lock-on), 06 (worlds) and 07 (shop) carry over to C with new headline text. C's first frame now exists (`creative/screens/c01_no_ads.png`, MEASURED, on disk). The balloon/power-up frame still needs a capture (`tools/capture_scenes.gd` scene) and a compose entry (`tools/compose_screens.gd`), and frames 2-7 need C's headlines: a **launch blocker** (Short version).

**Icon direction.** Revised 2026-10-25: launch with Concept 2, "B duel" (`icon-concepts.md`, `creative/icons/B_duel.png`), because "battles" is C's subtitle promise too and B is the only concept that shows a fight; Concept 1, "Hero toy plane", is the first PPO treatment. Both need the render fixes listed in `launch-action-plan.md` first (HYPOTHESIS: no conversion data).

**Risks.**
- **"Arcade" may suggest one-tap hypercasual.** The controls are full 3D flight with throttle, steering and weapons (VERIFIED, `touch.gd`). Players arriving from Sling Plane 3D may find it harder than they expected (HYPOTHESIS). Mitigation: Free Flight and Rookie AI are named early in the description.
- **"No ads" is easy to copy and hard to search.** Any competitor can add it, and its search demand is unknown. It works only on the product page.
- **Head-term competition.** "aeroplane game" and "plane game" have medium IN competition (1,938) and high US competition; the top results are flight sims (MEASURED). The game ranks against them with 0 ratings (HYPOTHESIS that it starts low).
- **Friends play is still the differentiator nobody else has.** C keeps it in the description and promo text but not in the name, subtitle or keywords.

---

## Comparison

| | A: Dogfight your friends | B: Arcade air war | C: No-ads arcade aeroplane game |
|---|---|---|---|
| Name / subtitle (India) | Toy Plane Dogfight: Air Combat / Aeroplane fights with friends | Toy Plane: Fighter Battles / Arcade jet dogfights in 3D | Toy Plane Arcade: Air Combat / Aeroplane battles with no ads |
| P1 terms covered, of 20 (ESTIMATE, `tools/coverage.py`, round 2) | 18 (IN and US) | 18 | 17 (IN and US) |
| P2 terms covered, of 26 | 16 (IN), 13 (US) | 14 | 14 (IN and US) |
| Lead term, IN / US top-5 median ratings and IN autocomplete (MEASURED) | dogfight: 34 (low) / 3,279 (medium); autocomplete 1 | fighter plane game: 1,940 (medium) / 67,440 (high); autocomplete 3 | aeroplane game: 1,938 (medium) / 28,382 (high); autocomplete 3 |
| Headline differentiator | rooms by code + LAN + AI fill | lock-on, flares, SAMs, base assault | no ads, arcade fights, solo with no internet |
| Review themes it answers (MEASURED, of 843) | friends/rooms 11, matchmaking/bots 15, timers 10 | pay-to-win 21, timers 10, air-to-ground request 1 | ads 79, no-ads praise 16, timers 10 |
| Review themes that cut against it (MEASURED, of 843) | connection/server 27, crash 51 | none specific | none specific |
| Competitors already making the same promise (MEASURED) | some: Metalstorm, War Thunder Mobile and Air Combat Online mention friends in their US descriptions. Wings of Heroes says "fly with friends" on its first screenshot. None of the 20 US descriptions mentions a room code, LAN, local play or Wi-Fi | many: Metalstorm, Sky Warriors, War Thunder Mobile, Alliance | none says "no ads"; 3 say "arcade" |
| Delivery risk of the headline | high: P2P with no bundled relay, free public brokers, 8-phone room untested | low | low: solo play is offline |
| Honesty risk | medium: connection failures on strict networks | medium: "Fighter Battles" implies depth and progression | low-medium: "arcade" may read as one-tap |
| Rendered frames that fit (in `creative/screens/`) | 7 | 2 (05 lock-on, 07 shop) | c01 "no ads" plus 04, 05, 06, 07 with new headlines |
| New captures needed | none | flares, bombing, SAM, base assault | balloons/power-ups (launch blocker) |

## Recommendation: ship C; switch to A when it passes its checks

**Ship Strategy C (`listing_C.json`, `listing_C_en-US.json`) at launch.** The evidence points there:

1. **C answers the largest measured themes (MEASURED, 843 reviews, 19 page-1 feeds, regex themes, `data/review_theme_counts.txt`).** Ads is the largest complaint at 79 (9.4%), and 16 reviews praise a game for having none. **But 60 of the 79 come from two hypercasual apps (Epic Plane Evolution 35, Sling Plane 3D 25) and 9 from Airline Commander; the combat apps C competes with for "aeroplane game" and "fighter plane game" (Metalstorm, Sky Warriors, War Thunder Mobile, Air Wings) have 0 ads complaints** (MEASURED, `data/review_theme_counts.txt`). So "no ads" differentiates C against the hypercasual results in those searches; that it matters to combat searchers is a HYPOTHESIS. The main reason left for C over A is delivery risk (point 2), not measured demand. A's themes are smaller: friends/private rooms 11 (1.3%) and matchmaking/bots 15 (1.8%). A review can match more than one theme.
2. **C's headline can't fail on a network.** Its promise (no ads, solo with no internet) is true on every phone (VERIFIED, `PRIVACY.md`, `main.gd:264-279`). A's promise rests on P2P with no bundled relay (`rooms.gd:7-8`) and on three free public MQTT brokers, one of which documents itself as running experimental code (VERIFIED, `rooms.gd:11`, https://test.mosquitto.org/). Against A, connection/server complaints (27) and crashes (51) already outnumber the friends theme (11) in competitor reviews (MEASURED).
3. **Search coverage is close to a tie.** C covers 17 of 20 P1 terms, A 18 (ESTIMATE, round 2). The extra term A covers is "games with friends", which is broad and hints at many genres (keyword-research.md). Neither has search volume data.
4. **Every line maps to code**, and C's one honesty risk ("arcade" read as one-tap) is handled in the description's first block.

**C cannot ship until its two blockers clear:** the in-game rename (Decision 1) and the missing balloon frame plus C headlines (Strategy C, screenshot headlines).

**Why A is still the switch-to listing, and why it isn't first.** A's promise is the one nobody else makes: no competitor description mentions a room code, LAN or local play (MEASURED). That is a differentiation argument. The other reasons A led in the first revision were the existing draft subtitle ("Dogfight friends in toy planes") and the storyboard and icon work already built around it. Those are sunk cost, not evidence, so they no longer decide the order.

**Switch to A when all three hold** (thresholds are my judgement, HYPOTHESIS):
- At least 9 of 10 TestFlight joins succeed on Jio data and on Airtel data (check 1 in Strategy A).
- Rooms no longer depend only on the three free brokers: a hosted broker, or a bundled TURN relay, ships in the game (a code decision outside this folder).
- An 8-phone room holds a full match (check 3 in Strategy A). Until then, no listing says "up to 8 pilots".

The switch changes name, subtitle and keywords, so it needs a new app version (VERIFIED, apple-requirements.md §7).

Borrow from the others:
- **A's friends set as a Custom Product Page** for players arriving from links friends share and from social ads. A CPP can carry its own screenshots, promo text and keywords (VERIFIED, apple-requirements.md §8). The rendered A frames in `creative/screens/` fit it now.
- **B's combat set as a Custom Product Page** for "air combat / fighter plane" traffic.

**What would change this recommendation:**
- The three checks pass → ship A in the next version.
- Launch data (App Store Connect impressions → product page views → downloads, by source) shows most installs come from shared links or "friends" terms, or most sessions are multiplayer → move to A sooner.
- Search traffic arrives mostly on combat terms → test B's screenshots in PPO. That test changes only the icon and screenshots.

## Localization opportunities

| Opportunity | Evidence | Action |
|---|---|---|
| **en-GB for India** | India's default App Store language is English (U.K.) (VERIFIED, Apple localization table) | Ship `listing_C.json` as the en-GB localization: "Aeroplane" in the subtitle, British spellings ("armour", "tyres"). |
| **en-GB is also the global English default** | More than 100 storefronts default to English (U.K.), including the UK, Ireland, Indonesia, Singapore, Malaysia, the Philippines, Pakistan, Nigeria and South Africa (VERIFIED, same table, fetched 2026-10-25) | At the global rollout, the India en-GB text becomes the listing for all of them. Write it for that audience, not for India alone; "aeroplane" is also UK and Irish spelling. |
| **en-US for the US** | US default English (U.S.) | `listing_C_en-US.json` (and `listing_A_en-US.json` for the switch): "Airplane" subtitle; "aeroplane" moves to keywords; US spelling in the description. The validator now WARNs on British spellings in en-US text and US spellings in en-GB text (keywords exempt). |
| **Whether India also indexes the en-US keywords** | unknown: Apple does not document per-storefront indexing (apple-requirements.md §9) | Don't rely on it. Treat each storefront as having one keyword field. |
| **Additional locales as extra English keyword fields** (HYPOTHESIS, to test) | Each additional locale has its own name, subtitle and 100-byte keyword field. India's additional languages include Hindi; the US's include Spanish (Mexico) (VERIFIED, Apple table, fetched 2026-10-25). Whether a storefront indexes an additional locale's fields for searches typed in English is **unknown**: Apple doesn't document it, and this folder has not measured it. | Test after launch, one storefront at a time: add a Hindi (India) or Spanish (Mexico) localization whose keyword field holds English terms the default field couldn't fit (for example `3d,fighting,combat,coop,pvp,multiplayer`), with a correct name and subtitle in that language. Then check with `tools/fetch_search.py` whether the app starts appearing for those terms in that storefront. Risks: text in the wrong language for that locale may draw a review objection (Guideline 2.3, HYPOTHESIS), and Hindi or Spanish speakers would see a product page for an English-only game. Keep the description honest ("English only"). |
| **Hindi (hi) metadata in Hindi** | Hindi is an App Store localization and an additional language for India (VERIFIED). The game UI is English only (no localization files found in the audit; HYPOTHESIS). Hinglish romanized terms ("jahaj game", "hawai jahaj") showed no autocomplete and 1-5 IN results (MEASURED). Devanagari queries were **not tested**. | **Later, not at launch.** Test autocomplete for "हवाई जहाज", "लड़ाकू विमान" and "जहाज गेम" with the IN storefront header first (`tools/fetch_hints.py` takes any term). A Hindi keyword field fits only about 33 Devanagari letters (VERIFIED arithmetic, apple-requirements.md §1.1). Hindi product-page text on an English-only game may mislead; say "English only" in the Hindi description if it is ever added (HYPOTHESIS). |
| **India-specific words in the en-GB fields** | "indian plane game" appears in IN autocomplete (MEASURED). | Do **not** add "indian" or "india": the game has no Indian aircraft or setting (VERIFIED, `planes.gd`), and the IN results for these terms are IAF-themed. Revisit only if India-themed content is added; Metalstorm India reviewers asked for the Tejas twice (MEASURED). |
| **India copy tone** | Competitor reviews in India cite ads, "connect to internet" errors and price ("gta 5 bhi 1700 puri game mil jaati") (MEASURED) | Keep "No ads", "play solo with no internet" and "one-time purchases" high in the en-GB description and promo text. Don't put ₹ amounts in the description (Guideline 2.3.7, apple-requirements.md). |
| **Other Indian languages** (Tamil, Telugu, Bangla, …) | Available for India (VERIFIED). No term data collected (unknown). | Not before Hindi shows a signal. |

## Appendix: validator runs (MEASURED)

Run 2026-10-25 18:36 IST from the repo root: `python3 aso/tools/validate_metadata.py aso/data/listing_X.json`. All exit 0 with 0 FAIL. The one WARN per listing is the intended "device name" launch-blocker check (Decision 1). 50 competitor names (brands plus sellers from the current `data/competitors.json`) and 28 banned terms (now including `up to 8`).

```
# listing_A.json  (exit 0)
PASS  name              30/30 chars, 30 bytes
PASS  subtitle          29/30 chars, 29 bytes
PASS  promotional_text  143/170 chars, 143 bytes
PASS  description       2445/4000 chars, 2445 bytes
SKIP  whats_new         empty (optional)
PASS  name+subtitle     no repeated words
PASS  keywords          96/100 chars, 96/100 UTF-8 bytes
WARN  device name       store name 'Toy Plane Dogfight: Air Combat' differs from project.godot config/name 'Toy Plane Sim' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close

PASS: 0 fail, 1 warn, 50 competitor names, 28 banned terms checked

# listing_A_en-US.json  (exit 0)
PASS  name              30/30 chars, 30 bytes
PASS  subtitle          28/30 chars, 28 bytes
PASS  promotional_text  143/170 chars, 143 bytes
PASS  description       2444/4000 chars, 2444 bytes
SKIP  whats_new         empty (optional)
PASS  name+subtitle     no repeated words
PASS  keywords          94/100 chars, 94/100 UTF-8 bytes
WARN  device name       store name 'Toy Plane Dogfight: Air Combat' differs from project.godot config/name 'Toy Plane Sim' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close

PASS: 0 fail, 1 warn, 50 competitor names, 28 banned terms checked

# listing_B.json  (exit 0)
PASS  name              26/30 chars, 26 bytes
PASS  subtitle          26/30 chars, 26 bytes
PASS  promotional_text  138/170 chars, 138 bytes
PASS  description       2256/4000 chars, 2256 bytes
SKIP  whats_new         empty (optional)
PASS  name+subtitle     no repeated words
PASS  keywords          92/100 chars, 92/100 UTF-8 bytes
WARN  device name       store name 'Toy Plane: Fighter Battles' differs from project.godot config/name 'Toy Plane Sim' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close

PASS: 0 fail, 1 warn, 50 competitor names, 28 banned terms checked

# listing_C.json  (exit 0)
PASS  name              28/30 chars, 28 bytes
PASS  subtitle          29/30 chars, 29 bytes
PASS  promotional_text  150/170 chars, 150 bytes
PASS  description       2231/4000 chars, 2231 bytes
SKIP  whats_new         empty (optional)
PASS  name+subtitle     no repeated words
PASS  keywords          98/100 chars, 98/100 UTF-8 bytes
WARN  device name       store name 'Toy Plane Arcade: Air Combat' differs from project.godot config/name 'Toy Plane Sim' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close

PASS: 0 fail, 1 warn, 50 competitor names, 28 banned terms checked

# listing_C_en-US.json  (exit 0)
PASS  name              28/30 chars, 28 bytes
PASS  subtitle          28/30 chars, 28 bytes
PASS  promotional_text  150/170 chars, 150 bytes
PASS  description       2229/4000 chars, 2229 bytes
SKIP  whats_new         empty (optional)
PASS  name+subtitle     no repeated words
PASS  keywords          99/100 chars, 99/100 UTF-8 bytes
WARN  device name       store name 'Toy Plane Arcade: Air Combat' differs from project.godot config/name 'Toy Plane Sim' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close

PASS: 0 fail, 1 warn, 50 competitor names, 28 banned terms checked
```

The listing text lives in `data/listing_*.json`; edit those files and re-run the validator and `tools/coverage.py`. Validator changes in this revision:
- **Locale spelling check.** en-US text (name, subtitle, promo, description, what's new) WARNs on British forms (armour, colour, tyre, defence, centre, favourite, aeroplane); en-GB text WARNs on US forms (armor, color, defense, center, favorite). The keyword field is exempt, because it crosses spellings on purpose. It caught nothing after the fixes; a copy of the old en-US file with "armour" WARNs.
- **Field-scoped banned terms.** `banned_terms.txt` takes an optional 4th column, a space-separated list of fields. `online` is a `warn` term scoped to `keywords`, with the reason (no public lobby or matchmaking, `rooms.gd:4-6`), so the honest "Online rooms connect phones directly" line in the description doesn't trip it. `multiplayer` is not flagged: rooms by code are real multiplayer.
- Earlier changes kept: the "Free Flight" mode name is whitelisted before the price check; promotional text gets the price and superlative checks; the superlative check matches only "world's"; competitor title words ("air war" from "Alliance: Air War") WARN in the name and subtitle.

## Round 2 changes

Resolves the latest strategy critique (r3) and re-checks the earlier ones (2026-10-25, 18:36 IST).
- **"up to 8" (r3 #1):** gone from A, B and C (promo text and descriptions); `banned_terms.txt` WARNs on it. Re-checked: no listing contains it.
- **Name mismatch (r3 #2):** a launch blocker in the Short version, Decision 1, the Recommendation and `launch-action-plan.md` step 1, with the verified locations (`project.godot:13`, `export_presets.cfg:41`, `main.gd:2427-2428`, `PRIVACY.md`, `SUPPORT.md`). The validator WARNs while the store name does not start with `config/name`.
- **C keywords (r3 #3):** `capture,flag` replaced; "plane fighting game", "air combat" and "air combat games" are covered.
- **Search term in the name (r3 #4): adopted.** C is now `Toy Plane Arcade: Air Combat` (28/30) and A `Toy Plane Dogfight: Air Combat` (30/30). `air,combat` left the keyword fields; the bytes went to `shooting` (C, A India) and `sky,pvp` (A US). Coverage (ESTIMATE, `tools/coverage.py`): C P2 13 to 14 (IN) and 11 to 14 (US); A P2 15 to 16 (IN) and 10 to 13 (US); P1 unchanged (C 17/20, A 18/20). `Toy Plane: Air War Arcade` stays rejected (competitor-title WARN).
- **"No ads" evidence (r3 #5):** Recommendation point 1 reports that 60 of 79 ads matches come from two hypercasual apps and that the combat competitors have 0; "no ads" for combat searchers is a HYPOTHESIS, and delivery risk is the main reason for C.
- **Three strategies (r3 #6):** reframed as two keyword strategies (A/C core, B combat) and two page pitches over the core (Short version, "How different are A and C").
- **C hero frame (r3 #7):** `c01_no_ads.png` exists; the balloon frame and C headlines are a named launch blocker.
- **"nothing to interrupt you" (r3 #8):** removed from C; C now leads with "no ads".
- **Housekeeping:** stale P1/P2 counts (of 21/22) replaced with the 20/26 figures everywhere; description lengths and the validator appendix re-run; the `3d` note fixed for the new byte counts.
- **Feature claims re-checked against code:** `MAX_PLAYERS := 8` (`main.gd:4`), `AI_MODES := [3, 4, 5]` (`main.gd:12`), menu title (`main.gd:2427-2428`). "Air Combat" in the names describes guns, rockets, bombs and flares the game has. No new feature claim was added.

