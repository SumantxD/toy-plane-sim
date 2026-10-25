# Launch action plan: Toy Plane Sim on iOS (India first, then US and global English)

Written 2026-10-25. Steps are in order. Owner is **You** (the developer: anything in App Store Connect, game code, devices, money or accounts) or **Claude** (anything inside `aso/`: research, copy, renders, validation). Claude does not edit game code, upload, buy or sign up for anything.

Labels: VERIFIED (code or Apple page), MEASURED (data fetched or counted here), ESTIMATE, HYPOTHESIS. No download, volume or conversion number appears below because none exists for this app yet: **unknown**.

---

## Phase 0: blockers before you submit

These would cause a rejection, a misleading listing or a wasted review cycle.

| # | Step | Owner | Why / evidence | Done when |
|---|---|---|---|---|
| 1 | **Decide the name, then rename the game to match.** Store name (round 2): `Toy Plane Arcade: Air Combat` (Strategy C, P2 14/26 vs 13/26 without the suffix); rename the game to `Toy Plane Arcade` so the store name starts with it. Alternative: keep `Toy Plane Sim`. The game still says "Toy Plane Sim" in `project.godot:13`, `export_presets.cfg:41`, the main-menu title (`main.gd:2427-2428`, "TOY PLANE" / "SIM"), `PRIVACY.md` and `SUPPORT.md`. | You decide and edit. Claude can draft the edits on request | App Review compares the store name with the name on the device (HYPOTHESIS based on common rejection reports; Guideline 2.3 accuracy). The validator now WARNs on the mismatch (`tools/validate_metadata.py`). Changing the name later needs a new version (VERIFIED, apple-requirements.md §9) | The validator shows no "device name" WARN for the chosen listing |
| 2 | **Build the release from commit `ed9bebf` or later**, which has the original callsigns in `main.gd:16` (Biscuit, Comet, Pebble... instead of Top Gun names). | You | Old names still appear in `builds/appstore/1-battle.png` and `2-taunt.png` (VERIFIED by viewing). **Never upload `builds/appstore/*.png`.** Use `aso/creative/screens/` | Release build made from `ed9bebf` or later |
| 3 | **Network checks on TestFlight:** at least 9 of 10 room joins succeed on Jio data and on Airtel data; an 8-phone room finishes a full match. | You (needs phones and testers) | Rooms depend on 3 free public MQTT brokers and P2P with no relay (VERIFIED, `rooms.gd:4-11`). Connection and server complaints are 5.1% of IN reviews on the 8 paired competitor apps, from a regex with 58% hand-checked precision (MEASURED, competitor-research.md §4) | Results written into positioning.md, Strategy A checks |
| 4 | **Price and IAP setup in App Store Connect:** set the app to free; create the Hangar Shop IAPs; check whether ₹79 is on India's price list (if not, use ₹89 or ₹49 and tell Claude to recompute the set saving). | You | ₹79 seen in 1 of 214 IN apps; ₹99/₹199/₹499 in 92-112 each (MEASURED, apple-requirements.md §11.6) | Prices entered; IAP review screenshots attached (§11.5) |
| 5 | **Give Claude the exact seller name** ASC shows. | You → Claude updates `developer_name` in `data/listing_*.json` and re-runs the validator | `developer_name` is an ESTIMATE ("Sumant Tirkey" from git) | Validator re-run with the real name |
| 6 | **Icon render fixes**, then pick the launch icon. Recommended: B duel (`creative/icons/B_duel.png`) after fixes; A hero is the first PPO treatment. Fixes from the icon critique: pale yellow-white tracers with an ink edge and an inked starburst spark (not orange on orange); delete or flatten the grey smoke puffs; make the blue plane the hero (60-65% of width, bleeding off bottom-left) and the red plane smaller and farther; hide the wheel and gear meshes; render a cream or deep-teal background to compare; grey (not white) red plane in the tinted variant; for A, raise the camera above the wing and swap the shark mouth for the Star or Lightning sticker. | Claude (`tools/render_icons.gd`, `tools/icon_sheet.sh`); You approve | Icon critique score 5.5/10. The current `assets/ui/icon_ios.png` shows an older plane model (game-audit.md §5) | New `contact_sheet.png` reviewed at 60 px; you choose |
| 7 | **Put the chosen icon in the build**, plus the second icon as an alternate icon, and the dark and tinted variants. | You (game files: `assets/ui/icon_ios.png`, `export_presets.cfg` icon keys) | An icon PPO test needs the alternate icon **in the live binary** (VERIFIED, apple-requirements.md §7). Shipping it in v1.0 lets the icon test start without an update | The archive lists the alternate icon |
| 8 | **Finish the Strategy C screenshot set.** Done: `creative/screens/c01_no_ads.png` (frame 1, "NO ADS. JUST DOGFIGHTS."). Still to do: a balloon/power-up capture and frame; C headlines on the AI, lock-on, worlds and shop frames; re-stage 05 (real HUD scale, rocket actually in flight, no stray name tags) or replace it with a bomb/AA/SAM frame; an 8th frame from a real CTF or Base Assault capture; a heavier, tighter headline font; one accent colour with a stated meaning; 06 metro crop; 07 empty panel; 04 enemy plane edge-on. | Claude (`tools/capture_scenes.gd`, `tools/compose_screens.gd`); You review | Screenshot critique score 5.5/10. Frame 1 is what search results show for a landscape app (HYPOTHESIS, screenshot-storyboard.md) | 7-8 C frames at 2868x1320 and 2622x1206, RGB, viewed on `contact_sheet_350.png` |
| 9 | **Category:** Games, primary **Action**, secondary **Simulation**. | You (ASC) | IN Simulation is easier to chart (#50-#100 median 3,780 vs 7,046 ratings) but its plane titles are all sims or hypercasual; the game drops "Sim" because it isn't one. Apple indexes both categories (VERIFIED, apple-requirements.md §1.2). Choice is HYPOTHESIS | Set in ASC |
| 10 | **Enter metadata** from `data/listing_C.json` (en-GB) and `data/listing_C_en-US.json` (en-US). Add **both** localizations now, even though the US launches later. While entering, try adding `3d` to the keyword field: if ASC accepts it, replace the last word that fits (it would cover 2 P1 terms, "plane game 3d" and "aeroplane game 3d"). | You | en-GB is India's default language and the default for 100+ other storefronts (VERIFIED, Apple localization table). Whether ASC accepts 2-character keywords is unknown | Fields saved; tell Claude whether `3d` was accepted |
| 11 | **Compliance forms:** age rating questionnaire (expect 13+ on iOS 26, 12+ on older; HYPOTHESIS), export compliance (`ITSAppUsesNonExemptEncryption`), App Privacy label, EU DSA trader status. | You | apple-requirements.md §11.1-§11.4 | All four answered |
| 12 | **Optional, free:** open an Apple Search Ads (now "Apple Ads") account and record popularity scores for the P1 terms and filler words in the empty table in keyword-research.md, "Data limitations". | You → Claude compares with the hint proxy | Only real demand number available for free. May need the app live first (unknown) | Table filled |
| 13 | **Submit** for review, India availability only. | You | | Approved |

---

## Phase 1: launch weeks 1-4 (India)

| # | Step | Owner | Notes |
|---|---|---|---|
| 14 | Turn on the release in India. Keep other storefronts off until Phase 3. | You | Charting in India takes far fewer ratings than in the US: 11-15 of the 51 apps at #50-#100 in IN Action and Simulation have under 1,000 lifetime ratings, against 1-4 in the US (MEASURED, competitor-research.md §2d) |
| 15 | **Seed the first ratings honestly.** Ask friends and TestFlight testers in India to install from the store, play a few matches and rate it if they like it. Never offer anything in return for a rating, never ask for 5 stars specifically. | You | The game already asks through Apple's own sheet: after a win, from the 5th match, at most every 60 days (VERIFIED, `shop.gd:229-238`, `tools/storekit/src/godot_review.mm`); Apple caps it at 3 prompts a year (VERIFIED, apple-requirements.md §9). Keep it that way: no custom "do you like the game?" gate in front of it |
| 16 | **Reply to every review** in the first month, especially 1-3 star ones about connections, crashes or controls. | You post; Claude drafts replies on request | Competitors' recent reviews run 0.4-2.9 stars below their lifetime average (MEASURED, competitor-research.md §4); replies are the one public answer you control |
| 17 | **Weekly rank check** for the P1 and P2 terms in IN and US: `python3 aso/tools/fetch_search.py "<term>" ...`, then report where the app appears. | Claude | MEASURED via iTunes Search API, which is not the App Store's own ranking (keyword-research.md, Data limitations) |
| 18 | **Weekly ASC analytics note:** impressions, product page views, conversion rate, installs by source (Search, Browse, App Referrer, Web Referrer), crashes. | You export; Claude writes it up | This is the first real conversion data. It decides the PPO priority and the A switch |
| 19 | **Fix what reviews report** before working on the listing: crashes and failed joins. | You | Crash themes were 7.7% of IN reviews on paired competitor apps (MEASURED). A listing can't outrun a one-star join failure |

---

## Phase 2: Product Page Optimization (from about week 2, when the app is live)

PPO rules (VERIFIED, apple-requirements.md §7): up to 3 treatments plus the original; only icon, screenshots and previews can change; one test at a time; up to 90 days; Apple suggests waiting for 90% confidence; icon treatments must be in the live binary.

**Test 1 (first): screenshot frame 1, India.**
- Control: `c01_no_ads.png` (the C pitch).
- Treatment A: `first_alt_1.png` (skywritten "LET'S GO!"; nothing like it in the 26 competitor first screenshots, MEASURED, competitor-research.md §5).
- Treatment B: `ppo_in_aeroplane.png` ("AEROPLANE DOGFIGHTS WITH FRIENDS", the friends pitch in India's spelling).
- **Why first:** it needs no new binary and no new review beyond the screenshots, the first frame is the one a landscape app shows in search results (HYPOTHESIS), and it answers the biggest open question in this folder: does "no ads" or "play with friends" pull harder? "No ads" is backed by 79 ad complaints in 843 competitor reviews, but 60 of those come from two hypercasual apps and the combat apps have none (MEASURED, positioning.md). Nothing measured says which pitch converts.
- If India traffic is small, drop to one treatment. A test that can't reach confidence in 90 days tells you nothing (traffic unknown).

**Test 2: icon B (control) vs icon A.** Only if both are in the binary (step 7). Icon conversion is unknown for every concept.

**Test 3: decided by the analytics.** If most search installs come on combat terms ("fighter plane game", "air combat"), test B's combat set (lock-on, SAM, base assault frames). If most come from referrals or shared links, test the friends set (01, 02, 03) as the whole page.

**What would make you switch the whole listing to Strategy A** (name, subtitle, keywords; needs a new version): step 3 passes, and either Test 1 favours a friends frame or analytics show most installs from shared links or friends terms (positioning.md).

---

## Phase 2b: Custom Product Pages

Up to 70 pages; each has its own screenshots, promo text and keywords, and its own URL; each must be approved (VERIFIED, apple-requirements.md §8). Analytics appear after 5 first-time downloads per page.

| Page | Who lands there | Frames | Promo text idea | Assigned keywords (ideas) |
|---|---|---|---|---|
| **Play with friends** | People tapping a link a friend shared, or a social post | 01, 02 (room code), 03 (skywriting) | "Share a room code and dogfight your friends. No account." | multiplayer, friends, co-op, pvp |
| **Fight AI offline** | "offline" and "no wifi" searchers; India travel and patchy-data players | 04 (AI), c01, worlds | "Fight AI pilots with no internet, Rookie to Ace." | offline, no wifi |
| **Air combat** | Combat searchers ("air combat", "fighter jet game") | lock-on, bombs/SAM, CTF/Base Assault frame | "Lock on, fire, drop flares, bomb their base." | air combat, fighter jet, bomber, rocket |

Also worth doing (You, game code): make the in-game "copy room code" share text include the friends-page URL, so every invite lands on the page that matches it. That is a game change and is not done here.

---

## Phase 3: US and global English rollout (after India stabilises)

| # | Step | Owner | Notes |
|---|---|---|---|
| 20 | Turn on the US and the other English storefronts. The en-US localization is already in ASC (step 10); the en-GB one covers 100+ storefronts. | You | US competition is 10-20x higher at the chart median (MEASURED, competitor-research.md §2d); 14 of 20 P1 terms have no sub-1,000-rating game in the US top 10 (MEASURED, keyword-research.md). Expect search to matter less in the US than links and word of mouth (HYPOTHESIS) |
| 21 | Re-fetch the hints and search data for the US before rewriting anything; terms move. | Claude | `fetch_hints.py`, `fetch_search.py`, `build_keywords.py` |
| 22 | Decide on paid data (below). | You | |

---

## Paid data: what, if anything, is worth buying later

- **Before launch: nothing.** The free sources (autocomplete, Search API, reviews RSS, charts RSS) already answered the launch decisions, and paid tools can't measure an app with no history.
- **First thing worth paying for: a small Apple Search Ads campaign in India**, after the page has its final frame 1. It returns Apple's own impressions, taps and installs per keyword and a search-terms report for your page. That is real demand and conversion data, which no third-party tool has. Budget: your call; no figure is suggested here because none can be justified yet.
- **Maybe later: one month of a third-party ASO tool** (AppTweak, Sensor Tower, Appfigures or similar; check current pricing) at the US rollout, where the hint proxy is weakest and competition highest. Use it for US keyword volume estimates and competitor keyword rankings over time. Treat its download estimates as estimates (they are modelled, not reported).
- **Not worth it:** competitor download estimates for India-only decisions; review-mining tools (the RSS feed plus `tools/review_themes.py` already does this).

---

## Localization

| When | What | Owner | Evidence |
|---|---|---|---|
| Launch | **en-GB** (India and 100+ other storefronts) from `listing_C.json`: "Aeroplane" in the subtitle, British spelling | You enter, Claude wrote | VERIFIED, Apple localization table |
| Launch | **en-US** from `listing_C_en-US.json`: "Airplane" subtitle, "aeroplane" in keywords | You enter | as above |
| After launch | **Hindi keyword-field test:** add a hi localization with a correct Hindi name and subtitle, one unique Devanagari token in its keyword field, "English only" in the description; then check whether IN search finds the app by that token with the device in English and in Hindi | You add; Claude checks with `fetch_search.py` | Hindi queries showed no autocomplete demand (MEASURED); whether IN users with English devices get hi keywords indexed is unknown (apple-requirements.md §9) |
| After launch | **Spanish (Mexico) in the US** as an extra English keyword field (`3d`, `multiplayer`, `pvp`...): only after the Hindi test shows extra locales are indexed | You / Claude | HYPOTHESIS; risk of a review objection to wrong-language text |
| Not planned | Other Indian languages; game UI translation | | No term data (unknown) |

---

## Open items carried from the critiques

Research (7/10) and strategy (6/10) items were fixed in this pass (see README.md, "What changed in the completeness pass"). Still open:
- Icons (5.5/10): every render fix in step 6, and a rebuilt or replaced C concept before it enters any test.
- Screenshots (5.5/10): every item in step 8, and the second LAN view for frame 02 so frames 01 and 02 stop sharing one capture.
- The competition bucket in `keywords.json` still uses the median; the top-3 strength is shown next to it, not folded into the score.
- `Toy Plane Arcade: Air Combat` is adopted as C's store name (positioning.md, Round 2 changes); the in-game rename in step 1 is still yours.
