# Toy Plane Sim — status (2026-10-19)

Godot 4.7.2. Code-built game: main.gd (rules, AI, UI, networking), plane.gd (flight, damage, audio, HUD),
planes.gd (4 plane types + models), terrain.gd, props.gd (+ LEVEL.md), sky.gd (class Atmos), sfx.gd,
rockets.gd, bullets.gd. Builds: ../builds (macOS zip, Windows exe, HOW_TO_PLAY.txt).

## Worlds
worlds.gd = registry + DEFAULT config; each world is worlds/<name>.gd (def + optional shape/color/bottom/layout/nodes hooks).
env.gd = wind/gust/updrafts/storm/weather/hazards (lava bombs, lightning). battlefield.gd = balloons, supply crates, AA guns.
objectives.gd = supply economy (cargo home -> team bank, pays for deploys/HQ repair), Capture the Flag (mode 4), Base Assault (mode 5: HQs + bomber raids), AI jobs via objective_for(). Base guns stand down in modes 4/5 (asymmetric Escort layout).
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

## Networking under lag (tools/lagtest.sh + tools/lagproxy.py)
A UDP relay adds ping, jitter, loss and (optionally) reordering between a bot client and the host;
`--netstats` on the client prints what remote planes look like every 10 s. Results after the fixes
(snapshots per 10 s for ~8 remote planes, full rate is ~2300):

| link | ping | snaps | worst gap | guessed ahead | frozen |
|---|---|---|---|---|---|
| LAN | 8 ms | 2320 | 44 ms | 0% | 0% |
| good wifi 40/5/0 | 55 ms | 2030 | 50 ms | 0% | 0% |
| other city 100/15/0.5% | 126 ms | 2213 | 82 ms | 0% | 0% |
| bad hotspot 250/50/3% +reorder | 295 ms | 2240 | 145 ms | 0% | 0% |
| awful 400/100/8% +reorder | 473 ms | 2079 | 194 ms | 0% | 0% |

What made the difference:
- Snapshots are `unreliable` (not `unreliable_ordered`): ordered ENet channels drop every packet a
  reordering route delivers late (~40% on a jittery link). Late snapshots are slotted in by timestamp.
- ENet's packet throttle is switched off per peer (`_no_throttle`): it discards unreliable packets
  whenever ping wobbles, and our ~16 KB/s never saturates anything.
- The interpolation buffer adapts per plane: 100 ms on steady links, up to 350 ms when arrivals jitter.
- New planes wait 1 s before streaming, so the reliable spawn usually lands first.
Unchanged by design: your own plane is client-authoritative (no input lag at any ping), hits favour
the shooter, the host decides everything else. Not covered: the WebRTC room transport can't be put
behind this relay; it uses the same unreliable/unordered snapshots.
