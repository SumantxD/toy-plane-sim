# Toy Plane Sim — status (2026-10-19)

Godot 4.7.2. Code-built game: main.gd (rules, AI, UI, networking), plane.gd (flight, damage, audio, HUD),
planes.gd (4 plane types + models), terrain.gd, props.gd (+ LEVEL.md), sky.gd (class Atmos), sfx.gd,
rockets.gd, bullets.gd. Builds: ../builds (macOS zip, Windows exe, HOW_TO_PLAY.txt).

## Worlds
worlds.gd = registry + DEFAULT config; each world is worlds/<name>.gd (def + optional shape/color/bottom/layout/nodes hooks).
env.gd = wind/gust/updrafts/storm/weather/hazards (lava bombs, lightning). battlefield.gd = balloons, supply crates, AA guns.
Preview a world: `godot --path . -s tools/preview_world.gd -- <index>` -> /tmp/world_<name>_*.png. Test flag: `--world N`.

## Test
- `./test.sh MODE CLIENTS SECONDS SPEED` (0 escort, 1 dogfight), e.g. `./test.sh 0 3 70 4`
- Screenshot + FPS: `godot -- --server --start --bot --shot 30 /tmp/shot.png`
- Previews: `godot --path . -s tools/preview_{planes,terrain,props,sky}.gd`
- Online (WebRTC rooms over public MQTT, rooms.gd): `--host-online [--room-file F]` / `--join-room CODE`
- Export: `godot --headless --export-release "macOS"` / `"Windows"`

## Open
1. Online rooms: STUN only. Very strict NAT pairs (some CGNAT) need a TURN relay: add free ExpressTURN
   credentials to Rooms.ICE (email signup, no card). Fallback documented: Tailscale.
2. Exported-app online test on this Mac was blocked by the macOS firewall entry for /tmp/macbuild
   (set to Block). Editor<->editor online tests pass; friends must click Allow on first launch.
3. Sound is wired but not ear-tested by a human; tune volumes.
4. Parked: takeoff/landing, cargo mode, roles, bump physics, key rebinding, recorded engine sounds.
