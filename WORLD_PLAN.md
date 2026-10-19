# World & level design — parallel agent plan

Shared contract: `terrain.gd` → `Terrain.height(x, z)` is the only ground truth (mesh, crashes, props, AI).
Constants there: WATER_Y, ROUTE (bomber path, ground capped at 90 m under it), LAKE_CENTER/RADIUS, RUNWAY rect.
Each agent owns its own files and must NOT edit main.gd / plane.gd / bullets.gd / rockets.gd / project.godot; the lead integrates.

## Agent 1 — Terrain (owns terrain.gd, terrain_ground.gdshader, tools/preview_terrain.gd)
- Keep `height()` constraints; add a river (`Terrain.RIVER` polyline, lake → (800,-1200) → map edge, bed below WATER_Y).
- `Terrain.build() -> Node3D`: flat-shaded low-poly mesh, vertex colours by height/slope (sand, greens, rock, snow), runway strip with markings; ~25 m grid inside ±2500, coarse to ±6000; < 400k tris, < 1.5 s build. Toon-lit, writes normals (outline pass).
- `Terrain.normal(x, z)`.
- Preview script saves /tmp/terrain_*.png; iterate on screenshots.

## Agent 2 — Props, landmarks, level design (owns props.gd, assets/, tools/preview_props.gd, LEVEL.md)
- Kenney Nature Kit + one town/castle kit (verify CC0), only used GLBs, < 25 MB, materials swapped to toon.gdshader.
- `Props.build() -> Node3D` (MultiMesh forests/rocks, seeded, on Terrain.height, off water/runway/route) and `Props.obstacles() -> Array[AABB]`.
- Landmarks: home airfield at RUNWAY (hangars, tower, windsock), village ~(600,1300), windmill on a hill, bridge over the river, lake lighthouse, enemy factory/fortress at ROUTE end (0,-1800) = escort target, Red airfield ~z=-1500, rock spires/canyon for dogfight cover off the route.
- Preview screenshots /tmp/props_*.png.

## Agent 3 — Atmosphere (owns sky.gd, sky/clouds/water shaders, tools/preview_sky.gd)
- `Sky.build_environment()`, `Sky.build_sun()`, `Sky.build_clouds()` (toon cumulus MultiMesh 300–600 m, clear of 220 m route, fade near camera), `Sky.build_water()` (plane at WATER_Y, depth-foam shoreline, stylised ripples).
- Preview screenshots /tmp/sky_*.png.

## Lead integration (after all three)
- `_build_world()`: replace flat ground/towers with Terrain.build(), Props.build(), Sky.*; `obstacles` += Props.obstacles().
- Crash/AI/bullets/rockets: replace `y < 1` / `y < 0` / altitude floors with `Terrain.height(x, z)`.
- Spawns from LEVEL.md; then test.sh regression + screenshots.
