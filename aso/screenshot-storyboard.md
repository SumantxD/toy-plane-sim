# Screenshot storyboard: Strategy A, "Dogfight your friends"

For the recommended strategy in `positioning.md`. Labels: VERIFIED (code or Apple page), MEASURED (looked at or counted), ESTIMATE, HYPOTHESIS. No conversion data exists for this app, so the frame order is a HYPOTHESIS to test with Product Page Optimization after launch, not a known result.

## Format

- **Orientation and size.** Landscape, real gameplay captures with a headline on top.
  - Upload 2868x1320 (the existing set) **and** 2622x1206, because Apple's page is unclear on whether the large size covers the required medium one (apple-requirements.md §2).
  - No alpha channel. Up to 10 per size. **Upload order (round 2, shipped): 01, 02, 03, 04, 06, 07** (6 frames; 05 is dropped, see fix pass 3).
- **Must be the real game (Guideline 2.3.3/2.3.4, VERIFIED).** Every frame below is a real capture from the game. Headlines go in a band over the capture and never over the HUD or the plane.
  - Competitor reviews flag store art that doesn't match the game 15 times (MEASURED). That is the reason to stay literal.
- **Headline style (ESTIMATE).**
  - Headline font (round 2): the game's menu font (`ThemeDB.fallback_font`) emboldened, glyph spacing -2, capped at 75% of the frame width (`compose_screens.gd` `head_font`, `HEAD_W`) (VERIFIED in code). `kenney_future_narrow.ttf`, the skywriting font, is used only on 03 and first_alt_1 (`sky = true`), where it echoes the letters in the sky.
  - Sub-line font: the game's menu font (`ThemeDB.fallback_font`, the one the shop's "Looks only" line uses), emboldened, in sentence case (VERIFIED in code).
  - Headline 184 px, sub-line 100 px, white / accent text with a heavy navy outline and drop shadow, set straight on the capture. Behind them, one see-through navy gradient, the same on every frame: 72% at the top edge, 45% at y = 235, clear by y = 470 (MEASURED, `compose_screens.gd` `_scrim`). No solid band.
  - No brand badge (the `_badge` code is deleted in round 2). One accent per theme: cyan on multiplayer frames (01, 02, 03, first_alt_1, first_alt_2, ppo_in_aeroplane), amber on solo, worlds and shop frames (04, 06, 07, first_alt_3, c01).
  - On a phone a landscape shot is about 350 pt wide, roughly 1/8 scale (ESTIMATE from the critique). So the headline shows at about 23 pt and the sub-line at about 12 pt. Checked on `creative/contact_sheet_350.png` (see "Readability" below).
- **First frame carries the whole pitch (HYPOTHESIS).** In search results, a landscape app usually shows only its first screenshot. Not verified for the current App Store layout.
- **Copy per storefront.** Frames are the same in India (en-GB) and the US (en-US). Frame 1's sub-line is a fact, "Online or LAN. Join by room code.", so it doesn't differ by storefront. The India keyword lives in the PPO headline variant `ppo_in_aeroplane.png` ("AEROPLANE DOGFIGHTS WITH FRIENDS"), not in a sub-line.

## Fix before any capture (found in game-audit.md)

| Problem | Where | Effect on screenshots |
|---|---|---|
| Keyboard hint "M hide N zoom" under the minimap on the phone build | `main.gd:2325` (VERIFIED) | Visible in existing shots 1-3 (MEASURED). It looks like a desktop port. |
| Pilot named "Ace" | `tools/appstore_shots.gd:48` sets `Settings.values.name = "Ace"` (VERIFIED) | Reads as the AI difficulty name in the lobby shot. Use a plain pilot name. |
| AI callsigns are Top Gun names (Maverick, Goose, Iceman, Viper) | `main.gd:16` (VERIFIED) | "Maverick" and "Viper" tags appear in shot 1 (MEASURED). Keep them illegible or out of frame, or change the callsign list. Third-party film marks don't belong in store art (HYPOTHESIS, apple-requirements.md §6; Guidelines 2.3.7 and 5.2). Checked 2026-10-25 on every revision-3 frame: no Top Gun callsign is visible; 05 shows only capture-time names in small tags (Nimbus, Mango, Dash, Biscuit) (MEASURED, by eye). **Resolved in round 2:** `main.gd:16` now holds original names (Biscuit, Comet...); 04 and 05 were re-captured with them (VERIFIED). |

These are game-code edits, which this folder does not make. They are listed for the developer.

## The frames (planned 7, shipped 6)

The Status column gives the shipped state as of round 2, fix pass 3. The frame-by-frame record of the files is under "Produced set".

| # | Selling point | Headline (sub-line) | Real scene to capture | Status |
|---|---|---|---|---|
| 1 | You fight your friends, not bots | **DOGFIGHT YOUR FRIENDS** (IN: *Aeroplane fights with friends* / US: *Airplane fights with friends*) | Team Dogfight in Volcanic Islands or Green Valley. Chase camera close behind a blue Toy Cub firing at a red plane 100-200 m ahead, with tracers visible. The red plane's name tag should show a human pilot name. Capture it from a real 2-instance LAN match (`HOST ON LAN`, `main.gd:2465`), so the "friends" claim is literally what is on screen. | **Shipped** (`01_dogfight_friends.png`): 4-instance LAN capture, red plane tagged "Dev". |
| 2 | Joining is one code | **SHARE A CODE. JUMP IN.** (*No account. No sign-up.*) | Online lobby after `HOST ONLINE`: the "ROOM CODE: XXXXX" label (`main.gd:2028`), the COPY ROOM CODE button (`main.gd:2541`), and both squads listing 3-4 human pilots. The code shown is whatever the game generates; don't retouch it. | **Shipped** (`02_room_code.png`): real room code DR6UW and roster on the left; on the right a LAN dogfight in Sky Islands (jet vs red biplane tagged "Riya"), so it no longer repeats 01's world and plane. |
| 3 | Social and playful, no open chat | **TAUNT THEM IN THE SKY** (*24 skywritten taunts*) | Skywritten taunt in big smoke letters, ideally "GG!" or "SKILL ISSUE!" (`taunts.gd:9,13`) with an enemy plane in view. | **Shipped** (`03_skywriting.png`): "SKILL ISSUE!" over the volcano, current build. |
| 4 | Works alone too | **FRIENDS BUSY? FIGHT AI** (*Rookie, Pilot or Ace*) | Team Battle vs AI 6v6 in Desert Wasteland: one red AI plane close ahead, staged like frame 1. AI radio muted, so no mirrored skywritten line. | **Shipped** (`04_vs_ai.png`): red AI biplane ahead over the desert, toy callsigns. |
| 5 | Real combat depth | ~~LOCK ON WITH HOMING ROCKETS~~ | Planned: lock ring on a nearer, side-on red plane with a rocket smoke trail heading for it. | **Dropped from the upload set** (fix pass 3). No take caught a rocket in flight, and the locked target was about 70 px wide at 1400 px. Old files are in `creative/takes/dropped_05/`. Bring it back only with a store-grade rocket or bomb frame. |
| 6 | Variety | **6 WORLDS, WILD WEATHER** (*Lava, snowstorms, lightning*) | Three real captures side by side: a Volcanic Islands eruption with lava bombs, a Frozen Frontier snowstorm, and a Neon Metropolis lightning strike (`worlds/volcano.gd:48-50`, `worlds/frozen.gd:39-42`, `worlds/metro.gd:31-33`). Thin dividers, no added effects. | **Shipped** (`06_worlds.png`): volcano, frozen and metro slices, a different plane type in each. |
| 7 | Fair, no pay-to-win | **LOOKS ONLY. NEVER PAY TO WIN.** (*One-time purchases. No ads, no timers.*) | Hangar Shop. The in-game line "Looks only: nothing here changes speed, damage or armour" is on screen (`shop_ui.gd:28`), with the Golden Ace Set and its gold trail. | **Shipped** (`07_no_pay_to_win.png`, headline NEVER PAY TO WIN / Looks only. No ads. No timers.): full-bleed Golden Ace Toy Cub. |

Why this order (HYPOTHESIS):
- **Frames 1-3 make the friends promise.** 4 of the 7 competitors that headline their first screenshot sell multiplayer or friends (MEASURED).
- **Frame 4 answers the first doubt** a lone visitor has.
- **Frame 6 proves there is a real game underneath** (5 is dropped; frame 8, CTF or Base Assault, is still open).
- **Frame 7 answers the review themes:** pay-to-win (18 matches) and timers (13) (MEASURED).

### Capture notes

`tools/appstore_shots.gd` already has these building blocks (VERIFIED):
- `_fly(world, mode)`: solo battle, then set world, mode and start.
- `send_taunt(i)`.
- `shop_ui.open(id)`.
- touch FIRE through an `InputEventScreenTouch`.

Frames 4, 5 and 6 can be scripted the same way, with `_fly(3, 3)`, `_fly(4, 3)` and world indices 1, 2 and 4. A new capture script belongs in `aso/tools/`, to avoid editing the game's tool. Frames 1 and 2 involve real network play: run two game instances (or two phones) and capture by hand, or script the host side and join from a second instance. Planned, not done here.

Run the capture with:

```
godot --path /Users/sumant.tirkey/Desktop/steam-start/plane-sim --resolution 2868x1320 -s <script> -- --phone --fake-store
```

Then `sips -z 1206 2622` for the second set, after checking the aspect ratio: 2868/1320 = 2.173 and 2622/1206 = 2.174 (MEASURED arithmetic), so plain resizing works.

## 3 alternative first-screenshot concepts (for PPO tests after launch)

PPO changes only the icon, screenshots and previews, runs up to 3 treatments, and needs the app to be live (VERIFIED, apple-requirements.md §7).

| Alt | Concept | Headline | Real scene | What it tests (HYPOTHESIS) |
|---|---|---|---|---|
| **X: Skywriting hero** | Lead with the most unusual visual instead of combat | **TAUNT YOUR FRIENDS IN THE SKY** | Existing `2-taunt.png`, re-captured after the hint fix, with "GG!" written across the sky above a dogfight | Whether a unique, playful image beats a generic combat image. No competitor shows anything like it (MEASURED, competitor-research.md §5). |
| **Y: Code + combat split** | Show the mechanism and the payoff together | **ONE CODE. ONE SKY.** | Left third: the real lobby with "ROOM CODE" (frame 2 capture). Right two thirds: the frame 1 dogfight | Whether explaining *how* friends join converts better than showing the fight alone. Relevant to the Air Wings "nobody is online" complaint (MEASURED). |
| **Z: World strip** | Lead with the toy look and variety | **TOY PLANE DOGFIGHTS** (shipped as `first_alt_3.png`) | 4 narrow real captures (volcano, frozen, desert, metro), each with a plane in it | Whether the stylized look is the stronger hook against 13/16 realistic military combat icons (MEASURED), at the cost of the friends message. This is Strategy C's lead, tested inside A. |

For India, test also an en-GB variant of the default frame 1 with the headline **AEROPLANE DOGFIGHTS WITH FRIENDS** (produced as `screens/ppo_in_aeroplane.png`). It mirrors the IN autocomplete wording, "aeroplane games" #1 from `aer` (MEASURED). Whether matching the search wording on the image lifts conversion is unknown.

## What not to show

- Any "for kids" framing, other platforms (PC/Mac builds), or Apple device frames with Apple marks (Guidelines 2.3.8 and 2.3.10, apple-requirements.md §5-6).
- Prices or "free" on the images (Guideline 2.3.7).
- Numbers the game doesn't have: "24 planes", "12v12", "worldwide matchmaking", "ranked" (game-audit.md §3).
- Retouched effects: explosions, extra planes or particles added after capture.

## PPO plan after the critique (HYPOTHESIS)

- **Most likely default winner: the skywriting frame** (`03_skywriting.png`, or `first_alt_1.png` with "LET'S GO!"). Giant smoke letters over a volcano read in under a second at 600 px wide, and no competitor shows anything like it (competitor-research.md §5). This is a judgement from looking at the set, not data.
- **Test order.** Treatment A: `first_alt_1.png` as frame 1. Treatment B: `ppo_in_aeroplane.png` (India keyword headline). Treatment C: `first_alt_2.png` (code + fight). The control is `01_dogfight_friends.png`.
- **Frame 01 stays first for now.** The re-capture makes the fight read at 600 px (MEASURED by eye): a red plane trailing fire, banking just above and ahead of your blue plane. If PPO shows the skywriting frame converting better, swap 01 and 03.

## Revision 4 (25 Oct 2026, ~18:30 IST, completeness pass)

- **"8" removed from every frame.** 01, 02, first_alt_2 and ppo_in_aeroplane said "Up to 8 pilots" or "8 PILOTS", but `positioning.md` bars that claim until an 8-phone room passes. New text: 01 and ppo_in_aeroplane "Online or LAN. Join by room code."; 02 "No account. No sign-up."; first_alt_2 "ONE CODE. ONE SKY.". The India variant now reads "AEROPLANE DOGFIGHTS WITH FRIENDS" (the old wording was awkward English).
- **"TOY PLANE SIM" badge removed** from every frame (`compose_screens.gd`, opt back in with `badge = true` per entry). It contradicted the recommended store name "Toy Plane Arcade", and the product page already shows the name and icon.
- Re-composed and re-sized: 11 frames at 2868x1320 and 11 at 2622x1206, all RGB with no alpha (MEASURED, PNG header check). Viewed on `creative/contact_sheet_350.png`.
- **This set is Strategy A's.** The recommended launch listing is C (`positioning.md`). **C's frame 1 now exists:** `screens/c01_no_ads.png` (and `2622x1206/`), "NO ADS. JUST DOGFIGHTS." / "Fight AI with no internet, or friends by code.", from the same real LAN capture as 01 with the critique's tighter zoom `[1710, 650, 1.45]` (both planes fill the frame; viewed at 1400 px). Claims: no ads `PRIVACY.md:5`; offline solo `main.gd:264-279`; room code `main.gd:2028`. Still missing for C: the balloon/power-up frame (needs a capture) and C's headlines on frames 2-7. The open critique items (headline font, 05 re-stage, 01 zoom, 02 second capture, 07 empty panel, frame 8 for CTF/Base Assault) are listed there too.

## Produced set (25 Oct 2026, revision 3)

The file table below is kept current (fix pass 3); the bullets just below it are the revision-3 record. Every frame is a real game render from `aso/tools/capture_scenes.gd` (run with `--phone --fake-store` at 2868x1320). `aso/tools/compose_screens.gd` adds the text. Neither script edits game code, scenes or `builds/appstore/`.

- **Sizes (MEASURED with a stdlib PNG header check).** All 11 screens are 2868x1320. The same 11 are in `screens/2622x1206/` (`sips -z 1206 2622`, re-made after the last compose). All 22 are PNG colour type 2: RGB, no alpha.
- **Contact sheets** (outside `screens/`, never uploaded): `creative/contact_sheet.png` (940 px tiles) and `creative/contact_sheet_350.png` (350 px tiles, the phone product-page size).
- **Readability at 350 px wide (MEASURED by eye on `contact_sheet_350.png`, 25 Oct 2026, round 3).** Every headline reads, including the two longest ("TAUNT YOUR FRIENDS IN THE SKY", "AEROPLANE DOGFIGHTS WITH FRIENDS", which shrink to fit). Every sub-line reads, small but clear, in sentence case. "ROOM CODE: DR6UW" in 02 and first_alt_2 reads, and so do the four roster names. 07 is full-bleed on the Golden Ace plane with no menu text; "Looks only." in its sub-line is the cosmetic cue. No frame has a badge.
- **Older versions:** revision 2 raw picks in `creative/takes/v2_sel/`, revision 1 in `takes/v1_screens/` and `takes/v1_sel/`. Revision 3 takes are in `creative/takes/v3/` (`pass1/`, `pass2/` hold the first tries).

| File | Headline / sub-line | Raw capture (take) | What it shows (VERIFIED in the frame) |
|---|---|---|---|
| `01_dogfight_friends.png` | DOGFIGHT YOUR FRIENDS / Online or LAN. Join by room code. | `raw/sel_dogfight_lan.png` (`takes/v4/lan_dogfight_5_0.png`), zoom `[1240, 640, 1.7]` | 4-instance LAN Team Dogfight, Volcanic Islands. A red plane tagged "Dev", side-on, up-left of your blue seaplane. Smoke trails off. |
| `02_room_code.png` | SHARE A CODE. JUMP IN. / No account. No sign-up. | `sel_lobby_room` (room code line, scaled 2.8x) + `raw/sel_dogfight_lan_b.png` (`takes/v4/lan_dogfight_4_2`), zoom `[1300, 760, 1.3]` (round 3) | Left: ROOM CODE DR6UW in a cyan box, then the roster as team-coloured text. Right: volcano-lagoon LAN dogfight, blue seaplane below a red jet tagged "Kabir". Same right half as first_alt_2: upload only one of the two. No pings, "(leader) host", "Room ready" or menu buttons. |
| `03_skywriting.png` | TAUNT THEM IN THE SKY / 24 skywritten taunts | `raw/sel_taunt_skill_issue.png` (`takes/v5/lan_taunt_3_2.png`), zoom `[1434, 660, 1.1]` (round 3) | "SKILL ISSUE!" over the volcano. No SUPPLY marker, no crosshair. |
| `04_vs_ai.png` | FRIENDS BUSY? FIGHT AI / Rookie, Pilot or Ace | `raw/sel_ai_battle.png` (`takes/v4/ai_battle_3.png`), zoom `[1300, 640, 1.35]` | One red AI biplane banking side-on ahead of your blue plane, desert below. No aim circle. |
| ~~`05_lock_on.png`~~ | **Not in the upload set** (fix pass 3) | was `raw/sel_rocket_lock.png` | Moved to `creative/takes/dropped_05/`. No rocket in frame and the target too small at phone size. |
| `06_worlds.png` | 6 WORLDS, WILD WEATHER / Lava, snow and lightning | `sel_world_volcano` (`world_volcano_side_3`), `sel_world_frozen` (`world_frozen_0`, 1.3x), `sel_world_metro_lightning` (`world_metro_13`, 1.15x) | Heavy Twin over the lava channel, Speedster in the snow, Jet Fighter beside a lightning bolt. Navy dividers below the headline band. |
| `07_no_pay_to_win.png` | NEVER PAY TO WIN / Looks only. No ads. No timers. | `raw/sel_shop.png` (`takes/v5/shop_cub_low_2.png`), zoom `[2040, 943, 1.75]` | Full-bleed Golden Ace Toy Cub over Green Valley, gold wing tops toward the camera. No menu text, OWNED tag, fine print or price. |
| `first_alt_1.png` (PPO) | TAUNT YOUR FRIENDS IN THE SKY / 24 skywritten taunts | `raw/sel_taunt_lets_go.png` (`takes/v4/lan_taunt_8_2.png`) | "LET'S GO!" over the volcano. |
| `first_alt_2.png` (PPO) | ONE CODE. ONE SKY. / Join by room code. No account. | as 02's left half + `sel_dogfight_lan_b` (`takes/v4/lan_dogfight_4_2`) | Same picture as 02 since round 3, different text. Upload 02 or this, not both. |
| `first_alt_3.png` (PPO) | TOY PLANE DOGFIGHTS / Lava, snow, lightning and more | `sel_world_volcano`, `sel_world_frozen`, `sel_world_desert`, `sel_world_metro_lightning` | 4 slices, one plane type per world (Heavy Twin, Speedster, Toy Cub, Jet Fighter). |
| `ppo_in_aeroplane.png` (PPO, India) | AEROPLANE DOGFIGHTS WITH FRIENDS / Online or LAN. Join by room code. | `sel_dogfight_lan` | Same capture as 01. The only frame with the keyword wording. |

### Copy claims and their sources

| Claim | Label | Source |
|---|---|---|
| Online or LAN | VERIFIED | `main.gd:2464` (HOST ONLINE), `main.gd:2465` (HOST ON LAN) |
| Up to 8 pilots | VERIFIED in code, **not used**: an 8-phone room is untested (positioning.md check 3), so no frame says it (revision 4) | `main.gd:4` (`MAX_PLAYERS := 8`), `main.gd:499-500` (room full message) |
| No account | VERIFIED | `PRIVACY.md:5` |
| 24 skywritten taunts | VERIFIED | `taunts.gd:8-17` (24 entries) |
| Rookie, Pilot or Ace | VERIFIED | `main.gd:15` (`SKILL_NAMES`) |
| Homing rockets on every plane | VERIFIED | every plane carries 2-6 rockets (`planes.gd:9-12`); any plane's rocket guides once locked, with no plane-type check (`plane.gd:443-461`) |
| Lava, snow and lightning | VERIFIED | `worlds/volcano.gd:48-50`, `worlds/frozen.gd:39-42`, `worlds/metro.gd:31-33` |
| Looks only | VERIFIED | `shop_ui.gd:28`, `shop.gd:4-5` |
| No ads | VERIFIED | `PRIVACY.md:5` ("no ads"); `addons/` holds only `mqtt` and `webrtc_native`, and a search of the project (outside `aso/`) finds no ad SDK |
| No timers | VERIFIED | `shop.gd:6` ("no timers"), `shop_ui.gd:6` |

### Changes in revision 3, by critique point

1. **Bigger text.** Headline 128 -> 184 px, sub-line 66 -> 100 px, sub-line now sentence case in the menu font. Checked at 350 px wide (above).
2. **No flat band.** A see-through gradient, the same on every frame (05's taller band is gone; the touch controls are hidden in the capture instead). One accent colour per frame. (Revision 3 also had a brand pill; it was removed in revision 4 and the code deleted in round 2.)
3. **Debug-looking labels hidden** in every capture (`_clean()`): `main.overlay` (SUPPLY, REVIVE, PRIZE BALLOON markers, red lead rings), balloon and prize name tags, the touch controls, and the plane HUD except in 05. Same `modulate.a = 0` / hide approach as before.
4. **05 re-captured**: target 12-19 m away (13 m in the pick), touch controls hidden. The game draws the lock box at a fixed 36 px of a 1100x620 canvas (`plane.gd:1038`, `main.gd:103`), about 2.7% of the frame. To reach the 8% target the capture scales the HUD layer 3x around the locked target (`hud_zoom`), which keeps the box on the plane and pushes the health bars off-screen. **This is staging: the box is drawn larger than in the game.** The compose then zooms 1.4x.
5. **04 re-captured** with `_lone_target()` (enemy with the fewest planes within 250 m) and 01's close framing. Headline is back to "FRIENDS BUSY? FIGHT AI".
6. **02** now uses the first_alt_2 layout.
7. **07 re-captured** in Green Valley, the turntable plane held side-on and closer, its trail particles hidden. Left side cropped to title, Looks-only line and item name.
8. **Worlds** re-captured with per-world camera distance, bank and viewpoint (`scene_weather`, `scene_worlds`). Volcano take with the most lava bombs picked; the snow panel cropped 1.4x. The game's snowfall is still light (900 flakes over a 700 m box, `env.gd:158-187`).
9. **01 re-captured** with smoke trails off and the compose zoomed 1.25x, pair left of centre. The capture geometry was also tried 25% closer and lower (`takes/v3/pass2/`), but at that height the red plane sits behind yours; revision 2's angles plus a compose zoom worked better.
10. **Sub-lines:** first_alt_1 "24 skywritten taunts", first_alt_2 "Join by room code. No account.", first_alt_3 "Lava, snow, lightning and more". "Aeroplane" wording now only in `ppo_in_aeroplane.png`.
11. **CALLSIGNS:** still the developer's job (see Still open).
12. This file: font, band and frame-4 drift fixed; 350 px check recorded.

### How the captures were staged (be ready to explain this if asked)

- **Positioning only.** The scripts move *your* plane, its aim and the camera angle. Every other plane, bullet, rocket, fire trail, lightning bolt and HUD element comes from the game simulation.
- **Hidden, not removed:** the top HUD row, the kill feed, your stats line, the touch controls, world markers and lead rings, balloon name tags, the plane HUD (except 05) and, in 07, the turntable's trail particles. They still exist in the game.
- **Enlarged:** nothing in the shipped set. (Revision 3's 3x HUD zoom on 05 was deleted in round 2, and 05 is no longer uploaded.)
- **Settings changed for capture only:** smoke trails off (a player option, `menus.gd:271`).
- **Muted:** AI radio chatter in 04 (and the dropped 05) (`main.gd:1653-1660`, rate limit set far ahead).
- **Weather fast-forwarded:** the storm clock and hazard timers, as before. The planes' HP is refilled during the lightning capture so a strike doesn't end the take.
- **The 'friends' in 01-03** are extra game instances in human slots, run by the game's `--bot` brain. No person was flying them. Names are typed in.
- **Settings untouched:** `settings.cfg` and `fake_store.cfg` are restored byte-for-byte by the script. Only processes the script started are stopped.

### Still open

Superseded by the round-2 sections below. As of fix pass 3: callsigns are fixed in the game and every capture shows the game's own toy names; `hud_zoom` is deleted; 05 is dropped. Still true:
- **01 friends** were bots in human slots. For a fully literal frame, capture once with real people.
- **06 snow** is as heavy as the game renders.

### Re-running

```
godot --path . --resolution 2868x1320 -s aso/tools/capture_scenes.gd -- --phone --fake-store [--only lan[,fight|,taunt],lobby,ai,rocket,weather,worlds,ctf,shop,assault,hqside] [--lan-world N --lan-plane cub|racer|twin|fighter]
godot --headless -s aso/tools/strip_sheet.gd -- /tmp/sheet.png 560 3 aso/creative/takes/v3/ai_battle_*.png   # review takes
godot --path . --resolution 640x300 -s aso/tools/compose_screens.gd
cd aso/creative/screens && mkdir -p 2622x1206 && for f in *.png; do sips -z 1206 2622 "$f" --out "2622x1206/$f"; done
```

- Takes go to `creative/takes/v3/`. Each run differs, so pick the best take and copy it over the matching `raw/sel_*.png` before composing.
- `lobby` contacts the game's public MQTT brokers, like a player pressing HOST ONLINE. `lan` binds to `127.0.0.1` and skips UPnP.

## Round 2 changes (25 Oct 2026, ASO round 2, screenshots)

Resolves the r3 screenshot critique (`data/critiques_round1.json` → `screenshots[-1]`). All 12 frames are re-composed. 2868x1320 and 2622x1206 sets: 12 + 12 files, RGB, no alpha (MEASURED with `sips -g hasAlpha`). The contact sheets are in `creative/` (not `screens/`), and all 12 frames were checked at 350 px wide (`contact_sheet_350.png`): every headline reads.

**New captures** (`capture_scenes.gd --only ai,rocket,ctf,lan` → `creative/takes/v4/`, the current game build with the original toy callsigns and softer smoke):
- 01, c01, ppo ← `lan_dogfight_5_0` (now `raw/sel_dogfight_lan.png`): the red plane is side-on and large, and carries the human tag "Dev", so "friends" shows. There is no left-edge fire glow and no white streaks. Zoom `[1240, 660, 1.55]`.
- 02, first_alt_2 right half ← `lan_dogfight_4_2` (new `raw/sel_dogfight_lan_b.png`): a red jet tagged "Kabir" over the lagoon. It no longer repeats 01's image.
- 04 ← `ai_battle_3`: one red AI biplane banking side-on, ahead, with no fire glow. The tags are the game's own names (Bolt, Pebble, Comet, Pipkin, Sprocket; MEASURED by eye at 1400 px).
- 05 ← `rocket_lock_3`: the HUD is at its real size. `hud_zoom` is deleted from `capture_scenes.gd`, which removes the Guideline 2.3 risk. Every tag except the locked target's is hidden. There is no aim circle cut-off or stray HUD fragment. The headline now says what the frame shows: "LOCK ON WITH HOMING ROCKETS" / "Shake them off with flares" (flare button: `touch.gd`).
- first_alt_1 ← `lan_taunt_8_2` ("LET'S GO!" with the current smoke).
- `capture_scenes.gd`: `AI_NAMES` and `_rename_ai` are deleted. The game's `CALLSIGNS` (`main.gd:16`) are original now, so captures show real names.

**Compose (`compose_screens.gd`)**:
- Headline font: the heavy, tight menu font, with the 75% width cap (see Format). Skywriting font only on 03 and first_alt_1.
- 02 and first_alt_2: the room code is scaled 2.8x as the focal point. The roster is set as text in team colours (Blue: Arjun, Kabir; Red: Riya, Dev, as shown in `sel_lobby_room`), so there are no row boxes and no pings. A solid top scrim on split frames and a divider starting at y = 400 mean the text no longer crosses the seam.
- 07: full-bleed on the Golden Ace plane (zoom `[2100, 600, 1.75]`), with no unreadable menu panel. The OWNED tag and the fine print are out of frame.
- 06: the metro panel is re-centred (cx 1800) so the plane and the bolt are both in it. Dividers are 6 px navy, not white.
- first_alt_3: 4 slices (volcano, frozen, desert, metro), headline "TOY PLANE DOGFIGHTS" (fits with no shrink).
- Accent tied to theme (cyan multiplayer, amber solo/shop). Coral is removed. The `_badge` code is deleted.

**Not done (open):**
- Frame 8 (CTF / Base Assault): the new `ctf_flag` take only shows a thin red flag beam over a valley. It is not store-grade, so no frame 8 yet. A Base Assault capture with AA guns or SAMs needs a new scene.
- 03 keeps its earlier `sel_taunt_skill_issue` capture. The new SKILL ISSUE take (`lan_taunt_6_2`) has a downed plane's smoke column crossing the "S".
- first_alt_3 still shows the same blue plane in every slice. Varying the plane per world needs a `worlds` re-capture with other loadouts.
- 05 is still the weakest frame: the lock box is small at 1x, and no rocket was caught in flight. Every `rocket_fly_*` take hit at once, or showed explosions and MISSILE warnings.


## Round 2, fix pass 2 (25 Oct 2026, after the 6.5/10 critique)

**Re-captured on the current build** (z-fighting fix `ed9bebf`, toy callsigns): `capture_scenes.gd --only shop,assault,worlds,weather,lan,taunt`, then `--only shop` again for a lower pose. Takes are in `creative/takes/v5/`. The picks they replaced are kept in `creative/takes/v4_sel/`.

| Frame | New raw (take) | Change |
|---|---|---|
| 03 | `sel_taunt_skill_issue` ← `lan_taunt_3_2` | New SKILL ISSUE! take on the current build, with "Dev" in the sky. The only column crossing the text is the volcano's own plume. |
| 06, first_alt_3 | volcano ← `world_volcano_side_3` (Heavy Twin), frozen ← `world_frozen_0` (Speedster), metro ← `world_metro_13` (Jet Fighter, normal camera), desert ← `world_desert` (Toy Cub) | Each slice now shows a different real plane type in that world's theme. In the metro panel the jet sits right beside the bolt (crop cx 1360, 1.15x). |
| 07 | `sel_shop` ← `shop_cub_low_2` | The Golden Ace livery only repaints the wings, tail and trim. The fuselage keeps the team colour (`planes.gd:41`). The capture sweeps 3 plane types × 3 banks × 2 yaws. The pick is the Toy Cub banked 0.5 rad toward the camera, so the gold wing tops fill most of the plane. Compose zoom `[2040, 943, 1.75]`. |
| 01, c01, ppo | same raw, zoom `[1240, 640, 1.7]` (was `[1240, 660, 1.55]`) | The near-camera cloud at the bottom right (raw x ≥ 1740, y ≥ 1030) and the dark specks on the hills below it are now out of frame. |

**Z-fighting check (MEASURED by eye, 25 Oct 2026).** Each wing tip and tail cap of each picked take was cropped at full resolution (180x140 or 260x160 px boxes, viewed at 3x):
- Checked: 07's Golden Ace (both wing tips and the fin), 03's seaplane (both tips), the volcano twin, the frozen racer and the metro jet (both tips each).
- Result: every cap face is one flat colour with a clean, straight border to the next face. There is no dithered or interleaved colour.
- For comparison, the round-1 07 frame shows the glitch on the near wing tip, in the full-res crop at x 1550-1900, y 690-800: jagged, stepped patches of gold, tan, grey and dark gold.
- The fine, even dot texture on the gold paint is the same everywhere on the surface. It is not face interleave.
- 01, 02, 04, 05, first_alt_1 and first_alt_2 are round-2 (`takes/v4/`) captures and were already on the fixed build.

**Destruction leftovers (MEASURED by eye).**
- The picked takes were checked for leftover flak puffs or debris spheres: none in 03, 06, 07 or first_alt_3, and 01's hill specks are cropped out.
- 05 is unchanged and still has the grey-purple clump left of the target.
- **For the developer (game code, outside this folder's write scope).** These are the likely sources of the "large dark shiny balls" left at the end of a destruction (HYPOTHESIS, from reading the code):
  - `fx.gd:219` `flak()`: the soot sphere grows to 14x scale in 0.5 s, but its alpha fades with `EASE_IN` over 1.4 s. So it stays nearly opaque at full size and reads as a solid dark ball before it vanishes. Fade with `EASE_OUT` or over ≤ 0.5 s, or shrink it as it fades.
  - `fx.gd:171` `crash()`: the crash-site fire is `fire(5.0)`, 4 m spheres up to 1.5x. Its colour ramp ends at dark red, `Color(0.35, 0.05, 0, 0)`. The smoke is `smoke(4.5, 10.0)`, spheres up to about 20 m that grow to 2.2x. Late in the 18 s site life these show as big dark spheres. Drop the last few: end the fire ramp earlier, or cut the smoke's `scale_amount_curve` end value.

**Compose:** in 06 and first_alt_3 the navy dividers now start at y = 400 (`_slices` draws the slices 6 px wider and fills the gaps only below `TOP`), so the headline band is unbroken.

**Upload folders:** an empty `aso/.gdignore` stops Godot importing anything under `aso/`. All `*.png.import` sidecars under `aso/` are deleted, so `screens/` and `screens/2622x1206/` hold only the 12 + 12 PNGs. The capture and compose scripts still run with it in place (VERIFIED by this run).

**Sizes (MEASURED, `sips`):** 12 frames at 2868x1320 and 12 at 2622x1206, `hasAlpha: no` on all 24.

**Still open:**
- **05:** not replaced. A `scene_assault` (Base Assault vs AI: buy a SAM with the starting supplies, then bomb runs on the red HQ) was added and run. Its takes (`takes/v5/assault_*`, `bomb_*`) show only a small plane over the valley from above. No HQ, SAM or falling bomb reads, so they are not store-grade.
- **Frame 8** (CTF or Base Assault with an AA gun or SAM) is still missing for the same reason. Next try: a lower, side-on camera on the red HQ during a bomber raid, with `cam = 0`.
- **07:** the far wing tip sits behind the sub-line, so the frame leans on the scrim. Re-shoot with the turntable further right if that matters.

## Round 2, fix pass 3 (25 Oct 2026, after the 7.5/10 critique)

**Upload set: 01, 02, 03, 04, 06, 07 (6 frames).** `screens/` and `screens/2622x1206/` now hold 11 + 11 PNGs, all `hasAlpha: no` at 2868x1320 and 2622x1206 (MEASURED, `sips`). The other five files (c01, first_alt_1-3, ppo_in_aeroplane) are alternates for Strategy C and PPO, not part of the default upload. Keep the 04 → 06 gap in the file names; the order is the sort order.

| Critique point | Change |
|---|---|
| 1. 05 shows no rocket and a tiny target | **Dropped.** The 05 entry is removed from `compose_screens.gd` and both files are moved to `creative/takes/dropped_05/`. A re-shoot with a rocket in flight was not attempted again; every earlier `rocket_fly_*` take hit at once. |
| 2. Frame 8 missing | **Tried, not shipped.** A new `capture_scenes.gd` scene `hqside` (Base Assault in Green Valley, near camera, 26-40 m above the ground, 120-170 m from the red HQ, HQ ahead and to one side) ran twice (`takes/v6/hqside_*`). The HQ now sits in frame, but it reads as a small red-roofed building on a lawn. There is no fire, bomb, AA gun or raid in view, so nothing says "base assault". Still open. |
| 3. Stale storyboard rows | The frame table ("The frames"), the format notes (upload order, accents), the Produced-set file table (01, 02, 04, 05, 06, 07 and the first_alt rows), the brand-pill line, the staging notes (enlarged and muted) and the revision-3 "Still open" list now describe the shipped state. |
| 5. 01 and 02 look alike | 02's right half is a **new LAN capture in Sky Islands** (`--only lan,fight --lan-world 5 --lan-plane fighter` → `takes/v6/lan_dogfight_2_1.png` → `raw/sel_dogfight_lan_c.png`): a blue jet behind a red biplane tagged "Riya", over pastel cloud islands. That is a different world, plane type and palette from 01's seaplane over the volcano (checked at 1400 px and on the contact sheet). first_alt_2 keeps the lagoon take, so 02 and first_alt_2 differ too. |
| 6. "Dev" tag crossed by the propeller in 01 and c01 | **Not changed.** None of the 16 `takes/v4/lan_dogfight_*` takes has the red plane as large and side-on with a clear tag. A fix needs a new 01 capture. |

**Z-fighting (MEASURED by eye).** The new 02 take was checked in a full-resolution crop (1500x900 around both planes): the jet's wing, tail and drop-tank faces and the biplane's wings are flat colours with clean edges, and nothing flickers or interleaves. The critic also found no face overlap on the planes in 01, 02, 04, 06 or 07.

**Destruction leftovers: developer follow-up (game code, outside this folder's write scope).** None of these spheres appears in the shipped frames (MEASURED by eye; the purple clump in the dropped 05 is the metro world's own cloud). Suggested trims, from reading `fx.gd` (HYPOTHESIS until tried in game):
- `fx.gd:37-40` `fire()`: the colour ramp fades to dark red, `Color(0.35, 0.05, 0, 0)`. At `fire(5.0)` in `crash()` (`fx.gd:184`), the last particles are big dark-red balls. Move the end colour to orange-transparent, or add a point at about 0.7 that already has alpha 0, so the dark tail never shows.
- `fx.gd:73-76` `smoke()`: `scale_amount_curve` grows from 0.6 to 2.2. At `smoke(4.5, 10.0)` in `crash()` (`fx.gd:190`), the late puffs reach about 20 m. Lower the end point to about 1.2, or fade alpha to 0 by about 0.8 of life in `_smoke_fade`.
- `fx.gd:235-236` `flak()`: the puff scales to 14x in 0.5 s, but the soot alpha fades over 1.4 s with `EASE_IN`, so it stays nearly opaque at full size. Use `EASE_OUT` and about 0.6 s, or shrink it as it fades.

**Scripts touched (in `aso/tools/` only):** `capture_scenes.gd` writes to `takes/v6/`, has the `hqside` scene, and takes `--lan-world` / `--lan-plane` options (defaults 1 / cub, so earlier runs reproduce). `compose_screens.gd` drops 05 and points 02 at `sel_dogfight_lan_c`, zoom `[1350, 700, 1.05]`. Every friend instance the capture started was stopped by its PID (`pgrep -fl lan_friend.gd` is empty afterwards).


## Round 3 (fix pass 3.3, 25 Oct 2026)

- **02 replaced.** Its right panel was `sel_dogfight_lan_c` (Sky Kingdom), where a cloud slab cut the jet's wing and tailplane and the right half washed out to white. It now uses `sel_dogfight_lan_b` `[1300, 760, 1.3]`, the clean volcano-lagoon take first_alt_2 already used. 02 and first_alt_2 now differ only in their text, so upload one of them.
- **03:** zoom `[1434, 660, 1.1]` moves the tiny "Dev" name tag into the gap between the headline and the sub-line (it touched "24 skywritten taunts" before). VIEWED at 1400 px.
- **07 unchanged.** A lower crop (`[2040, 880, 1.6]`) cleared the wing from "PAY TO" but pulled the shop menu's dark left panel into frame, so it was reverted. Clearing the headline needs a re-staged shop capture (a lower `drop` in `scene_shop`). No "Golden Ace Set" tag added: the sub-line already says "Looks only."
- **Frame 8 still missing.** `capture_scenes.gd --only ctf,assault,hqside` ran again (`takes/v6/assault_*`, `bomb_*`, `ctf_flag`, `hqside_*`). No take shows an AA gun or SAM firing, and the red HQ stays small behind the plane, so none was promoted to `raw/`.
- **One capture, three frames:** 01, c01_no_ads and ppo_in_aeroplane all use `sel_dogfight_lan`. Upload at most one per listing.
- Re-composed both sizes: 11 at 2868x1320 and 11 at 2622x1206, all PNG colour type 2 (RGB, no alpha), MEASURED. Contact sheets regenerated.
