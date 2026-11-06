# Headless fake-Roblox engine (offline QA)

Runs the **real** `game/**` scripts (Main, World, Services, Persistence, shared modules and the client LocalScript) inside the official Luau CLI, with a fake Roblox engine validated against the public Roblox API dump. Created 2026-11-04 in the cloud session; no Studio, no network at test time.

## Run

```bash
python tools/gen_roblox_api.py            # only when the API dump changes
python tests/test_spark_headless.py       # all scenarios; nonzero exit on any failure
python tests/test_spark_headless.py --scenario D_Multi --keep   # one scenario, keep temp dir
```

Prerequisites: `.tools/luau/luau` (official Luau 0.744 CLI) and `tests/engine/RobloxApi.luau` (committed; regenerate from `.tools/api/Full-API-Dump.json`, fetched from `https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json`, sha256 recorded in the generated header).

## How it works

- `tools/gen_roblox_api.py` compacts the dump into `tests/engine/RobloxApi.luau`: 950 classes (superclass, NotCreatable/Service tags, properties with type, read-only flag and game-script security, functions, events) and 656 enums.
- `tests/engine/Datatypes.luau`: Vector3/Vector2/CFrame (rotation matrices, kept orthonormal like Roblox's quaternion storage), Color3, UDim/UDim2, sequences, NumberRange, TweenInfo, Rect, deterministic Random.
- `tests/engine/FakeRoblox.luau`: Instances as proxies. `Instance.new` rejects unknown/non-creatable classes; property reads/writes reject unknown members, read-only and security-restricted properties (e.g. `Lighting.Technology`), wrong enum types, wrong datatypes and wrong class references; attributes reject unsupported value types. `typeof`/`type` follow Roblox (`type(Vector3)=="vector"`, Instances `"userdata"`). Services, Players/characters, RemoteEvents (server↔client routing per context, payload validation for mixed/sparse tables, functions, cycles), DataStore/OrderedDataStore doubles with injectable failures, AnalyticsService with argument-shape checks, TweenService, Debris, ContextActionService, deterministic virtual-time scheduler (`task.*`, `os.clock`, `os.time`). Scripts load with `loadstring` + `setfenv` per-script environments and per-context module caches.
- `tests/engine/Harness.luau`: boot, join, remote send, state/feedback collection, a scripted (non-human) bot that chases, catches, dashes and banks, NaN scan of world parts in `assertClean`.
- `tests/test_spark_headless.py`: copies the harness to a temp dir, generates `Sources.luau` from current `game/**`, runs every `tests/engine/Scenario*.luau`.

## Scenarios and results (2026-11-04, Linux, Luau 0.744; scripted bot, virtual time)

| Scenario | What it proves | Result |
| --- | --- | --- |
| 0 EngineSelfTest | The fake rejects invalid classes, members, enums, types, read-only/security writes, attributes, circular parents; remote payload issues; virtual timers; 20,000 PivotTo calls stay finite | 55 checks pass |
| A Boot | Main boots, 3 arenas, 54 creatures, all 12 species, herd moves within radius 49; no API errors | 119 checks pass; 1,732 world instances |
| B SoloOnboarding | Join → Ready via remote → 3 private starters → catch → bank; v2 payload fields | 18 checks pass (walker: starters 2.3 s, bank 3.3 s after join — not human timing) |
| C FullRound | 110 s round by bot, settlement, lastResult/progression, heat rule, replay, round 2 | 15 checks pass; round length 109–112 s |
| D Multiplayer | Same-frame contention (no duplicates), 4 concurrent players, mid-round leave with carried Sparks banked by final save, rejoin restore, BindToClose | 22 checks pass; stable 10/10 repeated runs |
| E Soak | 10 rounds × 2 players: non-herd instances constant (823 every round), herd 54–58 after settle, scheduled threads flat | 43 checks pass |
| F ProductionPath | Non-Studio path: DataStore envelope/lease, 2 injected transient failures retried, analytics funnel/economy arg shapes, all-time/weekly leaderboard writes, lease release on leave | 18 checks pass |
| G ClientBoot | Real LocalScript boots beside the server, Ready handshake, renders timer from State, bound actions drive catches/banks, every button Activated once, full round with client attached | 8 checks pass (structure-tolerant) |
| H RemoteAbuse | 275 malformed + 500 flooding Action requests: no server errors, no progression change, legitimate catch afterwards | 5 checks pass |

### Added during final production plan execution (2026-11-05/06)

Current counts and timings are in `docs/qa/latest-checks.json`; descriptions below.

| Scenario | What it proves |
| --- | --- |
| A Boot (updated) | 3 shared arenas + Trial Grounds (arena 4); per-arena obstacle sets |
| F ProductionPath (updated) | Frozen 8-step funnel numbering; normal rounds never write public boards (D16); daily board read; exploit counters reported once at leave |
| G ClientBoot (extended) | Real client attached through round 2, a full Daily Stampede run and LEAVE via the client's own button |
| H RemoteAbuse (extended) | New actions (Trial, Reroll, ClaimAll, SitOut, Play, Style tables): no unearned cosmetics/titles, trial stays locked, fixed goal slots intact |
| I SyncedCycles | Four joiners at different cycle offsets: warm-up / partial / full rounds, one buzzer, positive podium, Sit out / Play |
| J DailyStampede | Two players unlock the trial, get identical seeded courses per slot, normalized stats, once-per-day reward, retry, leave mid-run, ClaimAll, daily OrderedDataStore board order, records boards |
| K ArenaIdentity | Distinct obstacle layouts; signature catches and album counts in real play; Aurora Starfall telegraph → six impacts → dazed Sparks hold still → STARSTRUCK catch; no instance growth |
| L Soak4x20 | 4 players × 20 cycles: instances ≤ 4,500, herd ≤ 80/arena, no non-herd growth, threads flat, measured per-client traffic (herd ≤ 6 KB/s, state ≤ 2 KB/tick without the periodic profile, total ≤ 25 KB/s), non-vacuous window |

Wall time for the full suite ≈ 2 minutes (soak ≈ 60 s).

## Findings reported to the main session (not fixed here)

1. **Stale herding attribution across rejoin** — `game/ServerScriptService/Spark/Main.server.luau` gate resolution (`sessionFor(c.spookedBy)`, ~line 1115) and `creditAssist` (~line 494) key spooks by UserId with only a 4 s age check. A player who leaves and rejoins (same UserId) inside 4 s is credited with a HERDED catch for a Spark their previous session spooked (observed in scenario D before the wait was added). Suggested fix: also require `c.spookedAt >= hs.started` (spook happened during the herder's current round) in both places, or clear `spookedBy/assistBy` for that UserId on `PlayerRemoving`.
2. **Uncaught scattered Sparks never expire** — `Main.server.luau` `scatter()` (~line 637) sets `expiresAt` only for golden scatters. Ordinary scattered extras persist until caught; in arenas nobody is playing they accumulate (bounded by zaps, not by time). Suggested fix: `expiresAt=os.clock()+30` for all scattered extras, or cap extras per arena.
3. **Balance signal** — the scripted bot (perfect tracking, zero latency, no human reaction) scored 4,000–6,600 skill in solo rounds and ~800–1,500 with four players sharing a herd; medal thresholds and rank XP should be tuned with these numbers in mind (bots overestimate humans).

## Limitations (what this does NOT prove)

- No physics, collision, character controller, network ownership, LinearVelocity dash motion or falling; the walker sets the root CFrame at ≤21 studs/s.
- No rendering, layout, text fitting, occlusion, particles, audio playback or input devices.
- Server and clients share one DataModel; no replication filtering or latency. Signals fire immediately (not Deferred mode).
- DataStore doubles have no quotas, size limits, throttling or real latency; analytics calls are recorded, not delivered.
- Instance methods present in the API but not modelled return `nil` (recorded in `engine.calls`). Datatype fields are not write-protected against raw mutation.
- Bot behaviour is a scripted heuristic; scores/timings are not human measurements.
