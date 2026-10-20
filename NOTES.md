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
1. Online rooms: STUN (Google + Cloudflare) by default. Very strict NAT pairs (some CGNAT) need a TURN
   relay, and we ship no credentials. A player adds their own (only one side of a pair needs it):
   - Get free TURN credentials, e.g. metered.ca (free plan: dashboard > TURN credentials) or Cloudflare
     Realtime TURN (API-generated, short-lived). Use the UDP URL: libjuice ignores `turns:` and TCP.
   - Quit the game, then add to the `[prefs]` section of settings.cfg (macOS: ~/Library/Application
     Support/Godot/app_userdata/Toy Plane Sim/, Windows: %APPDATA%\Godot\app_userdata\Toy Plane Sim\):
     `turn_urls="turn:<host>:<port>"` as your provider lists it (comma-separated for several),
     `turn_username="..."`, `turn_credential="..."`.
   - Or for one run: env `TPS_TURN_URLS`, `TPS_TURN_USERNAME`, `TPS_TURN_CREDENTIAL` (override settings).
   Untested against a real TURN server (needs an account); without one, Tailscale is the fallback.
   Rooms signaling: host always offers; every message carries the host's session id (stale/foreign ones
   dropped), exact duplicates dropped, early ICE queued, own messages repeated until the peer connects,
   20 s per-peer ICE timeout with a NAT hint, brokers rotate on failure then back off 2-30 s with jitter.
   A client that hears nothing after 4 knocks moves to the next broker (finds a host that fell back).
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

## Network architecture (summary, after the 6-stream hardening pass)
- Star topology: everyone talks to the host (ENet on LAN, WebRTC rooms online; TURN optional, see above).
- Authority: your own plane is simulated on your machine (no input lag at any ping); the host owns
  everything else (state, scores, flags, HQs, damage) and validates every client claim: snapshot
  sanity + max speed, hits (range, terrain line of sight, rewind <= 0.3 s, launch exists, ammo,
  fire rate), ordnance only from its owner, match_id on gameplay RPCs, rate limits with auto-kick.
- Motion: all plane snapshots batched into one unreliable packet per host frame (29 B each, AI 20 Hz,
  pilots 30 Hz); clients interpolate on an estimated owner clock with an adaptive buffer, dead-reckon
  up to 1 s through gaps and fade corrections instead of snapping.
- State: delta sync of `gs` every 0.5 s (full sync for joiners), reliable events for the rest.
- Lifecycle: GO waits for loading pilots (15 s max) and is lag-led so everyone fires at once;
  stale RPCs from a previous match are dropped; late joiners get full state.
- Connections: app-level ping for everyone (roster/HUD/feed), "connection interrupted" notice,
  60 s rejoin grace keyed by a saved player id, auto-reconnect, frozen pilots hidden + unhittable,
  host/client goodbyes on leave/quit, user://netlog.txt for post-mortems.
- Measured (8 pilots + AI, mixed bad links): host upload ~115 KB/s, client download ~6-15 KB/s,
  0 teleports / 0% frozen up to 500 ms + 8% loss + reordering, 1 s outages bridged smoothly.
- Test kit: tools/lagproxy.py (ping/jitter/loss/reorder/--burst/--blackout), tools/lagtest.sh,
  tools/evil.gd (malicious client, `--evil`), `--netstats` (client NET / host HOST lines).
