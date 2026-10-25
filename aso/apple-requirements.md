# Apple App Store requirements for Toy Plane Sim (checked 2026-10-25)

All limits below were read from Apple's pages on 2026-10-25 by fetching them with curl. Apple edits these pages without notice, so re-check before submitting. The App Review Guidelines page showed "Last Updated: October 16, 2026".

Labels used:
- **VERIFIED**: stated on an Apple page (URL given) or read from this repo or file.
- **MEASURED**: data fetched and computed during this session.
- **ESTIMATE**: a reasoned call with no Apple statement behind it.
- **HYPOTHESIS**: untested belief. Check it before relying on it.

Sources (short names used below):

| Short name | URL |
|---|---|
| ASC-AppInfo | https://developer.apple.com/help/app-store-connect/reference/app-information/app-information |
| ASC-Version | https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information |
| ASC-Shots | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications |
| ASC-Preview | https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications |
| ASC-Icon | https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon |
| HIG-Icons | https://developer.apple.com/design/human-interface-guidelines/app-icons |
| Xcode-Icon | https://developer.apple.com/documentation/xcode/configuring-your-app-icon |
| ProductPage | https://developer.apple.com/app-store/product-page/ |
| Search | https://developer.apple.com/app-store/search/ |
| PPO-Help | https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization (also `/create-a-test` and `/configure-test-treatments`) |
| PPO-Mkt | https://developer.apple.com/app-store/product-page-optimization/ |
| CPP-Help | https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions |
| CPP-Mkt | https://developer.apple.com/app-store/custom-product-pages/ |
| ARG | https://developer.apple.com/app-store/review/guidelines/ |
| Marketing | https://developer.apple.com/app-store/marketing/guidelines/ |
| Apple-TM | https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html |
| ASC-Loc | https://developer.apple.com/help/app-store-connect/reference/app-store-localizations |
| ASC-AgeDefs | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions |
| ASC-AgeSet | https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating |
| ASC-Export | https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance (and `/determine-and-upload-app-encryption-documentation`) |
| Dev-Encrypt | https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations (read through its JSON at `developer.apple.com/tutorials/data/documentation/...`) |
| Privacy | https://developer.apple.com/app-store/app-privacy-details/ |
| ASC-DSA | https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements |
| ASC-IAP | https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information |
| ASC-Price | https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price |

Apple's help pages moved under `/help/app-store-connect/reference/app-information/...`. The older `/reference/app-information` path redirects there.

---

## 1. Text fields

| Field | Limit | Unit | When you can change it | Indexed for App Store search? | Source |
|---|---|---|---|---|---|
| App name | min 2, max 30 | characters | Until first submission. After that, only with a new version. | Yes | ASC-AppInfo, ARG 2.3.7, Search: VERIFIED |
| Subtitle | max 30 | characters | With a new version | Yes | ASC-AppInfo, ProductPage, Search: VERIFIED |
| Promotional text | max 170 | characters | Any time, no review of a new version | **No.** "promotional text doesn't affect your app's search ranking" | ASC-Version, ProductPage, Search: VERIFIED |
| Description | max 4000, required, plain text (no HTML) | characters | With a new version | Apple does not list it as an App Store search factor. ASC says it "will be used for web engine search results". | ASC-Version, Search: VERIFIED |
| Keywords | **100 bytes** (ASC help) / "100 characters" (marketing pages) | see 1.1 | With a new version | Yes | ASC-Version, ProductPage, Search: VERIFIED |
| What's New | max 4000, required for every update after v1.0 | characters | With each version | Not listed as a search factor | ASC-Version: VERIFIED |
| App Review notes | max 4000 | bytes | Any time | Not public | ASC-Version: VERIFIED |
| In-app purchase display name | **2–30** per ASC-IAP; ProductPage says 35 | characters | Changes need review | IAPs can appear in search results | ASC-IAP, ProductPage: VERIFIED. The pages disagree; use the stricter ASC limit. |
| In-app purchase description | **max 45** per ASC-IAP; ProductPage says 55 | characters | Changes need review | | ASC-IAP, ProductPage: VERIFIED. Use 45. |
| Promoted IAPs | up to 20 items across IAP and subscription sections | | | | ProductPage: VERIFIED |
| PPO test reference name | max 64 | characters | | Not public | PPO-Mkt: VERIFIED |
| Support URL | required, must lead to real contact info | | Any time | | ASC-Version: VERIFIED |
| Privacy Policy URL | required for iOS | | | | ASC-AppInfo: VERIFIED |
| Copyright | required, e.g. "2026 Your Name" (Apple adds the © symbol itself) | | | | ASC-Version: VERIFIED |

**Unit for "characters": unknown.** Apple does not say whether it counts Unicode code points, UTF-16 units or grapheme clusters. For plain English and Hindi text the counts match closely. Emoji and some Indic clusters may count differently. The validator counts code points (Python `len`), so treat a field within 1 to 2 characters of its limit as a risk (ESTIMATE).

### 1.1 Keywords: exact rules

- **ASC-Version (VERIFIED):** "One or more keywords (each greater than two characters) describing your app. You can provide up to 100 bytes of content. Your app is searchable by app name and company name, so you shouldn't duplicate these values in the keyword list. Names of other apps or companies aren't allowed."
- **ProductPage and Search (VERIFIED):** "Keywords are limited to 100 characters total, with terms separated by commas and no spaces. You can use spaces to separate words within keyword phrases. For example: Property,House,Real Estate."
- **Bytes and characters:** the two Apple pages disagree. The byte limit is the stricter one for any non-ASCII text. Each Devanagari letter is 3 bytes in UTF-8, so a Hindi keyword field fits only about 33 Devanagari code points (MEASURED by arithmetic: 100 / 3). English ASCII is 1 byte per character, so the two limits are the same. The validator enforces both.
- **Separator:** comma, with no space after it. A space after a comma costs a byte and adds nothing (ProductPage).
- **Do not repeat (Search, VERIFIED):** "Don't repeat any words included in your app name, subtitle, or category." Also skip:
  - plurals of words you already have ("climbs" and "climb" are "considered duplicates")
  - "app" and "game"
  - filler words such as "the" and "to"
  - `#` and `@`
- **Banned in keywords (ProductPage and Search, VERIFIED):**
  - unauthorized trademarked terms, celebrity names and other protected words or phrases
  - terms not relevant to the app
  - competing app names
  - inappropriate, offensive or objectionable terms

  ASC-Version adds "names of other ... companies".
- **Custom product page keywords:** a CPP can be assigned keywords taken from the latest approved version's keyword list. Each keyword combination should belong to only one page (CPP-Help, Search: VERIFIED).

### 1.2 What App Store search indexes

From Search (VERIFIED): "Search results are based on a number of factors, including text relevance (matches for your app's title, subtitle, keywords, and primary category), as well as user behavior (downloads, ratings and reviews, and more)." The same page says the "primary category and optional secondary category are indexed". ASC-Version says the app is "searchable by app name and company name".

| Indexed (VERIFIED) | Not a ranking input (VERIFIED) | Unknown |
|---|---|---|
| Name, subtitle, keywords, primary and secondary category, developer (company) name, ratings and reviews, downloads, CPP keywords | Promotional text | Description (Apple says only "don't add unnecessary keywords to your description"), IAP names (they do appear in search results) |

Search also says app tags in search results "are generated using large language models (LLMs) based on the metadata you've provided". So the description can affect tags even if it does not affect ranking (HYPOTHESIS about the effect on ranking).

**What this means for the current draft:**
- Name: "Toy Plane Sim".
- Subtitle: "Dogfight friends in toy planes".
- MEASURED by the validator: the name is 13 of 30 characters and the subtitle is 30 of 30. The words "toy" and "plane(s)" appear in both.
- Apple prohibits repeats only between keywords and name or subtitle, not between name and subtitle. Repeating them still uses about 10 of the subtitle's 30 characters on words that are already indexed (ESTIMATE).

## 2. Screenshots (iPhone, landscape)

Repo facts (VERIFIED):
- `export_presets.cfg` has `application/targeted_device_family=0`, which means iPhone only in Godot's iOS exporter. So no iPad screenshots are required.
- `project.godot` has `window/handheld/orientation=4`, which is sensor landscape. Screenshots are landscape.

Rules from ASC-Shots (VERIFIED):
- **Count:** at least 1 and at most **10** per device size per localization.
- **Format:** .jpeg, .jpg or .png. **No alpha channel or transparency.**
- **Required device size:** "iPhone: At least one screenshot for iPhone with Dynamic Island (medium display)."
- **Scaling:** if the UI is the same across sizes, you can provide only the highest required resolution and App Store Connect scales it down.

Accepted sizes for this game (landscape):

| Display class | Devices (from Apple's list) | Landscape sizes accepted | Status for this game |
|---|---|---|---|
| iPhone with Dynamic Island (large) | iPhone Air, 18 Pro Max, 17 Pro Max, 16 Pro Max, 16 Plus, 15 Pro Max, 15 Plus, 14 Pro Max | **2868 x 1320**, 2796 x 1290, 2736 x 1260 | Existing shots fit (see below) |
| iPhone with Dynamic Island (medium), **required** | iPhone 18 Pro, 17 Pro, 17, 16 Pro, 16, 15 Pro, 15, 14 Pro | **2622 x 1206**, 2556 x 1179 | No files at this size yet |
| iPhone with Face ID (large) | 14 Plus, 13 Pro Max, 11 Pro Max, XR... | 2778 x 1284, 2688 x 1242 | Falls back to the large Dynamic Island shots when absent |
| iPhone Duo (new device class) | iPhone Duo outer and inner displays | 2034 x 1398 (outer), 2853 x 2007 (inner) | "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." Not needed for the v0.9 build. |

Existing files, MEASURED with `sips` on 2026-10-25:
- `builds/appstore/1-battle.png`, `2-taunt.png`, `3-sky-kingdom.png`, `4-mission-setup.png`, `5-shop.png`.
- All five are 2868 x 1320 with `hasAlpha: no`. They are valid for the large Dynamic Island class.

**Open question: does 2868 x 1320 alone satisfy the "medium display required" rule?** The page conflicts with itself:
- The "Required device sizes" line names the medium display.
- The fallback notes chain medium → Face ID large → Dynamic Island large, and the general scaling text says to provide only the highest resolution.

HYPOTHESIS: uploading only 2868 x 1320 is accepted. To remove the risk, also upload a 2622 x 1206 set.

Resizing the existing shots takes two `sips` steps:
1. Scale to 2622 x 1207. The aspect ratios differ by about 0.06% (MEASURED: 2868/1320 = 2.1727 and 2622/1206 = 2.1741).
2. Crop to 2622 x 1206. For example: `sips -z 1207 2622 in.png --out tmp.png && sips -c 1206 2622 tmp.png --out out.png`.

Write the output under `aso/`, not `builds/`.

Search results show "the first one to three" screenshots, depending on orientation, when no preview exists (ProductPage, VERIFIED). HYPOTHESIS, not stated by Apple: a landscape screenshot shows one image per result row, so screenshot 1 does most of the work.

## 3. App previews (video)

From ASC-Preview and ProductPage (VERIFIED):

| Spec | Value |
|---|---|
| Count | Optional. Up to **3** per device size per language. |
| Length | **15 to 30 seconds** |
| File size | max **500 MB** |
| Formats | .mov, .m4v, .mp4 (H.264), or .mov (ProRes 422 HQ only) |
| H.264 | Progressive, up to High Profile Level 4.0. Target 10 to 12 Mbps. |
| Frame rate | max **30 fps** |
| Audio | Stereo, 256 kbps AAC, 44.1 or 48 kHz, all tracks enabled |
| iPhone resolution (all 19.5:9 classes: Dynamic Island large and medium, Face ID large and medium, Duo) | **1920 x 886 landscape** (886 x 1920 portrait) |
| Orientation | iOS: landscape or portrait |
| Poster frame | Default is at 5 s. You can choose another frame. |
| Processing time | Up to 24 hours |
| Display order | Previews always appear **before** screenshots. A preview with a different aspect ratio than the screenshots goes to "A Closer Look". |
| Autoplay | Muted, so the first seconds must work without sound (ProductPage) |
| Content rule | ARG 2.3.4: "previews may only use video screen captures of the app itself". Narration and text overlays are allowed. |

## 4. App icon

From HIG-Icons, Xcode-Icon and ASC-Icon (VERIFIED unless labeled):
- **Size:** iOS layout is **1024 x 1024 px**, square.
- **No rounded corners:** "the system applies masking to produce rounded corners". Provide square, unmasked art: "Providing layers with pre-defined masking negatively impacts specular highlight effects and makes edges look jagged."
- **Opaque background:** an imported background layer must be "full-bleed and opaque".
- **No alpha channel:** ASC-Shots says "Images can't include alpha channels or transparencies" for screenshots. For the icon itself, the no-alpha rule is enforced by App Store Connect build validation, which rejects a transparent marketing icon (error ITMS-90717). That error code is from prior knowledge and was not re-fetched today (HYPOTHESIS for the exact error text). Either way, ship it opaque.
- **Color spaces:** sRGB, Gray Gamma 2.2, Display P3.
- **Appearances (iOS 18+ and Liquid Glass):** default, dark, clear light, clear dark, tinted light, tinted dark. "The system automatically generates variants you don't provide."
  - Xcode guidance: "Provide your tinted app icon as a grayscale image. Provide your dark app icon with a transparent background so the system-provided background can show through." The dark variant is the one place a transparent background is expected.
  - Keep the core shapes the same across every appearance.
- **Avoid:** text unless it is essential, photos, replicas of UI, and baked-in gloss or shadows (the system adds these).
- **Changing the icon:** needs a new binary and review (ASC-Icon). Icons used in a PPO test must already be in the live binary (PPO-Help).
- **Current icon, MEASURED with `sips`:** `assets/ui/icon_ios.png` is 1024 x 1024, RGB, `hasAlpha: no`. It passes the size and alpha checks.
- **Dark and tinted variants, VERIFIED:** `export_presets.cfg` sets only `icons/icon_1024x1024`. Godot's iOS exporter also has `icons/icon_1024x1024_dark` and `icons/icon_1024x1024_tinted`, per https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html. Without them, iOS auto-generates the dark and tinted variants.
- **ARG 2.3.8:** the icon, the IAP icons and any alternate icons should look similar to avoid confusion, and must be 4+ appropriate.

## 5. Accuracy rules (App Review Guidelines 2.3)

These are quoted or closely paraphrased from ARG (VERIFIED). The note after each rule applies it to this game.

| Rule | What it says | Application to Toy Plane Sim |
|---|---|---|
| 2.3 | Metadata, including description, screenshots and previews, must "accurately reflect the app's core experience", kept current with each version. | Only show modes, worlds and features that ship in the build being submitted. |
| 2.3.1(a) | Marketing content or services the app does not offer, or a false price, is grounds for removal and account termination. | Do not state player counts, modes or worlds beyond what the submitted build does. Leave out any feature still marked "coming soon". |
| 2.3.2 | If the app has IAPs, the description, screenshots and previews must make clear which featured items cost extra. | The Hangar Shop paint jobs, trails and kill effects are paid. `5-shop.png` shows the shop, so say in the description (and ideally the caption) that cosmetics are optional purchases. |
| 2.3.3 | Screenshots must show the app in use, not just title art, login or splash. Text and image overlays are allowed. | `4-mission-setup.png` is a menu. It is acceptable, but gameplay shots are safer as screenshot 1 (ESTIMATE). |
| 2.3.4 | Previews must be screen captures of the app. | No cinematic renders that the game cannot produce. |
| 2.3.5 | Pick the right category. Apple may change it. | Games, with subcategories Action and/or Simulation. Choosing Simulation together with "Sim" in the name is a judgment call (see below). The top-chart benchmark in `competitor-research.md` §2d puts numbers on it: IN Simulation's #50–#100 median is 3,780 ratings against 7,046 for IN Action, and IN Simulation already holds 5 plane games (all sims or hypercasual) against 1 in IN Action (MEASURED). |
| 2.3.6 | Answer the age rating questions honestly. | The game has guns, rockets and bombs against toy planes, plus taunts. Answer the cartoon violence questions accordingly. Expected result: §11.1. |
| 2.3.7 | Unique name. No trademarks, popular app names, pricing or irrelevant phrases. Name max 30 characters. Name, subtitle, screenshots and previews may not include prices. Subtitles may not reference other apps or make unverifiable claims. Apple may change bad keywords. | No "free", "₹", "#1" or "best" in the name or subtitle. No competitor names anywhere. |
| 2.3.8 | Icons, screenshots and previews must suit **4+** even if the app is rated higher. "For Kids" and "For Children" are reserved for the Kids category. | Avoid shots of a gun aimed at a specific character, and keep the taunts in screenshots mild. Never write "for kids". |
| 2.3.9 | You must own the rights to everything in your icons, screenshots and previews. Use fictional account data. | The music is original (VERIFIED, `tools/make_music.py:1`: "World music (ours, CC0)"). Use made-up player names and room codes in shots. AI callsigns are original toy names since commit `ed9bebf` (`main.gd:16`); `builds/appstore/1-battle.png` and `2-taunt.png` still show the old film callsigns (Maverick, Merlin, Viper, Jester), so do not upload them (game-audit.md §4 blocker). |
| 2.3.10 | No names, icons or imagery of other mobile platforms or alternative app marketplaces. Stay focused on the app. | No "also on Steam/Android", no controller or PC imagery from other stores, no Android UI. |
| 2.3.12 | What's New must list significant changes specifically. | |
| 2.3.14 | Creative assets: no misleading references to other apps, unverifiable claims, or specific or discounted pricing. | |
| Notes for Review (2.3.1a) | New features must be described specifically in Review Notes. | Add a test room code and LAN or online instructions to the notes. |

ProductPage also says to avoid specific prices in the description, because "references within the description may not be accurate in all regions". This matters for India-first INR pricing: keep "₹" amounts out of the description and use the IAP price display instead.

**"Sim" in the name:** the game is an arcade dogfighter, not a flight simulator. No guideline bans the word. Some reviewers or users might read "Sim" as overpromising realism under 2.3.1 or 2.3.7. Low risk (HYPOTHESIS). Worth a PPO or CPP test of copy that makes clear it is arcade.

## 6. Trademarks

| Rule | Source |
|---|---|
| Don't use third-party trademarks, copyrighted works or patented ideas without permission. No "copycat representations, names, or metadata". | ARG 5.2.1, VERIFIED |
| Don't suggest that Apple endorses or supplies the app. The "Editor's Choice" badge is applied by Apple only. | ARG 5.2.4, VERIFIED |
| No Apple trademark "as or as part of a ... product name". An Apple word mark may appear only in a referential phrase ("for", "runs on", "compatible with"), and less prominently than your product name. Never the Apple logo. | Apple-TM, VERIFIED |
| Write "Toy Plane Sim for iPhone", never "iPhone Toy Plane Sim". Use correct casing (iPhone, iPad). Say "on the App Store", never "Apple App Store" or "iPhone App Store". | Marketing, VERIFIED |
| Generic device illustrations must not show details unique to Apple hardware. | Marketing, VERIFIED |
| No trademarked terms, celebrity names, or competing app or company names in keywords. | ProductPage, Search, ASC-Version, VERIFIED |

For this game, avoid names like Top Gun, Ace Combat, War Thunder, LEGO, Hot Wheels and Nerf. "Toy" as a generic word is fine. A starter list is in `aso/data/banned_terms.txt`. The validator also checks the competitor app and company names in `aso/data/competitors.json` (MEASURED from the iTunes Search API by the competitor-research step).

## 7. Product Page Optimization (A/B tests)

From PPO-Help and PPO-Mkt (VERIFIED):
- **What you can test:** up to **3 treatments** plus the original. Only the icon, screenshots and previews can change. Text (name, subtitle, description) cannot be tested.
- **Concurrency and length:** **one test at a time**, running up to **90 days** or until stopped. A test cannot be changed once started.
- **Traffic:** you choose the proportion. It is split evenly across treatments.
- **Eligibility:**
  - The app must be live (Ready for Distribution or Pre-Order Ready for Distribution).
  - Treatments show only on iOS and iPadOS 15+.
  - Not available for custom product pages, Apple Watch or iMessage.
- **Icons:** alternate icons must be in the current live binary, built with Xcode 13+, and 1024 x 1024. If someone installs from an icon treatment, they keep that icon on their device.
- **Review:** new metadata in treatments must be approved first. A test without icon changes can be submitted without a new app version.
- **Results:** Apple recommends waiting until a treatment is declared better or worse with at least **90% confidence**. Releasing a new version during a test can affect the results.

## 8. Custom Product Pages

From CPP-Help and CPP-Mkt (VERIFIED):
- **Count:** up to **70** per app.
- **What can vary:** screenshots, app previews, promotional text and keywords. Each page gets its own unique URL and can be localized.
- **Visibility:** a page is seen only through its URL, or in search for its assigned keywords once it is approved and set visible. It works on iOS and iPadOS 15+.
- **Review:** each page must be approved before it is visible. This can happen independently of an app update.
- **Requirements:** the app must be Ready for Distribution in at least one country or region. Pre-order apps can also use CPPs.
- **Optional deep link:** works on iOS 18+ and needs approval.
- **Analytics:** App Analytics shows impressions, downloads and conversion once a page has at least **5 first-time downloads**.
- **Apple's own figure:** CPP-Mkt says developers "see a 2.5 percentage point increase on average" when referring people to a custom product page, against a "1.6% average conversion rate on default product pages". This is Apple's marketing claim, not a measurement for this app.

Uses for Toy Plane Sim (ESTIMATE): separate pages for "play with friends (room code / LAN)", "vs AI (Rookie/Pilot/Ace)" and "Capture the Flag / Base Assault". Each page would carry its own keyword subset and link targets for social posts.

## 9. Other limits worth knowing

- **Rating prompts:** `SKStoreReviewController` can prompt up to 3 times in 365 days (ProductPage, VERIFIED).
- **Changing the app name** after the first approval needs a new version (ASC-AppInfo, VERIFIED).
- **India's listing language (ASC-Loc, VERIFIED, fetched 2026-10-25):**
  - India's default language is **English (U.K.)**. Its additional languages are Bangla, Gujarati, Hindi, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu and Urdu.
  - The US default is English (U.S.). Its additional languages are Arabic, Chinese (Simplified), Chinese (Traditional), French, Korean, Portuguese (Brazil), Russian, Spanish (Mexico) and Vietnamese.
  - The page also says the language shown "could be impacted by factors like the App Store language for their location, their device's language settings, languages you've added, and your primary language in App Store Connect".
  - **Corroborated (MEASURED, 2026-10-25):** all 26 competitor product pages at `apps.apple.com/in/...` report page language `en-GB`, and all 26 at `/us/` report `en-US` (`data/competitor_pages.json`).
  - **Consequence:** the IN listing is the en-GB localization. Its keyword field must be built and validated separately from en-US, and an en-GB localization must be added explicitly. `keyword-research.md` has both fields and their validator output.
- **HYPOTHESIS, Hindi keyword field:** ASC-Loc lists Hindi for India but doesn't say whether a hi localization's keyword field is searched by IN users with an English device language, by Hindi-language users only, or not at all. There's no measured demand for it either: Devanagari queries return no IN hints (MEASURED, `keyword-research.md`).
  - **Test once live:** put one unique Devanagari token only in the hi keyword field. Search it on an IN Apple ID with the device language set to English (U.K.), then to Hindi, and through `itunes.apple.com/search?country=in`.
  - **Then:** record here which case holds.
- **Unknown, with no Apple page found:**
  - how Apple matches partial words, plurals beyond the documented "climb/climbs" example, hyphenated words ("co-op" vs "coop") and phrases across name, subtitle and keywords.

## 10. Validator

The validator is `aso/tools/validate_metadata.py`. It uses only the Python standard library.

```
python3 aso/tools/validate_metadata.py aso/data/listing_current.json
```

What it checks:

| Area | Checks |
|---|---|
| Field length | name 2 to 30, subtitle 30, promotional text 170, description 4000 (required, no HTML), What's New 4000 |
| Keywords | ≤100 characters **and** ≤100 UTF-8 bytes; comma separator with no spaces around commas; each term more than 2 characters |
| Duplicates | plurals and duplicate words inside keywords; keyword words already in the name, subtitle or developer name; filler words, "app" and "game"; `#` and `@`; repeated words between name and subtitle (warning) |
| Pricing and claims | pricing words in the name, subtitle or keywords; superlatives in the name or subtitle; prices in the description (warning) |
| Banned and competitor terms | terms from `aso/data/banned_terms.txt` (fail or warn); competitor app and company names from `aso/data/competitors.json`. A competitor match is a warning, because some competitor names are generic phrases such as "air battle". |

Each field prints PASS, FAIL, WARN or SKIP. The script exits with code 1 if any field fails.

Result on the current draft (MEASURED, 2026-10-25):

```
PASS  name              13/30 chars, 13 bytes
PASS  subtitle          30/30 chars, 30 bytes
SKIP  promotional_text  empty (optional)
FAIL  description       required, missing
SKIP  whats_new         empty (optional)
WARN  name+subtitle     repeated words waste indexed space: plane, toy
FAIL  keywords          required, missing
```

The two failures are fields that have not been written yet, not rule violations.

## 11. Compliance items for submission (fetched 2026-10-25, ~17:20 IST)

### 11.1 Age rating: current tiers and the questionnaire (VERIFIED, ASC-AgeDefs, ASC-AgeSet)

- **Current tiers:** on iOS 26 and later the global ratings are **4+, 9+, 13+, 16+, 18+** (plus Unrated, which can't be on the App Store). Devices on an OS earlier than 26 still show the old **4+, 9+, 12+, 17+** scale, listed in ASC "under the Operating Systems Earlier than Version 26 section". "Age ratings for an app may vary based on the OS version."
- **Why `competitors.json` shows 12+/17+:** the Lookup API's `trackContentRating` returns the pre-26 scale (MEASURED: across 610 `trackContentRating` values in `data/lookup_*.json` and `data/search/*.json`, only 4+, 9+, 12+ and 17+ appear; never 13+, 16+ or 18+). So 12+ in the competitor table maps to the old scale, not to a current tier.
- **The questionnaire** covers in-app controls (parental controls, age assurance), capabilities (unrestricted web, user-generated content, social media, messaging and chat, advertising), mature themes, medical/wellness, sexuality/nudity, violence (cartoon or fantasy, realistic, prolonged graphic, guns or other weapons) and chance-based activities (gambling, simulated gambling, contests, loot boxes). Each is answered as none, infrequent or frequent. Apple computes the rating and any regional ratings from the answers.
- **Relevant thresholds (iOS 26+ scale, VERIFIED):** infrequent cartoon or fantasy violence → 9+; **frequent cartoon or fantasy violence → 13+**; infrequent guns or other weapons → 9+; **frequent guns or other weapons → 13+**; infrequent contests → 4+, frequent contests → 13+; messaging and chat, user-generated content and advertising all sit at 4+. Old scale: frequent or intense cartoon or fantasy violence → 12+.
- **Expected answers for Toy Plane Sim (HYPOTHESIS until the questionnaire is filled in):**
  - Cartoon or fantasy violence: **frequent**. Shooting down toy planes is the core loop in 5 of 6 modes (`game-audit.md` §1).
  - Guns or other weapons: **frequent**. Guns, rockets and bombs on every plane (`plane.gd:11-25`).
  - Contests: matches are scored per match with no leaderboards or rankings (`game-audit.md` §2). Infrequent or none is defensible; frequent also lands on 13+, so the answer doesn't change the result.
  - Messaging and chat: preset taunts only, no free text (`taunts.gd:4-6`). Whether presets count as "communicate with one another" is a judgement call; it sits at 4+ either way.
  - User-generated content: the typed pilot name is shown to others in the room. 4+ either way.
  - Advertising, loot boxes, gambling, web access: none (`game-audit.md` §2).
  - **Expected rating: 13+ on iOS 26+, 12+ on earlier versions.** Brazil and Korea show their own regional values.
- **Made for Kids is not available at 13+.** Apple offers the Kids category only when the calculated rating is 4+ or 9+ (ASC-AgeSet). This matches the "for kids" ban in §5 and `banned_terms.txt`.

### 11.2 Export compliance: `ITSAppUsesNonExemptEncryption`

- **What the build already says (VERIFIED):** `export_presets.cfg:73` puts `<key>ITSAppUsesNonExemptEncryption</key><false/>` into the iOS Info.plist. That tells App Store Connect the app uses no encryption, or only exempt encryption, and skips the per-build questions.
- **What the app actually uses (VERIFIED, repo):** WebRTC data channels through the `addons/webrtc_native` GDExtension, which bundles libdatachannel, libsrtp, usrsctp and **mbedTLS** (their license files are in `addons/webrtc_native/`). WebRTC data channels run over DTLS, a standard IETF protocol. The MQTT handshake uses `wss://` brokers (`rooms.gd:11`), which is TLS. This is standard, published cryptography in the app's own bundled libraries, **not** the OS crypto (URLSession) that Apple names as the typical exempt case.
- **Apple's rule (VERIFIED, Dev-Encrypt):** "Set the value to NO if your app—including any third-party libraries it links against—doesn't use encryption, or if it only uses forms of encryption that are exempt from export compliance documentation requirements. Otherwise, set it to YES." And: "Typically, the use of encryption that's built into the operating system… is exempt…, whereas the use of proprietary encryption is not." ASC-Export adds that apps using "standard encryption algorithms" need an export compliance determination, and "you're responsible for… claiming exemption inaccurately".
- **Expected answer (HYPOTHESIS, not legal advice):** `false` is the answer most games with standard-protocol networking give, on the reading that the encryption only protects the game's own traffic and isn't the app's purpose (US EAR Category 5 Part 2 exemptions). Apple doesn't confirm this reading for libraries outside the OS, so it is the developer's self-assessment. Two open points:
  - Apple notes that exempt apps "might alternatively be required to submit a year-end self-classification report to the U.S. government" (VERIFIED, Dev-Encrypt). Whether that applies here: unknown.
  - France controls the import of encryption apps, mainly "Secure Communications" apps (VERIFIED, ASC-Export). A game is unlikely to count (HYPOTHESIS).
  - Upgrade path: if in doubt, answer the in-ASC questionnaire once without the plist key and see whether it asks for documents.

### 11.3 App Privacy label: definitions vs the "Data Not Collected" hypothesis (VERIFIED definitions, Privacy)

- **"Collect"** means "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time."
- **"Third-party partners"** means "analytics tools, advertising networks, third-party SDKs, or other external vendors whose code you've added to your app." You must disclose what you **and** your partners collect.
- **How the game's network services map onto that (VERIFIED code, HYPOTHESIS reading):**
  - **No developer server.** Rooms are P2P (`rooms.gd:4-9`). The developer never receives player data, so nothing is "collected" by the developer.
  - **MQTT brokers** (HiveMQ, EMQX, Mosquitto; `rooms.gd:11`) relay the connection handshake, which contains IP addresses but not the pilot name (`PRIVACY.md`). The MQTT client is open-source code in the repo (`addons/mqtt/mqtt.gd`), not a vendor SDK. The brokers are public services the app connects to, not code added to the app. Whether a broker keeps those messages longer than needed to relay them: **unknown**. If one does, and it counts as a partner, the IP-derived data might need disclosing.
  - **STUN servers** (Google, Cloudflare; `rooms.gd:13`) see the device's IP to tell it its public address. That is "servicing the request in real time". Retention under their own policies: unknown.
  - **Other players** see your IP and pilot name (`PRIVACY.md`). That is peer-to-peer, not developer collection.
  - **Purchases** run through StoreKit. Apple: "If your app uses a payment service, the payment information is entered outside your app, and you as the developer never have access to the payment information, it is not collected." No purchase history leaves the device to the developer (`shop.gd`, no server).
- **Reading (HYPOTHESIS):** "Data Not Collected" is the answer the definitions support, because neither the developer nor any SDK partner keeps data. The residual risk is the public brokers. `PRIVACY.md` already discloses them, which is the honest backstop. Re-check if a TURN relay, crash reporting or analytics is ever added.

### 11.4 EU Digital Services Act trader status (VERIFIED, ASC-DSA)

- **Everyone must declare a status:** "Even if you don't distribute apps in the EU, you'll still need to declare a trader status." You're asked when submitting a new app.
- **Who is a trader:** Apple lists factors, including "Whether you make revenue as a result of your app, for example if your app includes In-App Purchases". Toy Plane Sim sells 15 IAPs, which points toward trader (HYPOTHESIS; Apple says it "can't determine whether you're a trader").
- **What a trader must publish:** individuals must give an address or P.O. box, a phone number and an email, verified with two-factor codes and a document. Apple shows them on the product page in all 27 EU storefronts. Non-traders' EU customers are told consumer-protection rights don't apply.
- **Decision for the India-then-global plan:** either declare trader and accept public contact details on EU pages (a P.O. box is allowed with proof), or leave the 27 EU storefronts out of availability until ready. Leaving the EU out still requires a declared status. UK storefronts are not in the EU.

### 11.5 In-App Purchase review screenshots and metadata (VERIFIED, ASC-IAP)

- **Every IAP needs an App Review Screenshot**: "A screenshot of the In-App Purchase that clearly shows the item or service being offered. This screenshot is used for review only and isn't displayed on the App Store." It must meet "any of the screenshot specifications your app supports", so 2868 x 1320 or 2622 x 1206 landscape works (§2). "Once you've uploaded a screenshot, you can update it but not remove it."
- **For this game: 15 screenshots,** one per product in `shop.gd:17-33`. Each should show that item in the Hangar Shop, with its preview on the plane. HYPOTHESIS: `tools/appstore_shots.gd --fake-store` can render shop states for this, as it did `5-shop.png`.
- **Display name 2–30 characters, description at most 45** (ASC-IAP, stricter than ProductPage's 35/55, §1). MEASURED from `shop.gd`: the longest in-game title is 21 characters, so titles fit. **8 of the 15 in-game blurbs are over 45 characters** (longest 73), so the ASC descriptions need shorter text.
- **Promotional image** (1024 x 1024, JPG or PNG, 72 dpi, RGB, flattened, no rounded corners) is required only to promote an IAP on the product page.
- **Review notes** up to 4000 characters per IAP: say that items are cosmetic and how to reach the shop.

### 11.6 India price points for the Hangar Shop

- **What Apple documents (VERIFIED, ASC-Price):** you "choose from up to 800 price points by default" per storefront, and the list shows "25 price points that follow the most common pricing convention for each country or region" first. Apple can adjust non-base storefront prices for tax and exchange-rate changes, but "will never change the price in your base country or region". The actual INR price list is visible only inside App Store Connect, so **Apple-documented validity of ₹79, ₹99, ₹199 and ₹499: unknown** without an account.
- **Indirect evidence (MEASURED, `tools/price_points.py`, `data/in_price_points.json`, 2026-10-25 17:36 IST):** I read the In-App Purchase lists (up to 10 items each) on 214 live IN product pages: the IN top-free Action and Simulation charts plus the 27 competitors. A price showing on a live IN page is a price point Apple currently allows.
  - ₹499: 211 items in 112 apps. ₹199: 189 items in 112 apps. ₹99: 183 items in 92 apps. These are three of the four most common INR IAP prices.
  - **₹79: 1 item in 1 app.** It exists, but it is rare; ₹49 (11 apps) and ₹89 (8 apps) are more common near it. One sighting doesn't show it is in the default 25 or will survive the next Apple price update.
- **What to do:** treat ₹99/₹199/₹499 as valid (MEASURED, widely live). Treat ₹79 as **probably valid, unconfirmed**: open the India price list in App Store Connect when creating the first IAP. If ₹79 isn't offered, the nearest are ₹89 or ₹49, which changes the bundle savings in `game-audit.md` (each ₹199 set vs 99+79+79).
- The INR comparison in `competitor-research.md` §2b compares against these prices, so its ₹79 conclusions carry the same caveat.

## Round 2 changes

Against the latest research critique (r3 in `data/critiques_round1.json`):
- r3 #1: §5 row 2.3.9 now notes the callsign rename (`main.gd:16`, commit `ed9bebf`) and the old-screenshot blocker.
- r3 #9: §5 row 2.3.9 cites `tools/make_music.py:1` for original music, not the brief.
- r3 #10: sections run 1-11 in order (§10 Validator, §11 Compliance), so the §11.x cross-references in game-audit.md, competitor-research.md and keyword-research.md point to the compliance items as intended.

