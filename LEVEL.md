# Level layout (props.gd)

Map ±2500 m, mountain ring beyond ~1500. Bomber ROUTE: (0,1800) → (1200,600) → (-1200,-600) → (0,-1800) at 220 m.
Nothing solid rises above 120 m within 450 m of the route (`_solid` warns if it does). Trees and scattered rocks are not obstacles.

| Landmark | Where | Role |
|---|---|---|
| Home airfield (Blue) | Terrain.RUNWAY (x 0, z 1650–2300, y 14). 3 hangars + tower east side, windsock west | Blue spawn; escort start (route starts overhead) |
| Village + church steeple | (600, 1300), under route leg 1 | First waypoint landmark |
| Windmill (turning sails) | Highest point < 190 m in x 950–1300, z 1300–1650 (now ≈ (1300, 182, 1650)) | Navigation landmark east of the village |
| Lighthouse | North shore of the lake (≈ (-797, 9, 1194)) | Lake landmark |
| Red viaduct bridge | Snapped to Terrain.RIVER near (355, -660), deck ≈ 80 m, pillars every 45 m | Fly-under challenge |
| Spire canyon | Two rows of 70–140 m spires, x ≈ -1500, z -170…470 | Low-level dogfight cover (west) |
| Rock arches | Three fly-through arches at x 1450, z -470 / -250 / -30, plus loose spires | Low-level dogfight cover (east) |
| Red airfield | Centre (-300, -1500) on the 90 m plateau, along route leg 3, 3 hangars + tower | Red spawn in Dogfight |
| Enemy factory fortress | (0, -1800) = ROUTE[-1], walled 280 m square, buildings ≤ 28 m tall | Escort TARGET |

Spawns (recommended for main.gd `_base()`):
- Dogfight Blue: `Vector3(i * 30.0 - 45.0, 160, 2150)`, yaw `0.0` (over home runway, heading north, -z).
- Dogfight Red: `Vector3(-345.0 + i * 30.0, 200, -1450)`, yaw `PI` (over Red airfield, heading south, +z).
- Escort: unchanged (behind the lead bomber, which starts over the home runway).

Forests are clumped by noise (seed 4242), pines above ~160 m, none above 330 m, on slopes steeper than ~37°, in water, on the runway or near landmarks.
