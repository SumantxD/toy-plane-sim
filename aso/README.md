# ASO for Toy Plane Sim (iOS): start here

App Store Optimization work for the iPhone launch, India first, then US and global English. Everything lives in this folder; no game code, scenes, assets or `builds/appstore/` files were changed. Updated 2026-10-25 ~19:45 IST (ASO round 2 wrap-up).

Labels used everywhere: **VERIFIED** (code file:line or an Apple page), **MEASURED** (data fetched or counted for this project, in `data/`), **ESTIMATE**, **HYPOTHESIS**. Search volume, downloads and conversion are **unknown** for this app and every term: nothing here predicts installs.

## Files

| File | What it answers |
|---|---|
| [launch-action-plan.md](launch-action-plan.md) | **What to do next**, in order, with owners: blockers, launch weeks, PPO tests, Custom Product Pages, paid data, reviews, localization |
| [positioning.md](positioning.md) | Strategies A (friends), B (air combat), C (no-ads arcade); why C launches; listing text |
| [keyword-research.md](keyword-research.md) | 88 terms scored by autocomplete and competition in IN and US; final keyword fields |
| [competitor-research.md](competitor-research.md) | 27 competitor apps, IAP prices, charts, 993 reviews by theme, gaps |
| [game-audit.md](game-audit.md) | What the game really has (file:line), what it doesn't, which claims are safe |
| [apple-requirements.md](apple-requirements.md) | Field limits, screenshot and icon specs, Guideline 2.3, PPO and CPP rules, compliance forms |
| [screenshot-storyboard.md](screenshot-storyboard.md) | Frame list, rendered set, claim sources, PPO alternates |
| [icon-concepts.md](icon-concepts.md) | Round-1 concepts and the round-2 finalists (`creative/icons/v3/`); read "Round 2 finalists" |
| `data/listing_*.json` | Ready-to-paste listings. Check with `python3 aso/tools/validate_metadata.py aso/data/listing_C.json` |
| `creative/screens/`, `creative/icons/v3/` | Rendered screenshots (2868x1320 and `2622x1206/`) and final icons. `creative/icons/*.png` outside `v3/` is the round-1 archive |
| `creative/finals_contact_sheet.png` | One-look sheet: final icons at 1024 and 60 px, the screenshot set in order, the PPO first frames (`tools/finals_sheet.gd`) |
| `tools/` | Fetchers, scorers, validator, coverage check, Godot capture/compose/icon scripts |

`game-audit.md`, `competitor-research.md` and `keyword-research.md` each open with a "Decisions this supports" table. For the current names and keyword fields, the `data/listing_*.json` files are the source of truth; some field strings quoted in those tables predate round 2 (open issue below).

## The three strongest positioning opportunities

**1. India's search field is thin, and it spells "aeroplane".**
- Typing `aer` in the IN App Store suggests "aeroplane games" first (MEASURED, autocomplete endpoint with the IN storefront).
- Every one of the 20 P1 terms has a matching game with under 1,000 IN ratings somewhere in the API's top 9, and 9 terms have one in the top 3. In the US, 14 of 20 have none in the top 10 (MEASURED, `data/keywords.json`, keyword-research.md "How hard the top of each list is").
- "dogfight" in IN: the median matching game has 34 ratings, though #1 is Metalstorm with 1,940 (MEASURED).
- Charting is reachable: 11-15 of the 51 apps at #50-#100 in IN Action and Simulation have under 1,000 lifetime ratings, against 1-4 in the US (MEASURED, competitor-research.md §2d).
- Use: "Aeroplane" in the en-GB subtitle, India first.

**2. No ads, no pay-to-win, and solo play with no internet.**
- The game has no ads and no ad SDK (VERIFIED, `PRIVACY.md:5`, `addons/` holds only `mqtt` and `webrtc_native`), cosmetic-only one-time IAPs and no timers (VERIFIED, `shop.gd:4-6`), and solo modes run with no network (VERIFIED, `main.gd:264-279`).
- Ads are the largest complaint theme: 79 of 843 page-1 competitor reviews. **Caveat:** 60 of the 79 come from two hypercasual apps (Epic Plane Evolution, Sling Plane 3D), and the combat rivals have none, so this pitch wins against the hypercasual results that fill "aeroplane game" searches, and only as a HYPOTHESIS for combat players (MEASURED, `data/review_theme_counts.txt`).
- None of the competitor descriptions says "no ads" (MEASURED, positioning.md Comparison). Pay-to-win/grind 21 and timers 10 more (MEASURED).
- "aeroplane games offline" is an IN autocomplete hint (`aeroplane g` #5, P2), and a Sky Warriors IN reviewer asked for an offline mode (MEASURED).

**3. Friends join by a 5-letter room code or LAN, with no account.**
- Rooms by code and LAN hosting are in the code (VERIFIED, `main.gd:2028`, `main.gd:2465`, `rooms.gd`); no sign-up (`PRIVACY.md:5`).
- None of the 20 US competitor descriptions mentions a room code, LAN, local play or Wi-Fi (MEASURED, positioning.md).
- Reviewers of the closest rivals ask for it: matchmaking waits, bot-filled matches, "ability to form personal rooms", "connecting through lan wifi" (MEASURED, competitor-research.md G2). The theme is small (1.3-1.5% of reviews).
- **Why it isn't the launch pitch:** it depends on free public MQTT brokers and P2P with no relay (VERIFIED, `rooms.gd:4-11`), and joins on Indian mobile data and an 8-phone room are untested. It becomes the listing (Strategy A) when the three checks in launch-action-plan.md step 3 pass.

## Final recommended listing (Strategy C)

| Field | India (en-GB, also 100+ other storefronts) | US (en-US) |
|---|---|---|
| Name | `Toy Plane Arcade: Air Combat` (28/30) | `Toy Plane Arcade: Air Combat` |
| Subtitle | `Aeroplane battles with no ads` | `Airplane battles with no ads` |
| Keywords | `airplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` (98 bytes) | `aeroplane,fighter,war,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,fighting,shooting` (99 bytes) |
| Promotional text | `Arcade dogfights in toy planes. Fight AI pilots on Rookie, Pilot or Ace with no internet, or share a room code with friends. No ads, no energy timers.` | same |
| Coverage (ESTIMATE, `tools/coverage.py`, re-run 19:40 IST) | P1 17/20, P2 14/26 | P1 17/20, P2 14/26 |
| Full text (source of truth) | `data/listing_C.json` | `data/listing_C_en-US.json` |

- Validator (MEASURED, re-run 19:40 IST): 0 FAIL, 1 WARN in both. The WARN is the device name: the game is still "Toy Plane Sim" (`project.godot:13`, `main.gd:2427-2428`). Renaming the game to `Toy Plane Arcade` is a launch blocker (plan step 1).
- Category: Games, Action primary, Simulation secondary (HYPOTHESIS).
- Switch-to listing when the network checks pass (launch-action-plan.md step 3): Strategy A, `Toy Plane Dogfight: Air Combat` / `Aeroplane fights with friends` (`data/listing_A.json`, `data/listing_A_en-US.json`). Coverage: IN P1 18/20, P2 16/26; US P1 18/20, P2 13/26 (ESTIMATE, same run).

## Final icon

**SHIP THIS:** `creative/icons/v3/final_duel.png` (light), `creative/icons/v3/final_duel_dark.png` (dark), `creative/icons/v3/final_duel_tinted.png` (tinted). Set these three in the iOS export preset. The light icon is 1024 px RGB with no alpha; the dark one has alpha on purpose (VERIFIED, `sips`).

- Why: it is the only finalist that shows a fight (a blue-and-yellow toy cub shooting a red one), and it reads at 60 px in this order: the plane, the tracer dashes, the hit star, the red plane (MEASURED by eye, `v3/final_duel_sizes.png`). Round-2 icon score 8.4/10.
- **PPO runner-up:** `creative/icons/v3/final_duel_orange.png`. It changes only the background, so it is a clean one-variable test.
- Second PPO arm (charm, never the control): `creative/icons/v3/final_skywrite.png`. At 60 px its loop reads as an "o", not as combat.
- Round-1 `creative/icons/A_hero.png`, `B_duel*.png` and `C_face.png` are archive only. icon-concepts.md "Recommendation and test plan" still names them (open issue).

## Final screenshot order

Upload in this order (2868x1320, `creative/screens/`; 2622x1206 copies in `creative/screens/2622x1206/`; all RGB with no alpha, MEASURED with `sips`):

| # | File | Headline |
|---|---|---|
| 1 | `c01_no_ads.png` | NO ADS. JUST DOGFIGHTS. |
| 2 | `02_room_code.png` | SHARE A CODE. JUMP IN. |
| 3 | `03_skywriting.png` | TAUNT THEM IN THE SKY |
| 4 | `04_vs_ai.png` | FRIENDS BUSY? FIGHT AI |
| 5 | `06_worlds.png` | 6 WORLDS, WILD WEATHER |
| 6 | `07_no_pay_to_win.png` | NEVER PAY TO WIN |

- This is the storyboard's shipped set (01, 02, 03, 04, 06, 07) with C's own first frame in place of 01. Frames 2-6 still carry A's headlines. Positioning.md lists C headlines on them plus a balloon/power-up frame as a launch blocker.
- **First-frame alternatives for PPO** (HYPOTHESIS, no conversion data): `01_dogfight_friends.png` (A's friends pitch, also the Custom Product Page lead), `ppo_in_aeroplane.png` (India, "AEROPLANE DOGFIGHTS WITH FRIENDS"), `first_alt_1.png` (skywriting), `first_alt_2.png` (code + fight), `first_alt_3.png` (world strip).
- `01`, `c01_no_ads` and `ppo_in_aeroplane` use the same capture. One listing or treatment should never upload two of them.
- Do **not** upload `builds/appstore/*.png`: two of them show the old Top Gun callsigns.
- Everything above is on one sheet: `creative/finals_contact_sheet.png`.

## Scores per deliverable

| Deliverable | Round 1 (first → last critique) | Round 2 (acceptance) |
|---|---|---|
| Research (audit, competitors, keywords) | 6.5 → 7 → 7 | **8** |
| Strategy (positioning, listings) | 6 → 6.5 → 6 | **8** |
| Icons | 5 → 5 → 5.5 | **8.4** |
| Screenshots | 5.5 → 6 → 5.5 | **7** |

Round-1 scores are from `data/critiques_round1.json`. Round-2 scores come from the acceptance critique of this round. The fixes it listed (below) were not re-scored.

## Open issues

**Launch blockers**
1. Rename the game to `Toy Plane Arcade` in `project.godot:13`, `export_presets.cfg:41`, `main.gd:2427-2428`, `PRIVACY.md` and `SUPPORT.md`. This is game-side work, outside this folder.
2. Strategy C screenshots: put C headlines on frames 2-6, and capture and compose the balloon/power-up frame.
3. Confirm the seller name in App Store Connect. `developer_name` is an ESTIMATE in every listing.
4. Wire the three icon files into the iOS export preset (game-side).

**Game-side bugs reported by the user (not fixable here: this ASO pass may not edit game code)**
5. Faces overlapping on the plane (z-fighting). It is still visible in `02_room_code.png` (right half, Sky Islands take) even after the round-2 fix. After the game fix, re-capture 02's right half (or reuse a clean volcano or desert LAN take) and check every plane at full resolution before composing.
6. Large dark shiny spheres left at the end of a destruction. None appears in the shipped frames (MEASURED by eye). Suggested trims are in screenshot-storyboard.md, "Destruction leftovers". After the fix, re-capture any take that shows an explosion or a wreck.

**Doc consistency (no effect on the listing)**
7. The "Decisions this supports" tables in game-audit.md, competitor-research.md and keyword-research.md, and keyword-research.md "Final fields", still quote the older C field with `air,combat`. keyword-research.md "Reconciliation" still describes A with `capture,flag,pvp`. Treat `data/listing_*.json` as the source of truth.
8. `listing_A_en-US.json` keeps `pvp`, which keyword-research.md's "Leave out" rule excludes. Resolve this in positioning.md.
9. competitor-research.md says "26 apps" in one place and 27 elsewhere. Its summary leads with raw ad counts (42 IN, 42 US). Use the matched-app rates instead: 9.0% IN vs 10.5% US (§4).
10. positioning.md still has stale figures in its header (21 P1 and 22 P2, the 16:54 runs, "21 of 24" shared words, C US P2 11/26). The current figures are in the table above.
11. icon-concepts.md "Recommendation and test plan" still points to the round-1 B_duel. The plan above and "Round 2 finalists" replace it. The teal-vs-blue-row check has not been re-run for v3 (`tools/icon_sheet.sh`). `final_skywrite.png` shows a thin seam on the right wing.

**Creative gaps**
12. Frame 8 (Capture the Flag or Base Assault, with an AA gun or SAM) is missing. Two tries did not read as a raid.
13. 07 states "never pay to win" without showing a cosmetic label or a second skin.
14. The storyboard's "Readability at 350 px" note still describes the older 07.
15. Optional C keyword polish: swap `sky` for `wifi` to cover "airplane games no wifi", then re-run `tools/coverage.py`.
