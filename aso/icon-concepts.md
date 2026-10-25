# Icon concepts: Toy Plane Sim

A brief for 3 icon concepts, each rendered from the game's own plane models. Labels: VERIFIED (code or Apple page), MEASURED (looked at or counted), ESTIMATE, HYPOTHESIS. Icon conversion effects are **unknown** until Product Page Optimization data exists. The icon is one of the three things PPO can test, so plan to test, not to guess (VERIFIED, apple-requirements.md §7).

## Constraints (VERIFIED, apple-requirements.md §4)

- 1024x1024, square, opaque, RGB, no pre-rounded corners (Apple applies the mask). No text needed.
- Apple auto-generates dark, clear and tinted versions if none are supplied. Godot's iOS export can take `icons/icon_1024x1024_dark` and `icons/icon_1024x1024_tinted`. The current preset sets only `icons/icon_1024x1024` (`export_presets.cfg:72`).
- No Apple marks, no "free", no price, no third-party marks. The Top Gun callsigns stay out (`main.gd:16`).

## What the category looks like (MEASURED, competitor-research.md §5)

- 13 of the 20 competitor icons are mostly blue sky or sea.
- 13 of the 16 combat icons are realistic military jets at a three-quarter, nose-forward angle.
- The current icon (`assets/ui/icon_ios.png`) is a yellow, boxy, older cub model on flat blue with a faint circle edge. It is closest to Epic Plane Evolution's (game-audit.md §5).

Implication (HYPOTHESIS): a **non-blue background** and a **plane that is obviously a toy** are the two cheapest ways to stand out in a row of search results.

## The models to render from (VERIFIED)

- `Planes.build(kind, root, paint, trim, glass, dark, glow, livery)`, `planes.gd:81`.
  - `kind` is one of `cub`, `racer`, `twin`, `fighter`, built by `_cub`, `_racer`, `_twin` and `_fighter` (`planes.gd:135-207`).
  - The look follows `Worlds.index`: each world sets the landing gear (wheels, floats, skis, tyres, none, spats) and trim colours (`planes.gd:29-36`).
- **Team colours:** blue `Color(0.3, 0.55, 1.0)` and red `Color(1.0, 0.35, 0.3)` (`plane.gd:19`). The fuselage keeps the team colour even with a paint job (`planes.gd:41-43`).
- **Paint jobs:** Golden Ace, Black Phantom, Neon Night, Inferno (`planes.gd:44-50`).
- **Stickers:** Star, Lightning, Flame, Roundel, Checkers, Shark Mouth (`planes.gd:39-40`).
- **Shading:** the toon shader `res://toon.gdshader` (the game's `main.toon()`) plus the game's ink outline (`main.add_outline()`).
- **Render script:** `aso/tools/render_icons.gd` wraps all of this. It writes `aso/creative/icons/{A_hero,B_duel,C_face}.png`, plus `B_duel_dark.png` and `B_duel_tinted.png` for the chosen concept (all RGB, 1024, no alpha: MEASURED with `sips`). For icon renders only, it cuts the cub's wing struts out of the merged strut mesh (`_drop_struts`), because at 120 px and below the inked 0.05-radius rods read as scratches. Game code is untouched.
- **Same plane as screenshot 1:** `builds/appstore/1-battle.png` shows the Toy Cub with yellow wings on a blue fuselage. That is the Golden Ace livery (`Settings.values.livery = 1`, `tools/appstore_shots.gd:49`; `planes.gd:46`). The blue cub in A and B now uses it (`GOLD` in the script). VERIFIED (code).
- **Size test:** `aso/tools/icon_sheet.sh` renders the concepts, fetches the 20 competitor icons (`data/competitors.json`) and the top 3 iTunes Search results for "dogfight" (country=in), downsizes everything with `sips`, then builds two images. It runs in about 30 s.
  - `creative/icons/contact_sheet.png` has five sections:
    1. sizes 180 to 29 px, light and dark wallpaper;
    2. 60 px in front of the 20 competitors;
    3. the 60 px mock search list;
    4. **the search-result size**, 192 px (@3x) and 128 px (@2x), next to the 3 real search results at the same size;
    5. **an iOS dark home-screen row** at 60 px, with B_dark first.
  - `creative/icons/masked_1024.png` shows A, B, C and B_dark at 1024 with the rounded mask, to check what the corners cut.
  - The "about 64 pt" search-result size is an ESTIMATE taken from the critic's note. I did not check it against Apple's HIG.

  ```
  sh aso/tools/icon_sheet.sh          # all concepts + sheets
  godot --path . --resolution 1024x1024 -s aso/tools/render_icons.gd -- A   # one concept
  ```

  The notes below describe the renders and sheets as of 2026-10-25, after the second round of critic fixes. "MEASURED (sheet)" means I looked at that size in `contact_sheet.png` at 1:1. "MEASURED (by eye)" means I judged a preview by eye, without a pixel count.

## How the three differ (VERIFIED, script)

| | A hero | B duel | C face |
|---|---|---|---|
| Subject | one Golden Ace cub, three-quarter, nose to viewer | Golden Ace cub shooting a red cub | red cub, head-on |
| Palette | cream to Green Valley green and teal (from `1-battle.png`) | pale orange to deep coral | Sky Kingdom violet to pink (`3-sky-kingdom.png`) |
| Reads as | toy plane, character (shark mouth) | fight, two players | toy as a face |

**Correction (2026-10-25 ~18:30 IST).** The three are less different than this table suggests: all three use the same cub model and the same bottom-left to top-right diagonal. The 14-16 px outline is a sticker edge drawn only for the icons; the in-game ink lines are thin (compare screenshot 1). That the thick edge "matches the game" is a HYPOTHESIS; a 6-8 px version has not been rendered. A and B share the plane on purpose, because it is the plane in screenshot 1.

## Concept 1: Hero toy plane

**Idea.** One chunky toy plane, big in the frame, on a background that is not the category's blue. It is the same plane and livery as screenshot 1.

**Render** (`creative/icons/A_hero.png`), VERIFIED (script):
- **Plane:** `cub`, world 0 (Green Valley, wheels), blue fuselage, Golden Ace livery (yellow wings, cream cowling). No rockets, so no black rods break the silhouette.
- **Sticker:** Shark Mouth, scaled 1.8x along the fuselage side in the render script (`grow_mouth`). The game's decal is about 1.1 x 0.6 m and was a 2 px dot at 60 px. Game code is untouched.
- **Angle:** low camera `(-9, 2.5, -13)`, fov 45, then refit to 92% of the frame. The nose points to the right of the frame and toward the viewer, so the prop and cowling face out. Banked 24° so the wing top is lit and the wingtips stay clear of the rounded corners.
- **Background:** radial from cream in the top-left corner (away from the cowling) through valley green to dark teal.
- **Outline:** 16 px ink.

**What it looks like:**
- MEASURED (by eye, masked 1024 preview): yellow wing top, blue fuselage, red shark mouth with white teeth, cream cowling with ink against mid-green. Both wingtips sit inside the iOS mask.
- MEASURED (sheet): reads as a yellow-winged blue plane at 180 down to 60 px. The shark mouth reads at 192 to 87 px and is a red dash at 60. At 40 and 29 px it is a yellow slash with a blue body.
- MEASURED (sheet, competitor row): no other icon in the 20 uses a green gradient with one ink-outlined toy plane. Position 12 (a green cartoon plane on cyan) is the closest in style.
- It says nothing about combat. HYPOTHESIS: fine for brand, weak for "dogfight".

**Best for:** the safe control in a PPO test, or Strategy C.

## Concept 2: Aerial duel

**Idea.** Two toy planes, blue chasing red, with tracers hitting the red one. It says "toy" and "fight" at once, and two planes hint at "with someone".

**Render** (`creative/icons/B_duel.png`), VERIFIED (script):
- **Planes:** two cubs. Blue (Golden Ace, matching screenshot 1) bottom-left, climbing and firing. Red (team colours) top-right, banking away, 9 m ahead along the blue plane's heading. Neither carries rockets. Both are fitted to 95% of the frame.
- **Tracers:** two tapered streaks per gun, 30 and 40 px wide at 1024, running from the wing-root muzzles to 95% of the way to the red plane.
- **Hit spark:** an orange glow with a white core (70 px) where the fire lands on the red plane.
- **Smoke:** grey puffs (`Color(0.55, 0.55, 0.58)`, the game's hurt-part smoke from `plane.gd:687`) trailing behind the red plane's engine. This replaces the white airshow trail in the earlier spec: hit smoke also says the red plane is losing.
- **Background:** radial from pale orange `(1.0, 0.78, 0.4)`, centred behind the red plane, to deep coral `(0.85, 0.3, 0.25)` behind the yellow-winged plane. The cream wingtips no longer sit on a cream centre, and the yellow wings sit on the darker coral.
- **Outline:** 14 px ink.

**What it looks like:**
- MEASURED (by eye, masked 1024 preview): each plane spans about half the icon width (blue about 51%, red about 48%). The blue nose and the red tail overlap horizontally, with about 15% of the height between them. Empty gradient is now limited to the top-left and bottom-right corners.
- MEASURED (sheet): at 192, 128 and 87 px it reads as a yellow-and-blue plane shooting a red plane, with the spark visible. At 60 px both planes, their colours and the spark read. At 40 px it is still two planes with something bright between them. At 29 px it is two coloured shapes.

**Best for:** Strategy A (friends dogfights) and Strategy B (arcade combat).

## Concept 3: Character face

**Idea.** The toy plane as a character: nose to camera, cowling and windshield as the face. It sells the toy and the personality rather than the fight.

**Render** (`creative/icons/C_face.png`), VERIFIED (script):
- **Plane:** `cub`, world 0 (cream cowling, no Sky Kingdom pods), red team colour. The windshield glass is a light sky blue `(0.55, 0.78, 0.95)` for this render only, so it reads as a face, not a black hole. The two prop blades are turned to lie along the wing, so they leave the cowling and windshield clear (the cub has 2 blades, so a 4-blade X is not possible).
- **Framing:** head-on and banked 30°, so the wing runs from bottom-left to top-right. A wide lens (fov 85, close camera) makes the nose large next to the wingtips. The whole plane is fitted to 90%, so both wingtips sit inside the square.
- **Background:** Sky Kingdom palette, deep violet at the top to lavender-pink at the bottom.
- **Outline:** 16 px ink.

**What it looks like:**
- MEASURED (by eye, masked 1024 preview): a cream nose with a blue windshield and a red wing, all inside the mask. No pods and no cut edges.
- MEASURED (sheet): at 192 to 87 px it reads as a plane coming at you. At 60 px it is a thin red diagonal with a white nose. At 40 px the nose is a white dot on a red line. It is the weakest of the three at small sizes, because a head-on wing is thin.
- MEASURED (sheet, competitor row): purple is unique in the 20-icon row, and no competitor uses a head-on shot.

**Best for:** a PPO treatment (Strategy C).

## Recommendation and test plan

1. **Launch icon: Concept 2, B duel (HYPOTHESIS).** It is the only concept that carries the Strategy A promise (fight a friend), and the warm background breaks the blue row.
   - Before this round, by the sheet's own measurement, B lost the duel at 60 px and below. The planes were small, the tracers faint and short, and 40% of the icon was empty. The fixes above were aimed at exactly that.
   - After the fixes, MEASURED (sheet): the duel reads at 60 px and survives at 40 px.
   - That B *converts* better is still a HYPOTHESIS. No conversion data exists (unknown).
   - **A is the safer control.** One plane is the simpler read, and it carries the brand without depending on a story. If the team wants the lowest-risk launch icon, ship A and test B against it.
   - Either is better grounded than the current `icon_ios.png`, which shows an older plane model than the game ships (game-audit.md §5) and blends into the blue majority (MEASURED, sheet).
2. **Small-size check (done; rerun after any change):** `sh aso/tools/icon_sheet.sh`. Check `contact_sheet.png` sections 3 to 5 (60 px list, 192/128 px search size, dark home screen) and `masked_1024.png` for corner clipping.
   - MEASURED (sheet): all three concepts read as "a plane" at 60 px.
   - In the mock search list, A (green) and B (orange) stand out most against the blue-grey neighbours. C stands out by colour, but its subject is the least clear.
   - At 192 px, next to the three real search results, all three concepts are as legible as the competitors' detailed 3D art. B and A are the only flat-gradient icons in that set.
3. **After launch, run PPO** with up to 3 treatments, one test at a time, for up to 90 days (VERIFIED, apple-requirements.md §7). Ship B (after the open render fixes in `launch-action-plan.md`) as control and run A (after its fixes) as the first treatment. **Do not put C into PPO as it stands:** the head-on view has no readable face and the prop reads as skis. Add a third treatment only after C is rebuilt (for example the fighter model, or a plane flying through a prize balloon) and passes the 60 px read on `contact_sheet.png`. Apple reports results by conversion. No numbers can be predicted here (unknown).
4. **Dark and tinted variants (rendered for B).**
   - `creative/icons/B_duel_dark.png`: navy gradient `(0.12, 0.12, 0.22)` to `(0.04, 0.04, 0.08)`, with a white rim (alpha 0.85, 8 px outside the ink) so the planes keep their edge on a dark background.
   - `creative/icons/B_duel_tinted.png`: the dark version mapped to grayscale by HSV value (max channel), not luma. Luma put the blue plane at mid-grey.
   - MEASURED (sheet): the dark variant keeps both outlines down to 40 px on the dark home-screen row. The tinted variant reads as two white planes with ink and rim on dark grey.
   - To use them, set `icons/icon_1024x1024_dark` and `icons/icon_1024x1024_tinted` in the iOS export preset. Not done: game files are untouched.
   - If A is chosen instead, change `CHOSEN` in `render_icons.gd` and rerun. If no variants are supplied, Apple generates them automatically (VERIFIED) from an image nobody has checked.

## Round 2 finalists

Judges scored `creative/icons/v3/duel.png` 6.8/10 (average of three). This round reworks it as `creative/icons/v3/final_duel.png`. It is rendered by `tools/icon_duel.gd` (edited in place; the layout constants sit at the top of the file). Run it with `godot --path . --resolution 1024x1024 -s aso/tools/icon_duel.gd [-- bg=orange]`. It takes about 10 s.

| File | What it is | Spec check (VERIFIED, `sips -g hasAlpha -g pixelWidth`) |
|---|---|---|
| `v3/final_duel.png` | Launch candidate, mid-teal background | 1024, RGB, no alpha |
| `v3/final_duel_orange.png` | PPO variant: only the background changes, to the round-1 B_duel orange ramp | 1024, RGB, no alpha |
| `v3/final_duel_dark.png` | Apple dark appearance: transparent background (per Xcode guidance, apple-requirements.md §4), ink outline plus an outer white rim at 0.85 alpha | 1024, RGBA |
| `v3/final_duel_tinted.png` | Apple tinted appearance: grayscale of the dark version on black. Value×0.6 + luma×0.4, so the red plane comes out darker than the hero | 1024, grayscale RGB |
| `v3/final_duel_sizes.png`, `v3/final_duel_orange_sizes.png` | 180/120/87/60/40 px with the squircle mask, on light and dark rows | — |
| `v3/src/final_duel_render.png` | Raw transparent 3D pass | — |

**What changed against the judges' notes:**
- **Tracers.** The blob is replaced by 3 separate dashes along one line from the hero's nose to the hit. Each dash tapers from thin to wide (22, 28 and 34 px), is pale yellow with a white core, and has a 6 px ink edge. There are clear gaps between them, a gap after the prop and a gap before the star.
- **Spark.** It is now a single bold 4-point star (radius 84 px) with a white-hot core and a 10 px ink edge, sitting on the red plane's rear fuselage behind the cockpit.
- **Red plane.** It is turned to a top three-quarter view (banked +20°), so the wings and tail read as a plane, not an X, and nothing red floats under the spark.
- **Sizes and gap.** MEASURED (projected bounds printed by the script): the hero spans 60% of the width and the red plane 35%. The gap from nose to hit is 324 px.
  - The hero is aimed straight at the red plane, so the shot line runs off its nose and the prop stays visible.
- **Safe area.** The planes span y 97 to 968 and x 143 to 880, so everything sits inside the squircle and neither plane bleeds off.
  - Judge 1 asked for the hero to bleed off the bottom-left. Judges 2 and 3 asked for it to sit fully inside. The majority won.
- **Background.** Lifted to a mid teal, `(0.42, 0.8, 0.76)` at the centre down to `(0.1, 0.42, 0.46)` at the edge. The light glow is centred on the hit. MEASURED (sizes strip): the icon's edge shows clearly on the dark row.
- **Hit-smoke puff (optional note).** Tried with 3 flat, inked, light-grey discs and then dropped. At 1024 px they read as bubbles or stray balls, not smoke, and they cluttered the gap between the planes.

**Small-size read (MEASURED, by eye on `final_duel_sizes.png`):**
- At 60 px the icon reads in order: blue and yellow plane, the dashes, the star, the red plane.
- At 40 px the star is still a distinct white-yellow point on the red plane. The dashes merge into a faint line.
- The red plane is the weakest element at 40 px, because it is only 35% of the width.
- Both backgrounds hold on the light and dark rows. On orange the red plane has less hue contrast and depends on its ink outline (the same weakness noted in round 1).

**Test plan (HYPOTHESIS until PPO data exists; no conversion numbers are known):**
1. Ship `final_duel.png` (teal) as the control.
2. Run `final_duel_orange.png` as a clean one-variable PPO treatment: only the background changes.
3. Wire up the dark and tinted variants through `icons/icon_1024x1024_dark` and `icons/icon_1024x1024_tinted` in the iOS export preset. This is not done here, because game files are off-limits.

### Skywrite (round 2)

Judges scored `creative/icons/v3/skywrite.png` 7.0/10 (average of three). This round reworks it as `creative/icons/v3/final_skywrite.png`. It is rendered by `tools/icon_skywrite.gd` (edited in place; the layout constants sit at the top of the file). Run it with `godot --path . --resolution 1024x1024 -s aso/tools/icon_skywrite.gd [-- foe]`. It takes about 20 s. For the size strip, write `/tmp/skywrite_{180,120,87,60}.png` with `sips -z`, then run it with `-- sizes`.

| File | What it is | Spec check (VERIFIED, `sips -g hasAlpha -g pixelWidth`) |
|---|---|---|
| `v3/final_skywrite.png` | Charm arm, purple-to-coral background | 1024, RGB, no alpha |
| `v3/final_skywrite_foe.png` | Same art plus a small all-red foe cub fleeing in the upper left, for the "promise combat" note | 1024, RGB, no alpha |
| `v3/final_skywrite_dark.png` | Apple dark appearance: transparent background (Xcode guidance, apple-requirements.md §4) | 1024, RGBA |
| `v3/final_skywrite_tinted.png` | Apple tinted appearance: luminance of the dark version on black | 1024, grayscale RGB |
| `v3/final_skywrite_sizes.png` | 180/120/87/60 px with the squircle mask, on light and dark rows | — |
| `v3/src/skywrite_plane_src.png`, `v3/src/skywrite_smoke_src.png` | Raw transparent 3D passes | — |

**What changed against the judges' notes:**
- **Plane size and position.** The camera is fitted so the plane spans 60% of the frame (its larger side), centred at (0.64, 0.50). It was about 45% in the bottom-right before. The nose climbs to the upper right, so the trail leaves from the tail.
- **Outline.** The thick white sticker outline is gone. The plane now has a 21 px game-ink outline (1.5 times round 1's 14 px) with a thin 8 px white rim outside it, so it still separates from the dark purple top. The smoke gets a 9 px ink edge.
- **Trail.** It is now one closed loop: a short stem straight back from the tail, then a full circle (radius 155 px) whose oldest end tucks under the stem. Nothing reaches an edge, and there is no run-out that makes a letter shape. By eye on a 500 px preview (MEASURED), the loop's outer edge sits about 10% in from the left, outside the 8% squircle inset.
- **Puffs.** There are fewer, larger puffs (radius 46 px at the tail down to 32 px at the oldest end, one every 1.25 radii), so the scallops still show at 87 px. The taper runs thick at the tail to thin at the start, as judge 1 asked. Judge 3 asked for an even width, so the taper is kept mild (about 1.4:1).
- **Motion cue.** A white prop-blur disc at 55% opacity, drawn in its own pass over the blades.
- **Wing stars.** Dropped (sticker 0). They mushed at 60 px.
- **Background.** Unchanged purple-to-coral. All three judges asked to keep it.

**Small-size read (MEASURED, by eye on `final_skywrite_sizes.png`):**
- At 60 px it reads as a big yellow-and-red plane plus a white ring joined to its tail. In round 1 it was a small plane plus a white scribble cut off by the corner.
- At 60 px the ring reads as an "o" rather than as puffs; the scallops show from 87 px up.
- Both rows hold. The ink outline carries the plane on the coral corner, and the white rim carries it on the dark top.

**Not fully done:**
- **"Chase" note (judge 2).** The foe sits in the empty upper left, not ahead of the nose. With the hero at 60%, the space past the nose is taken by the prop, so it reads as "two planes" rather than "chasing". If combat is the goal, the duel icon already covers it.
- **Hit starburst.** Not added, to keep the 60 px read clean.

**Test plan (HYPOTHESIS; no conversion data):** Keep `final_duel.png` as the control. Run `final_skywrite.png` as the charm treatment in a PPO test. If a third arm is allowed, add `final_skywrite_foe.png` to test whether a visible enemy brings back the combat promise.
