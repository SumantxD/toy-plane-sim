# Keyword research: Toy Plane Sim (iOS)

Fetched 2026-10-25 from Apple's public endpoints. Storefronts: India (IN, launch market) and United States (US).
- Autocomplete hints: the first 68 terms were fetched around 15:30 IST. The 13 round-2 terms (10 phrases found in hints plus 3 Devanagari queries) were fetched at 16:39 IST and merged into the same file.
- iTunes Search API: all 81 terms were re-fetched at 16:51 IST. This run also stores the top 25 results per query, each flagged as a game or not and as matching the term or not.
- **Fix round (~17:05–17:50 IST):** round 3 added the two IN-only hint phrases "indian plane game" and "real plane game" (hints and search, 83 terms now). Subtitles of every top-10 game the title/description rule missed were fetched from the public product pages (`data/subtitles.json`, `tools/fetch_subtitles.py`) and merged into the term-match rule. A hint tiebreak column and a raw top-5 median were added, and co-op was re-judged. Everything below is rebuilt from that.

Raw data: `aso/data/keywords.json` (merged), `aso/data/raw_hints.json`, `aso/data/raw_search.json`, `aso/data/subtitles.json`. Scripts to re-run: `aso/tools/fetch_hints.py` and `aso/tools/fetch_search.py` (pass terms to fetch only those), `aso/tools/fetch_subtitles.py` (resumable), `aso/tools/build_keywords.py`. Term list: `aso/tools/kw_terms.py`. Relevance notes: `aso/tools/kw_judgement.py`.

**Evidence labels**
- **VERIFIED:** read in this repo's code, or stated on an Apple documentation page (URL given).
- **MEASURED:** data I fetched from an Apple endpoint on 2026-10-25. The endpoint is named next to the claim.
- **ESTIMATE:** a derived number or a weight I chose.
- **HYPOTHESIS:** untested.

**No search volumes appear anywhere in this file.** Apple doesn't publish them, and I didn't buy or estimate any. Demand is shown only through autocomplete presence, which is a proxy.

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


## Summary

- **The IN and US listings need separate keyword fields (VERIFIED).** Apple's localization table lists India with default language **English (U.K.)**. Its additional languages are Bangla, Gujarati, Hindi, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu and Urdu. The US default is English (U.S.). Source: https://developer.apple.com/help/app-store-connect/reference/app-store-localizations, fetched 2026-10-25. So India's keyword field is the en-GB one. Build and validate it on its own (see "Keyword fields").
- **P1, 20 terms, each with a measured demand signal**, in table order (score, then hint tiebreak): fighter plane game, aeroplane game(s), plane game(s), airplane game(s), plane fighting game, plane fight, fighter plane games, aeroplane game 3d, war plane game, air plane game, plane game 3d, flying game, air war, dogfight, games with friends, flight game, dogfight games. (MEASURED hints + judged relevance)
- **co-op games dropped from P1 to P2 (fix round).** Its relevance rested on one mode of six (Co-op Escort), and its term-matching results include unrelated co-op games (IN top five: Unsolved Case, Pepelo, The Ghost - Multiplayer Horror, The Escape: Together, Fire and Water). Relevance is now 3, score 20.5. That generic co-op searchers would install a plane game is a HYPOTHESIS. It keeps a filler slot in the keyword fields because its hint is the strongest of any filler (`co-` #2 in both stores).
- **"dogfight" carries a solo caveat.** Conversion stays 5 because Team Dogfight is a named mode, but it is the one mode a solo player can't start: it needs a human on each team (`main.gd:909-911`). A solo searcher gets Team Battle vs AI. Listing copy must not promise a solo "Dogfight" mode.
- **Round 2 added four P1 terms.** "plane fighting game" hints at `plane f` in both stores (#3 IN, #4 US). "aeroplane game 3d" hints at `aeroplane` #3 in IN. "dogfight games" is #1 at `dogfight` in US. "fighter plane games" behaves like its singular. These match the game more closely than broad P1 terms such as "games with friends". (MEASURED, hints endpoint)
- **"aeroplane" is the India keyword.** In the IN storefront, typing `aer` puts "aeroplane games" at hint #1. The IN hints also include "aeroplane game 3d", "aeroplane games offline" and "aeroplane game free". (MEASURED, hints endpoint with the IN storefront header)
- **Competition now counts only games that match the term,** in title, subtitle or description. The old metric took the median ratings of the raw top 5, which included unrelated apps: Truck Simulator for "online plane game", Subway Surfers and Instagram for "plane wala game". The raw top-5 median is still shown next to it (`raw5`). On that basis, combat terms are thin in India: "dogfight" has a median of 34 IN ratings (raw5 also 34), "aeroplane game 3d" 38, "war plane game" 687. (MEASURED, iTunes Search API + product-page subtitles)
- **India-specific phrases "indian plane game" and "real plane game" are now scored** (round 3). Both are IN-only hints (`indian plane` #1, `real plane` #2). "indian plane game" is P3: the game has no Indian content, and its 9 IN results contain no Indian plane game. "real plane game" is Avoid: its results are flight sims and the game isn't realistic. The one India-made plane game found, Indian Air Force: A Cut Above, ranks on IAF searches instead (`competitor-research.md` §2c).
- **"capture the flag" is an intent mismatch, not P1.** Only 24 of 187 IN results are Games, and the top hits are CTF cybersecurity and Education apps such as Hacktivate. The term is capped at P3: mention the mode in the description and spend no keyword bytes on it. (MEASURED)
- **Terms with no autocomplete in either store are capped at P3 (description only).** This covers aerial combat, cartoon plane, toy planes, arcade flying, multiplayer plane game, online plane game and plane games with friends. They fit the game, but there's no measured sign that anyone types them. (MEASURED hints + rule below)
- **Hindi was tested, and none of the queries shows demand.** हवाई जहाज ("aeroplane") and हवाई जहाज गेम ("aeroplane game") return no hints in IN at any prefix. The endpoint does serve Devanagari: `गेम` returns "गाड़ी गेम" and "बस गेम". The romanized terms (jahaj game, hawai jahaj, plane wala game) also return no hints. (MEASURED, hints endpoint with the IN header, 16:39 IST)

## Locales: what the IN listing is (VERIFIED + HYPOTHESIS)

| Storefront | Default listing language | Additional languages | Source |
|---|---|---|---|
| India | English (U.K.) | Bangla, Gujarati, Hindi, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu, Urdu | VERIFIED, App Store localizations page (URL above), fetched 2026-10-25 |
| United States | English (U.S.) | Arabic, Chinese (Simplified), Chinese (Traditional), French, Korean, Portuguese (Brazil), Russian, Spanish (Mexico), Vietnamese | same |

- **What follows (VERIFIED by the table, plus a gap):** the IN listing is the en-GB localization, and its keyword field is the one India searchers match against. en-US doesn't appear in India's list. The same page says the language a customer sees "could be impacted by factors like the App Store language for their location, their device's language settings, languages you've added, and your primary language in App Store Connect". So **add an en-GB localization explicitly**. Without one, India falls back to the primary language. Exactly how that fallback works isn't documented (HYPOTHESIS).
- **HYPOTHESIS, Hindi keyword field:** a Hindi (hi) localization's name, subtitle and keyword field *might* be indexed in the IN storefront. The likeliest case is only for users whose device language is Hindi, but Apple doesn't document it. Whatever the answer, today there's nothing to gain: every Devanagari query tested returns no hints, and a Hindi keyword field holds only about 33 Devanagari letters (100 bytes at 3 bytes each; `apple-requirements.md` §1.1).
- **How to test it once the app is live:**
  1. Add a hi localization whose keyword field holds one distinctive Devanagari token that appears in no other field, for example `खिलौनाविमान`.
  2. After approval, search for that token on an IN Apple ID, once with the device language set to English (U.K.) and once with it set to Hindi.
  3. Run the same query through `https://itunes.apple.com/search?term=<token>&entity=software&country=in`.
  4. If the app appears only with the Hindi device language, the hi field is indexed only for Hindi-language users. If it appears in both, it's indexed for every IN user. If it never appears after 7 days, it isn't indexed.
  5. Record the result in `apple-requirements.md` §9.

## Method

1. **Universe:** 83 candidate terms in 8 groups: core, combat, multiplayer, casual/arcade, toy/stylized, India English/Hinglish, Hindi (Devanagari), and misfit terms included to document why they're excluded. Round 2 added the 10 phrases discovered in the round-1 hints and 3 Devanagari queries. Round 3 added "indian plane game" and "real plane game".
2. **Demand proxy, App Store search hints (MEASURED, a DEMAND PROXY and not volume).**
   - Endpoint: `https://search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints?clientApplication=Software&term=TERM`, with header `X-Apple-Store-Front: 143467-1,29` for IN and `143441-1,29` for US. The header changes the hints: for `plane g`, IN returns "indian plane game" and "real plane game", and US returns "plane games for kids" and "ww2 plane games". No request failed.
   - For each term I queried a few prefixes: the first 3 characters, the first word, then each later word's first letter and the full word, then the whole term. I recorded the shortest tested prefix where the term appeared (singular and plural count as the same term), its position in the list (1–10), and the full hint list.
   - Demand score per store:
     - **3:** appears by the first word plus 2 characters
     - **2:** appears before the full term is typed
     - **1:** appears only when the full term is typed, or only longer extensions of it appear
     - **0:** nothing
   - When the full-term hints are mostly app titles (for example "air battle: sea battle"), that usually means little generic query demand. The score doesn't capture this; read the raw hints for those terms.
3. **Competition, iTunes Search API (MEASURED).** Endpoint: `https://itunes.apple.com/search?term=TERM&entity=software&country=in|us&limit=200`, re-fetched 2026-10-25 16:51 IST. Each Competition cell shows four numbers:
   - **`g`:** Games among all results, out of `resultCount`. The API caps `resultCount` at 200, so treat it as a ceiling, not a count.
   - **`aw`:** titles that contain every word of the term.
   - **`rel`:** how many of the top 10 results are **Games and match the term**. "Match" means a content word of the term (anything other than game/games/3d/with/the/for) is in the title **or the subtitle**, or every content word is in the description.
     - **Why the subtitle was added:** the iTunes API returns no subtitle, so the first version of this rule only saw title and description. That dropped apps that rank on a term through their subtitle. Metalstorm, #1 for "dogfight" in both stores with the subtitle "5v5 Multiplayer Dogfight Wars", was missing from the dogfight `rel` set, and so was Jet Attack Move. Subtitles now come from `data/subtitles.json` (product pages of every top-10 game the title/description rule missed, fetched 2026-10-25) and `data/competitor_pages.json`. A subtitle that is just a genre name ("Action") is the page's fallback, not a real subtitle, and is ignored. The apps a subtitle added are listed per term under `relevant_games_subtitle_only` in `keywords.json`.
   - **The median `userRatingCount` of the first 5 `rel` apps,** bucketed as low (<1k), medium (1k–10k), high (10k–100k) or very high (>100k). With no `rel` apps, the median is 0.
   - **`raw5`:** the median `userRatingCount` of the raw top 5, with no filter. It is shown next to the `rel` median so a reader can see when the filter changes the picture (it doesn't feed the score).
   - The old metric used the raw top 5, so it counted unrelated apps. The per-term lists of `rel` apps are in `keywords.json` under `relevant_games_top5_names`. Rating counts are per storefront.
4. **Relevance (1–5):** judged against the code.
   - Modes: `main.gd:10`
   - Planes: `planes.gd:9-12` (Toy Cub, Speedster, Heavy Twin, Jet Fighter)
   - Offline solo vs AI and Free Flight: `main.gd:264-279`
   - Online room codes: `rooms.gd:45-49`
   - LAN: `main.gd:2465`
   - Cosmetic-only shop: `shop.gd`, `SUPPORT.md`
5. **Conversion fit (1–5):** HYPOTHESIS. How well the listing's promise matches what a searcher on that term expects. No conversion data exists yet.
6. **Priority (formula, applied to every term the same way):**
   `score = 3×relevance + conversion + 2×demand_IN + demand_US − comp_IN − 0.5×comp_US`, where comp is the bucket number 0–3. IN is weighted higher because it's the launch market.
   - **Avoid:** relevance ≤ 2, whatever the score.
   - **P1:** score ≥ 22
   - **P2:** 17–21.5
   - **P3:** < 17
   - **Cap ¹:** demand 0 on **both** storefronts caps a term at **P3 (description only)**. Relevance is weighted 3×, so without this cap, perfect-fit terms nobody types would reach P2 on relevance alone.
   - **Cap ²:** Games under 25% of results in a storefront with 20 or more results marks an **intent mismatch** and caps the term at P3. Only "capture the flag" (IN: 24 of 187) and "hawai jahaj" (US: 1 of 176) trigger it.
   - The weights and caps are my choice (ESTIMATE). Change them in `build_keywords.py` and re-run.
7. **Tiebreak (MEASURED hints, ESTIMATE rule):** the demand score saturates. Most P1 terms score 3 in both stores, so it can't rank within P1. The tiebreak is **characters typed at the shortest hinted prefix + position in that hint list**, per store; lower is stronger. Example: "aeroplane game" in IN is `aer` #1 → 3 + 1 = **4**; "fighter plane game" in IN is `fighter` #7 → 7 + 7 = **14**. "-" means no hint. Within a tier, rows with equal scores are sorted by the IN tiebreak, then the US one, and the keyword fields are ordered by it.

## Ranked table

Cell formats:
- **Hints:** demand score (0–3), then `shortest prefix` and #position in the hint list. "ext:" lists longer phrases that appeared when the term itself didn't.
- **Competition:** `g` Games/results, `aw` all-words titles, `rel` term-matching games in the top 10 (title, subtitle or description), then their median ratings (bucket), then `raw5`, the unfiltered top-5 median. See Method 3.
- **Tiebreak:** prefix characters + hint position, per store; lower is stronger; "-" = no hint. See Method 7.
- **Priority ¹/²:** capped at P3 by the no-demand or intent-mismatch rule. The score shown is from before the cap.

| # | Term | Group | Hints IN | Hints US | Competition IN | Competition US | Tiebreak IN / US | Rel | Conv | Score | Priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | fighter plane game | core | 3 (`fighter` #7) | 3 (`fighter` #9) | 173/177 g, 6 aw, 8 rel: 221 (low); raw5 1,940 | 174/175 g, 7 aw, 8 rel: 67,440 (high); raw5 67,440 | 14 / 16 | 5 | 4 | 27.0 | P1 |
| 2 | aeroplane game | india | 3 (`aer` #1) | 3 (`aeroplane` #1) | 192/194 g, 2 aw, 2 rel: 6,191 (medium); raw5 1,938 | 189/192 g, 2 aw, 2 rel: 24,746 (high); raw5 28,382 | 4 / 10 | 5 | 4 | 26.0 | P1 |
| 3 | aeroplane games | india | 3 (`aer` #1) | 3 (`aeroplane` #1) | 190/193 g, 1 aw, 2 rel: 6,191 (medium); raw5 1,938 | 188/191 g, 2 aw, 2 rel: 24,746 (high); raw5 45,115 | 4 / 10 | 5 | 4 | 26.0 | P1 |
| 4 | plane game | core | 3 (`plane` #4) | 3 (`plane` #5) | 192/198 g, 32 aw, 6 rel: 1,584 (medium); raw5 1,938 | 182/188 g, 44 aw, 8 rel: 67,440 (high); raw5 45,115 | 9 / 10 | 5 | 4 | 26.0 | P1 |
| 5 | plane games | core | 3 (`plane` #4) | 3 (`plane` #5) | 190/197 g, 23 aw, 6 rel: 1,584 (medium); raw5 4,929 | 179/187 g, 27 aw, 8 rel: 67,440 (high); raw5 45,115 | 9 / 10 | 5 | 4 | 26.0 | P1 |
| 6 | airplane game | core | 3 (`airplane` #2) | 3 (`airplane` #1) | 191/194 g, 40 aw, 5 rel: 4,929 (medium); raw5 1,938 | 190/192 g, 49 aw, 6 rel: 52,639 (high); raw5 45,115 | 10 / 9 | 5 | 4 | 26.0 | P1 |
| 7 | airplane games | core | 3 (`airplane` #2) | 3 (`airplane` #1) | 187/192 g, 20 aw, 7 rel: 4,929 (medium); raw5 4,929 | 187/190 g, 27 aw, 6 rel: 45,115 (high); raw5 45,115 | 10 / 9 | 5 | 4 | 26.0 | P1 |
| 8 | plane fighting game | core | 3 (`plane f` #3) | 3 (`plane f` #4) | 103/106 g, 1 aw, 5 rel: 1,584 (medium); raw5 4,930 | 145/145 g, 2 aw, 4 rel: 70,438 (high); raw5 67,449 | 10 / 11 | 5 | 4 | 26.0 | P1 |
| 9 | plane fight | combat | 3 (`plane f` #6) | 3 (`plane f` #10) | 109/118 g, 11 aw, 4 rel: 1,339 (medium); raw5 1,940 | 167/173 g, 16 aw, 5 rel: 68,037 (high); raw5 68,037 | 13 / 17 | 5 | 4 | 26.0 | P1 |
| 10 | fighter plane games | core | 3 (`fighter` #7) | 3 (`fighter` #9) | 166/169 g, 6 aw, 8 rel: 1,154 (medium); raw5 1,940 | 160/161 g, 6 aw, 8 rel: 67,449 (high); raw5 67,449 | 14 / 16 | 5 | 4 | 26.0 | P1 |
| 11 | aeroplane game 3d | core | 3 (`aeroplane` #3) | 0 | 186/194 g, 0 aw, 5 rel: 38 (low); raw5 0 | 173/175 g, 0 aw, 3 rel: 244 (low); raw5 244 | 12 / - | 5 | 4 | 25.0 | P1 |
| 12 | war plane game | core | 3 (`war p` #1) | 3 (`war p` #4) | 182/185 g, 13 aw, 8 rel: 687 (low); raw5 3,273 | 185/185 g, 9 aw, 9 rel: 22,854 (high); raw5 42,011 | 6 / 9 | 4 | 3 | 23.0 | P1 |
| 13 | air plane game | core | 3 (`air p` #4) | 0 | 196/198 g, 52 aw, 5 rel: 4,930 (medium); raw5 1,939 | 184/188 g, 44 aw, 7 rel: 67,449 (high); raw5 45,130 | 9 / - | 5 | 4 | 23.0 | P1 |
| 14 | plane game 3d | core | 3 (`plane g` #3) | 1 (ext: plane game 3d - space flight) | 182/188 g, 13 aw, 7 rel: 781 (low); raw5 952 | 167/169 g, 19 aw, 10 rel: 4,377 (medium); raw5 4,377 | 10 / - | 4 | 4 | 22.5 | P1 |
| 15 | flying game | core | 3 (`flying` #3) | 3 (`flying` #4) | 190/194 g, 33 aw, 4 rel: 1,465 (medium); raw5 4,929 | 174/178 g, 26 aw, 6 rel: 28,382 (high); raw5 36,984 | 9 / 10 | 4 | 3 | 22.0 | P1 |
| 16 | air war | combat | 3 (`air w` #5) | 3 (`air w` #3) | 183/187 g, 41 aw, 7 rel: 1,564 (medium); raw5 2,086 | 168/174 g, 30 aw, 9 rel: 42,011 (high); raw5 42,011 | 10 / 8 | 4 | 3 | 22.0 | P1 |
| 17 | dogfight | combat | 1 (`dogfight` #2) | 1 (`dogfight` #4) | 146/150 g, 19 aw, 8 rel: 34 (low); raw5 34 | 128/129 g, 19 aw, 8 rel: 22,854 (high); raw5 3,279 | 10 / 12 | 5 | 5 | 22.0 | P1 |
| 18 | games with friends | multiplayer | 3 (`games w` #4) | 3 (`games w` #3) | 167/186 g, 5 aw, 9 rel: 3,517 (medium); raw5 3,517 | 166/175 g, 8 aw, 10 rel: 25,111 (high); raw5 25,111 | 11 / 10 | 4 | 3 | 22.0 | P1 |
| 19 | flight game | core | 3 (`flight` #7) | 3 (`flight g` #1) | 184/189 g, 29 aw, 10 rel: 1,938 (medium); raw5 1,938 | 189/190 g, 23 aw, 10 rel: 45,115 (high); raw5 45,115 | 13 / 9 | 4 | 3 | 22.0 | P1 |
| 20 | dogfight games | combat | 0 | 3 (`dogfight` #1) | 189/193 g, 0 aw, 8 rel: 687 (low); raw5 687 | 150/150 g, 0 aw, 9 rel: 42,023 (high); raw5 42,023 | - / 9 | 5 | 5 | 22.0 | P1 |
| 21 | air battle | combat | 1 (`air battle` #1) | 1 (`air battle` #1) | 169/178 g, 19 aw, 8 rel: 687 (low); raw5 1,940 | 151/168 g, 16 aw, 9 rel: 42,011 (high); raw5 42,011 | 11 / 11 | 5 | 4 | 21.0 | P2 |
| 22 | sky war | combat | 3 (`sky w` #8) | 1 (ext: sky warriors, sky warriors: airplane games) | 158/167 g, 29 aw, 8 rel: 338 (low); raw5 1,940 | 150/154 g, 22 aw, 10 rel: 22,854 (high); raw5 22,854 | 13 / - | 4 | 3 | 21.0 | P2 |
| 23 | plane shooting game | core | 0 | 3 (`plane s` #5) | 153/156 g, 2 aw, 6 rel: 112 (low); raw5 4,929 | 168/169 g, 3 aw, 6 rel: 61,072 (high); raw5 66,313 | - / 12 | 5 | 4 | 21.0 | P2 |
| 24 | co-op games | multiplayer | 3 (`co-` #2) | 3 (`co-` #2) | 173/184 g, 0 aw, 6 rel: 267 (low); raw5 267 | 185/186 g, 0 aw, 3 rel: 3,686 (medium); raw5 10,968 | 5 / 5 | 3 | 3 | 20.5 | P2 |
| 25 | air attack | combat | 3 (`air a` #5) | 1 (`air attack` #2) | 142/146 g, 18 aw, 6 rel: 2,086 (medium); raw5 14,592 | 151/154 g, 17 aw, 9 rel: 6,771 (medium); raw5 3,361 | 10 / 12 | 4 | 3 | 20.5 | P2 |
| 26 | online games with friends | multiplayer | 3 (`onl` #8) | 3 (`onl` #10) | 179/191 g, 0 aw, 5 rel: 31,010 (high); raw5 39,001 | 174/192 g, 0 aw, 8 rel: 287,841 (very high); raw5 20,083 | 11 / 13 | 4 | 3 | 20.5 | P2 |
| 27 | toy plane | toy | 1 (ext: toy plane glider, toy planet track) | 1 (ext: toy plane glider, toy planet track) | 133/191 g, 1 aw, 8 rel: 3,160 (medium); raw5 4,847 | 140/174 g, 1 aw, 8 rel: 1,237 (medium); raw5 5,436 | - / - | 5 | 4 | 20.5 | P2 |
| 28 | fighter jet game | core | 3 (`fig` #3) | 3 (`fig` #6) | 175/177 g, 12 aw, 8 rel: 687 (low); raw5 687 | 160/160 g, 12 aw, 8 rel: 22,854 (high); raw5 26,058 | 6 / 9 | 3 | 3 | 20.0 | P2 |
| 29 | jet plane game | core | 3 (`jet p` #3) | 0 | 185/188 g, 4 aw, 4 rel: 380 (low); raw5 1,939 | 171/172 g, 4 aw, 8 rel: 26,061 (high); raw5 42,023 | 8 / - | 4 | 3 | 20.0 | P2 |
| 30 | plane battle | combat | 0 | 3 (`plane b` #4) | 156/183 g, 3 aw, 8 rel: 3,160 (medium); raw5 3,273 | 162/167 g, 3 aw, 7 rel: 68,037 (high); raw5 67,440 | - / 11 | 5 | 4 | 20.0 | P2 |
| 31 | bomber game | combat | 3 (`bomber` #8) | 3 (`bomber` #4) | 179/189 g, 6 aw, 8 rel: 133 (low); raw5 133 | 160/163 g, 5 aw, 7 rel: 3,638 (medium); raw5 3,638 | 14 / 10 | 3 | 2 | 19.5 | P2 |
| 32 | airplane shooter | core | 1 (ext: airplane shooter war strike) | 3 (`airplane s` #8) | 151/154 g, 5 aw, 9 rel: 112 (low); raw5 112 | 152/154 g, 4 aw, 8 rel: 3,361 (medium); raw5 3,361 | - / 18 | 4 | 3 | 19.5 | P2 |
| 33 | air combat | combat | 1 (`air combat` #1) | 1 (`air combat` #4) | 175/177 g, 50 aw, 8 rel: 1,940 (medium); raw5 1,940 | 164/165 g, 52 aw, 10 rel: 22,854 (high); raw5 22,854 | 11 / 14 | 5 | 3 | 19.0 | P2 |
| 34 | air combat games | combat | 0 | 2 (`air combat` #1) | 167/168 g, 5 aw, 10 rel: 288 (low); raw5 288 | 174/174 g, 2 aw, 10 rel: 22,856 (high); raw5 22,856 | - / 11 | 5 | 3 | 19.0 | P2 |
| 35 | air strike game | combat | 3 (`air s` #4) | 2 (`air strike` #1) | 146/147 g, 5 aw, 8 rel: 221 (low); raw5 478 | 160/161 g, 4 aw, 6 rel: 3,690 (medium); raw5 42,011 | 9 / 11 | 3 | 2 | 18.5 | P2 |
| 36 | low poly | casual | 1 (ext: low poly puzzle: art coloring, low poly - color by number) | 3 (`low p` #2) | 95/175 g, 13 aw, 6 rel: 15 (low); raw5 12 | 95/170 g, 13 aw, 5 rel: 1,950 (medium); raw5 1,950 | - / 7 | 4 | 2 | 18.5 | P2 |
| 37 | sky battle | combat | 1 (ext: sky battleships: pvp rts) | 1 (ext: sky battleships: pvp rts) | 136/151 g, 10 aw, 10 rel: 622 (low); raw5 622 | 131/131 g, 13 aw, 10 rel: 4,235 (medium); raw5 4,235 | - / - | 4 | 4 | 18.5 | P2 |
| 38 | pvp games | multiplayer | 3 (`pvp` #1) | 3 (`pvp` #1) | 194/195 g, 1 aw, 8 rel: 7,780 (medium); raw5 7,780 | 188/188 g, 4 aw, 7 rel: 40,253 (high); raw5 40,253 | 4 / 4 | 3 | 2 | 18.0 | P2 |
| 39 | jet game | core | 3 (`jet` #4) | 3 (`jet g` #1) | 186/196 g, 21 aw, 8 rel: 1,940 (medium); raw5 1,940 | 181/183 g, 23 aw, 7 rel: 26,058 (high); raw5 26,058 | 7 / 6 | 3 | 2 | 18.0 | P2 |
| 40 | pilot game | core | 3 (`pilot` #2) | 3 (`pilot g` #2) | 169/188 g, 36 aw, 9 rel: 1,938 (medium); raw5 1,938 | 173/174 g, 29 aw, 9 rel: 45,115 (high); raw5 36,984 | 7 / 9 | 3 | 2 | 18.0 | P2 |
| 41 | co op games | multiplayer | 3 (`co o` #2) | 0 | 157/181 g, 0 aw, 4 rel: 209 (low); raw5 107 | 185/188 g, 0 aw, 2 rel: 3,291 (medium); raw5 10,968 | 6 / - | 3 | 3 | 17.5 | P2 |
| 42 | multiplayer games | multiplayer | 3 (`mul` #1) | 3 (`mul` #1) | 186/191 g, 3 aw, 9 rel: 31,009 (high); raw5 31,009 | 190/191 g, 7 aw, 7 rel: 37,922 (high); raw5 425,131 | 4 / 4 | 3 | 2 | 17.0 | P2 |
| 43 | team battle | multiplayer | 1 (ext: team battle - 3d) | 1 (ext: team battle - 3d) | 190/193 g, 2 aw, 9 rel: 335 (low); raw5 4,466 | 169/176 g, 3 aw, 10 rel: 15,479 (high); raw5 15,479 | - / - | 4 | 3 | 17.0 | P2 |
| 44 | capture the flag | multiplayer | 2 (`capture the` #8) | 3 (`capture` #9) | 24/187 g, 4 aw, 5 rel: 0 (low); raw5 0 | 110/160 g, 4 aw, 7 rel: 0 (low); raw5 15 | 19 / 16 | 4 | 3 | 22.0 | P3 ² |
| 45 | plane games with friends | multiplayer | 0 | 0 | 22/28 g, 0 aw, 1 rel: 0 (low); raw5 16,483 | 157/162 g, 0 aw, 6 rel: 9,525 (medium); raw5 9,525 | - / - | 5 | 5 | 19.5 | P3 ¹ |
| 46 | dog fight game | combat | 0 | 0 | 103/103 g, 0 aw, 4 rel: 28 (low); raw5 60 | 172/175 g, 0 aw, 6 rel: 877 (low); raw5 1,555 | - / - | 5 | 4 | 19.0 | P3 ¹ |
| 47 | aerial combat | combat | 0 | 0 | 41/41 g, 1 aw, 9 rel: 0 (low); raw5 0 | 142/142 g, 1 aw, 8 rel: 3,279 (medium); raw5 9,786 | - / - | 5 | 4 | 18.5 | P3 ¹ |
| 48 | arcade flying | casual | 0 | 0 | 140/140 g, 3 aw, 10 rel: 10 (low); raw5 10 | 141/141 g, 4 aw, 9 rel: 3,875 (medium); raw5 10,773 | - / - | 5 | 4 | 18.5 | P3 ¹ |
| 49 | cartoon plane | casual | 0 | 0 | 14/18 g, 1 aw, 7 rel: 0 (low); raw5 0 | 99/147 g, 1 aw, 8 rel: 9,525 (medium); raw5 9,525 | - / - | 5 | 4 | 18.5 | P3 ¹ |
| 50 | toy planes | toy | 0 | 0 | 26/33 g, 0 aw, 3 rel: 1 (low); raw5 11 | 136/166 g, 0 aw, 8 rel: 1,126 (medium); raw5 5,436 | - / - | 5 | 4 | 18.5 | P3 ¹ |
| 51 | multiplayer plane game | multiplayer | 0 | 0 | 72/73 g, 0 aw, 4 rel: 1,538 (medium); raw5 14,853 | 153/153 g, 1 aw, 7 rel: 15,034 (high); raw5 42,011 | - / - | 5 | 5 | 18.0 | P3 ¹ |
| 52 | online plane game | multiplayer | 0 | 0 | 45/48 g, 0 aw, 4 rel: 1,199 (medium); raw5 99,850 | 159/159 g, 0 aw, 7 rel: 21,806 (high); raw5 67,440 | - / - | 5 | 5 | 18.0 | P3 ¹ |
| 53 | arcade plane game | casual | 0 | 0 | 141/142 g, 0 aw, 8 rel: 5,635 (medium); raw5 7,060 | 167/167 g, 1 aw, 9 rel: 72,797 (high); raw5 72,797 | - / - | 5 | 4 | 17.0 | P3 ¹ |
| 54 | toy airplane | toy | 0 | 0 | 190/196 g, 0 aw, 10 rel: 4,929 (medium); raw5 4,929 | 170/177 g, 0 aw, 9 rel: 13,690 (high); raw5 13,690 | - / - | 5 | 4 | 17.0 | P3 ¹ |
| 55 | offline plane game | casual | 0 | 2 (`offline plane` #1) | 180/187 g, 0 aw, 5 rel: 2,390 (medium); raw5 14,853 | 175/177 g, 1 aw, 6 rel: 98,606 (high); raw5 67,440 | - / 14 | 4 | 4 | 16.0 | P3 |
| 56 | jet fighter | core | 1 (ext: jet fighter air war simulator, jet fighter ocean at war) | 3 (`jet f` #10) | 181/184 g, 47 aw, 8 rel: 159 (low); raw5 1,940 | 147/151 g, 54 aw, 8 rel: 3,279 (medium); raw5 22,854 | - / 15 | 3 | 2 | 15.5 | P3 |
| 57 | jahaj game | india | 0 | 0 | 1/1 g, 0 aw, 0 rel: 0 (low); raw5 0 | 173/178 g, 0 aw, 0 rel: 0 (low); raw5 1,853 | - / - | 4 | 3 | 15.0 | P3 ¹ |
| 58 | hawai jahaj | india | 0 | 0 | 1/1 g, 0 aw, 0 rel: 0 (low); raw5 0 | 1/176 g, 0 aw, 0 rel: 0 (low); raw5 2,094 | - / - | 4 | 3 | 15.0 | P3 ¹ ² |
| 59 | cute plane game | casual | 0 | 0 | 27/31 g, 0 aw, 3 rel: 1 (low); raw5 1,801 | 154/157 g, 0 aw, 7 rel: 7,639 (medium); raw5 7,639 | - / - | 4 | 3 | 14.5 | P3 ¹ |
| 60 | plane wala game | india | 0 | 0 | 2/5 g, 0 aw, 0 rel: 0 (low); raw5 99,850 | 157/158 g, 0 aw, 7 rel: 9,525 (medium); raw5 11,351 | - / - | 4 | 3 | 14.5 | P3 ¹ |
| 61 | warplanes | core | 1 (`warplanes` #2) | 1 (`warplanes` #3) | 145/191 g, 10 aw, 6 rel: 7 (low); raw5 52 | 138/142 g, 9 aw, 7 rel: 376 (low); raw5 1,555 | 11 / 12 | 3 | 2 | 14.0 | P3 |
| 62 | indian plane game | india | 2 (`indian plane` #1) | 0 | 7/9 g, 0 aw, 0 rel: 0 (low); raw5 99,851 | 158/159 g, 0 aw, 5 rel: 21,806 (high); raw5 5,470 | 13 / - | 3 | 2 | 14.0 | P3 |
| 63 | online multiplayer | multiplayer | 1 (`online multiplayer` #3) | 3 (`online m` #5) | 188/189 g, 5 aw, 7 rel: 3,094 (medium); raw5 3,094 | 194/195 g, 13 aw, 9 rel: 28,619 (high); raw5 28,619 | 21 / 13 | 3 | 2 | 14.0 | P3 |
| 64 | casual plane game | casual | 0 | 0 | 176/176 g, 0 aw, 3 rel: 2,611 (medium); raw5 16,483 | 168/168 g, 0 aw, 7 rel: 15,034 (high); raw5 67,440 | - / - | 4 | 4 | 14.0 | P3 ¹ |
| 65 | हवाई जहाज | hindi | 0 | 0 | 13/16 g, 0 aw, 0 rel: 0 (low); raw5 307 | 0/0 g, 0 aw, 0 rel: 0 (low); raw5 0 | - / - | 4 | 2 | 14.0 | P3 ¹ |
| 66 | हवाई जहाज गेम | hindi | 0 | 0 | 0/0 g, 0 aw, 0 rel: 0 (low); raw5 0 | 0/0 g, 0 aw, 0 rel: 0 (low); raw5 0 | - / - | 4 | 2 | 14.0 | P3 ¹ |
| 67 | लड़ाकू विमान | hindi | 0 | 0 | 0/0 g, 0 aw, 0 rel: 0 (low); raw5 0 | 0/0 g, 0 aw, 0 rel: 0 (low); raw5 0 | - / - | 4 | 2 | 14.0 | P3 ¹ |
| 68 | warplane | core | 1 (`warplane` #2) | 1 (`warplane` #3) | 150/188 g, 14 aw, 5 rel: 34 (low); raw5 1,154 | 148/155 g, 18 aw, 6 rel: 7,293 (medium); raw5 7,293 | 10 / 11 | 3 | 2 | 13.5 | P3 |
| 69 | plane game offline | casual | 0 | 0 | 178/186 g, 0 aw, 5 rel: 15,280 (high); raw5 14,853 | 171/174 g, 1 aw, 7 rel: 190,455 (very high); raw5 98,606 | - / - | 4 | 4 | 12.5 | P3 ¹ |
| 70 | 2 player games | multiplayer | 3 (`2` #1) | 3 (`2` #1) | 176/185 g, 43 aw, 7 rel: 1,063 (medium); raw5 15,280 | 181/188 g, 56 aw, 7 rel: 25,111 (high); raw5 209,659 | 2 / 2 | 2 | 1 | - | Avoid |
| 71 | rc plane | toy | 3 (`rc p` #2) | 3 (`rc p` #3) | 154/162 g, 13 aw, 9 rel: 20 (low); raw5 20 | 129/153 g, 11 aw, 9 rel: 564 (low); raw5 564 | 6 / 7 | 2 | 1 | - | Avoid |
| 72 | helicopter game | misfit | 3 (`hel` #3) | 3 (`helicopter` #1) | 187/190 g, 17 aw, 8 rel: 638 (low); raw5 638 | 151/153 g, 13 aw, 9 rel: 3,722 (medium); raw5 6,121 | 6 / 11 | 1 | 1 | - | Avoid |
| 73 | air force game | misfit | 3 (`air f` #2) | 3 (`air f` #10) | 148/155 g, 4 aw, 8 rel: 687 (low); raw5 1,940 | 155/157 g, 4 aw, 7 rel: 22,854 (high); raw5 26,058 | 7 / 15 | 2 | 2 | - | Avoid |
| 74 | paper plane | toy | 3 (`paper p` #1) | 3 (`paper p` #1) | 87/132 g, 40 aw, 5 rel: 2 (low); raw5 30 | 90/137 g, 39 aw, 6 rel: 1,237 (medium); raw5 1,237 | 8 / 8 | 1 | 1 | - | Avoid |
| 75 | plane simulator | misfit | 3 (`plane` #3) | 3 (`plane` #4) | 188/192 g, 38 aw, 10 rel: 1,938 (medium); raw5 1,938 | 187/189 g, 32 aw, 9 rel: 28,382 (high); raw5 28,382 | 8 / 9 | 2 | 1 | - | Avoid |
| 76 | airplane simulator | misfit | 3 (`airplane` #1) | 3 (`airplane` #4) | 188/190 g, 26 aw, 9 rel: 1,938 (medium); raw5 1,938 | 194/198 g, 24 aw, 9 rel: 28,382 (high); raw5 28,382 | 9 / 12 | 2 | 1 | - | Avoid |
| 77 | flight simulator | misfit | 3 (`fli` #7) | 3 (`flight` #5) | 180/193 g, 87 aw, 10 rel: 1,938 (medium); raw5 1,938 | 174/181 g, 85 aw, 10 rel: 28,382 (high); raw5 28,382 | 10 / 11 | 1 | 1 | - | Avoid |
| 78 | indian air force game | india | 3 (`indian a` #2) | 0 | 7/10 g, 0 aw, 2 rel: 1,022 (medium); raw5 14,305 | 151/151 g, 0 aw, 9 rel: 925 (low); raw5 1,133 | 10 / - | 1 | 1 | - | Avoid |
| 79 | real plane game | india | 2 (`real plane` #2) | 0 | 114/118 g, 2 aw, 6 rel: 2,435 (medium); raw5 1,584 | 165/165 g, 1 aw, 7 rel: 24,654 (high); raw5 24,654 | 12 / - | 2 | 1 | - | Avoid |
| 80 | local multiplayer | multiplayer | 1 (`local multiplayer` #2) | 3 (`local m` #7) | 188/189 g, 0 aw, 8 rel: 20,911 (high); raw5 22,066 | 155/162 g, 2 aw, 8 rel: 6,110 (medium); raw5 11,690 | 19 / 14 | 2 | 1 | - | Avoid |
| 81 | ww2 plane game | misfit | 0 | 3 (`ww2` #2) | 82/86 g, 1 aw, 8 rel: 104 (low); raw5 104 | 170/170 g, 1 aw, 7 rel: 14,485 (high); raw5 7,293 | - / 5 | 1 | 1 | - | Avoid |
| 82 | plane games for kids | toy | 0 | 3 (`plane g` #2) | 185/195 g, 7 aw, 6 rel: 447 (low); raw5 737 | 174/183 g, 9 aw, 6 rel: 10,126 (high); raw5 10,126 | - / 9 | 2 | 1 | - | Avoid |
| 83 | anti aircraft game | combat | 0 | 0 | 22/23 g, 0 aw, 8 rel: 0 (low); raw5 0 | 146/146 g, 0 aw, 4 rel: 3,759 (medium); raw5 67,440 | - / - | 2 | 1 | - | Avoid |

Relevance reasons, conversion notes, flags and the term-matching game names for every row are in `keywords.json`.

**What the subtitle merge changed (MEASURED):** Metalstorm now counts for "dogfight", "dogfight games", "war plane game" and "sky war" in both stores; War Thunder Mobile for "fighter plane game(s)"; Wings of Heroes for "plane fighting game" and "plane battle". The full per-term list is `relevant_games_subtitle_only` in `keywords.json`.
- **"dogfight" IN** keeps a `rel` median of 34 (Metalstorm's 1,940 joins, but the median of the first five is still a 34-rating app). **"dogfight" US** moves from 1,555 (medium) to 22,854 (high), and its score from 22.5 to 22.0. It stays P1.
- **Jet Attack Move is still outside the dogfight `rel` set**, though it is #3–#4 for "dogfight". "dogfight" isn't in its title, its subtitle ("Arcade Air Combat") or its description, so it probably ranks through its hidden keyword field (HYPOTHESIS). That is why `raw5` sits next to the `rel` median: for "dogfight" it is 34 in IN and 3,279 in US.
- No term changed tier because of the merge. The tier changes in this round come from the co-op re-judgement and the two new terms.

## What each tier means for name, subtitle and keyword field

Indexed fields combine, so a phrase is covered when its words are spread across name + subtitle + keywords. Apple doesn't document that rule (HYPOTHESIS, `apple-requirements.md` §1.2). "game"/"games" counts as covered by the Games category (HYPOTHESIS). The current draft name and subtitle already index *toy, plane, sim, dogfight, friends*.

- **P1 (20 terms): every P1 term must be covered in both storefronts' indexed fields, and the strongest storefront-specific word goes in the name or subtitle.**
  - **en-GB (IN), strongest by tiebreak:** aeroplane game(s) (`aer` #1, tiebreak 4), war plane game (`war p` #1, 6), plane game(s) and air plane game (9), flying game (9), airplane game(s) and plane fighting game (10). Fighter plane game(s) tops the score but has a weaker hint (`fighter` #7, 14).
    - Put **"aeroplane"** in the IN subtitle or name.
    - "3d" can only be indexed through the name or subtitle, because keyword terms must be longer than 2 characters (VERIFIED, ASC help).
  - **en-US (US), strongest by tiebreak:** air war (`air w` #3, 8), airplane game(s) (`airplane` #1, 9), war plane game, flight game and dogfight games (9; US-only hint `dogfight` #1), plane game(s) (10).
    - Put **"airplane"** in the US subtitle or name. "dogfight" is already in the subtitle.
  - **Words needed in either keyword field:** aeroplane/airplane (whichever isn't in the subtitle), fighter, fighting, fight, war, air, flying, flight.
- **P2 (23 terms): the keyword field's filler words, chosen per storefront from that storefront's hints and ordered by tiebreak.**
  - **IN:** co-op (`co-` #2, 5), jet ("jet game" `jet` #4, 7; "jet plane game" `jet p` #3, IN only), battle and combat (11), sky ("sky war", `sky w` #8, 13), bomber ("bomber game", `bomber` #8, 14).
  - **US:** co-op (5), jet (`jet g` #1, 6), battle ("plane battle" `plane b` #4, US only, 11), combat ("air combat games" `air combat` #1, 11), shooting ("plane shooting game" `plane s` #5, US only, 12).
  - **Leave out:** broad terms such as "multiplayer games", "pvp games" and "online games with friends". Their competition is medium to very high, their relevance is 3–4 at best, and "online" now warns in the validator because there are no public lobbies (`data/banned_terms.txt`). The earlier drafts broke this rule by ending both fields with `pvp`; it is now dropped (see "Keyword fields"). `pvp` has a strong hint (`pvp` #1, tiebreak 4), but its results are general PvP shooters (IN `rel` median 7,780, US 40,253) and relevance is only 3.
- **P3 (26 terms): description only.**
  - The ¹ terms (multiplayer/online/with-friends plane phrases, toy, cartoon, arcade, Hindi) fit the game. Use them as natural description copy, because nobody types them into autocomplete.
  - **Capture the Flag ²:** name the mode in the description, and spend no keyword bytes on it.
- **Avoid (14 terms): never in any metadata field.** See "Terms to avoid".

## Top-5 apps that show up most often (MEASURED, iTunes Search API top 5, 162 term × store queries from the 81 round-1/2 terms, 2026-10-25 16:51 IST)

| App (seller) | Times in a top 5 | Max ratings seen |
|---|---|---|
| Sky Warriors: Airplane Games (Wildlife Studios) | 70 | 67,449 (US) |
| Metalstorm: Modern Air Combat (Starform) | 43 | 42,023 (US) |
| Airline Commander: Flight Game (RORTOS) | 37 | 82,512 (US) |
| Infinite Flight Simulator (Infinite Flight LLC) | 27 | 28,385 (US) |
| Airplane Pro: Flight Simulator (GameShark) | 27 | 45,130 (US) |
| Flight Simulator Advanced (Panagiotis Drakopoulos) | 23 | 9,062 (US) |
| Alliance: Air War (Art of the State) | 21 | 22,856 (US) |
| Warplanes: WW2 Dogfight (Teresa Dymek) | 14 | 1,555 (US) |
| 1945 Arcade Airplane Shooter / 1945 Air Force (Falcon Games) | 14 / 12 | 65,598 (IN) / 433,238 (US) |
| Go Plane, Epic Plane Evolution (Voodoo) | 14 / 12 | 72,797 / 190,455 (US) |

- **Closest rivals (MEASURED, API names, genres and descriptions):** the closest direct rivals for arcade multiplayer plane combat are Sky Warriors and Metalstorm. On the combat-specific terms, Warplanes: WW2 Dogfight is #2 for "dogfight" in both stores.
- **Cartoon-style games (MEASURED):** Go Plane and Epic Plane Evolution are the cartoon-style plane games that show up, and both are single-player hypercasual.
- **Reading (HYPOTHESIS):** nobody holds the "cartoon multiplayer" position. The full competitor set, with subtitles and IAP prices, is in `competitor-research.md`.

**Snapshot note.** These counts come from the 16:51 IST Search API run; `competitor-research.md` uses Lookup API counts from about 15:16 IST, so the same app can differ by a few ratings (Metalstorm US 42,023 here vs 42,011 there). Different snapshots, not errors.

## How hard the top of each list is (MEASURED, `data/keywords.json`, added 2026-10-25 ~18:25 IST)

The competition column above is the median of the first 5 matching games, which hides a big #1: IN "dogfight" has a median of 34, but #1 is Metalstorm with 1,940 IN ratings. Two more numbers per store, now stored in `keywords.json` by `tools/build_keywords.py`:
- **top-3 max:** the most ratings among the first 3 matching games in the top 10.
- **first <1k slot:** the rank (in the API's top 10) of the first matching game with under 1,000 ratings: a slot a new app could plausibly take. "none in top 10" means every matching game in the top 10 has 1,000+ ratings.

The priority formula still uses the median; read this table next to it.

| Term | Pri | IN median | IN top-3 max | IN first <1k slot | US median | US top-3 max | US first <1k slot |
|---|---|---|---|---|---|---|---|
| fighter plane game | P1 | 221 | 65,598 | 3 | 67,440 | 433,210 | 5 |
| aeroplane game | P1 | 6,191 | 11,601 | 5 | 24,746 | 45,115 | none in top 10 |
| aeroplane games | P1 | 6,191 | 11,601 | 5 | 24,746 | 45,115 | none in top 10 |
| plane game | P1 | 1,584 | 11,601 | 4 | 67,440 | 190,455 | none in top 10 |
| plane games | P1 | 1,584 | 11,601 | 6 | 67,440 | 190,455 | none in top 10 |
| airplane game | P1 | 4,929 | 14,853 | 7 | 52,639 | 82,508 | none in top 10 |
| airplane games | P1 | 4,929 | 14,853 | 7 | 45,115 | 82,508 | none in top 10 |
| plane fighting game | P1 | 1,584 | 5,635 | 6 | 70,438 | 72,798 | none in top 10 |
| plane fight | P1 | 1,339 | 5,635 | 8 | 68,037 | 433,210 | none in top 10 |
| fighter plane games | P1 | 1,154 | 65,598 | 3 | 67,449 | 433,238 | 5 |
| aeroplane game 3d | P1 | 38 | 781 | 2 | 244 | 4,378 | 2 |
| war plane game | P1 | 687 | 3,273 | 5 | 22,854 | 42,011 | none in top 10 |
| air plane game | P1 | 4,930 | 65,598 | 9 | 67,449 | 82,512 | none in top 10 |
| plane game 3d | P1 | 781 | 1,398 | 2 | 4,377 | 28,566 | 2 |
| flying game | P1 | 1,465 | 11,601 | 4 | 28,382 | 45,115 | none in top 10 |
| air war | P1 | 1,564 | 2,086 | 3 | 42,011 | 61,072 | none in top 10 |
| dogfight | P1 | 34 | 1,940 | 2 | 22,854 | 42,011 | 7 |
| games with friends | P1 | 3,517 | 22,066 | 2 | 25,111 | 63,875 | none in top 10 |
| flight game | P1 | 1,938 | 14,853 | 3 | 45,115 | 82,508 | none in top 10 |
| dogfight games | P1 | 687 | 1,940 | 1 | 42,023 | 68,079 | 8 |
| air battle | P2 | 687 | 65,598 | 2 | 42,011 | 68,037 | none in top 10 |
| sky war | P2 | 338 | 4,929 | 2 | 22,854 | 67,440 | 2 |
| plane shooting game | P2 | 112 | 458,619 | 4 | 61,072 | 433,210 | 10 |
| co-op games | P2 | 267 | 3,844 | 1 | 3,686 | 4,463 | none in top 10 |
| air attack | P2 | 2,086 | 65,598 | 6 | 6,771 | 66,313 | none in top 10 |
| online games with friends | P2 | 31,010 | 161,764 | 2 | 287,841 | 287,841 | none in top 10 |
| toy plane | P2 | 3,160 | 4,847 | 3 | 1,237 | 190,455 | 1 |
| fighter jet game | P2 | 687 | 4,929 | 3 | 22,854 | 67,440 | 6 |
| jet plane game | P2 | 380 | 4,930 | 3 | 26,061 | 67,449 | 3 |
| aeroplane games offline | P2 | 8,838 | 15,286 | 1 | 11,363 | 11,363 | 7 |
| aeroplane game free | P2 | 621 | 11,604 | 4 | 11,363 | 45,130 | none in top 10 |
| plane battle | P2 | 3,160 | 5,635 | 6 | 68,037 | 72,797 | none in top 10 |
| bomber game | P2 | 133 | 1,154 | 1 | 3,638 | 18,125 | 9 |
| airplane shooter | P2 | 112 | 65,598 | 2 | 3,361 | 433,210 | 3 |
| air combat | P2 | 1,940 | 2,056 | 2 | 22,854 | 42,011 | 3 |
| air combat games | P2 | 288 | 4,930 | 3 | 22,856 | 67,449 | 5 |
| air strike game | P2 | 221 | 1,940 | 3 | 3,690 | 69,159 | 8 |
| low poly | P2 | 15 | 15 | 2 | 1,950 | 24,116 | 6 |
| sky battle | P2 | 622 | 4,929 | 2 | 4,235 | 67,440 | 3 |
| pvp games | P2 | 7,780 | 661,039 | none in top 10 | 40,253 | 104,085 | 8 |
| jet game | P2 | 1,940 | 4,929 | 4 | 26,058 | 67,440 | 8 |
| pilot game | P2 | 1,938 | 14,853 | 3 | 45,115 | 82,508 | none in top 10 |
| co op games | P2 | 209 | 267 | 2 | 3,291 | 4,462 | none in top 10 |
| multiplayer games | P2 | 31,009 | 38,046 | 3 | 37,922 | 518,449 | none in top 10 |
| airplane games no wifi | P2 | 2,391 | 15,286 | 2 | 67,449 | 378,091 | none in top 10 |
| team battle | P2 | 335 | 22,133 | 1 | 15,479 | 104,210 | none in top 10 |

**Reading (HYPOTHESIS: API rank order is not the App Store's).** In India, every P1 term has a matching sub-1,000 game somewhere in the top 9, and 9 P1 terms have one in the top 3. In the US, 14 of 20 P1 terms have none in the top 10. The India-first plan is where a 0-rating app has room.

## Round-2 phrases (MEASURED hints, now scored above)

| Phrase | IN hint | US hint | Priority | Note |
|---|---|---|---|---|
| plane fighting game | `plane f` #3 | `plane f` #4 | P1 | Needs "fighting" in the keyword field. Apple's stemming of fight/fighting is unknown. |
| fighter plane games | `fighter` #7 | `fighter` #9 | P1 | Same hint as the singular. |
| aeroplane game 3d | `aeroplane` #3 | none | P1 | "3d" fits only in the name or subtitle. |
| air plane game | `air p` #4 | none | P1 | Split spelling. Covered by "air" + "plane". |
| co-op games | `co-` #2 | `co-` #2 | P2 (was P1) | Low game competition (IN median 267), but relevance cut to 3 in the fix round: one co-op mode of six, and the results are unrelated co-op games. Whether Apple matches "co-op" and "coop" as the same term is unknown (HYPOTHESIS). Use the hinted spelling, "co-op". |
| dogfight games | none | `dogfight` #1 | P1 | Already covered by the subtitle. Solo caveat: Team Dogfight needs a human on each team (`main.gd:909-911`). |
| jet plane game | `jet p` #3 | none | P2 | IN only. |
| online games with friends | `onl` #8 | `onl` #10 | P2 | Very high US competition (median 287,841). |
| air combat games | none (only app titles) | `air combat` #1 | P2 | |
| warplane | `warplane` #2 | `warplane` #3 | P3 | Hints are mostly competitor titles (Warplanes: WW2 Dogfight, Warplane Inc). |
| हवाई जहाज ("aeroplane") | none | none | P3 ¹ | IN: 16 results, 13 of them games, none term-matching. |
| हवाई जहाज गेम ("aeroplane game") | none | none | P3 ¹ | IN: 0 results. |
| लड़ाकू विमान ("fighter aircraft") | none | none | P3 ¹ | IN: 0 results. |

### Round 3 (MEASURED, fetched 2026-10-25 ~17:10 IST, scored above)

| Phrase | IN hint | US hint | Priority | Note |
|---|---|---|---|---|
| indian plane game | `indian plane` #1 | none | P3 | Relevance 3: no Indian setting, aircraft or theme. Only 9 IN results, none an Indian plane game (Infinite Flight, Truck Simulator, Sniper 3D, Subway Surfers, Instagram, YouTube…). A hint with no matching apps: an opening only if the game ever adds Indian content (HYPOTHESIS). |
| real plane game | `real plane` #2 | none | Avoid | Relevance 2: "real" asks for realism. IN results are flight sims (Airline Commander, X-Plane, RFS, Infinite Flight). |

### Round 4 (MEASURED, hints + Search API fetched 2026-10-25 ~18:20 IST, scored with the same formula; `data/keywords.json` now has 88 terms: 20 P1, 26 P2)

| Phrase | IN hint | US hint | IN / US matching median (top-3 max) | Priority | Note |
|---|---|---|---|---|---|
| aeroplane games offline | `aeroplane g` #5 | none | 8,838 (15,286) / 11,363 (11,363) | P2 (20.0) | Covered by `offline` in both C and A fields. Solo play really runs offline (VERIFIED, `main.gd:264-279`); a Sky Warriors IN reviewer asked for exactly this (competitor-research.md §4). |
| aeroplane game free | `aeroplane g` #9 | none | 621 (11,604) / 11,363 (45,130) | P2 (20.0) | Needs the word `free` (not in any field). Needs `free` in the keyword field, which the validator FAILs as a pricing term (Guideline 2.3.7, `validate_metadata.py:24`), and the price tier is unknown (game-audit.md §3). Leave it out. |
| airplane games no wifi | none | `airplane` #10 | 2,391 / 67,449 (378,091) | P2 (17.0) | Needs `wifi`; 4 bytes would fit only by dropping a word. US-only and high competition; not worth a swap. |
| offline plane games | none | `offline plane` #1 | 8,838 / 98,620 | P3 (16.0) | Covered anyway by `offline` + `plane`. |
| free plane games | none | `free plane` #2 | 1,154 / 36,987 | P3 (15.0) | Same caveat as "aeroplane game free". |

The subtitles of new top-10 apps for these 5 terms were not fetched (`tools/fetch_subtitles.py` not re-run), so their matching counts use title and description only.

**Result for the fields:** the existing `offline` keyword in C and A covers the two offline phrases with real hints. No field change.

## Keyword fields

### Final fields (these assume the launch name `Toy Plane Arcade`, Strategy C)

`positioning.md` leads with C, so the deliverable is C's fields. The "current name" draft below is kept for reference only.

| Locale | Name / subtitle | Keyword field | Bytes |
|---|---|---|---|
| en-GB (India + 100 other storefronts) | Toy Plane Arcade / Aeroplane battles with no ads | `airplane,fighter,war,air,dogfight,fight,flying,flight,offline,shooter,bomber,sky,jet,combat,fighting` | 100 |
| en-US | Toy Plane Arcade / Airplane battles with no ads | `aeroplane,fighter,war,air,dogfight,fight,flying,flight,offline,shooter,bomber,jet,combat,fighting` | 97 |

Drop-in fields if the name becomes `Toy Plane Dogfight` (Strategy A):

| Locale | Name / subtitle | Keyword field | Bytes |
|---|---|---|---|
| en-GB | Toy Plane Dogfight / Aeroplane fights with friends | `airplane,war,fighter,air,combat,co-op,fighting,sky,flying,battle,jet,flight,offline,bomber,shooter` | 98 |
| en-US | Toy Plane Dogfight / Airplane fights with friends | `aeroplane,war,fighter,air,combat,multiplayer,co-op,fighting,flying,battle,shooting,flight,offline` | 97 |

All four are written into `data/listing_C*.json` and `data/listing_A*.json` and pass the validator with 0 FAIL (MEASURED, 18:30 IST). Each shows 1 WARN, the new device-name check, until the game itself is renamed (`project.godot:13`).

### Draft for the current name and subtitle

Name: "Toy Plane Sim". Subtitle: "Dogfight friends in toy planes" (`data/listing_current.json`). The fields below are built per storefront from the tier takeaways.

The previous single draft, `aeroplane,airplane,fighter,war,air,battle,fight,combat,shooting,arcade,multiplayer,online,3d,game`, **fails** the validator or the research, for four reasons:
- **"3d":** each keyword must be longer than 2 characters (VERIFIED, ASC help).
- **"game":** Apple says to skip it (VERIFIED, `apple-requirements.md` §1.1).
- **"air,battle" (HYPOTHESIS):** the two words sit next to each other and spell the competitor title "Air Battle". Apple doesn't document whether neighbouring keywords are read as one phrase, or whether that would count as using a competitor's name. The validator warns on it as a precaution, because the downside (a Guideline 2.3.7 rejection) costs a review cycle while the fix costs nothing: put another word between them.
- **"online":** now flagged as risky in `banned_terms.txt`.

| Locale (storefront) | Keyword field (ordered by tier, then hint tiebreak) | Bytes |
|---|---|---|
| **en-GB (IN)** | `aeroplane,war,air,flying,airplane,fighting,fight,flight,fighter,co-op,jet,battle,combat,sky,bomber` | 98/100 |
| **en-US (US)** | `air,airplane,war,flight,aeroplane,flying,fighting,fighter,fight,co-op,jet,battle,combat,shooting` | 96/100 |

- **Order:** P1 words first, each ranked by the best tiebreak of the P1 terms it unlocks in that storefront (en-GB uses IN tiebreaks, en-US uses US ones), then the P2 fillers by their tiebreak. Apple doesn't document that word order inside the field affects ranking (HYPOTHESIS that it doesn't), so the order is the **cut order**: if bytes are needed later, cut from the end.
- **Shared P1 words (both fields):** aeroplane, airplane, fighter, fighting, fight, war, air, flying, flight. Together with the name and subtitle they cover every P1 term except the "3d" ones.
- **fight / fighting / fighter is a hedge, and it costs 16 bytes.** Apple documents only that "climb" and "climbs" are duplicates (`apple-requirements.md` §1.1). Whether it also matches "fight" to "fighting" or "fighter" is unknown. Keeping all three covers "plane fight", "plane fighting game" and "fighter plane game" whatever the stemming. If Apple does stem them together, `fighting,fight` (14 bytes plus 2 commas) is wasted. HYPOTHESIS, untestable until the app is live.
- **`pvp` dropped from both fields** (it broke this file's own "Leave out" rule; see the P2 tier).
  - **en-GB:** its 4 bytes plus 3 spare go to `bomber` ("bomber game" P2, hinted in both stores: IN `bomber` #8, US `bomber` #4).
  - **en-US:** `bomber` (7 bytes with its comma) doesn't fit without cutting a word. The closest call is `combat`: "air combat (games)" scores 19.0 against "bomber game" at 19.5, and its US tiebreak is 11 against 10. I keep `combat` because its terms have relevance 5 and bomber's has 3 (you drop bombs, but you don't fly a bomber as the main loop, `kw_judgement.py`). Swap them if you weigh the score over relevance. The 4 bytes stay unused. A 3-letter option is `dog`, which would complete "dog fight game", but that term has no hint in either store (P3 ¹), so it isn't worth recommending.
- **co-op stays,** as the first P2 filler: P2 since the fix round, but with the strongest filler hint (`co-` #2, tiebreak 5 in both stores).
- **IN-only fillers:** sky, bomber. **US-only filler:** shooting.
- **Dropped:** "arcade", "multiplayer", "online", "capture/flag" and "pvp". They're P3 ¹/², flagged by the validator, or broad.
- **Adjacency check:** no two neighbouring words in either field form a competitor name (validator, 50 competitor names after the India pass added Indian Air Force: A Cut Above and its seller).
- **Validated** with `python3 aso/tools/validate_metadata.py aso/data/listing_kwdraft_<locale>.json` at about 17:55 IST. The description is copied from `listing_A*.json` only so the required field isn't empty.

```
== listing_kwdraft_en-GB.json
PASS  name              13/30 chars, 13 bytes
PASS  subtitle          30/30 chars, 30 bytes
SKIP  promotional_text  empty (optional)
PASS  description       2468/4000 chars, 2468 bytes
SKIP  whats_new         empty (optional)
WARN  name+subtitle     repeated words waste indexed space: plane, toy
PASS  keywords          98/100 chars, 98/100 UTF-8 bytes

PASS: 0 fail, 1 warn, 50 competitor names, 27 banned terms checked
== listing_kwdraft_en-US.json
PASS  name              13/30 chars, 13 bytes
PASS  subtitle          30/30 chars, 30 bytes
SKIP  promotional_text  empty (optional)
PASS  description       2469/4000 chars, 2469 bytes
SKIP  whats_new         empty (optional)
WARN  name+subtitle     repeated words waste indexed space: plane, toy
PASS  keywords          96/100 chars, 96/100 UTF-8 bytes

PASS: 0 fail, 1 warn, 50 competitor names, 27 banned terms checked
```

The one warning is about name and subtitle ("toy" and "plane" appear in both), not about keywords. It goes away with any of the `listing_*.json` names.

### Reconciliation with the strategy listings (snapshot 16:54 IST, re-checked unchanged at 17:55 IST)

`positioning.md` owns the listings, and they changed while this pass ran (A is now "Toy Plane Dogfight"). I didn't edit them. Every one of them passes the validator. Against this research, they differ as follows:

| File (locale) | Name / subtitle | Keyword field | Validator | Research notes |
|---|---|---|---|---|
| `listing_A.json` (en-GB) | Toy Plane Dogfight / Aeroplane fights with friends | `airplane,war,fighter,air,combat,multiplayer,coop,capture,flag,flying,battle,jet,flight,offline,pvp` | PASS, 98 bytes | Swap `capture,flag` (P3 ², 12 bytes) for `fighting,sky` to cover the P1 "plane fighting game" and the IN P2 "sky war". `pvp` and `multiplayer` break the "Leave out" rule; `bomber` fits in their place. `coop` becomes `co-op`, the hinted spelling. The swapped field passes the validator at 99 bytes. "aeroplane" in the subtitle is the right IN P1 placement. |
| `listing_A_en-US.json` (en-US) | Toy Plane Dogfight / Airplane fights with friends | `aeroplane,war,fighter,air,combat,multiplayer,coop,capture,flag,flying,battle,shooting,flight,offline` | PASS, 100 bytes | Swap `capture,flag` for `fighting`, and `coop` for `co-op`. The swapped field passes the validator at 97 bytes. |
| `listing_B.json` (en-GB) | Toy Plane: Fighter Battles / Arcade jet dogfights in 3D | `aeroplane,airplane,air,war,shooting,rocket,bomber,fight,combat,flying,flight,sky,pvp,shooter` | PASS, 92 bytes | The only listing that indexes "3d" (P1 "plane game 3d" and "aeroplane game 3d" in IN), through the subtitle. Missing `fighting` (swap in for `pvp`). `rocket` has no measured signal. |
| `listing_C.json` / `listing_C_en-US.json` | Toy Plane Arcade / Aeroplane (Airplane) battles with no ads | `...offline,shooter,bomber,sky,capture,flag,jet` | PASS, 97 / 98 bytes | Same `capture,flag` swap. Missing `fighting`. |

## Terms to avoid

| Term | Why |
|---|---|
| flight simulator, plane simulator, airplane simulator, real plane game | The game is arcade combat, with no realistic flight model, airports or landing career. These searches have strong demand (hints from `fli` and `plane`), but the top results are Infinite Flight, X-Plane and Airplane Pro. Mismatched searchers would bounce or leave bad reviews. (MEASURED results + HYPOTHESIS on behaviour) |
| plane games for kids, "for kids" anywhere | "for kids" is reserved for the Kids category (VERIFIED, App Review Guideline 2.3.8; see `aso/data/banned_terms.txt`). The game also has guns, rockets and online play. |
| ww2 plane game, helicopter game, paper plane, rc plane | No WW2 setting, no helicopters, no paper planes, no RC simulation. These would be misleading metadata (Guideline 2.3.7). |
| indian air force game | Implies official or realistic IAF content. The IN #1 result is the official IAF game, Indian Air Force: A Cut Above (`competitor-research.md` §2c). Not about the game. |
| local multiplayer, 2 player games | Searchers expect same-device play. The game uses online room codes or LAN, with no split screen. |
| anti aircraft game | You buy AA guns with supplies, but you never operate them. |
| Competitor names and trademarks | Sky Warriors, Metalstorm, Alliance: Air War, Wings of Heroes, Airline Commander, Infinite Flight, X-Plane, War Thunder, Ace Combat, Microsoft Flight Simulator, Dogfight Elite, AirAttack, 1945 Air Force, Go Plane, Epic Plane Evolution, Top Gun, Warplanes, Sky Force, ACE Fighter, Last Wing, Jet Attack Move. Guideline 2.3.7 bans other apps' names in metadata, and some are registered trademarks. "air attack", "sky war" and "air battle" are generic words, but they sit next to existing titles. Use them only as separate words, never as the exact title. |
| Platform/store names | Android, Google Play, Steam (Guideline 2.3.10), per `banned_terms.txt`. |

## Data limitations

- **No volumes.** Autocomplete presence and position are a proxy only. A term can be hinted with tiny volume, and long phrases can have real volume without a hint.
- **Free next step for real demand data (user action).** Create an Apple Search Ads Advanced account (Apple has been renaming the product "Apple Ads"; not re-checked here). Creating the account costs nothing; Apple's keyword tool shows a popularity score per keyword and storefront when you add keywords to an ad group. Whether this works before the app is live is **unknown**: campaigns are tied to an app, so it may have to wait until launch week. Record the scores below without launching any paid campaign, then compare them with the hint proxy.

| Term or word | Hint proxy IN / US | ASA popularity IN | ASA popularity US |
|---|---|---|---|
| fighter plane game | 3 / 3 | | |
| aeroplane game(s) | 3 / 3 | | |
| plane game(s) | 3 / 3 | | |
| airplane game(s) | 3 / 3 | | |
| plane fighting game | 3 / 3 | | |
| plane fight | 3 / 3 | | |
| fighter plane games | 3 / 3 | | |
| aeroplane game 3d | 3 / 0 | | |
| war plane game | 3 / 3 | | |
| air plane game | 3 / 0 | | |
| plane game 3d | 3 / 1 | | |
| flying game | 3 / 3 | | |
| air war | 3 / 3 | | |
| dogfight | 1 / 1 | | |
| games with friends | 3 / 3 | | |
| flight game | 3 / 3 | | |
| dogfight games | 0 / 3 | | |
| filler: co-op, sky, bomber, shooter, shooting, jet, combat, offline, fighting, battle | per word | | |
- **Hints are a snapshot** from a single day, storefront header and unauthenticated client. They change over time and may be personalised on devices. The round-1 and round-2 terms were fetched about an hour apart.
- **The iTunes Search API ranking is not the App Store app's search ranking,** and `resultCount` caps at 200. "Top 10" here means the API's order.
- **The term-match rule is mechanical.** It checks title, subtitle and description words (subtitles from product pages, since the API has none), and it can miss a relevant game or include a loosely related one. Read `relevant_games_top5_names` before trusting a single cell.
- **`userRatingCount` counts ratings, not downloads,** and it's per storefront. India users rate less often, so IN counts run lower for the same app. Compare stores only in relative terms.
- **Relevance and conversion fit are my judgement.** Relevance is checked against the code. Conversion fit has no data behind it until the app has App Store Connect analytics, so treat it as HYPOTHESIS.
- **Hindi:** Devanagari queries were tested and showed no hints. Whether a hi localization's keyword field is indexed for IN users is a HYPOTHESIS, with a test plan above.

## Round 2 changes

Against the latest research critique (r3 in `data/critiques_round1.json`):
- r3 #2: "How hard the top of each list is" adds top-3 max and first-under-1k slot per store for every P1/P2 term (`tools/build_keywords.py` stores both in `data/keywords.json`).
- r3 #3: the offline, free and no-wifi phrases are scored in "Round 4" (two P2 offline phrases covered by `offline`; `free` stays out because the validator fails it as a pricing term).
- r3 #4: "Decisions this supports" block at the top with the final en-GB/en-US fields, subtitle word, category, name, ₹79 item and top 3 screenshot claims.
- r3 #7: snapshot note under the top-5 table (16:51 IST Search API vs 15:16 IST Lookup API).
- r3 #8: "Data limitations" names the free Apple Search Ads popularity check, with an empty column per P1 term and filler word.
- r3 #11: "Final fields" states they assume `Toy Plane Arcade` (C, the lead listing in positioning.md) and gives drop-in fields for `Toy Plane Dogfight` (A). The "current name" draft is kept for reference only.
- Earlier items still holding: `pvp` dropped (r2 #3), adjacency claim labelled HYPOTHESIS and the 16-byte stemming hedge stated (r2 #5), co-op at P2 (r2 #6), subtitle-aware term matching (r2 #2).

