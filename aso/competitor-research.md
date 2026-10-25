# Competitor research: Toy Plane Sim (iOS)

Fetched 2026-10-25 from Apple's public endpoints, India (`country=in`) and US (`country=us`) storefronts. Raw responses are in `aso/data/`. A second pass the same afternoon added the following:
- six competitors that rank on the core combat terms;
- subtitles and in-app purchase lists from the public product pages;
- retried and extra review feeds;
- a hand-checked precision test of the review themes.

A third pass (fix round, ~17:00–17:30 IST) added an India-developer search with one new competitor (§2c), a top-chart benchmark (§2d), and evidence-base notes on the gaps (§6).

**Evidence labels**
- **VERIFIED**: read in Toy Plane Sim's own code (file:line), or stated on an Apple documentation page.
- **MEASURED**: fetched from an Apple endpoint on 2026-10-25 (named next to the claim), or counted by me from that data or from images I looked at. API fields count as MEASURED, not VERIFIED.
- **ESTIMATE**: a number derived from measured data by a stated method.
- **HYPOTHESIS**: my interpretation, untested.

Search volume, downloads, revenue and conversion for every app below: **unknown**. None of the free endpoints expose them, and this report has no numbers for them.

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


## 1. Method and caveats

1. Searched 12 terms × 2 storefronts with the iTunes Search API (`limit=25`): 24 result files, 15–25 apps each (`data/search/*.json`).
2. Ranked every app by how many of the 24 result lists it appeared in. Then I picked 20 that compete with a multiplayer arcade plane game: mostly combat titles, plus the large casual plane games that show up for generic "plane game" terms. I left out pure airliner sims (Infinite Flight, X-Plane, RFS) and tycoon games. Airline Commander is the one exception, because it ranks for almost every generic term.
3. **Second pass, 6 added:** the first pick missed apps that rank on the core combat terms:
   - Warplanes: WW2 Dogfight: #2 for "dogfight" in both stores.
   - WW2 Warplane Fighter Bomber: #3 for "dogfight" in IN, #4 in US.
   - Jet Attack Move: #3 for "dogfight" in US, #4 in IN.
   - ACE Fighter: #2 for "air combat" in IN, and an "air combat" hint.
   - Last Wing: an "air combat" hint, though it doesn't appear in the search results. Found by searching "last wing".
   - Sky Force Reloaded: top 3 for "sky battle" in both stores.

   Ranks are MEASURED from `data/search/*.json`.
4. Fetched all 26 with the Lookup API (`https://itunes.apple.com/lookup?id=…&country=us|in`) for both storefronts: `data/lookup_us.json`, `data/lookup_in.json`, plus `data/lookup_new_us.json` and `data/lookup_new_in.json` for the 6. I flattened the fields used here into `data/competitors.json`.
5. **Subtitles and in-app purchases:** the Lookup API has no subtitle field. I read the public product pages `https://apps.apple.com/in/app/id<ID>` and `/us/app/id<ID>` for all 26 (52 pages, read-only, 1.5 s apart) with `aso/tools/fetch_pages.py`, and saved the extracted fields to `data/competitor_pages.json`.
   - **Subtitle field:** the page's `lockup.subtitle`. When it equals a genre name ("Action", "Simulation"), the app has no subtitle set and the page shows the genre instead.
   - **Price list:** the page's "In-App Purchases" list, which shows **at most 10 items**.
   - **Page language:** every IN page reports page language `en-GB`, and every US page `en-US`.
6. **Reviews:** pulled the customer reviews RSS (`https://itunes.apple.com/<cc>/rss/customerreviews/page=N/id=<ID>/sortby=mostrecent/json`, 50 newest reviews per page) with `aso/tools/fetch_reviews.py`. Details and the theme precision check are in section 4.
7. Autocomplete hints: the endpoint returned empty lists until I sent an `X-Apple-Store-Front` header (143441 = US, 143467 = India). Then it worked (`data/hints/*.xml`).
8. Downloaded all 26 icons and first iPhone screenshots and looked at them on contact sheets built with `aso/tools/contact_sheet.gd`.

**Caveats**
- The order of results from the iTunes Search API is **not** guaranteed to match ranking in the App Store app. Treat "rank" here as a rough signal (HYPOTHESIS that it approximates).
- `userRatingCount` is a lifetime, per-storefront count of star ratings. It is not a download count.
- The RSS feed returns only the newest 50 reviews. That group is far more negative than the lifetime averages (see section 4), so read it for **themes**, not for scores.
- Screenshot URLs from the API are the iPhone set at low resolution (392 px). If an app has a preview video, users may see the video first. Whether each app has one: unknown.

## 2. Competitor table

**Snapshot note.** Rating counts here come from the Lookup API at about 15:16 IST. `keyword-research.md` uses Search API results fetched at 16:51 IST, so the same app can differ by a few ratings (Metalstorm US 42,011 here vs 42,023 there; Sky Warriors 67,440 vs 67,449). These are different snapshots, not errors. In `data/competitors.json`, the field `iap_unreliable_do_not_use` (formerly `iap`) is not an in-app-purchase flag: it is False for 20 of 27 apps, including Metalstorm, which sells IAPs. Use the IAP lists in `data/competitor_pages.json` (§2b) instead.

MEASURED: Lookup API fields, `https://itunes.apple.com/lookup?id=<IDs>&country=us` and `&country=in`, fetched 2026-10-25. The first 20 apps were fetched around 15:16 IST and the 6 marked ⁴ at 16:40 IST. The table is sorted by US rating count.

| # | App (trackName, US) | Seller | Genres | Price US / IN | Rating US (count) | Rating IN (count) | releaseDate US / IN ³ | Last update (US) | Age |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1945 Air Force: Airplane Games (id 1460632826) ¹ | FALCON GAMES PTE. LTD. | Action, Entertainment | Free / Free | 4.83 (433,210) | 4.75 (65,598) | 2019-05-28 | 2026-10-15 | 12+ |
| 2 | Epic Plane Evolution (id 6504122823) | Voodoo | Simulation, Racing | Free / Free | 4.62 (190,455) | 4.35 (4,847) | 2024-06-11 | 2026-10-06 | 9+ |
| 3 | Sling Plane 3D - Sky Crash Jet (id 1553278236) | Panteon Yazilim (Panteon Games) | Action, Simulation | Free / Free | 4.34 (153,990) | 4.27 (3,160) | 2021-02-15 / **2021-03-04** | 2026-10-17 | 12+ |
| 4 | War Thunder Mobile (id 1577525428) | GAIJIN NETWORK LTD | Action, Simulation | Free / Free | 4.81 (139,700) | 4.73 (3,273) | 2023-08-15 | 2026-10-25 | 12+ |
| 5 | Airline Commander: Flight Game (id 1333476679) | RORTOS SRL | Simulation, Action | Free / Free | 4.57 (82,508) | 4.34 (14,853) | 2018-08-04 | 2026-10-07 | 4+ |
| 6 | Go Plane (id 1312798014) | Voodoo | Entertainment, Simulation | Free / Free | 4.58 (72,797) | 4.42 (5,635) | 2017-11-27 / **2017-12-11** | 2025-12-23 | 12+ |
| 7 | Wings of Heroes: Flying Games (id 1528146941) | RORTOS SRL | Action, Simulation | Free / Free | 4.55 (68,037) | 4.5 (341) | 2022-10-05 / **2022-08-15** | 2026-10-20 | 12+ |
| 8 | Sky Warriors: Airplane Games (id 1572323748) | Wildlife Studios, Inc | Entertainment, Action | Free / Free | 4.68 (67,440) | 4.54 (4,929) | 2021-10-05 / **2021-07-01** | 2026-10-19 | 4+ |
| 9 | Metalstorm: Modern Air Combat (id 1461423243) | Starform Inc. | Action, Simulation | Free / Free | 4.78 (42,011) | 4.69 (1,940) | 2023-11-07 / **2024-12-17** | 2026-10-13 | 12+ |
| 10 | Armed Air Forces - Jet Fighter (id 1538640580) | Filip Kasik | Racing, Education | Free / Free | 4.54 (26,058) | 4.42 (540) | 2020-12-25 | 2026-08-27 | 9+ |
| 11 | Alliance: Air War (id 1059604202) | Art of the State LLC | Entertainment, Simulation | Free / Free | 4.65 (22,854) | 4.44 (687) | 2015-12-16 | 2026-05-26 | 12+ |
| 12 | Bomber Ace: WW2 war plane game (id 1360313315) | MADFATCAT LIMITED | Simulation, Action | Free / Free | 4.68 (18,125) | 4.57 (1,154) | 2018-08-02 | 2026-09-14 | 4+ |
| 13 | AirFighters Combat Flight Sim (id 792650358) | RORTOS SRL | Entertainment, Simulation | Free / Free | 4.48 (16,371) | 4.38 (2,056) | 2014-02-20 | 2025-03-25 | 12+ |
| 14 | War Plane Strike: Sky Combat (id 6443915404) | Voodoo | Action, Simulation | Free / Free | 4.59 (15,034) | 4.58 (538) | 2022-11-04 / **2023-03-07** | 2025-12-23 | 12+ |
| 15 | Sky Force Reloaded (id 976116090) ⁴ | Infinite Dreams | Action, Entertainment | Free / Free | 4.75 (11,436) | 4.62 (1,304) | 2016-04-15 | 2024-07-16 | 9+ |
| 16 | Air Battle - Sky Fighters 3D (id 1437052197) | Greg Tripp | Action, Simulation | Free / Free | 4.69 (4,235) | 4.61 (622) | 2018-10-10 | 2019-08-27 | 9+ |
| 17 | Jet Attack Move (id 1672519234) ⁴ | Attack Move Pty Ltd | Entertainment, Casual | Free / Free | 4.84 (3,279) | 4.87 (60) | 2023-02-20 | 2026-10-15 | 12+ |
| 18 | Warplanes: WW2 Dogfight (id 1444886764) ⁴ | Teresa Dymek | Action, Simulation | Free / Free | 4.44 (1,555) | 4.29 (34) | 2018-12-02 | 2026-10-23 | 12+ |
| 19 | WW2 Warplane Fighter Bomber (id 6467832550) ⁴ | Hockenheim Pty Ltd | Simulation, Action | Free / Free | 4.65 (1,401) | 4.5 (34) | 2023-10-04 | 2023-10-05 | 9+ |
| 20 | Air Wings® (id 496386846) | Pangea Software, Inc. | Action, Entertainment | Free / Free | 4.3 (1,183) | 4.51 (197) | 2012-03-07 | 2026-10-14 | 9+ |
| 21 | ACE Fighter: Modern Air Combat (id 6448736535) ⁴ | Pouria Partazian | Entertainment, Action | Free / Free | 4.52 (409) | 4.21 (151) | 2023-05-05 | 2024-05-26 | 12+ |
| 22 | Air Combat Online (id 6449967099) | VOLV LLC | Entertainment, Simulation | Free / Free | 4.72 (407) | 4.4 (53) | 2023-06-25 | 2026-06-02 | 17+ |
| 23 | Dogfight Elite Airplane Combat (id 1073557947) | joaquin grech | Simulation, Action | Free / Free | 4.34 (281) | 3.25 (4) | 2016-02-26 | 2026-04-26 | 9+ |
| 24 | Sky Combat 2: Fighter planes (id 6748014969) | AZUR INTERACTIVE GAMES LIMITED | Action | Free / Free | 4.6 (77) | 4.67 (15) | 2025-11-09 | 2026-08-20 | 12+ |
| 25 | Modern Jet Fighters Online (id 6748027205) ² | MicroProse Software Pty Ltd | Action, Simulation | not listed / Free | no ratings | 4.5 (4) | 2026-11-05 / **2026-10-01** | 2026-11-05 | 12+ |
| 26 | Last Wing: Air Combat Shooter (id 6821467797) ⁴ | Yongliang Wang | Strategy, Action | Free / Free | no ratings | no ratings | 2026-10-24 | 2026-10-24 | 12+ |


¹ The India storefront uses a different name for the same app: "1945 Arcade Airplane Shooter" (MEASURED, `lookup_in.json`). This is per-locale name targeting: "arcade" and "shooter" in India, "air force" and "airplane games" in the US. The subtitles differ too (section 2b).
² The US releaseDate is in the future and the US price field is missing. It is probably a pre-order in the US (HYPOTHESIS).
³ **releaseDate is per storefront, so it is not the app's launch date.** The Lookup API returns a different `releaseDate` for 7 of the 26 apps depending on `country`. Examples: Metalstorm is 2023-11-07 in US and 2024-12-17 in IN, and Modern Jet Fighters is 2026-11-05 in US and 2026-10-01 in IN. The likeliest reading is the date the app became available in that storefront (HYPOTHESIS). Where the two dates differ, the IN date is shown in bold. "Last update" is `currentVersionReleaseDate` from the US lookup.
⁴ Added in the second pass (method step 3). Last Wing was released 2026-10-24, one day before this fetch, and has no ratings yet.

Icon and screenshot URLs for every row are in the appendix.

**What the table says**
- All 26 are free to download in India, and 25 of 26 in the US. Modern Jet Fighters has no US price yet (MEASURED). There's no paid-upfront competitor. Every one of the 26 sells in-app purchases (MEASURED, product pages, section 2b).
- Age rating: 15 of 26 are 12+, 7 are 9+, 3 are 4+, 1 is 17+ (MEASURED, Lookup API `trackContentRating`). These are the **pre-iOS 26 values**: Apple's current scale on iOS 26 and later is 4+/9+/13+/16+/18+, and 12+/17+ remain only for devices on earlier OS versions (VERIFIED, `apple-requirements.md` §11.1). The API still returns the old scale.
- Downloads are large: reported `fileSizeBytes` runs from 102 MB (Air Battle) to 2,792 MB (Metalstorm). War Thunder Mobile is 1,319 MB, Armed Air Forces 1,860 MB and Air Combat Online 1,505 MB (MEASURED, Lookup API `fileSizeBytes` in `competitors.json`). Toy Plane Sim's iOS size is unknown. The desktop zips in `builds/` are 41–68 MB, which is not the same thing.
- Among the original 20, India rating counts run from 0.5% (Wings of Heroes) to 20% (Sky Combat 2) of each app's US count. In absolute terms only 1945 Air Force (65,598) and Airline Commander (14,853) pass 6,000 India ratings. Outside the table, Airplane Pro: Flight Simulator has 11,601 (MEASURED, `search/*_in.json`). The India plane-combat field is thin in visible ratings. Whether that means low demand or just fewer people leaving ratings: unknown.
- Most apps are actively maintained: 16 of 26 have been updated since August 2026. The stale ones are Air Battle (2019), WW2 Warplane Fighter Bomber (2023), ACE Fighter (May 2024), Sky Force Reloaded (July 2024) and AirFighters (March 2025) (MEASURED).
- The new combat entrants are small in India: Warplanes has 34 IN ratings, WW2 Warplane Fighter Bomber 34, Jet Attack Move 60 and ACE Fighter 151. Even the #2 result for "dogfight" has a thin India footprint (MEASURED).

## 2b. Subtitles and in-app purchase prices (MEASURED, apps.apple.com product pages, 2026-10-25)

The subtitle is the best public evidence of which words a rival targets, because Apple indexes it (VERIFIED, `apple-requirements.md` §1.2). Raw data, including every listed IAP item and price: `data/competitor_pages.json`.

| App | Subtitle IN (en-GB page) | Subtitle US (en-US page), if different | IAPs shown (max 10) | INR price range (paid items) | USD price range | What the IAPs sell (from item names) |
|---|---|---|---|---|---|---|
| 1945 Air Force: Airplane Games | Epic Air Attack in Space Games | Classic Arcade Sky Shooter | 10 | ₹99–₹9,900 | $0.99–$99.99 | Package gem 3 sale off; Package gem 2 sale off; Pack Gem 1; Package gem 6 sale off… |
| Epic Plane Evolution | Launch, Upgrade, Fly | same | 10 | ₹199–₹9,900 | $1.99–$24.99 | Remove Ads; 10 Gems; 100 Gems; Coins Tier 3… |
| Sling Plane 3D - Sky Crash Jet | Try to go Far, Explore the Sky | same | 1 | ₹999–₹999 | $8.99–$8.99 | Special Offer |
| War Thunder Mobile | PvP Ship, Plane & Tank Battles | same | 10 | ₹299–₹4,999 | $2.99–$99.99 | Stack of Platinum Wolves; Pile of Platinum Wolves; Few Golden Eagles; Stack of Golden Eagles… |
| Airline Commander: Flight Game | A real airplane simulator | same | 10 | ₹99–₹2,999 | $1.99–$29.99 | AC Credits small; AC Credits medium; Offer Pack 3; Flight Pass Premium… |
| Go Plane | Most addictive plane game! | same | 1 | ₹299–₹299 | $2.99–$2.99 | Remove Ads |
| Wings of Heroes: Flying Games | Plane Battles War Simulator | same | 10 | ₹199–₹1,999 | $1.99–$99.99 | Offer 1; Credits large; Offer 1; Credits medium… |
| Sky Warriors: Airplane Games | Jet fighter flight simulator | Battle flight simulator game | 10 | ₹99–₹1,999 | $0.99–$19.99 | Special Offer Pack: 2; Piggy Bank Level 1; Special Offer Pack: 5; Special Offer Pack: 1… |
| Metalstorm: Modern Air Combat | 5v5 Multiplayer Dogfight Wars | same | 10 | ₹70–₹3,600 | $0.99–$99.99 | 170 Gold; Special Offer; 30 Gold; 80 Gold… |
| Armed Air Forces - Jet Fighter | Flight simulator of PC quality | same | 10 | ₹199–₹199 | $1.99–$1.99 | F-35 Lightning II; Su-57 Felon; F-22A Raptor; B-2 Spirit… |
| Alliance: Air War | Airplane Flight Simulator Game | same | 10 | ₹99–₹299 | $0.99–$24.99 | Platinum Supporter (Sale); Platinum Supporter; Fuel Purchase Small; F-22A Navy Plane… |
| Bomber Ace: WW2 war plane game | Airplane fighter simulator | same | 10 | ₹99–₹2,999 | $0.99–$14.99 | 50 Gems; No Ads; 200 Gems; Premium Pack… |
| AirFighters Combat Flight Sim | none set (page shows genre "Simulation") | same | 10 | ₹299–₹1,999 | $2.99–$17.99 | F22 RAPTOR; PREMIUM; SU-47 BERKUT; F-14 SUPER TOMCAT… |
| War Plane Strike: Sky Combat | Become an Ace in Plane Combat! | same | 10 | ₹99–₹2,499 | $0.99–$24.99 | No Ads; Mega Bundle; Special Offer; Special Offer… |
| Sky Force Reloaded | none set (page shows genre "Action") | same | 5 | ₹199–₹999 | $1.99–$9.99 | Precious Cargo; SX2 - Star Doubler; Plane Generator; Ads Removal… |
| Air Battle - Sky Fighters 3D | Airforce Fight for Victory | same | 10 | ₹199–₹9,900 | $1.99–$19.99 | package 60% off; package with 75% off; 5000 coins; 300 diamonds… |
| Jet Attack Move | Arcade Air Combat | same | 3 | ₹199–₹399 | $1.99–$3.99 | No Ads; Golden Su-57; Golden F/A-18 |
| Warplanes: WW2 Dogfight | none set (page shows genre "Action") | same | 10 | ₹99–₹799 | $0.99–$7.99 | 500 Gold; Haunebu II; Ju 287; P-80… |
| WW2 Warplane Fighter Bomber | Warplane bombing action | same | 1 | ₹399–₹399 | $3.99–$3.99 | Unlock Premium Planes |
| Air Wings® | Multiplayer Flying Battles! | same | 10 | ₹199–₹799 | $1.99–$7.99 | Plane Pack #3; Plane Pack #1; Plane Pack #2; Everything Bundle… |
| ACE Fighter: Modern Air Combat | High Quality Flight Simulation | same | 10 | ₹99–₹7,900 | $0.99–$49.99 | Medium Gold Pack; Small Gold Pack; Large Gold Pack; Starter Pack… |
| Air Combat Online | 4v4 modern jet fighters | same | 10 | ₹99–₹9,900 | $0.99–$99.99 | Bonus Open Ticket; Quarterly card; Daily Selection; Daily Growth Package… |
| Dogfight Elite Airplane Combat | WWI & WWII Multiplayer Combat | same | 10 | ₹199–₹11,900 | $1.99–$31.99 | 1 Month advance access plus; Purchase 300,000 DC; Purchase 150,000 DC; 1 Year Premium… |
| Sky Combat 2: Fighter planes | Modern warplanes, jet shooter | same | 10 | ₹99–₹4,999 | $0.99–$19.99 | First Offer; Proposition Horizon 1; Proposition Celestial 1; Proposition Skyspirits 1… |
| Modern Jet Fighters Online | Nonstop Sky Combat Anytime | same | 10 | ₹99–₹9,900 | $0.99–$99.99 | Jaguar Bundle; Jaguar Discount Bundle; F-35 Discount Bundle; F-35 Bundle… |
| Last Wing: Air Combat Shooter | Jet Fighter Plane War Games | same | 2 | ₹199–₹299 | $1.99–$2.99 | 5 Repair Kits; Remove Ads |


**What the subtitles say (MEASURED counts, HYPOTHESIS readings)**
- **Plane, sim and combat words dominate.** Of the 23 apps that set a subtitle: "plane"/"airplane"/"planes" appears in 8, "simulator"/"simulation" in 7, "jet" or "fighter" in 5, "war"/"warplanes"/"warfare" in 5, "combat" in 4 and "battle(s)" in 4.
- **Only 4 sell multiplayer or team size:** Metalstorm "5v5 Multiplayer Dogfight Wars", Air Combat Online "4v4 modern jet fighters", Air Wings "Multiplayer Flying Battles!" and Dogfight Elite "WWI & WWII Multiplayer Combat".
- **Only Metalstorm puts "dogfight" in its subtitle,** and it pairs the word with "Multiplayer". This is the closest rival phrasing to Toy Plane Sim's draft "Dogfight friends in toy planes".
- **No subtitle uses "friends", "toy", "cartoon" or "aeroplane"** (MEASURED, all 52 pages). "aeroplane" is the IN P1 word (`keyword-research.md`), and no rival targets it in the subtitle.
- **Two rivals localize the subtitle per storefront.** 1945 Air Force uses "Epic Air Attack in Space Games" in IN and "Classic Arcade Sky Shooter" in US. Sky Warriors uses "Jet fighter flight simulator" in IN and "Battle flight simulator game" in US. This is evidence that per-storefront keyword targeting is in use.
- **Three apps set no subtitle:** AirFighters, Warplanes: WW2 Dogfight and Sky Force Reloaded.

**INR prices against Toy Plane Sim's ₹79–₹499 (MEASURED, IN product pages; Toy Plane Sim prices VERIFIED, `shop.gd:18-33`)**
- **Before using this for decisions:** Toy Plane Sim's INR values are what the code says will be set; whether Apple's India list offers them is checked in `apple-requirements.md` §11.6. ₹99, ₹199 and ₹499 are live in 92–112 IN apps each (MEASURED); ₹79 appears in only 1 of 214 sampled apps, so it is unconfirmed.
- **Entry prices:** each app's cheapest listed paid item has a median of **₹199** across the 26 apps (range ₹70 for Metalstorm's "30 Gold" to ₹999). ₹99 is the most common entry price.
- **Listed paid items:** 205 in total, with a median of ₹499. 118 of the 205 (58%) fall within ₹79–₹499. 78 cost ₹999 or more (top tiers reach ₹9,900–₹11,900, mostly currency packs and subscriptions).
- **Remove-ads purchases** range from ₹99 (Warplanes) to ₹699 (Epic Plane Evolution). Most cost ₹199–₹399.
- **Cosmetic or single-plane purchases priced like Toy Plane Sim's:** Jet Attack Move sells "Golden Su-57" and "Golden F/A-18" at ₹399 each. Air Wings sells a "Toy Plane Pack" at ₹199 and an "Everything Bundle" at ₹799. Warplanes sells single premium planes at ₹99. Armed Air Forces sells single planes at ₹199.
- **Reading (HYPOTHESIS):** Toy Plane Sim's ₹79 trails and kill effects sit just under the common ₹99 entry point. Its ₹99 paints, ₹199 sets and ₹499 bundle sit inside the band where most rivals' smaller items cluster. The prices look in line with the market, not high. The main difference is what the money buys: rivals mostly sell currency, fuel and offers, while Toy Plane Sim sells only one-time cosmetics.
- **Caveat:** the page shows only up to 10 IAPs, so apps with more items have prices this sample doesn't show.

## 2c. India pass: Indian-developer plane games (MEASURED, 2026-10-25 ~17:10 IST)

None of the first 26 is from an Indian publisher, so I searched for one.
- **The two IN-only hint phrases were scored** (`keyword-research.md`, round 3). "indian plane game" is IN hint #1 at `indian plane`, and "real plane game" is IN hint #2 at `real plane` (MEASURED, hints endpoint). Neither is hinted in the US.
- **Their IN top 10 holds no Indian-developer plane game.** "indian plane game" returns only 9 IN results, none of them about Indian planes: Infinite Flight, Truck Simulator, Sniper 3D, Subway Surfers, a cooking game, two small flight sims, Instagram and YouTube. "real plane game" returns flight sims: Airline Commander, X-Plane, Flight Simulator Advanced, Infinite Flight, RFS and others (MEASURED, `data/raw_search.json`, sellers in `seller_top10`).
- **The Indian title surfaces on IAF searches instead.** "indian air force game" (an Avoid term, `keyword-research.md`), "indian air force" and "iaf" all return **Indian Air Force: A Cut Above** at #1 in IN (MEASURED, iTunes Search API, `country=in`). I added it as competitor #27.

| # | App | Seller | Genres | Price US / IN | Rating US (count) | Rating IN (count) | releaseDate US / IN | Last update | Age | Size |
|---|---|---|---|---|---|---|---|---|---|---|
| 27 | Indian Air Force: A Cut Above (id 1451450072) | THREYE INTERACTIVE PRIVATE LIMITED | Education, Adventure, Action | Free / Free | 4.30 (128) | 4.09 (2,025) | 2019-03-15 / 2019-03-15 | 2026-01-30 | 9+ | 897 MB |

Source: Lookup API, `data/lookup_india_in.json` and `data/lookup_india_us.json`; row added to `data/competitors.json`. Product page (`data/competitor_pages.json`): subtitle "[DISHA - IAF HQ]" in both stores, and **no In-App Purchases listed**.
- **What it is (MEASURED, its description):** the official IAF game. It has single-player missions, an online multiplayer with "squad vs squad" and "free for all" modes, a "dogfight mode", and a recruitment "career navigator". The same seller has an AR spin-off, IAF: A Cut Above - AR (19 IN ratings).
- **Seller nationality:** the seller name is an Indian company form, and the app is the Indian Air Force's own game, so Indian-developed is near certain. The Lookup API has no country field, so this is HYPOTHESIS by name and content.
- **Reading (HYPOTHESIS):** with 2,025 IN ratings it is the only India-made plane game with a visible footprint, and its IN rating count is 5th among the 23 plane-combat apps in this set, after 1945 Air Force (65,598), Sky Warriors (4,929), War Thunder Mobile (3,273) and AirFighters (2,056). Its pull comes from the IAF brand, which Toy Plane Sim can't and shouldn't borrow (official-name risk, `keyword-research.md` Avoid list). It shows Indian players will play an online plane-combat game, but it isn't a positioning rival for a toy-plane game.

## 2d. Chart benchmark: what it takes to chart (MEASURED, iTunes RSS + Lookup API, 2026-10-25 17:17 IST)

Source: `https://itunes.apple.com/<cc>/rss/topfreeapplications/limit=200/genre=<7001|7015>/json` for the top-free iPhone charts, Games/Action (7001) and Games/Simulation (7015), joined with `userRatingCount` from the Lookup API in the same storefront. Script: `aso/tools/fetch_charts.py`. Raw data: `data/charts.json`.
- **The feed returned 100 entries, not the 200 requested** (MEASURED, all four charts). So the band below is #50–#100. Ranks #101–#200: unknown from this free source.
- Charts rank by recent downloads (HYPOTHESIS: Apple doesn't publish the formula). `userRatingCount` is lifetime ratings, so it is a proxy for an app's size, not for the downloads needed to chart. Single snapshot, one time of day.

Rating counts of the apps at ranks #50–#100 (51 apps per chart):

| Chart | Min | 25th pct | Median | 75th pct | Apps under 1,000 ratings | Apps under 5,000 |
|---|---|---|---|---|---|---|
| IN Action | 0 | 1,030 | 7,046 | 19,525 | 11 | 22 |
| IN Simulation | 11 | 566 | 3,780 | 11,604 | 15 | 28 |
| US Action | 732 | 30,165 | 74,601 | 201,953 | 1 | 4 |
| US Simulation | 34 | 17,101 | 59,633 | 137,183 | 4 | 8 |

Across the whole top 100: IN Action has 18 apps under 1,000 ratings, and IN Simulation 31 (MEASURED).

**Plane games in these charts (MEASURED, by name, checked by hand):**
- IN Simulation: Crazy Plane Landing #8 (738 IN ratings), Epic Plane Evolution #41, Infinite Flight #64, Airplane Pro #88, Airline Commander #94. All are flight sims or hypercasual.
- IN Action: Airline Commander #82. ("Super Fighter 3" at #65 matched the name filter, but it's not a plane game.)
- US Action: Wings of Heroes #82. US Simulation: Epic Plane Evolution #30.
- No plane-combat multiplayer game (Sky Warriors, Metalstorm, War Thunder Mobile) is in any of the four top-100 charts at this snapshot.

**India-made titles in the IN charts (HYPOTHESIS by seller name and India-themed titles):** Highbrow Interactive holds #1 (Truck Masters: India Simulator), #43 and #47 in IN Simulation. Cricket games from Indian studios sit at #55, #62 and #77. India-themed simulators chart well in the Simulation list.

**What this turns "thin India field" into:**
- An IN Action or IN Simulation top-100 entry sits among apps whose median is about 4k–7k lifetime ratings at #50–#100. But 11–15 of those 51 apps have under 1,000, and some have under 100. So a new app can chart in India with few ratings, if it gets a burst of downloads (MEASURED counts; HYPOTHESIS about why).
- The US bar is roughly 10–20× higher at the median (75k Action, 60k Simulation).
- **For the Action vs Simulation choice (`apple-requirements.md` §5):** IN Simulation has the lower bar (median 3,780 vs 7,046; 15 vs 11 apps under 1,000 ratings) and is where Indian players already find plane games (5 plane titles vs 1). Against it, every plane title there is a sim or hypercasual game, so an arcade combat game would sit next to the realism it says it isn't, and "Sim" in the name would add to that reading. Action has the arcade shooters. This data doesn't settle the choice; it puts numbers on both sides (HYPOTHESIS on searcher behaviour).

## 3. Search landscape

### Top 3 per term (MEASURED, API order; see caveat in section 1)

| Term | India top 3 | US top 3 |
|---|---|---|
| airplane game | Airplane Pro / Airline Commander / Infinite Flight | Airplane Pro / Sky Warriors / Infinite Flight |
| plane game | Infinite Flight / Airplane Pro / Airline Commander | Epic Plane Evolution / Infinite Flight / Airplane Pro |
| dogfight | Metalstorm / Warplanes: WW2 Dogfight / WW2 Warplane Fighter Bomber | Metalstorm / Warplanes: WW2 Dogfight / Jet Attack Move |
| air combat | Metalstorm / ACE Fighter / Modern Warships | Metalstorm / Alliance / Air Combat Online |
| flight simulator | Infinite Flight / Airline Commander / Flight Simulator Advanced | Infinite Flight / X-Plane / Airline Commander |
| plane battle | Sky Warriors / Go Plane / War Thunder Mobile | Metalstorm / Sky Warriors / Go Plane |
| fighter plane | Metalstorm / Sky Warriors / Armed Air Forces | Metalstorm / Wings of Heroes / Alliance |
| airplane multiplayer | **Air Wings** / Flight Simulator 2026 / Metalstorm | **Air Wings** / Metalstorm / Flight Simulator 2025 |
| sky battle | Sky Warriors / SkyBattle Board / Sky Force Reloaded | Sky Warriors / Sky Force Reloaded / Sky Battleships |
| toy plane | Sling Plane 3D / Epic Plane Evolution / Rc Plane 2 | Rc Plane 2 / Epic Plane Evolution / Sling Plane 3D |
| paper plane | Air Wings / Paperly / How to make Paper Airplanes | Epic Plane Evolution / Paper Planes App / Paper Plane !! |
| arcade plane | 1945 Arcade Airplane Shooter / Sky Warriors / 1941 Air Attack | Falling Plane / 1945 Air Force / Shooty Skies |

Observations:
- **Metalstorm owns combat terms**: it is #1 for "dogfight", "air combat" and "fighter plane" in both stores, and #1 for "plane battle" in the US (MEASURED). Sky Warriors appeared in 21 of the 24 result lists, the most of any app (MEASURED).
- **"toy plane" has no combat game in its top 8 in either store. Only the two broad combat incumbents appear, at #9–#10:** War Plane Strike: Sky Combat (#9) and Sky Warriors (#10) in the US, and Sky Warriors (#9) in India. Ranks #1–#8 are RC flight sims (Rc Plane 2, RC Plane 3, Absolute RC Simulator), hypercasual distance games (Epic Plane Evolution, Sling Plane 3D, Go Plane, Plane Evolution!), airline games, a paper plane and one "Toy Plane Glider" with 0 ratings (MEASURED, `search/toy_plane_*.json`; a live re-query at 17:19 IST on 2026-10-25 returned the same top 10 in both stores). An earlier version of this file said "no combat game in its top 10", which was wrong against this data.
- **"dogfight" rewards titles that contain the word.** Warplanes: WW2 Dogfight is #2 in both stores, and WW2 Warplane Fighter Bomber and Jet Attack Move are #3–#4, all with small IN rating counts: 34, 34 and 60 (MEASURED). That suggests "dogfight" is winnable in India for a new app that indexes the word (HYPOTHESIS).
- **"airplane multiplayer" is led by Air Wings**, a 2012 paper-airplane battle game with 1,183 US / 197 IN ratings (MEASURED). That is a weak incumbent on the term closest to Toy Plane Sim's core (HYPOTHESIS).

### Autocomplete hints (MEASURED, `data/hints/`)

| Typed | US suggestions (first few) | India suggestions (first few) |
|---|---|---|
| plane game | plane games, plane games for kids, fighter plane games, war plane games, free plane games, offline plane games, ww2 plane games | plane games, air plane game, plane game 3d, fighter plane games, jet plane game, **indian plane game**, war plane games |
| airplane game | airplane games, airplane games for kids, airplane games no wifi, airplane games offline | airplane games, airplane games kids, sky warriors: airplane games |
| dogfight | dogfight games, warplanes: ww2 dogfight, ww2 dogfight | warplanes: ww2 dogfight, dogfight, dogfight elite |
| air combat | air combat games, ace fighter, last wing, metalstorm | air combat, last wing, ace fighter, metalstorm, air combat online |
| toy plane | toy plane glider, toy planet track, toy planet ops | toy plane glider, toy planet track |
| airplane multiplayer, plane multiplayer, plane games with friends | **no suggestions** | **no suggestions** |

- "for kids", "offline" and "no wifi" variants appear for US generic plane terms (MEASURED). "indian plane game" appears in India (MEASURED).
- Every multiplayer and friends phrasing I tried returned no suggestions. Neither did a "toy plane" + game phrasing (MEASURED). One reading is that few people type these phrases (HYPOTHESIS). It is not a volume figure: volume is **unknown**.

## 4. What reviewers say

**Source (MEASURED):** customer reviews RSS, `https://itunes.apple.com/<cc>/rss/customerreviews/page=N/id=<ID>/sortby=mostrecent/json`, fetched 2026-10-25. Each page holds up to 50 of the newest reviews.

**Feeds:**
- The first pass got 10 of 16 feeds. The 6 empty ones:
  - Airline Commander IN
  - 1945 Air Force US
  - Sling Plane 3D IN
  - War Thunder Mobile IN
  - Air Wings US
  - Epic Plane Evolution US
- **Retried in the second pass with the `page=1` URL form: all 6 returned data on the first request.** Sling Plane IN has only 26 reviews.
- To give the India-first decisions more than 5 IN feeds, I also pulled IN page 1 for Sky Force Reloaded, Jet Attack Move (11 reviews) and Warplanes (6 reviews). I added IN page 2 for Sky Warriors, Metalstorm and 1945 Air Force.
- **Total: 22 feeds, 993 reviews. 14 IN feeds hold 593 reviews, and 8 US feeds hold 400.** Page-2 reviews reach further back (some from 2023).

| App | IN feed (reviews, avg ★) | US feed (reviews, avg ★) | Lifetime ★ IN / US |
|---|---|---|---|
| Epic Plane Evolution | 50, 2.14 | 50, 3.02 (was missing) | 4.35 / 4.62 |
| Sling Plane 3D | 26, 1.42 (was missing) | 50, 2.64 | 4.27 / 4.34 |
| Airline Commander | 50, 2.34 (was missing) | 50, 2.56 (a crash-on-launch update on 2026-10-03/04) | 4.34 / 4.57 |
| Sky Warriors | 50 + 50 p2, 3.04 / 2.96 | 50, 3.54 | 4.54 / 4.68 |
| 1945 Air Force | 50 + 50 p2, 3.50 / 3.06 | 50, 3.58 (was missing) | 4.75 / 4.83 |
| War Thunder Mobile | 50, 3.22 (was missing) | 50, 3.66 | 4.73 / 4.81 |
| Metalstorm | 50 + 50 p2, 3.62 / 3.96 | 50, 3.94 | 4.69 / 4.78 |
| Sky Force Reloaded | 50, 3.50 (new) | not fetched | 4.62 / 4.75 |
| Air Wings | 50, 4.06 (reviews span 2015–2025) | 50, 3.24 (was missing) | 4.51 / 4.30 |
| Jet Attack Move | 11, 4.82 (new) | not fetched | 4.87 / 4.84 |
| Warplanes: WW2 Dogfight | 6, 4.00 (new) | not fetched | 4.29 / 4.44 |

**Recent reviews are much harsher than lifetime ratings (MEASURED).** Every feed with 26 or more reviews averages below its lifetime rating, by 0.4 to 2.9 stars. Lifetime averages are probably inflated by well-timed in-game rating prompts, and unhappy players write text reviews (HYPOTHESIS). Either way, a 4.5+ star average is the norm for this category, not a differentiator (MEASURED: all 24 apps with US ratings are at 4.3 or higher).

### Theme counts, with hand-checked precision

**Method.** Themes are regex matches over each review's title plus body (`aso/tools/review_themes.py`). The first-pass counts were unvalidated, so I hand-checked samples:
- **Round 1:** 52 regex-matched reviews, 4 per theme (`data/review_handcheck_v1.csv`). Six themes scored below 70% precision. The main false positives:
  - "ads" caught "No adds" praise and complaints about misleading marketing ads.
  - "friends" caught "Friends," used as a form of address.
  - "fuel" caught "fuel train" missions.
- **Round 2:** I tightened those six patterns and hand-checked a fresh, non-overlapping sample of 36 reviews (`data/review_handcheck.csv`).

**Precision** is the share of regex matches that really are about the theme (MEASURED, by my reading). For themes whose pattern didn't change, both rounds are pooled. The samples are small, so read each figure with its n.

| Theme | Precision (sample) | Used below? | Count, IN feeds (593 reviews) | Count, US feeds (400 reviews) | Where it concentrates |
|---|---|---|---|---|---|
| Ads (complaint) | 88% (7/8, v2) | yes | 42 | 42 | Epic Plane Evolution US 22/50 and IN 13/50; Sling Plane US 13/50 and IN 12/26 |
| Crashes / won't open / stuck | 89% (8/9) | yes | 38 | 19 | Airline Commander IN 15/50 and US 8/50 |
| Pay-to-win / grind | 88% (7/8, v2) | yes | 4 | 17 | War Thunder Mobile US 6/50; Sky Force IN 3/50 |
| More maps / modes / levels | 100% (5/5) | yes | 13 | 2 | Sky Warriors IN 3+3; Sky Force IN 2 |
| Matchmaking / bots | 100% (6/6) | yes | 8 | 11 | Metalstorm US 4/50; Air Wings US 4/50 |
| Friends / private rooms / local play | 83% (5/6, v2) | yes | 8 | 6 | Air Wings IN 3 and US 4; Metalstorm IN p2 3 |
| Misleading store art / ads | 80% (4/5) | yes | 1 | 10 | Sling Plane US 7/50 |
| Cockpit view requests | 80% (4/5) | yes | 5 | 6 | Metalstorm, all feeds |
| Toxic chat / players | 75% (3/4) | yes, n is small | 0 | 4 | Sky Warriors US 2 |
| Fun / simple / love (praise) | 83% (29/35) | yes | 94 | 126 | Metalstorm US 22/50 |
| Connection / server | 58% (7/12) | **dropped** (hand-read instead) | (39) | (8) | Sky Warriors IN p2 |
| Fuel / energy timers | 57% (4/7, v2) | **dropped** (hand-read instead) | (10) | (3) | Sky Warriors |
| "No ads" (praise) | 17% (1/6, v2) | **dropped** | (2) | (14) | mostly complaints *about* no-ads purchases |

**Hand-read checks for the dropped themes (MEASURED, my reading):**
- **Connection:** 10 of the 11 "connection" matches in the Sky Warriors IN page-2 feed are real disconnection complaints, for example "Non stop disconnection issue", "Disconnection issues!! Worst!" and "using 200 mbps wifi connection and yet … you have been disconnected". The 1945 Air Force IN feed has false "connect to internet" errors ("Internet connection error for no reason").
- **Offline:** one Sky Warriors IN reviewer asks: "Pls provide an offline mode so that we can enjoy this game during travel".
- **Fuel:** Sky Warriors fuel complaints are real ("You are forced to purchase fuel", "fuel tank we only able to play 2 to 3 games in one fuel section").
- **What the drop means:** these themes are real for Sky Warriors, but the regex counts over-state them, so no count is used.

**India-specific reading, paired apps only (MEASURED counts, `data/review_theme_counts.txt`, 16:51 IST regex version; reading is HYPOTHESIS).** The all-feed totals above are confounded: the IN feeds include Sky Force, Jet Attack Move, Warplanes and three page-2 feeds that have no US counterpart. So this compares only the 8 apps with a page-1 feed in both stores (Airline Commander, 1945 Air Force, Metalstorm, Sling Plane 3D, Sky Warriors, War Thunder Mobile, Air Wings, Epic Plane Evolution): 376 IN reviews, 400 US.

| Theme | IN rate (n=376) | US rate (n=400) |
|---|---|---|
| Ads (complaint) | 34 (9.0%) | 42 (10.5%) |
| Crash / won't open | 29 (7.7%) | 19 (4.8%) |
| Connection / server (58% precision, see above) | 19 (5.1%) | 8 (2.0%) |
| Pay-to-win / grind | 1 (0.3%) | 17 (4.2%) |
| Matchmaking / bots | 4 (1.1%) | 11 (2.8%) |
| Friends / private rooms | 5 (1.3%) | 6 (1.5%) |
| Misleading store art | 1 (0.3%) | 10 (2.5%) |
| Fun / simple (praise) | 49 (13.0%) | 126 (31.5%) |

- On the same apps, IN reviews complain more about crashes and connections, and US reviews more about pay-to-win, matchmaking and misleading art. Ads complaints are close (9.0% vs 10.5%). With these sample sizes, differences of one or two points are not reliable.
- US reviewers praise far more often (31.5% vs 13.0%). Part of that may be language: the praise regex is English, and IN reviews mix in Hinglish (HYPOTHESIS).

### Per app: recurring complaints and praise (brief quotes, MEASURED, hand-read)

**1945 Air Force (IN feed).** Complaints: false "no internet" errors ("game keeps telling me I need to connect to internet to play"), ads ("too many ads"), harsh nerfs to rewards ("rewards have been reduced drastically"). Praise: nostalgia, "simple and easy game", "best for time pass". One reviewer asked for a music/sound toggle.

**Epic Plane Evolution (IN feed).** About half the latest 50 are about ads: "Its not game its ads platform", "1 ad every 2 plays and every play is like 10 sec", "nothing like showed in ads and app store pics". One reviewer called the ₹999 subscription absurd: "gta 5 bhi 1700 puri game mil jaati" (all of GTA 5 costs ₹1,700).

**Sling Plane 3D (US feed).** Ads ("I saw more ads than game"), misleading store art and ads ("the pictures are for Epic Plane evolution", "nothing like the advertisement"), and the game hits a ceiling ("Never able to fly any farther than 10,000m"). Praise: "Good road trip game… with no internet", "satisfying".

**War Thunder Mobile (US feed).** Pay-to-win and grind ("extremely grindy and pay to win", "Higher tier tanks in lower level game matches"), bots and toxic players, storage ("Too much storage"), and players who can't talk to their friends ("almost impossible to communicate with friends"). Praise: realism, historical vehicles, "no adds".

**Airline Commander (US feed).** Most of the latest 50 report the October 2026 update crashing on launch. Other themes: too many ads, pay-to-win ("set up for paying players mainly"), lost progress tied to a Facebook login. Requests: "Please add a free flight mode", "needs multiplayer".

**Sky Warriors (US + IN feeds).** Fuel timers ("waiting 8 minutes for a SINGLE slot", "You are forced to purchase fuel"), the move from friends to bots ("We used to play with friends… now I've played only with bots"), toxic chat ("Almost everyone says bad words", "adults that bully and harass children"), and unfair matchups. One India review asked for local play ("add feature that we can local friends"). Another complained that India was missing from the country list. Praise: "simple and fun", "no ads".

**Metalstorm (US + IN feeds).** Matchmaking ("spend 30 mnt just to find a game", "very one sided"), bots, slow unlocks or pay-to-win, disconnects. India-specific requests: Tejas and Su-30 aircraft, personal rooms ("If we can play in separate rooms… we want to face off against our friends"), customisable controls, longer matches. Praise is strong and specific: "Simple. Stylish. Fun. The music elevates the experience", "No adds, super easy to learn, and doesn't really seem p2w", "skill based", and a request for "Air to Ground attack modes. Like destroying a base while fighting enemy aircraft and SAM Missiles".

**New IN feeds (second pass).**
- **Airline Commander IN:** mostly the same October 2026 crash-on-launch ("App not opening since 3Oct26 iPhone17"), plus ads and grind ("too grundy … without putting in real money").
- **War Thunder Mobile IN:** update frequency and download size ("Its annoying to have to update every 2-3 days", "taking too much time to load the add on packs").
- **Jet Attack Move IN:** asks for rooms ("need to be fix in multiplayer co op and specially custom room") and more missions.
- **Warplanes IN:** "pls add multiplayer". Also praise for playing with no internet during a power cut.
- **Sky Force Reloaded IN:** ads after every play, upgrade grind, and "Pls add a chat feature".

**Air Wings (IN feed, the closest concept: paper-plane multiplayer).** Loved but empty: "most underrated game", "Great game, less player base", "Many times nobody is online", "in multiplayer slow to found opponent", "vs. Computer mode not there". Players asked for LAN ("connecting through lan wifi"), and some said they play with cousins and friends ("We can play Local").

## 5. Visual patterns (MEASURED: I looked at all 26 icons and first iPhone screenshots)

The first 20 were viewed in the first pass. The 6 added in the second pass were viewed on a separate contact sheet; their notes are at the end of each bullet.

**Icons**
- **Blue sky everywhere**: of the first 20 icons, 13 are mostly sky blue or sea blue, 2 are partly blue, and 5 are not (1945, Armed Air Forces, AirFighters, Dogfight Elite, Modern Jet Fighters). The 6 added: Warplanes is mostly blue sky, ACE Fighter and Last Wing are partly blue, and three use other colours: WW2 Warplane Fighter Bomber on grey/white, Jet Attack Move on green, Sky Force Reloaded on yellow. **Total: 14 of 26 mostly blue, 4 partly, 8 not.**
- **Realistic beats stylized**: 14 of 20 are realistic or painterly renders of real aircraft (F-16, F-22, Su-series, P-40, airliners). The 6 stylized ones are 1945 (cartoon top-down), Epic Plane Evolution (low-poly camo jet), Sling Plane 3D (cartoon airliner), Go Plane (flat logo plus silhouette), Bomber Ace (cartoon P-51) and Air Wings (flat paper plane). Of the first 16 combat-focused apps (all except Epic Plane Evolution, Sling Plane, Go Plane and Airline Commander), only 3 icons are stylized: 1945, Bomber Ace and Air Wings.
  - The 6 added are all combat apps, and 4 have stylized icons: WW2 Warplane Fighter Bomber (silhouette P-51), Jet Attack Move (flat F-22), Last Wing (cartoon jet on a sunset) and Sky Force Reloaded (stylized 3D plane).
  - Warplanes (painterly Spitfire) and ACE Fighter (pilot helmet) are realistic.
  - **Total: 7 of 22 combat-focused icons are stylized.** The newer and smaller combat apps lean stylized, so "stylized" alone is less rare than the first pass suggested.
- **Composition**: one hero aircraft at a three-quarter, nose-forward angle, often with muzzle flash or missile smoke. Three use a pilot-helmet close-up (Air Combat Online, Modern Jet Fighters, ACE Fighter). Five carry a wordmark or logo (Go Plane, Armed Air Forces, Alliance, Dogfight Elite, Metalstorm).
- **Toy Plane Sim's current icon** (`assets/ui/icon_ios.png`): a chunky yellow low-poly plane on flat sky blue. The yellow plane is distinctive. The blue background is the category default. The closest look-alike is Epic Plane Evolution, a low-poly plane on blue (HYPOTHESIS: it may blend in at thumbnail size, and a non-blue background or a stronger toy cue could help. Test it, don't assume).

**First screenshots**
- **Orientation**: 19 of 26 are landscape and 7 are portrait: 1945, Epic Plane Evolution, Sling Plane, Go Plane, War Plane Strike, Last Wing and Sky Force Reloaded. All the portrait ones are hypercasual or top-down shooters. The combat-multiplayer apps are all landscape, the same as Toy Plane Sim's existing 2868×1320 shots.
- **Caption text**: 8 of 26 first screenshots carry a headline. Among the 6 added, only Last Wing has one ("One jet left. You fly it."). Of the first 20, 7 carry a headline. 4 of those 7 sell multiplayer or friends: "FLY WITH FRIENDS AND TURN THE TIDE OF WAR" (Wings of Heroes), "5V5 MULTIPLAYER" (Metalstorm), "Play against with other player" (Air Battle), "KING OF THE HILL" (Air Wings). The other 13 are raw gameplay with HUD and no headline.
- **Camera**: third-person chase or side view dominates. There is one cockpit/HUD view (Alliance), and 1945 uses top-down. Most scenes are realistic terrain or ocean under a hazy sky. Nobody shows bright miniature or toy-scale worlds.

## 6. Gaps Toy Plane Sim could own

Each gap below lists the competitor evidence, the evidence that Toy Plane Sim has the feature, and the claim it supports.

### G1. Toy-scale stylized combat
- Competitors: 15 of the 22 combat-focused icons are realistic military aircraft. The 7 stylized ones are 1945, Bomber Ace, Air Wings, WW2 Warplane Fighter Bomber, Jet Attack Move, Last Wing and Sky Force Reloaded, and none of them is toy-like. On "toy plane", no combat game ranks in the top 8 in either store; the only combat results are the broad incumbents War Plane Strike and Sky Warriors at #9–#10, neither of them toy-styled. The only stylized multiplayer combat app, Air Wings, has 1,183 US ratings (MEASURED).
- Reading (HYPOTHESIS): the toy-combat look is uncontested in icons and on the "toy plane" results page, but the term isn't empty of combat: two large combat games already rank on it. So the claim is "nobody looks like this", not "nobody holds this term".
- Toy Plane Sim: low-poly toy planes (VERIFIED, the existing 2868×1320 captures as described in `game-audit.md` and the icon `assets/ui/icon_ios.png`; the cel-shaded look: game materials come from `main.toon()`, which loads `toon.gdshader`, `main.gd:3107-3110`).
- Use: make the look the visual differentiator in icon and screenshots. Don't make "toy plane" the main keyword: autocomplete suggests little typed interest and volume is unknown (HYPOTHESIS). Pair "toy" with terms people do type: "plane games", "dogfight", "fighter plane games".

### G2. Play with your friends by room code, no account, no matchmaking queue
- **Evidence base: thin.** 14 regex matches in 993 reviews (1.4%; about 12 real at 83% precision). 7 of the 14 come from Air Wings, 5 from Metalstorm and 2 from Sky Warriors (`data/review_theme_counts.txt`). It is a repeated request from players of the closest rivals, not a common complaint.
- Competitors: friends, private rooms and local play come up in 14 reviews (8 IN, 6 US; regex precision 83%, section 4). Reviewers report matchmaking waits and bots replacing people ("spend 30 mnt just to find a game", "now I've played only with bots"), ask for rooms ("ability to form personal rooms"), ask for local play ("we can local friends", "connecting through lan wifi"), and Air Wings has an empty lobby ("nobody is online") (MEASURED).
- Caveat: competitors do have social features. Metalstorm has Squadrons and private matches, Air Combat Online has a friend system and group battles, and War Thunder Mobile has squads (MEASURED, Lookup API descriptions in `lookup_us.json` and Metalstorm reviews). So the claim is **not** "the only game with friends". It is **"type a 5-letter code and you're in the same sky"**, plus LAN, plus AI to fill the match.
- Toy Plane Sim (VERIFIED, references from `game-audit.md`):
  - 5-character room codes: `rooms.gd:45-49`, `main.gd:338`.
  - LAN by IP: `main.gd:2465-2467`.
  - AI pilots at Rookie/Pilot/Ace: the lobby's "ENEMY PILOTS" selector, `main.gd:2513-2514`.
- Use: a first-screenshot headline in the same family as "FLY WITH FRIENDS". Competitors who use that message rank high, which suggests it is a proven hook (HYPOTHESIS).

### G3. No pay-to-win, no energy timers, no currency
- **Evidence base: thin.** 21 pay-to-win/grind matches in 993 reviews (2.1%), 17 of them in US feeds; War Thunder Mobile US alone has 6 (`data/review_theme_counts.txt`). The stronger evidence is structural: every rival sells IAP, mostly currency and offers (section 2b).
- Competitors: pay-to-win/grind has 21 matches (17 US, 4 IN; precision 88%). Fuel complaints are hand-read in Sky Warriors; the regex count was dropped for low precision (section 4). Every one of the 26 apps sells IAP, and most sell currency, fuel or offers (section 2b) (MEASURED). Sky Warriors makes you buy fuel, and Metalstorm and War Thunder Mobile are accused of pay-to-win. Positive mirror: Metalstorm's praise often names this ("doesn't really seem p2w") (MEASURED).
- Toy Plane Sim: every product is cosmetic and one-time, and "none of it changes speed, damage or armour. No coins/gems… no timers, no loot boxes" (VERIFIED, `shop.gd:4-6`). INR prices are ₹79–₹499 (VERIFIED, `shop.gd:17-33`).
- Use: say it plainly in the description and possibly in a screenshot caption ("Skins only. Never pay to win."). App Store rules require any such claim to be literally true. It is, per `shop.gd`.

### G4. No ads
- **Evidence base: mostly hypercasual players, not combat rivals' players.** 60 of the 84 ads matches (71%) come from two hypercasual, non-combat apps: Epic Plane Evolution (35) and Sling Plane 3D (25). The multiplayer combat rivals (Metalstorm, Sky Warriors, War Thunder Mobile, Air Wings, Jet Attack Move, Warplanes) have **0** ads matches between them. The rest are Airline Commander (9), 1945 Air Force (12) and Sky Force Reloaded (3) (`data/review_theme_counts.txt`). So don't over-weight "no ads" as a reason combat players switch: it answers a complaint of people coming from ad-heavy casual plane games.
- Competitors (MEASURED):
  - Ads are the top complaint theme: 84 matches, 42 IN and 42 US, precision 88%. They concentrate in the big casual plane games: Epic Plane Evolution 22/50 US and 13/50 IN, Sling Plane 13/50 US and 12/26 IN.
  - "No ads" praise shows up in hand-read Metalstorm and Sky Warriors reviews ("No adds, super easy to learn", "no glitches no ads"), but its regex count was dropped at 17% precision.
  - 9 rivals sell a remove-ads purchase in IN, at ₹99–₹699 (section 2b).
- Toy Plane Sim: no ad SDK or ad calls found by grepping the top-level `.gd` files for admob/advert/interstitial/rewarded (VERIFIED, limited to that grep; native plugins not audited).
- Use: description line and review-reply line. HYPOTHESIS: this matters most to India players coming from ad-heavy hypercasual plane games.

### G5. Honest screenshots
- Competitors: 11 matches say the store art or ads don't match the game (10 US, 1 IN; precision 80%) (MEASURED). Sling Plane's screenshots are even called out as another game's art ("the pictures are for Epic Plane evolution") (MEASURED).
- Toy Plane Sim: real 2868×1320 gameplay captures already exist in `builds/appstore/` (VERIFIED, file listing).
- Use: keep screenshots as real captures with captions on top. HYPOTHESIS: this protects early ratings from "looks nothing like the pictures" reviews.

### G6. Air-to-ground team modes and free flight
- Competitors: players ask for "Air to Ground attack modes. Like destroying a base while fighting enemy aircraft and SAM Missiles" (Metalstorm US), "Please add a free flight mode" (Airline Commander), more modes and maps (10 matches) (MEASURED).
- Toy Plane Sim (VERIFIED):
  - Base Assault, Capture the Flag, Co-op Escort and the other modes: the lobby mode selector, `main.gd:2503-2507`; mode names at `main.gd:10`.
  - Free Flight on an offline peer: `main.gd:272-279`.
  - Buyable AA/SAM/radar: `battlefield.gd:165`, `battlefield.gd:296` (SAM site).
  - Each line read in the code; `game-audit.md` uses the same references.
- Use: one screenshot on "Build SAM sites. Assault their base."

### G7. Family-safe social: preset taunts instead of open chat
- Competitors: toxic chat complaints in Sky Warriors ("Almost everyone says bad words", "adults that bully and harass children") and War Thunder Mobile (MEASURED, 3 matches). Category age ratings are mostly 12+ on the pre-iOS 26 scale the API returns (MEASURED); the iOS 26 equivalent is likely 13+ (`apple-requirements.md` §11.1).
- Toy Plane Sim: taunts are preset messages; "only the message number crosses the network… there is no free text to moderate" (VERIFIED, `taunts.gd:4-6`).
- Use: say "preset messages only, no open chat" in the description and in a screenshot caption. That answers the toxic-chat complaint for any player.
- Don't target "plane games for kids", or "for kids" anywhere. The phrase is reserved for the Kids category (VERIFIED, App Review Guideline 2.3.8; `apple-requirements.md`, `data/banned_terms.txt`), and the game has guns, rockets and online play. `keyword-research.md` lists it under Avoid.
- The final age rating depends on Apple's questionnaire, since the game has weapons. Expected 13+ on iOS 26 and later, 12+ on earlier versions (HYPOTHESIS, worked through in `apple-requirements.md` §11.1).

### G8. Small and light (unconfirmed)
- Competitors: 13 of the 22 combat-focused apps report 400 MB or more, up to 2,792 MB (MEASURED). How it was counted: the `size_mb` field in `data/competitors.json` (Lookup API `fileSizeBytes` ÷ 10⁶, US lookup), over the 26 original rows minus the four non-combat apps (Epic Plane Evolution, Sling Plane 3D, Go Plane, Airline Commander). The smallest of the 22 is Air Battle (102 MB). Of the 6 added in the second pass, Jet Attack Move (778 MB) and Sky Force Reloaded (720 MB) are over 400 MB, and Last Wing (119 MB) is the smallest. The India-pass addition, Indian Air Force: A Cut Above, is 897 MB.
- One War Thunder Mobile US review says "Too much storage", and a War Thunder Mobile IN review complains about add-on pack downloads (MEASURED, section 4). Install size likely matters more on the low-storage phones common in India (HYPOTHESIS).
- Toy Plane Sim: iOS size **unknown**. Measure the IPA's install size before claiming anything.

### G9. India-specific openings (HYPOTHESIS)
- Measured signals (MEASURED):
  - "indian plane game" autocomplete in India.
  - Metalstorm India reviewers ask for the Tejas and Su-30 twice.
  - A Sky Warriors reviewer is upset that India is missing from the country list.
  - India reviews are heavy on disconnections and false "connect to internet" errors (hand-read, section 4), and one asks for "an offline mode so that we can enjoy this game during travel".
  - 1945 Air Force targets India with its own name ("1945 Arcade Airplane Shooter") and its own subtitle. Sky Warriors also uses a different IN subtitle.
  - India pages are served in en-GB (section 2b).
  - The one visible India-made plane game is the official IAF game (2,025 IN ratings, online squad and dogfight modes), and it ranks on IAF searches, not on "indian plane game" (§2c).
  - "indian plane game" is IN hint #1 at `indian plane`, but its IN results hold no Indian plane game at all (§2c). Toy Plane Sim has no Indian content either, so it scores low on relevance (`keyword-research.md`).
- **Offline play is verified in code (VERIFIED, read in `main.gd`; matches `game-audit.md` "Works offline: Can, for solo"):**
  - Battle vs AI and Free Flight create an `OfflineMultiplayerPeer` (`main.gd:264-279`). No network peer is opened.
  - The lobby's mode selector lists every mode in the offline lobby too (`main.gd:2503-2507`). Team Dogfight still needs a human on each team, as the listing copy states.
  - Buying an IAP needs a connection.
  - Whether the iOS build behaves the same in airplane mode is untested on a device (unknown).
- Possible uses: India-localized title or subtitle wording ("aeroplane", en-GB), and "play solo vs AI with no internet" for patchy connections (HYPOTHESIS that this converts).

## 7. Things not to claim

- "Only multiplayer plane game with friends": false. Metalstorm, Air Combat Online, War Thunder Mobile and Wings of Heroes all advertise playing with friends (MEASURED, Lookup API descriptions).
- Any search-volume, download or ranking-position claim: **unknown** with free data.
- "Most realistic", or anything about real aircraft models: Toy Plane Sim is deliberately not realistic, and the realistic lane is crowded (MEASURED).

## 8. Raw data files

| File | Contents |
|---|---|
| `data/search/<term>_<in|us>.json` | 24 raw iTunes Search API responses (12 terms × 2 storefronts) |
| `data/lookup_us.json`, `data/lookup_in.json` | Raw Lookup API responses for the 20 competitors |
| `data/lookup_new_us.json`, `data/lookup_new_in.json` | Raw Lookup API responses for the 6 apps added in the second pass |
| `data/competitors.json` | Flattened table fields for all 26, first two screenshot URLs, file size, `release_us` / `release_in` |
| `data/competitor_pages.json` | Subtitle, IAP list (up to 10) and page language per app and storefront, from apps.apple.com (`tools/fetch_pages.py`); includes #27 |
| `data/lookup_india_in.json`, `data/lookup_india_us.json` | Raw Lookup API responses for Indian Air Force: A Cut Above and its AR spin-off (§2c) |
| `data/charts.json` | IN/US top-free Games/Action and Games/Simulation charts (100 each) with Lookup rating counts (`tools/fetch_charts.py`, §2d) |
| `data/in_price_points.json` | Which INR prices appear in live IN IAP lists (`tools/price_points.py`, `apple-requirements.md` §11.6) |
| `data/reviews/<id>_<in|us>[_p2].json` | Raw RSS review feeds: 22 feeds, all non-empty (`tools/fetch_reviews.py`) |
| `data/review_theme_counts.txt` | Theme counts per feed, v2 patterns (`tools/review_themes.py counts`) |
| `data/review_handcheck_v1.csv`, `data/review_handcheck.csv` | Hand-checked samples (52 + 36 reviews) behind the precision column (`tools/review_themes.py precision`) |
| `data/hints/<term>_<in|us>.xml` | Raw autocomplete hint plists (sent with `X-Apple-Store-Front`) |
| `tools/contact_sheet.gd` | Godot script that tiles images into a contact sheet: `godot --headless --path <project> -s aso/tools/contact_sheet.gd -- OUT.png CELL COLS img...` |

## Appendix: icon and first screenshot URLs (MEASURED, Lookup API `artworkUrl512` and `screenshotUrls`, 2026-10-25)

Numbers follow the first-pass order (1–20), then the 6 added (21–26). They are not the table's # column.

1. **1945 Air Force: Airplane Games**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/a2/e5/d4/a2e5d41e-dc89-86f6-ed77-3d169a5e01c8/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/a7/71/55/a77155eb-d126-6cfe-1871-5fd796ab0b1f/3803c7a6-fb61-4089-bd39-bde9bcb8c2fe_1945-Screenshot_Noel_Thai_1242x2208-A5.jpg/392x696bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/76/0f/e2/760fe212-72a6-dca4-a22f-60f980d22426/322d539c-7e36-400c-ae45-c8675ffb378e_1945-Screenshot_Noel_Thai_1242x2208-A1.jpg/392x696bb.jpg
2. **Epic Plane Evolution**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/fd/0d/6d/fd0d6d6a-4251-bbb2-f3e9-a8a6f547151f/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/64/06/9c/64069c8a-4e80-978d-b2fb-a8cddbc747ac/six1242__U00d7_2688.png/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/36/ac/66/36ac66f1-4c67-388f-229b-396a8d5fbc5f/1241x2688.png/320x480bb.jpg
3. **Sling Plane 3D - Sky Crash Jet**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/f5/64/6a/f5646aa3-b9a2-d96c-b138-bd8a4d61c4bb/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/fd/72/74/fd727402-3c3d-0160-0931-3c86bd725a64/2496bde3-a254-4821-8cbb-d5129e3141a3_XX00_OPTX_SS01_1242x2208_copy_2.jpg/392x696bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/cd/4f/85/cd4f8562-1756-6c97-860a-4ccf60db6666/eb4c2c44-2a4a-41e4-9c7d-3c2bca73fdcf_XX00_OPTX_SS01_1242x2208_copy_4.jpg/392x696bb.jpg
4. **War Thunder Mobile**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ab/2e/37/ab2e37d0-fc02-a8d1-b5a3-93c1280a18b0/AppIcon-0-0-1x_U007emarketing-0-11-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/88/eb/97/88eb9782-dce2-a828-05ed-db4011ce7da7/bfbff648-5b54-456b-ac42-92e22af922b2_6_5_shot01.jpg/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/6b/f1/b6/6bf1b647-df21-0178-70ac-a291749d876b/air-pvp_2688x1242_00006.png/320x480bb.jpg
5. **Airline Commander: Flight Game**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/f3/3d/af/f33dafc3-3f47-fcd9-1039-e1aec8b61769/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3d/da/a9/3ddaa904-21b9-0231-f815-dda7f90bf495/mzl.mfdbqrza.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/f9/54/61/f9546106-6570-3f1f-57c2-5a0b6ce5b50f/mzl.odrpteve.png/406x228bb.png
6. **Go Plane**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/25/fe/e8/25fee8e4-4634-a182-0548-fc8580de424a/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/24/5a/a8/245aa8b9-847b-1e1e-c53d-6d1cb280b19e/mzl.bjcexyww.png/392x696bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/f4/65/1f/f4651f60-5b10-4331-523e-48fd310fb557/mzl.lvcpsmpk.png/392x696bb.png
7. **Wings of Heroes: Flying Games**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/a8/fa/52/a8fa52e2-c36c-4652-ce67-6f1a1a13767c/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/db/61/f0/db61f042-178f-34d1-b0b4-8338313b1659/WoH_screenshots_retargeting_1_2688x1242_en-US.jpg/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/65/6c/f8/656cf886-8b5b-3314-ba3b-3b209ab160ae/WoH_screenshots_retargeting_2_2688x1242_en-US.jpg/320x480bb.jpg
8. **Sky Warriors: Airplane Games**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/10/31/f5/1031f5f8-ae0c-8134-6084-9b1044856904/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource116/v4/61/bc/99/61bc991f-c001-3812-a3b9-40dcf9901fad/260594dc-e11d-4d16-ada2-b1b9eff8b79f_20230721__SW__en__SS__IPHONE__top_UA__I1__02__JM.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource126/v4/e1/59/ba/e159ba51-0de0-fc57-4d54-5bf28b69d3fc/1df221c7-ac5f-4b28-9842-5579cf0d01d9_IPHONE_01.jpg/406x228bb.jpg
9. **Metalstorm: Modern Air Combat**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/91/6c/60/916c605b-cb35-4bef-bf35-0f11abb348fa/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/7f/43/11/7f4311ca-9c01-8b8b-9ee4-35e660312e1b/Online_Multiplayer_-_2796x1290__U00282_U0029.png/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/35/0e/67/350e673d-a5cd-0262-8f6c-c3ec1db5f4ed/Play_with_Friends__-_2796x1290__U00281_U0029.png/320x480bb.jpg
10. **Armed Air Forces - Jet Fighter**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/c6/72/e5/c672e550-b08f-1e90-5e70-ca0275b52957/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/f2/54/b9/f254b9a2-c14d-33c6-19d8-52a382491593/10a318ba-b5e4-4281-97ad-1b41d05201d6_F22_2_2208.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/22/78/a2/2278a2ea-1570-16ca-6ea1-570452689a08/f6527d0a-5c65-49a8-87cf-ae43fba36a10_2.png/406x228bb.png
11. **Alliance: Air War**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/e1/97/85/e197852e-89ca-eb2c-cfb6-d20482dce8c7/AppIcon-0-0-1x_U007emarketing-0-10-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ba/2e/ca/ba2eca76-949f-7f0f-928d-f4dc00429c4b/mzl.nqcevtza.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/25/66/64/256664e6-b0f2-6a14-c859-b649e5c363ee/mzl.bacblxbl.png/406x228bb.png
12. **Bomber Ace: WW2 war plane game**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ab/a8/67/aba8674c-88e2-0347-073c-e473b1acb2b2/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/7e/1c/0a/7e1c0ae2-11c4-8522-77c2-d6535a4770f6/13f8cb24-a73f-4c9a-a5be-7e94ab1ccbb0_6s1.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/99/cf/98/99cf98fd-7599-eeb7-5ec5-b7764ceebe69/f9b42686-8d16-44fe-950e-c2d22b022e50_6s6.png/406x228bb.png
13. **AirFighters Combat Flight Sim**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/9f/73/da/9f73da07-87a3-0206-84ac-c10612575f72/AppIcon-1x_U007emarketing-0-7-0-85-220-0.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple123/v4/75/b8/9f/75b89f1c-6314-347e-0b3b-e8a4e313c11a/pr_source.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple113/v4/bc/30/ce/bc30ce35-5a57-a438-f570-60c82326a288/pr_source.png/406x228bb.png
14. **War Plane Strike: Sky Combat**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/5e/2a/51/5e2a512a-29de-b638-c2ef-6f20df0f5776/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/84/05/35/840535de-11a7-b2fd-275f-0ffd43af5c7c/97fd5cd8-3740-411f-bdfb-a9ef48399f4a_Aircraft_Master_1673025879_iPhone5.5.png/392x696bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/4e/ac/f3/4eacf3a8-6d1b-6054-b1f5-f84075a332c4/a2f6fb86-9b24-481c-bd6a-e08403734a70_Aircraft_Master_1673026156_iPhone5.5.png/392x696bb.png
15. **Air Battle - Sky Fighters 3D**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple113/v4/d1/5d/81/d15d8174-1c4c-34fa-3c18-d1dca16da915/AppIcon-0-1x_U007emarketing-0-85-220-9.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple123/v4/b8/48/42/b84842e7-3628-dfe6-5b78-6866eb23bd3b/pr_source.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple113/v4/c3/c1/c4/c3c1c409-6f4f-faac-11f5-9a55efa6c9ba/pr_source.jpg/406x228bb.jpg
16. **Air Wings®**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/56/79/b3/5679b3f7-aca9-aeac-cd8c-fa8645a9b885/AirWingsIcon-0-0-1x_U007epad-0-1-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/fa/05/bb/fa05bb2d-59be-b8e7-8a21-7a0e45cd355f/mzl.dwaplcmy.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/ab/2a/d7/ab2ad77b-2580-131f-9776-b2641c3fcf59/mzl.ekueolfx.jpg/406x228bb.jpg
17. **Air Combat Online**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/27/7e/5a/277e5af7-4301-98a0-df9c-3ee005b65bfa/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/26/b0/55/26b055d5-0d2e-8d9c-fe2a-94892d251c35/_U82f1_U6587.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/7d/c8/40/7dc84052-9326-c27d-2663-cbf45bd7c2f0/a5fc3795-1c21-44b1-b2b9-80ad2269a61e__U82f1_U6587__U526f_U672c.jpg/406x228bb.jpg
18. **Dogfight Elite Airplane Combat**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/84/0d/18/840d1878-a8a9-77a9-420e-cd454271082b/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource126/v4/c7/f6/16/c7f616ec-2765-4540-eb5b-bdcef7060931/b75795ff-ef30-447b-8763-53054f00ae20_1-1920x1080.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource126/v4/0b/fe/8d/0bfe8d72-cefb-167c-6ffc-e369850c7055/4682cb5b-9e75-4117-9a8e-f19a5a5e329c_2-1920x1080.jpg/406x228bb.jpg
19. **Sky Combat 2: Fighter planes**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/79/71/bc/7971bc7b-932f-a723-06d2-566ee17013e9/AppIcon-1x_U007emarketing-0-8-0-85-220-0.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/15/12/b3/1512b385-8165-0830-2cd6-c40a8f95e55e/2.png/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/be/c9/c8/bec9c814-b050-0cb1-bd32-72930758aeed/3.png/320x480bb.jpg
20. **Modern Jet Fighters Online**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ce/6b/32/ce6b3200-3d5a-59ab-6bb6-6b36b3bd8ab7/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/7f/4b/75/7f4b75cb-2332-f992-6226-7d7987eb9dd9/iPhone_6.9_2868x1320_20260517_192856_496.png/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/43/0b/d0/430bd0d5-b784-ef2c-4745-8612bd9f5697/iPhone_6.9_2868x1320_20260515_094626_878.png/320x480bb.jpg
21. **Warplanes: WW2 Dogfight**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/43/1b/97/431b97ce-133d-f854-37c8-a339cd0f28e3/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource114/v4/ae/00/49/ae004907-e0fa-3c96-6eeb-900965cae48c/c39441f0-ca5a-445c-a7ca-e22fef53d1f9_Screenshot_0005_iOS_5.5-Inch.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple124/v4/5a/3c/e4/5a3ce417-a0fd-5a7e-75c7-c18a0cca8ce4/mzl.wnxvdkxr.png/406x228bb.png
22. **WW2 Warplane Fighter Bomber**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/09/d8/d2/09d8d21f-aa38-97bb-055b-d679457684aa/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource126/v4/50/0b/6e/500b6ead-785d-3d45-0aaf-63d69e782795/b65128f4-76fa-4724-a575-3f7a1d104943_1.png/406x228bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource126/v4/ea/cd/4c/eacd4cde-2471-35b4-b4b8-a0ebd603bced/742b968a-304e-44d3-bc57-9183fa5e6021_2.png/406x228bb.png
23. **Jet Attack Move**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/26/b1/c6/26b1c623-6a67-6c7b-1a65-dcfd349c41c8/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/fc/59/52/fc595269-7cac-a236-d118-c5abff3cd3b1/image_095_0000.png/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/73/52/68/73526814-c783-3554-7a2b-cd78f98c0955/image_080_0000.png/320x480bb.jpg
24. **ACE Fighter: Modern Air Combat**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/6c/2c/d7/6c2cd707-058b-dde7-f58e-48156efc4501/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/22/2a/33/222a33c8-2f16-0379-4eb2-f75d72037a05/2cdab9bc-6f1c-4a62-af07-def605a3c58d_iphone-5.5-1.jpg/406x228bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/0c/47/c3/0c47c37c-7c43-a6e3-ed38-9e5ec34011f4/dd758631-ed1d-410a-983c-fad3cb1f96af_iphone-5.5-2.jpg/406x228bb.jpg
25. **Last Wing: Air Combat Shooter**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/6f/de/e9/6fdee93b-2625-b1a8-6866-1a4e322c4d38/AppIcon-0-0-1x_U007epad-0-11-0-85-220.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/a4/31/b8/a431b835-2e73-96fa-652f-ac9ddc0040b1/en-US_iPhone_6_9_portrait_01.jpg/320x480bb.jpg  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/b1/0d/aa/b10daac3-db9c-3ece-9fa9-339cc8029975/en-US_iPhone_6_9_portrait_02.jpg/320x480bb.jpg
26. **Sky Force Reloaded**  
   icon: https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/67/46/62/67466228-cb5f-4287-074c-1ed0370c72aa/AppIcon-1x_U007emarketing-0-7-0-85-220-0.png/512x512bb.jpg  
   shot 1: https://is1-ssl.mzstatic.com/image/thumb/Purple123/v4/8d/0a/5b/8d0a5b2f-a2b3-9d6e-3018-c0e4b730e0da/mzl.fijswvby.png/392x696bb.png  
   shot 2: https://is1-ssl.mzstatic.com/image/thumb/Purple113/v4/50/b5/7d/50b57dcb-7150-be38-a73f-c29bb0cfddec/mzl.slkkwddc.png/392x696bb.png

## Round 2 changes

Against the latest research critique (r3 in `data/critiques_round1.json`); line refs are to this file:
- r3 #4: "Decisions this supports" block at the top (category recommendation: Action primary, Simulation secondary, with the §2d numbers).
- r3 #5: §4 "India-specific reading" now compares only the 8 apps with a page-1 feed in both stores, with per-review rates (ads 9.0% IN vs 10.5% US), and drops the "42 vs 42 is equal" reading.
- r3 #6 and #7: the snapshot note under §2 explains the 15:16 vs 16:51 IST count drift and that `iap_unreliable_do_not_use` (renamed from `iap` in `data/competitors.json`) is not an IAP flag.
- r3 #9: G1 cites the shader path (`main.gd:3107-3110`, `toon.gdshader`) instead of the brief.
- Earlier items re-checked: "toy plane" reads "no combat game in the top 8" (r2 #1); the §2c table's date column now uses the same "releaseDate US / IN" label as §2 (r1 releaseDate caveat); G8 sentence and size-count method fixed (r2 #14).

